@TestOn('vm')
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bones_api/src/bones_api_utils_isolate_pool.dart';
import 'package:test/test.dart';

// The computations are top-level functions (or closures capturing only
// sendable values), sent to the worker isolates.

int _square(int n) => n * n;

/// State of the worker isolate (each isolate has its own).
int _workerCounter = 0;

int _incrementWorkerCounter() => ++_workerCounter;

int _sleepAndReturn(int n, int ms) {
  sleep(Duration(milliseconds: ms));
  return n;
}

int _throwError() => throw StateError('Computation failure');

ReceivePort _unsendableResult() => ReceivePort();

int _exitIsolate() => Isolate.exit();

Future<int> _asyncSquare(int n) async {
  await Future<void>.delayed(const Duration(milliseconds: 5));
  return n * n;
}

Future<int> _asyncThrow() async {
  await Future<void>.delayed(const Duration(milliseconds: 5));
  throw StateError('Async computation failure');
}

Uint8List _reverse(Uint8List data) =>
    Uint8List.fromList(data.reversed.toList());

String? _workerName(int ms) {
  sleep(Duration(milliseconds: ms));
  return Isolate.current.debugName;
}

/// Runs in a new isolate: uses a pool and doesn't close it.
Future<void> _usePoolWithoutClose(SendPort result) async {
  var pool = APIIsolatePool(maxIsolates: 2);
  var squares = await Future.wait([
    for (var i = 0; i < 4; ++i) pool.run(() => _square(i)),
  ]);
  result.send(squares);
}

/// Waits until [pool] has [length] isolates (fails after 5s).
Future<void> _waitIsolates(APIIsolatePool pool, int length) async {
  var sw = Stopwatch()..start();
  while (pool.isolatesLength != length) {
    if (sw.elapsed > const Duration(seconds: 5)) {
      fail('Timeout waiting for $length isolates: $pool');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('APIIsolatePool', () {
    test('run', () async {
      var pool = APIIsolatePool(maxIsolates: 2, debugName: 'test-run');
      addTearDown(pool.close);

      expect(pool.maxIsolates, equals(2));
      expect(pool.isolatesLength, equals(0));

      var results = await Future.wait([
        for (var i = 0; i < 10; ++i) pool.run(() => _square(i)),
      ]);
      expect(results, equals([for (var i = 0; i < 10; ++i) i * i]));

      // Never more than `maxIsolates`:
      expect(pool.isolatesLength, equals(2));
      expect(pool.runningLength, equals(0));
      expect(pool.queuedLength, equals(0));

      expect(
        pool.toString(),
        equals(
          'APIIsolatePool{name: test-run, maxIsolates: 2, isolates: 2, '
          'running: 0, queued: 0}',
        ),
      );
    });

    test(
      'maxIsolates: concurrent computations limited, others queued',
      () async {
        var pool = APIIsolatePool(maxIsolates: 2);
        addTearDown(pool.close);

        var futures = [
          for (var i = 0; i < 6; ++i) pool.run(() => _sleepAndReturn(i, 100)),
        ];

        expect(pool.isolatesLength, equals(2));
        expect(pool.runningLength, equals(2));
        expect(pool.queuedLength, equals(4));

        var sw = Stopwatch()..start();
        expect(await Future.wait(futures), equals([0, 1, 2, 3, 4, 5]));

        // 6 computations of 100ms, 2 at a time: ~300ms.
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(250));
        expect(pool.isolatesLength, equals(2));
        expect(pool.queuedLength, equals(0));
      },
    );

    test('workers are reused (state kept)', () async {
      var pool = APIIsolatePool(maxIsolates: 1);
      addTearDown(pool.close);

      var results = [
        for (var i = 0; i < 3; ++i) await pool.run(_incrementWorkerCounter),
      ];
      expect(results, equals([1, 2, 3]));

      // Not in this isolate:
      expect(_workerCounter, equals(0));
    });

    test('defaultMaxIsolates', () {
      expect(APIIsolatePool.defaultMaxIsolates, inInclusiveRange(2, 4));
      expect(
        APIIsolatePool.defaultMaxIsolates,
        equals(APIIsolatePool.defaultMaxIsolatesFor(workers: 1)),
      );

      var pool = APIIsolatePool();
      expect(pool.maxIsolates, equals(APIIsolatePool.defaultMaxIsolates));
      // An explicit size can be `1`:
      expect(APIIsolatePool(maxIsolates: 0).maxIsolates, equals(1));
      expect(APIIsolatePool(maxIsolates: 1).maxIsolates, equals(1));
      pool.close();
    });

    test('defaultMaxIsolatesFor: divided by the workers, from 2 to 4', () {
      var cores = Platform.numberOfProcessors;

      for (var workers in [-1, 0, 1, 2, 3, 4, 8, 16, 100]) {
        var expected = ((cores ~/ 2) ~/ (workers < 1 ? 1 : workers)).clamp(
          2,
          4,
        );
        expect(
          APIIsolatePool.defaultMaxIsolatesFor(workers: workers),
          equals(expected),
          reason: 'workers: $workers, cores: $cores',
        );
      }

      // Many workers: never below 2.
      expect(APIIsolatePool.defaultMaxIsolatesFor(workers: 1000), equals(2));
      // Never above 4.
      expect(APIIsolatePool.defaultMaxIsolatesFor(), lessThanOrEqualTo(4));
    });

    test('async computation', () async {
      var pool = APIIsolatePool(maxIsolates: 2);
      addTearDown(pool.close);

      expect(await pool.run(() => _asyncSquare(6)), equals(36));
      await expectLater(pool.run(_asyncThrow), throwsA(isA<RemoteError>()));
    });

    test('large data: sent and received intact', () async {
      var pool = APIIsolatePool(maxIsolates: 1);
      addTearDown(pool.close);

      var data = Uint8List(4 * 1024 * 1024);
      for (var i = 0; i < data.length; ++i) {
        data[i] = (i * 31 + (i >> 11)) & 0xFF;
      }

      var reversed = await pool.run(() => _reverse(data));
      expect(reversed.length, equals(data.length));
      expect(reversed.first, equals(data.last));
      expect(reversed.last, equals(data.first));
      expect(_reverse(reversed), equals(data));
    });

    test('never more than `maxIsolates` distinct workers', () async {
      var pool = APIIsolatePool(maxIsolates: 3, debugName: 'test-distinct');
      addTearDown(pool.close);

      var names = await Future.wait([
        for (var i = 0; i < 60; ++i) pool.run(() => _workerName(2)),
      ]);

      expect(names.toSet().length, inInclusiveRange(1, 3));
      expect(names.every((n) => n!.startsWith('test-distinct#')), isTrue);
      expect(pool.isolatesLength, lessThanOrEqualTo(3));
    });

    test('idleTimeout race: jobs around the timeout never fail', () async {
      var pool = APIIsolatePool(
        maxIsolates: 2,
        idleTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(pool.close);

      // Jobs submitted just before, at and after the idle timeout: a worker
      // may be idle-notified while a job is sent to it.
      for (var i = 0; i < 40; ++i) {
        expect(await pool.run(() => _square(i)), equals(i * i));
        await Future<void>.delayed(Duration(milliseconds: 25 + (i % 4) * 5));
      }

      await _waitIsolates(pool, 0);
      expect(await pool.run(() => _square(3)), equals(9));
    });

    test("doesn't keep its isolate alive", () async {
      var exit = ReceivePort();
      var result = ReceivePort();
      addTearDown(exit.close);
      addTearDown(result.close);

      // An isolate using a pool, without closing it: must exit when done.
      await Isolate.spawn(
        _usePoolWithoutClose,
        result.sendPort,
        onExit: exit.sendPort,
      );

      expect(await result.first, equals([0, 1, 4, 9]));
      await exit.first.timeout(const Duration(seconds: 10));
    });

    test(
      'close while spawning, unsendable computation: worker exits',
      () async {
        // No `idleTimeout`: only the `close` makes the worker exit.
        var pool = APIIsolatePool(maxIsolates: 1, idleTimeout: null);

        var port = ReceivePort();
        addTearDown(port.close);

        var job = pool.run(() => port.hashCode);
        var jobFails = expectLater(job, throwsA(anything));

        // Before the worker is ready (its `SendPort`):
        pool.close();

        await jobFails;
        await _waitIsolates(pool, 0);
      },
    );

    test('computation error: `RemoteError`, pool still usable', () async {
      var pool = APIIsolatePool(maxIsolates: 1);
      addTearDown(pool.close);

      await expectLater(
        pool.run(_throwError),
        throwsA(
          isA<RemoteError>().having(
            (e) => e.toString(),
            'toString',
            contains('Computation failure'),
          ),
        ),
      );

      expect(await pool.run(() => _square(3)), equals(9));
      expect(pool.isolatesLength, equals(1));
    });

    test('unsendable computation or result', () async {
      var pool = APIIsolatePool(maxIsolates: 1);
      addTearDown(pool.close);

      var port = ReceivePort();
      addTearDown(port.close);

      // Captures a `ReceivePort`: can't be sent to the worker.
      await expectLater(
        pool.run(() => port.sendPort.hashCode + port.hashCode),
        throwsA(anything),
      );

      await expectLater(
        pool.run(_unsendableResult),
        throwsA(isA<RemoteError>()),
      );

      expect(await pool.run(() => _square(4)), equals(16));
    });

    test('worker exit: computation fails, worker replaced', () async {
      var pool = APIIsolatePool(maxIsolates: 1);
      addTearDown(pool.close);

      expect(await pool.run(() => _square(2)), equals(4));
      expect(pool.isolatesLength, equals(1));

      await expectLater(pool.run(_exitIsolate), throwsA(isA<RemoteError>()));

      // A new worker:
      expect(await pool.run(() => _square(5)), equals(25));
      expect(pool.isolatesLength, equals(1));
    });

    test('idleTimeout: idle workers exit, spawned again on demand', () async {
      var pool = APIIsolatePool(
        maxIsolates: 2,
        idleTimeout: const Duration(milliseconds: 400),
      );
      addTearDown(pool.close);

      expect(APIIsolatePool.defaultIdleTimeout, const Duration(seconds: 30));
      expect(APIIsolatePool().idleTimeout, APIIsolatePool.defaultIdleTimeout);

      await Future.wait([
        pool.run(() => _sleepAndReturn(1, 50)),
        pool.run(() => _sleepAndReturn(2, 50)),
      ]);
      expect(pool.isolatesLength, equals(2));

      // Both used again before the timeout: kept (the idle time restarts).
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        await Future.wait([
          pool.run(() => _sleepAndReturn(3, 20)),
          pool.run(() => _sleepAndReturn(4, 20)),
        ]),
        equals([3, 4]),
      );
      // Over the first idle deadline (~450ms), under the restarted one:
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(pool.isolatesLength, equals(2));

      // Idle for the timeout: disposed.
      await _waitIsolates(pool, 0);
      expect(pool.isolatesLength, equals(0));

      // A new worker (its state is new):
      expect(await pool.run(_incrementWorkerCounter), equals(1));
      expect(pool.isolatesLength, equals(1));
    });

    test('idleTimeout: not while computing', () async {
      var pool = APIIsolatePool(
        maxIsolates: 1,
        idleTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(pool.close);

      // A computation longer than the `idleTimeout`:
      expect(await pool.run(() => _sleepAndReturn(7, 200)), equals(7));
      expect(pool.isolatesLength, equals(1));

      await _waitIsolates(pool, 0);
    });

    test('idleTimeout: `null`, workers kept', () async {
      var pool = APIIsolatePool(maxIsolates: 1, idleTimeout: null);
      addTearDown(pool.close);

      expect(await pool.run(_incrementWorkerCounter), equals(1));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(pool.isolatesLength, equals(1));
      expect(await pool.run(_incrementWorkerCounter), equals(2));
    });

    test('close', () async {
      var pool = APIIsolatePool(maxIsolates: 1);

      var running = pool.run(() => _sleepAndReturn(1, 100));
      var queued = pool.run(() => _square(2));
      expect(pool.queuedLength, equals(1));

      // Listened before `close` (fails on `close`):
      var queuedFails = expectLater(queued, throwsA(isA<StateError>()));

      pool.close();
      expect(pool.isClosed, isTrue);
      pool.close(); // Idempotent.

      // The running one completes, the queued one fails:
      expect(await running, equals(1));
      await queuedFails;
      await expectLater(pool.run(() => _square(3)), throwsA(isA<StateError>()));
      expect(pool.queuedLength, equals(0));
    });
  });
}

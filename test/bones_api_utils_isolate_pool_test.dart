@TestOn('vm')
import 'dart:io';
import 'dart:isolate';

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
      expect(APIIsolatePool.defaultMaxIsolates, inInclusiveRange(1, 4));

      var pool = APIIsolatePool();
      expect(pool.maxIsolates, equals(APIIsolatePool.defaultMaxIsolates));
      expect(APIIsolatePool(maxIsolates: 0).maxIsolates, equals(1));
      pool.close();
    });

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

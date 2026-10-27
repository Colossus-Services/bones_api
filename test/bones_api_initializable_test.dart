@Timeout(Duration(seconds: 180))
// ignore_for_file: discarded_futures
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_logging.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

final _log = logging.Logger('Initializable');

void main() {
  group('Initializable', () {
    setUpAll(() {
      _log.handler.logToConsole();
      _log.info('Activated logging to console.');
    });

    test('basic', () {
      var initA = _InitA();

      expect(initA.isInitialized, isFalse);
      expect(initA.isInitializing, isFalse);

      var result = initA.doInitialization() as InitializationResult;

      expect(result.ok, isTrue);

      expect(initA.isInitialized, isTrue);
      expect(initA.isInitializing, isFalse);
    });

    test('with dependency', () {
      var initB = _InitB();

      expect(initB.isInitialized, isFalse);
      expect(initB.isInitializing, isFalse);

      var result = initB.doInitialization() as InitializationResult;

      expect(result.ok, isTrue);

      expect(initB.isInitialized, isTrue);
      expect(initB.isInitializing, isFalse);
    });

    test('with sub-dependency', () {
      var initC = _InitC();

      expect(initC.isInitialized, isFalse);
      expect(initC.isInitializing, isFalse);

      var result = initC.doInitialization() as InitializationResult;

      expect(result.ok, isTrue);

      expect(initC.isInitialized, isTrue);
      expect(initC.isInitializing, isFalse);
    });

    test('with recursive dependency (sync)', () {
      var initD = _InitD();

      expect(initD.isInitialized, isFalse);
      expect(initD.isInitializing, isFalse);

      // All synchronous (no delay heuristics): a synchronous result.
      var result = initD.doInitialization();
      expect(result, isA<InitializationResult>());
      expect((result as InitializationResult).ok, isTrue);

      expect(initD.isInitialized, isTrue);
      expect(initD.isInitializing, isFalse);

      // `E` didn't wait for `D` (`D` was waiting for it):
      var initE = initD.context[_InitE]!;
      expect(initE.isInitialized, isTrue);
      expect(initE.cyclicDependencies, [initD]);
      expect(initD.cyclicDependencies, isEmpty);
    });

    test('with recursive dependency (async)', () async {
      var initD = _InitDAsync();

      expect(initD.isInitialized, isFalse);
      expect(initD.isInitializing, isFalse);

      var result = await initD.doInitialization();

      expect(result.ok, isTrue);

      expect(initD.isInitialized, isTrue);
      expect(initD.isInitializing, isFalse);
      expect(initD.context[_InitEAsync]!.isInitialized, isTrue);
    });

    test('with recursive dependency (async 2)', () async {
      var initD = _InitDAsync2();

      expect(initD.isInitialized, isFalse);
      expect(initD.isInitializing, isFalse);

      var result = await initD.doInitialization();

      expect(result.ok, isTrue);

      expect(initD.isInitialized, isTrue);
      expect(initD.isInitializing, isFalse);
      expect(initD.context[_InitEAsync2]!.isInitialized, isTrue);
    });
  });

  group('Initializable: status', () {
    test('idle -> initializing -> finalizing -> initialized', () async {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B')..initGate = Completer();
      a.postDeps.add(b);

      expect(a.initializationStatus.status, 'idle');
      expect(a.initializationStatus.idle, isTrue);

      var r = a.ensureInitialized();
      expect(r, isA<Future>());

      // `A.initialize()` done, waiting for its post-dependency `B`:
      expect(a.isInitializing, isTrue);
      expect(a.initializationStatus.finalizing, isTrue);
      expect(a.initializationStatus.status, 'finalizing[async]');
      expect(a.initializationStatus.idle, isFalse);

      b.initGate!.complete();
      expect((await r).ok, isTrue);

      expect(a.initializationStatus.status, 'initialized[async]');
      expect(a.initializationStatus.initializationTime, isNotNull);
      expect(a.isAsyncInitialization, isTrue);
      expect(a.initializationStatus.failed, isFalse);
    });

    test('result toString', () {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      a.deps.add(b);
      b.deps.add(a);

      var r = a.ensureInitialized() as InitializationResult;
      expect(r.toString(), startsWith('[OK]@_Node'));

      var cyclic = InitializationResult(a, true, cyclic: true);
      expect(cyclic.toString(), startsWith('[OK:CYCLIC]@_Node'));

      var error = InitializationResult.error(a, StateError('x'));
      expect(error.toString(), contains('[ERROR]@_Node'));
      expect(error.toString(), contains('Bad state: x'));
    });

    test('sortByInitializationOrder: the attempts start order', () {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      var c = g.node('C');

      c.ensureInitialized();
      a.ensureInitialized();
      b.ensureInitialized();

      var l = [a, b, c]..sortByInitializationOrder();
      expect(l, [c, a, b]);
    });
  });

  group('Initializable: graphs (sync)', () {
    test('a self-dependency (pre and post)', () {
      var g = _Graph();
      var a = g.node('A');
      a.deps.add(a);
      a.postDeps.add(a);

      var r = a.ensureInitialized();
      expect(r, isA<InitializationResult>());
      expect((r as InitializationResult).ok, isTrue);
      expect(a.initCount, 1);
      expect(a.cyclicDependencies, isEmpty);
      expect(r.dependencies, isEmpty);
    });

    test('A <-> B: B first (A waits for it)', () {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      a.deps.add(b);
      b.deps.add(a);

      var r = a.ensureInitialized() as InitializationResult;
      expect(r.ok, isTrue);
      expect(r.cyclic, isFalse);
      expect(g.events, ['init:B', 'done:B', 'init:A', 'done:A']);
      expect(b.cyclicDependencies, [a]);
      expect(b.cyclicAtInit, [a]);
      expect(a.cyclicDependencies, isEmpty);
      expect([a.initCount, b.initCount], [1, 1]);
    });

    test('a 3-cycle', () {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      var c = g.node('C');
      a.deps.add(b);
      b.deps.add(c);
      c.deps.add(a);

      expect((a.ensureInitialized() as InitializationResult).ok, isTrue);
      expect(g.events.where((e) => e.startsWith('done:')), [
        'done:C',
        'done:B',
        'done:A',
      ]);
      expect(c.cyclicDependencies, [a]);
      g.expectAllInitializedOnce();
    });

    test('a cycle through a post-dependency', () {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      a.deps.add(b);
      b.postDeps.add(a);

      expect((a.ensureInitialized() as InitializationResult).ok, isTrue);
      expect(b.cyclicDependencies, [a]);
      g.expectAllInitializedOnce();
    });

    for (var post in [false, true]) {
      test('a clique of 20 (${post ? 'post' : 'pre'}-dependencies)', () {
        var g = _Graph();
        var nodes = List.generate(20, (i) => g.node('N$i'));
        for (var n in nodes) {
          (post ? n.postDeps : n.deps).addAll(nodes.where((e) => e != n));
        }

        expect(
          (nodes[7].ensureInitialized() as InitializationResult).ok,
          isTrue,
        );
        g.expectAllInitializedOnce();
      });
    }

    test('a diamond: the shared dependency once, first', () {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      var c = g.node('C');
      var d = g.node('D');
      a.deps.addAll([b, c]);
      b.deps.add(d);
      c.deps.add(d);

      expect((a.ensureInitialized() as InitializationResult).ok, isTrue);
      g.expectAllInitializedOnce();
      expect(g.events.indexOf('done:D'), lessThan(g.events.indexOf('init:B')));
      expect(g.events.indexOf('done:D'), lessThan(g.events.indexOf('init:C')));
      expect(g.events.last, 'done:A');
    });

    test('a chain of 200', () {
      var g = _Graph();
      var nodes = List.generate(200, (i) => g.node('N$i'));
      for (var i = 0; i < nodes.length - 1; ++i) {
        nodes[i].deps.add(nodes[i + 1]);
      }

      expect(
        (nodes.first.ensureInitialized() as InitializationResult).ok,
        isTrue,
      );
      g.expectAllInitializedOnce();
      expect(g.events.first, 'init:N199');
      expect(g.events.last, 'done:N0');
    });

    test('a ring of 8 and a dependant off the ring (no stack overflow)', () {
      // The previous resolver walked the parents in 5 levels, restarting
      // its visited set: a parent cycle >= 6 never ended.
      var g = _Graph();
      var ring = List.generate(8, (i) => g.node('R$i'));
      for (var i = 0; i < ring.length; ++i) {
        ring[i].postDeps.add(ring[(i + 1) % ring.length]);
      }
      var x = g.node('X');
      x.deps.add(ring[3]);

      expect(
        (ring.first.ensureInitialized() as InitializationResult).ok,
        isTrue,
      );
      expect((x.ensureInitialized() as InitializationResult).ok, isTrue);
      g.expectAllInitializedOnce();
    });

    test('dependencies of the result: pre and post, declared order', () {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      var c = g.node('C');
      var d = g.node('D');
      a.deps.addAll([b, c, b]);
      a.postDeps.addAll([d, c]);

      var r = a.ensureInitialized() as InitializationResult;
      expect(r.dependencies, [b, c, d]);

      // Already initialized: the same dependencies.
      var r2 = a.ensureInitialized() as InitializationResult;
      expect(r2.ok, isTrue);
      expect(r2.dependencies, [b, c, d]);
    });
  });

  group('Initializable: graphs (async)', () {
    for (var releaseFirst in ['A', 'B']) {
      test('A <-> B, async (release $releaseFirst first)', () async {
        var g = _Graph();
        var a = g.node('A')..initGate = Completer();
        var b = g.node('B')..initGate = Completer();
        a.deps.add(b);
        b.deps.add(a);

        var r = a.ensureInitialized();
        expect(r, isA<Future>());

        await pumpEventQueue();
        // `B` is initializing (not waiting for `A`): `A` waits for it.
        expect(g.events, ['init:B']);

        if (releaseFirst == 'A') {
          a.initGate!.complete();
          await pumpEventQueue();
          expect(a.isInitialized, isFalse);
          b.initGate!.complete();
        } else {
          b.initGate!.complete();
          await pumpEventQueue();
          expect(b.isInitialized, isTrue);
          expect(a.isInitialized, isFalse);
          a.initGate!.complete();
        }

        expect((await r).ok, isTrue);
        g.expectAllInitializedOnce();
        expect(g.events, ['init:B', 'done:B', 'init:A', 'done:A']);
        expect(b.cyclicDependencies, [a]);
      });
    }

    test('async dependencies hooks', () async {
      var g = _Graph();
      var a = g.node('A')..depsGate = Completer();
      var b = g.node('B')..depsGate = Completer();
      a.deps.add(b);
      b.deps.add(a);

      var r = a.ensureInitialized();
      a.depsGate!.complete();
      await pumpEventQueue();
      expect(b.isInitializing, isTrue);
      b.depsGate!.complete();

      expect((await r).ok, isTrue);
      g.expectAllInitializedOnce();
    });

    test('a clique of 20, async', () async {
      var g = _Graph();
      var gate = Completer<void>();
      var nodes = List.generate(20, (i) => g.node('N$i')..initGate = gate);
      for (var n in nodes) {
        n.deps.addAll(nodes.where((e) => e != n));
      }

      var r = nodes.first.ensureInitialized();
      await pumpEventQueue();
      gate.complete();

      expect((await r).ok, isTrue);
      g.expectAllInitializedOnce();
    });

    test('a diamond, async: the shared dependency once', () async {
      var g = _Graph();
      var gate = Completer<void>();
      var a = g.node('A');
      var b = g.node('B')..initGate = gate;
      var c = g.node('C')..initGate = gate;
      var d = g.node('D')..initGate = gate;
      a.deps.addAll([b, c]);
      b.deps.add(d);
      c.deps.add(d);

      var r = a.ensureInitialized();
      gate.complete();
      expect((await r).ok, isTrue);
      g.expectAllInitializedOnce();
    });

    test('a chain of 200, async', () async {
      var g = _Graph();
      var nodes = List.generate(
        200,
        (i) => g.node('N$i')..initGate = (i.isEven ? Completer() : null),
      );
      for (var i = 0; i < nodes.length - 1; ++i) {
        nodes[i].deps.add(nodes[i + 1]);
      }

      var r = nodes.first.ensureInitialized();
      for (var n in nodes) {
        n.initGate?.complete();
      }

      expect((await r).ok, isTrue);
      g.expectAllInitializedOnce();
    });

    test('concurrent roots in a cycle: no deadlock', () async {
      // R1 -> A -> B and R2 -> B -> A, started before any dependency is
      // known (the previous resolver could make both wait for each other).
      var g = _Graph();
      var a = g.node('A')..depsGate = Completer();
      var b = g.node('B')..depsGate = Completer();
      a.deps.add(b);
      b.deps.add(a);

      var r1 = a.ensureInitialized();
      var r2 = b.ensureInitialized();
      expect(a.isInitializing && b.isInitializing, isTrue);

      a.depsGate!.complete();
      b.depsGate!.complete();

      var results = await Future.wait([Future.value(r1), Future.value(r2)])
          .timeout(const Duration(seconds: 10));

      expect(results.every((r) => r.ok), isTrue);
      g.expectAllInitializedOnce();
    });

    test('concurrent roots in a cycle, the other order', () async {
      var g = _Graph();
      var a = g.node('A')..depsGate = Completer();
      var b = g.node('B')..depsGate = Completer();
      a.deps.add(b);
      b.deps.add(a);

      var r1 = a.ensureInitialized();
      var r2 = b.ensureInitialized();

      b.depsGate!.complete();
      await pumpEventQueue();
      a.depsGate!.complete();

      var results = await Future.wait([Future.value(r1), Future.value(r2)])
          .timeout(const Duration(seconds: 10));

      expect(results.every((r) => r.ok), isTrue);
      g.expectAllInitializedOnce();
    });

    test(
      'a concurrent caller waits for the dependencies in progress',
      () async {
        // Synchronous `initializeDependencies`, an async dependency: a second
        // caller got a fake OK before.
        var g = _Graph();
        var a = g.node('A');
        var b = g.node('B')..initGate = Completer();
        a.deps.add(b);

        var r1 = a.ensureInitialized();
        var r2 = a.ensureInitialized();
        var r3 = a.doInitialization();

        expect(r1, isA<Future>());
        expect(r2, isA<Future>());
        expect(r3, isA<Future>());

        var completed = false;
        Future.value(r2).then((_) => completed = true);

        await pumpEventQueue();
        expect(completed, isFalse);
        expect(a.isInitialized, isFalse);

        b.initGate!.complete();

        for (var r in [r1, r2, r3]) {
          expect((await r).ok, isTrue);
        }
        expect(completed, isTrue);
        expect(a.initCount, 1);
      },
    );

    test('a concurrent caller waits for the post-dependencies', () async {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B')..initGate = Completer();
      a.postDeps.add(b);

      var r1 = a.ensureInitialized();
      var r2 = a.ensureInitialized();
      expect(r2, isA<Future>());

      await pumpEventQueue();
      expect(a.isInitialized, isFalse);

      b.initGate!.complete();
      expect((await r1).ok, isTrue);
      expect((await r2).ok, isTrue);
    });

    test('a root waits for its in-progress dependencies closure', () async {
      // `D` (started by `S`) waits for `W`; `W` doesn't wait for `D` (a
      // cycle) and completes. `R` needs `W`: it also waits for `D`, still
      // in progress (in `W`'s dependencies).
      var g = _Graph();
      var d = g.node('D')..initGate = Completer();
      var w = g.node('W');
      var r = g.node('R');
      d.deps.add(w);
      w.deps.add(d);
      r.deps.add(w);

      var rd = d.ensureInitialized();
      await pumpEventQueue();
      expect(w.isInitialized, isTrue);
      expect(w.cyclicDependencies, [d]);
      expect(d.isInitializing, isTrue);

      var rr = r.ensureInitialized();
      expect(rr, isA<Future>());

      await pumpEventQueue();
      expect(r.isInitialized, isFalse);

      d.initGate!.complete();
      expect((await rr).ok, isTrue);
      expect((await rd).ok, isTrue);
      expect(d.isInitialized, isTrue);
    });

    test('ensureInitializedAsync', () async {
      var g = _Graph();
      var a = g.node('A');

      var r = a.ensureInitializedAsync();
      expect(r, isA<Future>());
      expect(a.isInitialized, isFalse);

      expect((await r).ok, isTrue);
      expect(a.isInitialized, isTrue);

      // Already initialized: synchronous.
      expect(a.ensureInitializedAsync(), isA<InitializationResult>());
    });
  });

  group('Initializable: errors', () {
    for (var mode in ['throw', 'error result']) {
      for (var async in [false, true]) {
        test(
          'initialize(): $mode (${async ? 'async' : 'sync'}), retry',
          () async {
            var g = _Graph();
            var a = g.node('A')
              ..failTimes = 1
              ..failWithResult = mode == 'error result'
              ..initGate = async ? (Completer()..complete()) : null;

            var r = a.ensureInitialized();
            expect(r, async ? isA<Future>() : isA<InitializationResult>());

            var result = await r;
            expect(result.ok, isFalse);
            expect(result.error, isA<StateError>());
            expect('${result.error}', contains('fail A'));
            if (mode == 'throw') {
              expect(result.stackTrace, isNotNull);
            }

            var status = a.initializationStatus;
            expect(status.failed, isTrue);
            expect(status.idle, isTrue);
            expect(status.error, isA<StateError>());
            expect(status.status, startsWith('failed'));
            expect(a.isInitializing, isFalse);
            expect(a.isInitialized, isFalse);

            // A retry: a new attempt.
            var result2 = await a.ensureInitialized();
            expect(result2.ok, isTrue);
            expect(a.initCount, 2);
            expect(a.isInitialized, isTrue);
            expect(a.initializationStatus.failed, isFalse);
            expect(a.initializationStatus.error, isNull);
          },
        );
      }
    }

    test('initializeDependencies() throws', () async {
      var g = _Graph();
      var a = g.node('A')..throwOnDeps = true;

      var r = await a.ensureInitialized();
      expect(r.ok, isFalse);
      expect('${r.error}', contains('deps A'));
      expect(a.initCount, 0);
      expect(a.initializationStatus.failed, isTrue);

      a.throwOnDeps = false;
      expect((await a.ensureInitialized()).ok, isTrue);
    });

    test(
      'a dependency fails: the dependant fails (cause), then retries',
      () async {
        var g = _Graph();
        var a = g.node('A');
        var b = g.node('B')..failTimes = 1;
        a.deps.add(b);

        var r = await a.ensureInitialized();
        expect(r.ok, isFalse);
        expect(r.error, isA<InitializationError>());
        var error = r.error as InitializationError;
        expect(error.initializable, a);
        expect('${error.cause}', contains('fail B'));
        expect(error.toString(), contains('Caused by:'));
        expect(a.initCount, 0);
        expect(b.initializationStatus.failed, isTrue);

        // Both retried:
        expect((await a.ensureInitialized()).ok, isTrue);
        expect(a.isInitialized && b.isInitialized, isTrue);
        expect(b.initCount, 2);
      },
    );

    test('a post-dependency fails', () async {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B')
        ..failTimes = 1
        ..initGate = (Completer()..complete());
      a.postDeps.add(b);

      var r = await a.ensureInitialized();
      expect(r.ok, isFalse);
      expect(a.initializationStatus.failed, isTrue);

      expect((await a.ensureInitialized()).ok, isTrue);
    });

    test('a failure in a cycle', () async {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B')..failTimes = 1;
      a.deps.add(b);
      b.deps.add(a);

      var r = await a.ensureInitialized();
      expect(r.ok, isFalse);
      expect(a.initializationStatus.failed, isTrue);
      expect(b.initializationStatus.failed, isTrue);

      expect((await a.ensureInitialized()).ok, isTrue);
      g.expectAllInitialized();
    });

    test(
      'concurrent callers all get the error (no rejected futures)',
      () async {
        var errors = <Object>[];

        await runZonedGuarded(() async {
          var g = _Graph();
          var a = g.node('A')
            ..failTimes = 1
            ..initGate = Completer();

          var callers = [
            a.ensureInitialized(),
            a.ensureInitialized(),
            a.doInitialization(),
          ];

          a.initGate!.complete();

          for (var r in callers) {
            var result = await r;
            expect(result.ok, isFalse);
            expect('${result.error}', contains('fail A'));
          }

          // A discarded attempt that fails: no uncaught error.
          var b = g.node('B')
            ..failTimes = 1
            ..initGate = (Completer()..complete());
          b.ensureInitialized();
          await pumpEventQueue();
        }, (e, s) => errors.add(e));

        expect(errors, isEmpty);
      },
    );
  });

  group('Initializable: checkInitialized', () {
    test('idle, synchronous: initializes', () {
      var g = _Graph();
      var a = g.node('A');
      a.checkInitialized();
      expect(a.isInitialized, isTrue);

      // Initialized: nothing.
      a.checkInitialized();
      expect(a.initCount, 1);
    });

    test('idle, asynchronous: throws (the initialization goes on)', () async {
      var g = _Graph();
      var a = g.node('A')..initGate = Completer();

      expect(
        () => a.checkInitialized(),
        throwsA(
          isA<InitializationError>().having(
            (e) => e.message,
            'message',
            contains('Async'),
          ),
        ),
      );

      a.initGate!.complete();
      expect((await a.ensureInitialized()).ok, isTrue);
    });

    test('a synchronous failure: throws with the cause', () {
      var g = _Graph();
      var a = g.node('A')..failTimes = 1;

      expect(
        () => a.checkInitialized(),
        throwsA(
          isA<InitializationError>().having(
            (e) => '${e.cause}',
            'cause',
            contains('fail A'),
          ),
        ),
      );

      // Not stuck: a retry initializes it.
      a.checkInitialized();
      expect(a.isInitialized, isTrue);
    });

    test(
      'in progress, from outside: returns (allowInProgress: false: throws)',
      () async {
        var g = _Graph();
        var a = g.node('A')..initGate = Completer();

        var r = a.ensureInitialized();

        // The default (as before 1.20.0): in progress is accepted.
        a.checkInitialized();
        a.checkInitialized(allowInProgress: true);

        expect(
          () => a.checkInitialized(allowInProgress: false),
          throwsA(
            isA<InitializationError>().having(
              (e) => e.message,
              'message',
              contains('in progress'),
            ),
          ),
        );

        a.initGate!.complete();
        await r;
        a.checkInitialized(allowInProgress: false);
      },
    );

    test('allowInProgress: false, in a cycle: returns, recorded', () async {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B')..initGate = Completer();
      a.deps.add(b);
      b.deps.add(a);

      Object? error;
      b.onInitialize = (n) {
        try {
          // `A` waits for `B`: a cycle (not an error).
          a.checkInitialized(allowInProgress: false);
        } catch (e) {
          error = e;
        }
      };

      var r = a.ensureInitialized();
      b.initGate!.complete();
      expect((await r).ok, isTrue);
      expect(error, isNull);
      expect(b.cyclicDependencies, [a]);
    });

    test('a cycle found by checkInitialized: in cyclicDependencies', () async {
      // `W`'s hook checks `X` (in progress, waiting for `W`), with no
      // declared dependency: recorded in `W.cyclicDependencies`.
      var g = _Graph();
      var x = g.node('X')..initGate = Completer();
      var w = g.node('W');
      x.deps.add(w);

      w.onInitialize = (n) => x.checkInitialized();

      var r = x.ensureInitialized();
      await pumpEventQueue();
      expect(w.isInitialized, isTrue);
      expect(w.cyclicDependencies, [x]);

      x.initGate!.complete();
      expect((await r).ok, isTrue);
    });

    test('async start throws: the caller is not left waiting for it', () async {
      // `W`'s hook: `C.checkInitialized()` starts `C` (async) and throws.
      // `W` doesn't wait for `C`: when `C` asks for `W`, it waits for it (no
      // false cycle).
      var g = _Graph();
      var w = g.node('W')..initGate = Completer();
      var c = g.node('C')..depsGate = Completer();
      c.deps.add(w);

      Object? error;
      w.onInitialize = (n) {
        try {
          c.checkInitialized();
        } catch (e) {
          error = e;
        }
      };

      var rw = w.ensureInitialized();
      expect(error, isA<InitializationError>());

      c.depsGate!.complete();
      await pumpEventQueue();
      expect(c.cyclicDependencies, isEmpty);
      expect(c.isInitialized, isFalse);

      w.initGate!.complete();
      expect((await rw).ok, isTrue);
      expect((await c.ensureInitialized()).ok, isTrue);
      expect(c.cyclicDependencies, isEmpty);
    });

    test('from its own initialize(): OK', () {
      var g = _Graph();
      var a = g.node('A');
      Object? error;
      a.onInitialize = (n) {
        try {
          n.checkInitialized();
        } catch (e) {
          error = e;
        }
      };

      expect((a.ensureInitialized() as InitializationResult).ok, isTrue);
      expect(error, isNull);
    });

    test('from a cyclic dependency\'s initialize(): OK', () async {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B')..initGate = Completer();
      a.deps.add(b);
      b.deps.add(a);

      Object? error;
      var checked = false;
      b.onInitialize = (n) {
        try {
          a.checkInitialized();
          checked = true;
        } catch (e) {
          error = e;
        }
      };

      var r = a.ensureInitialized();
      b.initGate!.complete();
      expect((await r).ok, isTrue);
      expect(checked, isTrue);
      expect(error, isNull);
    });
  });

  group('Initializable: executeInitialized', () {
    test('runs the callback once initialized', () async {
      var g = _Graph();
      var a = g.node('A')..initGate = Completer();

      bool? initializedInCallback;
      var r = a.executeInitialized(() {
        initializedInCallback = a.isInitialized;
        return 123;
      });

      expect(r, isA<Future>());
      a.initGate!.complete();
      expect(await r, 123);
      expect(initializedInCallback, isTrue);

      // Initialized: synchronous.
      expect(a.executeInitialized(() => 456), 456);
    });

    test(
      'a failure: InitializationError with the cause (sync/async)',
      () async {
        var g = _Graph();

        var sync = g.node('S')..failTimes = 1;
        expect(
          () => sync.executeInitialized(() => 1),
          throwsA(
            isA<InitializationError>().having(
              (e) => '${e.cause}',
              'cause',
              contains('fail S'),
            ),
          ),
        );

        var async = g.node('A')
          ..failTimes = 1
          ..initGate = (Completer()..complete());
        await expectLater(
          Future.value(async.executeInitialized(() => 1)),
          throwsA(
            isA<InitializationError>().having(
              (e) => '${e.cause}',
              'cause',
              contains('fail A'),
            ),
          ),
        );
      },
    );

    test('in a cycle: the callback runs while initializing', () async {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      a.deps.add(b);
      b.deps.add(a);

      bool? aInitializingInCallback;
      b.onInitialize = (n) {
        // `A` waits for `B`: `B` can't wait for `A`.
        a.executeInitialized(() {
          aInitializingInCallback = a.isInitializing;
        });
      };

      expect((a.ensureInitialized() as InitializationResult).ok, isTrue);
      expect(aInitializingInCallback, isTrue);
    });

    test('parent: attributes the wait outside the hooks', () async {
      // `P` waits for `D` (async); `D` asks for `P` outside any hook of
      // `D`, with `parent: D`: a cycle (no deadlock).
      var g = _Graph();
      var p = g.node('P');
      var d = g.node('D')..initGate = Completer();
      p.deps.add(d);

      var rp = p.ensureInitialized();
      await pumpEventQueue();
      expect(d.isInitializing, isTrue);

      var called = false;
      var r = await Zone.root.run(
        () => p.executeInitialized(() => called = true, parent: d),
      );
      expect(r, isTrue);
      expect(called, isTrue);
      expect(p.isInitialized, isFalse);

      d.initGate!.complete();
      expect((await rp).ok, isTrue);
    });
  });

  group('Initializable: merged initializable', () {
    test(
      'a result of another instance: waits for it, reports its deps',
      () async {
        var g = _Graph();
        var x = g.node('X');
        var dep = g.node('D')..initGate = Completer();
        x.deps.add(dep);

        var ra = g.node('RA');
        ra.initializeOverride = (n) => x.ensureInitialized(parent: n);

        var r = ra.ensureInitialized();
        expect(r, isA<Future>());

        await pumpEventQueue();
        expect(ra.isInitialized, isFalse);

        dep.initGate!.complete();
        var result = await r;
        expect(result.ok, isTrue);
        expect(result.initializable, ra);
        expect(result.dependencies, containsAll([x, dep]));
        expect(x.isInitialized && dep.isInitialized, isTrue);
      },
    );
  });

  group('Initializable: waiter attribution (zones)', () {
    test('a parentless call after an await in a hook: a cycle', () async {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B')..initGate = Completer();
      a.deps.add(b);

      InitializationResult? fromB;
      b.afterGate = (n) async {
        // Inside `B`'s hook zone: attributed to `B` (`A` waits for `B`).
        fromB = await a.ensureInitialized();
      };

      var r = a.ensureInitialized();
      b.initGate!.complete();

      expect(
        (await Future.value(r).timeout(const Duration(seconds: 10))).ok,
        isTrue,
      );
      expect(fromB?.cyclic, isTrue);
      expect(b.cyclicDependencies, [a]);
    });

    test('a synchronous call in another zone, in a hook: a cycle', () {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      a.deps.add(b);

      InitializationResult? fromB;
      b.onInitialize = (n) {
        // A foreign zone: attributed by the synchronous hooks stack.
        fromB =
            Zone.root.run(() => a.ensureInitialized()) as InitializationResult;
      };

      expect((a.ensureInitialized() as InitializationResult).ok, isTrue);
      expect(fromB?.cyclic, isTrue);
    });

    test('a stale zone (after the hook completed): a root call', () async {
      var g = _Graph();
      var a = g.node('A');
      var c = g.node('C');

      var later = Completer<FutureOr<InitializationResult>>();
      a.onInitialize = (n) {
        Timer.run(() => later.complete(c.ensureInitialized()));
      };

      expect((a.ensureInitialized() as InitializationResult).ok, isTrue);

      var rc = await (await later.future);
      expect(rc.ok, isTrue);
      expect(rc.cyclic, isFalse);
      expect(c.isInitialized, isTrue);
      expect(a.dependenciesOf, isEmpty);
    });

    test('a fire-and-forget call in a hook: not waited, no deadlock', () async {
      var g = _Graph();
      var a = g.node('A');
      var c = g.node('C')..initGate = Completer();

      a.onInitialize = (n) {
        c.ensureInitialized(); // discarded
      };

      expect((a.ensureInitialized() as InitializationResult).ok, isTrue);
      expect(c.isInitializing, isTrue);

      c.initGate!.complete();
      expect((await c.ensureInitialized()).ok, isTrue);
    });
  });

  group('Initializable: a DB-shaped graph', () {
    for (var async in [false, true]) {
      test(
        'provider <-> adapter <-> repositories (${async ? 'async' : 'sync'})',
        () async {
          // P (provider): post-deps [A, R1..Rn].
          // A (adapter): pre-deps [P]; populates through each R
          //   (`R.executeInitialized(..., parent: P)`), post-deps [P, R1..Rn].
          // R (repository): A.executeInitialized(...), post-deps [A, RA].
          // RA (repository adapter): returns A's result (merged).
          var g = _Graph();
          var p = g.node('P');
          var a = g.node('A')..initGate = async ? Completer() : null;
          var repos = List.generate(5, (i) => g.node('R$i'));
          var repoAdapters = List.generate(5, (i) => g.node('RA$i'));

          p.postDeps.addAll([a, ...repos]);
          a.deps.add(p);
          a.postDeps.addAll([p, ...repos]);

          var populated = <String>[];
          a.afterGate = (n) async {
            for (var r in repos) {
              await r.executeInitialized(
                () => populated.add(r.name),
                parent: p,
              );
            }
          };

          for (var i = 0; i < repos.length; ++i) {
            var r = repos[i];
            var ra = repoAdapters[i];
            ra.initializeOverride = (n) => a.ensureInitialized(parent: n);
            r.initializeOverride = (n) => a.executeInitialized(
              () => InitializationResult.ok(n, dependencies: [a, ra]),
              parent: n,
            );
          }

          var r = p.ensureInitialized();
          if (async) {
            await pumpEventQueue();
            a.initGate!.complete();
          }

          var result = await Future.value(r)
              .timeout(const Duration(seconds: 10));
          expect(result.ok, isTrue);
          expect(populated, repos.map((e) => e.name).toList());
          g.expectAllInitializedOnce();
        },
      );
    }
  });

  group('Initializable: waits and attempts', () {
    test('a discarded call from a hook: not a wait after the hook', () async {
      // `W.initialize()` starts `C` and discards it (e.g. a constructor
      // starting a repository), then `W` waits for a post-dependency. When
      // `C` asks for `W` (after `W`'s hook completed), it waits for it: no
      // false cycle.
      var g = _Graph();
      var p = g.node('P')..initGate = Completer();
      var w = g.node('W');
      var c = g.node('C')..depsGate = Completer();
      w.postDeps.add(p);
      c.deps.add(w);

      w.onInitialize = (n) {
        c.ensureInitialized(); // discarded
      };

      var rw = w.ensureInitialized();
      await pumpEventQueue();
      expect(w.initializationStatus.finalizing, isTrue);

      c.depsGate!.complete();
      await pumpEventQueue();
      expect(c.cyclicDependencies, isEmpty);
      expect(c.isInitialized, isFalse);

      p.initGate!.complete();
      expect((await rw).ok, isTrue);
      expect((await c.ensureInitialized()).ok, isTrue);
      expect(g.events.indexOf('done:W'), lessThan(g.events.indexOf('done:C')));
    });

    test('a root joining an attempt (started by a waiter) drains', () async {
      // `D` waits for `W`; `W` doesn't wait for `D` (a cycle). `P`, started
      // by `Q`'s hook (not a root), has `W` as a post-dependency: a root
      // that joins `P` waits for `D` too (in `W`'s dependencies).
      var g = _Graph();
      var d = g.node('D')..initGate = Completer();
      var w = g.node('W');
      d.deps.add(w);
      w.deps.add(d);

      var rd = d.ensureInitialized();
      await pumpEventQueue();
      expect(w.isInitialized, isTrue);

      var p = g.node('P')..initGate = Completer();
      p.postDeps.add(w);
      var q = g.node('Q');
      q.onInitialize = (n) {
        p.ensureInitialized(); // started by `Q` (discarded)
      };
      expect((q.ensureInitialized() as InitializationResult).ok, isTrue);
      expect(p.isInitializing, isTrue);

      // A root joins `P`:
      var rp = p.ensureInitialized();
      p.initGate!.complete();
      await pumpEventQueue();

      // `P` waits for `D` (in its closure, in progress):
      expect(p.isInitialized, isFalse);

      d.initGate!.complete();
      expect((await rp).ok, isTrue);
      expect((await rd).ok, isTrue);
    });

    test('a retry: its own dependencies (not the failed attempt\'s)', () async {
      var g = _Graph();
      var a = g.node('A')..failTimes = 1;
      var x = g.node('X');
      var y = g.node('Y');
      var z = g.node('Z');
      a.deps.addAll([x, y]);

      var r1 = await a.ensureInitialized();
      expect(r1.ok, isFalse);

      a.deps
        ..clear()
        ..add(z);

      var r2 = await a.ensureInitialized();
      expect(r2.ok, isTrue);
      expect(r2.dependencies, [z]);
    });

    test(
      'a result of another instance: its extra dependencies waited',
      () async {
        // `RA.initialize()` returns a result of `X` with `Y` (not one of `X`'s
        // dependencies): `RA` waits for `Y` too (not a root: no drain).
        var g = _Graph();
        var x = g.node('X');
        var y = g.node('Y')..initGate = Completer();
        var ra = g.node('RA');
        ra.initializeOverride = (n) =>
            InitializationResult.ok(x, dependencies: [y]);

        var q = g.node('Q');
        q.deps.add(ra);

        var rq = q.ensureInitialized();
        await pumpEventQueue();
        expect(ra.isInitialized, isFalse);
        expect(y.isInitializing, isTrue);

        y.initGate!.complete();
        expect((await rq).ok, isTrue);
        expect(ra.isInitialized && x.isInitialized && y.isInitialized, isTrue);
      },
    );

    test('an explicit parent also waits (with the hook)', () async {
      // `A`'s hook asks for `Z` on behalf of `B` (`parent: B`, in
      // progress). `Z` needs `B`: `B` waits for `Z` (declared), so `Z`
      // doesn't wait for `B` (a cycle).
      var g = _Graph();
      var b = g.node('B')..initGate = Completer();
      var a = g.node('A');
      var z = g.node('Z');
      z.deps.add(b);

      var rb = b.ensureInitialized();
      await pumpEventQueue();
      expect(b.isInitializing, isTrue);

      a.onInitialize = (n) {
        z.ensureInitialized(parent: b); // discarded
      };
      expect((a.ensureInitialized() as InitializationResult).ok, isTrue);

      expect(z.isInitialized, isTrue);
      expect(z.cyclicDependencies, [b]);

      b.initGate!.complete();
      expect((await rb).ok, isTrue);
    });

    test('initialized: the same result instance (no copies)', () {
      var g = _Graph();
      var a = g.node('A');
      var b = g.node('B');
      a.deps.add(b);

      var r1 = a.ensureInitialized();
      var r2 = a.ensureInitialized();
      var r3 = a.doInitialization();

      expect(identical(r1, r2), isTrue);
      expect(identical(r2, r3), isTrue);
      expect((r1 as InitializationResult).dependencies, [b]);
    });
  });
}

/// A graph of [_Node]s, with a shared events log.
class _Graph {
  final List<_Node> nodes = [];
  final List<String> events = [];

  _Node node(String name) {
    var n = _Node(name, events);
    nodes.add(n);
    return n;
  }

  void expectAllInitialized() {
    for (var n in nodes) {
      expect(n.isInitialized, isTrue, reason: '$n');
      expect(n.isInitializing, isFalse, reason: '$n');
    }
  }

  void expectAllInitializedOnce() {
    expectAllInitialized();
    for (var n in nodes) {
      expect(n.initCount, 1, reason: '$n');
    }
  }
}

/// A configurable [Initializable]: pre/post dependencies, gates (async
/// hooks), failures and hooks code.
class _Node with Initializable {
  final String name;
  final List<String> events;

  final List<_Node> deps = [];
  final List<_Node> postDeps = [];

  /// `initializeDependencies()` waits for it (async).
  Completer<void>? depsGate;

  /// `initialize()` waits for it (async).
  Completer<void>? initGate;

  bool throwOnDeps = false;

  /// The next attempts that fail.
  int failTimes = 0;

  /// Fail with an error result (not a throw).
  bool failWithResult = false;

  /// Code run synchronously at the start of `initialize()`.
  void Function(_Node node)? onInitialize;

  /// Code run in `initialize()` after the [initGate] (or synchronously).
  Future<void> Function(_Node node)? afterGate;

  /// Replaces `initialize()`.
  FutureOr<InitializationResult> Function(_Node node)? initializeOverride;

  int initCount = 0;
  int depsCount = 0;

  List<Initializable>? cyclicAtInit;

  _Node(this.name, this.events);

  List<Initializable> get dependenciesOf =>
      (ensureInitialized() as InitializationResult).dependencies;

  @override
  FutureOr<List<Initializable>> initializeDependencies() {
    depsCount++;
    if (throwOnDeps) throw StateError('deps $name');

    var gate = depsGate;
    if (gate != null) {
      return gate.future.then((_) => List<Initializable>.of(deps));
    }
    return List<Initializable>.of(deps);
  }

  @override
  FutureOr<InitializationResult> initialize() {
    initCount++;

    var override = initializeOverride;
    if (override != null) return override(this);

    events.add('init:$name');
    onInitialize?.call(this);

    var gate = initGate;
    var afterGate = this.afterGate;

    if (gate != null || afterGate != null) {
      return () async {
        if (gate != null) await gate.future;
        if (afterGate != null) await afterGate(this);
        return _finish();
      }();
    }

    return _finish();
  }

  InitializationResult _finish() {
    cyclicAtInit = cyclicDependencies;

    if (failTimes > 0) {
      failTimes--;
      var error = StateError('fail $name');
      if (failWithResult) return InitializationResult.error(this, error);
      throw error;
    }

    events.add('done:$name');
    return InitializationResult.ok(this, dependencies: postDeps);
  }

  @override
  String toString() => '_Node($name)@$initializationStatus';
}

class _Init with Initializable {
  final Map<Type, _Init> context;

  _Init(this.context) {
    context[runtimeType] = this;
  }

  T inContext<T extends _Init>(T Function() instantiator) =>
      context.putIfAbsent(T, instantiator) as T;

  List<T> inContextAsList<T extends _Init>(T Function() instantiator) => <T>[
    inContext<T>(instantiator),
  ];

  DateTime? initDate;

  @override
  FutureOr<InitializationResult> initialize() {
    initDate = DateTime.now();
    return InitializationResult.ok(this);
  }

  @override
  String toString() {
    return '$runtimeTypeNameUnsafe{${initDate?.millisecondsSinceEpoch}, $initializationStatus}';
  }
}

class _InitAsync extends _Init {
  final Duration delay = Duration(milliseconds: 200);

  _InitAsync(super.context);

  @override
  Future<InitializationResult> initialize() => Future.delayed(delay, () {
    initDate = DateTime.now();
    return InitializationResult.ok(this);
  });
}

class _InitA extends _Init {
  _InitA([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});
}

class _InitB extends _Init {
  _InitB([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() => <Initializable>[
    context.putIfAbsent(_InitA, () => _InitA(context)),
  ];
}

class _InitC extends _Init {
  _InitC([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      inContextAsList<_InitB>(() => _InitB(context));
}

class _InitD extends _Init {
  _InitD([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      inContextAsList<_InitE>(() => _InitE(context));
}

class _InitE extends _Init {
  _InitE([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      inContextAsList<_InitD>(() => _InitD(context));
}

class _InitDAsync extends _InitAsync {
  _InitDAsync([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() => Future.delayed(
    Duration(milliseconds: 200),
    () => inContextAsList<_InitEAsync>(() => _InitEAsync(context)),
  );
}

class _InitEAsync extends _InitAsync {
  _InitEAsync([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() => Future.delayed(
    Duration(milliseconds: 200),
    () => inContextAsList<_InitDAsync>(() => _InitDAsync(context)),
  );
}

class _InitDAsync2 extends _InitAsync {
  _InitDAsync2([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  Future<InitializationResult> initialize() => Future.delayed(delay, () {
    initDate = DateTime.now();
    return InitializationResult.ok(
      this,
      dependencies: inContextAsList<_InitEAsync2>(() => _InitEAsync2(context)),
    );
  });
}

class _InitEAsync2 extends _InitAsync {
  _InitEAsync2([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  Future<InitializationResult> initialize() => Future.delayed(delay, () {
    initDate = DateTime.now();
    return InitializationResult.ok(
      this,
      dependencies: inContextAsList<_InitDAsync2>(() => _InitDAsync2(context)),
    );
  });
}

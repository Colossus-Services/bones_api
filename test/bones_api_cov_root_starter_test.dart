@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

class _StarterRoot extends APIRoot {
  _StarterRoot(String name, {super.apiConfig}) : super(name, '1.0');

  @override
  Set<APIModule> loadModules() => {};
}

void main() {
  group('APIRootStarter', () {
    test(
      'fromInstantiator: async config, preInitializer and stopper',
      () async {
        var preInitCalls = 0;
        var stopCalls = 0;
        APIConfig? receivedConfig;

        var starter = APIRootStarter<_StarterRoot>.fromInstantiator(
          (config) {
            receivedConfig = config;
            return _StarterRoot('cov-starter-1', apiConfig: config);
          },
          apiConfig: () async => APIConfig({'x': 1}),
          preInitializer: () async {
            preInitCalls++;
            return true;
          },
          stopper: () async {
            stopCalls++;
            return true;
          },
        );

        expect(starter.apiRoot, isNull);
        expect(starter.isStarted, isFalse);
        expect(starter.isStopped, isFalse);

        // Not started: nothing to stop.
        expect(await starter.stop(), isFalse);

        var apiRoot = await starter.getAPIRootStarted();
        expect(apiRoot.name, equals('cov-starter-1'));
        expect(receivedConfig?['x'], equals(1));
        expect(starter.apiRoot, same(apiRoot));
        expect(starter.isStarted, isTrue);
        expect(preInitCalls, equals(1));

        // Already started:
        expect(await starter.start(), isTrue);
        expect(await starter.getAPIRootStarted(), same(apiRoot));
        expect(preInitCalls, equals(1));

        expect(await starter.stop(), isTrue);
        expect(starter.isStopped, isTrue);
        expect(starter.isStarted, isFalse);
        expect(stopCalls, equals(1));
      },
    );

    test('fromInstance: concurrent start and stop', () async {
      var apiRoot = _StarterRoot('cov-starter-2');

      var starter = APIRootStarter.fromInstance(apiRoot);
      expect(starter.apiRoot, same(apiRoot));
      expect(await starter.getAPIRoot(), same(apiRoot));

      var s1 = starter.start();
      var s2 = starter.start();
      expect(await s1, isTrue);
      expect(await s2, isTrue);
      expect(starter.isStarted, isTrue);

      expect(await starter.stop(), isTrue);
      expect(starter.isStopped, isTrue);
      expect(starter.isStarted, isFalse);
    });

    test('preInitializer failure', () async {
      var starter = APIRootStarter.fromInstance(
        _StarterRoot('cov-starter-3'),
        preInitializer: () => false,
      );

      await expectLater(
        () async => await starter.start(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Pre-initialization error.',
          ),
        ),
      );

      // Still marked as pre-initializing:
      await expectLater(
        () async => await starter.getAPIRootStarted(),
        throwsStateError,
      );

      starter.apiRoot?.close();
    });

    test('stopper failure', () async {
      var starter = APIRootStarter.fromInstance(
        _StarterRoot('cov-starter-4'),
        stopper: () => false,
      );

      expect(await starter.start(), isTrue);

      await expectLater(
        () async => await starter.stop(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Error stopping.',
          ),
        ),
      );

      // A stop already in progress:
      expect(() => starter.stop(), throwsStateError);
    });
  });
}

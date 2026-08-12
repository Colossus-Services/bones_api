import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_logging.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

import 'bones_api_test_modules.dart';

/// Lets the `Logger.onRecord` broadcast stream deliver.
Future<void> _pump() => Future.delayed(Duration(milliseconds: 5));

void main() {
  // `_logRootMsg` skips building the formatted message when no destination
  // would consume it. These pin the routing that guard depends on: a dropped
  // message would otherwise be a silent regression.
  group('LoggerHandler destinations', () {
    setUp(() {
      LoggerHandler.disableLogQueue();
      _clearDestinations();
    });

    tearDown(_clearDestinations);

    test('logAllTo receives a logged message', () async {
      var all = <String>[];
      logAllTo(messageLogger: (l, m) => all.add(m.toString()));

      logging.Logger('test.logging.all').info('hello-all-destination');
      await _pump();

      expect(
        all.where((m) => m.contains('hello-all-destination')),
        isNotEmpty,
        reason: '`logAllTo` did not receive the message',
      );
    });

    test('logErrorTo receives a SEVERE message', () async {
      var errors = <String>[];
      logErrorTo(messageLogger: (l, m) => errors.add(m.toString()));

      logging.Logger('test.logging.error').severe('hello-severe-destination');
      await _pump();

      expect(
        errors.where((m) => m.contains('hello-severe-destination')),
        isNotEmpty,
        reason: '`logErrorTo` did not receive the SEVERE message',
      );
    });

    test('logAllTo still receives while other destinations are null', () async {
      var all = <String>[];
      logAllTo(messageLogger: (l, m) => all.add(m.toString()));

      logging.Logger('test.logging.mixed').warning('hello-warning');
      logging.Logger('test.logging.mixed').severe('hello-severe');
      await _pump();

      expect(all.where((m) => m.contains('hello-warning')), isNotEmpty);
      expect(all.where((m) => m.contains('hello-severe')), isNotEmpty);
    });

    test('no destination configured: nothing is delivered', () async {
      var all = <String>[];

      logging.Logger('test.logging.none').info('hello-nowhere');
      await _pump();

      expect(all, isEmpty);
    });
  });

  group('logging', () {
    test('apiConfig', () async {
      var logAll = [];
      var logErrors = [];
      var logDb = [];

      var apiRoot = TestAPIRoot(
        apiConfig: {
          'log': {
            'all': (l, m) => logAll.add([l, m]),
            'error': (l, m) => logErrors.add([l, m]),
            'db': (l, m) => logDb.add([l, m]),
            'console': true,
          },
        },
      );

      DBSQLMemoryAdapter.boot();

      await apiRoot.ensureInitialized();

      expect(LoggerHandler.getLogAllTo(), isNotNull);
      expect(LoggerHandler.getLogToConsole(), isTrue);

      expect(LoggerHandler.root.getLogDbTo(), isNotNull);
      expect(LoggerHandler.root.getLogErrorTo(), isNotNull);

      expect(LoggerHandler.dbLoggers, equals([]));
    });
  });
}

void _clearDestinations() {
  logAllTo(messageLogger: null);
  logErrorTo(messageLogger: null);
  logDbTo(messageLogger: null);
  logToConsole(enabled: false);
}

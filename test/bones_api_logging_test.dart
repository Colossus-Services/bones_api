import 'package:test/test.dart';
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_logging.dart';

import 'bones_api_test_modules.dart';

void main() {
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

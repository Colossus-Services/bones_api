@Tags(['entities'])
@Timeout(Duration(seconds: 30))
import 'package:bones_api/bones_api_test.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';

class MemoryTestConfig extends APITestConfigDBSQLMemory {
  MemoryTestConfig({required bool generateTables, required bool checkTables})
      : super({
          'db': {
            'sql.memory': {
              'port': 0,
              'generateTables': generateTables,
              'checkTable': checkTables,
            }
          }
        });
}

Future<void> main() async {
  await _runTest(true, false, false);
  await _runTest(false, false, false);

  await _runTest(true, true, false);
  await _runTest(true, true, true);

  await _runTest(false, true, false);
  await _runTest(false, true, true);
}

Future<bool> _runTest(
    bool useReflection, bool generateTables, bool checkTables) {
  return runAdapterTests(
    'DBSQLMemory',
    MemoryTestConfig(generateTables: generateTables, checkTables: checkTables),
    (provider, dbPort, dbConfig) => DBSQLMemoryAdapter(
      parentRepositoryProvider: provider,
      generateTables: generateTables,
      checkTables: checkTables,
    ),
    (provider, dbPort, dbConfig) =>
        DBObjectMemoryAdapter(parentRepositoryProvider: provider),
    '"',
    'int',
    entityByReflection: useReflection,
    generateTables: generateTables,
    checkTables: checkTables,
  );
}

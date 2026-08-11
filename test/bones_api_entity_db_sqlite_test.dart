@TestOn('vm')
@Tags(['sqlite', 'entities', 'slow'])
@Timeout(Duration(minutes: 10))
library;

import 'package:bones_api/bones_api_db_sqlite.dart';
import 'package:bones_api/bones_api_test_sqlite.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';

class SQLiteTestConfig extends APITestConfigSQLite {
  @override
  String get runtimeTypeNameSafe => 'SQLiteTestConfig';

  SQLiteTestConfig({
    required bool generateTables,
    required bool checkTables,
    required bool memory,
  }) : super({
         'db': {
           'sqlite': {
             'port': 0,
             'memory': memory,
             'generateTables': generateTables,
             'checkTables': checkTables,
           },
         },
       }, memory: memory);
}

Future<void> main() async {
  // A file database, over the same matrix used by the PostgreSQL/MySQL tests:
  await _runTest(false, false, false, false, memory: false);
  await _runTest(true, false, false, false, memory: false);

  await _runTest(true, true, false, false, memory: false);
  await _runTest(true, true, true, false, memory: false);
  await _runTest(true, true, true, true, memory: false);

  // And an in-memory database:
  await _runTest(true, true, true, false, memory: true);
  await _runTest(false, true, true, true, memory: true);
}

Future<bool> _runTest(
  bool useReflection,
  bool generateTables,
  bool checkTables,
  bool populateSource, {
  required bool memory,
}) {
  var testConfig = SQLiteTestConfig(
    generateTables: generateTables,
    checkTables: checkTables,
    memory: memory,
  );

  return runAdapterTests(
    'SQLite${memory ? '+memory' : '+file'}',
    testConfig,
    (provider, dbPort, dbConfig) {
      var populate = dbConfig?['populate'] as Map?;
      var sqliteConfig = dbConfig?['sqlite'] as Map?;

      var adapter = DBSQLiteAdapter(
        sqliteConfig?['path']?.toString() ?? ':memory:',
        parentRepositoryProvider: provider,
        generateTables: generateTables,
        checkTables: checkTables,
        populateSource: populate?['source'],
        populateSourceVariables: populate?['variables'],
      );

      // `runSQL`/`listTables` must reach the same database — mandatory for an
      // in-memory one, whose handle is private to the adapter.
      testConfig.sqlAdapter = adapter;

      return adapter;
    },
    (provider, dbPort, dbConfig) =>
        DBObjectMemoryAdapter(parentRepositoryProvider: provider),
    '"',
    'integer',
    entityByReflection: useReflection,
    generateTables: generateTables,
    checkTables: checkTables,
    populateSource: populateSource,
  );
}

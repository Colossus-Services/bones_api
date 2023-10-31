@TestOn('vm')
@Tags(['docker', 'postgres', 'entities', 'slow'])
@Timeout(Duration(minutes: 4))
import 'package:bones_api/bones_api_db_postgre.dart';
import 'package:bones_api/bones_api_test_postgres.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';

final dbUser = 'postgres';
final dbPass = '123456';
final dbName = 'postgres';

class PostgresTestConfig extends APITestConfigDockerPostgreSQL {
  @override
  String get runtimeTypeNameSafe => 'PostgresTestConfig';

  PostgresTestConfig({required bool generateTables, required bool checkTables})
      : super({
          'db': {
            'postgres': {
              'username': dbUser,
              'password': dbPass,
              'database': dbName,
              'port': -5432,
              'generateTables': generateTables,
              'checkTables': checkTables,
            }
          }
        }, containerNamePrefix: 'bones_api_test_postgres');
}

Future<void> main() async {
  await _runTest(true, false, false, false);
  await _runTest(false, false, false, false);

  await _runTest(true, true, false, false);
  await _runTest(true, true, true, false);
  await _runTest(true, true, true, true);
}

Future<bool> _runTest(bool useReflection, bool generateTables, bool checkTables,
        bool populateSource) =>
    runAdapterTests(
      'PostgreSQL',
      PostgresTestConfig(
          generateTables: generateTables, checkTables: checkTables),
      (provider, dbPort, dbConfig) {
        var populate = dbConfig?['populate'] as Map?;
        return DBPostgreSQLAdapter(
          dbName,
          dbUser,
          password: dbPass,
          port: dbPort,
          parentRepositoryProvider: provider,
          generateTables: generateTables,
          checkTables: checkTables,
          populateSource: populate?['source'],
          populateSourceVariables: populate?['variables'],
        );
      },
      (provider, dbPort, dbConfig) =>
          DBObjectMemoryAdapter(parentRepositoryProvider: provider),
      '"',
      'bigint',
      entityByReflection: useReflection,
      generateTables: generateTables,
      checkTables: checkTables,
      populateSource: populateSource,
    );

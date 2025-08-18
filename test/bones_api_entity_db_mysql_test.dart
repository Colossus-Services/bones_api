@TestOn('vm')
@Tags(['docker', 'mysql', 'slow'])
@Timeout(Duration(minutes: 4))
import 'package:bones_api/bones_api_db_mysql.dart';
import 'package:bones_api/bones_api_test_mysql.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';

final dbUser = 'myuser';
final dbPass = 'mypass';
final dbName = 'mydb';

class MySQLTestConfig extends APITestConfigDockerMySQL {
  @override
  String get runtimeTypeNameSafe => 'MySQLTestConfig';

  MySQLTestConfig({
    required bool generateTables,
    required bool checkTables,
    super.cleanContainer,
  }) : super(
         {
           'db': {
             'mysql': {
               'username': dbUser,
               'password': dbPass,
               'database': dbName,
               'port': -3306,
               'generateTables': generateTables,
               'checkTables': checkTables,
             },
           },
         },
         containerNamePrefix: 'bones_api_test_mysql',
         forceNativePasswordAuthentication: true,
         // TODO: update package `mysql1` with support for MySQL 8.4.0
         version: '8.0.37',
       );
}

Future<void> main() async {
  await _runTest(false, false, false, false);
  await _runTest(true, false, false, false);

  await _runTest(true, true, false, false);
  await _runTest(true, true, true, false);
  await _runTest(true, true, true, true);
}

Future<bool> _runTest(
  bool useReflection,
  bool generateTables,
  bool checkTables,
  bool populateSource,
) => runAdapterTests(
  'MySQL',
  MySQLTestConfig(generateTables: generateTables, checkTables: checkTables),
  (provider, dbPort, dbConfig) {
    var populate = dbConfig?['populate'] as Map?;
    return DBMySQLAdapter(
      dbName,
      dbUser,
      password: dbPass,
      host: '127.0.0.1',
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
  '`',
  'bigint unsigned',
  entityByReflection: useReflection,
  generateTables: generateTables,
  checkTables: checkTables,
  populateSource: populateSource,
);

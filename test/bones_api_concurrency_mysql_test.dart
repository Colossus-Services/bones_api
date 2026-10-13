@TestOn('vm')
@Tags(['concurrency', 'docker', 'mysql'])
@Timeout(Duration(minutes: 10))
library;

import 'package:bones_api/bones_api_db_mysql.dart';
import 'package:test/test.dart';

import 'bones_api_concurrency_tests_base.dart';
import 'bones_api_entity_db_mysql_test.dart';

void main() {
  var testConfig = MySQLTestConfig(generateTables: true, checkTables: false);

  var providers = ConcurrencySQLProviders(
    (provider, dbPort, dbConfig) => DBMySQLAdapter(
      dbName,
      dbUser,
      password: dbPass,
      host: '127.0.0.1',
      port: dbPort,
      parentRepositoryProvider: provider,
      generateTables: true,
    ),
  );

  runConcurrencyTests(
    'MySQL',
    setUp: () async {
      await testConfig.start();
      return providers.setUp(dbPort: await testConfig.dbPort);
    },
    tearDown: () async {
      providers.close();
      await testConfig.stop();
    },
    capabilities: const ConcurrencyCapabilities(isolation: true),
  );
}

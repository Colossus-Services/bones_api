@TestOn('vm')
@Tags(['concurrency', 'docker', 'postgres'])
@Timeout(Duration(minutes: 10))
library;

import 'package:bones_api/bones_api_db_postgre.dart';
import 'package:test/test.dart';

import 'bones_api_concurrency_tests_base.dart';
import 'bones_api_enitity_db_postgres_test.dart';

void main() {
  var testConfig = PostgresTestConfig(generateTables: true, checkTables: false);

  var providers = ConcurrencySQLProviders(
    (provider, dbPort, dbConfig) => DBPostgreSQLAdapter(
      dbName,
      dbUser,
      password: dbPass,
      port: dbPort,
      parentRepositoryProvider: provider,
      generateTables: true,
    ),
  );

  runConcurrencyTests(
    'PostgreSQL',
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

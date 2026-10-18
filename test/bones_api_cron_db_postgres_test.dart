@TestOn('vm')
@Tags(['docker', 'postgres', 'entities', 'slow'])
@Timeout(Duration(minutes: 5))
library;

import 'package:bones_api/bones_api_db_postgre.dart';
import 'package:test/test.dart';

import 'bones_api_cron_db_tests_base.dart';
import 'bones_api_enitity_db_postgres_test.dart';

void main() {
  var testConfig = PostgresTestConfig(generateTables: true, checkTables: true);

  CronDBProvider? provider;

  runCronStoreDBTests(
    'PostgreSQL',
    setUpProvider: () async {
      await testConfig.start();
      var dbPort = await testConfig.dbPort;

      var p = provider = CronDBProvider(
        (provider) => DBPostgreSQLAdapter(
          dbName,
          dbUser,
          password: dbPass,
          port: dbPort,
          parentRepositoryProvider: provider,
          generateTables: true,
          checkTables: true,
        ),
      );
      await p.ensureInitialized();
      return p;
    },
    tearDownProvider: () async {
      provider?.close();
      await testConfig.stop();
    },
  );
}

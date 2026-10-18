@TestOn('vm')
@Tags(['docker', 'mysql', 'entities', 'slow'])
@Timeout(Duration(minutes: 5))
library;

import 'package:bones_api/bones_api_db_mysql.dart';
import 'package:test/test.dart';

import 'bones_api_cron_db_tests_base.dart';
import 'bones_api_entity_db_mysql_test.dart';

void main() {
  var testConfig = MySQLTestConfig(generateTables: true, checkTables: true);

  CronDBProvider? provider;

  runCronStoreDBTests(
    'MySQL',
    setUpProvider: () async {
      await testConfig.start();
      var dbPort = await testConfig.dbPort;

      var p = provider = CronDBProvider(
        (provider) => DBMySQLAdapter(
          dbName,
          dbUser,
          password: dbPass,
          host: '127.0.0.1',
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

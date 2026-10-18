@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(minutes: 2))
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_cron_db_tests_base.dart';

void main() {
  CronDBProvider? provider;

  runCronStoreDBTests(
    'memory',
    setUpProvider: () async {
      var p = provider = CronDBProvider(
        (provider) => DBSQLMemoryAdapter(parentRepositoryProvider: provider),
      );
      await p.ensureInitialized();
      return p;
    },
    tearDownProvider: () async => provider?.close(),
  );
}

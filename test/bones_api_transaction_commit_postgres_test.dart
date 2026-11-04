@TestOn('vm')
@Tags(['docker', 'postgres'])
@Timeout(Duration(minutes: 4))
library;

import 'package:bones_api/bones_api_db_postgre.dart';
import 'package:test/test.dart';

import 'bones_api_enitity_db_postgres_test.dart';
import 'bones_api_transaction_commit_tests_base.dart';

const _createTableSQL =
    'CREATE TABLE IF NOT EXISTS "commit_test_owner" ('
    '"id" BIGSERIAL PRIMARY KEY, '
    '"name" VARCHAR, '
    'CONSTRAINT "commit_test_owner_name_deferred" UNIQUE ("name") '
    'DEFERRABLE INITIALLY DEFERRED)';

/// A PostgreSQL `COMMIT` that fails: a `DEFERRABLE INITIALLY DEFERRED`
/// unique constraint is only checked at the `COMMIT` (each `INSERT` succeeds).
void main() {
  runTransactionCommitErrorTests(
    dbName: 'PostgreSQL',
    testConfig: PostgresTestConfig(generateTables: false, checkTables: false),
    createAdapter: (provider, dbPort) => DBPostgreSQLAdapter(
      dbName,
      dbUser,
      password: dbPass,
      port: dbPort,
      parentRepositoryProvider: provider,
      generateTables: false,
      checkTables: false,
    ),
    createTablesSQLs: [_createTableSQL],
    storeWithFailingCommit: (t, p) async {
      await p.ownerRepository.store(
        CommitTestOwner(name: 'dup'),
        transaction: t,
      );
      await p.ownerRepository.store(
        CommitTestOwner(name: 'dup'),
        transaction: t,
      );
    },
    commitError: predicate(
      (e) =>
          '$e'.contains('23505') ||
          '$e'.contains('commit_test_owner_name_deferred'),
      'a unique violation (23505)',
    ),
  );
}

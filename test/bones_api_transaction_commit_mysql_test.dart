@TestOn('vm')
@Tags(['docker', 'mysql'])
@Timeout(Duration(minutes: 4))
library;

import 'package:bones_api/bones_api_db_mysql.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_mysql_test.dart';
import 'bones_api_transaction_commit_tests_base.dart';

const _createTableSQL =
    'CREATE TABLE IF NOT EXISTS `commit_test_owner` ('
    '`id` BIGINT AUTO_INCREMENT PRIMARY KEY, '
    '`name` VARCHAR(255)) ENGINE=InnoDB';

/// A MySQL `COMMIT` that fails: MySQL has no deferred constraints, so the
/// transaction's connection is closed (as by a network failure) after its
/// last `INSERT`, before the `COMMIT`.
void main() {
  runTransactionCommitErrorTests(
    dbName: 'MySQL',
    testConfig: MySQLTestConfig(generateTables: false, checkTables: false),
    createAdapter: (provider, dbPort) => DBMySQLAdapter(
      dbName,
      dbUser,
      password: dbPass,
      host: '127.0.0.1',
      port: dbPort,
      parentRepositoryProvider: provider,
      generateTables: false,
      checkTables: false,
    ),
    createTablesSQLs: [_createTableSQL],
    storeWithFailingCommit: (t, p) async {
      await p.ownerRepository.store(
        CommitTestOwner(name: 'lost'),
        transaction: t,
      );

      var connection = t.context as DBMySqlConnectionWrapper;
      await connection.nativeConnection.close();
    },
    // Not a `MySqlException`: the `COMMIT` can't be written to the closed
    // socket (`mysql1`: "Cannot write to socket, it is closed").
    commitError: predicate(
      (e) => '$e'.contains('closed'),
      'a closed connection error',
    ),
  );
}

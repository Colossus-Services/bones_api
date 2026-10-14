@TestOn('vm')
@Tags(['docker', 'postgres', 'entities', 'slow'])
@Timeout(Duration(minutes: 40))
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

  PostgresTestConfig({
    required bool generateTables,
    required bool checkTables,
    super.cleanContainer,
  }) : super(
         {
           'db': {
             'postgres': {
               'username': dbUser,
               'password': dbPass,
               'database': dbName,
               'port': -5432,
               'generateTables': generateTables,
               'checkTables': checkTables,
             },
           },
         },
         containerNamePrefix: 'bones_api_test_postgres',
         logStatement: 'all',
       );
}

Future<void> main() async {
  await _runTest(true, false, false, false);
  await _runTest(false, false, false, false);

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
  'PostgreSQL',
  PostgresTestConfig(generateTables: generateTables, checkTables: checkTables),
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
  adapterTests: {
    'prepared statements: not run on a finished transaction':
        _testPreparedStatementOnFinishedTransaction,
    'prepared statements: stale inside a transaction':
        _testStalePreparedStatementInTransaction,
  },
);

/// A cached prepared statement made stale by a schema change (`0A000`: its
/// result columns changed), run inside a transaction: the error has aborted
/// the transaction, so it's rethrown (not retried), and the statement is
/// evicted (the next run, outside, prepares it again).
Future<void> _testStalePreparedStatementInTransaction(
  DBSQLAdapter sqlAdapter,
) async {
  var adapter = sqlAdapter as DBPostgreSQLAdapter;
  var info = adapter.preparedStatementsInfo;
  var conn = await adapter.catchFromPool();

  const select = 'SELECT * FROM "store" WHERE "id" = @id:int8';
  var altered = false;

  try {
    var cache = conn.statementsCache;
    if (cache == null || info == null) return;

    // Prepared on the connection (when it repeats):
    for (var i = 0; i < 2; ++i) {
      await conn.query(select, substitutionValues: {'id': 1});
    }
    expect(cache.contains(select), isTrue);

    // `SELECT *` gets another column:
    await conn.execute('ALTER TABLE "store" ADD COLUMN "ps_tx_extra" INT');
    altered = true;

    var stale0 = info.stale;

    await expectLater(
      conn.openTransaction(
        (tx) => tx.query(select, substitutionValues: {'id': 1}),
      ),
      throwsA(predicate((e) => '$e'.contains('0A000'))),
    );

    expect(info.stale, equals(stale0 + 1));
    expect(cache.contains(select), isFalse);

    // Outside a transaction, the connection is usable and the SQL runs again:
    var rs = await conn.query(select, substitutionValues: {'id': 1});
    expect(rs.schema.columns.map((c) => c.columnName), contains('ps_tx_extra'));
  } finally {
    if (altered) {
      await conn.execute('ALTER TABLE "store" DROP COLUMN "ps_tx_extra"');
      adapter.disposeTableSchemeCache('store');
    }
    await adapter.releaseIntoPool(conn);
  }
}

/// A cached prepared statement run on the connection wrapper of a transaction
/// already finished (e.g. an execution queued before an abort) must fail, as
/// an unprepared one does, and not run outside that transaction.
Future<void> _testPreparedStatementOnFinishedTransaction(
  DBSQLAdapter sqlAdapter,
) async {
  var adapter = sqlAdapter as DBPostgreSQLAdapter;
  var conn = await adapter.catchFromPool();

  const insert =
      'INSERT INTO "store" ("name", "number") VALUES (@name, @number)';

  try {
    var cache = conn.statementsCache;
    if (cache == null) return;

    // Prepared on the connection (when it repeats):
    for (var i = 0; i < 2; ++i) {
      await conn.execute(
        insert,
        substitutionValues: {'name': 'ps-tx-$i', 'number': i},
      );
    }
    expect(cache.contains(insert), isTrue);

    PostgreSQLConnectionTransactionWrapper? txConn;
    await conn.openTransaction((tx) async => txConn = tx);

    await expectLater(
      txConn!.execute(
        insert,
        substitutionValues: {'name': 'ps-tx-late', 'number': 9},
      ),
      throwsA(predicate((e) => '$e'.contains('not open'))),
    );

    var rows = await conn.mappedResultsQuery(
      'SELECT count(*) AS "n" FROM "store" WHERE "name" = @name',
      substitutionValues: {'name': 'ps-tx-late'},
    );
    expect(rows.first['n'], equals(0));
  } finally {
    // The other tests count the stores:
    await conn.execute(
      'DELETE FROM "store" WHERE "name" LIKE @name',
      substitutionValues: {'name': 'ps-tx-%'},
    );
    await adapter.releaseIntoPool(conn);
  }
}

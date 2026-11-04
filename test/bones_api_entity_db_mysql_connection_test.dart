@TestOn('vm')
@Tags(['docker', 'mysql'])
@Timeout(Duration(minutes: 4))
library;

import 'package:bones_api/bones_api_db_mysql.dart';
import 'package:mysql1/mysql1.dart' show MySqlException;
import 'package:test/test.dart';

import 'bones_api_entity_db_mysql_test.dart';

/// `mysql1` (since 0.21) closes the connection when a query fails with
/// anything but a [MySqlException] (a timeout, a socket error...), without
/// exposing it: the [DBMySqlConnectionWrapper] must then report itself closed,
/// so the pool discards it.
void main() {
  var testConfig = MySQLTestConfig(generateTables: false, checkTables: false);

  late DBMySQLAdapter adapter;

  setUpAll(() async {
    await testConfig.start();
    adapter = DBMySQLAdapter(
      dbName,
      dbUser,
      password: dbPass,
      host: '127.0.0.1',
      port: await testConfig.dbPort,
    );
  });

  tearDownAll(() async {
    adapter.close();
    await testConfig.stop();
  });

  group('DBMySqlConnectionWrapper', () {
    test('a MySqlException keeps the connection', () async {
      var c = await adapter.createConnection();

      await expectLater(
        c.query('SELECT * FROM `bones_api_no_such_table`'),
        throwsA(isA<MySqlException>()),
      );

      expect(c.isClosed, isFalse);
      expect(adapter.isConnectionValid(c, checkUsage: false), isTrue);

      var r = await c.query('SELECT ? AS v', [1]);
      expect(r.first['v'], equals(1));

      var rs = await c.queryMulti('SELECT ? AS v', [
        [1],
        [2],
      ]);
      expect(rs.map((r) => r.first['v']), equals([1, 2]));

      c.close();
      expect(c.isClosed, isTrue);
    });

    test('a connection closed by mysql1 is marked closed: query', () async {
      var c = await adapter.createConnection();
      expect(c.isClosed, isFalse);

      // Closes the native connection, as `mysql1` does on a timeout or a
      // socket error:
      await c.nativeConnection.close();
      expect(c.isClosed, isFalse);

      await expectLater(
        c.query('SELECT 1'),
        throwsA(isNot(isA<MySqlException>())),
      );

      expect(c.isClosed, isTrue);
      expect(adapter.isConnectionValid(c, checkUsage: false), isFalse);
    });

    test(
      'a connection closed by mysql1 is marked closed: queryMulti',
      () async {
        var c = await adapter.createConnection();

        await c.nativeConnection.close();

        await expectLater(
          c.queryMulti('SELECT ? AS v', [
            [1],
          ]),
          throwsA(isNot(isA<MySqlException>())),
        );

        expect(c.isClosed, isTrue);
      },
    );

    test('in a transaction: also marks the connection closed', () async {
      var c = await adapter.createConnection();

      DBMySqlConnectionWrapper? transactionConnection;
      Object? error;

      try {
        await c.openTransaction((t) async {
          transactionConnection = t;

          var rs = await t.queryMulti('SELECT ? AS v', [
            [1],
            [2],
          ]);
          expect(rs.map((r) => r.first['v']), equals([1, 2]));

          await c.nativeConnection.close();

          await t.query('SELECT 1');
        });
      } catch (e) {
        error = e;
      }

      expect(error, isNotNull);
      expect(error, isNot(isA<MySqlException>()));

      expect(transactionConnection!.isClosed, isTrue);
      expect(c.isClosed, isTrue);
      expect(adapter.isConnectionValid(c, checkUsage: false), isFalse);
    });
  });
}

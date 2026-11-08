// Unit-level tests (no database needed) of the PostgreSQL and MySQL adapters'
// fixes: their parsing of results and the SQL they generate.
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_mysql.dart';
import 'package:bones_api/bones_api_db_postgre.dart';
import 'package:test/test.dart';

void main() {
  group('DBPostgreSQLAdapter.countFromResults', () {
    test('no row: 0 (as SQLite/MySQL)', () {
      expect(DBPostgreSQLAdapter.countFromResults([]), equals(0));
    });

    test('a row without a parseable count: 0', () {
      expect(
        DBPostgreSQLAdapter.countFromResults([
          {'count': 'x'},
        ]),
        equals(0),
      );
    });

    test('the count', () {
      expect(
        DBPostgreSQLAdapter.countFromResults([
          {'count': 3},
        ]),
        equals(3),
      );
      expect(
        DBPostgreSQLAdapter.countFromResults([
          {'count': ' 7 '},
        ]),
        equals(7),
      );
      expect(
        DBPostgreSQLAdapter.countFromResults([
          {'count': null},
        ]),
        equals(0),
      );
    });
  });

  group('DBPostgreSQLAdapter.fixTableSequenceSQL', () {
    test('max of the ID field (not a literal `id`)', () {
      var sql = DBPostgreSQLAdapter.fixTableSequenceSQL('account', 'user_id');

      expect(
        sql,
        equals(
          "SELECT setval(pg_get_serial_sequence('account', 'user_id'), "
          "coalesce(max(\"user_id\"),0) + 1, false) FROM \"account\"",
        ),
      );
      expect(sql, isNot(contains('max(id)')));
    });

    test("a `'` in the table name is escaped", () {
      expect(
        DBPostgreSQLAdapter.fixTableSequenceSQL("a'b", 'id'),
        startsWith("SELECT setval(pg_get_serial_sequence('a''b', 'id'), "),
      );
    });
  });

  group('DBSQLAdapter.sqlStringLiteral', () {
    test('quoted', () {
      expect(DBSQLAdapter.sqlStringLiteral('user'), equals("'user'"));
      expect(DBSQLAdapter.sqlStringLiteral(''), equals("''"));
    });

    test("a `'` is doubled", () {
      expect(DBSQLAdapter.sqlStringLiteral("a'b"), equals("'a''b'"));
      expect(
        DBSQLAdapter.sqlStringLiteral("x' OR '1'='1"),
        equals("'x'' OR ''1''=''1'"),
      );
    });
  });

  group('findFieldsReferencedTablesSQL', () {
    test('PostgreSQL: the same query, the table name escaped', () {
      var sql = DBPostgreSQLAdapter.findFieldsReferencedTablesSQL('account');
      expect(sql, contains("AND m.relname = 'account'\n"));

      var sqlQuote = DBPostgreSQLAdapter.findFieldsReferencedTablesSQL(
        "x' OR '1'='1",
      );
      expect(sqlQuote, contains("AND m.relname = 'x'' OR ''1''=''1'\n"));
      expect(
        sqlQuote.replaceFirst("'x'' OR ''1''=''1'", "'account'"),
        equals(sql),
      );
    });

    test('MySQL: the same query, the names escaped', () {
      var sql = DBMySQLAdapter.findFieldsReferencedTablesSQL('db', 'account');
      expect(sql, contains("TABLE_SCHEMA = 'db' AND TABLE_NAME = 'account'\n"));

      var sqlQuote = DBMySQLAdapter.findFieldsReferencedTablesSQL(
        "d'b",
        "x' OR '1'='1",
      );
      expect(
        sqlQuote,
        contains("TABLE_SCHEMA = 'd''b' AND TABLE_NAME = 'x'' OR ''1''=''1'\n"),
      );
    });
  });
}

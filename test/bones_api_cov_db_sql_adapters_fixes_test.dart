// Unit-level tests (no database needed) of the PostgreSQL and MySQL adapters'
// fixes: their parsing of results and the SQL they generate.
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
}

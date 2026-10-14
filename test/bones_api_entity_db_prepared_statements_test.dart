import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('PreparedStatementsCache', () {
    test('prepareOnSighting: 1 (on the first use)', () {
      var cache = PreparedStatementsCache<String>(maxSize: 10, onEvict: (_) {});
      expect(cache.shouldPrepare('a'), isTrue);
      expect(cache.shouldPrepare('a'), isTrue);
    });

    test('prepareOnSighting: 2 (when it repeats)', () {
      var cache = PreparedStatementsCache<String>(
        maxSize: 10,
        prepareOnSighting: 2,
        onEvict: (_) {},
      );
      expect(cache.shouldPrepare('a'), isFalse);
      expect(cache.shouldPrepare('b'), isFalse);
      expect(cache.shouldPrepare('a'), isTrue);
      expect(cache.shouldPrepare('b'), isTrue);

      // Forgotten once it returned `true`: counted again from the start.
      expect(cache.shouldPrepare('a'), isFalse);
    });

    test('the sightings are bounded (the oldest forgotten)', () {
      var cache = PreparedStatementsCache<String>(
        maxSize: 2,
        prepareOnSighting: 2,
        onEvict: (_) {},
      );
      // Up to `maxSize * 4` (8) sightings: `s0` is forgotten by the 9th.
      for (var i = 0; i < 9; ++i) {
        expect(cache.shouldPrepare('s$i'), isFalse);
      }
      expect(cache.shouldPrepare('s0'), isFalse);
      expect(cache.shouldPrepare('s8'), isTrue);
    });

    test('get, put and the least recently used evicted', () {
      var evicted = <String>[];
      var info = PreparedStatementsInfo();
      var cache = PreparedStatementsCache<String>(
        maxSize: 2,
        onEvict: evicted.add,
        info: info,
      );

      expect(cache.get('a'), isNull);
      cache.put('a', 'A');
      cache.put('b', 'B');
      expect(cache.length, equals(2));

      // `a` used: `b` is the least recently used.
      expect(cache.get('a'), equals('A'));
      cache.put('c', 'C');

      expect(evicted, equals(['B']));
      expect(cache.contains('a'), isTrue);
      expect(cache.contains('b'), isFalse);
      expect(cache.contains('c'), isTrue);

      expect(info.prepared, equals(3));
      expect(info.hits, equals(1));
      expect(info.evicted, equals(1));
    });

    test('put over a cached statement releases the previous one', () {
      var evicted = <String>[];
      var cache = PreparedStatementsCache<String>(
        maxSize: 5,
        onEvict: evicted.add,
      );
      cache.put('a', 'A1');
      cache.put('a', 'A2');
      expect(evicted, equals(['A1']));
      expect(cache.get('a'), equals('A2'));
      expect(cache.length, equals(1));
    });

    test('removeStale and clear', () {
      var evicted = <String>[];
      var info = PreparedStatementsInfo();
      var cache = PreparedStatementsCache<String>(
        maxSize: 5,
        onEvict: evicted.add,
        info: info,
      );
      cache.put('a', 'A');
      cache.put('b', 'B');
      cache.put('c', 'C');

      cache.removeStale('b');
      cache.removeStale('x'); // Not cached: nothing.
      expect(evicted, equals(['B']));
      expect(info.stale, equals(1));

      cache.clear();
      expect(evicted, equals(['B', 'A', 'C']));
      expect(cache.length, equals(0));
      expect(info.toString(), contains('stale: 1'));
    });

    test('invalid sizes', () {
      expect(
        () => PreparedStatementsCache<String>(maxSize: 0, onEvict: (_) {}),
        throwsArgumentError,
      );
      expect(
        () => PreparedStatementsCache<String>(
          maxSize: 1,
          prepareOnSighting: 0,
          onEvict: (_) {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('DBSQLAdapter.parseConfigPreparedStatements', () {
    test('defaults and keys', () {
      var d = DBSQLAdapter.parseConfigPreparedStatements(null);
      expect(d.enabled, isTrue);
      expect(
        d.cacheSize,
        equals(DBSQLAdapter.defaultPreparedStatementsCacheSize),
      );

      var c = DBSQLAdapter.parseConfigPreparedStatements({
        'preparedStatements': false,
        'preparedStatementsCacheSize': 20,
      });
      expect(c.enabled, isFalse);
      expect(c.cacheSize, equals(20));

      var c2 = DBSQLAdapter.parseConfigPreparedStatements({
        'prepared_statements': 'false',
        'prepared-statements-cache-size': 0,
      });
      expect(c2.enabled, isFalse);
      // An invalid size: the default.
      expect(
        c2.cacheSize,
        equals(DBSQLAdapter.defaultPreparedStatementsCacheSize),
      );
    });

    test('adapters from config', () {
      var sqlite = DBSQLiteAdapter.fromConfig({
        'memory': true,
        'preparedStatements': false,
      });
      expect(sqlite.preparedStatements, isFalse);
      expect(sqlite.preparedStatementsInfo, isNull);

      var sqlite2 = DBSQLiteAdapter.fromConfig({
        'memory': true,
        'preparedStatementsCacheSize': 7,
      });
      expect(sqlite2.preparedStatements, isTrue);
      expect(sqlite2.preparedStatementsCacheSize, equals(7));
      expect(sqlite2.preparedStatementsInfo, isNotNull);
    });
  });
}

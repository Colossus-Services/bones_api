import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_mixin.dart';
import 'package:test/test.dart';

void main() {
  group('FieldsFromMap', () {
    setUp(() {});

    test('getFieldValueFromMap', () async {
      var fieldsTest = _FieldsTest();

      var map = {
        'country_code': 'US',
        'city': 'New York',
        'stateOrProvince': 'NY'
      };

      expect(
          fieldsTest.getFieldValueFromMap('country_code', map), equals('US'));
      expect(fieldsTest.getFieldValueFromMap('countrycode', map), equals('US'));
      expect(fieldsTest.getFieldValueFromMap('countryCode', map), equals('US'));
      expect(
          fieldsTest.getFieldValueFromMap('countryCode_', map), equals('US'));

      expect(fieldsTest.getFieldValueFromMap('city', map), equals('New York'));
      expect(fieldsTest.getFieldValueFromMap('City', map), equals('New York'));
      expect(fieldsTest.getFieldValueFromMap('City_', map), equals('New York'));

      expect(fieldsTest.getFieldValueFromMap('stateOrProvince', map),
          equals('NY'));
      expect(fieldsTest.getFieldValueFromMap('state_Or_Province', map),
          equals('NY'));
      expect(fieldsTest.getFieldValueFromMap('stateorprovince', map),
          equals('NY'));
    });

    test('getFieldValueFromMap', () async {
      var fieldsTest = _FieldsTest();

      var fieldsNames = ['country_code', 'city', 'state_or_province'];
      var fieldsNamesIndexes = fieldsTest.buildFieldsNamesIndexes(fieldsNames);
      var fieldsNamesLC = fieldsTest.buildFieldsNamesLC(fieldsNames);
      var fieldsNamesSimple = fieldsTest.buildFieldsNamesSimple(fieldsNames);

      expect(
          fieldsTest.getFieldsValuesFromMap(
              fieldsNames,
              {
                'country_code': 'US',
                'city': 'New York',
                'stateOrProvince': 'NY'
              },
              fieldsNamesIndexes: fieldsNamesIndexes,
              fieldsNamesLC: fieldsNamesLC,
              fieldsNamesSimple: fieldsNamesSimple),
          equals({
            'country_code': 'US',
            'city': 'New York',
            'state_or_province': 'NY'
          }));

      expect(
          fieldsTest.getFieldsValuesFromMap(
              fieldsNames,
              {
                'countrycode': 'US',
                'City': 'New York',
                'stateOrProvince': 'NY'
              },
              fieldsNamesIndexes: fieldsNamesIndexes,
              fieldsNamesLC: fieldsNamesLC,
              fieldsNamesSimple: fieldsNamesSimple),
          equals({
            'country_code': 'US',
            'city': 'New York',
            'state_or_province': 'NY'
          }));

      expect(
          fieldsTest.getFieldsValuesFromMap(
              fieldsNames,
              {
                'countryCode': 'US',
                'City': 'New York',
                'state_Or_Province': 'NY'
              },
              fieldsNamesIndexes: fieldsNamesIndexes,
              fieldsNamesLC: fieldsNamesLC,
              fieldsNamesSimple: fieldsNamesSimple),
          equals({
            'country_code': 'US',
            'city': 'New York',
            'state_or_province': 'NY'
          }));
    });
  });

  group('Pool', () {
    setUp(() {});

    test('basic', () async {
      var pool = _PoolTest(3);

      expect(pool.poolSize, equals(0));
      expect(pool.isPoolEmpty, isTrue);
      expect(pool.isPoolNotEmpty, isFalse);

      {
        var e = await pool.catchFromPool();
        expect(pool.poolSize, equals(0));
        e.status += 'a';
        expect(e.status, equals('a'));
        pool.releaseIntoPool(e);

        expect(pool.poolSize, equals(1));
        expect(pool.isPoolEmpty, isFalse);
        expect(pool.isPoolNotEmpty, isTrue);
      }

      {
        var e = await pool.catchFromPool();
        e.status += 'b';
        expect(e.status, equals('ab'));
        pool.releaseIntoPool(e);
      }

      {
        expect(pool.poolSize, equals(1));
        var e1 = await pool.catchFromPool();
        expect(pool.poolSize, equals(0));
        var e2 = await pool.catchFromPool();
        expect(pool.poolSize, equals(0));

        e1.status += 'c';
        e2.status += 'c';

        expect(e1.status, equals('abc'));
        expect(e2.status, equals('c'));

        pool.releaseIntoPool(e1);
        expect(pool.poolSize, equals(1));
        pool.releaseIntoPool(e2);
        expect(pool.poolSize, equals(2));
      }

      {
        expect(pool.poolSize, equals(2));
        var e1 = await pool.catchFromPool();
        expect(pool.poolSize, equals(1));
        var e2 = await pool.catchFromPool();
        expect(pool.poolSize, equals(0));

        e1.close();
        pool.releaseIntoPool(e1);
        expect(pool.poolSize, equals(0));
        pool.releaseIntoPool(e2);
        expect(pool.poolSize, equals(1));
      }

      {
        expect(pool.poolSize, equals(1));
        var e1 = await pool.catchFromPool();
        expect(pool.poolSize, equals(0));
        var e2 = await pool.catchFromPool();
        expect(pool.poolSize, equals(0));

        pool.releaseIntoPool(e1);
        expect(pool.poolSize, equals(1));
        pool.releaseIntoPool(e2);
        expect(pool.poolSize, equals(2));

        e2.close();

        pool.checkPool();
        expect(pool.poolSize, equals(1));
      }
    });
  });
}

class _FieldsTest with FieldsFromMap {}

class _PoolTest with Pool<_PoolElement> {
  final int sizeLimit;

  _PoolTest(this.sizeLimit);

  int _idCount = 0;

  @override
  FutureOr<_PoolElement> createPoolElement({bool force = false}) {
    super.createPoolElement(force: force);
    return _PoolElement(++_idCount);
  }

  @override
  FutureOr<bool> isPoolElementValid(_PoolElement o) {
    return !o.isClosed;
  }

  @override
  int get poolSizeDesiredLimit => sizeLimit;
}

class _PoolElement {
  final int id;

  _PoolElement(this.id);

  bool _closed = false;

  bool get isClosed => _closed;

  void close() => _closed = true;

  String status = '';

  @override
  String toString() {
    return '_PoolElement[#$id]{closed: $_closed, status: <$status>}';
  }
}

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_logging.dart';
import 'package:statistics/statistics.dart'
    show Decimal, DecimalOnDoubleExtension;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

class Foo {
  int id;

  String name;

  Foo(this.id, this.name);

  @override
  String toString() {
    return '#$id[$name]';
  }
}

void main() {
  logToConsole();

  group('StringUtils', () {
    test('toLowerCaseSimple, toLowerCaseUnderscore', () async {
      expect(StringUtils.toLowerCase('someCamel-Case+Name'),
          equals('somecamel-case+name'));

      expect(StringUtils.toLowerCaseSimple('someCamel-Case+Name'),
          equals('somecamelcasename'));

      expect(StringUtils.toLowerCaseUnderscore('someCamelCaseName'),
          equals('some_camel_case_name'));

      expect(StringUtils.toLowerCaseUnderscore('someCamel-caseName'),
          equals('some_camel-case_name'));
      expect(
          StringUtils.toLowerCaseUnderscore('someCamel-caseName', simple: true),
          equals('some_camel_case_name'));

      expect(StringUtils.toLowerCaseUnderscore('_someCamelCaseName'),
          equals('_some_camel_case_name'));

      expect(StringUtils.toLowerCaseUnderscore('someCamel_CaseName'),
          equals('some_camel_case_name'));
      expect(StringUtils.toLowerCaseUnderscore('_someCamel_CaseName'),
          equals('_some_camel_case_name'));
    });

    test('getHeadEquality', () async {
      expect(StringUtils.endsWithPattern('abx_xyz', 'z'), isTrue);
      expect(StringUtils.endsWithPattern('abx_xyz', 'a'), isFalse);

      var re = RegExp(r'[yz]');
      expect(StringUtils.endsWithPattern('abx_xz', re), isTrue);
      expect(StringUtils.endsWithPattern('abx_xy', re), isTrue);
      expect(StringUtils.endsWithPattern('abx_xa', re), isFalse);
      expect(StringUtils.endsWithPattern('abz_', re), isFalse);
    });

    test('getHeadEquality', () async {
      expect(
          StringUtils.getHeadEquality(['abc_xyz', 'abc_123']), equals('abc_'));
      expect(StringUtils.getHeadEquality(['abc_xyz1', 'abc_xyz2', 'abc_123']),
          equals('abc_'));

      expect(StringUtils.getHeadEquality(['abc_xyz1', 'abc_xyz2', 'abc_xyz3']),
          equals('abc_xyz'));
      expect(
          StringUtils.getHeadEquality(['abc_xyz1', 'abc_xyz2', 'abc_xyz3'],
              delimiter: '_'),
          equals('abc_'));

      expect(
          StringUtils.getHeadEquality(['abc_xyz1', 'abc_xyz2', 'abc_xyz3'],
              validator: (s) => !s.contains('y')),
          equals('abc_x'));
      expect(
          StringUtils.getHeadEquality(['abc_xyz1', 'abc_xyz2', 'abc_xyz3'],
              validator: (s) => !s.contains('y'), delimiter: '_'),
          equals('abc_'));
    });

    test('getTailEquality', () async {
      expect(
          StringUtils.getTailEquality(['abc_xyz', '123_xyz']), equals('_xyz'));
      expect(StringUtils.getTailEquality(['1abc_xyz', '2abc_xyz', '123_xyz']),
          equals('_xyz'));

      expect(StringUtils.getTailEquality(['1abc_xyz', '2abc_xyz', '3abc_xyz']),
          equals('abc_xyz'));
      expect(
          StringUtils.getTailEquality(['1abc_xyz', '2abc_xyz', '3abc_xyz'],
              delimiter: '_'),
          equals('_xyz'));

      expect(
          StringUtils.getTailEquality(['1abc_xyz', '2abc_xyz', '3abc_xyz'],
              validator: (s) => !s.contains('b')),
          equals('c_xyz'));
      expect(
          StringUtils.getTailEquality(['1abc_xyz', '2abc_xyz', '3abc_xyz'],
              validator: (s) => !s.contains('b'), delimiter: '_'),
          equals('_xyz'));
    });

    test('trimEqualitiesMap', () async {
      expect(
          StringUtils.trimEqualitiesMap(['item_abc', 'item_klm', 'item_xyz']),
          equals({'item_abc': 'abc', 'item_klm': 'klm', 'item_xyz': 'xyz'}));

      expect(
          StringUtils.trimEqualitiesMap(
              ['item_abc_id', 'item_klm_id', 'item_xyz_id']),
          equals({
            'item_abc_id': 'abc',
            'item_klm_id': 'klm',
            'item_xyz_id': 'xyz'
          }));

      expect(
          StringUtils.trimEqualitiesMap(
              ['item_abc_1k_id', 'item_klm_2k_id', 'item_xyz_3k_id']),
          equals({
            'item_abc_1k_id': 'abc_1',
            'item_klm_2k_id': 'klm_2',
            'item_xyz_3k_id': 'xyz_3'
          }));

      expect(
          StringUtils.trimEqualitiesMap(
              ['item_abc_1k_id', 'item_klm_2k_id', 'item_xyz_3k_id'],
              delimiter: '_'),
          equals({
            'item_abc_1k_id': 'abc_1k',
            'item_klm_2k_id': 'klm_2k',
            'item_xyz_3k_id': 'xyz_3k'
          }));

      expect(StringUtils.trimEqualitiesMap(['item_abc_id', 'item_abc_xyz_id']),
          equals({'item_abc_id': 'i', 'item_abc_xyz_id': 'xyz_i'}));

      expect(
          StringUtils.trimEqualitiesMap(['item_abc_id', 'item_abc_xyz_id'],
              validator: (s) => !s.contains('abc')),
          equals({'item_abc_id': 'c', 'item_abc_xyz_id': 'c_xyz'}));

      expect(StringUtils.trimEqualitiesMap(['item_xyz_id', 'item_abc_xyz_id']),
          equals({'item_xyz_id': 'x', 'item_abc_xyz_id': 'abc_x'}));

      expect(
          StringUtils.trimEqualitiesMap(['item_xyz_id', 'item_abc_xyz_id'],
              delimiter: '_', validator: (s) => !s.contains('xyz')),
          equals({'item_xyz_id': 'xyz', 'item_abc_xyz_id': 'abc_xyz'}));
    });
  });

  group('Json', () {
    test('toJson', () async {
      expect(Json.toJson(123), equals(123));
      expect(Json.toJson(DateTime.utc(2021, 1, 2, 3, 4, 5)),
          equals('2021-01-02 03:04:05.000Z'));

      expect(
          Json.toJson({'a': 1, 'b': 2, 'p': 123}, removeField: (k) => k == 'p'),
          equals({'a': 1, 'b': 2}));

      expect(
          Json.toJson({'a': 1, 'b': 2, 'p': 123}, maskField: (k) => k == 'p'),
          equals({'a': 1, 'b': 2, 'p': '***'}));

      expect(Json.toJson({'a': 1, 'b': 2, 'foo': Foo(51, 'x')}),
          equals({'a': 1, 'b': 2, 'foo': '#51[x]'}));

      expect(
          Json.toJson({'a': 1, 'b': 2, 'foo': Foo(51, 'x')}, toEncodable: (o) {
            return o is Foo ? '${o.id}:${o.name}' : o;
          }),
          equals({'a': 1, 'b': 2, 'foo': '51:x'}));

      expect(Json.toJson(Role(RoleType.unknown)),
          equals({'type': 'unknown', 'enabled': true, 'value': null}));

      roleEntityHandler.toString();

      expect(
          Json.toJson(Role(RoleType.admin), removeField: (k) => k == 'enabled'),
          equals({'id': null, 'type': 'admin', 'value': null}));

      expect(
          Json.toJson(
              Role(RoleType.guest,
                  enabled: false, value: Decimal.parse('456.789')),
              removeNullFields: true),
          equals({'type': 'guest', 'enabled': false, 'value': '456.789'}));
    });

    test('fromJson', () async {
      Role$reflection.boot();

      {
        var json = Json.toJson(Role(RoleType.guest, enabled: false));

        expect(Json.fromJson<Role>(json),
            equals(Role(RoleType.guest, enabled: false)));
      }

      {
        var json = Json.toJson(Role(RoleType.admin));

        expect(Json.fromJson<Role>(json),
            equals(Role(RoleType.admin, enabled: true)));
      }
    });

    test('fromJson + id ref', () async {
      User$reflection.boot();
      Address$reflection.boot();
      Role$reflection.boot();

      {
        var creationTime = DateTime.utc(2022, 1, 2);
        var address = Address('CA', 'LA', 'one', 101, id: 1101);
        var role1 = Role(RoleType.guest,
            enabled: true, value: 10.20.toDecimal(), id: 10);
        var role2 = Role(RoleType.admin,
            enabled: true, value: 101.10.toDecimal(), id: 101);
        var user = User('joe@mail.com', '123', address, [role1, role2],
            id: 1001, creationTime: creationTime);

        var json = Json.toJson(user);

        print(json);

        var entityCache = JsonEntityCacheSimple();

        var user2 = Json.fromJson<User>(json, entityCache: entityCache);

        expect(user2?.toJsonEncoded(), equals(user.toJsonEncoded()));

        var jsonRoles = json['roles'] as List;

        expect(jsonRoles.length, equals(2));
        expect(jsonRoles[0]['id'], equals(10));
        expect(jsonRoles[1]['id'], equals(101));

        jsonRoles.add(10);

        var user3 = Json.fromJson<User>(json, entityCache: entityCache);

        expect(user3, isA<User>());
        expect(user3!.id, equals(1001));
      }
    });

    test('encode', () async {
      expect(Json.encode({'a': 1, 'b': 2}), equals('{"a":1,"b":2}'));

      expect(
          Json.encode({'a': 1, 'b': 2}, pretty: true),
          equals('{\n'
              '  "a": 1,\n'
              '  "b": 2\n'
              '}'));

      expect(
          Json.encode({'a': 1, 'pass': 123456},
              maskField: (f) => f.contains('pass')),
          equals('{"a":1,"pass":"***"}'));

      expect(
          Json.encode({'a': 1, 'pass': 123456},
              maskField: (f) => f.contains('pass'), maskText: 'x'),
          equals('{"a":1,"pass":"x"}'));
    });

    test('decode', () async {
      expect(Json.decode('{"a":1,"b":2}'), equals({'a': 1, 'b': 2}));

      expect(
          Json.decode('{"ab": {"a":1,"b":2}}', jsomMapDecoder: (map, j) {
            return map.map((k, v) {
              switch (k) {
                case 'ab':
                  return MapEntry(k, AB.fromMap(v as Map<String, dynamic>));
                default:
                  return MapEntry(k, v);
              }
            });
          }),
          equals({'ab': AB(1, 2)}));
    });

    test('decodeFromBytes', () async {
      Role$reflection.boot();

      {
        var jsonBytes =
            Json.encodeToBytes(Role(RoleType.guest, enabled: false));

        expect(Json.decodeFromBytes<Role>(jsonBytes),
            equals(Role(RoleType.guest, enabled: false)));
      }

      {
        var jsonBytes = Json.encodeToBytes(Role(RoleType.admin));

        expect(Json.decodeFromBytes<Role>(jsonBytes),
            equals(Role(RoleType.admin, enabled: true)));
      }
    });
  });

  group('TypeParser', () {
    test('parseInt', () async {
      expect(TypeParser.parseInt(10), equals(10));
      expect(TypeParser.parseInt('11'), equals(11));
      expect(TypeParser.parseInt(' 12 '), equals(12));
      expect(TypeParser.parseInt(' -12 '), equals(-12));
      expect(TypeParser.parseInt(13.1), equals(13));
      expect(TypeParser.parseInt(" '123' "), equals(123));
      expect(TypeParser.parseInt(" '-123' "), equals(-123));
      expect(TypeParser.parseInt(' -1.2345e3 '), equals(-1234));
      expect(TypeParser.parseInt(' 123,456.78 '), equals(123456));
      expect(TypeParser.parseInt(' -123,456.78 '), equals(-123456));
      expect(TypeParser.parseInt(' "123,456.78 " '), equals(123456));
      expect(TypeParser.parseInt(' "-123,456.78 " '), equals(-123456));
      expect(TypeParser.parseInt(DateTime.utc(2020, 1, 2, 3, 4, 5, 0, 0)),
          equals(1577934245000));
      expect(TypeParser.parseInt(null, 404), equals(404));
      expect(TypeParser.parseInt('', 404), equals(404));
      expect(TypeParser.parseInt(' x ', 404), equals(404));
      expect(TypeParser.parseInt(null), isNull);
    });

    test('parseDouble', () async {
      expect(TypeParser.parseDouble(10), equals(10));
      expect(TypeParser.parseDouble(10.11), equals(10.11));
      expect(TypeParser.parseDouble('11'), equals(11.0));
      expect(TypeParser.parseDouble(' 12 '), equals(12.0));
      expect(TypeParser.parseDouble(' -12 '), equals(-12.0));
      expect(TypeParser.parseDouble(13.1), equals(13.1));
      expect(TypeParser.parseDouble(" '123' "), equals(123.0));
      expect(TypeParser.parseDouble(" '-123' "), equals(-123.0));
      expect(TypeParser.parseDouble(" '123.4' "), equals(123.4));
      expect(TypeParser.parseDouble(" '-123.4' "), equals(-123.4));
      expect(TypeParser.parseDouble('    -1.2345e3 '), equals(-1234.5));
      expect(TypeParser.parseDouble('   " 1.2345e3 "'), equals(1234.5));
      expect(TypeParser.parseDouble('   " -1.2345e3 "'), equals(-1234.5));
      expect(TypeParser.parseDouble(' 123,456.78 '), equals(123456.78));
      expect(TypeParser.parseDouble(' -123,456.78 '), equals(-123456.78));
      expect(TypeParser.parseDouble(' "123,456.78 " '), equals(123456.78));
      expect(TypeParser.parseDouble(' "-123,456.78 " '), equals(-123456.78));
      expect(TypeParser.parseDouble(DateTime.utc(2020, 1, 2, 3, 4, 5, 0, 0)),
          equals(1577934245000));
      expect(TypeParser.parseDouble(null, 404), equals(404));
      expect(TypeParser.parseDouble('', 404), equals(404));
      expect(TypeParser.parseDouble(' x ', 404), equals(404));
      expect(TypeParser.parseDouble(null), isNull);
    });

    test('parseNum', () async {
      expect(TypeParser.parseNum(10), equals(10));
      expect(TypeParser.parseNum(10.11), equals(10.11));
      expect(TypeParser.parseNum('11'), equals(11.0));
      expect(TypeParser.parseNum(' 12 '), equals(12));
      expect(TypeParser.parseNum(' -12 '), equals(-12));
      expect(TypeParser.parseNum(13.1), equals(13.1));
      expect(TypeParser.parseNum(" '123' "), equals(123));
      expect(TypeParser.parseNum(" '-123' "), equals(-123));
      expect(TypeParser.parseNum(" '123.4' "), equals(123.4));
      expect(TypeParser.parseNum(" '-123.4' "), equals(-123.4));
      expect(TypeParser.parseNum('    -1.2345e3 '), equals(-1234.5));
      expect(TypeParser.parseNum('   " 1.2345e3 "'), equals(1234.5));
      expect(TypeParser.parseNum('   " -1.2345e3 "'), equals(-1234.5));
      expect(TypeParser.parseNum(' 123,456.78 '), equals(123456.78));
      expect(TypeParser.parseNum(' -123,456.78 '), equals(-123456.78));
      expect(TypeParser.parseNum(' "123,456.78 " '), equals(123456.78));
      expect(TypeParser.parseNum(' "-123,456.78 " '), equals(-123456.78));
      expect(TypeParser.parseNum(DateTime.utc(2020, 1, 2, 3, 4, 5, 0, 0)),
          equals(1577934245000));
      expect(TypeParser.parseNum(null, 404), equals(404));
      expect(TypeParser.parseNum('', 404), equals(404));
      expect(TypeParser.parseNum(' x ', 404), equals(404));
      expect(TypeParser.parseNum(null), isNull);
    });

    test('parseBool', () async {
      expect(TypeParser.parseBool(true), isTrue);
      expect(TypeParser.parseBool(false), isFalse);

      expect(TypeParser.parseBool(1), isTrue);
      expect(TypeParser.parseBool(0), isFalse);
      expect(TypeParser.parseBool(-1), isFalse);

      expect(TypeParser.parseBool(' x ', true), isTrue);
      expect(TypeParser.parseBool(' x ', false), isFalse);

      expect(TypeParser.parseBool('null', true), isTrue);
      expect(TypeParser.parseBool('null', false), isFalse);

      expect(TypeParser.parseBool('1'), isTrue);
      expect(TypeParser.parseBool('0'), isFalse);
      expect(TypeParser.parseBool('-1'), isFalse);

      expect(TypeParser.parseBool('true'), isTrue);
      expect(TypeParser.parseBool('t'), isTrue);
      expect(TypeParser.parseBool('yes'), isTrue);
      expect(TypeParser.parseBool('ok'), isTrue);

      expect(TypeParser.parseBool('false'), isFalse);
      expect(TypeParser.parseBool('f'), isFalse);
      expect(TypeParser.parseBool('no'), isFalse);
      expect(TypeParser.parseBool('fail'), isFalse);
      expect(TypeParser.parseBool('error'), isFalse);
    });

    test('parserFor', () async {
      expect(TypeParser.parserFor<int>()!('123'), isA<int>());
      expect(TypeParser.parserFor<double>()!('123,4'), isA<double>());
      expect(TypeParser.parserFor<num>()!('123,4'), isA<num>());
      expect(TypeParser.parserFor<bool>()!('true'), isA<bool>());
      expect(TypeParser.parserFor<String>()!('x'), isA<String>());
      expect(TypeParser.parserFor<Map>()!('a:1'), isA<Map>());
      expect(TypeParser.parserFor<Set>()!('1,2'), isA<Set>());
      expect(TypeParser.parserFor<List>()!('1,2'), isA<List>());
      expect(TypeParser.parserFor<Iterable>()!('1,2'), isA<List>());

      expect(TypeParser.parserFor(type: int)!('123'), isA<int>());
      expect(TypeParser.parserFor(type: double)!('123,4'), isA<double>());
      expect(TypeParser.parserFor(type: num)!('123,4'), isA<num>());
      expect(TypeParser.parserFor(type: bool)!('t'), isA<bool>());
      expect(TypeParser.parserFor(type: String)!('x'), isA<String>());
      expect(TypeParser.parserFor(type: Map)!('a:1'), isA<Map>());
      expect(TypeParser.parserFor(type: Set)!('1,2'), isA<Set>());
      expect(TypeParser.parserFor(type: List)!('1,2'), isA<List>());
      expect(TypeParser.parserFor(type: Iterable)!('1,2'), isA<Iterable>());

      expect(TypeParser.parserFor(obj: 123)!('123'), isA<int>());
      expect(TypeParser.parserFor(obj: 123.4)!('123,4'), isA<double>());
      expect(TypeParser.parserFor(obj: 123)!('123,4'), isA<num>());
      expect(TypeParser.parserFor(obj: true)!('123,4'), isA<bool>());
      expect(TypeParser.parserFor(obj: 'x')!('x'), isA<String>());
      expect(TypeParser.parserFor(obj: {'a': 1})!('a:1'), isA<Map>());
      expect(TypeParser.parserFor(obj: {1, 2})!('1,2'), isA<Set>());
      expect(TypeParser.parserFor(obj: [1, 2])!('1,2'), isA<List>());
      expect(TypeParser.parserFor(obj: [1, 2].map((e) => e))!('1,2'),
          isA<Iterable>());
    });

    test('parseList', () async {
      expect(TypeParser.parseList([1, 2, 3]), equals([1, 2, 3]));
      expect(TypeParser.parseList('1,2,3'), equals(['1', '2', '3']));
      expect(TypeParser.parseList('1,2,3', elementParser: TypeParser.parseInt),
          equals([1, 2, 3]));
      expect(TypeParser.parseList<int>('1,2,3'), equals([1, 2, 3]));
    });

    test('parseSet', () async {
      expect(TypeParser.parseSet([1, 2, 3]), equals({1, 2, 3}));
      expect(TypeParser.parseSet('1,2,3'), equals({'1', '2', '3'}));
      expect(TypeParser.parseSet('1,2,3', elementParser: TypeParser.parseInt),
          equals({1, 2, 3}));
      expect(TypeParser.parseSet<int>('1,2,3'), equals({1, 2, 3}));
    });

    test('parseMap', () async {
      expect(TypeParser.parseMap({'a': 1, 'b': 2}), equals({'a': 1, 'b': 2}));
      expect(TypeParser.parseMap('a:1&b:2'), equals({'a': '1', 'b': '2'}));
      expect(
          TypeParser.parseMap('a:1&b:2',
              keyParser: TypeParser.parseString,
              valueParser: TypeParser.parseInt),
          equals({'a': 1, 'b': 2}));
      expect(TypeParser.parseMap<String, int>('a:1&b:2'),
          equals({'a': 1, 'b': 2}));
    });
  });

  group('TimedMap', () {
    test('basic', () async {
      var m = TimedMap<String, int>(Duration(seconds: 1), {'a': 1, 'b': 2});

      expect(m.isEmpty, isFalse);
      expect(m.isNotEmpty, isTrue);
      expect(m.length, equals(2));
      expect(m.keys, equals(['a', 'b']));

      expect(m['a'], equals(1));
      expect(m['b'], equals(2));

      expect(m.cast<String, num>().toString(), equals('{a: 1, b: 2}'));

      m['a'] = 10;
      expect(m['a'], equals(10));

      m.update('b', (v) => v * 2);
      m.updateTimed('c', (v) => v * 2, ifAbsent: () => 3);

      m.putIfAbsent('b', () => 200);
      m.putIfAbsentChecked('c', () => 300);

      expect(m.toString(), equals('{a: 10, b: 4, c: 3}'));

      m.updateAll((key, value) => value * 2);

      expect(m.toString(), equals('{a: 20, b: 8, c: 6}'));

      m.removeWhere((key, value) => value > 10);

      expect(m.toString(), equals('{b: 8, c: 6}'));

      m.clear();
      expect(m.isEmpty, isTrue);
      expect(m.keys, equals([]));

      await m.putIfAbsentCheckedAsync('d', () => Future.value(4));
      expect(m.keys, equals(['d']));
    });

    test('timed', () async {
      var m = TimedMap<String, int>(Duration(seconds: 1));

      expect(m.isEmpty, isTrue);
      expect(m.isNotEmpty, isFalse);
      expect(m.length, equals(0));

      expect(m.keys, equals([]));
      expect(m.values, equals([]));
      expect(m.entries, equals([]));

      m.addAll({'a': 1, 'b': 2});

      expect(m.isEmpty, isFalse);
      expect(m.isNotEmpty, isTrue);
      expect(m.length, equals(2));

      expect(m.keys, equals(['a', 'b']));
      expect(m.values, equals([1, 2]));
      expect(m.entries.map((e) => e.key), equals(['a', 'b']));
      expect(m.entries.map((e) => e.value), equals([1, 2]));

      expect(m.keysChecked(), equals(['a', 'b']));
      expect(m.valuesChecked(), equals([1, 2]));
      expect(m.entriesChecked().map((e) => e.key), equals(['a', 'b']));
      expect(m.entriesChecked().map((e) => e.value), equals([1, 2]));

      expect(m['a'], equals(1));
      expect(m['b'], equals(2));

      expect(m.containsKey('a'), isTrue);
      expect(m.containsKey('b'), isTrue);
      expect(m.containsKey('c'), isFalse);

      expect(m.containsValue(1), isTrue);
      expect(m.containsValue(2), isTrue);
      expect(m.containsValue(3), isFalse);

      expect(m.getChecked('a'), equals(1));
      expect(m.getChecked('b'), equals(2));
      expect(m.getChecked('c'), isNull);

      m.put('d', 4, now: DateTime.now().add(Duration(seconds: 1)));
      m.put('e', 5, now: DateTime.now().add(Duration(seconds: 2)));

      expect(m.getChecked('a'), equals(1));
      expect(m.getChecked('b'), equals(2));
      expect(m.getChecked('c'), isNull);
      expect(m.getChecked('d'), equals(4));
      expect(m.getChecked('e'), equals(5));
      expect(m.length, equals(4));

      await Future.delayed(Duration(milliseconds: 1100));

      expect(m.getElapsedTime('a')!.inMilliseconds > 1000, isTrue);

      expect(m.getChecked('a'), isNull);
      expect(m.getChecked('b'), isNull);
      expect(m.getChecked('c'), isNull);
      expect(m.getChecked('d'), equals(4));
      expect(m.getChecked('e'), equals(5));
      expect(m.length, equals(2));

      expect(m.remove('d'), equals(4));

      expect(m.getChecked('e'), equals(5));
      expect(m.length, equals(1));

      await Future.delayed(Duration(milliseconds: 2100));
      m.checkAllEntries();

      expect(m.length, equals(0));
    });
  });

  group('PositionalFields', () {
    test('basic', () async {
      var positionalFields = PositionalFields(['a', 'b', 'c']);

      expect(positionalFields.fields, equals(['a', 'b', 'c']));
      expect(positionalFields.fieldsOrder, equals(['a', 'b', 'c']));

      expect(positionalFields.getFieldIndex('a'), equals(0));
      expect(positionalFields.getFieldIndex('b'), equals(1));
      expect(positionalFields.getFieldIndex('c'), equals(2));

      expect(positionalFields.get('b', [1, 2, 3]), equals(2));

      expect(positionalFields.getMapEntry('b', [1, 2, 3])!.key, equals('b'));
      expect(positionalFields.getMapEntry('b', [1, 2, 3])!.value, equals(2));

      expect(
          positionalFields.toMap([1, 2, 3]), equals({'a': 1, 'b': 2, 'c': 3}));

      expect(
          positionalFields.toListOfMap([
            [1, 2, 3],
            [10, 20, 30]
          ]),
          equals([
            {'a': 1, 'b': 2, 'c': 3},
            {'a': 10, 'b': 20, 'c': 30}
          ]));
    });
  });

  group('InstanceTracker', () {
    test('basic', () async {
      var tracker = InstanceTracker<Map<String, Object>, List<Object>>(
          'test', (m) => m.values.toList());

      var m1 = {'a': 1, 'b': 2};
      var m2 = {'a': 2, 'b': 20};

      expect(tracker.isTrackedInstance(m1), isFalse);
      expect(tracker.isTrackedInstance(m2), isFalse);

      expect(tracker.trackInstance(m1), equals(m1));

      expect(tracker.isTrackedInstance(m1), isTrue);

      expect(tracker.getTrackedInstanceInfo(m1), equals(m1.values.toList()));
      expect(tracker.getTrackedInstanceInfo(m2), isNull);

      tracker.untrackInstance(m1);
      expect(tracker.isTrackedInstance(m1), isFalse);
      expect(tracker.isTrackedInstance(m2), isFalse);

      expect(tracker.getTrackedInstanceInfo(m1), isNull);
      expect(tracker.getTrackedInstanceInfo(m2), isNull);

      tracker.trackInstances([m1, m2]);
      expect(tracker.isTrackedInstance(m1), isTrue);
      expect(tracker.isTrackedInstance(m2), isTrue);

      expect(tracker.getTrackedInstanceInfo(m1), equals(m1.values.toList()));
      expect(tracker.getTrackedInstanceInfo(m2), equals(m2.values.toList()));

      tracker.untrackInstances([m1, m2]);
      expect(tracker.isTrackedInstance(m1), isFalse);
      expect(tracker.isTrackedInstance(m2), isFalse);
    });
  });

  group('tryCall', () {
    test('basic', () {
      expect(tryCall(() => 123), equals(123));

      expect(tryCall(() => null, defaultValue: 123), equals(123));

      expect(tryCall(() => 123, onSuccessValue: 456, onErrorValue: -456),
          equals(456));

      expect(
          tryCall(() => throw StateError('test'),
              onSuccessValue: 456, onErrorValue: -456),
          equals(-456));
    });
  });

  group('FieldNameMapper', () {
    test('map', () {
      var fm = FieldNameMapper();

      fm.setupKeys(['user', 'e-mail', 'business_account']);

      expect(fm.map('user'), equals('user'));
      expect(fm.map('User'), equals('user'));
      expect(fm.map('_user'), equals('user'));

      expect(fm.map('email'), equals('e-mail'));
      expect(fm.map('e-mail'), equals('e-mail'));
      expect(fm.map('EMail'), equals('e-mail'));
      expect(fm.map('E-Mail'), equals('e-mail'));

      expect(fm.map('business_account'), equals('business_account'));
      expect(fm.map('businessAccount'), equals('business_account'));
      expect(fm.map('business-account'), equals('business_account'));
    });

    test('unmap', () {
      var fm = FieldNameMapper();

      fm.setupKeys(['user', 'e-mail', 'business_account']);

      expect(fm.unmap('user'), equals('user'));
      expect(fm.unmap('User'), equals('user'));

      expect(fm.unmap('e-mail'), equals('email'));
      expect(fm.unmap('email'), isNull);

      expect(fm.unmap('business_account'), equals('businessaccount'));
      expect(fm.unmap('businessAccount'), isNull);
    });
  });

  group('tryCallMapped', () {
    test('sync', () {
      expect(tryCallMapped(() => 123), equals(123));

      expect(tryCallMapped(() => null, defaultValue: 123), equals(123));

      expect(tryCallMapped(() => 123, onSuccessValue: 456, onErrorValue: -456),
          equals(456));

      expect(
          tryCallMapped(() => throw StateError('test error'),
              onSuccessValue: 456, onErrorValue: -456),
          equals(-456));
    });

    test('async', () async {
      expect(await tryCallMapped(() => _asyncValue(123)), equals(123));

      expect(await tryCallMapped(() => _asyncValue(null), defaultValue: 123),
          equals(123));

      expect(
          await tryCallMapped(() => _asyncValue(123),
              onSuccessValue: 456, onErrorValue: -456),
          equals(456));

      expect(
          await tryCallMapped(() => _asyncValue(123),
              onSuccess: (v) => 456 * 2, onError: (e, s) => -456 * 2),
          equals(456 * 2));

      expect(
          await tryCallMapped(
              () => Future.delayed(Duration(milliseconds: 1),
                  () => throw StateError('test async error')),
              onSuccess: (v) => 456 * 2,
              onError: (e, s) => e.toString()),
          contains('test async error'));
    });
  });
}

Future<T> _asyncValue<T>(T value) =>
    Future.delayed(Duration(milliseconds: 1), () => value);

class AB {
  final int a;

  final int b;

  AB(this.a, this.b);

  AB.fromMap(Map<String, dynamic> o) : this(o['a'], o['b']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AB &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b;

  @override
  int get hashCode => a.hashCode ^ b.hashCode;

  @override
  String toString() => 'AB{a: $a, b: $b}';
}

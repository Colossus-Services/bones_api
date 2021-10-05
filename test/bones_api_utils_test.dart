import 'package:bones_api/src/bones_api_logging.dart';
import 'package:bones_api/src/bones_api_utils.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

final _log = logging.Logger('bones_api_test');

void main() {
  _log.handler.logToConsole();

  group('Utils', () {
    setUp(() {});

    test('Json.encode', () async {
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

    test('Json.decode', () async {
      expect(Json.decode('{"a":1,"b":2}'), equals({'a': 1, 'b': 2}));

      expect(
          Json.decode('{"ab": {"a":1,"b":2}}', reviver: (k, v) {
            switch (k) {
              case 'ab':
                return AB.fromMap(v as Map<String, dynamic>);
              default:
                return v;
            }
          }),
          equals({'ab': AB(1, 2)}));
    });

    test('TypeParser.parseInt', () async {
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

    test('TypeParser.parseDouble', () async {
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

    test('TypeParser.parseNum', () async {
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

    test('TypeParser.parseBool', () async {
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

    test('TypeParser.parserFor', () async {
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

    test('TypeParser.parseList', () async {
      expect(TypeParser.parseList([1, 2, 3]), equals([1, 2, 3]));
      expect(TypeParser.parseList('1,2,3'), equals(['1', '2', '3']));
      expect(TypeParser.parseList('1,2,3', elementParser: TypeParser.parseInt),
          equals([1, 2, 3]));
      expect(TypeParser.parseList<int>('1,2,3'), equals([1, 2, 3]));
    });

    test('TypeParser.parseSet', () async {
      expect(TypeParser.parseSet([1, 2, 3]), equals({1, 2, 3}));
      expect(TypeParser.parseSet('1,2,3'), equals({'1', '2', '3'}));
      expect(TypeParser.parseSet('1,2,3', elementParser: TypeParser.parseInt),
          equals({1, 2, 3}));
      expect(TypeParser.parseSet<int>('1,2,3'), equals({1, 2, 3}));
    });

    test('TypeParser.parseMap', () async {
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

  group('TimedMap', () {
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
}

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

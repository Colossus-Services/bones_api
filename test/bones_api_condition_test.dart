import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_condition_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Condition', () {
    setUp(() {});

    test('ConditionParameter', () async {
      expect(
          KeyConditionEQ(ConditionKey.parse('foo'), ConditionParameter())
              .encode(),
          equals('foo == ?'));

      expect(
          KeyConditionEQ(ConditionKey.parse('foo'), ConditionParameter.index(0))
              .encode(),
          equals('foo == ?#0'));

      expect(
          KeyConditionEQ(ConditionKey.parse('foo'), ConditionParameter.index(1))
              .encode(),
          equals('foo == ?#1'));

      expect(
          KeyConditionEQ(
                  ConditionKey.parse('foo'), ConditionParameter.key('xy'))
              .encode(),
          equals('foo == ?:xy'));
    });
  });

  group('ConditionParser', () {
    setUp(() {});

    test('key op value', () async {
      var conditionParser = ConditionParser();

      expect(conditionParser.parse(' foo == true ').toString(),
          equals('foo == true'));
      expect(conditionParser.parse(' foo != false ').toString(),
          equals('foo != false'));

      expect(conditionParser.parse(' foo.x == 123 ').toString(),
          equals('foo.x == 123'));

      expect(conditionParser.parse(' foo.x != 123 ').toString(),
          equals('foo.x != 123'));

      expect(conditionParser.parse(' "a:b" == false ').toString(),
          equals('"a:b" == false'));
      expect(conditionParser.parse(" 'a  b' == 'xyz' ").toString(),
          equals('"a  b" == "xyz"'));

      expect(conditionParser.parse(' k_1 == 234 ').toString(),
          equals('k_1 == 234'));

      expect(conditionParser.parse(' ( foo == 123 ) ').toString(),
          equals('foo == 123'));

      expect(conditionParser.parse(' ( foo != 123 ) ').toString(),
          equals('foo != 123'));

      expect(conditionParser.parse(' ( foo == [1 , 2] ) ').toString(),
          equals('foo == [1,2]'));

      expect(conditionParser.parse(' ( foo == {"a": 1 , "b": 2} ) ').toString(),
          equals('foo == {"a":1,"b":2}'));
    });

    test('group AND', () async {
      var conditionParser = ConditionParser();

      expect(conditionParser.parse(' foo == 123 && bar == false ').toString(),
          equals('( foo == 123 && bar == false )'));

      expect(conditionParser.parse(' (foo == 123 && bar == false) ').toString(),
          equals('( foo == 123 && bar == false )'));

      expect(
          conditionParser
              .parse(' ( (foo == 123) && (bar == 456) ) ')
              .toString(),
          equals('( foo == 123 && bar == 456 )'));

      expect(
          conditionParser
              .parse(' ( (foo == 123 && foo == 321) && (bar == 456) ) ')
              .toString(),
          equals('( ( foo == 123 && foo == 321 ) && bar == 456 )'));

      expect(
          conditionParser
              .parse(' (foo == 123 && foo == 321) && (bar == 456) ')
              .toString(),
          equals('( ( foo == 123 && foo == 321 ) && bar == 456 )'));

      expect(
          conditionParser
              .parse(' (foo == 123 && foo == 321) || bar == 456 ')
              .toString(),
          equals('( ( foo == 123 && foo == 321 ) || bar == 456 )'));
    });

    test('group OR', () async {
      var conditionParser = ConditionParser();

      expect(conditionParser.parse(' foo == 123 || bar == false ').toString(),
          equals('( foo == 123 || bar == false )'));

      expect(
          conditionParser
              .parse(' foo == 123 || ( bar == false || baz == 123 ) ')
              .toString(),
          equals('( foo == 123 || ( bar == false || baz == 123 ) )'));

      expect(conditionParser.parse('( foo == 123 || bar == false )').toString(),
          equals('( foo == 123 || bar == false )'));

      expect(
          conditionParser
              .parse(' ( (foo == 123) || (bar == 456) ) ')
              .toString(),
          equals('( foo == 123 || bar == 456 )'));

      expect(
          conditionParser
              .parse(' ( (foo == 123 || foo == 321) || (bar == 456) ) ')
              .toString(),
          equals('( ( foo == 123 || foo == 321 ) || bar == 456 )'));

      expect(
          conditionParser
              .parse(' (foo == 123 || foo == 321) || (bar == 456) ')
              .toString(),
          equals('( ( foo == 123 || foo == 321 ) || bar == 456 )'));

      expect(
          conditionParser
              .parse(' (foo == 123 || foo == 321) && bar == 456 ')
              .toString(),
          equals('( ( foo == 123 || foo == 321 ) && bar == 456 )'));
    });

    test('ConditionParameter single', () async {
      var conditionParser = ConditionParser();

      var c1 = conditionParser.parse(' foo == ? ');
      expect(c1.toString(), equals('foo == ?'));
      expect(c1.parameters.toString(), equals('[?]'));
      expect(c1.parameters.map((e) => e.contextPosition), equals([0]));
      expect(c1.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c1.parameters.map((e) => e.index), equals([null]));
      expect(c1.parameters.map((e) => e.key), equals([null]));

      var c2 = conditionParser.parse(' foo == ?#1 ');
      expect(c2.toString(), equals('foo == ?#1'));
      expect(c2.parameters.toString(), equals('[?#1]'));
      expect(c2.parameters.map((e) => e.contextPosition), equals([null]));
      expect(c2.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c2.parameters.map((e) => e.index), equals([1]));
      expect(c2.parameters.map((e) => e.key), equals([null]));

      var c3 = conditionParser.parse(' foo == ?#123 ');
      expect(c3.toString(), equals('foo == ?#123'));
      expect(c3.parameters.toString(), equals('[?#123]'));
      expect(c3.parameters.map((e) => e.contextPosition), equals([null]));
      expect(c3.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c3.parameters.map((e) => e.index), equals([123]));
      expect(c3.parameters.map((e) => e.key), equals([null]));

      var c4 = conditionParser.parse(' foo == ?:xyz ');
      expect(c4.toString(), equals('foo == ?:xyz'));
      expect(c4.parameters.toString(), equals('[?:xyz]'));
      expect(c4.parameters.map((e) => e.contextPosition), equals([null]));
      expect(c4.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c4.parameters.map((e) => e.index), equals([null]));
      expect(c4.parameters.map((e) => e.key), equals(['xyz']));

      var c5 = conditionParser.parse(' foo == ?# ');
      expect(c5.toString(), equals('foo == ?#'));
      expect(c5.parameters.toString(), equals('[?#]'));
      expect(c5.parameters.map((e) => e.contextPosition), equals([0]));
      expect(c5.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c5.parameters.map((e) => e.index), equals([-1]));
      expect(c5.parameters.map((e) => e.key), equals([null]));

      var c6 = conditionParser.parse(' foo == ?: ');
      expect(c6.toString(), equals('foo == ?:'));
      expect(c6.parameters.toString(), equals('[?:]'));
      expect(c6.parameters.map((e) => e.contextPosition), equals([null]));
      expect(c6.parameters.map((e) => e.contextKey), equals(['foo']));
      expect(c6.parameters.map((e) => e.index), equals([null]));
      expect(c6.parameters.map((e) => e.key), equals(['']));
    });

    test('ConditionParameter group', () async {
      var conditionParser = ConditionParser();

      var c5 = conditionParser.parse(' foo == ? || bar == ? ');
      expect(c5.toString(), equals('( foo == ? || bar == ? )'));
      expect(c5.parameters.toString(), equals('[?, ?]'));
      expect(c5.parameters.map((e) => e.contextPosition), equals([0, 1]));

      var c6 = conditionParser.parse(' foo == ? || ( bar == ? || baz == ? ) ');
      expect(c6.toString(), equals('( foo == ? || ( bar == ? || baz == ? ) )'));
      expect(c6.parameters.toString(), equals('[?, ?, ?]'));
      expect(c6.parameters.map((e) => e.contextPosition), equals([0, 1, 2]));

      var c7 =
          conditionParser.parse(' foo == ? || ( bar == ?:x || baz == ? ) ');
      expect(
          c7.toString(), equals('( foo == ? || ( bar == ?:x || baz == ? ) )'));
      expect(c7.parameters.toString(), equals('[?, ?:x, ?]'));
      expect(c7.parameters.map((e) => e.contextPosition), equals([0, null, 1]));
      expect(c7.parameters.map((e) => e.contextKey),
          equals(['foo', 'bar', 'baz']));
      expect(c7.parameters.map((e) => e.index), equals([null, null, null]));
      expect(c7.parameters.map((e) => e.key), equals([null, 'x', null]));

      var c8 =
          conditionParser.parse(' foo == ? || ( bar == ?#0 || baz == ? ) ');
      expect(
          c8.toString(), equals('( foo == ? || ( bar == ?#0 || baz == ? ) )'));
      expect(c8.parameters.toString(), equals('[?, ?#0, ?]'));
      expect(c8.parameters.map((e) => e.contextPosition), equals([0, null, 1]));
      expect(c8.parameters.map((e) => e.contextKey),
          equals(['foo', 'bar', 'baz']));
      expect(c8.parameters.map((e) => e.index), equals([null, 0, null]));
      expect(c8.parameters.map((e) => e.key), equals([null, null, null]));
    });
  });
}

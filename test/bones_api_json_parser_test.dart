import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('JsonParser', () {
    setUp(() {});

    test('normal', () async {
      var jsonParser = JsonParser();

      _testJson(jsonParser);
    });

    test('extended', () async {
      var jsonParser = JsonParser(extendedGrammar: true);

      expect(
        jsonParser.parse('{a: 1, b: 2, c: 3}'),
        equals({'a': 1, 'b': 2, 'c': 3}),
      );

      expect(
        jsonParser.parse('{ a : 1 , b : 2 , c : 3 }'),
        equals({'a': 1, 'b': 2, 'c': 3}),
      );

      _testJson(jsonParser);
      _testJson(jsonParser, quote: "'");
    });
  });
}

void _testJson(JsonParser jsonParser, {String quote = '"'}) {
  expect(jsonParser.parse('true'), equals(true));
  expect(jsonParser.parse(' true '), equals(true));
  expect(jsonParser.parse('false'), equals(false));
  expect(jsonParser.parse(' false '), equals(false));

  expect(jsonParser.parse('123'), equals(123));
  expect(jsonParser.parse(' 123 '), equals(123));

  expect(jsonParser.parse('1.2'), equals(1.2));
  expect(jsonParser.parse(' 1.2 '), equals(1.2));

  expect(jsonParser.parse('${quote}abc$quote'), equals('abc'));
  expect(jsonParser.parse(' ${quote}abc$quote '), equals('abc'));

  expect(jsonParser.parse('[1,2,3]'), equals([1, 2, 3]));
  expect(jsonParser.parse(' [ 1 , 2 , 3 ]'), equals([1, 2, 3]));

  expect(
    jsonParser.parse(
      '{${quote}a$quote: 1, ${quote}b$quote: 2, ${quote}c$quote: 3}',
    ),
    equals({'a': 1, 'b': 2, 'c': 3}),
  );

  expect(
    jsonParser.parse(
      '{ ${quote}a$quote : 1 , ${quote}b$quote : 2 , ${quote}c$quote : 3 }',
    ),
    equals({'a': 1, 'b': 2, 'c': 3}),
  );

  expect(
    jsonParser.parse(
      '{ ${quote}a$quote : [ 1 , 2] , ${quote}b$quote : [ 3 , 4 ] }',
    ),
    equals({
      'a': [1, 2],
      'b': [3, 4],
    }),
  );

  expect(
    jsonParser.parse(
      '[ { ${quote}a$quote: 1  , ${quote}b$quote: 2} , { ${quote}c$quote: 3  , ${quote}d$quote: 4} ]',
    ),
    equals([
      {'a': 1, 'b': 2},
      {'c': 3, 'd': 4},
    ]),
  );
}

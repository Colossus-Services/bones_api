@TestOn('vm')
import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('APIConfig', () {
    setUp(() {});

    test('resolveStringUri', () async {
      expect(APIConfig.resolveStringUri('api.conf'),
          allOf(isA<Uri>(), (Uri o) => o.path.endsWith('api.conf')));

      expect(APIConfig.resolveStringUri('./api.conf'),
          allOf(isA<Uri>(), (Uri o) => o.path.endsWith('/api.conf')));

      expect(APIConfig.resolveStringUri('/api.conf'),
          allOf(isA<Uri>(), (Uri o) => o.path == '/api.conf'));

      expect(APIConfig.resolveStringUri('/api\n.conf'), isNull);
    });

    test('fromContent', () async {
      var testDir = resolveTestDir();
      print('Test dir: $testDir');

      var jsonEncoded = '{"a": 1, "b": 2}';

      expect(APIConfig.fromContent(jsonEncoded)?.toJson(),
          equals({'a': 1, 'b': 2}));
      expect(APIConfig.fromContent(jsonEncoded, type: 'JSON')?.toJson(),
          equals({'a': 1, 'b': 2}));
      expect(
          APIConfig.fromContent(jsonEncoded, type: 'foo', autoIdentify: false),
          isNull);

      var yamlEncoded = '''
aa: 11
bb: 22
      ''';

      expect(APIConfig.fromContent(yamlEncoded)?.toJson(),
          equals({'aa': 11, 'bb': 22}));
      expect(APIConfig.fromContent(yamlEncoded, type: 'YAML')?.toJson(),
          equals({'aa': 11, 'bb': 22}));
      expect(
          APIConfig.fromContent(yamlEncoded, type: 'foo', autoIdentify: false),
          isNull);

      var propertiesEncoded = '''
x=100
y=zzz
      ''';

      expect(APIConfig.fromContent(propertiesEncoded)?.toJson(),
          equals({'x': 100, 'y': 'zzz'}));
      expect(
          APIConfig.fromContent(propertiesEncoded, type: 'properties')
              ?.toJson(),
          equals({'x': 100, 'y': 'zzz'}));
      expect(
          APIConfig.fromContent(propertiesEncoded,
              type: 'foo', autoIdentify: false),
          isNull);
    });

    test('fromSync', () async {
      var testDir = resolveTestDir();
      print('Test dir: $testDir');

      var apiConfig1 = APIConfig.fromSync('$testDir/api-test.conf');
      expect(apiConfig1?.toJson(),
          equals({'foo': 123, 'bar': 'abc', 'password': 123456}));

      var apiConfig2 = APIConfig.fromSync({'foo': 12, 'bar': 'ab'});
      expect(apiConfig2?.toJson(), equals({'foo': 12, 'bar': 'ab'}));

      var apiConfig3 = APIConfig.fromSync([
        {'foo': 12, 'bar': 'ab'},
        {'baz': 'zzz'}
      ]);
      expect(
          apiConfig3?.toJson(), equals({'foo': 12, 'bar': 'ab', 'baz': 'zzz'}));

      var apiConfig4 = APIConfig.fromSync('{"foo": 1, "bar": "a"}');
      expect(apiConfig4?.toJson(), equals({'foo': 1, 'bar': 'a'}));
    });

    test('fromAsync', () async {
      var testDir = resolveTestDir();
      print('Test dir: $testDir');

      var apiConfig = await APIConfig.fromAsync('$testDir/api-test.conf');

      expect(apiConfig!.source, endsWith('api-test.conf'));
      expect(apiConfig.sourceParentPath, endsWith(testDir));

      expect(apiConfig.isEmpty, isFalse);
      expect(apiConfig.isNotEmpty, isTrue);
      expect(apiConfig.length, 3);

      expect(apiConfig.properties,
          equals({'foo': 123, 'bar': 'abc', 'password': 123456}));
      expect(Map.fromEntries(apiConfig.entries),
          equals({'foo': 123, 'bar': 'abc', 'password': 123456}));
      expect(apiConfig.keys, equals(['foo', 'bar', 'password']));
      expect(apiConfig.values, equals([123, 'abc', 123456]));

      expect(apiConfig.toJson(),
          equals({'foo': 123, 'bar': 'abc', 'password': 123456}));

      expect(apiConfig['foo'], equals(123));
      expect(apiConfig['bar'], equals('abc'));
      expect(apiConfig['password'], equals(123456));
      expect(apiConfig['BaR'], isNull);

      expect(apiConfig.getIgnoreCase('FoO'), equals(123));
      expect(apiConfig.getIgnoreCase('Baz'), isNull);

      expect(
          apiConfig.toJsonEncoded(),
          equals('{\n'
              '  "foo": 123,\n'
              '  "bar": "abc",\n'
              '  "password": 123456\n'
              '}'));

      expect(
          apiConfig.toYAMLEncoded(),
          equals('foo: 123\n'
              'bar: \'abc\'\n'
              'password: 123456\n'));

      expect(
          apiConfig.toPropertiesEncoded(),
          equals('foo=123\n'
              'bar="abc"\n'
              'password=123456\n'));

      expect(
          apiConfig.toString(),
          matches(RegExp(
            r'APIConfig\[.*?/api-test.conf\]\{\s*'
            r'"foo": 123,\s*'
            r'"bar": "abc",\s*'
            r'"password": "\*\*\*"\s*'
            r'\}',
          )));
    });
  });
}

String resolveTestDir() {
  for (var f in ['test', '.', '../test']) {
    if (File('$f/api-test.conf').existsSync()) {
      return f;
    }
  }

  throw StateError("Can't resolve test directory!");
}

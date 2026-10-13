@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('bones_api_cov_config_');
  });

  tearDownAll(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('APIConfig (coverage)', () {
    test('setter / get caseSensitive', () {
      var config = APIConfig({'Foo': 1});
      config['bar'] = 2;

      expect(config['bar'], equals(2));
      expect(config.get('foo'), equals(1));
      expect(config.get('foo', caseSensitive: true), isNull);
      expect(config.get('Foo', caseSensitive: true), equals(1));
      expect(
        config.get('baz', caseSensitive: true, defaultValue: 3),
        equals(3),
      );
      expect(config.length, equals(2));
    });

    test('variables', () {
      APIPlatform.get().setProperty('BONES_API_COV_CONFIG_VAR', 'pval');

      var config = APIConfig({
        'a': '%BONES_API_COV_CONFIG_VAR%',
        'b': '%a%-x',
        'selfRefXyzCov': '[%selfRefXyzCov%]',
        'unknown': '[%BONES_API_COV_CONFIG_UNKNOWN_XYZ%]',
        'nested': '%BONES_API_COV_CONFIG_NESTED%',
      });

      APIPlatform.get().setProperty('BONES_API_COV_CONFIG_NESTED', '%a%!');

      expect(config['a'], equals('pval'));
      expect(config['b'], equals('pval-x'));
      expect(config['selfRefXyzCov'], equals('[]'));
      expect(config['unknown'], equals('[]'));
      expect(config['nested'], equals('pval!'));
    });

    test('getPath', () {
      var config = APIConfig({
        'a': {
          'b': {
            'c': [
              {
                'd': {'e': '12'},
              },
            ],
          },
        },
        's': 'text',
      });

      expect(config.getPath<Map>('a', 'b', 'c', 0, 'd'), equals({'e': '12'}));
      expect(config.getPath<int>('a', 'b', 'c', 0, 'x'), isNull);
      expect(config.getPath<int>('a', 'b', 'x'), isNull);
      // A `List` index out of range (or negative): `null`.
      expect(config.getPath<Map>('a', 'b', 'c', 1), isNull);
      expect(config.getPath<Map>('a', 'b', 'c', -1), isNull);
      expect(config.getPath<int>('a', 'b', 'c', 5, 'd'), isNull);
      expect(
        config.getPath<Map>('a', 'b', 'c', 0),
        equals({
          'd': {'e': '12'},
        }),
      );

      var config2 = APIConfig({
        'a': {
          'b': {
            'c': {
              'd': {'e': '12'},
            },
          },
        },
        's': 'text',
      });
      expect(config2.getPath<int>('a', 'b', 'c', 'd', 'e'), equals(12));
      expect(config2.getPath<String>('a', 'b', 'c', 'd', 'e'), equals('12'));
      expect(config2.getPath<int>('a', 'b', 'c', 'd', 'x'), isNull);

      expect(
        () => config2.getPath<APIConfig>('s'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('`s`'),
          ),
        ),
      );
      expect(
        () => config2.getPath<APIConfig>('a', 'b', 'c', 'd', 'e'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('a/b/c/d/e'),
          ),
        ),
      );
    });

    test('getAsMap / getAsList / getAs', () {
      var config = APIConfig({
        'm': {'x': 1},
        'l': [1, 2],
        'ld': <dynamic>['a', 'b'],
        's': 'text',
        'n': '42',
      });

      expect(config.getAsMap<int>('m'), equals({'x': 1}));
      expect(config.getAsMap('none'), isNull);
      expect(() => config.getAsMap('s'), throwsA(isA<StateError>()));

      expect(config.getAsList<int>('l'), equals([1, 2]));
      var ld = config.getAsList<String>('ld')!;
      expect(ld, equals(['a', 'b']));
      expect(ld, isA<List<String>>());
      expect(config.getAsList('none'), isNull);
      expect(() => config.getAsList('s'), throwsA(isA<StateError>()));

      expect(config.getAs<int>('n'), equals(42));
      expect(config.getAs<String>('n'), equals('42'));
      expect(config.getAs<Object>('n'), equals('42'));
      expect(config.getAs<int>('none'), isNull);
      expect(() => config.getAs<APIConfig>('s'), throwsA(isA<StateError>()));
    });

    test('applyProperties', () {
      expect(APIConfig({}).applyProperties(), isNull);
      expect(APIConfig({'properties': 'x'}).applyProperties(), isNull);

      var config = APIConfig({
        'properties': {
          'bones_api.cov.config.s': 'v1',
          'bones_api.cov.config.n': 10,
          'bones_api.cov.config.b': true,
          'bones_api.cov.config.l': [1, 2],
        },
      });

      var props = config.applyProperties();
      expect(
        props,
        equals({
          'bones_api.cov.config.s': 'v1',
          'bones_api.cov.config.n': '10',
          'bones_api.cov.config.b': 'true',
        }),
      );

      var platform = APIPlatform.get();
      expect(platform.getProperty('bones_api.cov.config.s'), equals('v1'));
      expect(platform.getProperty('bones_api.cov.config.n'), equals('10'));
      expect(platform.getProperty('bones_api.cov.config.l'), isNull);
    });

    test('from / fromSync / fromAsync', () async {
      expect(APIConfig.from({'a': 1})!['a'], equals(1));
      expect(APIConfig.from(null, {'d': 2})!['d'], equals(2));
      expect(APIConfig.from(123), isNull);
      expect(APIConfig.from(123, {'d': 3})!['d'], equals(3));

      var c0 = APIConfig({'x': 0});
      expect(identical(APIConfig.from(c0), c0), isTrue);

      APIConfig? provider() => APIConfig({'p': 1});
      expect(APIConfig.fromSync(provider)!['p'], equals(1));

      Future<APIConfig?> asyncProvider() async => APIConfig({'p': 2});
      expect(
        () => APIConfig.fromSync(asyncProvider),
        throwsA(isA<StateError>()),
      );
      expect((await APIConfig.fromAsync(asyncProvider))!['p'], equals(2));
      expect((await APIConfig.fromAsync(provider))!['p'], equals(1));

      expect(APIConfig.from('a b c = not a valid content'), isNotNull);
      expect(APIConfig.fromSync(Object(), {'z': 1})!['z'], equals(1));
    });

    test('fromCollection', () {
      expect(APIConfig.fromCollection(null), isNull);
      expect(APIConfig.fromCollection(null, {'d': 1})!['d'], equals(1));
      expect(APIConfig.fromCollection(123), isNull);

      var c1 = APIConfig.fromCollection({1: 'a', 2: 'b'})!;
      expect(c1['1'], equals('a'));
      expect(c1['2'], equals('b'));

      var c2 = APIConfig.fromCollection([
        null,
        MapEntry('k1', {
          'x': [
            1,
            {'y': 2},
          ],
        }),
        {'k2': 2},
        [
          {'k3': 3},
        ],
        'k4=4\nk5: "five"',
      ])!;

      expect(
        c2.properties,
        equals({
          'k1': {
            'x': [
              1,
              {'y': 2},
            ],
          },
          'k2': 2,
          'k3': 3,
          'k4': 4,
          'k5': 'five',
        }),
      );

      expect(() => APIConfig.fromCollection([123]), throwsA(isA<StateError>()));
    });

    test('fromYAML (list)', () {
      var config = APIConfig.fromYAML(
        '- a: 1\n'
        '- b:\n'
        '    - x\n'
        '    - y\n'
        '- ~\n'
        "- 'c=3'\n",
      );

      expect(
        config.properties,
        equals({
          'a': 1,
          'b': ['x', 'y'],
          'c': 3,
        }),
      );
    });

    test('fromJson', () {
      var config = APIConfig.fromJson({'development': 'true', 'test': true});
      expect(config.development, isTrue);
      expect(config.test, isTrue);
    });

    test('fromContent: forced types', () {
      expect(
        () => APIConfig.fromContent('{invalid', type: 'json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => APIConfig.fromContent('a: [1, 2', type: 'yaml'),
        throwsA(isA<FormatException>()),
      );

      var c = APIConfig.fromContent('a=1', type: 'properties')!;
      expect(c['a'], equals(1));

      var c2 = APIConfig.fromContent('{"a": 2}', type: '*')!;
      expect(c2['a'], equals(2));
    });

    test('resolveStringUri', () {
      expect(APIConfig.resolveStringUri('a b'), isNull);
      expect(
        APIConfig.resolveStringUri('http://localhost/x.json'),
        equals(Uri.parse('http://localhost/x.json')),
      );

      var base = Uri.base;
      var basePath = base.path.endsWith('/') ? base.path : '${base.path}/';

      var u1 = APIConfig.resolveStringUri('./conf/x.json')!;
      expect(u1.path, equals('${basePath}conf/x.json'));
      expect(u1.scheme, equals(base.scheme));

      var u2 = APIConfig.resolveStringUri('conf.json')!;
      expect(u2.path, endsWith('conf.json'));

      var u3 = APIConfig.resolveStringUri('/abs/conf.json')!;
      expect(u3.path, equals('/abs/conf.json'));

      expect(APIConfig.resolveStringUri('#x'), isNull);
    });

    test('from file URI', () async {
      var file = File('${tmpDir.path}/cov-config.json');
      await file.writeAsString('{"name": "cov", "n": 7}');

      var uri = file.uri.toString();
      var config = APIConfig.fromSync(uri)!;
      expect(config['name'], equals('cov'));
      expect(config['n'], equals(7));
      expect(config.source, equals(uri));
      expect(
        config.sourceParentPath,
        equals(
          File(file.path).parent.uri.toFilePath().replaceAll(RegExp(r'/$'), ''),
        ),
      );

      var emptyFile = File('${tmpDir.path}/empty.json');
      await emptyFile.writeAsString('');
      expect(APIConfig.fromSync(emptyFile.uri.toString()), isNull);
      expect(
        APIConfig.fromSync(emptyFile.uri.toString(), {'d': 1})!['d'],
        equals(1),
      );

      var missing = File('${tmpDir.path}/missing.json');
      expect(APIConfig.fromUri(missing.uri), isNull);
      expect(APIConfig.fromUri(Uri.parse('ftp://host/x.json')), isNull);
    });

    test('from http URI (async)', () async {
      var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var served = Completer<String>();

      server.listen((request) async {
        if (request.uri.path == '/missing.json') {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"remote": true}');
        }
        await request.response.close();
        if (!served.isCompleted) served.complete(request.uri.path);
      });

      try {
        var url = 'http://127.0.0.1:${server.port}/cov-config.json';

        // Sync mode doesn't download:
        expect(APIConfig.fromSync(url), isNull);
        expect(APIConfig.fromSync(url, {'fallback': 1})!['fallback'], 1);

        // Async mode returns the downloaded configuration:
        var config = await APIConfig.fromAsync(url, {'fallback': 1});
        expect(config!['remote'], isTrue);
        expect(config['fallback'], isNull);
        expect(config.source, equals(url));

        // The exact URL (no trailing `/`):
        expect(
          await served.future.timeout(Duration(seconds: 10)),
          equals('/cov-config.json'),
        );

        // Not found: the default.
        var missingURL = 'http://127.0.0.1:${server.port}/missing.json';
        var config2 = await APIConfig.fromAsync(missingURL, {'fallback': 2});
        expect(config2!['fallback'], equals(2));
        expect(await APIConfig.fromAsync(missingURL), isNull);
      } finally {
        await server.close(force: true);
      }
    });
  });
}

@TestOn('vm')
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args_simple/args_simple.dart';
import 'package:bones_api/bones_api_server.dart';
import 'package:bones_api/src/bones_api_server_cache.dart';
import 'package:path/path.dart' as pack_path;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _CovConfigAPIRoot extends APIRoot {
  _CovConfigAPIRoot([dynamic apiConfig])
    : super('cov-config', '1.0.1', apiConfig: apiConfig);

  @override
  Set<APIModule> loadModules() => {};
}

void main() {
  group('APICrossOriginConfig', () {
    test('defaults + toJson/fromJson/toString', () {
      var config = APICrossOriginConfig();

      var json = config.toJson();
      expect(json.keys, equals(['api', 'static_files']));
      var jsonApi = json['api'] as Map;
      var jsonStatic = json['static_files'] as Map;
      expect(jsonApi['allow_origin'], isEmpty);
      expect(
        jsonApi['allow_methods'],
        equals(APICORSConfig.defaultAllowMethods),
      );
      expect(jsonApi['allow_credentials'], isTrue);
      expect(jsonApi['max_age'], equals(0));
      expect(jsonApi['vary_origin'], isTrue);
      expect(
        jsonStatic['opener_policy'],
        equals(APICrossOriginPolicies.defaultOpenerPolicy),
      );
      expect(jsonStatic['embedder_policy'], equals(''));
      expect(jsonStatic['resource_policy'], equals(''));

      var config2 = APICrossOriginConfig.fromJson({
        'api': {
          'allow_origin': 'https://a.com, https://b.com',
          'allow_methods': ['GET', ' POST ', ''],
          'allow_headers': '',
          'allow_credentials': 'false',
          'expose_headers': ['X-Foo'],
          'max_age': '600',
          'vary_origin': false,
        },
        'static_files': {
          'opener_policy': 'none',
          'embedder_policy': 'require-corp',
          'resource_policy': 'same-site',
        },
      });

      expect(
        config2.api.allowOrigin,
        equals(['https://a.com', 'https://b.com']),
      );
      expect(config2.api.allowMethods, equals(['GET', 'POST']));
      expect(config2.api.allowHeaders, isEmpty);
      expect(config2.api.allowCredentials, isFalse);
      expect(config2.api.exposeHeaders, equals(['X-Foo']));
      expect(config2.api.maxAge, equals(600));
      expect(config2.api.varyOrigin, isFalse);
      expect(config2.staticFiles.openerPolicy, equals(''));
      expect(config2.staticFiles.embedderPolicy, equals('require-corp'));
      expect(config2.staticFiles.resourcePolicy, equals('same-site'));

      expect(config2.toString(), startsWith('APICrossOriginConfig{api: '));
      expect(config2.toString(), contains('APICORSConfig{'));
      expect(config2.toString(), contains('APICrossOriginPolicies{'));
      expect(config2.api.toString(), contains('max_age: 600'));
      expect(
        config2.staticFiles.toString(),
        contains('embedder_policy: require-corp'),
      );

      // Non-map entries fall back to the defaults:
      var config3 = APICrossOriginConfig.fromJson({
        'api': 'x',
        'static_files': 1,
      });
      expect(config3.api.allowOrigin, isEmpty);
      expect(
        config3.staticFiles.openerPolicy,
        equals(APICrossOriginPolicies.defaultOpenerPolicy),
      );
    });

    test('resolve from APIConfig and args', () {
      var apiConfig = APIConfig({
        'cross_origin': {
          'api': {'allow_origin': 'https://cfg.com', 'max_age': 60},
          'static_files': {'resource_policy': 'same-origin'},
        },
      });

      var config = APICrossOriginConfig.resolve(apiConfig: apiConfig);
      expect(config.api.allowOrigin, equals(['https://cfg.com']));
      expect(config.api.maxAge, equals(60));
      expect(config.staticFiles.resourcePolicy, equals('same-origin'));

      var args = ArgsSimple.parse([
        '--cross-origin-api-allow-origin',
        'https://arg.com',
        '--cross-origin-api-max-age',
        '120',
        '--cross-origin-static-files-opener-policy',
        'same-origin',
        '--cross-origin-static-files-embedder-policy',
        'credentialless',
      ]);

      var config2 = APICrossOriginConfig.resolve(
        apiConfig: apiConfig,
        args: args,
      );
      expect(config2.api.allowOrigin, equals(['https://arg.com']));
      expect(config2.api.maxAge, equals(120));
      expect(config2.staticFiles.openerPolicy, equals('same-origin'));
      expect(config2.staticFiles.embedderPolicy, equals('credentialless'));
      expect(config2.staticFiles.resourcePolicy, equals('same-origin'));
    });

    test('APICORSConfig helpers', () {
      expect(APICORSConfig.parseMaxAge(null), isNull);
      expect(APICORSConfig.parseMaxAge(10), equals(10));
      expect(APICORSConfig.parseMaxAge(10.7), equals(10));
      expect(APICORSConfig.parseMaxAge(' 30 '), equals(30));
      expect(APICORSConfig.parseMaxAge('x'), isNull);

      expect(
        APICORSConfig.normalizeOrigin(' HTTP://Foo.com// '),
        equals('http://foo.com'),
      );

      expect(APICORSConfig.isLocalhostOrigin('http://localhost:8080'), isTrue);
      expect(APICORSConfig.isLocalhostOrigin('http://127.0.0.1:80'), isTrue);
      expect(APICORSConfig.isLocalhostOrigin('http://foo.com'), isFalse);

      var reflect = APICORSConfig();
      expect(reflect.resolveAllowOrigin(''), equals('*'));
      expect(
        reflect.resolveAllowOrigin('http://x.com'),
        equals('http://x.com'),
      );

      var allowList = APICORSConfig(allowOrigin: ['https://a.com/']);
      expect(allowList.resolveAllowOrigin(''), isNull);
      expect(
        allowList.resolveAllowOrigin('https://A.com'),
        equals('https://A.com'),
      );
      expect(allowList.resolveAllowOrigin('https://b.com'), isNull);

      var any = APICORSConfig(allowOrigin: '*');
      expect(any.resolveAllowOrigin('https://b.com'), equals('https://b.com'));

      expect(
        reflect.resolveAllowHeaders('http://localhost:1234'),
        equals([...APICORSConfig.defaultAllowHeaders, 'x-ijt']),
      );
      expect(
        reflect.resolveAllowHeaders('http://foo.com'),
        equals(APICORSConfig.defaultAllowHeaders),
      );

      var withIjt = APICORSConfig(allowHeaders: 'Content-Type, x-ijt');
      expect(
        withIjt.resolveAllowHeaders('http://localhost:1234'),
        equals(['Content-Type', 'x-ijt']),
      );

      var noHeaders = APICORSConfig(allowHeaders: []);
      expect(noHeaders.resolveAllowHeaders('http://localhost:1'), isEmpty);
    });

    test('APICrossOriginPolicies.normalizePolicy', () {
      expect(APICrossOriginPolicies.normalizePolicy(null, 'def'), 'def');
      expect(APICrossOriginPolicies.normalizePolicy('  ', 'def'), '');
      expect(APICrossOriginPolicies.normalizePolicy('NONE', 'def'), '');
      expect(
        APICrossOriginPolicies.normalizePolicy(' same-site ', 'def'),
        'same-site',
      );
    });
  });

  group('APIServerConfig', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('bones_api_cov_cfg_');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('resolveArgs', () {
      expect(APIServerConfig.resolveArgs(null).isEmpty, isTrue);

      var a = ArgsSimple.parse(['--x', '1']);
      expect(identical(APIServerConfig.resolveArgs(a), a), isTrue);

      var l = APIServerConfig.resolveArgs(['--port', 81, '-flag']);
      expect(l.optionAsInt('port'), equals(81));
      expect(l.flag('flag'), isTrue);

      var s = APIServerConfig.resolveArgs('["--name","foo"]');
      expect(s.optionAsString('name'), equals('foo'));

      expect(APIServerConfig.resolveArgs(123).isEmpty, isTrue);
    });

    test('fromArgs (full)', () {
      var docRoot = Directory(pack_path.join(tmpDir.path, 'www'))..createSync();

      var configFile = File(pack_path.join(tmpDir.path, 'api-cov.json'));
      configFile.writeAsStringSync(
        json.encode({
          'development': true,
          'server': {'response-delay': '15ms'},
        }),
      );

      var leDir = pack_path.join(tmpDir.path, 'le');

      var config = APIServerConfig.fromArgs([
        configFile.path,
        '--name',
        'CovServer',
        '--version',
        '9.9.9',
        '--port',
        '8123',
        '--secure-port',
        '8443',
        '--address',
        '*',
        '-letsencrypt',
        '-letsencrypt-production',
        '-allow-request-letsencrypt-certificate',
        '--letsencrypt-directory',
        leDir,
        '-hot-reload',
        '--total-workers',
        '3',
        '-cookieless',
        '--api-cache-control',
        'no-store',
        '--static-files-cache-control',
        'max-age=1',
        '--long-lived-static-files-cache-control',
        'max-age=999',
        '--long-lived-static-files-cached',
        '/a.js,re:^/b.*',
        '--cache-static-files-responses',
        'false',
        '--static-files-cache-max-memory-size',
        '2000000',
        '--static-files-cache-max-content-length',
        '1000',
        '--max-payload-length',
        '4096',
        '-decompress-payload',
        '--compression-encodings',
        'gzip,br',
        '--brotli-quality',
        '7',
        '-log-toConsole',
        '-log-queue',
        '--document-root',
        docRoot.path,
        '--domains',
        'foo.com=${docRoot.path}',
      ]);

      expect(config.development, isTrue);
      expect(config.name, equals('CovServer'));
      expect(config.version, equals('9.9.9'));
      expect(config.port, equals(8123));
      expect(config.securePort, equals(8443));
      expect(config.address, equals('0.0.0.0'));
      expect(config.letsEncrypt, isTrue);
      expect(config.letsEncryptProduction, isTrue);
      expect(config.allowRequestLetsEncryptCertificate, isTrue);
      expect(config.letsEncryptDirectory, isNotNull);
      expect(Directory(leDir).existsSync(), isTrue);
      expect(config.hotReload, isTrue);
      expect(config.totalWorkers, equals(3));
      expect(config.cookieless, isTrue);
      expect(config.useSessionID, isFalse);
      expect(config.apiCacheControl, equals('no-store'));
      expect(config.staticFilesCacheControl, equals('max-age=1'));
      expect(config.longLivedStaticFilesCacheControl, equals('max-age=999'));
      expect(config.longLivedStaticFilesCached.length, equals(2));
      expect(config.longLivedStaticFilesCached[0], equals('/a.js'));
      expect(config.longLivedStaticFilesCached[1], isA<RegExp>());
      expect(config.cacheStaticFilesResponses, isFalse);
      expect(config.staticFilesCacheMaxMemorySize, equals(2000000));
      expect(config.staticFilesCacheMaxContentLength, equals(1000));
      expect(config.maxPayloadLength, equals(4096));
      expect(config.decompressPayload, isTrue);
      expect(
        config.compressionEncodings,
        equals([APIContentEncoding.gzip, APIContentEncoding.br]),
      );
      expect(config.brotliQuality, equals(7));
      expect(
        config.responseCompression,
        equals(
          APIResponseCompression(
            encodings: [APIContentEncoding.gzip, APIContentEncoding.br],
            brotliQuality: 7,
          ),
        ),
      );
      expect(config.logToConsole, isTrue);
      expect(config.logQueue, isTrue);
      expect(config.serverResponseDelay, equals(Duration(milliseconds: 15)));
      expect(config.domains, equals(['foo.com']));
      expect(config.domainsRoots.length, equals(2));
      expect(config.apiConfig, isNotNull);
      expect(config.args.isNotEmpty, isTrue);

      var j = config.toJson();
      expect(j['name'], equals('CovServer'));
      expect(j['letsEncryptDirectory'], isNotNull);
      expect(
        j['longLivedStaticFilesCached'],
        equals(['/a.js', r'regexp:^/b.*']),
      );
      expect(j['args'], isA<List>());
      expect(j['crossOrigin'], isA<Map>());
      expect(j['compressionEncodings'], equals(['gzip', 'br']));
      expect(j['brotliQuality'], equals(7));

      var config2 = APIServerConfig.fromJson({
        ...j,
        'domains': {'foo.com': docRoot.path},
      });
      expect(config2.name, equals('CovServer'));
      expect(config2.port, equals(8123));
      expect(config2.cookieless, isTrue);
      expect(config2.apiCacheControl, equals('no-store'));
      expect(config2.longLivedStaticFilesCached[0], equals('/a.js'));
      expect(config2.longLivedStaticFilesCached[1], isA<RegExp>());
      expect(config2.maxPayloadLength, equals(4096));
      expect(
        config2.compressionEncodings,
        equals([APIContentEncoding.gzip, APIContentEncoding.br]),
      );
      expect(config2.brotliQuality, equals(7));
      expect(config2.args.isNotEmpty, isTrue);
      expect(config2.domains, equals(['foo.com']));
    });

    test('fromArgs (minimal, cookie flags)', () {
      var config = APIServerConfig.fromArgs(['-use-session-id']);
      expect(config.port, equals(80));
      expect(config.address, equals('localhost'));
      expect(config.letsEncrypt, isFalse);
      expect(config.letsEncryptProduction, isFalse);
      expect(config.useSessionID, isTrue);
      expect(config.cookieless, isFalse);
      expect(config.securePort, equals(-1));
      expect(config.name, equals('Bones_API'));
      expect(config.version, equals(BonesAPI.VERSION));

      var config2 = APIServerConfig.fromArgs([
        'not-a-config-file.txt',
        '--api-config',
        pack_path.join(tmpDir.path, 'none.yaml'),
      ]);
      expect(config2.port, equals(80));
    });

    test('fromArgs: --compression-encodings false', () {
      for (var off in ['false', 'none', 'off']) {
        var config = APIServerConfig.fromArgs(['--compression-encodings', off]);
        expect(config.compressionEncodings, isEmpty, reason: off);
        expect(config.responseCompression.isEnabled, isFalse, reason: off);
      }
    });

    test('normalizeAddress', () {
      for (var a in ['*', '0', '::', '0:0:0:0:0:0:0:0']) {
        expect(APIServerConfig.normalizeAddress(a), equals('0.0.0.0'));
      }
      for (var a in [null, '', 'local', '1', '127', '::1', '0:0:0:0:0:0:0:1']) {
        expect(APIServerConfig.normalizeAddress(a), equals('localhost'));
      }
      expect(
        APIServerConfig.normalizeAddress(' 10.0.0.1 '),
        equals('10.0.0.1'),
      );

      var apiConfig = APIConfig({
        'server': {'address': '*', 'port': 9001, 'securePort': 9443},
      });
      expect(
        APIServerConfig.normalizeAddress(null, apiConfig: apiConfig),
        equals('0.0.0.0'),
      );
      expect(
        APIServerConfig.resolvePort(null, apiConfig: apiConfig),
        equals(9001),
      );
      expect(APIServerConfig.resolvePort(5), equals(80));
      expect(
        APIServerConfig.resolveSecurePort(
          null,
          apiConfig: apiConfig,
          letsEncrypt: true,
        ),
        equals(9443),
      );
      expect(
        APIServerConfig.resolveSecurePort(null, letsEncrypt: true),
        equals(443),
      );
      expect(APIServerConfig.resolveSecurePort(null), equals(-1));
    });

    test('normalizeHeaderValue', () {
      expect(APIServerConfig.normalizeHeaderValue(' x ', 'def'), equals('x'));
      expect(APIServerConfig.normalizeHeaderValue('', 'def'), equals('def'));

      var apiConfig = APIConfig({
        'cache': {
          'api': {'cache_control': 'from-config'},
        },
      });
      expect(
        APIServerConfig.normalizeHeaderValue(
          null,
          'def',
          apiConfig,
          'cache',
          'api',
          'cache_control',
        ),
        equals('from-config'),
      );
      expect(
        APIServerConfig.normalizeHeaderValue(
          null,
          'def',
          apiConfig,
          'cache',
          'static_files',
          'cache_control',
        ),
        equals('def'),
      );
    });

    test('resolveDomainsRoots', () {
      var root = Directory('/var/root');
      var map = APIServerConfig.resolveDomainsRoots([
        'a.com',
        'b.com=/var/b',
        'c.com=',
      ], root);
      expect(
        map.map((k, v) => MapEntry(k, v.path)),
        equals({'a.com': '/var/root', 'b.com': '/var/b', 'c.com': '/var/root'}),
      );

      var map2 = APIServerConfig.resolveDomainsRoots(['a.com', 'b.com=/x']);
      expect(map2.keys, equals(['b.com']));
    });

    test('resolveLetsEncryptDirectory', () {
      var existing = APIServerConfig.resolveLetsEncryptDirectory(tmpDir);
      expect(existing!.path, equals(tmpDir.absolute.path));

      var str = APIServerConfig.resolveLetsEncryptDirectory(' ${tmpDir.path} ');
      expect(str!.path, equals(tmpDir.absolute.path));

      var nonExistentPath = pack_path.join(tmpDir.path, 'nope');
      var nonExistent = APIServerConfig.resolveLetsEncryptDirectory(
        nonExistentPath,
      );
      expect(nonExistent!.path, equals(nonExistentPath));
      expect(Directory(nonExistentPath).existsSync(), isFalse);

      var created = APIServerConfig.resolveLetsEncryptDirectory(
        nonExistentPath,
        letsEncrypt: true,
      );
      expect(created, isNotNull);
      expect(Directory(nonExistentPath).existsSync(), isTrue);

      var fromConfig = APIServerConfig.resolveLetsEncryptDirectory(
        null,
        apiConfig: APIConfig({
          'letsencrypt': {'directory': tmpDir.path},
        }),
      );
      expect(fromConfig!.path, equals(tmpDir.absolute.path));

      // No directory: searches default paths (result depends on the host).
      var defaultDir = APIServerConfig.resolveLetsEncryptDirectory('  ');
      if (defaultDir != null) {
        expect(defaultDir.existsSync(), isTrue);
      }
    });

    test('resolve* from APIConfig', () {
      var apiConfig = APIConfig({
        'server': {
          'totalWorkers': 500,
          'cookieless': false,
          'use_session_id': false,
          'max_payload_length': 123,
          'decompress_payload': true,
          'compression_encodings': ['gzip'],
          'brotli_quality': '99',
        },
        'letsencrypt': {'production': true, 'allow-request-certificate': true},
        'log': {'console': false, 'queue': false},
        'cache': {
          'static_files': {
            'enabled': false,
            'max_memory_size': 3000000,
            'max_content_length': 3000,
          },
          'long_lived_static_files': {
            'cached': ['/x.js', 'regexp:^/y', '', 're:^/z'],
          },
        },
      });

      expect(
        APIServerConfig.resolveTotalWorkers(null, apiConfig: apiConfig),
        equals(100),
      );
      expect(APIServerConfig.resolveTotalWorkers(0), equals(1));
      expect(
        APIServerConfig.resolveCookieless(null, apiConfig: apiConfig),
        isFalse,
      );
      expect(
        APIServerConfig.resolveUseSessionID(null, null, apiConfig: apiConfig),
        isFalse,
      );
      expect(APIServerConfig.resolveUseSessionID(true, true), isFalse);
      expect(
        APIServerConfig.resolveMaxPayloadLength(null, apiConfig: apiConfig),
        equals(123),
      );
      expect(
        APIServerConfig.resolveDecompressPayload(null, apiConfig: apiConfig),
        isTrue,
      );
      expect(
        APIServerConfig.resolveCompressionEncodings(null, apiConfig: apiConfig),
        equals([APIContentEncoding.gzip]),
      );
      expect(
        APIServerConfig.resolveCompressionEncodings('br'),
        equals([APIContentEncoding.br]),
      );
      // Empty or `none`: compression disabled:
      expect(APIServerConfig.resolveCompressionEncodings(''), isEmpty);
      expect(APIServerConfig.resolveCompressionEncodings([]), isEmpty);
      expect(APIServerConfig.resolveCompressionEncodings('None'), isEmpty);
      // Unknown ones ignored; none known (or a flag): the defaults:
      expect(
        APIServerConfig.resolveCompressionEncodings('gzip, deflate'),
        equals([APIContentEncoding.gzip]),
      );
      expect(
        APIServerConfig.resolveCompressionEncodings([
          APIContentEncoding.gzip,
          'br',
        ]),
        equals([APIContentEncoding.gzip, APIContentEncoding.br]),
      );
      expect(
        APIServerConfig.resolveCompressionEncodings('gzp,brr'),
        equals(APIContentEncoding.defaultEncodings),
      );
      expect(
        APIServerConfig.resolveCompressionEncodings(
          null,
          apiConfig: APIConfig({
            'server': {'compression_encodings': 'deflate'},
          }),
        ),
        equals(APIContentEncoding.defaultEncodings),
      );
      expect(
        APIServerConfig.resolveCompressionEncodings(true),
        equals(APIContentEncoding.defaultEncodings),
      );
      expect(
        APIServerConfig.resolveCompressionEncodings('true'),
        equals(APIContentEncoding.defaultEncodings),
      );
      expect(
        APIServerConfig.resolveCompressionEncodings(null),
        equals(APIContentEncoding.defaultEncodings),
      );
      expect(
        APIServerConfig.resolveCompressionEncodings(' ON '),
        equals(APIContentEncoding.defaultEncodings),
      );
      // `false` (bool or string) and the like: compression disabled:
      expect(APIServerConfig.resolveCompressionEncodings(false), isEmpty);
      for (var off in [
        'false',
        'FALSE',
        'off',
        'no',
        ' none ',
        'none,deflate',
      ]) {
        expect(
          APIServerConfig.resolveCompressionEncodings(off),
          isEmpty,
          reason: off,
        );
      }
      expect(APIServerConfig.resolveCompressionEncodings([false]), isEmpty);
      expect(APIServerConfig.resolveCompressionEncodings(['', ' ']), isEmpty);
      expect(
        APIServerConfig.resolveCompressionEncodings(
          null,
          apiConfig: APIConfig({
            'server': {'compression_encodings': false},
          }),
        ),
        isEmpty,
      );
      // A known encoding wins over a disabled value:
      expect(
        APIServerConfig.resolveCompressionEncodings('none,br'),
        equals([APIContentEncoding.br]),
      );
      // Duplicates removed, order kept:
      expect(
        APIServerConfig.resolveCompressionEncodings('gzip,br,x-gzip'),
        equals([APIContentEncoding.gzip, APIContentEncoding.br]),
      );
      // Clamped:
      expect(
        APIServerConfig.resolveBrotliQuality(null, apiConfig: apiConfig),
        equals(11),
      );
      expect(APIServerConfig.resolveBrotliQuality(-3), equals(0));
      expect(APIServerConfig.resolveBrotliQuality(null), equals(5));
      expect(
        APIServerConfig.resolveBrotliQuality(
          null,
          apiConfig: APIConfig({
            'server': {'brotli_quality': 6},
          }),
        ),
        equals(6),
      );
      expect(
        APIServerConfig.resolveLetsEncryptProduction(
          null,
          apiConfig: apiConfig,
        ),
        isTrue,
      );
      expect(
        APIServerConfig.resolveAllowRequestLetsEncryptCertificate(
          null,
          apiConfig: apiConfig,
        ),
        isTrue,
      );
      expect(
        APIServerConfig.resolveLogToConsole(null, apiConfig: apiConfig),
        isFalse,
      );
      expect(
        APIServerConfig.resolveLogQueue(null, apiConfig: apiConfig),
        isFalse,
      );
      expect(
        APIServerConfig.resolveCacheStaticFilesResponses(
          null,
          apiConfig: apiConfig,
        ),
        isFalse,
      );
      expect(
        APIServerConfig.resolveCacheStaticFilesResponses(
          null,
          apiConfig: APIConfig({
            'cache': {'static_files': false},
          }),
        ),
        isFalse,
      );
      expect(
        APIServerConfig.resolveCacheStaticFilesResponses(
          null,
          apiConfig: APIConfig({'cache_static_files_responses': false}),
        ),
        isFalse,
      );
      expect(APIServerConfig.resolveCacheStaticFilesResponses(null), isTrue);
      expect(
        APIServerConfig.resolveStaticFilesCacheMaxMemorySize(
          null,
          apiConfig: apiConfig,
        ),
        equals(3000000),
      );
      expect(
        APIServerConfig.resolveStaticFilesCacheMaxMemorySize(
          null,
          apiConfig: APIConfig({'static_files_cache_max_memory_size': 7}),
        ),
        equals(7),
      );
      expect(
        APIServerConfig.resolveStaticFilesCacheMaxMemorySize(null),
        equals(APIServerResponseCache.defaultMaxMemorySize),
      );
      expect(
        APIServerConfig.resolveStaticFilesCacheMaxContentLength(
          null,
          apiConfig: apiConfig,
        ),
        equals(3000),
      );
      expect(
        APIServerConfig.resolveStaticFilesCacheMaxContentLength(
          null,
          apiConfig: APIConfig({'static_files_cache_max_content_length': 8}),
        ),
        equals(8),
      );
      expect(
        APIServerConfig.resolveStaticFilesCacheMaxContentLength(null),
        equals(APIServerResponseCache.defaultMaxContentLength),
      );

      var patterns = APIServerConfig.resolveLongLivedStaticFiles(
        null,
        apiConfig: apiConfig,
      );
      expect(patterns.length, equals(3));
      expect(patterns[0], equals('/x.js'));
      expect((patterns[1] as RegExp).pattern, equals('^/y'));
      expect((patterns[2] as RegExp).pattern, equals('^/z'));

      var single = APIServerConfig.resolveLongLivedStaticFiles(
        RegExp(r'\.png$'),
      );
      expect(single.single, isA<RegExp>());

      var defs = APIServerConfig.resolveLongLivedStaticFiles(null, def: ['/d']);
      expect(defs, equals(['/d']));

      expect(APIServerConfig.resolveLongLivedStaticFiles(null), isEmpty);
    });

    test('parseDomains / parseDomainEntry / parseDomainPattern', () {
      expect(APIServerConfig.parseDomains(null), isEmpty);

      var fromConfig = APIServerConfig.parseDomains(
        null,
        apiConfig: APIConfig({
          'domains': {'cfg.com': tmpDir.path, '*': tmpDir.path},
        }),
        documentRoot: tmpDir.path,
      );
      expect(fromConfig.keys.whereType<RegExp>(), isNotEmpty);
      expect(fromConfig.keys.whereType<String>(), equals(['cfg.com']));

      var nonExistent = APIServerConfig.parseDomains([
        'a.com=/non/existent/dir/xyz',
        'b.com=${tmpDir.path}',
      ], checkDirectoryExistence: true);
      expect(nonExistent.keys, equals(['b.com']));

      var allInvalid = APIServerConfig.parseDomains([
        'a.com=/non/existent/dir/xyz',
      ], checkDirectoryExistence: true);
      expect(allInvalid, isEmpty);

      var fromObj = APIServerConfig.parseDomains(123);
      expect(fromObj.keys, equals(['123']));

      expect(APIServerConfig.parseDomainEntry(null), isNull);

      expect(APIServerConfig.parseDomainPattern('.'), isA<RegExp>());
      expect(APIServerConfig.parseDomainPattern('*'), isA<RegExp>());
      var re = RegExp('x');
      expect(identical(APIServerConfig.parseDomainPattern(re), re), isTrue);

      expect(APIServerConfig.parseDomainDirectory(null), isNull);
      expect(
        identical(APIServerConfig.parseDomainDirectory(tmpDir), tmpDir),
        isTrue,
      );
      expect(
        APIServerConfig.parseDomainDirectory(
          '/non/existent/xyz',
          checkDirectoryExistence: true,
        ),
        isNull,
      );
    });
  });

  group('APIServer (static helpers)', () {
    test('create / _parseArg', () async {
      var tmpDir = await Directory.systemTemp.createTemp('bones_api_cov_srv_');
      addTearDown(() => tmpDir.delete(recursive: true));

      var s0 = APIServer.create(_CovConfigAPIRoot());
      expect(s0.address, equals('localhost'));
      expect(s0.port, equals(8080));

      var s1 = APIServer.create(_CovConfigAPIRoot(), ['8181']);
      expect(s1.address, equals('localhost'));
      expect(s1.port, equals(8181));

      var s2 = APIServer.create(_CovConfigAPIRoot(), ['0']);
      expect(s2.address, equals('0.0.0.0'));
      expect(s2.port, equals(8080));

      var s3 = APIServer.create(_CovConfigAPIRoot(), ['10.1.2.3']);
      expect(s3.address, equals('10.1.2.3'));
      expect(s3.port, equals(8080));

      var configFile = File(pack_path.join(tmpDir.path, 'cfg.json'));
      configFile.writeAsStringSync(json.encode({'foo': 'bar'}));

      var root4 = _CovConfigAPIRoot();
      var s4 = APIServer.create(root4, [
        'x',
        '--address',
        '127.0.0.1',
        '--port',
        '8282',
        '--hotreload',
        '--config',
        configFile.path,
      ], 1);
      expect(s4.address, equals('127.0.0.1'));
      expect(s4.port, equals(8282));
      expect(s4.hotReload, isTrue);
      expect(root4.apiConfig['foo'], equals('bar'));
      expect(s4.urlHost, equals('localhost'));
      expect(s4.url, equals('http://localhost:8282/'));

      var s5 = APIServer.create(_CovConfigAPIRoot(), [
        'example.com',
        '8383',
        'true',
        configFile.path,
      ]);
      expect(s5.address, equals('example.com'));
      expect(s5.port, equals(8383));
      expect(s5.hotReload, isTrue);
      expect(s5.urlHost, equals('example.com'));

      var s6 = APIServer.create(_CovConfigAPIRoot(), ['-p', '8484'], 10);
      expect(s6.port, equals(8080));

      var s7 = APIServer.create(_CovConfigAPIRoot(), [
        '-a',
        'h.com',
        '-p',
        '8585',
      ]);
      expect(s7.address, equals('h.com'));
      expect(s7.port, equals(8585));
      expect(s7.hotReload, isFalse);
    });

    test('fromConfig / fromArgs / toString', () async {
      var tmpDir = await Directory.systemTemp.createTemp('bones_api_cov_srv_');
      addTearDown(() => tmpDir.delete(recursive: true));

      var config = APIServerConfig(
        address: 'localhost',
        port: 8686,
        securePort: 8687,
        letsEncrypt: true,
        letsEncryptDirectory: tmpDir.path,
        domains: {'foo.com': tmpDir.path, r'r/(www\.)?bar.com/': tmpDir.path},
        serverResponseDelay: Duration(milliseconds: 1),
      );

      var server = APIServer.fromConfig(_CovConfigAPIRoot(), config);
      expect(server.port, equals(8686));
      expect(server.securePort, equals(8687));
      expect(server.canUseLetsEncrypt, isTrue);
      expect(server.serverName, equals('Bones_API/${BonesAPI.VERSION}'));
      expect(server.apiInfoURL, equals('http://localhost:8686/API-INFO'));
      expect(server.isStarted, isFalse);
      expect(server.isStarting, isFalse);
      expect(server.isStopped, isFalse);

      var str = server.toString();
      expect(str, contains('port: 8686'));
      expect(str, contains('serverResponseDelay: '));
      expect(str, contains('securePort: 8687'));
      expect(str, contains('letsEncrypt: true @staging'));
      expect(str, contains('`foo.com`='));
      expect(str, contains(r'r/(www\.)?bar.com/='));

      // `stop` on a not started server is a no-op:
      await server.stop();
      expect(server.isStopped, isFalse);

      var server2 = APIServer.fromArgs(_CovConfigAPIRoot(), [
        '--port',
        '8787',
        '--address',
        '0.0.0.0',
      ]);
      expect(server2.port, equals(8787));
      expect(server2.urlHost, equals('localhost'));
      expect(server2.toString(), isNot(contains('securePort')));
    });

    test('resolveServerTiming', () {
      var timing = APIServer.resolveServerTiming({
        'a': APIMetric('a', duration: Duration(microseconds: 1500)),
        'b': APIMetric('b', description: 'desc B', n: 3),
        'c': APIMetric('c', description: 'with "quote"'),
      }, ' prev;dur=1 ');

      expect(timing, equals('prev;dur=1, a;dur=1.5, b;desc="desc B";int=3, c'));

      expect(APIServer.resolveServerTiming({}, '  '), equals(''));
    });

    test('resolveBestTextMimeType', () {
      expect(APIServer.resolveBestTextMimeType('x', 'css'), equals('text/css'));
      expect(
        APIServer.resolveBestTextMimeType('<p>x</p>', 'unknownext123'),
        equals('text/html'),
      );
      expect(APIServer.resolveBestTextMimeType('a < b'), equals('text/plain'));
      expect(APIServer.resolveBestTextMimeType('abc'), equals('text/plain'));
    });

    test('resolveBody / resolveBodySync', () async {
      expect(APIServer.resolveBody(null, APIResponse.ok(null)), isNull);

      var r1 = APIResponse.ok(null);
      expect(
        await APIServer.resolveBody(Future.value('<b>x</b>'), r1),
        equals('<b>x</b>'),
      );
      expect(r1.payloadMimeType.toString(), equals('text/html'));

      expect(
        await APIServer.resolveBody(Future.value(null), APIResponse.ok(null)),
        isNull,
      );

      var rErr = await APIServer.resolveBody(
        Future<Object?>.error(StateError('fail')),
        APIResponse.ok(null),
      );
      expect(rErr, isA<APIResponse>());
      expect((rErr as APIResponse).status, equals(APIResponseStatus.ERROR));
      expect('${rErr.error}', contains('fail'));

      expect(
        () => APIServer.resolveBodySync(Future.value(1), APIResponse.ok(null)),
        throwsArgumentError,
      );
      expect(APIServer.resolveBodySync(null, APIResponse.ok(null)), isNull);

      var rBytes = APIResponse.ok(null);
      var bytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0];
      expect(APIServer.resolveBodySync(bytes, rBytes), same(bytes));
      expect(rBytes.payloadMimeType.toString(), equals('image/png'));

      var rStream = APIResponse.ok(null);
      var stream = Stream<List<int>>.fromIterable([
        [1, 2],
      ]);
      expect(APIServer.resolveBodySync(stream, rStream), same(stream));
      expect(
        rStream.payloadMimeType.toString(),
        equals('application/octet-stream'),
      );

      var rDate = APIResponse.ok(null);
      var d = DateTime.utc(2020, 1, 2, 3, 4, 5);
      expect(APIServer.resolveBodySync(d, rDate), equals(d.toString()));
      expect(rDate.payloadMimeType.toString(), equals('text/plain'));

      var rJson = APIResponse.ok(null);
      var jsonBytes = APIServer.resolveBodySync({'a': 1}, rJson) as List<int>;
      expect(utf8.decode(jsonBytes), equals('{"a":1}'));
      expect(rJson.payloadMimeType.toString(), equals('application/json'));
      expect(rJson.metrics.keys, contains('API-Response-JSON'));

      var rBig = APIResponse.ok(null);
      var big = List.generate(500, (i) => {'id': i, 'name': 'name $i'});
      var bigBytes = APIServer.resolveBodySync(big, rBig) as Uint8List;
      expect(rBig.headers['content-encoding'], equals('gzip'));
      expect(rBig.headers['X-Compression-Ratio'], isNotNull);
      expect(rBig.headers['server-timing'], contains('obj-json-gzip;dur='));
      var decoded = json.decode(utf8.decode(gzip.decode(bigBytes)));
      expect((decoded as List).length, equals(500));

      var rBig2 = APIResponse.ok(
        null,
        headers: {'server-timing': 'prev;dur=1'},
      );
      APIServer.resolveBodySync(big, rBig2);
      expect(
        rBig2.headers['server-timing'],
        startsWith('prev;dur=1,obj-json-gzip;dur='),
      );

      // With `compression`: negotiated with `acceptEncoding`:
      const compression = APIResponseCompression();

      var rBr = APIResponse.ok(null, headers: {'vary': 'Origin'});
      var brBytes = APIServer.resolveBodySync(
        big,
        rBr,
        compression: compression,
        acceptEncoding: 'gzip, br',
      ) as Uint8List;
      expect(rBr.headers['content-encoding'], equals('br'));
      expect(rBr.headers['vary'], equals('Origin, Accept-Encoding'));
      expect(rBr.headers['server-timing'], contains('obj-json-br;dur='));
      expect(rBr.headers['content-length'], equals('${brBytes.length}'));
      expect(
        (json.decode(utf8.decode(APIBrotli.decode(brBytes))) as List).length,
        equals(500),
      );

      var rGz = APIResponse.ok(null);
      var gzBytes = await APIServer.resolveBody(
        Future.value(big),
        rGz,
        compression: compression,
        acceptEncoding: 'gzip',
      ) as Uint8List;
      expect(rGz.headers['content-encoding'], equals('gzip'));
      expect(
        (json.decode(utf8.decode(gzip.decode(gzBytes))) as List).length,
        equals(500),
      );

      // Not accepted: not compressed (the legacy mode always uses GZip):
      for (var accept in [null, '', 'identity', 'br;q=0, gzip;q=0']) {
        var rNone = APIResponse.ok(null);
        var noneBytes = APIServer.resolveBodySync(
          big,
          rNone,
          compression: compression,
          acceptEncoding: accept,
        ) as Uint8List;
        expect(rNone.headers['content-encoding'], isNull, reason: '$accept');
        expect(rNone.headers['vary'], isNull, reason: '$accept');
        expect(
          (json.decode(utf8.decode(noneBytes)) as List).length,
          equals(500),
        );
      }

      // Disabled:
      var rOff = APIResponse.ok(null);
      APIServer.resolveBodySync(
        big,
        rOff,
        compression: APIResponseCompression.none,
        acceptEncoding: 'br, gzip',
      );
      expect(rOff.headers['content-encoding'], isNull);

      // Small JSON: not compressed:
      var rSmall = APIResponse.ok(null);
      APIServer.resolveBodySync(
        {'a': 1},
        rSmall,
        compression: compression,
        acceptEncoding: 'br',
      );
      expect(rSmall.headers['content-encoding'], isNull);

      expect(
        APIServer.exposeHeaders,
        equals(APICORSConfig.defaultExposeHeaders.join(', ')),
      );

      var rBad = APIResponse.ok(null);
      var cyclic = <Object?>[];
      cyclic.add(cyclic);
      var bad = APIServer.resolveBodySync(cyclic, rBad);
      expect(bad, isA<APIResponse>());
      expect((bad as APIResponse).status, equals(APIResponseStatus.ERROR));
    });

    test('setCORS / getOrigin', () {
      var req = APIRequest.get(
        '/x',
        headers: {'origin': 'http://localhost:8080'},
      );

      var res = APIResponse.ok('x', headers: {'vary': 'Accept-Encoding'});
      APIServer.setCORS(req, res);
      expect(
        res.headers['access-control-allow-origin'],
        equals('http://localhost:8080'),
      );
      expect(res.headers['vary'], equals('Accept-Encoding, Origin'));
      expect(res.headers['access-control-allow-headers'], contains('x-ijt'));
      expect(res.headers['access-control-allow-credentials'], equals('true'));
      expect(res.headers['access-control-max-age'], isNull);

      var res2 = APIResponse.ok('x', headers: {'vary': 'Accept, origin'});
      APIServer.setCORS(req, res2);
      expect(res2.headers['vary'], equals('Accept, origin'));

      var res3 = APIResponse.ok('x', headers: {'vary': '*'});
      APIServer.setCORS(req, res3);
      expect(res3.headers['vary'], equals('*'));

      var cors = APICORSConfig(
        allowOrigin: ['https://allowed.com'],
        allowMethods: [],
        allowHeaders: [],
        exposeHeaders: [],
        allowCredentials: false,
        maxAge: 300,
        varyOrigin: false,
      );

      var res4 = APIResponse.ok('x');
      APIServer.setCORS(req, res4, cors: cors);
      expect(res4.headers['access-control-allow-origin'], isNull);
      expect(res4.headers['vary'], isNull);
      expect(res4.headers['access-control-allow-methods'], isNull);
      expect(res4.headers['access-control-allow-credentials'], equals('false'));
      expect(res4.headers['access-control-expose-headers'], isNull);

      var reqOptions = APIRequest(
        APIRequestMethod.OPTIONS,
        '/x',
        headers: {'origin': 'https://allowed.com'},
      );
      var res5 = APIResponse.ok('');
      APIServer.setCORS(reqOptions, res5, cors: cors);
      expect(
        res5.headers['access-control-allow-origin'],
        equals('https://allowed.com'),
      );
      expect(res5.headers['access-control-max-age'], equals('300'));

      var reqHost = APIRequest(
        APIRequestMethod.GET,
        '/x',
        headers: {'host': 'foo.com:81'},
        requestedUri: Uri.parse('https://foo.com:81/x'),
      );
      expect(APIServer.getOrigin(reqHost), equals('https://foo.com:81/'));

      expect(
        APIServer.getOrigin(APIRequest.get('/x')),
        equals('http://localhost/'),
      );
    });
  });

  group('APIServer.toAPIRequest', () {
    Future<APIRequest> toAPIRequest(
      Request request, {
      bool cookieless = false,
      bool useSessionID = false,
      int? maxPayloadLength,
      bool? decompressPayload,
    }) async => await APIServer.toAPIRequest(
      request,
      cookieless: cookieless,
      useSessionID: useSessionID,
      maxPayloadLength: maxPayloadLength,
      decompressPayload: decompressPayload,
    );

    test('credentials', () async {
      var basic = await toAPIRequest(
        Request(
          'GET',
          Uri.parse('http://localhost/a'),
          headers: {
            'authorization': 'Basic ${base64.encode(utf8.encode('joe:123'))}',
          },
        ),
      );
      expect(basic.credential?.username, equals('joe'));

      var bearer = await toAPIRequest(
        Request(
          'GET',
          Uri.parse('http://localhost/a'),
          headers: {'authorization': 'Bearer TOKEN123'},
        ),
      );
      expect(bearer.credential?.token, equals('TOKEN123'));

      var unknown = await toAPIRequest(
        Request(
          'GET',
          Uri.parse('http://localhost/a'),
          headers: {'authorization': 'Custom abc'},
        ),
      );
      expect(unknown.credential, isNull);

      var noSpace = await toAPIRequest(
        Request(
          'GET',
          Uri.parse('http://localhost/a'),
          headers: {'authorization': 'Token'},
        ),
      );
      expect(noSpace.credential, isNull);

      expect(
        () => APIServer.toAPIRequest(
          Request(
            'GET',
            Uri.parse('http://localhost/a'),
            headers: {'authorization': 'Digest abc'},
          ),
          cookieless: false,
          useSessionID: false,
        ),
        throwsUnsupportedError,
      );
    });

    test('session cookies, keep-alive, multi-value params', () async {
      var withCookie = await toAPIRequest(
        Request(
          'GET',
          Uri.parse('http://localhost/a?x=1&x=2&y=3'),
          headers: {
            'cookie': 'foo=bar; SESSIONID=sess123; invalid',
            'connection': 'Keep-Alive',
          },
        ),
        useSessionID: true,
      );
      expect(withCookie.sessionID, equals('sess123'));
      expect(withCookie.newSession, isFalse);
      expect(withCookie.keepAlive, isTrue);
      expect(withCookie.parameters['x'], equals(['1', '2']));
      expect(withCookie.parameters['y'], equals('3'));
      expect(withCookie.protocol, equals('HTTP/1.1'));

      var newSession = await toAPIRequest(
        Request('GET', Uri.parse('http://localhost/a')),
        useSessionID: true,
      );
      expect(newSession.sessionID, isNotNull);
      expect(newSession.newSession, isTrue);

      var cookieless = await toAPIRequest(
        Request(
          'GET',
          Uri.parse('http://localhost/a'),
          headers: {'cookie': 'SESSIONID=abc'},
        ),
        cookieless: true,
        useSessionID: true,
      );
      expect(cookieless.sessionID, isNull);
      expect(cookieless.headers.containsKey('cookie'), isFalse);
    });

    test('payload: form-urlencoded', () async {
      var req = await toAPIRequest(
        Request(
          'POST',
          Uri.parse('http://localhost/a?q=1'),
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: 'a=1&b=x%20y&b=z&c=&&d',
        ),
      );
      expect(req.payload, isNull);
      expect(req.parameters['q'], equals('1'));
      expect(req.parameters['a'], equals('1'));
      expect(req.parameters['b'], equals(['x y', 'z']));
      expect(req.parameters['c'], equals(''));
      expect(req.parameters['d'], equals(''));

      var req2 = await toAPIRequest(
        Request(
          'POST',
          Uri.parse('http://localhost/a'),
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: 'a=1',
        ),
      );
      expect(req2.parameters, equals({'a': '1'}));
    });

    test('payload: JSON', () async {
      var ok = await toAPIRequest(
        Request(
          'POST',
          Uri.parse('http://localhost/a'),
          headers: {'content-type': 'application/json'},
          body: '{"a": [1, 2]}',
        ),
      );
      expect(
        ok.payload,
        equals({
          'a': [1, 2],
        }),
      );

      var invalid = await toAPIRequest(
        Request(
          'POST',
          Uri.parse('http://localhost/a'),
          headers: {'content-type': 'application/json'},
          body: '{invalid',
        ),
      );
      expect(invalid.payload, isNull);

      var blank = await toAPIRequest(
        Request(
          'POST',
          Uri.parse('http://localhost/a'),
          headers: {'content-type': 'application/json'},
          body: '   ',
        ),
      );
      expect(blank.payload, isNull);
    });

    test('payload: by extension, empty, latin1 fallback', () async {
      var byPath = await toAPIRequest(
        Request('POST', Uri.parse('http://localhost/file.json'), body: '[1]'),
      );
      expect(byPath.payload, equals([1]));
      expect(byPath.payloadMimeType?.isJSON, isTrue);

      var byQuery = await toAPIRequest(
        Request(
          'POST',
          Uri.parse('http://localhost/up?name=img.png'),
          body: [1, 2, 3],
        ),
      );
      expect(byQuery.payload, equals([1, 2, 3]));
      expect(byQuery.payloadMimeType.toString(), equals('image/png'));

      var emptyText = await toAPIRequest(
        Request(
          'POST',
          Uri.parse('http://localhost/a'),
          headers: {'content-type': 'text/plain'},
          body: '',
        ),
      );
      expect(emptyText.payload, equals(''));

      var emptyBytes = await toAPIRequest(
        Request(
          'POST',
          Uri.parse('http://localhost/a'),
          headers: {'content-type': 'application/octet-stream'},
          body: <int>[],
        ),
      );
      expect(emptyBytes.payload, isA<Uint8List>());
      expect((emptyBytes.payload as Uint8List), isEmpty);

      var latin = await toAPIRequest(
        Request(
          'POST',
          Uri.parse('http://localhost/a'),
          headers: {'content-type': 'text/plain; charset=utf-8'},
          body: [0x63, 0xE9, 0xFF],
        ),
      );
      expect(latin.payload, equals(latin1.decode([0x63, 0xE9, 0xFF])));

      var noPayload = await toAPIRequest(
        Request('GET', Uri.parse('http://localhost/a')),
      );
      expect(noPayload.payload, equals(''));
    });

    test('payload: multiple chunks + maxPayloadLength', () async {
      Request chunked() => Request(
        'POST',
        Uri.parse('http://localhost/a'),
        headers: {'content-type': 'application/octet-stream'},
        body: Stream<List<int>>.fromIterable([
          [1, 2, 3],
          [4, 5],
          [6],
        ]),
      );

      var req = await toAPIRequest(chunked());
      expect(req.payload, equals([1, 2, 3, 4, 5, 6]));

      await expectLater(
        toAPIRequest(chunked(), maxPayloadLength: 4),
        throwsStateError,
      );

      Request single() => Request(
        'POST',
        Uri.parse('http://localhost/a'),
        headers: {'content-type': 'application/octet-stream'},
        body: Stream<List<int>>.fromIterable([
          [1, 2, 3, 4, 5],
        ]),
      );

      await expectLater(
        toAPIRequest(single(), maxPayloadLength: 4),
        throwsStateError,
      );

      expect(
        () => APIServer.toAPIRequest(
          Request(
            'POST',
            Uri.parse('http://localhost/a'),
            headers: {'content-type': 'application/octet-stream'},
            body: List.filled(10, 1),
          ),
          cookieless: false,
          useSessionID: false,
          maxPayloadLength: 5,
        ),
        throwsStateError,
      );
    });

    test('payload: decompress', () async {
      var data = utf8.encode('hello world! ' * 20);

      Request compressed(String encoding, List<int> body) => Request(
        'POST',
        Uri.parse('http://localhost/a'),
        headers: {
          'content-type': 'application/octet-stream',
          'content-encoding': encoding,
        },
        body: body,
      );

      var g = await toAPIRequest(
        compressed('gzip', gzip.encode(data)),
        decompressPayload: true,
        maxPayloadLength: 1000,
      );
      expect(g.payload, equals(data));

      var gNoMax = await toAPIRequest(
        compressed('gzip', gzip.encode(data)),
        decompressPayload: true,
      );
      expect(gNoMax.payload, equals(data));

      var z = await toAPIRequest(
        compressed('deflate', zlib.encode(data)),
        decompressPayload: true,
      );
      expect(z.payload, equals(data));

      var identity = await toAPIRequest(
        compressed('identity', data),
        decompressPayload: true,
      );
      expect(identity.payload, equals(data));

      await expectLater(
        toAPIRequest(
          compressed('gzip', gzip.encode(data)),
          decompressPayload: true,
          maxPayloadLength: 100,
        ),
        throwsStateError,
      );

      await expectLater(
        toAPIRequest(
          compressed('deflate', zlib.encode(data)),
          decompressPayload: true,
          maxPayloadLength: 100,
        ),
        throwsStateError,
      );

      var br = await toAPIRequest(
        compressed('br', APIBrotli.encode(data)!),
        decompressPayload: true,
        maxPayloadLength: 1000,
      );
      expect(br.payload, equals(data));

      var brNoMax = await toAPIRequest(
        compressed('br', APIBrotli.encode(data)!),
        decompressPayload: true,
      );
      expect(brNoMax.payload, equals(data));

      // Uncompressed size (260) over the limit, compressed size under it:
      await expectLater(
        toAPIRequest(
          compressed('br', APIBrotli.encode(data)!),
          decompressPayload: true,
          maxPayloadLength: 100,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Brotli payload uncompressed size exceeds'),
          ),
        ),
      );

      // Corrupted Brotli stream:
      await expectLater(
        toAPIRequest(compressed('br', data), decompressPayload: true),
        throwsFormatException,
      );

      await expectLater(
        toAPIRequest(compressed('compress', data), decompressPayload: true),
        throwsUnsupportedError,
      );
    });
  });
}

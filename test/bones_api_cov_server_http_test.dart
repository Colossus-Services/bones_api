@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:bones_api/bones_api_server.dart';
import 'package:bones_api/bones_api_test_vm.dart';
import 'package:path/path.dart' as pack_path;
import 'package:shelf/shelf.dart' show Response;
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

class _CovHttpAPIRoot extends APIRoot {
  _CovHttpAPIRoot(String name, [dynamic apiConfig])
    : super(name, '1.0.2', apiConfig: apiConfig);

  @override
  Set<APIModule> loadModules() => {_CovHttpModule(this)};
}

/// An [APIRoot] that only loads its modules after [gate] completes.
class _CovLazyAPIRoot extends APIRoot {
  final Completer<void> gate;
  final bool fail;

  _CovLazyAPIRoot(String name, this.gate, {this.fail = false})
    : super(name, '1.0.3');

  @override
  Future<Set<APIModule>> loadModules() async {
    await gate.future;
    if (fail) {
      throw StateError('Modules loading failure');
    }
    return {_CovHttpModule(this)};
  }
}

Future<void> _waitPortOpen(int port) async {
  for (var i = 0; i < 200; ++i) {
    try {
      var socket = await Socket.connect('localhost', port);
      socket.destroy();
      return;
    } catch (_) {
      await Future.delayed(Duration(milliseconds: 10));
    }
  }
  throw StateError("Port not opened: $port");
}

class _CovHttpModule extends APIModule {
  _CovHttpModule(APIRoot apiRoot) : super(apiRoot, 'cov');

  @override
  void configure() {
    routes.any('ok', (request) => APIResponse.ok('OK:${request.method.name}'));

    routes.any(
      'json',
      (request) => APIResponse.ok({
        'a': 1,
        'b': [1, 2],
      }),
    );

    routes.any(
      'big',
      (request) => APIResponse.ok(
        List.generate(300, (i) => {'id': i, 'name': 'item $i'}),
      ),
    );

    routes.any(
      'redirect',
      (request) => APIResponse.redirect(Uri.parse('http://example.com/x')),
    );

    routes.any(
      'redirectBad',
      (request) => APIResponse<String>(
        APIResponseStatus.REDIRECT,
        payload: 'not-an-uri',
      ),
    );

    routes.any('notModified', (request) => APIResponse.notModified());

    routes.any(
      'authRealm',
      (request) => APIResponse.unauthorized(
        payload: 'need auth',
      ).requireAuthentication(type: 'Bearer', realm: 'Cov'),
    );

    routes.any(
      'authDefault',
      (request) => APIResponse.unauthorized(
        payload: 'need auth',
      ).requireAuthentication(type: ' ', realm: 'X'),
    );

    routes.any(
      'bad',
      (request) => APIResponse.badRequest(payload: 'bad input'),
    );

    routes.any(
      'error',
      (request) => APIResponse.error(
        error: 'boom',
        stackTrace: StackTrace.fromString('#0 fake'),
      ),
    );

    routes.any(
      'errorNoStack',
      (request) => APIResponse.error(error: 'boom-no-stack'),
    );

    routes.any('throwAsync', (request) async {
      await Future.delayed(Duration(milliseconds: 1));
      throw StateError('async failure');
    });

    routes.any('cyclic', (request) {
      var l = <Object?>[];
      l.add(l);
      return APIResponse.ok(l);
    });

    routes.any(
      'badError',
      (request) => APIResponse.badRequest(error: 'bad-error'),
    );

    routes.any('auth', (request) {
      request.authentication = APIAuthentication(
        APIToken('joe', token: 'TK123'),
        resumed: request.parameters['resumed'] == 'true',
      );
      return APIResponse.ok(
        'authenticated',
        headers: {
          if (request.parameters['preset'] == 'true') 'X-Access-Token': 'TK123',
        },
      );
    });

    routes.any('metrics', (request) {
      request.setMetric(
        'route-metric',
        duration: Duration(milliseconds: 2),
        description: 'Route',
      );
      return APIResponse.ok('with metrics');
    });

    routes.any(
      'etag',
      (request) => APIResponse.ok(
        'tagged',
        payloadETag: StrongEtag('abc'),
        cacheControl: CacheControl(maxAge: Duration(seconds: 30)),
        headers: {'server-timing': 'custom;dur=1'},
      ),
    );
  }
}

typedef _Res = ({int status, HttpHeaders headers, List<int> body});

Future<_Res> _request(
  String url, {
  String method = 'GET',
  Map<String, String>? headers,
  List<int>? body,
}) async {
  var client = HttpClient();
  client.autoUncompress = false;

  try {
    var req = await client.openUrl(method, Uri.parse(url));
    req.followRedirects = false;
    headers?.forEach(req.headers.set);
    if (body != null) req.add(body);

    var res = await req.close();
    var bytes = await res.expand((e) => e).toList();

    return (status: res.statusCode, headers: res.headers, body: bytes);
  } finally {
    client.close(force: true);
  }
}

String _bodyStr(_Res res) {
  var bytes = res.body;
  if (res.headers.value('content-encoding') == 'gzip') {
    bytes = gzip.decode(bytes);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

void main() {
  group('APIServer HTTP', () {
    late APIServer apiServer;

    setUpAll(() async {
      var port = await resolveFreePort(6100);

      apiServer = APIServer(
        _CovHttpAPIRoot('cov-http'),
        'localhost',
        port,
        useSessionID: true,
        cookieless: false,
        logToConsole: false,
        maxPayloadLength: 1024 * 64,
      );

      expect(await apiServer.start(), isTrue);
      // Already started:
      expect(await apiServer.start(), isTrue);
    });

    tearDownAll(() async {
      await apiServer.stop();
      expect(apiServer.isStopped, isTrue);
      expect(await apiServer.waitStopped(), isTrue);
    });

    test('ok + session cookie + keep-alive', () async {
      var res = await _request(
        '${apiServer.url}cov/ok',
        headers: {'connection': 'Keep-Alive'},
      );
      expect(res.status, equals(200));
      expect(_bodyStr(res), equals('OK:GET'));
      expect(res.headers.value('set-cookie'), startsWith('SESSIONID='));
      expect(res.headers.value('x-api-server-worker'), equals('0/1'));
      expect(res.headers.value('keep-alive'), equals('timeout=10, max=1000'));
      expect(
        res.headers.value('server'),
        equals('Bones_API/${BonesAPI.VERSION}'),
      );

      var res2 = await _request(
        '${apiServer.url}cov/ok',
        headers: {'cookie': 'SESSIONID=abc123'},
      );
      expect(res2.status, equals(200));
      expect(res2.headers.value('set-cookie'), isNull);
    });

    test('HEAD', () async {
      var res = await _request('${apiServer.url}cov/ok', method: 'HEAD');
      expect(res.status, equals(200));
      expect(res.body, isEmpty);
    });

    test('json + gzip', () async {
      var res = await _request('${apiServer.url}cov/json');
      expect(res.status, equals(200));
      expect(res.headers.contentType?.mimeType, equals('application/json'));
      expect(
        json.decode(_bodyStr(res)),
        equals({
          'a': 1,
          'b': [1, 2],
        }),
      );

      var res2 = await _request(
        '${apiServer.url}cov/big',
        headers: {'accept-encoding': 'gzip'},
      );
      expect(res2.status, equals(200));
      expect(res2.headers.value('content-encoding'), equals('gzip'));
      expect(res2.headers.value('x-compression-ratio'), isNotNull);
      expect((json.decode(_bodyStr(res2)) as List).length, equals(300));
    });

    test('redirect', () async {
      var res = await _request('${apiServer.url}cov/redirect');
      expect(res.status, equals(307));
      expect(res.headers.value('location'), equals('http://example.com/x'));
      expect(_bodyStr(res), contains("Redirecting to: <a href='http"));

      var res2 = await _request('${apiServer.url}cov/redirectBad');
      expect(res2.status, equals(400));
      expect(_bodyStr(res2), equals('Invalid redirect URL: not-an-uri'));
    });

    test('notModified', () async {
      var res = await _request('${apiServer.url}cov/notModified');
      expect(res.status, equals(304));
      expect(res.body, isEmpty);
    });

    test('unauthorized with WWW-Authenticate', () async {
      var res = await _request('${apiServer.url}cov/authRealm');
      expect(res.status, equals(401));
      expect(
        res.headers.value('www-authenticate'),
        equals('Bearer realm="Cov"'),
      );
      expect(_bodyStr(res), equals('need auth'));

      var res2 = await _request('${apiServer.url}cov/authDefault');
      expect(res2.status, equals(401));
      expect(res2.headers.value('www-authenticate'), equals('Basic realm="X"'));
    });

    test('bad request + errors', () async {
      var res = await _request('${apiServer.url}cov/bad');
      expect(res.status, equals(400));
      expect(_bodyStr(res), equals('bad input'));

      var res2 = await _request('${apiServer.url}cov/error');
      expect(res2.status, equals(500));
      expect(_bodyStr(res2), equals('boom\n#0 fake'));
      expect(res2.headers.contentType?.mimeType, equals('text/plain'));

      var res3 = await _request('${apiServer.url}cov/errorNoStack');
      expect(res3.status, equals(500));
      expect(_bodyStr(res3), equals('boom-no-stack'));

      var res4 = await _request('${apiServer.url}cov/throwAsync');
      expect(res4.status, equals(500));
      expect(_bodyStr(res4), contains('async failure'));

      var res5 = await _request('${apiServer.url}cov/cyclic');
      expect(res5.status, equals(500));
      expect(_bodyStr(res5), contains('ERROR while encoding payload to JSON'));
    });

    test('etag + cache-control + server-timing', () async {
      var res = await _request('${apiServer.url}cov/etag');
      expect(res.status, equals(200));
      expect(_bodyStr(res), equals('tagged'));
      expect(res.headers.value('etag'), equals('"abc"'));
      expect(res.headers.value('cache-control'), contains('max-age=30'));
      expect(res.headers.value('server-timing'), startsWith('custom;dur=1, '));
    });

    test('bad request with error', () async {
      var res = await _request('${apiServer.url}cov/badError');
      expect(res.status, equals(400));
      expect(_bodyStr(res), equals('bad-error'));
    });

    test('authentication: X-Access-Token', () async {
      var res = await _request('${apiServer.url}cov/auth');
      expect(res.status, equals(200));
      expect(res.headers.value('x-access-token'), equals('TK123'));

      // Sent by the client (request `Authorization`): not sent back.
      var res1 = await _request(
        '${apiServer.url}cov/auth',
        headers: {'authorization': 'Bearer TK123'},
      );
      expect(res1.status, equals(200));
      expect(res1.headers['x-access-token'], isNull);

      // Another token in the request `Authorization`: sent.
      var res1b = await _request(
        '${apiServer.url}cov/auth',
        headers: {'authorization': 'Bearer OTHER'},
      );
      expect(res1b.status, equals(200));
      expect(res1b.headers.value('x-access-token'), equals('TK123'));

      // Already set by the route: not duplicated.
      var res2 = await _request('${apiServer.url}cov/auth?preset=true');
      expect(res2.status, equals(200));
      expect(res2.headers['x-access-token'], equals(['TK123']));

      // Resumed session: always sent:
      var res3 = await _request(
        '${apiServer.url}cov/auth?resumed=true',
        headers: {'authorization': 'Bearer TK123'},
      );
      expect(res3.status, equals(200));
      expect(res3.headers.value('x-access-token'), equals('TK123'));
    });

    test('request metrics', () async {
      var res = await _request('${apiServer.url}cov/metrics');
      expect(res.status, equals(200));
      expect(res.headers.value('server-timing'), contains('route-metric;dur='));
      expect(res.headers.value('server-timing'), contains('desc="Route"'));
      expect(res.headers.value('server-timing'), contains('API-call;dur='));
    });

    test('OPTIONS', () async {
      var res = await _request(
        '${apiServer.url}cov/ok',
        method: 'OPTIONS',
        headers: {'origin': 'http://foo.com'},
      );
      expect(res.status, equals(200));
      expect(
        res.headers.value('access-control-allow-origin'),
        equals('http://foo.com'),
      );

      var res2 = await _request(
        '${apiServer.url}unknownModule/x',
        method: 'OPTIONS',
      );
      expect(res2.status, equals(404));
    });

    test('payload errors', () async {
      var res = await _request(
        '${apiServer.url}cov/ok',
        method: 'POST',
        headers: {'content-type': 'application/octet-stream'},
        body: List<int>.filled(1024 * 65, 1),
      );
      expect(res.status, equals(500));
      expect(_bodyStr(res), contains('ERROR processing request'));
      expect(_bodyStr(res), contains('exceeds `maxPayloadLength`'));

      // With `Content-Length`: rejected before reading the payload.
      var bigPayload = List<int>.filled(1024 * 65, 1);
      var res1 = await _request(
        '${apiServer.url}cov/ok',
        method: 'POST',
        headers: {
          'content-type': 'application/octet-stream',
          'content-length': '${bigPayload.length}',
        },
        body: bigPayload,
      );
      expect(res1.status, equals(500));
      expect(_bodyStr(res1), contains('METHOD: POST'));
      expect(_bodyStr(res1), contains('Content-Length: ${bigPayload.length}'));
      expect(_bodyStr(res1), contains('HEADERS:'));

      var res2 = await _request(
        '${apiServer.url}cov/ok',
        headers: {'authorization': 'Digest abc'},
      );
      expect(res2.status, equals(500));
      expect(_bodyStr(res2), contains('Unsupported `Authorization` type'));
    });

    test('getURL / getURLAsString / getURLAsByteArray', () async {
      var res = await getURL('${apiServer.url}cov/ok');
      expect(res.status, equals(200));
      expect(res.bodyAsString, equals('OK:GET'));

      var res2 = await getURL('${apiServer.url}cov/ok', method: 'POST');
      expect(res2.bodyAsString, equals('OK:POST'));

      var s = await getURLAsString('${apiServer.url}cov/ok', method: 'PUT');
      expect(s, equals('OK:PUT'));

      var bs = await getURLAsByteArray('${apiServer.url}cov/ok');
      expect(utf8.decode(bs!), equals('OK:GET'));

      var closedPort = await resolveFreePort(6900);
      expect(await getURLAsString('http://localhost:$closedPort/x'), isNull);
      expect(await getURLAsByteArray('http://localhost:$closedPort/x'), isNull);
    });
  });

  group('APIServer HTTP (cookieless + delay)', () {
    test('serverResponseDelay', () async {
      var port = await resolveFreePort(6200);

      var apiServer = APIServer(
        _CovHttpAPIRoot('cov-http-delay'),
        'localhost',
        port,
        cookieless: true,
        logToConsole: false,
        logQueue: true,
        serverResponseDelay: Duration(milliseconds: 20),
      );

      await apiServer.start();
      addTearDown(apiServer.stop);

      var init = DateTime.now();
      var res = await _request(
        '${apiServer.url}cov/ok',
        headers: {'cookie': 'SESSIONID=abc'},
      );
      var elapsed = DateTime.now().difference(init);

      expect(res.status, equals(200));
      expect(_bodyStr(res), equals('OK:GET'));
      expect(res.headers.value('set-cookie'), isNull);
      expect(
        res.headers.value(APIServer.headerXCookielessServer),
        equals(APIServer.headerXCookielessServerValue),
      );
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(20));
    });
  });

  group('APIServer initialization', () {
    test('request while initializing', () async {
      var port = await resolveFreePort(6500);
      var gate = Completer<void>();

      var apiServer = APIServer(
        _CovLazyAPIRoot('cov-http-lazy', gate),
        'localhost',
        port,
        logToConsole: false,
      );

      var startAsync = apiServer.start();
      expect(apiServer.isStarting, isTrue);

      await _waitPortOpen(port);

      var resAsync = _request('${apiServer.url}cov/ok');

      await Future.delayed(Duration(milliseconds: 50));
      gate.complete();

      expect(await startAsync, isTrue);
      expect(apiServer.isStarting, isFalse);

      var res = await resAsync;
      expect(res.status, equals(200));
      expect(_bodyStr(res), equals('OK:GET'));
      expect(
        res.headers.value('server-timing'),
        contains('APIServerWorker-initialization;dur='),
      );

      await apiServer.stop();
    });

    test('initialization failure', () async {
      var port = await resolveFreePort(6600);
      var gate = Completer<void>();

      var apiRoot = _CovLazyAPIRoot('cov-http-lazy-fail', gate, fail: true);

      var apiServer = APIServer(
        apiRoot,
        'localhost',
        port,
        logToConsole: false,
      );

      var startAsync = apiServer.start();

      await _waitPortOpen(port);

      var resAsync = _request('${apiServer.url}cov/ok');

      await Future.delayed(Duration(milliseconds: 50));
      gate.complete();

      var ok = await startAsync.then<bool>((ok) => ok, onError: (e) => false);
      expect(ok, isFalse);

      var res = await resAsync;
      expect(res.status, greaterThanOrEqualTo(500));

      await apiServer.stop();
      apiRoot.close();
    });

    test("Let's Encrypt without certificates", () async {
      var leDir = await Directory.systemTemp.createTemp('bones_api_cov_le_');
      var docRoot = await Directory.systemTemp.createTemp('bones_api_cov_le_');
      addTearDown(() async {
        await docRoot.delete(recursive: true);
        if (leDir.existsSync()) await leDir.delete(recursive: true);
      });

      var port = await resolveFreePort(6650);

      var apiRoot = _CovHttpAPIRoot('cov-http-le');

      var apiServer = APIServer(
        apiRoot,
        'localhost',
        port,
        securePort: port + 1,
        letsEncrypt: true,
        letsEncryptDirectory: leDir.path,
        domains: {'cov-test.local': docRoot.path},
        logToConsole: false,
      );

      expect(apiServer.canUseLetsEncrypt, isTrue);
      expect(apiServer.domains, equals(['cov-test.local']));
      expect(apiServer.toString(), contains('letsEncrypt: true @staging'));

      // No certificates in the directory and not allowed to request them
      // (no network access is attempted):
      var error = await apiServer.start().then<Object?>(
        (ok) => ok,
        onError: (e) => e,
      );
      expect(error, isA<StateError>());
      expect(
        '$error',
        contains(
          '`requestCertificate` is `false`, can\'t request certificates',
        ),
      );

      apiRoot.close();
    });

    test(
      "Let's Encrypt directory removed after the worker's constructor",
      () async {
        var leDir = await Directory.systemTemp.createTemp('bones_api_cov_le2_');
        var docRoot = await Directory.systemTemp.createTemp(
          'bones_api_cov_le2_',
        );
        addTearDown(() async {
          await docRoot.delete(recursive: true);
          if (leDir.existsSync()) await leDir.delete(recursive: true);
        });

        var port = await resolveFreePort(6670);

        var apiRoot = _CovHttpAPIRoot('cov-http-le2');
        addTearDown(apiRoot.close);

        // An `APIServer` creates its workers on `start` (each one resolving,
        // and creating, the directory): only a worker started after the
        // directory is removed reaches the check.
        var worker = APIServerWorker(
          0,
          apiRoot,
          name: 'LE',
          version: '1.0',
          address: 'localhost',
          port: port,
          securePort: port + 1,
          letsEncrypt: true,
          letsEncryptDirectory: leDir.path,
          domains: {'cov-test.local': docRoot.path},
        );

        expect(worker.canUseLetsEncrypt, isTrue);

        await leDir.delete(recursive: true);

        var error = await worker.start().then<Object?>(
          (ok) => ok,
          onError: (e) => e,
        );
        expect(error, isA<StateError>());
        expect('$error', contains("Let's Encrypt directory doesn't exists"));
      },
    );

    test('restricted CORS + log queue + properties', () async {
      var port = await resolveFreePort(6700);

      var apiRoot = _CovHttpAPIRoot(
        'cov-http-cors',
        APIConfig({
          'properties': {'cov.prop.str': 'x', 'cov.prop.num': 1, 'bad': []},
        }),
      );

      var apiServer = APIServer(
        apiRoot,
        'localhost',
        port,
        logToConsole: true,
        logQueue: false,
        crossOrigin: APICrossOriginConfig(
          api: APICORSConfig(
            allowOrigin: ['https://only.com'],
            allowMethods: [],
          ),
        ),
      );

      await apiServer.start();
      addTearDown(apiServer.stop);

      expect(APIPlatform.get().getProperty('cov.prop.str'), equals('x'));
      expect(APIPlatform.get().getProperty('cov.prop.num'), equals('1'));

      var res = await _request(
        '${apiServer.url}cov/ok',
        headers: {'origin': 'https://other.com'},
      );
      expect(res.status, equals(200));
      expect(res.headers.value('access-control-allow-origin'), isNull);
      expect(res.headers.value('access-control-allow-methods'), isNull);

      var res2 = await _request(
        '${apiServer.url}cov/ok',
        headers: {'origin': 'https://only.com'},
      );
      expect(
        res2.headers.value('access-control-allow-origin'),
        equals('https://only.com'),
      );
    });
  });

  group('APIServerWorker', () {
    late Directory docRoot;

    setUp(() async {
      docRoot = await Directory.systemTemp.createTemp('bones_api_cov_wk_');
      File(
        pack_path.join(docRoot.path, 'index.html'),
      ).writeAsStringSync('<html>WORKER</html>');
    });

    tearDown(() => docRoot.delete(recursive: true));

    test('direct usage', () async {
      var apiRoot = _CovHttpAPIRoot('cov-http-worker');
      addTearDown(apiRoot.close);

      var worker = APIServerWorker(
        1,
        apiRoot,
        name: 'W',
        version: '1.0',
        address: 'localhost',
        port: 6999,
        securePort: 7443,
        domains: {RegExp(r'.*'): docRoot, 'w.com': docRoot},
        totalWorkers: 2,
        cookieless: true,
        longLivedStaticFilesCached: ['/a.js', RegExp(r'\.png$')],
      );

      expect(worker.isMainWorker, isFalse);
      expect(worker.isAuxiliaryWorker, isTrue);
      expect(worker.hasMultipleWorkers, isTrue);
      expect(worker.workerDebugName, startsWith('APIServerWorker#'));
      expect(worker.serverName, equals('W/1.0'));

      var str = worker.toString();
      expect(str, startsWith('APIServerWorker{ apiRoot: cov-http-worker'));
      expect(str, contains('securePort: 7443'));
      expect(str, contains('letsEncrypt: false'));
      expect(str, contains('r/.*/='));
      expect(str, contains('`w.com`='));

      expect(worker.isLongLivedStaticFileCached('a.js'), isTrue);
      expect(worker.isLongLivedStaticFileCached('/img/x.png'), isTrue);
      expect(worker.isLongLivedStaticFileCached('/b.js'), isFalse);

      var withCookie = Response.ok(
        'x',
        headers: {'set-cookie': 'a=1', 'x-foo': 'bar'},
      );
      var noCookie = worker.removeStaticFileCookies(withCookie);
      expect(noCookie.headers['set-cookie'], isNull);
      expect(noCookie.headers['x-foo'], equals('bar'));

      var plain = Response.ok('x');
      expect(identical(worker.removeStaticFileCookies(plain), plain), isTrue);

      // Static file served through `APIRoot.call` (no shelf `Request`):
      var res = await apiRoot.call(
        APIRequest(
          APIRequestMethod.GET,
          '/index.html',
          requestedUri: Uri.parse('http://localhost/index.html'),
        ),
      );
      expect(res.status, equals(APIResponseStatus.OK));

      var worker2 = APIServerWorker(
        0,
        apiRoot,
        name: 'W2',
        version: '1.0',
        cookieless: false,
      );
      expect(worker2.isMainWorker, isTrue);
      expect(worker2.hasMultipleWorkers, isFalse);
      expect(worker2.toString(), isNot(contains('domains:')));
      expect(
        identical(worker2.removeStaticFileCookies(withCookie), withCookie),
        isTrue,
      );
    });
  });

  group('APIServer static files', () {
    late Directory docRoot;
    late APIServer apiServer;

    setUpAll(() async {
      docRoot = await Directory.systemTemp.createTemp('bones_api_cov_www_');

      File(
        pack_path.join(docRoot.path, 'index.html'),
      ).writeAsStringSync('<html><body>INDEX</body></html>');
      File(
        pack_path.join(docRoot.path, 'style.css'),
      ).writeAsStringSync('body { color: red; }');
      File(
        pack_path.join(docRoot.path, 'data.txt'),
      ).writeAsStringSync('DATA ' * 500);

      Directory(pack_path.join(docRoot.path, 'sub')).createSync();
      File(
        pack_path.join(docRoot.path, 'sub', 'index.html'),
      ).writeAsStringSync('<html><body>SUB</body></html>');

      var port = await resolveFreePort(6300);

      apiServer = APIServer(
        _CovHttpAPIRoot('cov-http-static'),
        'localhost',
        port,
        documentRoot: docRoot.path,
        cookieless: true,
        logToConsole: false,
        longLivedStaticFilesCached: ['/index.html', RegExp(r'\.css$')],
        longLivedStaticFilesCacheControl: 'max-age=7777',
        staticFilesCacheControl: 'max-age=11',
        crossOrigin: APICrossOriginConfig(
          staticFiles: APICrossOriginPolicies(
            embedderPolicy: 'require-corp',
            resourcePolicy: 'same-site',
          ),
        ),
      );

      await apiServer.start();
    });

    tearDownAll(() async {
      await apiServer.stop();
      await docRoot.delete(recursive: true);
    });

    test('long-lived + policies', () async {
      var res = await _request('${apiServer.url}index.html');
      expect(res.status, equals(200));
      expect(_bodyStr(res), contains('INDEX'));
      expect(res.headers.value('cache-control'), equals('max-age=7777'));
      expect(
        res.headers.value('cross-origin-embedder-policy'),
        equals('require-corp'),
      );
      expect(
        res.headers.value('cross-origin-opener-policy'),
        equals(APICrossOriginPolicies.defaultOpenerPolicy),
      );
      expect(
        res.headers.value('cross-origin-resource-policy'),
        equals('same-site'),
      );
      expect(
        res.headers.value(APIServer.headerXCookielessServer),
        equals(APIServer.headerXCookielessServerValue),
      );

      var res2 = await _request('${apiServer.url}style.css');
      expect(res2.status, equals(200));
      expect(res2.headers.value('cache-control'), equals('max-age=7777'));
      expect(res2.headers.value('cross-origin-opener-policy'), isNull);
      expect(
        res2.headers.value('cross-origin-resource-policy'),
        equals('same-site'),
      );

      var res3 = await _request(
        '${apiServer.url}data.txt',
        headers: {'accept-encoding': 'gzip'},
      );
      expect(res3.status, equals(200));
      expect(res3.headers.value('cache-control'), equals('max-age=11'));
      expect(_bodyStr(res3), startsWith('DATA DATA'));

      // Cached response:
      var res4 = await _request('${apiServer.url}data.txt');
      expect(res4.status, equals(200));
      expect(_bodyStr(res4), startsWith('DATA DATA'));

      var res5 = await _request('${apiServer.url}sub/');
      expect(res5.status, equals(200));
      expect(_bodyStr(res5), contains('SUB'));

      var res6 = await _request('${apiServer.url}missing.txt');
      expect(res6.status, equals(404));

      var res7 = await _request('${apiServer.url}missing.txt');
      expect(res7.status, equals(404));
    });
  });

  group('APIServer multiple workers', () {
    test('totalWorkers: 2', () async {
      var port = await resolveFreePort(6400);

      // Created in the test's `Zone` (not `Zone.root`): the `APIRoot` sent to
      // the worker `Isolate` holds no `Zone` (unsendable) before its
      // initialization.
      expect(identical(Zone.current, Zone.root), isFalse);
      var apiRoot = _CovHttpAPIRoot('cov-http-workers');

      var apiServer = APIServer(
        apiRoot,
        'localhost',
        port,
        totalWorkers: 2,
        logToConsole: false,
      );

      expect(apiServer.totalWorkers, equals(2));

      expect(await apiServer.start(), isTrue);

      var workers = <String>{};
      for (var i = 0; i < 10; ++i) {
        var res = await _request('${apiServer.url}cov/ok');
        expect(res.status, equals(200));
        expect(_bodyStr(res), equals('OK:GET'));
        workers.add(res.headers.value('x-api-server-worker')!);
      }

      expect(workers, everyElement(endsWith('/2')));

      await apiServer.stop();
      expect(apiServer.isStopped, isTrue);
    });

    test('totalWorkers: 2 (APIRoot initialized before start)', () async {
      var port = await resolveFreePort(6500);

      var apiRoot = _CovHttpAPIRoot('cov-http-workers-init');
      await apiRoot.ensureInitialized();
      var zoneField = apiRoot.currentAPIRequest;

      var apiServer = APIServer(
        apiRoot,
        'localhost',
        port,
        totalWorkers: 2,
        logToConsole: false,
      );

      // `prepareForIsolateCopy` (by `start`) makes it sendable:
      expect(await apiServer.start(), isTrue);

      for (var i = 0; i < 10; ++i) {
        var res = await _request('${apiServer.url}cov/ok');
        expect(res.status, equals(200));
        expect(_bodyStr(res), equals('OK:GET'));
      }

      // The main `Isolate` keeps its `ZoneField`:
      expect(apiRoot.currentAPIRequest, same(zoneField));

      await apiServer.stop();
      expect(apiServer.isStopped, isTrue);
    });
  });

  group('runTestAPIServer', () {
    test('with channel', () async {
      var controller = StreamChannelController<Object?>();
      var logs = <Object?>[];
      int? callbackPort;

      var serverAsync = runTestAPIServer(
        'cov-test-server',
        {'foo': 'bar'},
        (apiConfig) => _CovHttpAPIRoot('cov-http-test-server', apiConfig),
        channel: controller.local,
        portCallback: (port) => callbackPort = port,
        logPrintter: logs.add,
      );

      var port = await controller.foreign.stream.first as int;
      expect(callbackPort, equals(port));

      var res = await _request('http://localhost:$port/cov/ok');
      expect(res.status, equals(200));
      expect(_bodyStr(res), equals('OK:GET'));

      controller.foreign.sink.add('stop');

      var apiServer = await serverAsync;
      expect(apiServer.isStopped, isTrue);
      expect(apiServer.cookieless, isTrue);
      expect(apiServer.apiRoot.apiConfig['foo'], equals('bar'));

      // `stop`: the `APIRoot` is also closed (as on an unknown command):
      expect(apiServer.apiRoot.isClosed, isTrue);
      expect(APIRoot.getByName(apiServer.apiRoot.name), isNull);

      expect(logs.first, equals('** Resolving free port...'));
      expect(logs.join('\n'), contains('URL: http://localhost:$port/'));
      expect(logs.join('\n'), contains('API Server CMD: stop'));
    });

    test('invalid command', () async {
      var controller = StreamChannelController<Object?>();
      APIRoot? apiRoot;

      var serverAsync = runTestAPIServer(
        'cov-test-server2',
        {},
        (apiConfig) =>
            apiRoot = _CovHttpAPIRoot('cov-http-test-server2', apiConfig),
        channel: controller.local,
        logPrintter: (_) {},
      );

      var port = await controller.foreign.stream.first as int;
      expect(port, greaterThan(0));

      controller.foreign.sink.add('unknown');

      await expectLater(serverAsync, throwsUnsupportedError);

      // `runTestAPIServer` stops the server and closes its `APIRoot`:
      expect(apiRoot!.isClosed, isTrue);
      expect(APIRoot.getByName('cov-http-test-server2'), isNull);

      // The port is free again:
      var server = await HttpServer.bind('localhost', port);
      await server.close(force: true);
    });

    test('without channel', () async {
      var apiServer = await runTestAPIServer(
        'cov-test-server3',
        {},
        (apiConfig) => _CovHttpAPIRoot('cov-http-test-server3', apiConfig),
        cookieless: false,
        logPrintter: (_) {},
      );

      expect(apiServer.isStarted, isTrue);
      expect(apiServer.cookieless, isFalse);

      var res = await _request('${apiServer.url}cov/ok');
      expect(res.status, equals(200));

      await apiServer.stop();
    });
  });
}

@TestOn('vm')
import 'dart:convert' as convert;
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:bones_api/bones_api_console.dart';
import 'package:bones_api/bones_api_server.dart';
import 'package:mercury_client/mercury_client.dart' as mercury_client;
import 'package:path/path.dart' as pack_path;
import 'package:statistics/statistics.dart';
import 'package:test/test.dart';

part 'bones_api_test.reflection.g.dart';

void main() {
  group('APIRoot', () {
    final api = MyAPI();

    setUp(() {});

    test('api', () async {
      expect(APIRoot.get(singleton: true), equals(api));
      expect(APIRoot.getByName('Example'), equals(api));
      expect(APIRoot.getByName('Foo'), isNull);
      expect(APIRoot.getWithinName('ex'), equals(api));
      expect(APIRoot.getWithinName('foo'), isNull);

      expect(api.modules.length, equals(2));
      expect(api.modulesNames, equals(['base', 'info']));
      expect(api.getModule('base'), isNotNull);
      expect(api.getModule('info'), isNotNull);
      expect(api.getModule('X'), isNull);

      expect(api.defaultModuleName, isNull);
      expect(api.getModule('base')!.defaultRouteName, equals('404'));
    });

    test('basic', () async {
      {
        var resp = APIResponse<List>.unauthorized(error: "Not allowed")
            .requireAuthentication(require: true, type: 'Basic', realm: 'Foo');

        expect(resp, isA<APIResponse<List>>());
        expect(resp.error, equals("Not allowed"));
        expect(resp.requiresAuthentication, isTrue);
        expect(resp.authenticationType, equals('Basic'));
        expect(resp.authenticationRealm, equals('Foo'));

        var resp2 = resp.cast<Map>();

        expect(resp2, isA<APIResponse<Map>>());
        expect(resp2.error, equals("Not allowed"));
        expect(resp2.requiresAuthentication, isTrue);
        expect(resp2.authenticationType, equals('Basic'));
        expect(resp2.authenticationRealm, equals('Foo'));

        var resp3 = resp.cast<Map>(error: "Wow!");

        expect(resp3, isA<APIResponse<Map>>());
        expect(resp3.error, equals("Wow!"));
        expect(resp3.requiresAuthentication, isTrue);
        expect(resp3.authenticationType, equals('Basic'));
        expect(resp3.authenticationRealm, equals('Foo'));
      }

      {
        var resp = APIResponse<List>.unauthorized(payloadDynamic: "Not allowed")
            .requireAuthentication(require: true, type: 'Basic', realm: 'Foo');

        expect(resp, isA<APIResponse<List>>());
        expect(resp.payload, isNull);
        expect(resp.error, isNull);
        expect(resp.requiresAuthentication, isTrue);
        expect(resp.authenticationType, equals('Basic'));
        expect(resp.authenticationRealm, equals('Foo'));

        var resp2 = resp.cast<Map>();

        expect(resp2, isA<APIResponse<Map>>());
        expect(resp2.payload, isNull);
        expect(resp2.error, isNull);
        expect(resp2.requiresAuthentication, isTrue);
        expect(resp2.authenticationType, equals('Basic'));
        expect(resp2.authenticationRealm, equals('Foo'));

        var resp3 = resp.cast<Map>(error: "Wow!");

        expect(resp3, isA<APIResponse<Map>>());
        expect(resp3.payload, isNull);
        expect(resp3.error, equals("Wow!"));
        expect(resp3.requiresAuthentication, isTrue);
        expect(resp3.authenticationType, equals('Basic'));
        expect(resp3.authenticationRealm, equals('Foo'));
      }
    });

    test('foo[GET]', () async {
      var apiRequest = APIRequest.get('/base/foo');

      expect(apiRequest.pathParts, equals(['base', 'foo']));

      var res = await api.call(apiRequest);
      expect(res.toString(), equals('Hi[GET]!'));
      expect(
          res.toInfos(),
          equals(
              'APIResponse{ status: APIResponseStatus.OK, headers: {}, payloadLength: 8 }'));

      expect(res.payloadLength, equals(8));
    });

    test('foo[GET]', () async {
      var apiRequest = APIRequest.get('/base/foo');
      expect(apiRequest.pathParts, equals(['base', 'foo']));

      var res = await api.call(apiRequest);
      expect(res.toString(), equals('Hi[GET]!'));

      var res2 = await api.doCall(APIRequestMethod.GET, '/base/foo');

      expect(res2.toString(), equals(res.toString()));
    });

    test('pre-request', () async {
      var apiRequest = APIRequest.get('/pre-request/foo');

      expect(apiRequest.pathParts, equals(['pre-request', 'foo']));

      var res = await api.call(apiRequest);
      expect(res.toString(), equals('Pre request: /pre-request/foo'));
      expect(
          res.toInfos(),
          equals(
              'APIResponse{ status: APIResponseStatus.OK, headers: {}, payloadLength: 29 }'));

      expect(res.payloadLength, equals(29));
    });

    test('pos-request', () async {
      var apiRequest = APIRequest.get('/pos-request/bar');

      expect(apiRequest.pathParts, equals(['pos-request', 'bar']));

      var res = await api.call(apiRequest);
      expect(res.toString(), equals('Pos request: /pos-request/bar'));
      expect(
          res.toInfos(),
          equals(
              'APIResponse{ status: APIResponseStatus.OK, headers: {}, payloadLength: 29 }'));

      expect(res.payloadLength, equals(29));
    });

    test('foo[POST]', () async {
      var res =
          await api.call(APIRequest.post('/base/foo', parameters: {'a': 1}));
      expect(res.toString(), equals('Hi[POST]! {a: 1}'));
    });

    test('time', () async {
      var res = await api.call(APIRequest.post('/base/time'));
      expect(res.toString(),
          matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+$')));

      expect(
          res.toInfos(),
          equals(
              'APIResponse{ status: APIResponseStatus.OK, headers: {}, payloadLength: 26, payloadMimeType: text/plain }'),
          reason: 'Payload: <<${res.payload}>>');

      expect(res.payloadMimeType.toString(), equals('text/plain'));
    });

    test('404 module', () async {
      var res = await api.call(APIRequest.get('/service/baseX/foo'));
      expect(res.toString(),
          equals('NOT FOUND: No route for path "/service/baseX/foo"'));
    });

    test('404 route', () async {
      var res = await api.call(APIRequest.get('/base/bar'));
      expect(res.toString(), equals('404: /base/bar'));
    });

    test('unauthorized', () async {
      var res = await api.call(APIRequest.get('/base/auth'));
      expect(res.toString(), equals('APIResponseStatus.UNAUTHORIZED'));
    });

    test('error', () async {
      var res = await api.call(APIRequest.get('/base/err'));
      expect(res.toString(), contains('Bad state: Error!'));
    });

    test('put', () async {
      var res = await api.call(APIRequest.put('/base/put'));
      expect(res.toString(), equals('PUT'));
    });

    test('delete', () async {
      var res = await api.call(APIRequest.delete('/base/delete'));
      expect(res.toString(), equals('DELETE'));
    });

    test('patch', () async {
      var res = await api.call(APIRequest.patch('/base/patch'));
      expect(res.toString(), equals('PATCH'));
    });

    test('head', () async {
      var res = await api.call(APIRequest.head('/base/head'));
      expect(res.toString(), equals('HEAD'));
    });
  });

  group('APIRootStarter', () {
    test('fromInstance', () async {
      var starter = APIRootStarter<MyAPI>.fromInstance(MyAPI());

      expect(starter.isStarted, isFalse);
      expect(starter.isStopped, isFalse);

      expect(await starter.start(), isTrue);
      expect(starter.isStarted, isTrue);
      expect(starter.isStopped, isFalse);

      var api = starter.apiRoot;
      expect(api, isNotNull);

      var apiRequest = APIRequest.get('/base/foo');

      var res = await api!.call(apiRequest);
      expect(res.payload, equals('Hi[GET]!'));

      expect(starter.stop(), isTrue);
      expect(starter.isStopped, isTrue);
    });

    test('fromInstantiator', () async {
      var starterStatus = 0;

      var starter = APIRootStarter<MyAPI>.fromInstantiator(
          (apiConfig) => MyAPI.withConfig(apiConfig),
          apiConfig: () => APIConfig({'test': 'fromStarter'}),
          preInitializer: () {
            starterStatus = 1;
            return true;
          },
          stopper: () {
            starterStatus = -1;
            return true;
          });

      expect(starter.isStarted, isFalse);
      expect(starter.isStopped, isFalse);
      expect(starterStatus, equals(0));

      expect(await starter.start(), isTrue);
      expect(starter.isStarted, isTrue);
      expect(starter.isStopped, isFalse);
      expect(starterStatus, equals(1));

      var api = starter.apiRoot;
      expect(api, isNotNull);

      var apiRequest = APIRequest.get('/base/foo');

      var res = await api!.call(apiRequest);
      expect(res.payload, equals('Hi[GET]!'));

      expect(starter.stop(), isTrue);
      expect(starter.isStopped, isTrue);
      expect(starterStatus, equals(-1));
    });
  });

  group('APIServer', () {
    final api = MyAPI();

    final apiServer = APIServer(api, 'localhost', 5544,
        decompressPayload: true, maxPayloadLength: 100);

    setUp(() async {
      await apiServer.start();
    });

    test('parseDomains', () async {
      expect(APIServerConfig.parseDomains(MapEntry('', '')), isEmpty);

      expect(
          APIServerConfig.parseDomains(MapEntry('foo.com', '/var/www'))
              .map((key, value) => MapEntry(key, value.path)),
          equals({'foo.com': '/var/www'}));

      expect(
          APIServerConfig.parseDomains(
                  MapEntry('foo.com', Directory('/var/www0')))
              .map((key, value) => MapEntry(key, value.path)),
          equals({'foo.com': '/var/www0'}));

      expect(
          APIServerConfig.parseDomains('foo.com=/var/www&bar.com=/var/www2')
              .map((key, value) => MapEntry(key, value.path)),
          equals({'foo.com': '/var/www', 'bar.com': '/var/www2'}));

      expect(
          APIServerConfig.parseDomains(
                  r'r/(\w+\.)?foo.com/=/var/www&bar.com=/var/www2')
              .map((key, value) => MapEntry(key, value.path)),
          equals({
            RegExp(r'(\w+\.)?foo.com'): '/var/www',
            'bar.com': '/var/www2'
          }));

      expect(
          APIServerConfig.parseDomains('bar.com=/var/www2')
              .map((key, value) => MapEntry(key, value.path)),
          equals({'bar.com': '/var/www2'}));
    });

    test('foo[GET] /base', () async {
      var res = await _getURL('${apiServer.url}base/foo');
      expect(res.toString(), equals('(200, Hi[GET]!)'));
    });

    test('foo[POST] /base', () async {
      var res = await _getURL('${apiServer.url}base/foo',
          method: APIRequestMethod.POST, parameters: {'a': 1});
      expect(res.toString(), equals('(200, Hi[POST]! {a: 1})'));
    });

    test('time /base', () async {
      var res = await _getURL('${apiServer.url}base/time',
          method: APIRequestMethod.POST, expectedContentType: 'text/plain');
      expect(
          res.toString(),
          matches(
              RegExp(r'^\(200, \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\)$')));
    });

    test('404 module /base', () async {
      var res = await _getURL('${apiServer.url}baseX/foo',
          method: APIRequestMethod.GET);
      expect(res.toString(),
          equals('(404, NOT FOUND: No route for path "/baseX/foo")'));
    });

    test('404 route /base', () async {
      var res = await _getURL('${apiServer.url}base/bar',
          method: APIRequestMethod.GET);
      expect(res.toString(), equals('(404, 404: /base/bar)'));
    });

    test('unauthorized /base', () async {
      var res = await _getURL('${apiServer.url}base/auth',
          method: APIRequestMethod.GET);
      expect(res.toString(), equals('(403, Forbidden)'));
    });

    test('error /base', () async {
      var res = await _getURL('${apiServer.url}base/err',
          method: APIRequestMethod.GET);
      expect(res.$1, equals(500));
      expect(res.toString(), contains('Bad state: Error!'));
    });

    test('put /base', () async {
      var res = await _getURL('${apiServer.url}base/put',
          method: APIRequestMethod.PUT);
      expect(res.toString(), equals('(200, PUT)'));
    });

    test('delete /base', () async {
      var res = await _getURL('${apiServer.url}base/delete',
          method: APIRequestMethod.DELETE);
      expect(res.toString(), equals('(200, DELETE)'));
    });

    test('patch /base', () async {
      var res = await _getURL('${apiServer.url}base/patch',
          method: APIRequestMethod.PATCH);
      expect(res.toString(), equals('(200, PATCH)'));
    });

    test('head /base', () async {
      var res = await _getURL('${apiServer.url}base/head',
          method: APIRequestMethod.HEAD);
      expect(res.toString(), equals('(200, )'));
    });

    test('upload(bytes) /base', () async {
      var res = await _getURL('${apiServer.url}base/upload',
          method: APIRequestMethod.POST,
          payload: List.generate(64, (i) => i),
          payloadType: 'application/octet-stream');
      expect(
          res.toString(),
          equals(
              '(200, Payload> mimeType: application/octet-stream ; length: 64)'));
    });

    test('upload(json) /base', () async {
      var res = await _getURL('${apiServer.url}base/upload',
          method: APIRequestMethod.POST,
          payload: convert.JsonUtf8Encoder().convert({
            'á': 1,
            'b': [2, 20]
          }),
          payloadType: 'application/json');
      expect(
          res.toString(),
          equals(
              '(200, Payload> mimeType: application/json ; length: 19<<{á: 1, b: [2, 20]}>>)'));
    });

    test('upload(text:utf8) /base', () async {
      var res = await _getURL('${apiServer.url}base/upload',
          method: APIRequestMethod.POST,
          payload: convert.utf8.encode('utf8: áÁ'),
          payloadType: 'text/plain');
      expect(
          res.toString(),
          equals(
              '(200, Payload> mimeType: text/plain ; length: 10<<utf8: áÁ>>)'));
    });

    test('upload(text:latin1) /base', () async {
      var res = await _getURL('${apiServer.url}base/upload',
          method: APIRequestMethod.POST,
          payload: convert.utf8.encode('utf8: áÁ'),
          payloadType: 'text/plain; charset=latin1');
      expect(
          res.toString(),
          equals(
              '(200, Payload> mimeType: text/plain; charset=latin1 ; length: 14<<utf8: Ã¡Ã>>)'));
    });

    test('upload(text:latin1) /base', () async {
      var res = await _getURL('${apiServer.url}base/upload',
          method: APIRequestMethod.POST,
          payload: convert.latin1.encode('utf8: áÁ'),
          payloadType: 'text/plain; charset=latin1');
      expect(
          res.toString(),
          equals(
              '(200, Payload> mimeType: text/plain; charset=latin1 ; length: 10<<utf8: áÁ>>)'));
    });

    test('payload(Hello World!) /base', () async {
      var res = await _getURL('${apiServer.url}base/payload',
          method: APIRequestMethod.POST,
          payload: convert.utf8.encode('Hello World!'),
          payloadType: 'text/plain');
      expect(res.toString(), equals('(200, PAYLOAD: 12 <<Hello World!>>)'));
    });

    test('payload(empty) /base', () async {
      var res = await _getURL('${apiServer.url}base/payload',
          method: APIRequestMethod.POST,
          payload: Uint8List(0),
          payloadType: 'application/octet-stream');
      expect(res.toString(), equals('(200, PAYLOAD: empty)'));
    });

    test('payload+gzip(Hello World With GZip!) /base', () async {
      var payload = convert.utf8.encode('Hello World With GZip!');
      var payloadGZip = GZipEncoder().encode(payload);

      var res = await _getURL('${apiServer.url}base/payload',
          method: APIRequestMethod.POST,
          headers: {'Content-Encoding': 'gzip'},
          payload: payloadGZip,
          payloadType: 'text/plain');
      expect(res.toString(),
          equals('(200, PAYLOAD: 22 <<Hello World With GZip!>>)'));
    });

    test('payload(large content) /base', () async {
      const largePayload =
          'This is a large content, over maxPayloadLength: 100> ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
      var res = await _getURL('${apiServer.url}base/payload',
          method: APIRequestMethod.POST,
          payload: convert.utf8.encode(largePayload),
          payloadType: 'text/plain');
      expect(
          res.toString(),
          allOf(startsWith('(500, ERROR processing request:'),
              contains('Payload size (115) exceeds `maxPayloadLength` (100)')));
    });

    test('payload+gzip /base', () async {
      const content =
          'This is a normal content: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      var payload = convert.utf8.encode(content);
      var payloadGZip = GZipEncoder().encode(payload);

      var res = await _getURL('${apiServer.url}base/payload',
          method: APIRequestMethod.POST,
          headers: {'Content-Encoding': 'gzip'},
          payload: payloadGZip,
          payloadType: 'text/plain');
      expect(
          res.toString(),
          equals(
              '(200, PAYLOAD: 90 <<This is a normal content: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA>>)'));
    });

    test('payload+gzip(large content) /base', () async {
      const largePayload =
          'This is a large content: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      var payload = convert.utf8.encode(largePayload);
      var payloadGZip = GZipEncoder().encode(payload);

      var res = await _getURL('${apiServer.url}base/payload',
          method: APIRequestMethod.POST,
          headers: {'Content-Encoding': 'gzip'},
          payload: payloadGZip,
          payloadType: 'text/plain');
      expect(
          res.toString(),
          allOf(
              startsWith('(500, ERROR processing request:'),
              contains(
                  "Can't decompress payload of size 48: GZip payload uncompressed size (117) exceeds `maxPayloadLength` (100).")));
    });

    test('payload+zlib /base', () async {
      const largePayload =
          'This is a large content: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      var payload = convert.utf8.encode(largePayload);
      var payloadZlib = ZLibEncoder().encode(payload);

      var res = await _getURL('${apiServer.url}base/payload',
          method: APIRequestMethod.POST,
          headers: {'Content-Encoding': 'deflate'},
          payload: payloadZlib,
          payloadType: 'text/plain');
      expect(
          res.toString(),
          equals(
              '(200, PAYLOAD: 89 <<This is a large content: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA>>)'));
    });

    test('payload+zlib(large content) /base', () async {
      const largePayload =
          'This is a large content: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      var payload = convert.utf8.encode(largePayload);
      var payloadZlib = ZLibEncoder().encode(payload);

      var res = await _getURL('${apiServer.url}base/payload',
          method: APIRequestMethod.POST,
          headers: {'Content-Encoding': 'deflate'},
          payload: payloadZlib,
          payloadType: 'text/plain');
      expect(
          res.toString(),
          allOf(
              startsWith('(500, ERROR processing request:'),
              contains(
                  "Decompressed `deflate` payload size (117) exceeds `maxPayloadLength` (100)")));
    });

    test('get /info', () async {
      var res = await _getURL('${apiServer.url}info/echo',
          method: APIRequestMethod.GET, parameters: {'msg': 'Hello!'});

      expect(res.toString(),
          equals('(200, [method: GET ; msg: HELLO! ; agent: BonesAPI/Test])'));

      var res2 = await _getURL('${apiServer.url}info/echo',
          method: APIRequestMethod.POST, parameters: {'msg': 'Hello!'});

      expect(res2.toString(),
          equals('(200, [method: POST ; msg: HELLO! ; agent: BonesAPI/Test])'));
    });

    test('proxy: toUpperCase', () async {
      var infoProxy = MyInfoModuleProxy(
          mercury_client.HttpClient(apiServer.url, _MyHttpClientRequester()));

      expect(await infoProxy.toUpperCase('abc'), equals('Upper case: ABC'));

      expect(await infoProxy.toUpperCase('abc X'), equals('Upper case: ABC X'));

      expect(await infoProxy.toUpperCase('AAA'), equals('Upper case: AAA'));
    });

    test('proxy: withPayload', () async {
      var infoProxy = MyInfoModuleProxy(
          mercury_client.HttpClient(apiServer.url, _MyHttpClientRequester()));

      expect(await infoProxy.withPayload(null), equals('Payload length: -1'));

      expect(await infoProxy.withPayload([0, 1, 2, 3].asUint8List),
          equals('Payload length: 4'));

      expect(await infoProxy.withPayload([0].asUint8List),
          equals('Payload length: 1'));

      expect(await infoProxy.withPayload(<int>[].asUint8List),
          equals('Payload length: 0'));
    });

    test('proxy: mapKeys', () async {
      var infoProxy = MyInfoModuleProxy(
          mercury_client.HttpClient(apiServer.url, _MyHttpClientRequester()));

      expect(await infoProxy.mapKeys({'a': 1, 'b': '2', 'c': true}),
          equals(['a', 'b', 'c']));
    });

    test('proxy: listMultiplier', () async {
      var infoProxy = MyInfoModuleProxy(
          mercury_client.HttpClient(apiServer.url, _MyHttpClientRequester()));

      expect(
          await infoProxy.listMultiplier([1, 2, 3], 10), equals([10, 20, 30]));
    });

    test('/API-INFO', () async {
      var res = await _getURL('${apiServer.url}API-INFO');

      var expectedInfo = '(200, {"name":"example","version":"1.0","modules":['
          '{"name":"base","routes":['
          '{"name":"time","uri":"http://localhost:0/base/time"},'
          '{"name":"auth","uri":"http://localhost:0/base/auth"},'
          '{"name":"404","uri":"http://localhost:0/base/404"},'
          '{"name":"err","uri":"http://localhost:0/base/err"},'
          '{"name":"foo","method":"GET","uri":"http://localhost:0/base/foo"},'
          '{"name":"foo","method":"POST","uri":"http://localhost:0/base/foo"},'
          '{"name":"upload","method":"POST","uri":"http://localhost:5544/base/upload"},'
          '{"name":"payload","method":"POST","uri":"http://localhost:5544/base/payload"},'
          '{"name":"patch","method":"PATCH","uri":"http://localhost:0/base/patch"},'
          '{"name":"put","method":"PUT","uri":"http://localhost:0/base/put"},'
          '{"name":"delete","method":"DELETE","uri":"http://localhost:0/base/delete"}'
          ']},'
          '{"name":"info","routes":['
          '{"name":"echo","parameters":{"msg":"String"},"uri":"http://localhost:0/info/echo?msg=String"},'
          '{"name":"listMultiplier","parameters":{"list":"List<int>","m":"int"},"uri":"http://localhost:5544/info/listMultiplier?list=List%3Cint%3E&m=int"},'
          '{"name":"mapKeys","parameters":{"map":"Map<String,dynamic>"},"uri":"http://localhost:5544/info/mapKeys?map=Map%3CString%2Cdynamic%3E"},'
          '{"name":"toUpperCase","parameters":{"msg":"String"},"uri":"http://localhost:0/info/toUpperCase?msg=String"},'
          '{"name":"withPayload","parameters":{"payload":"Uint8List"},"uri":"http://localhost:5544/info/withPayload?payload=Uint8List"}'
          ']}'
          ']})';

      expectedInfo = expectedInfo.replaceAll(
          'localhost:0', '${apiServer.address}:${apiServer.port}');

      expect(res.toString(), equals(expectedInfo));
    });

    tearDownAll(() async {
      await apiServer.stop();
    });
  });

  group('APIServer.create', () {
    final api = MyAPI();

    test('create []', () async {
      var apiServer = APIServer.create(api);
      expect(apiServer, isNotNull);
      expect(apiServer.address, equals('localhost'));
      expect(apiServer.port, equals(8080));
    });

    test('create [localhost]', () async {
      var apiServer = APIServer.create(api, ['localhost']);
      expect(apiServer, isNotNull);
      expect(apiServer.address, equals('localhost'));
      expect(apiServer.port, equals(8080));
    });

    test('create [localhost, 5545]', () async {
      var apiServer = APIServer.create(api, ['localhost', '5545']);
      expect(apiServer, isNotNull);
      expect(apiServer.address, equals('localhost'));
      expect(apiServer.port, equals(5545));
    });

    test('create [0]', () async {
      var apiServer = APIServer.create(api, ['0']);
      expect(apiServer, isNotNull);
      expect(apiServer.address, equals('0.0.0.0'));
      expect(apiServer.port, equals(8080));
    });

    test('create [1]', () async {
      var apiServer = APIServer.create(api, ['1']);
      expect(apiServer, isNotNull);
      expect(apiServer.address, equals('localhost'));
      expect(apiServer.port, equals(8080));
    });

    test('create [8091]', () async {
      var apiServer = APIServer.create(api, ['8091']);
      expect(apiServer, isNotNull);
      expect(apiServer.address, equals('localhost'));
      expect(apiServer.port, equals(8091));
    });

    test('create [localhost, 5545]', () async {
      var apiServer =
          APIServer.create(api, ['--address', 'localhost', '-p', '5546']);
      expect(apiServer, isNotNull);
      expect(apiServer.address, equals('localhost'));
      expect(apiServer.port, equals(5546));
    });
  });

  group('APIServer.create + start + GET', () {
    final api = MyAPI();

    final apiServer = APIServer.create(api, ['localhost', '5545']);

    setUp(() async {
      await apiServer.start();
    });

    test('foo[GET]', () async {
      var res = await _getURL('${apiServer.url}base/foo');
      expect(res.toString(), equals('(200, Hi[GET]!)'));
    });

    tearDownAll(() async {
      await apiServer.stop();
    });
  });

  group('APIServer.run', () {
    final api = MyAPI();

    test('run + stop', () async {
      final apiServer =
          await APIServer.run(api, ['X', '5546'], argsOffset: 1, verbose: true);
      expect(apiServer, isNotNull);
      expect(apiServer.address, equals('localhost'));
      expect(apiServer.port, equals(5546));

      await apiServer.stop();
    });
  });

  group('APIServer + docRoot', () {
    final api = MyAPI();

    final apiServer = APIServer(
      api,
      'localhost',
      5544,
      documentRoot: _resolveServerDocRoot(),
    );

    setUp(() async {
      await apiServer.start();
    });

    test('foo[GET] /foo (404)', () async {
      var res = await _getURL('${apiServer.url}/foo');
      expect(res.toString(), equals('(404, Not Found)'));
    });

    test('foo[GET] /index.html', () async {
      var (status, data, headers) =
          await _getUrlAndHeaders('${apiServer.url}/index.html');
      expect(status, equals(200));
      expect(data, equals('<html>Hello World!</html>\n'));

      var lastModified = headers[HttpHeaders.lastModifiedHeader]?.firstOrNull;
      expect(lastModified, isNotEmpty);

      expect(headers['x-api-server-cache'], isNull);

      var (status2, data2, headers2) = await _getUrlAndHeaders(
          '${apiServer.url}/index.html',
          headers: {'If-Modified-Since': lastModified!});

      expect(status2, equals(304));
      expect(data2, equals(''));
      expect(headers2['x-api-server-cache'], isNotEmpty);

      var (status3, data3, headers3) =
          await _getUrlAndHeaders('${apiServer.url}/index.html');

      expect(status3, equals(200));
      expect(data3, equals(data));
      expect(headers3['x-api-server-cache'], isNotEmpty);
    });

    tearDownAll(() async {
      await apiServer.stop();
    });
  });

  group('APIConsole', () {
    final api = MyAPI();

    test('basic', () async {
      var apiConsole = APIConsole(api);

      expect(apiConsole.toString(), startsWith('APIConsole{'));

      var res1 = await apiConsole.processRequestLine('base/foo');
      expect(res1.toString(), equals('Hi[GET]!'));

      var res2 =
          await apiConsole.processRequestLine('base/foo --method post -a 1');
      expect(res2.toString(), equals('Hi[POST]! {a: 1}'));
    });

    test('run', () async {
      var apiConsole = APIConsole(api);

      var commandsConst = const [
        'base/foo',
        'base/foo --method post -a 2',
      ];

      var commands = commandsConst.toList();

      var responses = await apiConsole
          .run(() => commands.isNotEmpty ? commands.removeAt(0) : null);

      print(responses);

      expect(responses[0].toString(), equals('Hi[GET]!'));
      expect(responses[0].payloadLength, equals(8));

      expect(responses[1].toString(), equals('Hi[POST]! {a: 2}'));

      var onRequests = <APIRequest>[];
      var onResponses = <APIResponse>[];

      var commands2 = commandsConst.toList();

      var responses2 = await apiConsole.run(
          () => commands2.isNotEmpty ? commands2.removeAt(0) : null,
          onRequest: (req) => onRequests.add(req),
          onResponse: (res) => onResponses.add(res),
          returnResponses: false);

      print(onRequests);
      print(onResponses);

      expect(responses2, isEmpty);

      expect(onRequests.map((e) => e.path), equals(['base/foo', 'base/foo']));
      expect(onResponses.map((e) => '$e'),
          equals(['Hi[GET]!', 'Hi[POST]! {a: 2}']));
    });
  });
}

class MyAPI extends APIRoot {
  static MyAPI? _instance;

  factory MyAPI() => _instance ??= MyAPI.withConfig();

  MyAPI.withConfig([dynamic apiConfig])
      : super('example', '1.0',
            apiConfig: apiConfig,
            preApiRequestHandlers: [_preRequest],
            posApiRequestHandlers: [_posRequest]);

  static APIResponse<T>? _preRequest<T>(APIRoot apiRoot, APIRequest request) {
    if (request.pathPartFirst.startsWith('pre')) {
      return APIResponse.ok('Pre request: ${request.path}' as T);
    }
    return null;
  }

  static APIResponse<T>? _posRequest<T>(APIRoot apiRoot, APIRequest request) {
    if (request.pathPartFirst.startsWith('pos')) {
      return APIResponse.ok('Pos request: ${request.path}' as T);
    }
    return null;
  }

  @override
  Set<APIModule> loadModules() => {MyBaseModule(this), MyInfoModule(this)};
}

class MyBaseModule extends APIModule {
  MyBaseModule(APIRoot apiRoot) : super(apiRoot, 'base');

  @override
  String? get defaultRouteName => '404';

  @override
  void configure() {
    routes.get('foo', (request) => APIResponse.ok('Hi[GET]!'));
    routes.post(
        'foo', (request) => APIResponse.ok('Hi[POST]! ${request.parameters}'));

    routes.any('time',
        (request) => APIResponse.ok(DateTime.now(), mimeType: 'text/plain'));

    routes.any('auth', (request) => APIResponse.unauthorized());

    routes.any('404',
        (request) => APIResponse.notFound(payload: '404: ${request.path}'));

    routes.any('err', (request) => throw StateError('Error!'));

    routes.put('put', (request) => APIResponse.ok('PUT'));
    routes.delete('delete', (request) => APIResponse.ok('DELETE'));
    routes.patch('patch', (request) => APIResponse.ok('PATCH'));
    routes.head('head', (request) => APIResponse.ok('HEAD'));

    routes.post(
        'upload',
        (request) => APIResponse.ok('Payload> '
            'mimeType: ${request.payloadMimeType} ; '
            'length: ${request.payloadAsBytes?.length}'
            '${(request.payloadMimeType?.isStringType ?? false) ? '<<${request.payload}>>' : ''}'));

    routes.post('payload', (request) {
      var payloadBytes = request.payloadAsBytes;
      if (payloadBytes == null || payloadBytes.isEmpty) {
        return APIResponse.ok('PAYLOAD: empty');
      }

      var payloadStr = convert.utf8.decode(payloadBytes);
      return APIResponse.ok('PAYLOAD: ${payloadStr.length} <<$payloadStr>>');
    });
  }
}

@APIModuleProxy('MyInfoModule')
class MyInfoModuleProxy extends APIModuleProxyHttpCaller {
  MyInfoModuleProxy(super.httpClient) : super(moduleRoute: 'info');
}

@EnableReflection()
class MyInfoModule extends APIModule {
  MyInfoModule(APIRoot apiRoot) : super(apiRoot, 'info');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  FutureOr<APIResponse<String>> echo(String msg, APIRequest request) {
    var method = request.method.name;
    var agent = request.headers['user-agent'];
    var reply = '[method: $method ; msg: ${msg.toUpperCase()} ; agent: $agent]';
    return APIResponse.ok(reply);
  }

  FutureOr<APIResponse<String>> toUpperCase(String msg) {
    var reply = 'Upper case: ${msg.toUpperCase()}';
    return APIResponse.ok(reply);
  }

  FutureOr<APIResponse<String>> withPayload(Uint8List? payload) {
    var reply = 'Payload length: ${payload?.length ?? -1}';
    return APIResponse.ok(reply);
  }

  FutureOr<APIResponse<List<String>>> mapKeys(Map<String, dynamic> map) {
    return APIResponse.ok(map.keys.toList());
  }

  FutureOr<APIResponse<List<int>>> listMultiplier(List<int> list, int m) {
    return APIResponse.ok(list.map((n) => n * m).toList(), mimeType: 'json');
  }
}

Future<(int, String)> _getURL(String url,
    {APIRequestMethod? method,
    Map<String, dynamic>? parameters,
    Map<String, String>? headers,
    List<int>? payload,
    String? payloadType,
    String? expectedContentType}) async {
  var (status, content, _) = await _getUrlAndHeaders(url,
      method: method,
      parameters: parameters,
      headers: headers,
      payload: payload,
      payloadType: payloadType,
      expectedContentType: expectedContentType);
  return (status, content);
}

/// Simple HTTP get URL function.
Future<(int, String, HttpHeaders)> _getUrlAndHeaders(String url,
    {APIRequestMethod? method,
    Map<String, dynamic>? parameters,
    Map<String, String>? headers,
    List<int>? payload,
    String? payloadType,
    String? expectedContentType}) async {
  method ??= APIRequestMethod.GET;

  var uri = Uri.parse(url);

  if (parameters != null) {
    parameters = parameters.map((key, value) => MapEntry(key, '$value'));

    uri = Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: uri.path,
      fragment: uri.fragment,
      queryParameters: parameters,
    );
  }

  var httpClient = HttpClient();

  httpClient.userAgent = 'BonesAPI/Test';

  Future<HttpClientRequest> future;
  HttpClientResponse response;
  switch (method) {
    case APIRequestMethod.GET:
      {
        future = httpClient.getUrl(uri);
        break;
      }
    case APIRequestMethod.POST:
      {
        future = httpClient.postUrl(uri);
        break;
      }
    case APIRequestMethod.PUT:
      {
        future = httpClient.putUrl(uri);
        break;
      }
    case APIRequestMethod.DELETE:
      {
        future = httpClient.deleteUrl(uri);
        break;
      }
    case APIRequestMethod.PATCH:
      {
        future = httpClient.patchUrl(uri);
        break;
      }
    case APIRequestMethod.OPTIONS:
      {
        future = httpClient.openUrl('OPTIONS', uri);
        break;
      }
    case APIRequestMethod.HEAD:
      {
        future = httpClient.openUrl('HEAD', uri);
        break;
      }
  }

  response = await future.then((request) {
    if (headers != null && headers.isNotEmpty) {
      for (var e in headers.entries) {
        request.headers.add(e.key, e.value);
      }
    }

    if (payload != null) {
      if (payloadType != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, payloadType);
      }

      request.add(payload);
    }

    return request.close();
  });

  var status = response.statusCode;

  var responseHeaders = response.headers;

  if (expectedContentType != null) {
    var contentType = responseHeaders['content-type'];
    expect(contentType![0], expectedContentType);
  }

  var data = await response.transform(convert.Utf8Decoder()).toList();
  var body = data.join();

  return (status, body, responseHeaders);
}

class _MyHttpClientRequester extends mercury_client.HttpClientRequester {
  @override
  bool setupUserAgent(String? userAgent) => true;

  @override
  Future<mercury_client.HttpResponse> doHttpRequest(
      mercury_client.HttpClient client,
      mercury_client.HttpRequest request,
      mercury_client.ProgressListener? progressListener,
      bool log) async {
    (int, String) response;

    if (request.method == mercury_client.HttpMethod.POST) {
      response = await _getURL(
        request.requestURL,
        method: APIRequestMethod.POST,
        payload: request.sendData as List<int>?,
        payloadType: request.headerContentType,
      );
    } else {
      response = await _getURL(request.requestURL);
    }

    var responseContent = response.$2;

    return mercury_client.HttpResponse(
        mercury_client.getHttpMethod(request.method.name)!,
        request.url,
        request.requestURL,
        200,
        mercury_client.HttpBody.from(responseContent));
  }
}

Directory? _resolveServerDocRoot() {
  final dirName = 'server-doc-root';
  var possiblePaths = ['test', '.', '..', '../test'];

  for (var p in possiblePaths) {
    var dir = Directory(pack_path.join(p, dirName));
    if (dir.existsSync() &&
        dir.statSync().type == FileSystemEntityType.directory) {
      return dir;
    }
  }

  return null;
}

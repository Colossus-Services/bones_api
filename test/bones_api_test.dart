@TestOn('vm')
import 'dart:convert' as convert;
import 'dart:io';

import 'package:bones_api/bones_api_console.dart';
import 'package:bones_api/bones_api_server.dart';
import 'package:mercury_client/mercury_client.dart' as mercury_client;
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

    test('foo[GET]', () async {
      var apiRequest = APIRequest.get('/service/base/foo');

      expect(apiRequest.pathParts, equals(['service', 'base', 'foo']));

      var res = await api.call(apiRequest);
      expect(res.toString(), equals('Hi[GET]!'));
      expect(
          res.toInfos(),
          equals(
              'APIResponse{ status: APIResponseStatus.OK, headers: {}, payloadLength: 8 }'));

      expect(res.payloadLength, equals(8));
    });

    test('foo[GET]', () async {
      var apiRequest = APIRequest.get('/service/base/foo');
      expect(apiRequest.pathParts, equals(['service', 'base', 'foo']));

      var res = await api.call(apiRequest);
      expect(res.toString(), equals('Hi[GET]!'));

      var res2 = await api.doCall(APIRequestMethod.GET, '/service/base/foo');

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
      var res = await api
          .call(APIRequest.post('/service/base/foo', parameters: {'a': 1}));
      expect(res.toString(), equals('Hi[POST]! {a: 1}'));
    });

    test('time', () async {
      var res = await api.call(APIRequest.post('/service/base/time'));
      expect(res.toString(),
          matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+$')));

      expect(
          res.toInfos(),
          equals(
              'APIResponse{ status: APIResponseStatus.OK, headers: {}, payloadLength: 26, payloadMimeType: text/plain }'));

      expect(res.payloadMimeType, equals('text/plain'));
    });

    test('404 module', () async {
      var res = await api.call(APIRequest.get('/service/baseX/foo'));
      expect(res.toString(),
          equals('NOT FOUND: No route for path "/service/baseX/foo"'));
    });

    test('404 route', () async {
      var res = await api.call(APIRequest.get('/service/base/bar'));
      expect(res.toString(), equals('404: /service/base/bar'));
    });

    test('unauthorized', () async {
      var res = await api.call(APIRequest.get('/service/base/auth'));
      expect(res.toString(), equals('APIResponseStatus.UNAUTHORIZED'));
    });

    test('error', () async {
      var res = await api.call(APIRequest.get('/service/base/err'));
      expect(res.toString(), contains('Bad state: Error!'));
    });

    test('put', () async {
      var res = await api.call(APIRequest.put('/service/base/put'));
      expect(res.toString(), equals('PUT'));
    });

    test('delete', () async {
      var res = await api.call(APIRequest.delete('/service/base/delete'));
      expect(res.toString(), equals('DELETE'));
    });

    test('patch', () async {
      var res = await api.call(APIRequest.patch('/service/base/patch'));
      expect(res.toString(), equals('PATCH'));
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

      var apiRequest = APIRequest.get('/service/base/foo');

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

      var apiRequest = APIRequest.get('/service/base/foo');

      var res = await api!.call(apiRequest);
      expect(res.payload, equals('Hi[GET]!'));

      expect(starter.stop(), isTrue);
      expect(starter.isStopped, isTrue);
      expect(starterStatus, equals(-1));
    });
  });

  group('APIServer', () {
    final api = MyAPI();

    final apiServer = APIServer(api, 'localhost', 5544);

    setUp(() async {
      await apiServer.start();
    });

    test('parseDomains', () async {
      expect(APIServer.parseDomains(MapEntry('', '')), isNull);

      expect(
          APIServer.parseDomains(MapEntry('foo.com', '/var/www'))
              ?.map((key, value) => MapEntry(key, value.path)),
          equals({'foo.com': '/var/www'}));

      expect(
          APIServer.parseDomains(MapEntry('foo.com', Directory('/var/www0')))
              ?.map((key, value) => MapEntry(key, value.path)),
          equals({'foo.com': '/var/www0'}));

      expect(
          APIServer.parseDomains('foo.com=/var/www&bar.com=/var/www2')
              ?.map((key, value) => MapEntry(key, value.path)),
          equals({'foo.com': '/var/www', 'bar.com': '/var/www2'}));

      expect(
          APIServer.parseDomains(
                  r'r/(\w+\.)?foo.com/=/var/www&bar.com=/var/www2')
              ?.map((key, value) => MapEntry(key, value.path)),
          equals({
            RegExp(r'(\w+\.)?foo.com'): '/var/www',
            'bar.com': '/var/www2'
          }));

      expect(
          APIServer.parseDomains('bar.com=/var/www2')
              ?.map((key, value) => MapEntry(key, value.path)),
          equals({'bar.com': '/var/www2'}));
    });

    test('foo[GET] /base', () async {
      var res = await _getURL('${apiServer.url}service/base/foo');
      expect(res.toString(), equals('Hi[GET]!'));
    });

    test('foo[POST] /base', () async {
      var res = await _getURL('${apiServer.url}service/base/foo',
          method: APIRequestMethod.POST, parameters: {'a': 1});
      expect(res.toString(), equals('Hi[POST]! {a: 1}'));
    });

    test('time /base', () async {
      var res = await _getURL('${apiServer.url}service/base/time',
          method: APIRequestMethod.POST, expectedContentType: 'text/plain');
      expect(res.toString(),
          matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+$')));
    });

    test('404 module /base', () async {
      var res = await _getURL('${apiServer.url}service/baseX/foo',
          method: APIRequestMethod.GET);
      expect(res.toString(),
          equals('NOT FOUND: No route for path "/service/baseX/foo"'));
    });

    test('404 route /base', () async {
      var res = await _getURL('${apiServer.url}service/base/bar',
          method: APIRequestMethod.GET);
      expect(res.toString(), equals('404: /service/base/bar'));
    });

    test('unauthorized /base', () async {
      var res = await _getURL('${apiServer.url}service/base/auth',
          method: APIRequestMethod.GET);
      expect(res.toString(), equals('Forbidden'));
    });

    test('error /base', () async {
      var res = await _getURL('${apiServer.url}service/base/err',
          method: APIRequestMethod.GET);
      expect(res.toString(), contains('Bad state: Error!'));
    });

    test('put /base', () async {
      var res = await _getURL('${apiServer.url}service/base/put',
          method: APIRequestMethod.PUT);
      expect(res.toString(), equals('PUT'));
    });

    test('delete /base', () async {
      var res = await _getURL('${apiServer.url}service/base/delete',
          method: APIRequestMethod.DELETE);
      expect(res.toString(), equals('DELETE'));
    });

    test('patch /base', () async {
      var res = await _getURL('${apiServer.url}service/base/patch',
          method: APIRequestMethod.PATCH);
      expect(res.toString(), equals('PATCH'));
    });

    test('get /info', () async {
      var res = await _getURL('${apiServer.url}service/info/echo',
          method: APIRequestMethod.GET, parameters: {'msg': 'Hello!'});

      expect(res.toString(),
          equals('[method: GET ; msg: HELLO! ; agent: BonesAPI/Test]'));

      var res2 = await _getURL('${apiServer.url}service/info/echo',
          method: APIRequestMethod.POST, parameters: {'msg': 'Hello!'});

      expect(res2.toString(),
          equals('[method: POST ; msg: HELLO! ; agent: BonesAPI/Test]'));
    });

    test('proxy: toUpperCase', () async {
      var infoProxy = MyInfoModuleProxy(mercury_client.HttpClient(
          '${apiServer.url}service', _MyHttpClientRequester()));

      expect(await infoProxy.toUpperCase('abc'), equals('Upper case: ABC'));

      expect(await infoProxy.toUpperCase('abc X'), equals('Upper case: ABC X'));

      expect(await infoProxy.toUpperCase('AAA'), equals('Upper case: AAA'));
    });

    test('/API-INFO', () async {
      var res = await _getURL('${apiServer.url}API-INFO');

      var expectedInfo = '{"name":"example","version":"1.0","modules":['
          '{"name":"base","routes":['
          '{"name":"time","uri":"http://localhost:0/base/time"},'
          '{"name":"auth","uri":"http://localhost:0/base/auth"},'
          '{"name":"404","uri":"http://localhost:0/base/404"},'
          '{"name":"err","uri":"http://localhost:0/base/err"},'
          '{"name":"foo","method":"GET","uri":"http://localhost:0/base/foo"},'
          '{"name":"foo","method":"POST","uri":"http://localhost:0/base/foo"},'
          '{"name":"patch","method":"PATCH","uri":"http://localhost:0/base/patch"},'
          '{"name":"put","method":"PUT","uri":"http://localhost:0/base/put"},'
          '{"name":"delete","method":"DELETE","uri":"http://localhost:0/base/delete"}'
          ']},'
          '{"name":"info","routes":['
          '{"name":"echo","parameters":{"msg":"String"},"uri":"http://localhost:0/info/echo?msg=String"},'
          '{"name":"toUpperCase","parameters":{"msg":"String"},"uri":"http://localhost:0/info/toUpperCase?msg=String"}'
          ']}'
          ']}';

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
      var res = await _getURL('${apiServer.url}service/base/foo');
      expect(res.toString(), equals('Hi[GET]!'));
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
  }
}

@APIModuleProxy('MyInfoModule')
class MyInfoModuleProxy extends APIModuleHttpProxy {
  MyInfoModuleProxy(mercury_client.HttpClient httpClient)
      : super(httpClient, moduleRoute: 'info');
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
}

/// Simple HTTP get URL function.
Future<String> _getURL(String url,
    {APIRequestMethod? method,
    Map<String, dynamic>? parameters,
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
  }

  response = await future.then((request) => request.close());

  if (expectedContentType != null) {
    var contentType = response.headers['content-type'];
    expect(contentType![0], expectedContentType);
  }

  var data = await response.transform(convert.Utf8Decoder()).toList();
  var body = data.join();

  return body;
}

class _MyHttpClientRequester extends mercury_client.HttpClientRequester {
  @override
  Future<mercury_client.HttpResponse> doHttpRequest(
      mercury_client.HttpClient client,
      mercury_client.HttpRequest request,
      mercury_client.ProgressListener? progressListener,
      bool log) async {
    var responseContent = await _getURL(request.requestURL);
    return mercury_client.HttpResponse(
        mercury_client.getHttpMethod(request.method.name)!,
        request.url,
        request.requestURL,
        200,
        mercury_client.HttpBody.from(responseContent));
  }
}

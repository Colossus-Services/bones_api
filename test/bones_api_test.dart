import 'dart:convert' as convert;
import 'dart:io';

import 'package:bones_api/bones_api_server.dart';
import 'package:test/test.dart';

void main() {
  group('APIRoot', () {
    final api = MyAPI();

    setUp(() {});

    test('api', () async {
      expect(api.modules.length, equals(1));
      expect(api.modulesNames, equals(['base']));
      expect(api.getModule('base'), isNotNull);
      expect(api.getModule('X'), isNull);

      expect(api.defaultModuleName, isNull);
      expect(api.getModule('base')!.defaultRouteName, equals('404'));
    });

    test('foo[GET]', () async {
      var res = await api.call(APIRequest.get('/service/base/foo'));
      expect(res.toString(), equals('Hi[GET]!'));
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
    });

    test('404 module', () async {
      var res = await api.call(APIRequest.get('/service/baseX/foo'));
      expect(res.toString(), equals('APIResponseStatus.NOT_FOUND'));
    });

    test('404 route', () async {
      var res = await api.call(APIRequest.get('/service/base/bar'));
      expect(res.toString(), equals('404: /service/base/bar'));
    });
  });

  group('APIServer', () {
    final api = MyAPI();

    final apiServer = APIServer(api, 'localhost', 5544);

    setUp(() async {
      await apiServer.start();
    });

    test('foo[GET]', () async {
      var res = await _getURL('${apiServer.url}service/base/foo');
      expect(res.toString(), equals('Hi[GET]!'));
    });

    test('foo[POST]', () async {
      var res = await _getURL('${apiServer.url}service/base/foo',
          method: APIRequestMethod.POST, parameters: {'a': 1});
      expect(res.toString(), equals('Hi[POST]! {a: 1}'));
    });

    test('time', () async {
      var res = await _getURL('${apiServer.url}service/base/time',
          method: APIRequestMethod.POST);
      expect(res.toString(),
          matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+$')));
    });

    test('404 module', () async {
      var res = await _getURL('${apiServer.url}service/baseX/foo',
          method: APIRequestMethod.GET);
      expect(res.toString(), equals('Not Found'));
    });

    test('404 route', () async {
      var res = await _getURL('${apiServer.url}service/base/bar',
          method: APIRequestMethod.GET);
      expect(res.toString(), equals('404: /service/base/bar'));
    });

    tearDownAll(() async {
      apiServer.stop();
    });
  });
}

class MyAPI extends APIRoot {
  MyAPI() : super('example', '1.0');

  @override
  Set<APIModule> loadModules() => {MyBaseModule()};
}

class MyBaseModule extends APIModule {
  MyBaseModule() : super('base');

  @override
  String? get defaultRouteName => '404';

  @override
  void configure() {
    routes.get('foo', (request) => APIResponse.ok('Hi[GET]!'));
    routes.post(
        'foo', (request) => APIResponse.ok('Hi[POST]! ${request.parameters}'));

    routes.any('time', (request) => APIResponse.ok(DateTime.now()));

    routes.any('404',
        (request) => APIResponse.notFound(payload: '404: ${request.path}'));
  }
}

/// Simple HTTP get URL function.
Future<String> _getURL(String url,
    {APIRequestMethod? method, Map<String, dynamic>? parameters}) async {
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
    case APIRequestMethod.PATH:
      {
        future = httpClient.patchUrl(uri);
        break;
      }
  }

  response = await future.then((request) => request.close());

  var data = await response.transform(convert.Utf8Decoder()).toList();
  var body = data.join();
  return body;
}

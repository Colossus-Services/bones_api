import 'dart:convert' as convert;
import 'dart:io';

import 'package:bones_api/bones_api_server.dart';
import 'package:bones_api/src/bones_api_console.dart';
import 'package:test/test.dart';

void main() {
  group('Arguments', () {
    setUp(() {});

    test('Arguments.parseLine 1', () async {
      var args = Arguments.parseLine('x -a 1 -b 2 -f');

      print(args);

      expect(args.parameters, equals({'a': '1', 'b': '2'}));
      expect(args.flags, equals({'f'}));
      expect(args.args, equals(['x']));

      expect(args.toArgumentsLine(), equals('-f --a 1 --b 2'));
    });

    test('Arguments.parseLine 2', () async {
      var args = Arguments.parseLine('-a host -port 80 -v a b',
          abbreviations: {'a': 'address', 'v': 'verbose'}, flags: {'verbose'});

      expect(args.parameters, equals({'address': 'host', 'port': '80'}));
      expect(args.flags, equals({'verbose'}));
      expect(args.args, equals(['a', 'b']));

      expect(args.toArgumentsLine(), equals('-v --address host --port 80'));
      expect(args.toArgumentsLine(abbreviateFlags: false),
          equals('-verbose --address host --port 80'));

      expect(
          args.toArgumentsLine(
              abbreviateFlags: false, abbreviateParameters: true),
          equals('-verbose --a host --port 80'));
    });

    test('Arguments.parseLine 3', () async {
      var args = Arguments.parseLine('-a host -port 80 -list 1 -list 2 -v a b',
          abbreviations: {'a': 'address', 'v': 'verbose'}, flags: {'verbose'});

      expect(
          args.parameters,
          equals({
            'address': 'host',
            'port': '80',
            'list': ['1', '2']
          }));
      expect(args.flags, equals({'verbose'}));
      expect(args.args, equals(['a', 'b']));
    });

    test('Arguments.parseLine 3', () async {
      var args = Arguments.parseLine(
          '-a host -port 80 -list 1 -list 2 -list 3 -v a b',
          abbreviations: {'a': 'address', 'v': 'verbose'},
          flags: {'verbose'});

      expect(
          args.parameters,
          equals({
            'address': 'host',
            'port': '80',
            'list': ['1', '2', '3']
          }));
      expect(args.flags, equals({'verbose'}));
      expect(args.args, equals(['a', 'b']));

      expect(args.toArgumentsLine(),
          equals('-v --address host --port 80 --list 1 --list 2 --list 3'));
    });
  });

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
      expect(res.toString(), equals('APIResponseStatus.NOT_FOUND'));
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
          method: APIRequestMethod.POST, expectedContentType: 'text/plain');
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

    test('unauthorized', () async {
      var res = await _getURL('${apiServer.url}service/base/auth',
          method: APIRequestMethod.GET);
      expect(res.toString(), equals('Forbidden'));
    });

    test('error', () async {
      var res = await _getURL('${apiServer.url}service/base/err',
          method: APIRequestMethod.GET);
      expect(res.toString(), contains('Bad state: Error!'));
    });

    test('put', () async {
      var res = await _getURL('${apiServer.url}service/base/put',
          method: APIRequestMethod.PUT);
      expect(res.toString(), equals('PUT'));
    });

    test('delete', () async {
      var res = await _getURL('${apiServer.url}service/base/delete',
          method: APIRequestMethod.DELETE);
      expect(res.toString(), equals('DELETE'));
    });

    test('patch', () async {
      var res = await _getURL('${apiServer.url}service/base/patch',
          method: APIRequestMethod.PATCH);
      expect(res.toString(), equals('PATCH'));
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

      expect(
          onRequests.map((e) => '${e.path}'), equals(['base/foo', 'base/foo']));
      expect(onResponses.map((e) => '$e'),
          equals(['Hi[GET]!', 'Hi[POST]! {a: 2}']));
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

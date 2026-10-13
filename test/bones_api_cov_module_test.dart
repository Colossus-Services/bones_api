@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:mercury_client/mercury_client.dart' as mercury;
import 'package:statistics/statistics.dart'
    show Decimal, DynamicInt, DynamicNumber;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';
import 'bones_api_test_modules.dart';

class _ProxyModule extends APIModule {
  _ProxyModule(APIRoot apiRoot) : super(apiRoot, 'proxy');

  @override
  void configure() {
    routes.any(
      'hello',
      (request) =>
          APIResponse.ok('hello ${request.getParameter('name') ?? 'world'}'),
    );
    routes.any(
      'map',
      (request) => APIResponse.ok(<String, dynamic>{'a': 1, 'b': 'x'}),
    );
    routes.any('notFound', (request) => APIResponse.notFound());
    routes.any(
      'error',
      (request) => APIResponse.error(
        error: 'route error',
        stackTrace: StackTrace.current,
      ),
    );
    routes.any('errorNoStack', (request) => APIResponse.error(error: 'no st'));
  }
}

class _ProxyRoot extends APIRoot {
  _ProxyRoot() : super('cov-proxy-root', '1.0');

  @override
  Set<APIModule> loadModules() => {_ProxyModule(this)};
}

mercury.HttpResponse _httpResponse(
  int status,
  Object? body, [
  String? mimeType,
]) => mercury.HttpResponse(
  mercury.HttpMethod.GET,
  'http://localhost/x',
  'http://localhost/x',
  status,
  mercury.HttpBody.from(
    body,
    mimeType != null ? MimeType.parse(mimeType) : null,
  ),
);

void main() {
  group('APIRouteBuilder.resolveValueByType', () {
    setUpAll(() {
      // Ensure the reflections are registered:
      expect(Role.empty().reflection.className, equals('Role'));
      expect(RoleType.admin.reflection.name(), equals('admin'));
    });

    Object? resolve(TypeInfo t, Object? v) =>
        APIRouteBuilder.resolveValueByType(t, v);

    test('basic types', () {
      expect(resolve(TypeInfo.tInt, null), isNull);
      expect(resolve(TypeInfo.tInt, 5), equals(5));
      expect(resolve(TypeInfo.tInt, '12'), equals(12));
      expect(resolve(TypeInfo.tDouble, '1.5'), equals(1.5));
      expect(resolve(TypeInfo.tString, 12), equals('12'));
      expect(resolve(TypeInfo.tBool, 'true'), isTrue);
    });

    test('statistics types and Time', () {
      expect(
        resolve(TypeInfo.fromType(Decimal), '1.25'),
        equals(Decimal.parse('1.25')),
      );
      expect(
        resolve(TypeInfo.fromType(DynamicInt), '10'),
        equals(DynamicInt.fromInt(10)),
      );

      var n = resolve(TypeInfo.fromType(DynamicNumber), '2.5');
      expect(n, isA<DynamicNumber>());
      expect((n as DynamicNumber).toDouble(), equals(2.5));

      expect(
        resolve(TypeInfo.fromType(Time), '10:20:30'),
        equals(Time(10, 20, 30)),
      );
    });

    test('Uint8List', () {
      var t = TypeInfo.tUint8List;
      expect(resolve(t, [1, 2]), equals([1, 2]));
      expect(resolve(t, [1, 2]), isA<Uint8List>());
      expect(resolve(t, 'hex:0102'), equals([1, 2]));
      expect(resolve(t, 'base64:AQI='), equals([1, 2]));
      expect(
        resolve(t, 'data:application/octet-stream;base64,AQI='),
        equals([1, 2]),
      );
      expect(resolve(t, 'AQI='), equals([1, 2]));
      // Not Base64, but HEX:
      expect(resolve(t, '0a0'), equals([0x00, 0xa0]));
      // Invalid HEX after the prefix: falls back to the UTF-8 bytes.
      expect(resolve(t, 'hex:zz'), equals(utf8.encode('hex:zz')));
      expect(resolve(t, 'base64:!!'), equals(utf8.encode('base64:!!')));
      expect(resolve(t, 'zz!'), equals(utf8.encode('zz!')));
    });

    test('List', () {
      var t = TypeInfo<List<int>>.fromListType(int);
      expect(resolve(t, '1,2,3'), equals([1, 2, 3]));
      expect(resolve(t, ['1', '2']), equals([1, 2]));
      expect(resolve(t, ['1', '2']), isA<List<int>>());
      expect(resolve(t, <int>[3, 4]), equals([3, 4]));
    });

    test('Set', () {
      var t = TypeInfo<Set<int>>.fromSetType(int);
      expect(resolve(t, '1,2,2'), equals({1, 2}));
      expect(resolve(t, {'1', '2'}), equals({1, 2}));
      expect(resolve(t, {'1', '2'}), isA<Set<int>>());

      var tAny = TypeInfo.tSet;
      expect(resolve(tAny, '1,2'), equals({'1', '2'}));

      var tRole = TypeInfo<Set<Role>>.fromSetType(Role);
      var roles = resolve(tRole, [
        {'type': 'admin', 'enabled': true},
      ]);
      expect(roles, isA<Set>());
      expect((roles as Set<Role>).single.type, equals(RoleType.admin));

      var roles2 = resolve(tRole, {
        {'type': 'guest', 'enabled': true},
      });
      expect((roles2 as Set<Role>).single.type, equals(RoleType.guest));
    });

    test('Map', () {
      var t = TypeInfo<Map<String, int>>.fromMapType(String, int);
      var m = resolve(t, {'a': '1', 'b': '2'});
      expect(m, equals({'a': 1, 'b': 2}));
      expect(m, isA<Map<String, int>>());
    });

    test('entities and enums', () {
      var role = resolve(TypeInfo.fromType(Role), {
        'type': 'admin',
        'enabled': true,
        'id': 3,
      });
      expect(role, isA<Role>());
      expect((role as Role).id, equals(3));
      expect(role.type, equals(RoleType.admin));

      var role2 = resolve(TypeInfo.fromType(Role), role);
      expect(role2, same(role));

      expect(
        resolve(TypeInfo.fromType(RoleType), 'guest'),
        equals(RoleType.guest),
      );

      var roles = resolve(TypeInfo<List<Role>>.fromListType(Role), [
        {'type': 'admin', 'enabled': true},
        {'type': 'guest', 'enabled': false},
      ]);
      expect(roles, isA<List<Role>>());
      expect(
        (roles as List<Role>).map((e) => e.type).toList(),
        equals([RoleType.admin, RoleType.guest]),
      );

      var types = resolve(TypeInfo<List<RoleType>>.fromListType(RoleType), [
        'admin',
        'guest',
      ]);
      expect(types, equals([RoleType.admin, RoleType.guest]));
    });
  });

  group('APIModuleProxyCallerResponseError', () {
    test('with APIResponse', () {
      var st1 = StackTrace.current;
      var response = APIResponse.error(error: 'e1', stackTrace: st1);

      var e = APIModuleProxyCallerResponseError(
        'msg',
        response: response,
        responseError: 'other',
        responseStackTrace: StackTrace.empty,
        responseStatus: APIResponseStatus.ERROR,
        module: 'm',
        methodName: 'f',
        parameters: {'a': 1},
      );

      expect(e.apiResponse, same(response));
      expect(e.module, equals('m'));
      expect(e.methodName, equals('f'));
      expect(e.parameters, equals({'a': 1}));
      expect(
        e.runtimeTypeNameSafe,
        equals('APIModuleProxyCallerResponseError'),
      );
      expect(
        e.extraInfo,
        equals([response, 'other', StackTrace.empty, APIResponseStatus.ERROR]),
      );
      expect(
        e.toString(),
        startsWith('APIModuleProxyCallerResponseError: msg\n  -- e1'),
      );

      // Same error and stack-trace of the response are not repeated:
      var e2 = APIModuleProxyCallerResponseError(
        'msg',
        response: response,
        responseError: 'e1',
        responseStackTrace: st1,
      );
      expect(e2.extraInfo, equals([response]));
    });

    test('without APIResponse', () {
      var e = APIModuleProxyCallerResponseError(
        'msg: err',
        response: 'resp',
        responseError: 'err',
        responseStackTrace: StackTrace.empty,
        responseStatus: APIResponseStatus.NOT_FOUND,
      );
      expect(e.apiResponse, isNull);
      // `err` is already in the message:
      expect(
        e.extraInfo,
        equals(['resp', StackTrace.empty, APIResponseStatus.NOT_FOUND]),
      );

      var e2 = APIModuleProxyCallerResponseError('msg', responseError: 'err');
      expect(e2.extraInfo, equals(['err']));

      var e3 = APIModuleProxyCallerResponseError('only message');
      expect(e3.extraInfo, isEmpty);
      expect(
        e3.toString(),
        equals('APIModuleProxyCallerResponseError: only message'),
      );
    });
  });

  group('APIModuleProxyCaller', () {
    test('resolveTarget', () {
      var httpClient = mercury.HttpClient('http://localhost/');

      var listener = APIModuleProxyCaller.resolveTarget(
        httpClient,
        moduleName: '/mod/',
        responsesAsJson: false,
      );
      expect(listener, isA<APIModuleProxyHttpCaller>());
      var httpCaller = listener as APIModuleProxyHttpCaller;
      expect(httpCaller.modulePath, equals('mod'));
      expect(httpCaller.responsesAsJson, isFalse);
      expect(httpCaller.httpClient, same(httpClient));

      expect(APIModuleProxyCaller.resolveTarget(httpCaller), same(httpCaller));

      expect(() => APIModuleProxyCaller.resolveTarget('foo'), throwsStateError);

      var caller = APIModuleProxyCaller(httpClient, moduleName: 'mod2');
      expect(caller.moduleName, equals('mod2'));
      expect(
        (caller.targetListener as APIModuleProxyHttpCaller).modulePath,
        equals('mod2'),
      );
    });

    test('register/unregister target resolver', () {
      var custom = APIModuleProxyHttpCaller(
        mercury.HttpClient('http://localhost/'),
      );

      ClassProxyListener<T>? resolver<T>(
        Object target,
        String? moduleName,
        bool? responsesAsJson,
        APIModuleProxyResponseErrorHandler? errorHandler,
      ) => target == 'custom' ? custom as ClassProxyListener<T> : null;

      expect(APIModuleProxyCaller.registerTargetResolver(resolver), isTrue);
      try {
        expect(APIModuleProxyCaller.resolveTarget('custom'), same(custom));
      } finally {
        expect(APIModuleProxyCaller.unregisterTargetResolver(resolver), isTrue);
      }

      expect(APIModuleProxyCaller.unregisterTargetResolver(resolver), isFalse);
      expect(
        () => APIModuleProxyCaller.resolveTarget('custom'),
        throwsStateError,
      );
    });
  });

  group('APIModuleProxyDirectCaller', () {
    late _ProxyRoot root;

    setUp(() async {
      root = _ProxyRoot();
      await root.ensureInitialized();
    });

    tearDown(() {
      root.close();
      APIModuleProxyDirectCaller.defaultErrorHandler = null;
    });

    test('resolved from an APIRoot', () async {
      var caller = APIModuleProxyCaller(root, moduleName: 'proxy');
      var target = caller.targetListener;
      expect(target, isA<APIModuleProxyDirectCaller>());

      var direct = target as APIModuleProxyDirectCaller;
      expect(direct.api, same(root));
      expect(direct.moduleName, equals('proxy'));
      expect(direct.responsesAsJson, isTrue);

      var r = await direct.onCall(null, 'hello', {'name': 'joe'}, null);
      expect(r, equals('hello joe'));
    });

    test('responses', () async {
      var direct = APIModuleProxyDirectCaller(
        root,
        moduleName: 'proxy',
        credential: APICredential('joe'),
      );

      expect(
        await direct.onCall(null, 'hello', {}, TypeReflection.tString),
        equals('hello world'),
      );

      var map = await direct.onCall(
        null,
        'map',
        {},
        TypeReflection.tMapStringDynamic,
      );
      expect(map, equals({'a': 1, 'b': 'x'}));

      expect(await direct.onCall(null, 'notFound', {}, null), isNull);

      var noJson = APIModuleProxyDirectCaller(
        root,
        moduleName: 'proxy',
        responsesAsJson: false,
      );
      expect(
        await noJson.onCall(null, 'map', {}, TypeReflection.tMapStringDynamic),
        equals({'a': 1, 'b': 'x'}),
      );
    });

    test('errors', () async {
      var handled = <APIModuleProxyCallerResponseError>[];

      var direct = APIModuleProxyDirectCaller(
        root,
        moduleName: 'proxy',
        errorHandler: handled.add,
      );

      await expectLater(
        () async => await direct.onCall(null, 'error', {'x': 1}, null),
        throwsA(
          isA<APIModuleProxyCallerResponseError>()
              .having((e) => e.methodName, 'methodName', 'error')
              .having((e) => e.module, 'module', 'proxy')
              .having((e) => e.responseError, 'responseError', 'route error')
              .having(
                (e) => e.responseStatus,
                'responseStatus',
                APIResponseStatus.ERROR,
              ),
        ),
      );

      expect(handled.length, equals(1));
      expect(handled.single.message, equals('Response ERROR> route error'));

      // The default error handler, that throws (logged and ignored):
      var defaultHandled = 0;
      APIModuleProxyDirectCaller.defaultErrorHandler = (e) {
        defaultHandled++;
        throw StateError('handler failure');
      };

      var direct2 = APIModuleProxyDirectCaller(root, moduleName: 'proxy');
      await expectLater(
        () async => await direct2.onCall(null, 'errorNoStack', {}, null),
        throwsA(
          isA<APIModuleProxyCallerResponseError>().having(
            (e) => e.responseError,
            'responseError',
            'no st',
          ),
        ),
      );
      expect(defaultHandled, equals(1));
    });

    test('responseToJson with entity access rules', () async {
      var testRoot = TestAPIRoot();
      try {
        await testRoot.ensureInitialized();

        var direct = APIModuleProxyDirectCaller(testRoot, moduleName: 'user');

        var json = await direct.onCall(null, 'getUser', {
          'id': 1,
        }, TypeReflection.tMapStringDynamic);
        expect(json, isA<Map>());
        expect((json as Map)['email'], equals('joe@email.com'));

        var userModule = testRoot.getModule('user')!;
        expect(
          userModule.getRouteHandler('getUser').toString(),
          startsWith('_APIRouteHandlerAPIMethodReflection<User>@'),
        );
        expect(
          userModule.getRouteHandler('getRequestEntityAccessRules').toString(),
          startsWith('_APIRouteHandlerAPIMethodAPIRequestAPIResponse<Map'),
        );
        expect(direct.responseToJson({'a': 1}), equals({'a': 1}));
      } finally {
        testRoot.close();
      }
    });
  });

  group('APIModuleProxyHttpCaller', () {
    late mercury.HttpClientRequesterSimulation simulation;
    late mercury.HttpClient httpClient;
    late List<String> requestedURLs;

    setUp(() {
      requestedURLs = [];
      simulation = mercury.HttpClientRequesterSimulation()
        ..simulateGET(RegExp(r'/mod/hello'), (url, params) {
          requestedURLs.add(url);
          return '{"hello": "${Uri.parse(url).queryParameters['name']}"}';
        })
        ..simulateGET(RegExp(r'/mod/text'), (url, params) => 'not json')
        ..simulateGET(RegExp(r'/plain'), (url, params) => '"plain"')
        ..simulatePOST(RegExp(r'/mod/post'), (url, params) => '[1, 2]');

      httpClient = mercury.HttpClient('http://localhost/', simulation);
    });

    tearDown(() {
      APIModuleProxyHttpCaller.defaultErrorHandler = null;
    });

    test('GET requests', () async {
      var caller = APIModuleProxyHttpCaller(httpClient, moduleRoute: '/mod/');
      expect(caller.modulePath, equals('mod'));

      expect(
        await caller.onCall(null, 'hello', {'name': 'joe'}, null),
        equals({'hello': 'joe'}),
      );
      expect(requestedURLs.single, startsWith('http://localhost/mod/hello'));

      expect(
        await caller.doRequest('text', {}, TypeReflection.tString),
        equals('not json'),
      );

      var noModule = APIModuleProxyHttpCaller(httpClient);
      expect(noModule.modulePath, isEmpty);
      expect(await noModule.doRequest('plain', {}, null), equals('plain'));
    });

    test('POST requests (non primitive parameters)', () async {
      var caller = APIModuleProxyHttpCaller(httpClient, moduleRoute: 'mod');

      expect(
        await caller.doRequest('post', {
          'list': [1, 2],
        }, null),
        equals([1, 2]),
      );
      expect(
        await caller.doRequest('post', {
          'bytes': Uint8List.fromList([1, 2]),
        }, null),
        equals([1, 2]),
      );
      expect(
        await caller.doRequest('post', {'time': Time(1, 2, 3)}, null),
        equals([1, 2]),
      );
      expect(
        await caller.doRequest('post', {
          'map': {'a': 1},
        }, TypeReflection(Future, [TypeReflection(Uint8List)])),
        isNotNull,
      );
    });

    test('requestHandler', () async {
      var caller = APIModuleProxyHttpCaller(httpClient, moduleRoute: 'mod');
      caller.requestHandler = (proxy, methodName, parameters) =>
          methodName == 'intercepted' ? 'intercepted: $parameters' : null;

      expect(
        await caller.doRequest('intercepted', {'a': 1}, null),
        equals('intercepted: {a: 1}'),
      );
      expect(
        await caller.doRequest('hello', {'name': 'x'}, null),
        equals({'hello': 'x'}),
      );
    });

    test('parseResponse', () {
      var handled = <APIModuleProxyCallerResponseError>[];

      var caller = APIModuleProxyHttpCaller(
        httpClient,
        moduleRoute: 'mod',
        errorHandler: handled.add,
      );

      expect(
        caller.parseResponse(_httpResponse(200, '{"a":1}', 'application/json')),
        equals({'a': 1}),
      );

      // Not OK, but not an error:
      expect(caller.parseResponse(_httpResponse(404, 'nf')), isNull);

      expect(
        () => caller.parseResponse(
          _httpResponse(500, '{"error":"fail"}', 'application/json'),
          requestMethod: mercury.HttpMethod.GET,
          requestPath: 'mod/x',
          methodName: 'x',
          parameters: {'p': 1},
        ),
        throwsA(
          isA<APIModuleProxyCallerResponseError>()
              .having(
                (e) => e.responseStatus,
                'responseStatus',
                APIResponseStatus.ERROR,
              )
              .having((e) => e.module, 'module', 'mod')
              .having((e) => e.methodName, 'methodName', 'x')
              .having(
                (e) => e.request,
                'request',
                equals({
                  'requestMethod': 'GET',
                  'requestPath': 'mod/x',
                  'responseStatus': 500,
                }),
              ),
        ),
      );
      expect(handled.length, equals(1));
      expect(handled.single.responseError, equals({'error': 'fail'}));

      // A default error handler that throws:
      var defaultCalls = 0;
      APIModuleProxyHttpCaller.defaultErrorHandler = (e) {
        defaultCalls++;
        throw StateError('x');
      };
      var caller2 = APIModuleProxyHttpCaller(httpClient);
      expect(
        () => caller2.parseResponse(_httpResponse(400, 'bad')),
        throwsA(isA<APIModuleProxyCallerResponseError>()),
      );
      expect(defaultCalls, equals(1));
    });

    test('parseResponseBody', () {
      var asJson = APIModuleProxyHttpCaller(httpClient);
      var noJson = APIModuleProxyHttpCaller(httpClient, responsesAsJson: false);

      expect(asJson.parseResponseBody(_httpResponse(200, null)), isNull);
      expect(asJson.parseResponseBody(_httpResponse(200, '')), isNull);

      expect(asJson.parseResponseBody(_httpResponse(200, '[1]')), equals([1]));
      expect(
        noJson.parseResponseBody(_httpResponse(200, '[1]')),
        equals('[1]'),
      );

      expect(
        noJson.parseResponseBody(_httpResponse(200, '[1]', 'text/plain')),
        equals('[1]'),
      );
      expect(
        noJson.parseResponseBody(
          _httpResponse(200, '{"a":2}', 'application/json'),
        ),
        equals({'a': 2}),
      );

      expect(
        noJson.parseResponseBody(
          _httpResponse(200, Uint8List.fromList([1, 2, 3]), 'image/png'),
        ),
        equals([1, 2, 3]),
      );

      expect(
        noJson.parseResponseBody(
          _httpResponse(200, 'a=1&b=2', 'application/x-www-form-urlencoded'),
        ),
        equals({'a': '1', 'b': '2'}),
      );

      expect(
        noJson.parseResponseBody(_httpResponse(200, 'xyz', 'application/foo')),
        equals('xyz'),
      );

      expect(asJson.decodeJson('{"a":1}'), equals({'a': 1}));
      expect(asJson.decodeJson('not json'), equals('not json'));
    });

    test('isJsonResponse', () {
      var asJson = APIModuleProxyHttpCaller(httpClient);
      var noJson = APIModuleProxyHttpCaller(httpClient, responsesAsJson: false);
      var resp = _httpResponse(200, 'x');

      bool isJson(APIModuleProxyHttpCaller c, String? mime) =>
          c.isJsonResponse(resp, mime != null ? MimeType.parse(mime) : null);

      expect(isJson(asJson, null), isTrue);
      expect(isJson(noJson, null), isFalse);

      expect(isJson(noJson, 'application/json'), isTrue);
      expect(isJson(noJson, 'application/javascript'), isTrue);
      expect(isJson(noJson, 'text/plain'), isFalse);

      for (var m in ['font/woff', 'image/png', 'audio/mpeg', 'video/mp4']) {
        expect(isJson(asJson, m), isFalse, reason: m);
      }

      for (var sub in [
        'gzip',
        'zip',
        'x-tar',
        'x-bzip',
        'x-bzip2',
        'x-7z-compressed',
        'x-rar-compressed',
        'dart',
        'yaml',
        'xml',
        'pdf',
        'msword',
        'octet-stream',
      ]) {
        expect(isJson(asJson, 'application/$sub'), isFalse, reason: sub);
      }
      expect(isJson(asJson, 'application/x-foo'), isTrue);

      for (var sub in ['html', 'css', 'csv', 'xml', 'md']) {
        expect(isJson(asJson, 'text/$sub'), isFalse, reason: sub);
      }
      expect(isJson(asJson, 'text/plain'), isTrue);
      expect(isJson(asJson, 'multipart/form-data'), isTrue);
    });

    test('isTextResponse and isByteArrayResponse', () {
      var caller = APIModuleProxyHttpCaller(httpClient);
      var resp = _httpResponse(200, 'x');

      MimeType mt(String s) => MimeType.parse(s)!;

      expect(caller.isTextResponse(resp, null), isFalse);
      expect(caller.isTextResponse(resp, mt('text/plain')), isTrue);
      expect(caller.isTextResponse(resp, mt('application/xml')), isTrue);
      expect(caller.isTextResponse(resp, mt('image/png')), isFalse);

      expect(caller.isByteArrayResponse(resp, null), isFalse);
      expect(caller.isByteArrayResponse(resp, mt('image/png')), isTrue);
      expect(caller.isByteArrayResponse(resp, mt('audio/mpeg')), isTrue);
      expect(caller.isByteArrayResponse(resp, mt('video/mp4')), isTrue);
      for (var sub in [
        'gzip',
        'zip',
        'x-tar',
        'x-bzip',
        'x-bzip2',
        'x-7z-compressed',
        'x-rar-compressed',
        'pdf',
        'msword',
        'octet-stream',
      ]) {
        expect(
          caller.isByteArrayResponse(resp, mt('application/$sub')),
          isTrue,
          reason: sub,
        );
      }
      expect(caller.isByteArrayResponse(resp, mt('application/json')), isFalse);
      expect(caller.isByteArrayResponse(resp, mt('text/plain')), isFalse);
    });
  });
}

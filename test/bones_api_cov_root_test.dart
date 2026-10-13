@TestOn('vm')
library;

import 'dart:isolate';

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_modules.dart';

class _CovModule extends APIModule {
  _CovModule(APIRoot apiRoot) : super(apiRoot, 'Cov', version: '2.0');

  @override
  void configure() {
    routes.get(
      'hello',
      (request) =>
          APIResponse.ok('hello ${request.getParameter('name') ?? 'world'}'),
      parameters: {'name': TypeInfo.tString, 'request': APIRequest.typeInfo},
    );

    routes.get('zone', (request) {
      var r = APIRoot.getByAPIRequestZone(Zone.current);
      return APIResponse.ok(
        '${r.apiRoot?.name}|${identical(r.apiRequest, request)}',
      );
    });

    // A value of the call's `Zone` (inherited from its parent zone):
    routes.get('zoneValue', (request) {
      return APIResponse.ok('${Zone.current[#covZoneKey]}');
    });

    routes.post(
      'secret',
      (request) => APIResponse.ok('secret'),
      rules: [APIRouteAuthenticatedRule()],
    );

    routes.put('put', (request) => APIResponse.ok('put'));
    routes.delete('del', (request) => APIResponse.ok('del'));
    routes.patch('patch', (request) => APIResponse.ok('patch'));
    routes.head('head', (request) => APIResponse.ok('head'));

    routes.any(
      'quiet',
      (request) => APIResponse.ok('quiet'),
      config: APIRouteConfig(log: false),
    );

    routes.any('throw', (request) => throw StateError('boom'));

    routes.any('async', (request) async {
      await Future.delayed(Duration(milliseconds: 1));
      return APIResponse.ok('async');
    });

    routes.any('asyncThrow', (request) async {
      await Future.delayed(Duration(milliseconds: 1));
      throw APIResponse.badRequest(payloadDynamic: 'bad async');
    });

    routes.any(
      'credential',
      (request) => APIResponse.ok(
        '${request.credential?.username}|${request.originalCredential?.username}',
      ),
    );

    // Routes from another module reflection (bound to that instance):
    var about = AboutModule(apiRoot);
    routes.getFrom(about.reflection);
    routes.postFrom(about.reflection.apiMethods());
    routes.putFrom(about.reflection.method('about'));
    routes.deleteFrom(null);
    routes.patchFrom(null);
    routes.headFrom(null);
  }
}

class _CovRoot extends APIRoot {
  final String? _defaultModuleName;
  final String? _securityModuleName;

  _CovRoot(
    String name, {
    String? defaultModuleName,
    String? securityModuleName,
    super.preApiRequestHandlers,
    super.posApiRequestHandlers,
  }) : _defaultModuleName = defaultModuleName,
       _securityModuleName = securityModuleName,
       super(name, '1.0');

  @override
  String? get defaultModuleName => _defaultModuleName;

  @override
  String? get securityModuleName => _securityModuleName;

  @override
  Set<APIModule> loadModules() => {_CovModule(this)};
}

class _OtherRoot extends APIRoot {
  _OtherRoot(String name) : super(name, '0.1');

  @override
  Set<APIModule> loadModules() => {};
}

FutureOr<APIResponse<T>?> _handlerNull<T>(APIRoot root, APIRequest request) =>
    null;

FutureOr<APIResponse<T>?> _handlerThrow<T>(APIRoot root, APIRequest request) =>
    throw StateError('handler error');

FutureOr<APIResponse<T>?> _handlerOK<T>(APIRoot root, APIRequest request) =>
    APIResponse<T>.ok(null, payloadDynamic: 'handler: ${request.path}');

FutureOr<APIResponse<T>?> _handlerAsyncNull<T>(
  APIRoot root,
  APIRequest request,
) => Future<APIResponse<T>?>.value(null);

FutureOr<APIResponse<T>?> _handlerAsyncOK<T>(
  APIRoot root,
  APIRequest request,
) => Future<APIResponse<T>?>.value(
  APIResponse<T>.ok(null, payloadDynamic: 'async handler'),
);

FutureOr<APIResponse<T>?> _handlerAsyncThrow<T>(
  APIRoot root,
  APIRequest request,
) => Future<APIResponse<T>?>.error(StateError('async handler error'));

FutureOr<APIResponse<T>?> _handlerOnlyPre<T>(
  APIRoot root,
  APIRequest request,
) => request.path == '/pre'
    ? APIResponse<T>.ok(null, payloadDynamic: 'pre')
    : null;

FutureOr<APIResponse<T>?> _handlerPosAsync<T>(
  APIRoot root,
  APIRequest request,
) => request.path == '/pos'
    ? Future<APIResponse<T>?>.value(
        APIResponse<T>.ok(null, payloadDynamic: 'pos'),
      )
    : Future<APIResponse<T>?>.value(null);

void main() {
  group('APIRoot instances', () {
    test('get/getByName/getByType/getWhere/getWithinName', () async {
      expect(APIRoot.get(), isNull);

      var r1 = _CovRoot('cov-root-A');
      try {
        expect(APIRoot.get(), same(r1));

        var r2 = _OtherRoot('cov-root-B');
        try {
          expect(() => APIRoot.get(), throwsStateError);
          expect(APIRoot.get(singleton: false), same(r2));

          expect(APIRoot.getByName('cov-root-A'), same(r1));
          expect(APIRoot.getByName('COV-ROOT-b'), same(r2));
          expect(APIRoot.getByName('COV-ROOT-b', caseSensitive: true), isNull);
          expect(APIRoot.getByName('x'), isNull);
          expect(APIRoot.getByName('x', lastAsDefault: true), same(r2));

          expect(APIRoot.getByType<_CovRoot>(), same(r1));
          expect(APIRoot.getByType<APIRoot>(type: _OtherRoot), same(r2));
          expect(APIRoot.getByType<_OtherRoot>(), same(r2));
          expect(APIRoot.getByType<APIRoot>(type: String), isA<_CovRoot>());
          expect(APIRoot.getByType<TestAPIRoot>(), isNull);

          expect(APIRoot.getWhere((r) => r.version == '0.1'), same(r2));
          expect(APIRoot.getWhere((r) => false), isNull);
          expect(APIRoot.getWhere((r) => false, lastAsDefault: true), same(r2));

          expect(APIRoot.getWithinName('ROOT-A'), same(r1));
          expect(APIRoot.getWithinName('ROOT-A', caseSensitive: true), isNull);
          expect(APIRoot.getWithinName('ROOT-b', caseSensitive: true), isNull);
          expect(
            APIRoot.getWithinName('root-B', caseSensitive: true),
            same(r2),
          );
          expect(APIRoot.getWithinName('root-B'), same(r2));

          // With 2 instances, the zone lookup iterates all of them:
          await r1.ensureInitialized();
          var zone = await r1.call(APIRequest.get('/cov/zone'));
          expect(zone.payload, equals('cov-root-A|true'));

          var r3 = _OtherRoot('cov-root-C');
          try {
            expect(APIRoot.get(), isNull);
            // `get` returns `null` with 3 instances:
            expect(APIRoot.getByType<TestAPIRoot>(lastAsDefault: true), isNull);
            expect(APIRoot.getByName('x', lastAsDefault: true), isNull);
          } finally {
            r3.close();
          }
        } finally {
          r2.close();
        }

        var zone = await r1.call(APIRequest.get('/cov/zone'));
        expect(zone.payload, equals('cov-root-A|true'));

        var noZone = APIRoot.getByAPIRequestZone(Zone.current);
        expect(noZone.apiRoot, isNull);
        expect(noZone.apiRequest, isNull);
      } finally {
        r1.close();
      }

      expect(APIRoot.get(), isNull);
      expect(APIRoot.getByAPIRequestZone(Zone.current).apiRoot, isNull);
    });
  });

  group('APIRoot', () {
    late _CovRoot root;

    setUp(() async {
      root = _CovRoot('cov-root');
      await root.ensureInitialized();
    });

    tearDown(() {
      root.close();
    });

    test('basic info', () {
      expect(root.modulesNames, equals({'cov'}));
      expect(root.modules.single.name, equals('cov'));
      expect(root.getModule('nope'), isNull);
      expect(root.toString(), contains('cov-root[1.0]#'));
      expect(root.toString(), endsWith('{cov}'));
      expect(root.toString(withModulesNames: false), isNot(contains('{cov}')));
      expect(root.hashCode, equals('cov-root'.hashCode ^ '1.0'.hashCode));
      expect(root == root, isTrue);
      expect(root.sharedStoreID, equals('SharedStore[cov-root/1.0]'));
      expect(root.isAuxiliaryInstance, isFalse);
      expect(root.authenticationRoute, equals('authenticate'));
      expect(root.securityModule, isNull);
      expect(root.security, isNull);
    });

    test('log', () {
      var logs = <String>[];
      root.logger = (apiRoot, type, message, [error, stackTrace]) =>
          logs.add('$type|$message|${error ?? ''}');

      root.log('INFO', 'info msg');
      root.log('WARN', 'warn msg');
      root.log('ERROR', 'error msg', StateError('x'), StackTrace.current);

      expect(
        logs,
        equals([
          'INFO|info msg|',
          'WARN|warn msg|',
          'ERROR|error msg|Bad state: x',
        ]),
      );
    });

    test('call routes', () async {
      var r = await root.doCall(
        APIRequestMethod.GET,
        '/cov/hello',
        parameters: {'name': 'joe'},
      );
      expect(r.isOK, isTrue);
      expect(r.payload, equals('hello joe'));
      expect(r.apiRequest?.path, equals('/cov/hello'));
      expect(r.apiRequest?.routeHandler?.routeName, equals('hello'));

      for (var m in [
        (APIRequestMethod.PUT, 'put'),
        (APIRequestMethod.DELETE, 'del'),
        (APIRequestMethod.PATCH, 'patch'),
        (APIRequestMethod.HEAD, 'head'),
      ]) {
        var resp = await root.doCall(m.$1, '/cov/${m.$2}');
        expect(resp.payload, equals(m.$2));
      }

      expect(
        (await root.doCall(APIRequestMethod.GET, '/cov/quiet')).payload,
        equals('quiet'),
      );
      expect(
        (await root.doCall(APIRequestMethod.GET, '/cov/async')).payload,
        equals('async'),
      );

      var asyncThrow = await root.doCall(
        APIRequestMethod.GET,
        '/cov/asyncThrow',
      );
      expect(asyncThrow.isBadRequest, isTrue);
      expect(asyncThrow.payload, equals('bad async'));

      // A route that throws synchronously:
      var thrown = await root.doCall(APIRequestMethod.GET, '/cov/throw');
      expect(thrown.isError, isTrue);
      expect(thrown.error.toString(), contains('boom'));

      // Wrong method for a method specific route:
      var wrongMethod = await root.doCall(APIRequestMethod.GET, '/cov/put');
      expect(wrongMethod.isNotFound, isTrue);
      expect(wrongMethod.payload, contains('No route for path "/cov/put"'));

      var noModule = await root.doCall(APIRequestMethod.GET, '/nope/x');
      expect(noModule.isNotFound, isTrue);
    });

    test('routes from reflection', () async {
      var get = await root.doCall(APIRequestMethod.GET, '/cov/about');
      expect(get.payload, equals('About...'));

      var post = await root.doCall(APIRequestMethod.POST, '/cov/about');
      expect(post.payload, equals('About...'));

      var put = await root.doCall(APIRequestMethod.PUT, '/cov/about');
      expect(put.payload, equals('About...'));

      var module = root.getModule('cov')!;
      expect(
        module.getRoutesHandlersNames(method: APIRequestMethod.GET),
        containsAll(['hello', 'zone', 'about']),
      );
      expect(
        module.getRoutesHandlersNames(method: APIRequestMethod.POST),
        containsAll(['secret', 'about']),
      );
      expect(
        module.getRoutesHandlersNames(),
        containsAll(['quiet', 'throw', 'async']),
      );
      expect(
        module.getRoutesHandlersNames(method: APIRequestMethod.OPTIONS),
        containsAll(['quiet', 'throw', 'async']),
      );
      expect(module.allRoutesNames, containsAll(['hello', 'about', 'head']));
    });

    test('route rules', () async {
      var r = await root.doCall(APIRequestMethod.POST, '/cov/secret');
      expect(r.isUnauthorized, isTrue);
      expect(r.payload, contains('UNAUTHORIZED: Rules issues'));

      var handler = root
          .getModule('cov')!
          .getRouteHandler('secret', APIRequestMethod.POST)!;
      expect(
        handler.toString(),
        equals(
          'APIRouteHandler[POST]{routeName: secret, rules: [APIRouteAuthenticatedRule{}]}',
        ),
      );

      var anyHandler = root.getModule('cov')!.getRouteHandler('quiet')!;
      expect(
        anyHandler.toString(),
        equals('APIRouteHandler{routeName: quiet}'),
      );
      expect(anyHandler.checkRules(APIRequest.get('/cov/quiet')), isTrue);
    });

    test('OPTIONS call is not allowed', () {
      expect(
        () => root.call(APIRequest(APIRequestMethod.OPTIONS, '/cov/hello')),
        throwsArgumentError,
      );
    });

    test('credential copy', () async {
      var request = APIRequest.get(
        '/cov/credential',
        credential: APICredential('joe'),
      );
      var original = request.credential;

      var r = await root.call(request);
      expect(r.payload, equals('joe|joe'));
      expect(request.credential, isNot(same(original)));
      expect(request.originalCredential, same(request.credential));

      // A credential that is not the original one:
      var request2 = APIRequest.get(
        '/cov/credential',
        credential: APICredential('orig'),
      );
      var orig2 = request2.originalCredential;
      request2.credential = APICredential('other');

      var r2 = await root.call(request2);
      expect(r2.payload, equals('other|orig'));
      expect(request2.originalCredential, isNot(same(orig2)));

      // An external call keeps the credentials:
      var request3 = APIRequest.get(
        '/cov/credential',
        credential: APICredential('ext'),
      );
      var cred3 = request3.credential;
      await root.call(request3, externalCall: true);
      expect(request3.credential, same(cred3));
    });

    test('callAuthenticate without security', () async {
      expect(await root.callAuthenticate('a@b.com', '123'), isNull);
    });

    test('acceptsRequest', () {
      expect(root.acceptsRequest(APIRequest.get('/cov/hello')), isTrue);
      expect(root.acceptsRequest(APIRequest.get('/cov/API-INFO')), isTrue);
      expect(root.acceptsRequest(APIRequest.get('/cov/authenticate')), isTrue);
      // `tables` is not a route, but there's no default route:
      expect(root.acceptsRequest(APIRequest.get('/cov/nope')), isFalse);
      expect(root.acceptsRequest(APIRequest.get('/authenticate')), isTrue);
      expect(root.acceptsRequest(APIRequest.get('/x/authenticate')), isTrue);
      expect(root.acceptsRequest(APIRequest.get('/x/y')), isFalse);
    });

    test('API-INFO', () async {
      var r = await root.call(
        APIRequest.get('/API-INFO', headers: {'origin': 'http://foo.com:81'}),
      );
      expect(r.isOK, isTrue);

      var info = r.payload as APIRootInfo;
      expect(info.name, equals('cov-root'));
      expect(info.version, equals('1.0'));
      expect(info.selectedModule, isNull);

      var json = info.toJson();
      expect(json['name'], equals('cov-root'));
      var modules = json['modules'] as List;
      var module = modules.single as Map;
      expect(module['name'], equals('cov'));
      expect(module['version'], equals('2.0'));

      var routes = (module['routes'] as List).cast<Map>();
      var hello = routes.firstWhere((e) => e['name'] == 'hello');
      expect(hello['method'], equals('GET'));
      expect(hello['parameters'], equals({'name': 'String'}));
      expect(hello['uri'], equals('http://foo.com:81/cov/hello?name=String'));

      var secret = routes.firstWhere((e) => e['name'] == 'secret');
      expect(secret['rules'], isNotEmpty);
      expect(secret['uri'], equals('http://foo.com:81/cov/secret'));

      var quiet = routes.firstWhere((e) => e['name'] == 'quiet');
      expect(quiet.containsKey('method'), isFalse);

      // Selected module:
      var sel = await root.call(APIRequest.get('/API-INFO/cov'));
      var selJson = (sel.payload as APIRootInfo).toJson();
      expect(selJson['selectedModule'], equals('cov'));

      var unknown = await root.call(APIRequest.get('/API-INFO/nope'));
      var unknownJson = (unknown.payload as APIRootInfo).toJson();
      expect(
        unknownJson['error'],
        equals("Can't find selected module: `nope`"),
      );
      expect(unknownJson.containsKey('modules'), isFalse);

      // Module level API-INFO:
      var modInfo = await root.call(APIRequest.get('/cov/API-INFO'));
      expect(modInfo.payload, isA<APIModuleInfo>());
      var modInfoJson = (modInfo.payload as APIModuleInfo).toJson();
      expect(modInfoJson['name'], equals('cov'));
      expect((modInfo.payload as APIModuleInfo).rules, isEmpty);
    });

    test('APIRouteInfo without request', () {
      var module = root.getModule('cov')!;
      var info = module
          .getRouteHandler('hello', APIRequestMethod.GET)!
          .apiInfo();

      expect(info.name, equals('hello'));
      expect(info.module, same(module));
      expect(info.method, equals(APIRequestMethod.GET));
      expect(info.hasParameters, isTrue);
      expect(info.parametersAsJson, equals({'name': 'String'}));
      expect(info.rules, isEmpty);

      // Without a request the base URI is `Uri.base` (a `file:` URI in the VM):
      expect(info.uri.path, endsWith('cov/hello'));
      expect(info.uriAsJson, endsWith('cov/hello?name=String'));

      var info2 = module
          .getRouteHandler('quiet')!
          .apiInfo(APIRequest.get('/x', headers: {'host': 'h.com'}));
      expect(info2.hasParameters, isFalse);
      expect(info2.uriAsJson, equals('http://h.com/cov/quiet'));
    });

    test('APIModule', () {
      var module = root.getModule('cov')!;
      expect(module.name, equals('cov'));
      expect(module.version, equals('2.0'));
      expect(module.defaultRouteName, isNull);
      expect(module.apiConfig, same(root.apiConfig));
      expect(module.security, isNull);
      expect(module.authenticationRoute, equals('authenticate'));

      var other = _CovModule(root);
      expect(module == other, isTrue);
      expect(module.hashCode, equals(other.hashCode));
      expect(module == AboutModule(root), isFalse);

      expect(
        () => module.addRoute(
          APIRequestMethod.OPTIONS,
          'opt',
          (r) => APIResponse.ok(1),
        ),
        throwsArgumentError,
      );

      expect(
        module
            .getRouteHandlerByRequest(APIRequest.get('/cov/hello'))
            ?.routeName,
        equals('hello'),
      );

      expect(module.acceptsRequest(APIRequest.get('/cov/hello')), isTrue);
      expect(module.acceptsRequest(APIRequest.get('/cov/x')), isFalse);

      expect(module.routes.from(null, null), isFalse);
      expect(module.routes.from(null, 123), isFalse);
      expect(module.routes.from(null, []), isFalse);
      expect(module.routes.from(null, [123, null]), isFalse);

      // An `Iterable` of providers:
      var about = AboutModule(root);
      expect(
        module.routes.from(APIRequestMethod.PATCH, [
          about.reflection.method('about'),
          123,
        ]),
        isTrue,
      );
      expect(
        module
            .getRouteHandlerByRequest(APIRequest.patch('/cov/about'))
            ?.routeName,
        equals('about'),
      );
    });
  });

  group('APIRoot currentAPIRequest', () {
    test('created by the constructor (its Zone: the calls\' parent)', () async {
      // Created in a `Zone` with a value:
      var root = runZoned(
        () => _CovRoot('cov-root-current-request'),
        zoneValues: {#covZoneKey: 'creation-zone'},
      );
      try {
        // Available before the initialization (not an error):
        var zoneField = root.currentAPIRequest;
        expect(root.getCurrentAPIRequest(), isNull);
        expect(APIRoot.getByAPIRequestZone(Zone.current).apiRequest, isNull);

        await root.ensureInitialized();
        expect(root.currentAPIRequest, same(zoneField));

        // Called outside that `Zone`: the call's zone inherits its value.
        expect(Zone.current[#covZoneKey], isNull);
        var res = await root.call(APIRequest.get('/cov/zoneValue'));
        expect(res.payload, equals('creation-zone'));

        var res2 = await root.call(APIRequest.get('/cov/zone'));
        expect(res2.payload, equals('cov-root-current-request|true'));
        expect(root.currentAPIRequest, same(zoneField));

        // Outside the `call`: no current request.
        expect(root.getCurrentAPIRequest(), isNull);
      } finally {
        root.close();
      }
    });

    test('an isolate copy: sendable, initialized in its isolate', () async {
      var root = _CovRoot('cov-root-isolate-copy');
      try {
        // Created and initialized in the test's `Zone` (not sendable): its
        // `currentAPIRequest` (a field: the fast path) holds it.
        expect(identical(Zone.current, Zone.root), isFalse);
        await root.ensureInitialized();
        var zoneField = root.currentAPIRequest;

        Matcher unsendable() => throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('_CustomZone'),
          ),
        );

        await expectLater(Isolate.run(() => root.name), unsendable());

        // Prepared: sendable (and the same `ZoneField` in this `Isolate`).
        root.prepareForIsolateCopy();
        expect(root.currentAPIRequest, same(zoneField));
        expect(await Isolate.run(() => root.name), 'cov-root-isolate-copy');

        var copyResult = await Isolate.run(() async {
          // A new `Isolate`: nothing initialized yet for the copy.
          var noRequest = root.getCurrentAPIRequest();
          var providers0 = EntityRulesResolver.cotextProviders.length;

          // In the zone of this point (as an `APIServerWorker` start):
          root.initializeIsolateCopy();
          var providers1 = EntityRulesResolver.cotextProviders.length;

          var field = root.currentAPIRequest;
          root.initializeIsolateCopy(); // Idempotent.
          var sameField = identical(root.currentAPIRequest, field);
          var providers2 = EntityRulesResolver.cotextProviders.length;

          var res = await root.call(APIRequest.get('/cov/zone'));
          return '${root.isAuxiliaryInstance}|$noRequest|'
              '$providers0->$providers1->$providers2|$sameField|${res.payload}';
        });
        expect(
          copyResult,
          equals('true|null|0->1->1|true|cov-root-isolate-copy|true'),
        );

        // A copy used without `initializeIsolateCopy`: created when used
        // (not an error).
        var copyResult2 = await Isolate.run(() async {
          var res = await root.call(APIRequest.get('/cov/zone'));
          return '${res.payload}|${EntityRulesResolver.cotextProviders.length}';
        });
        expect(copyResult2, equals('cov-root-isolate-copy|true|1'));

        // This `Isolate` keeps the same `ZoneField` (also while copied):
        expect(root.currentAPIRequest, same(zoneField));
        var res = await root.call(APIRequest.get('/cov/zone'));
        expect(res.payload, equals('cov-root-isolate-copy|true'));
        expect(root.currentAPIRequest, same(zoneField));

        // Still sendable (not put back in the instance by its use):
        expect(await Isolate.run(() => root.name), 'cov-root-isolate-copy');

        // Finished: back in the instance (the fast path), not sendable.
        root.finishIsolateCopy();
        expect(root.currentAPIRequest, same(zoneField));
        await expectLater(Isolate.run(() => root.name), unsendable());

        var res2 = await root.call(APIRequest.get('/cov/zone'));
        expect(res2.payload, equals('cov-root-isolate-copy|true'));
      } finally {
        root.close();
      }
    });

    test('a closed APIRoot: its rules provider not registered again', () async {
      var root = _CovRoot('cov-root-closed-provider');

      await root.ensureInitialized();
      var registered = EntityRulesResolver.cotextProviders.length;

      root.prepareForIsolateCopy();
      root.close();
      expect(
        EntityRulesResolver.cotextProviders.length,
        equals(registered - 1),
      );

      // Used after closed (e.g. its `modules`): not registered again.
      root.modules;
      root.initializeIsolateCopy();
      expect(
        EntityRulesResolver.cotextProviders.length,
        equals(registered - 1),
      );
    });
  });

  group('APIRoot handlers', () {
    test('callHandlers', () async {
      var root = _CovRoot('cov-root-handlers');
      try {
        var request = APIRequest.get('/x');

        expect(root.callHandlers([], request), isNull);
        expect(
          root.callHandlers([_handlerNull, _handlerThrow], request),
          isNull,
        );

        var sync = root.callHandlers([
          _handlerNull,
          _handlerThrow,
          _handlerOK,
        ], request);
        expect(sync, isA<APIResponse>());
        expect((sync as APIResponse).payload, equals('handler: /x'));

        var async1 = await root.callHandlers([
          _handlerAsyncNull,
          _handlerNull,
          _handlerThrow,
          _handlerOK,
        ], request);
        expect(async1?.payload, equals('handler: /x'));

        var async2 = await root.callHandlers([
          _handlerAsyncThrow,
          _handlerAsyncNull,
          _handlerAsyncOK,
        ], request);
        expect(async2?.payload, equals('async handler'));

        var async3 = await root.callHandlers([
          _handlerAsyncNull,
          _handlerAsyncThrow,
          _handlerAsyncNull,
        ], request);
        expect(async3, isNull);

        var async4 = await root.callHandlers([
          _handlerAsyncOK,
          _handlerOK,
        ], request);
        expect(async4?.payload, equals('async handler'));
      } finally {
        root.close();
      }
    });

    test('pre and pos handlers, default module', () async {
      var root = _CovRoot(
        'cov-root-pre-pos',
        defaultModuleName: 'cov',
        preApiRequestHandlers: [_handlerOnlyPre],
        posApiRequestHandlers: [_handlerPosAsync],
      );

      try {
        await root.ensureInitialized();

        expect(
          (await root.call(APIRequest.get('/pre'))).payload,
          equals('pre'),
        );

        // Default module:
        var def = await root.call(APIRequest.get('/unknown/hello'));
        expect(def.payload, equals('hello world'));

        expect(root.acceptsRequest(APIRequest.get('/unknown/hello')), isTrue);

        var pos = await root.onNoRouteForPath(APIRequest.get('/pos'));
        expect(pos.payload, equals('pos'));

        var notFound = await root.onNoRouteForPath(APIRequest.get('/x'));
        expect(notFound.isNotFound, isTrue);

        // No route in the default module falls to the `pos` handlers:
        var pos2 = await root.call(APIRequest.get('/pos'));
        expect(pos2.payload, equals('pos'));

        var notFound2 = await root.call(APIRequest.get('/nope'));
        expect(notFound2.isNotFound, isTrue);
      } finally {
        root.close();
      }
    });

    test('pre handlers async', () async {
      var root = _CovRoot(
        'cov-root-pre-async',
        preApiRequestHandlers: [_handlerAsyncNull],
      );

      try {
        await root.ensureInitialized();
        var r = await root.call(APIRequest.get('/cov/hello'));
        expect(r.payload, equals('hello world'));
      } finally {
        root.close();
      }
    });

    test('unknown security module', () async {
      var root = _CovRoot('cov-root-sec', securityModuleName: 'nope');
      try {
        await root.ensureInitialized();
        expect(() => root.securityModule, throwsStateError);

        var r = await root.call(
          APIRequest.get('/cov/hello', credential: APICredential('x')),
        );
        expect(r.isError, isTrue);
        expect(
          r.error.toString(),
          contains("Can't find security module with name: nope"),
        );
      } finally {
        root.close();
      }
    });

    test('modules accessed before initialization', () async {
      var root = _CovRoot('cov-root-lazy');
      try {
        // Not initialized yet: loads the modules on demand.
        var r = await root.call(APIRequest.get('/cov/hello'));
        expect(r.payload, equals('hello world'));
        expect(root.modulesNames, equals({'cov'}));
      } finally {
        root.close();
      }
    });
  });

  group('APIRouteConfig', () {
    test('toString', () {
      expect(
        APIRouteConfig.defaultConfig.toString(),
        equals('APIRouteConfig{log: true, slowCall: false}'),
      );
    });
  });
}

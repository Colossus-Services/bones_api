@TestOn('vm')
import 'dart:convert' as convert;
import 'dart:io';

import 'package:bones_api/bones_api_server.dart';
import 'package:mercury_client/mercury_client.dart' as mercury_client;
import 'package:test/test.dart';

part 'bones_api_route_raw_handler_test.reflection.g.dart';

/// Client proxy of [RawHandlerModule]
/// (`APIRequest` and `APICredential` parameters are not part of the proxy).
@APIModuleProxy('RawHandlerModule')
class RawHandlerModuleProxy extends APIModuleProxyHttpCaller {
  RawHandlerModuleProxy(super.httpClient) : super(moduleRoute: 'raw');
}

class RawHandlerAPIRoot extends APIRoot {
  RawHandlerAPIRoot() : super('raw-handler-test', '1.0');

  @override
  Set<APIModule> loadModules() => {RawHandlerModule(this)};
}

/// A rule that only allows requests with `establishmentId == 10`,
/// read from the request parameters or JSON payload.
class EstablishmentRule extends APIRouteRule {
  const EstablishmentRule() : super();

  @override
  bool validate(APIRequest request) {
    var payload = request.payload;
    var establishmentId =
        request.getParameterIgnoreCase('establishmentId') ??
        (payload is Map ? payload['establishmentId'] : null);
    return '$establishmentId' == '10';
  }

  @override
  Map<String, Object> toJson() => {'rule': 'establishment'};
}

@EnableReflection()
class RawHandlerModule extends APIModule {
  RawHandlerModule(APIRoot apiRoot) : super(apiRoot, 'raw');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  /// Raw handler: only an `APIRequest`.
  APIResponse<Map> raw(APIRequest request) =>
      APIResponse.ok({'path': request.path, 'a': request.getParameter('a')});

  /// Raw handler (not returning an `APIResponse`): only an `APIRequest`.
  Future<String> rawNoResponse(APIRequest request) async =>
      'raw: ${request.getParameter('a')}';

  /// `APIRequest` + named parameters: NOT a raw handler.
  @EstablishmentRule()
  Future<APIResponse<Map>> withNamed(
    APIRequest request, {
    required int establishmentId,
    int? otherId,
    String label = 'def',
  }) async => APIResponse.ok({
    'path': request.path,
    'establishmentId': establishmentId,
    'otherId': otherId,
    'label': label,
  });

  /// `APIRequest` + optional positional parameter: NOT a raw handler.
  APIResponse<Map> withOptional(APIRequest request, [int? id]) =>
      APIResponse.ok({'path': request.path, 'id': id});

  /// `APIRequest` + named parameters (not returning an `APIResponse`).
  Map withNamedNoResponse(APIRequest request, {int? id}) => {
    'path': request.path,
    'id': id,
  };

  /// `APICredential` + `APIRequest` + named parameters (the old workaround).
  APIResponse<Map> withCredential(
    APICredential? credential,
    APIRequest request, {
    required int establishmentId,
  }) => APIResponse.ok({
    'path': request.path,
    'establishmentId': establishmentId,
  });
}

void main() {
  group('APIRequest raw handler', () {
    setUpAll(() {
      RawHandlerModule$reflection.boot();
    });

    late RawHandlerAPIRoot apiRoot;

    setUp(() => apiRoot = RawHandlerAPIRoot());
    tearDown(() => apiRoot.close());

    test('isRawAPIRequestHandler', () {
      var reflection = RawHandlerModule$reflection();

      bool isRaw(String name) =>
          reflection.method(name)!.isRawAPIRequestHandler;
      bool receives(String name) => reflection.method(name)!.receivesAPIRequest;

      expect(isRaw('raw'), isTrue);
      expect(isRaw('rawNoResponse'), isTrue);

      expect(isRaw('withNamed'), isFalse);
      expect(isRaw('withOptional'), isFalse);
      expect(isRaw('withNamedNoResponse'), isFalse);
      expect(isRaw('withCredential'), isFalse);

      // Still API methods (receiving an `APIRequest`):
      expect(receives('withNamed'), isTrue);
      expect(receives('withOptional'), isTrue);
      expect(receives('withNamedNoResponse'), isTrue);
      expect(reflection.method('withNamedNoResponse')!.isAPIMethod, isTrue);
    });

    test('raw handler (no named parameters): works as before', () async {
      var response = await apiRoot.call(
        APIRequest.get('/raw/raw', parameters: {'a': 'x'}),
      );

      expect(response.error, isNull, reason: '${response.error}');
      expect(response.payload, equals({'path': '/raw/raw', 'a': 'x'}));

      var route = apiRoot.getModule('raw')!.getRouteHandler('raw')!;
      expect(route.parameters!.keys, equals(['request']));
    });

    test('raw handler (not returning `APIResponse`)', () async {
      var response = await apiRoot.call(
        APIRequest.get('/raw/rawNoResponse', parameters: {'a': 'y'}),
      );

      expect(response.error, isNull, reason: '${response.error}');
      expect(response.payload, equals('raw: y'));
    });

    test('`APIRequest` + named parameters: parameters are passed', () async {
      var response = await apiRoot.call(
        APIRequest.get(
          '/raw/withNamed',
          parameters: {'establishmentId': '10', 'otherId': '20', 'label': 'L'},
        ),
      );

      expect(response.error, isNull, reason: '${response.error}');
      expect(
        response.payload,
        equals({
          'path': '/raw/withNamed',
          'establishmentId': 10,
          'otherId': 20,
          'label': 'L',
        }),
      );

      var route = apiRoot.getModule('raw')!.getRouteHandler('withNamed')!;
      expect(
        route.parameters!.keys,
        unorderedEquals(['request', 'establishmentId', 'otherId', 'label']),
      );
    });

    test('`APIRequest` + named parameters: defaults', () async {
      var response = await apiRoot.call(
        APIRequest.get('/raw/withNamed', parameters: {'establishmentId': 10}),
      );

      expect(response.error, isNull, reason: '${response.error}');
      expect(
        response.payload,
        equals({
          'path': '/raw/withNamed',
          'establishmentId': 10,
          'otherId': null,
          'label': 'def',
        }),
      );
    });

    test('`APIRequest` + named parameters: JSON payload', () async {
      // `withCredential` has no route rule (`EstablishmentRule` only reads
      // the request parameters, not the payload):
      var response = await apiRoot.call(
        APIRequest.post(
          '/raw/withCredential',
          payload: {'establishmentId': 30},
          payloadMimeType: 'json',
        ),
      );

      expect(response.error, isNull, reason: '${response.error}');
      expect(
        response.payload,
        equals({'path': '/raw/withCredential', 'establishmentId': 30}),
      );
    });

    test('`APIRequest` + named parameters: route rule', () async {
      var response = await apiRoot.call(
        APIRequest.get('/raw/withNamed', parameters: {'establishmentId': 11}),
      );

      expect(response.status, equals(APIResponseStatus.UNAUTHORIZED));
    });

    test('`APIRequest` + optional positional parameter', () async {
      var response = await apiRoot.call(
        APIRequest.get('/raw/withOptional', parameters: {'id': '7'}),
      );

      expect(response.error, isNull, reason: '${response.error}');
      expect(response.payload, equals({'path': '/raw/withOptional', 'id': 7}));
    });

    test(
      '`APIRequest` + named parameters (not returning `APIResponse`)',
      () async {
        var response = await apiRoot.call(
          APIRequest.get('/raw/withNamedNoResponse', parameters: {'id': '8'}),
        );

        expect(response.error, isNull, reason: '${response.error}');
        expect(
          response.payload,
          equals({'path': '/raw/withNamedNoResponse', 'id': 8}),
        );
      },
    );

    test('`APICredential` + `APIRequest` + named parameters', () async {
      var response = await apiRoot.call(
        APIRequest.get(
          '/raw/withCredential',
          parameters: {'establishmentId': '5'},
        ),
      );

      expect(response.error, isNull, reason: '${response.error}');
      expect(
        response.payload,
        equals({'path': '/raw/withCredential', 'establishmentId': 5}),
      );
    });
  });

  group('APIRequest raw handler: APIServer (HTTP)', () {
    late final APIServer apiServer;

    setUpAll(() async {
      RawHandlerModule$reflection.boot();

      apiServer = APIServer(RawHandlerAPIRoot(), 'localhost', 5549);
      await apiServer.start();
    });

    tearDownAll(() async {
      await apiServer.stop();
    });

    test('raw handler: GET', () async {
      var (status, body) = await _httpCall(apiServer, 'GET', 'raw/raw?a=x');

      expect(status, equals(200), reason: body);
      expect(convert.json.decode(body), equals({'path': '/raw/raw', 'a': 'x'}));
    });

    test('raw handler (not returning `APIResponse`): GET', () async {
      var (status, body) = await _httpCall(
        apiServer,
        'GET',
        'raw/rawNoResponse?a=y',
      );

      expect(status, equals(200), reason: body);
      expect(body, equals('raw: y'));
    });

    test('`APIRequest` + named parameters: GET query', () async {
      var (status, body) = await _httpCall(
        apiServer,
        'GET',
        'raw/withNamed?establishmentId=10&otherId=20&label=L',
      );

      expect(status, equals(200), reason: body);
      expect(
        convert.json.decode(body),
        equals({
          'path': '/raw/withNamed',
          'establishmentId': 10,
          'otherId': 20,
          'label': 'L',
        }),
      );
    });

    test('`APIRequest` + named parameters: POST form', () async {
      var (status, body) = await _httpCall(
        apiServer,
        'POST',
        'raw/withNamed',
        body: 'establishmentId=10&otherId=21',
        contentType: 'application/x-www-form-urlencoded',
      );

      expect(status, equals(200), reason: body);
      expect(
        convert.json.decode(body),
        equals({
          'path': '/raw/withNamed',
          'establishmentId': 10,
          'otherId': 21,
          'label': 'def',
        }),
      );
    });

    test('`APIRequest` + named parameters: route rule', () async {
      var (status, body) = await _httpCall(
        apiServer,
        'GET',
        'raw/withNamed?establishmentId=11',
      );

      expect(status, equals(403), reason: body);
    });

    test('`APIRequest` + named parameters: POST JSON', () async {
      var (status, body) = await _httpCall(
        apiServer,
        'POST',
        'raw/withNamedNoResponse',
        body: convert.json.encode({'id': 9}),
        contentType: 'application/json',
      );

      expect(status, equals(200), reason: body);
      expect(
        convert.json.decode(body),
        equals({'path': '/raw/withNamedNoResponse', 'id': 9}),
      );
    });

    test('proxy: `APIRequest` + named parameters', () async {
      var proxy = RawHandlerModuleProxy(
        mercury_client.HttpClient(apiServer.url),
      );

      expect(
        await proxy.withNamed(establishmentId: 10, otherId: 22, label: 'P'),
        equals({
          'path': '/raw/withNamed',
          'establishmentId': 10,
          'otherId': 22,
          'label': 'P',
        }),
      );

      expect(
        await proxy.withNamed(establishmentId: 10),
        equals({
          'path': '/raw/withNamed',
          'establishmentId': 10,
          'otherId': null,
          'label': 'def',
        }),
      );

      await expectLater(
        proxy.withNamed(establishmentId: 11),
        throwsA(isA<APIModuleProxyCallerResponseError>()),
      );

      expect(
        await proxy.withOptional(23),
        equals({'path': '/raw/withOptional', 'id': 23}),
      );

      expect(
        await proxy.withCredential(establishmentId: 24),
        equals({'path': '/raw/withCredential', 'establishmentId': 24}),
      );
    });
  });
}

Future<(int, String)> _httpCall(
  APIServer apiServer,
  String method,
  String path, {
  String? body,
  String? contentType,
}) async {
  var httpClient = HttpClient();
  try {
    var request = await httpClient.openUrl(
      method,
      Uri.parse('${apiServer.url}$path'),
    );

    if (body != null) {
      if (contentType != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      request.write(body);
    }

    var response = await request.close();
    var responseBody = await convert.utf8.decodeStream(response);
    return (response.statusCode, responseBody);
  } finally {
    httpClient.close();
  }
}

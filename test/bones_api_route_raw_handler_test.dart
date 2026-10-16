@TestOn('vm')
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

part 'bones_api_route_raw_handler_test.reflection.g.dart';

class RawHandlerAPIRoot extends APIRoot {
  RawHandlerAPIRoot() : super('raw-handler-test', '1.0');

  @override
  Set<APIModule> loadModules() => {RawHandlerModule(this)};
}

/// A rule that only allows requests with `establishmentId == 10`,
/// read from the request parameters.
class EstablishmentRule extends APIRouteRule {
  const EstablishmentRule() : super();

  @override
  bool validate(APIRequest request) {
    var establishmentId = request.getParameterIgnoreCase('establishmentId');
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
}

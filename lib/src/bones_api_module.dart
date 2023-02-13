import 'dart:convert';
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:data_serializer/data_serializer.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mercury_client/mercury_client.dart';
import 'package:meta/meta_meta.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart'
    show Decimal, DynamicInt, DynamicNumber, ListExtension;
import 'package:swiss_knife/swiss_knife.dart' show MimeType, DataURLBase64;

import 'bones_api_authentication.dart';
import 'bones_api_base.dart';
import 'bones_api_config.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_rules.dart';
import 'bones_api_extension.dart';
import 'bones_api_initializable.dart';
import 'bones_api_security.dart';
import 'bones_api_types.dart';
import 'bones_api_utils_json.dart';

final _log = logging.Logger('APIModule');

/// A module of an API.
abstract class APIModule with Initializable {
  static const Set<String> interfaceMethodsNames = <String>{
    'acceptsRequest',
    'addRoute',
    'apiInfo',
    'call',
    'configure',
    'ensureConfigured',
    'getRouteHandler',
    'getRouteHandlerByRequest',
    'getRoutesHandlersNames',
    'resolveRoute',
    ...Initializable.interfaceMethodsNames,
  };

  /// The API root, that is loading this module.
  final APIRoot apiRoot;

  /// The name of this API module.
  final String name;

  /// Optional module version.
  final String? version;

  late final APIRouteBuilder _routeBuilder;

  APIModule(this.apiRoot, String name, {this.version})
      : name = name.trim().toLowerCase() {
    BonesAPI.boot();
    _routeBuilder = APIRouteBuilder(this);
  }

  /// The [APIConfig] from [apiRoot].
  APIConfig get apiConfig => apiRoot.apiConfig;

  /// The default route to use when the request doesn't match.
  String? get defaultRouteName => null;

  /// Configures this API module. Usually defines the routes of this instance.
  void configure();

  bool _configured = false;

  void ensureConfigured() {
    if (_configured) return;
    _configured = true;
    configure();
  }

  @override
  FutureOr<InitializationResult> initialize() {
    ensureConfigured();
    return InitializationResult.ok(this);
  }

  final Map<String, APIRouteHandler> _routesHandlers =
      <String, APIRouteHandler>{};

  final Map<String, APIRouteHandler> _routesHandlersGET =
      <String, APIRouteHandler>{};

  final Map<String, APIRouteHandler> _routesHandlersPOST =
      <String, APIRouteHandler>{};

  final Map<String, APIRouteHandler> _routesHandlersPUT =
      <String, APIRouteHandler>{};

  final Map<String, APIRouteHandler> _routesHandlersDELETE =
      <String, APIRouteHandler>{};

  final Map<String, APIRouteHandler> _routesHandlersPATH =
      <String, APIRouteHandler>{};

  /// Returns all the routes names.
  Set<String> get allRoutesNames => {
        ..._routesHandlers.keys,
        ..._routesHandlersGET.keys,
        ..._routesHandlersPOST.keys,
        ..._routesHandlersPUT.keys,
        ..._routesHandlersDELETE.keys,
        ..._routesHandlersPATH.keys,
      };

  /// Returns the routes names for [method].
  Iterable<String> getRoutesHandlersNames({APIRequestMethod? method}) {
    var handlers = _getRoutesHandlers(method);
    return handlers.keys;
  }

  Map<String, APIRouteHandler> _getRoutesHandlers(APIRequestMethod? method) {
    switch (method) {
      case APIRequestMethod.GET:
        return _routesHandlersGET;
      case APIRequestMethod.POST:
        return _routesHandlersPOST;
      case APIRequestMethod.PUT:
        return _routesHandlersPUT;
      case APIRequestMethod.DELETE:
        return _routesHandlersDELETE;
      case APIRequestMethod.PATCH:
        return _routesHandlersPATH;
      default:
        return _routesHandlers;
    }
  }

  /// Adds a route, of [name], to this module.
  ///
  /// [method] The route method. If `null` accepts any method.
  /// [function] The route handler, to process calls.
  APIModule addRoute(
      APIRequestMethod? method, String name, APIRouteFunction function,
      {Map<String, TypeInfo>? parameters, Iterable<APIRouteRule>? rules}) {
    if (method == APIRequestMethod.OPTIONS) {
      throw ArgumentError("Can't add a route with method `OPTIONS`."
          "Requests with method `OPTIONS` are reserved for CORS or other informational requests.");
    }

    var routesHandlers = _getRoutesHandlers(method);
    routesHandlers[name] =
        APIRouteHandler(this, method, name, function, parameters, rules);
    return this;
  }

  /// Returns the routes builder of this module.
  APIRouteBuilder get routes => _routeBuilder;

  /// Returns a route handler for [name].
  APIRouteHandler<T>? getRouteHandler<T>(String name,
      [APIRequestMethod? method]) {
    var handler = _getRouteHandlerImpl<T>(name, method);

    if (handler == null) {
      var def = defaultRouteName;
      if (def != null) {
        handler = _getRouteHandlerImpl<T>(def, method);
      }
    }

    return handler;
  }

  APIRouteHandler<T>? _getRouteHandlerImpl<T>(
      String name, APIRequestMethod? method) {
    ensureConfigured();

    var routesHandlers = _getRoutesHandlers(method);
    var handler = routesHandlers[name];

    if (handler == null && method != null) {
      handler = _routesHandlers[name];
    }

    return handler as APIRouteHandler<T>?;
  }

  /// Returns a route handler for [request].
  ///
  /// Calls [resolveRoute] to determine the route name of the [request].
  APIRouteHandler<T>? getRouteHandlerByRequest<T>(APIRequest request,
      [String? routeName]) {
    ensureConfigured();

    routeName ??= resolveRoute(request);
    return getRouteHandler(routeName, request.method);
  }

  /// Resolves the route name of the [request].
  String resolveRoute(APIRequest request) {
    var routeName = request.pathPartAt(1) ?? request.pathPartAt(0) ?? '';
    return routeName;
  }

  /// Calls a route for [request].
  FutureOr<APIResponse<T>> call<T>(APIRequest request) {
    ensureConfigured();

    var routeName = resolveRoute(request);

    var apiSecurity = security;

    if (apiSecurity != null) {
      if (routeName == authenticationRoute) {
        return apiSecurity.doRequestAuthentication(request);
      } else if (request.authentication == null) {
        return apiSecurity.resumeAuthenticationByRequest(request).then((_) {
          return _callImpl<T>(request, routeName);
        });
      }
    }

    return _callImpl<T>(request, routeName);
  }

  static final MimeType _mimeTypeJson = MimeType.parse(MimeType.json)!;

  FutureOr<APIResponse<T>> _callImpl<T>(
      APIRequest apiRequest, String routeName) {
    if (routeName == 'API-INFO') {
      var info = apiInfo(apiRequest);
      return APIResponse.ok(info as T, mimeType: _mimeTypeJson);
    }

    var handler = getRouteHandlerByRequest<T>(apiRequest, routeName);

    if (handler == null) {
      return apiRoot.onNoRouteForPath(apiRequest);
    }

    try {
      var response = handler.call(apiRequest);
      return response;
    } catch (e, s) {
      _log.severe(
          'Error calling route `$routeName` of module `$name`! APIModule: `$runtimeType` ; APIRequest: ${apiRequest.toString(withHeaders: false, withPayload: false)}',
          e,
          s);
      var error = 'ERROR: $e\n$s';
      return APIResponse.error(error: error, stackTrace: s);
    }
  }

  /// Returns `true` if [apiRequest] is an accepted route/call for this module.
  bool acceptsRequest(APIRequest apiRequest) {
    var routeName = resolveRoute(apiRequest);

    if (routeName == 'API-INFO' || routeName == authenticationRoute) {
      return true;
    } else {
      var handler = getRouteHandlerByRequest(apiRequest, routeName);
      return handler != null;
    }
  }

  /// Returns a [APIModuleInfo].
  APIModuleInfo apiInfo([APIRequest? apiRequest]) =>
      APIModuleInfo(this, apiRequest);

  String get authenticationRoute => 'authenticate';

  APISecurity? get security => _securityImpl();

  APISecurity? _security;
  bool _securityResolved = false;

  APISecurity? _securityImpl() {
    if (_securityResolved) return _security;
    _securityResolved = true;

    return _security = apiRoot.security;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is APIModule &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// The [APIModule] information.
///
/// Returned by `API-INFO`.
class APIModuleInfo {
  final APIModule module;
  final APIRequest? apiRequest;

  APIModuleInfo(this.module, [this.apiRequest]);

  /// Returns the name of the [module].
  String get name => module.name;

  /// Returns the version of the [module].
  String? get version => module.version;

  /// Returns the routes of the [module].
  List<APIRouteInfo> get routes => module.routes.apiInfo(apiRequest);

  Map<String, dynamic> toJson() => {
        'name': name,
        if (version != null) 'version': version,
        'routes': routes.map((e) => e.toJson()).toList()
      };
}

/// A route builder.
class APIRouteBuilder<M extends APIModule> {
  /// The API module of this route builder.
  final M module;

  APIRouteBuilder(this.module);

  /// Adds a route of [name] with [handler] for ANY request method.
  APIModule any(String name, APIRouteFunction function,
          {Map<String, TypeInfo>? parameters, Iterable<APIRouteRule>? rules}) =>
      add(null, name, function, parameters: parameters, rules: rules);

  /// Adds a route of [name] with [handler] for `GET` request method.
  APIModule get(String name, APIRouteFunction function,
          {Map<String, TypeInfo>? parameters, Iterable<APIRouteRule>? rules}) =>
      add(APIRequestMethod.GET, name, function,
          parameters: parameters, rules: rules);

  /// Adds a route of [name] with [handler] for `POST` request method.
  APIModule post(String name, APIRouteFunction function,
          {Map<String, TypeInfo>? parameters, Iterable<APIRouteRule>? rules}) =>
      add(APIRequestMethod.POST, name, function,
          parameters: parameters, rules: rules);

  /// Adds a route of [name] with [handler] for `PUT` request method.
  APIModule put(String name, APIRouteFunction function,
          {Map<String, TypeInfo>? parameters, Iterable<APIRouteRule>? rules}) =>
      add(APIRequestMethod.PUT, name, function,
          parameters: parameters, rules: rules);

  /// Adds a route of [name] with [handler] for `DELETE` request method.
  APIModule delete(String name, APIRouteFunction function,
          {Map<String, TypeInfo>? parameters, Iterable<APIRouteRule>? rules}) =>
      add(APIRequestMethod.DELETE, name, function,
          parameters: parameters, rules: rules);

  /// Adds a route of [name] with [handler] for `PATCH` request method.
  APIModule patch(String name, APIRouteFunction function,
          {Map<String, TypeInfo>? parameters, Iterable<APIRouteRule>? rules}) =>
      add(APIRequestMethod.PATCH, name, function,
          parameters: parameters, rules: rules);

  /// Adds a route of [name] with [handler] for the request [method].
  APIModule add(
          APIRequestMethod? method, String name, APIRouteFunction function,
          {Map<String, TypeInfo>? parameters, Iterable<APIRouteRule>? rules}) =>
      module.addRoute(method, name, function,
          parameters: parameters, rules: rules);

  /// Adds routes from [provider] for ANY request method.
  void anyFrom(Object? provider) => from(null, provider);

  /// Adds routes from [provider] for `GET` request method.
  void getFrom(Object? provider) => from(APIRequestMethod.GET, provider);

  /// Adds routes from [provider] for `POS` request method.
  void postFrom(Object? provider) => from(APIRequestMethod.POST, provider);

  /// Adds routes from [provider] for `PUT` request method.
  void putFrom(Object? provider) => from(APIRequestMethod.PUT, provider);

  /// Adds routes from [provider] for `DELETE` request method.
  void deleteFrom(Object? provider) => from(APIRequestMethod.DELETE, provider);

  /// Adds routes from [provider] for `PATCH` request method.
  void patchFrom(Object? provider) => from(APIRequestMethod.PATCH, provider);

  /// Adds routes from [provider] for the request [requestMethod].
  ///
  /// [provider] can be one of the types below:
  /// - [MethodReflection]: a route from a reflection method (uses the method name as route name). See [apiMethod].
  /// - [Iterable<MethodReflection>]: a list of many routes from [MethodReflection]. See [apiMethods].
  /// - [ClassReflection]: uses the API methods in the reflected class. See [apiReflection].
  /// - [Iterable]: a list of any of the provider types above.
  void from(APIRequestMethod? requestMethod, Object? provider) {
    if (provider == null) return;

    if (provider is MethodReflection) {
      apiMethod(provider, requestMethod);
    } else if (provider is Iterable<MethodReflection>) {
      apiMethods(provider, requestMethod);
    } else if (provider is ClassReflection) {
      apiReflection(provider, requestMethod);
    } else if (provider is Iterable) {
      for (var e in provider) {
        from(e, requestMethod);
      }
    }
  }

  /// Adds routes from a [reflection], one for each API method in the reflected class.
  /// See [ClassReflectionExtension.apiMethods].
  ///
  /// - [requestMethod] the route request method.
  void apiReflection(ClassReflection reflection,
      [APIRequestMethod? requestMethod]) {
    var methods = reflection.apiMethods();
    apiMethods(methods, requestMethod);
  }

  /// Adds the routes from [apiMethods]. See [apiMethod].
  void apiMethods(Iterable<MethodReflection> apiMethods,
      [APIRequestMethod? requestMethod]) {
    for (var m in apiMethods) {
      apiMethod(m, requestMethod);
    }
  }

  /// Adds a route from [apiMethod], using the same name of the methods as route.
  /// See [MethodReflectionExtension.isAPIMethod].
  ///
  /// - [requestMethod] the route request method.
  void apiMethod(MethodReflection apiMethod,
      [APIRequestMethod? requestMethod]) {
    var returnsAPIResponse = apiMethod.returnsAPIResponse;
    var receivesAPIRequest = apiMethod.receivesAPIRequest;

    var methodRules = apiMethod.annotations.whereType<APIRouteRule>().toList();
    var classRules = apiMethod.classReflection.classAnnotations
        .whereType<APIRouteRule>()
        .toList();

    List<APIRouteRule> rules;
    if (methodRules.isEmpty) {
      rules = classRules;
    } else {
      var noGlobalRules = methodRules.any((r) => r.noGlobalRules);

      rules = noGlobalRules
          ? methodRules
          : [
              ...methodRules,
              ...classRules.where((r) => r.globalRules),
            ];
    }

    if (returnsAPIResponse && receivesAPIRequest) {
      var paramName = apiMethod.normalParametersNames.first;
      var parameters = <String, TypeInfo>{paramName: APIRequest.typeInfo};

      add(
        requestMethod,
        apiMethod.name,
        (req) => _apiMethodStandard(apiMethod, req),
        parameters: parameters,
        rules: rules,
      );
    } else if (receivesAPIRequest) {
      var paramName = apiMethod.normalParametersNames.first;
      var parameters = <String, TypeInfo>{paramName: APIRequest.typeInfo};

      add(
        requestMethod,
        apiMethod.name,
        (req) => _apiMethodStandard(apiMethod, req),
        parameters: parameters,
        rules: rules,
      );
    } else if (returnsAPIResponse) {
      var parameters = Map<String, TypeInfo>.fromEntries(apiMethod.allParameters
          .map((p) => MapEntry(p.name, TypeInfo.from(p))));

      add(
        requestMethod,
        apiMethod.name,
        (req) => _apiMethodInvocation(apiMethod, req),
        parameters: parameters,
        rules: rules,
      );
    }
  }

  FutureOr<APIResponse> _apiMethodStandard(
      MethodReflection apiMethod, APIRequest request) {
    var ret = apiMethod.invoke([request]);
    if (ret is Future) {
      return ret.then((r) => APIResponse.from(r));
    } else {
      return APIResponse.from(ret);
    }
  }

  FutureOr<APIResponse> _apiMethodInvocation(
      MethodReflection apiMethod, APIRequest request) {
    var methodInvocation = _resolveMethodInvocation(apiMethod, request);
    return methodInvocation.invoke(apiMethod.method);
  }

  MethodInvocation _resolveMethodInvocation(
      MethodReflection method, APIRequest request) {
    var payloadIsParametersMap = _isPayloadParametersMap(method, request);

    var methodInvocation = method.methodInvocation((p, i) =>
        _resolveRequestParameter(request, p, i, payloadIsParametersMap));

    return methodInvocation;
  }

  bool _isPayloadParametersMap(MethodReflection method, APIRequest request) {
    var payload = request.payload;
    if (payload is! Map) return false;

    var allParametersNames = method.allParametersNames;

    if (payload.isEmpty && allParametersNames.isNotEmpty) return false;

    var hasNonParameterKey =
        payload.keys.any((k) => !allParametersNames.containsIgnoreCase(k));

    return !hasNonParameterKey;
  }

  static final TypeInfo _typeInfoDecimal = TypeInfo.fromType(Decimal);
  static final TypeInfo _typeInfoDynamicInt = TypeInfo.fromType(DynamicInt);
  static final TypeInfo _typeInfoDynamicNumber =
      TypeInfo.fromType(DynamicNumber);

  static final TypeInfo _typeInfoTime = TypeInfo.fromType(Time);

  Object? _resolveRequestParameter(
      APIRequest request,
      ParameterReflection parameter,
      int? parameterIndex,
      bool payloadIsParametersMap,
      {EntityResolutionRules? resolutionRules}) {
    var parameterTypeInfo = parameter.type.typeInfo;

    if (parameterTypeInfo.isOf(APIRequest)) {
      return request;
    } else if (parameterTypeInfo.isOf(APICredential)) {
      return request.credential;
    } else if (parameterTypeInfo.isOf(APIAuthentication)) {
      return request.authentication;
    }

    Object? value = request.getParameterIgnoreCase(parameter.name);

    if (value == null) {
      if (request.hasPayload) {
        if (payloadIsParametersMap) {
          var map = request.payload as Map<String, Object?>;
          value = map.getIgnoreCase(parameter.name);
        } else {
          if (parameterTypeInfo.isUInt8List) {
            return request.payloadAsBytes;
          }

          var payload = request.payload;
          var payloadTypeInfo = TypeInfo.from(payload);

          if (parameterTypeInfo.equalsTypeAndArguments(payloadTypeInfo)) {
            return payload;
          } else if (payload is Map &&
              EntityHandler.isValidEntityType(parameterTypeInfo.type)) {
            return _resolveValueAsEntity(parameterTypeInfo, payload,
                resolutionRules: resolutionRules);
          } else if (payload is List &&
              parameterTypeInfo.isListEntity &&
              EntityHandler.isValidEntityType(
                  parameterTypeInfo.listEntityType!.type)) {
            return _resolveValueAsEntity(parameterTypeInfo, payload,
                resolutionRules: resolutionRules);
          }
        }
      }

      if (value == null && parameterIndex != null) {
        var pathPart = request.pathPartAt(2 + parameterIndex);
        value = pathPart;
      }
    }

    if (value == null) return null;

    return _resolveValueType(parameterTypeInfo, value);
  }

  Object? _resolveValueType(TypeInfo typeInfo, Object? value,
      {EntityCache? entityCache, EntityResolutionRules? resolutionRules}) {
    if (value == null) {
      return null;
    } else if (typeInfo.type == value.runtimeType && !typeInfo.hasArguments) {
      return value;
    } else if (typeInfo.isNumber) {
      var n = typeInfo.parse(value);
      return n;
    } else if (typeInfo.isString) {
      var s = typeInfo.parse(value);
      return s;
    } else if (typeInfo.equalsType(_typeInfoDecimal)) {
      return Decimal.from(value);
    } else if (typeInfo.equalsType(_typeInfoDynamicInt)) {
      return DynamicInt.from(value);
    } else if (typeInfo.equalsType(_typeInfoDynamicNumber)) {
      return DynamicNumber.from(value);
    } else if (typeInfo.equalsType(_typeInfoTime)) {
      return Time.from(value);
    } else if (typeInfo.isUInt8List) {
      var bytes = _resolveRequestParameterValueAsBytes(value);
      return bytes;
    } else {
      if (!typeInfo.isPrimitiveType) {
        var o = _resolveValueAsEntity(typeInfo, value,
            entityCache: entityCache, resolutionRules: resolutionRules);
        if (o != null) return o;
      }

      var parsed = typeInfo.parse(value);
      return parsed ?? value;
    }
  }

  Uint8List? _resolveRequestParameterValueAsBytes(Object value) {
    if (value is List<int>) {
      var data = value.asUint8List;
      return data;
    } else if (value is String) {
      var dataUrl = DataURLBase64.parse(value);
      if (dataUrl != null) {
        return dataUrl.payloadArrayBuffer;
      }

      try {
        var data = base64.decode(value);
        return data;
      } catch (_) {
        // not a Base64 data:
      }

      try {
        var data = hex.decode(value);
        return data;
      } catch (_) {
        // not a HEX data:
      }
    }

    return null;
  }

  Object? _resolveValueAsEntity(TypeInfo parameterTypeInfo, Object? value,
      {EntityCache? entityCache, EntityResolutionRules? resolutionRules}) {
    if (value == null) return null;

    entityCache ??= JsonEntityCacheSimple();
    var valueTypeInfo = TypeInfo.from(value);

    if (parameterTypeInfo.equalsTypeAndArguments(valueTypeInfo)) {
      return value;
    }

    var reflectionFactory = ReflectionFactory();

    if (parameterTypeInfo.isListEntity) {
      var listEntityType = parameterTypeInfo.listEntityType!;

      if (value is Iterable) {
        var list = value
            .map((e) => _resolveValueAsEntity(listEntityType, e,
                entityCache: entityCache, resolutionRules: resolutionRules))
            .toList();

        return _castList(list, listEntityType);
      } else {
        var list = TypeParser.parseList(value,
            elementParser: (e) => _resolveValueAsEntity(listEntityType, e,
                entityCache: entityCache, resolutionRules: resolutionRules));

        if (list != null) {
          return _castList(list, listEntityType);
        }
      }
    } else if (!parameterTypeInfo.isBasicType) {
      if (value is Map) {
        var classReflection = reflectionFactory
            .getRegisterClassReflection(parameterTypeInfo.type);

        if (classReflection != null) {
          var map = value is Map<String, Object?>
              ? value
              : value.map((k, v) => MapEntry(k.toString(), v));

          var o = classReflection.createFromMap(map,
              entityCache: entityCache, resolutionRules: resolutionRules);
          if (o != null) {
            return o;
          }
        }
      } else if (value is String) {
        var enumReflection =
            reflectionFactory.getRegisterEnumReflection(parameterTypeInfo.type);

        if (enumReflection != null) {
          var o = enumReflection.from(value);
          if (o != null) {
            return o;
          }
        }
      }
    }

    return parameterTypeInfo.parse(value);
  }

  List _castList(List<Object?> list, TypeInfo typeInfo) {
    var reflectionFactory = ReflectionFactory();

    var classReflection =
        reflectionFactory.getRegisterClassReflection(typeInfo.type);
    if (classReflection != null) {
      var nullable = list.any((e) => e == null);
      return classReflection.castList(list, typeInfo.type,
              nullable: nullable) ??
          list;
    }

    var enumReflection =
        reflectionFactory.getRegisterEnumReflection(typeInfo.type);
    if (enumReflection != null) {
      var nullable = list.any((e) => e == null);
      return enumReflection.castList(list, typeInfo.type, nullable: nullable) ??
          list;
    }

    return list;
  }

  List<APIRouteInfo> apiInfo([APIRequest? apiRequest]) {
    var routesHandlers = <APIRouteHandler>[
      ...module._routesHandlers.values,
      ...module._routesHandlersGET.values,
      ...module._routesHandlersPOST.values,
      ...module._routesHandlersPATH.values,
      ...module._routesHandlersPUT.values,
      ...module._routesHandlersDELETE.values,
    ].toDistinctList();

    var info = routesHandlers.map((e) => e.apiInfo(apiRequest)).toList();
    return info;
  }
}

/// A [ClassProxy] annotation for proxies on [APIModule] classes.
@Target({TargetKind.classType})
class APIModuleProxy extends ClassProxy {
  const APIModuleProxy(
    String moduleClassName, {
    String libraryName = '',
    String libraryPath = '',
  }) : super(moduleClassName,
            libraryName: libraryName,
            libraryPath: libraryPath,
            ignoreMethods: APIModule.interfaceMethodsNames,
            alwaysReturnFuture: true,
            traverseReturnTypes: const {
              APIResponse
            },
            ignoreParametersTypes: const {
              APIRequest,
              APICredential,
              APIAuthentication,
            });
}

typedef APIModuleHttpProxyRequestHandler = FutureOr<dynamic>? Function(
    APIModuleHttpProxy proxy,
    String methodName,
    Map<String, Object?> parameters);

/// Implements a [ClassProxyListener] that redirects calls to [httpClient].
class APIModuleHttpProxy implements ClassProxyListener {
  /// The [httpClient] ot perform the proxy calls.
  final HttpClient httpClient;

  /// The module path in the [httpClient] base URL.
  final String modulePath;

  /// If `true` all the returned responses of [httpClient] requests will be decoded as JSON.
  /// If `false` will treat as response only of `Content-Type` is JSON or JavaScript ([HttpResponse.isBodyTypeJSON]).
  final bool responsesAsJson;

  APIModuleHttpProxy(this.httpClient,
      {String? moduleRoute, this.responsesAsJson = true})
      : modulePath = _normalizeModulePath(moduleRoute) {
    BonesAPI.boot();
  }

  static String _normalizeModulePath(String? path) {
    if (path == null) return '';
    var p = path.trim();

    while (p.startsWith('/')) {
      p = p.substring(1);
    }

    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }

    return p;
  }

  APIModuleHttpProxyRequestHandler? requestHandler;

  Future<dynamic> doRequest(
      String methodName, Map<String, Object?> parameters) async {
    var requestHandler = this.requestHandler;

    if (requestHandler != null) {
      var ret = requestHandler(this, methodName, parameters);
      if (ret != null) return ret;
    }

    var needsJsonRequest = false;

    parameters = parameters.map((key, value) {
      var val = value;
      if ((!value.isPrimitiveValue &&
              !value.isPrimitiveList &&
              !value.isPrimitiveMap) ||
          (value is Uint8List)) {
        val = Json.toJson(value);
        needsJsonRequest = true;
      }
      return MapEntry(key, val);
    });

    var path = modulePath.isNotEmpty ? '$modulePath/$methodName' : methodName;

    HttpResponse response;
    if (needsJsonRequest) {
      response = await httpClient.post(path,
          body: parameters, contentType: MimeType.json);
    } else {
      response = await httpClient.get(path, parameters: parameters);
    }

    return parseResponse(response);
  }

  FutureOr<dynamic> parseResponse(HttpResponse response) {
    if (response.isNotOK) return null;

    var body = response.body;
    if (body == null) return null;

    MimeType? mimeType = body.mimeType;

    if (isJsonResponse(response, mimeType)) {
      var content = response.bodyAsString;
      if (content == null) return null;
      return decodeJson(content);
    } else if (mimeType == null || isTextResponse(response, mimeType)) {
      return body.asString;
    } else if (isByteArrayResponse(response, mimeType)) {
      return body.asByteArray;
    } else if (mimeType.isFormURLEncoded) {
      return Uri.splitQueryString(body.asString ?? '');
    } else {
      return body.asString;
    }
  }

  bool isJsonResponse(HttpResponse response, MimeType? mimeType) =>
      responsesAsJson || response.isBodyTypeJSON;

  bool isTextResponse(HttpResponse response, MimeType? mimeType) =>
      mimeType != null &&
      (mimeType.isText || mimeType.isXHTML || mimeType.isXML);

  bool isByteArrayResponse(HttpResponse response, MimeType? mimeType) =>
      mimeType != null &&
      (mimeType.isImage || mimeType.isAudio || mimeType.isVideo);

  FutureOr<dynamic> decodeJson(String content) {
    try {
      return Json.decode(content);
    } on FormatException {
      return content;
    }
  }

  @override
  Future onCall(dynamic instance, String methodName,
      Map<String, Object?> parameters, TypeReflection? returnType) async {
    var json = await doRequest(methodName, parameters);
    if (returnType == null || json == null) return json;

    var typeInfo = returnType.typeInfo;
    var mainType =
        typeInfo.isFuture ? (typeInfo.arguments0 ?? typeInfo) : typeInfo;

    return mainType.fromJson(json);
  }
}

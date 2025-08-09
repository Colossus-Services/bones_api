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
import 'bones_api_utils.dart';
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

  final Map<String, APIRouteHandler> _routesHandlersHEAD =
      <String, APIRouteHandler>{};

  /// Returns all the routes names.
  Set<String> get allRoutesNames => {
        ..._routesHandlers.keys,
        ..._routesHandlersGET.keys,
        ..._routesHandlersPOST.keys,
        ..._routesHandlersPUT.keys,
        ..._routesHandlersDELETE.keys,
        ..._routesHandlersPATH.keys,
        ..._routesHandlersHEAD.keys,
      };

  /// Returns the routes names for [method].
  Iterable<String> getRoutesHandlersNames({APIRequestMethod? method}) {
    var handlers = _getRoutesHandlers(method);
    return handlers.keys;
  }

  Map<String, APIRouteHandler> _getRoutesHandlers(APIRequestMethod? method) {
    if (method == null) {
      return _routesHandlers;
    }

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
      case APIRequestMethod.HEAD:
        return _routesHandlersHEAD;
      case APIRequestMethod.OPTIONS:
        return _routesHandlers;
    }
  }

  /// Adds a route, of [name], to this module.
  ///
  /// [method] The route method. If `null` accepts any method.
  /// [function] The route handler, to process calls.
  APIModule addRoute(
      APIRequestMethod? method, String name, APIRouteFunction function,
      {Map<String, TypeInfo>? parameters,
      Iterable<APIRouteRule>? rules,
      APIRouteConfig? config}) {
    _checkMethodNotOPTIONS(method);

    var routeHandler = APIRouteHandlerFunction(
        this, method, name, function, parameters, rules, config);

    var routesHandlers = _getRoutesHandlers(method);
    routesHandlers[name] = routeHandler;
    return this;
  }

  /// Adds a [routeHandler], of [name], to this module.
  ///
  /// [routeHandler] The route handler, to process calls.
  APIModule addRouteHandler(APIRouteHandler routeHandler) {
    final method = routeHandler.requestMethod;
    _checkMethodNotOPTIONS(method);

    var routesHandlers = _getRoutesHandlers(method);
    routesHandlers[routeHandler.routeName] = routeHandler;
    return this;
  }

  void _checkMethodNotOPTIONS(APIRequestMethod? method) {
    if (method == APIRequestMethod.OPTIONS) {
      throw ArgumentError("Can't add a route with method `OPTIONS`."
          "Requests with method `OPTIONS` are reserved for CORS or other informational requests.");
    }

    var routesHandlers = _getRoutesHandlers(method);
    routesHandlers[name] = APIRouteHandler(
        this, method, name, function, parameters, rules, config);
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
  final ClassReflection? moduleClassReflection;
  final APIRequest? apiRequest;

  APIModuleInfo(this.module, [this.apiRequest])
      : moduleClassReflection =
            ReflectionFactory().getRegisterClassReflection(module.runtimeType);

  /// Returns the name of the [module].
  String get name => module.name;

  /// Returns the version of the [module].
  String? get version => module.version;

  /// Returns the routes of the [module].
  List<APIRouteInfo> get routes => module.routes.apiInfo(apiRequest);

  /// Returns the module rules (through [moduleClassReflection]).
  List<APIRouteRule> get rules =>
      moduleClassReflection?.classAnnotations
          .whereType<APIRouteRule>()
          .toList() ??
      [];

  Map<String, dynamic> toJson() {
    var rules = this.rules;

    return {
      'name': name,
      if (version != null) 'version': version,
      'routes': routes.map((e) => e.toJson()).toList(),
      if (rules.isNotEmpty) 'rules': rules,
    };
  }
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

  /// Adds a route of [name] with [handler] for `HEAD` request method.
  APIModule head(String name, APIRouteFunction function,
          {Map<String, TypeInfo>? parameters, Iterable<APIRouteRule>? rules}) =>
      add(APIRequestMethod.HEAD, name, function,
          parameters: parameters, rules: rules);

  /// Adds a route of [name] with [handler] for the request [method].
  APIModule add(
          APIRequestMethod? method, String name, APIRouteFunction function,
          {Map<String, TypeInfo>? parameters,
          Iterable<APIRouteRule>? rules,
          APIRouteConfig? config}) =>
      module.addRoute(method, name, function,
          parameters: parameters, rules: rules, config: config);

  /// Adds a [routeHandler] of [name] with [handler] for the request [method].
  APIModule addRouteHandler(APIRouteHandler routeHandler) =>
      module.addRouteHandler(routeHandler);

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

  /// Adds routes from [provider] for `HEAD` request method.
  void headFrom(Object? provider) => from(APIRequestMethod.HEAD, provider);

  /// Adds routes from [provider] for the request [requestMethod].
  ///
  /// [provider] can be one of the types below:
  /// - [MethodReflection]: a route from a reflection method (uses the method name as route name). See [apiMethod].
  /// - [Iterable<MethodReflection>]: a list of many routes from [MethodReflection]. See [apiMethods].
  /// - [ClassReflection]: uses the API methods in the reflected class. See [apiReflection].
  /// - [Iterable]: a list of any of the provider types above.
  bool from(APIRequestMethod? requestMethod, Object? provider) {
    if (provider == null) return false;

    if (provider is MethodReflection) {
      return apiMethod(provider, requestMethod);
    } else if (provider is Iterable<MethodReflection>) {
      return apiMethods(provider, requestMethod);
    } else if (provider is ClassReflection) {
      return apiReflection(provider, requestMethod);
    } else if (provider is Iterable) {
      var addedAny = false;
      for (var e in provider) {
        var added = from(e, requestMethod);
        addedAny |= added;
      }
      return addedAny;
    }

    return false;
  }

  /// Adds routes from a [reflection], one for each API method in the reflected class.
  /// See [ClassReflectionExtension.apiMethods].
  ///
  /// - [requestMethod] the route request method.
  bool apiReflection(ClassReflection reflection,
      [APIRequestMethod? requestMethod]) {
    var methods = reflection.apiMethods();
    return apiMethods(methods, requestMethod);
  }

  /// Adds the routes from [apiMethods]. See [apiMethod].
  bool apiMethods(Iterable<MethodReflection> apiMethods,
      [APIRequestMethod? requestMethod]) {
    var addedAny = false;
    for (var m in apiMethods) {
      var added = apiMethod(m, requestMethod);
      addedAny |= added;
    }
    return addedAny;
  }

  /// Adds a route from [apiMethod], using the same name of the methods as route.
  /// See [MethodReflectionExtension.isAPIMethod].
  ///
  /// - [requestMethod] the route request method.
  bool apiMethod(MethodReflection apiMethod,
      [APIRequestMethod? requestMethod]) {
    var classReflection = apiMethod.classReflection;

    if (classReflection.supperTypes.contains(APIModule) &&
        APIModule.interfaceMethodsNames.contains(apiMethod.name)) {
      return false;
    }

    var returnsAPIResponse = apiMethod.returnsAPIResponse;
    var receivesAPIRequest = apiMethod.receivesAPIRequest;

    var methodRules = apiMethod.annotations.whereType<APIRouteRule>().toList();
    var classRules =
        classReflection.classAnnotations.whereType<APIRouteRule>().toList();

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

    var config = apiMethod.annotations.whereType<APIRouteConfig>().firstOrNull;

    if (returnsAPIResponse && receivesAPIRequest) {
      var paramName = apiMethod.normalParametersNames.first;
      var parameters = <String, TypeInfo>{paramName: APIRequest.typeInfo};

      add(
        requestMethod,
        apiMethod.name,
        // ignore: discarded_futures
        (req) => _apiMethodStandard(apiMethod, req),
        parameters: parameters,
        rules: rules,
        config: config,
      );

      return true;
    } else if (receivesAPIRequest) {
      var paramName = apiMethod.normalParametersNames.first;
      var parameters = <String, TypeInfo>{paramName: APIRequest.typeInfo};

      add(
        requestMethod,
        apiMethod.name,
        // ignore: discarded_futures
        (req) => _apiMethodStandard(apiMethod, req),
        parameters: parameters,
        rules: rules,
        config: config,
      );

      return true;
    } else if (returnsAPIResponse) {
      var parameters = Map<String, TypeInfo>.fromEntries(apiMethod.allParameters
          .map((p) => MapEntry(p.name, TypeInfo.from(p))));

      add(
        requestMethod,
        apiMethod.name,
        // ignore: discarded_futures
        (req) => _apiMethodInvocation(apiMethod, req),
        parameters: parameters,
        rules: rules,
        config: config,
      );

      return true;
    }

    return false;
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
    var ret = methodInvocation.invoke(apiMethod.method);

    if (ret == null) {
      return APIResponse.error(
          error: "Call returned `null` (not an `APIResponse`): $apiMethod");
    } else if (ret is Future && ret is! Future<APIResponse>) {
      return ret.then((ret) {
        if (ret == null) {
          return APIResponse.error(
              error: "Call returned `null` (not an `APIResponse`): $apiMethod");
        } else {
          try {
            return ret as APIResponse;
          } catch (e, s) {
            return APIResponse.error(
                error:
                    "Call didn't returned an `APIResponse`. Returned type: ${ret.runtimeType} > $apiMethod\n$e",
                stackTrace: s);
          }
        }
      });
    } else {
      try {
        return ret as FutureOr<APIResponse>;
      } catch (e, s) {
        return APIResponse.error(
            error:
                "Call didn't returned a `FutureOr<APIResponse>`. Returned type: ${ret.runtimeType} > $apiMethod\n$e",
            stackTrace: s);
      }
    }
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

    return resolveValueByType(parameterTypeInfo, value);
  }

  static Object? resolveValueByType(TypeInfo typeInfo, Object? value,
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
    } else if (typeInfo.isList) {
      if (value is! List) {
        value = TypeParser.parseList(value) ?? value;
      }

      var arg0 = typeInfo.arguments0;
      if (value is List && arg0 != null && arg0.isPrimitiveType) {
        var argParser = TypeParser.parserForTypeInfo(arg0);
        if (argParser != null && !typeInfo.isCastedList(value)) {
          value =
              TypeParser.parseList(value, elementParser: argParser) ?? value;
        }

        return typeInfo.castList(value);
      }
    } else if (typeInfo.isSet) {
      var arg0 = typeInfo.arguments0;

      if (value is! Set) {
        if (arg0 != null) {
          var s = _resolveValueSetTypeAsListType(
              arg0, value, entityCache, resolutionRules);
          if (s != null) return s;
        } else {
          value = TypeParser.parseSet(value) ?? value;
        }
      }

      if (value is Set && arg0 != null && arg0.isPrimitiveType) {
        var argParser = TypeParser.parserForTypeInfo(arg0);
        if (argParser != null && !typeInfo.isCastedSet(value)) {
          value = TypeParser.parseSet(value, elementParser: argParser) ?? value;
        }

        return typeInfo.castSet(value);
      } else if (arg0 != null) {
        var s = _resolveValueSetTypeAsListType(
            arg0, value, entityCache, resolutionRules);
        if (s != null) return s;
      }
    } else if (typeInfo.isMap) {
      var arg0 = typeInfo.arguments0;
      var arg1 = typeInfo.arguments1;

      if (value is! Map) {
        value = TypeParser.parseMap(value);
      }

      if (value is Map &&
          arg0 != null &&
          arg1 != null &&
          arg0.isPrimitiveType &&
          arg1.isPrimitiveType) {
        var argParser0 = TypeParser.parserForTypeInfo(arg0);
        var argParser1 = TypeParser.parserForTypeInfo(arg1);

        if ((argParser0 != null || argParser1 != null) &&
            !typeInfo.isCastedMap(value)) {
          Map? m = typeInfo.callCastedArgumentsAB(<K, V>() {
            return TypeParser.parseMap<K, V>(
              value,
              keyParser: argParser0 is TypeElementParser<K> ? argParser0 : null,
              valueParser:
                  argParser1 is TypeElementParser<V> ? argParser1 : null,
            );
          });

          value = m ?? value;
        }

        return typeInfo.castMap(value);
      }
    }

    if (!typeInfo.isPrimitiveType) {
      var o = _resolveValueAsEntity(typeInfo, value,
          entityCache: entityCache, resolutionRules: resolutionRules);
      if (o != null) return o;
    }

    var parsed = typeInfo.parse(value);
    return parsed ?? value;
  }

  static Set? _resolveValueSetTypeAsListType(TypeInfo listType, Object value,
      EntityCache? entityCache, EntityResolutionRules? resolutionRules) {
    var setTypeAsList = TypeInfo.fromListType(listType);

    var l = resolveValueByType(setTypeAsList, value,
        entityCache: entityCache, resolutionRules: resolutionRules);

    if (l is List) {
      return l.toSet();
    } else {
      return null;
    }
  }

  static Uint8List? _resolveRequestParameterValueAsBytes(Object value) {
    if (value is List<int>) {
      var data = value.asUint8List;
      return data;
    } else if (value is String) {
      if (value.startsWith("hex:")) {
        var hexData = value.substring(4);
        try {
          var data = hex.decode(hexData);
          return data;
        } catch (_) {
          // Not a HEX data:
        }
      } else if (value.startsWith("base64:")) {
        var base64Data = value.substring(7);
        try {
          var data = base64.decode(base64Data);
          return data;
        } catch (_) {
          // Not a Base64 data:
        }
      }

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

      return utf8.encode(value);
    }

    return null;
  }

  static Object? _resolveValueAsEntity(
      TypeInfo parameterTypeInfo, Object? value,
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
          var o = classReflection.createFromMapSync(map,
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

  static List _castList(List<Object?> list, TypeInfo typeInfo) {
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
    super.moduleClassName, {
    super.libraryName,
    super.libraryPath,
    Set<String> ignoreMethods = const <String>{},
  }) : super(
            ignoreMethods: APIModule.interfaceMethodsNames,
            ignoreMethods2: ignoreMethods,
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

typedef APIModuleProxyTargetResolver = ClassProxyListener<T>? Function<T>(
  Object target,
  String? moduleName,
  bool? responsesAsJson,
  APIModuleProxyResponseErrorHandler? errorHandler,
);

/// A [APIModuleProxy] caller for a specific module ([moduleName]).
///
/// Extends a [ClassProxyDelegateListener] that delegates to [targetListener].
class APIModuleProxyCaller<T> extends ClassProxyDelegateListener<T> {
  static final Set<APIModuleProxyTargetResolver> _targetResolvers = {};

  /// Registers a target resolver.
  /// See [registerTargetResolver] and [resolveTarget].
  static bool registerTargetResolver(
          APIModuleProxyTargetResolver targetResolver) =>
      _targetResolvers.add(targetResolver);

  /// Unregisters a target resolver.
  /// See [registerTargetResolver] and [resolveTarget].
  static bool unregisterTargetResolver(
          APIModuleProxyTargetResolver targetResolver) =>
      _targetResolvers.remove(targetResolver);

  /// Resolves [target] to a [ClassProxyListener].
  /// See [registerTargetResolver].
  static ClassProxyListener<T> resolveTarget<T>(Object target,
      {String? moduleName,
      bool? responsesAsJson,
      APIModuleProxyResponseErrorHandler? errorHandler}) {
    for (var resolver in _targetResolvers) {
      var targetResolved =
          resolver<T>(target, moduleName, responsesAsJson, errorHandler);
      if (targetResolved != null) return targetResolved;
    }

    if (target is ClassProxyListener<T>) return target;

    if (target is HttpClient) {
      return APIModuleProxyHttpCaller(
        target,
        moduleRoute: moduleName,
        responsesAsJson: responsesAsJson,
        errorHandler: errorHandler,
      ) as ClassProxyListener<T>;
    }

    throw StateError("Can't resolve `APIModuleProxyListener` target: $target");
  }

  /// The [APIModule] name.
  final String moduleName;

  APIModuleProxyCaller(Object target,
      {required this.moduleName,
      bool? responsesAsJson,
      APIModuleProxyResponseErrorHandler? errorHandler})
      : super(resolveTarget(target,
            moduleName: moduleName,
            responsesAsJson: responsesAsJson,
            errorHandler: errorHandler));
}

abstract class APIModuleProxyCallerError extends Error
    implements WithRuntimeTypeNameSafe {
  final String message;

  APIModuleProxyCallerError(this.message);

  List<Object> get extraInfo => [];

  @override
  String toString() {
    var extraInfo = this.extraInfo;
    var extra = extraInfo.isEmpty ? '' : '\n  -- ${extraInfo.join('\n  -- ')}';
    return '$runtimeTypeNameSafe: $message$extra';
  }
}

class APIModuleProxyCallerResponseError extends APIModuleProxyCallerError {
  final Object? request;
  final Object? response;
  final APIResponseStatus? responseStatus;
  final Object? responseError;
  final StackTrace? responseStackTrace;

  final String? module;
  final String? methodName;
  final Map<String, Object?>? parameters;

  APIModuleProxyCallerResponseError(super.message,
      {this.request,
      this.response,
      this.responseStatus,
      this.responseError,
      this.responseStackTrace,
      this.module,
      this.methodName,
      this.parameters});

  APIResponse? get apiResponse {
    var response = this.response;
    return response is APIResponse ? response : null;
  }

  @override
  List<Object> get extraInfo {
    final response = this.response;
    final responseError = this.responseError;
    final responseStackTrace = this.responseStackTrace;
    final responseStatus = this.responseStatus;

    if (response is APIResponse) {
      return [
        response,
        if (responseError != null &&
            !identical(response.error, responseError) &&
            !message.contains('$responseError'))
          responseError,
        if (responseStackTrace != null &&
            !identical(response.stackTrace, responseStackTrace))
          responseStackTrace,
        if (responseStatus != null) responseStatus,
      ];
    } else {
      return [
        if (response != null) response,
        if (responseError != null &&
            !identical(response, responseError) &&
            !message.contains('$responseError'))
          responseError,
        if (responseStackTrace != null) responseStackTrace,
        if (responseStatus != null) responseStatus,
      ];
    }
  }

  @override
  String get runtimeTypeNameSafe => 'APIModuleProxyCallerResponseError';
}

abstract class APIModuleProxyCallerListener<T>
    implements ClassProxyListener<T> {
  /// The default response error handler.
  static APIModuleProxyResponseErrorHandler? defaultErrorHandler;

  Object? resolveResponse(TypeReflection? returnType, dynamic json) {
    if (returnType == null || json == null) {
      return json;
    }

    var typeInfo = returnType.typeInfo;
    var mainType =
        typeInfo.isFuture ? (typeInfo.arguments0 ?? typeInfo) : typeInfo;

    // var debugJsonPretty = Json.encode(json, pretty: true);
    // print(debugJsonPretty);

    // print(Json.dumpRuntimeTypes(json));

    var jsonDecoder = Json.decoder(
        entityHandlerProvider: EntityHandlerProvider.globalProvider);

    return mainType.fromJson(json, jsonDecoder: jsonDecoder);
  }
}

/// An [APIModuleProxy] caller with direct calls to an [api] instance,
/// for a specific module ([moduleName]).
class APIModuleProxyDirectCaller<T> extends APIModuleProxyCallerListener<T> {
  final APIRoot api;

  final String moduleName;

  /// If `true` converts the response object to a JSON collection/data.
  final bool responsesAsJson;

  /// The error handler to call when an HTTP response error happens.
  final APIModuleProxyResponseErrorHandler? errorHandler;

  /// The default response error handler. See [errorHandler].
  static APIModuleProxyResponseErrorHandler? defaultErrorHandler;

  APIModuleProxyDirectCaller(this.api,
      {required this.moduleName,
      this.credential,
      bool? responsesAsJson,
      this.errorHandler})
      : responsesAsJson = responsesAsJson ?? true;

  APICredential? credential;

  @override
  FutureOr onCall(T instance, String methodName,
      Map<String, dynamic> parameters, TypeReflection? returnType) async {
    var response = api.call(APIRequest.get('$moduleName/$methodName',
        parameters: parameters, credential: credential));

    return response.resolveMapped((response) {
      if (response.isError) {
        var responseError = APIModuleProxyCallerResponseError(
          'Response ERROR> ${response.error}',
          response: response,
          responseStatus: APIResponseStatus.ERROR,
          responseError: response.error,
          responseStackTrace: response.stackTrace,
          module: moduleName,
          methodName: methodName,
          parameters: parameters,
        );

        var errorHandler = this.errorHandler ??
            defaultErrorHandler ??
            APIModuleProxyCallerListener.defaultErrorHandler;

        if (errorHandler != null) {
          try {
            errorHandler(responseError);
          } catch (e, s) {
            _log.severe("Error calling `errorHandler`!", e, s);
          }
        }

        throw responseError;
      }

      if (response.isNotOK) return null;

      var payload = response.payload;

      if (responsesAsJson && returnType != null) {
        var json = responseToJson(payload, apiResponse: response);
        return resolveResponse(returnType, json);
      }

      return payload;
    });
  }

  dynamic responseToJson(dynamic payload, {APIResponse<dynamic>? apiResponse}) {
    if (apiResponse != null) {
      final apiRequest = apiResponse.apiRequest;
      if (apiRequest != null) {
        final routeHandler = apiRequest.routeHandler;
        if (routeHandler != null) {
          var accessRules = routeHandler.entityAccessRules;

          if (!accessRules.isInnocuous) {
            return Json.toJson(payload,
                toEncodableProvider: (o) => accessRules.toJsonEncodable(
                    apiRequest, Json.defaultToEncodableJsonProvider(), o));
          }
        }
      }
    }

    return Json.toJson(payload, toEncodable: ReflectionFactory.toJsonEncodable);
  }
}

typedef APIModuleHttpProxyRequestHandler = FutureOr<dynamic>? Function(
    APIModuleProxyHttpCaller proxy,
    String methodName,
    Map<String, Object?> parameters);

typedef APIModuleProxyResponseErrorHandler = void Function(
    APIModuleProxyCallerResponseError responseError);

/// An [APIModuleProxy] caller that performs HTTP requests.
/// Implements a [ClassProxyListener] that redirects calls to [httpClient].
class APIModuleProxyHttpCaller<T> extends APIModuleProxyCallerListener<T> {
  /// The [httpClient] ot perform the proxy calls.
  final HttpClient httpClient;

  /// The error handler to call when an HTTP response error happens.
  final APIModuleProxyResponseErrorHandler? errorHandler;

  /// The default response error handler. See [errorHandler].
  static APIModuleProxyResponseErrorHandler? defaultErrorHandler;

  /// The module path in the [httpClient] base URL.
  final String modulePath;

  /// If `true` all the returned responses of [httpClient] requests will be decoded as JSON.
  /// If `false` will treat as response only of `Content-Type` is JSON or JavaScript ([HttpResponse.isBodyTypeJSON]).
  final bool responsesAsJson;

  APIModuleProxyHttpCaller(this.httpClient,
      {String? moduleRoute, bool? responsesAsJson, this.errorHandler})
      : modulePath = _normalizeModulePath(moduleRoute),
        responsesAsJson = responsesAsJson ?? true {
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

  Future<dynamic> doRequest(String methodName, Map<String, Object?> parameters,
      TypeReflection? returnType) async {
    var requestHandler = this.requestHandler;

    if (requestHandler != null) {
      var ret = requestHandler(this, methodName, parameters);
      if (ret != null) return ret;
    }

    var needsJsonRequest = false;

    parameters = parameters.map((key, value) {
      Object? val = value;

      if (value is Uint8List) {
        val = Json.toJson(value);
        needsJsonRequest = true;
      } else if (value.isPrimitiveList || value.isPrimitiveMap) {
        needsJsonRequest = true;
      } else if (!value.isPrimitiveValue) {
        val = Json.toJson(value);
        needsJsonRequest = true;
      }

      return MapEntry(key, val);
    });

    bool returnsBytes = false;

    if (returnType != null) {
      var type = returnType.type;
      returnsBytes = type == Uint8List ||
          ((type == Future || type == FutureOr) &&
              returnType.arguments0?.type == Uint8List);
    }

    var responseType = returnsBytes ? 'arraybuffer' : 'text';

    final modulePath = this.modulePath;

    var path = modulePath.isNotEmpty ? '$modulePath/$methodName' : methodName;

    HttpMethod method;
    HttpResponse response;
    if (needsJsonRequest) {
      method = HttpMethod.POST;
      response = await httpClient.post(
        path,
        body: parameters,
        contentType: MimeType.json,
        responseType: responseType,
      );
    } else {
      method = HttpMethod.GET;
      response = await httpClient.get(
        path,
        parameters: parameters,
        responseType: responseType,
      );
    }

    return parseResponse(
      response,
      requestMethod: method,
      requestPath: path,
      methodName: methodName,
      parameters: parameters,
    );
  }

  dynamic parseResponse(
    HttpResponse response, {
    HttpMethod? requestMethod,
    String? requestPath,
    String? methodName,
    Map<String, Object?>? parameters,
  }) {
    if (response.isError) {
      var error = parseResponseBody(response);

      var responseError = APIModuleProxyCallerResponseError(
        'Response ERROR> $error',
        request: {
          'requestMethod': requestMethod?.name,
          'requestPath': requestPath,
          'responseStatus': response.status,
        },
        response: response,
        responseStatus: parseAPIResponseStatus(response.status),
        responseError: error,
        module: modulePath,
        methodName: methodName,
        parameters: parameters,
      );

      final errorHandler = this.errorHandler ??
          defaultErrorHandler ??
          APIModuleProxyCallerListener.defaultErrorHandler;

      if (errorHandler != null) {
        try {
          errorHandler(responseError);
        } catch (e, s) {
          _log.severe("Error calling `errorHandler`!", e, s);
        }
      }

      throw responseError;
    }

    if (response.isNotOK) return null;

    return parseResponseBody(response);
  }

  Object? parseResponseBody(HttpResponse response) {
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

  bool isJsonResponse(HttpResponse response, MimeType? mimeType) {
    if (mimeType == null) {
      return responsesAsJson;
    }

    if (mimeType.isJSON || mimeType.isJavascript) return true;

    if (responsesAsJson) {
      switch (mimeType.type) {
        case 'font':
        case 'image':
        case 'audio':
        case 'video':
          return false;

        case 'application':
          switch (mimeType.subType) {
            case 'gzip':
            case 'zip':
            case 'x-tar':
            case 'x-bzip':
            case 'x-bzip2':
            case 'x-7z-compressed':
            case 'x-rar-compressed':
            case 'dart':
            case 'yaml':
            case 'xml':
            case 'xhtml+xml':
            case 'pdf':
            case 'msword':
            case 'octet-stream':
              return false;
            default:
              return true;
          }

        case 'text':
          switch (mimeType.subType) {
            case 'html':
            case 'css':
            case 'csv':
            case 'xml':
            case 'md':
              return false;
            default:
              return true;
          }

        default:
          return true;
      }
    }

    return false;
  }

  bool isTextResponse(HttpResponse response, MimeType? mimeType) =>
      mimeType != null &&
      (mimeType.isText || mimeType.isXHTML || mimeType.isXML);

  bool isByteArrayResponse(HttpResponse response, MimeType? mimeType) {
    if (mimeType == null) return false;

    if (mimeType.isImage || mimeType.isAudio || mimeType.isVideo) return true;

    if (mimeType.type == 'application') {
      switch (mimeType.subType) {
        case 'gzip':
        case 'zip':
        case 'x-tar':
        case 'x-bzip':
        case 'x-bzip2':
        case 'x-7z-compressed':
        case 'x-rar-compressed':
        case 'pdf':
        case 'msword':
        case 'octet-stream':
          return true;
      }
    }

    return false;
  }

  dynamic decodeJson(String content) {
    try {
      return json.decode(content);
    } on FormatException {
      return content;
    }
  }

  @override
  Future onCall(dynamic instance, String methodName,
      Map<String, Object?> parameters, TypeReflection? returnType) async {
    var json = await doRequest(methodName, parameters, returnType);
    return resolveResponse(returnType, json);
  }
}

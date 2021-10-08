import 'dart:async';
import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_config.dart';
import 'bones_api_extension.dart';

/// Root class of an API.
abstract class APIRoot {
  // ignore: constant_identifier_names
  static const String VERSION = '1.0.21';

  static final Map<String, APIRoot> _instances = <String, APIRoot>{};

  /// Returns the last [APIRoot] if instantiated.
  ///
  /// - If [singleton] is `true` and multiple instances exists throws an [StateError].
  static APIRoot? get({bool singleton = true}) {
    if (_instances.isEmpty) {
      return null;
    } else if (_instances.length == 1) {
      return _instances.values.first;
    } else if (_instances.length == 2) {
      if (singleton) {
        throw StateError(
            "Multiple APIRoot instances> singleton: $singleton ; length: ${_instances.length} ; names: ${_instances.keys.toList()}");
      }
      return _instances.values.last;
    }
  }

  /// Returns an [APIRoot] instance with [name].
  ///
  /// - If [caseInsensitive] is `true` will ignore [name] case.
  static APIRoot? getByName(String name,
      {bool caseInsensitive = true, bool lastAsDefault = false}) {
    var apiRoot = _instances[name];
    if (apiRoot != null) return apiRoot;

    if (caseInsensitive) {
      var nameLC = name.toLowerCase();
      for (var n in _instances.keys) {
        if (n.toLowerCase() == nameLC) {
          return _instances[n];
        }
      }
    }

    return lastAsDefault ? get(singleton: false) : null;
  }

  /// Returns the first [APIRoot] matched by [matcher].
  static APIRoot? getWhere(bool Function(APIRoot apiRoot) matcher,
          {bool lastAsDefault = false}) =>
      _instances.values.firstWhereOrNull(matcher) ??
      (lastAsDefault ? get(singleton: false) : null);

  static APIRoot? getWithinName(String part,
      {bool lastAsDefault = false, bool caseInsensitive = true}) {
    if (caseInsensitive) {
      part = part.toLowerCase();
    }

    return getWhere((apiRoot) {
      var n = caseInsensitive ? apiRoot.name.toLowerCase() : apiRoot.name;
      return n.contains(part);
    }, lastAsDefault: lastAsDefault);
  }

  /// API name.
  final String name;

  /// API version.
  final String version;

  /// The API Configuration.
  APIConfig apiConfig;

  APIRoot(this.name, this.version,
      {dynamic apiConfig, APIConfigProvider? apiConfigProvider})
      : apiConfig =
            APIConfig.fromSync(apiConfig, apiConfigProvider) ?? APIConfig() {
    _instances[name] = this;
  }

  /// The default module to use when request module doesn't match.
  String? get defaultModuleName => null;

  /// Loads the modules of this API.
  Set<APIModule> loadModules();

  Map<String, APIModule>? _modules;

  /// Returns the names of the modules of this API.
  Set<String> get modulesNames {
    _ensureModulesLoaded();
    return _modules!.keys.toSet();
  }

  /// Returns the modules of this API.
  Set<APIModule> get modules {
    _ensureModulesLoaded();
    return _modules!.values.toSet();
  }

  void _ensureModulesLoaded() {
    _modules ??= Map.fromEntries(loadModules().map((e) => MapEntry(e.name, e)));
  }

  /// Returns a module with [name].
  APIModule? getModule(String name) {
    _ensureModulesLoaded();
    return _modules![name];
  }

  /// Returns an [APIModule] based in the [request].
  ///
  /// Calls [resolveModule] to determine the module name.
  APIModule? getModuleByRequest(APIRequest request) {
    _ensureModulesLoaded();
    var moduleName = resolveModule(request);
    return _modules![moduleName];
  }

  /// Resolves the module name of a [request].
  String resolveModule(APIRequest request) {
    var moduleName = request.pathPart(1, reversed: true);
    return moduleName;
  }

  /// Perform an API call.
  FutureOr<APIResponse<T>> doCall<T>(APIRequestMethod method, String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    var request = APIRequest(method, path,
        parameters: parameters, headers: headers, payload: payload);
    return call(request);
  }

  /// Calls the API.
  FutureOr<APIResponse<T>> call<T>(APIRequest request) {
    var module = getModuleByRequest(request);

    if (module == null) {
      var def = defaultModuleName;
      if (def != null) {
        module = _modules![def];
      }
    }

    if (module == null) {
      return APIResponse.notFound();
    }

    return module.call(request);
  }

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => name.hashCode ^ version.hashCode;

  @override
  String toString() {
    return '$name[$version]$modulesNames';
  }
}

/// An API route handler
typedef APIRouteHandler<T> = FutureOr<APIResponse<T>> Function(
    APIRequest request);

/// A module of an API.
abstract class APIModule {
  /// The API root, that is loading this module.
  final APIRoot apiRoot;

  /// The name of this API module.
  final String name;

  late final APIRouteBuilder _routeBuilder;

  APIModule(this.apiRoot, this.name) {
    _routeBuilder = APIRouteBuilder(this);
  }

  /// The [APIConfig] from [apiRoot].
  APIConfig get apiConfig => apiRoot.apiConfig;

  /// The default route to use when the request doesn't match.
  String? get defaultRouteName => null;

  /// Configures this API module. Usually defines the routes of this instance.
  void configure();

  bool _configured = false;

  void _ensureConfigured() {
    if (_configured) return;
    _configured = true;
    configure();
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
  /// [handler] The route handler, to process calls.
  APIModule addRoute(
      APIRequestMethod? method, String name, APIRouteHandler handler) {
    var routesHandlers = _getRoutesHandlers(method);
    routesHandlers[name] = handler;
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
    _ensureConfigured();

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
  APIRouteHandler<T>? getRouteHandlerByRequest<T>(APIRequest request) {
    _ensureConfigured();

    var route = resolveRoute(request);
    return getRouteHandler(route, request.method);
  }

  /// Resolves the route name of the [request].
  String resolveRoute(APIRequest request) {
    var routeName = request.pathPart(0, reversed: true);
    return routeName;
  }

  /// Calls a route for [request].
  FutureOr<APIResponse<T>> call<T>(APIRequest request) {
    var handler = getRouteHandlerByRequest<T>(request);

    if (handler == null) {
      return APIResponse.notFound();
    }

    try {
      var response = handler(request);
      return response;
    } catch (e, s) {
      var error = 'ERROR: $e\n$s';
      return APIResponse.error(error: error);
    }
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

/// A route builder.
class APIRouteBuilder<M extends APIModule> {
  /// The API module of this route builder.
  final M module;

  APIRouteBuilder(this.module);

  /// Adds a route of [name] with [handler] for ANY request method.
  APIModule any(String name, APIRouteHandler handler) =>
      add(null, name, handler);

  /// Adds a route of [name] with [handler] for `GET` request method.
  APIModule get(String name, APIRouteHandler handler) =>
      add(APIRequestMethod.GET, name, handler);

  /// Adds a route of [name] with [handler] for `POST` request method.
  APIModule post(String name, APIRouteHandler handler) =>
      add(APIRequestMethod.POST, name, handler);

  /// Adds a route of [name] with [handler] for `PUT` request method.
  APIModule put(String name, APIRouteHandler handler) =>
      add(APIRequestMethod.PUT, name, handler);

  /// Adds a route of [name] with [handler] for `DELETE` request method.
  APIModule delete(String name, APIRouteHandler handler) =>
      add(APIRequestMethod.DELETE, name, handler);

  /// Adds a route of [name] with [handler] for `PATCH` request method.
  APIModule patch(String name, APIRouteHandler handler) =>
      add(APIRequestMethod.PATCH, name, handler);

  /// Adds a route of [name] with [handler] for the request [method].
  APIModule add(
          APIRequestMethod? method, String name, APIRouteHandler handler) =>
      module.addRoute(method, name, handler);

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

    if (returnsAPIResponse && receivesAPIRequest) {
      add(requestMethod, apiMethod.name, (req) {
        return apiMethod.invoke([req]);
      });
    } else if (receivesAPIRequest) {
      add(requestMethod, apiMethod.name, (req) {
        var ret = apiMethod.invoke([req]);
        return APIResponse.from(ret);
      });
    } else if (returnsAPIResponse) {
      add(requestMethod, apiMethod.name, (req) {
        var methodInvocation =
            apiMethod.methodInvocation((p) => _resolveRequestParameter(req, p));
        return methodInvocation.invoke(apiMethod.method);
      });
    }
  }

  _resolveRequestParameter(APIRequest request, ParameterReflection parameter) {
    var typeReflection = parameter.type;
    if (typeReflection.isOfType(APIRequest)) {
      return request;
    }

    if (typeReflection.isOfType(Uint8List)) {
      return request.payloadAsBytes;
    }

    var value = request.getParameterIgnoreCase(parameter.name);
    if (value == null) {
      return null;
    }

    var typeInfo = TypeInfo.from(typeReflection);

    if (typeInfo.isNumber) {
      var n = typeInfo.parse(value);
      return n;
    } else if (typeInfo.isString) {
      var s = typeInfo.parse(value);
      return s;
    } else {
      var parsed = typeInfo.parse(value);
      return parsed ?? value;
    }
  }
}

/// API Methods
enum APIRequestMethod {
  // ignore: constant_identifier_names
  GET,
  // ignore: constant_identifier_names
  POST,
  // ignore: constant_identifier_names
  PUT,
  // ignore: constant_identifier_names
  DELETE,
  // ignore: constant_identifier_names
  PATCH,
}

/// Extension of enum [APIRequestMethod].
extension APIRequestMethodExtension on APIRequestMethod {
  String get name {
    switch (this) {
      case APIRequestMethod.GET:
        return 'GET';
      case APIRequestMethod.POST:
        return 'POST';
      case APIRequestMethod.PUT:
        return 'PUT';
      case APIRequestMethod.DELETE:
        return 'DELETE';
      case APIRequestMethod.PATCH:
        return 'PATCH';
      default:
        throw ArgumentError('Unknown method: $this');
    }
  }
}

/// Returns the [APIRequestMethod] for [method].
APIRequestMethod? parseAPIRequestMethod(String? method) {
  if (method == null) return null;
  method = method.trim();

  switch (method) {
    case 'get':
    case 'GET':
      return APIRequestMethod.GET;
    case 'post':
    case 'POST':
      return APIRequestMethod.POST;
    case 'put':
    case 'PUT':
      return APIRequestMethod.PUT;
    case 'delete':
    case 'DELETE':
      return APIRequestMethod.DELETE;
    case 'patch':
    case 'PATCH':
      return APIRequestMethod.PATCH;

    default:
      return null;
  }
}

/// Base class for payload.
abstract class APIPayload {
  /// The payload.
  dynamic get payload;

  /// The payload MIME Type.
  String? get payloadMimeType;

  /// The payload usual file name extension.
  String? get payloadFileExtension;

  /// Returns `true` if [payload] is not `null`.
  bool get hasPayload => payload != null;

  /// Returns the [payload] length.
  int get payloadLength {
    if (payload == null) {
      return -1;
    } else if (payload is String) {
      return payload.length;
    } else if (payload is Iterable<Iterable>) {
      return _sum(payload);
    } else if (payload is Iterable) {
      return payload.length;
    } else {
      return '$payload'.length;
    }
  }

  static int _sum(Iterable<Iterable> itr) {
    var total = 0;
    for (var e in itr) {
      total += e.length;
    }
    return total;
  }
}

enum APIRequesterSource { internal, local, remote, unknown }

extension APIRequesterSourceExtension on APIRequesterSource {
  String get name {
    switch (this) {
      case APIRequesterSource.internal:
        return 'internal';
      case APIRequesterSource.local:
        return 'local';
      case APIRequesterSource.remote:
        return 'remote';
      case APIRequesterSource.unknown:
        return 'unknown';
      default:
        throw ArgumentError('Unknown: $this');
    }
  }
}

/// Represents an API request.
class APIRequest extends APIPayload {
  /// The request method.
  final APIRequestMethod method;

  /// The request path.
  final String path;

  /// The parameters of the request.
  final Map<String, dynamic> parameters;

  /// The headers of the request.
  final Map<String, dynamic> headers;

  /// The [DateTime] of this request.
  final DateTime time;

  /// The payload/body of the request.
  @override
  final dynamic payload;

  Uint8List? get payloadAsBytes {
    var payload = this.payload;

    if (payload == null) {
      return null;
    }

    if (payload is Uint8List) {
      return payload;
    }

    if (payload is List<int>) {
      return Uint8List.fromList(payload);
    }

    var s = payload.toString();
    var bs = dart_convert.utf8.encode(s);

    return Uint8List.fromList(bs);
  }

  /// The payload/body MIME Type.
  @override
  String? payloadMimeType;

  /// The payload usual file name extension.
  @override
  String? payloadFileExtension;

  final String? scheme;

  final APIRequesterSource requesterSource;
  final String? _requesterAddress;

  late final List<String> _pathParts;

  APIRequest(this.method, this.path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      this.payload,
      this.payloadMimeType,
      this.payloadFileExtension,
      String? scheme,
      APIRequesterSource? requesterSource,
      String? requesterAddress,
      DateTime? time})
      : parameters = parameters ?? <String, dynamic>{},
        headers = headers ?? <String, dynamic>{},
        _pathParts = _buildPathParts(path),
        scheme = scheme?.trim(),
        requesterSource = _resolveRestSource(requesterAddress),
        _requesterAddress = requesterAddress,
        time = time ?? DateTime.now();

  static APIRequesterSource _resolveRestSource(String? requestAddress) {
    if (requestAddress == null) return APIRequesterSource.unknown;

    requestAddress = requestAddress.trim();
    if (requestAddress.isEmpty || requestAddress == '?') {
      return APIRequesterSource.unknown;
    }

    var requestAddressLC = requestAddress.toLowerCase();

    if (requestAddressLC == 'localhost' ||
        requestAddressLC == '127.0.0.1' ||
        requestAddressLC == '0.0.0.0' ||
        requestAddressLC == '::1' ||
        requestAddressLC == '::' ||
        requestAddressLC == '*') {
      return APIRequesterSource.local;
    }

    if (requestAddressLC == 'internal' || requestAddressLC == '.') {
      return APIRequesterSource.internal;
    }

    return APIRequesterSource.remote;
  }

  static List<String> _buildPathParts(String path) {
    var p = path.trim();

    if (p.startsWith('/')) {
      p = p.substring(1);
    }

    if (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }

    return p.split('/');
  }

  /// Constructs an [APIRequest] parsing [argsLine].
  factory APIRequest.fromArgsLine(String argsLine) {
    var args = Arguments.splitArgumentsLine(argsLine);
    return APIRequest.fromArgs(args);
  }

  static final RegExp _regexpHeaderPrefix =
      RegExp(r'^header[-_]', caseSensitive: false);

  /// Constructs an [APIRequest] parsing [args].
  factory APIRequest.fromArgs(List<String> args) {
    var path = args.removeAt(0);

    var arguments = Arguments.parse(
      args,
      abbreviations: {
        'm': 'method',
        'q': 'query',
        'querystring': 'query',
        'body': 'payload',
      },
    );

    var query = arguments.parameters.remove('query');

    if (query != null) {
      var params = Uri.splitQueryString(query);
      arguments.parameters.addAll(params);
    }

    var methodVal = arguments.parameters.remove('method');
    var method = methodVal != null
        ? parseAPIRequestMethod(methodVal.toString().toLowerCase()) ??
            APIRequestMethod.GET
        : APIRequestMethod.GET;

    var payload = arguments.parameters.remove('payload');

    var parameters = Map.fromEntries(arguments.parameters.entries
        .where((e) => !_regexpHeaderPrefix.hasMatch(e.key)));

    for (var f in arguments.flags) {
      parameters[f] = true;
    }

    var headers = Map.fromEntries(arguments.parameters.entries
        .where((e) => _regexpHeaderPrefix.hasMatch(e.key))
        .map((e) => MapEntry(e.key.substring(7), e.value)));

    return APIRequest(method, path,
        parameters: parameters, headers: headers, payload: payload);
  }

  /// Creates a request of `GET` method.
  factory APIRequest.get(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.GET, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  /// Creates a request of `POST` method.
  factory APIRequest.post(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.POST, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  /// Creates a request of `PUT` method.
  factory APIRequest.put(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.PUT, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  /// Creates a request of `DELETE` method.
  factory APIRequest.delete(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.DELETE, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  /// Creates a request of `PATCH` method.
  factory APIRequest.patch(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.PATCH, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  /// The elapsed time of this request.
  ///
  /// Difference between [DateTime.now] and [time].
  Duration get elapsedTime => DateTime.now().difference(time);

  /// Returns the parts of the [path].
  List<String> get pathParts => _pathParts.toList();

  /// Returns a path part at [index].
  ///
  /// [reversed] if `true`, [index] is reversed.
  String pathPart(int index, {bool reversed = false}) {
    var length = _pathParts.length;

    int idx;
    if (reversed) {
      idx = length - (index + 1);
    } else {
      idx = index;
    }

    return idx >= 0 && idx < length ? _pathParts[idx] : '';
  }

  /// Returns from [parameters] a value for [name1] or [name1] .. [name9].
  V? getParameter<V>(
    String name1, [
    String? name2,
    String? name3,
    String? name4,
    String? name5,
    String? name6,
    String? name7,
    String? name8,
    String? name9,
  ]) {
    var val = parameters[name1];
    if (val != null) return val;

    if (name2 != null) {
      val = parameters[name2];
      if (val != null) return val;
    }

    if (name3 != null) {
      val = parameters[name3];
      if (val != null) return val;
    }

    if (name4 != null) {
      val = parameters[name4];
      if (val != null) return val;
    }

    if (name5 != null) {
      val = parameters[name5];
      if (val != null) return val;
    }

    if (name6 != null) {
      val = parameters[name6];
      if (val != null) return val;
    }

    if (name7 != null) {
      val = parameters[name7];
      if (val != null) return val;
    }

    if (name8 != null) {
      val = parameters[name8];
      if (val != null) return val;
    }

    if (name9 != null) {
      val = parameters[name9];
      if (val != null) return val;
    }

    return null;
  }

  /// Returns from [parameters] a value for [name] or [name1] .. [name9] ignoring case.
  /// See [getParameter].
  V? getParameterIgnoreCase<V>(
    String name, [
    String? name2,
    String? name3,
    String? name4,
    String? name5,
    String? name6,
    String? name7,
    String? name8,
    String? name9,
  ]) {
    var val = getParameter(name, name2, name3, name4, name5);
    if (val != null) return val;

    for (var k in parameters.keys) {
      if (equalsIgnoreAsciiCase(k, name)) return parameters[k];

      if (name2 != null && equalsIgnoreAsciiCase(k, name2)) {
        return parameters[k];
      }

      if (name3 != null && equalsIgnoreAsciiCase(k, name3)) {
        return parameters[k];
      }

      if (name4 != null && equalsIgnoreAsciiCase(k, name4)) {
        return parameters[k];
      }

      if (name5 != null && equalsIgnoreAsciiCase(k, name5)) {
        return parameters[k];
      }

      if (name6 != null && equalsIgnoreAsciiCase(k, name6)) {
        return parameters[k];
      }

      if (name7 != null && equalsIgnoreAsciiCase(k, name7)) {
        return parameters[k];
      }

      if (name8 != null && equalsIgnoreAsciiCase(k, name8)) {
        return parameters[k];
      }

      if (name9 != null && equalsIgnoreAsciiCase(k, name9)) {
        return parameters[k];
      }
    }

    return null;
  }

  String? getHeader(String headerKey, {String? def}) {
    var val = headers[headerKey];
    if (val != null) return val;

    headerKey = headerKey.trim().toLowerCase();

    val = headers[headerKey];
    if (val != null) return val;

    for (var k in headers.keys) {
      var kLC = k.toLowerCase();

      if (kLC == headerKey) {
        return headers[k];
      }
    }

    return def;
  }

  String get hostname {
    var host = getHeader('host');
    if (host == null) {
      return 'localhost';
    }

    var idx = host.lastIndexOf(':');
    if (idx >= 0) {
      host = host.substring(0, idx);
    }

    host = host.trim();

    if (host.isEmpty) {
      return 'localhost';
    }

    return host;
  }

  int get port {
    var port = getHeader('port');
    if (port != null) {
      var p = int.tryParse(port.trim());
      if (p != null) return p;
    }

    var host = getHeader('host');
    if (host == null) {
      return 0;
    }

    var idx = host.lastIndexOf(':');
    if (idx > 0) {
      port = host.substring(idx + 1);
      var p = int.tryParse(port.trim());
      if (p != null) return p;
    }

    return 0;
  }

  String get hostnameAndPort => '$hostname:$port';

  String? get requesterAddress {
    if (_requesterAddress != null) return _requesterAddress;

    String? client;

    var proxy = getHeader('x-forwarded-for');
    if (proxy != null) {
      var idx = proxy.indexOf(',');
      client = idx > 0 ? proxy.substring(0, idx) : proxy;
    } else {
      client = getHeader('remote-address') ?? '';
    }

    client = client.trim();
    if (client.isNotEmpty) {
      return client;
    }

    return null;
  }

  String get origin {
    var origin = getHeader('origin');
    if (origin != null) {
      origin = origin.trim();
      if (origin.isNotEmpty) {
        return origin;
      }
    }

    var host = hostnameAndPort;
    var scheme = this.scheme ?? 'http';

    origin = "$scheme://$host/";
    return origin;
  }

  @override
  String toString() {
    return 'APIRequest{ method: ${method.name}, '
        'path: $path, '
        'parameters: $parameters, '
        'requester: ${requesterAddress != null ? '$requesterAddress ' : ''}(${requesterSource.name}), '
        'scheme: $scheme, '
        'origin: $origin, '
        'headers: $headers${hasPayload ? ', '
            'payloadLength: $payloadLength, payloadMimeType: $payloadMimeType' : ''} }';
  }
}

/// An [APIResponse] status.
enum APIResponseStatus {
  // ignore: constant_identifier_names
  OK,
  // ignore: constant_identifier_names
  NOT_FOUND,
  // ignore: constant_identifier_names
  UNAUTHORIZED,
  // ignore: constant_identifier_names
  BAD_REQUEST,
  // ignore: constant_identifier_names
  ERROR,
}

/// Represents an API response.
class APIResponse<T> extends APIPayload {
  /// The response status.
  final APIResponseStatus status;

  /// The response headers.
  final Map<String, dynamic> headers;

  /// The response payload/body/
  @override
  final T? payload;

  /// The payload/body MIME Type.
  @override
  String? payloadMimeType;

  /// The payload usual file name extension.
  @override
  String? payloadFileExtension;

  /// The response error.
  final dynamic error;

  APIResponse(this.status,
      {this.headers = const <String, dynamic>{},
      this.payload,
      this.payloadMimeType,
      this.payloadFileExtension,
      this.error,
      Map<String, Duration>? metrics})
      : _metrics = metrics;

  /// Creates a response of status `OK`.
  factory APIResponse.ok(T? payload,
      {Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.OK,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadMimeType: mimeType,
        metrics: metrics);
  }

  /// Transform this response to an `OK` response.
  APIResponse asOk(
      {T? payload,
      Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse.ok(payload ?? this.payload,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `NOT_FOUND`.
  factory APIResponse.notFound(
      {Map<String, dynamic>? headers,
      T? payload,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.NOT_FOUND,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadMimeType: mimeType,
        metrics: metrics);
  }

  /// Transform this response to a `NOT_FOUND` response.
  APIResponse asNotFound(
      {T? payload,
      Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse.notFound(
        payload: payload,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `UNAUTHORIZED`.
  factory APIResponse.unauthorized(
      {Map<String, dynamic>? headers,
      T? payload,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.UNAUTHORIZED,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadMimeType: mimeType,
        metrics: metrics);
  }

  /// Transform this response to an `UNAUTHORIZED` response.
  APIResponse asUnauthorized(
      {T? payload,
      Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse.unauthorized(
        payload: payload,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `BAD_REQUEST`.
  factory APIResponse.badRequest(
      {Map<String, dynamic>? headers,
      T? payload,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.BAD_REQUEST,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadMimeType: mimeType,
        metrics: metrics);
  }

  /// Transform this response to an `BAD_REQUEST` response.
  APIResponse asBadRequest(
      {T? payload,
      Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse.badRequest(
        payload: payload,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates an error response.
  factory APIResponse.error(
      {Map<String, dynamic>? headers,
      dynamic error,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.ERROR,
        headers: headers ?? <String, dynamic>{},
        error: error,
        metrics: metrics);
  }

  /// Transform this response to an `ERROR` response.
  APIResponse asError(
      {Map<String, dynamic>? headers,
      dynamic error,
      Map<String, Duration>? metrics}) {
    return APIResponse.error(
        headers: headers ?? this.headers,
        error: error ?? this.error,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response based into [o] value.
  factory APIResponse.from(dynamic o) {
    if (o == null) {
      return APIResponse.notFound();
    } else if (o is Error || o is Exception) {
      return APIResponse.error(error: '$o');
    } else {
      return APIResponse.ok(o);
    }
  }

  Map<String, Duration>? _metrics;

  /// Returns `true` if any metric is set. See [metrics].
  bool get hasMetrics => _metrics != null && _metrics!.isNotEmpty;

  /// Returns the current metrics.
  Map<String, Duration> get metrics => _metrics ??= <String, Duration>{};

  /// Set a metric.
  ///
  /// This usually is transformed to a `Server-Timing` header.
  setMetric(String name, Duration duration) => metrics[name] = duration;

  /// Returns a metric.
  getMetric(String name) => metrics[name];

  Map<String, DateTime>? _startedMetrics;

  void _copyStartedMetrics(APIResponse other) {
    var otherStartedMetrics = other._startedMetrics;

    if (otherStartedMetrics != null && otherStartedMetrics.isNotEmpty) {
      var startedMetrics = _startedMetrics ??= <String, DateTime>{};
      startedMetrics.addAll(otherStartedMetrics);
    }
  }

  /// Starts a metric chronometer.
  DateTime startMetric(String name) {
    var startedMetrics = _startedMetrics ??= <String, DateTime>{};

    var time = startedMetrics.putIfAbsent(name, () => DateTime.now());
    return time;
  }

  /// Stops a metric previously started and adds it to [metrics].
  /// See [startMetric].
  Duration? stopMetric(String name, {DateTime? now}) {
    var start = _startedMetrics?[name];
    if (start == null) return null;

    now ??= DateTime.now();

    var duration = now.difference(start);
    setMetric(name, duration);

    return duration;
  }

  void stopAllMetrics({DateTime? now}) {
    var startedMetrics = _startedMetrics;

    if (startedMetrics != null) {
      now ??= DateTime.now();

      for (var k in startedMetrics.keys) {
        stopMetric(k, now: now);
      }
    }
  }

  String? getHeader(String headerKey, {String? def}) {
    var val = headers[headerKey];
    if (val != null) return val;

    headerKey = headerKey.trim().toLowerCase();

    val = headers[headerKey];
    if (val != null) return val;

    for (var k in headers.keys) {
      var kLC = k.toLowerCase();

      if (kLC == headerKey) {
        return headers[k];
      }
    }

    return def;
  }

  static final String headerXAccessToken = "X-Access-Token";
  static final String headerXAccessTokenExpiration =
      "X-Access-Token-Expiration";

  static final String exposeHeaders =
      "Content-Length, Content-Type, Last-Modified, $headerXAccessToken, $headerXAccessTokenExpiration";

  /// Returns `true` if this response has `CORS` (Cross-origin Resource Sharing) headers set.
  bool get hasCORS =>
      getHeader('Access-Control-Allow-Origin') != null ||
      getHeader('Access-Control-Allow-Methods') != null;

  /// Sets the `CORS` (Cross-origin Resource Sharing) headers of this response.
  void setCORS(APIRequest request,
      {bool allowCredentials = true,
      List<String>? allowMethods,
      List<String>? allowHeaders,
      List<String>? exposeHeaders}) {
    var origin = request.origin;

    var localhost = false;

    if (origin.isEmpty) {
      headers["Access-Control-Allow-Origin"] = "*";
    } else {
      headers["Access-Control-Allow-Origin"] = origin;

      if (origin.contains("://localhost:") ||
          origin.contains("://127.0.0.1:") ||
          origin.contains("://::1")) {
        localhost = true;
      }
    }

    headers["Access-Control-Allow-Methods"] =
        allowMethods?.join(',') ?? 'GET,HEAD,PUT,POST,PATCH,DELETE,OPTIONS';

    headers["Access-Control-Allow-Credentials"] =
        allowCredentials ? 'true' : 'false';

    if (localhost) {
      headers["Access-Control-Allow-Headers"] = allowHeaders?.join(', ') ??
          'Content-Type, Access-Control-Allow-Headers, Authorization, x-ijt';
    } else {
      headers["Access-Control-Allow-Headers"] = allowHeaders?.join(', ') ??
          'Content-Type, Access-Control-Allow-Headers, Authorization';
    }

    headers["Access-Control-Expose-Headers"] =
        exposeHeaders?.join(', ') ?? exposeHeaders;
  }

  /// Response infos.
  String toInfos() {
    return 'APIResponse{'
        ' status: $status, headers: $headers'
        '${hasPayload ? ', payloadLength: $payloadLength' : ''}'
        '${payloadMimeType != null ? ', payloadMimeType: $payloadMimeType' : ''}'
        '${error != null ? ', error: $error' : ''}'
        ' }';
  }

  /// Returns the [payload] or the [status] as [String].
  @override
  String toString() {
    if (payload != null) {
      return payload.toString();
    } else if (error != null) {
      return error.toString();
    } else {
      return status.toString();
    }
  }
}

class Arguments {
  /// The positional arguments.
  List<String> args;

  /// The parameters (keys with `--` prefixes).
  Map<String, dynamic> parameters;

  /// The flags (keys with `--` prefixes and no values).
  Set<String> flags;

  /// The abbreviations used to [parse].
  Map<String, String> abbreviations;

  Arguments(this.args,
      {Map<String, dynamic>? parameters,
      Set<String>? flags,
      Map<String, String>? abbreviations})
      : parameters = parameters ?? <String, dynamic>{},
        flags = flags ?? <String>{},
        abbreviations = abbreviations ?? <String, String>{};

  /// The keys abbreviations.
  Map<String, String> get keysAbbreviations {
    var keysAbbrev = <String, String>{};

    for (var e in abbreviations.entries) {
      if (!keysAbbrev.containsKey(e.value)) {
        keysAbbrev[e.value] = e.key;
      }
    }

    return keysAbbrev;
  }

  /// Converts this instances to a [String] line.
  ///
  /// The inverse of [parseLine].
  String toArgumentsLine(
          {bool abbreviateFlags = true, bool abbreviateParameters = false}) =>
      toArgumentsList(
              abbreviateFlags: abbreviateFlags,
              abbreviateParameters: abbreviateParameters)
          .join(' ');

  /// Converts this instances to a [String] line.
  ///
  /// The inverse of [parse].
  List<String> toArgumentsList(
      {bool abbreviateFlags = true, bool abbreviateParameters = false}) {
    var arguments = <String>[];

    var keysAbbreviations = abbreviateFlags || abbreviateParameters
        ? this.keysAbbreviations
        : abbreviations;

    for (var f in flags) {
      if (abbreviateFlags) {
        var abbrev = keysAbbreviations[f];
        if (abbrev != null) {
          f = abbrev;
        }
      }
      arguments.add('-$f');
    }

    for (var e in parameters.entries) {
      var k = e.key;

      if (abbreviateParameters) {
        var abbrev = keysAbbreviations[k];
        if (abbrev != null) {
          k = abbrev;
        }
      }

      var v = e.value;

      if (v is Iterable) {
        for (var val in v) {
          arguments.add('--$k');
          arguments.add('$val');
        }
      } else {
        arguments.add('--$k');
        arguments.add('$v');
      }
    }

    return arguments;
  }

  @override
  String toString() {
    return 'Arguments{ args: $args, parameters: $parameters, flags: $flags }';
  }

  static final RegExp _regexpSpace = RegExp(r'\s+');

  /// Splits [argsLine] to a [List].
  static List<String> splitArgumentsLine(String argsLine) =>
      argsLine.split(_regexpSpace);

  /// Parses [argsLine].
  ///
  /// - See [parse].
  factory Arguments.parseLine(
    String argsLine, {
    Set<String>? flags,
    Map<String, String>? abbreviations,
    bool caseInsensitive = true,
  }) {
    var args = splitArgumentsLine(argsLine);
    return Arguments.parse(args,
        flags: flags,
        abbreviations: abbreviations,
        caseInsensitive: caseInsensitive);
  }

  static final RegExp _namedParameter = RegExp(r'^--?(\w+)$');

  /// Parses [args].
  ///
  /// - [flags] the flags keys.
  /// - [abbreviations] the keys abbreviations.
  /// - [caseInsensitive] if `true`, keys are `toLowerCase`.
  factory Arguments.parse(
    List<String> args, {
    Set<String>? flags,
    Map<String, String>? abbreviations,
    bool caseInsensitive = true,
  }) {
    abbreviations ??= <String, String>{};

    var parsedParams = <String, dynamic>{};
    var parsedFlags = <String>{};

    for (var i = 0; i < args.length;) {
      var key = args[i];

      String? name;
      var flagName = false;

      if (key.startsWith('-')) {
        var match = _namedParameter.firstMatch(key);

        if (match != null) {
          name = match.group(1)!;

          if (caseInsensitive) {
            name = name.toLowerCase();
          }

          if (!key.startsWith('--')) {
            var name2 = abbreviations[name];
            if (name2 != null) {
              name = name2;
            } else if (i < args.length - 1) {
              var next = args[i + 1];
              var nextKey = _namedParameter.hasMatch(next);
              flagName = nextKey;
            } else {
              flagName = true;
            }
          }
        }
      }

      if (name != null) {
        if (flags != null && flags.contains(name)) {
          args.removeAt(i);
          parsedFlags.add(name);
        } else if (flagName) {
          args.removeAt(i);
          parsedFlags.add(name);
        } else if (i < args.length - 1) {
          var val = args.removeAt(i + 1);
          args.removeAt(i);
          _addToMap(parsedParams, name, val);
        } else {
          throw StateError('Should be a flag');
        }
      } else {
        ++i;
      }
    }

    return Arguments(args,
        parameters: parsedParams,
        flags: parsedFlags,
        abbreviations: abbreviations);
  }

  static void _addToMap(Map<String, dynamic> map, String key, String value) {
    if (map.containsKey(key)) {
      var prev = map[key];
      if (prev is List) {
        prev.add(value);
      } else {
        map[key] = [prev, value];
      }
    } else {
      map[key] = value;
    }
  }
}

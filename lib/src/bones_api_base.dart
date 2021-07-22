import 'dart:async';

/// Root class of an API.
abstract class APIRoot {
  /// API name.
  final String name;

  /// API version.
  final String version;

  APIRoot(this.name, this.version);

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
  String toString() {
    return '$name[$version]$modulesNames';
  }
}

/// An API route handler
typedef APIRouteHandler<T> = FutureOr<APIResponse<T>> Function(
    APIRequest request);

/// A module of an API.
abstract class APIModule {
  /// The name of this API module.
  final String name;

  late final APIRouteBuilder _routeBuilder;

  APIModule(this.name) {
    _routeBuilder = APIRouteBuilder(this);
  }

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
class APIRouteBuilder {
  /// The API module of this route builder.
  final APIModule module;

  APIRouteBuilder(this.module);

  /// Adds a route of [name] with [handler] for ANY method.
  APIModule any(String name, APIRouteHandler handler) =>
      module.addRoute(null, name, handler);

  /// Adds a route of [name] with [handler] for `GET` method.
  APIModule get(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.GET, name, handler);

  /// Adds a route of [name] with [handler] for `POST` method.
  APIModule post(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.POST, name, handler);

  /// Adds a route of [name] with [handler] for `PUT` method.
  APIModule put(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.PUT, name, handler);

  /// Adds a route of [name] with [handler] for `DELETE` method.
  APIModule delete(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.DELETE, name, handler);

  /// Adds a route of [name] with [handler] for `PATCH` method.
  APIModule patch(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.PATCH, name, handler);
}

/// API Methods
enum APIRequestMethod {
  GET,
  POST,
  PUT,
  DELETE,
  PATCH,
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

/// Represents an API request.
class APIRequest {
  /// The request method.
  final APIRequestMethod method;

  /// The request path.
  final String path;

  /// The parameters of the request.
  final Map<String, dynamic> parameters;

  /// The headers of the request.
  final Map<String, dynamic> headers;

  /// The payload/body of the request.
  final dynamic payload;

  late final List<String> _pathParts;

  APIRequest(this.method, this.path,
      {this.parameters = const <String, dynamic>{},
      this.headers = const <String, dynamic>{},
      this.payload})
      : _pathParts = _buildPathParts(path);

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
}

/// An [APIResponse] status.
enum APIResponseStatus {
  OK,
  NOT_FOUND,
  UNAUTHORIZED,
  ERROR,
}

/// Represents an API response.
class APIResponse<T> {
  /// The response status.
  final APIResponseStatus status;

  /// The response headers.
  final Map<String, dynamic> headers;

  /// The response payload/body/
  final T? payload;

  /// The response error.
  final dynamic error;

  APIResponse(this.status,
      {this.headers = const <String, dynamic>{}, this.payload, this.error});

  /// Creates a response of status `OK`.
  factory APIResponse.ok(T? payload, {Map<String, dynamic>? headers}) {
    return APIResponse(APIResponseStatus.OK,
        headers: headers ?? <String, dynamic>{}, payload: payload);
  }

  /// Creates a response of status `NOT_FOUND`.
  factory APIResponse.notFound({Map<String, dynamic>? headers, T? payload}) {
    return APIResponse(APIResponseStatus.NOT_FOUND,
        headers: headers ?? <String, dynamic>{}, payload: payload);
  }

  /// Creates a response of status `UNAUTHORIZED`.
  factory APIResponse.unauthorized(
      {Map<String, dynamic>? headers, T? payload}) {
    return APIResponse(APIResponseStatus.UNAUTHORIZED,
        headers: headers ?? <String, dynamic>{}, payload: payload);
  }

  /// Creates an error response.
  factory APIResponse.error({Map<String, dynamic>? headers, dynamic error}) {
    return APIResponse(APIResponseStatus.ERROR,
        headers: headers ?? <String, dynamic>{}, error: error);
  }

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

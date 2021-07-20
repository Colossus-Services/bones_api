import 'dart:async';

abstract class APIRoot {
  final String name;

  final String version;

  APIRoot(this.name, this.version);

  String? get defaultModuleName => null;

  Set<APIModule> loadModules();

  Map<String, APIModule>? _modules;

  Set<String> get modulesNames {
    _ensureModulesLoaded();
    return _modules!.keys.toSet();
  }

  Set<APIModule> get modules {
    _ensureModulesLoaded();
    return _modules!.values.toSet();
  }

  void _ensureModulesLoaded() {
    _modules ??= Map.fromEntries(loadModules().map((e) => MapEntry(e.name, e)));
  }

  APIModule? getModule(String name) {
    _ensureModulesLoaded();
    return _modules![name];
  }

  APIModule? getModuleByRequest(APIRequest request) {
    _ensureModulesLoaded();
    var moduleName = resolveModule(request);
    return _modules![moduleName];
  }

  String resolveModule(APIRequest request) {
    var moduleName = request.pathPart(1, reversed: true);
    return moduleName;
  }

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

typedef APIRouteHandler<T> = FutureOr<APIResponse<T>> Function(
    APIRequest request);

abstract class APIModule {
  final String name;

  late final APIRouteBuilder _routeBuilder;

  APIModule(this.name) {
    _routeBuilder = APIRouteBuilder(this);
  }

  String? get defaultRouteName => null;

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
      case APIRequestMethod.PATH:
        return _routesHandlersPATH;
      default:
        return _routesHandlers;
    }
  }

  APIModule addRoute(
      APIRequestMethod? method, String name, APIRouteHandler handler) {
    var routesHandlers = _getRoutesHandlers(method);
    routesHandlers[name] = handler;
    return this;
  }

  APIRouteBuilder get routes => _routeBuilder;

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

  APIRouteHandler<T>? getRouteHandlerByRequest<T>(APIRequest request) {
    _ensureConfigured();

    var route = resolveRoute(request);
    return getRouteHandler(route, request.method);
  }

  String resolveRoute(APIRequest request) {
    var routeName = request.pathPart(0, reversed: true);
    return routeName;
  }

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

class APIRouteBuilder {
  final APIModule module;

  APIRouteBuilder(this.module);

  APIModule any(String name, APIRouteHandler handler) =>
      module.addRoute(null, name, handler);

  APIModule get(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.GET, name, handler);

  APIModule pos(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.POST, name, handler);

  APIModule put(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.PUT, name, handler);

  APIModule delete(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.DELETE, name, handler);

  APIModule patch(String name, APIRouteHandler handler) =>
      module.addRoute(APIRequestMethod.PATH, name, handler);
}

enum APIRequestMethod {
  GET,
  POST,
  PUT,
  DELETE,
  PATH,
}

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
    case 'path':
    case 'PATH':
      return APIRequestMethod.PATH;

    default:
      return null;
  }
}

class APIRequest {
  final APIRequestMethod method;

  final String path;

  final Map<String, dynamic> parameters;

  final Map<String, dynamic> headers;

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

  factory APIRequest.get(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.GET, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  factory APIRequest.post(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.POST, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  factory APIRequest.put(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.PUT, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  factory APIRequest.delete(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.DELETE, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  factory APIRequest.path(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload}) {
    return APIRequest(APIRequestMethod.PATH, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload);
  }

  List<String> get pathParts => _pathParts.toList();

  String pathPart(int index, {String delimiter = '/', bool reversed = false}) {
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

enum APIResponseStatus {
  OK,
  NOT_FOUND,
  UNAUTHORIZED,
  ERROR,
}

class APIResponse<T> {
  final APIResponseStatus status;

  final Map<String, dynamic> headers;

  final T? payload;

  final dynamic error;

  APIResponse(this.status,
      {this.headers = const <String, dynamic>{}, this.payload, this.error});

  factory APIResponse.ok(T? payload, {Map<String, dynamic>? headers}) {
    return APIResponse(APIResponseStatus.OK,
        headers: headers ?? <String, dynamic>{}, payload: payload);
  }

  factory APIResponse.notFound({Map<String, dynamic>? headers, T? payload}) {
    return APIResponse(APIResponseStatus.NOT_FOUND,
        headers: headers ?? <String, dynamic>{}, payload: payload);
  }

  factory APIResponse.unauthorized(
      {Map<String, dynamic>? headers, T? payload}) {
    return APIResponse(APIResponseStatus.UNAUTHORIZED,
        headers: headers ?? <String, dynamic>{}, payload: payload);
  }

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

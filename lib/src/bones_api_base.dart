import 'dart:async';

/// Root class of an API.
abstract class APIRoot {
  static const String VERSION = '1.0.4';

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

/// Base class for payload.
abstract class APIPayload {
  /// The payload.
  dynamic get payload;

  /// The payload MIME Type.
  String? get payloadMimeType;

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

  /// The payload/body of the request.
  @override
  final dynamic payload;

  /// The payload/body MIME Type.
  @override
  String? payloadMimeType;

  late final List<String> _pathParts;

  APIRequest(this.method, this.path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      this.payload,
      this.payloadMimeType})
      : parameters = parameters ?? <String, dynamic>{},
        headers = headers ?? <String, dynamic>{},
        _pathParts = _buildPathParts(path);

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

  @override
  String toString() {
    return 'APIRequest{ method: $method, path: $path, parameters: $parameters, headers: $headers${hasPayload ? ', payloadLength: $payloadLength' : ''} }';
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

  /// The response error.
  final dynamic error;

  APIResponse(this.status,
      {this.headers = const <String, dynamic>{},
      this.payload,
      this.payloadMimeType,
      this.error});

  /// Creates a response of status `OK`.
  factory APIResponse.ok(T? payload,
      {Map<String, dynamic>? headers, String? mimeType}) {
    return APIResponse(APIResponseStatus.OK,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadMimeType: mimeType);
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

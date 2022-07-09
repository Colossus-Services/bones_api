import 'dart:collection';
import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_authentication.dart';
import 'bones_api_config.dart';
import 'bones_api_entity.dart';
import 'bones_api_initializable.dart';
import 'bones_api_module.dart';
import 'bones_api_security.dart';
import 'bones_api_utils_arguments.dart';
import 'bones_api_utils_json.dart';

/// An [APIRoot] [APIRequest] handler.
///
/// See [APIRoot.preApiRequestHandlers] and [APIRoot.posApiRequestHandlers].
typedef APIRequestHandler = FutureOr<APIResponse<T>?> Function<T>(
    APIRoot apiRoot, APIRequest request);

/// An [APIRoot] logger function.
typedef APILogger = void Function(APIRoot apiRoot, String type, String? message,
    [Object? error, StackTrace? stackTrace]);

class BonesAPI {
  // ignore: constant_identifier_names
  static const String VERSION = '1.2.2';

  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    Json.boot();
  }
}

/// Root class of an API.
abstract class APIRoot with Initializable {
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
    } else {
      return null;
    }
  }

  /// Returns an [APIRoot] instance with [name].
  ///
  /// - If [caseSensitive] is `false` will ignore [name] case.
  static APIRoot? getByName(String name,
      {bool caseSensitive = false, bool lastAsDefault = false}) {
    var apiRoot = _instances[name];
    if (apiRoot != null) return apiRoot;

    if (!caseSensitive) {
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
      {bool lastAsDefault = false, bool caseSensitive = false}) {
    if (!caseSensitive) {
      part = part.toLowerCase();
    }

    return getWhere((apiRoot) {
      var n = caseSensitive ? apiRoot.name : apiRoot.name.toLowerCase();
      return n.contains(part);
    }, lastAsDefault: lastAsDefault);
  }

  /// API name.
  final String name;

  /// API version.
  final String version;

  /// The API Configuration.
  APIConfig apiConfig;

  /// [APIRequestHandler] list to try before attempt an API call.
  ///
  /// - The first [APIRequestHandler] to return an [APIResponse] will defined the [APIRequest] response.
  /// - This [APIRequestHandler] list is ALWAYS called.
  /// - An API call will be attempted ONLY if NO [APIRequestHandler] returns an [APIResponse].
  final Set<APIRequestHandler> preApiRequestHandlers;

  /// [APIRequestHandler] list to try after attempt an API call.
  ///
  /// - This [APIRequestHandler] list is ONLY called if there's no successful API call.
  final Set<APIRequestHandler> posApiRequestHandlers;

  /// The logger of this [APIRoot] instance. See [APILogger].
  APILogger? logger;

  APIRoot(this.name, this.version,
      {dynamic apiConfig,
      APIConfigProvider? apiConfigProvider,
      Iterable<APIRequestHandler>? preApiRequestHandlers,
      Iterable<APIRequestHandler>? posApiRequestHandlers})
      : preApiRequestHandlers =
            LinkedHashSet.from(preApiRequestHandlers ?? <APIRequestHandler>{}),
        posApiRequestHandlers =
            LinkedHashSet.from(posApiRequestHandlers ?? <APIRequestHandler>{}),
        apiConfig =
            APIConfig.fromSync(apiConfig, apiConfigProvider) ?? APIConfig() {
    BonesAPI.boot();
    _instances[name] = this;
  }

  /// Logs to [logger], if present.
  void log(String type, String? message,
      [Object? error, StackTrace? stackTrace]) {
    var logger = this.logger;
    if (logger != null) {
      logger(this, type, message, error, stackTrace);
    }
  }

  @override
  FutureOr<List<Initializable>> initializeDependencies() {
    var lAsync1 = loadEntityProviders();
    var lAsync2 = loadEntityRepositoryProviders();

    var inits = lAsync1.resolveBoth(lAsync2,
        (l1, l2) => [...l1, ...l2].whereType<Initializable>().toList());
    return inits;
  }

  @override
  FutureOr<InitializationResult> initialize() => _ensureModulesLoaded();

  /// The default module to use when request module doesn't match.
  String? get defaultModuleName => null;

  /// Gracefully loads the [EntityProvider] needed for this [APIRoot].
  FutureOr<List<EntityProvider>> loadEntityProviders() => <EntityProvider>[];

  /// Gracefully loads the [EntityRepositoryProvider] needed for this [APIRoot].
  FutureOr<List<EntityRepositoryProvider>> loadEntityRepositoryProviders() =>
      <EntityRepositoryProvider>[];

  /// Loads the modules of this API.
  FutureOr<Set<APIModule>> loadModules();

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

  Future<InitializationResult>? _modulesLoading;

  FutureOr<InitializationResult> _ensureModulesLoaded() {
    if (_modules != null) {
      return InitializationResult.ok(this, dependencies: _modules!.values);
    }

    var modulesLoading = _modulesLoading;
    if (modulesLoading != null) {
      return modulesLoading;
    }

    var ret = loadModules().resolveMapped((modules) {
      _modules ??= Map.fromEntries(modules.map((e) => MapEntry(e.name, e)));
      _modulesLoading = null;
      return InitializationResult.ok(this, dependencies: modules);
    });

    if (ret is Future<InitializationResult>) {
      _modulesLoading = ret;
    }

    return ret;
  }

  /// Returns a module with [name].
  APIModule? getModule(String name) {
    _ensureModulesLoaded();
    var module = _modules![name];
    if (module != null) {
      module.ensureConfigured();
    }
    return module;
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
    var moduleName = request.pathPartReversed(1);
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

  /// Attempt to process [request] using an [APIRequestHandler] at [handlers].
  FutureOr<APIResponse<T>?> callHandlers<T>(
      Iterable<APIRequestHandler> handlers, APIRequest request,
      [String handlersType = 'external']) {
    if (handlers.isEmpty) return null;

    Iterator<APIRequestHandler> handlersIterator = handlers.iterator;

    while (handlersIterator.moveNext()) {
      var handler = handlersIterator.current;

      try {
        var response = handler<T>(this, request);

        if (response == null) continue;

        if (response is APIResponse) {
          return response;
        } else if (response is Future<APIResponse<T>?>) {
          return response.then((resp) {
            if (resp != null) return resp;
            return _callHandlersAsync(handlersIterator, request, handlersType);
          }, onError: (e, s) {
            _logCallHandlersError(handlersType, handler, e, s);
            return _callHandlersAsync(handlersIterator, request, handlersType);
          });
        } else {
          continue;
        }
      } catch (e, s) {
        _logCallHandlersError(handlersType, handler, e, s);
        continue;
      }
    }

    return null;
  }

  void _logCallHandlersError(
          String handlersType, APIRequestHandler handler, error, stackTrace) =>
      log(
          'APIRoot',
          'Error calling `APIRequestHandler` ($handlersType): $handler',
          error,
          stackTrace);

  Future<APIResponse<T>?> _callHandlersAsync<T>(
      Iterator<APIRequestHandler> handlersIterator,
      APIRequest request,
      String handlersType) async {
    while (handlersIterator.moveNext()) {
      var handler = handlersIterator.current;

      try {
        var response = handler<T>(this, request);
        if (response == null) continue;

        if (response is APIResponse) {
          return response;
        } else if (response is Future<APIResponse<T>?>) {
          var resp = await response;
          if (resp != null) {
            return resp;
          }
        } else {
          continue;
        }
      } catch (e, s) {
        _logCallHandlersError(handlersType, handler, e, s);
        continue;
      }
    }

    return null;
  }

  /// Calls the API.
  FutureOr<APIResponse<T>> call<T>(APIRequest request) {
    if (request.method == APIRequestMethod.OPTIONS) {
      throw ArgumentError("Can't perform a call with an `OPTIONS` method. "
          "Requests with method `OPTIONS` are reserved for CORS or other informational requests.");
    }

    var ret = _ensureModulesLoaded();

    if (ret is Future<InitializationResult>) {
      return ret.then((_) => _preCall(request));
    } else {
      return _preCall(request);
    }
  }

  FutureOr<APIResponse<T>> _preCall<T>(APIRequest request) {
    var preResponse = callHandlers<T>(
        preApiRequestHandlers, request, 'preApiRequestHandlers');

    if (preResponse != null) {
      return preResponse
          .resolveMapped((response) => response ?? _callAPI(request));
    } else {
      return _callAPI(request);
    }
  }

  FutureOr<APIResponse<T>> _callAPI<T>(APIRequest request) {
    var apiSecurity = security;

    if (apiSecurity != null &&
        request.credential != null &&
        request.authentication == null) {
      return apiSecurity.authenticateByRequest(request).resolveWith(() {
        return _callImpl<T>(request, apiSecurity);
      });
    } else {
      return _callImpl<T>(request, apiSecurity);
    }
  }

  FutureOr<APIResponse<T>> _callImpl<T>(
      APIRequest apiRequest, APISecurity? apiSecurity) {
    var pathPartRoot = apiRequest.pathParts[0];

    if (pathPartRoot == 'API-INFO') {
      var info = apiInfo(apiRequest);
      return APIResponse.ok(info as T)..payloadMimeType = 'application/json';
    }

    var module = getModuleByRequest(apiRequest);

    if (module == null &&
        apiSecurity != null &&
        apiRequest.lastPathPart == authenticationRoute) {
      return apiSecurity.doRequestAuthentication(apiRequest);
    }

    return _callModule<T>(module, apiRequest);
  }

  Future<APIAuthentication?> callAuthenticate(
      String email, String password) async {
    var auth = await call(APIRequest.get('/authenticate',
        parameters: {'email': email, 'password': password}));
    if (auth.isNotOK) return null;

    var authentication = APIAuthentication.fromJson(auth.payload);
    return authentication;
  }

  /// Returns `true` if [apiRequest] is an accepted route/call.
  bool acceptsRequest(APIRequest apiRequest) {
    var module = getModuleByRequest(apiRequest);
    if (module == null) {
      var def = defaultModuleName;
      if (def != null) {
        module = _modules![def];
      }
    }

    if (module == null) return false;

    return module.acceptsRequest(apiRequest);
  }

  /// Returns a [APIRootInfo].
  APIRootInfo apiInfo([APIRequest? apiRequest]) =>
      APIRootInfo(this, apiRequest);

  FutureOr<APIResponse<T>> _callModule<T>(
      APIModule? module, APIRequest request) {
    if (module == null) {
      var def = defaultModuleName;
      if (def != null) {
        module = _modules![def];
      }
    }

    if (module == null) {
      return onNoRouteForPath<T>(request);
    }

    return module.call(request);
  }

  FutureOr<APIResponse<T>> onNoRouteForPath<T>(APIRequest request) {
    var posResponse = callHandlers<T>(
        posApiRequestHandlers, request, 'posApiRequestHandlers');

    if (posResponse != null) {
      return posResponse.resolveMapped((response) {
        return response ?? _responseNotFoundNoRouteForPath<T>(request);
      });
    }

    return _responseNotFoundNoRouteForPath<T>(request);
  }

  String get authenticationRoute => 'authenticate';

  String? get securityModuleName => null;

  APIModule? get securityModule => _securityModuleImpl();

  APIModule? _securityModule;

  APIModule? _securityModuleImpl() {
    if (_securityModule != null) return _securityModule;

    var securityModuleName = this.securityModuleName;
    if (securityModuleName != null) {
      var module = getModule(securityModuleName);
      if (module != null) {
        return _securityModule = module;
      } else {
        throw StateError(
            "Can't find security module with name: $securityModuleName");
      }
    }

    return null;
  }

  APISecurity? get security => _securityImpl();

  APISecurity? _security;
  bool _securityResolved = false;

  APISecurity? _securityImpl() {
    if (_securityResolved) return _security;
    _securityResolved = true;

    var securityModule = this.securityModule;
    return _security = securityModule?.security;
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

/// The [APIRoot] information.
///
/// Returned by `API-INFO`.
class APIRootInfo {
  final APIRoot apiRoot;
  final APIRequest? apiRequest;

  APIRootInfo(this.apiRoot, [this.apiRequest]);

  /// Returns the name of the [apiRoot].
  String get name => apiRoot.name;

  /// Returns the version of the [apiRoot].
  String get version => apiRoot.version;

  /// Returns the modules of the [apiRoot].
  List<APIModuleInfo> get modules =>
      apiRoot.modules.map((e) => e.apiInfo(apiRequest)).toList();

  Map<String, dynamic> toJson() =>
      {'name': name, 'version': version, 'modules': modules};
}

/// An API route handler
typedef APIRouteFunction<T> = FutureOr<APIResponse<T>> Function(
    APIRequest request);

/// A route handler, with its [function] and [rules].
class APIRouteHandler<T> {
  final APIModule module;
  final APIRequestMethod? requestMethod;
  final String routeName;

  APIRouteFunction<T> function;

  List<APIRouteRule> rules;

  Map<String, TypeInfo>? parameters;

  APIRouteHandler(this.module, this.requestMethod, this.routeName,
      this.function, this.parameters, Iterable<APIRouteRule>? rules)
      : rules = List<APIRouteRule>.unmodifiable(rules ?? <APIRouteRule>[]);

  /// Calls this route.
  FutureOr<APIResponse<T>> call(APIRequest request) {
    if (!checkRules(request)) {
      return APIResponse.unauthorized(
          payloadDynamic: 'UNAUTHORIZED: Rules issues $rules');
    }

    return function(request);
  }

  /// Check the rules of this route.
  bool checkRules(APIRequest request) {
    if (rules.isEmpty) return true;

    for (var rule in rules) {
      if (!rule.validate(request)) {
        return false;
      }
    }

    return true;
  }

  APIRouteInfo apiInfo([APIRequest? apiRequest]) =>
      APIRouteInfo(this, apiRequest);

  @override
  String toString() {
    return 'APIRouteHandler${requestMethod != null ? '[${requestMethod!.name}]' : ''}'
        '{routeName: $routeName'
        '${rules.isNotEmpty ? ', rules: $rules' : ''}'
        '}';
  }
}

/// A route information.
///
/// Returned by `API-INFO`.
class APIRouteInfo {
  final APIRouteHandler routeHandler;
  final APIRequest? apiRequest;

  APIRouteInfo(this.routeHandler, [this.apiRequest]);

  /// Returns the name of the route.
  String get name => routeHandler.routeName;

  /// Returns the module of the route.
  APIModule get module => routeHandler.module;

  /// Returns the method of the route.
  APIRequestMethod? get method => routeHandler.requestMethod;

  /// Returns the parameters of the route.
  Map<String, TypeInfo>? get parameters => routeHandler.parameters;

  /// Returns `true` if this route has parameters.
  bool get hasParameters => parameters != null && parameters!.isNotEmpty;

  /// Returns the [Uri] of the route.
  Uri get uri {
    var baseUri = apiRequest != null
        ? Uri.tryParse(apiRequest!.origin) ?? Uri.base
        : Uri.base;
    var module = routeHandler.module;
    var path = '${module.name}/$name';

    var parameters = hasParameters ? parametersAsJson : null;

    var scheme = baseUri.scheme;

    var uri = Uri(
        scheme: scheme,
        host: baseUri.host,
        port: baseUri.port,
        userInfo: baseUri.userInfo,
        path: path,
        queryParameters: parameters);

    return uri;
  }

  String get uriAsJson {
    var uri = this.uri;

    if (uri.scheme == 'file') {
      var path = uri.path;
      var query = uri.query;
      return query.isEmpty ? path : '$path?$query';
    } else {
      return uri.toString();
    }
  }

  /// Returns the rules of the route.
  List<APIRouteRule> get rules => routeHandler.rules;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (method != null) 'method': method!.name,
        if (parameters != null && parameters!.isNotEmpty)
          'parameters': parametersAsJson,
        'uri': uriAsJson,
        if (rules.isNotEmpty) 'rules': rules,
      };

  Map<String, String> get parametersAsJson =>
      Map<String, String>.fromEntries(parameters!.entries
          .where((e) => !e.value.isOf(APIRequest))
          .map((e) => MapEntry(e.key, e.value.toString())));
}

APIResponse<T> _responseNotFoundNoRouteForPath<T>(APIRequest request) {
  var payload = 'NOT FOUND: No route for path "${request.path}"';
  return APIResponse.notFound(payloadDynamic: payload);
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
  // ignore: constant_identifier_names
  OPTIONS,
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
      case APIRequestMethod.OPTIONS:
        return 'OPTIONS';
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
    case 'optionS':
    case 'OPTIONS':
      return APIRequestMethod.OPTIONS;
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
  static final TypeInfo typeInfo = TypeInfo.from(APIRequest);

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

  /// Returns [payload] as bytes ([Uint8List]).
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

  /// The session ID (usually from a session cookie).
  final String? sessionID;

  /// If `true` indicates that [sessionID] is new (was created in this request).
  final bool newSession;

  /// The request credential.
  APICredential? credential;

  /// The authentication of this request, processed by [APISecurity].
  APIAuthentication? authentication;

  /// Returns `true` if this request is authenticated and the token is not expired.
  bool get isAuthenticated =>
      authentication != null && authentication!.isExpired();

  final String? scheme;

  final APIRequesterSource requesterSource;
  final String? _requesterAddress;

  final Uri requestedUri;
  final Object? originalRequest;

  late final List<String> _pathParts;

  APIRequest(this.method, this.path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      this.payload,
      this.payloadMimeType,
      this.payloadFileExtension,
      this.sessionID,
      this.newSession = false,
      this.credential,
      String? scheme,
      APIRequesterSource? requesterSource,
      String? requesterAddress,
      DateTime? time,
      Uri? requestedUri,
      this.originalRequest})
      : parameters = parameters ?? <String, dynamic>{},
        headers = headers ?? <String, dynamic>{},
        _pathParts = _buildPathParts(path),
        scheme = scheme?.trim(),
        requesterSource = _resolveRestSource(requesterAddress),
        _requesterAddress = requesterAddress,
        requestedUri = requestedUri ??
            Uri(
                host: requesterSource == APIRequesterSource.local
                    ? 'localhost'
                    : null,
                path: path,
                queryParameters: parameters?.map((key, value) => MapEntry(
                    key,
                    value is List
                        ? value.map((e) => '$e').toList()
                        : '$value'))),
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
      dynamic payload,
      APICredential? credential}) {
    return APIRequest(APIRequestMethod.GET, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        credential: credential);
  }

  /// Creates a request of `POST` method.
  factory APIRequest.post(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload,
      APICredential? credential}) {
    return APIRequest(APIRequestMethod.POST, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        credential: credential);
  }

  /// Creates a request of `PUT` method.
  factory APIRequest.put(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload,
      APICredential? credential}) {
    return APIRequest(APIRequestMethod.PUT, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        credential: credential);
  }

  /// Creates a request of `DELETE` method.
  factory APIRequest.delete(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload,
      APICredential? credential}) {
    return APIRequest(APIRequestMethod.DELETE, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        credential: credential);
  }

  /// Creates a request of `PATCH` method.
  factory APIRequest.patch(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload,
      APICredential? credential}) {
    return APIRequest(APIRequestMethod.PATCH, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        credential: credential);
  }

  /// The elapsed time of this request.
  ///
  /// Difference between [DateTime.now] and [time].
  Duration get elapsedTime => DateTime.now().difference(time);

  /// Returns the parts of the [path].
  List<String> get pathParts => _pathParts.toList();

  /// First of [pathParts].
  String get pathPartFirst => _pathParts.isEmpty ? '' : _pathParts.first;

  /// Last of [pathParts].
  String get pathPartLast => _pathParts.isEmpty ? '' : _pathParts.last;

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

  /// Sames as [pathPart] but with a reversed [index].
  String pathPartReversed(int index) {
    var length = _pathParts.length;

    var idx = length - (index + 1);
    return idx >= 0 && idx < length ? _pathParts[idx] : '';
  }

  String? _lastPathPart;

  /// Returns the last [pathParts]. Sames as [pathPartReversed] for index `0`.
  String get lastPathPart => _lastPathPart ??= pathPartReversed(0);

  /// Returns from [parameters] a value for [name1] or [name1] .. [name9].
  V? getParameter<V>(String name1, [V? def]) {
    var val = parameters[name1];
    return val ?? def;
  }

  V? getParameterFirstOf<V>(
    String name1, [
    String? name2,
    String? name3,
    String? name4,
    String? name5,
    String? name6,
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

    return null;
  }

  /// Returns from [parameters] a value for [name] or [name1] .. [name9] ignoring case.
  /// See [getParameter].
  V? getParameterIgnoreCase<V>(String name, [V? def]) {
    var val = parameters[name];
    if (val != null) return val;

    for (var k in parameters.keys) {
      if (equalsIgnoreAsciiCase(k, name)) return parameters[k];
    }

    return def;
  }

  V? getParameterIgnoreCaseFirstOf<V>(String name1,
      [String? name2,
      String? name3,
      String? name4,
      String? name5,
      String? name6]) {
    var val = getParameterFirstOf(name1, name2, name3, name4, name5);
    if (val != null) return val;

    for (var k in parameters.keys) {
      if (equalsIgnoreAsciiCase(k, name1)) return parameters[k];

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
    }

    return null;
  }

  String? getHeader(String key, {String? def}) {
    var val = headers[key];
    if (val != null) return val;

    key = key.trim();

    for (var k in headers.keys) {
      if (equalsIgnoreAsciiCase(k, key)) {
        return headers[k];
      }
    }

    return def;
  }

  String? getHeaderFirstOf(
    String key1, [
    String? key2,
    String? key3,
    String? key4,
    String? key5,
    String? key6,
  ]) {
    var val = _getHeaderFirstOf(key1, key2, key3, key4, key5, key6);
    if (val != null) return val;

    for (var k in headers.keys) {
      if (equalsIgnoreAsciiCase(k, key1)) return parameters[k];

      if (key2 != null && equalsIgnoreAsciiCase(k, key2)) {
        return headers[k];
      }

      if (key3 != null && equalsIgnoreAsciiCase(k, key3)) {
        return headers[k];
      }

      if (key4 != null && equalsIgnoreAsciiCase(k, key4)) {
        return headers[k];
      }

      if (key5 != null && equalsIgnoreAsciiCase(k, key5)) {
        return headers[k];
      }

      if (key6 != null && equalsIgnoreAsciiCase(k, key6)) {
        return headers[k];
      }
    }

    return null;
  }

  String? _getHeaderFirstOf(
    String key1, [
    String? key2,
    String? key3,
    String? key4,
    String? key5,
    String? key6,
  ]) {
    var val = headers[key1];
    if (val != null) return val;

    if (key2 != null) {
      val = headers[key2];
      if (val != null) return val;
    }

    if (key3 != null) {
      val = headers[key3];
      if (val != null) return val;
    }

    if (key4 != null) {
      val = headers[key4];
      if (val != null) return val;
    }

    if (key5 != null) {
      val = headers[key5];
      if (val != null) return val;
    }

    if (key6 != null) {
      val = headers[key6];
      if (val != null) return val;
    }

    return null;
  }

  /// Returns `true` if [patterns] matches [hostname].
  bool matchesHostname(Pattern pattern) {
    var hostname = this.hostname;
    if (pattern is RegExp) {
      return pattern.hasMatch(hostname);
    } else {
      return hostname == pattern;
    }
  }

  String? _hostname;

  String get hostname => _hostname ??= _hostnameImpl();

  String _hostnameImpl() {
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

  int? _port;

  int get port => _port ??= _portImpl();

  int _portImpl() {
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

  String? _requesterAddressResolved;

  String? get requesterAddress =>
      _requesterAddressResolved ??= _requesterAddressImpl();

  String? _requesterAddressImpl() {
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

  String? _origin;

  String get origin => _origin ??= _originImpl();

  String _originImpl() {
    var origin = getHeader('origin');
    if (origin != null) {
      origin = origin.trim();
      if (origin.isNotEmpty) {
        return origin;
      }
    }

    var host = hostnameAndPort;
    if (host.endsWith(':0')) {
      host = host.substring(0, host.length - 2);
    }

    var scheme = this.scheme ?? 'http';

    origin = "$scheme://$host/";
    return origin;
  }

  @override
  String toString({bool withHeaders = true, bool withPayload = true}) {
    var headersStr = withHeaders ? ', headers: $headers' : '';
    var payloadStr = withPayload && hasPayload
        ? ', payloadLength: $payloadLength, payloadMimeType: $payloadMimeType'
        : '';

    return 'APIRequest{ method: ${method.name}, '
        'path: $path, '
        'parameters: $parameters, '
        'requester: ${requesterAddress != null ? '$requesterAddress ' : ''}(${requesterSource.name}), '
        'scheme: $scheme, '
        'origin: $origin'
        '$headersStr$payloadStr'
        ' }';
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

/// Parses a [APIResponseStatus].
APIResponseStatus? parseAPIResponseStatus(Object o) {
  if (o is APIResponseStatus) return o;

  if (o is int) {
    switch (o) {
      case 200:
      case 201:
      case 202:
      case 204:
      case 205:
      case 206:
        return APIResponseStatus.OK;
      case 400:
        return APIResponseStatus.BAD_REQUEST;
      case 401:
      case 402:
      case 403:
        return APIResponseStatus.UNAUTHORIZED;
      case 404:
      case 405:
      case 410:
        return APIResponseStatus.NOT_FOUND;
      case 429:
      case 500:
      case 501:
      case 503:
        return APIResponseStatus.ERROR;
      default:
        return null;
    }
  }

  var s = o.toString().trim().toLowerCase();

  switch (s) {
    case 'ok':
      return APIResponseStatus.OK;
    case 'internalservererror':
    case 'internal server error':
    case 'internal_server_error':
    case 'error':
      return APIResponseStatus.ERROR;
    case 'notfound':
    case 'not found':
    case 'not_found':
      return APIResponseStatus.NOT_FOUND;
    case 'unauthorized':
      return APIResponseStatus.UNAUTHORIZED;
    case 'badrequest':
    case 'bad request':
    case 'bad_request':
      return APIResponseStatus.BAD_REQUEST;
    default:
      return null;
  }
}

/// Represents an API response.
class APIResponse<T> extends APIPayload {
  static final TypeInfo typeInfo = TypeInfo.from(APIResponse);

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

  bool _requiresAuthentication = false;

  /// If `true` this response should require `Authentication`.
  /// See [authenticationType] and [authenticationRealm].
  bool get requiresAuthentication => _requiresAuthentication;

  String? _authenticationType;

  /// The type of the required `Authentication`.
  String? get authenticationType => _authenticationType;

  String? _authenticationRealm;

  /// The real of the required `Authentication`.
  String? get authenticationRealm => _authenticationRealm;

  /// The response error.
  final dynamic error;

  /// Constructs an [APIResponse].
  ///
  /// - [payloadDynamic] is only used if [payload] is `null` and [T] accepts the [payloadDynamic] value.
  APIResponse(this.status,
      {this.headers = const <String, dynamic>{},
      T? payload,
      Object? payloadDynamic,
      this.payloadMimeType,
      this.payloadFileExtension,
      this.error,
      Map<String, Duration>? metrics})
      : payload = _resolvePayload(payload, payloadDynamic),
        _metrics = metrics;

  static T? _resolvePayload<T>(T? payload, Object? payloadDynamic) =>
      payload ??
      (payloadDynamic != null && TypeInfo.accepts<T>(payloadDynamic.runtimeType)
          ? payloadDynamic as T
          : null);

  /// Creates a response of status `OK`.
  factory APIResponse.ok(T? payload,
      {Object? payloadDynamic,
      Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.OK,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadDynamic: payloadDynamic,
        payloadMimeType: mimeType,
        metrics: metrics);
  }

  /// Transform this response to an `OK` response.
  APIResponse<T> asOk(
      {T? payload,
      Object? payloadDynamic,
      Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse.ok(
        payload ?? (payloadDynamic == null ? this.payload : null),
        payloadDynamic: payloadDynamic,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `NOT_FOUND`.
  factory APIResponse.notFound(
      {Map<String, dynamic>? headers,
      T? payload,
      Object? payloadDynamic,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.NOT_FOUND,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadDynamic: payloadDynamic,
        payloadMimeType: mimeType,
        metrics: metrics);
  }

  /// Transform this response to a `NOT_FOUND` response.
  APIResponse<T> asNotFound(
      {T? payload,
      Object? payloadDynamic,
      Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse.notFound(
        payload: payload ?? (payloadDynamic == null ? this.payload : null),
        payloadDynamic: payloadDynamic,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `UNAUTHORIZED`.
  factory APIResponse.unauthorized(
      {Map<String, dynamic>? headers,
      T? payload,
      Object? payloadDynamic,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.UNAUTHORIZED,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadDynamic: payloadDynamic,
        payloadMimeType: mimeType,
        metrics: metrics);
  }

  /// Transform this response to an `UNAUTHORIZED` response.
  APIResponse<T> asUnauthorized(
      {T? payload,
      Object? payloadDynamic,
      Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse.unauthorized(
        payload: payload ?? (payloadDynamic == null ? this.payload : null),
        payloadDynamic: payloadDynamic,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `BAD_REQUEST`.
  factory APIResponse.badRequest(
      {Map<String, dynamic>? headers,
      T? payload,
      Object? payloadDynamic,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.BAD_REQUEST,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadDynamic: payloadDynamic,
        payloadMimeType: mimeType,
        metrics: metrics);
  }

  /// Transform this response to an `BAD_REQUEST` response.
  APIResponse<T> asBadRequest(
      {T? payload,
      Object? payloadDynamic,
      Map<String, dynamic>? headers,
      String? mimeType,
      Map<String, Duration>? metrics}) {
    return APIResponse.badRequest(
        payload: payload ?? (payloadDynamic == null ? this.payload : null),
        payloadDynamic: payloadDynamic,
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
  APIResponse<T> asError(
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

  /// Defines that this response requires authentication.
  ///
  /// Depending of the serve implementation (usually HTTP),
  /// it will send to the client the request for authentication
  /// (in HTTP is the headers `WWW-Authenticate`).
  void requireAuthentication(
      {bool require = true, String type = 'Basic', String realm = 'API'}) {
    _requiresAuthentication = require;
    _authenticationType = type;
    _authenticationRealm = realm;
  }

  /// Returns `true` if [status] is a [APIResponseStatus.OK] or a [APIResponseStatus.NOT_FOUND].
  bool get isValid =>
      status == APIResponseStatus.OK || status == APIResponseStatus.NOT_FOUND;

  /// Alias to ![isValid].
  bool get isNotValid => !isValid;

  /// Returns `true` if [status] is a [APIResponseStatus.OK].
  bool get isOK => status == APIResponseStatus.OK;

  /// Alias to ![isNotOK].
  bool get isNotOK => !isOK;

  /// Returns `true` if [status] is a [APIResponseStatus.NOT_FOUND].
  bool get isNotFound => status == APIResponseStatus.NOT_FOUND;

  /// Returns `true` if [status] is a [APIResponseStatus.UNAUTHORIZED].
  bool get isUnauthorized => status == APIResponseStatus.UNAUTHORIZED;

  /// Returns `true` if [status] is a [APIResponseStatus.ERROR].
  bool get isError => status == APIResponseStatus.ERROR;

  /// Returns `true` if [status] is a [APIResponseStatus.BAD_REQUEST].
  bool get isBadRequest => status == APIResponseStatus.BAD_REQUEST;

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
        exposeHeaders?.join(', ') ?? APIResponse.exposeHeaders;
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

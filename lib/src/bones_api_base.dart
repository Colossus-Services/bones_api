import 'dart:collection';
import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:async_events/async_events.dart';
import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' show sha256, sha384, sha512;
import 'package:archive/archive.dart' show Adler32, Crc32;
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';
import 'package:swiss_knife/swiss_knife.dart' show MimeType;

import 'bones_api_authentication.dart';
import 'bones_api_config.dart';
import 'bones_api_entity.dart';
import 'bones_api_error_zone.dart';
import 'bones_api_initializable.dart';
import 'bones_api_mixin.dart';
import 'bones_api_module.dart';
import 'bones_api_security.dart';
import 'bones_api_utils.dart';
import 'bones_api_utils_arguments.dart';
import 'bones_api_utils_json.dart';

final _log = logging.Logger('APIRoot');

/// An [APIRoot] [APIRequest] handler.
///
/// See [APIRoot.preApiRequestHandlers] and [APIRoot.posApiRequestHandlers].
typedef APIRequestHandler = FutureOr<APIResponse<T>?> Function<T>(
    APIRoot apiRoot, APIRequest request);

/// An [APIRoot] logger function.
typedef APILogger = void Function(APIRoot apiRoot, String type, String? message,
    [Object? error, StackTrace? stackTrace]);

/// Bones API Library class.
class BonesAPI {
  // ignore: constant_identifier_names
  static const String VERSION = '1.3.35';

  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    AsyncEvent.boot();
    Json.boot();
  }
}

/// Root class of an API.
abstract class APIRoot with Initializable, Closable {
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

  /// Returns an [APIRoot] instance by [type].
  static A? getByType<A extends APIRoot>(
      {Type? type, bool lastAsDefault = false}) {
    type ??= A;

    var apiRoot =
        _instances.values.firstWhereOrNull((e) => e.runtimeType == type);
    if (apiRoot != null) return apiRoot as A;

    apiRoot = _instances.values.firstWhereOrNull((e) => e is A);
    if (apiRoot != null) return apiRoot as A;

    return lastAsDefault ? get(singleton: false) as A? : null;
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

  static int _instanceIdCount = 0;

  /// An instance ID to help with debug.
  final int _instanceId = ++_instanceIdCount;

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

  @override
  bool close() {
    if (!(super.close() as bool)) return false;

    tryCallMapped(() => onClose());

    _instances.remove(this);

    return true;
  }

  /// Called when this instance is closed.
  void onClose() {}

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
    var moduleName = request.pathPart(0);
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
  FutureOr<APIResponse<T>> call<T>(APIRequest request,
      {bool externalCall = false}) {
    if (request.method == APIRequestMethod.OPTIONS) {
      throw ArgumentError("Can't perform a call with an `OPTIONS` method. "
          "Requests with method `OPTIONS` are reserved for CORS or other informational requests.");
    }

    var modulesLoadAsync = _ensureModulesLoaded();

    if (modulesLoadAsync is Future<InitializationResult>) {
      return modulesLoadAsync.then((_) => _callZoned<T>(request, externalCall));
    } else {
      return _callZoned<T>(request, externalCall);
    }
  }

  /// Returns the current [APIRequest] of the current [call].
  final ZoneField<APIRequest> currentAPIRequest = ZoneField(Zone.current);

  FutureOr<APIResponse<T>> _callZoned<T>(
      APIRequest request, bool externalCall) {
    var callZone = currentAPIRequest.createContextZone();

    return callZone.run<FutureOr<APIResponse<T>>>(() {
      currentAPIRequest.set(request, contextZone: callZone);

      try {
        var response = _preCall<T>(request, externalCall);

        // Any throwed error won't be passed to the previous `Zone`.
        // Then the erros will be wrapped into a `APIResponse.error`,
        // to be rethrown by the previous `Zone`.

        if (response is Future<APIResponse<T>>) {
          return response.then((r) => r,
              onError: (e, s) => APIResponse.error(
                  error: e, stackTrace: s, headers: {'callZone': true}));
        } else {
          return response;
        }
      } catch (e, s) {
        return APIResponse.error(
            error: e, stackTrace: s, headers: {'callZone': true});
      }
    }).resolveMapped((response) {
      currentAPIRequest.remove(contextZone: callZone);

      if (response.isError && response.headers['callZone'] == true) {
        throw response.error;
      }

      return response;
    });
  }

  FutureOr<APIResponse<T>> _preCall<T>(APIRequest request, bool externalCall) {
    if (!externalCall) {
      request.credential = request.credential?.copy(withUsernameEntity: false);
    }

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

  static final MimeType _mimeTypeJson = MimeType.parse(MimeType.json)!;

  FutureOr<APIResponse<T>> _callImpl<T>(
      APIRequest apiRequest, APISecurity? apiSecurity) {
    var pathPartRoot = apiRequest.pathParts[0];

    if (pathPartRoot == 'API-INFO') {
      var info = apiInfo(apiRequest);
      return APIResponse.ok(info as T, mimeType: _mimeTypeJson);
    }

    var module = getModuleByRequest(apiRequest);

    if (module == null && apiSecurity != null) {
      if (apiRequest.pathPartAt(0) == authenticationRoute ||
          apiRequest.pathPartAt(1) == authenticationRoute) {
        return apiSecurity.doRequestAuthentication(apiRequest);
      }
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

    if (module == null) {
      if (apiRequest.pathPartAt(0) == authenticationRoute ||
          apiRequest.pathPartAt(1) == authenticationRoute) {
        return true;
      }

      return false;
    }

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
  String toString({bool withModulesNames = true}) {
    var modulesNames = '';
    if (withModulesNames) {
      modulesNames = _modules?.keys.toSet().toString() ?? '{loading...}';
    }

    return '$name[$version]$modulesNames#$_instanceId';
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

  /// Returns the optional selected [module] to generate info.
  /// - The selected module is defined by the [apiRequest] path at index `1`.
  String? get selectedModule {
    var moduleName = apiRequest?.pathPartAt(1);
    return moduleName != null && moduleName.isNotEmpty ? moduleName : null;
  }

  /// Returns the modules of the [apiRoot].
  List<APIModuleInfo> get modules {
    Iterable<APIModule> modules = apiRoot.modules;

    var selectedModule = this.selectedModule;
    if (selectedModule != null) {
      modules = modules.where((e) => e.name == selectedModule);
    }

    return modules.map((e) => e.apiInfo(apiRequest)).toList();
  }

  Map<String, dynamic> toJson() {
    var modules = this.modules;
    var selectedModule = this.selectedModule;

    return {
      'name': name,
      'version': version,
      if (selectedModule != null && modules.isNotEmpty)
        'selectedModule': selectedModule,
      if (modules.isNotEmpty)
        'modules': modules.map((e) => e.toJson()).toList(growable: false),
      if (selectedModule != null && modules.isEmpty)
        'error': "Can't find selected module: `$selectedModule`",
    };
  }
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
      _log.warning(
          "UNAUTHORIZED CALL> ${module.name}.$routeName( $parameters ) > rules: $rules");

      return APIResponse.unauthorized(
          payloadDynamic: 'UNAUTHORIZED: Rules issues $rules');
    }

    _log.info("CALL> ${module.name}.$routeName( $parameters )");

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
          .map((e) => MapEntry(e.key, e.value.toString(withT: false))));
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
  static MimeType? resolveMimeType(Object? mimeType) {
    if (mimeType == null) return null;
    if (mimeType is MimeType) return mimeType;
    return MimeType.parse(mimeType.toString());
  }

  /// The payload.
  dynamic get payload;

  /// The payload MIME Type.
  MimeType? get payloadMimeType;

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

  static int _idCount = 0;

  /// The request ID (to help debugging and loggign).
  final int id = ++_idCount;

  /// The request protocol.
  final String? protocol;

  /// The request method.
  final APIRequestMethod method;

  /// The request path.
  final String path;

  /// The parameters of the request.
  final Map<String, dynamic> parameters;

  /// The headers of the request.
  final Map<String, dynamic> headers;

  /// If `true` the client accepts `Keep-Alive` connections.
  final bool keepAlive;

  /// The [DateTime] of this request.
  final DateTime time;

  /// The [Duration] to parse this request (optional).
  final Duration? parsingDuration;

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

  MimeType? _payloadMimeType;

  /// The payload/body MIME Type.
  @override
  MimeType? get payloadMimeType => _payloadMimeType;

  set payloadMimeType(Object? value) {
    _payloadMimeType = APIPayload.resolveMimeType(value);
  }

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
      {this.protocol,
      Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      this.payload,
      Object? payloadMimeType,
      this.payloadFileExtension,
      this.sessionID,
      this.newSession = false,
      this.credential,
      String? scheme,
      APIRequesterSource? requesterSource,
      String? requesterAddress,
      this.keepAlive = false,
      DateTime? time,
      this.parsingDuration,
      Uri? requestedUri,
      this.originalRequest})
      : parameters = parameters ?? <String, dynamic>{},
        _payloadMimeType = APIPayload.resolveMimeType(payloadMimeType),
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
      Object? payloadMimeType,
      APICredential? credential}) {
    return APIRequest(APIRequestMethod.POST, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadMimeType: payloadMimeType,
        credential: credential);
  }

  /// Creates a request of `PUT` method.
  factory APIRequest.put(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload,
      Object? payloadMimeType,
      APICredential? credential}) {
    return APIRequest(APIRequestMethod.PUT, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadMimeType: payloadMimeType,
        credential: credential);
  }

  /// Creates a request of `DELETE` method.
  factory APIRequest.delete(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload,
      Object? payloadMimeType,
      APICredential? credential}) {
    return APIRequest(APIRequestMethod.DELETE, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadMimeType: payloadMimeType,
        credential: credential);
  }

  /// Creates a request of `PATCH` method.
  factory APIRequest.patch(String path,
      {Map<String, dynamic>? parameters,
      Map<String, dynamic>? headers,
      dynamic payload,
      Object? payloadMimeType,
      APICredential? credential}) {
    return APIRequest(APIRequestMethod.PATCH, path,
        parameters: parameters ?? <String, dynamic>{},
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadMimeType: payloadMimeType,
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

  /// Returns the [path] part at [index] in [pathParts].
  /// - Negative [index] will return in reversed index order.
  String? pathPartAt(int index) {
    var idx = index >= 0 ? index : _pathParts.length - index;
    return idx >= 0 && idx < _pathParts.length ? _pathParts[idx] : null;
  }

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

    return 'APIRequest#$id{ method: ${method.name}, '
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
  NOT_MODIFIED,
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
      case 304:
        return APIResponseStatus.NOT_MODIFIED;
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
    case 'notmodified':
    case 'not modified':
    case 'not_modified':
      return APIResponseStatus.NOT_MODIFIED;
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

/// A `Etag` of a file/payload identification.
/// See [WeakEtag] and [StrongEtag].
abstract class Etag {
  factory Etag.parse(String s) {
    if (s.isEmpty) return WeakEtag([]);

    s = s.trim();

    if (s.startsWith('W/')) {
      return WeakEtag.parse(s);
    } else {
      return StrongEtag.parse(s);
    }
  }

  Etag();

  String get tag;

  bool get isEmpty;

  bool equals(Object? other);

  @override
  String toString();
}

/// A strong [Etag], that fully identifies the file/payload bytes.
/// - Strong [Etag] requests can be cached (including range requests).
/// - See [WeakEtag].
class StrongEtag extends Etag {
  @override
  final String tag;

  @override
  bool get isEmpty => tag.isEmpty;

  StrongEtag(this.tag);

  factory StrongEtag.parse(String s) {
    if (s.isEmpty) return StrongEtag('');

    s = s.trim();

    if (s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }

    if (s.isEmpty) return StrongEtag('');

    return StrongEtag(s);
  }

  factory StrongEtag.sha256(List<int> bytes) {
    if (bytes.isEmpty) return StrongEtag('');
    return StrongEtag(sha256.convert(bytes).toString());
  }

  factory StrongEtag.sha384(List<int> bytes) {
    if (bytes.isEmpty) return StrongEtag('');
    return StrongEtag(sha384.convert(bytes).toString());
  }

  factory StrongEtag.sha512(List<int> bytes) {
    if (bytes.isEmpty) return StrongEtag('');
    return StrongEtag(sha512.convert(bytes).toString());
  }

  @override
  bool equals(Object? other) {
    if (identical(this, other)) return true;

    if (other is StrongEtag) {
      return tag == other.tag;
    } else if (other is String) {
      return tag == StrongEtag.parse(other).tag;
    } else {
      return false;
    }
  }

  @override
  bool operator ==(Object other) => equals(other);

  @override
  int get hashCode => tag.hashCode;

  String? _str;

  @override
  String toString() => _str ??= '"$tag"';
}

/// A weak [Etag], that identifies the file/payload allowing tag collisions,
/// but easy to generate.
/// - Weak [Etag] requests can be cached, but prevents range requests caching.
/// - See [StrongEtag].
class WeakEtag extends Etag {
  final List<String> values;
  final String delimiter;

  WeakEtag(List<String> values, {this.delimiter = ','})
      : values = values.asUnmodifiableView;

  factory WeakEtag.parse(String s, {String delimiter = ','}) {
    if (s.isEmpty) return WeakEtag([]);

    s = s.trim();

    if (s.startsWith('W/')) {
      s = s.substring(2);
    }

    if (s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }

    if (s.isEmpty) return WeakEtag([]);

    var values = s.split(delimiter);

    return WeakEtag(values, delimiter: delimiter);
  }

  factory WeakEtag.adler32(List<int> bytes) {
    if (bytes.isEmpty) return WeakEtag([]);

    return WeakEtag(<String>[
      bytes.length.toString(),
      Adler32().convert(bytes).toString(),
      _computeFragments(bytes),
    ]);
  }

  factory WeakEtag.crc32(List<int> bytes) {
    if (bytes.isEmpty) return WeakEtag([]);

    return WeakEtag(<String>[
      bytes.length.toString(),
      Crc32().convert(bytes).toString(),
      _computeFragments(bytes),
    ]);
  }

  static String _computeFragments(List<int> bytes) {
    var length = bytes.length;

    switch (length) {
      case 0:
        {
          return '0';
        }
      case 1:
        {
          return bytes[0].toHex8();
        }
      case 2:
        {
          return bytes[0].toHex8() + bytes[1].toHex8();
        }
      case 3:
        {
          return bytes[0].toHex8() + bytes[1].toHex8() + bytes[2].toHex8();
        }
      default:
        {
          var center = length ~/ 2;
          return bytes[0].toHex8() +
              bytes[center - 1].toHex8() +
              bytes[center].toHex8() +
              bytes.last.toHex8();
        }
    }
  }

  @override
  bool get isEmpty => values.isEmpty;

  String? _tag;

  @override
  String get tag => _tag ??= values.join(delimiter);

  static final ListEquality<String> _valuesEquality = ListEquality<String>();

  @override
  bool equals(Object? other) {
    if (identical(this, other)) return true;

    if (other is WeakEtag) {
      return _valuesEquality.equals(values, other.values);
    } else if (other is String) {
      return _valuesEquality.equals(values, WeakEtag.parse(other).values);
    } else {
      return false;
    }
  }

  @override
  bool operator ==(Object other) => equals(other);

  @override
  int get hashCode => tag.hashCode;

  String? _str;

  @override
  String toString() => _str ??= 'W/"$tag"';
}

/// A [CacheControl] directive.
///
/// See:
/// - [CacheControl]
/// - [HTTP Header - Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control)
enum CacheControlDirective {
  private,
  public,
  noCache,
  noStore,
  noTransform,
  mustRevalidate,
  staleWhileRevalidate,
  staleIfError,
}

/// A cache control response.
///
/// See:
/// - [CacheControlDirective]
/// - [HTTP Header - Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control)
///
class CacheControl {
  static const CacheControl defaultCacheControl = CacheControl();

  final List<CacheControlDirective> directives;

  final Duration maxAge;
  final Duration staleAge;
  final Duration staleIfErrorAge;

  const CacheControl({
    this.directives = const <CacheControlDirective>[
      CacheControlDirective.private,
      CacheControlDirective.noTransform,
      CacheControlDirective.mustRevalidate,
      CacheControlDirective.staleWhileRevalidate,
      CacheControlDirective.staleIfError,
    ],
    this.maxAge = const Duration(seconds: 10),
    this.staleAge = const Duration(minutes: 5),
    this.staleIfErrorAge = const Duration(minutes: 10),
  });

  bool hasDirective(CacheControlDirective directive) =>
      directives.contains(directive);

  static final ListEquality<Enum> _listEqualityEnum = ListEquality<Enum>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheControl &&
          runtimeType == other.runtimeType &&
          _listEqualityEnum.equals(directives, other.directives) &&
          maxAge == other.maxAge;

  @override
  int get hashCode => _listEqualityEnum.hash(directives) ^ maxAge.hashCode;

  @override
  String toString() {
    List<String> values;

    if (hasDirective(CacheControlDirective.noCache)) {
      values = <String>[
        'no-cache',
        if (hasDirective(CacheControlDirective.noStore)) 'no-store',
        if (hasDirective(CacheControlDirective.noTransform)) 'no-transform',
        'max-age=0',
      ];
    } else {
      values = <String>[];

      if (hasDirective(CacheControlDirective.private)) {
        values.add('private');
      } else if (hasDirective(CacheControlDirective.public)) {
        values.add('public');
      }

      if (hasDirective(CacheControlDirective.noStore)) {
        values.add('no-store');
      }

      if (hasDirective(CacheControlDirective.noTransform)) {
        values.add('no-transform');
      }

      if (hasDirective(CacheControlDirective.mustRevalidate)) {
        values.add('must-revalidate');
      }

      var maxAgeSecs = maxAge.inSeconds;
      values.add('max-age=$maxAgeSecs');

      var staleAgeSecs = staleAge.inSeconds;
      if (staleAgeSecs < maxAgeSecs) {
        staleAgeSecs = maxAgeSecs;
      }

      var staleIfErrorAgeSecs = staleIfErrorAge.inSeconds;
      if (staleIfErrorAgeSecs < maxAgeSecs) {
        staleIfErrorAgeSecs = maxAgeSecs;
      }

      if (hasDirective(CacheControlDirective.staleWhileRevalidate)) {
        values.add('stale-while-revalidate=$staleAgeSecs');
      }

      if (hasDirective(CacheControlDirective.staleIfError)) {
        values.add('stale-if-error=$staleIfErrorAgeSecs');
      }
    }

    return values.join(', ');
  }
}

extension _IntExtension on int {
  String toHex8() => toRadixString(16).padLeft(2, '0');
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

  MimeType? _payloadMimeType;

  /// The payload/body MIME Type.
  @override
  MimeType? get payloadMimeType => _payloadMimeType;

  set payloadMimeType(Object? value) {
    _payloadMimeType = APIPayload.resolveMimeType(value);
  }

  /// The payload usual file name extension.
  @override
  String? payloadFileExtension;

  bool _requiresAuthentication = false;

  /// The [Etag] of the [payload].
  Etag? payloadETag;

  /// The response [CacheControl].
  CacheControl? cacheControl;

  /// The `Keep-Alive` timeout. Default: `10s`
  Duration keepAliveTimeout;

  /// The `Keep-Alive` maximum number of requests. Default: `1000`
  int keepAliveMaxRequests;

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

  final StackTrace? stackTrace;

  /// Constructs an [APIResponse].
  ///
  /// - [payloadDynamic] is only used if [payload] is `null` and [T] accepts the [payloadDynamic] value.
  APIResponse(this.status,
      {Map<String, dynamic>? headers,
      T? payload,
      Object? payloadDynamic,
      Object? payloadMimeType,
      this.payloadETag,
      this.cacheControl,
      this.payloadFileExtension,
      Duration? keepAliveTimeout,
      int? keepAliveMaxRequests,
      this.error,
      this.stackTrace,
      Map<String, Duration>? metrics})
      : headers = headers ?? <String, dynamic>{},
        payload = _resolvePayload(payload, payloadDynamic),
        _payloadMimeType = APIPayload.resolveMimeType(payloadMimeType),
        keepAliveTimeout = keepAliveTimeout ?? const Duration(seconds: 10),
        keepAliveMaxRequests = keepAliveMaxRequests ?? 1000,
        _metrics = metrics;

  static T? _resolvePayload<T>(T? payload, Object? payloadDynamic) =>
      payload ??
      (payloadDynamic != null && TypeInfo.accepts<T>(payloadDynamic.runtimeType)
          ? payloadDynamic as T
          : null);

  /// Copy this response casting the [payload] to [E].
  APIResponse<E> cast<E>({E? payload}) {
    return APIResponse<E>(status,
        payload: payload ?? (this.payload as E?),
        payloadMimeType: payloadMimeType,
        payloadFileExtension: payloadFileExtension,
        payloadETag: payloadETag,
        cacheControl: cacheControl,
        headers: headers,
        keepAliveTimeout: keepAliveTimeout,
        keepAliveMaxRequests: keepAliveMaxRequests,
        error: error,
        stackTrace: stackTrace,
        metrics: _metrics)
      .._copyStartedMetrics(this);
  }

  /// Copy this response.
  APIResponse<T> copy(
      {APIResponseStatus? status,
      T? payload,
      Object? payloadDynamic,
      bool nullPayload = false,
      Etag? payloadETag,
      String? payloadFileExtension,
      CacheControl? cacheControl,
      Map<String, dynamic>? headers,
      Object? mimeType,
      Duration? keepAliveTimeout,
      int? keepAliveMaxRequests,
      Object? error,
      StackTrace? stackTrace,
      Map<String, Duration>? metrics}) {
    return APIResponse(status ?? this.status,
        payload: nullPayload
            ? null
            : (payload ?? (payloadDynamic == null ? this.payload : null)),
        payloadDynamic: nullPayload ? null : payloadDynamic,
        payloadMimeType: mimeType ?? payloadMimeType,
        payloadFileExtension: payloadFileExtension,
        payloadETag: payloadETag ?? this.payloadETag,
        cacheControl: cacheControl ?? this.cacheControl,
        headers: headers ?? this.headers,
        keepAliveTimeout: keepAliveTimeout ?? this.keepAliveTimeout,
        keepAliveMaxRequests: keepAliveMaxRequests ?? this.keepAliveMaxRequests,
        error: error,
        stackTrace: stackTrace,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `OK`.
  factory APIResponse.ok(T? payload,
      {Object? payloadDynamic,
      Etag? payloadETag,
      CacheControl? cacheControl,
      Map<String, dynamic>? headers,
      Object? mimeType,
      String? fileExtension,
      Duration? keepAliveTimeout,
      int? keepAliveMaxRequests,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.OK,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadDynamic: payloadDynamic,
        payloadMimeType: mimeType,
        payloadFileExtension: fileExtension,
        payloadETag: payloadETag,
        cacheControl: cacheControl,
        keepAliveTimeout: keepAliveTimeout,
        keepAliveMaxRequests: keepAliveMaxRequests,
        metrics: metrics);
  }

  /// Transform this response to an `OK` response.
  APIResponse<T> asOk(
      {T? payload,
      Object? payloadDynamic,
      Map<String, dynamic>? headers,
      Object? mimeType,
      String? fileExtension,
      Etag? eTag,
      CacheControl? cacheControl,
      Duration? keepAliveTimeout,
      int? keepAliveMaxRequests,
      Map<String, Duration>? metrics}) {
    return APIResponse.ok(
        payload ?? (payloadDynamic == null ? this.payload : null),
        payloadDynamic: payloadDynamic,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        fileExtension: fileExtension ?? payloadFileExtension,
        payloadETag: eTag ?? payloadETag,
        cacheControl: cacheControl ?? this.cacheControl,
        keepAliveTimeout: keepAliveTimeout ?? this.keepAliveTimeout,
        keepAliveMaxRequests: keepAliveMaxRequests ?? this.keepAliveMaxRequests,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `NOT_FOUND`.
  factory APIResponse.notFound(
      {Map<String, dynamic>? headers,
      T? payload,
      Object? payloadDynamic,
      Object? mimeType,
      Duration? keepAliveTimeout,
      int? keepAliveMaxRequests,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.NOT_FOUND,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadDynamic: payloadDynamic,
        payloadMimeType: mimeType,
        keepAliveTimeout: keepAliveTimeout,
        keepAliveMaxRequests: keepAliveMaxRequests,
        metrics: metrics);
  }

  /// Transform this response to a `NOT_FOUND` response.
  APIResponse<T> asNotFound(
      {T? payload,
      Object? payloadDynamic,
      Map<String, dynamic>? headers,
      Object? mimeType,
      Duration? keepAliveTimeout,
      int? keepAliveMaxRequests,
      Map<String, Duration>? metrics}) {
    return APIResponse.notFound(
        payload: payload ?? (payloadDynamic == null ? this.payload : null),
        payloadDynamic: payloadDynamic,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        keepAliveTimeout: keepAliveTimeout ?? this.keepAliveTimeout,
        keepAliveMaxRequests: keepAliveMaxRequests ?? this.keepAliveMaxRequests,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `NOT_FOUND`.
  factory APIResponse.notModified(
      {Map<String, dynamic>? headers,
      T? payload,
      Object? payloadDynamic,
      Object? mimeType,
      Etag? eTag,
      CacheControl? cacheControl,
      Duration? keepAliveTimeout,
      int? keepAliveMaxRequests,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.NOT_MODIFIED,
        headers: headers ?? <String, dynamic>{},
        payload: payload,
        payloadDynamic: payloadDynamic,
        payloadMimeType: mimeType,
        payloadETag: eTag,
        cacheControl: cacheControl,
        keepAliveTimeout: keepAliveTimeout,
        keepAliveMaxRequests: keepAliveMaxRequests,
        metrics: metrics);
  }

  /// Transform this response to a `NOT_MODIFIED` response.
  APIResponse<T> asNotModified(
      {T? payload,
      Object? payloadDynamic,
      Map<String, dynamic>? headers,
      Object? mimeType,
      Etag? eTag,
      CacheControl? cacheControl,
      Duration? keepAliveTimeout,
      int? keepAliveMaxRequests,
      Map<String, Duration>? metrics}) {
    return APIResponse.notModified(
        payload: payload ?? (payloadDynamic == null ? this.payload : null),
        payloadDynamic: payloadDynamic,
        headers: headers ?? this.headers,
        mimeType: mimeType ?? payloadMimeType,
        eTag: eTag ?? payloadETag,
        cacheControl: cacheControl ?? this.cacheControl,
        keepAliveTimeout: keepAliveTimeout ?? this.keepAliveTimeout,
        keepAliveMaxRequests: keepAliveMaxRequests ?? this.keepAliveMaxRequests,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response of status `UNAUTHORIZED`.
  factory APIResponse.unauthorized(
      {Map<String, dynamic>? headers,
      T? payload,
      Object? payloadDynamic,
      Object? mimeType,
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
      Object? mimeType,
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
      Object? mimeType,
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
      Object? mimeType,
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
      StackTrace? stackTrace,
      Map<String, Duration>? metrics}) {
    return APIResponse(APIResponseStatus.ERROR,
        headers: headers ?? <String, dynamic>{},
        error: error,
        stackTrace: stackTrace,
        metrics: metrics);
  }

  /// Transform this response to an `ERROR` response.
  APIResponse<T> asError(
      {Map<String, dynamic>? headers,
      dynamic error,
      StackTrace? stackTrace,
      Map<String, Duration>? metrics}) {
    return APIResponse.error(
        headers: headers ?? this.headers,
        error: error ?? this.error,
        stackTrace: stackTrace ?? this.stackTrace,
        metrics: metrics ?? _metrics)
      .._copyStartedMetrics(this);
  }

  /// Creates a response based into [o] value.
  factory APIResponse.from(dynamic o) {
    if (o == null) {
      return APIResponse.notFound();
    } else if (o is APIResponse) {
      if (o is APIResponse<T>) {
        return o;
      } else {
        return o.cast<T>();
      }
    } else if (o is Error) {
      return APIResponse.error(error: o, stackTrace: o.stackTrace);
    } else if (o is Exception) {
      return APIResponse.error(error: o);
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

  /// Returns `true` if [status] is a [APIResponseStatus.NOT_MODIFIED].
  bool get isNotModified => status == APIResponseStatus.NOT_MODIFIED;

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

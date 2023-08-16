import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as pack_path;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_gzip/shelf_gzip.dart';
import 'package:shelf_letsencrypt/shelf_letsencrypt.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:statistics/statistics.dart' hide IterableIntExtension;
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_api_authentication.dart';
import 'bones_api_base.dart';
import 'bones_api_config.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_entity_rules.dart';
import 'bones_api_extension.dart';
import 'bones_api_hotreload.dart';
import 'bones_api_logging.dart';
import 'bones_api_session.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';
import 'bones_api_utils_httpclient.dart';
import 'bones_api_utils_json.dart';

final _log = logging.Logger('APIServer');

/// An API HTTP Server
class APIServer {
  /// The API root of this server.
  final APIRoot apiRoot;

  /// The bind address of this server.
  final String address;

  /// The listen port of this server (HTTP).
  final int port;

  /// The listen secure port of this server (HTTPS).
  final int securePort;

  /// If `true` enabled Let's Encrypt.
  ///
  /// - See [LetsEncrypt].
  final bool letsEncrypt;

  /// The Let's Encrypt certificates [Directory].
  ///
  /// - See [LetsEncrypt].
  final Directory? letsEncryptDirectory;

  /// If `true` runs Let's Encrypt in production mode.
  final bool letsEncryptProduction;

  /// If `true` allows the request of Let's Encrypt certificates.
  final bool allowRequestLetsEncryptCertificate;

  /// The name of this server.
  ///
  /// This is used for the `server` header.
  final String name;

  /// The version of this server.
  ///
  /// This is used for the `server` header.
  final String version;

  /// If `true` enables Hot Reload ([APIHotReload.enable]).
  final bool hotReload;

  /// The domains root directories.
  final Map<Pattern, Directory> domainsRoots;

  /// Returns a list of domains at [domainsRoots] keys (non [RegExp] entries).
  List<String> get domains => domainsRoots.keys.whereType<String>().toList();

  /// If `true` the server will use/generate a `SESSIONID` for each request.
  /// If `false` will ignore any `SESSIONID` cookie (useful to comply with cookieless servers).
  /// - If [cookieless] is `true` `SESSIONID` is disabled.
  final bool useSessionID;

  /// If `true` will remove any `Set-Cookie` or `Cookie` header.
  ///
  /// See [useSessionID].
  final bool cookieless;

  /// The `cache-control` header for API responses.
  final String apiCacheControl;

  /// The default value for [apiCacheControl].
  static const String defaultApiCacheControl =
      'private, no-transform, must-revalidate, max-age=0, no-store, no-cache';

  /// The `cache-control` header for static files.
  final String staticFilesCacheControl;

  /// The default value for [staticFilesCacheControl].
  static const String defaultStaticFilesCacheControl =
      'private, no-transform, must-revalidate, max-age=60, stale-while-revalidate=600, stale-if-error=300';

  /// If `true` log messages to [stdout] (console).
  late final bool logToConsole;

  APIServer(
    this.apiRoot,
    String address,
    this.port, {
    int? securePort,
    this.letsEncrypt = false,
    this.letsEncryptProduction = false,
    this.allowRequestLetsEncryptCertificate = true,
    Object? letsEncryptDirectory,
    this.name = 'Bones_API',
    this.version = BonesAPI.VERSION,
    this.hotReload = false,
    Object? domains,
    bool useSessionID = true,
    this.cookieless = false,
    String? apiCacheControl,
    String? staticFilesCacheControl,
    bool? logToConsole,
  })  : useSessionID = useSessionID && !cookieless,
        apiCacheControl =
            _normalizeHeaderValue(apiCacheControl, defaultApiCacheControl),
        staticFilesCacheControl = _normalizeHeaderValue(
            staticFilesCacheControl, defaultStaticFilesCacheControl),
        securePort = letsEncrypt
            ? (securePort != null && securePort > 10 ? securePort : 443)
            : (securePort ?? -1),
        letsEncryptDirectory = resolveLetsEncryptDirectory(
            directory: letsEncryptDirectory, letsEncrypt: letsEncrypt),
        address = _normalizeAddress(address),
        domainsRoots = parseDomains(domains) ?? <Pattern, Directory>{} {
    var isLoggingAll = LoggerHandler.getLogAllTo() != null;

    // If `logToConsole` not defined and NOT logging all set `logToConsole = true`:
    this.logToConsole = logToConsole ?? !isLoggingAll;

    _configureAPIRoot(apiRoot);
  }

  static String _normalizeHeaderValue(String? header, String def) {
    if (header == null) return def;
    header = header.trim();
    return header.isNotEmpty ? header : def;
  }

  static Directory? resolveLetsEncryptDirectory(
      {Object? directory, bool letsEncrypt = false}) {
    if (directory != null) {
      Directory? dir;
      if (directory is Directory) {
        dir = directory;
      } else if (directory is String) {
        directory = directory.trim();
        if (directory.isNotEmpty) {
          dir = Directory(directory);
        }
      }

      if (dir != null) {
        if (letsEncrypt && !dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir.existsSync() ? dir.absolute : dir;
      }
    }

    var paths = ['/etc/letsencrypt/live', '/etc/letsencrypt'];

    var userDir = _getUserDirectory();
    if (userDir != null) {
      paths.add(pack_path.join(userDir.path, '.letsencrypt'));
      paths.add(pack_path.join(userDir.path, '.lets-encrypt'));
      paths.add(pack_path.join(userDir.path, 'letsencrypt'));
      paths.add(pack_path.join(userDir.path, 'lets-encrypt'));
    }

    for (var p in paths) {
      var dir = Directory(p);
      if (dir.existsSync() && dir.statSync().canWrite) {
        return dir.absolute;
      }
    }

    if (letsEncrypt && userDir != null) {
      var dir = Directory(pack_path.join(userDir.path, '.letsencrypt'));
      dir.createSync();
      return dir;
    }

    return null;
  }

  static Directory? _getUserDirectory() {
    var envVars = Platform.environment;

    String? home;
    if (Platform.isMacOS) {
      home = envVars['HOME'];
    } else if (Platform.isLinux) {
      home = envVars['HOME'];
    } else if (Platform.isWindows) {
      home = envVars['UserProfile'];
    }

    if (home != null) {
      var dir = Directory(home);
      if (dir.existsSync()) {
        return dir.absolute;
      }
    }

    var dir = Directory('~/');
    if (dir.existsSync()) {
      return dir.absolute;
    }

    return null;
  }

  /// Parses a set of domains to serve static files.
  ///
  /// - See: [APIServer.domainsRoots], [parseDomainPattern], [parseDomainDirectory].
  static Map<Pattern, Directory>? parseDomains(Object? o) {
    if (o == null) return null;

    if (o is Map) {
      var map = o.map((key, value) =>
          MapEntry(parseDomainPattern(key), parseDomainDirectory(value)));
      _removeInvalidDomains(map);
      return map.isNotEmpty ? map : null;
    }

    List values;

    if (o is List) {
      values = o;
    } else if (o is String) {
      values = o.split('&');
    } else {
      values = [o];
    }

    var entries = values.map(parseDomainEntry).whereNotNull().toList();
    if (entries.isEmpty) return null;

    var map = Map<Pattern, Directory>.fromEntries(entries);
    _removeInvalidDomains(map);

    return map.isNotEmpty ? map : null;
  }

  static void _removeInvalidDomains(Map<Pattern, Directory> domains) {
    domains.removeWhere((key, value) => (key is String && key.isEmpty));
  }

  /// Parses a domain entry as [MapEntry].
  ///
  /// - See [APIServer.domainsRoots].
  static MapEntry<Pattern, Directory>? parseDomainEntry(Object? o) {
    if (o == null) return null;
    if (o is MapEntry) {
      return MapEntry(parseDomainPattern(o.key), parseDomainDirectory(o.value));
    }

    var s = o.toString();

    var parts = s.split('=');
    var domain = parts[0].trim();
    var path = parts.length > 1 ? parts[1].trim() : '';

    return MapEntry(parseDomainPattern(domain), parseDomainDirectory(path));
  }

  /// Parses a domain pattern.
  ///
  /// - If is in the format `r/.../` it will be parsed as a [RegExp]. Example: `r/(www\.)?mydomain.com/`
  /// - See [APIServer.domainsRoots].
  static Pattern parseDomainPattern(Pattern domainPatter) {
    if (domainPatter is RegExp) return domainPatter;

    var s = domainPatter.toString().trim();

    if (s.startsWith('r/') && s.endsWith('/')) {
      var re = s.substring(2, s.length - 1);
      return RegExp(re);
    }

    if (s == '*' || s == '.') {
      return RegExp(r'.*');
    }

    return s;
  }

  /// Parses a domain [Directory].
  ///
  /// - See [APIServer.domainsRoots].
  static Directory parseDomainDirectory(Object dir) {
    if (dir is Directory) return dir;
    var p = dir.toString();
    return Directory(p);
  }

  static String _normalizeAddress(String address) {
    address = address.trim();

    if (address.isEmpty ||
        address == '*' ||
        address == '0' ||
        address == '::' ||
        address == '0:0:0:0:0:0:0:0') {
      return '0.0.0.0';
    }

    if (address == 'local' ||
        address == '1' ||
        address == '127' ||
        address == '::1' ||
        address == '0:0:0:0:0:0:0:1') {
      return 'localhost';
    }

    return address;
  }

  void _configureAPIRoot(APIRoot apiRoot) {
    apiRoot.posApiRequestHandlers.add(_handleStaticFiles);
  }

  FutureOr<APIResponse<T>?> _handleStaticFiles<T>(
      APIRoot apiRoot, APIRequest apiRequest) {
    if (domainsRoots.isEmpty) return null;

    for (var e in domainsRoots.entries) {
      if (apiRequest.matchesHostname(e.key)) {
        return _serveFile<T>(apiRequest, e.value);
      }
    }

    return null;
  }

  FutureOr<APIResponse<T>> _serveFile<T>(
      APIRequest apiRequest, Directory rootDirectory) {
    var staticHandler = _getDirectoryStaticHandler(rootDirectory);

    return staticHandler(apiRequest.toRequest())
        .resolveMapped((response) => _APIResponseStaticFile<T>(response));
  }

  final Map<String, Handler> _directoriesStaticHandlers = <String, Handler>{};

  Handler _getDirectoryStaticHandler(Directory rootDirectory) =>
      _directoriesStaticHandlers.putIfAbsent(
          rootDirectory.path, () => _createDirectoryHandler(rootDirectory));

  Handler _createDirectoryHandler(Directory rootDirectory) {
    rootDirectory = rootDirectory.absolute;

    var pipeline = const Pipeline()
        .addMiddleware(gzipMiddleware)
        .addMiddleware(_staticFilesHeadersMiddleware);

    var handler = pipeline.addHandler(
        createStaticHandler(rootDirectory.path, defaultDocument: 'index.html'));
    return handler;
  }

  Handler _staticFilesHeadersMiddleware(Handler innerHandler) => (request) {
        return Future.sync(() => innerHandler(request)).then(
            (response) => _configureStaticFilesHeaders(request, response));
      };

  Response _configureStaticFilesHeaders(Request request, Response response,
      {Map<String, String>? headers}) {
    headers ??= <String, String>{};

    var statusCode = response.statusCode;
    if (statusCode < 200 || statusCode > 299) {
      return response.change(headers: headers);
    }

    headers[HttpHeaders.cacheControlHeader] = staticFilesCacheControl;

    headers[HttpHeaders.serverHeader] ??= serverName;

    return response.change(headers: headers);
  }

  /// The `server` header value.
  String get serverName => '$name/$version';

  String get urlHost {
    switch (address) {
      case '0.0.0.0':
      case '127.0.0.1':
        return 'localhost';
      default:
        return address;
    }
  }

  /// The local URL of this server.
  String get url {
    return 'http://$urlHost:$port/';
  }

  /// The local `API-INFO` URL of this server.
  String get apiInfoURL {
    return 'http://$urlHost:$port/API-INFO';
  }

  /// Returns `true` if the basic conditions for Let's Encrypt are configured.
  ///
  /// - See: [letsEncrypt], [letsEncryptDirectory], [domainsRoots].
  bool get canUseLetsEncrypt {
    return letsEncrypt && letsEncryptDirectory != null && domains.isNotEmpty;
  }

  bool _started = false;

  /// Returns `true` if this servers is started.
  bool get isStarted => _started;

  late HttpServer _httpServer;

  HttpServer? _httpSecureServer;

  /// Starts this server.
  Future<bool> start() async {
    if (_started) return true;
    _started = true;

    if (logToConsole) {
      _log.handler.logToConsole();

      _log.info("Activated `logToConsole` from `APIServer`.");
    }

    {
      var isLoggingAll = LoggerHandler.getLogAllTo() != null;
      var isLoggingToConsole = LoggerHandler.getLogToConsole();
      var isLoggingError = LoggerHandler.root.getLogErrorTo() != null;
      var isLoggingDB = LoggerHandler.root.getLogDbTo() != null;

      _log.info(
          "LOGGING> toConsole: $isLoggingToConsole ; all: $isLoggingAll ; error: $isLoggingError ; db: $isLoggingDB");
    }

    if (canUseLetsEncrypt) {
      await _startLetsEncrypt();
    } else {
      await _startNormal();
    }

    if (hotReload) {
      await APIHotReload.get().enable();
    }

    if (cookieless) {
      _log.info('Cookieless Server: all cookies disabled! (NO `SESSIONID`)');
    } else if (useSessionID) {
      _log.info('Using `SESSIONID` cookies.');
    }

    _log.info('Started HTTP Server at: $address:$port');

    _log.info('Initializing APIRoot `${apiRoot.name}`...');

    return apiRoot.ensureInitialized().then((result) {
      var modules = apiRoot.modules;
      _log.info('Loaded modules: ${modules.map((e) => e.name).toList()}');

      if (!result.ok) {
        _log.severe('Error loading APIRoot: ${apiRoot.name}');
      }

      return result.ok;
    });
  }

  Future<void> _startNormal() async {
    _httpServer = await shelf_io.serve(_process, address, port);
    _httpServer.autoCompress = true;

    _configureServer(_httpServer);
  }

  void _configureServer(HttpServer server) {
    // Enable built-in [HttpServer] gzip:
    server.autoCompress = true;
  }

  Future<void> _startLetsEncrypt() async {
    var letsEncryptDirectory = this.letsEncryptDirectory;

    if (letsEncryptDirectory == null) {
      throw StateError("Let's Encrypt directory not set!");
    } else if (!letsEncryptDirectory.existsSync()) {
      throw StateError(
          "Let's Encrypt directory doesn't exists: $letsEncryptDirectory");
    }

    _log.info("Let's Encrypt directory: ${letsEncryptDirectory.path}");

    final certificatesHandler = CertificatesHandlerIO(letsEncryptDirectory);

    final LetsEncrypt letsEncrypt =
        LetsEncrypt(certificatesHandler, production: letsEncryptProduction);

    var pipeline = const Pipeline().addMiddleware(_redirectToHttpsMiddleware);

    var handler = pipeline.addHandler(_process);

    final domains = this.domains;

    var domain = domains.first;
    var domainEmail = 'contact@$domain';

    _log.info("Let's Encrypt domain: $domain");

    if (!allowRequestLetsEncryptCertificate) {
      _log.warning("NOT allowed to request Let's Encrypt certificates!");
    }

    var servers = await letsEncrypt.startSecureServer(
      handler,
      {domain: domainEmail},
      port: port,
      securePort: securePort,
      bindingAddress: address,
      requestCertificate: allowRequestLetsEncryptCertificate,
    );

    var server = servers[0]; // HTTP Server.
    var secureServer = servers[1]; // HTTPS Server.

    _httpServer = server;
    _httpSecureServer = secureServer;

    _configureServer(server);
    _configureServer(secureServer);
  }

  Handler _redirectToHttpsMiddleware(Handler innerHandler) {
    return (request) {
      var requestedUri = request.requestedUri;

      if (requestedUri.scheme == 'http' &&
          !requestedUri.path.contains('/.well-known/acme-challenge/')) {
        final domains = this.domains;
        if (domains.contains(requestedUri.host)) {
          var secureUri = requestedUri.replace(scheme: 'https');
          return Response.seeOther(secureUri);
        }
      }

      return innerHandler(request);
    };
  }

  /// Returns `true` if this server is closed.type
  ///
  /// A closed server can't processe new requests.
  bool get isStopped => _stopped.isCompleted;

  final Completer<bool> _stopped = Completer<bool>();

  /// Returns a [Future] that completes when this server stops.
  Future<bool> waitStopped() => _stopped.future;

  bool _stopping = false;

  /// Stops/closes this server.
  Future<void> stop() async {
    if (!_started || _stopping || isStopped) return;
    _stopping = true;

    apiRoot.close();

    await _httpServer.close();

    if (_httpSecureServer != null) {
      await _httpSecureServer!.close();
    }

    _stopped.complete(true);
  }

  FutureOr<Response> _process(Request request) {
    APIRequest? apiRequest;
    try {
      return toAPIRequest(request).resolveMapped((apiReq) {
        apiRequest = apiReq;
        return _processAPIRequest(request, apiReq);
      });
    } catch (e, s) {
      return _errorProcessing(request, apiRequest, e, s);
    }
  }

  FutureOr<Response> _processAPIRequest(
      Request request, APIRequest apiRequest) {
    try {
      if (apiRequest.method == APIRequestMethod.OPTIONS) {
        return _processOPTIONSRequest(request, apiRequest);
      } else {
        return _processCall(request, apiRequest);
      }
    } catch (e, s) {
      return _errorProcessing(request, apiRequest, e, s);
    }
  }

  Response _errorProcessing(
      Request request, APIRequest? apiRequest, Object error, StackTrace stack) {
    var requestStr = apiRequest ?? _requestToString(request);

    var message = 'ERROR processing request:\n\n$requestStr';
    _log.severe(message, error, stack);

    return Response.internalServerError(body: '$message\n\n$error\n$stack');
  }

  String _requestToString(Request request) {
    var s = StringBuffer();
    s.write('METHOD: ');
    s.write(request.method);
    s.write('\n');

    s.write('URI: ');
    s.write(request.requestedUri);
    s.write('\n');

    if (request.contentLength != null) {
      s.write('Content-Length: ');
      s.write(request.contentLength);
      s.write('\n');
    }

    s.write('HEADERS:\n');
    for (var e in request.headers.entries) {
      s.write('  - ');
      s.write(e.key);
      s.write(': ');
      s.write(e.value);
      s.write('\n');
    }

    return s.toString();
  }

  /// Converts a [request] to an [APIRequest].
  FutureOr<APIRequest> toAPIRequest(Request request) {
    var requestTime = DateTime.now();

    var method = parseAPIRequestMethod(request.method) ?? APIRequestMethod.GET;

    var headers = Map.fromEntries(request.headersAll.entries.map((e) {
      var values = e.value;
      return MapEntry(e.key, values.length == 1 ? values[0] : values);
    }));

    if (cookieless) {
      headers.remove('cookie');
    }

    var requestedUri = request.requestedUri;

    var path = requestedUri.path;
    var parameters =
        Map.fromEntries(requestedUri.queryParametersAll.entries.map((e) {
      var values = e.value;
      return MapEntry(e.key, values.length == 1 ? values[0] : values);
    }));

    var scheme = request.requestedUri.scheme;

    var connectionInfo = _getConnectionInfo(request);
    var requesterAddress = connectionInfo?.remoteAddress.address;

    var requesterSource = requesterAddress == null
        ? APIRequesterSource.unknown
        : (_isLocalAddress(requesterAddress)
            ? APIRequesterSource.local
            : APIRequesterSource.remote);

    String? sessionID;
    bool newSession = false;

    if (useSessionID && !cookieless) {
      var cookies = _parseCookies(request);
      if (cookies != null && cookies.isNotEmpty) {
        sessionID = cookies['SESSIONID'] ?? cookies['SESSION_ID'];
      }

      if (sessionID == null) {
        sessionID = APISession.generateSessionID();
        newSession = true;
      }
    }

    var keepAlive = false;

    if (request.protocolVersion == '1.1') {
      var headerConnection = headers[HttpHeaders.connectionHeader];
      if (headerConnection != null) {
        keepAlive = equalsIgnoreAsciiCase('$headerConnection', 'Keep-Alive');
      }
    }

    var credential = _resolveCredential(request);

    var parsingDuration = DateTime.now().difference(requestTime);

    return _resolvePayload(request).resolveMapped((payloadResolved) {
      var mimeType = payloadResolved?.key;
      var payload = payloadResolved?.value;

      Map<String, dynamic> parametersResolved;

      if (mimeType != null && payload != null && mimeType.isFormURLEncoded) {
        var payloadMap = payload as Map<String, dynamic>;

        parametersResolved = parameters.isEmpty
            ? payloadMap
            : <String, dynamic>{...parameters, ...payloadMap};

        payload = null;
        mimeType = null;
      } else {
        parametersResolved = Map<String, dynamic>.from(parameters);
      }

      var req = APIRequest(method, path,
          protocol: 'HTTP/${request.protocolVersion}',
          keepAlive: keepAlive,
          parameters: parametersResolved,
          requesterSource: requesterSource,
          requesterAddress: requesterAddress,
          headers: headers,
          sessionID: sessionID,
          newSession: newSession,
          credential: credential,
          scheme: scheme,
          requestedUri: request.requestedUri,
          originalRequest: request,
          payload: payload,
          payloadMimeType: mimeType,
          time: requestTime,
          parsingDuration: parsingDuration);

      return req;
    });
  }

  Map<String, String>? _parseCookies(Request request) {
    var headerCookies = request.headersAll['cookie'];
    if (headerCookies == null || headerCookies.isEmpty) return null;

    var cookies = <String, String>{};

    for (var line in headerCookies) {
      for (var c in line.split(';')) {
        var idx = c.indexOf('=');
        if (idx > 0) {
          var k = c.substring(0, idx).trim();
          var v = c.substring(idx + 1).trim();
          cookies[k] = v;
        }
      }
    }

    return cookies;
  }

  static final MimeType _mimeTypeTextPlain =
      MimeType.parse(MimeType.textPlain)!;

  Future<MapEntry<MimeType, Object>?> _resolvePayload(Request request) {
    var contentLength = request.contentLength;

    var contentMimeType = _resolveContentMimeType(request);
    if (contentLength == null && contentMimeType == null) {
      return Future.value(null);
    }

    var mimeType = contentMimeType ?? _mimeTypeTextPlain;

    if (mimeType.isStringType) {
      return _resolvePayloadString(mimeType, request);
    } else {
      return request
          .read()
          .toList()
          .then((bs) => _resolvePayloadBytes(mimeType, bs));
    }
  }

  MimeType? _resolveContentMimeType(Request request) {
    var contentType = request.headers[HttpHeaders.contentTypeHeader];

    var mimeType = MimeType.parse(contentType);

    if (mimeType == null) {
      var requestedUri = request.requestedUri;
      mimeType = _resolveMimeTypeByExtension(requestedUri.path);

      mimeType ??= requestedUri.queryParameters.entries
          .map((e) => _resolveMimeTypeByExtension(e.value))
          .whereNotNull()
          .firstOrNull;
    }

    return mimeType;
  }

  MimeType? _resolveMimeTypeByExtension(String? path) {
    if (path == null || path.isEmpty) return null;

    var idx = path.lastIndexOf('.');
    if (idx < 0) return null;

    var ext = path.substring(idx + 1);
    return MimeType.byExtension(ext, defaultAsApplication: false);
  }

  Future<MapEntry<MimeType, Object>?> _resolvePayloadString(
      MimeType mimeType, Request request) {
    var encoding = mimeType.charsetEncoding ?? latin1;

    return request.readAsString(encoding).then((s) {
      Object? payload = s;
      if (mimeType.isJSON) {
        payload = json.decode(s);
      } else if (mimeType.isFormURLEncoded) {
        payload = decodeQueryStringParameters(s, charset: mimeType.charset);
      }

      return payload == null ? null : MapEntry(mimeType, payload);
    });
  }

  FutureOr<MapEntry<MimeType, Object>?> _resolvePayloadBytes(
      MimeType mimeType, List<List<int>> bs) {
    Uint8List bytes;
    if (bs.length == 1) {
      final bs0 = bs[0];
      if (bs0 is Uint8List) {
        bytes = bs0;
      } else {
        bytes = Uint8List.fromList(bs0);
      }

      assert(bytes.length == bs0.length);
    } else {
      var allBytesSz = bs.map((e) => e.length).sum;

      bytes = Uint8List(allBytesSz);
      var bytesOffset = 0;

      for (var i = 0; i < bs.length; ++i) {
        var l = bs[i];
        var lng = l.length;

        bytes.setRange(bytesOffset, bytesOffset + lng, l);
        bytesOffset += lng;
      }

      assert(bytesOffset == allBytesSz);
    }

    return MapEntry(mimeType, bytes);
  }

  static final RegExp _regExpSpace = RegExp(r'\s+');

  APICredential? _resolveCredential(Request request) {
    var headerAuthorization = request.headers.getIgnoreCase('Authorization');
    if (headerAuthorization == null) return null;

    var idx = headerAuthorization.indexOf(_regExpSpace);
    if (idx <= 0) return null;

    var credentialType =
        headerAuthorization.substring(0, idx).trim().toLowerCase();
    var credential = headerAuthorization.substring(idx + 1).trim();

    if (credentialType == 'basic') {
      var decoded = base64.decode(credential);
      var decodedStr = utf8.decode(decoded);
      var idx2 = decodedStr.indexOf(':');

      var username = decodedStr.substring(0, idx2);
      var password = decodedStr.substring(idx2 + 1);

      return APICredential(username, passwordHash: password);
    } else if (credentialType == 'bearer') {
      return APICredential('', token: credential);
    } else if (credentialType == 'digest') {
      throw UnsupportedError('Unsupported `Authorization` type: digest');
    }

    return null;
  }

  bool _isLocalAddress(String address) =>
      address == '127.0.0.1' ||
      address == '0.0.0.0' ||
      address == '::1' ||
      address == '::';

  HttpConnectionInfo? _getConnectionInfo(Request request) {
    var val = request.context['shelf.io.connection_info'];
    return val is HttpConnectionInfo ? val : null;
  }

  FutureOr<Response> _processOPTIONSRequest(
      Request request, APIRequest apiRequest) {
    APIResponse apiResponse;

    if (!apiRoot.acceptsRequest(apiRequest)) {
      apiResponse = APIResponse.notFound();
    } else {
      apiResponse = APIResponse.ok('');
    }

    return _processAPIResponse(request, apiRequest, apiResponse);
  }

  FutureOr<Response> _processCall(Request request, APIRequest apiRequest) {
    FutureOr<APIResponse> apiResponse;

    try {
      apiResponse = apiRoot.call(apiRequest);
      if (apiResponse is Future<APIResponse>) {
        apiResponse = apiResponse.catchError((e, s) {
          return APIResponse.error(error: e, stackTrace: s);
        });
      }
    } catch (e, s) {
      apiResponse = APIResponse.error(error: e, stackTrace: s);
    }

    return apiResponse
        .resolveMapped((res) => _processAPIResponse(request, apiRequest, res));
  }

  FutureOr<Response> _processAPIResponse(
      Request request, APIRequest apiRequest, APIResponse apiResponse) {
    setCORS(apiRequest, apiResponse);

    if (apiResponse is _APIResponseStaticFile) {
      return apiResponse.fileResponse;
    }

    var headers = <String, Object>{};

    if (!apiResponse.hasCORS) {
      apiResponse.setCORS(apiRequest);
    }

    if (apiResponse.requiresAuthentication) {
      var type = apiResponse.authenticationType;
      if (type == null || type.trim().isEmpty) {
        type = 'Basic';
      }

      var realm = apiResponse.authenticationRealm;
      if (realm == null || type.trim().isEmpty) {
        realm = 'API';
      }

      headers[HttpHeaders.wwwAuthenticateHeader] = '$type realm="$realm"';
    }

    for (var e in apiResponse.headers.entries) {
      var value = e.value;
      if (value != null) {
        headers[e.key] = value;
      }
    }

    headers[HttpHeaders.serverHeader] ??= serverName;

    if (apiRequest.newSession && !cookieless) {
      var setSessionID = 'SESSIONID=${apiRequest.sessionID}';
      headers.setMultiValue(HttpHeaders.setCookieHeader, setSessionID,
          ignoreCase: true);
    }

    var authentication = apiRequest.authentication;
    if (authentication != null) {
      var tokenKey = authentication.tokenKey;

      if (authentication.resumed ||
          _needToSendHeaderXAccessToken(headers, tokenKey)) {
        headers.setMultiValue('X-Access-Token', tokenKey, ignoreCase: true);
      }
    }

    headers[HttpHeaders.cacheControlHeader] = apiCacheControl;

    var retPayload = resolveBody(apiResponse.payload, apiResponse);

    return retPayload.resolveMapped((payload) {
      if (payload is APIResponse) {
        var apiResponse2 = payload;
        return resolveBody(apiResponse2.payload, apiResponse2)
            .resolveMapped((payload2) {
          var response = _sendAPIResponse(
              request, apiRequest, apiResponse2, headers, payload2);
          return _applyGzipEncoding(request, response);
        });
      } else {
        var response = _sendAPIResponse(
            request, apiRequest, apiResponse, headers, payload);
        return _applyGzipEncoding(request, response);
      }
    });
  }

  FutureOr<Response> _applyGzipEncoding(
      Request request, FutureOr<Response> response) {
    if (!acceptsGzipEncoding(request)) {
      return response;
    } else {
      return response.resolveMapped(gzipEncodeResponse);
    }
  }

  bool _needToSendHeaderXAccessToken(
      Map<String, Object> headers, String tokenKey) {
    var headerAuthorization = headers.getFirstValue('authorization');
    var notSentByAuthentication =
        headerAuthorization == null || !headerAuthorization.contains(tokenKey);

    var headerAccessToken =
        headers.getMultiValue('x-access-token', ignoreCase: true);
    var notSentByAccessToken =
        headerAccessToken == null || !headerAccessToken.contains(tokenKey);

    var needToSendHeaderXAccessToken =
        notSentByAuthentication && notSentByAccessToken;

    return needToSendHeaderXAccessToken;
  }

  static final String headerXAccessToken = "X-Access-Token";
  static final String headerXAccessTokenExpiration =
      "X-Access-Token-Expiration";

  static final String exposeHeaders =
      "Content-Length, Content-Type, Last-Modified, $headerXAccessToken, $headerXAccessTokenExpiration";

  void setCORS(APIRequest request, APIResponse response) {
    var origin = getOrigin(request);

    var localhost = false;

    if (origin.isEmpty) {
      response.headers[HttpHeaders.accessControlAllowOriginHeader] = "*";
    } else {
      response.headers[HttpHeaders.accessControlAllowOriginHeader] = origin;

      if (origin.contains("://localhost:") ||
          origin.contains("://127.0.0.1:") ||
          origin.contains("://::1")) {
        localhost = true;
      }
    }

    response.headers[HttpHeaders.accessControlAllowMethodsHeader] =
        "GET,HEAD,PUT,POST,PATCH,DELETE,OPTIONS";

    response.headers[HttpHeaders.accessControlAllowCredentialsHeader] = "true";

    if (localhost) {
      response.headers[HttpHeaders.accessControlAllowHeadersHeader] =
          "Content-Type, Access-Control-Allow-Headers, Authorization, x-ijt";
    } else {
      response.headers[HttpHeaders.accessControlAllowHeadersHeader] =
          "Content-Type, Access-Control-Allow-Headers, Authorization";
    }

    response.headers[HttpHeaders.accessControlExposeHeadersHeader] =
        exposeHeaders;
  }

  String getOrigin(APIRequest request) {
    var origin = request.headers['origin'];
    if (origin != null) return origin;

    var host = request.headers[HttpHeaders.hostHeader];
    if (host != null) {
      var scheme = request.requestedUri.scheme;

      origin = "$scheme://$host/";
      return origin;
    }

    origin = "http://localhost/";
    return origin;
  }

  FutureOr<Response> _sendAPIResponse(Request request, APIRequest apiRequest,
      APIResponse apiResponse, Map<String, Object> headers, Object? payload) {
    apiResponse.setMetric('API-call', apiRequest.elapsedTime);

    var parsingDuration = apiRequest.parsingDuration;
    if (parsingDuration != null) {
      apiResponse.setMetric('API-request-parsing', parsingDuration);
    }

    apiResponse.stopAllMetrics();

    var contentType = apiResponse.payloadMimeType;
    if (contentType != null) {
      headers[HttpHeaders.contentTypeHeader] = contentType.toString();
    }

    var etag = apiResponse.payloadETag;
    if (etag != null) {
      headers[HttpHeaders.etagHeader] = etag.toString();
    }

    var cacheControl = apiResponse.cacheControl;
    if (cacheControl != null) {
      headers[HttpHeaders.cacheControlHeader] = cacheControl.toString();
    }

    if (apiRequest.keepAlive && !apiResponse.isBadRequest) {
      var timeout = apiResponse.keepAliveTimeout.inSeconds.clamp(0, 3600);
      var max = apiResponse.keepAliveMaxRequests.clamp(0, 1000000);

      headers[HttpHeaders.connectionHeader] = 'Keep-Alive';
      headers['keep-alive'] = 'timeout=$timeout, max=$max';
    }

    headers['server-timing'] = resolveServerTiming(apiResponse.metrics);

    if (cookieless) {
      headers.remove(HttpHeaders.setCookieHeader);
      headers['X-Cookieless-Server'] = 'Blocking all cookies';
    }

    switch (apiResponse.status) {
      case APIResponseStatus.OK:
        return Response.ok(payload, headers: headers);
      case APIResponseStatus.NOT_FOUND:
        return Response.notFound(payload, headers: headers);
      case APIResponseStatus.NOT_MODIFIED:
        {
          headers.remove('content-length');
          return Response.notModified(headers: headers);
        }
      case APIResponseStatus.UNAUTHORIZED:
        {
          var wwwAuthenticate =
              headers.getAsString('WWW-Authenticate', ignoreCase: true);

          if (wwwAuthenticate != null && wwwAuthenticate.isNotEmpty) {
            return Response(401, body: payload, headers: headers);
          } else {
            return Response.forbidden(payload, headers: headers);
          }
        }
      case APIResponseStatus.REDIRECT:
        {
          var location = apiResponse.payload;
          if (location is! Uri) {
            return Response(400, body: "Invalid redirect URL: $location");
          }

          var body =
              "<html><body>Redirecting to: <a href='$location'>$location</a></body></html>";

          headers[HttpHeaders.locationHeader] = location.toString();
          headers[HttpHeaders.contentTypeHeader] = 'text/html';

          return Response(307, body: body, headers: headers);
        }
      case APIResponseStatus.BAD_REQUEST:
        return Response(400, body: payload, headers: headers);
      case APIResponseStatus.ERROR:
        {
          var error = apiResponse.error ?? '';
          var stackTrace = apiResponse.stackTrace;
          var errorContent = stackTrace != null ? '$error\n$stackTrace' : error;

          var retError = resolveBody(errorContent, apiResponse);

          headers[HttpHeaders.contentTypeHeader] ??= 'text/plain';

          return retError.resolveMapped((error) {
            _log.severe('500 Internal Server Error', error, stackTrace);
            return Response.internalServerError(body: error, headers: headers);
          });
        }
      default:
        return Response.notFound('NOT FOUND[${request.method}]: ${request.url}',
            headers: headers);
    }
  }

  /// Resolves a [payload] to a HTTP body.
  static FutureOr<Object?> resolveBody(
      dynamic payload, APIResponse apiResponse) {
    if (payload == null) return null;

    if (payload is Future) {
      return payload.then((value) {
        return resolveBody(value, apiResponse);
      }, onError: (e, s) {
        return apiResponse.asError(error: 'ERROR: $e\n$s');
      });
    }

    var apiRequestMethod = apiResponse.apiRequest?.method;

    if (apiRequestMethod == APIRequestMethod.HEAD) {
      return null;
    }

    if (payload is String) {
      apiResponse.payloadMimeType ??=
          resolveBestTextMimeType(payload, apiResponse.payloadFileExtension);
      return payload;
    }

    if (payload is List<int>) {
      apiResponse.payloadMimeType ??= lookupMimeType(
              apiResponse.payloadFileExtension ?? 'bytes',
              headerBytes: payload) ??
          'application/octet-stream';
      return payload;
    }

    if (payload is Stream<List<int>>) {
      apiResponse.payloadMimeType ??=
          lookupMimeType(apiResponse.payloadFileExtension ?? 'bytes') ??
              'application/octet-stream';

      return payload;
    }

    if (payload is DateTime || payload is Time) {
      apiResponse.payloadMimeType ??=
          lookupMimeType(apiResponse.payloadFileExtension ?? 'text') ??
              'text/plain';
      return payload.toString();
    }

    try {
      var s = _jsonEncodePayload(apiResponse, payload);
      apiResponse.payloadMimeType ??= 'application/json';
      return s;
    } catch (e) {
      var s = payload.toString();
      apiResponse.payloadMimeType ??=
          resolveBestTextMimeType(s, apiResponse.payloadFileExtension);
      return s;
    }
  }

  static String _jsonEncodePayload(APIResponse<dynamic> apiResponse, payload) {
    final apiRequest = apiResponse.apiRequest;

    if (apiRequest != null) {
      final routeHandler = apiRequest.routeHandler;

      if (routeHandler != null) {
        var accessRules = routeHandler.entityAccessRules;

        if (!accessRules.isInnocuous) {
          return Json.encode(payload,
              toEncodableProvider: (o) => _toJsonEncodableAccessRules(
                  apiRequest,
                  accessRules,
                  Json.defaultToEncodableJsonProvider(),
                  o));
        }
      }
    }

    return Json.encode(payload, toEncodable: ReflectionFactory.toJsonEncodable);
  }

  static ToEncodableJson? _toJsonEncodableAccessRules(
      APIRequest apiRequest,
      EntityAccessRules accessRules,
      ToEncodableJsonProvider encodableJsonProvider,
      Object o) {
    if (o is EntityReferenceList ||
        o is DateTime ||
        o is Time ||
        o is Decimal ||
        o is DynamicNumber) {
      return null;
    }

    var t = o is EntityReference ? o.type : o.runtimeType;

    // No rule for entity type. No `ToEncodableJson` filter: return null
    if (!accessRules.hasRuleForEntityType(t)) return null;

    var allowType = accessRules.isAllowedEntityType(t);

    // Block not allowed type. Return `ToEncodableJson` filter: empty `Map`
    if (allowType != null && !allowType) {
      return (o, j) => <String, Object>{};
    }

    // No rule for entity field. No `ToEncodableJson` filter: return null
    if (!accessRules.hasRuleForEntityTypeField(t)) {
      return null;
    }

    return (o, j) {
      if (o == null) return null;

      var enc = encodableJsonProvider(o);

      Object? map;
      if (enc == null) {
        map = Json.toJson(o, toEncodable: ReflectionFactory.toJsonEncodable);
      } else {
        map = enc(o, j);
      }

      if (map is! Map) return map;

      var t = o.runtimeType;

      var c = EntityAccessRulesContext(accessRules, o, context: apiRequest);

      map.removeWhere((key, _) {
        var allowed = accessRules.isAllowedEntityTypeField(t, key, context: c);
        return allowed != null && !allowed;
      });

      return map;
    };
  }

  static final RegExp _htmlTag = RegExp(r'<\w+.*?>');

  static String resolveBestTextMimeType(String text, [String? fileExtension]) {
    if (fileExtension != null && fileExtension.isNotEmpty) {
      var mimeType = lookupMimeType(fileExtension);
      if (mimeType != null) {
        return mimeType;
      }
    }

    if (text.contains('<')) {
      if (_htmlTag.hasMatch(text)) {
        return 'text/html';
      }
    }

    return 'text/plain';
  }

  @override
  String toString() {
    var domainsStr = domainsRoots.isNotEmpty
        ? ', domains: [${domainsRoots.entries.map((e) {
            var key = e.key;
            var val = e.value;

            return '${key is RegExp ? 'r/${key.pattern}/' : '`$key`'}=${val.path}';
          }).join(' ; ')}]'
        : '';

    var secureStr = securePort < 10
        ? ''
        : ', securePort: $securePort, '
            'letsEncrypt: $letsEncrypt'
            '${(letsEncrypt ? (letsEncryptProduction ? ' @production' : ' @staging') : '')}, '
            'letsEncryptDirectory: ${letsEncryptDirectory?.path}';

    return 'APIServer{ apiRoot: ${apiRoot.name}[${apiRoot.version}] (${apiRoot.runtimeTypeNameUnsafe}), address: $address, port: $port$secureStr, hotReload: $hotReload (${APIHotReload.get().isEnabled ? 'enabled' : 'disabled'}), cookieless: $cookieless, SESSIONID: $useSessionID, started: $isStarted, stopped: $isStopped$domainsStr }';
  }

  /// Creates an [APIServer] with [apiRoot].
  static APIServer create(APIRoot apiRoot,
      [List<String> args = const <String>[], int argsOffset = 0]) {
    if (argsOffset > args.length) {
      argsOffset = args.length;
    }

    if (argsOffset > 0) {
      args = args.sublist(argsOffset);
    }

    String address;
    int port;
    var hotReload = false;
    String? configFile;

    if (args.isEmpty) {
      address = 'localhost';
      port = 8080;
    } else if (args.length == 1) {
      var a = args[0];
      var p = int.tryParse(a);

      if (p != null) {
        if (p >= 80) {
          address = 'localhost';
          port = p;
        } else {
          address = '$p';
          port = 8080;
        }
      } else {
        address = a;
        port = 8080;
      }
    } else {
      address = _parseArg(args, 'address', 'a', 'localhost', 0);
      port = int.parse(_parseArg(args, 'port', 'p', '8080', 1));

      var hotReloadStr =
          _parseArg(args, 'hotreload', 'r', 'false', 2, flag: true)
              .toLowerCase();

      hotReload = hotReloadStr == 'true' || hotReloadStr == 'hotreload';

      configFile = _parseArg(args, 'config', 'i', 'api-local.yaml', 3);
    }

    if (configFile != null) {
      var apiConfig = APIConfig.fromSync(configFile);
      if (apiConfig != null) {
        apiRoot.apiConfig = apiConfig;
      }
    }

    var apiServer = APIServer(apiRoot, address, port, hotReload: hotReload);

    return apiServer;
  }

  /// Runs [apiRoot] and returns the [APIServer].
  static Future<APIServer> run(APIRoot apiRoot, List<String> args,
      {int argsOffset = 0, bool verbose = false}) async {
    var apiServer = create(apiRoot, args, argsOffset);

    await apiServer.start();

    if (verbose) {
      print('\nRunning: $apiServer\n');
      print('${apiRoot.apiConfig}\n');
      print('URL: ${apiServer.apiInfoURL}\n');
    }

    return apiServer;
  }

  static String _parseArg(
      List<String> args, String name, String abbrev, String def, int index,
      {bool flag = false}) {
    if (args.isEmpty) return def;

    for (var i = 0; i < args.length; ++i) {
      var a = args[i];

      if (i < args.length - 1 &&
          (a == '--$name' || a == '-$name' || a == '-$abbrev')) {
        if (!flag) {
          var v = args[i + 1];
          return v;
        } else {
          return 'true';
        }
      }
    }

    if (index < args.length) {
      var val = args[index];
      if (val.startsWith('-')) return def;

      if (index > 0) {
        var prev = args[index - 1];
        return prev.startsWith('-') ? def : val;
      } else {
        return val;
      }
    }

    return def;
  }

  static String resolveServerTiming(Map<String, Duration> metrics) {
    var s = StringBuffer();

    for (var e in metrics.entries) {
      if (s.isNotEmpty) {
        s.write(', ');
      }
      s.write(e.key);
      s.write(';dur=');
      var ms = e.value.inMicroseconds / 1000;
      s.write(ms);
    }

    return s.toString();
  }
}

extension _FileStatExtension on FileStat {
  bool get canWrite => modeString().contains('w');
}

class _APIResponseStaticFile<T> extends APIResponse<T> {
  Response fileResponse;

  _APIResponseStaticFile(this.fileResponse)
      : super(parseAPIResponseStatus(fileResponse.statusCode) ??
            APIResponseStatus.NOT_FOUND);
}

extension _APIRequestExtension on APIRequest {
  Request toRequest() {
    var originalRequest = this.originalRequest;
    if (originalRequest is Request) {
      return originalRequest;
    }

    return Request(method.name, requestedUri);
  }
}

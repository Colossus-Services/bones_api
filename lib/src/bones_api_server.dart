import 'dart:convert';
import 'dart:io';

import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mime/mime.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_gzip/shelf_gzip.dart';

import 'bones_api_authentication.dart';
import 'bones_api_base.dart';
import 'bones_api_config.dart';
import 'bones_api_extension.dart';
import 'bones_api_hotreload.dart';
import 'bones_api_logging.dart';
import 'bones_api_utils.dart';

final _log = logging.Logger('APIServer');

/// An API HTTP Server
class APIServer {
  /// The API root of this server.
  final APIRoot apiRoot;

  /// The bind address of this server.
  final String address;

  /// The listen port of this server.
  final int port;

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

  /// If `true` log messages to [stdout] (console).
  final bool logToConsole;

  APIServer(
    this.apiRoot,
    String address,
    this.port, {
    this.name = 'Bones_API',
    this.version = APIRoot.VERSION,
    this.hotReload = false,
    this.logToConsole = true,
  }) : address = _normalizeAddress(address);

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

  /// The `server` header value.
  String get serverName => '$name/$version';

  /// The local URL of this server.
  String get url {
    return 'http://$address:$port/';
  }

  /// The local `API-INFO` URL of this server.
  String get apiInfoURL {
    return 'http://$address:$port/API-INFO';
  }

  bool _started = false;

  /// Returns `true` if this servers is started.
  bool get isStarted => _started;

  late HttpServer _httpServer;

  /// Starts this server.
  Future<bool> start() async {
    if (_started) return true;
    _started = true;

    if (logToConsole) {
      _log.handler.logToConsole();
    }

    _httpServer = await shelf_io.serve(_process, address, port);
    _httpServer.autoCompress = true;

    if (hotReload) {
      await APIHotReload.get().enable();
    }

    _log.info('Started HTTP server: $address:$port');

    return true;
  }

  /// Returns `true` if this server is closed.type
  ///
  /// A closed server can't processe new requests.
  bool get isStopped => _stopped.isCompleted;

  final Completer<bool> _stopped = Completer<bool>();

  /// Returns a [Future] that complets when this server stops.
  Future<bool> waitStopped() => _stopped.future;

  bool _stopping = false;

  /// Stops/closes this server.
  Future<void> stop() async {
    if (!_started || _stopping || isStopped) return;
    _stopping = true;

    await _httpServer.close();
    _stopped.complete(true);
  }

  FutureOr<Response> _process(Request request) {
    APIRequest? apiRequest;
    try {
      apiRequest = toAPIRequest(request);
      var apiResponse = apiRoot.call(apiRequest);
      return apiResponse.resolveMapped(
          (res) => _processAPIResponse(request, apiRequest!, res));
    } catch (e, s) {
      var requestStr = apiRequest ?? _requestToString(request);

      var message = 'ERROR processing request:\n\n$requestStr';
      _log.log(logging.Level.SEVERE, message, e, s);

      return Response.internalServerError(body: '$message\n\n$e\n$s');
    }
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

  /// Convers a [request] to an [APIRequest].
  APIRequest toAPIRequest(Request request) {
    var method = parseAPIRequestMethod(request.method)!;

    var headers = Map.fromEntries(request.headersAll.entries.map((e) {
      var vals = e.value;
      return MapEntry(e.key, vals.length == 1 ? vals[0] : vals);
    }));

    var requestedUri = request.requestedUri;

    var path = requestedUri.path;
    var parameters =
        Map.fromEntries(requestedUri.queryParametersAll.entries.map((e) {
      var vals = e.value;
      return MapEntry(e.key, vals.length == 1 ? vals[0] : vals);
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

    var cookies = _parseCookies(request);
    if (cookies != null && cookies.isNotEmpty) {
      sessionID = cookies['SESSIONID'] ?? cookies['SESSION_ID'];
    }

    if (sessionID == null) {
      sessionID = APISession.generateSessionID();
      newSession = true;
    }

    var credential = _resolveCredential(request);

    var req = APIRequest(method, path,
        parameters: parameters,
        requesterSource: requesterSource,
        requesterAddress: requesterAddress,
        headers: headers,
        sessionID: sessionID,
        newSession: newSession,
        credential: credential,
        scheme: scheme);

    return req;
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

  FutureOr<Response> _processAPIResponse(
      Request request, APIRequest apiRequest, APIResponse apiResponse) {
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

      headers['WWW-Authenticate'] = '$type realm="$realm"';
    }

    for (var e in apiResponse.headers.entries) {
      var value = e.value;
      if (value != null) {
        headers[e.key] = value;
      }
    }

    headers['server'] ??= serverName;

    if (apiRequest.newSession) {
      var setSessionID = 'SESSIONID=${apiRequest.sessionID}';
      headers.setMultiValue('Set-Cookie', setSessionID, ignoreCase: true);
    }

    var authentication = apiRequest.authentication;
    if (authentication != null) {
      var tokenKey = authentication.tokenKey;

      if (authentication.resumed ||
          _needToSendHeaderXAccessToken(headers, tokenKey)) {
        headers.setMultiValue('X-Access-Token', tokenKey, ignoreCase: true);
      }
    }

    var retPayload = resolveBody(apiResponse.payload, apiResponse);

    return retPayload.resolveMapped((payload) {
      if (payload is APIResponse) {
        var apiResponse2 = payload;
        return resolveBody(apiResponse2.payload, apiResponse2)
            .resolveMapped((payload2) {
          var response = _sendResponse(
              request, apiRequest, apiResponse2, headers, payload2);
          return _applyGzipEncoding(request, response);
        });
      } else {
        var response =
            _sendResponse(request, apiRequest, apiResponse, headers, payload);
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

    var needToSendHeaderXAcessToken =
        notSentByAuthentication && notSentByAccessToken;

    return needToSendHeaderXAcessToken;
  }

  FutureOr<Response> _sendResponse(Request request, APIRequest apiRequest,
      APIResponse apiResponse, Map<String, Object> headers, Object? payload) {
    apiResponse.setMetric('API-call', apiRequest.elapsedTime);
    apiResponse.stopAllMetrics();

    var contentType = apiResponse.payloadMimeType;
    if (contentType != null && contentType.isNotEmpty) {
      contentType = _fixContentType(contentType);
      headers['content-type'] = contentType;
    }

    headers['server-timing'] = resolveServerTiming(apiResponse.metrics);

    switch (apiResponse.status) {
      case APIResponseStatus.OK:
        return Response.ok(payload, headers: headers);
      case APIResponseStatus.NOT_FOUND:
        return Response.notFound(payload, headers: headers);
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
      case APIResponseStatus.BAD_REQUEST:
        return Response(400, body: payload, headers: headers);
      case APIResponseStatus.ERROR:
        {
          var retError = resolveBody(apiResponse.error, apiResponse);

          return retError.resolveMapped((error) {
            return Response.internalServerError(body: error, headers: headers);
          });
        }
      default:
        return Response.notFound('NOT FOUND[${request.method}]: ${request.url}',
            headers: headers);
    }
  }

  String _fixContentType(String contentType) {
    var contentTypeLC = contentType.trim().toLowerCase();

    switch (contentTypeLC) {
      case 'json':
        return 'application/json';
      case 'js':
      case 'javascript':
        return 'application/javascript';
      case 'text':
        return 'text/plain';
      case 'html':
        return 'text/html';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return contentType;
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
      var s =
          Json.encode(payload, toEncodable: ReflectionFactory.toJsonEncodable);
      apiResponse.payloadMimeType ??= 'application/json';
      return s;
    } catch (e) {
      var s = payload.toString();
      apiResponse.payloadMimeType ??=
          resolveBestTextMimeType(s, apiResponse.payloadFileExtension);
      return s;
    }
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
    return 'APIServer{ apiType: ${apiRoot.runtimeType}, apiRoot: $apiRoot, address: $address, port: $port, hotReload: $hotReload, started: $isStarted, stopped: $isStopped }';
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

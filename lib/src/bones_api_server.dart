import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mime/mime.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'bones_api_base.dart';
import 'bones_api_hotreload.dart';
import 'bones_api_logging.dart';

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

    var req = APIRequest(method, path,
        parameters: parameters,
        requesterSource: requesterSource,
        requesterAddress: requesterAddress,
        headers: headers,
        scheme: scheme);

    return req;
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

    for (var e in apiResponse.headers.entries) {
      var value = e.value;
      if (value != null) {
        headers[e.key] = value;
      }
    }

    headers['server'] ??= serverName;

    var retPayload = resolveBody(apiResponse.payload, apiResponse);

    return retPayload.resolveMapped((payload) {
      if (payload is APIResponse) {
        var apiResponse2 = payload;
        return resolveBody(apiResponse2.payload, apiResponse2)
            .resolveMapped((payload2) {
          return _sendResponse(
              request, apiRequest, apiResponse2, headers, payload2);
        });
      } else {
        return _sendResponse(
            request, apiRequest, apiResponse, headers, payload);
      }
    });
  }

  FutureOr<Response> _sendResponse(Request request, APIRequest apiRequest,
      APIResponse apiResponse, Map<String, Object> headers, Object? payload) {
    apiResponse.setMetric('API-call', apiRequest.elapsedTime);
    apiResponse.stopAllMetrics();

    var contentType = apiResponse.payloadMimeType;
    if (contentType != null && contentType.isNotEmpty) {
      headers['content-type'] = contentType;
    }

    headers['server-timing'] = resolveServerTiming(apiResponse.metrics);

    switch (apiResponse.status) {
      case APIResponseStatus.OK:
        return Response.ok(payload, headers: headers);
      case APIResponseStatus.NOT_FOUND:
        return Response.notFound(payload, headers: headers);
      case APIResponseStatus.UNAUTHORIZED:
        return Response.forbidden(payload, headers: headers);
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

    if (payload is DateTime) {
      apiResponse.payloadMimeType ??=
          lookupMimeType(apiResponse.payloadFileExtension ?? 'text') ??
              'text/plain';
      return payload.toString();
    }

    try {
      var s =
          json.encode(payload, toEncodable: ReflectionFactory.toJsonEncodable);
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
      print('Running: $apiServer');
      print('URL: ${apiServer.url}');
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
      return args[index];
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

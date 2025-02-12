import 'dart:async';
// ignore: deprecated_member_use
import 'dart:html';
import 'dart:typed_data';

import 'package:mercury_client/mercury_client.dart';
import 'package:swiss_knife/swiss_knife.dart';

import 'bones_api_extension.dart';
import 'bones_api_platform.dart';

class APIPlatformBrowser extends APIPlatform {
  @override
  APIPlatformType get type => APIPlatformType.browser;

  APIPlatformCapability? _capability;

  @override
  APIPlatformCapability get capability =>
      _capability ??= APIPlatformCapability.bits53(canReadFile: true);

  @override
  void log(Object? message, [Object? error, StackTrace? stackTrace]) {
    _log('LOG', message);
  }

  @override
  void logError(Object? message, [Object? error, StackTrace? stackTrace]) {
    _logError('ERROR', message);
  }

  @override
  void logInfo(Object? message, [Object? error, StackTrace? stackTrace]) {
    _log('INFO', message);
  }

  @override
  void logWarning(Object? message, [Object? error, StackTrace? stackTrace]) {
    _log('WARNING', message);
  }

  void _log(String type, Object? message,
      [Object? error, StackTrace? stackTrace]) {
    print('[$type] $message');
    if (error != null) {
      stderrLn(error);
    }
    if (stackTrace != null) {
      print(stackTrace);
    }
  }

  void _logError(String type, Object? message,
      [Object? error, StackTrace? stackTrace]) {
    stderrLn('[WARNING] $message');
    if (error != null) {
      stderrLn(error);
    }
    if (stackTrace != null) {
      stderrLn(stackTrace);
    }
  }

  @override
  void stdout(Object? o) => stdoutLn(o);

  @override
  void stdoutLn(Object? o) => window.console.log(o);

  @override
  void stderr(Object? o) => stderrLn(o);

  @override
  void stderrLn(Object? o) => window.console.error(o);

  static final RegExp _regExpUriStart = RegExp(r'^\w+:/');

  @override
  String? resolveFilePath(String filePath, {String? parentPath}) {
    if (parentPath != null &&
        parentPath.isNotEmpty &&
        !filePath.startsWith('/')) {
      if (!parentPath.endsWith('/')) {
        parentPath += '/';
      }
      filePath = '$parentPath$filePath';
    }

    if (filePath.startsWith(_regExpUriStart)) {
      var uri = Uri.tryParse(filePath);
      if (uri != null) {
        var path = uri.toFilePath();
        var uriBasePath = getUriBase().path;
        if (path.startsWith(uriBasePath)) {
          path = path.substring(uriBasePath.length);
        }
        filePath = path;
      }
    }

    var url = resolveURL(filePath, baseUri: getUriBase());
    return url;
  }

  Future<HttpResponse> _readFile(String filePath) async {
    var baseUrl = getUriBase();
    var client = HttpClient(baseUrl.toString());
    var response = await client.get(filePath);
    return response;
  }

  @override
  FutureOr<String?> readFileAsString(String filePath) async {
    HttpResponse response = await _readFile(filePath);
    if (response.isNotOK) return null;

    return response.bodyAsString;
  }

  @override
  FutureOr<Uint8List?> readFileAsBytes(String filePath) async {
    HttpResponse response = await _readFile(filePath);
    if (response.isNotOK) return null;

    var data = response.body?.asByteArray;
    if (data == null) return null;
    return data is Uint8List ? data : Uint8List.fromList(data);
  }

  final Map<String, String> _properties = {};

  @override
  Iterable<String> get propertiesKeys {
    var location = window.location.href.trim();
    var uri = location.isNotEmpty ? Uri.tryParse(location) : null;

    return {..._properties.keys, ...?uri?.queryParameters.keys};
  }

  @override
  String? setProperty(String key, String value) {
    var prev = getProperty(key);
    _properties[key] = value;
    return prev;
  }

  @override
  String? getProperty(String? key,
      {String? defaultValue, bool caseSensitive = false}) {
    if (key == null) return defaultValue;

    var prev = _properties[key];
    if (prev != null) return prev;

    var location = window.location.href.trim();
    if (location.isEmpty) return defaultValue;

    var uri = Uri.tryParse(location);
    if (uri == null) return defaultValue;

    return uri.queryParameters.getIgnoreCase(key, defaultValue: defaultValue);
  }
}

APIPlatform createAPIPlatform() {
  return APIPlatformBrowser();
}

import 'dart:typed_data';

import 'bones_api_extension.dart';
import 'bones_api_platform.dart';

class APIPlatformGeneric extends APIPlatform {
  @override
  APIPlatformType get type => APIPlatformType.generic;

  APIPlatformCapability? _capability;

  @override
  APIPlatformCapability get capability =>
      _capability ??= APIPlatformCapability.bits32(canReadFile: false);

  @override
  void log(Object? message, [Object? error, StackTrace? stackTrace]) {
    _log('LOG', message);
  }

  @override
  void logError(Object? message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message);
  }

  @override
  void logInfo(Object? message, [Object? error, StackTrace? stackTrace]) {
    _log('INFO', message);
  }

  @override
  void logWarning(Object? message, [Object? error, StackTrace? stackTrace]) {
    _log('WARNING', message);
  }

  void _log(
    String type,
    Object? message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    print('[WARNING] $message');
    if (error != null) {
      print(error);
    }
    if (stackTrace != null) {
      print(stackTrace);
    }
  }

  @override
  void stdout(Object? o) {
    print(o);
  }

  @override
  void stdoutLn(Object? o) => stdout(o);

  @override
  void stderr(Object? o) => stdout(o);

  @override
  void stderrLn(Object? o) => stdout(o);

  @override
  String? resolveFilePath(String filePath, {String? parentPath}) => filePath;

  @override
  String? readFileAsString(String filePath) => null;

  @override
  Uint8List? readFileAsBytes(String filePath) => null;

  final Map<String, String> _properties = {};

  @override
  Iterable<String> get propertiesKeys {
    var uri = Uri.base;
    return {..._properties.keys, ...uri.queryParameters.keys};
  }

  @override
  String? setProperty(String key, String value) {
    var prev = getProperty(key);
    _properties[key] = value;
    return prev;
  }

  @override
  String? getProperty(
    String? key, {
    String? defaultValue,
    bool caseSensitive = false,
  }) {
    if (key == null) return defaultValue;

    var prev = _properties[key];
    if (prev != null) return prev;

    var uri = Uri.base;
    return uri.queryParameters.getIgnoreCase(key, defaultValue: defaultValue);
  }
}

APIPlatform createAPIPlatform() {
  return APIPlatformGeneric();
}

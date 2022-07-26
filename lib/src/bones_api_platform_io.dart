import 'dart:io' as io;
import 'dart:typed_data';

import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as pack_path;

import 'bones_api_extension.dart';
import 'bones_api_platform.dart';

final _log = logging.Logger('APIPlatform');

class APIPlatformVM extends APIPlatform {
  APIPlatformVM._();

  APIPlatformType? _type;

  @override
  APIPlatformType get type => _type ??= _typeImpl();

  APIPlatformType _typeImpl() {
    if (io.Platform.isIOS) {
      return APIPlatformType.ios;
    } else if (io.Platform.isAndroid) {
      return APIPlatformType.android;
    } else if (io.Platform.isLinux) {
      return APIPlatformType.linux;
    } else if (io.Platform.isMacOS) {
      return APIPlatformType.macos;
    } else if (io.Platform.isWindows) {
      return APIPlatformType.windows;
    } else {
      var path = pack_path.split(io.Platform.executable);
      var fileName = path.last;
      if (fileName == 'dart' || fileName.startsWith('dart.')) {
        return APIPlatformType.vm;
      } else {
        return APIPlatformType.native;
      }
    }
  }

  APIPlatformCapability? _capability;

  @override
  APIPlatformCapability get capability =>
      _capability ??= APIPlatformCapability.bits64(canReadFile: true);

  @override
  void log(Object? message, [Object? error, StackTrace? stackTrace]) =>
      _log.fine(message, error, stackTrace);

  @override
  void logInfo(Object? message, [Object? error, StackTrace? stackTrace]) =>
      _log.info(message, error, stackTrace);

  @override
  void logWarning(Object? message, [Object? error, StackTrace? stackTrace]) =>
      _log.warning(message, error, stackTrace);

  @override
  void logError(Object? message, [Object? error, StackTrace? stackTrace]) =>
      _log.severe(message, error, stackTrace);

  @override
  void stdout(Object? o) => io.stdout.write(o);

  @override
  void stdoutLn(Object? o) => io.stdout.writeln(o);

  @override
  void stderr(Object? o) => io.stderr.write(o);

  @override
  void stderrLn(Object? o) => io.stderr.writeln(o);

  static final RegExp _regExpUriFileStart = RegExp(r'^file:/');

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

    if (filePath.startsWith(_regExpUriFileStart)) {
      var uri = Uri.tryParse(filePath);
      if (uri != null) {
        filePath = uri.toFilePath();
      }
    }

    var file = io.File(filePath).absolute;
    return file.path;
  }

  @override
  String? readFileAsString(String filePath) {
    var file = io.File(filePath);
    return file.readAsStringSync();
  }

  @override
  Uint8List? readFileAsBytes(String filePath) {
    var file = io.File(filePath);
    return file.readAsBytesSync();
  }

  @override
  String? getProperty(String? key,
      {String? defaultValue, bool caseSensitive = false}) {
    if (key == null) return defaultValue;
    var value = io.Platform.environment.get(key, ignoreCase: !caseSensitive);
    return value ?? defaultValue;
  }
}

APIPlatform createAPIPlatform() {
  return APIPlatformVM._();
}

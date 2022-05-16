import 'dart:io' as io;
import 'dart:typed_data';

import 'package:logging/logging.dart' as logging;

import 'bones_api_platform.dart';

final _log = logging.Logger('APIPlatform');

class APIPlatformVM extends APIPlatform {
  APIPlatformVM._();

  @override
  APIPlatformType get type {
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
      return APIPlatformType.vm;
    }
  }

  @override
  APIPlatformCapability get capability =>
      APIPlatformCapability.bits64(canReadFile: true);

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

  @override
  String? resolveFilePath(String filePath) {
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
}

APIPlatform createAPIPlatform() {
  return APIPlatformVM._();
}

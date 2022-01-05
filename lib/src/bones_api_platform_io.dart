import 'dart:io' as io;

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
      APIPlatformCapability(int64: true, double64: true);

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
}

APIPlatform createAPIPlatform() {
  return APIPlatformVM._();
}

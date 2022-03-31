import 'dart:html';

import 'bones_api_platform.dart';

class APIPlatformBrowser extends APIPlatform {
  @override
  APIPlatformType get type => APIPlatformType.browser;

  @override
  APIPlatformCapability get capability => APIPlatformCapability.bits53();

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
}

APIPlatform createAPIPlatform() {
  return APIPlatformBrowser();
}

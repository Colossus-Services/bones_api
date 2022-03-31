import 'bones_api_platform.dart';

class APIPlatformGeneric extends APIPlatform {
  @override
  APIPlatformType get type => APIPlatformType.generic;

  @override
  APIPlatformCapability get capability => APIPlatformCapability.bits32();

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

  void _log(String type, Object? message,
      [Object? error, StackTrace? stackTrace]) {
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
}

APIPlatform createAPIPlatform() {
  return APIPlatformGeneric();
}

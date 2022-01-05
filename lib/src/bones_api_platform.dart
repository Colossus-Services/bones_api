import 'bones_api_platform_generic.dart'
    if (dart.library.html) 'bones_api_platform_browser.dart'
    if (dart.library.io) 'bones_api_platform_io.dart';

enum APIPlatformType {
  generic,
  browser,
  vm,
  native,
  ios,
  android,
  linux,
  macos,
  windows,
}

extension APIPlatformTypeExtension on APIPlatformType {
  String get name {
    switch (this) {
      case APIPlatformType.generic:
        return 'generic';
      case APIPlatformType.browser:
        return 'browser';
      case APIPlatformType.vm:
        return 'vm';
      case APIPlatformType.native:
        return 'native';
      case APIPlatformType.ios:
        return 'ios';
      case APIPlatformType.android:
        return 'android';
      case APIPlatformType.linux:
        return 'linux';
      case APIPlatformType.macos:
        return 'macos';
      case APIPlatformType.windows:
        return 'windows';
      default:
        throw StateError('Unknown: $this');
    }
  }
}

/// The current API platform.
abstract class APIPlatform {
  static final APIPlatform _instance = createAPIPlatform();

  /// Returns the static [APIPlatform] instance for the current platform.
  static APIPlatform get() => _instance;

  APIPlatformType get type;

  String get name => type.name;

  APIPlatformCapability get capability;

  void log(Object? message, [Object? error, StackTrace? stackTrace]);

  void logInfo(Object? message, [Object? error, StackTrace? stackTrace]);

  void logWarning(Object? message, [Object? error, StackTrace? stackTrace]);

  void logError(Object? message, [Object? error, StackTrace? stackTrace]);

  void stdout(Object? o);

  void stdoutLn(Object? o);

  void stderr(Object? o);

  void stderrLn(Object? o);
}

class APIPlatformCapability {
  final bool int64;
  final bool double64;

  APIPlatformCapability({this.int64 = false, this.double64 = false});
}

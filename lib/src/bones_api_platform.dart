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
  static final BigInt int64Max = BigInt.parse('9223372036854775807');

  static final BigInt int64Min = BigInt.parse('-9223372036854775808');

  static final BigInt int53Max = BigInt.parse('9007199254740991');

  static final BigInt int53Min = BigInt.parse('-9007199254740991');

  static final BigInt int32Max = BigInt.parse('2147483647');

  static final BigInt int32Min = BigInt.parse('-2147483648');

  final bool int64;
  final bool double64;
  final bool int53;
  final bool double53;
  final bool int32;
  final bool double32;
  final int maxSafeInteger;
  final int minSafeInteger;

  APIPlatformCapability(
      {this.int64 = false,
      this.double64 = false,
      this.int53 = false,
      this.double53 = false,
      this.int32 = false,
      this.double32 = false,
      int? maxSafeInteger,
      int? minSafeInteger})
      : maxSafeInteger = maxSafeInteger ??
            (int64
                ? int64Max.toInt()
                : (int53
                    ? int53Max.toInt()
                    : (int32
                        ? int32Max.toInt()
                        : throw StateError(
                            'maxSafeInteger error: Platform `int` not defined!')))),
        minSafeInteger = minSafeInteger ??
            (int64
                ? int64Min.toInt()
                : (int53
                    ? int53Min.toInt()
                    : (int32
                        ? int32Min.toInt()
                        : throw StateError(
                            'minSafeInteger error: Platform `int` not defined!'))));

  APIPlatformCapability.bits64() : this(int64: true, double64: true);
  APIPlatformCapability.bits53() : this(int53: true, double53: true);
  APIPlatformCapability.bits32() : this(int32: true, double32: true);
}

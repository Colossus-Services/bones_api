import 'dart:async';
import 'dart:typed_data';

import 'package:args_simple/args_simple.dart';

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
    }
  }
}

/// The current API platform.
abstract class APIPlatform {
  static final APIPlatform _instance = createAPIPlatform();

  /// Returns the static [APIPlatform] instance for the current platform.
  static APIPlatform get() => _instance;

  /// The platform type.
  APIPlatformType get type;

  /// The name of the platform.
  String get name => type.name;

  /// The capabilities of this platforms.
  APIPlatformCapability get capability;

  void log(Object? message, [Object? error, StackTrace? stackTrace]);

  void logInfo(Object? message, [Object? error, StackTrace? stackTrace]);

  void logWarning(Object? message, [Object? error, StackTrace? stackTrace]);

  void logError(Object? message, [Object? error, StackTrace? stackTrace]);

  void stdout(Object? o);

  void stdoutLn(Object? o);

  void stderr(Object? o);

  void stderrLn(Object? o);

  /// Resolves [filePath] to the platform actual file path.
  String? resolveFilePath(String filePath, {String? parentPath});

  /// Reads a [filePath] data as [String].
  FutureOr<String?> readFileAsString(String filePath);

  /// Reads a [filePath] data as [Uint8List].
  FutureOr<Uint8List?> readFileAsBytes(String filePath);

  /// Returns a platform property. See [setProperty].
  ///
  /// Depending on the [APIPlatform] implementation this
  /// can be an `environment` variable or an URL `queryParameters`.
  String? getProperty(String? key,
      {String? defaultValue, bool caseSensitive = false});

  /// Alias to [getProperty] with a casting to [T].
  T? getPropertyAs<T>(String? key,
      {String? defaultValue, bool caseSensitive = false}) {
    var val = getProperty(key,
        defaultValue: defaultValue, caseSensitive: caseSensitive);
    if (val == null) return null;

    if (val is! T) {
      var parser = TypeParser.parserFor<T>();
      if (parser != null) {
        return parser(val);
      }

      throw StateError("Can't return key `$key` as `$T`: $val");
    }

    return val as T;
  }

  /// Overwrites a platform property. Returns the previous value.
  /// See [getProperty].
  String? setProperty(String key, String value);

  /// Returns the platform properties keys.
  /// See [getProperty] and [setProperty].
  Iterable<String> get propertiesKeys;
}

class APIPlatformCapability {
  static final BigInt int64Max = BigInt.parse('9223372036854775807');

  static final BigInt int64Min = BigInt.parse('-9223372036854775808');

  static final BigInt int53Max = BigInt.parse('9007199254740991');

  static final BigInt int53Min = BigInt.parse('-9007199254740991');

  static final BigInt int32Max = BigInt.parse('2147483647');

  static final BigInt int32Min = BigInt.parse('-2147483648');

  final bool canReadFile;
  final bool int64;
  final bool double64;
  final bool int53;
  final bool double53;
  final bool int32;
  final bool double32;
  final int maxSafeInteger;
  final int minSafeInteger;

  APIPlatformCapability(
      {required this.canReadFile,
      this.int64 = false,
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

  APIPlatformCapability.bits64({required bool canReadFile})
      : this(canReadFile: canReadFile, int64: true, double64: true);

  APIPlatformCapability.bits53({required bool canReadFile})
      : this(canReadFile: canReadFile, int53: true, double53: true);

  APIPlatformCapability.bits32({required bool canReadFile})
      : this(canReadFile: canReadFile, int32: true, double32: true);
}

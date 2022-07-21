import 'package:async_extension/async_extension.dart';
import 'package:statistics/statistics.dart';

/// Basic [String] functions.
class StringUtils {
  /// Transforms [s] to lower-case.
  static String toLowerCase(String s) => s.toLowerCase();

  static final RegExp _regexpLettersAndDigits = RegExp(r'[^a-zA-Z\d]+');

  /// Transforms [s] to lower-case and removes non-letters and non-digits.
  static String toLowerCaseSimple(String s) =>
      s.toLowerCase().replaceAll(_regexpLettersAndDigits, '');

  /// Transforms [s] to lower-case using underscore (`_`)
  /// before the upper-case letters.
  /// - If [simple] is `true` removes non-letters and non-digits.
  static String toLowerCaseUnderscore(String s, {bool simple = false}) {
    if (simple) {
      s = s.replaceAll(_regexpLettersAndDigits, '_');
    }

    var str = StringBuffer();

    String? prevChar;

    for (var rune in s.runes) {
      var char = String.fromCharCode(rune);

      if (prevChar != null && isUpperCase(char) && isLetterOrDigit(char)) {
        if (char != '_' && prevChar != '_') {
          str.write('_');
        }
      }

      str.write(char.toLowerCase());

      prevChar = char;
    }

    return str.toString();
  }

  /// Returns `true` if [s] is a uppercase [String].
  static bool isUpperCase(String s) => s == s.toUpperCase();

  static final RegExp _regexpIsLetter = RegExp(r'^[a-zA-Z]+$');

  /// Returns `true` if [s] is a latter.
  static bool isLetter(String s) => _regexpIsLetter.hasMatch(s);

  static final RegExp _regexpIsDigit = RegExp(r'^\d+$');

  /// Returns `true` if [s] is a digit.
  static bool isDigit(String s) => _regexpIsDigit.hasMatch(s);

  static final RegExp _regexpIsLetterOrDigit = RegExp(r'^[a-zA-Z\d]+$');

  /// Returns `true` if [s] is a letter or digit.
  static bool isLetterOrDigit(String s) => _regexpIsLetterOrDigit.hasMatch(s);
}

/// Base class for key normalization mapping.
abstract class KeyMapper<K> {
  List<K> expandedKeys(K key);

  List<K> normalizedKeys(K key);

  final Map<K, K> _keysMapping = <K, K>{};
  final Map<K, K> _keysUnmapping = <K, K>{};

  void setupKeys(Iterable<K> keys) {
    for (var k in keys) {
      setupKey(k);
    }
  }

  List<K> setupKey(K key) {
    var expandKeys =
        expandedKeys(key).expand((k) => normalizedKeys(k)).toList();

    var keysNorm = [...normalizedKeys(key), ...expandKeys].toDistinctList();

    if (keysNorm.isEmpty) return keysNorm;

    _keysMapping[key] = key;
    _keysUnmapping[key] = keysNorm.first;

    for (var kNorm in keysNorm) {
      _keysMapping[kNorm] = key;
    }

    return keysNorm;
  }

  K? map(K key) {
    var k = _keysMapping[key];
    if (k != null) return k;

    var keysNorm = normalizedKeys(key);

    for (var kNorm in keysNorm) {
      var k = _keysMapping[kNorm];
      if (k != null) return k;
    }

    return null;
  }

  K? unmap(K keyMapped) {
    var key = _keysUnmapping[keyMapped];
    if (key != null) return key;

    var keysNorm = normalizedKeys(keyMapped);

    for (var e in _keysMapping.entries) {
      var k = e.value;
      if (k == keyMapped || keysNorm.contains(k)) {
        return e.key;
      }
    }

    return key;
  }
}

/// A [KeyMapper] for class fields or table columns.
class FieldNameMapper extends KeyMapper<String> {
  @override
  List<String> expandedKeys(String key) {
    var exp = <String>[
      key,
      if (key.contains('-')) key.replaceAll('-', '_'),
      if (key.contains('_')) key.replaceAll('_', '-'),
    ];

    exp.addAll(exp.map((k) => k.toUpperCase()).toList());
    exp.addAll(exp.map((k) => k.toLowerCase()).toList());

    var norm = exp.expand((k) => normalizedKeys(k)).toList();

    var allExp = <String>[...exp, ...norm];

    return allExp;
  }

  @override
  List<String> normalizedKeys(String key) {
    var lc = StringUtils.toLowerCase(key);
    var lcSimple = StringUtils.toLowerCaseSimple(key);

    return lc != lcSimple ? <String>[lcSimple, lc] : <String>[lc];
  }
}

/// Tries to performa a [call].
/// - If [onSuccessValue] is defined it overwrites the [call] returned value.
/// - If [onErrorValue] is defined it will be returned in case of error.
/// - Returns [defaultValue] if [call] returns `null` and [onSuccessValue] or [onErrorValue] are `null`.
FutureOr<T?> tryCall<T>(FutureOr<T?> Function() call,
    {T? defaultValue, T? onSuccessValue, T? onErrorValue}) {
  try {
    return call().then((ret) => onSuccessValue ?? ret ?? defaultValue,
        onError: (e) => onErrorValue ?? defaultValue);
  } catch (_) {
    return onErrorValue ?? defaultValue;
  }
}

/// Tries to performa a [call].
/// See [tryCall].
FutureOr<R?> tryCallMapped<T, R>(FutureOr<T?> Function() call,
    {R? defaultValue,
    R? onSuccessValue,
    R? Function(T? value)? onSuccess,
    R? onErrorValue,
    R? Function(Object error, StackTrace s)? onError}) {
  try {
    return call().then((ret) {
      if (onSuccess != null) {
        return onSuccess(ret) ?? onSuccessValue ?? defaultValue;
      }
      return ret
          .resolveMapped((r) => onSuccessValue ?? r as R? ?? defaultValue);
    }, onError: (e, s) {
      if (onError != null) {
        return onError(e, s) ?? onErrorValue ?? defaultValue;
      }
      return onErrorValue ?? defaultValue;
    });
  } catch (e, s) {
    if (onError != null) {
      return onError(e, s) ?? onErrorValue ?? defaultValue;
    }
    return onErrorValue ?? defaultValue;
  }
}

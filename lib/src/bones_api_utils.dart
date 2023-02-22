import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:statistics/statistics.dart';

/// Basic [String] functions.
class StringUtils {
  /// Transforms [s] to lower-case.
  static String toLowerCase(String s) => s.toLowerCase();

  static final RegExp _regexpNotLettersAndDigits = RegExp(r'[^a-zA-Z\d]+');

  /// Transforms [s] to lower-case and removes non-letters and non-digits.
  static String toLowerCaseSimple(String s) =>
      s.toLowerCase().replaceAll(_regexpNotLettersAndDigits, '');

  static final RegExp _regexpNotLettersDigitsAndUnderscore = RegExp(r'\W+');

  /// Transforms [s] to lower-case and removes non-letters, non-digits and non-underscore (`_`), also repeating underscores are replaced to a single one `_`.
  static String toLowerCaseSimpleUnderscored(String s) {
    return s
        .toLowerCase()
        .replaceAll(_regexpNotLettersDigitsAndUnderscore, '')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Transforms [s] to lower-case using underscore (`_`)
  /// before the upper-case letters.
  /// - If [simple] is `true` removes non-letters and non-digits.
  static String toLowerCaseUnderscore(String s, {bool simple = false}) {
    if (simple) {
      s = s.replaceAll(_regexpNotLettersAndDigits, '_');
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

  /// Ensures that this [regexp] matches an ending of a [String].
  static RegExp asEndingPattern(RegExp regexp) {
    if (regexp.pattern.contains('\$')) {
      return regexp;
    } else {
      return RegExp('${regexp.pattern}\$');
    }
  }

  /// Returns `true` if [s] ends with [pattern] (accepts [RegExp]).
  static bool endsWithPattern(String s, Pattern pattern,
      {bool isEndingPattern = false}) {
    if (pattern is RegExp) {
      var p = isEndingPattern ? pattern : asEndingPattern(pattern);
      return p.hasMatch(s);
    } else {
      return s.endsWith(pattern.toString());
    }
  }

  /// Returns the equals head part of [l] elements.
  static String getHeadEquality(List<String> l,
      {Pattern? delimiter,
      int? minLength,
      bool Function(String s)? validator}) {
    if (l.length <= 1) return '';

    var min = l.map((e) => e.length).min;
    if (minLength != null && min > minLength) min = minLength;

    var longest = '';
    String? longestWithDelimiter;

    if (delimiter is RegExp) {
      delimiter = asEndingPattern(delimiter);
    }

    for (var sz = 1; sz < min; ++sz) {
      var head = l[0].substring(0, sz);

      var matches = true;
      for (var i = 1; i < l.length; ++i) {
        var e = l[i];
        if (!e.startsWith(head)) {
          matches = false;
          break;
        }
      }

      if (matches && (validator == null || validator(head))) {
        longest = head;
        if (delimiter != null &&
            endsWithPattern(head, delimiter, isEndingPattern: true)) {
          longestWithDelimiter = head;
        }
      }
    }

    return longestWithDelimiter ?? longest;
  }

  /// Returns the equals tail part of [l] elements.
  static String getTailEquality(List<String> l,
      {Pattern? delimiter,
      int? minLength,
      bool Function(String s)? validator}) {
    if (l.length <= 1) return '';

    var min = l.map((e) => e.length).min;
    if (minLength != null && min > minLength) min = minLength;

    var longest = '';
    String? longestWithDelimiter;

    for (var sz = 1; sz < min; ++sz) {
      var s = l[0];
      var tail = s.substring(s.length - sz);

      var matches = true;
      for (var i = 1; i < l.length; ++i) {
        var e = l[i];
        if (!e.endsWith(tail)) {
          matches = false;
          break;
        }
      }

      if (matches && (validator == null || validator(tail))) {
        longest = tail;
        if (delimiter != null && tail.startsWith(delimiter)) {
          longestWithDelimiter = tail;
        }
      }
    }

    return longestWithDelimiter ?? longest;
  }

  static List<String> trimEqualities(List<String> l,
      {Pattern? delimiter,
      int? minLength,
      bool Function(String s)? validator}) {
    if (l.length <= 1) return l.toList();

    var head = getHeadEquality(l,
        delimiter: delimiter, minLength: minLength, validator: validator);
    var headSz = head.length;

    var min = l.map((e) => e.length).min;
    var tailMinLength = min - headSz;
    if (minLength != null && tailMinLength > minLength) {
      tailMinLength = minLength;
    }

    var tail = getTailEquality(l,
        delimiter: delimiter, minLength: tailMinLength, validator: validator);
    var tailSz = tail.length;

    var l2 = l.map((e) => e.substring(headSz, e.length - tailSz)).toList();
    return l2;
  }

  static Map<String, String> trimEqualitiesMap(List<String> l,
      {String? delimiter,
      String Function(String s)? normalizer,
      bool Function(String s)? validator}) {
    var l1 = normalizer != null ? normalizeAll(l, normalizer) : l;
    var l2 = trimEqualities(l1, delimiter: delimiter, validator: validator);
    return Map<String, String>.fromIterables(l, l2);
  }

  static List<String> normalizeAll(
      List<String> l, String Function(String s)? normalizer) {
    if (normalizer == null) return l;
    l = l.map(normalizer).toList();
    return l;
  }
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

/// Tries to performa a [call] synchronously.
/// - If [onSuccessValue] is defined it overwrites the [call] returned value.
/// - If [onErrorValue] is defined it will be returned in case of error.
/// - Returns [defaultValue] if [call] returns `null` and [onSuccessValue] or [onErrorValue] are `null`.
T? tryCallSync<T>(T? Function() call,
    {T? defaultValue, T? onSuccessValue, T? onErrorValue}) {
  try {
    var ret = call();
    return onSuccessValue ?? ret ?? defaultValue;
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

/// Interface for classes that need a safe [runtimeType] as [String].
abstract class WithRuntimeTypeNameSafe {
  /// Returns the [runtimeType] as [String] in safe way.
  String get runtimeTypeNameSafe;
}

extension ExtensionRuntimeTypeNameUnsafe on Object? {
  /// Returns the [runtimeType] as [String].
  /// - This is an unsafe method and should be used only for debugging.
  /// - If the instance is a [WithRuntimeTypeNameSafe] will use [runtimeTypeNameSafe].
  String get runtimeTypeNameUnsafe {
    final self = this;
    if (self == null) {
      return 'Null';
    } else if (self is WithRuntimeTypeNameSafe) {
      return self.runtimeTypeNameSafe;
    } else {
      // ignore: no_runtimeType_toString
      return '${self.runtimeType}';
    }
  }
}

import 'dart:convert' as dart_convert;

import 'package:collection/collection.dart';
import 'package:reflection_factory/builder.dart';

/// JSON utility class.
class Json {
  /// Converts [o] to a JSON collection/data.
  /// - [maskField] when preset indicates if a field value should be masked with [maskText].
  static T? toJson<T>(Object? o,
      {bool Function(String key)? maskField,
      String maskText = '***',
      Object? Function(dynamic object)? toEncodable}) {
    if (o == null) {
      return null;
    }

    if (o is String || o is num || o is bool) {
      return o as T;
    }

    if (maskField != null) {
      if (o is Map) {
        o = _mapToJson(o, maskField, maskText);
      } else if (o is Iterable) {
        o = o.map((e) {
          return e is Map ? _mapToJson(o as Map, maskField, maskText) : e;
        }).toList();
      }
    }

    return o as T;
  }

  static Map<dynamic, dynamic> _mapToJson(
      Map o, bool Function(String key)? maskField, String maskText) {
    return o.map((key, value) =>
        MapEntry(key, _mapKeyToJson(key, value, maskField, maskText)));
  }

  static dynamic _mapKeyToJson(String k, dynamic o,
      bool Function(String key)? maskField, String maskText) {
    if (o == null) {
      return null;
    }

    if (maskField != null) {
      var masked = maskField(k);
      if (masked) {
        return maskText;
      }
    }

    if (o is String || o is num || o is bool) {
      return o;
    }

    if (o is Map) {
      return o.map((key, value) =>
          MapEntry(key, _mapKeyToJson(key, value, maskField, maskText)));
    } else if (o is Set) {
      return o.map((e) => _mapKeyToJson(k, e, maskField, maskText)).toSet();
    } else if (o is Iterable) {
      return o.map((e) => _mapKeyToJson(k, e, maskField, maskText)).toList();
    } else {
      try {
        return o.toJson();
      } catch (_) {
        return '$o';
      }
    }
  }

  /// Transforms [o] to an encoded JSON.
  /// - If [pretty] is `true` generates a pretty JSON, with indentation and line break.
  /// - [maskField] is the mask function. See [toJson].
  /// - [toEncodable] converts a not encodable [Object] to a encodable JSON collection/data. See [dart_convert.JsonEncoder].
  static String encode(Object? o,
      {bool pretty = false,
      bool Function(String key)? maskField,
      String maskText = '***',
      Object? Function(dynamic object)? toEncodable}) {
    if (pretty) {
      return dart_convert.JsonEncoder.withIndent('  ').convert(toJson(o,
          maskField: maskField, maskText: maskText, toEncodable: toEncodable));
    } else {
      return dart_convert.json.encode(toJson(o,
          maskField: maskField, maskText: maskText, toEncodable: toEncodable));
    }
  }

  /// Decodes [encodedJson] to a JSON collection/data.
  /// - [reviver] transforms a JSON value to another [Object]. See [dart_convert.JsonDecoder].
  static T decode<T>(String encodedJson,
          {Object? Function(Object? key, Object? value)? reviver}) =>
      dart_convert.json.decode(encodedJson, reviver: reviver);
}

typedef TypeElementParser<T> = T? Function(Object? o);

/// Lenient parsers for basic Dart types.
class TypeParser {
  /// Returns the parser for the desired type, defined by [T], [obj] or [type].
  static TypeElementParser? parserFor<T>({Object? obj, Type? type}) {
    if (obj != null) {
      if (obj is String) {
        return parseString;
      } else if (obj is Map) {
        return parseMap;
      } else if (obj is Set) {
        return parseSet;
      } else if (obj is List || obj is Iterable) {
        return parseList;
      } else if (obj is int) {
        return parseInt;
      } else if (obj is double) {
        return parseDouble;
      } else if (obj is num) {
        return parseNum;
      } else if (obj is bool) {
        return parseBool;
      } else if (obj is DateTime) {
        return parseDateTime;
      }
    }

    type ??= T;

    if (type == String) {
      return parseString;
    } else if (type == Map) {
      return parseMap;
    } else if (type == Set) {
      return parseSet;
    } else if (type == List || type == Iterable) {
      return parseList;
    } else if (type == int) {
      return parseInt;
    } else if (type == double) {
      return parseDouble;
    } else if (type == num) {
      return parseNum;
    } else if (type == bool) {
      return parseBool;
    } else if (type == DateTime) {
      return parseDateTime;
    }

    return null;
  }

  static final RegExp _regexpListDelimiter = RegExp(r'\s*[,;]\s*');

  /// Tries to parse a [List].
  /// - Returns [def] if [value] is `null` or an empty [String].
  /// - [elementParser] is an optional parser for the elements of the parsed [List].
  static List<T>? parseList<T>(Object? value,
      {List<T>? def, TypeElementParser<T>? elementParser}) {
    if (value == null) return def;

    var l = _parseListImpl(value);
    if (l == null) return def;

    if (elementParser != null) {
      l = l.map(elementParser).toList();
    }

    if (l is List<T>) {
      return l;
    } else if (elementParser != null) {
      l = l.whereType<T>().toList();
    } else {
      var parser = parserFor<T>();
      if (parser != null) {
        l = l.map(parser).toList();
      }
    }

    if (l is List<T>) {
      return l;
    } else {
      return l.whereType<T>().toList();
    }
  }

  static List? _parseListImpl<T>(Object value) {
    if (value is List) {
      return value;
    } else if (value is Iterable) {
      return value.toList();
    } else {
      var s = '$value'.trim();
      if (s.isEmpty) return null;
      var l = s.split(_regexpListDelimiter);
      return l;
    }
  }

  /// Tries to parse a [Set].
  ///
  /// See [parseList].
  static Set<T>? parseSet<T>(Object? value,
      {Set<T>? def, TypeElementParser<T>? elementParser}) {
    var l = parseList<T>(value, elementParser: elementParser);
    return l?.toSet() ?? def;
  }

  static final RegExp _regexpPairDelimiter = RegExp(r'\s*[;&]\s*');
  static final RegExp _regexpKeyValueDelimiter = RegExp(r'\s*[:=]\s*');

  /// Tries to parse a [Map].
  /// - Returns [def] if [value] is `null` or an empty [String].
  static Map<K, V>? parseMap<K, V>(Object? value,
      {Map<K, V>? def,
      TypeElementParser<K>? keyParser,
      TypeElementParser<V>? valueParser}) {
    if (value == null) return def;

    if (value is Map<K, V>) {
      return value;
    }

    keyParser ??= parserFor<K>() as TypeElementParser<K>?;
    keyParser ??= (k) => k as K;

    valueParser ??= parserFor<V>() as TypeElementParser<V>?;
    valueParser ??= (v) => v as V;

    if (value is Map) {
      return value
          .map((k, v) => MapEntry(keyParser!(k) as K, valueParser!(k) as V));
    } else if (value is Iterable) {
      return Map.fromEntries(value
          .map((e) => parseMapEntry<K, V>(e,
              keyParser: keyParser, valueParser: valueParser))
          .whereNotNull());
    } else {
      var s = '$value'.trim();
      if (s.isEmpty) return def;

      var pairs = s.split(_regexpPairDelimiter);
      return Map.fromEntries(pairs
          .map((e) => parseMapEntry<K, V>(e,
              keyParser: keyParser, valueParser: valueParser))
          .whereNotNull());
    }
  }

  /// Tries to parse a [MapEntry].
  /// - Returns [def] if [value] is `null` or an empty [String].
  static MapEntry<K, V>? parseMapEntry<K, V>(Object? value,
      {MapEntry<K, V>? def,
      TypeElementParser<K>? keyParser,
      TypeElementParser<V>? valueParser}) {
    if (value == null) return def;

    if (value is MapEntry<K, V>) {
      return value;
    }

    keyParser ??= parserFor<K>() as TypeElementParser<K>?;
    keyParser ??= (k) => k as K;

    valueParser ??= parserFor<V>() as TypeElementParser<V>?;
    valueParser ??= (v) => v as V;

    if (value is MapEntry) {
      return MapEntry(keyParser(value.key) as K, valueParser(value.value) as V);
    } else if (value is Iterable) {
      var k = value.elementAt(0);
      var v = value.elementAt(1);
      return MapEntry(keyParser(k) as K, valueParser(v) as V);
    } else {
      var s = '$value'.trim();
      if (s.isEmpty) return def;

      var idx = s.indexOf(_regexpKeyValueDelimiter);
      if (idx >= 0) {
        var k = s.substring(0, idx);
        var v = s.substring(idx + 1);
        return MapEntry(keyParser(k) as K, valueParser(v) as V);
      }
      return MapEntry(keyParser(s) as K, null as V);
    }
  }

  /// Tries to parse a [String].
  /// - Returns [def] if [value] is `null`.
  static String? parseString(Object? value, [String? def]) {
    if (value == null) return def;

    if (value is String) {
      return value;
    } else {
      return '$value';
    }
  }

  static final RegExp _regExpNotNumber = RegExp(r'[^0-9\.\+\-eENna]');

  /// Tries to parse an [int].
  /// - Returns [def] if [value] is invalid.
  static int? parseInt(Object? value, [int? def]) {
    if (value == null) return def;

    if (value is int) {
      return value;
    } else if (value is num) {
      return value.toInt();
    } else if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    } else {
      var n = _parseNumString(value);
      return n?.toInt() ?? def;
    }
  }

  static num? _parseNumString(Object value) {
    var s = _valueAsString(value);

    var n = num.tryParse(s);
    if (n == null) {
      s = s.replaceAll(_regExpNotNumber, '');
      n = num.tryParse(s);
    }

    return n;
  }

  static String _valueAsString(Object value) {
    String s;
    if (value is String) {
      s = value.trim();
    } else {
      s = '$value'.trim();
    }
    return s;
  }

  /// Tries to parse a [double].
  /// - Returns [def] if [value] is invalid.
  static double? parseDouble(Object? value, [double? def]) {
    if (value == null) return def;

    if (value is double) {
      return value;
    } else if (value is num) {
      return value.toDouble();
    } else if (value is DateTime) {
      return value.millisecondsSinceEpoch.toDouble();
    } else {
      var n = _parseNumString(value);
      return n?.toDouble() ?? def;
    }
  }

  /// Tries to parse a [num].
  /// - Returns [def] if [value] is invalid.
  static num? parseNum(Object? value, [num? def]) {
    if (value == null) return def;

    if (value is num) {
      return value;
    } else if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    } else {
      var n = _parseNumString(value);
      return n ?? def;
    }
  }

  /// Tries to parse a [bool].
  /// - Returns [def] if [value] is invalid.
  static bool? parseBool(Object? value, [bool? def]) {
    if (value == null) return def;

    if (value is bool) {
      return value;
    } else if (value is num) {
      return value > 0;
    } else {
      var s = _valueAsString(value).toLowerCase();
      if (s.isEmpty || s == 'null' || s == 'empty') return def;

      if (s == 'true' ||
          s == 't' ||
          s == 'yes' ||
          s == 'y' ||
          s == '1' ||
          s == '+' ||
          s == 'ok') {
        return true;
      }

      if (s == 'false' ||
          s == 'f' ||
          s == 'no' ||
          s == 'n' ||
          s == '0' ||
          s == '-1' ||
          s == '-' ||
          s == 'fail' ||
          s == 'error' ||
          s == 'err') {
        return false;
      }

      var n = _parseNumString(value);
      if (n != null) {
        return n > 0;
      }

      return def;
    }
  }

  /// Tries to parse a [DateTime].
  /// - Returns [def] if [value] is invalid.
  static DateTime? parseDateTime(Object? value, [DateTime? def]) {
    if (value == null) return def;

    if (value is DateTime) {
      return value;
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else {
      var s = '$value'.trim();
      return DateTime.tryParse(s) ?? def;
    }
  }

  /// Returns `true` if [type] is primitive ([String], [int], [double], [num], [bool]).
  static bool isPrimitiveType<T>([Type? type]) {
    type ??= T;
    return type == String ||
        type == int ||
        type == double ||
        type == num ||
        type == bool;
  }
}

/// Represents a [Type] and its [arguments].
class TypeInfo {
  static final TypeInfo tString = TypeInfo.from(String);
  static final TypeInfo tBool = TypeInfo.from(bool);
  static final TypeInfo tInt = TypeInfo.from(int);
  static final TypeInfo tDouble = TypeInfo.from(double);
  static final TypeInfo tNum = TypeInfo.from(num);

  /// The main [Type].
  final Type type;

  /// The [type] arguments (generics).
  final List<TypeInfo> arguments;

  static final _emptyArguments = List<TypeInfo>.unmodifiable([]);

  TypeInfo(this.type, [Iterable<Object>? arguments])
      : arguments = arguments == null || arguments.isEmpty
            ? _emptyArguments
            : List<TypeInfo>.unmodifiable(
                arguments.map((o) => TypeInfo.from(o)));

  factory TypeInfo.from(Object o) {
    if (o is TypeInfo) return o;
    if (o is Type) return TypeInfo(o);

    if (o is FieldReflection) {
      return TypeInfo(
          o.type.type, o.type.arguments.map((o) => TypeInfo.from(o)));
    }

    return TypeInfo(o.runtimeType);
  }

  /// The [arguments] length.
  int get argumentsLength => arguments.length;

  /// Returns `true` if [type] has [arguments].
  bool get hasArguments => arguments.isNotEmpty;

  /// Returns the [type] parser.
  ///
  /// See [TypeParser.parserFor].
  TypeElementParser? get parser => TypeParser.parserFor(type: type);

  /// Returns the parser of the argument at [index].
  TypeElementParser? argumentParser(int index) =>
      index < argumentsLength ? arguments[index].parser : null;

  /// Parse [value] or return [def].
  ///
  /// See [TypeParser.parserFor].
  T? parse<T>(Object? value, [T? def]) {
    if (value == null) return def;

    switch (type) {
      case String:
        return TypeParser.parseString(value, def as String?) as T?;
      case int:
        return TypeParser.parseInt(value, def as int?) as T?;
      case double:
        return TypeParser.parseDouble(value, def as double?) as T?;
      case num:
        return TypeParser.parseNum(value, def as num?) as T?;
      case DateTime:
        return TypeParser.parseDateTime(value, def as DateTime?) as T?;
      case List:
      case Iterable:
        return TypeParser.parseList(value, elementParser: argumentParser(0))
            as T?;
      case Set:
        return TypeParser.parseSet(value, elementParser: argumentParser(0))
            as T?;
      case Map:
        return TypeParser.parseMap(value,
            keyParser: argumentParser(0), valueParser: argumentParser(1)) as T?;
      case MapEntry:
        return TypeParser.parseMapEntry(value,
            keyParser: argumentParser(0), valueParser: argumentParser(1)) as T?;
      default:
        {
          if (value.runtimeType == type) {
            return value as T;
          }

          return null;
        }
    }
  }

  /// Returns `true` if [type] is primitive.
  ///
  /// See [TypeParser.isPrimitiveType].
  bool get isPrimitiveType => TypeParser.isPrimitiveType(type);

  /// Returns `true` if [type] is [List].
  bool get isList => type == List;

  /// Returns `true` if [type] is a [List] of entities.
  bool get isListEntity =>
      isList && hasArguments && !arguments.first.isPrimitiveType;

  /// The [TypeInfo] of the [List] elements type.
  TypeInfo? get listEntityType => isListEntity ? arguments.first : null;

  @override
  String toString() {
    return hasArguments ? '$type<${arguments.join(',')}>' : '$type';
  }
}

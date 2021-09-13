import 'dart:convert' as dart_convert;

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

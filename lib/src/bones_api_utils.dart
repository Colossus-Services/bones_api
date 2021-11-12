import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_mixin.dart';
import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';

typedef ToEncodable = Object? Function(Object? object);

/// JSON utility class.
class Json {
  /// A standard implementation of mask filed.
  ///
  /// - [extraKeys] is the extra keys to mask.
  static bool standardJsonMaskField(String key, {Iterable<String>? extraKeys}) {
    key = key.trim().toLowerCase();
    return key == 'password' ||
        key == 'pass' ||
        key == 'passwordhash' ||
        key == 'passhash' ||
        key == 'passphrase' ||
        key == 'ping' ||
        key == 'secret' ||
        key == 'privatekey' ||
        key == 'pkey' ||
        (extraKeys != null && extraKeys.contains(key));
  }

  /// Converts [o] to a JSON collection/data.
  /// - [maskField] when preset indicates if a field value should be masked with [maskText].
  static T? toJson<T>(Object? o,
      {JsonFieldMatcher? maskField,
      String maskText = '***',
      JsonFieldMatcher? removeField,
      bool removeNullFields = false,
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonCodec = _buildJsonEncoder(maskField, maskText, removeField,
        removeNullFields, toEncodable, entityHandlerProvider);

    return jsonCodec.toJson(o);
  }

  /// Transforms [o] to an encoded JSON.
  /// - If [pretty] is `true` generates a pretty JSON, with indentation and line break.
  /// - [maskField] is the mask function. See [toJson].
  /// - [toEncodable] converts a not encodable [Object] to a encodable JSON collection/data. See [dart_convert.JsonEncoder].
  static String encode(Object? o,
      {bool pretty = false,
      JsonFieldMatcher? maskField,
      String maskText = '***',
      JsonFieldMatcher? removeField,
      bool removeNullFields = false,
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonEncoder = _buildJsonEncoder(maskField, maskText, removeField,
        removeNullFields, toEncodable, entityHandlerProvider);

    return jsonEncoder.encode(o, pretty: pretty);
  }

  /// Sames as [encode] but returns a [Uint8List].
  static Uint8List encodeToBytes(Object? o,
      {bool pretty = false,
      JsonFieldMatcher? maskField,
      String maskText = '***',
      JsonFieldMatcher? removeField,
      bool removeNullFields = false,
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonEncoder = _buildJsonEncoder(maskField, maskText, removeField,
        removeNullFields, toEncodable, entityHandlerProvider);

    return jsonEncoder.encodeToBytes(o, pretty: pretty);
  }

  static final JsonEncoder defaultEncoder =
      JsonEncoder(toEncodableProvider: (o) => _jsonEncodableProvider(o, null));

  static JsonEncoder _buildJsonEncoder(
      JsonFieldMatcher? maskField,
      String maskText,
      JsonFieldMatcher? removeField,
      bool removeNullFields,
      ToEncodable? toEncodable,
      EntityHandlerProvider? entityHandlerProvider) {
    if (entityHandlerProvider == null &&
        toEncodable == null &&
        !removeNullFields &&
        removeField == null &&
        maskField == null) {
      return defaultEncoder;
    }

    return JsonEncoder(
        maskField: maskField,
        maskText: maskText,
        removeField: removeField,
        removeNullFields: removeNullFields,
        toEncodable: toEncodable == null ? null : (o, j) => toEncodable(o),
        toEncodableProvider: (o) =>
            _jsonEncodableProvider(o, entityHandlerProvider));
  }

  static ToEncodableJson? _jsonEncodableProvider(
      Object object, EntityHandlerProvider? entityHandlerProvider) {
    var oType = object.runtimeType;

    if (entityHandlerProvider != null) {
      var entityHandler = entityHandlerProvider.getEntityHandler(type: oType);

      if (entityHandler != null) {
        return (o, j) => entityHandler.getFields(o);
      }
    }

    var entityHandler =
        EntityHandlerProvider.globalProvider.getEntityHandler(type: oType);

    if (entityHandler != null) {
      return (o, j) => entityHandler.getFields(o);
    }
  }

  /// Converts [o] to [type].
  static T? fromJson<T>(Object? o,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.fromJson<T>(o, type: type);
  }

  /// Converts [o] to [type] allowing async calls ([Future] and [FutureOr]).
  static FutureOr<T?> fromJsonAsync<T>(Object? o,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.fromJsonAsync<T>(o, type: type);
  }

  /// Converts [o] to as [List] of [type].
  static List<T?> fromJsonList<T>(Iterable o,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.fromJsonList<T>(o, type: type);
  }

  /// Converts [o] to as [List] of [type] allowing async calls ([Future] and [FutureOr]).
  static FutureOr<List<T?>> fromJsonListAsync<T>(FutureOr<Iterable> o,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.fromJsonListAsync<T>(o, type: type);
  }

  /// Converts [map] to [type].
  static T fromJsonMap<T>(Map<String, Object?> map,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.fromJsonMap<T>(map, type: type);
  }

  /// Converts [map] to [type] allowing async calls ([Future] and [FutureOr]).
  static FutureOr<T> fromJsonMapAsync<T>(FutureOr<Map<String, Object?>> map,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.fromJsonMapAsync<T>(map, type: type);
  }

  /// Decodes [encodedJson] to a JSON collection/data.
  static T decode<T>(String encodedJson,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.decode(encodedJson, type: type);
  }

  /// Sames as [decode] but from a [Uint8List].
  static T decodeFromBytes<T>(Uint8List encodedJsonBytes,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.decodeFromBytes(encodedJsonBytes, type: type);
  }

  /// Decodes [encodedJson] to a JSON collection/data accepting async values.
  static FutureOr<T> decodeAsync<T>(FutureOr<String> encodedJson,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.decodeAsync(encodedJson, type: type);
  }

  /// Sames as [decodeAsync] but from a [Uint8List].
  static FutureOr<T> decodeFromBytesAsync<T>(
      FutureOr<Uint8List> encodedJsonBytes,
      {Type? type,
      JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider}) {
    var jsonDecoder = _buildJsonDecoder(jsomMapDecoder, entityHandlerProvider);

    return jsonDecoder.decodeFromBytesAsync(encodedJsonBytes, type: type);
  }

  static final JsonDecoder defaultDecoder = JsonDecoder(
    jsomMapDecoderAsyncProvider: (m) => _jsomMapDecoderAsyncProvider(m, null),
  );

  static JsonDecoder _buildJsonDecoder(JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider) {
    if (jsomMapDecoder == null && entityHandlerProvider == null) {
      return defaultDecoder;
    }

    return JsonDecoder(
        jsomMapDecoder: jsomMapDecoder,
        jsomMapDecoderAsyncProvider: (m) =>
            _jsomMapDecoderAsyncProvider(m, entityHandlerProvider),
        iterableCaster: (v, t) => _iterableCaster(v, t, entityHandlerProvider));
  }

  static JsomMapDecoderAsync? _jsomMapDecoderAsyncProvider(
      Object identifier, EntityHandlerProvider? entityHandlerProvider) {
    var type = identifier is Type ? identifier : identifier.runtimeType;

    if (entityHandlerProvider != null) {
      var entityHandler = entityHandlerProvider.getEntityHandler(type: type);

      if (entityHandler != null) {
        return (m, j) => entityHandler.createFromMap(m);
      }
    }

    var classReflection = ReflectionFactory().getRegisterClassReflection(type);

    if (classReflection != null) {
      return (m, j) => classReflection.createInstanceFromMap(m,
          fieldNameResolver: defaultFieldNameResolver,
          fieldValueResolver: (f, v, t) =>
              defaultFieldValueResolver(f, v, t, j, entityHandlerProvider));
    }

    var entityHandler =
        EntityHandlerProvider.globalProvider.getEntityHandler(type: type);

    if (entityHandler != null) {
      return (m, j) => entityHandler.createFromMap(m);
    }
  }

  static String defaultFieldNameResolver(
      String field, Map<String, Object?> map) {
    if (map.containsKey(field)) {
      return field;
    }

    var fieldLC = field.toLowerCase();
    if (map.containsKey(fieldLC)) {
      return fieldLC;
    }

    var fieldSimple = FieldsFromMap.defaultFieldToSimpleKey(field);
    if (map.containsKey(fieldSimple)) {
      return fieldSimple;
    }

    for (var k in map.keys) {
      if (equalsIgnoreAsciiCase(fieldLC, k)) {
        return k;
      }

      if (equalsIgnoreAsciiCase(fieldSimple, k)) {
        return k;
      }
    }

    return field;
  }

  static Object? defaultFieldValueResolver(
      String field,
      Object? value,
      TypeReflection type,
      JsonDecoder jsonDecoder,
      EntityHandlerProvider? entityHandlerProvider) {
    if (type.isListEntity && value is Iterable) {
      return _iterableCaster(value, type, entityHandlerProvider);
    } else {
      return jsonDecoder.fromJson(value, type: type.type);
    }
  }

  static Object? _iterableCaster(Iterable value, TypeReflection type,
      EntityHandlerProvider? entityHandlerProvider) {
    if (entityHandlerProvider != null) {
      var entityType = type.isListEntity ? type.listEntityType! : type;
      var entityHandler =
          entityHandlerProvider.getEntityHandler(type: entityType.type);

      if (entityHandler != null) {
        return entityHandler.castIterable(value, entityType.type);
      }
    }

    return null;
  }
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

  /// Parses [value] using a [parserFor] [type].
  /// Returns [value] if can't parse.
  static V? parseValueForType<V>(Type type, Object? value, [V? def]) {
    if (value == null) return def;

    if (value.runtimeType == type) {
      return value as V;
    }

    var parser = parserFor(type: type);

    if (parser != null) {
      var parsed = parser(value);
      return parsed ?? def;
    } else {
      return def;
    }
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
    if (s.isEmpty) {
      return null;
    }

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

  /// Returns `true` if [type] is primitive ([String], [int], [double], [num] or [bool]).
  static bool isPrimitiveType<T>([Type? type]) {
    type ??= T;
    return type == String ||
        type == int ||
        type == double ||
        type == num ||
        type == bool;
  }

  /// Returns `true` if [value] is primitive ([String], [int], [double], [num] or [bool]).
  static bool isPrimitiveValue(Object value) {
    return value is String ||
        value is int ||
        value is double ||
        value is num ||
        value is bool;
  }

  /// Returns `true` if [type] is a collection ([List], [Iterable], [Map] or [Set]).
  static bool isCollectionType<T>([Type? type]) {
    type ??= T;
    return type == List || type == Iterable || type == Map || type == Set;
  }

  /// Returns `true` if [value] is a collection ([List], [Iterable], [Map] or [Set]).
  static bool isCollectionValue(Object value) {
    return value is List || value is Iterable || value is Map || value is Set;
  }
}

/// Represents a [Type] and its [arguments].
class TypeInfo {
  static bool accepts<T>(Type type) {
    return T == type || T == Object || T == dynamic;
  }

  static final TypeInfo tString = TypeInfo.from(String);
  static final TypeInfo tBool = TypeInfo.from(bool);
  static final TypeInfo tInt = TypeInfo.from(int);
  static final TypeInfo tDouble = TypeInfo.from(double);
  static final TypeInfo tNum = TypeInfo.from(num);

  static final TypeInfo tAPIRequest = TypeInfo.from(APIRequest);
  static final TypeInfo tAPIResponse = TypeInfo.from(APIResponse);

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

    if (o is TypeReflection) {
      return TypeInfo(o.type, o.arguments.map((o) => TypeInfo.from(o)));
    }

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

  /// Returns the [TypeInfo] of the argument at [index].
  TypeInfo? argumentType(int index) =>
      index < argumentsLength ? arguments[index] : null;

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
      case bool:
        return TypeParser.parseBool(value, def as bool?) as T?;
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

  /// Returns `true` if [type] is `int`.
  bool get isInt => type == int;

  /// Returns `true` if [type] is `double`.
  bool get isDouble => type == double;

  /// Returns `true` if [type] is `num`.
  bool get isNum => type == num;

  /// Returns `true` if [type] is `int`, `double` or `num`.
  bool get isNumber => isInt || isDouble || isNum;

  /// Returns `true` if [type] is `String`.
  bool get isString => type == String;

  /// Returns `true` if [type] is a [List].
  bool get isList => type == List;

  /// Returns `true` if [type] is a [Iterable].
  bool get isIterable => type == Iterable;

  /// Returns `true` if [type] is a [Map].
  bool get isMap => type == Map;

  /// Returns `true` if [type] is a [Set].
  bool get isSet => type == Set;

  /// Returns `true` if [type] is a collection ([List], [Iterable], [Map] or [Set]).
  bool get isCollection => isList || isIterable || isMap || isSet;

  /// Returns `true` if [type] [isPrimitiveType] or [isCollection].
  bool get isBasicType => isPrimitiveType || isCollection;

  /// Returns `true` if [type] is a [List] of entities.
  bool get isListEntity =>
      isList && hasArguments && !arguments.first.isPrimitiveType;

  /// The [TypeInfo] of the [List] elements type.
  TypeInfo? get listEntityType => isListEntity ? arguments.first : null;

  TypeReflection? _typeReflection;

  /// Returns this instance as [TypeReflection].
  TypeReflection get asTypeReflection =>
      _typeReflection ??= TypeReflection(type, arguments);

  static final ListEquality<TypeInfo> _listTypeInfoEquality =
      ListEquality<TypeInfo>();

  /// Returns `true` if this instances has the same [type] and [arguments].
  bool isOf(Type type, [List<TypeInfo>? arguments]) =>
      this.type == type &&
      (arguments != null && arguments.isNotEmpty) &&
      hasArguments &&
      _listTypeInfoEquality.equals(arguments, arguments);

  @override
  String toString() {
    var typeStr = type.toString();
    var idx = typeStr.indexOf('<');
    if (idx > 0) typeStr = typeStr.substring(0, idx);

    return hasArguments ? '$typeStr<${arguments.join(',')}>' : typeStr;
  }
}

/// A [Map] where the keys have a put time ([DateTime]) and also can expire.
class TimedMap<K, V> implements Map<K, V> {
  /// The key timeout. When a key is put, it expires after the timeout [Duration].
  final Duration keyTimeout;

  TimedMap(this.keyTimeout, [Map<K, V>? map]) {
    if (map != null) {
      addAll(map);
    }
  }

  final Map<K, V> _entries = <K, V>{};

  final Map<K, DateTime> _entriesPutTime = <K, DateTime>{};

  @override
  String toString() => _entries.toString();

  /// Sets a [key] [value]. See [put].
  @override
  void operator []=(K key, V value) {
    _entries[key] = value;
    _entriesPutTime[key] = DateTime.now();
  }

  /// Sets a [key] [value].
  void put(K key, V value, {DateTime? now}) {
    _entries[key] = value;
    _entriesPutTime[key] = now ?? DateTime.now();
  }

  /// Returns a [key] without check [keyTimeout]. See [getChecked].
  @override
  V? operator [](Object? key) {
    return _entries[key];
  }

  /// Returns the time ([DateTime]) of a [key].
  DateTime? getTime(Object? key) {
    return _entriesPutTime[key];
  }

  /// Returns a [key] checking [keyTimeout].
  ///
  /// - If the parameter [keyTimeout] is not provided the class field `this.keyTimeout` is used.
  V? getChecked(K key, {DateTime? now, Duration? keyTimeout}) {
    if (!checkEntry(key, now: now, keyTimeout: keyTimeout)) {
      return _entries[key];
    } else {
      return null;
    }
  }

  /// Returns the keys of this instance, without check [keyTimeout].
  /// See [checkAllEntries].
  @override
  Iterable<K> get keys => _entries.keys;

  /// Returns the values of this instance, without check [keyTimeout].
  /// See [checkAllEntries].
  @override
  Iterable<V> get values => _entries.values;

  /// Returns the entries of this instance, without check [keyTimeout].
  /// See [checkAllEntries].
  @override
  Iterable<MapEntry<K, V>> get entries => _entries.entries;

  /// Returns the keys of this instance checking [keyTimeout].
  /// See [checkAllEntries].
  List<K> keysChecked({DateTime? now, Duration? keyTimeout}) {
    now ??= DateTime.now();
    keyTimeout ??= this.keyTimeout;

    var keys = _entries.keys.toList(growable: false);
    return keys
        .where((k) => !checkEntry(k, now: now, keyTimeout: keyTimeout))
        .toList();
  }

  /// Returns the values of this instance checking [keyTimeout].
  /// See [checkAllEntries].
  List<V> valuesChecked({DateTime? now, Duration? keyTimeout}) =>
      keysChecked(now: now, keyTimeout: keyTimeout)
          .map((k) => _entries[k]!)
          .toList();

  /// Returns the entries of this instance checking [keyTimeout].
  /// See [checkAllEntries].
  List<MapEntry<K, V>> entriesChecked({DateTime? now, Duration? keyTimeout}) =>
      keysChecked(now: now, keyTimeout: keyTimeout)
          .map((k) => MapEntry(k, _entries[k]!))
          .toList();

  /// Checks all the entries of this instance.
  ///
  /// - If the parameter [keyTimeout] is not provided the class field `this.keyTimeout` is used.
  int checkAllEntries({DateTime? now, Duration? keyTimeout}) {
    now ??= DateTime.now();
    keyTimeout ??= this.keyTimeout;

    var keys = _entries.keys.toList(growable: false);

    var count = 0;
    for (var k in keys) {
      if (checkEntry(k, now: now, keyTimeout: keyTimeout)) {
        count++;
      }
    }
    return count;
  }

  /// Check the [key] entry timeout. Returns `true` if the [key] expired.
  ///
  /// - If the parameter [keyTimeout] is not provided the class field `this.keyTimeout` is used.
  bool checkEntry(Object? key, {DateTime? now, Duration? keyTimeout}) {
    if (isEntryExpired(key, now: now, keyTimeout: keyTimeout)) {
      _entries.remove(key);
      _entriesPutTime.remove(key);
      return true;
    } else {
      return false;
    }
  }

  /// Returns `true` if the [key] entry is expired (reached the timeout).
  ///
  /// - If the parameter [keyTimeout] is not provided the class field `this.keyTimeout` is used.
  bool isEntryExpired(Object? key, {DateTime? now, Duration? keyTimeout}) {
    var elapsedTime = getElapsedTime(key, now: now);
    if (elapsedTime == null) return false;

    keyTimeout ??= this.keyTimeout;
    return elapsedTime.inMilliseconds > keyTimeout.inMilliseconds;
  }

  /// Returns the elapsed time of [key], since the put.
  Duration? getElapsedTime(Object? key, {DateTime? now}) {
    var time = getTime(key);
    if (time == null) return null;

    now ??= DateTime.now();
    var elapsedTime = now.difference(time);
    return elapsedTime;
  }

  @override
  V? remove(Object? key) {
    var t = _entriesPutTime.remove(key);
    if (t != null) {
      return _entries.remove(key);
    } else {
      return null;
    }
  }

  /// Removes keys where [test] returns `true`. See [removeWhereTimed].
  @override
  void removeWhere(bool Function(K key, V value) test) =>
      removeWhereTimed((key, value, time) => test(key, value));

  /// Removes keys where [test] returns `true`. See [removeWhere].
  void removeWhereTimed(bool Function(K key, V value, DateTime time) test) {
    var keys = _entries.keys.toList(growable: false);

    for (var k in keys) {
      var t = _entriesPutTime[k];

      if (t != null) {
        var v = _entries[k]!;

        if (test(k, v, t)) {
          _entries.remove(k);
          _entriesPutTime.remove(k);
        }
      }
    }
  }

  @override
  void addAll(Map<K, V> other) => addEntries(other.entries);

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    var now = DateTime.now();
    for (var e in newEntries) {
      put(e.key, e.value, now: now);
    }
  }

  @override
  Map<RK, RV> cast<RK, RV>() => _entries.cast<RK, RV>();

  @override
  void clear() {
    _entries.clear();
    _entriesPutTime.clear();
  }

  @override
  bool containsKey(Object? key) => _entries.containsKey(key);

  @override
  bool containsValue(Object? value) => _entries.containsValue(value);

  @override
  void forEach(void Function(K key, V value) action) =>
      _entries.forEach(action);

  @override
  bool get isEmpty => _entries.isEmpty;

  @override
  bool get isNotEmpty => _entries.isNotEmpty;

  @override
  int get length => _entries.length;

  @override
  TimedMap<K2, V2> map<K2, V2>(
          MapEntry<K2, V2> Function(K key, V value) convert) =>
      TimedMap<K2, V2>(keyTimeout, _entries.map(convert));

  @override
  V putIfAbsent(K key, V Function() ifAbsent) => _entries.putIfAbsent(key, () {
        var v = ifAbsent();
        _entriesPutTime[key] = DateTime.now();
        return v;
      });

  /// Same as [putIfAbsent], but calls [checkEntry] first.
  V putIfAbsentChecked(K key, V Function() ifAbsent,
      {DateTime? now, Duration? keyTimeout}) {
    checkEntry(key, now: now, keyTimeout: keyTimeout);
    return putIfAbsent(key, ifAbsent);
  }

  /// Same as [putIfAbsentChecked], but accepts an async function for [ifAbsent].
  FutureOr<V> putIfAbsentCheckedAsync(K key, FutureOr<V> Function() ifAbsent,
      {DateTime? now, Duration? keyTimeout}) {
    if (checkEntry(key, now: now, keyTimeout: keyTimeout)) {
      return ifAbsent().resolveMapped((val) {
        put(key, val, now: now);
        return val;
      });
    } else {
      var t = _entriesPutTime[key];
      if (t == null) {
        return ifAbsent().resolveMapped((val) {
          put(key, val, now: now);
          return val;
        });
      } else {
        return _entries[key]!;
      }
    }
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) =>
      _entries.update(key, (V v) {
        v = update(v);
        _entriesPutTime[key] = DateTime.now();
        return v;
      }, ifAbsent: () {
        var v = ifAbsent!();
        _entriesPutTime[key] = DateTime.now();
        return v;
      });

  /// Same as [update], but calls [checkEntry] first.
  V updateTimed(K key, V Function(V value) update,
      {V Function()? ifAbsent, DateTime? now, Duration? keyTimeout}) {
    checkEntry(key, now: now, keyTimeout: keyTimeout);
    return this.update(key, update, ifAbsent: ifAbsent);
  }

  @override
  void updateAll(V Function(K key, V value) update) =>
      updateAllTimed((k, v, t) => update(k, v));

  /// Same as [updateAll], but with an extra parameter [time] in function [update].
  void updateAllTimed(V Function(K key, V value, DateTime time) update) {
    var keys = _entries.keys.toList(growable: false);

    for (var k in keys) {
      var t = _entriesPutTime[k];

      if (t != null) {
        var v = _entries[k]!;
        var v2 = update(k, v, t);

        _entries[k] = v2;
        _entriesPutTime[k] = DateTime.now();
      }
    }
  }
}

/// Helper to work with positional fields.
class PositionalFields {
  late final Set<String> _fields;
  late final List<String> _fieldsOrder;
  final Map<String, int> _fieldsIndexes = <String, int>{};

  PositionalFields(Iterable<String> fields) {
    var list = fields.toList();
    _fields = Set<String>.unmodifiable(list.toSet());

    if (list.length != _fields.length) {
      throw ArgumentError("fields not uniques: $fields");
    }

    _fieldsOrder = List<String>.unmodifiable(list);

    for (var i = 0; i < list.length; ++i) {
      var f = list[i];
      _fieldsIndexes[f] = i;
    }
  }

  /// The fields names.
  Set<String> get fields => _fields;

  /// The fields order.
  List<String> get fieldsOrder => _fieldsOrder;

  /// Returns the index of a [field].
  int? getFieldIndex(String field) => _fieldsIndexes[field];

  /// Returns a [field] value from [row].
  V? get<V>(String field, Iterable<Object?> row) {
    var idx = getFieldIndex(field);
    if (idx == null) return null;

    var val = row.elementAt(idx);
    return val as V?;
  }

  /// Returns a [field] [MapEntry] from [row].
  MapEntry<String, V?>? getMapEntry<V>(String field, Iterable<Object?> row) {
    var idx = getFieldIndex(field);
    if (idx == null) return null;

    var val = row.elementAt(idx);
    return MapEntry(field, val as V?);
  }

  /// Converts [row] to a collection of [MapEntry].
  Iterable<MapEntry<String, Object?>> toEntries(Iterable<Object?> row) =>
      fieldsOrder.map((f) => getMapEntry<Object>(f, row)).whereNotNull();

  /// Converts [row] to a [Map].
  Map<String, Object?> toMap(Iterable<Object?> row) =>
      Map<String, Object?>.fromEntries(toEntries(row));

  /// Converts [rows] to a list of [Map].
  List<Map<String, Object?>> toListOfMap(Iterable<Iterable<Object?>> rows) =>
      rows.map((r) => toMap(r)).toList();
}

typedef ValueEquality = bool Function(Object v1, Object v2);

/// Returns [true] if [o1] and [o2] are equals deeply.
bool isEqualsDeep(Object? o1, Object? o2, {ValueEquality? valueEquality}) {
  if (identical(o1, o2)) return true;

  if (o1 == null) return o2 == null;
  if (o2 == null) return false;

  if (o1 is List) {
    if (o2 is List) {
      return isEqualsListDeep(o1, o2, valueEquality: valueEquality);
    }
    return false;
  } else if (o1 is Map) {
    if (o2 is Map) {
      return isEqualsMapDeep(o1, o2, valueEquality: valueEquality);
    }
    return false;
  } else if (o1 is Set) {
    if (o2 is Set) {
      return isEqualsSetDeep(o1, o2, valueEquality: valueEquality);
    }
    return false;
  } else if (o1 is Iterable) {
    if (o2 is Iterable) {
      return isEqualsIterableDeep(o1, o2, valueEquality: valueEquality);
    }
    return false;
  }

  if (valueEquality != null) {
    return valueEquality(o1, o2);
  } else {
    return o1 == o2;
  }
}

/// Returns [true] if [l1] and [l2] are equals deeply (including values tree equality).
bool isEqualsListDeep(List? l1, List? l2, {ValueEquality? valueEquality}) {
  if (identical(l1, l2)) return true;

  if (l1 == null) return false;
  if (l2 == null) return false;

  var length = l1.length;
  if (length != l2.length) return false;

  for (var i = 0; i < length; ++i) {
    var v1 = l1[i];
    var v2 = l2[i];

    if (!isEqualsDeep(v1, v2, valueEquality: valueEquality)) return false;
  }

  return true;
}

/// Same as [isEqualsListDeep] but for [Iterable].
bool isEqualsIterableDeep(Iterable? it1, Iterable? it2,
    {ValueEquality? valueEquality}) {
  if (identical(it1, it2)) return true;

  if (it1 == null) return false;
  if (it2 == null) return false;

  var length = it1.length;
  if (length != it2.length) return false;

  for (var i = 0; i < length; i++) {
    var v1 = it1.elementAt(i);
    var v2 = it2.elementAt(i);

    if (!isEqualsDeep(v1, v2, valueEquality: valueEquality)) return false;
  }

  return true;
}

/// Same as [isEqualsListDeep] but for [Set].
bool isEqualsSetDeep(Set? set1, Set? set2, {ValueEquality? valueEquality}) {
  if (identical(set1, set2)) return true;

  if (set1 == null) return false;
  if (set2 == null) return false;

  var length = set1.length;
  if (length != set2.length) return false;

  var l1 = set1.toList();
  var l2 = set2.toList();

  l1.sort();
  l2.sort();

  return isEqualsListDeep(l1, l2, valueEquality: valueEquality);
}

/// Returns [true] if [m1] and [m2] are equals deeply (including values tree equality).
bool isEqualsMapDeep(Map? m1, Map? m2, {ValueEquality? valueEquality}) {
  if (identical(m1, m2)) return true;

  if (m1 == null) return false;
  if (m2 == null) return false;

  if (m1.length != m2.length) return false;

  var k1 = List.from(m1.keys);
  var k2 = List.from(m2.keys);

  k1.sort();
  k2.sort();

  if (!isEqualsListDeep(k1, k2, valueEquality: valueEquality)) return false;

  for (var k in k1) {
    var v1 = m1[k];
    var v2 = m2[k];

    if (!isEqualsDeep(v1, v2, valueEquality: valueEquality)) return false;
  }

  return true;
}

/// Returns an [Enum] name.
String enumToName(Enum enumValue) {
  var s = enumValue.toString();
  var idx = s.indexOf('.');
  var name = s.substring(idx + 1);
  return name;
}

/// Returns an [Enum] from [enumValues] that matches [name].
Enum? enumFromName(String name, Iterable<Enum> enumValues) {
  for (var e in enumValues) {
    var n = enumToName(e);
    if (n == name) {
      return e;
    }
  }
  return null;
}

typedef InstanceInfoExtractor<O, I> = I Function(O o);

/// Tracks an instance with a info relationship.
///
/// Uses [Expando].
class InstanceTracker<O extends Object, I extends Object> {
  /// Name of this instance tracker.
  final String name;

  /// The info extractor.
  final InstanceInfoExtractor<O, I> instanceInfoExtractor;

  final Expando<I> _instancesInfo;

  InstanceTracker(this.name, this.instanceInfoExtractor)
      : _instancesInfo = Expando(name);

  /// Extract the info of instance [o].
  I extractInfo(O o) => instanceInfoExtractor(o);

  /// Returns `true` if instance [o] is tracked.
  bool isTrackedInstance(O o) => getTrackedInstanceInfo(o) != null;

  /// returns the [o] info, if tracked.
  I? getTrackedInstanceInfo(O o) {
    var trackedInfo = _instancesInfo[o];
    return trackedInfo;
  }

  /// Tracks instance [o]
  O trackInstance(O o) {
    var info = extractInfo(o);

    _instancesInfo[o] = info;

    return o;
  }

  /// Untracks instance [o].
  void untrackInstance(O? o) {
    if (o == null) return;

    _instancesInfo[o] = null;
  }

  /// Same as [trackInstance] with a nullable [o].
  O? trackInstanceNullable(O? o) {
    return o != null ? trackInstance(o) : null;
  }

  /// Tracks instances [os].
  List<O> trackInstances(Iterable<O> os) {
    return os.map((o) => trackInstance(o)).toList();
  }

  /// Same as [trackInstanceNullable] with a nullable [os].
  List<O?> trackInstancesNullable(Iterable<O?> os) {
    return os.map((o) => trackInstanceNullable(o)).toList();
  }

  /// Untrack instances [os].
  void untrackInstances(Iterable<O?> os) {
    for (var o in os) {
      untrackInstance(o);
    }
  }
}

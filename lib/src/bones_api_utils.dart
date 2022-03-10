import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:data_serializer/data_serializer.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_entity.dart';
import 'bones_api_mixin.dart';

typedef ToEncodable = Object? Function(Object? object);

/// JSON utility class.
class Json {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    Time.boot();
  }

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
    if (object is Time) {
      return (o, j) => object.toString();
    }

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

    return null;
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
    jsonValueDecoderProvider: _jsonValueDecoderProvider,
    jsomMapDecoderAsyncProvider: (type, map) =>
        _jsomMapDecoderAsyncProvider(type, null),
  );

  static JsonDecoder _buildJsonDecoder(JsomMapDecoder? jsomMapDecoder,
      EntityHandlerProvider? entityHandlerProvider) {
    if (jsomMapDecoder == null && entityHandlerProvider == null) {
      return defaultDecoder;
    }

    return JsonDecoder(
        jsonValueDecoderProvider: _jsonValueDecoderProvider,
        jsomMapDecoder: jsomMapDecoder,
        jsomMapDecoderAsyncProvider: (type, map) =>
            _jsomMapDecoderAsyncProvider(type, entityHandlerProvider),
        iterableCaster: (v, t) => _iterableCaster(v, t, entityHandlerProvider));
  }

  static JsonValueDecoder<O>? _jsonValueDecoderProvider<O>(
      Type type, Object? value) {
    if (type == Time) {
      return (o, t, j) {
        var time = Time.from(o);
        return time as O?;
      };
    }

    return null;
  }

  static JsomMapDecoderAsync? _jsomMapDecoderAsyncProvider(
      Type type, EntityHandlerProvider? entityHandlerProvider) {
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

    return null;
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

/// A [Time] represents the time of the day,
/// independently of the day of the year, timezone or [DateTime].
class Time implements Comparable<Time> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    JsonDecoder.registerTypeDecoder(Time, (o) => Time.from(o));
  }

  int hour;
  int minute = 0;
  int second = 0;
  int millisecond = 0;
  int microsecond = 0;

  Time(this.hour,
      [this.minute = 0,
      this.second = 0,
      this.millisecond = 0,
      this.microsecond = 0]) {
    if (hour < 0 || hour > 24) {
      throw ArgumentError.value(hour, 'hour', 'Not in range: 0..24');
    }

    if (minute < 0 || minute > 59) {
      throw ArgumentError.value(minute, 'minute', 'Not in range: 0..59');
    }

    if (second < 0 || second > 59) {
      throw ArgumentError.value(second, 'second', 'Not in range: 0..59');
    }

    if (millisecond < 0 || millisecond > 1000) {
      throw ArgumentError.value(
          millisecond, 'millisecond', 'Not in range: 0..999');
    }

    if (microsecond < 0 || microsecond > 1000) {
      throw ArgumentError.value(
          microsecond, 'microsecond', 'Not in range: 0..999');
    }
  }

  /// Creates a [Time] instance from [duration].
  factory Time.fromDuration(Duration duration) {
    var h = duration.inHours;
    var m = duration.inMinutes - Duration(hours: h).inMinutes;
    var s = duration.inSeconds - Duration(hours: h, minutes: m).inSeconds;
    var ms = duration.inMilliseconds -
        Duration(hours: h, minutes: m, seconds: s).inMilliseconds;
    var mic = duration.inMicroseconds -
        Duration(hours: h, minutes: m, seconds: s, milliseconds: ms)
            .inMicroseconds;
    return Time(h, m, s, ms, mic);
  }

  /// Creates a [Time] instance from [dateTime].
  factory Time.fromDateTime(DateTime dateTime) {
    var h = dateTime.hour;
    var m = dateTime.minute;
    var s = dateTime.second;
    var ms = dateTime.millisecond;
    var mic = dateTime.microsecond;
    return Time(h, m, s, ms, mic);
  }

  /// Creates a [Time] period instance from a total [microseconds].
  factory Time.fromMicroseconds(int microseconds) {
    return Time.fromDuration(Duration(microseconds: microseconds));
  }

  /// Creates a [Time] period instance from a total [milliseconds].
  factory Time.fromMilliseconds(int milliseconds) {
    return Time.fromDuration(Duration(milliseconds: milliseconds));
  }

  /// Creates a [Time] period instance from a total [seconds].
  factory Time.fromSeconds(int seconds) {
    return Time.fromDuration(Duration(seconds: seconds));
  }

  /// Creates a [Time] period instance from a total [minutes].
  factory Time.fromMinutes(int minutes) {
    return Time.fromDuration(Duration(minutes: minutes));
  }

  static final int _char0 = '0'.codeUnitAt(0);
  static final int _char9 = '9'.codeUnitAt(0);
  static final int _charColon = ':'.codeUnitAt(0);
  static final int _charDot = '.'.codeUnitAt(0);

  static bool _isDigitByte(int b) {
    return b >= _char0 && b <= _char9;
  }

  static bool _bytesInStringFormat(List<int> value) {
    if (value.isEmpty) return false;

    if (!_isDigitByte(value[0])) return false;
    if (value.length < 2 && !_isDigitByte(value[1])) return false;

    if (value.length == 8 &&
        value[2] == _charColon &&
        value[5] == _charColon &&
        _isDigitByte(value[3]) &&
        _isDigitByte(value[4]) &&
        _isDigitByte(value[6]) &&
        _isDigitByte(value[7])) {
      return true;
    } else if (value.length >= 10 &&
        value[2] == _charColon &&
        value[5] == _charColon &&
        value[8] == _charDot &&
        _isDigitByte(value[3]) &&
        _isDigitByte(value[4]) &&
        _isDigitByte(value[6]) &&
        _isDigitByte(value[7]) &&
        _isDigitByte(value[9])) {
      for (var i = 10; i < value.length; ++i) {
        if (!_isDigitByte(value[i])) {
          return false;
        }
      }

      return true;
    }

    return false;
  }

  /// Parses [bytes] to [Time]. See [toBytes32] and [toBytes64].
  factory Time.fromBytes(List<int> bytes, {bool allowParseString = true}) {
    if (bytes.length == 4) {
      var milliseconds = bytes.asUint8List.getInt32(0);
      if (milliseconds >= 0) {
        var time = Time.fromMilliseconds(milliseconds);
        return time;
      }
    } else if (bytes.length >= 8 && !_bytesInStringFormat(bytes)) {
      var microseconds = bytes.asUint8List.getInt64();
      if (microseconds >= 0) {
        var time = Time.fromMicroseconds(microseconds);
        return time;
      }
    } else if (allowParseString) {
      try {
        var s = String.fromCharCodes(bytes);
        return Time.parse(s, allowFromBytes: false);
      } catch (_) {
        throw FormatException(
            'Invalid bytes or string format: ${bytes.runtimeType}:${bytes.toList()}');
      }
    }

    throw FormatException(
        'Invalid bytes format: ${bytes.runtimeType}:${bytes.toList()}');
  }

  /// Parses [s] to [Time].
  factory Time.parse(String s, {bool allowFromBytes = true}) {
    s = s.trim();
    if (s.isEmpty) {
      throw FormatException('Invalid `Time` format: $s');
    }

    var idx1 = s.indexOf(':');
    var idx2 = s.indexOf('.');

    if (idx1 != 2 || (idx2 > 0 && idx2 < idx1)) {
      if (allowFromBytes) {
        try {
          var bs = dart_convert.latin1.encode(s);
          return Time.fromBytes(bs, allowParseString: false);
        } catch (_) {
          throw FormatException('Invalid string or bytes format: $s');
        }
      }

      throw FormatException('Invalid string format: $s');
    }

    int ms = 0;
    int mic = 0;

    String hmsStr;
    if (idx2 >= 0) {
      hmsStr = s.substring(0, idx2).trim();
      var msMicStr = s.substring(idx2 + 1).trim();

      if (msMicStr.length <= 3) {
        ms = int.parse(msMicStr);
      } else {
        var msEnd = msMicStr.length - 3;
        var msStr = msMicStr.substring(0, msEnd);
        var micStr = msMicStr.substring(msEnd);

        ms = int.parse(msStr);
        mic = int.parse(micStr);
      }
    } else {
      hmsStr = s;
    }

    var parts = hmsStr.split(':');

    var hStr = parts[0].trim();
    var mStr = (parts.length > 1 ? parts[1] : '0').trim();
    var secStr = (parts.length > 2 ? parts[2] : '0').trim();

    var h = int.parse(hStr);
    var m = int.parse(mStr);
    var sec = int.parse(secStr);

    return Time(h, m, sec, ms, mic);
  }

  static Time? from(Object? o) {
    if (o == null) return null;
    if (o is Time) return o;

    if (o is Duration) return Time.fromDuration(o);
    if (o is DateTime) return Time.fromDateTime(o);
    if (o is List<int>) return Time.fromBytes(o);

    if (o is int) return Time.fromMilliseconds(o);

    if (o is Map) {
      return Time(
        TypeParser.parseInt(o['hour'], 0)!,
        TypeParser.parseInt(o['minute'], 0)!,
        TypeParser.parseInt(o['second'], 0)!,
        TypeParser.parseInt(o['millisecond'], 0)!,
        TypeParser.parseInt(o['microsecond'], 0)!,
      );
    }

    return Time.parse(o.toString());
  }

  /// Converts this to 64-bits bytes ([Uint8List]), encoding [totalMicrosecond].
  Uint8List toBytes64() {
    var bytes = Uint8List(8);
    bytes.asByteData().setInt64(0, totalMicrosecond);
    return bytes;
  }

  /// Converts this to 32-bits bytes ([Uint8List]), encoding [totalMilliseconds].
  Uint8List toBytes32() {
    var bytes = Uint8List(4);
    bytes.asByteData().setInt32(0, totalMilliseconds);
    return bytes;
  }

  @override
  String toString(
      {bool withSeconds = true, bool? withMillisecond, bool? withMicrosecond}) {
    var h = _intToPaddedString(hour);
    var m = _intToPaddedString(minute);
    var s = _intToPaddedString(second);

    withMillisecond ??= millisecond != 0;
    if (withMillisecond) {
      var ms = _intToPaddedString(millisecond, 3);

      withMicrosecond ??= microsecond != 0;
      if (withMicrosecond) {
        var mic = _intToPaddedString(microsecond, 3);
        return '$h:$m:$s.$ms$mic';
      } else {
        return '$h:$m:$s.$ms';
      }
    } else {
      return '$h:$m:$s';
    }
  }

  static String _intToPaddedString(int n, [int padding = 2]) =>
      n.toString().padLeft(padding, '0');

  /// Converts this [Time] to [DateTime].
  DateTime toDateTime(int year,
          [int month = 1, int day = 1, bool utc = true]) =>
      utc
          ? DateTime.utc(
              year, month, day, hour, minute, second, millisecond, microsecond)
          : DateTime(
              year, month, day, hour, minute, second, millisecond, microsecond);

  /// Returns the total minutes of this [Time] period.
  int get totalMinutes => (hour * 60) + minute;

  /// Returns the total seconds of this [Time] period.
  int get totalSeconds => (totalMinutes * 60) + second;

  /// Returns the total milliseconds of this [Time] period.
  int get totalMilliseconds => (totalSeconds * 1000) + millisecond;

  /// Returns the total microsecond of this [Time] period.
  int get totalMicrosecond => (totalMilliseconds * 1000) + microsecond;

  /// Converts `this` instance to [Duration].
  Duration get asDuration => Duration(
      hours: hour,
      minutes: minute,
      seconds: second,
      milliseconds: millisecond,
      microseconds: microsecond);

  @override
  int compareTo(Time other) {
    var cmp = hour.compareTo(other.hour);
    if (cmp == 0) {
      cmp = minute.compareTo(other.minute);
      if (cmp == 0) {
        cmp = second.compareTo(other.second);
        if (cmp == 0) {
          cmp = millisecond.compareTo(other.millisecond);
          if (cmp == 0) {
            cmp = microsecond.compareTo(other.microsecond);
          }
        }
      }
    }
    return cmp;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Time &&
          runtimeType == other.runtimeType &&
          hour == other.hour &&
          minute == other.minute &&
          second == other.second &&
          millisecond == other.millisecond &&
          microsecond == other.microsecond;

  @override
  int get hashCode =>
      hour.hashCode ^
      minute.hashCode ^
      second.hashCode ^
      millisecond.hashCode ^
      microsecond.hashCode;

  operator <(Time other) => totalMicrosecond < other.totalMicrosecond;

  operator <=(Time other) => totalMicrosecond <= other.totalMicrosecond;

  operator >(Time other) => totalMicrosecond > other.totalMicrosecond;

  operator >=(Time other) => totalMicrosecond >= other.totalMicrosecond;
}

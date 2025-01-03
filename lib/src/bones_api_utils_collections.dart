import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';

import 'bones_api_entity.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_utils_timedmap.dart';

/// Helper to work with positional fields.
class PositionalFields {
  late final Set<String> _fields;
  late final List<String> _fieldsOrder;
  final Map<String, int> _fieldsIndexes = <String, int>{};

  PositionalFields(Iterable<String> fields) {
    var list = fields.toList();
    _fields = UnmodifiableSetView<String>(list.toSet());

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
      fieldsOrder.map((f) => getMapEntry<Object>(f, row)).nonNulls;

  /// Converts [row] to a [Map].
  Map<String, Object?> toMap(Iterable<Object?> row) =>
      Map<String, Object?>.fromEntries(toEntries(row));

  /// Converts [rows] to a list of [Map].
  List<Map<String, Object?>> toListOfMap(Iterable<Iterable<Object?>> rows) =>
      rows.map(toMap).toList();
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
    } else if (o2 is EntityReferenceList) {
      return isEqualsListDeep(o1, o2.entities, valueEquality: valueEquality);
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
    } else if (o2 is EntityReferenceList) {
      return isEqualsIterableDeep(o1, o2.entities,
          valueEquality: valueEquality);
    }
    return false;
  } else if (o1 is EntityReferenceList) {
    if (o2 is EntityReferenceList) {
      return o1 == o2;
    } else if (o2 is Iterable) {
      return isEqualsIterableDeep(o1.entities, o2,
          valueEquality: valueEquality);
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

  if (l1 == null || l2 == null) return false;

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

  if (it1 == null || it2 == null) return false;

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

  if (set1 == null || set2 == null) return false;

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

  if (m1 == null || m2 == null) return false;

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

bool intersectsIterableDeep(Iterable? it1, Iterable? it2,
    {ValueEquality? valueEquality}) {
  if (identical(it1, it2)) return true;

  if (it1 == null || it2 == null) return false;
  if (it1.isEmpty || it2.isEmpty) return false;

  var length1 = it1.length;
  var length2 = it2.length;

  for (var i = 0; i < length1; i++) {
    var v1 = it1.elementAt(i);

    for (var j = 0; j < length2; ++j) {
      var v2 = it2.elementAt(j);
      if (isEqualsDeep(v1, v2, valueEquality: valueEquality)) return true;
    }
  }

  return false;
}

/// Deeply copies [o].
T? deepCopy<T>(T? o) {
  if (o == null) return null;
  if (o is String) return o;
  if (o is num) return o;
  if (o is bool) return o;

  if (o is Set) return deepCopySet(o) as T?;
  if (o is List) return deepCopyList(o) as T?;
  if (o is Iterable) return deepCopyList(o.toList(growable: false)) as T?;
  if (o is Map) return deepCopyMap(o) as T?;

  var entityHandler =
      EntityHandlerProvider.globalProvider.getEntityHandler(obj: o);

  if (entityHandler != null) {
    // ignore: discarded_futures
    var o2 = entityHandler.copy(o);
    if (o2 is! Future) {
      return o2 ?? o;
    }
  }

  return o;
}

/// Deeply copies [list].
List<T>? deepCopyList<T>(List<T>? list) {
  if (list == null) return null;

  if (list is List<String>) {
    return List<String>.from(list) as List<T>;
  } else if (list is Uint8List) {
    return Uint8List.fromList(list as Uint8List) as List<T>;
  } else if (list is Int8List) {
    return Int8List.fromList(list as Int8List) as List<T>;
  } else if (list is List<int>) {
    return List<int>.from(list) as List<T>;
  } else if (list is List<double>) {
    return List<double>.from(list) as List<T>;
  } else if (list is List<num>) {
    return List<num>.from(list) as List<T>;
  } else if (list is List<bool>) {
    return List<bool>.from(list) as List<T>;
  }

  if (list.isEmpty) return <T>[];
  return list.map<T>((T e) => deepCopy(e) as T).toList();
}

/// Deeply copies [list].
Set<T>? deepCopySet<T>(Set<T>? set) {
  if (set == null) return null;

  if (set is Set<String>) {
    return Set<String>.from(set) as Set<T>;
  } else if (set is Set<int>) {
    return Set<int>.from(set) as Set<T>;
  } else if (set is Set<double>) {
    return Set<double>.from(set) as Set<T>;
  } else if (set is Set<num>) {
    return Set<num>.from(set) as Set<T>;
  } else if (set is Set<bool>) {
    return Set<bool>.from(set) as Set<T>;
  }

  if (set.isEmpty) return <T>{};
  return set.map<T>((T e) => deepCopy(e) as T).toSet();
}

/// Deeply copies [map].
Map<K, V>? deepCopyMap<K, V>(Map<K, V>? map) {
  if (map == null) return null;

  if (map is Map<String, String>) {
    return Map<String, String>.from(map) as Map<K, V>;
  } else if (map is Map<String, int>) {
    return Map<String, int>.from(map) as Map<K, V>;
  } else if (map is Map<String, double>) {
    return Map<String, double>.from(map) as Map<K, V>;
  } else if (map is Map<String, num>) {
    return Map<String, num>.from(map) as Map<K, V>;
  } else if (map is Map<String, bool>) {
    return Map<String, bool>.from(map) as Map<K, V>;
  }

  if (K == dynamic || K == Object) {
    if (map is Map<String, Object?>) {
      return map.map<String, V>(
              (k, V v) => MapEntry<String, V>(k as String, deepCopy(v) as V))
          as Map<K, V>;
    }
  }

  if (map.isEmpty) return <K, V>{};

  return map.map<K, V>(
      (K k, V v) => MapEntry<K, V>(deepCopy(k) as K, deepCopy(v) as V));
}

/// Returns an [Enum] name.
String enumToName(Enum enumValue) => enumValue.name;

/// Returns an [Enum] from [enumValues] that matches [name].
E? enumFromName<E extends Enum>(String? name, Iterable<E> enumValues) {
  if (name == null) return null;
  name = name.trim();
  if (name.isEmpty) return null;

  for (var e in enumValues) {
    var n = enumToName(e);

    if (equalsIgnoreAsciiCase(n, name)) {
      return e;
    }
  }

  return null;
}

/// Extension on [Iterable] of [Enum].
extension IterableEnumExtension<E extends Enum> on Iterable<E> {
  E? parse(String? name) => enumFromName(name, this);
}

/// Extension that ads cached methods to a [Map].
extension MapAsCacheExtension<K, V> on Map<K, V> {
  void checkCachedEntry(K key) {
    var self = this;
    if (self is TimedMap<K, V>) {
      self.checkEntry(key);
    }
  }

  /// Returns [key] value, checking if it's still valid.
  /// See [checkCachedEntry] and [checkCacheLimit].
  V? getIfCached(K key, {int? cacheLimit}) {
    checkCachedEntry(key);
    checkCacheLimit(cacheLimit);

    return this[key];
  }

  /// Returns [key] value or computes it and caches it.
  /// See [checkCachedEntry], [checkCacheLimit] and [getCachedAsync].
  V getCached(K key, V Function() computer, {int? cacheLimit}) {
    checkCachedEntry(key);
    checkCacheLimit(cacheLimit);

    return putIfAbsent(key, computer);
  }

  V? getCachedNullable(K key, V? Function() computer, {int? cacheLimit}) {
    checkCachedEntry(key);

    var cached = this[key];
    if (cached != null) return cached;

    checkCacheLimit(cacheLimit);

    var val = computer();
    if (val == null) return val;

    this[key] = val;
    return val;
  }

  /// Same as [getCached] but accepts a [computer] that returns a [Future].
  /// See [checkCachedEntry], [checkCacheLimit] and [getCachedAsync].
  FutureOr<V> getCachedAsync(K key, FutureOr<V> Function() computer,
      {int? cacheLimit}) {
    checkCachedEntry(key);

    var cached = this[key];
    if (cached != null) return cached;

    checkCacheLimit(cacheLimit);

    return computer().resolveMapped((val) {
      this[key] = val;
      return val;
    });
  }

  FutureOr<V?> getCachedAsyncNullable(K key, FutureOr<V?> Function() computer,
      {int? cacheLimit}) {
    checkCachedEntry(key);

    var cached = this[key];
    if (cached != null) return cached;

    checkCacheLimit(cacheLimit);

    return computer().resolveMapped((val) {
      if (val == null) return null;
      this[key] = val;
      return val;
    });
  }

  /// Checks if this [Map.length] is bigger than [cacheLimit] and
  /// removes elements to not exceed the [cacheLimit].
  int checkCacheLimit(int? cacheLimit) {
    if (cacheLimit == null) return 0;

    if (cacheLimit <= 0) {
      var length = this.length;
      clear();
      return length;
    }

    var deleted = 0;

    while (true) {
      var length = this.length;
      if (length == 0 || length <= cacheLimit) {
        break;
      }

      var k = keys.first;
      remove(k);
      var lng = this.length;
      if (lng >= length) break;
      deleted++;
    }

    return deleted;
  }
}

extension MapOfCachesExtension<K, V, C extends Record, M extends Map<K, V>>
    on Map<C, Map<K, V>> {
  bool isEquivalentContext(C context1, C context2) {
    if (context1 is (Object?,) && context2 is (Object?,)) {
      return context1.$1 == context2.$1;
    }

    if (context1 is (Object?, Object?) && context2 is (Object?, Object?)) {
      return context1.$1 == context2.$1 &&
          (context1.$2 == context2.$2 || context1.$2 == true);
    }

    if (context1 is (Object?, Object?, Object?) &&
        context2 is (Object?, Object?, Object?)) {
      return context1.$1 == context2.$1 &&
          (context1.$2 == context2.$2 || context1.$2 == true) &&
          (context1.$3 == context2.$3 || context1.$3 == true);
    }

    if (context1 is (Object?, Object?, Object?, Object?) &&
        context2 is (Object?, Object?, Object?, Object?)) {
      return context1.$1 == context2.$1 &&
          (context1.$2 == context2.$2 || context1.$2 == true) &&
          (context1.$3 == context2.$3 || context1.$3 == true) &&
          (context1.$4 == context2.$4 || context1.$4 == true);
    }

    if (context1 is (Object?, Object?, Object?, Object?, Object?) &&
        context2 is (Object?, Object?, Object?, Object?, Object?)) {
      return context1.$1 == context2.$1 &&
          (context1.$2 == context2.$2 || context1.$2 == true) &&
          (context1.$3 == context2.$3 || context1.$3 == true) &&
          (context1.$4 == context2.$4 || context1.$4 == true) &&
          (context1.$5 == context2.$5 || context1.$5 == true);
    }

    if (context1 is (Object?, Object?, Object?, Object?, Object?, Object?) &&
        context2 is (Object?, Object?, Object?, Object?, Object?, Object?)) {
      return context1.$1 == context2.$1 &&
          (context1.$2 == context2.$2 || context1.$2 == true) &&
          (context1.$3 == context2.$3 || context1.$3 == true) &&
          (context1.$4 == context2.$4 || context1.$4 == true) &&
          (context1.$5 == context2.$5 || context1.$5 == true) &&
          (context1.$6 == context2.$6 || context1.$6 == true);
    }

    if (context1 is (
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?
        ) &&
        context2 is (
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?
        )) {
      return context1.$1 == context2.$1 &&
          (context1.$2 == context2.$2 || context1.$2 == true) &&
          (context1.$3 == context2.$3 || context1.$3 == true) &&
          (context1.$4 == context2.$4 || context1.$4 == true) &&
          (context1.$5 == context2.$5 || context1.$5 == true) &&
          (context1.$6 == context2.$6 || context1.$6 == true) &&
          (context1.$7 == context2.$7 || context1.$7 == true);
    }

    if (context1 is (
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?
        ) &&
        context2 is (
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?
        )) {
      return context1.$1 == context2.$1 &&
          (context1.$2 == context2.$2 || context1.$2 == true) &&
          (context1.$3 == context2.$3 || context1.$3 == true) &&
          (context1.$4 == context2.$4 || context1.$4 == true) &&
          (context1.$5 == context2.$5 || context1.$5 == true) &&
          (context1.$6 == context2.$6 || context1.$6 == true) &&
          (context1.$7 == context2.$7 || context1.$7 == true) &&
          (context1.$8 == context2.$8 || context1.$8 == true);
    }

    if (context1 is (
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?
        ) &&
        context2 is (
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?
        )) {
      return context1.$1 == context2.$1 &&
          (context1.$2 == context2.$2 || context1.$2 == true) &&
          (context1.$3 == context2.$3 || context1.$3 == true) &&
          (context1.$4 == context2.$4 || context1.$4 == true) &&
          (context1.$5 == context2.$5 || context1.$5 == true) &&
          (context1.$6 == context2.$6 || context1.$6 == true) &&
          (context1.$7 == context2.$7 || context1.$7 == true) &&
          (context1.$8 == context2.$8 || context1.$8 == true) &&
          (context1.$9 == context2.$9 || context1.$9 == true);
    }

    if (context1 is (
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?
        ) &&
        context2 is (
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?,
          Object?
        )) {
      return context1.$1 == context2.$1 &&
          (context1.$2 == context2.$2 || context1.$2 == true) &&
          (context1.$3 == context2.$3 || context1.$3 == true) &&
          (context1.$4 == context2.$4 || context1.$4 == true) &&
          (context1.$5 == context2.$5 || context1.$5 == true) &&
          (context1.$6 == context2.$6 || context1.$6 == true) &&
          (context1.$7 == context2.$7 || context1.$7 == true) &&
          (context1.$8 == context2.$8 || context1.$8 == true) &&
          (context1.$9 == context2.$9 || context1.$9 == true) &&
          (context1.$10 == context2.$10 || context1.$10 == true);
    }

    return false;
  }

  Iterable<M> equivalentCaches(C context) => entries.where((e) {
        var context2 = e.key;
        if (context2 == context) {
          return false;
        }
        return isEquivalentContext(context2, context);
      }).map((e) => e.value as M);

  M getCache(C context, M Function() cacheInstantiator) =>
      putIfAbsent(context, cacheInstantiator) as M;

  V? getIfCached(K key, C context, M Function() cacheInstantiator) =>
      _getIfCached(key, context, cacheInstantiator).$1;

  (V?, M) _getIfCached(K key, C context, M Function() cacheInstantiator) {
    var cache = getCache(context, cacheInstantiator);

    var o = cache.getIfCached(key);
    if (o != null) return (o, cache);

    var cachesEq = equivalentCaches(context);

    for (var cache in cachesEq) {
      o = cache[key];
      if (o != null) return (o, cache);
    }

    return (null, cache);
  }

  FutureOr<V> getMultiCachedAsync(K key, C context,
      M Function() cacheInstantiator, FutureOr<V> Function() computer) {
    var (o, cache) = _getIfCached(key, context, cacheInstantiator);
    if (o != null) return o;

    return cache.getCachedAsync(key, computer);
  }

  FutureOr<V?> getMultiCachedAsyncNullable(K key, C context,
      M Function() cacheInstantiator, FutureOr<V?> Function() computer) {
    var (o, cache) = _getIfCached(key, context, cacheInstantiator);
    if (o != null) return o;

    return cache.getCachedAsyncNullable(key, computer);
  }

  V getMultiCached(
      K key, C context, M Function() cacheInstantiator, V Function() computer) {
    var (o, cache) = _getIfCached(key, context, cacheInstantiator);
    if (o != null) return o;

    return cache.getCached(key, computer);
  }

  V? getMultiCachedNullable(K key, C context, M Function() cacheInstantiator,
      V? Function() computer) {
    var (o, cache) = _getIfCached(key, context, cacheInstantiator);
    if (o != null) return o;

    return cache.getCachedNullable(key, computer);
  }

  void populateMultiCache(
      K key, C context, M Function() cacheInstantiator, V value) {
    var cache = getCache(context, cacheInstantiator);
    cache[key] = value;
  }
}

extension RecordExtension on Record {
  static final Map<Type, int> _positionalParametersLengthCache = {};

  /// Returns the number of positional parameters in a [Record] type.
  /// - Supports [Records] with up to 10 positional parameters and no named parameters.
  int get positionalParametersLength =>
      _positionalParametersLengthCache[runtimeType] ??=
          _positionalParametersLengthImpl;

  int get _positionalParametersLengthImpl {
    final o = this;

    if (o is (Object?,)) return 1;

    if (o is (Object?, Object?)) return 2;

    if (o is (Object?, Object?, Object?)) return 3;

    if (o is (Object?, Object?, Object?, Object?)) return 4;

    if (o is (Object?, Object?, Object?, Object?, Object?)) return 5;

    if (o is (Object?, Object?, Object?, Object?, Object?, Object?)) return 6;

    if (o is (Object?, Object?, Object?, Object?, Object?, Object?, Object?)) {
      return 7;
    }

    if (o is (
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?
    )) {
      return 8;
    }

    if (o is (
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?
    )) {
      return 9;
    }

    if (o is (
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?,
      Object?
    )) {
      return 10;
    }

    return -1;
  }
}

extension PopulateMultiCacheExtension<V extends Object> on Future<V> {
  Future<V> populateMultiCache<K, C extends Record, M extends Map<K, V>>(
          Map<C, M> caches,
          K key,
          C context,
          M Function() cacheInstantiator) async =>
      then((o) {
        caches.populateMultiCache(key, context, cacheInstantiator, o);
        return o;
      });
}

extension PopulateMultiCacheNullableExtension<V extends Object> on Future<V?> {
  Future<V?> populateMultiCache<K, C extends Record, M extends Map<K, V>>(
          Map<C, M> caches,
          K key,
          C context,
          M Function() cacheInstantiator) async =>
      then((o) {
        if (o != null) {
          caches.populateMultiCache(key, context, cacheInstantiator, o);
        }
        return o;
      });
}

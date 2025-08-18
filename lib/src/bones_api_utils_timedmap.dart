import 'package:async_extension/async_extension.dart';

/// A [Map] where the keys have a put time ([DateTime]) and also can expire.
class TimedMap<K, V> implements Map<K, V> {
  /// The key timeout. When a key is put, it expires after the timeout [Duration].
  final Duration keyTimeout;

  final bool? Function(
    TimedMap timedMap,
    Object? key,
    Duration elapsedTime,
    Duration keyTimeout,
  )?
  keyTimeoutChecker;

  TimedMap(this.keyTimeout, [Map<K, V>? map, this.keyTimeoutChecker]) {
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
      keysChecked(
        now: now,
        keyTimeout: keyTimeout,
      ).map((k) => _entries[k]!).toList();

  /// Returns the entries of this instance checking [keyTimeout].
  /// See [checkAllEntries].
  List<MapEntry<K, V>> entriesChecked({DateTime? now, Duration? keyTimeout}) =>
      keysChecked(
        now: now,
        keyTimeout: keyTimeout,
      ).map((k) => MapEntry(k, _entries[k] as V)).toList();

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

    final keyTimeoutChecker = this.keyTimeoutChecker;

    keyTimeout ??= this.keyTimeout;

    if (keyTimeoutChecker != null) {
      var expired = keyTimeoutChecker(this, key, elapsedTime, keyTimeout);
      if (expired != null) {
        return expired;
      }
    }

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
        var v = _entries[k] as V;

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
    MapEntry<K2, V2> Function(K key, V value) convert,
  ) => TimedMap<K2, V2>(keyTimeout, _entries.map(convert));

  @override
  V putIfAbsent(K key, V Function() ifAbsent) => _entries.putIfAbsent(key, () {
    var v = ifAbsent();
    _entriesPutTime[key] = DateTime.now();
    return v;
  });

  /// Same as [putIfAbsent], but calls [checkEntry] first.
  V putIfAbsentChecked(
    K key,
    V Function() ifAbsent, {
    DateTime? now,
    Duration? keyTimeout,
  }) {
    checkEntry(key, now: now, keyTimeout: keyTimeout);
    return putIfAbsent(key, ifAbsent);
  }

  /// Same as [putIfAbsentChecked], but accepts an async function for [ifAbsent].
  FutureOr<V> putIfAbsentCheckedAsync(
    K key,
    FutureOr<V> Function() ifAbsent, {
    DateTime? now,
    Duration? keyTimeout,
  }) {
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
      _entries.update(
        key,
        (V v) {
          v = update(v);
          _entriesPutTime[key] = DateTime.now();
          return v;
        },
        ifAbsent: () {
          var v = ifAbsent!();
          _entriesPutTime[key] = DateTime.now();
          return v;
        },
      );

  /// Same as [update], but calls [checkEntry] first.
  V updateTimed(
    K key,
    V Function(V value) update, {
    V Function()? ifAbsent,
    DateTime? now,
    Duration? keyTimeout,
  }) {
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
        var v = _entries[k] as V;
        var v2 = update(k, v, t);

        _entries[k] = v2;
        _entriesPutTime[k] = DateTime.now();
      }
    }
  }
}

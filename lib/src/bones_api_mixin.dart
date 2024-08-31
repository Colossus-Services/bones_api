import 'dart:collection';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:statistics/statistics.dart';
import 'package:logging/logging.dart' as logging;

import 'bones_api_utils.dart';

final _logPool = logging.Logger('Pool');

mixin Closable {
  bool _closed = false;

  bool get isClosed => _closed;

  FutureOr<bool> close() {
    if (_closed) return false;
    _closed = true;
    return true;
  }

  void checkNotClosed() {
    if (isClosed) {
      throw StateError("Closed: $this");
    }
  }
}

abstract class PoolError extends Error implements WithRuntimeTypeNameSafe {
  final String message;

  PoolError(this.message);

  @override
  String toString() {
    return '$runtimeTypeNameSafe: $message';
  }
}

class PoolTimeoutError extends PoolError {
  PoolTimeoutError(super.message);

  @override
  String get runtimeTypeNameSafe => 'PoolTimeoutError';
}

class PoolFullError extends PoolError {
  PoolFullError(super.message);

  @override
  String get runtimeTypeNameSafe => 'PoolFullError';
}

mixin Pool<O extends Object> {
  final ListQueue<O> _pool = ListQueue(8);

  Iterable<O> get poolElements => UnmodifiableListView<O>(_pool);

  bool removeFromPool(O o) {
    return _pool.remove(o);
  }

  int removeElementsFromPool(int amount) {
    var rm = 0;

    while (amount > 0 && _pool.isNotEmpty) {
      var o = _pool.removeFirst();

      // It won't wait for elements to close:
      // ignore: discarded_futures
      closePoolElement(o);

      --amount;
      rm++;
    }

    return rm;
  }

  FutureOr<List<O>> validPoolElements() =>
      filterPoolElements(isPoolElementValid);

  FutureOr<List<O>> invalidPoolElements({bool checkUsage = true}) =>
      filterPoolElements(
          (e) => isPoolElementInvalid(e, checkUsage: checkUsage));

  FutureOr<List<O>> filterPoolElements(FutureOr<bool> Function(O o) filter) {
    var hasFuture = false;

    var elements = _pool.map<FutureOr<O?>>((o) {
      var valid = filter(o);

      if (valid is Future<bool>) {
        hasFuture = true;
        return valid.then((valid) => valid ? o : null);
      }

      return valid ? o : null;
    }).toList();

    if (hasFuture) {
      return elements.resolveAllNotNull();
    } else {
      return elements.whereType<O>().toList();
    }
  }

  int _invalidatedElementsCount = 0;

  FutureOr<bool> removeInvalidElementsFromPool({bool checkUsage = true}) {
    FutureOr<List<O>> ret = invalidPoolElements(checkUsage: checkUsage);

    return ret.resolveMapped((l) {
      for (var o in l) {
        ++_invalidatedElementsCount;
        removeFromPool(o);
      }
      return true;
    });
  }

  FutureOr<bool> isPoolElementValid(O o, {bool checkUsage = true});

  FutureOr<bool> isPoolElementInvalid(O o, {bool checkUsage = true}) {
    var valid = isPoolElementValid(o, checkUsage: checkUsage);

    if (valid is Future<bool>) {
      return valid.then((valid) => !valid);
    } else {
      return !valid;
    }
  }

  FutureOr<bool> clearPool() {
    var pool = _pool.toList();

    return pool.map(disposePoolElement).resolveAll().resolveMapped((l) {
      _pool.clear();
      return true;
    });
  }

  int get poolSize => _pool.length;

  bool get isPoolEmpty => poolSize == 0;

  bool get isPoolNotEmpty => !isPoolEmpty;

  int get poolCreatedElementsCount => _createElementCount;

  int get poolDisposedElementsCount =>
      _closedElementsCount +
      _unrecycledElementsCount +
      _invalidatedElementsCount;

  int get poolAliveElementsSize =>
      poolCreatedElementsCount - poolDisposedElementsCount;

  int _createElementCount = 0;

  FutureOr<O?> createPoolElement({bool force = false}) {
    ++_createElementCount;
    return null;
  }

  FutureOr<O> createPoolElementForced() {
    return createPoolElement(force: true).resolveMapped((o) {
      if (o == null) {
        throw PoolFullError("Can't create a new element `$O`! (forced)");
      }
      return o;
    });
  }

  Completer<bool>? _waitingPoolElement;

  FutureOr<O> catchFromPool({Duration? timeout}) {
    if (_pool.isEmpty) {
      return _catchFromEmptyPool(timeout);
    } else {
      return _catchFromPopulatedPool().resolveMapped((o) {
        if (o != null) return o;
        return createPoolElementForced();
      });
    }
  }

  FutureOr<O?> peekFromPool() {
    if (_pool.isEmpty) {
      return null;
    } else {
      return _catchFromPopulatedPool();
    }
  }

  int get poolSizeDesiredLimit;

  static final Duration _defaultPoolYieldTimeout = Duration(milliseconds: 200);

  Duration get poolYieldTimeout => _defaultPoolYieldTimeout;

  static final Duration _defaultPoolFullYieldTimeout =
      Duration(milliseconds: 120);

  Duration get poolFullYieldTimeout => _defaultPoolFullYieldTimeout;

  static final Duration _defaultPoolFullWaitTimeout =
      Duration(milliseconds: 240);

  Duration get poolFullWaitTimeout => _defaultPoolFullWaitTimeout;

  final QueueList<Completer<bool>> _yields = QueueList(8);

  FutureOr<O> _catchFromEmptyPool(Duration? timeout) {
    final catchInitTime = DateTime.now();

    var alive = poolAliveElementsSize;

    FutureOr<O?> created;

    if (alive >= poolSizeDesiredLimit) {
      var yield = Completer<bool>();
      _yields.addLast(yield);

      created = yield.future.timeout(poolYieldTimeout, onTimeout: () {
        _yields.remove(yield);
        return false;
      }).then((ok) {
        if (_pool.isNotEmpty) {
          return _catchFromPopulatedPool();
        } else {
          return createPoolElement();
        }
      });
    } else {
      created = createPoolElement();
    }

    return created.resolveMapped((o) {
      if (o != null) return o;

      if (_pool.isNotEmpty) {
        return _catchFromPopulatedPool().resolveMapped((o) {
          if (o != null) return o;
          return _catchFromEmptyPoolForced(catchInitTime, timeout);
        });
      }

      return _catchFromEmptyPoolForced(catchInitTime, timeout);
    });
  }

  FutureOr<O> _catchFromEmptyPoolForced(
      DateTime catchInitTime, Duration? timeout) {
    var alive = poolAliveElementsSize;

    Future<bool> waiting;

    if (alive >= poolSizeDesiredLimit) {
      var yield = Completer<bool>();
      _yields.addLast(yield);

      waiting = yield.future.timeout(poolFullYieldTimeout, onTimeout: () {
        _yields.remove(yield);
        return false;
      });
    } else {
      var waitingPoolElement = _waitingPoolElement ??= Completer<bool>();
      waiting = waitingPoolElement.future;
    }

    var ret = waiting.then((_) {
      if (_pool.isNotEmpty) {
        return _catchFromPopulatedPool();
      } else {
        return _waitElementInPool(catchInitTime);
      }
    }).then((o) {
      if (o != null) return o;
      return createPoolElementForced();
    });

    if (timeout != null) {
      return ret.timeout(timeout, onTimeout: () {
        throw PoolTimeoutError("Catch from Pool timeout[$timeout]: $this");
      });
    } else {
      return ret;
    }
  }

  FutureOr<O?> catchFromPopulatedPool() {
    if (_pool.isEmpty) return null;
    return _catchFromPopulatedPool();
  }

  FutureOr<O?> _catchFromPopulatedPool() {
    var o = _pool.removeLast();

    var waitingPoolElement = _waitingPoolElement;
    if (waitingPoolElement != null) {
      if (!waitingPoolElement.isCompleted) {
        waitingPoolElement.complete(false);
      }
      _waitingPoolElement = null;
    }

    var valid = isPoolElementValid(o);

    if (valid is Future<bool>) {
      return valid.then((valid) {
        if (!valid) {
          disposePoolElement(o);
          return null;
        }
        return preparePoolElement(o);
      });
    }

    if (!valid) {
      disposePoolElement(o);
      return null;
    }
    return preparePoolElement(o);
  }

  FutureOr<O> _waitElementInPool(DateTime catchInitTime) async {
    int retry = 0;

    while (true) {
      var waitingPoolElement = _waitingPoolElement ??= Completer<bool>();

      await waitingPoolElement.future
          .timeout(poolFullWaitTimeout, onTimeout: () => false);

      if (_pool.isNotEmpty) {
        var o = await _catchFromPopulatedPool();
        if (o != null) return o;
      }

      if (retry >= 2) {
        final elapsedTime = DateTime.now().difference(catchInitTime);

        _logPool.warning(
            "Pool full ($poolAliveElementsSize / $poolSizeDesiredLimit) "
            "after trying to catch for ${elapsedTime.inMilliseconds} ms. "
            "Forcing createPoolElement<$O>() ...");

        return createPoolElementForced();
      }

      ++retry;
    }
  }

  FutureOr<O?> preparePoolElement(O o) => o;

  DateTime _lastCheckPoolTime = DateTime.now();

  int get lastCheckPoolElapsedTimeMs =>
      DateTime.now().millisecondsSinceEpoch -
      _lastCheckPoolTime.millisecondsSinceEpoch;

  FutureOr<bool> callCheckPool() {
    return checkPool().resolveMapped((ok) {
      _lastCheckPoolTime = DateTime.now();
      return ok;
    });
  }

  FutureOr<bool> checkPool() => removeInvalidElementsFromPool();

  FutureOr<bool> checkPoolSize(
      int minSize, int maxSize, int checkInvalidsIntervalMs) {
    var poolSize = this.poolSize;

    if (poolSize <= minSize) {
      if (lastCheckPoolElapsedTimeMs > checkInvalidsIntervalMs) {
        return removeInvalidElementsFromPool(checkUsage: false);
      } else {
        return true;
      }
    }

    if (poolSize > maxSize) {
      return removeInvalidElementsFromPool().resolveMapped((_) {
        var excess = this.poolSize - maxSize;
        _logPool.info(
            "Removing excess> poolSize: $poolSize ; maxSize: $maxSize ; excess: $excess");
        removeElementsFromPool(excess);
        return true;
      });
    }

    if (lastCheckPoolElapsedTimeMs > checkInvalidsIntervalMs) {
      return removeInvalidElementsFromPool();
    } else {
      return true;
    }
  }

  FutureOr<O?> recyclePoolElement(O o) {
    var valid = isPoolElementValid(o);

    if (valid is Future<bool>) {
      return valid.then((valid) => valid ? o : null);
    }

    return valid ? o : null;
  }

  int _unrecycledElementsCount = 0;

  FutureOr<bool> releaseIntoPool(O o) {
    var ret = recyclePoolElement(o);

    return ret.resolveMapped((recycled) {
      if (recycled == null) {
        ++_unrecycledElementsCount;
        disposePoolElement(o);
        return false;
      }

      callCheckPool();
      _pool.addLast(recycled);

      while (_yields.isNotEmpty) {
        var yield = _yields.removeFirst();
        if (!yield.isCompleted) {
          yield.complete(true);
          break;
        }
      }

      var waitingPoolElement = _waitingPoolElement;
      if (waitingPoolElement != null && !waitingPoolElement.isCompleted) {
        waitingPoolElement.complete(true);
        _waitingPoolElement = null;
      }

      return true;
    });
  }

  int _closedElementsCount = 0;

  FutureOr<bool> closePoolElement(O o) {
    ++_closedElementsCount;
    return true;
  }

  FutureOr<bool> disposePoolElement(O o) {
    _pool.remove(o);
    return closePoolElement(o);
  }

  FutureOr<R> executeWithPool<R>(FutureOr<R> Function(O o) f,
      {Duration? timeout,
      bool Function(O o)? validator,
      Function(Object error, StackTrace stackTrace)? onError}) {
    return catchFromPool(timeout: timeout).then((o) {
      try {
        var ret = f(o);

        return ret.then((val) {
          if (validator == null || validator(o)) {
            releaseIntoPool(o);
          } else {
            disposePoolElement(o);
          }
          return val;
        }, onError: (e, s) {
          disposePoolElement(o);
          if (onError != null) {
            return onError(e, s);
          } else {
            throw e;
          }
        });
      } catch (e, s) {
        disposePoolElement(o);
        if (onError != null) {
          return onError(e, s);
        } else {
          rethrow;
        }
      }
    });
  }
}

mixin FieldsFromMap {
  Map<String, int> buildFieldsNamesIndexes(List<String> fieldsNames) {
    return Map<String, int>.fromEntries(
        List.generate(fieldsNames.length, (i) => MapEntry(fieldsNames[i], i)));
  }

  List<String> buildFieldsNamesLC(List<String> fieldsNames) =>
      List<String>.unmodifiable(fieldsNames.map(fieldToLCKey));

  List<String> buildFieldsNamesSimple(List<String> fieldsNames) {
    return List<String>.unmodifiable(fieldsNames.map(fieldToSimpleKey));
  }

  /// Resolves [fieldName] to one that matches a [fieldsNames] element.
  String? resolveFiledName(
    List<String> fieldsNames,
    final String fieldName, {
    Map<String, int>? fieldsNamesIndexes,
    List<String>? fieldsNamesLC,
    List<String>? fieldsNamesSimple,
    bool includeAbsentFields = false,
    List<String>? returnMapUsedKeys,
  }) {
    var f = fieldsNames.firstWhereOrNull((f) => f == fieldName);

    f ??= fieldsNames.firstWhereOrNull((f) {
      String? fLC, fSimple;
      if (fieldsNamesIndexes != null) {
        var idx = fieldsNamesIndexes[f]!;
        fLC = fieldsNamesLC?[idx];
        fSimple = fieldsNamesSimple?[idx];
      }

      fLC ??= fieldToLCKey(f);
      if (fieldName == fLC) return true;

      fSimple ??= fieldToSimpleKey(f);
      if (fieldName == fSimple) return true;

      return false;
    });

    return f;
  }

  /// Returns a [Map] with the fields values populated from the provided [map].
  ///
  /// The field name resolution is case insensitive. See [getFieldValueFromMap].
  Map<String, Object?> getFieldsValuesFromMap(
    List<String> fieldsNames,
    Map<String, Object?> map, {
    Map<String, int>? fieldsNamesIndexes,
    List<String>? fieldsNamesLC,
    List<String>? fieldsNamesSimple,
    bool includeAbsentFields = false,
    List<String>? returnMapUsedKeys,
  }) {
    var mapLC = <String, String>{};
    var mapSimple = <String, String>{};

    var returnMapField = returnMapUsedKeys != null ? <String>[''] : null;

    var fields = <String, Object?>{};

    for (var f in fieldsNames) {
      String? fLC, fSimple;
      if (fieldsNamesIndexes != null) {
        var idx = fieldsNamesIndexes[f]!;
        fLC = fieldsNamesLC?[idx];
        fSimple = fieldsNamesSimple?[idx];
      }

      var entry = _getFieldValueFromMapImpl(
          f, fLC, fSimple, map, mapLC, mapSimple, returnMapField);

      if (entry == null) {
        if (includeAbsentFields) {
          fields[f] = null;
        }
      } else {
        if (returnMapUsedKeys != null) {
          var mapField = returnMapField![0];
          returnMapUsedKeys.add(mapField);
        }

        fields[entry.key] = entry.value;
      }
    }

    return fields;
  }

  /// Returns a [field] value from [map].
  /// - [field] is case insensitive.
  Object? getFieldValueFromMap(String field, Map<String, Object?> map,
      {String? fieldLC,
      String? fieldSimple,
      Map<String, String>? mapLC,
      Map<String, String>? mapSimple}) {
    var entry = _getFieldValueFromMapImpl(
        field, fieldLC, fieldSimple, map, mapLC, mapSimple, null);
    return entry?.value;
  }

  MapEntry<String, Object?>? _getFieldValueFromMapImpl(
      String field,
      String? fieldLC,
      String? fieldSimple,
      Map<String, Object?> map,
      Map<String, String>? mapLC,
      Map<String, String>? mapSimple,
      List<String>? returnMapField) {
    if (map.isEmpty) return null;

    var key = _getFieldKeyInMapImpl(
        field, fieldLC, fieldSimple, map, mapLC, mapSimple);
    if (key == null) return null;

    returnMapField?[0] = key;

    var value = map[key];
    return MapEntry(field, value);
  }

  /// Returns a [Map] of [field] keys from [map].
  /// - [field] is case insensitive.
  Map<String, String?> getFieldsKeysInMap(
      List<String> fields, Map<String, Object?> map,
      {String? fieldLC,
      String? fieldSimple,
      Map<String, String>? mapLC,
      Map<String, String>? mapSimple}) {
    var fieldsMap = fields
        .map((f) => MapEntry(
            f,
            getFieldKeyInMap(f, map,
                fieldLC: fieldLC,
                fieldSimple: fieldSimple,
                mapLC: mapLC,
                mapSimple: mapSimple)))
        .toMapFromEntries();

    return fieldsMap;
  }

  /// Returns a [field] key from [map].
  /// - [field] is case insensitive.
  String? getFieldKeyInMap(String field, Map<String, Object?> map,
      {String? fieldLC,
      String? fieldSimple,
      Map<String, String>? mapLC,
      Map<String, String>? mapSimple}) {
    return _getFieldKeyInMapImpl(
        field, fieldLC, fieldSimple, map, mapLC, mapSimple);
  }

  String? _getFieldKeyInMapImpl(
      String field,
      String? fieldLC,
      String? fieldSimple,
      Map<String, Object?> map,
      Map<String, String>? mapLC,
      Map<String, String>? mapSimple) {
    if (map.isEmpty) return null;

    if (map.containsKey(field)) return field;

    fieldLC ??= fieldToLCKey(field);
    if (map.containsKey(fieldLC)) return fieldLC;

    fieldSimple ??= fieldToSimpleKey(field);
    if (map.containsKey(fieldSimple)) return fieldSimple;

    if (mapLC != null) {
      if (mapLC.isEmpty) {
        for (var e in map.entries) {
          var k = e.key;
          var kLC = fieldToLCKey(k);
          mapLC[kLC] = k;
        }
      }

      var mapKey = mapLC[fieldLC];
      if (mapKey != null) {
        return mapKey;
      }
    } else {
      for (var k in map.keys) {
        var kLC = fieldToLCKey(k);
        if (kLC == fieldLC) {
          return k;
        }
      }
    }

    if (mapSimple != null) {
      if (mapSimple.isEmpty) {
        for (var e in map.entries) {
          var k = e.key;
          var kSimple = fieldToSimpleKey(k);
          mapSimple[kSimple] = k;
        }
      }

      var mapKey = mapSimple[fieldSimple];
      if (mapKey != null) {
        return mapKey;
      }
    } else {
      for (var k in map.keys) {
        var kSimple = fieldToSimpleKey(k);
        if (kSimple == fieldSimple) {
          return k;
        }
      }
    }

    return null;
  }

  String fieldToLCKey(String key) => StringUtils.toLowerCase(key);

  String fieldToSimpleKey(String key) =>
      StringUtils.toLowerCaseSimpleCached(key);
}

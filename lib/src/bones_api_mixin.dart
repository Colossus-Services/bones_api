import 'dart:collection';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';

typedef ExecuteInitializedCallback<R> = FutureOr<R> Function();

mixin Initializable {
  /// Ensures that this instance is initialized.
  FutureOr<bool> ensureInitialized() => _doInitializationImpl();

  /// Ensures that this instance is initialized. If is not
  /// initialized yet it will force an asynchronous initialization
  /// and return a [Future].
  FutureOr<bool> ensureInitializedAsync() {
    if (_initialized) return true;
    return Future<bool>.microtask(_doInitializationImpl);
  }

  /// Initialize this instance if is not initialized yet.
  FutureOr<bool> doInitialization() => _doInitializationImpl();

  bool _initializing = false;
  bool _initialized = false;

  /// Returns `true` if this instance is already initialized.
  bool get isInitialized => _initialized;

  Future<bool>? _initializeAsync;

  FutureOr<bool> _doInitializationImpl() {
    if (_initialized) return true;

    var initializeAsync = _initializeAsync;
    if (initializeAsync != null) {
      return initializeAsync;
    }

    // Avoid recursive call to this initialization:
    if (_initializing) return true;
    _initializing = true;

    var retDep = initializeDependencies();

    var dependencies = retDep
        .resolveMapped((l) => l.map((e) => e.doInitialization()).resolveAll());

    if (dependencies is Future<List<bool>>) {
      return _initializeAsync = dependencies.then((okDeps) {
        if (okDeps.any((ok) => !ok)) {
          throw StateError("Error initializing dependencies (async): $this");
        }

        return _callInitialize();
      });
    } else {
      if (dependencies.any((ok) => !ok)) {
        throw StateError("Error initializing dependencies: $this");
      }

      return _callInitialize();
    }
  }

  FutureOr<bool> _callInitialize() {
    var ret = initialize();

    if (ret is Future<bool>) {
      return _initializeAsync = ret.then((ok) {
        _initialized = true;
        _initializing = false;
        _initializeAsync = null;
        if (!ok) {
          throw StateError("Error initializing (async): $this");
        }
        return true;
      });
    } else {
      _initialized = true;
      _initializing = false;
      _initializeAsync = null;
      if (!ret) {
        throw StateError("Error initializing: $this");
      }
      return true;
    }
  }

  /// Return a [List] of [Initializable] instances that need to be initialized
  /// before initialize this instance.
  FutureOr<List<Initializable>> initializeDependencies() => <Initializable>[];

  /// Initialization implementation. Do not call it directly, use [doInitialization].
  ///
  /// It can be a synchronous (returning a [bool]) or an asynchronous
  /// implementation (returning a [Future]<[bool]>).
  FutureOr<bool> initialize() => true;

  /// Checks if this instance is initialized.
  ///
  /// Throws a [StateError] if is not initialized and
  /// can't initialize it synchronously.
  void checkInitialized() {
    if (!isInitialized) {
      if (_initializing) return;

      var ret = _doInitializationImpl();
      if (ret is Future<bool>) {
        throw StateError(
            "Not initialized yet! Async initialization for: $this");
      }
    }
  }

  /// Executes the [callback] ensuring that this instances was fully initialized.
  FutureOr<R> executeInitialized<R>(ExecuteInitializedCallback<R> callback) {
    if (isInitialized) {
      return callback();
    }

    var ret = ensureInitialized();

    if (ret is Future<bool>) {
      return ret.then((ok) {
        if (!ok) {
          throw StateError("Error initializing (async): $this");
        }
        return callback();
      });
    } else {
      if (!ret) {
        throw StateError("Error initializing: $this");
      }

      return callback();
    }
  }
}

mixin Closable {
  bool _closed = false;

  bool get isClosed => _closed;

  void close() {
    if (_closed) return;
    _closed = true;
  }

  void checkNotClosed() {
    if (isClosed) {
      throw StateError("Closed: $this");
    }
  }
}

class PoolTimeoutError extends Error {
  final String message;

  PoolTimeoutError(this.message);

  @override
  String toString() {
    return 'PoolTimeoutError: $message';
  }
}

mixin Pool<O> {
  final ListQueue<O> _pool = ListQueue(8);

  Iterable<O> get poolElements => List<O>.unmodifiable(_pool);

  bool removeFromPool(O o) {
    return _pool.remove(o);
  }

  int removeElementsFromPool(int amount) {
    var rm = 0;

    while (amount > 0 && _pool.isNotEmpty) {
      var o = _pool.removeFirst();
      closePoolElement(o);
      --amount;
      rm++;
    }

    return rm;
  }

  FutureOr<List<O>> validPoolElements() =>
      filterPoolElements(isPoolElementValid);

  FutureOr<List<O>> invalidPoolElements() => filterPoolElements(
      (o) => isPoolElementValid(o).resolveMapped((valid) => !valid));

  FutureOr<List<O>> filterPoolElements(FutureOr<bool> Function(O o) filter) {
    var elements = _pool.map((o) {
      return filter(o).resolveMapped((valid) => valid ? o : null);
    }).resolveAllNotNull();

    return elements;
  }

  FutureOr<bool> removeInvalidElementsFromPool() {
    FutureOr<List<O>> ret = invalidPoolElements();

    return ret.resolveMapped((l) {
      for (var o in l) {
        removeFromPool(o);
      }
      return true;
    });
  }

  FutureOr<bool> isPoolElementValid(O o);

  FutureOr<bool> clearPool() {
    _pool.clear();
    return true;
  }

  int get poolSize => _pool.length;

  bool get isPoolEmpty => poolSize == 0;

  bool get isPoolNotEmpty => !isPoolEmpty;

  int get poolCreatedElementsCount => _createElementCount;

  int get poolDisposedElementsCount =>
      _closedElementsCount + _unrecycledElementCount;

  int get poolAliveElementsSize =>
      poolCreatedElementsCount - poolDisposedElementsCount;

  int _createElementCount = 0;

  FutureOr<O?> createPoolElement() {
    ++_createElementCount;
    return null;
  }

  Completer<bool>? _waitingPoolElement;

  FutureOr<O> catchFromPool({Duration? timeout}) {
    if (_pool.isEmpty) {
      return _catchFromEmptyPool(timeout);
    } else {
      return _catchFromPopulatedPool();
    }
  }

  int get poolSizeDesiredLimit;

  static final Duration _defaultPoolYieldTimeout = Duration(milliseconds: 100);

  Duration get poolYieldTimeout => _defaultPoolYieldTimeout;

  final QueueList<Completer<bool>> _yields = QueueList(8);

  FutureOr<O> _catchFromEmptyPool(Duration? timeout) {
    var alive = poolAliveElementsSize;

    FutureOr<O?> created;

    if (alive > poolSizeDesiredLimit) {
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

      var waitingPoolElement = _waitingPoolElement ??= Completer<bool>();

      var ret = waitingPoolElement.future.then((_) {
        if (_pool.isNotEmpty) {
          return _catchFromPopulatedPool();
        } else {
          return _waitElementInPool();
        }
      });

      if (timeout != null) {
        return ret.timeout(timeout, onTimeout: () {
          throw PoolTimeoutError("Catch from Pool timeout[$timeout]: $this");
        });
      } else {
        return ret;
      }
    });
  }

  FutureOr<O> _catchFromPopulatedPool() {
    var o = _pool.removeLast();

    var waitingPoolElement = _waitingPoolElement;
    if (waitingPoolElement != null) {
      if (!waitingPoolElement.isCompleted) {
        waitingPoolElement.complete(false);
      }
      _waitingPoolElement = null;
    }

    return preparePoolElement(o);
  }

  FutureOr<O> _waitElementInPool() async {
    while (true) {
      var waitingPoolElement = _waitingPoolElement ??= Completer<bool>();

      await waitingPoolElement.future;

      if (_pool.isNotEmpty) {
        return _catchFromPopulatedPool();
      }
    }
  }

  FutureOr<O> preparePoolElement(O o) => o;

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

    if (poolSize <= minSize) return true;

    if (poolSize > maxSize) {
      return removeInvalidElementsFromPool().resolveMapped((_) {
        var excess = this.poolSize - maxSize;
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
    var retValid = isPoolElementValid(o);
    return retValid.resolveMapped((valid) => valid ? o : null);
  }

  int _unrecycledElementCount = 0;

  FutureOr<bool> releaseIntoPool(O o) {
    var ret = recyclePoolElement(o);

    return ret.resolveMapped((recycled) {
      if (recycled != null) {
        checkPool();
        _pool.addLast(recycled);

        if (_yields.isNotEmpty) {
          var yield = _yields.removeFirst();
          if (!yield.isCompleted) {
            yield.complete(true);
          }
        }

        var waitingPoolElement = _waitingPoolElement;
        if (waitingPoolElement != null && !waitingPoolElement.isCompleted) {
          waitingPoolElement.complete(true);
        }

        return true;
      } else {
        ++_unrecycledElementCount;
        return false;
      }
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
      {Duration? timeout, bool Function(O o)? validator}) {
    return catchFromPool(timeout: timeout).then((o) {
      try {
        var ret = f(o);
        return ret.resolveMapped((val) {
          if (validator == null || validator(o)) {
            releaseIntoPool(o);
          } else {
            disposePoolElement(o);
          }
          return val;
        });
      } catch (_) {
        disposePoolElement(o);
        rethrow;
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
      List<String>.unmodifiable(fieldsNames.map((f) => fieldToLCKey(f)));

  List<String> buildFieldsNamesSimple(List<String> fieldsNames) {
    return List<String>.unmodifiable(
        fieldsNames.map((f) => fieldToSimpleKey(f)));
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

    var entries = fieldsNames.map((f) {
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
          entry = MapEntry(f, null);
        }
      } else if (returnMapUsedKeys != null) {
        var mapField = returnMapField![0];
        returnMapUsedKeys.add(mapField);
      }

      return entry;
    }).whereNotNull();

    var fields = Map<String, Object?>.fromEntries(entries);

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

  /// Returns a [field] value from [map].
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

  String fieldToLCKey(String key) => key.toLowerCase();

  String fieldToSimpleKey(String key) => defaultFieldToSimpleKey(key);

  static final RegExp _regexpLettersAndDigits = RegExp(r'[^a-zA-Z\d]');

  static String defaultFieldToSimpleKey(String key) =>
      key.toLowerCase().replaceAll(_regexpLettersAndDigits, '');
}

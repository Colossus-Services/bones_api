import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;

final _log = logging.Logger('Initializable');

typedef ExecuteInitializedCallback<R> = FutureOr<R> Function();

mixin Initializable {
  static const Set<String> interfaceMethodsNames = <String>{
    'checkInitialized',
    'doInitialization',
    'ensureInitialized',
    'ensureInitializedAsync',
    'executeInitialized',
    'initialize',
    'initializeDependencies',
  };

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

  static int _initializationIDCount = 0;

  int _initializationID = 0;

  bool _initializing = false;
  bool _initialized = false;
  bool _asyncInitialization = false;

  /// Returns `true` if this instance is in the middle of the initialization process.
  bool get isInitializing => _initializing;

  /// Returns `true` if this instance is already initialized.
  bool get isInitialized => _initialized;

  /// Returns `true` if this instance initialization was asynchronous.
  bool get isAsyncInitialization => _asyncInitialization;

  Future<bool>? _initializeDependenciesAsync;
  Future<bool>? _initializeAsync;

  FutureOr<bool> _doInitializationImpl() {
    if (_initialized) return true;

    var initializeAsync = _initializeAsync;
    if (initializeAsync != null) {
      return initializeAsync;
    }

    var initializeDependenciesAsync = _initializeDependenciesAsync;
    if (initializeDependenciesAsync != null) {
      return initializeDependenciesAsync;
    }

    // Avoid recursive call to this initialization:
    if (_initializing) {
      return true;
    }

    _initializing = true;
    _initializationID = ++_initializationIDCount;

    var initDepsCall = initializeDependencies();

    if (initDepsCall is Future<List<Initializable>>) {
      _asyncInitialization = true;

      return _initializeDependenciesAsync =
          initDepsCall.then((dependencies) async {
        return _doDependenciesInitialization(dependencies)
            .resolveMapped((depsInit) {
          _checkAllDependenciesOk(depsInit);
          return _callInitialize();
        });
      });
    } else {
      _asyncInitialization =
          initDepsCall.any((dep) => dep.isAsyncInitialization);

      return _doDependenciesInitialization(initDepsCall)
          .resolveMapped((depsInit) {
        _checkAllDependenciesOk(depsInit);
        return _callInitialize();
      });
    }
  }

  void _checkAllDependenciesOk(List<bool> depsInit) {
    if (depsInit.any((ok) => !ok)) {
      throw StateError("Error initializing dependencies: $this");
    }
  }

  List<Initializable>? _initializedDependencies;

  Map<Initializable, Completer<bool>>? _initializedDependenciesCompleters;

  FutureOr<List<bool>> _doDependenciesInitialization(
      List<Initializable> dependencies) {
    if (dependencies.isEmpty) return <bool>[];

    _initializedDependencies = dependencies.toList();

    var depsInits =
        dependencies.map((e) => MapEntry(e, e.doInitialization())).toList();

    var depsInitsAsync = depsInits
        .where((e) => e.value is Future<bool>)
        .map((e) => MapEntry(e.key, e.value as Future<bool>))
        .toList();

    var depsCompleters = depsInitsAsync
        .map((e) => MapEntry(e.key, e.value.toCompleter()))
        .toList();

    if (depsCompleters.isNotEmpty) {
      _initializedDependenciesCompleters =
          Map<Initializable, Completer<bool>>.fromEntries(depsCompleters);
    }

    var depsInitializingAsync =
        dependencies.whereInitializing().whereAsyncInitialization();

    if (depsInitializingAsync.isNotEmpty) {
      var subDepsInitializing =
          _subDependenciesInitialized(depsInitializingAsync);

      if (subDepsInitializing.containsIdentical(this)) {
        _log.warning(
            'Found self reference in async initialization graph: $this -> $depsInitializingAsync ->> $subDepsInitializing');

        for (var dep in dependencies) {
          dep._completeCircularDependency(this);
        }
      }
    }

    var depsInitsResolved =
        Map<Initializable, FutureOr<bool>>.fromEntries(depsInits);
    for (var e in depsCompleters) {
      depsInitsResolved[e.key] = e.value.future;
    }

    return depsInitsResolved.values.resolveAll();
  }

  FutureOr<bool> _callInitialize() {
    var ret = initialize();

    if (ret is Future<bool>) {
      _asyncInitialization = true;

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

  void _completeCircularDependency(Initializable dependency) {
    var completers = _initializedDependenciesCompleters;
    if (completers == null) return;

    var completer = completers[dependency];

    if (completer != null && !completer.isCompleted) {
      _log.warning(
          'Not waiting self reference `$dependency` in async initialization graph of `$this`.');

      completer.complete(true);
    }
  }

  List<Initializable> get initializedDependencies =>
      <Initializable>[...?_initializedDependencies];

  int get initializedDependenciesLength =>
      _initializedDependencies?.length ?? 0;

  List<Initializable> get initializedDependenciesDeeply =>
      _allInitializedDependenciesDeeply();

  int get initializedDependenciesDeeplyLength =>
      initializedDependenciesDeeply.length;

  List<Initializable> _allInitializedDependenciesDeeply(
      [List<Initializable>? allDeep]) {
    allDeep ??= <Initializable>[];

    var deps = _initializedDependencies;
    if (deps == null || deps.isEmpty) return allDeep;

    var newDeps = deps.where((d) => !allDeep!.containsIdentical(d)).toList();
    allDeep.addAll(newDeps);

    for (var d in newDeps) {
      d._allInitializedDependenciesDeeply(allDeep);
    }

    return allDeep;
  }

  List<Initializable> _subDependenciesInitialized(
      List<Initializable> depsInitializing) {
    var subDeps = <Initializable>[];

    for (var dep in depsInitializing) {
      dep._allInitializedDependenciesDeeply(subDeps);
    }

    return subDeps;
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

  /// Returns the initialization status as [String]. Examples:
  /// - `initialized`
  /// - `initializing`
  /// - `initialized[async]`
  /// - `initializing[async]`
  String get initializationStatus {
    var asyncStr = isAsyncInitialization ? '[async]' : '';

    if (isInitialized) {
      return 'initialized$asyncStr';
    } else if (isInitializing) {
      return 'initializing$asyncStr';
    } else {
      return 'idle';
    }
  }
}

extension InitializableListExtension<T extends Initializable> on List<T> {
  void sortByInitializationOrder() {
    sort((a, b) => a._initializationID.compareTo(b._initializationID));
  }

  List<T> whereInitializing() => where((e) => e.isInitializing).toList();

  List<T> whereAsyncInitialization() =>
      where((e) => e.isAsyncInitialization).toList();
}

extension _ListExtension<T> on List<T> {
  bool containsIdentical(T elem) => any((e) => identical(e, elem));
}

extension _FutureExtension<T> on Future<T> {
  Completer<T> toCompleter() {
    var completer = Completer<T>();
    then((val) {
      if (!completer.isCompleted) {
        completer.complete(val);
      }
    });
    return completer;
  }
}

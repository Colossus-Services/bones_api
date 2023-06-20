import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:statistics/statistics.dart';

import 'bones_api_utils.dart';

final _log = logging.Logger('Initializable');

typedef ExecuteInitializedCallback<R> = FutureOr<R> Function();

/// The initialization status of the [initializable] instance.
class InitializationStatus {
  /// The [Initializable] instance of this status.
  final Initializable initializable;

  InitializationStatus._(this.initializable);

  static int _idCount = 0;

  int _id = 0;

  /// The [initializable] ID (defined by initialization order).
  int get id => _id;

  bool _initialized = false;

  /// Returns `true` if [initializable] is already initialized.
  bool get initialized => _initialized;

  void _setInitialized() {
    _initialized = true;
    _initializing = false;
    _finalizing = false;
  }

  bool _initializing = false;

  void _setInitializing() {
    _initializing = true;
    _id = ++_idCount;
  }

  /// Returns `true` if [initializable] is initializing.

  bool get initializing => _initializing;

  bool _finalizing = false;

  void _setFinalizing() {
    _finalizing = true;
  }

  /// Returns `true` if [initializable] is finalizing.
  bool get finalizing => _finalizing;

  bool _asynchronous = false;

  /// Returns `true` if [initializable] has an asynchronous initialization.
  bool get asynchronous => _asynchronous;

  void _markAsynchronous(bool async) {
    if (async) {
      _asynchronous = true;
    }
  }

  /// Returns `true` if is not initialized yet and not initializing.
  bool get idle => !initialized && !initializing;

  /// Returns the initialization status as [String]. Examples:
  /// - `initialized`
  /// - `initializing`
  /// - `initialized[async]`
  /// - `initializing[async]`
  String get status {
    var asyncStr = asynchronous ? '[async]' : '';

    if (initialized) {
      return 'initialized$asyncStr';
    } else if (_finalizing) {
      return 'finalizing$asyncStr';
    } else if (initializing) {
      return 'initializing$asyncStr';
    } else {
      return 'idle';
    }
  }

  @override
  String toString() {
    var id = this.id;
    var idStr = id > 0 ? '#$id' : '';
    return '${initializable.runtimeTypeNameUnsafe}$idStr:$status';
  }
}

/// The initialization result of a [Initializable] instance.
class InitializationResult {
  /// The [Initializable] of this result.
  final Initializable initializable;

  /// `true` if the initialization was OK.
  final bool ok;

  /// The dependencies of this [Initializable] instance.
  final List<Initializable> dependencies;

  InitializationResult(this.initializable, this.ok,
      {Iterable<Initializable>? dependencies})
      : dependencies = dependencies?.toList() ?? <Initializable>[];

  factory InitializationResult.ok(Initializable initializable,
      {Iterable<Initializable>? dependencies}) {
    return InitializationResult(initializable, true,
        dependencies: dependencies);
  }

  factory InitializationResult.error(Initializable initializable) =>
      InitializationResult(initializable, false);

  @override
  String toString() {
    var depsStr = dependencies.isNotEmpty
        ? '->${dependencies.length <= 3 ? dependencies.toInitializationStatus() : dependencies.length}'
        : '';

    return '[${ok ? 'OK' : 'ERROR'}]@${initializable.initializationStatus}$depsStr';
  }
}

class _InitializationChain {
  final Initializable initializable;

  _InitializationChain._(this.initializable);

  List<Initializable>? _parents;

  List<Initializable> get parents => _parents?.toList() ?? <Initializable>[];

  int get parentsLength => _parents?.length ?? 0;

  Initializable? get firstParent => _parents?.first;

  bool _addParent(Initializable parent) {
    var parents = _parents ??= <Initializable>[];
    return parents.addUnique(parent);
  }

  bool _isParent(Initializable o) {
    var parents = _parents;
    if (parents == null || parents.isEmpty) return false;

    var allParents = <Initializable>{
      // Avoid analyzing dependencies of `initializable`
      // if it exists in the parent's tree:
      initializable,
    };

    var parents2 = <Initializable>{};

    for (var p in parents) {
      if (identical(p, o)) return true;
      parents2.addAllNew(p._chain.parents, allParents);
    }

    if (parents2.isEmpty) return false;

    var parents3 = <Initializable>{};

    for (var p in parents2) {
      if (identical(p, o)) return true;
      parents3.addAllNew(p._chain.parents, allParents);
    }

    if (parents3.isEmpty) return false;

    var parents4 = <Initializable>{};

    for (var p in parents3) {
      if (identical(p, o)) return true;
      parents4.addAllNew(p._chain.parents, allParents);
    }

    if (parents4.isEmpty) return false;

    var parents5 = <Initializable>{};

    for (var p in parents4) {
      if (identical(p, o)) return true;
      parents5.addAllNew(p._chain.parents, allParents);
    }

    if (parents5.isEmpty) return false;

    for (var p in parents5) {
      if (identical(p, o)) return true;
    }

    for (var p in parents5) {
      if (p._chain._isParent(o)) return true;
    }

    return false;
  }

  bool _isAnyParent(Iterable<Initializable> elems) => elems.any(_isParent);

  bool _isCircularParent(Initializable parent) {
    if (parent._chain._isParent(initializable)) {
      return true;
    }

    var parent0 = firstParent;
    if (parent0 == null) return false;

    var parentParents = parent._chain._parents;
    if (parentParents == null || parentParents.isEmpty) return false;

    if (parent0._chain._isAnyParent(parentParents)) {
      return true;
    }

    return false;
  }

  List<Initializable>? _dependencies;

  List<Initializable> get dependencies =>
      _dependencies?.toList() ?? <Initializable>[];

  void _addAllDependencies(Iterable<Initializable> deps) {
    var depsValid = deps.where((dep) => !identical(dep, initializable));

    var dependencies = _dependencies ??= <Initializable>[];
    dependencies.addAllUnique(depsValid);
  }

  void _checkDependency(Initializable dependency) {
    var dependencies = _dependencies;
    if (dependencies == null || !dependencies.containsIdentical(dependency)) {
      throw StateError("Dependency not in chain: $dependency");
    }
  }

  ({
    List<Initializable> valids,
    List<Initializable> circular,
    List<Initializable> finalizing
  }) _filterValidDependencies(Iterable<Initializable> dependencies) {
    var valids = <Initializable>[];
    var circular = <Initializable>[];
    var finalizing = <Initializable>[];

    for (var e in dependencies) {
      if (identical(e, initializable) || e._status.initialized) {
        continue;
      }

      if (!_isParent(e) && !e._chain._isParent(initializable)) {
        valids.add(e);
      } else if (e._status.finalizing) {
        finalizing.add(e);
      } else {
        circular.add(e);
      }
    }

    return (valids: valids, circular: circular, finalizing: finalizing);
  }

  List<Initializable>? _initializedDependencies;

  bool _markInitializedDependency(Initializable dependency) {
    _checkDependency(dependency);

    var initializedDependencies =
        _initializedDependencies ??= <Initializable>[];
    return initializedDependencies.addUnique(dependency);
  }

  void _markInitializedDependencies(Iterable<Initializable> dependencies) {
    for (var dep in dependencies) {
      _markInitializedDependency(dep);
    }
  }

  List<Initializable> _allInitializedDependenciesDeeply(
      [List<Initializable>? allDeep]) {
    allDeep ??= <Initializable>[];

    var deps = _initializedDependencies;
    if (deps == null || deps.isEmpty) return allDeep;

    var newDeps = deps.where((d) => !allDeep!.containsIdentical(d)).toList();
    allDeep.addAll(newDeps);

    for (var d in newDeps) {
      d._chain._allInitializedDependenciesDeeply(allDeep);
    }

    return allDeep;
  }

  Map<Initializable, Completer<InitializationResult>>?
      _initializedDependenciesCompleters;

  void _setInitializedDependencyCompleter(
      Initializable dependency, Completer<InitializationResult> completer) {
    _checkDependency(dependency);

    var initializedDependenciesCompleters =
        _initializedDependenciesCompleters ??=
            <Initializable, Completer<InitializationResult>>{};

    var prev = initializedDependenciesCompleters[dependency];
    if (prev != null && !identical(prev, completer)) {
      throw StateError("Dependency completer already set!");
    }

    initializedDependenciesCompleters[dependency] = completer;
  }

  void _setInitializedDependenciesCompleters(
      Iterable<MapEntry<Initializable, Completer<InitializationResult>>>
          entries) {
    for (var e in entries) {
      _setInitializedDependencyCompleter(e.key, e.value);
    }
  }

  bool _completeCircularDependency(
      Initializable dependency, List<Initializable> callChain) {
    if (identical(initializable, dependency)) return false;

    if (callChain.containsIdentical(initializable)) return false;
    callChain.add(initializable);

    var completed = false;

    var completers = _initializedDependenciesCompleters;
    if (completers != null) {
      var completer = completers[dependency];

      if (completer != null && !completer.isCompleted) {
        _log.warning(
            '[$runtimeTypeNameUnsafe] Not waiting self reference `${dependency.initializationStatus}` '
            'in async initialization graph of `${initializable.initializationStatus}`.');

        completer.complete(dependency._resultOk());
        completed = true;
      }

      for (var e in completers.entries) {
        var dep = e.key;
        if (dep._chain._isParent(dependency)) {
          var completer = e.value;

          _log.warning(
              '[$runtimeTypeNameUnsafe] Not waiting indirect self reference `${dependency.initializationStatus}` '
              'in async initialization graph of `${initializable.initializationStatus}`.');

          completer.complete(dependency._resultOk());
          completed = true;
        }
      }
    }

    var initializedDependencies = _initializedDependencies;
    if (initializedDependencies != null) {
      for (var dep in initializedDependencies) {
        if (dep.isInitializing) {
          if (dep._chain._completeCircularDependency(dependency, callChain)) {
            completed = true;
          }
        }
      }
    }

    return completed;
  }

  void _checkAllCircularDependencies() {
    _checkCircularDependencies();
    _checkParentsCircularDependencies();
  }

  void _checkParentsCircularDependencies() {
    var parents = _parents;
    if (parents == null) return;

    for (var p in parents) {
      p._chain._checkCircularDependencies();
    }
  }

  void _checkCircularDependencies([List<Initializable>? dependencies]) {
    dependencies ??= _dependencies;
    if (dependencies == null || dependencies.isEmpty) return;

    var depsInitializingAsync =
        dependencies.whereInitializing().whereAsyncInitialization();

    if (depsInitializingAsync.isEmpty) return;

    var subDepsInitializing =
        depsInitializingAsync._subDependenciesInitialized();

    //print('!!! depsInitializingAsync: $runtimeTypeNameUnsafe >> ${depsInitializingAsync.toInitializationStatus()}');
    //print('!!! subDepsInitializing: $runtimeTypeNameUnsafe >> ${subDepsInitializing.toInitializationStatus()}');

    if (subDepsInitializing.containsIdentical(initializable)) {
      var callChain = <Initializable>[];
      var completed = false;

      for (var dep in dependencies) {
        if (dep._chain._completeCircularDependency(initializable, callChain)) {
          completed = true;
        }
      }

      if (completed) {
        _log.warning(
            '[${initializable.runtimeTypeNameUnsafe}] Found self reference in async initialization graph: ${initializable.initializationStatus} -> '
            '${depsInitializingAsync.length <= 3 ? '${depsInitializingAsync.toInitializationStatus()}' : '${depsInitializingAsync.length}'} ->> '
            '${subDepsInitializing.length <= 3 ? '${subDepsInitializing.toInitializationStatus()}' : '${subDepsInitializing.length}'}');
      }
    }
  }
}

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

  late final _InitializationChain _chain = _InitializationChain._(this);

  late final InitializationStatus _status = InitializationStatus._(this);

  /// Returns the current [InitializationStatus].
  InitializationStatus get initializationStatus => _status;

  int get _initializationID => _status._id;

  /// Ensures that this instance is initialized.
  FutureOr<InitializationResult> ensureInitialized({Initializable? parent}) =>
      _doInitializationImpl(parent);

  /// Ensures that this instance is initialized. If is not
  /// initialized yet it will force an asynchronous initialization
  /// and return a [Future].
  FutureOr<InitializationResult> ensureInitializedAsync(
      {Initializable? parent}) {
    if (_status.initialized) return _resultOk();
    return Future<InitializationResult>.microtask(
        () => _doInitializationImpl(parent));
  }

  /// Initialize this instance if is not initialized yet.
  FutureOr<InitializationResult> doInitialization({Initializable? parent}) =>
      _doInitializationImpl(parent);

  /// Returns `true` if this instance is already initialized.
  bool get isInitialized => _status.initialized;

  /// Returns `true` if this instance is in the middle of the initialization process.
  bool get isInitializing => _status.initializing;

  /// Returns `true` if this instance initialization was asynchronous.
  bool get isAsyncInitialization => _status._asynchronous;

  Future<InitializationResult>? _initializeDependenciesAsync;
  Future<InitializationResult>? _initializeAsync;

  FutureOr<InitializationResult> _doInitializationImpl(
      [Initializable? parent]) {
    if (_status.initialized) return _resultOk();

    final chain = _chain;

    if (parent != null) {
      if (!chain._addParent(parent)) {
        chain._checkAllCircularDependencies();
        return _resultOk();
      }

      if (!parent._status.initialized && chain._isCircularParent(parent)) {
        _log.warning('AVOIDING CIRCULAR INITIALIZATION: $this -> $parent');
        chain._checkAllCircularDependencies();

        var initCircular = _doInitializationImpl2(parent);

        if (initCircular is! Future<InitializationResult>) {
          return initCircular;
        }

        return initCircular.timeout(Duration(milliseconds: 1000),
            onTimeout: () {
          _log.warning("Circular initialization timeout: $this");
          return _resultOk();
        });
      }
    }

    return _doInitializationImpl2(parent);
  }

  FutureOr<InitializationResult> _doInitializationImpl2(Initializable? parent) {
    final chain = _chain;
    final status = _status;

    var initializeAsync = _initializeAsync;
    if (initializeAsync != null) {
      return initializeAsync;
    }

    var initializeDependenciesAsync = _initializeDependenciesAsync;
    if (initializeDependenciesAsync != null) {
      return initializeDependenciesAsync;
    }

    // Avoid recursive call to this initialization:
    if (status.initializing) {
      chain._checkAllCircularDependencies();
      return _resultOk();
    }

    status._setInitializing();

    _log.info(
        '[$runtimeTypeNameUnsafe#$_initializationID] Initializing${parent == null ? ' (ROOT)' : ''}...');

    var initDeps = initializeDependencies();

    if (initDeps is Future<List<Initializable>>) {
      status._markAsynchronous(true);

      return _initializeDependenciesAsync = initDeps.then((initDeps) async {
        return _doDependenciesInitialization(initDeps)
            .resolveMapped((depsInit) {
          _checkAllDependenciesOk(depsInit.results);
          return _callInitialize();
        });
      });
    } else {
      var hasAsyncDep = initDeps.any((dep) => dep.isAsyncInitialization);
      status._markAsynchronous(hasAsyncDep);

      return _doDependenciesInitialization(initDeps).resolveMapped((depsInit) {
        _checkAllDependenciesOk(depsInit.results);
        return _callInitialize();
      });
    }
  }

  void _checkAllDependenciesOk(List<InitializationResult> depsInit) {
    if (depsInit.any((res) => !res.ok)) {
      throw StateError("Error initializing dependencies: $this");
    }
  }

  InitializationResult _resultOk() =>
      InitializationResult.ok(this, dependencies: _chain._dependencies);

  FutureOr<_DependenciesInitialization> _doDependenciesInitialization(
      List<Initializable> dependencies,
      {bool forceCircular = false}) {
    if (dependencies.isEmpty) {
      return _DependenciesInitialization(<InitializationResult>[],
          dependencies: null);
    }

    final chain = _chain;
    chain._addAllDependencies(dependencies);

    dependencies = dependencies.where((e) => !e.isInitialized).toList();

    var depsStep1 = chain._filterValidDependencies(dependencies);
    var initValids1 = _doDependenciesInitializationImpl(depsStep1.valids);

    if (depsStep1.circular.isEmpty && depsStep1.finalizing.isEmpty) {
      return _DependenciesInitialization.async(initValids1,
          dependencies: dependencies);
    }

    if (forceCircular) {
      return initValids1.resolveMapped((initValids1) {
        var initCirculars1 =
            _doDependenciesInitializationImpl(depsStep1.circular);

        return initCirculars1.resolveMapped((initCirculars1) {
          return _DependenciesInitialization(
              [...initValids1, ...initCirculars1],
              dependencies: dependencies);
        });
      });
    }

    // All dependencies are circular:
    if (depsStep1.valids.isEmpty) {
      return Future.delayed(Duration(milliseconds: 1), () {
        var depsStep2 = chain._filterValidDependencies(depsStep1.circular);
        var initValids2 = _doDependenciesInitializationImpl(depsStep2.valids);

        return initValids2.resolveMapped((initValids2) {
          return _DependenciesInitialization(initValids2,
              dependencies: dependencies);
        });
      });
    }

    return initValids1.resolveMapped((initValids1) {
      var depsStep2 = chain._filterValidDependencies(depsStep1.circular);
      var initValids2 = _doDependenciesInitializationImpl(depsStep2.valids);

      if (depsStep2.circular.isEmpty) {
        return initValids2.resolveMapped((initValids2) {
          return _DependenciesInitialization([...initValids1, ...initValids2],
              dependencies: dependencies);
        });
      }

      return Future.delayed(Duration(milliseconds: 1), () {
        return initValids2.resolveMapped((initValids2) {
          var depsStep3 = chain._filterValidDependencies(depsStep2.circular);
          var initValids3 = _doDependenciesInitializationImpl(depsStep3.valids);

          return initValids3.resolveMapped((initValids3) {
            return _DependenciesInitialization(
                [...initValids1, ...initValids2, ...initValids3],
                dependencies: dependencies);
          });
        });
      });
    });
  }

  FutureOr<List<InitializationResult>> _doDependenciesInitializationImpl(
      List<Initializable> dependencies) {
    if (dependencies.isEmpty) {
      return <InitializationResult>[];
    }

    final chain = _chain;

    chain._markInitializedDependencies(dependencies);

    var depsInits = dependencies
        .map((e) => MapEntry(e, e._doInitializationImpl(this)))
        .toList();

    var depsInitsAsync = depsInits
        .where((e) => e.value is Future<InitializationResult>)
        .map((e) => MapEntry(e.key, e.value as Future<InitializationResult>))
        .toList();

    var depsCompleters = depsInitsAsync
        .map((e) => MapEntry(e.key, e.value.toCompleter()))
        .toList();

    chain._setInitializedDependenciesCompleters(depsCompleters);

    chain._checkCircularDependencies(dependencies);

    var depsInitsResolved =
        Map<Initializable, FutureOr<InitializationResult>>.fromEntries(
            depsInits);

    for (var e in depsCompleters) {
      depsInitsResolved[e.key] = e.value.future;
    }

    return depsInitsResolved.values.resolveAll();
  }

  FutureOr<InitializationResult> _callInitialize() {
    var ret = initialize();

    if (ret is Future<InitializationResult>) {
      _status._markAsynchronous(true);
      return _initializeAsync = ret.then(_finalizeInitialization);
    } else {
      return _finalizeInitialization(ret);
    }
  }

  FutureOr<InitializationResult> _finalizeInitialization(
      InitializationResult result) {
    if (!result.ok) {
      _log.info(
          '[$runtimeTypeNameUnsafe] Initialized #$_initializationID: ERROR');
      throw StateError("Error initializing (async): $this");
    }

    _status._setFinalizing();

    var dependencies = result.dependencies.uniqueEntries();

    if (!identical(this, result.initializable)) {
      dependencies = <Initializable>[result.initializable, ...dependencies]
          .uniqueEntries();
      result = InitializationResult.ok(this, dependencies: dependencies);
    }

    if (dependencies.isEmpty) {
      _log.info('[$runtimeTypeNameUnsafe#$_initializationID] Initialized: OK');

      _status._setInitialized();
      _initializeAsync = null;

      return result;
    }

    return _doDependenciesInitialization(dependencies)
        .resolveMapped((depsResults) {
      if (depsResults.hasSkipped) {
        var skipped = depsResults.skipped
            ?.notInitialized(ignoreFinalizing: true)
            .toList();

        if (skipped?.isNotEmpty ?? false) {
          return _doDependenciesInitialization(dependencies,
                  forceCircular: true)
              .resolveMapped((depsResults2) {
            var allDepsResults =
                depsResults.merge(depsResults2, dependencies: dependencies);
            return _finalizeInitializationWithDeps(allDepsResults, result);
          });
        }
      }

      return _finalizeInitializationWithDeps(depsResults, result);
    });
  }

  InitializationResult _finalizeInitializationWithDeps(
      _DependenciesInitialization depsResults, InitializationResult result) {
    if (depsResults.hasSkipped) {
      var skipped =
          depsResults.skipped?.notInitialized(ignoreFinalizing: true).toList();

      if (skipped?.isNotEmpty ?? false) {
        _log.warning(
            'Skipped from initialization> $runtimeTypeNameUnsafe  -> ${skipped?.toInitializationStatus()}');
      }
    }

    _checkAllDependenciesOk(depsResults.results);

    _log.info(
        '[$runtimeTypeNameUnsafe#$_initializationID] Initialized: OK (result dependencies: ${depsResults.resultsLength})');

    _status._setInitialized();
    _initializeAsync = null;

    return result;
  }

  /// Return a [List] of [Initializable] instances that need to be initialized
  /// BEFORE [initialize] this instance.
  ///
  /// See [doInitialization].
  FutureOr<List<Initializable>> initializeDependencies() => <Initializable>[];

  /// Initialization implementation. Do not call it directly, use [doInitialization].
  ///
  /// It can be a synchronous (returning a [bool]) or an asynchronous
  /// implementation (returning a [Future]<[bool]>).
  ///
  /// See [initializeDependencies].
  FutureOr<InitializationResult> initialize() => InitializationResult.ok(this);

  /// Checks if this instance is initialized.
  ///
  /// Throws a [StateError] if is not initialized and
  /// can't initialize it synchronously.
  void checkInitialized() {
    if (!isInitialized) {
      if (isInitializing) return;

      // ignore: discarded_futures
      var ret = _doInitializationImpl();
      if (ret is Future<InitializationResult>) {
        throw StateError(
            "Not initialized yet! Async initialization for: $this");
      }
    }
  }

  /// Executes the [callback] ensuring that this instances was fully initialized.
  FutureOr<R> executeInitialized<R>(ExecuteInitializedCallback<R> callback,
      {Initializable? parent}) {
    if (isInitialized) {
      return callback();
    }

    var ret = ensureInitialized(parent: parent);

    if (ret is Future<InitializationResult>) {
      return ret.then((result) {
        if (!result.ok) {
          throw StateError("Error initializing (async): $this");
        }
        return callback();
      });
    } else {
      if (!ret.ok) {
        throw StateError("Error initializing: $this");
      }

      return callback();
    }
  }
}

class _DependenciesInitialization {
  final List<InitializationResult> results;

  late final List<Initializable>? skipped;

  _DependenciesInitialization(this.results,
      {required List<Initializable>? dependencies}) {
    List<Initializable>? skipped;

    if (dependencies != null) {
      var resultsDeps =
          results.map((e) => e.initializable).toList(growable: false);
      skipped = dependencies.where((e) => !resultsDeps.contains(e)).toList();

      if (skipped.isNotEmpty) {
        var skippedFinished = skipped.initialized;

        if (skippedFinished.isNotEmpty) {
          skipped.removeAll(skippedFinished);

          var skippedFinishedResults =
              skippedFinished.map((e) => e._resultOk());
          results.addAll(skippedFinishedResults);
        }
      }

      if (skipped.isEmpty) {
        skipped = null;
      }
    }

    this.skipped = skipped;
  }

  static FutureOr<_DependenciesInitialization> async(
      FutureOr<List<InitializationResult>> results,
      {required List<Initializable>? dependencies}) {
    return results.resolveMapped((results) =>
        _DependenciesInitialization(results, dependencies: dependencies));
  }

  bool get hasSkipped => skipped?.isNotEmpty ?? false;

  int get resultsLength => results.length;

  _DependenciesInitialization merge(_DependenciesInitialization other,
      {required List<Initializable>? dependencies}) {
    var allResults = [...results, ...other.results]
        .groupBy((dep) => dep.initializable)
        .map((dep, res) => MapEntry(dep, res.first))
        .values
        .toList();

    return _DependenciesInitialization(allResults, dependencies: dependencies);
  }

  @override
  String toString() {
    return '_DependenciesInitialization{results: $results, skipped: $skipped}';
  }
}

extension InitializableListExtension<T extends Initializable> on List<T> {
  void sortByInitializationOrder() {
    sort((a, b) => a._initializationID.compareTo(b._initializationID));
  }

  List<T> whereNotInitialized() =>
      where((e) => !e.isInitialized && !e.isInitializing).toList();

  List<T> whereInitializing() => where((e) => e.isInitializing).toList();

  List<T> whereAsyncInitialization() =>
      where((e) => e.isAsyncInitialization).toList();

  List<Initializable> _subDependenciesInitialized() {
    var subDeps = <Initializable>[];

    for (var dep in this) {
      dep._chain._allInitializedDependenciesDeeply(subDeps);
    }

    return subDeps;
  }

  List<InitializationStatus> toInitializationStatus() =>
      map((e) => e.initializationStatus).toList();

  List<T> get initialized => where((e) => e._status.initialized).toList();

  List<T> get finalizing => where((e) => e._status.finalizing).toList();

  List<T> get initializing => where((e) => e._status.initializing).toList();

  List<T> get idle =>
      where((e) => !e._status.initialized && !e._status.initializing).toList();

  List<T> notInitialized({bool ignoreFinalizing = false}) => where((e) =>
      !e._status.initialized &&
      (!ignoreFinalizing || !e._status.finalizing)).toList();
}

extension _ListExtension<T> on List<T> {
  bool containsIdentical(T elem) => any((e) => identical(e, elem));

  bool addUnique(T elem) {
    if (!containsIdentical(elem)) {
      add(elem);
      return true;
    }
    return false;
  }

  void addAllUnique(Iterable<T> elems) {
    for (var e in elems) {
      addUnique(e);
    }
  }

  List<T> uniqueEntries() {
    var l = <T>[];
    l.addAllUnique(this);
    return l;
  }
}

extension _SetExtension<T> on Set<T> {
  void addAllNew(Iterable<T> elems, Set<T> seen) {
    for (var e in elems) {
      addNew(e, seen);
    }
  }

  bool addNew(T elem, Set<T> seen) {
    if (seen.add(elem)) {
      add(elem);
      return true;
    }
    return false;
  }
}

extension _FutureExtension<T> on Future<T> {
  Completer<T> toCompleter() {
    var completer = Completer<T>();
    // ignore: discarded_futures
    then((val) {
      if (!completer.isCompleted) {
        completer.complete(val);
      }
    });
    return completer;
  }
}

/// The initialization framework: objects that must be initialized, once,
/// after their dependencies, possibly asynchronously, in graphs that can be
/// cyclic (self-referenced).
///
/// ## Model
///
/// An [Initializable] declares:
/// - [Initializable.initializeDependencies]: the dependencies to initialize
///   **before** its [Initializable.initialize] (pre-dependencies).
/// - [Initializable.initialize]: its own initialization. The returned
///   [InitializationResult.dependencies] are initialized **after** it
///   (post-dependencies). If the result is of another [Initializable] `X`
///   (e.g. `return adapter.ensureInitialized(parent: this)`), `X` is a
///   post-dependency too (a *merged* initializable), and its dependencies are
///   reported as this one's.
///
/// Calling [Initializable.ensureInitialized] / [Initializable.doInitialization]
/// runs the phases: pre-dependencies → `initialize()` → post-dependencies →
/// (root only) drain → initialized.
///
/// ## Lifecycle ([InitializationStatus])
///
/// `idle` → `initializing` → `finalizing` (post-dependencies) →
/// `initialized`. On error: `failed` (also [InitializationStatus.idle]): the
/// next call starts a new attempt (retry).
///
/// ## One attempt, one result
///
/// Each object has at most one initialization attempt in progress. Every
/// caller of that attempt gets **its** result: synchronously, when the whole
/// initialization was synchronous (no [Future] involved), otherwise the same
/// [Future]. A result is never fabricated: OK means the object was
/// initialized (or, for [InitializationResult.cyclic], see below).
///
/// ## Cycles: the waits-for graph
///
/// While attempts are in progress, the framework keeps a *waits-for* graph:
/// an edge `W → D` means the attempt of `W` is waiting for the attempt of
/// `D`. Before `W` waits for an in-progress `D`, it checks whether `D`
/// already (transitively) waits for `W`:
/// - **No:** the edge `W → D` is added, and `W` waits for `D`'s result.
/// - **Yes:** waiting would never end (a cycle). `W` doesn't wait: it gets an
///   OK result with [InitializationResult.cyclic] `true`, and `D` is listed
///   in `W`'s [Initializable.cyclicDependencies].
///
/// Example: `A` depends on `B`, and `B` on `A`. `A` starts, waits for `B`
/// (`A → B`). `B` starts and asks for `A`: `A` already waits for `B`, so `B`
/// doesn't wait for `A` (`B.cyclicDependencies == [A]`). `B` initializes,
/// then `A`. The same rule covers a self-dependency, synchronous re-entry,
/// asynchronous cycles, cliques and concurrent roots: the graph is always
/// acyclic, so the framework's waits never deadlock. There are no delays,
/// retries or timeouts.
///
/// ## Who is waiting
///
/// A request has up to two waiters:
/// - The code calling: a dependency requested from a hook
///   ([Initializable.initializeDependencies] or [Initializable.initialize]) is
///   attributed to the hook's object, with or without a `parent`: the
///   innermost hook running synchronously, or the hook's [Zone] (after an
///   `await` in the hook).
/// - The explicit `parent`'s attempt (if another one): declared.
///
/// It's a cycle if the dependency waits for either. With no waiter, the
/// caller is a *root*.
///
/// A call from a hook (`ensureInitialized`, `executeInitialized`, ...) is
/// considered waited for by the hook until the hook completes: its future
/// may be discarded, so the wait doesn't outlive the hook. The framework's
/// own waits (the declared dependencies) last until the dependency
/// completes.
///
/// Limitation: code running after an `await` in a [Zone] not forked from
/// the hook's one (e.g. a zone forked from a captured/static zone), that
/// requests a dependency with no `parent`, can't be attributed: it waits as
/// a root, and would wait forever if that dependency waits for the hook's
/// object. Pass `parent:` in such code.
///
/// ## Guarantees
///
/// - No timeouts; no deadlock among the framework's waits.
/// - When an attempt completes OK, all its dependencies completed OK, except
///   the ones that were waiting for it ([Initializable.cyclicDependencies]):
///   those are still initializing (they need this one first).
/// - An attempt started or joined by a root caller (no waiter) also waits
///   for every in-progress object of its dependencies' closure (except the
///   ones waiting for it). A root call on an initialized object returns
///   right away.
/// - Errors are results ([InitializationResult.ok] `false`, with the
///   [InitializationResult.error] and [InitializationResult.stackTrace]):
///   the futures never fail. A failed object can be initialized again (a new
///   attempt, with its own dependencies).
///
/// ## Complexity
///
/// Each dependency request is O(1), plus a cycle check (an iterative
/// depth-first search over the in-progress waits only) when the dependency is
/// in progress. A root's drain visits its dependencies' closure once per
/// round (O(V + E)).
library;

import 'dart:async';
import 'dart:collection';

import 'package:logging/logging.dart' as logging;

import 'bones_api_logging.dart';
import 'bones_api_utils.dart';

final _log = logging.Logger('Initializable');

typedef ExecuteInitializedCallback<R> = FutureOr<R> Function();

/// The initialization status of the [initializable] instance.
///
/// | state          | [initialized] | [initializing] | [finalizing] | [failed] | [idle] |
/// |----------------|---------------|----------------|--------------|----------|--------|
/// | `idle`         | false         | false          | false        | false    | true   |
/// | `initializing` | false         | true           | false        | false    | false  |
/// | `finalizing`   | false         | true           | true         | false    | false  |
/// | `initialized`  | true          | false          | false        | false    | false  |
/// | `failed`       | false         | false          | false        | true     | true   |
class InitializationStatus {
  /// The [Initializable] instance of this status.
  final Initializable initializable;

  InitializationStatus._(this.initializable);

  static int _idCount = 0;

  int _id = 0;

  /// The [initializable] ID: the order its (last) initialization attempt
  /// started.
  int get id => _id;

  bool _initialized = false;

  /// Returns `true` if [initializable] is already initialized.
  bool get initialized => _initialized;
  DateTime? _initializedTime;

  void _setInitialized() {
    _initialized = true;
    _initializedTime = DateTime.now();
    _initializing = false;
    _finalizing = false;
    _failed = false;
    _error = null;
    _stackTrace = null;
  }

  bool _initializing = false;
  DateTime? _initializingTime;

  void _setInitializing() {
    _initializing = true;
    _initializingTime = DateTime.now();
    _initializedTime = null;
    _finalizing = false;
    _failed = false;
    _error = null;
    _stackTrace = null;
    _id = ++_idCount;
  }

  /// Returns `true` if [initializable] is initializing (an attempt is in
  /// progress, including [finalizing]).
  bool get initializing => _initializing;

  DateTime? get initializingTime => _initializingTime;

  DateTime? get initializedTime => _initializedTime;

  Duration? get initializationTime {
    var init = _initializingTime;
    var end = _initializedTime;
    if (init == null || end == null) return null;
    return end.difference(init);
  }

  bool _finalizing = false;

  void _setFinalizing() {
    _finalizing = true;
  }

  /// Returns `true` if [initializable] is finalizing: its `initialize()`
  /// completed and it's initializing its post-dependencies.
  bool get finalizing => _finalizing;

  bool _failed = false;
  Object? _error;
  StackTrace? _stackTrace;

  void _setFailed(Object? error, StackTrace? stackTrace) {
    _initializing = false;
    _finalizing = false;
    _failed = true;
    _error = error;
    _stackTrace = stackTrace;
  }

  /// Returns `true` if the last initialization attempt failed (see [error]).
  /// The next initialization call starts a new attempt.
  bool get failed => _failed;

  /// The error of the last (failed) initialization attempt.
  Object? get error => _error;

  /// The [StackTrace] of the [error].
  StackTrace? get stackTrace => _stackTrace;

  bool _asynchronous = false;

  /// Returns `true` if [initializable] has an asynchronous initialization
  /// (an attempt that didn't complete synchronously).
  bool get asynchronous => _asynchronous;

  void _markAsynchronous(bool async) {
    if (async) {
      _asynchronous = true;
    }
  }

  /// Returns `true` if is not initialized yet and not initializing (also
  /// after a [failed] attempt).
  bool get idle => !initialized && !initializing;

  /// Returns the initialization status as [String]. Examples:
  /// - `idle`
  /// - `initializing` / `initializing[async]`
  /// - `finalizing` / `finalizing[async]`
  /// - `initialized` / `initialized[async]`
  /// - `failed` / `failed[async]`
  String get status {
    var asyncStr = asynchronous ? '[async]' : '';

    if (initialized) {
      return 'initialized$asyncStr';
    } else if (_finalizing) {
      return 'finalizing$asyncStr';
    } else if (initializing) {
      return 'initializing$asyncStr';
    } else if (_failed) {
      return 'failed$asyncStr';
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
///
/// - [ok] `true`: [initializable] is initialized, or, if [cyclic], it's
///   still initializing and waiting (transitively) for the requester, which
///   can't wait for it (see [Initializable.cyclicDependencies]).
/// - [ok] `false`: the initialization failed: [error] and [stackTrace].
class InitializationResult {
  /// The [Initializable] of this result.
  final Initializable initializable;

  /// `true` if the initialization was OK.
  final bool ok;

  /// `true` if [initializable] wasn't waited for: it's waiting
  /// (transitively) for the requester (a cycle). See
  /// [Initializable.cyclicDependencies].
  final bool cyclic;

  /// The dependencies of this [Initializable] instance.
  final List<Initializable> dependencies;

  /// The thrown error, if any.
  final Object? error;

  /// The thrown error [StackTrace], if any.
  final StackTrace? stackTrace;

  InitializationResult(
    this.initializable,
    this.ok, {
    Iterable<Initializable>? dependencies,
    this.error,
    this.stackTrace,
    this.cyclic = false,
  }) : dependencies = dependencies?.toList() ?? <Initializable>[];

  factory InitializationResult.ok(
    Initializable initializable, {
    Iterable<Initializable>? dependencies,
  }) {
    return InitializationResult(
      initializable,
      true,
      dependencies: dependencies,
    );
  }

  factory InitializationResult.error(
    Initializable initializable, [
    Object? error,
    StackTrace? stackTrace,
  ]) => InitializationResult(
    initializable,
    false,
    error: error,
    stackTrace: stackTrace,
  );

  @override
  String toString() {
    var depsStr = dependencies.isNotEmpty
        ? '->${dependencies.length <= 3 ? dependencies.toInitializationStatus() : dependencies.length}'
        : '';

    if (ok) {
      var okStr = cyclic ? 'OK:CYCLIC' : 'OK';
      return '[$okStr]@${initializable.initializationStatus}$depsStr';
    } else {
      var s = '[ERROR]@${initializable.initializationStatus}$depsStr';
      return error == null
          ? s
          : (stackTrace == null ? '$s\n$error' : '$s\n$error\n$stackTrace');
    }
  }
}

extension IterableInitializationResultExtension
    on Iterable<InitializationResult> {
  List<InitializationResult> whereOk() => where((e) => e.ok).toList();

  List<InitializationResult> whereNotOk() => where((e) => !e.ok).toList();

  String allToString() => map((e) {
    var s = e.toString().replaceAll('\n', '\n     ').trim();
    return '  -- $s';
  }).join('\n');

  String errorsToString() => whereNotOk().allToString();
}

/// An [Initializable] initialization error. Extends [StateError].
class InitializationError extends StateError {
  final Initializable initializable;

  /// The original error (e.g. thrown by `initialize()`), if any.
  final Object? cause;

  /// The [cause] [StackTrace].
  final StackTrace? causeStackTrace;

  InitializationError(
    this.initializable,
    super.message, {
    this.cause,
    this.causeStackTrace,
  }) : super();

  @override
  String toString() {
    var cause = this.cause;
    return cause == null
        ? "Initialization error> $message"
        : "Initialization error> $message\nCaused by: $cause";
  }
}

/// The [Zone] key of the hook's [_AttemptRef] (see [Initializable._runHook]).
final Object _attemptZoneKey = Object();

/// The attempts whose hook is running synchronously (innermost last).
final List<_Attempt> _hookStack = <_Attempt>[];

/// The current mark of the depth-first searches ([_reaches]).
int _searchEpoch = 0;

/// A reference to an [_Attempt], held by its hooks' zones: cleared when the
/// attempt completes, so a zone outliving it (e.g. a listener or timer
/// created in a hook) doesn't retain it (and its graph).
final class _AttemptRef {
  _Attempt? attempt;

  _AttemptRef(this.attempt);
}

/// An initialization attempt of [node]: a node of the waits-for graph.
final class _Attempt {
  final Initializable node;

  /// `true` if a root caller (no waiter) started or joined it: it drains
  /// its dependencies' closure before completing.
  bool root;

  /// The result: set once, when completed.
  InitializationResult? result;

  Completer<InitializationResult>? _completer;

  /// The attempts this one is waiting for (waits-for edges).
  final Set<_Attempt> waitingOn = HashSet<_Attempt>.identity();

  /// The attempts waiting for this one (incoming edges).
  final Set<_Attempt> waiters = HashSet<_Attempt>.identity();

  /// Of [waitingOn], the waits of calls from its hooks (not the framework's
  /// own waits): a hook may discard the future, so they last only until the
  /// hook completes.
  final Set<_Attempt> hookWaits = HashSet<_Attempt>.identity();

  /// The reference held by its hooks' zones.
  late final _AttemptRef ref = _AttemptRef(this);

  int _mark = 0;

  _Attempt(this.node, {required this.root});

  /// `true` while in progress (not completed, and [node]'s current one).
  bool get isActive =>
      result == null && identical(node._initState.current, this);

  /// The [result], when completed.
  Future<InitializationResult> get future {
    var result = this.result;
    if (result != null) return Future.value(result);
    return (_completer ??= Completer<InitializationResult>()).future;
  }

  @override
  String toString() => '_Attempt{${node.initializationStatus}}';
}

/// Adds the waits-for edge [waiter] → [target]. A [hook] wait (a call from a
/// hook of [waiter]) lasts until the hook completes; a framework wait
/// replaces it.
void _addWaitEdge(_Attempt waiter, _Attempt target, {required bool hook}) {
  if (waiter.waitingOn.add(target)) {
    target.waiters.add(waiter);
    if (hook) waiter.hookWaits.add(target);
  } else if (!hook) {
    waiter.hookWaits.remove(target);
  }
}

/// Removes the waits-for edge [waiter] → [target].
void _removeWaitEdge(_Attempt waiter, _Attempt target) {
  if (waiter.waitingOn.remove(target)) {
    target.waiters.remove(waiter);
  }
  waiter.hookWaits.remove(target);
}

/// Removes the hook waits of [attempt] (its hook completed).
void _clearHookWaits(_Attempt attempt) {
  var hookWaits = attempt.hookWaits;
  if (hookWaits.isEmpty) return;

  for (var target in hookWaits) {
    if (attempt.waitingOn.remove(target)) {
      target.waiters.remove(attempt);
    }
  }
  hookWaits.clear();
}

/// Returns `true` if [from] is (transitively) waiting for [target]. An
/// iterative depth-first search over the waits-for edges (no recursion).
bool _reaches(_Attempt from, _Attempt target) {
  if (identical(from, target)) return true;
  if (from.waitingOn.isEmpty) return false;

  var mark = ++_searchEpoch;
  from._mark = mark;

  var stack = <_Attempt>[from];
  while (stack.isNotEmpty) {
    var attempt = stack.removeLast();
    for (var next in attempt.waitingOn) {
      if (identical(next, target)) return true;
      if (next._mark != mark) {
        next._mark = mark;
        stack.add(next);
      }
    }
  }

  return false;
}

/// [f] with the value of [value]: synchronous if [value] is not a [Future].
FutureOr<R> _then<T, R>(FutureOr<T> value, FutureOr<R> Function(T value) f) {
  if (value is Future<T>) {
    return value.then(f);
  } else {
    return f(value);
  }
}

/// The first not OK result, if any.
InitializationResult? _firstNotOk(Iterable<InitializationResult> results) {
  for (var r in results) {
    if (!r.ok) return r;
  }
  return null;
}

/// The initialization state of an [Initializable].
final class _InitializationState {
  /// The attempt in progress: `null` when idle, failed or initialized.
  _Attempt? current;

  /// The dependencies (pre and post), in the order they were declared.
  final Set<Initializable> dependencies =
      LinkedHashSet<Initializable>.identity();

  /// The dependencies not waited for in the last attempt (see
  /// [Initializable.cyclicDependencies]).
  final Set<Initializable> cyclic = LinkedHashSet<Initializable>.identity();

  /// The result once initialized (shared by every later call).
  InitializationResult? initializedResult;
}

/// An instance that must be initialized (once) before use, after its
/// dependencies. See the library documentation for the model, the cycles
/// handling and the guarantees.
///
/// Implement:
/// - [initializeDependencies]: the dependencies to initialize before
///   [initialize].
/// - [initialize]: the initialization. Return [InitializationResult.ok] (with
///   the post-dependencies, if any) or [InitializationResult.error] (or
///   throw).
///
/// Use:
/// - [ensureInitialized] / [doInitialization]: initialize it (if not yet).
/// - [executeInitialized]: run code after it's initialized.
/// - [checkInitialized]: initialize it synchronously, or throw.
///
/// From a hook ([initializeDependencies] / [initialize]), other instances
/// can be initialized directly (e.g. `other.ensureInitialized()`): they are
/// dependencies of this one (attributed by the framework).
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

  late final InitializationStatus _status = InitializationStatus._(this);

  late final _InitializationState _initState = _InitializationState();

  /// Returns the current [InitializationStatus].
  InitializationStatus get initializationStatus => _status;

  int get _initializationID => _status._id;

  /// Ensures that this instance is initialized.
  ///
  /// Returns the [InitializationResult]: synchronously if the initialization
  /// is (or was) synchronous. The returned [Future] never fails: an error is
  /// a result with [InitializationResult.ok] `false`.
  ///
  /// - [parent]: the instance that needs this one (when not called from its
  ///   hooks, where it's resolved automatically).
  FutureOr<InitializationResult> ensureInitialized({Initializable? parent}) =>
      _ensure(_resolveWaiters(parent));

  /// Ensures that this instance is initialized. If is not
  /// initialized yet it will force an asynchronous initialization
  /// and return a [Future].
  FutureOr<InitializationResult> ensureInitializedAsync({
    Initializable? parent,
  }) {
    if (_status.initialized) return _resultInitialized();
    var waiters = _resolveWaiters(parent);
    return Future<InitializationResult>.microtask(
      () => _ensure(waiters.where((w) => w.isActive).toList()),
    );
  }

  /// Initialize this instance if is not initialized yet. Same as
  /// [ensureInitialized].
  FutureOr<InitializationResult> doInitialization({Initializable? parent}) =>
      _ensure(_resolveWaiters(parent));

  /// Returns `true` if this instance is already initialized.
  bool get isInitialized => _status.initialized;

  /// Returns `true` if this instance is in the middle of the initialization process.
  bool get isInitializing => _status.initializing;

  /// Returns `true` if this instance initialization was asynchronous.
  bool get isAsyncInitialization => _status._asynchronous;

  /// The dependencies of the current (or last) initialization attempt that
  /// were not waited for: they were (transitively) waiting for this instance
  /// (a cycle), so they may still be initializing when [initialize] runs or
  /// when this instance is initialized.
  List<Initializable> get cyclicDependencies =>
      List<Initializable>.unmodifiable(_initState.cyclic);

  /// The OK result (once initialized, the same instance for every call: no
  /// copy of the dependencies per call).
  InitializationResult _resultInitialized() {
    var state = _initState;
    if (!_status.initialized) {
      return InitializationResult.ok(this, dependencies: state.dependencies);
    }
    return state.initializedResult ??= InitializationResult.ok(
      this,
      dependencies: state.dependencies,
    );
  }

  InitializationResult _resultCyclic() => InitializationResult(
    this,
    true,
    dependencies: _initState.dependencies,
    cyclic: true,
  );

  /// The attempts waiting for this instance (0 to 2):
  /// - The innermost hook running synchronously, or the hook's [Zone] (after
  ///   an `await` in the hook): the code that is calling.
  /// - The [parent]'s attempt (declared), if another one.
  static List<_Attempt> _resolveWaiters(Initializable? parent) {
    _Attempt? hookAttempt;

    if (_hookStack.isNotEmpty) {
      var attempt = _hookStack.last;
      if (attempt.isActive) hookAttempt = attempt;
    }

    if (hookAttempt == null) {
      var ref = Zone.current[_attemptZoneKey];
      if (ref is _AttemptRef) {
        var attempt = ref.attempt;
        if (attempt != null && attempt.isActive) hookAttempt = attempt;
      }
    }

    _Attempt? parentAttempt;
    if (parent != null) {
      var attempt = parent._initState.current;
      if (attempt != null &&
          attempt.isActive &&
          !identical(attempt, hookAttempt)) {
        parentAttempt = attempt;
      }
    }

    return [?hookAttempt, ?parentAttempt];
  }

  /// Runs a hook of [attempt] (attributing the dependencies requested in it).
  static FutureOr<T> _runHook<T>(
    _Attempt attempt,
    FutureOr<T> Function() hook,
  ) {
    _hookStack.add(attempt);
    try {
      return runZoned(hook, zoneValues: {_attemptZoneKey: attempt.ref});
    } finally {
      _hookStack.removeLast();
    }
  }

  /// Initializes this instance (if not yet) for the [waiters] (none: a root
  /// caller). A [hook] call (from code, not a framework wait) waits only
  /// until the waiters' hook completes (it may discard the future).
  FutureOr<InitializationResult> _ensure(
    List<_Attempt> waiters, {
    bool hook = true,
  }) {
    if (_status.initialized) return _resultInitialized();

    var state = _initState;
    var attempt = state.current;

    if (attempt == null) {
      attempt = _Attempt(this, root: waiters.isEmpty);
      state.current = attempt;
      state.dependencies.clear();
      state.cyclic.clear();
      state.initializedResult = null;
      _status._setInitializing();

      // A new attempt waits for nothing yet: no cycle possible.
      for (var waiter in waiters) {
        _addWaitEdge(waiter, attempt, hook: hook);
      }

      _run(attempt);

      var result = attempt.result;
      if (result != null) return result;

      _status._markAsynchronous(true);
      return attempt.future;
    }

    // A root caller: waits for the attempt (that also drains its closure).
    if (waiters.isEmpty) {
      attempt.root = true;
      return attempt.future;
    }

    if (_isCyclic(attempt, waiters)) return _resultCyclic();

    for (var waiter in waiters) {
      _addWaitEdge(waiter, attempt, hook: hook);
    }
    return attempt.future;
  }

  /// Returns `true` if [attempt] is (transitively) waiting for one of the
  /// [waiters] (a cycle: they can't wait for it), and records it in their
  /// [cyclicDependencies].
  bool _isCyclic(_Attempt attempt, List<_Attempt> waiters) {
    var cyclic = false;

    for (var waiter in waiters) {
      // A self-dependency, a re-entrant call from its own hooks, or this
      // attempt waiting for the waiter:
      if (identical(waiter, attempt) || _reaches(attempt, waiter)) {
        cyclic = true;
        if (!identical(waiter, attempt)) {
          waiter.node._initState.cyclic.add(this);
          _log.fine(
            () =>
                "Cyclic dependency (not waited): ${waiter.node.initializationStatus} -> $_status",
          );
        }
      }
    }

    return cyclic;
  }

  /// Runs the phases of [attempt]: it always completes it (OK or error).
  void _run(_Attempt attempt) {
    FutureOr<Object?> ret;
    try {
      ret = _phaseDependencies(attempt);
    } catch (e, s) {
      _fail(attempt, e, s);
      return;
    }

    if (ret is Future<Object?>) {
      // ignore: discarded_futures
      ret.then(
        (_) {},
        onError: (Object e, StackTrace s) => _fail(attempt, e, s),
      );
    }
  }

  /// Phase 1: the pre-dependencies ([initializeDependencies]).
  FutureOr<Object?> _phaseDependencies(_Attempt attempt) {
    var deps = _runHook(attempt, initializeDependencies);

    return _then<List<Initializable>, Object?>(deps, (deps) {
      _clearHookWaits(attempt);

      var depsInit = _initializeDependencies(attempt, deps, deps);

      return _then<InitializationResult?, Object?>(depsInit, (depsError) {
        if (depsError != null) {
          _failDependency(attempt, depsError);
          return null;
        }
        return _phaseInitialize(attempt);
      });
    });
  }

  /// Phase 2: [initialize].
  FutureOr<Object?> _phaseInitialize(_Attempt attempt) {
    var result = _runHook(attempt, initialize);

    return _then<InitializationResult, Object?>(result, (result) {
      _clearHookWaits(attempt);

      if (!result.ok) {
        _fail(
          attempt,
          result.error ?? InitializationError(this, "Error result: $result"),
          result.stackTrace,
        );
        return null;
      }
      return _phasePostDependencies(attempt, result);
    });
  }

  /// Phase 3: the post-dependencies (of the [initialize] result).
  FutureOr<Object?> _phasePostDependencies(
    _Attempt attempt,
    InitializationResult result,
  ) {
    _status._setFinalizing();

    // A result of another instance (merged): it's a post-dependency (waited
    // for), and its dependencies are reported as this one's. Its own
    // dependencies aren't waited for again (that instance already waits for
    // them); any other listed dependency is.
    var initializable = result.initializable;
    var merged = !identical(initializable, this);

    List<Initializable> postDeps, wait;
    if (merged) {
      postDeps = <Initializable>[initializable, ...result.dependencies];
      var ownDeps = initializable._initState.dependencies;
      wait = <Initializable>[
        initializable,
        ...result.dependencies.where((d) => !ownDeps.contains(d)),
      ];
    } else {
      postDeps = wait = result.dependencies;
    }

    var postDepsInit = _initializeDependencies(attempt, postDeps, wait);

    return _then<InitializationResult?, Object?>(postDepsInit, (depsError) {
      if (depsError != null) {
        _failDependency(attempt, depsError);
        return null;
      }

      if (!attempt.root) {
        _complete(attempt, _resultInitialized());
        return null;
      }

      return _phaseDrain(attempt);
    });
  }

  /// Phase 4 (root attempts only): the in-progress dependencies' closure.
  FutureOr<Object?> _phaseDrain(_Attempt attempt) {
    return _then<InitializationResult?, Object?>(_drain(attempt), (drainError) {
      if (drainError != null) {
        _failDependency(attempt, drainError);
        return null;
      }

      _complete(attempt, _resultInitialized());
      return null;
    });
  }

  /// Initializes the [wait] dependencies (and reports the [deps]): returns
  /// the first error result, if any.
  FutureOr<InitializationResult?> _initializeDependencies(
    _Attempt attempt,
    Iterable<Initializable> deps,
    Iterable<Initializable> wait,
  ) {
    var dependencies = _initState.dependencies;
    for (var dep in deps) {
      if (!identical(dep, this)) dependencies.add(dep);
    }

    List<Future<InitializationResult>>? futures;
    var seen = HashSet<Initializable>.identity();

    for (var dep in wait) {
      if (identical(dep, this) || !seen.add(dep) || dep.isInitialized) {
        continue;
      }

      var result = dep._ensure([attempt], hook: false);

      if (result is Future<InitializationResult>) {
        (futures ??= []).add(result);
      } else if (!result.ok) {
        return result;
      }
    }

    if (futures == null) return null;

    return Future.wait(futures).then(_firstNotOk);
  }

  /// A root attempt waits for every in-progress instance of its
  /// dependencies' closure (except the ones waiting for it), until none is
  /// left.
  FutureOr<InitializationResult?> _drain(_Attempt attempt) {
    var visited = HashSet<Initializable>.identity()..add(this);
    var queue = <Initializable>[..._initState.dependencies];

    List<Future<InitializationResult>>? futures;

    while (queue.isNotEmpty) {
      var dep = queue.removeLast();
      if (!visited.add(dep)) continue;

      queue.addAll(dep._initState.dependencies);

      var depAttempt = dep._initState.current;
      if (depAttempt == null || !depAttempt.isActive) continue;
      if (_reaches(depAttempt, attempt)) continue;

      _addWaitEdge(attempt, depAttempt, hook: false);
      (futures ??= []).add(depAttempt.future);
    }

    if (futures == null) return null;

    return Future.wait(futures).then((results) {
      var error = _firstNotOk(results);
      if (error != null) return error;
      // The closure can have new dependencies:
      return _drain(attempt);
    });
  }

  void _failDependency(_Attempt attempt, InitializationResult depError) {
    _fail(
      attempt,
      InitializationError(
        this,
        "Error initializing dependency of $this: ${depError.initializable}",
        cause: depError.error,
        causeStackTrace: depError.stackTrace,
      ),
      depError.stackTrace,
    );
  }

  void _fail(_Attempt attempt, Object error, StackTrace? stackTrace) {
    if (attempt.result != null) return;

    _log.severe("Initialization error: $_status", error, stackTrace);
    _forceLogFlushMessages();

    _complete(attempt, InitializationResult.error(this, error, stackTrace));
  }

  void _complete(_Attempt attempt, InitializationResult result) {
    if (attempt.result != null) return;
    attempt.result = result;

    for (var waiter in attempt.waiters) {
      waiter.waitingOn.remove(attempt);
    }
    for (var target in attempt.waitingOn) {
      target.waiters.remove(attempt);
    }
    attempt.waiters.clear();
    attempt.waitingOn.clear();
    attempt.hookWaits.clear();

    // Zones of its hooks that outlive it don't retain it:
    attempt.ref.attempt = null;

    if (identical(_initState.current, attempt)) {
      _initState.current = null;
    }

    if (result.ok) {
      _status._setInitialized();
      // Every later call gets this same result:
      _initState.initializedResult = result;
    } else {
      _status._setFailed(result.error, result.stackTrace);
    }

    attempt._completer?.complete(result);
  }

  /// Return a [List] of [Initializable] instances that need to be initialized
  /// BEFORE [initialize] this instance.
  ///
  /// A dependency that is (transitively) waiting for this instance (a cycle)
  /// isn't waited for: see [cyclicDependencies].
  ///
  /// See [doInitialization].
  FutureOr<List<Initializable>> initializeDependencies() => <Initializable>[];

  /// Initialization implementation. Do not call it directly, use [doInitialization].
  ///
  /// It can be a synchronous (returning an [InitializationResult]) or an
  /// asynchronous implementation (returning a [Future]). A thrown error, or
  /// an [InitializationResult.error], fails the initialization.
  ///
  /// The returned [InitializationResult.dependencies] are initialized after
  /// this (post-dependencies). A result of another [Initializable] makes it a
  /// post-dependency too (its dependencies are reported as this one's).
  ///
  /// See [initializeDependencies].
  FutureOr<InitializationResult> initialize() => InitializationResult.ok(this);

  /// Checks if this instance is initialized, initializing it if possible.
  ///
  /// - Initialized: returns.
  /// - Initializing: returns (as before 1.20.0). With
  ///   `allowInProgress: false`, it returns only if called from its own
  ///   initialization or from a dependency it's waiting for (a cycle), and
  ///   throws an [InitializationError] otherwise. A cycle is recorded in the
  ///   caller's [cyclicDependencies].
  /// - Not initialized: initializes it. Throws an [InitializationError] if it
  ///   can't be initialized synchronously (the initialization goes on), or if
  ///   it fails (with the [InitializationError.cause]).
  void checkInitialized({bool allowInProgress = true}) {
    if (_status.initialized) return;

    var waiters = _resolveWaiters(null);

    var attempt = _initState.current;
    if (attempt != null) {
      var cyclic = waiters.isNotEmpty && _isCyclic(attempt, waiters);
      if (cyclic || allowInProgress) return;

      _forceLogFlushMessages();
      throw InitializationError(this, "Initialization in progress: $this");
    }

    var result = _ensure(waiters);

    if (result is Future<InitializationResult>) {
      // The caller doesn't wait (it gets an error): not a wait.
      var current = _initState.current;
      if (current != null) {
        for (var waiter in waiters) {
          _removeWaitEdge(waiter, current);
        }
      }

      _forceLogFlushMessages();
      throw InitializationError(
        this,
        "Not initialized yet! Async initialization for: $this",
      );
    }

    if (!result.ok) {
      _forceLogFlushMessages();
      throw InitializationError(
        this,
        "Error initializing: $this",
        cause: result.error,
        causeStackTrace: result.stackTrace,
      );
    }
  }

  /// Executes the [callback] ensuring that this instance was initialized.
  ///
  /// Throws an [InitializationError] (with the [InitializationError.cause])
  /// if the initialization fails.
  ///
  /// In a cycle ([InitializationResult.cyclic]: this instance is waiting for
  /// the caller), the [callback] runs while this instance is still
  /// initializing.
  FutureOr<R> executeInitialized<R>(
    ExecuteInitializedCallback<R> callback, {
    Initializable? parent,
  }) {
    if (isInitialized) {
      return callback();
    }

    var result = ensureInitialized(parent: parent);

    return _then(
      result,
      (InitializationResult result) => _executeWithResult(result, callback),
    );
  }

  FutureOr<R> _executeWithResult<R>(
    InitializationResult result,
    ExecuteInitializedCallback<R> callback,
  ) {
    if (!result.ok) {
      _forceLogFlushMessages();
      Error.throwWithStackTrace(
        InitializationError(
          this,
          "Error initializing: $this",
          cause: result.error,
          causeStackTrace: result.stackTrace,
        ),
        result.stackTrace ?? StackTrace.current,
      );
    }

    return callback();
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

  List<InitializationStatus> toInitializationStatus() =>
      map((e) => e.initializationStatus).toList();

  List<T> get initialized => where((e) => e._status.initialized).toList();

  List<T> get finalizing => where((e) => e._status.finalizing).toList();

  List<T> get initializing => where((e) => e._status.initializing).toList();

  List<T> get idle =>
      where((e) => !e._status.initialized && !e._status.initializing).toList();

  List<T> notInitialized({bool ignoreFinalizing = false}) => where(
    (e) =>
        !e._status.initialized && (!ignoreFinalizing || !e._status.finalizing),
  ).toList();
}

void _forceLogFlushMessages() {
  logging.Logger.root.forceFlushMessages();
}

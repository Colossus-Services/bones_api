import 'package:async_extension/async_extension.dart';

import 'bones_api_base.dart';
import 'bones_api_config.dart';

/// Helper to gracefully start/stop an [APIRoot].
class APIRootStarter<A extends APIRoot> {
  A? _apiRoot;

  final FutureOr<A> Function(APIConfig? apiConfig)? _apiRootInstantiator;
  final FutureOr<APIConfig?> Function()? _apiConfigProvider;

  /// A pre-initialization [Function], called by [start].
  final FutureOr<bool> Function()? _preInitializer;

  /// A stopper [Function], called by [stop].
  final FutureOr<bool> Function()? _stopper;

  /// Instantiate from an already defined [APIRoot] instance.
  APIRootStarter.fromInstance(A apiRoot,
      {FutureOr<bool> Function()? preInitializer,
      FutureOr<bool> Function()? stopper})
      : _apiRoot = apiRoot,
        _preInitializer = preInitializer,
        _stopper = stopper,
        _apiRootInstantiator = null,
        _apiConfigProvider = null;

  /// Instantiate using instantiator [Function]s.
  APIRootStarter.fromInstantiator(
      A Function(APIConfig? apiConfig) apiRootInstantiator,
      {FutureOr<APIConfig?> Function()? apiConfig,
      FutureOr<bool> Function()? preInitializer,
      FutureOr<bool> Function()? stopper})
      : _apiRootInstantiator = apiRootInstantiator,
        _apiConfigProvider = apiConfig,
        _preInitializer = preInitializer,
        _stopper = stopper;

  /// Returns the [APIRoot] instance if already instantiated.
  /// See [getAPIRoot].
  A? get apiRoot => _apiRoot;

  /// Returns the [APIRoot] instance. Instantiates it if needed.
  FutureOr<A> getAPIRoot() {
    var apiRoot = _apiRoot;
    if (apiRoot != null) {
      return apiRoot;
    }

    var fConfig = _apiConfigProvider;
    var retConfig = fConfig == null ? null : fConfig();

    return retConfig.resolveMapped((config) {
      var f = _apiRootInstantiator!;
      var ret = f(config);

      return ret.resolveMapped((a) {
        _apiRoot = a;
        return a;
      });
    });
  }

  /// Returns the [APIRoot] instance started.
  /// See [getAPIRoot] and [start].
  FutureOr<A> getAPIRootStarted() {
    if (isStarted) {
      return getAPIRoot();
    }

    return start().resolveMapped((ok) {
      if (!ok) {
        throw StateError("Error starting.");
      }
      return getAPIRoot();
    });
  }

  bool? _preInitialized;

  FutureOr<bool> _preInitialize() {
    var preInitialized = _preInitialized;
    if (preInitialized != null) {
      if (!preInitialized) {
        throw StateError("Already pre-initializing!");
      }
      return true;
    }

    var f = _preInitializer;
    if (f == null) {
      _preInitialized = true;
      return true;
    }

    _preInitialized = false;

    var ret = f();

    return ret.resolveMapped((ok) {
      if (!ok) {
        throw StateError("Pre-initialization error.");
      }

      _preInitialized = true;
      return true;
    });
  }

  /// Returns `true` if is already started.
  /// See [start].
  bool get isStarted => _started ?? false;

  bool? _started;
  FutureOr<bool>? _starting;

  /// Starts the [APIRoot] instance.
  FutureOr<bool> start() {
    var started = _started;
    if (started != null) {
      if (started) return true;

      var starting = _starting;
      if (starting != null) {
        return starting;
      }
    }

    _started = false;
    _stopped = null;

    var retApiRoot = getAPIRoot();

    return _starting = retApiRoot.resolveMapped((apiRoot) {
      return _preInitialize().resolveMapped((preInitOk) {
        if (!preInitOk) {
          throw StateError("Pre-initialization error.");
        }

        return apiRoot.ensureInitialized().resolveMapped((initResult) {
          _started = true;
          _starting = null;
          return initResult.ok;
        });
      });
    });
  }

  bool? _stopped;

  /// Returns `true` if is already stopped.
  /// See [stop].
  bool get isStopped => _stopped ?? false;

  /// Stops the [APIRoot] instance. Calls [_stopper] if needed.
  /// Will return `false` if is not already started (see [isStarted] and [start]).
  FutureOr<bool> stop() {
    if (!isStarted) return false;

    var stopped = _stopped;
    if (stopped != null) {
      if (stopped) return true;
      throw StateError("Already stopping");
    }

    _stopped = false;

    var stopper = _stopper;
    if (stopper == null) {
      _stopped = true;
      _started = null;
      return true;
    }

    var ret = stopper();

    return ret.resolveMapped((ok) {
      if (!ok) throw StateError("Error stopping.");
      _stopped = true;
      _started = null;
      return true;
    });
  }
}

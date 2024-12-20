import 'dart:async';
import 'dart:collection';

import 'package:async_extension/async_extension.dart' as async_extension;

import 'bones_api_error_zone_generic.dart'
    if (dart.library.io) 'bones_api_error_zone_io.dart';

typedef OnUncaughtError = void Function(Object error, StackTrace stackTrace);

int _errorZoneIDCount = 0;

/// Creates an error [Zone].
///
/// - The [uncaughtErrorTitle] to use when printing error (if [onUncaughtError] is not provided).
/// - If [printErrorToStderr] is `true`, prints to `STDERR` (if [onUncaughtError] is not provided).
/// - [onUncaughtError] is the function to handle uncaught errors. If not provided, prints error.
///
/// See [printZoneError].
Zone createErrorZone({
  String uncaughtErrorTitle = 'Unhandled exception:',
  bool printErrorToStderr = true,
  OnUncaughtError? onUncaughtError,
  Zone? parentZone,
}) {
  var zoneId = ++_errorZoneIDCount;

  var zoneSpecification = ZoneSpecification(
    handleUncaughtError: (self, parent, zone, error, stackTrace) =>
        _handleUncaughtError(uncaughtErrorTitle, printErrorToStderr,
            onUncaughtError, self, parent, zone, error, stackTrace),
  );

  parentZone ??= Zone.current;

  var zone = parentZone
      .fork(specification: zoneSpecification, zoneValues: {'zoneID': zoneId});
  return zone;
}

extension ErrorZoneExtension on Zone {
  Completer<R> createCompleter<R>() {
    return run(() => Completer<R>());
  }

  Future<R> runGuardedAsync<R>(FutureOr<R> Function() action) {
    var completer = Completer<R>();

    runGuarded(() {
      try {
        var r = action();
        completer.complete(r);
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });

    return completer.future;
  }

  FutureOr<R?> asyncTry<R>(FutureOr<R?> Function() tryBlock,
      {FutureOr<R?> Function(R? r)? then,
      Function? onError,
      FutureOr<void> Function()? onFinally}) {
    return run(() => async_extension.asyncTry<R>(tryBlock,
        then: then, onError: onError, onFinally: onFinally));
  }
}

void _handleUncaughtError(
    String uncaughtErrorTitle,
    bool printErrorToStderr,
    OnUncaughtError? onUncaughtError,
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    Object error,
    StackTrace stackTrace) {
  if (onUncaughtError != null) {
    onUncaughtError(error, stackTrace);
  } else {
    printZoneError(error, stackTrace,
        title: uncaughtErrorTitle, printErrorToStderr: printErrorToStderr);
  }
}

/// Prints an [error] and [stackTrace].
///
/// See [printToZoneStderr].
void printZoneError(Object error, StackTrace stackTrace,
    {String? title, String? message, bool printErrorToStderr = true}) {
  var s = StringBuffer();

  s.write(
      '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n');

  if (title != null) {
    s.write('$title\n\n');
  }

  var errorMsg = error.toString().trim();
  s.write('$errorMsg\n\n');

  s.write('StackTrace:\n$stackTrace\n');

  if (message != null && message.isNotEmpty) {
    s.write(
        '------------------------------------------------------------------------------\n\n');
    s.write('$message\n');
  }

  s.write(
      '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n');

  if (printErrorToStderr) {
    printToZoneStderr(s);
  } else {
    print(s);
  }
}

/// Similar to [print] but prints to `STDERR`.
void printToZoneStderr(Object? o) => printToZoneStderrImpl(o);

/// A field value based in [Zone]s.
/// This is similar to `ThreadLocal` in Java,
/// but based in the current [Zone] or a passed [contextZone].
class ZoneField<T extends Object> {
  /// The parent zone of all [contextZone]s.
  final Zone parentZone;

  ZoneField(this.parentZone);

  final Expando<T> _values = Expando<T>();

  /// Gets the value associated with the [contextZone].
  /// - If [contextZone] is not provided it will get from [ZoneField.contextZone].
  T? get([Zone? contextZone]) {
    contextZone ??= this.contextZone;
    var t = _values[contextZone];
    return t;
  }

  /// Sets the value associated with the [contextZone].
  /// - If [contextZone] is not provided it will get from [ZoneField.contextZone].
  T? set(T? value, {Zone? contextZone}) {
    contextZone ??= this.contextZone;
    var prev = _values[contextZone];
    _values[contextZone] = value;
    return prev;
  }

  /// Removes the value associated with the [contextZone].
  /// See [set].
  T? remove({Zone? contextZone}) => set(null, contextZone: contextZone);

  final Queue<Zone> _zones = Queue<Zone>();

  /// Creates a new [contextZone] to store values.
  Zone createContextZone({Map<Object?, Object?>? zoneValues}) {
    var zone = parentZone.fork(
        specification: ZoneSpecification(), zoneValues: zoneValues);

    _zones.addLast(zone);
    return zone;
  }

  /// Same as [createContextZone] handling Uncaught Errors.
  /// See [ZoneSpecification.handleUncaughtError].
  Zone createSafeContextZone(
      {ZoneSpecification? zoneSpecification,
      Map<Object?, Object?>? zoneValues,
      void Function(Object error, StackTrace stackTrace)?
          handleUncaughtError}) {
    if (zoneSpecification == null) {
      if (handleUncaughtError == null) {
        throw ArgumentError(
            "One of the parameters, `zoneSpecification` or `handleUncaughtError`, must be provided!");
      }

      zoneSpecification = ZoneSpecification(
          handleUncaughtError: (self, parent, zone, error, stack) =>
              handleUncaughtError(error, stack));
    }

    var zone = parentZone.fork(
        specification: zoneSpecification, zoneValues: zoneValues);

    _zones.addLast(zone);
    return zone;
  }

  /// Disposes the [contextZone] and any related value.
  void disposeContextZone(Zone contextZone) {
    if (_zones.isNotEmpty) {
      if (identical(_zones.last, contextZone)) {
        var rmObj = _zones.removeLast();
        assert(identical(rmObj, contextZone));
      } else {
        var rm = _zones.remove(contextZone);
        assert(rm);
      }
    }

    _values[contextZone] = null;
  }

  /// Returns the current context zone.
  Zone get contextZone {
    var currentZone = Zone.current;

    for (var e in _zones) {
      if (identical(e, currentZone)) {
        return e;
      }
    }

    return currentZone;
  }
}

import 'dart:async';

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
}) {
  var zoneId = ++_errorZoneIDCount;

  var zoneSpecification = ZoneSpecification(
    handleUncaughtError: (self, parent, zone, error, stackTrace) =>
        _handleUncaughtError(uncaughtErrorTitle, printErrorToStderr,
            onUncaughtError, self, parent, zone, error, stackTrace),
  );

  var zone = Zone.current
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
    {String? title, bool printErrorToStderr = true}) {
  var p = printErrorToStderr ? printToZoneStderr : print;

  p('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<');

  if (title != null) {
    p('$title\n');
  }

  p(error);
  p('');
  p(stackTrace);

  p('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
}

/// Similar to [print] but prints to `STDERR`.
void printToZoneStderr(Object? o) => printToZoneStderrImpl(o);

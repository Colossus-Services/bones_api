import 'dart:async';
import 'dart:io';

typedef OnUncaughtError = void Function(Object error, StackTrace stackTrace);

void runErrorZone(
  void Function() action, {
  String uncaughtErrorTitle = 'Unhandled exception',
  bool printErrorToStderr = true,
  OnUncaughtError? onUncaughtError,
}) {
  var zoneSpecification = ZoneSpecification(
    handleUncaughtError: (self, parent, zone, error, stackTrace) =>
        _handleUncaughtError(uncaughtErrorTitle, printErrorToStderr,
            onUncaughtError, self, parent, zone, error, stackTrace),
  );

  var zone = Zone.current.fork(specification: zoneSpecification);
  zone.runGuarded(action);
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
    var p = printErrorToStderr ? print : _printError;
    p(uncaughtErrorTitle);
    p(error);
    p(stackTrace);
  }
}

void _printError(Object? o) => stderr.writeln(o);

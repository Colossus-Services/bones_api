import 'package:async_extension/async_extension.dart';

/// Tries to performa a [call].
/// - If [onSuccessValue] is defined it overwrites the [call] returned value.
/// - If [onErrorValue] is defined it will be returned in case of error.
/// - Returns [defaultValue] if [call] returns `null` and [onSuccessValue] or [onErrorValue] are `null`.
FutureOr<T?> tryCall<T>(
  FutureOr<T?> Function() call, {
  T? defaultValue,
  T? onSuccessValue,
  T? onErrorValue,
}) {
  try {
    return call().then(
      (ret) => onSuccessValue ?? ret ?? defaultValue,
      onError: (e) => onErrorValue ?? defaultValue,
    );
  } catch (_) {
    return onErrorValue ?? defaultValue;
  }
}

/// Tries to performa a [call] synchronously.
/// - If [onSuccessValue] is defined it overwrites the [call] returned value.
/// - If [onErrorValue] is defined it will be returned in case of error.
/// - Returns [defaultValue] if [call] returns `null` and [onSuccessValue] or [onErrorValue] are `null`.
T? tryCallSync<T>(
  T? Function() call, {
  T? defaultValue,
  T? onSuccessValue,
  T? onErrorValue,
}) {
  try {
    var ret = call();
    return onSuccessValue ?? ret ?? defaultValue;
  } catch (_) {
    return onErrorValue ?? defaultValue;
  }
}

/// Tries to performa a [call].
/// See [tryCall].
FutureOr<R?> tryCallMapped<T, R>(
  FutureOr<T?> Function() call, {
  R? defaultValue,
  R? onSuccessValue,
  R? Function(T? value)? onSuccess,
  R? onErrorValue,
  R? Function(Object error, StackTrace s)? onError,
}) {
  try {
    return call().then(
      (ret) {
        if (onSuccess != null) {
          return onSuccess(ret) ?? onSuccessValue ?? defaultValue;
        }
        return ret.resolveMapped(
          (r) => onSuccessValue ?? r as R? ?? defaultValue,
        );
      },
      onError: (e, s) {
        if (onError != null) {
          return onError(e, s) ?? onErrorValue ?? defaultValue;
        }
        return onErrorValue ?? defaultValue;
      },
    );
  } catch (e, s) {
    if (onError != null) {
      return onError(e, s) ?? onErrorValue ?? defaultValue;
    }
    return onErrorValue ?? defaultValue;
  }
}

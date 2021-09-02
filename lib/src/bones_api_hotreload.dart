import 'bones_api_hotreload_generic.dart'
    if (dart.library.io) 'bones_api_hotreload_vm.dart';

/// Hot Reload handler.
abstract class APIHotReload {
  static final APIHotReload _instance = createAPIHotReload();

  /// Returns the static [APIHotReload] instance for the current platform.
  static APIHotReload get() => _instance;

  /// Returns `true` if Hot Reload is allowed in this Dart process.
  Future<bool> isHotReloadAllowed();

  /// Returns `true` if Hot Reload is enabled.
  bool get isEnabled;

  /// Enables Hot Reload.
  Future<bool> enable();

  /// Disables Hot Reload.
  Future<bool> disable();

  /// Triggers reload of modified source codes.
  ///
  /// - If [force] is `true` reloads all source files regardless of their modification time.
  Future<bool> reload({bool force = false, bool autoEnable = true});
}

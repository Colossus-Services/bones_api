import 'dart:developer';
import 'package:logging/logging.dart' as logging;
import 'package:hotreloader/hotreloader.dart';

import 'bones_api_hotreload.dart';

final _log = logging.Logger('APIHotReload');

class APIHotReloadVM extends APIHotReload {
  static Future<bool> isVMServiceEnabled() async {
    try {
      var serviceInfo = await Service.getInfo();
      var enabled = serviceInfo.serverUri != null;
      return enabled;
    } catch (e, s) {
      print(e);
      print(s);
      return false;
    }
  }

  static HotReloader? _hotReloader;

  static Future<HotReloader?> hotReloader({bool autoCreate = true}) async {
    if (_hotReloader == null && autoCreate) {
      logging.hierarchicalLoggingEnabled = true;
      HotReloader.logLevel = logging.Level.CONFIG;
      _hotReloader = await HotReloader.create();
      _log.info('Created HotReloader');
    }
    return _hotReloader;
  }

  @override
  Future<bool> isHotReloadAllowed() async {
    var vmServiceEnabled = await isVMServiceEnabled();
    if (!vmServiceEnabled) {
      return false;
    }

    return true;
  }

  bool _enabled = false;

  @override
  bool get isEnabled => _enabled;

  @override
  Future<bool> enable() async {
    var allowed = await isHotReloadAllowed();

    if (!allowed) {
      _log.warning(
          'Hot Reloaded not allowed. Dart VM not running with: --enable-vm-service');
      return false;
    }

    if (_enabled) {
      var reloader = await hotReloader(autoCreate: false);
      if (reloader != null) {
        return true;
      }
    }
    _enabled = true;

    var reloader = await hotReloader();

    var ok = reloader != null;

    _log.info('Enabled Hot Reload: $ok');

    return ok;
  }

  @override
  Future<bool> disable() async {
    if (!_enabled) {
      return false;
    }

    var reloader = await hotReloader(autoCreate: false);

    if (reloader != null) {
      await reloader.stop();
      return true;
    }

    return false;
  }

  @override
  Future<bool> reload({bool force = false, bool autoEnable = true}) async {
    if (!_enabled && autoEnable) {
      await enable();
    }

    if (!_enabled) {
      return false;
    }

    var reloader = await hotReloader(autoCreate: false);

    if (reloader != null) {
      var result = await reloader.reloadCode(force: force);

      var ok = result == HotReloadResult.Succeeded ||
          result == HotReloadResult.PartiallySucceeded;
      return ok;
    }

    return false;
  }
}

APIHotReload createAPIHotReload() {
  return APIHotReloadVM();
}

import 'dart:developer';
import 'dart:isolate';

import 'package:hotreloader/hotreloader.dart';
import 'package:logging/logging.dart' as logging;

import 'bones_api_hotreload.dart';

final _log = logging.Logger('APIHotReload');

class APIHotReloadVM extends APIHotReload {
  APIHotReloadVM._();

  Future<bool> isVMServiceEnabled() async {
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

  HotReloader? _hotReloader;

  Future<HotReloader?> hotReloader({bool autoCreate = true}) async {
    if (_hotReloader == null && autoCreate) {
      logging.hierarchicalLoggingEnabled = true;
      HotReloader.logLevel = logging.Level.CONFIG;
      _hotReloader = await HotReloader.create(onBeforeReload: (ctx) {
        var isolateId = ctx.isolate.id;
        var isolateName = ctx.isolate.name ?? '?';
        var ignore = isIgnoredIsolate(isolateId);
        if (ignore) {
          _log.info(
              'Hot-reload ignored for Isolate[$isolateName]: `$isolateId`');
        } else {
          _log.info('Hot-reloading Isolate[$isolateName]: `$isolateId`');
        }
        return !ignore;
      });
      _log.info('Created HotReloader');
    }
    return _hotReloader;
  }

  @override
  String? getIsolateID(Object isolate) {
    if (isolate is Isolate) {
      return Service.getIsolateID(isolate);
    }
    return null;
  }

  final Set<String> _ignoredIsolateIDs = <String>{};

  @override
  bool isIgnoredIsolate(String? isolateId) {
    if (isolateId == null) return false;
    return _ignoredIsolateIDs.contains(isolateId);
  }

  @override
  void ignoreIsolate(String isolateId, [bool ignore = true]) {
    if (ignore) {
      _ignoredIsolateIDs.add(isolateId);
    } else {
      _ignoredIsolateIDs.remove(isolateId);
    }
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
  return APIHotReloadVM._();
}

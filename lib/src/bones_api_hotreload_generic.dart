import 'bones_api_hotreload.dart';

class APIHotReloadGeneric extends APIHotReload {
  @override
  Future<bool> isHotReloadAllowed() async {
    return false;
  }

  @override
  bool get isEnabled => false;

  @override
  Future<bool> enable() async => false;

  @override
  Future<bool> disable() async => false;

  @override
  Future<bool> reload({bool force = false, bool autoEnable = true}) async =>
      false;
}

APIHotReload createAPIHotReload() {
  return APIHotReloadGeneric();
}

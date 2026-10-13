@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'dart:isolate';

import 'package:bones_api/bones_api_server.dart';
import 'package:test/test.dart';

void main() {
  group('APIHotReload (coverage)', () {
    test('ignored isolates', () {
      var hotReload = APIHotReload.get();

      expect(hotReload.isIgnoredIsolate(null), isFalse);
      expect(hotReload.isIgnoredIsolate('isolates/cov-1'), isFalse);

      hotReload.ignoreIsolate('isolates/cov-1');
      expect(hotReload.isIgnoredIsolate('isolates/cov-1'), isTrue);
      expect(hotReload.isIgnoredIsolate('isolates/cov-2'), isFalse);

      hotReload.ignoreIsolate('isolates/cov-1', false);
      expect(hotReload.isIgnoredIsolate('isolates/cov-1'), isFalse);
    });

    test('getIsolateID', () {
      var hotReload = APIHotReload.get();

      expect(hotReload.getIsolateID('not an isolate'), isNull);

      var id = hotReload.getIsolateID(Isolate.current);
      // Only available when the VM service is enabled:
      if (id != null) {
        expect(id, startsWith('isolates/'));
      }
    });

    test('disabled operations', () async {
      var hotReload = APIHotReload.get();

      expect(hotReload.isEnabled, isFalse);
      expect(await hotReload.disable(), isFalse);
      expect(await hotReload.reload(autoEnable: false), isFalse);
      expect(hotReload.isEnabled, isFalse);
    });
  });
}

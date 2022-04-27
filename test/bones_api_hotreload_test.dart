@TestOn('vm')
import 'package:bones_api/bones_api_server.dart';
import 'package:test/test.dart';

import 'package:logging/logging.dart' as logging;

void main() {
  group('APIHotReload', () {
    setUpAll(() {
      logging.Logger.root.level = logging.Level.ALL;
      logging.Logger.root.onRecord.listen((msg) {
        print('$msg');
      });
    });

    test('basic', () async {
      expect(APIHotReload.get().isEnabled, isFalse);
      expect(await APIHotReload.get().isHotReloadAllowed(), isNotNull);
    });

    test('enable (allowed)', () async {
      if (await APIHotReload.get().isHotReloadAllowed()) {
        print('** Hot Reload: ALLOWED');

        //expect(await APIHotReload.get().enable(), isTrue);
        //await Future.delayed(Duration(seconds: 1));

        expect(await APIHotReload.get().disable(), isFalse);
      }
    });

    test('enable (disabled)', () async {
      if (!await APIHotReload.get().isHotReloadAllowed()) {
        print('** Hot Reload: DISABLED');

        expect(await APIHotReload.get().enable(), isFalse);
        expect(await APIHotReload.get().reload(), isFalse);
        expect(await APIHotReload.get().disable(), isFalse);
      }
    });
  });
}

@TestOn('vm')
@Timeout(Duration(seconds: 30))
import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_directory.dart';
import 'package:test/test.dart';

// NOTE: `DBAdapter.enableAuxiliaryMode` can't be disabled: this file runs in
// its own isolate, keeping the other tests unaffected.
void main() {
  group('DBAdapter.auxiliaryMode', () {
    late Directory tempDir;

    setUpAll(() {
      tempDir = Directory.systemTemp.createTempSync('bones_api_cov_aux_mode');
    });

    tearDownAll(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('enableAuxiliaryMode', () {
      expect(DBAdapter.auxiliaryMode, isFalse);
      expect(DBAdapter.enableAuxiliaryMode(), isTrue);
      expect(DBAdapter.auxiliaryMode, isTrue);
      // Already enabled:
      expect(DBAdapter.enableAuxiliaryMode(), isTrue);
      expect(DBAdapter.auxiliaryMode, isTrue);
    });

    test(
      'adapter without multi-isolate support: fails to initialize',
      () async {
        var adapter = DBObjectMemoryAdapter();
        expect(adapter.capability.multiIsolateSupport, isFalse);

        var result = await adapter.ensureInitialized();
        expect(result.ok, isFalse);
        expect(adapter.initializationStatus.failed, isTrue);

        adapter.close();
      },
    );

    test('adapter with multi-isolate support: initializes', () async {
      var adapter = DBObjectDirectoryAdapter(
        tempDir,
        populateSource: {
          'user_info': [
            {'id': 1, 'info': 'x'},
          ],
        },
      );
      expect(adapter.capability.multiIsolateSupport, isTrue);

      var result = await adapter.ensureInitialized();
      expect(result.ok, isTrue);
      expect(adapter.isInitialized, isTrue);

      // The populate source is ignored in auxiliary mode:
      expect(tempDir.listSync(), isEmpty);

      adapter.close();
    });
  });
}

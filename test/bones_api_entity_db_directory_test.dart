@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(seconds: 30))
import 'dart:io';

import 'package:bones_api/bones_api_db_directory.dart';
import 'package:bones_api/bones_api_test.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';

class MemoryTestConfig extends APITestConfigDBSQLMemory {
  MemoryTestConfig()
      : super({
          'db': {
            'sql.memory': {
              'port': 0,
            }
          }
        });
}

Future<void> main() async {
  await _runTest(true);
  await _runTest(false);
  await _runTest(true);
  await _runTest(false);
}

Future<bool> _runTest(bool useReflection) {
  final tempObjectDir =
      Directory.systemTemp.createTempSync("bones_api_tests_object_dir");

  return runAdapterTests(
    'DBSQLMemory+obj.dir',
    MemoryTestConfig(),
    (provider, dbPort) => DBSQLMemoryAdapter(
      parentRepositoryProvider: provider,
    ),
    (provider, dbPort) => DBObjectDirectoryAdapter(tempObjectDir,
        parentRepositoryProvider: provider)
      ..onClose.listen((_) {
        tempObjectDir.deleteSync(recursive: true);
      }),
    '"',
    'int',
    entityByReflection: useReflection,
  );
}

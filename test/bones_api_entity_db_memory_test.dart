@Tags(['entities'])
@Timeout(Duration(seconds: 30))
import 'dart:io';

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
  await _runTest(true, false);
  await _runTest(false, false);

  await _runTest(true, true);
  await _runTest(false, true);
}

Future<bool> _runTest(bool useReflection, bool objectDirectory) {
  Directory? tempObjectDir;
  if (objectDirectory) {
    tempObjectDir =
        Directory.systemTemp.createTempSync("bones_api_tests_object_dir");
  }

  return runAdapterTests(
    'DBSQLMemory',
    MemoryTestConfig(),
    (provider, dbPort) => DBSQLMemoryAdapter(
      parentRepositoryProvider: provider,
    ),
    (provider, dbPort) {
      DBAdapter<Object> a;

      if (objectDirectory) {
        a = DBObjectDirectoryAdapter(tempObjectDir!,
            parentRepositoryProvider: provider)
          ..onClose.listen((_) {
            tempObjectDir!.deleteSync(recursive: true);
          });
      } else {
        a = DBObjectMemoryAdapter(parentRepositoryProvider: provider);
      }

      return a;
    },
    '"',
    'int',
    entityByReflection: useReflection,
  );
}

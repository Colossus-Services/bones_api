@Tags(['entities'])
@Timeout(Duration(seconds: 30))
import 'package:bones_api/bones_api_test.dart';
import 'package:test/test.dart';

import 'bones_api_test_adapter.dart';

class MemoryTestConfig extends APITestConfigDBMemory {
  MemoryTestConfig()
      : super({
          'db': {
            'memory': {
              'port': 0,
            }
          }
        });
}

Future<void> main() async {
  await _runTest(true);
  await _runTest(false);
}

Future<bool> _runTest(bool useReflection) => runAdapterTests(
      'DBMemory',
      MemoryTestConfig(),
      (provider, dbPort) => MemorySQLAdapter(
        parentRepositoryProvider: provider,
      ),
      '"',
      'int',
      entityByReflection: useReflection,
    );

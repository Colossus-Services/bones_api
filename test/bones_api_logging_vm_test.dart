@TestOn('vm')
library;

import 'dart:isolate';

import 'package:bones_api/bones_api_logging.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

void main() {
  group('LoggerHandler (fresh isolate)', () {
    // A new isolate has fresh statics, so `LoggerHandler.root` is the very
    // first logging access there — which used to re-enter its own
    // initialization (`root` -> `handler` -> `_boot` -> `root`).
    test('LoggerHandler.root as the first access', () async {
      var ok = await Isolate.run(() {
        var root = LoggerHandler.root;
        return identical(root, logging.Logger.root.handler);
      });
      expect(ok, isTrue);
    });

    test('root receives records when accessed first', () async {
      var messages = await Isolate.run(() async {
        var received = <String>[];
        LoggerHandler.root.logAllTo(
          messageLogger: (level, message) => received.add(message),
        );

        logging.Logger('fresh_isolate_test').info('hello');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        return received;
      });

      expect(messages.any((m) => m.contains('hello')), isTrue);
    });
  });
}

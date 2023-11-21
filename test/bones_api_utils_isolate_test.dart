import 'dart:isolate';

import 'package:bones_api/src/bones_api_utils_isolate.dart';
import 'package:test/test.dart';

void main() {
  group('PortListener', () {
    test('basic', () async {
      var port = ReceivePort();

      var portListener = PortListener(port);

      var value1 = portListener.next();
      port.sendPort.send(10);
      expect(await value1, equals(10));

      var value2 = portListener.next();
      port.sendPort.send(20);
      expect(await value2, equals(20));

      var value3 = portListener.next();
      var value4 = portListener.next();

      port.sendPort.send(30);
      expect(await value3, equals(30));

      port.sendPort.send(40);
      expect(await value4, equals(40));

      var value5 = portListener.next();
      var value6 = portListener.next();

      port.sendPort.send(50);
      port.sendPort.send(60);

      expect(await value5, equals(50));
      expect(await value6, equals(60));

      port.sendPort.send(80);
      port.sendPort.send(90);

      var value8 = portListener.next();
      var value9 = portListener.next();

      expect(await value8, equals(80));
      expect(await value9, equals(90));
    });
  });
}

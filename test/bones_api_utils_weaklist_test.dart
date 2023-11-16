@TestOn('vm')
import 'dart:developer';
import 'dart:isolate';

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service_io.dart';

void main() async {
  final serverUri = (await Service.getInfo()).serverUri;

  if (serverUri == null) {
    print('** Test needs Dart VM Service to trigger the GC.\n');
    print('** Please run the test with the `--enable-vm-service` parameter:\n');
    print(
        '     dart --enable-vm-service test test/bones_api_utils_weaklist_test.dart\n');
    return;
  }

  Future<void> gc() async {
    final isolateId = Service.getIsolateId(Isolate.current)!;
    final vmService = await vmServiceConnectUri(_toWebSocket(serverUri));
    final profile = await vmService.getAllocationProfile(isolateId, gc: true);

    var memoryUsage = profile.memoryUsage;
    print('** GC> Memory: $memoryUsage');
  }

  Future<void> sleep(int ms) async {
    if (ms <= 0) return;
    print('** Sleep> $ms ms');
    return Future.delayed(Duration(milliseconds: ms));
  }

  group('WeakList', () {
    test('basic', () async {
      var weakList = WeakList<_MyEntry>(autoPurge: false);

      expect(weakList.isEmpty, isTrue);

      _MyEntry? e1 = _MyEntry('a');
      weakList.add(e1);

      expect(weakList.isEmpty, isFalse);
      expect(weakList.length, equals(1));
      expect(weakList[0], equals(e1));
      expect([...weakList], equals([e1]));

      _MyEntry? e2 = _MyEntry('b');
      weakList.add(e2);

      expect(weakList.length, equals(2));
      expect(weakList[0], equals(e1));
      expect(weakList[1], equals(e2));
      expect([...weakList], equals([e1, e2]));

      e1 = null;

      // The loop forces a GC for this `test` block context:
      for (var i = 0; i < 3; ++i) {
        await sleep(10);
        await gc();
      }

      expect(weakList.purge(force: true), isTrue);

      expect(weakList.length, equals(1));
      expect(weakList[0], equals(e2));
      expect([...weakList], equals([e2]));

      e2 = null;

      // The loop forces a GC for this `test` block context:
      for (var i = 0; i < 3; ++i) {
        await sleep(10);
        await gc();
      }

      expect(weakList.purge(force: true), isTrue);

      expect(weakList.isEmpty, isTrue);
      expect(weakList.length, equals(0));
      expect([...weakList], equals([]));
    });
  });
}

List<String> _cleanupPathSegments(Uri uri) {
  final pathSegments = <String>[];
  if (uri.pathSegments.isNotEmpty) {
    pathSegments.addAll(uri.pathSegments.where(
      (s) => s.isNotEmpty,
    ));
  }
  return pathSegments;
}

String _toWebSocket(Uri uri) {
  final pathSegments = _cleanupPathSegments(uri);
  pathSegments.add('ws');
  return uri.replace(scheme: 'ws', pathSegments: pathSegments).toString();
}

class _MyEntry {
  final String name;

  _MyEntry(this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MyEntry &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return '<$name>';
  }
}

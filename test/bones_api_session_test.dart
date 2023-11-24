@TestOn('vm')
@Timeout(Duration(seconds: 180))
import 'dart:isolate';

import 'package:bones_api/bones_api.dart';
import 'package:shared_map/shared_map.dart';
import 'package:test/test.dart';

void main() {
  group('APISessionSet', () {
    final sharedStoreRef = SharedStore("t1").sharedReference();

    test('basic (shared + Isolate)', () async {
      final timeout = Duration(seconds: 3);
      final timeout2 = Duration(seconds: 4);

      var apiSessionSet = APISessionSet(timeout,
          sharedStore: SharedStore.fromSharedReference(sharedStoreRef));

      expect(apiSessionSet.length, equals(0));

      expect(await apiSessionSet.get("abc"), isNull);

      var isolate1 = await Isolate.run(() async {
        var apiSessionSet2 =
            APISessionSet(timeout, sharedStoreReference: sharedStoreRef);
        return apiSessionSet2.get("abc");
      });

      expect(isolate1, isNull);

      expect(apiSessionSet.length, equals(0));

      var s1 = await apiSessionSet.getOrCreate("abc");
      expect(s1.id, equals('abc'));

      expect(apiSessionSet.length, equals(1));

      var isolate2 = await Isolate.run(() async {
        var apiSessionSet2 =
            APISessionSet(timeout, sharedStoreReference: sharedStoreRef);
        return apiSessionSet2.get("abc");
      });

      expect(apiSessionSet.length, equals(1));

      expect(isolate2?.id, equals('abc'));

      var s2 = await apiSessionSet.getMarkingAccess("abc");
      expect(s2?.id, equals('abc'));

      var isolate3 = await Isolate.run(() async {
        var apiSessionSet2 =
            APISessionSet(timeout, sharedStoreReference: sharedStoreRef);
        return apiSessionSet2.getMarkingAccess("abc");
      });

      expect(isolate3?.id, equals('abc'));

      expect(await apiSessionSet.expiredSessions(), equals([]));

      var isolate4 = await Isolate.run(() async {
        var apiSessionSet2 =
            APISessionSet(timeout, sharedStoreReference: sharedStoreRef);
        return apiSessionSet2.expiredSessions();
      });

      expect(isolate4, equals([]));

      await Future.delayed(timeout2);

      var expired1 = await apiSessionSet.expiredSessions();
      expect(expired1.map((e) => e.id).toList(), equals(['abc']));

      expect(await apiSessionSet.checkSessions(), equals(1));

      expect(apiSessionSet.length, equals(0));
      expect(await apiSessionSet.get("abc"), isNull);

      var isolate5 = await Isolate.run(() async {
        var apiSessionSet2 =
            APISessionSet(timeout, sharedStoreReference: sharedStoreRef);
        var s = await apiSessionSet2.getOrCreate("xyz");
        var l = await apiSessionSet2.length;
        return (s, l);
      });

      expect(isolate5.$1.id, equals('xyz'));
      expect(isolate5.$2, equals(1));

      expect(apiSessionSet.length, equals(1));

      var s3 = await apiSessionSet.getMarkingAccess("xyz");
      expect(s3?.id, equals('xyz'));

      var isolate6 = await Isolate.run(() async {
        var apiSessionSet2 =
            APISessionSet(timeout, sharedStoreReference: sharedStoreRef);
        var s1 = await apiSessionSet2.get("xyz");

        await Future.delayed(timeout2);

        var check = await apiSessionSet2.checkSessions();
        var l = await apiSessionSet2.length;

        var s2 = await apiSessionSet2.get("xyz");

        return (s1, check, l, s2);
      });

      expect(isolate6.$1?.id, equals('xyz'));
      expect(isolate6.$2, equals(1));
      expect(isolate6.$3, equals(0));
      expect(isolate6.$4, isNull);

      expect(apiSessionSet.length, equals(0));
      expect(await apiSessionSet.get("abc"), isNull);
      expect(await apiSessionSet.get("xyz"), isNull);
    });
  });
}

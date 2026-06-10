import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

void main() {
  group('Enum', () {
    test('enumFromName', () async {
      expect(enumFromName('admin', RoleType.values), RoleType.admin);
      expect(enumFromName(' admin ', RoleType.values), RoleType.admin);
      expect(enumFromName(' Guest ', RoleType.values), RoleType.guest);
      expect(enumFromName('x', RoleType.values), isNull);
      expect(enumFromName('', RoleType.values), isNull);
      expect(enumFromName(null, RoleType.values), isNull);
    });

    test('enumToName', () async {
      expect(enumToName(RoleType.admin), equals('admin'));
      expect(enumToName(RoleType.guest), equals('guest'));
    });

    test('parse', () async {
      expect(RoleType.values.parse('admin'), equals(RoleType.admin));
      expect(RoleType.values.parse(' Guest '), equals(RoleType.guest));
      expect(RoleType.values.parse(' X '), isNull);
    });
  });

  group('IdenticalSet', () {
    test('basic', () {
      var s1 = IdenticalSet<String>();

      expect(s1.isEmpty, isTrue);
      expect(s1.length, equals(0));
      expect(s1.toList(), equals([]));

      expect(s1.contains('a'), isFalse);
      expect(s1.add('a'), isTrue);
      expect(s1.contains('a'), isTrue);

      expect(s1.length, equals(1));
      expect(s1.isEmpty, isFalse);
      expect(s1.isNotEmpty, isTrue);

      expect(s1.toList(), unorderedEquals(['a']));

      expect(s1.contains('b'), isFalse);
      expect(s1.add('b'), isTrue);
      expect(s1.contains('b'), isTrue);

      expect(s1.length, equals(2));
      expect(s1.isEmpty, isFalse);
      expect(s1.isNotEmpty, isTrue);

      expect(s1.toList(), unorderedEquals(['a', 'b']));

      expect(s1.contains('x'), isFalse);
      expect(s1.remove('x'), isFalse);

      expect(s1.contains('b'), isTrue);
      expect(s1.add('b'), isFalse);
      expect(s1.contains('b'), isTrue);

      expect(s1.length, equals(2));
      expect(s1.isEmpty, isFalse);
      expect(s1.isNotEmpty, isTrue);

      expect(s1.toList(), unorderedEquals(['a', 'b']));

      expect(s1.contains('a'), isTrue);
      expect(s1.remove('a'), isTrue);
      expect(s1.contains('a'), isFalse);

      expect(s1.length, equals(1));
      expect(s1.isEmpty, isFalse);
      expect(s1.isNotEmpty, isTrue);

      expect(s1.toList(), unorderedEquals(['b']));
    });
  });

  group('isEqualsDeep', () {
    test('primitives and identity', () {
      expect(isEqualsDeep(1, 1), isTrue);
      expect(isEqualsDeep('a', 'a'), isTrue);
      expect(isEqualsDeep(1, 2), isFalse);
      expect(isEqualsDeep(null, null), isTrue);
      expect(isEqualsDeep(null, 1), isFalse);
      expect(isEqualsDeep(1, null), isFalse);

      var o = Object();
      expect(isEqualsDeep(o, o), isTrue);
    });

    test('lists', () {
      expect(isEqualsListDeep([1, 2, 3], [1, 2, 3]), isTrue);
      expect(isEqualsListDeep([1, 2, 3], [1, 2, 4]), isFalse);
      expect(isEqualsListDeep([1, 2], [1, 2, 3]), isFalse);
      expect(isEqualsListDeep(null, [1]), isFalse);
      expect(isEqualsListDeep([1], null), isFalse);
      expect(isEqualsListDeep(null, null), isTrue);

      var l = [1, 2];
      expect(isEqualsListDeep(l, l), isTrue);

      // nested
      expect(
        isEqualsDeep(
          [
            [1, 2],
            [3, 4],
          ],
          [
            [1, 2],
            [3, 4],
          ],
        ),
        isTrue,
      );
      expect(
        isEqualsDeep(
          [
            [1, 2],
          ],
          [
            [1, 9],
          ],
        ),
        isFalse,
      );
    });

    test('iterables', () {
      expect(isEqualsIterableDeep([1, 2].map((e) => e), [1, 2]), isTrue);
      expect(isEqualsIterableDeep([1, 2].where((e) => true), [1, 3]), isFalse);
      expect(isEqualsIterableDeep([1].map((e) => e), [1, 2]), isFalse);
      expect(isEqualsIterableDeep(null, [1]), isFalse);
      expect(isEqualsIterableDeep([1], null), isFalse);
      expect(isEqualsIterableDeep(null, null), isTrue);
    });

    test('sets', () {
      expect(isEqualsSetDeep({1, 2, 3}, {3, 2, 1}), isTrue);
      expect(isEqualsSetDeep({1, 2}, {1, 2, 3}), isFalse);
      expect(isEqualsSetDeep({1, 2}, {1, 9}), isFalse);
      expect(isEqualsSetDeep(null, {1}), isFalse);
      expect(isEqualsSetDeep({1}, null), isFalse);
      expect(isEqualsSetDeep(null, null), isTrue);

      var s = {1, 2};
      expect(isEqualsSetDeep(s, s), isTrue);
    });

    test('maps', () {
      expect(isEqualsMapDeep({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), isTrue);
      expect(isEqualsMapDeep({'a': 1}, {'a': 2}), isFalse);
      expect(isEqualsMapDeep({'a': 1}, {'a': 1, 'b': 2}), isFalse);
      expect(isEqualsMapDeep({'a': 1}, {'b': 1}), isFalse);
      expect(isEqualsMapDeep(null, {'a': 1}), isFalse);
      expect(isEqualsMapDeep({'a': 1}, null), isFalse);
      expect(isEqualsMapDeep(null, null), isTrue);

      var m = {'a': 1};
      expect(isEqualsMapDeep(m, m), isTrue);

      // nested via isEqualsDeep dispatch
      expect(
        isEqualsDeep(
          {
            'a': [1, 2],
          },
          {
            'a': [1, 2],
          },
        ),
        isTrue,
      );
    });

    test('dispatch via isEqualsDeep', () {
      expect(isEqualsDeep([1, 2], [1, 2]), isTrue);
      expect(isEqualsDeep({1, 2}, {2, 1}), isTrue);
      expect(isEqualsDeep({'a': 1}, {'a': 1}), isTrue);
      // List vs Set -> not equal
      expect(isEqualsDeep([1, 2], {1, 2}), isFalse);
    });

    test('valueEquality', () {
      bool ciEquals(Object? a, Object? b) =>
          a.toString().toLowerCase() == b.toString().toLowerCase();

      expect(isEqualsDeep('ABC', 'abc'), isFalse);
      expect(isEqualsDeep('ABC', 'abc', valueEquality: ciEquals), isTrue);
      expect(
        isEqualsDeep(['ABC'], ['abc'], valueEquality: ciEquals),
        isTrue,
      );
    });
  });

  group('intersectsIterableDeep', () {
    test('basic', () {
      expect(intersectsIterableDeep([1, 2, 3], [4, 5, 2]), isTrue);
      expect(intersectsIterableDeep([1, 2, 3], [4, 5, 6]), isFalse);
      expect(intersectsIterableDeep([], [1]), isFalse);
      expect(intersectsIterableDeep([1], []), isFalse);
      expect(intersectsIterableDeep(null, [1]), isFalse);
      expect(intersectsIterableDeep([1], null), isFalse);

      var l = [1, 2];
      expect(intersectsIterableDeep(l, l), isTrue);
    });

    test('deep elements', () {
      expect(
        intersectsIterableDeep(
          [
            [1, 2],
          ],
          [
            [9, 9],
            [1, 2],
          ],
        ),
        isTrue,
      );
    });
  });

  group('deepCopy', () {
    test('primitives', () {
      expect(deepCopy(null), isNull);
      expect(deepCopy('abc'), equals('abc'));
      expect(deepCopy(42), equals(42));
      expect(deepCopy(3.14), equals(3.14));
      expect(deepCopy(true), equals(true));
    });

    test('list copies are independent', () {
      List original = [
        [1, 2],
        [3, 4],
      ];
      var copy = deepCopy(original) as List;
      expect(copy, equals(original));
      expect(identical(copy, original), isFalse);
      expect(identical(copy[0], original[0]), isFalse);

      (copy[0] as List)[0] = 99;
      expect((original[0] as List)[0], equals(1));
    });

    test('deepCopyList typed fast paths', () {
      expect(deepCopyList(null), isNull);
      expect(deepCopyList(<String>[]), equals(<String>[]));
      expect(deepCopyList(<String>['a', 'b']), equals(['a', 'b']));
      expect(deepCopyList(<int>[1, 2]), equals([1, 2]));
      expect(deepCopyList(<double>[1.0, 2.0]), equals([1.0, 2.0]));
      expect(deepCopyList(<num>[1, 2.0]), equals(<num>[1, 2.0]));
      expect(deepCopyList(<bool>[true, false]), equals([true, false]));

      var bytes = Uint8List.fromList([1, 2, 3]);
      var bytesCopy = deepCopyList(bytes)!;
      expect(bytesCopy, equals([1, 2, 3]));
      expect(identical(bytesCopy, bytes), isFalse);

      var i8 = Int8List.fromList([1, -2, 3]);
      var i8Copy = deepCopyList(i8)!;
      expect(i8Copy, equals([1, -2, 3]));
      expect(identical(i8Copy, i8), isFalse);
    });

    test('deepCopySet typed fast paths', () {
      expect(deepCopySet(null), isNull);
      expect(deepCopySet(<String>{}), equals(<String>{}));
      expect(deepCopySet(<String>{'a'}), equals({'a'}));
      expect(deepCopySet(<int>{1, 2}), equals({1, 2}));
      expect(deepCopySet(<double>{1.0}), equals({1.0}));
      expect(deepCopySet(<num>{1, 2.0}), equals(<num>{1, 2.0}));
      expect(deepCopySet(<bool>{true}), equals({true}));

      var original = <List<int>>{
        [1, 2],
      };
      var copy = deepCopySet(original)!;
      expect(copy.first, equals([1, 2]));
      expect(identical(copy.first, original.first), isFalse);
    });

    test('deepCopyMap typed fast paths', () {
      expect(deepCopyMap(null), isNull);
      expect(deepCopyMap(<String, String>{}), equals(<String, String>{}));
      expect(deepCopyMap(<String, String>{'a': 'b'}), equals({'a': 'b'}));
      expect(deepCopyMap(<String, int>{'a': 1}), equals({'a': 1}));
      expect(deepCopyMap(<String, double>{'a': 1.0}), equals({'a': 1.0}));
      expect(deepCopyMap(<String, num>{'a': 1}), equals(<String, num>{'a': 1}));
      expect(deepCopyMap(<String, bool>{'a': true}), equals({'a': true}));

      var original = <String, List<int>>{
        'k': [1, 2],
      };
      var copy = deepCopyMap(original)!;
      expect(copy['k'], equals([1, 2]));
      expect(identical(copy['k'], original['k']), isFalse);
    });

    test('deepCopy dispatch for Set/Iterable/Map', () {
      var s = deepCopy(<int>{1, 2})!;
      expect(s, equals({1, 2}));

      var it = deepCopy([1, 2, 3].map((e) => e * 2))!;
      expect(it, equals([2, 4, 6]));

      var m = deepCopy(<String, int>{'a': 1})!;
      expect(m, equals({'a': 1}));
    });
  });

  group('MapAsCacheExtension', () {
    test('getCached caches the computed value', () {
      var cache = <String, int>{};
      var calls = 0;

      var v1 = cache.getCached('a', () {
        calls++;
        return 10;
      });
      expect(v1, equals(10));

      var v2 = cache.getCached('a', () {
        calls++;
        return 20;
      });
      expect(v2, equals(10));
      expect(calls, equals(1));
    });

    test('getCachedNullable does not cache null', () {
      var cache = <String, int>{};
      var calls = 0;

      var v = cache.getCachedNullable('a', () {
        calls++;
        return null;
      });
      expect(v, isNull);
      expect(cache.containsKey('a'), isFalse);

      var v2 = cache.getCachedNullable('a', () {
        calls++;
        return 5;
      });
      expect(v2, equals(5));
      expect(cache['a'], equals(5));
      expect(calls, equals(2));
    });

    test('getIfCached returns current value', () {
      var cache = <String, int>{'a': 1};
      expect(cache.getIfCached('a'), equals(1));
      expect(cache.getIfCached('b'), isNull);
    });

    test('getCachedAsync caches resolved value', () async {
      var cache = <String, int>{};
      var calls = 0;

      var v1 = await cache.getCachedAsync('a', () async {
        calls++;
        return 7;
      });
      expect(v1, equals(7));

      var v2 = await cache.getCachedAsync('a', () async {
        calls++;
        return 99;
      });
      expect(v2, equals(7));
      expect(calls, equals(1));
    });

    test('getCachedAsyncNullable does not cache null', () async {
      var cache = <String, int>{};

      var v = await cache.getCachedAsyncNullable('a', () async => null);
      expect(v, isNull);
      expect(cache.containsKey('a'), isFalse);

      var v2 = await cache.getCachedAsyncNullable('a', () async => 3);
      expect(v2, equals(3));
      expect(cache['a'], equals(3));
    });

    test('checkCacheLimit evicts oldest entries', () {
      var cache = <String, int>{};
      for (var i = 0; i < 5; ++i) {
        cache['k$i'] = i;
      }

      expect(cache.checkCacheLimit(null), equals(0));
      expect(cache.length, equals(5));

      var deleted = cache.checkCacheLimit(3);
      expect(deleted, equals(2));
      expect(cache.length, equals(3));
      // first-inserted keys evicted
      expect(cache.containsKey('k0'), isFalse);
      expect(cache.containsKey('k1'), isFalse);
      expect(cache.containsKey('k4'), isTrue);

      var cleared = cache.checkCacheLimit(0);
      expect(cleared, equals(3));
      expect(cache.isEmpty, isTrue);
    });

    test('getCached enforces cacheLimit', () {
      var cache = <String, int>{};
      // Eviction runs before insertion, so length stays bounded near the limit.
      for (var i = 0; i < 10; ++i) {
        cache.getCached('k$i', () => i, cacheLimit: 2);
      }
      expect(cache.length, lessThanOrEqualTo(3));
      expect(cache.length, greaterThanOrEqualTo(2));
    });
  });

  group('MapOfCachesExtension', () {
    test('getMultiCached reuses equivalent (wildcard) cache', () {
      var caches = <(String, bool), Map<String, int>>{};

      // Populate a wildcard cache (second field == true matches any query).
      caches.populateMultiCache('k1', ('a', true), () => <String, int>{}, 100);

      var computerCalled = false;
      var v = caches.getMultiCached('k1', ('a', false), () => <String, int>{}, () {
        computerCalled = true;
        return 999;
      });

      expect(v, equals(100));
      expect(computerCalled, isFalse);
    });

    test('getMultiCached computes and caches on miss', () {
      var caches = <(String, bool), Map<String, int>>{};

      var v = caches.getMultiCached('k', ('a', false), () => <String, int>{}, () => 42);
      expect(v, equals(42));

      // Now cached in its own context.
      var v2 = caches.getMultiCached('k', ('a', false), () => <String, int>{}, () => 0);
      expect(v2, equals(42));
    });

    test('getMultiCachedNullable does not cache null', () {
      var caches = <(String, bool), Map<String, int>>{};

      var v = caches.getMultiCachedNullable(
        'k',
        ('a', false),
        () => <String, int>{},
        () => null,
      );
      expect(v, isNull);

      var v2 = caches.getMultiCachedNullable(
        'k',
        ('a', false),
        () => <String, int>{},
        () => 5,
      );
      expect(v2, equals(5));
    });

    test('getMultiCachedAsync resolves and caches', () async {
      var caches = <(String, bool), Map<String, int>>{};

      var v = await caches.getMultiCachedAsync(
        'k',
        ('a', false),
        () => <String, int>{},
        () async => 11,
      );
      expect(v, equals(11));

      var v2 = await caches.getMultiCachedAsync(
        'k',
        ('a', false),
        () => <String, int>{},
        () async => 0,
      );
      expect(v2, equals(11));
    });

    test('isEquivalentContext wildcard semantics', () {
      var caches = <(String, bool), Map<String, int>>{};
      expect(caches.isEquivalentContext(('a', false), ('a', false)), isTrue);
      expect(caches.isEquivalentContext(('a', true), ('a', false)), isTrue);
      expect(caches.isEquivalentContext(('a', false), ('a', true)), isFalse);
      expect(caches.isEquivalentContext(('a', false), ('b', false)), isFalse);
    });

    test('equivalentCaches excludes exact-context match', () {
      var caches = <(String, bool), Map<String, int>>{};
      caches.populateMultiCache('k', ('a', true), () => <String, int>{}, 1);
      caches.populateMultiCache('k', ('a', false), () => <String, int>{}, 2);

      var equivalents = caches.equivalentCaches(('a', false)).toList();
      // Only the wildcard ('a', true) is equivalent; ('a', false) itself excluded.
      expect(equivalents.length, equals(1));
      expect(equivalents.first['k'], equals(1));
    });
  });

  group('RecordExtension', () {
    test('positionalParametersLength', () {
      expect((1,).positionalParametersLength, equals(1));
      expect((1, 2).positionalParametersLength, equals(2));
      expect((1, 2, 3).positionalParametersLength, equals(3));
      expect((1, 2, 3, 4).positionalParametersLength, equals(4));
      expect((1, 2, 3, 4, 5).positionalParametersLength, equals(5));
      // Cached on second access.
      expect((9, 8).positionalParametersLength, equals(2));
    });
  });
}

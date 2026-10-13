@TestOn('vm')
library;

import 'dart:convert' as dart_convert;
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:statistics/statistics.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A plain (non reflected) class, with a [GenericEntityHandler].
class _Plain extends Entity {
  int id;
  String name;

  _Plain(this.id, this.name);

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const <String>['id', 'name'];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'name' => name as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'name' => TypeInfo.tString,
    _ => null,
  };

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int;
      case 'name':
        name = value as String;
    }
  }

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

final _plainEntityHandler = GenericEntityHandler<_Plain>(
  instantiatorDefault: () => _Plain(0, ''),
  instantiatorFromMap: (m) => _Plain(m['id'] as int, m['name'] as String),
  type: _Plain,
  typeName: '_Plain',
);

void main() {
  setUpAll(() {
    Json.boot();
    UserInfo$reflection.boot();
    userInfoEntityHandler.ensureRegistered();
    _plainEntityHandler.ensureRegistered();
  });

  group('Json', () {
    test('registered type decoders', () {
      var decoder = JsonDecoder();

      var di = decoder.fromJson(10, type: DynamicInt);
      expect(di, isA<DynamicInt>());
      expect((di as DynamicInt).toInt(), equals(10));

      var dn = Json.fromJson(2.5, type: DynamicNumber);
      expect(dn, isA<DynamicNumber>());
      expect((dn as DynamicNumber).toDouble(), equals(2.5));

      var refList = decoder.fromJson(
        {
          'EntityReferenceList': 'UserInfo',
          'ids': [1, 2],
        },
        typeInfo: TypeInfo<EntityReferenceList<UserInfo>>.fromType(
          EntityReferenceList,
          [TypeInfo<UserInfo>.fromType(UserInfo)],
        ),
      );
      expect(refList, isA<EntityReferenceList<UserInfo>>());
      expect((refList as EntityReferenceList<UserInfo>).ids, equals([1, 2]));
    });

    test('value decoders (Time, Decimal, DynamicInt)', () {
      var time = Json.fromJson('10:20:30', type: Time);
      expect(time, equals(Time(10, 20, 30)));

      var dec = Json.fromJson('1.25', type: Decimal);
      expect(dec, equals(Decimal.parse('1.25')));

      var di = Json.fromJson(7, type: DynamicInt);
      expect((di as DynamicInt).toInt(), equals(7));
    });

    test('toJson: DynamicNumber and entityHandlerProvider', () {
      var dec = Decimal.parse('1.50');
      var j = Json.toJson(dec);
      expect(j, equals(dec.toStringStandard()));

      var j2 = Json.toJson({
        'a': 'x',
        'n': [1, 2],
      }, entityHandlerProvider: EntityHandlerProvider());
      expect(
        j2,
        equals({
          'a': 'x',
          'n': [1, 2],
        }),
      );

      var j3 = Json.toJson(
        _Plain(1, 'p'),
        entityHandlerProvider: EntityHandlerProvider.globalProvider,
      );
      expect(j3, equals({'id': 1, 'name': 'p'}));
    });

    test('fromJson with entityHandlerProvider', () {
      var o = Json.fromJson<UserInfo>(
        {'id': 1, 'info': 'a'},
        type: UserInfo,
        entityHandlerProvider: EntityHandlerProvider.globalProvider,
      );
      expect(o, isA<UserInfo>());
      expect(o!.info, equals('a'));
    });

    test('async decoders', () async {
      var o1 = await Json.fromJsonAsync<UserInfo>({
        'id': 1,
        'info': 'a1',
      }, type: UserInfo);
      expect(o1!.info, equals('a1'));

      var o2 = await Json.fromJsonAsync<UserInfo>(
        {'id': 2, 'info': 'a2'},
        type: UserInfo,
        entityHandlerProvider: EntityHandlerProvider.globalProvider,
      );
      expect(o2!.info, equals('a2'));

      var l = await Json.fromJsonListAsync<UserInfo>([
        {'id': 3, 'info': 'a3'},
        {'id': 4, 'info': 'a4'},
      ], type: UserInfo);
      expect(l.map((e) => e!.info), equals(['a3', 'a4']));

      var m = Json.fromJsonMap<UserInfo>({
        'id': 5,
        'info': 'a5',
      }, type: UserInfo);
      expect(m.info, equals('a5'));

      var m2 = await Json.fromJsonMapAsync<UserInfo>(
        Future.value({'id': 6, 'info': 'a6'}),
        type: UserInfo,
      );
      expect(m2.info, equals('a6'));

      var m3 = await Json.fromJsonMapAsync<UserInfo>(
        {'id': 7, 'info': 'a7'},
        type: UserInfo,
        entityHandlerProvider: EntityHandlerProvider.globalProvider,
        entityCache: JsonEntityCacheSimple(),
      );
      expect(m3.info, equals('a7'));

      // Non reflected type with a global `EntityHandler`:
      var p = await Json.fromJsonMapAsync<_Plain>({
        'id': 8,
        'name': 'p8',
      }, type: _Plain);
      expect(p.name, equals('p8'));

      var d = await Json.decodeAsync<Map>(Future.value('{"a": 1}'));
      expect(d, equals({'a': 1}));

      var bytes = Uint8List.fromList(dart_convert.utf8.encode('{"b": "x"}'));
      var d2 = await Json.decodeFromBytesAsync<Map>(Future.value(bytes));
      expect(d2, equals({'b': 'x'}));
    });

    test('defaultFieldNameResolver', () {
      expect(
        Json.defaultFieldNameResolver('country_code', {'COUNTRYCODE': 1}),
        equals('COUNTRYCODE'),
      );
      expect(
        Json.defaultFieldNameResolver('country_code', {'Country_Code': 1}),
        equals('Country_Code'),
      );
      expect(
        Json.defaultFieldNameResolver('country_code', {'other': 1}),
        isNull,
      );
      expect(
        Json.defaultFieldNameResolver('name', {'NAME': 1}),
        equals('NAME'),
      );
      expect(Json.defaultFieldNameResolver('name', {'x': 1}), isNull);
    });

    test('defaultFieldValueResolver', () {
      var decoder = JsonDecoder();

      Object? resolve(Object? v, TypeReflection t) =>
          Json.defaultFieldValueResolver('f', v, t, decoder, null);

      expect(resolve(null, TypeReflection.tString), isNull);
      expect(resolve('s', TypeReflection.tString), equals('s'));
      expect(resolve(123, TypeReflection.tString), equals('123'));
      expect(resolve('12', TypeReflection.tInt), equals(12));
      expect(resolve('1.5', TypeReflection.tDouble), equals(1.5));
      expect(resolve('3', TypeReflection.tNum), equals(3));
      expect(resolve('true', TypeReflection.tBool), isTrue);

      var ref = EntityReference<UserInfo>.fromID(1);
      var refType = TypeReflection<EntityReference<UserInfo>>(EntityReference, [
        UserInfo,
      ]);
      expect(resolve(ref, refType), same(ref));

      var refList = EntityReferenceList<UserInfo>.fromIDs([1]);
      var refListType = TypeReflection<EntityReferenceList<UserInfo>>(
        EntityReferenceList,
        [UserInfo],
      );
      expect(resolve(refList, refListType), same(refList));

      // Another type of reference:
      var refStoreType = TypeReflection<EntityReference<Store>>(
        EntityReference,
        [Store],
      );
      var resolved = resolve(ref, refStoreType);
      expect(resolved, isA<EntityReference>());
    });

    test('defaultFieldValueResolver: entity lists', () {
      var entityCache = JsonEntityCacheSimple();
      var u1 = UserInfo('u1', id: 1);
      var u2 = UserInfo('u2', id: 2);
      entityCache.cacheEntity(u1);
      entityCache.cacheEntity(u2);

      var decoder = JsonDecoder(entityCache: entityCache);

      var listType = TypeReflection<List<UserInfo>>(List, [UserInfo]);

      Object? resolve(Object? v) => Json.defaultFieldValueResolver(
        'f',
        v,
        listType,
        decoder,
        EntityHandlerProvider.globalProvider,
      );

      expect(resolve([1, 2]), equals([u1, u2]));
      expect(resolve([1, null]), equals([u1, null]));
      expect(resolve([u1, u2]), equals([u1, u2]));
      expect(resolve([null]), equals([null]));

      var mixed = resolve([
        u1,
        {'id': 3, 'info': 'u3'},
        2,
        null,
      ]);
      expect(mixed, isA<List>());
      expect((mixed as List).length, equals(4));
      expect(mixed[0], same(u1));
      expect((mixed[1] as UserInfo).info, equals('u3'));
      expect(mixed[2], same(u2));
      expect(mixed[3], isNull);
    });

    test('dumpRuntimeTypes', () {
      expect(Json.dumpRuntimeTypes(Object()), startsWith('@<Object>:'));
      var s = Json.dumpRuntimeTypes({
        'a': [1, 2.5, true, null, 'x'],
      });
      expect(s, contains('<int>:1'));
      expect(s, contains('<double>:2.5'));
      expect(s, contains('<bool>:true'));
      expect(s, contains('<null>'));
      expect(s, contains('<String>:"x"'));
    });

    test('asEntityProvider', () async {
      var entityCache = JsonEntityCacheSimple();
      var u1 = UserInfo('u1', id: 1);
      entityCache.cacheEntity(u1);

      var provider = entityCache.asEntityProvider;
      expect(await provider.getEntityByID(1, type: UserInfo), same(u1));
      expect(provider.toString(), startsWith('EntityProvider@'));
    });
  });

  group('collections', () {
    test('PositionalFields: duplicated fields', () {
      expect(() => PositionalFields(['a', 'b', 'a']), throwsArgumentError);
    });

    test('isEqualsDeep with EntityReferenceList and Iterable', () {
      var u1 = UserInfo('u1', id: 1);
      var u2 = UserInfo('u2', id: 2);

      var refList = EntityReferenceList<UserInfo>.fromEntities([u1, u2]);
      var refList2 = EntityReferenceList<UserInfo>.fromEntities([u1, u2]);

      expect(isEqualsDeep([u1, u2], refList), isTrue);
      expect(isEqualsDeep([u2, u1], refList), isFalse);

      var itr = [u1, u2].map((e) => e);
      expect(isEqualsDeep(itr, [u1, u2].map((e) => e)), isTrue);
      expect(isEqualsDeep(itr, refList), isTrue);
      expect(isEqualsDeep(itr, 'x'), isFalse);

      expect(isEqualsDeep(refList, refList2), isTrue);
      expect(isEqualsDeep(refList, [u1, u2].map((e) => e)), isTrue);
      expect(isEqualsDeep(refList, [u1]), isFalse);
      expect(isEqualsDeep(refList, 'x'), isFalse);
    });

    test('MapAsCacheExtension with TimedMap', () {
      var m = TimedMap<String, int>(const Duration(minutes: 10));
      m['a'] = 1;
      expect(m.getIfCached('a'), equals(1));
      expect(m.getIfCached('b'), isNull);
    });

    test('isEquivalentContext (1..10 elements)', () {
      expect(
        <(Object?,), Map<String, int>>{}.isEquivalentContext((1,), (1,)),
        isTrue,
      );
      expect(
        <(Object?,), Map<String, int>>{}.isEquivalentContext((1,), (2,)),
        isFalse,
      );
      expect(
        <(Object?, Object?, Object?), Map<String, int>>{}.isEquivalentContext(
          (1, true, true),
          (1, 2, 3),
        ),
        isTrue,
      );
      expect(
        <(Object?, Object?, Object?, Object?), Map<String, int>>{}
            .isEquivalentContext((1, 2, true, 4), (1, 2, 3, 4)),
        isTrue,
      );
      expect(
        <(Object?, Object?, Object?, Object?, Object?), Map<String, int>>{}
            .isEquivalentContext((1, 2, 3, 4, 5), (1, 2, 3, 4, 6)),
        isFalse,
      );
      expect(
        <
              (Object?, Object?, Object?, Object?, Object?, Object?),
              Map<String, int>
            >{}
            .isEquivalentContext((1, 2, 3, 4, 5, true), (1, 2, 3, 4, 5, 6)),
        isTrue,
      );
      expect(
        <
              (Object?, Object?, Object?, Object?, Object?, Object?, Object?),
              Map<String, int>
            >{}
            .isEquivalentContext(
              (1, 2, 3, 4, 5, 6, true),
              (1, 2, 3, 4, 5, 6, 7),
            ),
        isTrue,
      );
      expect(
        <
              (
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
              ),
              Map<String, int>
            >{}
            .isEquivalentContext(
              (1, 2, 3, 4, 5, 6, 7, true),
              (1, 2, 3, 4, 5, 6, 7, 8),
            ),
        isTrue,
      );
      expect(
        <
              (
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
              ),
              Map<String, int>
            >{}
            .isEquivalentContext(
              (1, 2, 3, 4, 5, 6, 7, 8, true),
              (1, 2, 3, 4, 5, 6, 7, 8, 9),
            ),
        isTrue,
      );
      expect(
        <
              (
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
                Object?,
              ),
              Map<String, int>
            >{}
            .isEquivalentContext(
              (1, 2, 3, 4, 5, 6, 7, 8, 9, true),
              (1, 2, 3, 4, 5, 6, 7, 8, 9, 10),
            ),
        isTrue,
      );
      expect(
        <Record, Map<String, int>>{}.isEquivalentContext((a: 1), (a: 1)),
        isFalse,
      );
    });

    test('multi-cache: getIfCached / getMultiCachedAsyncNullable', () async {
      var caches = <(Object?, Object?), Map<String, int>>{};

      expect(caches.getIfCached('a', (1, true), () => <String, int>{}), isNull);

      caches.populateMultiCache('a', (1, true), () => <String, int>{}, 10);
      expect(caches.getIfCached('a', (1, true), () => <String, int>{}), 10);

      // Equivalent context (`true` matches any value):
      expect(caches.getIfCached('a', (1, 2), () => <String, int>{}), 10);

      var r1 = await caches.getMultiCachedAsyncNullable(
        'a',
        (1, 2),
        () => <String, int>{},
        () => 99,
      );
      expect(r1, equals(10));

      var r2 = await caches.getMultiCachedAsyncNullable(
        'b',
        (1, 2),
        () => <String, int>{},
        () => Future.value(20),
      );
      expect(r2, equals(20));
      expect(caches[(1, 2)]!['b'], equals(20));

      var r3 = await caches.getMultiCachedAsyncNullable(
        'c',
        (1, 2),
        () => <String, int>{},
        () => null,
      );
      expect(r3, isNull);
      expect(caches[(1, 2)]!.containsKey('c'), isFalse);
    });

    test('positionalParametersLength', () {
      expect((1,).positionalParametersLength, equals(1));
      expect((1, 2, 3).positionalParametersLength, equals(3));
      expect((a: 1).positionalParametersLength, equals(-1));
      expect((1, b: 2).positionalParametersLength, equals(-1));
    });

    test('Future.populateMultiCache', () async {
      var caches = <(Object?,), Map<String, int>>{};

      var v1 = await Future<int>.value(
        5,
      ).populateMultiCache(caches, 'k1', (1,), () => <String, int>{});
      expect(v1, equals(5));
      expect(caches[(1,)]!['k1'], equals(5));

      var v2 = await Future<int?>.value(
        6,
      ).populateMultiCache(caches, 'k2', (1,), () => <String, int>{});
      expect(v2, equals(6));
      expect(caches[(1,)]!['k2'], equals(6));

      var v3 = await Future<int?>.value(
        null,
      ).populateMultiCache(caches, 'k3', (1,), () => <String, int>{});
      expect(v3, isNull);
      expect(caches[(1,)]!.containsKey('k3'), isFalse);
    });
  });
}

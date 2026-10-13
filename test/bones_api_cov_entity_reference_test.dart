@TestOn('vm')
@Tags(['entities'])
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A plain (non reflected, without `EntityHandler`) entity-like class.
class _Thing {
  final int? id;
  final String name;

  _Thing(this.id, this.name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  String toString() => '_Thing#$id:$name';
}

/// An object without `id` and without `toJson`.
class _NoIdNoJson {
  @override
  String toString() => '_NoIdNoJson';
}

class _FixedInstantiator extends EntityInstantiator<_Thing> {
  final _Thing thing;
  int calls = 0;

  _FixedInstantiator(this.thing);

  @override
  _Thing instantiate() {
    ++calls;
    return thing;
  }
}

class _ThingProvider implements EntityProvider {
  final bool async;
  final Map<Object?, _Thing> things;

  _ThingProvider(this.things, {this.async = false});

  int calls = 0;

  @override
  FutureOr<O?> getEntityByID<O>(
    dynamic id, {
    Type? type,
    bool sync = false,
    EntityResolutionRules? resolutionRules,
  }) {
    ++calls;
    var o = things[id] as O?;
    if (async) {
      if (sync) return null;
      return Future<O?>.value(o);
    }
    return o;
  }
}

/// Always returns a `Future`, even when `sync` is requested.
class _AlwaysAsyncProvider implements EntityProvider {
  @override
  FutureOr<O?> getEntityByID<O>(
    dynamic id, {
    Type? type,
    bool sync = false,
    EntityResolutionRules? resolutionRules,
  }) => Future<O?>.value(null);
}

/// An `EntityProvider` that is also an `EntityHandlerProvider`.
class _HandlerEntityProvider extends EntityHandlerProvider
    implements EntityProvider {
  @override
  FutureOr<O?> getEntityByID<O>(
    dynamic id, {
    Type? type,
    bool sync = false,
    EntityResolutionRules? resolutionRules,
  }) => null;
}

EntityReference<_Thing>? _nullRef() => null;

EntityReference<_Thing>? _someRef(EntityReference<_Thing> r) => r;

EntityReferenceList<_Thing>? _nullRefList() => null;

EntityReferenceList<_Thing>? _someRefList(EntityReferenceList<_Thing> r) => r;

void main() {
  setUpAll(() {
    userInfoEntityHandler.ensureRegistered();
    storeEntityHandler.ensureRegistered();
  });

  group('EntityReference (no EntityHandler)', () {
    test('fromEntity: type, ids and JSON', () {
      var thing = _Thing(1, 'a');
      var ref = EntityReference<_Thing>.fromEntity(thing);

      expect(ref.type, equals(_Thing));
      expect(ref.typeName, equals('_Thing'));
      expect(ref.entityHandler, isNull);
      expect(ref.entityProvider, isNull);

      expect(ref.isNotNull, isTrue);
      expect(ref.isLoaded, isTrue);
      expect(ref.isEntitySet, isTrue);
      expect(ref.id, equals(1));
      expect(ref.idAsInt, equals(1));
      expect(ref.idNotNullAsInt, equals(1));
      expect(ref.idAs<String>(), isNull);
      expect(ref.currentValue, same(thing));
      expect(ref.entityOrID, same(thing));

      expect(ref.entityToJson(), equals({'id': 1, 'name': 'a'}));
      expect(ref.entityOrIdToJson(), equals({'id': 1, 'name': 'a'}));
      expect(
        ref.toJson(),
        equals({
          'EntityReference': '_Thing',
          'id': 1,
          'entity': {'id': 1, 'name': 'a'},
        }),
      );

      expect(ref.toString(), contains('EntityReference<_Thing>{id: 1}'));
      expect(ref.toString(), contains('<_Thing#1:a>'));
      expect(ref.toString(withT: false), startsWith('EntityReference<_Thing>'));

      expect(ref.hashCode, equals(1.hashCode));
      expect(ref.updateIdFromEntity(), isTrue);
      expect(ref.id, equals(1));

      expect(ref.equalsEntityID(1), isTrue);
      expect(ref.equalsEntityID(thing), isTrue);
      // No `EntityHandler` to compare another instance:
      expect(ref.equalsEntityID(_Thing(1, 'other')), isNull);
      expect(ref.equalsEntityID(3.5), isNull);

      ref.resolve();
      ref.disposeInternalHandlers();
      expect(ref.entity, same(thing));
      expect(ref.id, equals(1));
    });

    test('fromID: idAsInt, entityOrID and JSON', () {
      var ref = EntityReference<_Thing>.fromID(10);

      expect(ref.isIdSet, isTrue);
      expect(ref.isEntitySet, isFalse);
      expect(ref.isLoaded, isFalse);
      expect(ref.currentValue, equals(10));
      expect(ref.entityOrID, equals(10));
      expect(ref.entityOrIdToJson(), equals(10));
      expect(ref.updateIdFromEntity(), isFalse);
      expect(ref.toString(), endsWith('EntityReference<_Thing>{id: 10}'));

      // No `entityProvider` or `entityFetcher`:
      expect(ref.get(), isNull);
      expect(ref.refresh(), isNull);
      expect(() => ref.getNotNull(), throwsStateError);

      var refStr = EntityReference<_Thing>.fromID('abc');
      expect(refStr.idAsInt, isNull);
      expect(refStr.idAs<String>(), equals('abc'));
    });

    test('entity without ID', () {
      var thing = _Thing(null, 'no-id');

      var ref1 = EntityReference<_Thing>.fromEntity(thing);
      var ref2 = EntityReference<_Thing>.fromEntity(thing);

      expect(ref1.isEntitySet, isTrue);
      expect(ref1.isIdSet, isFalse);
      expect(
        ref1.toString(),
        endsWith('EntityReference<_Thing><_Thing#null:no-id>'),
      );

      expect(ref1 == ref2, isTrue);
      expect(ref1.hashCode, equals(thing.hashCode));

      // Entity set (without ID) vs ID:
      expect(ref1 == EntityReference<_Thing>.fromID(5), isFalse);

      // `ref1` has no ID but `other` has an entity without ID:
      var refID = EntityReference<_Thing>.fromID(7);
      expect(refID.equalsEntityID(ref1), isFalse);

      var refNoId2 = EntityReference<_Thing>.fromEntity(_Thing(null, 'x'));
      expect(ref1.equalsEntityID(refNoId2), isNull);

      expect(ref1.updateIdFromEntity(), isTrue);
      expect(ref1.id, isNull);
    });

    test('== and hashCode', () {
      var t1 = _Thing(1, 'a');

      var refNull = EntityReference<_Thing>.asNull();
      expect(refNull.hashCode, equals(0));
      expect(refNull == EntityReference<_Thing>.asNull(), isTrue);
      expect(refNull == EntityReference<_Thing>.fromID(1), isFalse);

      var refE = EntityReference<_Thing>.fromEntity(t1);
      var refE2 = EntityReference<_Thing>.fromEntity(t1);
      var refID = EntityReference<_Thing>.fromID(1);
      var refID2 = EntityReference<_Thing>.fromID(2);

      expect(refE == refE2, isTrue);
      expect(refE == refID, isTrue);
      expect(refID == refE, isTrue);
      expect(refID == refID2, isFalse);
      Object otherTypeRef = EntityReference<UserInfo>.fromID(1);
      expect(refE == otherTypeRef, isFalse);
      // ignore: unrelated_type_equality_checks
      expect(refE == 1, isFalse);
    });

    test('fromEntityMap/fromJson without EntityHandler', () {
      var ref = EntityReference<_Thing>.fromEntityMap({'id': 7, 'name': 'x'});
      expect(ref.isIdSet, isTrue);
      expect(ref.id, equals(7));
      expect(ref.isEntitySet, isFalse);

      var ref2 = EntityReference<_Thing>.fromJson({'id': 8, 'name': 'y'});
      expect(ref2.id, equals(8));
      expect(ref2.isEntitySet, isFalse);

      expect(
        () => EntityReference<_Thing>.fromEntityMap({
          'id': [1, 2],
        }),
        throwsArgumentError,
      );

      expect(
        () => EntityReference<_Thing>.fromID(Object()),
        throwsArgumentError,
      );
    });

    test('entityToJson: JsonEncoder and default without toJson', () {
      var thing = _Thing(2, 'b');
      var ref = EntityReference<_Thing>.fromEntity(thing);

      var json = ref.entityToJson(JsonEncoder());
      expect(json, isA<Map>());

      var refDyn = EntityReference<dynamic>.fromEntity(
        _NoIdNoJson(),
        type: _Thing,
      );
      expect(refDyn.type, equals(_Thing));
      expect(refDyn.id, isNull);
      expect(refDyn.entityToJson(), isNull);
    });

    test('invalid entity instance', () {
      expect(
        () => EntityReference<dynamic>.fromEntity([1, 2], type: _Thing),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Invalid entity instance'),
          ),
        ),
      );
    });

    test('EntityInstantiator', () {
      var thing = _Thing(3, 'inst');
      var instantiator = _FixedInstantiator(thing);

      var ref = EntityReference<_Thing>.fromEntityInstantiator(3, instantiator);

      expect(ref.hasEntityInstantiator, isTrue);
      expect(ref.hasEntity, isTrue);
      expect(ref.isEntitySet, isFalse);
      expect(ref.isLoaded, isTrue);
      expect(instantiator.calls, equals(0));

      expect(ref.entityOrIdToJson(), equals({'id': 3, 'name': 'inst'}));
      expect(instantiator.calls, equals(1));
      expect(ref.hasEntityInstantiator, isFalse);
      expect(ref.entity, same(thing));

      var refBad = EntityReference<_Thing>.fromEntityInstantiator(
        4,
        _FixedInstantiator(_Thing(5, 'wrong')),
      );

      expect(
        () => refBad.entity,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('different id'),
          ),
        ),
      );

      var ref3 = EntityReference<_Thing>.fromEntityInstantiator(
        3,
        _FixedInstantiator(thing),
      );
      var copy = ref3.copy();
      expect(copy.hasEntityInstantiator, isTrue);
      var copyNoEntity = ref3.copy(withEntity: false);
      expect(copyNoEntity.hasEntityInstantiator, isFalse);
      expect(copyNoEntity.id, equals(3));
    });

    test('entityFetcher', () async {
      var fetchedIDs = <Object?>[];

      var ref = EntityReference<_Thing>.fromID(
        11,
        entityFetcher: (id, type) {
          fetchedIDs.add(id);
          expect(type, equals(_Thing));
          return _Thing(id as int, 'fetched');
        },
      );

      expect(ref.isEntitySet, isFalse);

      var o = await ref.get();
      expect(o!.name, equals('fetched'));
      expect(fetchedIDs, equals([11]));
      expect(ref.isEntitySet, isTrue);

      var o2 = await ref.refresh();
      expect(o2!.id, equals(11));
      expect(fetchedIDs, equals([11, 11]));

      var refList = ref.toEntityReferenceList();
      expect(refList.ids, equals([11]));
      expect(refList.entities!.single!.id, equals(11));

      var l = await refList.refresh();
      expect(l!.single!.name, equals('fetched'));
      expect(fetchedIDs, equals([11, 11, 11]));

      ref.disposeInternalHandlers();
      expect(ref.entity!.id, equals(11));
    });

    test('entityProvider', () async {
      var provider = _ThingProvider({1: _Thing(1, 'one'), 2: _Thing(2, 'two')});

      var ref = EntityReference<_Thing>.fromID(1, entityProvider: provider);
      expect(ref.entityProvider, same(provider));
      expect(ref.isEntitySet, isTrue);
      expect(ref.entity!.name, equals('one'));

      ref.setID(2);
      expect(ref.isEntitySet, isFalse);
      var o = await ref.get();
      expect(o!.name, equals('two'));

      var asyncProvider = _ThingProvider({3: _Thing(3, 'three')}, async: true);

      var refAsync = EntityReference<_Thing>.fromID(
        3,
        entityProvider: asyncProvider,
      );
      expect(refAsync.isEntitySet, isFalse);
      var o3 = await refAsync.get();
      expect(o3!.name, equals('three'));
      expect(refAsync.isEntitySet, isTrue);

      expect(
        () => EntityReference<_Thing>.fromID(
          5,
          entityProvider: _AlwaysAsyncProvider(),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('returned a `Future`'),
          ),
        ),
      );

      var hp = _HandlerEntityProvider();
      var refHP = EntityReference<_Thing>.fromID(6, entityProvider: hp);
      expect(refHP.entityHandler, isNull);
      expect(refHP.entity, isNull);
      expect(refHP.id, equals(6));
    });

    test('generic type different from `type`', () {
      var ref = EntityReference<dynamic>.fromID(1, type: _Thing);
      expect(ref.type, equals(_Thing));
      expect(ref.typeName, equals('_Thing'));
      expect(ref.toString(), contains('<T:dynamic>'));
    });

    test('from', () {
      var t = _Thing(1, 'a');

      var r1 = EntityReference<_Thing>.from(t);
      expect(r1.entity, same(t));

      var r2 = EntityReference<_Thing>.from(r1);
      expect(identical(r2, r1), isTrue);

      var r3 = EntityReference<_Thing>.from({'id': 9, 'name': 'n'});
      expect(r3.id, equals(9));

      expect(
        () => EntityReference<UserInfo>.from(Store('s', 1)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains("Can't resolve `EntityReference`"),
          ),
        ),
      );
    });

    test('Null extensions', () {
      var nRef = _nullRef();
      expect(nRef.isNull, isTrue);
      expect(nRef.isNotNull, isFalse);
      expect(nRef.isLoaded, isFalse);
      expect(nRef.entity, isNull);
      expect(nRef.id, isNull);
      expect(nRef.entityOrID, isNull);
      expect(nRef.get(), isNull);
      expect(nRef.getNotNull(), isNull);

      var t = _Thing(1, 'a');
      var sRef = _someRef(EntityReference<_Thing>.fromEntity(t));
      expect(sRef.isNull, isFalse);
      expect(sRef.isNotNull, isTrue);
      expect(sRef.isLoaded, isTrue);
      expect(sRef.entity, same(t));
      expect(sRef.id, equals(1));
      expect(sRef.entityOrID, same(t));
      expect(sRef.get(), same(t));
      expect(sRef.getNotNull(), same(t));

      var nList = _nullRefList();
      expect(nList.isNull, isTrue);
      expect(nList.entities, isNull);
      expect(nList.entitiesNotNull, isNull);
      expect(nList.ids, isNull);
      expect(nList.entitiesOrIDs, isNull);
      expect(nList.get(), isNull);
      expect(nList.getNotNull(), isNull);

      var sList = _someRefList(EntityReferenceList<_Thing>.fromEntities([t]));
      expect(sList.isNotNull, isTrue);
      expect(sList.entities, equals([t]));
      expect(sList.entitiesNotNull, equals([t]));
      expect(sList.ids, equals([1]));
      expect(sList.entitiesOrIDs, equals([t]));
      expect(sList.get(), equals([t]));
      expect(sList.getNotNull(), equals([t]));
    });

    test('Iterable extensions', () {
      var t1 = _Thing(1, 'a');
      var t2 = _Thing(2, 'b');

      var refs = [
        EntityReference<_Thing>.fromEntity(t1),
        EntityReference<_Thing>.fromID(2),
      ];

      expect(refs.allIDs, equals([1, 2]));
      expect(refs.allIDsAs<int>(), equals([1, 2]));
      expect(refs.allIDsAsInt, equals([1, 2]));
      expect(refs.allEntities, equals([t1]));

      refs.resolve();
      refs.disposeInternalHandlers();
      expect(refs.allIDs, equals([1, 2]));

      var lists = [
        EntityReferenceList<_Thing>.fromEntities([t1, t2]),
        EntityReferenceList<_Thing>.fromIDs([3, null]),
      ];

      expect(lists.allIDs, equals([1, 2, 3]));
      expect(lists.allIDsAs<int>(), equals([1, 2, 3]));
      expect(lists.allIDsAsInt, equals([1, 2, 3]));
      expect(lists.allEntities, equals([t1, t2]));

      var listOfLists = [
        lists,
        [
          EntityReferenceList<_Thing>.fromIDs([4]),
        ],
      ];

      expect(listOfLists.allIDs, equals([1, 2, 3, 4]));
      expect(listOfLists.allIDsAs<int>(), equals([1, 2, 3, 4]));
      expect(listOfLists.allIDsAsInt, equals([1, 2, 3, 4]));
      expect(listOfLists.allEntities, equals([t1, t2]));
    });
  });

  group('EntityReference (with EntityHandler)', () {
    test('fromJson variants', () {
      expect(
        () => EntityReference<UserInfo>.fromJson({'EntityReference': 123}),
        throwsArgumentError,
      );

      var refNull = EntityReference<UserInfo>.fromJson({
        'EntityReference': 'UserInfo',
      });
      expect(refNull.isNull, isTrue);
      expect(refNull.toJson(), isNull);
      expect(refNull.entityOrIdToJson(), isNull);

      // Entity without `id` entry:
      var refEntity = EntityReference<UserInfo>.fromJson({
        'EntityReference': 'UserInfo',
        'entity': {'id': 21, 'info': 'e21'},
      });
      expect(refEntity.id, equals(21));
      expect(refEntity.entity!.info, equals('e21'));

      // Entity (non `Map<String,dynamic>`) without `id` entry:
      var refEntity2 = EntityReference<UserInfo>.fromJson({
        'EntityReference': 'UserInfo',
        'entity': <Object, Object>{'id': 22, 'info': 'e22'},
      });
      expect(refEntity2.id, equals(22));
      expect(refEntity2.entity!.info, equals('e22'));

      // Entity as a list of pairs:
      var refEntity3 = EntityReference<UserInfo>.fromJson({
        'EntityReference': 'UserInfo',
        'entity': [
          ['id', 23],
          ['info', 'e23'],
        ],
      });
      expect(refEntity3.id, equals(23));
      expect(refEntity3.entity!.info, equals('e23'));

      // Entity (non `Map<String,dynamic>`) with `id` entry (lazy instantiator):
      var refInst = EntityReference<UserInfo>.fromJson({
        'EntityReference': 'UserInfo',
        'id': 24,
        'entity': <Object, Object>{'id': 24, 'info': 'e24'},
      });
      expect(refInst.hasEntityInstantiator, isTrue);
      expect(refInst.entity!.info, equals('e24'));

      var refInst2 = EntityReference<UserInfo>.fromJson({
        'EntityReference': 'UserInfo',
        'id': 25,
        'entity': [
          ['id', 25],
          ['info', 'e25'],
        ],
      });
      expect(refInst2.hasEntityInstantiator, isTrue);
      expect(refInst2.entity!.info, equals('e25'));
    });

    test('EntityInstantiatorHandler', () {
      var entityCache = JsonEntityCacheSimple();

      var instantiator = EntityInstantiatorHandler<UserInfo>(
        userInfoEntityHandler,
        31,
        <Object, Object>{'id': 31, 'info': 'i31'},
        entityCache: entityCache,
      );

      expect(instantiator.entityMap, equals({'id': 31, 'info': 'i31'}));

      var o1 = instantiator.instantiate();
      var o2 = instantiator.instantiate();
      expect(o1.info, equals('i31'));
      expect(identical(o1, o2), isTrue);

      expect(
        EntityInstantiatorHandler.resolveEntityMap({'a': 1}),
        equals({'a': 1}),
      );
      expect(
        EntityInstantiatorHandler.resolveEntityMap(<Object, int>{'b': 2}),
        equals({'b': 2}),
      );
      expect(
        EntityInstantiatorHandler.resolveEntityMap([
          ['c', 3],
        ]),
        equals({'c': 3}),
      );
    });

    test('equalsEntityID with EntityHandler', () {
      var ref = EntityReference<UserInfo>.fromID(41);
      expect(ref.equalsEntityID(UserInfo('x', id: 41)), isTrue);
      expect(ref.equalsEntityID(UserInfo('x', id: 42)), isFalse);
      expect(ref.equalsEntityID(EntityReference<Store>.fromID(41)), isFalse);
    });
  });

  group('EntityReferenceList (no EntityHandler)', () {
    test('fromEntities: basic', () {
      var t1 = _Thing(1, 'a');
      var t2 = _Thing(2, 'b');

      var l = EntityReferenceList<_Thing>.fromEntities([t1, t2]);

      expect(l.typeName, equals('_Thing'));
      expect(l.length, equals(2));
      expect(l.isNotEmpty, isTrue);
      expect(l.isNotEmptyOrNull, isTrue);
      expect(l.isEmpty, isFalse);
      expect(l.isLoaded, isTrue);
      expect(l.ids, equals([1, 2]));
      expect(l.idsAsInt, equals([1, 2]));
      expect(l.idsNotNullAsInt, equals([1, 2]));
      expect(l.idsAs<String>(), equals([null, null]));
      expect(l.idsNotNullAs<int>(), equals([1, 2]));
      expect(l.idsNotNull, equals([1, 2]));
      expect(l.entitiesNotNull, equals([t1, t2]));
      expect(l.currentValue, equals([t1, t2]));

      expect(
        l.entitiesToJson(),
        equals([
          {'id': 1, 'name': 'a'},
          {'id': 2, 'name': 'b'},
        ]),
      );
      expect(l.entitiesToJson(JsonEncoder()), hasLength(2));
      expect(
        l.entitiesOrIDsToJson(),
        equals([
          {'id': 1, 'name': 'a'},
          {'id': 2, 'name': 'b'},
        ]),
      );

      expect(
        l.toString(),
        endsWith(
          'EntityReferenceList<_Thing>{ids: [1, 2]}[<_Thing#1:a>, <_Thing#2:b>]',
        ),
      );

      expect(l.getAt(1), same(t2));
      expect(l.getAt(5), isNull);

      l.resolve();
      l.disposeInternalHandlers();
      expect(l.entities, equals([t1, t2]));

      // Copies:
      var cp = l.copy();
      expect(cp.entities, equals([t1, t2]));
      var cpNoEntities = l.copy(withEntity: false);
      expect(cpNoEntities.isEntitiesSet, isFalse);
      expect(cpNoEntities.ids, equals([1, 2]));
    });

    test('fromIDs: basic', () {
      var l = EntityReferenceList<_Thing>.fromIDs([1, 2]);

      expect(l.isIDsSet, isTrue);
      expect(l.isEntitiesSet, isFalse);
      expect(l.isLoaded, isFalse);
      expect(l.currentValue, equals([1, 2]));
      expect(l.entitiesOrIDsToJson(), equals([1, 2]));
      expect(l.entitiesToJson(), isNull);
      expect(
        l.toString(),
        endsWith('EntityReferenceList<_Thing>{ids: [1, 2]}'),
      );

      // No `entityProvider`/`entitiesFetcher`:
      expect(l.getAt(0), isNull);
      expect(l.fetchImpl(), isNull);

      var empty = EntityReferenceList<_Thing>.asEmpty();
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);
      expect(empty.isNotEmptyOrNull, isFalse);
      expect(empty.getAt(0), isNull);

      var asNull = EntityReferenceList<_Thing>.asNull();
      expect(asNull.length, isNull);
      expect(asNull.isNotEmpty, isFalse);
      expect(asNull.isNotEmptyOrNull, isTrue);
      expect(asNull.idsAsInt, isEmpty);
      expect(asNull.idsNotNullAsInt, isEmpty);
      expect(asNull.entitiesNotNull, isEmpty);
      expect(asNull.entitiesOrIDsToJson(), isNull);
      expect(asNull.toString(), endsWith('EntityReferenceList<_Thing>{null}'));
      expect(asNull.hashCode, equals(0));
    });

    test('fromEntitiesMaps / fromJson / from', () {
      var l = EntityReferenceList<_Thing>.fromEntitiesMaps([
        {'id': 1, 'name': 'a'},
        null,
        {'id': 3, 'name': 'c'},
      ]);
      expect(l.ids, equals([1, null, 3]));
      expect(l.isEntitiesSet, isFalse);

      expect(
        () => EntityReferenceList<_Thing>.fromIDs([Object()]),
        throwsArgumentError,
      );

      expect(
        () =>
            EntityReferenceList<UserInfo>.fromJson({'EntityReferenceList': 1}),
        throwsArgumentError,
      );

      var l2 = EntityReferenceList<_Thing>.fromJson({'id': 5, 'name': 'e'});
      expect(l2.ids, equals([5]));

      expect(
        () => EntityReferenceList<UserInfo>.from('not-a-list'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not compatible types'),
          ),
        ),
      );

      var t = _Thing(9, 'single');
      var l3 = EntityReferenceList<_Thing>.from(t);
      expect(l3.entities, equals([t]));
      expect(l3.ids, equals([9]));
    });

    test('invalid entities and casts', () {
      expect(
        () => EntityReferenceList<dynamic>.fromEntities([
          {'a': 1},
        ], type: _Thing),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('at index `0`'),
          ),
        ),
      );

      var t = _Thing(1, 'a');

      var lDyn = EntityReferenceList<dynamic>.fromEntities([
        t,
        null,
      ], type: _Thing);
      var lCast = lDyn.cast<_Thing>();
      expect(lCast, isA<EntityReferenceList<_Thing>>());
      expect(lCast.entities, equals([t, null]));

      var lDyn2 = EntityReferenceList<dynamic>.fromEntities([
        t,
        'str',
      ], type: _Thing);
      expect(
        () => lDyn2.cast<_Thing>(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains("Can't cast"),
          ),
        ),
      );

      expect(
        () => EntityReferenceList<_Thing>.fromIDs([
          1,
        ], entityProvider: _AlwaysAsyncProvider()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('returned a `Future`'),
          ),
        ),
      );
    });

    test('entityProvider and entitiesOrIDs', () async {
      var t1 = _Thing(1, 'one');
      var provider = _ThingProvider({1: t1});

      var l = EntityReferenceList<_Thing>.fromIDs([
        1,
        2,
      ], entityProvider: provider);

      expect(l.entities, equals([t1, null]));
      expect(l.entitiesOrIDs, equals([t1, 2]));

      var asyncProvider = _ThingProvider({
        1: _Thing(1, 'a1'),
        2: _Thing(2, 'a2'),
      }, async: true);

      var lAsync = EntityReferenceList<_Thing>.fromIDs([
        1,
        2,
      ], entityProvider: asyncProvider);

      expect(lAsync.isEntitiesSet, isFalse);

      var o = await lAsync.getAt(1);
      expect(o!.name, equals('a2'));

      var all = await lAsync.get();
      expect(all!.map((e) => e!.name), equals(['a1', 'a2']));
      expect(lAsync.isEntitiesSet, isTrue);
    });

    test('entitiesFetcher', () async {
      var calls = <List<Object?>>[];

      var l = EntityReferenceList<_Thing>.fromIDs(
        [1, 2],
        entitiesFetcher: (ids, type) {
          calls.add(ids);
          return ids.map((id) => _Thing(id as int, 'f$id')).toList();
        },
      );

      var r = await l.get();
      expect(r!.map((e) => e!.name), equals(['f1', 'f2']));
      expect(
        calls,
        equals([
          [1, 2],
        ]),
      );

      l.disposeInternalHandlers();
      expect(l.entities!.length, equals(2));

      var single = EntityReferenceList<_Thing>.fromIDs(
        [7],
        entitiesFetcher: (ids, type) =>
            ids.map((id) => _Thing(id as int, 'g$id')).toList(),
      );

      var ref = single.toEntityReference();
      expect(ref.id, equals(7));
      expect(ref.isEntitySet, isFalse);

      var o = await ref.get();
      expect(o!.name, equals('g7'));

      // `getAt` fetches only the ID at `index`:
      var atCalls = <List<Object?>>[];
      var lAt = EntityReferenceList<_Thing>.fromIDs(
        [1, 2],
        entitiesFetcher: (ids, type) {
          atCalls.add(ids);
          return ids.map((id) => _Thing(id as int, 'h$id')).toList();
        },
      );

      var e2 = await lAt.getAt(1);
      expect(e2!.name, equals('h2'));
      expect(
        atCalls,
        equals([
          [2],
        ]),
      );
    });

    test('add / addAll / remove / removeByID', () {
      var t1 = _Thing(1, 'a');
      var t2 = _Thing(2, 'b');
      var t3 = _Thing(3, 'c');

      var l = EntityReferenceList<_Thing>.fromEntities([t1]);
      l.addAll([t2, t3]);
      expect(l.ids, equals([1, 2, 3]));
      expect(l.entities, equals([t1, t2, t3]));

      expect(l.remove(null), isFalse);
      expect(l.remove(t2), isTrue);
      expect(l.ids, equals([1, 3]));
      expect(l.remove(_Thing(99, 'x')), isFalse);

      expect(l.removeByID(null), isFalse);
      expect(l.removeByID(3), isTrue);
      expect(l.ids, equals([1]));
      expect(l.entities, equals([t1]));
      expect(l.removeByID(404), isFalse);

      var lIDs = EntityReferenceList<_Thing>.fromIDs([10]);
      lIDs.add(_Thing(11, 'k'));
      expect(lIDs.ids, equals([10, 11]));
      expect(lIDs.entities!.length, equals(2));
      expect(lIDs.entities![0], isNull);
      expect(lIDs.entities![1]!.name, equals('k'));

      var lIDs2 = EntityReferenceList<_Thing>.fromIDs([20, 21]);
      expect(lIDs2.remove(_Thing(21, 'x')), isTrue);
      expect(lIDs2.ids, equals([20]));
      expect(lIDs2.remove(_Thing(null, 'no-id')), isFalse);
      expect(lIDs2.removeByID(20), isTrue);
      expect(lIDs2.ids, isEmpty);

      var lNull = EntityReferenceList<_Thing>.asNull();
      expect(lNull.remove(t1), isFalse);
      expect(lNull.removeByID(1), isFalse);
      lNull.add(t1);
      expect(lNull.entities, equals([t1]));

      // `set(null)` resets:
      expect(l.set(null), isNull);
      expect(l.isNull, isTrue);
      expect(l.entitiesTime, isNull);
    });

    test('equalsEntitiesIDs', () {
      var t1 = _Thing(1, 'a');
      var t2 = _Thing(2, 'b');

      var l = EntityReferenceList<_Thing>.fromEntities([t1]);
      var lIDs = EntityReferenceList<_Thing>.fromIDs([1]);
      var lNull = EntityReferenceList<_Thing>.asNull();

      // With `EntityReference`:
      expect(l.equalsEntitiesIDs(EntityReference<UserInfo>.fromID(1)), isFalse);
      expect(l.equalsEntitiesIDs(EntityReference<_Thing>.asNull()), isFalse);
      expect(lNull.equalsEntitiesIDs(EntityReference<_Thing>.asNull()), isTrue);
      expect(
        l.equalsEntitiesIDs(EntityReference<_Thing>.fromEntity(t1)),
        isTrue,
      );
      expect(lIDs.equalsEntitiesIDs(EntityReference<_Thing>.fromID(1)), isTrue);
      expect(
        lIDs.equalsEntitiesIDs(EntityReference<_Thing>.fromID(2)),
        isFalse,
      );
      expect(
        lIDs.equalsEntitiesIDs(
          EntityReference<_Thing>.fromEntity(_Thing(null, 'no-id')),
        ),
        isFalse,
      );

      // With `EntityReferenceList`:
      expect(
        l.equalsEntitiesIDs(EntityReferenceList<UserInfo>.fromIDs([1])),
        isFalse,
      );
      expect(
        l.equalsEntitiesIDs(
          EntityReferenceList<_Thing>.fromEntities([_Thing(null, 'x')]),
        ),
        isFalse,
      );

      // With `T`:
      expect(l.equalsEntitiesIDs(t1), isTrue);
      expect(l.equalsEntitiesIDs(t2), isNull);

      // With `List<T>`:
      expect(l.equalsEntitiesIDs([t1]), isTrue);
      expect(l.equalsEntitiesIDs([t2]), isNull);

      // With a list of IDs:
      expect(l.equalsEntitiesIDs([1]), isTrue);
      expect(l.equalsEntitiesIDs([2]), isFalse);

      // Others:
      expect(l.equalsEntitiesIDs('x'), isNull);
    });

    test('toString / toEntityReference', () {
      var t1 = _Thing(1, 'a');

      var lNoIDs = EntityReferenceList<_Thing>.fromEntities([
        _Thing(null, 'x'),
      ]);
      expect(lNoIDs.toString(), contains('{ids: [null]}'));

      var l2 = EntityReferenceList<_Thing>.fromEntities([t1, _Thing(2, 'b')]);
      expect(
        () => l2.toEntityReference(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('length (2)'),
          ),
        ),
      );

      var ref1 = EntityReferenceList<_Thing>.fromEntities([
        t1,
      ]).toEntityReference();
      expect(ref1.entity, same(t1));
      expect(ref1.id, equals(1));

      var refEmpty = EntityReferenceList<_Thing>.asEmpty().toEntityReference();
      expect(refEmpty.isNull, isTrue);

      var refEmpty2 = EntityReferenceList<_Thing>.fromEntities(
        [],
      ).toEntityReference();
      expect(refEmpty2.isNull, isTrue);
    });

    test('== and hashCode', () {
      var t1 = _Thing(1, 'a');

      var lNull = EntityReferenceList<_Thing>.asNull();
      var lE = EntityReferenceList<_Thing>.fromEntities([t1]);
      var lE2 = EntityReferenceList<_Thing>.fromEntities([t1]);
      var lIDs = EntityReferenceList<_Thing>.fromIDs([1]);
      var lIDs2 = EntityReferenceList<_Thing>.fromIDs([2]);

      expect(lNull == EntityReferenceList<_Thing>.asNull(), isTrue);
      expect(lNull == lE, isFalse);
      expect(lE == lE2, isTrue);
      expect(lE == lIDs, isTrue);
      expect(lIDs == lE, isTrue);
      expect(lIDs == lIDs2, isFalse);
      Object otherTypeList = EntityReferenceList<UserInfo>.fromIDs([1]);
      expect(lE == otherTypeList, isFalse);

      expect(lE.hashCode, equals(lE2.hashCode));
      expect(lIDs.hashCode, equals(lE.hashCode));

      var lNoID1 = EntityReferenceList<_Thing>.fromEntities([
        _Thing(null, 'x'),
      ]);
      expect(lNoID1.hashCode, isA<int>());
      expect(lNoID1 == lE, isFalse);
    });
  });

  group('EntityReferenceList (with EntityHandler)', () {
    test('fromJson variants', () {
      var l = EntityReferenceList<UserInfo>.fromJson({
        'EntityReferenceList': 'UserInfo',
        'entities': <Object>[
          <Object, Object>{'id': 1, 'info': 'a'},
          [
            ['id', 2],
            ['info', 'b'],
          ],
        ],
      });

      expect(l.ids, equals([1, 2]));
      expect(l.entities!.map((e) => e!.info), equals(['a', 'b']));

      var lRef = EntityReferenceList<UserInfo>.fromJson({
        'EntityReference': 'UserInfo',
        'id': 3,
        'entity': {'id': 3, 'info': 'c'},
      });
      expect(lRef.ids, equals([3]));
      expect(lRef.entities!.single!.info, equals('c'));

      var lRefNull = EntityReferenceList<UserInfo>.fromJson({
        'EntityReference': 'UserInfo',
      });
      expect(lRefNull.isNull, isTrue);
    });

    test('equalsEntitiesIDs with EntityHandler', () {
      var l = EntityReferenceList<UserInfo>.fromIDs([1, 2]);
      expect(
        l.equalsEntitiesIDs([UserInfo('a', id: 1), UserInfo('b', id: 2)]),
        isTrue,
      );
      expect(l.equalsEntitiesIDs([UserInfo('a', id: 1)]), isFalse);

      var l1 = EntityReferenceList<UserInfo>.fromIDs([5]);
      expect(l1.equalsEntitiesIDs(UserInfo('x', id: 5)), isTrue);
    });

    test('toJson with JsonEncoder', () {
      var l = EntityReferenceList<UserInfo>.fromEntities([
        UserInfo('a', id: 1),
        null,
      ]);
      var j = l.toJson(JsonEncoder());
      expect(j!['EntityReferenceList'], equals('UserInfo'));
      expect(j['ids'], equals([1, null]));
      expect((j['entities'] as List).length, equals(2));
    });
  });
}

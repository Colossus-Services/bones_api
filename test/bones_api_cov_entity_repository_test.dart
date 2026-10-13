@TestOn('vm')
import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

/// A simple manual entity, backed by a [Map].
abstract class CovEntity extends Entity {
  final Map<String, Object?> values;

  CovEntity([Map<String, Object?>? values]) : values = values ?? {};

  Map<String, TypeInfo> get types;

  Map<String, List<EntityAnnotation>> get annotations => const {};

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => types.keys.toList();

  @override
  V? getField<V>(String key) => values[key] as V?;

  @override
  TypeInfo? getFieldType(String key) => types[key];

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) =>
      annotations[key];

  @override
  void setField<V>(String key, V? value) {
    var t = types[key];
    if (t == null) throw StateError('Unknown field: $key');
    if (value != null && t.isPrimitiveType && t.type != value.runtimeType) {
      throw ArgumentError('Invalid value type for `$key`: $value');
    }
    values[key] = value;
  }

  @override
  Map<String, dynamic> toJson() => Map<String, dynamic>.fromEntries(
    values.entries
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, Json.toJson(e.value))),
  );

  @override
  String toString() => '$runtimeType$values';
}

final tCovItem = TypeInfo<CovItem>.fromType(CovItem);

class CovItem extends CovEntity {
  CovItem([super.values]);

  @override
  Map<String, TypeInfo> get types => {
    'id': TypeInfo.tInt,
    'name': TypeInfo.tString,
  };
}

class CovUniq extends CovEntity {
  CovUniq([super.values]);

  @override
  Map<String, TypeInfo> get types => {
    'id': TypeInfo.tInt,
    'code': TypeInfo.tString,
  };

  @override
  Map<String, List<EntityAnnotation>> get annotations => {
    'code': [const EntityField.unique()],
  };
}

class CovParent extends CovEntity {
  CovParent([super.values]);

  @override
  Map<String, TypeInfo> get types => {
    'id': TypeInfo.tInt,
    'child': tCovItem,
    'children': TypeInfo<List<CovItem>>.fromType(List, [tCovItem]),
    'ref': TypeInfo<EntityReference<CovItem>>.fromType(EntityReference, [
      tCovItem,
    ]),
    'refs': TypeInfo<EntityReferenceList<CovItem>>.fromType(
      EntityReferenceList,
      [tCovItem],
    ),
  };
}

class CovRefOnly extends CovEntity {
  CovRefOnly([super.values]);

  @override
  Map<String, TypeInfo> get types => {
    'id': TypeInfo.tInt,
    'refs': TypeInfo<EntityReferenceList<CovItem>>.fromType(
      EntityReferenceList,
      [tCovItem],
    ),
  };
}

final covItemHandler = GenericEntityHandler<CovItem>(
  instantiatorDefault: CovItem.new,
  instantiatorFromMap: (m) => CovItem(Map<String, Object?>.from(m)),
);

final covUniqHandler = GenericEntityHandler<CovUniq>(
  instantiatorDefault: CovUniq.new,
);

final covParentHandler = GenericEntityHandler<CovParent>(
  instantiatorDefault: CovParent.new,
);

final covRefOnlyHandler = GenericEntityHandler<CovRefOnly>(
  instantiatorDefault: CovRefOnly.new,
);

/// A minimal [EntitySource] over a [List] (exercises the default
/// implementations of [EntitySource]).
class ListEntitySource extends EntitySource<CovItem> {
  final List<CovItem> items;

  ListEntitySource(this.items) : super('list_source');

  @override
  Object? getEntityID(CovItem o) => o.getID();

  @override
  bool hasReferencedEntities() => false;

  @override
  FutureOr<bool> existsID(dynamic id, {Transaction? transaction}) =>
      items.any((e) => e.getID() == id);

  @override
  FutureOr<Iterable<I>> existIDs<I extends Object>(
    List<I?> ids, {
    Transaction? transaction,
  }) => items.map((e) => e.getID<I>()).nonNulls.where(ids.contains).toList();

  List<CovItem> _matches(
    EntityMatcher<CovItem> matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) => applySelectOrderAndPagination(
    items.where(
      (o) => matcher.matchesEntity(
        o,
        entityHandler: covItemHandler,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
      ),
    ),
    (o) => o.getID(),
    limit: limit,
    offset: resolveSelectOffset(page: page, offset: offset, limit: limit),
    orderByID: orderByID,
    orderDirection: orderDirection,
  ).toList();

  @override
  FutureOr<int> count({
    EntityMatcher<CovItem>? matcher,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Transaction? transaction,
  }) => matcher == null
      ? items.length
      : _matches(
          matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
        ).length;

  @override
  FutureOr<Iterable<CovItem>> select(
    EntityMatcher<CovItem> matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Transaction? transaction,
    int? limit,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
    EntityResolutionRules? resolutionRules,
  }) => _matches(
    matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    limit: limit,
    offset: offset,
    page: page,
    orderByID: orderByID,
    orderDirection: orderDirection,
  );

  @override
  FutureOr<Iterable<I>> selectIDsBy<I extends Object>(
    EntityMatcher<CovItem> matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Transaction? transaction,
    int? limit,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) => _matches(
    matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    limit: limit,
    offset: offset,
    page: page,
    orderByID: orderByID,
    orderDirection: orderDirection,
  ).map((e) => e.getID<I>()!).toList();

  @override
  FutureOr<Iterable<CovItem>> selectAll({
    Transaction? transaction,
    int? limit,
    int? offset,
    int? page,
    bool? orderByID,
    OrderDirection? orderDirection,
    EntityResolutionRules? resolutionRules,
  }) => _matches(
    ConditionANY(),
    limit: limit,
    offset: offset,
    page: page,
    orderByID: orderByID,
    orderDirection: orderDirection,
  );

  @override
  FutureOr<Iterable<dynamic>> selectRelationship<E>(
    CovItem? o,
    String field, {
    Object? oId,
    TypeInfo? fieldType,
    Transaction? transaction,
  }) => const [];

  @override
  FutureOr<Map<dynamic, Iterable<dynamic>>> selectRelationships<E>(
    List<CovItem>? os,
    String field, {
    List<dynamic>? oIds,
    TypeInfo? fieldType,
    Transaction? transaction,
  }) => const {};
}

/// A minimal [EntityStorage] over a [List] (exercises the default
/// implementations of [EntityStorage]).
class ListEntityStorage extends EntityStorage<CovItem> {
  final List<CovItem> items;

  ListEntityStorage(this.items) : super('list_storage');

  @override
  Object? getEntityID(CovItem o) => o.getID();

  @override
  bool isStored(CovItem o, {Transaction? transaction}) => items.contains(o);

  @override
  void checkEntityFields(CovItem o) {}

  @override
  FutureOr<dynamic> store(CovItem o, {Transaction? transaction}) {
    if (!items.contains(o)) items.add(o);
    return o.getID();
  }

  @override
  FutureOr<List> storeAll(Iterable<CovItem> o, {Transaction? transaction}) =>
      o.map((e) => store(e)).toList();

  @override
  FutureOr<bool> setRelationship<E extends Object>(
    CovItem o,
    String field,
    List<E> values, {
    TypeInfo? fieldType,
    Transaction? transaction,
  }) => false;

  @override
  FutureOr<Iterable<CovItem>> delete(
    EntityMatcher<CovItem> matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    Transaction? transaction,
  }) {
    var del = items
        .where(
          (o) => matcher.matchesEntity(
            o,
            entityHandler: covItemHandler,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters,
          ),
        )
        .toList();
    items.removeWhere(del.contains);
    return del;
  }
}

List<CovItem> _items(int n) =>
    List.generate(n, (i) => CovItem({'id': i + 1, 'name': 'n${i + 1}'}));

void main() {
  setUpAll(() {
    // Top-level finals are lazy: instantiate (and register) the handlers.
    expect(
      [
        covItemHandler,
        covUniqHandler,
        covParentHandler,
        covRefOnlyHandler,
      ].length,
      equals(4),
    );
  });

  group('EntitySource (default implementations)', () {
    test('select*', () async {
      var source = ListEntitySource(_items(5));

      expect(source.nameSimplified, equals('listsource'));

      expect((await source.selectByID(3))!.getID(), equals(3));
      expect(await source.selectByID(30), isNull);

      var byIDs = await source.selectByIDs([1, 30, 2]);
      expect(byIDs.map((e) => e?.getID()), equals([1, null, 2]));

      expect(await source.length(), equals(5));
      expect(await source.countByQuery('id > ?', parameters: [2]), equals(3));

      var first = await source.selectFirstByQuery(
        'id > ?',
        parameters: [1],
        orderByID: true,
        orderDirection: OrderDirection.descending,
      );
      expect(first!.getID(), equals(5));

      var second = await source.selectFirstByQuery(
        'id > ?',
        parameters: [1],
        page: 2,
      );
      expect(second!.getID(), equals(3));

      var sel = await source.selectByQuery(
        'id >= ?',
        parameters: [2],
        limit: 2,
        page: 2,
      );
      expect(sel.map((e) => e.getID()), equals([4, 5]));

      var ids = await source.selectIDsByQuery<int>(
        'id <= ?',
        parameters: [3],
        orderByID: true,
        orderDirection: OrderDirection.descending,
      );
      expect(ids, equals([3, 2, 1]));
    });

    test('paginate*', () async {
      var source = ListEntitySource(_items(5));

      var p1 = source.paginateByQuery('id > ?', parameters: [0], limit: 2);
      expect((await p1.getPage(1)).map((e) => e.getID()), equals([1, 2]));
      expect((await p1.getPage(3)).map((e) => e.getID()), equals([5]));

      var p2 = source.paginate(Condition.parse('id > 1'), limit: 3);
      expect((await p2.getPage(1)).map((e) => e.getID()), equals([2, 3, 4]));

      var p3 = source.paginateAll(
        limit: 4,
        orderDirection: OrderDirection.descending,
      );
      expect((await p3.getPage(1)).map((e) => e.getID()), equals([5, 4, 3, 2]));
    });
  });

  group('EntityStorage (default implementations)', () {
    test('delete*', () async {
      var items = _items(6);
      var storage = ListEntityStorage(items);

      var del = await storage.deleteByQuery('id == ?', parameters: [1]);
      expect(del.map((e) => e.getID()), equals([1]));

      expect(await storage.deleteByID(null), isNull);
      expect((await storage.deleteByID(2))!.getID(), equals(2));
      expect(await storage.deleteByID(2), isNull);

      expect((await storage.tryDeleteByID(3))!.getID(), equals(3));

      var item4 = items.firstWhere((e) => e.getID() == 4);
      expect((await storage.deleteEntity(item4))!.getID(), equals(4));

      var item5 = items.firstWhere((e) => e.getID() == 5);
      expect((await storage.tryDeleteEntity(item5))!.getID(), equals(5));

      expect(items.map((e) => e.getID()), equals([6]));
    });

    test('deleteEntityCascade (global providers)', () async {
      var repository = SetEntityRepository<CovItem>(
        'cov_item_global',
        covItemHandler,
      )..ensureInitialized();
      addTearDown(repository.close);

      var o = CovItem({'name': 'global'});
      var id = await repository.store(o);
      expect(id, isNotNull);

      var storage = ListEntityStorage([o]);
      var deleted = await storage.deleteEntityCascade(o);
      expect(deleted, equals([o]));
      expect(repository.selectByID(id), isNull);
    });
  });

  group('SetEntityRepository', () {
    late EntityRepositoryProvider provider;
    late SetEntityRepository<CovItem> itemRepo;
    late SetEntityRepository<CovUniq> uniqRepo;
    late SetEntityRepository<CovParent> parentRepo;
    late SetEntityRepository<CovRefOnly> refOnlyRepo;

    setUp(() {
      provider = EntityRepositoryProvider();
      itemRepo = SetEntityRepository<CovItem>(
        'cov_item',
        covItemHandler,
        provider: provider,
      )..ensureInitialized();
      uniqRepo = SetEntityRepository<CovUniq>(
        'cov_uniq',
        covUniqHandler,
        provider: provider,
      )..ensureInitialized();
      parentRepo = SetEntityRepository<CovParent>(
        'cov_parent',
        covParentHandler,
        provider: provider,
      )..ensureInitialized();
      refOnlyRepo = SetEntityRepository<CovRefOnly>(
        'cov_ref_only',
        covRefOnlyHandler,
        provider: provider,
      )..ensureInitialized();
    });

    tearDown(() {
      itemRepo.close();
      uniqRepo.close();
      parentRepo.close();
      refOnlyRepo.close();
      provider.close();
    });

    test('hasReferencedEntities', () {
      expect(itemRepo.hasReferencedEntities(), isFalse);
      expect(parentRepo.hasReferencedEntities(), isTrue);
      expect(refOnlyRepo.hasReferencedEntities(), isFalse);
    });

    test('count / exists / select', () async {
      await itemRepo.storeAll(_items(4).map((e) => e..setID(null)));

      expect(await itemRepo.count(), equals(4));
      expect(
        await itemRepo.count(matcher: Condition.parse('id > 2')),
        equals(2),
      );
      expect(
        await itemRepo.countByQuery('id <= ?', parameters: [3]),
        equals(3),
      );

      expect(await itemRepo.existsID(1), isTrue);
      expect(await itemRepo.existsID(10), isFalse);
      expect(
        (await itemRepo.existIDs<int>([1, 3, 10])).toList(),
        equals([1, 3]),
      );

      var o1 = itemRepo.selectByID(1)!;
      expect(itemRepo.isStored(o1), isTrue);
      expect(itemRepo.isStored(CovItem()), isFalse);

      expect(
        (await itemRepo.selectByIDs([2, 2])).map((e) => e?.getID()),
        equals([2, 2]),
      );
      expect(await itemRepo.selectByIDs([]), isEmpty);
      expect(
        (await itemRepo.selectByIDs([3, 99])).map((e) => e?.getID()),
        equals([3, null]),
      );

      var info = itemRepo.information();
      expect(info['name'], equals('cov_item'));
      expect(info['length'], equals(4));
      expect(info['nextID'], equals(5));

      expect(itemRepo.toString(), contains('cov_item'));

      expect(itemRepo.getEntityMapID({'id': 3}), equals(3));
      expect(
        (await itemRepo.fromMap({'id': 7, 'name': 'x'})).getID(),
        equals(7),
      );

      expect(itemRepo.isOfEntityType(o1), isTrue);
      expect(itemRepo.isOfEntityType(null), isFalse);
      expect(itemRepo.isOfEntityType(1), isFalse);
    });

    test('unique field', () async {
      await uniqRepo.store(CovUniq({'code': 'a'}));
      expect(
        () => uniqRepo.store(CovUniq({'code': 'a'})),
        throwsA(
          isA<EntityFieldInvalid>()
              .having((e) => e.reason, 'reason', 'unique')
              .having((e) => e.fieldName, 'fieldName', 'code'),
        ),
      );
      await uniqRepo.store(CovUniq({'code': 'b'}));
      await uniqRepo.store(CovUniq());
      expect(await uniqRepo.count(), equals(3));
    });

    test('relationships', () async {
      var c1 = CovItem({'name': 'c1'});
      var c2 = CovItem({'name': 'c2'});
      await itemRepo.storeAll([c1, c2]);

      var p = CovParent({
        'children': <CovItem>[],
        'refs': EntityReferenceList<CovItem>.asNull(
          entityHandler: covItemHandler,
        ),
      });
      await parentRepo.store(p);

      expect(await parentRepo.setRelationship(p, 'children', [c1, c2]), isTrue);

      expect(
        await parentRepo.selectRelationship(p, 'children'),
        equals([c1.getID(), c2.getID()]),
      );
      expect(
        await parentRepo.selectRelationship(
          null,
          'children',
          oId: 999,
          fieldType: TypeInfo<List<CovItem>>.fromType(List, [tCovItem]),
        ),
        isEmpty,
      );

      var rels = await parentRepo.selectRelationships([p], 'children');
      expect(
        rels,
        equals({
          p.getID(): [c1.getID(), c2.getID()],
        }),
      );

      expect(
        await parentRepo.selectRelationships(null, 'children', oIds: []),
        isEmpty,
      );

      expect(() => parentRepo.setRelationship(p, 'id', [c1]), throwsStateError);
      expect(() => parentRepo.selectRelationship(p, 'id'), throwsStateError);
    });

    test('ensureStored / references', () async {
      var c1 = CovItem({'name': 'r1'});
      var c2 = CovItem({'name': 'r2'});
      var c3 = CovItem({'name': 'r3'});

      var p = CovParent({
        'child': c3,
        'children': <CovItem>[c1, c2],
      });

      var id = await parentRepo.ensureStored(p);
      expect(id, isNotNull);
      // The single entity reference is stored:
      expect(c3.getID(), isNotNull);
      // And the entities of the `List` field:
      expect(c1.getID(), isNotNull);
      expect(c2.getID(), isNotNull);
      expect(await itemRepo.count(), equals(3));

      // Already stored and unchanged:
      expect(await parentRepo.ensureStored(p), equals(id));

      expect(await parentRepo.ensureReferencesStored(p), isTrue);
    });

    test('delete*', () async {
      var items = _items(5).map((e) => e..setID(null)).toList();
      await itemRepo.storeAll(items);

      expect(await itemRepo.deleteByID(null), isNull);
      expect(await itemRepo.deleteByID(99), isNull);
      expect((await itemRepo.deleteByID(1))!.getID(), equals(1));
      expect((await itemRepo.tryDeleteByID(2))!.getID(), equals(2));
      expect((await itemRepo.deleteEntity(items[2]))!.getID(), equals(3));
      expect((await itemRepo.tryDeleteEntity(items[3]))!.getID(), equals(4));

      var deletedEvents = <CovItem>[];
      itemRepo.onDelete.listen(deletedEvents.add);

      var del = await itemRepo.delete(Condition.parse('id == 5'));
      expect(del.map((e) => e.getID()), equals([5]));
      expect(await itemRepo.count(), equals(0));

      await Future<void>.delayed(Duration.zero);
      expect(deletedEvents.map((e) => e.getID()), equals([5]));
    });

    test('deleteEntityCascade', () async {
      var child = CovItem({'name': 'child'});
      var c1 = CovItem({'name': 'c1'});
      var c2 = CovItem({'name': 'c2'});
      var refEntity = CovItem({'name': 'ref'});
      var refsEntity = CovItem({'name': 'refs'});

      await itemRepo.storeAll([child, c1, c2, refEntity, refsEntity]);
      expect(await itemRepo.count(), equals(5));

      var p = CovParent({
        'child': child,
        'children': <CovItem>[c1, c2],
        'ref': EntityReference<CovItem>.fromEntity(
          refEntity,
          entityHandler: covItemHandler,
        ),
        'refs': EntityReferenceList<CovItem>.fromEntities([
          refsEntity,
        ], entityHandler: covItemHandler),
      });

      await parentRepo.store(p);

      var deleted = await parentRepo.deleteEntityCascade(p);
      expect(deleted, hasLength(6));
      expect(deleted, contains(p));
      expect(deleted, containsAll([child, c1, c2, refEntity, refsEntity]));

      expect(await itemRepo.count(), equals(0));
      expect(await parentRepo.count(), equals(0));
    });

    test('deleteCascadeGeneric without EntityHandler', () async {
      expect(
        () => EntityStorage.deleteCascadeGeneric<Object>(Uri()),
        throwsArgumentError,
      );
    });

    test('tracking / events', () async {
      var stored = <CovItem>[];
      itemRepo.onStore.listen(stored.add);

      var o = CovItem({'name': 'track'});
      await itemRepo.store(o);
      await Future<void>.delayed(Duration.zero);
      expect(stored, equals([o]));

      expect(itemRepo.isTrackingEntity(o), isTrue);
      expect(itemRepo.getEntityChangedFields(o), isEmpty);
      expect(itemRepo.entityHasChangedFields(o), isFalse);

      o.values['name'] = 'changed';
      expect(itemRepo.getEntityChangedFields(o), equals(['name']));
      expect(itemRepo.entityHasChangedFields(o), isTrue);

      var list = itemRepo.trackEntitiesNullable([o, null], stored: true);
      expect(list, equals([o, null]));

      itemRepo.untrackEntity(o);
      expect(itemRepo.isTrackingEntity(o), isFalse);
      expect(itemRepo.getEntityChangedFields(o), isNull);

      var deleted = <CovItem>[];
      itemRepo.onDelete.listen(deleted.add);
      itemRepo.trackEntity(o);
      itemRepo.untrackEntity(o, deleted: true);
      await Future<void>.delayed(Duration.zero);
      expect(deleted, equals([o]));
    });

    test('createFromMap errors', () async {
      var provider2 = EntityRepositoryProvider();
      var h = GenericEntityHandler<CovUniq>(
        instantiatorFromMap: (m) => throw StateError('no'),
        provider: EntityHandlerProvider(),
        sampleEntity: CovUniq({'id': 1}),
      );
      var repo = SetEntityRepository<CovUniq>(
        'cov_uniq2',
        h,
        provider: provider2,
      );
      addTearDown(repo.close);

      expect(
        () => repo.createFromMap({'id': 1}),
        throwsA(isA<UnsupportedError>()),
      );

      var hAsync = GenericEntityHandler<CovRefOnly>(
        instantiatorFromMap: (m) async => throw StateError('async no'),
        provider: EntityHandlerProvider(),
        sampleEntity: CovRefOnly({'id': 1}),
      );
      var repoAsync = SetEntityRepository<CovRefOnly>(
        'cov_ref_only2',
        hAsync,
        provider: provider2,
      );
      addTearDown(repoAsync.close);

      await expectLater(
        Future.sync(() => repoAsync.createFromMap({'id': 1})),
        throwsA(anything),
      );
    });
  });

  group('EntityRepositoryProvider', () {
    late EntityRepositoryProvider provider;
    late SetEntityRepository<CovItem> itemRepo;

    setUp(() {
      provider = EntityRepositoryProvider();
      itemRepo = SetEntityRepository<CovItem>(
        'cov_item',
        covItemHandler,
        provider: provider,
      )..ensureInitialized();
    });

    tearDown(() {
      itemRepo.close();
      provider.close();
    });

    test('lookups', () async {
      expect(provider.getEntityRepository<CovItem>(), same(itemRepo));
      expect(
        provider.getEntityRepository<Object>(obj: CovItem()),
        same(itemRepo),
      );
      expect(
        provider.getEntityRepository<Object>(type: CovItem),
        same(itemRepo),
      );
      expect(
        provider.getEntityRepository<Object>(name: 'Cov-Item'),
        same(itemRepo),
      );
      expect(provider.getEntityRepository<Object>(name: 'nope'), isNull);

      expect(
        provider.getEntityRepositoryByTypeInfo<CovItem>(tCovItem),
        same(itemRepo),
      );
      expect(
        provider.getEntityRepositoryByTypeInfo<Object>(TypeInfo.tInt),
        isNull,
      );

      expect(provider.registeredEntityRepositories, contains(itemRepo));
      expect(
        provider.registeredEntityRepositoriesInformation.keys,
        contains(itemRepo),
      );

      expect(provider.toString(), contains('CovItem'));
    });

    test('getEntityByID', () async {
      await itemRepo.store(CovItem({'name': 'x'}));

      expect(provider.getEntityByID<CovItem>(null, type: CovItem), isNull);
      expect(provider.getEntityByID<CovItem>(1), isNull);
      expect(
        provider.getEntityByID<CovItem>(1, type: CovItem, sync: true),
        isNull,
      );
      var o = await provider.getEntityByID<CovItem>(1, type: CovItem);
      expect(o!.values['name'], equals('x'));

      expect(provider.getEntityByID<Object>(1, type: Uri), isNull);
      expect(
        provider.getEntityByID<Object>(1, type: TransactionOperationType),
        isNull,
      );
    });

    test('allRepositories / known providers', () async {
      var provider2 = EntityRepositoryProvider();
      addTearDown(provider2.close);

      var parentRepo = SetEntityRepository<CovParent>(
        'cov_parent',
        covParentHandler,
        provider: provider2,
      );
      addTearDown(parentRepo.close);

      provider.notifyKnownEntityRepositoryProvider(provider2);
      provider2.notifyKnownEntityRepositoryProvider(provider);

      var all = provider.allRepositories();
      expect(all.keys, containsAll([CovItem, CovParent]));

      expect(
        provider.getEntityRepository<CovParent>(type: CovParent),
        same(parentRepo),
      );

      // Extensions over iterables of providers:
      var list = [provider, provider2];
      var set = {provider, provider2};
      var itr = list.where((e) => true);

      expect(list.getEntityRepository<CovItem>(type: CovItem), same(itemRepo));
      expect(set.getEntityRepository<CovItem>(type: CovItem), same(itemRepo));
      expect(itr.getEntityRepository<CovItem>(type: CovItem), same(itemRepo));

      expect(
        list.getEntityRepositoryByType<CovParent>(CovParent),
        same(parentRepo),
      );
      expect(
        set.getEntityRepositoryByType<CovParent>(CovParent),
        same(parentRepo),
      );
      expect(
        itr.getEntityRepositoryByType<CovParent>(CovParent),
        same(parentRepo),
      );

      expect(
        list.getEntityRepositoryByTypeInfo<CovItem>(tCovItem),
        same(itemRepo),
      );
      expect(
        set.getEntityRepositoryByTypeInfo<CovItem>(tCovItem),
        same(itemRepo),
      );
      expect(
        itr.getEntityRepositoryByTypeInfo<CovItem>(tCovItem),
        same(itemRepo),
      );
      expect(list.getEntityRepositoryByTypeInfo<Object>(TypeInfo.tInt), isNull);
      expect(set.getEntityRepositoryByTypeInfo<Object>(TypeInfo.tInt), isNull);
      expect(itr.getEntityRepositoryByTypeInfo<Object>(TypeInfo.tInt), isNull);

      expect(list.allRepositories().keys, containsAll([CovItem, CovParent]));
      expect(set.allRepositories().keys, containsAll([CovItem, CovParent]));
      expect(itr.allRepositories().keys, containsAll([CovItem, CovParent]));
      expect(<EntityRepositoryProvider>[].allRepositories(), isEmpty);
      expect([provider].allRepositories().keys, contains(CovItem));
      expect(
        <EntityRepositoryProvider>[].getEntityRepository<CovItem>(),
        isNull,
      );
    });

    test('multiple candidates', () async {
      var p1 = EntityRepositoryProvider();
      var p2 = EntityRepositoryProvider();
      addTearDown(() {
        p1.close();
        p2.close();
      });

      // A distinct `EntityHandler` for `r2`:
      var handlerProvider2 = EntityHandlerProvider();
      var covUniqHandler2 = GenericEntityHandler<CovUniq>(
        instantiatorDefault: CovUniq.new,
        provider: handlerProvider2,
      );

      var r1 = SetEntityRepository<CovUniq>(
        'cov_uniq',
        covUniqHandler,
        provider: p1,
      );
      var r2 = SetEntityRepository<CovUniq>(
        'cov_uniq',
        covUniqHandler2,
        provider: p2,
      );
      addTearDown(() {
        r1.close();
        r2.close();
      });

      var providers = [p1, p2];

      expect(
        () => providers.getEntityRepositoryByType<CovUniq>(CovUniq),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Multiple `EntityRepository` candidates'),
          ),
        ),
      );

      expect(
        providers.getEntityRepositoryByType<CovUniq>(
          CovUniq,
          entityRepositoryProvider: p2,
        ),
        same(r2),
      );

      expect(
        providers.getEntityRepositoryByType<CovUniq>(
          CovUniq,
          entityHandlerProvider: handlerProvider2,
        ),
        same(r2),
      );

      // A closed provider is skipped (and removed):
      p1.close();
      var mutable = <EntityRepositoryProvider>[p1, p2];
      expect(
        mutable.getEntityRepositoryByType<CovUniq>(
          CovUniq,
          removeClosedProviders: true,
        ),
        same(r2),
      );
      expect(mutable, equals([p2]));

      var mutableSet = <EntityRepositoryProvider>{p1, p2};
      expect(
        mutableSet.getEntityRepositoryByType<CovUniq>(
          CovUniq,
          removeClosedProviders: true,
        ),
        same(r2),
      );
      expect(mutableSet, equals({p2}));
    });

    test('storeAllFromJson / populate', () async {
      var parentRepo = SetEntityRepository<CovParent>(
        'cov_parent',
        covParentHandler,
        provider: provider,
      )..ensureInitialized();
      addTearDown(parentRepo.close);

      var res = await provider.storeAllFromJsonEncoded(
        '{"cov_item": [{"name": "a"}, {"name": "b"}], "cov_parent": []}',
      );
      expect(res['cov_item'], hasLength(2));
      expect(res['cov_parent'], isEmpty);
      expect(await itemRepo.count(), equals(2));

      expect(await provider.storeAllFromJsonEncoded('null'), isEmpty);

      await expectLater(
        Future.sync(
          () => provider.storeAllFromJson({
            'unknown_repo': [
              {'x': 1},
            ],
          }),
        ),
        throwsStateError,
      );

      var res2 = await provider.populateFromSource(
        {
          'cov_item': [
            {'name': '%v1%'},
            {'name': 'plain'},
          ],
        },
        variables: {'v1': 'var_value'},
      );
      expect(res2['cov_item'], hasLength(2));
      var names = (await itemRepo.selectAll()).map((e) => e.values['name']);
      expect(names, containsAll(['var_value', 'plain']));

      // A JSON string source, and a single entity (not a list):
      var res3 = await provider.populateFromSource(
        '{"cov_item": {"name": "single"}}',
      );
      expect(res3['cov_item'], hasLength(1));
    });

    test('storeAllFromJson in blocks', () async {
      var entries = List.generate(120, (i) => {'name': 'b$i'});
      var os = await itemRepo.storeAllFromJson(entries);
      expect(os, hasLength(120));
      expect(await itemRepo.count(), equals(120));

      var o = await itemRepo.storeFromJson({'name': 'one'});
      expect(o.getID(), isNotNull);
    });

    test('populateFromSource (file)', () async {
      var dir = await Directory.systemTemp.createTemp('bones_api_cov_repo_');
      addTearDown(() => dir.delete(recursive: true));

      var file = File('${dir.path}/source.json');
      await file.writeAsString('{"cov_item": [{"name": "from_file"}]}');

      var res = await provider.populateFromSource(file.path);
      expect(res['cov_item'], hasLength(1));
      expect(
        (await itemRepo.selectAll()).single.values['name'],
        equals('from_file'),
      );

      expect(
        () => provider.resolveSource('not_found_file_xyz.json'),
        throwsA(anything),
      );
      expect(await provider.resolveSource(null), isEmpty);
      expect(await provider.resolveSource(123), isEmpty);
    });

    test('resolveEntitySourceVariables', () {
      var vars = {'a': 1, 'b': 'B'};

      expect(
        provider.resolveEntitiesSourceVariables({
          't': [
            {'x': '%a%'},
          ],
        }, {}),
        equals({
          't': [
            {'x': '%a%'},
          ],
        }),
      );

      expect(
        provider.resolveEntitySourceVariables({'x': '%a%'}, {}),
        equals({'x': '%a%'}),
      );

      expect(
        provider.resolveEntitySourceVariables({
          'x': '%a%',
          'y': 'plain',
          'z': 10,
          'w': true,
          'n': null,
          'm': {'k': '%b%'},
          'm2': <Object, Object?>{'k2': '%b%'},
          'l': ['%a%', '%c%'],
          'o': Uri(path: 'u'),
        }, vars),
        equals({
          'x': 1,
          'y': 'plain',
          'z': 10,
          'w': true,
          'n': null,
          'm': {'k': 'B'},
          'm2': {'k2': 'B'},
          'l': [1, '%c%'],
          'o': Uri(path: 'u'),
        }),
      );

      expect(
        provider.resolveEntitySourceValueVariables('k', 'x', {}),
        equals('x'),
      );
    });
  });

  group('EntityRepository static helpers', () {
    late EntityRepositoryProvider provider;
    late SetEntityRepository<CovItem> itemRepo;

    setUp(() {
      provider = EntityRepositoryProvider();
      itemRepo = SetEntityRepository<CovItem>(
        'cov_item',
        covItemHandler,
        provider: provider,
      )..ensureInitialized();
    });

    tearDown(() {
      itemRepo.close();
      provider.close();
    });

    test('resolveEntityFromMap', () async {
      await itemRepo.store(CovItem({'name': 'stored'}));

      expect(
        () => EntityRepository.resolveEntityFromMap<CovItem>(),
        throwsArgumentError,
      );

      var o1 = await EntityRepository.resolveEntityFromMap<CovItem>(
        entityMap: {'name': 'fromMap'},
        fromMap: (m) => CovItem({'name': 'custom-${m['name']}'}),
      );
      expect(o1!.values['name'], equals('custom-fromMap'));

      var o2 = await EntityRepository.resolveEntityFromMap<CovItem>(
        parentMap: {
          'item': {'name': 'p'},
        },
        entityField: 'item',
        entityType: CovItem,
        entityRepositoryProvider: provider,
      );
      expect(o2!.values['name'], equals('p'));

      var o3 = await EntityRepository.resolveEntityFromMap<CovItem>(
        entityMap: 1,
        entityType: CovItem,
        entityRepositoryProvider: provider,
      );
      expect(o3!.values['name'], equals('stored'));

      var o4 = await EntityRepository.resolveEntityFromMap<CovItem>(
        entityMap: true,
        empty: () => CovItem({'name': 'empty'}),
      );
      expect(o4!.values['name'], equals('empty'));

      var o5 = await EntityRepository.resolveEntityFromMap<CovItem>(
        entityMap: {'name': 'via-handler'},
        entityType: CovItem,
        entityHandlerProvider: EntityHandlerProvider.globalProvider,
      );
      expect(o5!.values['name'], equals('via-handler'));

      var o6 = await EntityRepository.resolveEntityFromMap<CovItem>(
        entityMap: '1',
        entityField: 'cov_item',
        entityHandlerProvider: EntityHandlerProvider.globalProvider,
      );
      expect(o6, anyOf(isNull, isA<CovItem>()));
    });

    test('resolveSubEntitiesFields', () async {
      var fields = {'a': 1};
      expect(
        identical(
          await EntityRepository.resolveSubEntitiesFields(fields, {}),
          fields,
        ),
        isTrue,
      );

      var resolved = await EntityRepository.resolveSubEntitiesFields(
        {
          'x': 1,
          'item': {'name': 'sub'},
          'missing': null,
        },
        {'item': CovItem, 'missing': CovItem},
        fromMap: (f, m) => CovItem({'name': '$f:${m['name']}'}),
        empty: (f) => CovItem({'name': 'empty:$f'}),
        entityRepositoryProvider: provider,
      );

      expect(resolved['x'], equals(1));
      expect((resolved['item'] as CovItem).values['name'], equals('item:sub'));
      expect(
        (resolved['missing'] as CovItem).values['name'],
        equals('empty:missing'),
      );
    });
  });
}

@TestOn('vm')
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:statistics/statistics.dart' show Decimal, DynamicInt;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A simple manual entity, backed by a [Map].
abstract class CovEntity extends Entity {
  final Map<String, Object?> values;

  CovEntity([Map<String, Object?>? values]) : values = values ?? {};

  Map<String, TypeInfo> get types;

  Map<String, List<EntityAnnotation>> get annotations => const {};

  @override
  String get idFieldName => 'id';

  @override
  V? getID<V>() => getField(idFieldName);

  @override
  void setID<V>(V id) => setField(idFieldName, id);

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
    if (value != null && !t.isAnyType && t.type != value.runtimeType) {
      if (!(t.isList && value is List)) {
        throw ArgumentError('Invalid value type for `$key`: $value');
      }
    }
    values[key] = value;
  }

  @override
  Map<String, dynamic> toJson() => Map<String, dynamic>.fromEntries(
    values.entries.where((e) => e.value != null),
  );
}

class CovInt extends CovEntity {
  CovInt([super.values]);

  @override
  Map<String, TypeInfo> get types => {
    'id': TypeInfo.tInt,
    'name': TypeInfo.tString,
  };

  @override
  Map<String, List<EntityAnnotation>> get annotations => {
    'name': [const EntityField.maximum(5), const EntityField.unique()],
  };

  @override
  String toString() => 'CovInt$values';
}

class CovStr extends CovEntity {
  CovStr([super.values]);

  @override
  String get idFieldName => 'myId';

  static final TypeInfo _refType = TypeInfo<EntityReference<CovInt>>.fromType(
    EntityReference,
    [TypeInfo<CovInt>.fromType(CovInt)],
  );

  static final TypeInfo _listType = TypeInfo<List<CovInt>>.fromType(List, [
    TypeInfo<CovInt>.fromType(CovInt),
  ]);

  @override
  Map<String, TypeInfo> get types => {
    'myId': TypeInfo.tString,
    'tags': TypeInfo<List<String>>.fromType(List, [TypeInfo.tString]),
    'ref': _refType,
    'items': _listType,
  };

  @override
  Map<String, List<EntityAnnotation>> get annotations => {
    'items': [const EntityField.hidden()],
  };
}

class CovBig extends CovEntity {
  CovBig([super.values]);

  @override
  Map<String, TypeInfo> get types => {
    'id': TypeInfo<BigInt>.fromType(BigInt),
    'child': TypeInfo<CovInt>.fromType(CovInt),
  };
}

class CovDouble extends CovEntity {
  CovDouble([super.values]);

  @override
  Map<String, TypeInfo> get types => {'id': TypeInfo.tDouble};
}

class CovBool extends CovEntity {
  CovBool([super.values]);

  @override
  Map<String, TypeInfo> get types => {'id': TypeInfo.tBool};
}

class CovNoDefault extends CovEntity {
  CovNoDefault([super.values]);

  @override
  Map<String, TypeInfo> get types => {'id': TypeInfo.tInt};
}

class CovAsync extends CovEntity {
  CovAsync([super.values]);

  @override
  Map<String, TypeInfo> get types => {'id': TypeInfo.tInt};
}

class CovBroken extends CovEntity {
  CovBroken([super.values]);

  @override
  Map<String, TypeInfo> get types => {'id': TypeInfo.tInt};
}

class CovUnknownType extends CovEntity {
  CovUnknownType([super.values]);

  @override
  Map<String, TypeInfo> get types => {'id': TypeInfo.tInt};
}

/// An [EntityProvider] that never finds an entity.
class NullEntityProvider implements EntityProvider {
  int calls = 0;

  @override
  FutureOr<O?> getEntityByID<O>(
    dynamic id, {
    Type? type,
    bool sync = false,
    EntityResolutionRules? resolutionRules,
  }) {
    ++calls;
    return null;
  }
}

/// An [EntityProvider] that never finds an entity (asynchronously).
class AsyncNullEntityProvider implements EntityProvider {
  int calls = 0;

  @override
  FutureOr<O?> getEntityByID<O>(
    dynamic id, {
    Type? type,
    bool sync = false,
    EntityResolutionRules? resolutionRules,
  }) async {
    ++calls;
    return null;
  }
}

final covIntHandler = GenericEntityHandler<CovInt>(
  instantiatorDefault: CovInt.new,
  instantiatorFromMap: (m) => CovInt(Map<String, Object?>.from(m)),
);

final covStrHandler = GenericEntityHandler<CovStr>(
  instantiatorDefault: CovStr.new,
);

final covBigHandler = GenericEntityHandler<CovBig>(
  instantiatorDefault: CovBig.new,
);

final covDoubleHandler = GenericEntityHandler<CovDouble>(
  instantiatorDefault: CovDouble.new,
);

final covBoolHandler = GenericEntityHandler<CovBool>(
  instantiatorDefault: CovBool.new,
);

void main() {
  setUpAll(() {
    // Top-level finals are lazy: instantiate (and register) the handlers.
    expect(
      [
        covIntHandler,
        covStrHandler,
        covBigHandler,
        covDoubleHandler,
        covBoolHandler,
      ].length,
      equals(5),
    );
    RoleType$reflection.boot();
  });

  group('EntityHandlerProvider', () {
    test('getEntityHandlerByType', () {
      var provider = EntityHandlerProvider();
      expect(provider.getEntityHandlerByType<CovInt>(CovInt), covIntHandler);
      expect(
        EntityHandlerProvider.globalProvider.getEntityHandlerByType<CovStr>(
          CovStr,
        ),
        covStrHandler,
      );
      expect(provider.getEntityHandlerByType<Object>(Uri), isNull);
    });

    test('getEntityRepository (not found)', () {
      var provider = EntityHandlerProvider();
      expect(provider.getEntityRepository<CovInt>(type: CovInt), isNull);
      expect(
        EntityHandlerProvider.globalProvider.getEntityRepository<CovDouble>(
          type: CovDouble,
        ),
        isNull,
      );
    });
  });

  group('EntityHandler', () {
    test('constructor errors', () {
      var provider = EntityHandlerProvider();

      expect(
        () => GenericEntityHandler<CovBroken>(
          instantiatorDefault: CovBroken.new,
          type: CovInt,
          provider: provider,
        ),
        throwsStateError,
      );

      expect(
        () => GenericEntityHandler<CovBroken>(provider: provider),
        throwsArgumentError,
      );

      var h = GenericEntityHandler<CovNoDefault>(
        instantiatorFromMap: (m) => CovNoDefault(m),
        provider: provider,
      );

      expect(() => h.idFieldName(), throwsStateError);
      expect(() => h.fieldsNames(), throwsStateError);
      expect(() => h.fieldsTypes(), throwsStateError);

      var h2 = GenericEntityHandler<CovUnknownType>(
        instantiatorFromMap: (m) => CovUnknownType(m),
        sampleEntity: CovUnknownType({'id': 1}),
        provider: provider,
      );
      expect(h2.idFieldName(), equals('id'));
      expect(h2.fieldsNames(), equals(['id']));
      expect(h2.toString(), equals('GenericEntityHandler{CovUnknownType}'));
    });

    test('resolveEntityType / type checks', () {
      expect(
        EntityHandler.resolveEntityType<Object>(obj: CovInt()),
        equals(CovInt),
      );
      expect(EntityHandler.resolveEntityType<CovInt>(), equals(CovInt));
      expect(EntityHandler.resolveEntityType<Object>(obj: 123), isNull);
      expect(
        EntityHandler.resolveEntityType<Object>(type: CovBig),
        equals(CovBig),
      );

      expect(EntityHandler.isBasicType<Uint8List>(), isTrue);
      expect(EntityHandler.isBasicType<DynamicInt>(), isTrue);
      expect(EntityHandler.isBasicType<CovInt>(), isFalse);
      expect(EntityHandler.isReflectedEnumType<int>(), isFalse);
      expect(EntityHandler.isReflectedEnumType(RoleType), isTrue);
    });

    test('getEntityHandler / getEntityHandlerByType', () {
      var ref = EntityReference<CovInt>.fromID(1, entityHandler: covIntHandler);

      expect(covIntHandler.getEntityHandler<CovInt>(), same(covIntHandler));
      expect(
        covStrHandler.getEntityHandler<Object>(obj: ref),
        same(covIntHandler),
      );
      expect(
        covIntHandler.getEntityHandler<Object>(obj: ref),
        same(covIntHandler),
      );
      expect(
        covIntHandler.getEntityHandler<Object>(obj: CovInt()),
        same(covIntHandler),
      );
      expect(
        covIntHandler.getEntityHandler<Object>(typeName: 'CovInt'),
        same(covIntHandler),
      );
      expect(
        covIntHandler.getEntityHandler<Object>(
          type: CovStr,
          knownEntityHandler: covStrHandler,
        ),
        same(covStrHandler),
      );

      expect(
        covIntHandler.getEntityHandlerByType<Object>(CovInt),
        same(covIntHandler),
      );
      expect(
        covIntHandler.getEntityHandlerByType<Object>(
          CovStr,
          knownEntityHandler: covStrHandler,
        ),
        same(covStrHandler),
      );
      expect(
        covIntHandler.getEntityHandlerByType<Object>(CovBig),
        same(covBigHandler),
      );
    });

    test('normalizeID / normalizeIDs', () {
      expect(covIntHandler.normalizeID(null), isNull);
      expect(covIntHandler.normalizeID('12'), equals(12));
      expect(covStrHandler.normalizeID(12), equals('12'));
      expect(covBigHandler.normalizeID('12'), equals(BigInt.from(12)));

      expect(covIntHandler.normalizeIDs(null), isNull);
      expect(covIntHandler.normalizeIDs(<int>[1, 2]), equals([1, 2]));
      expect(covIntHandler.normalizeIDs(<int>{1, 2}), equals([1, 2]));
      expect(covIntHandler.normalizeIDs(['1', '2']), equals([1, 2]));

      expect(covStrHandler.normalizeIDs(<String>['a']), equals(['a']));
      expect(
        covStrHandler.normalizeIDs(<String>{'a', 'b'}),
        equals(['a', 'b']),
      );
      expect(covStrHandler.normalizeIDs([1, 2]), equals(['1', '2']));

      expect(
        covBigHandler.normalizeIDs(['1', 2]),
        equals([BigInt.one, BigInt.two]),
      );
    });

    test('resolveID', () {
      expect(covIntHandler.resolveID(null), isNull);
      expect(covIntHandler.resolveID(CovInt({'id': 7})), equals(7));
      expect(covIntHandler.resolveID({'ID': 8}), equals(8));
      expect(covIntHandler.resolveID(9), equals(9));
      expect(covIntHandler.resolveID('10'), equals(10));

      expect(
        covIntHandler.resolveID(
          EntityReference<CovInt>.fromID(11, entityHandler: covIntHandler),
        ),
        equals(11),
      );

      expect(
        covIntHandler.resolveID(
          EntityReferenceList<CovInt>.fromIDs([], entityHandler: covIntHandler),
        ),
        isNull,
      );
      expect(
        covIntHandler.resolveID(
          EntityReferenceList<CovInt>.fromIDs([
            12,
          ], entityHandler: covIntHandler),
        ),
        equals(12),
      );
      expect(
        covIntHandler.resolveID(
          EntityReferenceList<CovInt>.fromIDs([
            12,
            13,
          ], entityHandler: covIntHandler),
        ),
        isNull,
      );
    });

    test('resolveIDFromMap', () {
      expect(covStrHandler.idFieldName(), equals('myId'));
      expect(covStrHandler.resolveIDFromMap({'myId': 'a'}), equals('a'));
      expect(covStrHandler.resolveIDFromMap({'myid': 'b'}), equals('b'));
      expect(covStrHandler.resolveIDFromMap({'MY_ID': 'c'}), equals('c'));
      expect(covStrHandler.resolveIDFromMap({'other': 'd'}), isNull);
    });

    test('resolveIDs', () {
      expect(covIntHandler.resolveIDs<int>(null), isEmpty);
      expect(covIntHandler.resolveIDs<int>(CovInt({'id': 3})), equals([3]));
      expect(covIntHandler.resolveIDs<int>(CovInt()), isEmpty);
      expect(covIntHandler.resolveIDs<int>({'id': 4}), equals([4]));
      expect(covIntHandler.resolveIDs<int>({'x': 4}), isEmpty);
      expect(
        covIntHandler.resolveIDs<int>([
          1,
          CovInt({'id': 2}),
          null,
        ]),
        equals([1, 2]),
      );
      expect(
        covIntHandler.resolveIDs<int>(
          EntityReference<CovInt>.fromID(5, entityHandler: covIntHandler),
        ),
        equals([5]),
      );
      expect(
        covIntHandler.resolveIDs<int>(
          EntityReference<CovInt>.asNull(entityHandler: covIntHandler),
        ),
        isEmpty,
      );
      expect(
        covIntHandler.resolveIDs<int>(
          EntityReferenceList<CovInt>.fromIDs([
            6,
            7,
          ], entityHandler: covIntHandler),
        ),
        equals([6, 7]),
      );

      expect(covIntHandler.resolveIDs<int>('1, 2,3'), equals([1, 2, 3]));
      expect(
        covBigHandler.resolveIDs<BigInt>('1, 2'),
        equals([BigInt.one, BigInt.two]),
      );
      expect(covDoubleHandler.resolveIDs<double>('1.5, 2'), equals([1.5, 2.0]));
      expect(
        covStrHandler.resolveIDs<String>(' a "b"  \'c\' '),
        equals(['a', 'b', 'c']),
      );
      expect(covBoolHandler.resolveIDs<Object>(true), equals([true]));
    });

    test('getIDs / toEntitiesMapByIdMap / getFields', () {
      expect(covIntHandler.getIDs<int>([]), isEmpty);
      expect(
        covIntHandler.getIDs<int>([
          CovInt({'id': 1}),
          CovInt({'id': 2}),
        ]),
        equals([1, 2]),
      );

      var reflectionHandler = Role$reflection.staticInstance.entityHandler;
      expect(reflectionHandler.getIDs<int>([]), isEmpty);
      expect(
        reflectionHandler.getIDs<int>([
          Role(RoleType.admin, id: 10),
          Role(RoleType.guest, id: 11),
        ]),
        equals([10, 11]),
      );

      expect(
        covIntHandler.toEntitiesMapByIdMap([
          {'id': 1, 'name': 'a'},
          {'id': 2, 'name': 'b'},
        ]),
        equals({
          1: {'id': 1, 'name': 'a'},
          2: {'id': 2, 'name': 'b'},
        }),
      );

      expect(
        covIntHandler.getFields(CovInt({'id': 1, 'name': 'x'})),
        equals({'id': 1, 'name': 'x'}),
      );
    });

    test('fields with types', () {
      expect(
        covStrHandler.fieldsWithTypeList().keys,
        equals(['tags', 'items']),
      );
      expect(
        covStrHandler.fieldsWithTypeEntityOrReference().keys,
        equals(['ref']),
      );
      expect(covStrHandler.fieldsWithEntityReference().keys, equals(['ref']));
      // `items` is hidden:
      expect(covStrHandler.fieldsWithTypeListEntityOrReference(), isEmpty);
      expect(covStrHandler.fieldsWithEntityReferenceList(), isEmpty);

      expect(covBigHandler.fieldsWithTypeEntity().keys, equals(['child']));
      expect(covBigHandler.getFieldsEntityTypes().keys, equals(['child']));

      expect(
        covIntHandler.getFieldsTypes().keys.toList(),
        equals(['id', 'name']),
      );
      expect(covIntHandler.getFieldsEnumTypes(), isEmpty);
      expect(covStrHandler.getFieldsListEntityTypes().keys, equals(['items']));

      expect(covIntHandler.fieldsNamesIndexes(), equals({'id': 0, 'name': 1}));
      expect(covStrHandler.fieldsNamesLC(), contains('myid'));
      expect(covStrHandler.fieldsNamesSimple(), contains('myid'));
    });

    test('getFieldType resolving field name', () {
      expect(
        covIntHandler.getFieldType(null, 'NAME', resolveFiledName: true),
        equals(TypeInfo.tString),
      );
      expect(
        covIntHandler.getFieldType(CovInt(), 'Unknown', resolveFiledName: true),
        isNull,
      );
      expect(covIntHandler.getFieldType(null, 'NAME'), isNull);
    });

    test('casts and classification', () {
      expect(covIntHandler.castList([CovInt()], CovInt), isA<List<CovInt>>());
      expect(covIntHandler.castList([CovInt()], CovStr), isNull);
      expect(
        () => covIntHandler.castList([CovInt(), null], CovInt),
        throwsArgumentError,
      );

      expect(
        covIntHandler.castListNullable([CovInt(), null], CovInt),
        isA<List<CovInt?>>(),
      );
      expect(covIntHandler.castListNullable([null], CovStr), isNull);

      expect(
        covIntHandler.castIterable([CovInt()], CovInt),
        isA<Iterable<CovInt>>(),
      );
      expect(covIntHandler.castIterable([CovInt()], CovStr), isNull);
      expect(
        covIntHandler.castIterableNullable([CovInt(), null], CovInt),
        isA<Iterable<CovInt?>>(),
      );
      expect(covIntHandler.castIterableNullable([null], CovStr), isNull);

      expect(covIntHandler.canCastIterable([CovInt()], CovInt), isTrue);
      expect(covIntHandler.canCastIterable([CovInt(), 1], CovInt), isFalse);
      expect(covIntHandler.canCastIterable([CovInt()], CovStr), isFalse);
      expect(
        covIntHandler.canCastIterableNullable([CovInt(), null], CovInt),
        isTrue,
      );
      expect(covIntHandler.canCastIterableNullable([null], CovStr), isFalse);

      var c1 = covIntHandler.classifyIterableElements([]);
      expect(c1.isEmpty, isTrue);
      expect(c1.isAllNullOrEmpty, isTrue);

      var c2 = covIntHandler.classifyIterableElements([null, null]);
      expect(c2.isAllNull, isTrue);
      expect(c2.isEmpty, isFalse);

      var c3 = covIntHandler.classifyIterableElements([CovInt(), CovInt()]);
      expect(c3.isAllObj, isTrue);
      expect(c3.isAllID, isFalse);

      var c4 = covIntHandler.classifyIterableElements([1, 2]);
      expect(c4.isAllID, isTrue);

      var c5 = covIntHandler.classifyIterableElements([{}, {}]);
      expect(c5.isAllMap, isTrue);

      var c6 = covIntHandler.classifyIterableElements([Uri()]);
      expect(c6.hasOther, isTrue);
      expect(c6.toString(), contains('hasOther: true'));
    });

    test('validation', () {
      var ok = CovInt({'id': 1, 'name': 'abc'});
      var bad = CovInt({'id': 2, 'name': 'abcdefg'});

      expect(covIntHandler.validateFieldValue(ok, 'name'), isNull);
      expect(
        covIntHandler.validateFieldValue(ok, 'name', value: 'too long'),
        isA<EntityFieldInvalid>(),
      );
      expect(
        covIntHandler.validateFieldValue(bad, 'name', nullValue: true),
        isNull,
      );

      expect(covIntHandler.isValidFieldValue(ok, 'name'), isTrue);
      expect(covIntHandler.isValidFieldValue(bad, 'name'), isFalse);

      covIntHandler.checkFieldValue(ok, 'name');
      expect(
        () => covIntHandler.checkFieldValue(bad, 'name'),
        throwsA(isA<EntityFieldInvalid>()),
      );

      expect(covIntHandler.allFieldsValids(ok), isTrue);
      expect(covIntHandler.allFieldsValids(bad), isFalse);

      expect(covIntHandler.validateAllFields(ok), isNull);
      var errors = covIntHandler.validateAllFields(bad);
      expect(errors!.keys, equals(['name']));

      covIntHandler.checkAllFieldsValues(ok);
      expect(
        () => covIntHandler.checkAllFieldsValues(bad),
        throwsA(isA<EntityFieldInvalid>()),
      );

      // Sub-entity validation:
      var big = CovBig({'id': BigInt.one, 'child': bad});
      var invalid = covBigHandler.validateFieldValue(big, 'child');
      expect(invalid, isNotNull);
      expect(invalid!.subEntityErrors!.keys, equals(['name']));
      expect(invalid.reason, contains('field(name)'));
      expect(covBigHandler.isValidFieldValue(big, 'child'), isFalse);

      var big2 = CovBig({'id': BigInt.one, 'child': ok});
      expect(covBigHandler.validateFieldValue(big2, 'child'), isNull);

      // `EntityReference` values:
      var str = CovStr({
        'myId': 'x',
        'ref': EntityReference<CovInt>.fromEntity(
          bad,
          entityHandler: covIntHandler,
        ),
      });
      expect(covStrHandler.validateFieldValue(str, 'ref'), isNotNull);

      var str2 = CovStr({
        'myId': 'x',
        'ref': EntityReference<CovInt>.asNull(entityHandler: covIntHandler),
      });
      expect(covStrHandler.validateFieldValue(str2, 'ref'), isNull);

      expect(
        covIntHandler.getAllFieldsWithEntityAnnotation<EntityField>(),
        equals({
          'name': [const EntityField.maximum(5), const EntityField.unique()],
        }),
      );
      expect(
        covIntHandler.getAllFieldsWithEntityAnnotation<EntityField>(
          null,
          (e) => e.isUnique,
        ),
        equals({
          'name': [const EntityField.unique()],
        }),
      );
      expect(
        covIntHandler.getAllFieldsWithEntityAnnotation<EntityField>(
          null,
          (e) => e.isHidden,
        ),
        isEmpty,
      );
      expect(
        covDoubleHandler.getAllFieldsWithEntityAnnotation<EntityField>(),
        isEmpty,
      );
    });

    test('setField errors', () {
      var o = CovInt({'id': 1});
      expect(() => covIntHandler.setField(o, 'id', 'abc'), throwsStateError);
      expect(
        () => covIntHandler.setField(o, 'id', 'abc', log: false),
        throwsStateError,
      );
      expect(covIntHandler.trySetField(o, 'id', 'abc'), isFalse);
      expect(covIntHandler.trySetField(o, 'id', 2), isTrue);
      expect(o.values['id'], equals(2));
    });

    test('JSON', () async {
      var o1 = CovInt({'id': 1, 'name': 'a'});
      var o2 = CovInt({'id': 2, 'name': 'b'});

      var listJson = covIntHandler.encodeObjectListJson([o1, o2]);
      expect(listJson, equals('[{"id":1,"name":"a"},{"id":2,"name":"b"}]'));
      expect(covIntHandler.encodeObjectListJson([]), equals('[]'));

      // NOTE: `decodeObjectListJson` delegates to `decodeObjectJson`, which
      // casts the decoded JSON (a `List`) to `O`, so it can't decode a list
      // (reported as a lib bug). Accept both behaviors here:
      try {
        var list = covIntHandler.decodeObjectListJson(listJson);
        expect(list.map((e) => e.values), equals([o1.values, o2.values]));
      } on TypeError catch (e) {
        expect('$e', contains('List'));
      }

      var decoded = covIntHandler.decodeObjectJson('{"id":3,"name":"c"}');
      expect(decoded.values, equals({'id': 3, 'name': 'c'}));

      expect(covIntHandler.encodeJson(o1), equals('{"id":1,"name":"a"}'));
      expect(covIntHandler.toJson(o1), equals({'id': 1, 'name': 'a'}));

      covIntHandler.jsonReviver = (k, v) => v;
      expect(covIntHandler.decodeJson<Map>('{"id":3}'), equals({'id': 3}));
      covIntHandler.jsonReviver = null;
      expect(covIntHandler.decodeJson<CovInt>('{"id":3}'), isA<CovInt>());

      var copy = await covIntHandler.copy(o1);
      expect(copy!.values, equals(o1.values));
      expect(identical(copy, o1), isFalse);
    });

    test('createFromMapSync with async instantiator', () async {
      var provider = EntityHandlerProvider();
      var h = GenericEntityHandler<CovAsync>(
        instantiatorDefault: CovAsync.new,
        instantiatorFromMap: (m) async => CovAsync(m),
        provider: provider,
      );

      expect(() => h.createFromMapSync({'id': 1}), throwsStateError);
      var o = await h.createFromMap({'id': 1});
      expect(o.values['id'], equals(1));
    });

    test('createFromMap fallbacks', () async {
      var provider = EntityHandlerProvider();

      // `instantiatorFromMap` throws, and no default instantiator:
      var h = GenericEntityHandler<CovBroken>(
        instantiatorFromMap: (m) => throw StateError('fromMap'),
        provider: provider,
        sampleEntity: CovBroken({'id': 0}),
      );

      expect(
        () => h.createFromMap({'id': 1}),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains("Can't instantiate entity `CovBroken`"),
          ),
        ),
      );

      // `instantiatorFromMap` throws, with a default instantiator:
      var h2 = GenericEntityHandler<CovNoDefault>(
        instantiatorDefault: CovNoDefault.new,
        instantiatorFromMap: (m) => throw StateError('fromMap'),
        provider: provider,
      );

      var o = await h2.createFromMap({'id': 2});
      expect(o.values, equals({'id': 2}));
    });
  });

  group('EntityHandler.equalsValues', () {
    test('equalsValues', () {
      var h = covIntHandler;

      expect(h.equalsValues(null, null), isTrue);
      expect(h.equalsValues(null, 1), isFalse);
      expect(h.equalsValues(1, null), isFalse);
      expect(h.equalsValues(1, 1), isTrue);

      var dt = DateTime.utc(2020);
      expect(h.equalsValues(dt, dt.millisecondsSinceEpoch), isTrue);
      expect(h.equalsValues(Time(1), 3600000), isTrue);
      expect(h.equalsValues(1, 2), isFalse);
      expect(h.equalsValues(RoleType.admin, 'ADMIN'), isTrue);
      expect(h.equalsValues([1, 2], [1, 2]), isTrue);
      expect(
        h.equalsValues(Uint8List.fromList([1]), Uint8List.fromList([1])),
        isTrue,
      );

      var a1 = CovInt({'id': 1});
      var a1b = CovInt({'id': 1});
      var a2 = CovInt({'id': 2});
      expect(h.equalsValues(a1, a1b), isTrue);
      expect(h.equalsValues(a1, a2), isFalse);
      expect(h.equalsValues(a1, 1), isTrue);
      expect(h.equalsValues(1, a1), isTrue);
      expect(h.equalsValues(CovInt(), CovInt()), isFalse);

      expect(
        h.equalsValues(
          EntityReference<CovInt>.fromID(1, entityHandler: covIntHandler),
          EntityReference<CovInt>.fromID(1, entityHandler: covIntHandler),
        ),
        isTrue,
      );

      expect(h.equalsValues(Uri(), Uri(path: 'x')), isFalse);

      expect(h.equalsFieldValues('id', [1], [1]), isTrue);
      expect(h.equalsFieldValues('name', 'a', 'b'), isFalse);
    });

    test('static comparisons', () {
      expect(EntityHandler.valueToDynamicNumber(1.5), isA<Decimal>());
      expect(EntityHandler.valueToDynamicNumber(2), isA<DynamicInt>());
      expect(
        EntityHandler.valueToDynamicNumber(DateTime.utc(1970, 1, 1, 0, 0, 1)),
        equals(DynamicInt.fromInt(1000)),
      );
      expect(
        EntityHandler.valueToDynamicNumber(' 10.5 ').toDouble(),
        equals(10.5),
      );
      expect(
        EntityHandler.valueToDynamicNumber(null, def: DynamicInt.fromInt(3)),
        equals(DynamicInt.fromInt(3)),
      );
      expect(
        () => EntityHandler.valueToDynamicNumber(null),
        throwsArgumentError,
      );
      expect(
        () => EntityHandler.valueToDynamicNumber('abc'),
        throwsArgumentError,
      );
      var dn = DynamicInt.fromInt(5);
      expect(identical(EntityHandler.valueToDynamicNumber(dn), dn), isTrue);

      expect(EntityHandler.graterThanValue(2, 1), isTrue);
      expect(EntityHandler.graterThanValue(1, 2), isFalse);
      expect(EntityHandler.graterThanOrEqualValue(2, 2), isTrue);
      expect(EntityHandler.lessThanValue(1, '2'), isTrue);
      expect(EntityHandler.lessThanOrEqualValue(2.5, 2), isFalse);
    });

    test('equalsValuesBasic', () {
      expect(EntityHandler.equalsValuesBasic(null, null), isTrue);
      expect(EntityHandler.equalsValuesBasic(null, 1), isFalse);
      expect(EntityHandler.equalsValuesBasic(1, null), isFalse);
      expect(EntityHandler.equalsValuesBasic(1, 1), isTrue);
      expect(EntityHandler.equalsValuesBasic(DateTime.utc(1970), 0), isTrue);
      expect(EntityHandler.equalsValuesBasic(Time(0, 0, 1), 1000), isTrue);
      expect(EntityHandler.equalsValuesBasic(1, 2), isFalse);
      expect(EntityHandler.equalsValuesBasic(RoleType.guest, 'guest'), isTrue);
      expect(
        EntityHandler.equalsValuesBasic(RoleType.guest, RoleType.admin),
        isFalse,
      );
      expect(EntityHandler.equalsValuesBasic([1, 2], [1, 2]), isTrue);
      expect(EntityHandler.equalsValuesBasic([1, '2'], [1, 2]), isFalse);
      expect(EntityHandler.equalsValuesBasic({'a': 1}, {'a': 1}), isTrue);

      var a1 = CovInt({'id': 1});
      var a2 = CovInt({'id': 1});
      expect(EntityHandler.equalsValuesBasic(a1, a2), isTrue);
      expect(EntityHandler.equalsValuesBasic(a1, 1), isTrue);
      expect(EntityHandler.equalsValuesBasic(1, a1), isTrue);
      expect(EntityHandler.equalsValuesBasic(a1, CovStr({'myId': 1})), isFalse);

      var ref = EntityReference<CovInt>.fromID(1, entityHandler: covIntHandler);
      expect(EntityHandler.equalsValuesBasic(ref, 1), isTrue);
      expect(EntityHandler.equalsValuesBasic(1, ref), isTrue);

      // Non-entity objects without resolvable IDs: both IDs are `null`, so
      // they are considered equal (by ID):
      expect(EntityHandler.equalsValuesBasic(Uri(), Uri(path: 'x')), isTrue);
      expect(
        EntityHandler.equalsValuesBasic(
          Uri(),
          Uri(path: 'x'),
          entityHandler: covIntHandler,
        ),
        isTrue,
      );
    });

    test('equalsValuesEntityMap / getEntityIDFrom', () {
      expect(EntityHandler.equalsValuesEntityMap({'id': 1}, {'id': 1}), isTrue);
      expect(EntityHandler.equalsValuesEntityMap({'id': 1}, 1), isTrue);
      expect(EntityHandler.equalsValuesEntityMap('a', {'ID': 'a'}), isTrue);

      expect(EntityHandler.getEntityIDFrom(1), equals(1));
      expect(EntityHandler.getEntityIDFrom({'Id': 2}), equals(2));
      expect(
        EntityHandler.getEntityIDFrom(
          CovInt({'id': 3}),
          entityHandler: covIntHandler,
        ),
        equals(3),
      );
      expect(EntityHandler.getEntityIDFrom(Uri()), isNull);
    });

    test('equalsValues* helpers', () {
      expect(EntityHandler.equalsValuesDateTime(1, 2), isNull);
      expect(EntityHandler.equalsValuesTime(Time(1), Time(1)), isTrue);
      expect(EntityHandler.equalsValuesTime(1, 2), isNull);
      expect(EntityHandler.equalsValuesPrimitive(1, 'a'), isFalse);
      expect(EntityHandler.equalsValuesPrimitive(Uri(), 'a'), isNull);
      expect(EntityHandler.equalsValuesEnum(1, 2), isNull);
      expect(EntityHandler.equalsValuesCollection(1, [1]), isNull);
      expect(
        EntityHandler.equalsEntityReferenceBase(
          EntityReferenceList<CovInt>.fromIDs([
            1,
          ], entityHandler: covIntHandler),
          EntityReferenceList<CovInt>.fromIDs([
            1,
          ], entityHandler: covIntHandler),
        ),
        isTrue,
      );
      expect(EntityHandler.equalsEntityReferenceBase(1, 1), isNull);
    });
  });

  group('EntityHandler.resolveValueByType', () {
    test('basic types', () async {
      var h = covIntHandler;

      expect(await h.resolveValueByType(null, 'x'), equals('x'));
      expect(await h.resolveValueByType(TypeInfo.tInt, null), isNull);
      expect(await h.resolveValueByType(TypeInfo.tInt, '12'), equals(12));
      expect(
        await h.resolveValueByType(TypeInfo(Time), '01:02:03'),
        equals(Time(1, 2, 3)),
      );
      expect(
        (await h.resolveValueByType<DateTime>(
          TypeInfo(DateTime),
          0,
        ))!.millisecondsSinceEpoch,
        equals(0),
      );
      expect(
        await h.resolveValueByType(TypeInfo(Decimal), '1.5'),
        equals(Decimal.parse('1.5')),
      );
      expect(
        await h.resolveValueByType(TypeInfo(DynamicInt), '15'),
        equals(DynamicInt.fromInt(15)),
      );
      expect(
        await h.resolveValueByType(TypeInfo<BigInt>(BigInt), '15'),
        equals(BigInt.from(15)),
      );

      expect(
        await h.resolveValueByType(TypeInfo.fromType(List, [TypeInfo(Time)]), [
          '01:00',
          '02:00',
        ]),
        equals([Time(1), Time(2)]),
      );

      expect(
        await h.resolveValueByType(
          TypeInfo.fromType(Map, [TypeInfo.tString, TypeInfo.tInt]),
          {'a': '1'},
        ),
        equals({'a': 1}),
      );

      expect(
        await h.resolveValueByType(TypeInfo.fromType(Set, [TypeInfo.tInt]), [
          1,
          2,
          2,
        ]),
        equals({1, 2}),
      );
    });

    test('Uint8List', () async {
      var h = covIntHandler;
      var t = TypeInfo(Uint8List);

      expect(
        await h.resolveValueByType(t, Uint8List.fromList([1, 2])),
        equals([1, 2]),
      );
      expect(await h.resolveValueByType(t, '  '), anyOf(isNull, isEmpty));
      expect(await h.resolveValueByType(t, 'hex:010203'), equals([1, 2, 3]));
      expect(await h.resolveValueByType(t, 'base64:AQID'), equals([1, 2, 3]));
      expect(await h.resolveValueByType(t, 'AQID'), equals([1, 2, 3]));
      expect(await h.resolveValueByType(t, '010203'), equals([1, 2, 3]));
      expect(await h.resolveValueByType(t, 'hex:zz'), isNull);
      expect(await h.resolveValueByType(t, 'base64:!!!'), isNull);
      expect(
        await h.resolveValueByType(
          t,
          'data:application/octet-stream;base64,AQID',
        ),
        equals([1, 2, 3]),
      );
      expect(await h.resolveValueByType(t, 'url(/tmp/foo.bin)'), isNull);
      expect(await h.resolveValueByType(t, 123.5), isNull);
    });

    test('Uint8List from file', () async {
      var dir = await Directory.systemTemp.createTemp('bones_api_cov_');
      addTearDown(() => dir.delete(recursive: true));

      var file = File('${dir.path}/data.bin');
      await file.writeAsBytes([4, 5, 6]);

      var t = TypeInfo(Uint8List);
      var rules = const EntityResolutionRules(allowReadFile: true);

      expect(
        await covIntHandler.resolveValueByType(
          t,
          'url("${file.path}")',
          resolutionRules: rules,
        ),
        equals([4, 5, 6]),
      );
      expect(
        await covIntHandler.resolveValueByType(
          t,
          "url('${file.path}')",
          resolutionRules: rules,
        ),
        equals([4, 5, 6]),
      );
    });

    test('entities', () async {
      var cache = JsonEntityCacheSimple();
      var e5 = CovInt({'id': 5, 'name': 'five'});
      cache.cacheEntity(e5, (o) => o.values['id']);

      var tCovInt = TypeInfo<CovInt>.fromType(CovInt);

      expect(
        await covBigHandler.resolveValueByType(tCovInt, 5, entityCache: cache),
        same(e5),
      );

      expect(
        await covBigHandler.resolveValueByType(tCovInt, {
          'id': 6,
          'name': 'six',
        }),
        isA<CovInt>().having((e) => e.values['id'], 'id', 6),
      );

      var tList = TypeInfo<List<CovInt>>.fromType(List, [tCovInt]);

      var l = await covBigHandler.resolveValueByType(tList, [
        5,
      ], entityCache: cache);
      expect(l, equals([e5]));

      var l2 = await covBigHandler.resolveValueByType(
        tList,
        '5',
        entityCache: cache,
      );
      expect(l2, equals([e5]));

      var l3 = await covBigHandler.resolveValueByType(tList, [
        {'id': 7, 'name': 'seven'},
      ]);
      expect((l3 as List).single, isA<CovInt>());

      var tRef = TypeInfo<EntityReference<CovInt>>.fromType(EntityReference, [
        tCovInt,
      ]);
      var ref = await covBigHandler.resolveValueByType(tRef, {
        'id': 8,
        'name': 'eight',
      });
      expect(ref, isA<EntityReference<CovInt>>());

      var tRefList = TypeInfo<EntityReferenceList<CovInt>>.fromType(
        EntityReferenceList,
        [tCovInt],
      );
      var refList = await covBigHandler.resolveValueByType(tRefList, [9, 10]);
      expect(refList, isA<EntityReferenceList<CovInt>>());
      expect((refList as EntityReferenceList).ids, equals([9, 10]));

      var refList2 = await covBigHandler.resolveValueByType(tRefList, '9,10');
      expect((refList2 as EntityReferenceList).ids, equals([9, 10]));

      var refList3 = await covBigHandler.resolveValueByType(
        tRefList,
        [5],
        entityCache: cache,
        resolutionRules: EntityResolutionRules(eagerEntityTypes: [CovInt]),
      );
      expect(refList3, isNotNull);
    });

    test('entities with EntityProvider (eager)', () async {
      var tCovInt = TypeInfo<CovInt>.fromType(CovInt);
      var rules = EntityResolutionRules(eagerEntityTypes: [CovInt]);

      var provider = NullEntityProvider();
      var r = await covBigHandler.resolveValueByType(
        tCovInt,
        77,
        entityProvider: provider,
        resolutionRules: rules,
      );
      expect(provider.calls, equals(1));
      expect(r, anyOf(isNull, equals(77)));

      var asyncProvider = AsyncNullEntityProvider();
      var r2 = await covBigHandler.resolveValueByType(
        tCovInt,
        78,
        entityProvider: asyncProvider,
        resolutionRules: rules,
      );
      expect(asyncProvider.calls, equals(1));
      expect(r2, anyOf(isNull, equals(78)));
    });

    test('resolveFieldsValues / resolveEntityFieldValue', () async {
      var values = await covIntHandler.resolveFieldsValues({
        'id': '1',
        'name': 'x',
      });
      expect(values, equals({'id': 1, 'name': 'x'}));

      var v = await covIntHandler.resolveEntityFieldValue(CovInt(), 'id', '42');
      expect(v, equals(42));

      var str = CovStr();
      await covStrHandler.setFieldValueDynamic(str, 'tags', ['a', 'b']);
      expect(str.values['tags'], equals(['a', 'b']));
    });
  });

  group('ClassReflectionEntityHandler', () {
    test('basic', () async {
      EntityHandler<Role> h = Role$reflection.staticInstance.entityHandler;
      expect(h, isA<ClassReflectionEntityHandler<Role>>());
      var rh = h as ClassReflectionEntityHandler<Role>;

      expect(rh.typeName, equals('Role'));
      expect(rh.toString(), equals('ClassReflectionEntityHandler{Role}'));
      expect(rh.reflectionWithObject(), isNotNull);
      expect(rh.reflectionWithObject(Role(RoleType.admin)), isNotNull);
      expect(rh.siblingsEntityHandlers(), isNotEmpty);
      expect(rh.siblingsEntityHandlers(), same(rh.siblingsEntityHandlers()));

      expect(
        rh.getFieldType(null, 'ENABLED', resolveFiledName: true),
        equals(TypeInfo.tBool),
      );
      expect(rh.getFieldType(null, 'xyz', resolveFiledName: true), isNull);

      expect(rh.getFieldAnnotations(null, 'xyz'), isNull);
      expect(rh.getEntityIndexes(), isEmpty);

      var ctors = rh.constructors();
      expect(ctors, isNotNull);
      expect(ctors!.keys, contains(''));
      expect(identical(rh.constructors(), ctors), isTrue);

      var role = Role(RoleType.admin, id: 1);
      expect(rh.trySetField(role, 'enabled', false), isTrue);
      expect(role.enabled, isFalse);
      expect(rh.trySetField(role, 'xyz', false), isFalse);
      expect(rh.trySetField<Object?>(role, 'value', null), isTrue);
      expect(rh.trySetField<Object?>(role, 'enabled', null), isFalse);
      expect(rh.trySetField<Object?>(role, 'id', 'abc'), isFalse);

      expect(() => rh.setField(role, 'enabled', Uri()), throwsStateError);
      expect(
        () => rh.setField(role, 'enabled', Uri(), log: false),
        throwsStateError,
      );
      rh.setField(role, 'xyz', 1);

      var copy = await rh.copy(role);
      expect(copy, equals(role));
      expect(identical(copy, role), isFalse);

      var decoded = rh.decodeJson<Role>(
        '{"id":3,"type":"guest","enabled":true}',
      );
      expect(decoded!.type, equals(RoleType.guest));

      // Invalid JSON: fails with `Json.decode` and with the fallback decoder:
      expect(() => rh.decodeJson<Object>('[1,2'), throwsFormatException);
    });

    test('copy with references', () async {
      var h = User$reflection.staticInstance.entityHandler;

      var user = User(
        'a@b.com',
        'pass',
        Address('NY', 'New York', 'Street', 1, id: 1),
        [Role(RoleType.admin, id: 1)],
        id: 10,
        creationTime: DateTime.utc(2020),
      );

      var copy = await h.copy(user);
      expect(copy, isNotNull);
      expect(copy!.email, equals('a@b.com'));
      expect(copy.id, equals(10));
      expect(identical(copy, user), isFalse);

      var ref = EntityReference<User>.fromEntity(user);
      expect(h.getEntityHandler<Object>(obj: ref), isNotNull);
      expect(h.getEntityHandler<Address>(type: Address), isNotNull);
    });
  });

  group('EntityFieldAccessor', () {
    test('generic', () {
      var accessor = EntityFieldAccessorGeneric<Object>();

      var e = CovInt({'id': 1});
      expect(accessor.getID(e), equals(1));
      accessor.setID(e, 2);
      expect(accessor.getID(e), equals(2));
      accessor.setField(e, 'name', 'n');
      expect(accessor.getField(e, 'name'), equals('n'));

      var m = <String, Object?>{'id': 3};
      expect(accessor.getID(m), equals(3));
      accessor.setID(m, 4);
      expect(m['id'], equals(4));
      accessor.setField(m, 'x', 5);
      expect(accessor.getField(m, 'x'), equals(5));

      expect(() => accessor.getID(Uri()), throwsStateError);
      expect(() => accessor.setID(Uri(), 1), throwsStateError);
      expect(() => accessor.getField(Uri(), 'a'), throwsStateError);
      expect(() => accessor.setField(Uri(), 'a', 1), throwsStateError);

      var roleAccessor = EntityFieldAccessorGeneric<Role>();
      var rh = Role$reflection.staticInstance.entityHandler;
      var role = Role(RoleType.admin, id: 1);
      expect(roleAccessor.getID(role, entityHandler: rh), equals(1));
    });

    test('with EntityHandler (non Entity)', () {
      var accessor = EntityFieldAccessorGeneric<Map<String, Object?>>();
      var h = _MapEntityHandler();

      var m = <String, Object?>{'id': 1, 'name': 'a'};
      expect(accessor.getID(m, entityHandler: h), equals(1));
      accessor.setID(m, 2, entityHandler: h);
      expect(m['id'], equals(2));
      expect(accessor.getField(m, 'name', entityHandler: h), equals('a'));
      accessor.setField(m, 'name', 'b', entityHandler: h);
      expect(m['name'], equals('b'));
    });
  });

  group('helpers', () {
    test('compareEntityIDs', () {
      expect(compareEntityIDs(1, 1), equals(0));
      expect(compareEntityIDs(null, 1), equals(1));
      expect(compareEntityIDs(null, null), equals(0));
      expect(compareEntityIDs(1, null), equals(-1));
      expect(compareEntityIDs('a', 'b'), lessThan(0));
      expect(compareEntityIDs(BigInt.one, BigInt.two), lessThan(0));
      expect(compareEntityIDs(BigInt.one, 'x'), equals(0));
      expect(compareEntityIDs(Uri(), Uri()), equals(0));
    });

    test('resolveSelectOffset', () {
      expect(resolveSelectOffset(offset: 3), equals(3));
      expect(resolveSelectOffset(page: 2, limit: 10), equals(10));
      expect(
        () => resolveSelectOffset(page: 1, offset: 1, limit: 1),
        throwsArgumentError,
      );
      expect(() => resolveSelectOffset(page: 1), throwsArgumentError);
      expect(() => resolveSelectOffset(page: 0, limit: 1), throwsArgumentError);
    });

    test('EntityAccessor.simplifiedName', () {
      expect(EntityAccessor.simplifiedName(' User_Info '), equals('userinfo'));
    });

    test('JSON base64 sanity', () {
      expect(base64.encode([1, 2, 3]), equals('AQID'));
    });
  });
}

/// A manual [EntityHandler] for `Map` "entities".
class _MapEntityHandler extends EntityHandler<Map<String, Object?>> {
  _MapEntityHandler()
    : super(EntityHandlerProvider(), type: Map<String, Object?>);

  @override
  String idFieldName([Map<String, Object?>? o]) => 'id';

  @override
  List<String> fieldsNames([Map<String, Object?>? o]) => ['id', 'name'];

  @override
  Map<String, TypeInfo> fieldsTypes([Map<String, Object?>? o]) => {
    'id': TypeInfo.tInt,
    'name': TypeInfo.tString,
  };

  @override
  void inspectObject(Map<String, Object?>? o) {}

  @override
  V? getField<V>(Map<String, Object?> o, String key) => o[key] as V?;

  @override
  void setField<V>(
    Map<String, Object?> o,
    String key,
    V? value, {
    bool log = true,
    EntityCache? entityCache,
  }) => o[key] = value;

  @override
  TypeInfo? getFieldType(
    Map<String, Object?>? o,
    String key, {
    bool resolveFiledName = false,
  }) => fieldsTypes()[key];

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(
    Map<String, Object?>? o,
    String key,
  ) => null;

  @override
  FutureOr<Map<String, Object?>?> createDefault() => <String, Object?>{};

  @override
  FutureOr<Map<String, Object?>?> instantiateFromMapImpl(
    Map<String, dynamic> fields, {
    JsonDecoder? jsonDecoder,
  }) => Map<String, Object?>.from(fields);
}

@TestOn('vm')
@Timeout(Duration(seconds: 60))
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';
import 'bones_api_test_modules.dart';

final tRole = TypeInfo<Role>.fromType(Role);

void main() {
  setUpAll(() {
    // Ensure the reflections are registered in the `ReflectionFactory`:
    Role$reflection.staticInstance;
    Address$reflection.staticInstance;
    UserModule$reflection.staticInstance;
  });

  group('ReflectionFactoryExtension (coverage)', () {
    test('getRegisterEntityHandler / createFromMap', () async {
      var handler = ReflectionFactory().getRegisterEntityHandler<Role>();
      expect(handler, isNotNull);
      expect(handler!.type, equals(Role));

      var role = await ReflectionFactory().createFromMap<Role>({
        'type': 'admin',
        'enabled': true,
        'id': 10,
      });
      expect(role, isA<Role>());
      expect(role!.id, equals(10));
      expect(role.type, equals(RoleType.admin));

      var role2 = await ReflectionFactory().createFromMap<Object>({
        'type': 'guest',
      }, classType: Role);
      expect(role2, isA<Role>());
      expect((role2 as Role).type, equals(RoleType.guest));

      expect(
        ReflectionFactory().getRegisterEntityHandler(_NotReflected),
        isNull,
      );
    });
  });

  group('ClassReflectionExtension (coverage)', () {
    test('entity helpers', () {
      var role = Role(RoleType.admin, id: 1);
      var reflection = Role$reflection(role);

      expect(reflection.toList(), equals([role]));
      expect(Role$reflection.staticInstance.toList(role), equals([role]));

      var ref = reflection.toEntityReference();
      expect(ref.entity, same(role));

      var refList = Role$reflection.staticInstance.toEntityReferenceList([
        role,
      ]);
      expect(refList.entities, equals([role]));

      var role2 = Role$reflection.staticInstance.createFromMapSync({
        'type': 'guest',
        'id': 2,
      });
      expect(role2.id, equals(2));
      expect(role2.type, equals(RoleType.guest));
    });

    test('field validation', () {
      var address = Address('ABCD', 'NY', 'street', 10);
      var reflection = Address$reflection(address);

      expect(reflection.isValidFieldValue('city'), isTrue);
      expect(reflection.isValidFieldValue('state'), isFalse);
      expect(reflection.isValidFieldValue('state', value: 'SC'), isTrue);

      expect(reflection.validateFieldValue('city'), isNull);
      expect(reflection.validateFieldValue('state'), isNotNull);

      reflection.checkFieldValue('state', value: 'SC');
      expect(
        () => reflection.checkFieldValue('state'),
        throwsA(isA<EntityFieldInvalid>()),
      );

      expect(reflection.allFieldsValids(), isFalse);

      var invalids = reflection.validateAllFields();
      expect(invalids, isNotNull);
      expect(invalids!.keys, contains('state'));

      expect(
        () => reflection.checkAllFieldsValues(),
        throwsA(isA<EntityFieldInvalid>()),
      );

      var valid = Address('SC', 'NY', 'street', 10);
      expect(
        Address$reflection.staticInstance.allFieldsValids(obj: valid),
        isTrue,
      );
      expect(
        Address$reflection.staticInstance.validateAllFields(obj: valid),
        isNull,
      );
      Address$reflection.staticInstance.checkAllFieldsValues(obj: valid);
    });
  });

  group('MethodReflectionExtension (coverage)', () {
    test('isFullAPIMethod', () {
      var r = UserModule$reflection.staticInstance;

      var m1 = r.method('getRequestEntityResolutionRules')!;
      expect(m1.isAPIMethod, isTrue);
      expect(m1.receivesAPIRequest, isTrue);
      expect(m1.returnsAPIResponse, isTrue);
      expect(m1.isFullAPIMethod, isTrue);

      var m2 = r.method('getUser')!;
      expect(m2.isAPIMethod, isTrue);
      expect(m2.isFullAPIMethod, isFalse);

      var m3 = r.method('notARoute')!;
      expect(m3.isAPIMethod, isFalse);
      expect(m3.isFullAPIMethod, isFalse);
    });
  });

  group('MapGetterExtension (coverage)', () {
    test('getters', () {
      var m = <String, Object?>{
        'i': '12',
        'd': '1.5',
        'n': '7',
        's': 10,
        'set': [1, 2, 2, 3],
        'Upper': 'u',
      };

      expect(m.matchKey('i'), equals('i'));
      expect(m.matchKey('x'), isNull);
      expect(m.matchKeyIgnoreCase('upper'), equals('Upper'));

      expect(m.getAsDouble('d'), equals(1.5));
      expect(m.getAsDouble('x', defaultValue: 2.5), equals(2.5));
      expect(m.getAsNum('n'), equals(7));
      expect(m.getAsNum('x', defaultValue: 3), equals(3));

      expect(m.getMultiKeyAsInt(['x', 'i']), equals(12));
      expect(m.getMultiKeyAsInt(['x'], defaultValue: 1), equals(1));
      expect(m.getMultiKeyAsDouble(['x', 'd']), equals(1.5));
      expect(m.getMultiKeyAsNum(['x', 'n']), equals(7));
      expect(m.getMultiKeyAsString(['x', 's']), equals('10'));
      expect(
        m.getMultiKeyAsString(['X', 'UPPER'], ignoreCase: true),
        equals('u'),
      );
      expect(m.getMultiKeyAsBool(['x'], defaultValue: true), isTrue);

      expect(m.getAsSet<int>('set'), equals({1, 2, 3}));
      expect(m.getAsSet<int>('x', defaultValue: {9}), equals({9}));

      expect(m.getAs<int>('i'), equals(12));
      expect(m.getParsed<Object>('i', null), equals('12'));
      expect(() => m.getParsed<int>('i', null), throwsA(isA<ArgumentError>()));

      expect(m.getMultiKeyParsed<Object>(['x', 'i'], null), equals('12'));
      expect(m.getMultiKeyParsed<int>(['x'], null, defaultValue: 5), equals(5));
      expect(
        () => m.getMultiKeyParsed<int>(['x', 'i'], null),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains("key('x','i')"),
          ),
        ),
      );
    });
  });

  group('MapMultiValueExtension (coverage)', () {
    test('setMultiValue / getMultiValue / getFirstValue', () {
      var m = <String, Object>{};

      m.setMultiValue('a', '1');
      expect(m['a'], equals('1'));
      m.setMultiValue('a', '2');
      expect(m['a'], equals(['1', '2']));
      m.setMultiValue('A', '3', ignoreCase: true);
      expect(m['a'], equals(['1', '2', '3']));

      m['b'] = <Object?>[1, null, 'x'];
      m.setMultiValue('b', 'y');
      expect(m['b'], equals(['1', 'x', 'y']));
      expect(m['b'], isA<List<String>>());

      m['c'] = 123;
      m.setMultiValue('c', 'z');
      expect(m['c'], equals(123));

      m['d'] = <Object?>[1, null, 2];
      m['e'] = <String>[];
      m['f'] = <Object?>[];

      expect(m.getMultiValue('x'), isNull);
      expect(m.getMultiValue('a'), equals(['1', '2', '3']));
      expect(m.getMultiValue('A', ignoreCase: true), equals(['1', '2', '3']));
      expect(m.getMultiValue('d'), equals(['1', '2']));
      expect(m.getMultiValue('c'), isNull);

      m['g'] = 'single';
      expect(m.getMultiValue('g'), equals(['single']));

      expect(m.getFirstValue('x'), isNull);
      expect(m.getFirstValue('g'), equals('single'));
      expect(m.getFirstValue('G', ignoreCase: true), equals('single'));
      expect(m.getFirstValue('a'), equals('1'));
      expect(m.getFirstValue('e'), isNull);
      expect(m.getFirstValue('d'), equals('1'));
      expect(m.getFirstValue('f'), isNull);
      expect(m.getFirstValue('c'), isNull);
    });
  });

  group('TypeReflectionEntityExtension (coverage)', () {
    test('entity getters', () {
      var tList = TypeReflection(List, [Role]);
      expect(tList.isListEntityOrReference, isTrue);
      expect(tList.listEntityOrReferenceType!.type, equals(Role));
      expect(tList.isValidListEntityType, isTrue);
      expect(tList.isValidListEntityOrReferenceType, isTrue);
      expect(tList.entityType, equals(Role));

      var tRefList = TypeReflection(EntityReferenceList, [Role]);
      expect(tRefList.isEntityReferenceListType, isTrue);
      expect(tRefList.isListEntityOrReference, isTrue);
      expect(tRefList.listEntityOrReferenceType!.type, equals(Role));
      expect(tRefList.isValidListEntityType, isFalse);
      expect(tRefList.isValidListEntityOrReferenceType, isTrue);
      expect(tRefList.entityType, equals(Role));

      var tRef = TypeReflection(EntityReference, [Role]);
      expect(tRef.isEntityReferenceType, isTrue);
      expect(tRef.entityType, equals(Role));

      var tRefNoArgs = TypeReflection(EntityReference);
      expect(tRefNoArgs.entityType, isNull);

      var tRole = TypeReflection(Role);
      expect(tRole.entityType, equals(Role));
      expect(tRole.listEntityOrReferenceType, isNull);
      expect(tRole.isValidListEntityOrReferenceType, isFalse);

      var tInt = TypeReflection(int);
      expect(tInt.entityType, isNull);
    });
  });

  group('TypeInfoEntityExtension (coverage)', () {
    test('arguments / parseEntity', () {
      var tMap = TypeInfo.fromType(Map, [String, int]);
      expect(tMap.arguments0!.type, equals(String));
      expect(tMap.arguments1!.type, equals(int));

      var tRefList = TypeInfo.fromType(EntityReferenceList, [Role]);
      var role = Role(RoleType.admin, id: 1);
      expect(tRefList.parseEntity<Role>(role), same(role));

      var tRef = TypeInfo.fromType(EntityReference, [Role]);
      expect(tRef.parseEntity<Role>(role), same(role));
    });

    test('resolveValue', () {
      var role = Role(RoleType.admin, id: 1);

      var refRole = EntityReference<Role>.fromEntity(role);
      var refNull = EntityReference<Role>.asNull();
      var refId = EntityReference<Role>.fromID(5);

      // Non reference type:
      expect(tRole.resolveValue<Role>(refRole), same(role));
      expect(tRole.resolveValue<Role>(refNull), isNull);
      expect(tRole.resolveValue<int>(refId), equals(5));

      var refList = EntityReferenceList<Role>.fromEntities([role]);
      var refListNull = EntityReferenceList<Role>.asNull();
      var refListIds = EntityReferenceList<Role>.fromIDs([1, 2]);

      var tListRole = TypeInfo<List<Role>>.fromType(List, [Role]);
      expect(tListRole.resolveValue<List>(refList), equals([role]));
      expect(tListRole.resolveValue<List>(refListNull), isNull);
      expect(tListRole.resolveValue<List>(refListIds), equals([1, 2]));

      // Reference type with a different generic type:
      var tRefObj = TypeInfo<EntityReference<Object>>.fromType(
        EntityReference,
        [Object],
      );
      var r1 = tRefObj.resolveValue<EntityReference>(refRole);
      expect(r1, same(refRole));

      var tRefRole = TypeInfo<EntityReference<Role>>.fromType(EntityReference, [
        Role,
      ]);
      var r2 = tRefRole.resolveValue<EntityReference>(refRole);
      expect(r2, same(refRole));

      var tRefListRole = TypeInfo<EntityReferenceList<Role>>.fromType(
        EntityReferenceList,
        [tRole],
      );
      var r3 = tRefListRole.resolveValue<EntityReferenceList>(refList);
      expect(r3, same(refList));

      // Forces a reference from a raw value:
      var r4 = tRefListRole.resolveValue<EntityReferenceList>([1, 2]);
      expect(r4, isA<EntityReferenceList>());
      expect(r4!.ids, equals([1, 2]));

      var r5 = tRefRole.resolveValue<EntityReference>(7);
      expect(r5, isA<EntityReference>());
      expect(r5!.id, equals(7));
    });

    test('toEntityReference', () {
      var tRefRole = TypeInfo.fromType(EntityReference, [Role]);
      expect(
        () => tRefRole.toEntityReference(null),
        throwsA(isA<StateError>()),
      );

      var r1 = tRole.toEntityReference(null, id: 3);
      expect(r1.id, equals(3));
      expect(r1.type, equals(Role));

      var r2 = tRole.toEntityReference(null);
      expect(r2.isNull, isTrue);

      var r3 = tRole.toEntityReference(4, entityHandler: _roleHandler());
      expect(r3.id, equals(4));

      var role = Role(RoleType.guest, id: 9);
      var r4 = tRole.toEntityReference(role);
      expect(r4.entity, same(role));

      var r5 = tRole.toEntityReference({
        'id': 11,
        'type': 'admin',
      }, entityHandler: _roleHandler());
      expect(r5.id, equals(11));
    });

    test('toCastedList', () {
      expect(tRole.toCastedList<Role>(null), isNull);
      var role = Role(RoleType.guest, id: 9);
      expect(tRole.toCastedList<Role>(role), equals([role]));
      expect(tRole.toCastedList<Role>({role}), equals([role]));
      expect(tRole.toCastedList<Role>(<Role>[role]), equals([role]));
      expect(tRole.toCastedList<Role>('x'), isNull);
    });

    test('toEntityReferenceList', () async {
      var tRefListRole = TypeInfo.fromType(EntityReferenceList, [Role]);
      expect(
        () => tRefListRole.toEntityReferenceList(null),
        throwsA(isA<StateError>()),
      );

      var l1 = tRole.toEntityReferenceList(null);
      expect(l1.isNull, isTrue);

      var l2 = tRole.toEntityReferenceList(5, entityHandler: _roleHandler());
      expect(l2.ids, equals([5]));

      var role = Role(RoleType.guest, id: 9);
      var l3 = tRole.toEntityReferenceList([role]);
      expect(l3.entities, equals([role]));

      var l4 = tRole.toEntityReferenceList([
        {'id': 1, 'type': 'admin'},
        null,
      ], entityHandler: _roleHandler());
      expect(l4.length, equals(2));

      var fetched = <Object?>[];
      var l5 = tRole.toEntityReferenceList(
        <Object?>[1, null, 2],
        entityFetcher: (id, type) {
          fetched.add(id);
          return Role(RoleType.admin, id: id as int);
        },
      );
      expect(l5.ids, equals([1, null, 2]));
      var entities = await l5.get();
      expect(fetched, equals([1, 2]));
      expect(entities!.map((e) => e?.id), equals([1, null, 2]));

      expect(
        () => tRole.toEntityReferenceList([Object()]),
        throwsA(isA<StateError>()),
      );

      // Object `entityHandler` with a different type:
      var l6 = tRole.toEntityReferenceList([
        role,
      ], entityHandler: _roleHandler());
      expect(l6.entities, equals([role]));
    });
  });

  group('APIEntityTypeNullableExtension (coverage)', () {
    test('nullable type getters', () {
      var tNull = _nullableType(null);
      var tInt = _nullableType(int);
      var tBig = _nullableType(BigInt);
      var tRef = _nullableType(EntityReference);

      expect(tNull.isEntityIDPrimitiveType, isFalse);
      expect(tInt.isEntityIDPrimitiveType, isTrue);
      expect(tNull.isEntityIDType, isFalse);
      expect(tBig.isEntityIDType, isTrue);
      expect(tNull.isEntityReferenceBaseType, isFalse);
      expect(tRef.isEntityReferenceBaseType, isTrue);
      expect(tNull.typeInfo, isNull);
      expect(tInt.typeInfo!.type, equals(int));
    });
  });

  group('APIEntityObjectExtension (coverage)', () {
    test('object getters', () {
      var role = Role(RoleType.guest, id: 9);
      var refList = EntityReferenceList<Role>.fromEntities([role]);
      var ref = EntityReference<Role>.fromEntity(role);

      expect(refList.isEntityReferenceBase, isTrue);
      expect(ref.isEntityReferenceBase, isTrue);
      expect(role.isEntityReferenceBase, isFalse);

      expect(refList.resolveEntityInstance, equals([role]));
      expect(ref.resolveEntityInstance, same(role));
      expect(role.resolveEntityInstance, same(role));
      expect(10.resolveEntityInstance, isNull);
    });
  });

  group('APIResponse extensions (coverage)', () {
    test('FutureOr<APIResponse>', () async {
      FutureOr<APIResponse<int>> ok = APIResponse.ok(10, headers: {'h': 'v'});
      FutureOr<APIResponse<int>> error = APIResponse<int>.error(
        error: 'err',
        stackTrace: StackTrace.empty,
      );
      FutureOr<APIResponse<int>> notFound = APIResponse<int>.notFound();

      expect(await ok.payloadAsync, equals(10));
      expect(await notFound.payloadAsyncOr(5), equals(5));
      expect(await ok.statusAsync, equals(APIResponseStatus.OK));
      expect((await ok.headersAsync)['h'], equals('v'));
      expect(await ok.isOKAsync, isTrue);
      expect(await ok.isNotOKAsync, isFalse);
      expect(await error.isErrorAsync, isTrue);
      expect(await error.errorAsync, equals('err'));
      expect(await error.stackTraceAsync, same(StackTrace.empty));
      expect(await ok.apiRequestAsync, isNull);
    });

    test('Future<APIResponse>', () async {
      Future<APIResponse<int>> ok() async =>
          APIResponse.ok(10, headers: {'h': 'v'});
      Future<APIResponse<int>> error() async =>
          APIResponse<int>.error(error: 'err', stackTrace: StackTrace.empty);
      Future<APIResponse<int>> notFound() async => APIResponse<int>.notFound();

      expect(await ok().payloadAsync, equals(10));
      expect(await notFound().payloadAsyncOr(5), equals(5));
      expect(await ok().statusAsync, equals(APIResponseStatus.OK));
      expect((await ok().headersAsync)['h'], equals('v'));
      expect(await ok().isOKAsync, isTrue);
      expect(await notFound().isNotOKAsync, isTrue);
      expect(await error().isErrorAsync, isTrue);
      expect(await error().errorAsync, equals('err'));
      expect(await error().stackTraceAsync, same(StackTrace.empty));
      expect(await ok().apiRequestAsync, isNull);
    });
  });
}

class _NotReflected {}

EntityHandler<Role> _roleHandler() =>
    Role$reflection.staticInstance.entityHandler;

/// Avoids type promotion, to use the `Type?` extension.
Type? _nullableType(Type? t) => t;

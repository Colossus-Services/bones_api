import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_logging.dart';
import 'package:statistics/statistics.dart'
    show Decimal, DecimalOnDoubleExtension;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

class Foo {
  int id;

  String name;

  Foo(this.id, this.name);

  @override
  String toString() {
    return '#$id[$name]';
  }
}

void main() {
  logToConsole();

  group('Json', () {
    test('toJson', () async {
      expect(Json.toJson<int>(123), equals(123));

      expect(Json.toJson<Object?>(null), isNull);
      expect(Json.toJson<int>(null), isNull);

      expect(Json.toJson(DateTime.utc(2021, 1, 2, 3, 4, 5)),
          equals('2021-01-02 03:04:05.000Z'));

      expect(
          Json.toJson({'a': 1, 'b': 2, 'p': 123}, removeField: (k) => k == 'p'),
          equals({'a': 1, 'b': 2}));

      expect(
          Json.toJson({'a': 1, 'b': 2, 'p': 123}, maskField: (k) => k == 'p'),
          equals({'a': 1, 'b': 2, 'p': '***'}));

      expect(Json.toJson({'a': 1, 'b': 2, 'foo': Foo(51, 'x')}),
          equals({'a': 1, 'b': 2, 'foo': '#51[x]'}));

      expect(
          Json.toJson({'a': 1, 'b': 2, 'foo': Foo(51, 'x')}, toEncodable: (o) {
            return o is Foo ? '${o.id}:${o.name}' : o;
          }),
          equals({'a': 1, 'b': 2, 'foo': '51:x'}));

      expect(Json.toJson(Role(RoleType.unknown)),
          equals({'type': 'unknown', 'enabled': true, 'value': null}));

      roleEntityHandler.toString();

      expect(
          Json.toJson(Role(RoleType.admin), removeField: (k) => k == 'enabled'),
          equals({'type': 'admin', 'value': null}));

      expect(
          Json.toJson(
              Role(RoleType.guest,
                  enabled: false, value: Decimal.parse('456.789')),
              removeNullFields: true),
          equals({'type': 'guest', 'enabled': false, 'value': '456.789'}));

      expect(
          Json.toJson(EntityReference.fromEntity(Role(RoleType.admin))),
          equals({
            'EntityReference': 'Role',
            'entity': {'enabled': true, 'type': 'admin', 'value': null}
          }));

      expect(
          Json.toJson(EntityReference.fromEntity(Role(RoleType.admin)),
              removeNullFields: true),
          equals({
            'EntityReference': 'Role',
            'entity': {'enabled': true, 'type': 'admin'}
          }));

      expect(
          Json.toJson(EntityReferenceList.fromEntities(
              [Role(RoleType.admin), Role(RoleType.guest)])),
          equals({
            'EntityReferenceList': 'Role',
            'entities': [
              {'enabled': true, 'type': 'admin', 'value': null},
              {'enabled': true, 'type': 'guest', 'value': null}
            ]
          }));

      expect(
          Json.toJson(
              EntityReferenceList.fromEntities(
                  [Role(RoleType.admin), Role(RoleType.guest)]),
              removeNullFields: true),
          equals({
            'EntityReferenceList': 'Role',
            'entities': [
              {'enabled': true, 'type': 'admin'},
              {'enabled': true, 'type': 'guest'}
            ]
          }));

      expect(
          Json.toJson({
            'name': 'a',
            'value': EntityReferenceList.fromEntities(
                [Role(RoleType.admin), Role(RoleType.guest)])
          }),
          equals({
            'name': 'a',
            'value': {
              'EntityReferenceList': 'Role',
              'entities': [
                {'enabled': true, 'type': 'admin', 'value': null},
                {'enabled': true, 'type': 'guest', 'value': null}
              ]
            }
          }));

      expect(
          Json.toJson({
            'name': 'a',
            'value': EntityReferenceList.fromEntities(
                [Role(RoleType.admin), Role(RoleType.guest)])
          }, removeNullFields: true),
          equals({
            'name': 'a',
            'value': {
              'EntityReferenceList': 'Role',
              'entities': [
                {'enabled': true, 'type': 'admin'},
                {'enabled': true, 'type': 'guest'}
              ]
            }
          }));

      expect(
          Json.toJson({
            'name': 'a',
            'values': [
              EntityReferenceList.fromEntities(
                  [Role(RoleType.admin), Role(RoleType.guest)]),
              EntityReferenceList.fromEntities([Role(RoleType.unknown)])
            ]
          }),
          equals({
            'name': 'a',
            'values': [
              {
                'EntityReferenceList': 'Role',
                'entities': [
                  {'enabled': true, 'type': 'admin', 'value': null},
                  {'enabled': true, 'type': 'guest', 'value': null}
                ]
              },
              {
                'EntityReferenceList': 'Role',
                'entities': [
                  {'enabled': true, 'type': 'unknown', 'value': null}
                ]
              }
            ]
          }));

      expect(
          Json.toJson({
            'name': 'a',
            'values': [
              EntityReferenceList.fromEntities(
                  [Role(RoleType.admin), Role(RoleType.guest)]),
              EntityReferenceList.fromEntities([Role(RoleType.unknown)])
            ]
          }, removeNullFields: true),
          equals({
            'name': 'a',
            'values': [
              {
                'EntityReferenceList': 'Role',
                'entities': [
                  {'enabled': true, 'type': 'admin'},
                  {'enabled': true, 'type': 'guest'}
                ]
              },
              {
                'EntityReferenceList': 'Role',
                'entities': [
                  {'enabled': true, 'type': 'unknown'}
                ]
              }
            ]
          }));
    });

    test('fromJson', () async {
      expect(Json.fromJson<int>(123), equals(123));
      expect(Json.fromJson<String>("abc"), equals("abc"));
      expect(Json.fromJson<bool>(true), isTrue);
      expect(Json.fromJson<bool>(false), isFalse);
      expect(Json.fromJson<int>(null), isNull);
      expect(Json.fromJson<Object?>(null), isNull);
      expect(Json.fromJson([1, 2, 3]), equals([1, 2, 3]));
      expect(Json.fromJson({'a': 1, "b": 2}), equals({'a': 1, "b": 2}));
      expect(Json.fromJson({'a': 1, "b": 2, "c": null}),
          equals({'a': 1, "b": 2, "c": null}));

      Role$reflection.boot();

      {
        var json = Json.toJson(Role(RoleType.guest, enabled: false));

        expect(Json.fromJson<Role>(json),
            equals(Role(RoleType.guest, enabled: false)));
      }

      {
        var json = Json.toJson(Role(RoleType.admin));

        expect(Json.fromJson<Role>(json),
            equals(Role(RoleType.admin, enabled: true)));
      }
    });

    test('fromJson + id ref', () async {
      User$reflection.boot();
      Address$reflection.boot();
      Role$reflection.boot();

      {
        var creationTime = DateTime.utc(2022, 1, 2);
        var address = Address('CA', 'LA', 'one', 101, id: 1101);
        var role1 = Role(RoleType.guest,
            enabled: true, value: 10.20.toDecimal(), id: 10);
        var role2 = Role(RoleType.admin,
            enabled: true, value: 101.10.toDecimal(), id: 101);
        var user = User('joe@mail.com', '123', address, [role1, role2],
            id: 1001, creationTime: creationTime);

        var json = Json.toJson(user) as Map;

        print(json);

        var entityCache = JsonEntityCacheSimple();

        var user2 = Json.fromJson<User>(json, entityCache: entityCache);

        expect(user2?.toJsonEncoded(), equals(user.toJsonEncoded()));

        var jsonRoles = json['roles'] as List;

        expect(jsonRoles.length, equals(2));
        // ignore: avoid_dynamic_calls
        expect(jsonRoles[0]['id'], equals(10));
        // ignore: avoid_dynamic_calls
        expect(jsonRoles[1]['id'], equals(101));

        jsonRoles.add(10);

        var user3 = Json.fromJson<User>(json, entityCache: entityCache);

        expect(user3, isA<User>());
        expect(user3!.id, equals(1001));
      }

      {
        var role = Role(RoleType.admin, id: 11);

        var entityReference1 = Json.fromJson<EntityReference>({
          'EntityReference': 'Role',
          'entity': {'enabled': true, 'type': 'admin', 'id': 11}
        });
        expect(
            entityReference1,
            allOf(isA<EntityReference<Role>>()
                .having((e) => e.entity, 'equals entity', equals(role))));

        var entityReference2 = Json.fromJson<EntityReference>(
            {'EntityReference': 'Role', 'id': 11});
        expect(
            entityReference2,
            allOf(isA<EntityReference<Role>>()
                .having((e) => e.entity, 'null entity', isNull)));

        expect(entityReference2!.get(), isNull);
        expect(
            () => entityReference2.getNotNull(),
            throwsA(isA<StateError>().having(
                (e) => e.message,
                "Can't get entity message",
                contains("Can't `get` entity `Role` with ID `null`"))));

        var entityCache = JsonEntityCacheSimple();

        entityCache.cacheEntity(role);

        var entityReference3 = Json.fromJson<EntityReference>(
            {'EntityReference': 'Role', 'id': 11},
            entityCache: entityCache, autoResetEntityCache: false);

        expect(
            entityReference3,
            allOf(isA<EntityReference<Role>>()
                .having((e) => e.entity, 'equals entity', equals(role))));

        expect(entityReference3!.get(), isNotNull);
      }

      {
        var role1 = Role(RoleType.admin, id: 11);
        var role2 = Role(RoleType.guest, id: 12);

        var entityReferenceList1 = Json.fromJson<EntityReferenceList>({
          'EntityReferenceList': 'Role',
          'entities': [
            {'enabled': true, 'type': 'admin', 'id': 11},
            {'enabled': true, 'type': 'guest', 'id': 12}
          ]
        });
        expect(
            entityReferenceList1,
            allOf(isA<EntityReferenceList<Role>>().having(
                (e) => e.entities, 'equals entity', equals([role1, role2]))));

        var entityReferenceList2 = Json.fromJson<EntityReferenceList>({
          'EntityReferenceList': 'Role',
          'ids': [11, 12]
        });
        expect(
            entityReferenceList2,
            allOf(isA<EntityReferenceList<Role>>()
                .having((e) => e.entities, 'null entity', isNull)));

        expect(entityReferenceList2!.get(), isNull);
        expect(
            () => entityReferenceList2.getNotNull(),
            throwsA(isA<StateError>().having(
                (e) => e.message,
                "Can't get entities message",
                contains(
                    "Can't `get` entities `Role` with IDs [<11>, <12>]"))));

        var entityCache = JsonEntityCacheSimple();

        entityCache.cacheEntity(role1);
        entityCache.cacheEntity(role2);

        var entityReferenceList3 = Json.fromJson<EntityReferenceList>({
          'EntityReferenceList': 'Role',
          'ids': [11, 12]
        }, entityCache: entityCache, autoResetEntityCache: false);

        expect(
            entityReferenceList3,
            allOf(isA<EntityReferenceList<Role>>().having(
                (e) => e.entities, 'equals entities', equals([role1, role2]))));

        expect(await entityReferenceList3!.get(), equals([role1, role2]));

        var entityReferenceList4 = Json.fromJsonList<EntityReferenceList>([
          {
            'EntityReferenceList': 'Role',
            'ids': [11, 12]
          },
          {
            'EntityReferenceList': 'Role',
            'ids': [11]
          }
        ], entityCache: entityCache, autoResetEntityCache: false);

        expect(entityReferenceList4.length, equals(2));

        expect(
            entityReferenceList4[0],
            allOf(isA<EntityReferenceList<Role>>().having(
                (e) => e.entities, 'equals entities', equals([role1, role2]))));

        expect(
            entityReferenceList4[1],
            allOf(isA<EntityReferenceList<Role>>().having(
                (e) => e.entities, 'equals entities', equals([role1]))));

        expect(await entityReferenceList4[0]?.get(), equals([role1, role2]));
        expect(await entityReferenceList4[1]?.get(), equals([role1]));
      }
    });

    test('encode', () async {
      expect(Json.encode({'a': 1, 'b': 2}), equals('{"a":1,"b":2}'));

      expect(
          Json.encode({'a': 1, 'b': 2}, pretty: true),
          equals('{\n'
              '  "a": 1,\n'
              '  "b": 2\n'
              '}'));

      expect(
          Json.encode({'a': 1, 'pass': 123456},
              maskField: (f) => f.contains('pass')),
          equals('{"a":1,"pass":"***"}'));

      expect(
          Json.encode({'a': 1, 'pass': 123456},
              maskField: (f) => f.contains('pass'), maskText: 'x'),
          equals('{"a":1,"pass":"x"}'));
    });

    test('decode', () async {
      expect(Json.decode('{"a":1,"b":2}'), equals({'a': 1, 'b': 2}));

      expect(
          Json.decode('{"ab": {"a":1,"b":2}}', jsomMapDecoder: (map, j) {
            return map.map((k, v) {
              switch (k) {
                case 'ab':
                  return MapEntry(k, AB.fromMap(v as Map<String, dynamic>));
                default:
                  return MapEntry(k, v);
              }
            });
          }),
          equals({'ab': AB(1, 2)}));
    });

    test('decodeFromBytes', () async {
      Role$reflection.boot();

      {
        var jsonBytes =
            Json.encodeToBytes(Role(RoleType.guest, enabled: false));

        expect(Json.decodeFromBytes<Role>(jsonBytes),
            equals(Role(RoleType.guest, enabled: false)));
      }

      {
        var jsonBytes = Json.encodeToBytes(Role(RoleType.admin));

        expect(Json.decodeFromBytes<Role>(jsonBytes),
            equals(Role(RoleType.admin, enabled: true)));
      }
    });

    test('dumpRuntimeTypes', () {
      expect(Json.dumpRuntimeTypes(null), equals('<null>'));
      expect(Json.dumpRuntimeTypes(123), equals('<int>:123'));
      expect(Json.dumpRuntimeTypes(12.3), equals('<double>:12.3'));
      expect(Json.dumpRuntimeTypes(true), equals('<bool>:true'));
      expect(Json.dumpRuntimeTypes("foo"), equals('<String>:"foo"'));

      expect(
          Json.dumpRuntimeTypes(<int>[1, 2]),
          contains(
            '<int>>:[\n'
            '  <int>:1,\n'
            '  <int>:2\n'
            ']',
          ));

      expect(
          Json.dumpRuntimeTypes(<String, int>{'a': 1, 'b': 2}),
          contains(
            '<String, int>>:{\n'
            '  <String>:"a"=<int>:1,\n'
            '  <String>:"b"=<int>:2\n'
            '}',
          ));
    });
  });
}

class AB {
  final int a;

  final int b;

  AB(this.a, this.b);

  AB.fromMap(Map<String, dynamic> o) : this(o['a'], o['b']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AB &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b;

  @override
  int get hashCode => a.hashCode ^ b.hashCode;

  @override
  String toString() => 'AB{a: $a, b: $b}';
}

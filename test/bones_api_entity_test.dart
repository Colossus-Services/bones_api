@Tags(['entities'])
import 'package:bones_api/bones_api.dart';
import 'package:statistics/statistics.dart' show Decimal;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

class APIEntityRepositoryProvider extends EntityRepositoryProvider {
  static final APIEntityRepositoryProvider _instance =
      APIEntityRepositoryProvider._();

  factory APIEntityRepositoryProvider() => _instance;

  late final MemorySQLAdapter sqlAdapter;

  late final SQLEntityRepository<Store> storeSQLRepository;
  late final SQLEntityRepository<Address> addressSQLRepository;
  late final SQLEntityRepository<Role> roleSQLRepository;
  late final SQLEntityRepository<User> userSQLRepository;

  late final AddressAPIRepository addressAPIRepository;
  late final UserAPIRepository userAPIRepository;

  APIEntityRepositoryProvider._() {
    sqlAdapter = MemorySQLAdapter(parentRepositoryProvider: this)
      ..addTableSchemes([
        TableScheme('user', idFieldName: 'id', fieldsTypes: {
          'id': int,
          'email': String,
          'password': String,
          'address': int,
          'creation_time': DateTime,
        }, fieldsReferencedTables: {
          'address':
              TableFieldReference('user', 'address', int, 'address', 'id', int)
        }, relationshipTables: [
          TableRelationshipReference('user__roles__rel', 'user', 'id', int,
              'user_id', 'role', 'id', int, 'role_id')
        ]),
        TableScheme(
          'address',
          idFieldName: 'id',
          fieldsTypes: {
            'id': int,
            'state': String,
            'city': String,
            'street': String,
            'number': int,
          },
          relationshipTables: [
            TableRelationshipReference('address__stores__rel', 'address', 'id',
                int, 'address_id', 'store', 'id', int, 'store_id'),
            TableRelationshipReference('address__closed_stores__rel', 'address',
                'id', int, 'address_id', 'store', 'id', int, 'store_id')
          ],
        ),
        TableScheme(
          'store',
          idFieldName: 'id',
          fieldsTypes: {
            'id': int,
            'name': String,
            'number': int,
          },
        ),
        TableScheme(
          'role',
          idFieldName: 'id',
          fieldsTypes: {
            'id': int,
            'type': String,
            'enabled': bool,
            'value': Decimal,
          },
        )
      ]);

    storeSQLRepository =
        SQLEntityRepository<Store>(sqlAdapter, 'store', storeEntityHandler)
          ..ensureInitialized();

    addressSQLRepository = SQLEntityRepository<Address>(
        sqlAdapter, 'address', addressEntityHandler)
      ..ensureInitialized();

    roleSQLRepository =
        SQLEntityRepository<Role>(sqlAdapter, 'role', roleEntityHandler)
          ..ensureInitialized();

    userSQLRepository =
        SQLEntityRepository<User>(sqlAdapter, 'user', userEntityHandler)
          ..ensureInitialized();

    addressAPIRepository = AddressAPIRepository(this)..ensureConfigured();

    userAPIRepository = UserAPIRepository(this)..ensureConfigured();
  }
}

void main() {
  group('Entity', () {
    late final SetEntityRepository<Store> storeRepository;
    late final SetEntityRepository<Address> addressRepository;
    late final SetEntityRepository<Role> roleRepository;
    late final SetEntityRepository<User> userRepository;

    setUpAll(() {
      storeRepository = SetEntityRepository<Store>('store', storeEntityHandler);
      storeRepository.ensureInitialized();

      addressRepository =
          SetEntityRepository<Address>('address', addressEntityHandler);
      addressRepository.ensureInitialized();

      roleRepository = SetEntityRepository<Role>('role', roleEntityHandler);
      roleRepository.ensureInitialized();

      userRepository = SetEntityRepository<User>('user', userEntityHandler);
      userRepository.ensureInitialized();
    });

    tearDownAll(() {
      addressRepository.close();
      userRepository.close();
      storeRepository.close();
      roleRepository.close();
    });

    test('basic', () async {
      var user1 = User(
          'joe@mail.com',
          '123',
          Address('NY', 'New York', 'Fifth Avenue', 101),
          [Role(RoleType.admin)],
          level: 10,
          creationTime: DateTime.utc(2020, 10, 11, 12, 13, 14, 0, 0));
      var user2 = User(
          'smith@mail.com',
          'abc',
          Address('CA', 'Los Angeles', 'Hollywood Boulevard', 404,
              stores: [Store('s1', 1)], closedStores: [Store('s2', 2)]),
          [Role(RoleType.guest, value: Decimal.parse('12345.678'))],
          wakeUpTime: Time(12, 13, 14, 150),
          creationTime: DateTime.utc(2021, 10, 11, 12, 13, 14, 0, 0));
      var user3 = User(
          'john@mail.com',
          '456',
          Address('CA', 'Los Angeles', 'Hollywood Boulevard', 101,
              stores: [Store('s1', 1)]),
          [],
          wakeUpTime: Time(0, 13, 14, 150),
          creationTime: DateTime.utc(2021, 10, 12, 12, 13, 14, 0, 0));

      var user1Json =
          '{"email":"joe@mail.com","password":"123","address":{"state":"NY","city":"New York","street":"Fifth Avenue","number":101,"stores":[],"closedStores":[]},"roles":[{"enabled":true,"type":"admin"}],"level":10,"creationTime":"2020-10-11 12:13:14.000Z"}';
      var user2Json =
          '{"email":"smith@mail.com","password":"abc","address":{"state":"CA","city":"Los Angeles","street":"Hollywood Boulevard","number":404,"stores":[{"name":"s1","number":1}],"closedStores":[{"name":"s2","number":2}]},"roles":[{"enabled":true,"type":"guest","value":"12345.678"}],"wakeUpTime":"12:13:14.150","creationTime":"2021-10-11 12:13:14.000Z"}';
      var user3Json =
          '{"email":"john@mail.com","password":"456","address":{"state":"CA","city":"Los Angeles","street":"Hollywood Boulevard","number":101,"stores":[{"name":"s1","number":1}],"closedStores":[]},"roles":[],"wakeUpTime":"00:13:14.150","creationTime":"2021-10-12 12:13:14.000Z"}';

      addressEntityHandler.inspectObject(user1.address);
      roleEntityHandler.inspectObject(user1.roles.first);
      userEntityHandler.inspectObject(user1);

      expect(userEntityHandler.encodeJson(user1), equals(user1Json));
      expect(userEntityHandler.decodeJson(user1Json), equals(user1));
      expect(userEntityHandler.decodeJson(user1Json), equals(user1));

      expect(userEntityHandler.decodeObjectJson(user1Json), equals(user1));

      expect(userEntityHandler.encodeObjectJson(user2), equals(user2Json));

      expect(userEntityHandler.encodeObjectJson(user3), equals(user3Json));

      var user1b = userEntityHandler.decodeObjectJson(user1Json);

      expect(user1b, equals(user1));

      await userEntityHandler.setFieldsFromMap(user1b, user2.toJson());
      expect(user1b, equals(user2));
    });

    test('basic', () async {
      var user1 = User(
          'joe@mail.com',
          '123',
          Address('NY', 'New York', 'Fifth Avenue', 101),
          [Role(RoleType.admin)],
          creationTime: DateTime.utc(2020, 10, 11, 12, 13, 14, 0, 0));
      var user2 = User(
          'smith@mail.com',
          'abc',
          Address('CA', 'Los Angeles', 'Hollywood Boulevard', 404),
          [Role(RoleType.guest)],
          creationTime: DateTime.utc(2021, 10, 11, 12, 13, 14, 0, 0));

      var reflectionEntityHandler = user1.reflection.entityHandler;
      print(reflectionEntityHandler);
      expect(reflectionEntityHandler, isNotNull);

      expect(identical(reflectionEntityHandler, user2.reflection.entityHandler),
          isTrue);
    });

    test('SetEntityRepository', () async {
      expect(userRepository.nextID(), equals(1));
      expect(userRepository.selectByID(1), isNull);

      var user1Time = DateTime.utc(2019, 1, 2, 3, 4, 5);
      var user2Time = DateTime.utc(2019, 12, 2, 3, 4, 5);
      var user3Time = DateTime.utc(2019, 13, 2, 3, 4, 5);

      var user1 = User(
          'joe@setl.com',
          '123',
          Address('NY', 'New York', 'Fifth Avenue', 101),
          [Role(RoleType.admin)],
          creationTime: user1Time);
      var user2 = User(
          'smith@setl.com',
          'abc',
          Address('CA', 'Los Angeles', 'Hollywood Boulevard', 404),
          [Role(RoleType.guest, value: Decimal.parse('1234.67'))],
          creationTime: user2Time);
      var user3 = User('john@setl.com', '456',
          Address('CA', 'Los Angeles', 'Hollywood Boulevard', 101), [],
          creationTime: user3Time);

      expect(await userRepository.selectAll(), isEmpty);

      userRepository.store(user1);
      expect((await userRepository.selectAll()).length, equals(1));

      userRepository.store(user2);
      expect((await userRepository.selectAll()).length, equals(2));

      userRepository.store(user3);

      var user1Json = user1.toJsonEncoded();
      var user2Json = user2.toJsonEncoded();
      var user3Json = user3.toJsonEncoded();

      expect(userRepository.nextID(), equals(4));

      expect(userRepository.selectByID(1)!.toJsonEncoded(), equals(user1Json));

      expect(
          userRepository
              .select(Condition.parse('email == "joe@setl.com"'))
              .map((e) => e.toJsonEncoded()),
          equals([user1Json]));

      expect(
          userRepository
              .select(Condition.parse('email != "smith@setl.com"'))
              .map((e) => e.toJsonEncoded()),
          equals([user1Json, user3Json]));

      expect(
          userRepository
              .select(Condition.parse(' email != "joe@setl.com" '))
              .map((e) => e.toJsonEncoded()),
          equals([user2Json, user3Json]));

      expect(userRepository.select(Condition.parse('email == "foo@setl.com"')),
          isEmpty);

      expect(
          userRepository
              .select(Condition.parse('email != "foo@setl.com"'))
              .map((e) => e.toJsonEncoded()),
          equals([user1Json, user2Json, user3Json]));

      expect(
          userRepository
              .selectByQuery('address.state == ?', parameters: ['NY']),
          equals([user1]));

      expect(
          userRepository
              .selectByQuery('address.state == ?#0', parameters: ['NY']),
          equals([user1]));

      expect(
          userRepository
              .selectByQuery('address.state == ?#', parameters: ['NY']),
          equals([user1]));

      expect(
          userRepository
              .selectByQuery('address.state == ?', parameters: {'state': 'CA'}),
          equals([user2, user3]));

      expect(
          userRepository.selectByQuery('address.state == ?:the_state',
              parameters: {'the_state': 'CA'}),
          equals([user2, user3]));

      expect(
          userRepository.selectByQuery('address.state == ?:',
              parameters: {'state': 'CA'}),
          equals([user2, user3]));

      expect(
          (await userRepository.selectByQuery('address.state == ?',
                  parameters: {'state': 'FL'}))
              .map((e) => e.toJsonEncoded()),
          isEmpty);

      {
        var del =
            await userRepository.deleteByQuery(' #ID == ? ', parameters: [2]);
        var user = del.first;
        expect(user.email, equals('smith@setl.com'));
        expect(user.address.state, equals('CA'));
        expect(user.creationTime, equals(user2Time));
      }

      expect(userRepository.length(), equals(2));

      {
        var user = userRepository.selectByID(2);
        expect(user, isNull);
      }
    });
  });

  group('SQLEntityRepository[memory]', () {
    setUpAll(() {
      APIEntityRepositoryProvider();
    });

    test('store, selectByID, selectByQuery', () async {
      var addressSQLRepository =
          APIEntityRepositoryProvider().addressSQLRepository;
      var userSQLRepository = APIEntityRepositoryProvider().userSQLRepository;

      expect(await userSQLRepository.length(), equals(0));

      {
        var user = await userSQLRepository.selectByID(1);
        expect(user, isNull);
      }

      {
        var del = await userSQLRepository.deleteByQuery(' email == "foo" ');
        expect(del, isEmpty);
      }

      var user1Time = DateTime.utc(2020, 1, 2, 3, 4, 5);

      {
        var address = Address('NY', 'New York', 'street A', 101);
        var user = User(
            'joe@memory.com', '123', address, [Role(RoleType.admin)],
            creationTime: user1Time);
        var id = await userSQLRepository.store(user);
        expect(id, equals(1));
      }

      var user2Time = DateTime.utc(2021, 1, 2, 3, 4, 5);

      {
        var address = Address('CA', 'Los Angeles', 'street B', 201);

        var user = User('smith@memory.com', 'abc', address,
            [Role(RoleType.guest, value: Decimal.parse('1234.6789'))],
            creationTime: user2Time);
        var id = await userSQLRepository.store(user);
        expect(id, equals(2));
      }

      expect(await addressSQLRepository.count(), equals(2));
      expect(await userSQLRepository.count(), equals(2));

      expect(
          await userSQLRepository
              .countByQuery(' email == ? ', parameters: ['smith@memory.com']),
          equals(1));

      {
        var user = await userSQLRepository.selectByID(1);
        expect(user!.email, equals('joe@memory.com'));
        expect(user.address.state, equals('NY'));
        expect(
            user.roles.map((e) => e.toJson()),
            equals([
              {'enabled': true, 'id': 1, 'type': 'admin', 'value': null}
            ]));
        expect(user.creationTime, equals(user1Time));
      }

      {
        var user = await userSQLRepository.selectByID(2);
        expect(user!.email, equals('smith@memory.com'));
        expect(user.address.state, equals('CA'));
        expect(
            user.roles.map((e) => e.toJson()),
            equals([
              {'id': 2, 'type': 'guest', 'enabled': true, 'value': '1234.6789'}
            ]));
        expect(user.creationTime, equals(user2Time));
      }

      {
        var user = await userSQLRepository.selectByID(3000);
        expect(user, isNull);
      }

      {
        var sel = await userSQLRepository
            .selectByQuery(' email == ? ', parameters: ['joe@memory.com']);
        var user = sel.first;
        expect(user.email, equals('joe@memory.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userSQLRepository.selectByQuery(' email == ? ',
            parameters: {'email': 'smith@memory.com'});
        var user = sel.first;
        expect(user.email, equals('smith@memory.com'));
        expect(user.address.state, equals('CA'));
      }

      {
        var sel = await userSQLRepository
            .selectByQuery(' address.state == ?:st ', parameters: {'st': 'NY'});
        var user = sel.first;
        expect(user.email, equals('joe@memory.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userSQLRepository
            .selectByQuery('roles.type == ? ', parameters: ['admin']);

        var user = sel.first;
        print(user.toJson());

        expect(user.email, equals('joe@memory.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userSQLRepository
            .selectByQuery('roles.type == ? ', parameters: ['guest']);

        var user = sel.first;
        print(user.toJson());

        expect(user.email, equals('smith@memory.com'));
        expect(user.address.state, equals('CA'));
      }
    });
  });

  group('APIRepository', () {
    setUpAll(() {
      APIEntityRepositoryProvider();
    });

    tearDownAll(() {
      APIEntityRepositoryProvider().close();
    });

    test('selectByEmail, selectByAddressState, selectByState', () async {
      var userAPIRepository = APIEntityRepositoryProvider().userAPIRepository;
      var addressAPIRepository =
          APIEntityRepositoryProvider().addressAPIRepository;

      expect(await addressAPIRepository.length(), equals(2));
      expect(await userAPIRepository.length(), equals(2));

      // User:

      {
        var user = await userAPIRepository.selectByID(1);
        expect(user!.id, equals(1));
        expect(user.email, equals('joe@memory.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var user = await userAPIRepository.selectByEmail('joe@memory.com');
        expect(user!.email, equals('joe@memory.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userAPIRepository.selectByAddressState('CA');
        var user = sel.first;
        expect(user.email, equals('smith@memory.com'));
        expect(user.address.state, equals('CA'));
      }

      {
        var user = await userAPIRepository.selectByEmail('XX');
        expect(user, isNull);
      }

      {
        var sel = await addressAPIRepository
            .deleteByQuery(' state == ? ', parameters: ['ZZ']);
        expect(sel, isEmpty);
      }

      {
        var sel = await userAPIRepository.selectByAddressState('XX');
        expect(sel, isEmpty);
      }

      // Address:
      {
        var count = await addressAPIRepository.length();
        expect(count, equals(2));
      }

      {
        var address = await addressAPIRepository.selectByID(2);
        expect(address!.id, equals(2));
        expect(address.state, equals('CA'));
        expect(address.city, equals('Los Angeles'));

        var sel2 = await addressAPIRepository.selectByQuery(' #ID == 2 ');
        var address2 = sel2.first;
        expect(address2.toJson(), equals(address.toJson()));

        var sel3 = await addressAPIRepository
            .selectByQuery(' #ID == ? ', parameters: [2]);
        var address3 = sel3.first;
        expect(address3.toJson(), equals(address.toJson()));

        var sel4 = await addressAPIRepository
            .selectByQuery(' #ID == ?:theId ', parameters: {'theId': 2});
        var address4 = sel4.first;
        expect(address4.toJson(), equals(address.toJson()));
      }

      {
        var sel = await addressAPIRepository.selectByState('CA');
        var address = sel.first;
        expect(address.state, equals('CA'));
        expect(address.city, equals('Los Angeles'));
      }

      {
        var sel = await addressAPIRepository.selectByState('XX');
        expect(sel, isEmpty);
      }

      // Add User:
      {
        var address = Address('FL', 'Miami', 'Ocean Drive', 11);
        var user = User(
          'mary@memory.com',
          'xyz',
          address,
          [Role(RoleType.guest, value: Decimal.parse('2345.67'))],
        );
        var id = await userAPIRepository.store(user);
        expect(id, equals(3));
      }

      {
        var sel = await userAPIRepository.selectByAddressState('FL');
        var user = sel.first;

        expect(user.email, equals('mary@memory.com'));
        expect(user.address.state, equals('FL'));
        expect(
            user.roles.map((e) => e.toJson()),
            equals([
              {'id': 3, 'type': 'guest', 'enabled': true, 'value': '2345.67'}
            ]));
      }

      {
        var user = await userAPIRepository.selectByEmail('mary@memory.com');

        expect(user!.email, equals('mary@memory.com'));
        expect(user.address.state, equals('FL'));

        user.email = 'mary2@memory.com';

        expect(await userAPIRepository.store(user), equals(user.id));

        var user2 = await userAPIRepository.selectByEmail('mary2@memory.com');

        expect(user2!.email, equals('mary2@memory.com'));
        expect(user2.address.state, equals('FL'));
      }

      {
        var user = await userAPIRepository.selectByEmail('mary2@memory.com');

        expect(user!.email, equals('mary2@memory.com'));
        expect(user.address.state, equals('FL'));

        user.roles.add(Role(RoleType.unknown));

        expect(await userAPIRepository.store(user), equals(user.id));

        var user2 = await userAPIRepository.selectByID(user.id);
        expect(user2!.email, equals('mary2@memory.com'));
        expect(
            user2.roles.map((e) => e.toJson()),
            equals([
              {'id': 3, 'type': 'guest', 'enabled': true, 'value': '2345.67'},
              {'id': 4, 'type': 'unknown', 'enabled': true, 'value': null}
            ]));

        user2.roles.removeWhere((r) => r.type == RoleType.guest);
        expect(await userAPIRepository.store(user2), equals(user.id));

        var user3 = await userAPIRepository.selectByID(user.id);
        expect(user3!.email, equals('mary2@memory.com'));
        expect(
            user3.roles.map((e) => e.toJson()),
            equals([
              {'id': 4, 'type': 'unknown', 'enabled': true, 'value': null}
            ]));
      }

      // Del User:

      {
        var count = await userAPIRepository.length();
        expect(count, equals(3));
      }

      {
        var del = await userAPIRepository
            .deleteByQuery(' email == ? ', parameters: ['smith@memory.com']);
        var user = del.first;
        expect(user.email, equals('smith@memory.com'));
        expect(user.address.state, equals('CA'));
      }

      {
        var count = await userAPIRepository.length();
        expect(count, equals(2));
      }

      // Del Address:

      {
        var count = await addressAPIRepository.length();
        expect(count, equals(3));
      }

      {
        var del = await addressAPIRepository
            .deleteByQuery(' state == ? ', parameters: ['CA']);
        var address = del.first;
        expect(address.state, equals('CA'));
        expect(address.city, equals('Los Angeles'));
      }

      {
        var count = await addressAPIRepository.length();
        expect(count, equals(2));
      }

      // Transaction:

      {
        var t = Transaction();
        await t.execute(() async {
          var address = Address('TX', 'Austin', 'Main street', 22);
          var user = User(
            'bill@memory.com',
            'txs',
            address,
            [Role(RoleType.guest)],
          );
          var id = await userAPIRepository.store(user);
          expect(id, equals(4));

          expect(t.isExecuting, isTrue);

          var count = await userAPIRepository.length();
          expect(count, equals(3));

          var del = await userAPIRepository
              .deleteByQuery(' #ID == ? ', parameters: [id]);
          var delUser = del.first;
          expect(delUser.id, equals(4));
        });

        expect(t.isCommitted, isTrue);
        expect(t.length, equals(10));
        expect(t.isExecuting, isFalse);
        expect((t.result as List).first, isA<User>());
      }

      {
        var count = await userAPIRepository.length();
        expect(count, equals(2));
      }

      {
        var count = await addressAPIRepository.length();
        expect(count, equals(3));
      }
    });
  });
}

@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(seconds: 60))
import 'dart:io';
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_directory.dart';
import 'package:bones_api/src/bones_api_entity_db_object.dart';
import 'package:statistics/statistics.dart' show Decimal;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

typedef _AdapterCreator =
    DBAdapter Function(EntityRepositoryProvider parentRepositoryProvider);

/// A provider with the main test entities stored by a [DBObjectAdapter].
class _ObjectEntitiesProvider extends DBEntityRepositoryProvider<DBAdapter> {
  final _AdapterCreator adapterCreator;

  _ObjectEntitiesProvider(this.adapterCreator);

  @override
  Map<String, dynamic> get adapterConfig => {};

  @override
  FutureOr<DBAdapter> buildAdapter() => adapterCreator(this);

  List<EntityRepository<Object>>? _repositories;

  @override
  List<EntityRepository<Object>> buildRepositories(
    DBAdapter adapter,
  ) => _repositories ??= [
    DBEntityRepository<Store>(
      adapter,
      'store',
      Store$reflection().entityHandler,
    ),
    DBEntityRepository<Address>(
      adapter,
      'address',
      Address$reflection().entityHandler,
    ),
    DBEntityRepository<Role>(adapter, 'role', Role$reflection().entityHandler),
    DBEntityRepository<UserInfo>(
      adapter,
      'user_info',
      UserInfo$reflection().entityHandler,
    ),
    DBEntityRepository<User>(adapter, 'user', User$reflection().entityHandler),
    DBEntityRepository<Photo>(
      adapter,
      'photo',
      Photo$reflection().entityHandler,
    ),
  ];

  DBEntityRepository<O> repo<O extends Object>() =>
      getEntityRepositoryByType(O) as DBEntityRepository<O>;
}

Future<void> main() async {
  _runObjectAdapterTests(
    'DBObjectMemoryAdapter',
    () =>
        (p) => DBObjectMemoryAdapter(parentRepositoryProvider: p, log: true),
    rollbackOnAbort: true,
    jsonOnly: false,
  );

  late Directory tempDir;

  _runObjectAdapterTests(
    'DBObjectDirectoryAdapter',
    () {
      tempDir = Directory.systemTemp.createTempSync('bones_api_cov_obj_dir');
      return (p) =>
          DBObjectDirectoryAdapter(tempDir, parentRepositoryProvider: p);
    },
    rollbackOnAbort: false,
    jsonOnly: true,
    tearDown: () {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    },
  );

  _runMemoryAdapterSpecificTests();
  _runDirectoryAdapterSpecificTests();
  _runObjectAdapterRegisterTests();
}

void _runObjectAdapterTests(
  String name,
  _AdapterCreator Function() creatorFactory, {
  required bool rollbackOnAbort,
  required bool jsonOnly,
  void Function()? tearDown,
}) {
  group(name, () {
    late _ObjectEntitiesProvider provider;
    late DBAdapter adapter;

    setUpAll(() async {
      provider = _ObjectEntitiesProvider(creatorFactory());
      await provider.ensureInitialized();
      adapter = await provider.adapter;
    });

    tearDownAll(() {
      provider.close();
      tearDown?.call();
    });

    /// Stores [fields] directly through the repository adapter (`doUpdate`),
    /// which normalizes the entity values to IDs.
    Future<Object?> putRaw<O extends Object>(
      O o,
      Object id,
      Map<String, dynamic> fields,
    ) async {
      var repo = provider.repo<O>();
      var op = TransactionOperationUpdate(repo.name, false, adapter, o);
      return repo.repositoryAdapter.doUpdate(op, o, id, fields);
    }

    test('capability and dialect', () {
      expect(adapter.dialectName, equals('object'));
      expect(adapter.dialect, equals(const DBDialect('object')));
      expect(adapter.capability.transactions, isTrue);
      expect(adapter.capability.constraintSupport, isFalse);
      expect(adapter.capability.info, contains('transactions: true'));
      expect(adapter.capability.toString(), contains('DBAdapterCapability'));
      expect(adapter.toString(), contains(adapter.runtimeType.toString()));
    });

    test('empty table', () async {
      // No `Store` stored yet:
      var storeRepo = provider.repo<Store>();

      expect(await storeRepo.count(), equals(0));
      expect(await storeRepo.existsID(1), isFalse);
      expect(await storeRepo.existIDs<int>([1, 2]), isEmpty);
      expect(await storeRepo.selectByID(1), isNull);
      expect(await storeRepo.selectByIDs([1, 2]), equals([null, null]));
      expect(await storeRepo.selectAll(), isEmpty);
      expect(await storeRepo.delete(ConditionID(1)), isEmpty);
    });

    test('store and select entities with references', () async {
      var roleRepo = provider.repo<Role>();
      var storeRepo = provider.repo<Store>();
      var userInfoRepo = provider.repo<UserInfo>();
      var photoRepo = provider.repo<Photo>();
      var userRepo = provider.repo<User>();

      var role = Role(RoleType.admin, id: 101);
      var role2 = Role(RoleType.guest, id: 102, enabled: false);
      var store = Store('Shop', 1, id: 801);
      var address = Address(
        'NY',
        'New York',
        'Broadway',
        10,
        id: 201,
        closedStores: [store],
      );
      var userInfo = UserInfo('the info', id: 301);
      var photo = Photo.fromData(
        Uint8List.fromList([1, 2, 3, 4]),
        id: 'PHOTO-401',
      );

      expect(await roleRepo.store(role), equals(101));
      expect(await roleRepo.store(role2), equals(102));

      expect(await storeRepo.store(store), equals(801));
      expect(await userInfoRepo.store(userInfo), equals(301));
      expect(await photoRepo.store(photo), equals('PHOTO-401'));

      // `closedStores` as a `List` (an `EntityReferenceList` value: see the
      // `EntityReferenceList field` test):
      expect(
        await putRaw(address, 201, {
          'id': 201,
          'state': 'NY',
          'city': 'New York',
          'street': 'Broadway',
          'number': 10,
          'stores': [store],
          'closedStores': [store],
          'latitude': 1.5,
          'longitude': 2.5,
        }),
        equals(201),
      );

      // Entities, lists of entities and references normalized to IDs:
      expect(
        await putRaw(User.empty(), 501, {
          'email': 'joe@mail.com',
          'password': '123456',
          'address': address,
          'roles': [role, 102],
          'level': 7,
          'userInfo': EntityReference<UserInfo>.fromID(301),
          'photo': photo,
          'creationTime': '2020-01-02T03:04:05.000Z',
        }),
        equals(501),
      );

      expect(
        await putRaw(User.empty(), 502, {
          'email': 'ann@mail.com',
          'password': 'abc',
          'address': 201,
          'roles': role,
          'userInfo': EntityReference<UserInfo>.asNull(),
          'creationTime': '2021-01-02T03:04:05.000Z',
        }),
        equals(502),
      );

      expect(
        await putRaw(User.empty(), 503, {
          'email': 'bob@mail.com',
          'password': 'xyz',
          'address': 201,
          'roles': <Role>[],
          'userInfo': EntityReference<UserInfo>.fromEntity(userInfo),
          'creationTime': '2022-01-02T03:04:05.000Z',
        }),
        equals(503),
      );

      expect(
        await putRaw(User.empty(), 504, {
          'email': 'tom@mail.com',
          'password': 'xyz',
          'address': 201,
          'roles': <Role>[],
          'userInfo': userInfo,
          'creationTime': '2022-01-02T03:04:05.000Z',
        }),
        equals(504),
      );

      // The stored (normalized) entries:
      Future<Map<String, dynamic>?> selectRaw<O extends Object>(
        Object id,
      ) async {
        var repo = provider.repo<O>();
        var op = TransactionOperationSelect(
          repo.name,
          false,
          adapter,
          ConditionID(id),
        );
        return await repo.repositoryAdapter.doSelectByID<Map<String, dynamic>>(
          op,
          id,
        );
      }

      var raw1 = await selectRaw<User>(501);
      expect(raw1, isNotNull);
      expect(raw1!['id'], equals(501));
      expect(raw1['address'], equals(201));
      expect(raw1['roles'], equals([101, 102]));
      expect(raw1['userInfo'], equals(301));
      expect(raw1['photo'], equals('PHOTO-401'));

      var raw2 = await selectRaw<User>(502);
      expect(raw2!['roles'], equals([101]));
      expect(raw2['userInfo'], isNull);

      expect((await selectRaw<User>(503))!['userInfo'], equals(301));
      expect((await selectRaw<User>(504))!['userInfo'], equals(301));

      var rawAddress = await selectRaw<Address>(201);
      expect(rawAddress!['stores'], equals([801]));
      expect(rawAddress['closedStores'], equals([801]));

      expect(await selectRaw<User>(999), isNull);

      expect((await roleRepo.selectByID(102))?.enabled, isFalse);
      expect((await storeRepo.selectByID(801))?.name, equals('Shop'));
      expect((await photoRepo.selectByID('PHOTO-401'))?.data, [1, 2, 3, 4]);

      expect(await userRepo.existsID(501), isTrue);
      expect(await userRepo.existsID(999), isFalse);
      expect(await userRepo.count(), equals(4));
      expect(await userRepo.length(), equals(4));
      expect(await userRepo.count(matcher: ConditionID(501)), equals(1));
      expect(await userRepo.count(matcher: ConditionID(999)), equals(0));

      // Resolving the sub-entities (selected in the same transaction, after
      // the `User`'s select: previously a deadlock in
      // `DBObjectDirectoryAdapter`):

      var user1 = await userRepo.selectByID(
        501,
        resolutionRules: EntityResolutionRules(allEager: true),
      );

      expect(user1, isNotNull);
      expect(user1!.id, equals(501));
      expect(user1.email, equals('joe@mail.com'));
      expect(user1.level, equals(7));
      expect(user1.address.id, equals(201));
      expect(user1.address.city, equals('New York'));
      expect(user1.address.stores.map((e) => e.id), equals([801]));
      expect(user1.roles.map((r) => r.id), equals([101, 102]));
      expect(user1.roles.map((r) => r.type), [RoleType.admin, RoleType.guest]);
      expect(user1.userInfo.id, equals(301));
      expect(user1.photo?.id, equals('PHOTO-401'));
      expect(user1.creationTime, equals(DateTime.utc(2020, 1, 2, 3, 4, 5)));

      var user2 = await userRepo.selectByID(502);
      expect(user2!.roles.map((r) => r.id), equals([101]));
      expect(user2.userInfo.isNull, isTrue);
      expect(user2.photo, isNull);

      var user3 = await userRepo.selectByID(503);
      expect(user3!.userInfo.id, equals(301));

      var user4 = await userRepo.selectByID(504);
      expect(user4!.userInfo.id, equals(301));

      // Multiple results (resolves the sub-entities by field):
      var users = await userRepo.selectAll(orderByID: true);
      expect(users.map((u) => u.id), equals([501, 502, 503, 504]));
      expect(users.map((u) => u.address.id).toSet(), equals({201}));

      // `store` of an already stored `User` (update):
      user1.level = 8;
      expect(await userRepo.store(user1), equals(501));
      expect((await userRepo.selectByID(501))?.level, equals(8));

      // The `User` fields as entities (normalized to IDs):
      var user5 = User(
        'max@mail.com',
        '123',
        address,
        [role],
        id: 505,
        userInfo: userInfo,
        photo: photo,
      );
      expect(await userRepo.store(user5), equals(505));
      var user5b = await userRepo.selectByID(505);
      expect(user5b!.address.id, equals(201));
      expect(user5b.roles.map((r) => r.id), equals([101]));
      expect(user5b.photo?.id, equals('PHOTO-401'));
    });

    test('existIDs / selectByIDs / selectAll pagination', () async {
      var userInfoRepo = provider.repo<UserInfo>();

      for (var i = 1; i <= 5; ++i) {
        await userInfoRepo.store(UserInfo('info-$i', id: 1000 + i));
      }

      var exists = await userInfoRepo.existIDs<int>([1001, 1003, 9999, null]);
      expect(exists.toList()..sort(), equals([1001, 1003]));

      expect(await userInfoRepo.existIDs<int>([]), isEmpty);

      var sel = await userInfoRepo.selectByIDs([1005, 1002, 8888]);
      expect(
        sel.nonNulls.map((e) => e.id).toList()..sort(),
        equals([1002, 1005]),
      );

      var byIDs = await userInfoRepo.select(
        ConditionIdIN([1001, 1002, 1003, 1004]),
        limit: 2,
        offset: 1,
      );
      expect(byIDs.map((e) => e.id), equals([1002, 1003]));

      expect(await userInfoRepo.select(ConditionIdIN([])), isEmpty);

      var all = await userInfoRepo.selectAll(
        orderByID: true,
        orderDirection: OrderDirection.descending,
      );
      var allIDs = all.map((e) => e.id!).where((id) => id > 1000).toList();
      expect(allIDs, equals([1005, 1004, 1003, 1002, 1001]));

      var page = await userInfoRepo.selectAll(
        limit: 2,
        offset: 0,
        orderByID: true,
      );
      expect(page.length, equals(2));

      // `KeyConditionEQ` on the ID field -> select by ID:
      var byKey = await userInfoRepo.select(
        KeyConditionEQ([ConditionKeyField('id')], 1004),
      );
      expect(byKey.map((e) => e.info), equals(['info-4']));

      var byKeyOffset = await userInfoRepo.select(
        KeyConditionEQ([ConditionKeyField('id')], 1004),
        offset: 1,
      );
      expect(byKeyOffset, isEmpty);

      // Not supported by an object adapter:
      expect(
        () => userInfoRepo.select(
          KeyConditionEQ([ConditionKeyField('info')], 'info-1'),
        ),
        throwsA(isA<UnsupportedError>()),
      );

      // `selectIDsBy`:
      expect(
        await userInfoRepo.selectIDsBy<int>(ConditionID(1002)),
        equals([1002]),
      );
      expect(
        await userInfoRepo.selectIDsBy<int>(ConditionID(1002), offset: 1),
        isEmpty,
      );
      expect(await userInfoRepo.selectIDsBy<int>(ConditionID(7777)), isEmpty);
      expect(
        (await userInfoRepo.selectIDsBy<int>(
          ConditionIdIN([1003, 1001, 1002, 6666]),
          orderByID: true,
          limit: 2,
        )).toList(),
        equals([1001, 1002]),
      );
      expect(
        () => userInfoRepo.selectIDsBy<int>(
          KeyConditionEQ([ConditionKeyField('info')], 'x'),
        ),
        throwsA(isA<UnsupportedError>()),
      );

      // Errors inside the adapter operations are wrapped:
      expect(
        () => userInfoRepo.count(
          matcher: KeyConditionEQ([ConditionKeyField('info')], 'x'),
        ),
        throwsA(
          isA<DBObjectAdapterException>().having(
            (e) => e.message,
            'message',
            contains('Relationship count not supported'),
          ),
        ),
      );
    });

    test('delete', () async {
      var roleRepo = provider.repo<Role>();

      if (jsonOnly) {
        await putRaw(Role.empty(), 2001, {'type': 'guest'});
        await putRaw(Role.empty(), 2002, {'type': 'unknown'});
      } else {
        await roleRepo.store(Role(RoleType.guest, id: 2001));
        await roleRepo.store(Role(RoleType.unknown, id: 2002));
      }

      expect(await roleRepo.existsID(2001), isTrue);

      var del = await roleRepo.delete(ConditionID(2001));
      expect(del.map((e) => e.id), equals([2001]));
      expect(del.first.type, equals(RoleType.guest));

      expect(await roleRepo.existsID(2001), isFalse);

      var del2 = await roleRepo.delete(ConditionID(2001));
      expect(del2, isEmpty);

      expect(
        () => roleRepo.delete(
          KeyConditionEQ<Role>([ConditionKeyField('type')], 'guest'),
        ),
        throwsA(
          isA<DBObjectAdapterException>().having(
            (e) => e.message,
            'message',
            contains('Relationship delete not supported'),
          ),
        ),
      );

      expect(await roleRepo.existsID(2002), isTrue);
    });

    test('transaction: commit', () async {
      var userInfoRepo = provider.repo<UserInfo>();

      var transaction = Transaction();

      var result = await transaction.execute(() async {
        await userInfoRepo.store(UserInfo('tx-1', id: 3001));
        await userInfoRepo.store(UserInfo('tx-2', id: 3002));
        var sel = await userInfoRepo.selectByID(3001);
        expect(sel?.info, equals('tx-1'));
        expect(await userInfoRepo.count(matcher: ConditionID(3002)), equals(1));
        expect(await userInfoRepo.existIDs<int>([3001, 3002]), hasLength(2));
        var all = await userInfoRepo.selectByIDs([3001, 3002]);
        expect(all, hasLength(2));
        var del = await userInfoRepo.delete(ConditionID(3002));
        expect(del, hasLength(1));
        return 'ok';
      });

      expect(result, equals('ok'));
      expect(transaction.isCommitted, isTrue);
      expect(transaction.isAborted, isFalse);

      expect((await userInfoRepo.selectByID(3001))?.info, equals('tx-1'));
      expect(await userInfoRepo.existsID(3002), isFalse);
    });

    test('transaction: abort', () async {
      var userInfoRepo = provider.repo<UserInfo>();

      await userInfoRepo.store(UserInfo('before', id: 4001));

      var transaction = Transaction();

      var result = await transaction.execute(() async {
        var o = await userInfoRepo.selectByID(4001);
        o!.info = 'after';
        await userInfoRepo.store(o);
        await userInfoRepo.store(UserInfo('new', id: 4002));
        transaction.abort(reason: 'Test abort');
      });

      expect(result, isNull);
      expect(transaction.isAborted, isTrue);
      expect(transaction.abortError?.reason, equals('Test abort'));

      var o2 = await userInfoRepo.selectByID(4001);

      if (rollbackOnAbort) {
        expect(o2?.info, equals('before'));
        expect(await userInfoRepo.existsID(4002), isFalse);
      } else {
        expect(o2?.info, equals('after'));
      }
    });

    test('concurrent transactions', () async {
      var userInfoRepo = provider.repo<UserInfo>();

      var t1 = Transaction();
      var t2 = Transaction();

      var f1 = t1.execute(() async {
        await userInfoRepo.store(UserInfo('c-1', id: 5001));
        await Future.delayed(Duration(milliseconds: 20));
        await userInfoRepo.store(UserInfo('c-1b', id: 5011));
        return 1;
      });

      var f2 = t2.execute(() async {
        await userInfoRepo.store(UserInfo('c-2', id: 5002));
        await userInfoRepo.store(UserInfo('c-2b', id: 5012));
        return 2;
      });

      expect(await f1, equals(1));
      expect(await f2, equals(2));

      expect(
        (await userInfoRepo.existIDs<int>([5001, 5002, 5011, 5012])).length,
        equals(4),
      );
    });

    test('information', () async {
      await provider.repo<UserInfo>().store(UserInfo('i', id: 6001));

      var info = adapter.information(extended: true);
      expect(info['tables'], isNotNull);

      var repoInfo = provider.repo<UserInfo>().information(extended: true);
      expect(repoInfo['dialect'], equals('object'));
      expect(repoInfo['adapter'], isA<Map>());

      expect(
        provider.repo<UserInfo>().toString(),
        contains('DBEntityRepository'),
      );
    });

    test('table scheme', () async {
      var scheme = await adapter.getTableScheme('user');
      expect(scheme, isNotNull);
      expect(scheme!.idFieldName, equals('id'));
      expect(scheme.fieldsTypes.keys, contains('email'));

      var relScheme = await adapter.getTableScheme(
        'user__roles__rel',
        relationship: TableRelationshipReference(
          'user__roles__rel',
          'user',
          'id',
          int,
          'user_id',
          'role',
          'id',
          int,
          'role_id',
        ),
      );
      expect(relScheme, isNotNull);
      expect(relScheme!.relationship, isTrue);

      expect(
        () => adapter.getTableScheme('no_such_table'),
        throwsA(isA<StateError>()),
      );

      expect(await adapter.getTableFieldsTypes('no_such_table'), isNull);
    });

    test('direct insert operations', () async {
      var userInfoRepo = provider.repo<UserInfo>();
      var repoAdapter = userInfoRepo.repositoryAdapter;

      var o = UserInfo('direct', id: 7001);

      var op = TransactionOperationStore('user_info', false, adapter, o);

      var id = await repoAdapter.doInsert(op, o, {
        'id': 7001,
        'info': 'direct',
      });
      expect(id, equals(7001));

      expect((await userInfoRepo.selectByID(7001))?.info, equals('direct'));

      var o2 = UserInfo('no id');
      var op2 = TransactionOperationStore('user_info', false, adapter, o2);

      Object? error;
      try {
        await repoAdapter.doInsert(op2, o2, {'id': null, 'info': 'no id'});
      } catch (e) {
        error = e;
      }

      expect(error, isNotNull);
      expect(error.toString(), contains("Can't determine object ID"));

      // Through the repository: an entity without an ID can't be stored.
      Object? error2;
      try {
        await userInfoRepo.store(UserInfo('no id 2'));
      } catch (e) {
        error2 = e;
      }
      expect(error2, isA<DBObjectAdapterException>());
      expect(error2.toString(), contains('Operation>>'));
    });

    // The last one: it stores entities used by the previous tests' counts.
    test('EntityReferenceList field: stored as IDs (edge cases)', () async {
      var storeRepo = provider.repo<Store>();
      var addressRepo = provider.repo<Address>();

      var s1 = Store('S1', 1, id: 811);
      var s2 = Store('S2', 2, id: 812);
      expect(await storeRepo.store(s1), equals(811));
      expect(await storeRepo.store(s2), equals(812));

      Future<Map<String, dynamic>> selectRawAddress(int id) async {
        var op = TransactionOperationSelect(
          addressRepo.name,
          false,
          adapter,
          ConditionID(id),
        );
        var raw = await addressRepo.repositoryAdapter
            .doSelectByID<Map<String, dynamic>>(op, id);
        return raw!;
      }

      Future<Object?> storedClosedStores(
        int id,
        EntityReferenceList<Store> closedStores,
      ) async {
        var address = Address('NY', 'New York', 'Broadway', id, id: id);

        Object? stored;
        if (jsonOnly) {
          // Without the `Decimal` fields (not JSON encodable by
          // `DBObjectDirectoryAdapter`):
          stored = await putRaw(address, id, {
            'id': id,
            'state': 'NY',
            'city': 'New York',
            'street': 'Broadway',
            'number': id,
            'stores': <Store>[],
            'closedStores': closedStores,
          });
        } else {
          address.closedStores = closedStores;
          stored = await addressRepo.store(address);
        }
        expect(stored, equals(id));

        return (await selectRawAddress(id))['closedStores'];
      }

      // With the entities (stored): their IDs.
      expect(
        await storedClosedStores(
          221,
          EntityReferenceList<Store>.fromEntities([s1, s2]),
        ),
        equals([811, 812]),
      );

      // With only the IDs (the order is kept):
      expect(
        await storedClosedStores(
          222,
          EntityReferenceList<Store>.fromIDs([812, 811]),
        ),
        equals([812, 811]),
      );

      // A single element:
      expect(
        await storedClosedStores(
          223,
          EntityReferenceList<Store>.fromEntities([s2]),
        ),
        equals([812]),
      );

      // Empty (from entities, from IDs, `asEmpty`): an empty list.
      expect(
        await storedClosedStores(
          224,
          EntityReferenceList<Store>.fromEntities([]),
        ),
        equals([]),
      );
      expect(
        await storedClosedStores(225, EntityReferenceList<Store>.fromIDs([])),
        equals([]),
      );
      expect(
        await storedClosedStores(226, EntityReferenceList<Store>.asEmpty()),
        equals([]),
      );

      // `null` (`asNull`): no value.
      expect(
        await storedClosedStores(227, EntityReferenceList<Store>.asNull()),
        isNull,
      );

      // The `EntityReferenceList` itself is never stored (not even wrapped):
      for (var id in [221, 222, 223, 224, 225, 226, 227]) {
        var closedStores = (await selectRawAddress(id))['closedStores'];
        expect(closedStores, isNot(isA<EntityReferenceList>()));
        expect(closedStores ?? [], isNot(contains(isA<EntityReferenceList>())));
      }

      // Read back as an `EntityReferenceList` (previously: "Can't cast to
      // List<Store> due to null elements"):
      var a1 = await addressRepo.selectByID(221);
      expect(a1!.closedStores.ids, equals([811, 812]));
      expect(a1.closedStores.length, equals(2));

      var a4 = await addressRepo.selectByID(224);
      expect(a4!.closedStores.ids ?? [], isEmpty);
    });

    test('store and select: DateTime, enum and Decimal fields', () async {
      var roleRepo = provider.repo<Role>();
      var addressRepo = provider.repo<Address>();
      var userRepo = provider.repo<User>();

      // Through the repositories (previously not JSON encodable by
      // `DBObjectDirectoryAdapter`):
      var role = Role(RoleType.unknown, id: 131, value: Decimal.parse('12.5'));
      expect(await roleRepo.store(role), equals(131));

      var address = Address(
        'CA',
        'LA',
        'Sunset',
        3,
        id: 231,
        latitude: Decimal.parse('34.098'),
        longitude: Decimal.parse('-118.326'),
      );
      expect(await addressRepo.store(address), equals(231));

      var creationTime = DateTime.utc(2024, 2, 3, 4, 5, 6, 7);
      var user = User(
        'dt@mail.com',
        'pass',
        address,
        [role],
        id: 531,
        creationTime: creationTime,
        wakeUpTime: Time(7, 30),
      );
      expect(await userRepo.store(user), equals(531));

      // Read back with the same values:
      var role2 = await roleRepo.selectByID(131);
      expect(role2!.type, equals(RoleType.unknown));
      expect(role2.value, equals(Decimal.parse('12.5')));

      var address2 = await addressRepo.selectByID(231);
      expect(address2!.latitude, equals(Decimal.parse('34.098')));
      expect(address2.longitude, equals(Decimal.parse('-118.326')));

      var user2 = await userRepo.selectByID(
        531,
        resolutionRules: EntityResolutionRules(allEager: true),
      );
      expect(user2!.creationTime, equals(creationTime));
      expect(user2.wakeUpTime, equals(Time(7, 30)));
      expect(user2.address.id, equals(231));
      expect(user2.roles.map((r) => r.type), equals([RoleType.unknown]));
    });
  });
}

void _runMemoryAdapterSpecificTests() {
  group('DBObjectMemoryAdapter specifics', () {
    test('context', () {
      var c1 = DBObjectMemoryAdapterContext(1, {'a': 1});
      var c2 = DBObjectMemoryAdapterContext(2, {});
      expect(c1.compareTo(c2), lessThan(0));
      expect(c1.isClosed, isFalse);
      c1.close();
      expect(c1.isClosed, isTrue);
    });

    test('fromConfig', () async {
      var adapter = await DBObjectMemoryAdapter.fromConfig({
        'populate': {
          'generate-tables': true,
          'tables': 'x.sql',
          'source': null,
          'variables': {'A': 1},
        },
      });

      expect(adapter, isA<DBObjectMemoryAdapter>());
      expect(adapter.name, equals('object.memory'));

      var conn = adapter.createConnection();
      expect(adapter.getConnectionURL(conn), startsWith('object.memory://'));
      expect(await adapter.isConnectionValid(conn), isTrue);
      expect(adapter.closeConnection(conn), isTrue);
      expect(conn.isClosed, isTrue);

      expect(adapter.tablesVersions, isEmpty);
      expect(adapter.information(), isEmpty);
      expect(adapter.information(table: 'foo'), equals({'tables': {}}));

      adapter.addTableSchemes([
        TableScheme(
          'foo',
          idFieldName: 'code',
          fieldsTypes: {'code': String, 'name': String},
        ),
      ]);

      expect(await adapter.getTableFieldsTypes('foo'), {
        'code': String,
        'name': String,
      });
      expect((await adapter.getTableScheme('foo'))?.idFieldName, 'code');

      expect(adapter.toString(), contains('DBObjectMemoryAdapter#'));

      expect(adapter.close(), isTrue);
      expect(adapter.close(), isFalse);
      expect(adapter.toString(), contains('closed'));
    });

    test('exception', () {
      var e = DBObjectMemoryAdapterException(
        'test',
        'message',
        parentError: StateError('parent'),
        previousError: 'prev',
        operation: ['op1', () => 'op2'],
      );

      expect(e.runtimeTypeNameSafe, equals('DBObjectMemoryAdapterException'));
      var s = e.toString();
      expect(s, contains('[test]: message'));
      expect(s, contains('Parent ERROR>>'));
      expect(s, contains('Previous ERROR>>'));
      expect(s, contains('op1'));
      expect(s, contains('op2'));

      var e2 = DBObjectAdapterException('t', 'm');
      expect(e2.runtimeTypeNameSafe, equals('DBObjectAdapterException'));
      expect(e2.toString(), equals('DBObjectAdapterException[t]: m'));
    });
  });
}

void _runDirectoryAdapterSpecificTests() {
  group('DBObjectDirectoryAdapter specifics', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bones_api_cov_obj_dir2');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('context', () {
      var c1 = DBObjectDirectoryAdapterContext(1);
      var c2 = DBObjectDirectoryAdapterContext(2);
      expect(c2.compareTo(c1), greaterThan(0));
      expect(c1.isClosed, isFalse);
      c1.close();
      expect(c1.isClosed, isTrue);
    });

    test('directory not found', () {
      expect(
        () => DBObjectDirectoryAdapter(Directory('${tempDir.path}/no-dir')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('development: auto-create `/tmp/` directory', () {
      var tmpParent = Directory('${tempDir.path}/tmp')..createSync();
      var dir = Directory('${tmpParent.path}/auto');
      expect(dir.existsSync(), isFalse);

      var adapter = DBObjectDirectoryAdapter(dir, development: true);
      expect(dir.existsSync(), isTrue);
      expect(adapter.development, isTrue);
      expect(adapter.directory.path, equals(dir.path));

      adapter.close();
      expect(adapter.toString(), contains('{closed}'));
    });

    test('fromConfig', () async {
      expect(
        () => DBObjectDirectoryAdapter.fromConfig({}),
        throwsA(isA<ArgumentError>()),
      );

      var adapter = await DBObjectDirectoryAdapter.fromConfig({
        'path': tempDir.path,
        'development': false,
        'populate': {
          'generateTables': false,
          'tables': 'x.sql',
          'variables': {'A': 1},
        },
      });

      expect(adapter.development, isFalse);
      expect(adapter.name, equals('object.directory'));

      var adapter2 = await DBObjectDirectoryAdapter.fromConfig({
        'directory': tempDir.path,
      });
      expect(adapter2.directory.path, equals(tempDir.path));

      var conn = adapter.createConnection();
      expect(adapter.getConnectionURL(conn), startsWith('object.directory://'));
      expect(await adapter.isConnectionValid(conn), isTrue);
      expect(adapter.closeConnection(conn), isTrue);
      expect(conn.isClosed, isTrue);

      Directory('${tempDir.path}/foo').createSync();
      Directory('${tempDir.path}/bar').createSync();

      var info = adapter.information();
      expect((info['tables'] as List).toSet(), equals({'foo', 'bar'}));

      adapter.addTableSchemes([
        TableScheme(
          'foo',
          idFieldName: 'code',
          fieldsTypes: {'code': String, 'name': String},
        ),
      ]);

      expect(await adapter.getTableFieldsTypes('foo'), {
        'code': String,
        'name': String,
      });
      expect((await adapter.getTableScheme('foo'))?.idFieldName, 'code');

      expect(adapter.toString(), contains('DBObjectDirectoryAdapter#'));

      adapter.close();
      adapter2.close();
    });

    test('exception', () {
      var e = DBObjectDirectoryAdapterException('t', 'm');
      expect(
        e.runtimeTypeNameSafe,
        equals('DBObjectDirectoryAdapterException'),
      );
      expect(e.toString(), contains('DBObjectDirectoryAdapterException[t]: m'));
    });
  });
}

void _runObjectAdapterRegisterTests() {
  group('DBObjectAdapter register', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('bones_api_cov_obj_reg');
      DBObjectDirectoryAdapter.boot();
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('registered adapters', () {
      expect(
        DBObjectAdapter.registeredAdaptersNames,
        containsAll(['object.memory', 'obj.memory', 'object.directory']),
      );
      expect(
        DBObjectAdapter.registeredAdaptersTypes,
        containsAll([DBObjectMemoryAdapter, DBObjectDirectoryAdapter]),
      );

      expect(
        DBObjectAdapter.getAdapterInstantiator(name: 'obj.memory'),
        isNotNull,
      );
      expect(
        DBObjectAdapter.getAdapterInstantiator(type: DBObjectDirectoryAdapter),
        isNotNull,
      );
      expect(
        DBObjectAdapter.getAdapterInstantiator(name: 'no.such.adapter'),
        isNull,
      );

      expect(
        DBObjectAdapter.getAdapterInstantiatorsFromConfig({
          'obj.memory': {},
          'other': {},
        }),
        hasLength(1),
      );

      expect(DBObjectAdapter.parseConfigLog({'log': true}), isTrue);
      expect(DBObjectAdapter.parseConfigLog({'log': 'false'}), isFalse);
      expect(DBObjectAdapter.parseConfigLog(null), isNull);
    });

    test('fromConfig', () async {
      var a1 = await DBObjectAdapter.fromConfig({'object.memory': {}});
      expect(a1, isA<DBObjectMemoryAdapter>());

      var a2 = await DBObjectAdapter.fromConfig({
        'obj.dir': {'path': tempDir.path},
      });
      expect(a2, isA<DBObjectDirectoryAdapter>());

      var a3 = await DBAdapter.fromConfig({
        'object.directory': {'directory': tempDir.path},
      });
      expect(a3, isA<DBObjectDirectoryAdapter>());

      expect(
        () => DBObjectAdapter.fromConfig({'no.such.adapter': {}}),
        throwsA(isA<StateError>()),
      );

      expect(
        () => DBAdapter.fromConfig({'no.such.adapter': {}}),
        throwsA(isA<StateError>()),
      );

      // The instantiator fails (no `path`), returning `null`:
      expect(
        () => DBObjectAdapter.fromConfig({'obj.dir': {}}),
        throwsA(isA<StateError>()),
      );

      for (var a in [a1, a2, a3]) {
        a.close();
      }
    });
  });
}

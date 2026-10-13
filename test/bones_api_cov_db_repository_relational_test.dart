@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(seconds: 60))
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';
import 'bones_api_test_entities.dart';

/// A [DBRelationalEntityRepositoryProvider] with its adapter built from
/// [adapterConfig].
class _RelationalConfigProvider
    extends DBRelationalEntityRepositoryProvider<DBSQLMemoryAdapter> {
  @override
  Map<String, dynamic> get adapterConfig => {
    'sql.memory': {'generateTables': false},
  };

  List<EntityRepository<Object>>? _repositories;

  @override
  List<EntityRepository<Object>> buildRepositories(DBAdapter adapter) =>
      _repositories ??= [
        DBSQLEntityRepository<UserInfo>(
          adapter as DBSQLMemoryAdapter,
          'user_info',
          UserInfo$reflection().entityHandler,
        ),
      ];
}

void main() {
  group(
    'APIRepository / DBRelationalEntityRepository (DBSQLMemoryAdapter)',
    () {
      late TestEntityRepositoryProvider provider;
      late DBSQLMemoryAdapter sqlAdapter;

      late int user1Id;
      late int user2Id;

      setUpAll(() async {
        provider = createEntityRepositoryProvider(
          true,
          (p, dbPort, dbConfig) => DBSQLMemoryAdapter(
            parentRepositoryProvider: p,
            generateTables: false,
            checkTables: false,
          ),
          0,
          null,
        );

        await provider.ensureInitialized();
        sqlAdapter = (await provider.adapter) as DBSQLMemoryAdapter;

        var user1 = User(
          'joe@cov.com',
          '123',
          Address('NY', 'New York', 'Broadway', 1),
          [Role(RoleType.admin), Role(RoleType.guest)],
          userInfo: UserInfo('joe-info'),
          creationTime: DateTime.utc(2020, 1, 1),
        );

        var user2 = User(
          'ann@cov.com',
          '456',
          Address('CA', 'LA', 'Sunset', 2),
          [Role(RoleType.unknown)],
          creationTime: DateTime.utc(2021, 1, 1),
        );

        user1Id = await provider.userAPIRepository.store(user1);
        user2Id = await provider.userAPIRepository.store(user2);
      });

      tearDownAll(() => provider.close());

      test('APIRepository.resolveEntityRepository', () {
        var repo = APIRepository.resolveEntityRepository<UserInfo>(
          provider: provider,
        );
        expect(repo, isNotNull);
        expect(repo!.type, equals(UserInfo));

        expect(
          APIRepository.resolveEntityRepository<Duration>(type: Duration),
          isNull,
        );

        expect(
          () => APIRepository.resolveEntityRepository<Duration>(
            type: Duration,
            required: true,
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('onStore / onDelete', () async {
        var repo = provider.userInfoAPIRepository;

        expect(identical(repo.onStore, repo.entityRepository.onStore), isTrue);

        var deleted = <UserInfo>[];
        var sub = repo.onDelete.listen(deleted.add);

        var o = UserInfo('evt');
        var id = await repo.store(o);

        var del = await repo.deleteByID(id);
        expect(del?.info, equals('evt'));

        await Future.delayed(Duration(milliseconds: 10));

        expect(deleted.map((e) => e.info), contains('evt'));

        await sub.cancel();
      });

      test('countByQuery / selectIDsBy / existIDs', () async {
        var repo = provider.userAPIRepository;

        expect(
          await repo.countByQuery(' email == ? ', parameters: ['joe@cov.com']),
          equals(1),
        );

        expect(
          await repo.selectIDsBy<int>(ConditionID(user1Id)),
          equals([user1Id]),
        );

        var ids = await repo.selectIDsBy<int>(
          ConditionIdIN([user1Id, user2Id]),
          orderByID: true,
          orderDirection: OrderDirection.descending,
        );
        expect(ids.toList(), equals([user2Id, user1Id]));

        expect(await repo.existsID(user1Id), isTrue);
        expect(
          (await repo.existIDs<int>([user1Id, user2Id, 99999])).toList()
            ..sort(),
          equals([user1Id, user2Id]..sort()),
        );
        expect(await repo.length(), equals(2));
        expect(await repo.count(), equals(2));
      });

      test('paginate / paginateAll', () async {
        var repo = provider.roleAPIRepository;

        var all = repo.paginateAll(limit: 2, orderByID: true);
        var allRoles = await all.stream().toList();
        expect(allRoles.length, equals(3));
        expect(
          allRoles.map((e) => e.id).toList(),
          equals(allRoles.map((e) => e.id).toList()..sort()),
        );

        var p = repo.paginate(
          KeyConditionEQ([ConditionKeyField('type')], 'admin'),
          limit: 1,
        );
        var admins = await p.stream().toList();
        expect(admins.map((e) => e.type), equals([RoleType.admin]));
      });

      test('tryDeleteEntity / tryDeleteByID', () async {
        var repo = provider.userInfoAPIRepository;

        var o1 = UserInfo('del-1');
        var o2 = UserInfo('del-2');
        await repo.store(o1);
        await repo.store(o2);

        var d1 = await repo.tryDeleteEntity(o1);
        expect(d1?.info, equals('del-1'));
        expect(await repo.existsID(o1.id), isFalse);

        var d2 = await repo.tryDeleteByID(o2.id);
        expect(d2?.info, equals('del-2'));

        expect(await repo.tryDeleteByID(o2.id), isNull);
      });

      test('delete (with transaction)', () async {
        var repo = provider.userInfoAPIRepository;

        var o = UserInfo('del-t');
        await repo.store(o);

        // Not `executing`: only reached if passed through.
        var t = Transaction(autoCommit: true);

        var del = await repo.delete(
          Condition.parse('info == ?'),
          positionalParameters: ['del-t'],
          transaction: t,
        );
        expect(del.map((e) => e.info), equals(['del-t']));

        // The delete is an operation of the given transaction:
        expect(
          t.operations.whereType<TransactionOperationDelete>(),
          isNotEmpty,
        );
        expect(await repo.existsID(o.id), isFalse);
      });

      test('storeAllFromJson', () async {
        var repo = provider.userInfoAPIRepository;

        var list = await repo.storeAllFromJson([
          {'info': 'json-1'},
          {'info': 'json-2'},
        ]);

        expect(list.map((e) => e.info), equals(['json-1', 'json-2']));
        expect(list.every((e) => e.id != null), isTrue);

        var sel = await repo.selectByIDs(list.map((e) => e.id).toList());
        expect(sel.map((e) => e?.info), equals(['json-1', 'json-2']));
      });

      test('relational repository adapter', () async {
        var userRepo =
            provider.userAPIRepository.entityRepository
                as DBRelationalEntityRepository<User>;

        expect(
          userRepo.repositoryAdapter.toString(),
          startsWith('SQLRepositoryAdapter{name: user,'),
        );
        expect(
          userRepo.toString(),
          startsWith('DBSQLEntityRepository<User>[user]@'),
        );
      });

      test('ensureStored (relational)', () async {
        var userRepo = provider.userAPIRepository.entityRepository;

        // Not tracked, but stored:
        var user = await provider.userAPIRepository.selectByID(user2Id);
        var copy = User(
          user!.email,
          user.password,
          user.address,
          user.roles,
          id: user.id,
          creationTime: user.creationTime,
        );
        expect(await userRepo.ensureStored(copy), equals(user2Id));

        // Tracked:
        expect(await userRepo.ensureStored(user), equals(user2Id));
      });

      test('cached relationships (transaction)', () async {
        var userRepo =
            provider.userAPIRepository.entityRepository
                as DBRelationalEntityRepository<User>;

        var t = Transaction();

        var result = (await t.execute(() async {
          var u1 = await userRepo.selectByID(user1Id, transaction: t);
          expect(u1, isNotNull);

          var rolesIds = await userRepo.selectRelationship(
            null,
            'roles',
            oId: user1Id,
            transaction: t,
          );

          var addressId = await userRepo.selectRelationship(
            null,
            'address',
            oId: user1Id,
            transaction: t,
          );

          // `user2` is not cached: merged with the cached `user1`:
          var rels = await userRepo.selectRelationships(
            null,
            'roles',
            oIds: [user1Id, user2Id],
            transaction: t,
          );

          var u2 = await userRepo.selectByID(user2Id, transaction: t);
          expect(u2, isNotNull);

          // All cached:
          var rels2 = await userRepo.selectRelationships(
            null,
            'roles',
            oIds: [user1Id, user2Id],
            transaction: t,
          );

          var relsAddress = await userRepo.selectRelationships(
            null,
            'address',
            oIds: [user1Id, user2Id],
            transaction: t,
          );

          return (
            u1: u1!,
            u2: u2!,
            rolesIds: rolesIds.toList(),
            addressId: addressId.toList(),
            rels: rels,
            rels2: rels2,
            relsAddress: relsAddress,
          );
        }))!;

        var u1RolesIds = result.u1.roles.map((r) => r.id).toList();
        var u2RolesIds = result.u2.roles.map((r) => r.id).toList();

        expect(result.rolesIds, equals(u1RolesIds));
        expect(result.addressId, equals([result.u1.address.id]));

        expect(result.rels[user1Id]?.toList(), equals(u1RolesIds));
        expect(result.rels[user2Id]?.toList(), equals(u2RolesIds));

        expect(result.rels2[user1Id]?.toList(), equals(u1RolesIds));
        expect(result.rels2[user2Id]?.toList(), equals(u2RolesIds));

        expect(result.relsAddress[user1Id], equals([result.u1.address.id]));
        expect(result.relsAddress[user2Id], equals([result.u2.address.id]));

        // No IDs:
        expect(await userRepo.selectRelationships(null, 'roles', oIds: []), {});
      });

      test('relationship of an unknown type', () {
        var userRepo =
            provider.userAPIRepository.entityRepository
                as DBRelationalEntityRepository<User>;

        expect(
          () => userRepo.selectRelationship(
            null,
            'roles',
            oId: user1Id,
            fieldType: TypeInfo<List<Duration>>.fromType(List, [
              TypeInfo<Duration>.fromType(Duration),
            ]),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('DBSQLMemoryAdapter information', () {
        var info = sqlAdapter.information(extended: true);
        var tables = info['tables'] as Map;
        expect(tables.keys, containsAll(['user', 'address', 'role']));

        var infoUser = sqlAdapter.information(table: 'user');
        expect(
          ((infoUser['tables'] as Map)['user'] as Map)['ids'],
          containsAll([user1Id, user2Id]),
        );

        expect(sqlAdapter.information(), isEmpty);

        expect(
          () => sqlAdapter.executeTableSQL('CREATE TABLE x (id int)'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    },
  );

  group('DBSQLMemoryAdapter', () {
    test('fromConfig', () async {
      var adapter = await DBSQLMemoryAdapter.fromConfig({
        'generateTables': true,
        'checkTables': false,
        'log': {'sql': true},
        'populate': {
          'variables': {'A': 1},
        },
      });

      expect(adapter, isA<DBSQLMemoryAdapter>());
      expect(adapter.name, equals('sql.memory'));

      var conn = adapter.createConnection();
      expect(adapter.getConnectionURL(conn), startsWith('sql.memory://'));

      var conn2 = adapter.createConnection();
      expect(conn.compareTo(conn2), lessThan(0));
      expect(conn.isClosed, isFalse);
      conn.close();
      expect(conn.isClosed, isTrue);

      expect(adapter.close(), isTrue);
      expect(adapter.close(), isFalse);

      var adapter2 = await DBAdapter.fromConfig({'sql.memory': {}});
      expect(adapter2, isA<DBSQLMemoryAdapter>());
      adapter2.close();
    });

    test('DBRelationalEntityRepositoryProvider: adapter from config', () async {
      var provider = _RelationalConfigProvider();
      await provider.ensureInitialized();

      var adapter = await provider.adapter;
      expect(adapter, isA<DBSQLMemoryAdapter>());

      var repo = provider.getEntityRepositoryByType<UserInfo>(UserInfo)!;
      var id = await repo.store(UserInfo('rel-provider'));
      expect((await repo.selectByID(id))?.info, equals('rel-provider'));

      provider.close();
    });
  });
}

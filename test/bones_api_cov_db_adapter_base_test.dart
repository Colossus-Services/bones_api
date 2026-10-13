@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(seconds: 60))
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A provider with an adapter built from [adapterConfig]
/// (the default [DBEntityRepositoryProvider.buildAdapter]).
class _ConfigProvider extends DBEntityRepositoryProvider<DBAdapter> {
  final bool duplicated;

  _ConfigProvider({this.duplicated = false});

  @override
  Map<String, dynamic> get adapterConfig => {'object.memory': {}};

  List<EntityRepository<Object>>? _repositories;

  @override
  List<EntityRepository<Object>> buildRepositories(DBAdapter adapter) =>
      _repositories ??= [
        DBEntityRepository<UserInfo>(
          adapter,
          'user_info',
          UserInfo$reflection().entityHandler,
        ),
        DBEntityRepository<Role>(
          adapter,
          'role',
          Role$reflection().entityHandler,
        ),
        if (duplicated)
          DBEntityRepository<Role>(
            adapter,
            'role',
            Role$reflection().entityHandler,
          ),
      ];

  DBEntityRepository<O> repo<O extends Object>() =>
      getEntityRepositoryByType(O) as DBEntityRepository<O>;
}

class _TestConnection extends DBConnectionWrapper<String> {
  bool nativeClosed = false;
  int closeImplCount = 0;

  _TestConnection(super.nativeConnection);

  @override
  String get runtimeTypeNameSafe => '_TestConnection';

  @override
  String get connectionURL => 'test://$nativeConnection';

  @override
  bool isClosedImpl() => nativeClosed;

  @override
  void closeImpl() => ++closeImplCount;
}

class _CovAdapterTypeKey {}

void main() {
  group('DBDialect / capability', () {
    test('DBDialect', () {
      // ignore: prefer_const_constructors
      var d1 = DBDialect('x');
      // ignore: prefer_const_constructors
      var d2 = DBDialect('x');
      // ignore: prefer_const_constructors
      var d3 = DBDialect('y');

      expect(d1 == d2, isTrue);
      expect(d1 == d3, isFalse);
      expect(d1.hashCode, equals(d2.hashCode));
      expect(d1.toString(), contains('name: x'));
    });

    test('DBAdapterCapability', () {
      const c = DBAdapterCapability(
        dialect: DBDialect('d'),
        transactions: true,
        transactionAbort: false,
        constraintSupport: true,
        multiIsolateSupport: false,
        connectivity: DBAdapterCapabilityConnectivity.secure,
      );

      expect(c.fullTransaction, isFalse);
      expect(c.runtimeTypeNameSafe, equals('DBAdapterCapability'));
      expect(c.info, contains('connectivity: secure'));
      expect(c.toString(), startsWith('DBAdapterCapability[d]'));
    });

    test('DBAdapterConnectivity', () {
      expect(DBAdapterConnectivity.any.allowSecure, isTrue);
      expect(DBAdapterConnectivity.any.allowInsecure, isTrue);
      expect(DBAdapterConnectivity.secure.allowSecure, isTrue);
      expect(DBAdapterConnectivity.secure.allowInsecure, isFalse);
      expect(DBAdapterConnectivity.insecure.allowSecure, isFalse);
      expect(DBAdapterConnectivity.insecure.allowInsecure, isTrue);
      expect(DBAdapterConnectivity.secureAndInsecure.allowSecure, isTrue);
      expect(DBAdapterConnectivity.secureAndInsecure.allowInsecure, isTrue);
    });
  });

  group('DBAdapter register', () {
    setUpAll(() {
      DBSQLMemoryAdapter.boot();
      DBObjectMemoryAdapter.boot();
    });

    test('registered adapters', () {
      expect(
        DBAdapter.registeredAdaptersNames,
        containsAll(['sql.memory', 'object.memory']),
      );
      expect(
        DBAdapter.registeredAdaptersTypes,
        containsAll([DBSQLMemoryAdapter, DBObjectMemoryAdapter]),
      );
      expect(DBAdapter.getAdapterInstantiator(name: 'sql.memory'), isNotNull);
      expect(
        DBAdapter.getAdapterInstantiator(type: DBObjectMemoryAdapter),
        isNotNull,
      );
      expect(DBAdapter.getAdapterInstantiator(name: 'nope'), isNull);
      expect(
        DBAdapter.getAdapterInstantiatorsFromConfig({
          'sql.memory': {},
          'object.memory': {'a': 1},
          'not-a-map': 123,
          'unknown': {},
        }),
        hasLength(2),
      );

      expect(
        () => DBAdapter.adapterRegister.getAdapterInstantiator(),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        DBRelationalAdapter.registeredAdaptersNames,
        contains('sql.memory'),
      );
      expect(
        DBRelationalAdapter.registeredAdaptersTypes,
        contains(DBSQLMemoryAdapter),
      );
      expect(
        DBRelationalAdapter.getAdapterInstantiator(name: 'sql.memory'),
        isNotNull,
      );
      expect(
        DBRelationalAdapter.getAdapterInstantiatorsFromConfig({
          'sql.memory': {},
        }),
        hasLength(1),
      );
    });

    test('async instantiator', () async {
      DBAdapter.registerAdapter<Object, DBAdapter<Object>>(
        ['cov.async.adapter'],
        _CovAdapterTypeKey,
        (
          config, {
          minConnections,
          maxConnections,
          parentRepositoryProvider,
          workingPath,
        }) async => DBObjectMemoryAdapter(),
      );

      expect(DBAdapter.registeredAdaptersNames, contains('cov.async.adapter'));
      expect(DBAdapter.registeredAdaptersTypes, contains(_CovAdapterTypeKey));

      var adapter = await DBAdapter.fromConfig({'cov.async.adapter': {}});
      expect(adapter, isA<DBObjectMemoryAdapter>());
      adapter.close();
    });

    test('instantiateAdaptor', () async {
      FutureOr<DBAdapter<Object>?> nullInstantiator(
        Map<String, dynamic> config, {
        int? minConnections,
        int? maxConnections,
        EntityRepositoryProvider? parentRepositoryProvider,
        String? workingPath,
      }) => null;

      FutureOr<DBAdapter<Object>?> asyncInstantiator(
        Map<String, dynamic> config, {
        int? minConnections,
        int? maxConnections,
        EntityRepositoryProvider? parentRepositoryProvider,
        String? workingPath,
      }) => Future<DBAdapter<Object>>.value(DBObjectMemoryAdapter());

      expect(
        () => DBAdapter.instantiateAdaptor<Object, DBAdapter<Object>>([], {}),
        throwsA(isA<StateError>()),
      );

      expect(
        () => DBAdapter.instantiateAdaptor<Object, DBAdapter<Object>>([
          MapEntry(nullInstantiator, {}),
        ], {}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains("Can't instantiate"),
          ),
        ),
      );

      var adapter =
          await DBAdapter.instantiateAdaptor<Object, DBAdapter<Object>>([
            MapEntry(nullInstantiator, {}),
            MapEntry(asyncInstantiator, {}),
          ], {});
      expect(adapter, isA<DBObjectMemoryAdapter>());
      adapter.close();
    });

    test('instantiateAdaptor: async instantiators (`Future<A?>`)', () async {
      // `async`: returns a `Future<DBAdapter<Object>?>` (not a
      // `Future<DBAdapter<Object>>`).
      Future<DBAdapter<Object>?> asyncInstantiator(
        Map<String, dynamic> config, {
        int? minConnections,
        int? maxConnections,
        EntityRepositoryProvider? parentRepositoryProvider,
        String? workingPath,
      }) async => DBObjectMemoryAdapter();

      Future<DBAdapter<Object>?> asyncNullInstantiator(
        Map<String, dynamic> config, {
        int? minConnections,
        int? maxConnections,
        EntityRepositoryProvider? parentRepositoryProvider,
        String? workingPath,
      }) async => null;

      var adapter =
          await DBAdapter.instantiateAdaptor<Object, DBAdapter<Object>>([
            MapEntry(asyncInstantiator, {}),
          ], {});
      expect(adapter, isA<DBObjectMemoryAdapter>());
      adapter.close();

      // An async `null` is skipped:
      var adapter2 =
          await DBAdapter.instantiateAdaptor<Object, DBAdapter<Object>>([
            MapEntry(asyncNullInstantiator, {}),
            MapEntry(asyncInstantiator, {}),
          ], {});
      expect(adapter2, isA<DBObjectMemoryAdapter>());
      adapter2.close();

      // Only async `null`s: an error.
      await expectLater(
        DBAdapter.instantiateAdaptor<Object, DBAdapter<Object>>([
          MapEntry(asyncNullInstantiator, {}),
        ], {}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains("Can't async instantiate"),
          ),
        ),
      );
    });

    test('DBRelationalAdapter.fromConfig', () async {
      var adapter = await DBRelationalAdapter.fromConfig({'sql.memory': {}});
      expect(adapter, isA<DBSQLMemoryAdapter>());
      adapter.close();

      expect(
        () => DBRelationalAdapter.fromConfig({'object.memory': {}}),
        throwsA(isA<StateError>()),
      );
    });

    test('DBRelationalAdapter.registerAdapter', () {
      DBRelationalAdapter.registerAdapter<Object, DBRelationalAdapter<Object>>(
        ['cov.rel.adapter'],
        _CovAdapterTypeKey,
        (
          config, {
          minConnections,
          maxConnections,
          parentRepositoryProvider,
          workingPath,
        }) => null,
      );

      expect(
        DBRelationalAdapter.registeredAdaptersNames,
        contains('cov.rel.adapter'),
      );
    });

    test('instances', () {
      var adapter = DBObjectMemoryAdapter();
      expect(DBAdapter.instances, contains(adapter));
      expect(DBAdapter.auxiliaryMode, isFalse);
      adapter.close();
    });
  });

  group('DBConnectionWrapper', () {
    test('basic', () {
      var c1 = _TestConnection('a');
      var c2 = _TestConnection('b');

      // The `id` is lazily assigned (on first access):
      var id1 = c1.id;
      expect(c2.id, equals(id1 + 1));
      expect(c1.id, equals(id1));
      expect(c1.nativeConnection, equals('a'));
      expect(c1.connectionURL, equals('test://a'));
      expect(c1.lastAccessTime, equals(c1.creationTime));

      var now = c1.creationTime.add(Duration(minutes: 10));
      expect(c1.timeSinceAccess(now: now), equals(Duration(minutes: 10)));
      expect(c1.isInactive(Duration(minutes: 5), now: now), isTrue);
      expect(c1.isInactive(Duration(minutes: 15), now: now), isFalse);

      c1.updateLastAccessTime(now: now);
      expect(c1.lastAccessTime, equals(now));
      expect(c1.timeSinceAccess(now: now), equals(Duration.zero));
      c1.updateLastAccessTime();
      expect(c1.lastAccessTime.isAfter(now), isFalse);

      expect(c1.isClosed, isFalse);
      expect(c1.info, equals('closed: false'));
      expect(c1.toString(), contains('_TestConnection#'));
      expect(c1.toString(), contains('@a'));

      // Closed by the native connection:
      c1.nativeClosed = true;
      expect(c1.isClosed, isTrue);
      expect(c1.closeImplCount, equals(0));

      c2.close();
      c2.close();
      expect(c2.isClosed, isTrue);
      expect(c2.closeImplCount, equals(1));
    });
  });

  group('DBAdapterException', () {
    test('toString', () {
      var op = TransactionOperationCount('repo', 'executor');

      var e = DBAdapterException(
        'type',
        'msg',
        operation: () => [op, null, 'x'],
        parentError: 'parent',
      );

      expect(e.runtimeTypeNameSafe, equals('DBAdapterException'));
      expect(e.resolveToString(null), isNull);
      expect(e.resolveToString(op), contains('count'));

      var s = e.toString();
      expect(s, startsWith('DBAdapterException[type]: msg'));
      expect(s, contains('count'));
      expect(s, contains('-- x'));
      expect(s, contains('Parent ERROR>> [String] parent'));
    });
  });

  group('DBEntityRepositoryProvider', () {
    test('adapter from config', () async {
      var provider = _ConfigProvider();
      expect(provider.workingPath, isNull);

      await provider.ensureInitialized();
      expect(provider.isInitialized, isTrue);

      var adapter = await provider.adapter;
      expect(adapter, isA<DBObjectMemoryAdapter>());
      expect(identical(await provider.adapter, adapter), isTrue);

      expect(provider.requiredAdapters(), isEmpty);
      expect(provider.requiredEntityRepositoryProviders(), isEmpty);

      provider.close();
    });

    test('duplicated repositories', () async {
      var provider = _ConfigProvider(duplicated: true);

      Object? error;
      InitializationResult? result;
      try {
        result = await provider.ensureInitialized();
      } catch (e) {
        error = e;
      }

      expect(
        error != null || (result != null && !result.ok),
        isTrue,
        reason: 'error: $error ; result: $result',
      );
      expect(provider.initializationStatus.failed, isTrue);
      expect(
        '${provider.initializationStatus.error}',
        contains('Duplicated repositories'),
      );

      provider.close();
    });
  });

  group('DBAdapter + DBEntityRepository', () {
    late _ConfigProvider provider;
    late DBAdapter adapter;

    setUpAll(() async {
      provider = _ConfigProvider();
      await provider.ensureInitialized();
      adapter = await provider.adapter;

      var userInfoRepo = provider.repo<UserInfo>();
      for (var i = 1; i <= 3; ++i) {
        await userInfoRepo.store(UserInfo('info-$i', id: i));
      }
      await provider.repo<Role>().store(Role(RoleType.admin, id: 1));
    });

    tearDownAll(() => provider.close());

    test('getEntityByID', () async {
      expect(adapter.getEntityByID(null, type: UserInfo), isNull);
      expect(adapter.getEntityByID(1), isNull);
      expect(adapter.getEntityByID(1, type: UserInfo, sync: true), isNull);

      var o = await adapter.getEntityByID<UserInfo>(1, type: UserInfo);
      expect(o?.info, equals('info-1'));

      // Not an entity type:
      expect(adapter.getEntityByID(1, type: RoleType), isNull);
      expect(adapter.getEntityByID(1, type: Duration), isNull);
    });

    test('repositories information', () async {
      var info = adapter.registeredEntityRepositoriesInformation;
      expect(info.keys.map((r) => r.name), containsAll(['user_info', 'role']));

      var tables = await adapter.getEntityRepositoresTables();
      expect(tables.values, containsAll(['user_info', 'role']));

      expect(
        adapter.registeredEntityRepositories.map((e) => e.name),
        containsAll(['user_info', 'role']),
      );

      expect(adapter.entityRepositoriesBuildOrder, hasLength(2));

      expect(adapter.allRepositories().keys, containsAll([UserInfo, Role]));
    });

    test('getTableForType', () {
      var tUserInfo = TypeInfo<UserInfo>.fromType(UserInfo);

      expect(adapter.getTableForType(tUserInfo), equals('user_info'));
      expect(
        adapter.getTableForType(
          TypeInfo<List<UserInfo>>.fromType(List, [tUserInfo]),
        ),
        equals('user_info'),
      );
      expect(
        adapter.getTableForType(
          TypeInfo<Map<String, UserInfo>>.fromType(Map, [
            TypeInfo.tString,
            tUserInfo,
          ]),
        ),
        equals('user_info'),
      );
      expect(
        adapter.getTableForType(
          TypeInfo<EntityReference<UserInfo>>.fromType(EntityReference, [
            tUserInfo,
          ]),
        ),
        equals('user_info'),
      );
      expect(adapter.getTableForType(TypeInfo.tString), isNull);
    });

    test('getEntityID / getFieldType / getEntityHandler', () async {
      expect(adapter.getEntityID(10), equals(10));
      expect(
        adapter.getEntityID({'id': 3, 'info': 'x'}, entityType: UserInfo),
        equals(3),
      );
      expect(adapter.getEntityID(UserInfo('x', id: 2)), equals(2));
      expect(adapter.getEntityID('no-entity'), isNull);

      var t = await adapter.getFieldType('info', entityName: 'user_info');
      expect(t?.type, equals(String));

      var t2 = await adapter.getFieldType('info', tableName: 'user_info');
      expect(t2?.type, equals(String));

      var t3 = await adapter.getFieldType('info', entityType: UserInfo);
      expect(t3?.type, equals(String));

      expect(await adapter.getFieldType('info', entityName: 'nope'), isNull);

      expect(adapter.getEntityHandler(entityType: Role)?.type, equals(Role));
    });

    test('repository adapters', () async {
      var ra = adapter.getRepositoryAdapterByName<UserInfo>('user_info');
      expect(ra, isNotNull);
      expect(ra!.name, equals('user_info'));
      expect(ra.tableName, equals('user_info'));
      expect(ra.dialect.name, equals('object'));
      expect(ra.dialectName, equals('object'));
      expect(identical(ra.schemeProvider, adapter), isTrue);
      expect(ra.toString(), contains('DBRepositoryAdapter{name: user_info'));
      expect(ra.information(), isA<Map>());

      expect(adapter.getRepositoryAdapterByType<Role>(Role)?.name, 'role');
      expect(adapter.getRepositoryAdapterByTableName<Role>('role')?.type, Role);
      expect(adapter.getRepositoryAdapterByName('nope'), isNull);

      expect(await adapter.checkConnections(), isTrue);
      expect(adapter.isPoolElementValid(adapter.createConnection()), isTrue);
    });

    test('DBEntityRepository basics', () async {
      var repo = provider.repo<UserInfo>();

      expect(repo.dialect.name, equals('object'));
      expect(repo.dialectName, equals('object'));
      expect(repo.tableName, equals('user_info'));
      expect(repo.isStored(UserInfo('x', id: 1)), isTrue);
      expect(repo.isStored(UserInfo('x')), isFalse);

      expect(repo.entityManager, same(adapter));
      expect(repo.isSameEntityManager(provider.repo<Role>()), isTrue);

      expect(
        () => repo.ensureReferencesStored(UserInfo('x')),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => repo.setRelationship(UserInfo('x', id: 1), 'info', ['a']),
        throwsA(isA<UnsupportedError>()),
      );
      expect(await repo.selectRelationship(null, 'info', oId: 1), isEmpty);
      expect(
        await repo.selectRelationships(null, 'info', oIds: [1, 2]),
        isEmpty,
      );

      expect(await repo.resolveEntities(Transaction(), null), isEmpty);
      expect(await repo.resolveEntities(Transaction(), []), isEmpty);
      var entries = <Map<String, dynamic>?>[
        {'id': 9, 'info': 'nine'},
        null,
      ];
      var resolved = await repo.resolveEntities(
        Transaction(),
        entries.where((e) => true),
      );
      expect(resolved.map((e) => e.info), equals(['nine']));

      expect(repo.hasReferencedEntities(), isFalse);
      expect(
        provider.repo<Role>().hasReferencedEntities(
          repo.resolveEntityResolutionRules(
            EntityResolutionRules(allEager: true),
          ),
        ),
        isFalse,
      );
    });

    test('store: tracked entity without changes', () async {
      var repo = provider.repo<UserInfo>();

      var o = await repo.selectByID(2);
      expect(o, isNotNull);
      expect(repo.isTrackingEntity(o!), isTrue);
      expect(repo.entityHasChangedFields(o), isFalse);

      // No changed fields: finished without an update.
      expect(await repo.store(o), equals(2));

      o.info = 'info-2b';
      expect(repo.getEntityChangedFields(o), equals(['info']));
      expect(await repo.store(o), equals(2));
      expect((await repo.selectByID(2))?.info, equals('info-2b'));
    });

    test('ensureStored', () async {
      var repo = provider.repo<UserInfo>();

      // Tracked and not changed:
      var o = await repo.selectByID(3);
      expect(await repo.ensureStored(o!), equals(3));

      // Not tracked, but exists:
      var o2 = UserInfo('info-3', id: 3);
      expect(await repo.ensureStored(o2), equals(3));

      // Not tracked and doesn't exist:
      var o3 = UserInfo('new-20', id: 20);
      expect(await repo.ensureStored(o3), equals(20));
      expect((await repo.selectByID(20))?.info, equals('new-20'));

      // Changed:
      o.info = 'info-3-changed';
      expect(await repo.ensureStored(o), equals(3));
      expect((await repo.selectByID(3))?.info, equals('info-3-changed'));

      // Inside a transaction with the entity already being stored:
      var o4 = UserInfo('new-21', id: 21);
      var t = Transaction();
      var r = await t.execute(() async {
        var f1 = repo.store(o4, transaction: t);
        var id = await repo.ensureStored(o4, transaction: t);
        await f1;
        return id;
      });
      expect(r, equals(21));
    });

    test('existIDs with cached entities', () async {
      var repo = provider.repo<UserInfo>();

      var t = Transaction();
      var r = await t.execute(() async {
        await repo.selectByID(1, transaction: t);

        var cachedOnly = await repo.existIDs<int>([1], transaction: t);
        var mixed = await repo.existIDs<int>([1, 2, 404], transaction: t);
        return [cachedOnly.toList(), mixed.toList()..sort()];
      });

      expect(
        r,
        equals([
          [1],
          [1, 2],
        ]),
      );
    });

    test('storeAll', () async {
      var repo = provider.repo<UserInfo>();

      var ids = await repo.storeAll([
        UserInfo('a', id: 31),
        UserInfo('b', id: 32),
      ]);
      expect(ids, equals([31, 32]));
      expect(await repo.existIDs<int>([31, 32]), hasLength(2));
    });

    test('closed adapter', () async {
      var provider2 = _ConfigProvider();
      await provider2.ensureInitialized();
      var adapter2 = await provider2.adapter;

      expect(adapter2.getRepositoryAdapterByName('user_info'), isNotNull);

      adapter2.close();

      expect(adapter2.isClosed, isTrue);
      expect(adapter2.getRepositoryAdapterByName('user_info'), isNull);
      expect(adapter2.getRepositoryAdapterByType(UserInfo), isNull);
      expect(adapter2.getRepositoryAdapterByTableName('user_info'), isNull);
      expect(adapter2.createRepositoryAdapter('x'), isNull);

      provider2.close();
    });
  });
}

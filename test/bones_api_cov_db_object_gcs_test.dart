@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(seconds: 60))
library;

import 'dart:convert';
import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_entity_db_object_gcs.dart';
import 'package:statistics/statistics.dart' show Decimal;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';
import 'bones_api_test_fake_gcs.dart';

class _GCSProvider extends DBEntityRepositoryProvider<DBObjectGCSAdapter> {
  final FakeGCS gcs;
  final Directory? cacheDirectory;
  final bool cacheDevelopment;
  final int? cacheLimit;
  final int? cacheFilesLimit;

  _GCSProvider(
    this.gcs, {
    this.cacheDirectory,
    this.cacheDevelopment = false,
    this.cacheLimit,
    this.cacheFilesLimit,
  });

  @override
  Map<String, dynamic> get adapterConfig => {};

  @override
  FutureOr<DBObjectGCSAdapter> buildAdapter() => DBObjectGCSAdapter(
    gcs.client,
    'cov-project',
    gcs.bucket,
    cacheDirectory: cacheDirectory,
    cacheDevelopment: cacheDevelopment,
    cacheLimit: cacheLimit,
    cacheFilesLimit: cacheFilesLimit,
    parentRepositoryProvider: this,
  );

  @override
  List<EntityRepository<Object>> buildRepositories(
    DBObjectGCSAdapter adapter,
  ) => [
    DBEntityRepository<Store>(
      adapter,
      'store',
      Store$reflection().entityHandler,
    ),
    DBEntityRepository<Role>(adapter, 'role', Role$reflection().entityHandler),
  ];

  DBEntityRepository<Store> get storeRepo =>
      getEntityRepositoryByType(Store) as DBEntityRepository<Store>;

  DBEntityRepository<Role> get roleRepo =>
      getEntityRepositoryByType(Role) as DBEntityRepository<Role>;
}

void main() {
  group('DBObjectGCSAdapter (fake GCS)', () {
    late FakeGCS gcs;
    late _GCSProvider provider;

    setUp(() async {
      gcs = FakeGCS('cov-bucket');
      provider = _GCSProvider(gcs);
      await provider.ensureInitialized();
    });

    tearDown(() => provider.close());

    // The stored object (in the bucket), its data fields:
    Map<String, dynamic>? stored(String file) {
      var bytes = gcs.objects[file];
      if (bytes == null) return null;
      var o = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      return {
        for (var k in ['id', 'name', 'number'])
          if (o.containsKey(k)) k: o[k],
      };
    }

    test('store: insert, multiple and partial updates', () async {
      var storeRepo = provider.storeRepo;

      // Insert:
      var s = Store('g1', 1, id: 901);
      expect(await storeRepo.store(s), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g1', 'number': 1});

      // A partial update (only `name`): `number` kept.
      s.name = 'g2';
      expect(await storeRepo.store(s), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g2', 'number': 1});

      // A partial update (only `number`): `name` kept.
      s.number = 2;
      expect(await storeRepo.store(s), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g2', 'number': 2});

      // Unchanged:
      expect(await storeRepo.store(s), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g2', 'number': 2});

      // Another instance with the same ID (an updated copy):
      expect(await storeRepo.store(Store('g3', 3, id: 901)), equals(901));
      expect(stored('store/901.json'), {'id': 901, 'name': 'g3', 'number': 3});

      // Read back (a new instance):
      var s2 = (await storeRepo.selectByID(901))!;
      expect(s2, isNot(same(s)));
      expect(s2.name, equals('g3'));
      expect(s2.number, equals(3));

      expect(await storeRepo.count(), equals(1));
      expect(await storeRepo.existsID(901), isTrue);
      expect(await storeRepo.existsID(999), isFalse);
      expect(await storeRepo.selectByID(999), isNull);
    });

    test('update: a read error fails it (the stored object kept)', () async {
      var storeRepo = provider.storeRepo;

      var s = Store('e1', 10, id: 902);
      expect(await storeRepo.store(s), equals(902));

      // The bucket read of the stored object fails (not a "not found"):
      gcs.failingReads.add('store/902.json');

      // A partial update (only `name`) can't merge with the stored object:
      // it fails (previously: stored with only `name`, `number` lost).
      s.name = 'e2';
      Object? error;
      try {
        await storeRepo.store(s);
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      expect('$error', contains('503'));

      // The stored object is unchanged (not overwritten):
      expect(stored('store/902.json'), {'id': 902, 'name': 'e1', 'number': 10});

      // Readable again: the update works.
      gcs.failingReads.clear();
      s.name = 'e3';
      expect(await storeRepo.store(s), equals(902));
      expect(stored('store/902.json'), {'id': 902, 'name': 'e3', 'number': 10});
    });

    test('a read error in a select: as not found', () async {
      var storeRepo = provider.storeRepo;

      expect(await storeRepo.store(Store('r1', 1, id: 903)), equals(903));

      gcs.failingReads.add('store/903.json');
      expect(await storeRepo.selectByID(903), isNull);

      gcs.failingReads.clear();
      expect((await storeRepo.selectByID(903))!.name, equals('r1'));
    });

    test('enum and Decimal fields (JSON encoded)', () async {
      var roleRepo = provider.roleRepo;

      var role = Role(RoleType.admin, id: 951, value: Decimal.parse('3.25'));
      expect(await roleRepo.store(role), equals(951));

      var json = jsonDecode(utf8.decode(gcs.objects['role/951.json']!)) as Map;
      expect(json['type'], equals('admin'));
      expect(json['value'], equals('3.25'));

      var role2 = (await roleRepo.selectByID(951))!;
      expect(role2.type, equals(RoleType.admin));
      expect(role2.value, equals(Decimal.parse('3.25')));
    });

    test('delete', () async {
      var storeRepo = provider.storeRepo;

      expect(await storeRepo.store(Store('d1', 1, id: 904)), equals(904));
      expect(gcs.objects.containsKey('store/904.json'), isTrue);

      var del = await storeRepo.deleteByID(904);
      expect(del?.name, equals('d1'));
      expect(gcs.objects.containsKey('store/904.json'), isFalse);
      expect(await storeRepo.deleteByID(904), isNull);
    });
  });

  group('DBObjectGCSAdapter cache', () {
    late Directory tmpDir;

    setUp(() => tmpDir = Directory.systemTemp.createTempSync('bones_api_gcs_'));
    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    List<File> cacheFiles(Directory dir) => dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    test('cacheDevelopment: the cache directory auto-created', () async {
      var gcs = FakeGCS('cov-dev');
      var cacheDir = Directory('${tmpDir.path}/not-yet/cache');
      expect(cacheDir.existsSync(), isFalse);

      var provider = _GCSProvider(
        gcs,
        cacheDirectory: cacheDir,
        cacheDevelopment: true,
      );
      await provider.ensureInitialized();
      addTearDown(provider.close);

      expect(await provider.storeRepo.store(Store('c1', 1, id: 1)), 1);

      // Created, and the object cached in it:
      expect(cacheDir.existsSync(), isTrue);
      expect(cacheFiles(cacheDir), hasLength(1));

      // Read from the cache (not the bucket):
      gcs.failingReads.add('store/1.json');
      expect((await provider.storeRepo.selectByID(1))!.name, equals('c1'));
    });

    test('the files limit: the oldest cached files removed', () async {
      var gcs = FakeGCS('cov-limit');

      var provider = _GCSProvider(
        gcs,
        cacheDirectory: tmpDir,
        cacheFilesLimit: 3,
        cacheLimit: 1024 * 1024,
      );
      await provider.ensureInitialized();
      addTearDown(provider.close);

      for (var i = 1; i <= 8; ++i) {
        expect(await provider.storeRepo.store(Store('s$i', i, id: i)), i);
      }

      // The limit check is asynchronous (on a store): wait for it.
      for (var i = 0; i < 50 && cacheFiles(tmpDir).length > 3; ++i) {
        await Future.delayed(Duration(milliseconds: 20));
      }
      expect(cacheFiles(tmpDir).length, lessThanOrEqualTo(3));

      // All in the bucket, and readable (also the ones not cached):
      expect(gcs.objects.length, equals(8));
      for (var i = 1; i <= 8; ++i) {
        expect((await provider.storeRepo.selectByID(i))!.name, equals('s$i'));
      }
    });

    test('the files limit: parallel stores (one check at a time)', () async {
      var gcs = FakeGCS('cov-limit-parallel');

      var provider = _GCSProvider(
        gcs,
        cacheDirectory: tmpDir,
        cacheFilesLimit: 3,
        cacheLimit: 1024 * 1024,
      );
      await provider.ensureInitialized();
      addTearDown(provider.close);

      // Each cache write over the limit starts a check: concurrent checks
      // deleted the same files (an unhandled `PathNotFoundException`).
      for (var round = 0; round < 5; ++round) {
        var ids = [for (var i = 1; i <= 12; ++i) round * 100 + i];
        await Future.wait(
          ids.map(
            (id) => Future.sync(
              () => provider.storeRepo.store(Store('p$id', id, id: id)),
            ),
          ),
        );
      }

      for (var i = 0; i < 50 && cacheFiles(tmpDir).length > 3; ++i) {
        await Future.delayed(Duration(milliseconds: 20));
      }
      expect(cacheFiles(tmpDir).length, lessThanOrEqualTo(3));
      expect(gcs.objects.length, equals(60));
    });
  });

  group('DBObjectGCSAdapter.fromConfig', () {
    Future<Object?> fromConfigError(Map<String, dynamic> config) async {
      try {
        await DBObjectGCSAdapter.fromConfig(config);
        return null;
      } catch (e) {
        return e;
      }
    }

    test('required: credential, project and bucket', () async {
      expect(
        '${await fromConfigError({})}',
        contains('Config without `credential`'),
      );
      expect(
        '${await fromConfigError({'credential': {}})}',
        contains('Config without `project`'),
      );
      expect(
        '${await fromConfigError({'credential': {}, 'project': 'p'})}',
        contains('Config without `bucket`'),
      );
    });

    test('cache and populate options (an invalid credential)', () async {
      // The options are parsed before the client is created: an invalid
      // credential (not a service account) fails without network access.
      for (var limit in ['2k', '3m', '1g', '100', '0', 'x']) {
        var error = await fromConfigError({
          'credential': {'type': 'not_a_service_account'},
          'project': 'p',
          'bucket': 'b',
          'cache': {
            'path': '/tmp/bones_api_gcs_config_test',
            'limit': limit,
            'filesLimit': '10',
            'development': true,
          },
          'populate': {
            'generateTables': true,
            'tables': [],
            'source': null,
            'variables': {},
          },
        });
        expect(error, isNotNull, reason: limit);
        expect(error, isNot(isA<StateError>()), reason: limit);
      }

      var error = await fromConfigError({
        'credential': {'type': 'not_a_service_account'},
        'project': 'p',
        'bucket': 'b',
        'cache': {'files-limit': '0', 'limit': ''},
      });
      expect(error, isNotNull);
    });
  });
}

@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(seconds: 60))
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';
import 'bones_api_test_entities.dart';

class _DBAPIRoot extends APIRoot {
  final List<EntityRepositoryProvider> providers;
  final APICredential? credential;
  final bool onlyOnDevelopment;

  _DBAPIRoot(
    String name,
    this.providers, {
    bool development = true,
    this.credential,
    this.onlyOnDevelopment = true,
  }) : super(name, '1.0', apiConfig: APIConfig({'development': development}));

  @override
  Set<APIModule> loadModules() => {
    APIDBModule(
      this,
      credential: credential,
      onlyOnDevelopment: onlyOnDevelopment,
    ),
  };

  @override
  FutureOr<List<EntityRepositoryProvider>> loadEntityRepositoryProviders() =>
      providers;
}

void main() {
  group('APIDBModule (memory DB)', () {
    late final TestEntityRepositoryProvider provider;
    late final TestEntityRepositoryProvider2 provider2;
    late final _DBAPIRoot apiRoot;

    final creationTime = DateTime.utc(2021, 9, 20, 10, 11, 12);

    setUpAll(() async {
      provider2 = createEntityRepositoryProvider2(
        true,
        (p, port, cfg) => DBObjectMemoryAdapter(parentRepositoryProvider: p),
        0,
        null,
      );

      provider = createEntityRepositoryProvider(
        true,
        (p, port, cfg) => DBSQLMemoryAdapter(parentRepositoryProvider: p),
        0,
        null,
      );

      await provider2.ensureInitialized();
      await provider.ensureInitialized();

      var address = Address(
        'NY',
        'New York',
        'street A',
        101,
        stores: [Store('s1', 1), Store('s2', 2)],
        closedStores: [Store('s0', 0)],
      );

      var user = User(
        'joe@test.com',
        '123',
        address,
        [Role(RoleType.admin), Role(RoleType.guest)],
        level: 10,
        userInfo: UserInfo('The user joe'),
        photo: Photo.from(png1PixelBase64),
        creationTime: creationTime,
      );

      var userId = await provider.userAPIRepository.store(user);
      expect(userId, equals(1));

      apiRoot = _DBAPIRoot('db-cov-api', [provider, provider2]);
      await apiRoot.ensureInitialized();
    });

    tearDownAll(() {
      apiRoot.close();
      provider.close();
      provider2.close();
    });

    Future<APIResponse> get(
      String path, {
      String query = '',
      Map<String, dynamic>? parameters,
    }) async {
      var uri = Uri.parse(
        'http://localhost$path${query.isEmpty ? '' : '?$query'}',
      );
      return apiRoot.call(
        APIRequest(
          APIRequestMethod.GET,
          path,
          parameters: parameters,
          requestedUri: uri,
        ),
      );
    }

    test('info', () async {
      var response = await get('/db/info');
      expect(response.isOK, isTrue);
      expect(response.payload, startsWith('Open Transactions ('));
    });

    test('tables (HTML)', () async {
      var response = await get('/db/tables');
      expect(response.isOK, isTrue);
      expect(response.payloadMimeType.toString(), contains('text/html'));

      var html = response.payload as String;
      expect(html, contains('<title>DB - Tables</title>'));
      expect(html, contains('DB[db-cov-api/1.0]'));
      expect(html, contains('<a href="/db/select/user">select</a>'));
      expect(html, contains('<a href="/db/insert/address">insert</a>'));
      expect(html, contains('<a href="/db/tables/json">JSON</a>'));
      expect(html, contains('Bones_API/${BonesAPI.VERSION}'));
    });

    test('tables (JSON)', () async {
      var response = await get('/db/tables/json');
      expect(response.isOK, isTrue);

      var map = response.payload as Map;
      expect(map['User'], equals('user'));
      expect(map['Address'], equals('address'));
      expect(map['Role'], equals('role'));
      expect(map['Photo'], equals('photo'));
      expect(map.keys.toList(), equals(map.keys.toList()..sort()));
    });

    test('default route is `tables`', () async {
      var response = await get('/db/foo');
      expect(response.isOK, isTrue);
      expect(response.payload, contains('DB - Tables'));
    });

    test('select (HTML) with entity references', () async {
      var response = await get('/db/select/user');
      expect(response.isOK, isTrue);

      var html = response.payload as String;
      expect(html, contains('<h2>User</h2>'));
      expect(html, contains('joe@test.com'));
      // `address` is a reference to another table:
      expect(html, contains('<a href="/db/update/address/1">1</a>'));
      // `roles` is a list of references:
      expect(
        html,
        contains(
          '<a href="/db/update/role/1">1</a> , <a href="/db/update/role/2">2</a>',
        ),
      );
      expect(html, contains('<a href="../update/user/1">edit</a>'));
      expect(html, contains('<a href="../delete/user/1">del</a>'));
      expect(html, contains('<a href="/db/insert/user">&nbsp;+&nbsp;</a>'));
      expect(html, contains('<a href="/db/select/user/json">JSON</a>'));
      expect(html, contains('Select / User'));

      // The `id` column comes first:
      var idxId = html.indexOf('<td style="text-align: center">id</td>');
      var idxEmail = html.indexOf('<td style="text-align: center">email</td>');
      expect(idxId, greaterThan(0));
      expect(idxEmail, greaterThan(idxId));
    });

    test('select (HTML) with a query', () async {
      var response = await get(
        '/db/select/address',
        query: Uri.encodeQueryComponent('state == "NY"'),
      );
      expect(response.isOK, isTrue);

      var html = response.payload as String;
      expect(html, contains('<h2>Address</h2>'));
      expect(html, contains('New York'));
      expect(
        html,
        contains('<a href="/db/select/address/json?state == "NY"">'),
      );

      var none = await get(
        '/db/select/address',
        query: Uri.encodeQueryComponent('state == "XX"'),
      );
      expect(none.isOK, isTrue);
      expect(none.payload, isNot(contains('New York')));
    });

    test('select (JSON) normalizes references', () async {
      var response = await get('/db/select/user/json/eager');
      expect(response.isOK, isTrue);

      var list = response.payload as List;
      expect(list.length, equals(1));

      var user = list.first as Map;
      expect(user['id'], equals(1));
      expect(user['email'], equals('joe@test.com'));
      expect(user['address'], equals(1));
      expect(user['roles'], equals([1, 2]));

      var addresses = (await get('/db/select/address/json')).payload as List;
      var address = addresses.single as Map;
      // References are normalized to IDs:
      var stores = address['stores'] as List;
      var closedStores = address['closedStores'] as List;
      expect(stores.length, equals(2));
      expect(closedStores.length, equals(1));
      expect({...stores, ...closedStores}, equals({1, 2, 3}));
    });

    test('select: unknown table', () async {
      var response = await get('/db/select/nope');
      expect(response.isError, isTrue);
      expect(response.error, contains("Can't find table: nope"));
    });

    test('insert: form', () async {
      var response = await get('/db/insert/role');
      expect(response.isOK, isTrue);

      var html = response.payload as String;
      expect(html, contains('<title>DB - insert @ Role</title>'));
      expect(html, contains('<form method="post">'));
      expect(html, contains('LOCAL_TIMEZONE'));
      expect(html, contains('<h2>Role:</h2>'));
      expect(html, contains('<button type="submit">Insert</button>'));
      expect(html, contains('function fixAllInputsDateTimeToLocal()'));
    });

    test('insert: form with references and list types', () async {
      var response = await get('/db/insert/user');
      expect(response.isOK, isTrue);

      var html = response.payload as String;
      expect(html, contains('<h2>User:</h2>'));
      expect(html, contains('List&lt;Role&gt;'));
      expect(html, contains('<span class="note">Address</span>'));
      expect(html, contains('EntityReference&lt;UserInfo&gt;</span>'));
      expect(html, contains('<span class="note">DateTime</span>'));

      var address = await get('/db/insert/address');
      expect(address.payload, contains('<span class="note">List&lt;Store&gt;'));
      expect(
        address.payload,
        contains('<span class="note">EntityReferenceList&lt;Store&gt;'),
      );
      expect(address.payload, contains('<span class="note">Decimal</span>'));
    });

    test('select (HTML) with an enum field', () async {
      // Ensures that the `RoleType` enum reflection is registered:
      expect(RoleType.admin.reflection.name(), equals('admin'));

      var response = await get('/db/select/role');
      expect(response.isOK, isTrue);

      var html = response.payload as String;
      expect(html, contains('<h2>Role</h2>'));
      expect(html, contains('<td style="text-align: center">admin</td>'));
      expect(html, contains('<td style="text-align: center">guest</td>'));
    });

    test('insert: storing error', () async {
      // `UserInfo.info` has a maximum length of 1000:
      var response = await get(
        '/db/insert/user_info',
        parameters: {'info': 'x' * 1001},
      );
      expect(response.isOK, isTrue);

      var html = response.payload as String;
      expect(html, contains('Error storing `UserInfo`'));
      expect(html, contains('EntityRepository: '));
      expect(html, isNot(contains('Inserted: #')));
    });

    test('insert: unknown table', () async {
      var response = await get('/db/insert/nope');
      expect(response.isError, isTrue);
      expect(response.error, contains("Can't find table: nope"));
    });

    test('insert and update a Role', () async {
      var response = await get(
        '/db/insert/role',
        parameters: {
          'type': 'guest',
          'enabled': 'true',
          '__LOCAL_TIMEZONE__': '0',
        },
      );
      expect(response.isOK, isTrue);

      var html = response.payload as String;
      var match = RegExp(r'Inserted: #(\d+)').firstMatch(html);
      expect(match, isNotNull, reason: html);
      var id = int.parse(match!.group(1)!);

      expect(html, contains('Role {'));
      expect(html, contains('"type": "guest"'));

      var role = await provider.roleAPIRepository.selectByID(id);
      expect(role?.type, equals(RoleType.guest));

      // Update form (no parameters):
      var form = await get('/db/update/role/$id');
      expect(form.isOK, isTrue);
      var formHtml = form.payload as String;
      expect(formHtml, contains('<title>DB - update @ Role</title>'));
      expect(formHtml, contains('<button type="submit">Update</button>'));
      expect(formHtml, contains('<a href="/db/select/role?id==$id">id</a>'));

      // Update with parameters:
      var updated = await get(
        '/db/update/role/$id',
        parameters: {'id': '$id', 'type': 'admin', 'enabled': 'false'},
      );
      expect(updated.isOK, isTrue);
      expect(updated.payload, contains('Updated: #$id'));

      var role2 = await provider.roleAPIRepository.selectByID(id);
      expect(role2?.type, equals(RoleType.admin));
      expect(role2?.enabled, isFalse);

      // An update of an unknown ID is an insert form:
      var notFound = await get('/db/update/role/9999');
      expect(notFound.isOK, isTrue);
      expect(
        notFound.payload,
        contains('<button type="submit">Insert</button>'),
      );
    });

    test('insert with local timezone fix', () async {
      var response = await get(
        '/db/insert/user_info',
        parameters: {'info': '2021-01-02T03:04:05', '__LOCAL_TIMEZONE__': '60'},
      );
      expect(response.isOK, isTrue);

      var html = response.payload as String;
      expect(html, contains('Inserted: #'));
    });

    test('delete: confirmation and deletion', () async {
      var stored = await provider.roleAPIRepository.store(
        Role(RoleType.unknown),
      );
      var id = stored as int;

      var confirm = await get('/db/delete/role/$id');
      expect(confirm.isOK, isTrue);
      var html = confirm.payload as String;
      expect(html, contains('<title>DB - delete @ Role</title>'));
      expect(html, contains('Delete? #$id'));
      expect(html, contains('Confirm Deletion'));
      expect(html, contains('/db/delete/role/$id?confirm=true'));

      expect(await provider.roleAPIRepository.existsID(id), isTrue);

      var deleted = await get(
        '/db/delete/role/$id',
        parameters: {'confirm': 'true'},
      );
      expect(deleted.isOK, isTrue);
      expect(deleted.payload, contains('Deleted: #$id'));

      expect(await provider.roleAPIRepository.existsID(id), isFalse);

      var again = await get('/db/delete/role/$id');
      expect(again.isNotFound, isTrue);
      expect(again.payload, contains("Can't find `Role` entity with ID: $id"));
    });

    test('delete: null ID and unknown table', () async {
      var noId = await get('/db/delete/role');
      expect(noId.isNotFound, isTrue);
      expect(noId.payload, equals('Null ID.'));

      var noTable = await get('/db/delete/nope/1');
      expect(noTable.isError, isTrue);
      expect(noTable.error, contains("Can't find table: nope"));
    });

    test('dump (JSON)', () async {
      var response = await get('/db/dump');
      expect(response.isOK, isTrue);

      var dump = response.payload as Map;
      expect(dump.keys, containsAll(['user', 'address', 'role', 'store']));
      expect(
        ((dump['user'] as List).single as Map)['email'],
        equals('joe@test.com'),
      );
      // Empty tables are omitted:
      for (var e in dump.values) {
        expect((e as List), isNotEmpty);
      }
    });

    test('dump (ZIP)', () async {
      var response = await get('/db/dump/zip');
      expect(response.isOK, isTrue);
      expect(response.payloadMimeType.toString(), contains('application/zip'));

      var disposition = response.headers['Content-Disposition'] as String;
      expect(
        disposition,
        matches(
          RegExp(r'^attachment; filename="db-dump--db_cov_api--\d+\.zip"$'),
        ),
      );

      var bytes = response.payload as Uint8List;
      var archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.files.length, equals(1));

      var file = archive.files.single;
      expect(file.name, endsWith('/dump.json'));

      var json =
          jsonDecode(utf8.decode(file.content as List<int>))
              as Map<String, dynamic>;
      expect(
        ((json['user'] as List).single as Map)['email'],
        equals('joe@test.com'),
      );
    });
  });

  group('APIDBModule (authentication and environment)', () {
    late final TestEntityRepositoryProvider provider;

    setUpAll(() async {
      provider = createEntityRepositoryProvider(
        true,
        (p, port, cfg) => DBSQLMemoryAdapter(parentRepositoryProvider: p),
        0,
        null,
      );
      await provider.ensureInitialized();
    });

    tearDownAll(() {
      provider.close();
    });

    test('credential required', () async {
      var credential = APICredential('admin', passwordHash: 'abc123');

      var apiRoot = _DBAPIRoot('db-cov-auth', [
        provider,
      ], credential: credential);
      await apiRoot.ensureInitialized();

      try {
        var noAuth = await apiRoot.call(APIRequest.get('/db/tables/json'));
        expect(noAuth.isUnauthorized, isTrue);
        expect(noAuth.requiresAuthentication, isTrue);
        expect(noAuth.authenticationRealm, equals('DB'));
        expect(noAuth.authenticationType, equals('Basic'));
        expect(noAuth.payload, equals('Authorization required.'));

        for (var route in [
          'info',
          'select/role',
          'insert/role',
          'update/role/1',
          'delete/role/1',
          'dump',
        ]) {
          var r = await apiRoot.call(APIRequest.get('/db/$route'));
          expect(r.isUnauthorized, isTrue, reason: route);
        }

        var wrong = await apiRoot.call(
          APIRequest.get(
            '/db/tables/json',
            credential: APICredential('other', passwordHash: 'abc123'),
          ),
        );
        expect(wrong.isUnauthorized, isTrue);

        var ok = await apiRoot.call(
          APIRequest.get(
            '/db/tables/json',
            credential: APICredential('admin', passwordHash: 'abc123'),
          ),
        );
        expect(ok.isOK, isTrue);
        expect((ok.payload as Map)['Role'], equals('role'));
      } finally {
        apiRoot.close();
      }
    });

    test('not development: no routes', () async {
      var apiRoot = _DBAPIRoot('db-cov-prod', [provider], development: false);
      await apiRoot.ensureInitialized();

      try {
        var module = apiRoot.getModule('db') as APIDBModule;
        expect(module.development, isFalse);
        expect(module.basePath, equals('/db/'));
        expect(module.allRoutesNames, isEmpty);

        var r = await apiRoot.call(APIRequest.get('/db/tables'));
        expect(r.isNotFound, isTrue);

        var request = APIRequest.get('/db/select/role');

        expect((await module.tables()).error, equals('Unsupported request!'));
        expect(
          (await module.select('role', request)).error,
          equals('Unsupported request!'),
        );
        expect(
          (await module.insert('role', request)).error,
          equals('Unsupported request!'),
        );
        expect(
          (await module.delete('role', request, 1)).error,
          equals('Unsupported request!'),
        );
        expect(
          (await module.dump(false)).error,
          equals('Unsupported request!'),
        );
      } finally {
        apiRoot.close();
      }
    });

    test('not development and not only on development: error', () async {
      var apiRoot = _DBAPIRoot(
        'db-cov-prod2',
        [provider],
        development: false,
        onlyOnDevelopment: false,
      );
      await apiRoot.ensureInitialized();

      try {
        var r = await apiRoot.call(APIRequest.get('/db/tables/json'));
        expect(r.isError, isTrue);
        expect(r.error.toString(), contains('Not a `development` environment'));
      } finally {
        apiRoot.close();
      }
    });
  });
}

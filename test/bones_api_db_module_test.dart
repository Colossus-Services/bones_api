@TestOn('vm')
@Tags(['entities'])
// ignore_for_file: discarded_futures
import 'package:bones_api/bones_api.dart';
import 'package:statistics/statistics.dart' show Decimal;
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

class _DBModuleTestProvider extends EntityRepositoryProvider {
  late final DBSQLMemoryAdapter sqlAdapter;

  late final DBSQLEntityRepository<Role> roleRepository;

  _DBModuleTestProvider() {
    sqlAdapter = DBSQLMemoryAdapter(parentRepositoryProvider: this)
      ..addTableSchemes([
        TableScheme(
          'role',
          idFieldName: 'id',
          fieldsTypes: {
            'id': int,
            'type': String,
            'enabled': bool,
            'value': Decimal,
          },
        ),
      ]);

    roleRepository = DBSQLEntityRepository<Role>(
      sqlAdapter,
      'role',
      roleEntityHandler,
    )..ensureInitialized();
  }
}

class _DBModuleTestAPIRoot extends APIRoot {
  final _DBModuleTestProvider provider;

  _DBModuleTestAPIRoot(this.provider)
    : super(
        'db-module-test',
        '1.0',
        apiConfig: APIConfig({'development': true}),
      );

  @override
  Set<APIModule> loadModules() => {APIDBModule(this)};

  @override
  FutureOr<List<EntityRepositoryProvider>> loadEntityRepositoryProviders() => [
    provider,
  ];
}

void main() {
  group('APIDBModule.select', () {
    late final _DBModuleTestProvider provider;
    late final _DBModuleTestAPIRoot apiRoot;

    // The IDs of the 5 stored roles, in ascending order:
    late final List<int> ids;

    setUpAll(() async {
      roleEntityHandler.ensureRegistered();

      provider = _DBModuleTestProvider();
      await provider.ensureInitialized();

      var stored = <int>[];
      for (var i = 1; i <= 5; ++i) {
        var role = Role(i.isEven ? RoleType.admin : RoleType.guest);
        stored.add((await provider.roleRepository.store(role)) as int);
      }
      ids = stored;
      expect(ids, equals([1, 2, 3, 4, 5]));

      apiRoot = _DBModuleTestAPIRoot(provider);
      await apiRoot.ensureInitialized();
    });

    tearDownAll(() {
      apiRoot.close();
      provider.close();
    });

    /// Calls `/db/select/role/json` with the raw [query] `String`.
    Future<List<Object?>> selectIDs([String query = '']) async {
      var path = '/db/select/role/json';
      var uri = Uri.parse(
        'http://localhost$path${query.isEmpty ? '' : '?$query'}',
      );

      var response = await apiRoot.call(
        APIRequest(APIRequestMethod.GET, path, requestedUri: uri),
      );

      expect(response.isOK, isTrue, reason: 'Response: $response');

      var entities = response.payload as List;
      return entities.map((e) => (e as Map)['id']).toList();
    }

    test('default: ID-ordered, resolved by the DB', () async {
      // REGRESSION: this endpoint has always returned ID-sorted entities.
      // The sort moved from Dart to the DB; the output must not change.
      expect(await selectIDs(), equals(ids));
    });

    test('LIMIT', () async {
      expect(await selectIDs('LIMIT=2'), equals([1, 2]));
      expect(await selectIDs('LIMIT=5'), equals(ids));
      expect(await selectIDs('LIMIT=100'), equals(ids));
    });

    test('OFFSET', () async {
      expect(await selectIDs('OFFSET=3'), equals([4, 5]));
      expect(await selectIDs('OFFSET=5'), isEmpty);
    });

    test('LIMIT and OFFSET', () async {
      expect(await selectIDs('LIMIT=2&OFFSET=2'), equals([3, 4]));
      expect(await selectIDs('OFFSET=2&LIMIT=2'), equals([3, 4]));
    });

    test('ORDER', () async {
      expect(await selectIDs('ORDER=desc'), equals([5, 4, 3, 2, 1]));
      expect(await selectIDs('ORDER=DESC&LIMIT=2'), equals([5, 4]));
      expect(await selectIDs('ORDER=asc&LIMIT=2'), equals([1, 2]));
      expect(
        await selectIDs('ORDER=descending&LIMIT=2&OFFSET=1'),
        equals([4, 3]),
      );
    });

    test('PAGE', () async {
      expect(await selectIDs('LIMIT=2&PAGE=1'), equals([1, 2]));
      expect(await selectIDs('LIMIT=2&PAGE=2'), equals([3, 4]));
      expect(await selectIDs('LIMIT=2&PAGE=3'), equals([5]));
      expect(await selectIDs('LIMIT=2&PAGE=4'), isEmpty);

      expect(await selectIDs('PAGE=2&LIMIT=2&ORDER=desc'), equals([3, 2]));

      // `PAGE` is equivalent to the `OFFSET` it computes:
      expect(
        await selectIDs('LIMIT=2&PAGE=2'),
        equals(await selectIDs('LIMIT=2&OFFSET=2')),
      );
    });

    test('an invalid PAGE is an error response, not a crash', () async {
      FutureOr<APIResponse> call(String query) => apiRoot.call(
        APIRequest(
          APIRequestMethod.GET,
          '/db/select/role/json',
          requestedUri: Uri.parse(
            'http://localhost/db/select/role/json?$query',
          ),
        ),
      );

      // `PAGE` without a `LIMIT`:
      var noLimit = await call('PAGE=2');
      expect(noLimit.isOK, isFalse);
      expect(noLimit.toString(), contains('Invalid pagination'));

      // `PAGE` together with an `OFFSET`:
      var withOffset = await call('LIMIT=2&PAGE=2&OFFSET=2');
      expect(withOffset.isOK, isFalse);
      expect(withOffset.toString(), contains('Invalid pagination'));

      // `PAGE` below 1:
      var zero = await call('LIMIT=2&PAGE=0');
      expect(zero.isOK, isFalse);
      expect(zero.toString(), contains('Invalid pagination'));

      // An unparsable `PAGE` is ignored, like the other directives:
      expect(await selectIDs('LIMIT=2&PAGE=abc'), equals([1, 2]));
    });

    test('paging through reassembles the full set exactly once', () async {
      var pages = <List<Object?>>[];
      for (var offset = 0; offset < ids.length; offset += 2) {
        pages.add(await selectIDs('LIMIT=2&OFFSET=$offset'));
      }

      expect(pages.map((p) => p.length), equals([2, 2, 1]));
      expect(pages.expand((p) => p).toList(), equals(ids));
    });

    test('EAGER=true still works, alone and with the new directives', () async {
      // Backward-compat guard for the rewritten directive stripping:
      expect(await selectIDs('EAGER=true'), equals(ids));
      expect(await selectIDs('EAGER=true&LIMIT=2'), equals([1, 2]));
      expect(await selectIDs('LIMIT=2&EAGER=true'), equals([1, 2]));
      expect(await selectIDs('LIMIT=2&EAGER=true&ORDER=desc'), equals([5, 4]));
    });

    test('an entity query is preserved alongside the directives', () async {
      // Roles 2 and 4 are `admin`; the rest are `guest`.
      expect(await selectIDs('type == "admin"'), equals([2, 4]));

      expect(await selectIDs('type == "admin"&LIMIT=1'), equals([2]));

      expect(
        await selectIDs('type == "admin"&LIMIT=1&ORDER=desc'),
        equals([4]),
      );

      expect(await selectIDs('type == "guest"&OFFSET=1'), equals([3, 5]));

      expect(
        await selectIDs('EAGER=true&type == "admin"&OFFSET=1'),
        equals([4]),
      );
    });

    test('an unparsable directive value is ignored', () async {
      expect(await selectIDs('LIMIT=abc'), equals(ids));
      expect(await selectIDs('OFFSET=abc'), equals(ids));
      expect(await selectIDs('ORDER=sideways'), equals(ids));
    });

    test('selectQueryDirectives', () {
      expect(
        APIDBModule.selectQueryDirectives,
        equals(['EAGER', 'LIMIT', 'OFFSET', 'PAGE', 'ORDER']),
      );
    });
  });
}

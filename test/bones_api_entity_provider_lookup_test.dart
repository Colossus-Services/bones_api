@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A provider with a [DBSQLMemoryAdapter] and the repositories of
/// [handlers]. Closed at the test's end.
class _LookupTestProvider extends EntityRepositoryProvider {
  late final DBSQLMemoryAdapter sqlAdapter;

  _LookupTestProvider({
    EntityHandler<Address>? address,
    EntityHandler<Role>? role,
  }) {
    sqlAdapter = DBSQLMemoryAdapter(parentRepositoryProvider: this);
    if (address != null) {
      DBSQLEntityRepository<Address>(sqlAdapter, 'address', address);
    }
    if (role != null) {
      DBSQLEntityRepository<Role>(sqlAdapter, 'role', role);
    }

    addTearDown(() {
      sqlAdapter.close();
      close();
    });
  }
}

void main() {
  group('EntityRepositoryProvider lookup', () {
    test('a miss across many providers: each asked once (not N!)', () {
      // All known to each other (the global provider knows them all):
      var providers = [
        for (var i = 0; i < 12; ++i)
          _LookupTestProvider(address: Address$reflection().entityHandler),
      ];

      var stopwatch = Stopwatch()..start();

      for (var p in providers) {
        // `Store`: no provider has it.
        expect(p.getEntityRepositoryByType(Store), isNull);
        expect(p.getEntityRepository(type: Store), isNull);
        expect(p.getEntityRepository(name: 'store'), isNull);
        expect(p.sqlAdapter.getEntityRepositoryByType(Store), isNull);
        expect(p.sqlAdapter.getEntityRepository(name: 'store'), isNull);
      }

      stopwatch.stop();

      // A walk of every order of 12 providers (12! = 479M) would never end:
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('found: its own, or in another provider', () {
      var withAddress = _LookupTestProvider(
        address: Address$reflection().entityHandler,
      );
      var withRole = _LookupTestProvider(role: Role$reflection().entityHandler);

      var addressRepository = withAddress.getEntityRepositoryByType(Address);
      expect(addressRepository, isNotNull);
      expect(addressRepository!.type, Address);

      var roleRepository = withRole.getEntityRepositoryByType(Role);
      expect(roleRepository, isNotNull);

      // In another provider (through the global one):
      expect(withRole.getEntityRepositoryByType(Address), addressRepository);
      expect(withAddress.getEntityRepositoryByType(Role), roleRepository);
      expect(withRole.getEntityRepository(name: 'address'), addressRepository);
      expect(
        withAddress.sqlAdapter.getEntityRepositoryByType(Role),
        roleRepository,
      );

      // The same again (the lookup state is reset after each one):
      expect(withRole.getEntityRepositoryByType(Address), addressRepository);
      expect(withAddress.getEntityRepositoryByType(Address), addressRepository);
    });

    test('a closed provider: not asked', () {
      var withAddress = _LookupTestProvider(
        address: Address$reflection().entityHandler,
      );
      var withRole = _LookupTestProvider(role: Role$reflection().entityHandler);

      expect(withRole.getEntityRepositoryByType(Address), isNotNull);

      withAddress.sqlAdapter.close();
      withAddress.close();

      expect(withAddress.getEntityRepositoryByType(Address), isNull);
      expect(withRole.getEntityRepositoryByType(Address), isNull);
    });

    test('an error in a lookup: the next one not affected', () {
      // Two providers with an `Address` repository: ambiguous from a third.
      _LookupTestProvider(address: Address$reflection().entityHandler);
      _LookupTestProvider(address: Address$reflection().entityHandler);
      var other = _LookupTestProvider(role: Role$reflection().entityHandler);

      expect(
        () => other.getEntityRepositoryByType(Address),
        throwsA(isA<StateError>()),
      );

      // The lookup state was reset: its own repository found.
      expect(other.getEntityRepositoryByType(Role), isNotNull);
    });

    test('allRepositories: providers known to each other', () {
      var p1 = _LookupTestProvider(address: Address$reflection().entityHandler);
      var p2 = _LookupTestProvider(role: Role$reflection().entityHandler);

      // A cycle:
      p1.notifyKnownEntityRepositoryProvider(p2);
      p2.notifyKnownEntityRepositoryProvider(p1);

      var all = p1.allRepositories();
      expect(all.keys, containsAll([Address, Role]));

      var all2 = p2.sqlAdapter.allRepositories();
      expect(all2.keys, contains(Role));
    });
  });
}

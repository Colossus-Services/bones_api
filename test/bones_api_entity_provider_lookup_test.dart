@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A provider with a [DBSQLMemoryAdapter] and the repositories of
/// [handlers]. Closed at the test's end. Counts the lookups that enter it.
class _LookupTestProvider extends EntityRepositoryProvider {
  late final DBSQLMemoryAdapter sqlAdapter;

  /// The calls of [getEntityRepository] / [getEntityRepositoryByType].
  int lookups = 0;

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

  @override
  EntityRepository<O>? getEntityRepository<O extends Object>({
    O? obj,
    Type? type,
    String? name,
    Set<EntityRepositoryProvider>? traversed,
  }) {
    ++lookups;
    return super.getEntityRepository<O>(
      obj: obj,
      type: type,
      name: name,
      traversed: traversed,
    );
  }

  @override
  EntityRepository<O>? getEntityRepositoryByType<O extends Object>(
    Type type, {
    Set<EntityRepositoryProvider>? traversed,
  }) {
    ++lookups;
    return super.getEntityRepositoryByType<O>(type, traversed: traversed);
  }
}

/// A provider that, when asked in a lookup, starts another (nested) lookup:
/// [nested], its result.
class _NestedLookupProvider extends _LookupTestProvider {
  final EntityRepositoryProvider nestedFrom;
  final Type nestedType;

  EntityRepository? nested;

  _NestedLookupProvider(this.nestedFrom, this.nestedType);

  @override
  EntityRepository<O>? getEntityRepositoryByType<O extends Object>(
    Type type, {
    Set<EntityRepositoryProvider>? traversed,
  }) {
    if (traversed != null && type != nestedType) {
      // Not part of the current lookup: a new one.
      nested = nestedFrom.getEntityRepositoryByType(nestedType);
    }
    return super.getEntityRepositoryByType<O>(type, traversed: traversed);
  }
}

/// A provider that looks itself up while initializing: [foundInInitialize].
class _InitLookupProvider extends _LookupTestProvider {
  EntityRepository? foundInInitialize;
  bool initialized = false;

  _InitLookupProvider() : super(role: Role$reflection().entityHandler);

  @override
  FutureOr<InitializationResult> initialize() {
    foundInInitialize = getEntityRepositoryByType(Role);
    initialized = true;
    return super.initialize();
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

      for (var p in providers) {
        // `Store`: no provider has it.
        expect(p.getEntityRepositoryByType(Store), isNull);
        expect(p.getEntityRepository(type: Store), isNull);
        expect(p.getEntityRepository(name: 'store'), isNull);
        expect(p.sqlAdapter.getEntityRepositoryByType(Store), isNull);
        expect(p.sqlAdapter.getEntityRepository(name: 'store'), isNull);
      }

      for (var p in providers) {
        p.lookups = 0;
      }

      // One miss: each provider entered a few times (once per provider that
      // knows it: the global one, its adapter), asked once. Walking every
      // order of 12 providers (12! = 479M) would enter them millions of
      // times.
      expect(providers.first.getEntityRepositoryByType(Store), isNull);

      for (var p in providers) {
        expect(p.lookups, inInclusiveRange(1, 3), reason: '$p');
      }
    });

    test('a hit in the own repositories: not past them', () {
      var p1 = _LookupTestProvider(address: Address$reflection().entityHandler);
      var p2 = _LookupTestProvider(role: Role$reflection().entityHandler);

      p2.lookups = 0;
      expect(p1.getEntityRepositoryByType(Address), isNotNull);
      expect(p1.getEntityRepository(name: 'address'), isNotNull);

      // Found in `p1` (or its adapter): no other provider asked (not even
      // through the global provider).
      expect(p2.lookups, 0);
    });

    test('a nested lookup: independent of the current one', () {
      var withAddress = _LookupTestProvider(
        address: Address$reflection().entityHandler,
      );
      var nesting = _NestedLookupProvider(withAddress, Address);

      // A miss from `withAddress` (asked first): `nesting` asked later
      // starts a lookup of `Address` from `withAddress`, found (not skipped
      // as already asked in the current lookup).
      expect(withAddress.getEntityRepositoryByType(Store), isNull);
      expect(nesting.nested, isNotNull);
      expect(nesting.nested!.type, Address);
    });

    test('a self lookup while initializing: found', () {
      var p = _InitLookupProvider();
      addTearDown(() => p.close());

      var roleRepository = p.getEntityRepositoryByType(Role);
      expect(roleRepository, isNotNull);

      expect(p.initialized, isTrue);
      expect(p.foundInInitialize, roleRepository);
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

// Integration tests: multiple simultaneous (parallel) reads and stores of
// entities, and transactions, over a DB adapter (see the
// `bones_api_concurrency_*_test.dart` files: the CI `concurrency` job).

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_entity_db_tests_base.dart';
import 'bones_api_test_entities.dart';

/// The providers of a SQL adapter for [runConcurrencyTests] (as
/// `runAdapterTests`): the `Photo` repository (of `User.photo`) in a second
/// provider, over a [DBObjectMemoryAdapter].
class ConcurrencySQLProviders {
  final DBAdapterCreator<DBSQLAdapter> sqlAdapterCreator;

  ConcurrencySQLProviders(this.sqlAdapterCreator);

  TestEntityRepositoryProvider2? _photoProvider;

  /// Creates and initializes the providers ([dbPort] and [dbConfig] of the
  /// DB to the [sqlAdapterCreator]).
  Future<EntityRepositoryProvider> setUp({
    int dbPort = 0,
    Map<String, dynamic>? dbConfig,
  }) async {
    var photoProvider = _photoProvider = createEntityRepositoryProvider2(
      true,
      (p, dbPort, dbConfig) =>
          DBObjectMemoryAdapter(parentRepositoryProvider: p),
      dbPort,
      dbConfig,
    );

    var provider = createEntityRepositoryProvider(
      true,
      sqlAdapterCreator,
      dbPort,
      dbConfig,
    );

    await photoProvider.ensureInitialized();
    await provider.ensureInitialized();

    return provider;
  }

  void close() => _photoProvider?.close();
}

/// What an adapter supports, for the concurrency tests.
class ConcurrencyCapabilities {
  /// An aborted transaction rolls back its writes.
  final bool rollback;

  /// The unique fields are enforced (`@EntityField.unique()`): not by the
  /// object adapters (see `DBObjectAdapter`).
  final bool uniqueEnforced;

  /// No dirty reads between concurrent transactions (e.g. PostgreSQL and
  /// MySQL; not SQLite, that serializes the writers, nor the memory
  /// adapters, without isolation).
  final bool isolation;

  /// Parallel partial updates of the same entity (different fields) are all
  /// applied (not a GCS read-modify-write: see `DBObjectGCSAdapter`).
  final bool concurrentPartialUpdates;

  /// An aborted transaction rolls back only its own writes (not the ones of
  /// concurrent transactions: `DBSQLMemoryAdapter` and `DBObjectMemoryAdapter`
  /// revert their tables to a version, also reverting the later writes of
  /// other transactions).
  final bool isolatedRollback;

  /// The adapter generates the IDs of new entities (not the object adapters:
  /// the tests define them).
  final bool generatesIDs;

  const ConcurrencyCapabilities({
    this.generatesIDs = true,
    this.rollback = true,
    this.uniqueEnforced = true,
    this.isolation = false,
    this.concurrentPartialUpdates = true,
    this.isolatedRollback = true,
  });
}

/// The number of parallel operations of each test.
const int concurrencyParallel = 50;

/// The number of mixed operations of the connection pool pressure test.
const int concurrencyPoolPressure = 100;

/// Runs the concurrency tests over the [EntityRepositoryProvider] created by
/// [setUp] (with the `Store`, `Address`, `Role`, `UserInfo` and `User`
/// repositories, and their tables), closed by [tearDown].
void runConcurrencyTests(
  String name, {
  required Future<EntityRepositoryProvider> Function() setUp,
  FutureOr<void> Function()? tearDown,
  ConcurrencyCapabilities capabilities = const ConcurrencyCapabilities(),
}) {
  group('Concurrency[$name]', () {
    late EntityRepositoryProvider provider;

    setUpAll(() async => provider = await setUp());

    tearDownAll(() async {
      provider.close();
      await tearDown?.call();
    });

    EntityRepository<O> repo<O extends Object>() =>
        provider.getEntityRepositoryByType(O)! as EntityRepository<O>;

    var tagCount = 0;
    // A unique prefix for the values of a test (not the ones of others):
    String newTag() =>
        'cc${DateTime.now().microsecondsSinceEpoch}${++tagCount}';

    // Starts [f] now (not in a later event): truly simultaneous operations.
    Future<T> now<T>(FutureOr<T> Function() f) => Future<T>.sync(f);

    // Rolled back: the `Store` [id] is missing or another one (by ID and
    // value: SQLite reuses the ID of a rolled back insert; the object
    // adapters only select by ID).
    Future<void> expectNoStore(Object? id, String name) async {
      var o = await repo<Store>().selectByID(id);
      expect(o?.name, isNot(equals(name)), reason: 'Store `$name` stored');
    }

    Future<void> expectNoUser(Object? id, String email) async {
      var o = await repo<User>().selectByID(id);
      expect(o?.email, isNot(equals(email)), reason: 'User `$email` stored');
    }

    // The adapter generates the IDs, or (an object adapter) the test does:
    var idCount = 0;
    int? newID() => capabilities.generatesIDs ? null : ++idCount;

    Store newStore(String name, int number) => Store(name, number, id: newID());

    User newUser(String email, String state) => User(
      email,
      'pass',
      Address(state, 'City', 'Street', 1, id: newID()),
      [Role(RoleType.guest, id: newID()), Role(RoleType.unknown, id: newID())],
      creationTime: DateTime.utc(2024, 1, 2),
      id: newID(),
    );

    // Stores [user]: a reference with an ID counts as stored, so with the
    // IDs defined by the test, the `Address` and `Role`s are stored first.
    Future<Object?> storeUser(User user) async {
      if (!capabilities.generatesIDs) {
        await repo<Address>().store(user.address);
        await repo<Role>().storeAll(user.roles);
      }
      return repo<User>().store(user);
    }

    group('parallel reads and stores', () {
      test('A1: parallel inserts', () async {
        var storeRepo = repo<Store>();
        var tag = newTag();

        var count0 = await storeRepo.count();

        var ids = await Future.wait([
          for (var i = 0; i < concurrencyParallel; ++i)
            now(() => storeRepo.store(newStore('$tag-$i', i))),
        ]);

        expect(ids, everyElement(isNotNull));
        expect(ids.toSet(), hasLength(concurrencyParallel));
        expect(await storeRepo.count(), equals(count0 + concurrencyParallel));

        var stores = await Future.wait([
          for (var id in ids) now(() => storeRepo.selectByID(id)),
        ]);

        for (var i = 0; i < concurrencyParallel; ++i) {
          expect(stores[i]!.name, equals('$tag-$i'));
          expect(stores[i]!.number, equals(i));
        }
      });

      test('A2: reads interleaved with inserts', () async {
        var storeRepo = repo<Store>();
        var tag = newTag();

        var seed = await storeRepo.store(newStore('$tag-seed', -1));
        var count0 = await storeRepo.count();

        var inserts = <Future<Object?>>[];
        var reads = <Future<Object?>>[];

        for (var i = 0; i < concurrencyParallel; ++i) {
          inserts.add(now(() => storeRepo.store(newStore('$tag-$i', i))));
          reads.add(now(() => storeRepo.selectByID(seed)));
          reads.add(now(() => storeRepo.count()));
          reads.add(now(() => storeRepo.selectAll(limit: 10)));
        }

        var ids = await Future.wait(inserts);
        var results = await Future.wait(reads);

        for (var r in results) {
          if (r is Store) {
            expect(r.name, equals('$tag-seed'));
          } else if (r is int) {
            expect(r, inInclusiveRange(count0, count0 + concurrencyParallel));
          } else if (r is Iterable) {
            // Complete entities (not partially built):
            for (var s in r.cast<Store>()) {
              expect(s.id, isNotNull);
              expect(s.name, isNotEmpty);
            }
          }
        }

        expect(ids.toSet(), hasLength(concurrencyParallel));
        expect(await storeRepo.count(), equals(count0 + concurrencyParallel));
      });

      test('A3: parallel partial updates of different entities', () async {
        var storeRepo = repo<Store>();
        var tag = newTag();

        var stores = [
          for (var i = 0; i < concurrencyParallel; ++i) newStore('$tag-$i', i),
        ];
        await Future.wait([
          for (var s in stores) now(() => storeRepo.store(s)),
        ]);

        // Even: `name` changed; odd: `number` changed.
        for (var i = 0; i < stores.length; ++i) {
          if (i.isEven) {
            stores[i].name = '$tag-$i-b';
          } else {
            stores[i].number = i * 1000;
          }
        }
        await Future.wait([
          for (var s in stores) now(() => storeRepo.store(s)),
        ]);

        var read = await Future.wait([
          for (var s in stores) now(() => storeRepo.selectByID(s.id)),
        ]);

        for (var i = 0; i < stores.length; ++i) {
          var s = read[i]!;
          expect(s, isNot(same(stores[i])));
          if (i.isEven) {
            expect(s.name, equals('$tag-$i-b'));
            expect(s.number, equals(i));
          } else {
            expect(s.name, equals('$tag-$i'));
            expect(s.number, equals(i * 1000));
          }
        }
      });

      test(
        'A4: parallel partial updates of the same entity (other fields)',
        () async {
          var storeRepo = repo<Store>();
          var tag = newTag();

          var id = await storeRepo.store(newStore('$tag-a', 1));

          // Two tracked instances of the same entity:
          var a = (await storeRepo.selectByID(id))!;
          var b = (await storeRepo.selectByID(id))!;
          expect(a, isNot(same(b)));

          a.name = '$tag-b';
          b.number = 2;

          await Future.wait([
            now(() => storeRepo.store(a)),
            now(() => storeRepo.store(b)),
          ]);

          var s = (await storeRepo.selectByID(id))!;
          expect(s.name, equals('$tag-b'));
          expect(s.number, equals(2));
        },
        skip: capabilities.concurrentPartialUpdates
            ? false
            : 'A read-modify-write object storage (lost updates: GCS)',
      );

      test('A5: parallel stores and reads with references', () async {
        var userRepo = repo<User>();
        var tag = newTag();

        var n = concurrencyParallel ~/ 5;

        var users = [
          for (var i = 0; i < n; ++i) newUser('$tag-$i@mail.com', 'S$i'),
        ];

        var ids = await Future.wait([
          for (var u in users) now(() => storeUser(u)),
        ]);
        expect(ids.toSet(), hasLength(n));

        var read = await Future.wait([
          for (var id in ids)
            now(
              () => userRepo.selectByID(
                id,
                resolutionRules: EntityResolutionRules(allEager: true),
              ),
            ),
        ]);

        var addressesIDs = <Object?>{};
        var rolesIDs = <Object?>{};

        for (var i = 0; i < n; ++i) {
          var u = read[i]!;
          expect(u.email, equals('$tag-$i@mail.com'));
          expect(u.address.state, equals('S$i'));
          expect(
            u.roles.map((r) => r.type),
            unorderedEquals([RoleType.guest, RoleType.unknown]),
          );

          addressesIDs.add(u.address.id);
          rolesIDs.addAll(u.roles.map((r) => r.id));
        }

        // Each user with its own references (stored once each):
        expect(addressesIDs, hasLength(n));
        expect(rolesIDs, hasLength(n * 2));
      });

      test('A6: connection pool pressure', () async {
        var storeRepo = repo<Store>();
        var tag = newTag();

        var ids = await Future.wait([
          for (var i = 0; i < concurrencyParallel; ++i)
            now(() => storeRepo.store(newStore('$tag-$i', i))),
        ]);

        var ops = <Future<Object?>>[
          for (var i = 0; i < concurrencyPoolPressure; ++i)
            switch (i % 4) {
              0 => now(() => storeRepo.store(newStore('$tag-p$i', i))),
              1 => now(() => storeRepo.selectByID(ids[i % ids.length])),
              2 => now(() => storeRepo.count()),
              _ => now(() => storeRepo.existsID(ids[i % ids.length])),
            },
        ];

        // All complete (no deadlock, no pool timeout):
        var results = await Future.wait(ops).timeout(Duration(seconds: 60));
        expect(results, hasLength(concurrencyPoolPressure));

        await Future.delayed(Duration(milliseconds: 100));

        var adapter =
            (storeRepo as DBEntityRepository).repositoryAdapter.databaseAdapter;

        // At most `maxConnections` in the pool:
        expect(adapter.poolSize, lessThanOrEqualTo(adapter.maxConnections));

        // At most `maxConnections` alive, all back in the pool (not held).
        // (`DBSQLMemoryAdapter` doesn't count its created contexts: a
        // negative alive count.)
        var alive = adapter.poolAliveElementsSize;
        if (alive >= 0) {
          expect(alive, lessThanOrEqualTo(adapter.maxConnections));
          expect(adapter.poolSize, equals(alive));
        }
      });

      test(
        'A7: parallel inserts with the same unique value',
        () async {
          var userRepo = repo<User>();
          var tag = newTag();
          var email = '$tag@mail.com';

          var results = await Future.wait([
            for (var i = 0; i < 10; ++i)
              now(() => storeUser(newUser(email, 'U$i')))
                  .then<Object?>((id) => id, onError: (Object e) => e),
          ]);

          bool isError(Object? r) => r is Error || r is Exception;
          var stored = results.where((r) => !isError(r)).toList();
          var errors = results.where(isError).length;

          // Exactly one stored:
          expect(stored, hasLength(1), reason: '$results');
          expect(errors, equals(9), reason: '$results');

          var sel = await userRepo.selectByQuery(
            ' email == ? ',
            parameters: [email],
          );
          expect(sel, hasLength(1));
        },
        skip: capabilities.uniqueEnforced
            ? false
            : 'Unique fields not enforced (object storage)',
      );
    });

    group('transactions', () {
      test('B1: commit (reads its own writes)', () async {
        var storeRepo = repo<Store>();
        var tag = newTag();

        var t = Transaction();

        var ids = await t.execute(() async {
          var ids = <Object?>[];
          for (var i = 0; i < 3; ++i) {
            ids.add(await storeRepo.store(newStore('$tag-$i', i)));
          }

          // Its own writes, inside:
          for (var i = 0; i < 3; ++i) {
            expect((await storeRepo.selectByID(ids[i]))!.name, '$tag-$i');
          }

          return ids;
        });

        expect(t.isCommitted, isTrue);
        expect(t.isAborted, isFalse);

        for (var i = 0; i < 3; ++i) {
          expect((await storeRepo.selectByID(ids![i]))!.name, '$tag-$i');
        }
      });

      test('B2: an error in the block: aborted (rolled back)', () async {
        var storeRepo = repo<Store>();
        var tag = newTag();

        var ids = <Object?>[];
        var t = Transaction();

        // `execute`: the error is not rethrown (the result is `null`).
        var result = await t.execute(() async {
          ids.add(await storeRepo.store(newStore('$tag-1', 1)));
          ids.add(await storeRepo.store(newStore('$tag-2', 2)));
          throw StateError('B2 error');
        });

        expect(result, isNull);
        expect(t.isAborted, isTrue);
        expect(t.isCommitted, isFalse);

        // `executeOrError`: the error passed to `onError`.
        var t2 = Transaction();
        Object? error;
        var result2 = await t2.executeOrError<Object?>(
          () async {
            ids.add(await storeRepo.store(newStore('$tag-3', 3)));
            throw StateError('B2 error 2');
          },
          onError: (t, e, s) {
            error = e;
            return 'on-error';
          },
        );
        expect(result2, equals('on-error'));
        expect(error, isA<StateError>());
        expect(t2.isAborted, isTrue);

        expect(ids, hasLength(3));

        if (capabilities.rollback) {
          for (var i = 0; i < 3; ++i) {
            await expectNoStore(ids[i], '$tag-${i + 1}');
          }
        }
      });

      test('B3: an explicit abort: rolled back', () async {
        var storeRepo = repo<Store>();
        var tag = newTag();

        var before = newStore('$tag-before', 1);
        var beforeID = await storeRepo.store(before);

        Object? newID;
        var t = Transaction();

        await t.execute(() async {
          var o = (await storeRepo.selectByID(beforeID))!;
          o.name = '$tag-after';
          await storeRepo.store(o);
          newID = await storeRepo.store(newStore('$tag-new', 2));
          t.abort(reason: 'B3 abort');
        });

        expect(newID, isNotNull);

        expect(t.isAborted, isTrue);
        expect(t.isCommitted, isFalse);
        expect(t.abortError?.reason, equals('B3 abort'));

        if (capabilities.rollback) {
          expect(
            (await storeRepo.selectByID(beforeID))!.name,
            equals('$tag-before'),
          );
          await expectNoStore(newID, '$tag-new');
        }
      });

      test(
        'B4: concurrent transactions: no dirty reads',
        () async {
          var storeRepo = repo<Store>();
          var tag = newTag();

          var written = Completer<Object?>();
          var read = Completer<void>();

          var t1 = Transaction();
          var t2 = Transaction();

          // T1: writes, and waits (not committed) while T2 reads.
          var f1 = t1.execute(() async {
            var id = await storeRepo.store(newStore('$tag-t1', 1));
            written.complete(id);
            await read.future;
            return id;
          });

          var id = await written.future;

          // T2: doesn't see T1's uncommitted write.
          var seen = await t2.execute(() => storeRepo.selectByID(id));
          expect(seen, isNull);

          read.complete();
          expect(await f1, equals(id));
          expect(t1.isCommitted, isTrue);

          // Committed: visible.
          expect((await storeRepo.selectByID(id))!.name, equals('$tag-t1'));
        },
        skip: capabilities.isolation
            ? false
            : 'No isolation between concurrent transactions',
      );

      test('B6: parallel stores inside one transaction', () async {
        var storeRepo = repo<Store>();
        var tag = newTag();

        var t = Transaction();

        var ids = await t.execute(
          () => Future.wait([
            for (var i = 0; i < 5; ++i)
              now(() => storeRepo.store(newStore('$tag-$i', i))),
          ]),
        );

        expect(t.isCommitted, isTrue);
        expect(ids!.toSet(), hasLength(5));

        // In that transaction (not new ones). An insert, or an update with
        // an ID defined by the test:
        expect(t.operations.length, greaterThanOrEqualTo(5));

        for (var i = 0; i < 5; ++i) {
          expect((await storeRepo.selectByID(ids[i]))!.name, '$tag-$i');
        }
      });

      test(
        'B7: a failing operation aborts the whole transaction',
        () async {
          var storeRepo = repo<Store>();
          var userRepo = repo<User>();
          var tag = newTag();

          var email = '$tag@mail.com';
          await storeUser(newUser(email, 'X1'));

          Object? storeID;
          var t = Transaction();

          Object? error;
          await t.executeOrError<Object?>(() async {
            storeID = await storeRepo.store(newStore('$tag-store', 1));
            // A unique conflict:
            await storeUser(newUser(email, 'X2'));
            return null;
          }, onError: (t, e, s) => error = e);

          expect(error, isNotNull);
          expect(t.isAborted, isTrue);
          expect(storeID, isNotNull);
          await expectNoStore(storeID, '$tag-store');

          var sel = await userRepo.selectByQuery(
            ' email == ? ',
            parameters: [email],
          );
          expect(sel, hasLength(1));
        },
        skip: capabilities.uniqueEnforced && capabilities.rollback
            ? false
            : 'Unique fields not enforced (object storage)',
      );

      // The last one: with `DBSQLMemoryAdapter`, an abort can revert the
      // writes of concurrent transactions (see `isolatedRollback`).
      test('B5: parallel transactions, some aborted', () async {
        var storeRepo = repo<Store>();
        var userRepo = repo<User>();
        var tag = newTag();

        var openTransactions0 = Transaction.openInstances
            .where((t) => !t.isFinished)
            .length;

        const n = 20;
        var storeIDs = List<Object?>.filled(n, null);
        var userIDs = List<Object?>.filled(n, null);
        var transactions = List<Transaction?>.filled(n, null);

        // `execute`: an aborted one returns `null` (the error not rethrown).
        var results = await Future.wait([
          for (var i = 0; i < n; ++i)
            now(() {
              var t = transactions[i] = Transaction();
              return t.execute(() async {
                storeIDs[i] = await storeRepo.store(newStore('$tag-$i', i));
                userIDs[i] = await storeUser(
                  newUser('$tag-$i@mail.com', 'B$i'),
                );
                if (i % 3 == 0) throw StateError('B5 abort $i');
                return i;
              });
            }),
        ]);

        // The rollbacks finished:
        await Future.delayed(Duration(milliseconds: 100));

        for (var i = 0; i < n; ++i) {
          var aborted = i % 3 == 0;
          var t = transactions[i]!;

          if (aborted) {
            expect(results[i], isNull);
            expect(t.isAborted, isTrue);
            if (capabilities.rollback) {
              await expectNoStore(storeIDs[i], '$tag-$i');
              await expectNoUser(userIDs[i], '$tag-$i@mail.com');
            }
          } else {
            expect(results[i], equals(i));
            expect(t.isCommitted, isTrue);

            if (capabilities.isolatedRollback) {
              expect(
                (await storeRepo.selectByID(storeIDs[i]))!.name,
                '$tag-$i',
              );

              var u = (await userRepo.selectByID(
                userIDs[i],
                resolutionRules: EntityResolutionRules(allEager: true),
              ))!;
              expect(u.address.state, equals('B$i'));
              expect(u.roles, hasLength(2));
            }
          }
        }

        // No transaction left open:
        var openTransactions = Transaction.openInstances
            .where((t) => !t.isFinished)
            .length;
        expect(openTransactions, lessThanOrEqualTo(openTransactions0));
      });
    });
  });
}

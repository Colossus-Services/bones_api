import 'package:bones_api/bones_api_test.dart';
import 'package:test/test.dart';

/// An entity stored by the failing `COMMIT` tests
/// ([runTransactionCommitErrorTests]).
class CommitTestOwner extends Entity {
  int? id;
  String name;

  CommitTestOwner({this.id, this.name = ''});

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const ['id', 'name'];

  @override
  V? getField<V>(String key) => switch (key) {
    'id' => id as V?,
    'name' => name as V?,
    _ => null,
  };

  @override
  TypeInfo? getFieldType(String key) => switch (key) {
    'id' => TypeInfo.tInt,
    'name' => TypeInfo.tString,
    _ => null,
  };

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
      case 'name':
        name = value as String;
    }
  }

  @override
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class CommitTestProvider extends EntityRepositoryProvider {
  late final DBSQLAdapter adapter;
  late final DBSQLEntityRepository<CommitTestOwner> ownerRepository;

  CommitTestProvider(
    DBSQLAdapter Function(EntityRepositoryProvider provider) createAdapter,
  ) {
    adapter = createAdapter(this);

    ownerRepository = DBSQLEntityRepository<CommitTestOwner>(
      adapter,
      'commit_test_owner',
      GenericEntityHandler<CommitTestOwner>(
        instantiatorDefault: CommitTestOwner.new,
        sampleEntity: CommitTestOwner(),
      ),
    );
  }

  void dispose() {
    adapter.close();
    close();
  }
}

/// The outcome of [f] (its value or error). A hang (the bug fixed in 1.30.1:
/// an asynchronous `COMMIT` failure never reaching the caller of
/// `Transaction.execute`) times out.
Future<({Object? value, Object? error})> commitTestOutcomeOf(
  FutureOr<Object?> Function() f,
) => Future.sync(f)
    .then<({Object? value, Object? error})>(
      (v) => (value: v, error: null),
      onError: (Object e) => (value: null, error: e),
    )
    .timeout(const Duration(seconds: 30));

/// Tests a real (asynchronous) `COMMIT` that fails, with a DB adapter:
/// - [createTablesSQLs]: creates the table `commit_test_owner` (`id`, `name`).
/// - [storeWithFailingCommit]: stores in the transaction (one or more
///   [CommitTestOwner]s, passing it as `transaction`) so that its `COMMIT`
///   fails. Called inside its `execute`, or before it (with the transaction
///   already open: not its 1st operation).
/// - [commitError]: matches the `COMMIT` error.
void runTransactionCommitErrorTests({
  required String dbName,
  required APITestConfigDockerDBSQL testConfig,
  required DBSQLAdapter Function(EntityRepositoryProvider provider, int dbPort)
  createAdapter,
  required List<String> createTablesSQLs,
  required Future<void> Function(Transaction transaction, CommitTestProvider p)
  storeWithFailingCommit,
  required Matcher commitError,
}) {
  group('$dbName: failing COMMIT', () {
    late CommitTestProvider provider;

    setUpAll(() async {
      var started = await testConfig.start();
      expect(started, isTrue, reason: 'Container not started: $testConfig');

      var dbPort = await testConfig.dbPort;

      provider = CommitTestProvider((p) => createAdapter(p, dbPort));
      await provider.ensureInitialized();

      for (var sql in createTablesSQLs) {
        expect(
          await provider.adapter.executeTableSQL(sql),
          isTrue,
          reason: 'SQL: $sql',
        );
      }
    });

    tearDownAll(() async {
      provider.dispose();
      await testConfig.stop();
    });

    Future<void> expectFailedCommit(
      Transaction t,
      ({Object? value, Object? error}) outcome,
    ) async {
      expect(outcome.value, isNull);
      expect(outcome.error, commitError);

      await t.resultFuture.timeout(const Duration(seconds: 30));
      expect(t.isFinished, isTrue);
      expect(t.isCommitting, isFalse);
      expect(t.isCommitted, isFalse);
      expect(t.isAborted, isTrue);
      expect(t.abortError?.error, same(outcome.error));
      expect(Transaction.executingTransaction, isNull);
      expect(t.toString(), contains('abortError: TransactionAbortedError>'));

      // Rolled back:
      expect(await provider.ownerRepository.count(), equals(0));
    }

    Future<void> expectNextTransactionWorks() async {
      var t2 = Transaction();
      var id = await t2.execute(
        () => provider.ownerRepository.store(CommitTestOwner(name: 'ok')),
      );
      expect(id, isNotNull);
      expect(t2.isCommitted, isTrue);

      expect(await provider.ownerRepository.count(), equals(1));
      await provider.ownerRepository.deleteByQuery('id == ?', parameters: [id]);
      expect(await provider.ownerRepository.count(), equals(0));
    }

    test('Transaction.execute', () async {
      var t = Transaction();

      var outcome = await commitTestOutcomeOf(
        () => t.execute(() => storeWithFailingCommit(t, provider)),
      );

      await expectFailedCommit(t, outcome);
      await expectNextTransactionWorks();
    });

    test('Transaction.executeOrError', () async {
      var t = Transaction();
      var onErrorCalls = 0;

      var outcome = await commitTestOutcomeOf(
        () => t.executeOrError<Object?>(
          () => storeWithFailingCommit(t, provider),
          onError: (tr, e, s) {
            ++onErrorCalls;
            return -1;
          },
        ),
      );

      await expectFailedCommit(t, outcome);
      // A commit error is not a block error:
      expect(onErrorCalls, equals(0));
      await expectNextTransactionWorks();
    });

    test('Transaction.executeBlock', () async {
      Transaction? transaction;

      var outcome = await commitTestOutcomeOf(
        () => Transaction.executeBlock<Object?>((t) {
          transaction = t;
          return storeWithFailingCommit(t, provider);
        }),
      );

      await expectFailedCommit(transaction!, outcome);
      await expectNextTransactionWorks();
    });

    // The transaction is opened (by its operations) before `execute`, in the
    // caller's error `Zone`, where the adapter's `COMMIT` (`transactionResult`)
    // fails. Before 1.30.2 the commit, inside the transaction's error `Zone`,
    // never received that error: a hang.
    Future<Transaction> openBeforeExecute() async {
      var t = Transaction();
      // The 1st operation runs without opening the transaction (a single
      // operation): the next ones open it.
      expect(await provider.ownerRepository.count(transaction: t), equals(0));
      await storeWithFailingCommit(t, provider);
      expect(t.isOpen, isTrue);
      expect(Transaction.executingTransaction, isNull);
      return t;
    }

    test('transaction opened before Transaction.execute', () async {
      var t = await openBeforeExecute();

      var outcome = await commitTestOutcomeOf(
        () => t.execute<Object?>(() => 1),
      );

      await expectFailedCommit(t, outcome);
      await expectNextTransactionWorks();
    });

    test('transaction opened before Transaction.executeOrError', () async {
      var t = await openBeforeExecute();
      var onErrorCalls = 0;

      var outcome = await commitTestOutcomeOf(
        () => t.executeOrError<Object?>(
          () => 1,
          onError: (tr, e, s) {
            ++onErrorCalls;
            return -1;
          },
        ),
      );

      await expectFailedCommit(t, outcome);
      expect(onErrorCalls, equals(0));
      await expectNextTransactionWorks();
    });
  });
}

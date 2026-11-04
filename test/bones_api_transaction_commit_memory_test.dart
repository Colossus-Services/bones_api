@TestOn('vm')
@Tags(['entities'])
@Timeout(Duration(minutes: 2))
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_transaction_commit_tests_base.dart';

/// A [DBSQLMemoryAdapter] with a `COMMIT` as the PostgreSQL/MySQL/SQLite
/// adapters: an asynchronous [Transaction.transactionResult], created when the
/// transaction is opened (by its 1st operation) and completed after the
/// [Transaction.transactionFuture]. It fails with [commitError], if set.
class _CommitMemoryAdapter extends DBSQLMemoryAdapter {
  Object? commitError;

  _CommitMemoryAdapter({super.parentRepositoryProvider});

  @override
  DBSQLMemoryAdapterContext openTransaction(Transaction transaction) {
    var conn = super.openTransaction(transaction);

    transaction.transactionResult = transaction.transactionFuture.then((
      r,
    ) async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      if (r is TransactionAbortedError) throw r;
      var error = commitError;
      if (error != null) throw error;
      return r;
    });

    return conn;
  }
}

/// A [DBSQLMemoryAdapter] whose transactions always use a new context: its
/// tables versions (the rollback target) are the current ones, not the ones
/// of a pooled context, taken when it was created.
class _FreshContextMemoryAdapter extends DBSQLMemoryAdapter {
  _FreshContextMemoryAdapter({super.parentRepositoryProvider});

  @override
  DBSQLMemoryAdapterContext catchFromPool({Duration? timeout}) =>
      createConnection();
}

/// Stores 2 [CommitTestOwner]s in [t], outside [Transaction.execute]: the 2nd
/// one opens [t] (the 1st operation of a transaction runs without opening it).
Future<void> _storeOpening(CommitTestProvider provider, Transaction t) async {
  await provider.ownerRepository.store(
    CommitTestOwner(name: 'a'),
    transaction: t,
  );
  await provider.ownerRepository.store(
    CommitTestOwner(name: 'b'),
    transaction: t,
  );
  expect(t.isOpen, isTrue);
  expect(Transaction.executingTransaction, isNull);
}

void main() {
  group('DBSQLMemoryAdapter: transaction opened before execute', () {
    late CommitTestProvider provider;
    late _CommitMemoryAdapter adapter;

    setUp(() async {
      provider = CommitTestProvider(
        (p) => adapter = _CommitMemoryAdapter(parentRepositoryProvider: p),
      );
      await provider.ensureInitialized();
    });

    tearDown(() => provider.dispose());

    Future<void> expectFailedCommit(
      Transaction t,
      ({Object? value, Object? error}) outcome,
    ) async {
      expect(outcome.value, isNull);
      expect(outcome.error, isA<StateError>());
      expect('${outcome.error}', contains('memory COMMIT'));

      await t.resultFuture.timeout(const Duration(seconds: 10));
      expect(t.isFinished, isTrue);
      expect(t.isCommitting, isFalse);
      expect(t.isCommitted, isFalse);
      expect(t.isAborted, isTrue);
      expect(t.abortError?.reason, equals('Commit failed'));
      expect(t.abortError?.error, same(outcome.error));
      expect(Transaction.executingTransaction, isNull);
    }

    Future<void> expectNextTransactionWorks() async {
      adapter.commitError = null;

      var t2 = Transaction();
      var id = await t2.execute(
        () => provider.ownerRepository.store(CommitTestOwner(name: 'ok')),
      );
      expect(id, isNotNull);
      expect(t2.isCommitted, isTrue);
    }

    // Before 1.30.2 the `transactionResult` was created in the caller's error
    // `Zone` (the transaction was opened there, by `store`), and listened to
    // by the commit inside the transaction's error `Zone`: its error never
    // reached `execute` (a hang), and was only reported as uncaught.
    test('Transaction.execute: failing COMMIT', () async {
      var t = Transaction();
      await _storeOpening(provider, t);

      adapter.commitError = StateError('memory COMMIT');

      var outcome = await commitTestOutcomeOf(() => t.execute(() => 1));

      await expectFailedCommit(t, outcome);
      await expectNextTransactionWorks();
    });

    test('Transaction.executeOrError: failing COMMIT', () async {
      var t = Transaction();
      await _storeOpening(provider, t);

      adapter.commitError = StateError('memory COMMIT (onError)');

      var onErrorCalls = 0;
      var outcome = await commitTestOutcomeOf(
        () => t.executeOrError<int>(
          () => 1,
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

    test('Transaction.commit: failing COMMIT', () async {
      var t = Transaction();
      await _storeOpening(provider, t);

      adapter.commitError = StateError('memory COMMIT (commit)');

      // `commit` called directly, from the zone that opened the transaction:
      var outcome = await commitTestOutcomeOf(() => t.commit<Object?>());

      await expectFailedCommit(t, outcome);
      await expectNextTransactionWorks();
    });

    // An aborted transaction: the adapter fails its `transactionResult` (a
    // rollback). Before 1.30.2 that error never reached the abort inside
    // `execute`: a hang, with its `resultFuture` never completed.
    test('Transaction.execute: block error (rollback)', () async {
      var t = Transaction();
      await _storeOpening(provider, t);

      var outcome = await commitTestOutcomeOf(
        () => t.execute<int>(() => throw StateError('memory block')),
      );

      expect(outcome.error, isNull);
      expect(outcome.value, isNull);

      await t.resultFuture.timeout(const Duration(seconds: 10));
      expect(t.isAborted, isTrue);
      expect(t.abortError?.error, isA<StateError>());
      expect(Transaction.executingTransaction, isNull);

      await expectNextTransactionWorks();
    });

    test('Transaction.execute: successful COMMIT', () async {
      var t = Transaction();
      await _storeOpening(provider, t);

      var outcome = await commitTestOutcomeOf(
        () => t.execute<dynamic>(
          () => provider.ownerRepository.store(CommitTestOwner(name: 'c')),
        ),
      );

      expect(outcome.error, isNull);
      expect(outcome.value, isNotNull);
      await t.resultFuture.timeout(const Duration(seconds: 10));
      expect(t.isCommitted, isTrue);
      expect(await provider.ownerRepository.count(), equals(3));
    });
  });

  // `DBSQLMemoryAdapter.resolveTransactionResult`: before 1.30.2 its
  // `is! TransactionAbortedError` check was applied to the `Future` of
  // `super.resolveTransactionResult` (always `true`): the context of an
  // aborted transaction, already cancelled (rolled back and disposed), was
  // also "consolidated" and disposed a 2nd time (miscounting the pool).
  group('DBSQLMemoryAdapter: aborted transaction', () {
    late CommitTestProvider provider;

    setUp(() async {
      provider = CommitTestProvider(
        (p) => _FreshContextMemoryAdapter(parentRepositoryProvider: p),
      );
      await provider.ensureInitialized();
    });

    tearDown(() => provider.dispose());

    test('abort: rolled back', () async {
      // The table exists (a rollback reverts the tables existing when the
      // transaction's connection was created):
      var t0 = Transaction();
      await t0.execute<dynamic>(
        () => provider.ownerRepository.store(CommitTestOwner(name: 'kept')),
      );
      expect(t0.isCommitted, isTrue);
      expect(await provider.ownerRepository.count(), equals(1));

      var adapter = provider.adapter as _FreshContextMemoryAdapter;
      var disposed = adapter.poolDisposedElementsCount;

      var t = Transaction();

      var outcome = await commitTestOutcomeOf(
        () => t.execute(() async {
          await provider.ownerRepository.store(CommitTestOwner(name: 'x'));
          t.abort(reason: 'test abort');
          return 1;
        }),
      );

      expect(outcome.error, isNull);
      await t.resultFuture.timeout(const Duration(seconds: 10));
      expect(t.isAborted, isTrue);

      // Its context disposed once:
      expect(adapter.poolDisposedElementsCount, equals(disposed + 1));

      // Rolled back:
      expect(await provider.ownerRepository.count(), equals(1));

      // The next transaction works (and is kept):
      var t2 = Transaction();
      var id = await t2.execute(
        () => provider.ownerRepository.store(CommitTestOwner(name: 'ok')),
      );
      expect(id, isNotNull);
      expect(await provider.ownerRepository.count(), equals(2));
    });

    test('resolveTransactionResult: aborted', () async {
      var adapter = provider.adapter as _FreshContextMemoryAdapter;

      var t = Transaction();
      await _storeOpening(provider, t);
      var conn = t.context as DBSQLMemoryAdapterContext;

      var abortError = TransactionAbortedError(reason: 'test');
      var disposed = adapter.poolDisposedElementsCount;

      var r = await adapter.resolveTransactionResult(abortError, t, conn);
      expect(r, same(abortError));

      // Cancelled: its context disposed once (not also "consolidated" and
      // disposed again):
      expect(adapter.poolDisposedElementsCount, equals(disposed + 1));

      // Rolled back: only the 1st `store` is kept, the single operation of
      // `t` before it was opened (not part of the memory transaction).
      expect(await provider.ownerRepository.count(), equals(1));
    });

    test('resolveTransactionResult: committed', () async {
      var adapter = provider.adapter as _FreshContextMemoryAdapter;

      var t = Transaction();
      await _storeOpening(provider, t);
      var conn = t.context as DBSQLMemoryAdapterContext;

      var disposed = adapter.poolDisposedElementsCount;

      var r = await adapter.resolveTransactionResult(123, t, conn);
      expect(r, equals(123));

      // Consolidated, its context released into the pool (not disposed):
      expect(adapter.poolDisposedElementsCount, equals(disposed));
      expect(await provider.ownerRepository.count(), equals(2));
    });
  });
}

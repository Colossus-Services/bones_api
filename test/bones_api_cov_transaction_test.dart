@TestOn('vm')
@Timeout(Duration(seconds: 30))
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

class _FilteredError extends Error {}

class _TestDBException implements DBException {
  @override
  final String message;

  @override
  final Object? operation;

  _TestDBException(this.message, [this.operation]);

  @override
  String toString() => '_TestDBException: $message';
}

/// Creates a `select` operation in [transaction].
TransactionOperationSelect _select(
  Transaction transaction, {
  Object executor = 'exec',
  TransactionOperation? parentOperation,
}) => TransactionOperationSelect(
  'repo',
  false,
  executor,
  ConditionANY(),
  transaction: transaction,
  parentOperation: parentOperation,
);

void main() {
  group('TransactionAbortedError', () {
    test('withErrorStackTrace / toString', () {
      var e = TransactionAbortedError(reason: 'r', error: 'err');
      expect(identical(e.withErrorStackTrace(null), e), isTrue);

      var s = StackTrace.current;
      var e2 = e.withErrorStackTrace(s);
      expect(identical(e2, e), isFalse);
      expect(e2.errorStackTrace, same(s));
      expect(e2.reason, equals('r'));
      expect(identical(e2.withErrorStackTrace(s), e2), isTrue);

      expect(
        e.toString(),
        equals('TransactionAbortedError> reason: r ; error: err'),
      );
      expect(
        TransactionAbortedError().toString(),
        equals('TransactionAbortedError> '),
      );
    });
  });

  group('DBException', () {
    test('messageAndOperation', () {
      expect(_TestDBException('m').messageAndOperation, equals('m'));
      expect(_TestDBException('m', 'op').messageAndOperation, equals('m->op'));
    });
  });

  group('TransactionOperationType', () {
    test('name / isRead', () {
      for (var t in TransactionOperationType.values) {
        expect(TransactionOperationTypeExtension(t).name, equals(t.name));
      }

      expect(TransactionOperationType.select.isRead, isTrue);
      expect(TransactionOperationType.count.isRead, isTrue);
      expect(TransactionOperationType.store.isRead, isFalse);
    });
  });

  group('TransactionOperation', () {
    test('toString / toStringSimple', () async {
      var t = Transaction();
      var matcher = ConditionANY();

      var ops = <TransactionOperation>[
        TransactionOperationSelect('r', false, 'e', matcher, transaction: t),
        TransactionOperationCount('r', 'e', matcher: matcher, transaction: t),
        TransactionOperationStore('r', false, 'e', 'ent', transaction: t),
        TransactionOperationUpdate('r', false, 'e', 'ent', transaction: t),
        TransactionOperationStoreRelationship('r', 'e', 'ent', [
          'o1',
        ], transaction: t),
        TransactionOperationConstrainRelationship('r', 'e', 'ent', [
          'o2',
        ], transaction: t),
        TransactionOperationSelectRelationship('r', 'e', 'ent', transaction: t),
        TransactionOperationSelectRelationships('r', 'v', 'e', [
          'ent',
        ], transaction: t),
        TransactionOperationDelete('r', false, 'e', matcher, transaction: t),
      ];

      var types = [
        'select',
        'count',
        'store',
        'update',
        'storeRelationship',
        'constrainRelationship',
        'selectRelationship',
        'selectRelationships',
        'delete',
      ];

      for (var i = 0; i < ops.length; ++i) {
        var op = ops[i];
        op.command = 'CMD$i';

        expect(op.id, equals(i + 1));
        expect(op.transactionId, equals(t.id));
        expect(op.isExecuted, isFalse);
        expect(op.duration, isNull);
        expect(op.durationMsInfo, isEmpty);

        expect(op.toStringSimple(), contains(':${types[i]}@r'));
        expect(op.toString(), contains(':${types[i]}@r'));
        expect(op.toString(), contains('command: CMD$i'));
      }

      expect(ops[2].toString(), contains('entity: ent'));
      expect(ops[4].toString(), contains('other: [o1]'));
      expect(ops[7].toStringSimple(), contains('selectRelationships@r->v'));

      expect(t.isReadOnlyUntil(ops[1]), isTrue);
      expect(t.isReadOnlyUntil(ops[3]), isFalse);

      expect(t.operationsWithEntity<TransactionOperationStore>('ent'), [
        ops[2],
      ]);
      expect(
        t.firstOperationWithEntity<TransactionOperationUpdate>('ent'),
        same(ops[3]),
      );

      expect(t.info, equals('T#${t.id} select@r'));

      for (var op in ops) {
        await op.finish(true);
        expect(op.isExecuted, isTrue);
        expect(op.toStringSimple(), contains('(executed)'));
        expect(op.durationMsInfo, contains('ms'));
      }

      expect(t.isCommitted, isFalse);
      await t.commit();
      expect(t.isCommitted, isTrue);
      expect(t.toString(compact: true), contains('operations: 9'));
    });

    test('sub-transaction (different executor)', () async {
      var t = Transaction();

      var op1 = _select(t, executor: 'exec1');
      var op2 = _select(t, executor: 'exec2');

      // `op2` is in a sub-transaction:
      expect(identical(op2.transaction, t), isFalse);
      expect(op2.transaction.parentTransaction, same(t));

      var subOp = t.operations.whereType<TransactionOperationSubTransaction>();
      expect(subOp, hasLength(1));
      expect(subOp.first.toStringSimple(), contains('subTransaction@repo'));
      expect(subOp.first.toString(), contains('Transaction[#'));

      await op1.finish(1);
      await op2.finish(2);

      expect(await op2.transaction.commit(), equals(2));
      expect(await t.commit(), isNotNull);
      expect(t.isCommitted, isTrue);
    });

    test('isParentOperation', () async {
      var t = Transaction();
      var op1 = _select(t);
      var op2 = _select(t, parentOperation: op1);
      var op3 = _select(t, parentOperation: op2);

      expect(op3.isParentOperation(op1), isTrue);
      expect(op3.isParentOperation(op2), isTrue);
      expect(op1.isParentOperation(op3), isFalse);
      expect(op3.isParentOperation(null), isFalse);

      // Parent operation from another transaction is ignored:
      var t2 = Transaction();
      var opOther = _select(t2, parentOperation: op1);
      expect(opOther.parentOperation, isNull);

      expect(await t.waitOperation(null), isFalse);
      expect(() => t.waitOperation(opOther), throwsA(isA<StateError>()));

      // Waiting a parent operation (loop):
      expect(await t.waitOperation(op1, parentOperation: op3), isFalse);

      // Waits for the operation (finished later):
      var waiting = t.waitOperation(op2, timeout: const Duration(seconds: 5));
      await op1.finish(1);
      await op2.finish(2);
      expect(await waiting, isTrue);
      expect(await t.waitOperation(op2), isTrue);
      expect(await op2.waitFinish(), isTrue);

      // Timeout:
      expect(
        await t.waitOperation(op3, timeout: const Duration(milliseconds: 10)),
        isFalse,
      );
      await op3.finish(3);

      await opOther.finish(0);
    });
  });

  group('Transaction', () {
    test('static', () {
      expect(Transaction.openInstances, isA<List<Transaction>>());

      var t = Transaction.autoCommit();
      expect(t.autoCommit, isTrue);

      var t2 = Transaction.executingOrNew(autoCommit: false);
      expect(t2.autoCommit, isFalse);
      expect(Transaction.executingTransaction, isNull);

      Transaction.registerErrorFilter((e, s) => e is _FilteredError);
      expect(
        Transaction.isFilteredError(_FilteredError(), StackTrace.current),
        isTrue,
      );
      expect(
        Transaction.isFilteredError(StateError('x'), StackTrace.current),
        isFalse,
      );
    });

    test('operations state', () async {
      var t = Transaction();
      expect(t.isEmpty, isTrue);
      expect(t.isNotEmpty, isFalse);
      expect(t.length, equals(0));
      expect(t.info, equals('Transaction#${t.id}'));
      expect(t.canPropagate, isFalse);
      expect(t.executor, isNull);
      expect(t.dispose(), isFalse);

      var op1 = _select(t);
      expect(t.isLastExecutingOperation(op1), isTrue);

      var op2 = _select(t);
      expect(t.isNotEmpty, isTrue);
      expect(t.notExecutedOperationsSize, equals(2));
      expect(t.isLastExecutingOperation(op1), isFalse);
      expect(t.executor, equals('exec'));
      expect(t.mainOperation, same(op1));

      expect(() => t.addOperation(op1), throwsStateError);

      var waitAll = t.waitAllExecuted();
      expect(waitAll, isA<Future>());

      await op1.finish(1);
      expect(t.isLastExecutingOperation(op2), isTrue);

      expect(() => t.finishOperation(op1, 1), throwsA(isA<StateError>()));

      await op2.finish(2);
      expect(await waitAll, isTrue);
      expect(t.waitAllExecuted(), isTrue);
      expect(t.isLastExecutingOperation(op2), isTrue);

      var tOther = Transaction();
      var opOther = _select(tOther);
      expect(() => t.isLastExecutingOperation(opOther), throwsStateError);
      await opOther.finish(0);

      var result = await t.commit();
      expect(result, equals(2));
      expect(t.result, equals(2));
      expect(t.isCommitted, isTrue);
      expect(t.isFinished, isTrue);
      expect(t.duration, isNotNull);
      expect(t.endTime, isNotNull);
      expect(t.initTime, isNotNull);

      // Commit again:
      expect(await t.commit(), equals(2));

      expect(() => _select(t), throwsStateError);
      expect(() => t.finishOperation(op2, 1), throwsStateError);

      expect(t.abort(), isNull);

      expect(t.toString(), contains('committed: true'));
      expect(t.toString(), contains('result: 2'));

      expect(t.dispose(), isTrue);
      expect(t.operations, isEmpty);
      expect(t.executedOperations, isEmpty);
    });

    test('commit with transactionResult', () async {
      var t = Transaction();
      var op = _select(t);
      await op.finish('res');

      t.transactionResult = 'tr';
      expect(await t.commit(), equals('res'));

      var t2 = Transaction();
      var op2 = _select(t2);
      await op2.finish('res2');
      t2.transactionResult = Future.value('tr2');
      expect(await t2.commit(), equals('tr2'));
    });

    test('long transaction', () async {
      var t = Transaction();
      var ops = List.generate(17, (_) => _select(t));
      for (var op in ops) {
        await op.finish(1);
      }
      expect(await t.commit(), equals(1));
    });

    test('commit is committing', () async {
      var t = Transaction();
      var op1 = _select(t);
      var commit = t.commit();
      expect(t.isCommitting, isTrue);
      expect(() => _select(t), throwsStateError);
      expect(t.toString(), contains('committing...'));
      await op1.finish(1);
      expect(await commit, equals(1));
    });

    test('open', () async {
      var t = Transaction();
      expect(t.isOpen, isFalse);
      expect(t.isOpening, isFalse);

      var onOpen = t.onOpen(() => 'opened');

      var closed = false;
      var completer = Completer<Object>();
      var openRet = t.open(() => completer.future, () {
        closed = true;
      });

      expect(t.isOpening, isTrue);
      expect(() => t.open(() => 'ctx', null), throwsStateError);

      completer.complete('ctx');
      expect(await openRet, equals('ctx'));
      expect(t.isOpen, isTrue);
      expect(t.context, equals('ctx'));
      expect(await onOpen, equals('opened'));
      expect(t.onOpen(() => 'again'), equals('again'));

      expect(() => t.open(() => 'ctx', null), throwsStateError);

      var op = _select(t);
      await op.finish(1);
      await t.commit();
      expect(closed, isTrue);

      var t2 = Transaction();
      var op2 = _select(t2);
      await t2.open(() => 'ctx2', () async {
        closed = false;
      });
      await op2.finish(2);
      expect(await t2.commit(), equals(2));
      expect(closed, isFalse);
    });

    test('open error', () async {
      var t = Transaction();
      // The error is logged, and `null` returned:
      expect(await t.open(() => throw StateError('open'), null), isNull);
      expect(t.isOpen, isFalse);
    });

    test('abort', () async {
      var t = Transaction();
      var op1 = _select(t);
      var op2 = _select(t);
      await op1.finish('r1');

      var abortError = t.abort(reason: 'test', error: StateError('x'));
      expect(abortError, isA<TransactionAbortedError>());
      expect(t.isAborted, isTrue);
      expect(t.abortError, same(abortError));
      expect(op2.isExecuted, isTrue);

      // Abort again: same error.
      expect(t.abort(reason: 'other'), same(abortError));

      expect(() => _select(t), throwsStateError);

      expect(await t.commit(), isNull);
      expect(await t.commit(), isNull);
      expect(t.toString(), contains('abortError'));

      var t2 = Transaction();
      _select(t2);
      var abortError2 = TransactionAbortedError(reason: 'r2');
      var ret = t2.abort(error: abortError2) as TransactionAbortedError;
      expect(ret.reason, equals('r2'));
      expect(ret.errorStackTrace, isNotNull);

      var t3 = Transaction();
      _select(t3);
      var ret3 = t3.abort(error: 'just a string') as TransactionAbortedError;
      expect(ret3.error, equals('just a string'));
      t3.transactionResult = 'tr';
      expect(await t3.commit(), isNull);

      var t4 = Transaction();
      _select(t4);
      t4.abort();
      t4.transactionResult = Future.value('tr');
      expect(await t4.commit(), isNull);
    });

    test('execute', () async {
      var t = Transaction();
      var r = await t.execute(() {
        expect(t.isExecuting, isTrue);
        expect(Transaction.executingTransaction, same(t));
        expect(() => Transaction().execute(() => 1), throwsStateError);
        var op = _select(t);
        return op.finish(10);
      });
      expect(r, equals(10));
      expect(() => t.execute(() => 1), throwsStateError);

      var t2 = Transaction();
      var r2 = await t2.executeOrError<int>(
        () => throw StateError('fail'),
        onError: (tr, e, s) {
          expect(tr, same(t2));
          return -1;
        },
      );
      expect(r2, equals(-1));
      expect(t2.error, isA<StateError>());

      var t3 = Transaction();
      var r3 = await t3.executeOrError<int>(() => 3, onError: (tr, e, s) => -1);
      expect(r3, equals(3));
    });

    test('executeBlock', () async {
      var r = await Transaction.executeBlock((t) {
        var op = _select(t);
        return op.finish('block');
      });
      expect(r, equals('block'));

      var t = Transaction();
      var op = _select(t);
      var r2 = await Transaction.executeBlock((tr) {
        expect(tr, same(t));
        return 'given';
      }, transaction: t);
      expect(r2, equals('given'));
      await op.finish(0);
    });

    test('addExecution / errors', () async {
      var t = Transaction();
      await t.open(() => 'ctx', null);

      var op = _select(t);

      var r1 = await t.addExecution<String, String>((c) => '$c:1');
      expect(r1, equals('ctx:1'));

      var r2 = await t.addExecution<String, String>((c) async => '$c:2');
      expect(r2, equals('ctx:2'));

      Object? resolvedPrevious;
      await expectLater(
        Future.sync(
          () => t.addExecution<String, String>(
            (c) => throw StateError('exec error'),
            operation: 'op1',
            debugInfo: () => 'debug',
            errorResolver: (e, s, op, prev) {
              resolvedPrevious = prev;
              return _TestDBException('resolved', op);
            },
          ),
        ),
        throwsA(isA<_TestDBException>()),
      );
      expect(resolvedPrevious, isNull);
      expect(t.error, isA<_TestDBException>());
      expect(t.isAborted, isTrue);

      // A 2nd error is an "extra" error, also rethrown (not returned as the
      // operation's result):
      await expectLater(
        Future.sync(
          () => t.notifyExecutionError<String>(
            StateError('extra'),
            StackTrace.current,
          ),
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'extra')),
      );
      expect(t.extraErrors, hasLength(1));
      expect(t.error, isA<_TestDBException>());

      var s = t.toString();
      expect(s, contains('error: resolved->'));
      expect(s, contains('extraErrors'));

      // The abort marked the pending operation as executed:
      expect(op.isExecuted, isTrue);
      expect(await t.commit(), isNull);

      expect(() => t.addExecution<String, String>((c) => c), throwsStateError);
    });

    test('async execution error', () async {
      var t = Transaction();
      await t.open(() => 'ctx', null);
      var op = _select(t);

      await expectLater(
        Future.sync(
          () => t.addExecution<String, String>(
            (c) async => throw StateError('async exec error'),
          ),
        ),
        throwsStateError,
      );

      expect(t.isAborted, isTrue);
      expect(op.isExecuted, isTrue);
      expect(await t.commit(), isNull);
    });

    test('cache with parent transaction', () async {
      var parent = Transaction();
      var op1 = _select(parent, executor: 'e1');
      var op2 = _select(parent, executor: 'e2');

      var sub = op2.transaction;
      expect(sub.parentTransaction, same(parent));

      var e1 = _Ent(1);
      var e2 = _Ent(2);
      sub.cacheEntity(e1, (o) => o.id);
      sub.cacheEntities([e2], (o) => o.id);

      expect(parent.getCachedEntityByID(1, type: _Ent), same(e1));
      expect(parent.getCachedEntityByID(2, type: _Ent), same(e2));
      expect(await sub.getEntityByID<_Ent>(1, type: _Ent), same(e1));

      await op1.finish(1);
      await op2.finish(2);
      await sub.commit();
    });
  });

  group('TransactionEntityProvider', () {
    test('getEntityByID', () async {
      var t = Transaction();
      var e = _Ent(1);
      t.cacheEntity(e, (o) => o.id);

      var provider = TransactionEntityProvider(
        t,
        EntityRepositoryProvider.globalProvider,
        const EntityResolutionRules(allowEntityFetch: true),
      );

      expect(
        provider.getContextEntityResolutionRules()?.allowEntityFetch,
        isTrue,
      );

      expect(await provider.getEntityByID<_Ent>(1, type: _Ent), same(e));
      expect(await provider.getEntityByID<_Ent>(2, type: _Ent), isNull);
      expect(
        await provider.getEntityByID<_Ent>(2, type: _Ent, sync: true),
        isNull,
      );
      expect(await provider.getEntityByID<int>(2, type: int), isNull);

      var provider2 = TransactionEntityProvider(
        t,
        EntityRepositoryProvider.globalProvider,
        const EntityResolutionRules(allowEntityFetch: false),
      );
      expect(await provider2.getEntityByID<_Ent>(2, type: _Ent), isNull);
    });
  });
}

class _Ent {
  final int id;

  _Ent(this.id);
}

import 'dart:async';

import 'package:async_extension/async_extension.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';

class SQLEntityRepository<O> extends EntityRepository<O>
    with EntityFieldAccessor<O> {
  final SQLRepositoryAdapter<O> sqlRepositoryAdapter;

  SQLEntityRepository(
      SQLAdapter adapter, String name, EntityHandler<O> entityHandler,
      {SQLRepositoryAdapter<O>? repositoryAdapter, Type? type})
      : sqlRepositoryAdapter =
            repositoryAdapter ?? adapter.getRepositoryAdapter<O>(name)!,
        super(adapter, name, entityHandler, type: type);

  @override
  void initialize() {
    sqlRepositoryAdapter.ensureInitialized();
  }

  String get dialect => sqlRepositoryAdapter.dialect;

  @override
  Map<String, dynamic> information() =>
      {'queryType': 'SQL', 'dialect': dialect};

  @override
  FutureOr<dynamic> ensureStored(o, {Transaction? transaction}) {
    checkNotClosed();

    var id = getID(o, entityHandler: entityHandler);

    if (id == null) {
      transaction ??= Transaction.executingOrNew();
      return store(o, transaction: transaction);
    } else {
      return ensureReferencesStored(o, transaction: transaction)
          .resolveWithValue(id);
    }
  }

  @override
  FutureOr<bool> ensureReferencesStored(o, {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.executingOrNew();

    var fieldsNames = entityHandler.fieldsNames(o);

    var futures = fieldsNames
        .map((fieldName) {
          var value = entityHandler.getField(o, fieldName);
          if (value == null) return null;

          if (!EntityHandler.isValidType(value.runtimeType)) {
            return null;
          }

          var repository = provider.getEntityRepository(obj: value);
          if (repository == null) return null;

          return repository.ensureStored(value, transaction: transaction);
        })
        .whereNotNull()
        .toList(growable: false);

    return futures.resolveAllWithValue(true);
  }

  @override
  FutureOr<int> length({Transaction? transaction}) =>
      count(transaction: transaction);

  @override
  FutureOr<int> count(
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      TransactionOperation? op}) {
    checkNotClosed();

    var externalTransaction = transaction != null;
    transaction ??= Transaction.executingOrNew();
    var transactionRoot = transaction.isEmpty && !transaction.isExecuting;

    var op = TransactionOperationCount();
    transaction.addOperation(op);

    var retSql = sqlRepositoryAdapter.generateCountSQL(transaction,
        matcher: matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    return retSql.resolveMapped((sql) {
      var retCount = sqlRepositoryAdapter.countSQL(transaction!, op, sql);
      return retCount.resolveMapped((count) {
        return transaction!
            .finishOperation(op, count, transactionRoot, externalTransaction);
      });
    });
  }

  @override
  FutureOr<Iterable<O>> select(EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      int? limit}) {
    checkNotClosed();

    var externalTransaction = transaction != null;
    transaction ??= Transaction.executingOrNew();
    var transactionRoot = transaction.isEmpty && !transaction.isExecuting;

    var op = TransactionOperationSelect(matcher);
    transaction.addOperation(op);

    var retSql = sqlRepositoryAdapter.generateSelectSQL(transaction, matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        limit: limit);

    return retSql.resolveMapped((sql) {
      var selRet = sqlRepositoryAdapter.selectSQL(transaction!, op, sql);

      return selRet.resolveMapped((sel) {
        var entities = sel.map((e) => entityHandler.createFromMap(e)).toList();
        return entities.resolveAllJoined((l) {
          return transaction!
              .finishOperation(op, l, transactionRoot, externalTransaction);
        });
      });
    });
  }

  @override
  FutureOr<dynamic> store(O o, {Transaction? transaction}) {
    checkNotClosed();

    var externalTransaction = transaction != null;
    transaction ??= Transaction.executingOrNew();
    var transactionRoot = transaction.isEmpty && !transaction.isExecuting;

    var op = TransactionOperationStore(o);
    transaction.addOperation(op);

    return ensureReferencesStored(o, transaction: transaction).resolveWith(() {
      var fields = entityHandler.getFields(o);
      var retSql =
          sqlRepositoryAdapter.generateInsertSQL(transaction!, o, fields);

      return retSql.resolveMapped((sql) {
        var retId =
            sqlRepositoryAdapter.insertSQL(transaction!, op, sql, fields);

        return retId.resolveMapped((id) {
          entityHandler.setID(o, id);
          return transaction!
              .finishOperation(op, id, transactionRoot, externalTransaction);
        });
      });
    });
  }

  @override
  Iterable<dynamic> storeAll(Iterable<O> os, {Transaction? transaction}) {
    checkNotClosed();

    transaction ??= Transaction.executingOrNew();
    return os.map((o) => store(o, transaction: transaction)).toList();
  }

  @override
  FutureOr<Iterable<O>> delete(EntityMatcher<O> matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction}) {
    checkNotClosed();

    var externalTransaction = transaction != null;
    transaction ??= Transaction.executingOrNew();
    var transactionRoot = transaction.isEmpty && !transaction.isExecuting;

    var op = TransactionOperationDelete(matcher);
    transaction.addOperation(op);

    var retSql = sqlRepositoryAdapter.generateDeleteSQL(transaction, matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    return retSql.resolveMapped((sql) {
      var selRet = sqlRepositoryAdapter.deleteSQL(transaction!, op, sql);

      return selRet.resolveMapped((sel) {
        var entities = sel.map((e) => entityHandler.createFromMap(e)).toList();
        return entities.resolveAllJoined((l) {
          return transaction!
              .finishOperation(op, l, transactionRoot, externalTransaction);
        });
      });
    });
  }
}

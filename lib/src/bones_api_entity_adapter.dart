import 'dart:async';
import 'dart:convert';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_condition_sql.dart';
import 'bones_api_entity.dart';
import 'bones_api_mixin.dart';

final _log = logging.Logger('SQLRepositoryAdapter');

typedef PasswordProvider = FutureOr<String> Function(String user);

/// An encoded SQL representation.
/// This is used by a [SQLAdapter] to execute queries.
class SQL {
  final Condition? condition;
  final String? entityName;

  final String sql;

  final Map<String, dynamic> parameters;

  final String? idFieldName;

  SQL(this.sql, this.parameters,
      {this.condition, this.entityName, this.idFieldName});

  @override
  String toString() {
    var s =
        'SQL<< $sql >>( ${json.encode(parameters, toEncodable: _toEncodable)} )';
    if (condition != null) {
      s += ' ; Condition<< $condition >>';
    }
    if (entityName != null) {
      s += ' ; entityName: $entityName';
    }
    return s;
  }

  Object? _toEncodable(dynamic o) {
    try {
      return o.toJson();
    } catch (e) {
      return '$o';
    }
  }
}

/// Base class for SQL adapters.
abstract class SQLAdapter<C> extends SchemeProvider
    with Initializable, Pool<C>, Closable
    implements EntityRepositoryProvider {
  /// The minimum number of connections in the pool of this adapter.
  final int minConnections;

  /// The maximum number of connections in the pool of this adapter.
  final int maxConnections;

  /// The SQL dialect of this adapter.
  final String dialect;

  final EntityRepositoryProvider? parentRepositoryProvider;

  late final ConditionSQLEncoder _conditionSQLGenerator;

  SQLAdapter(this.minConnections, this.maxConnections, this.dialect,
      {this.parentRepositoryProvider}) {
    _conditionSQLGenerator = ConditionSQLEncoder(this);
    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  @override
  void initialize();

  FutureOr<SQL> generateCountSQL(Transaction transaction, String table,
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    if (matcher == null) {
      var sqlQuery = 'SELECT count(*) as "count" FROM "$table" ';
      return SQL(sqlQuery, {});
    } else {
      return _generateSQLFrom(transaction, table, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          sqlBuilder: (String from, EncodingContext context) {
        var tableAlias = context.resolveEntityAlias(table);
        return 'SELECT count("$tableAlias".*) as "count" $from';
      });
    }
  }

  FutureOr<SQL> generateSelectSQL(
      Transaction transaction, String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit}) {
    return _generateSQLFrom(transaction, table, matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        sqlBuilder: (String from, EncodingContext context) {
      var tableAlias = context.resolveEntityAlias(table);
      var limitStr = limit != null && limit > 0 ? ' LIMIT $limit' : '';
      var sql = 'SELECT "$tableAlias".* $from$limitStr';
      return sql;
    });
  }

  FutureOr<SQL> generateDeleteSQL(
      Transaction transaction, String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    return _generateSQLFrom(transaction, table, matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        sqlBuilder: (String from, EncodingContext context) {
      var tableAlias = context.resolveEntityAlias(table);

      var sql = StringBuffer();
      sql.write('DELETE ');

      if (sqlAcceptsInsertOutput) {
        sql.write(' OUTPUT DELETED.* ');
      }

      sql.write(from);

      if (sqlAcceptsInsertReturning) {
        sql.write(' RETURNING "$tableAlias".*');
      }

      return sql.toString();
    });
  }

  FutureOr<SQL> _generateSQLFrom(
      Transaction transaction, String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      required String Function(String from, EncodingContext context)
          sqlBuilder}) {
    if (matcher is Condition) {
      var retEncodedSQL = _conditionSQLGenerator.encode(matcher, table,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

      return retEncodedSQL.resolveMapped((encodedSQL) {
        var conditionSQL = encodedSQL.outputString;

        var tableAlias =
            _conditionSQLGenerator.resolveEntityAlias(encodedSQL, table);

        if (encodedSQL.fieldsReferencedTables.isEmpty) {
          String from;
          if (conditionSQL.isNotEmpty) {
            from = 'FROM "$table" as "$tableAlias" WHERE $conditionSQL';
          } else {
            from = 'FROM $table as "$tableAlias"';
          }

          var sqlQuery = sqlBuilder(from, encodedSQL);

          return SQL(sqlQuery, encodedSQL.parametersPlaceholders,
              condition: matcher, entityName: encodedSQL.entityName);
        } else {
          var referencedTablesFields = encodedSQL.referencedTablesFields;

          var innerJoin = StringBuffer();

          for (var e in referencedTablesFields.entries) {
            var refTable = e.key;

            var refTableAlias = encodedSQL.resolveEntityAlias(refTable);

            innerJoin.write('INNER JOIN "$refTable" as "$refTableAlias" ON ');

            for (var fieldRef in e.value) {
              var sourceTableAlias = _conditionSQLGenerator.resolveEntityAlias(
                  encodedSQL, fieldRef.sourceTable);
              var targetTableAlias = _conditionSQLGenerator.resolveEntityAlias(
                  encodedSQL, fieldRef.targetTable);

              innerJoin.write('"');
              innerJoin.write(sourceTableAlias);
              innerJoin.write('"');
              innerJoin.write('.');
              innerJoin.write('"');
              innerJoin.write(fieldRef.sourceField);
              innerJoin.write('"');

              innerJoin.write(' = ');

              innerJoin.write('"');
              innerJoin.write(targetTableAlias);
              innerJoin.write('"');
              innerJoin.write('.');
              innerJoin.write('"');
              innerJoin.write(fieldRef.targetField);
              innerJoin.write('"');
            }
          }

          var from =
              'FROM "$table" as "$tableAlias" $innerJoin WHERE $conditionSQL';
          var sqlQuery = sqlBuilder(from, encodedSQL);

          return SQL(sqlQuery, encodedSQL.parametersPlaceholders,
              condition: matcher, entityName: encodedSQL.entityName);
        }
      });
    } else {
      throw StateError('$matcher');
    }
  }

  /// If `true` indicates that this adapter SQL uses the `OUTPUT` syntax for inserts.
  bool get sqlAcceptsInsertOutput;

  /// If `true` indicates that this adapter SQL uses the `RETURNING` syntax for inserts.
  bool get sqlAcceptsInsertReturning;

  FutureOr<SQL> generateInsertSQL(
      Transaction transaction, String table, Map<String, Object?> fields) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        throw StateError("Can't find TableScheme for table: $table");
      }

      var context = EncodingContext(table,
          namedParameters: fields, transaction: transaction);

      var fieldsValues = tableScheme.getFieldsValues(fields);

      var fieldsNotNull = fieldsValues.entries
          .map((e) => e.value != null ? e.key : null)
          .whereNotNull()
          .toList(growable: false);

      var fieldsValuesInSQL = <String, Object?>{};

      return fieldsNotNull
          .map((f) => fieldValueToSQL(
              context, tableScheme, f, fieldsValues[f]!, fieldsValuesInSQL))
          .toList(growable: false)
          .resolveAll()
          .resolveMapped((values) {
        var idFieldName = tableScheme.idFieldName;

        var sql = StringBuffer();

        sql.write('INSERT INTO "');
        sql.write(table);
        sql.write('" ("');
        sql.write(fieldsNotNull.join('","'));
        sql.write('")');

        if (sqlAcceptsInsertOutput) {
          sql.write(' OUTPUT INSERTED.');
          sql.write(idFieldName);
        }

        sql.write(' VALUES (');
        sql.write(values.join(' , '));
        sql.write(')');

        if (sqlAcceptsInsertReturning) {
          sql.write(' RETURNING "$table"."$idFieldName"');
        }

        return SQL(sql.toString(), fieldsValuesInSQL,
            entityName: table, idFieldName: idFieldName);
      });
    });
  }

  FutureOr<String> fieldValueToSQL(
      EncodingContext context,
      TableScheme tableScheme,
      String fieldName,
      Object value,
      Map<String, Object?> fieldsValues) {
    var fieldRef = tableScheme.fieldsReferencedTables[fieldName];

    if (fieldRef == null) {
      fieldsValues.putIfAbsent(fieldName, () => value);
      var valueSQL = _conditionSQLGenerator.parameterPlaceholder(fieldName);
      return valueSQL;
    } else {
      var refEntity = value;
      var refEntityRepository = getEntityRepository(obj: refEntity);

      if (refEntityRepository != null) {
        var refId = refEntityRepository.entityHandler
            .getField(value, fieldRef.targetField);

        if (refId != null) {
          fieldsValues.putIfAbsent(fieldName, () => refId);
          var valueSQL = _conditionSQLGenerator.parameterPlaceholder(fieldName);
          return valueSQL;
        } else {
          var retRefId = refEntityRepository.store(refEntity,
              transaction: context.transaction);
          return retRefId.resolveMapped((refId) {
            fieldsValues.putIfAbsent(fieldName, () => refId);
            var valueSQL =
                _conditionSQLGenerator.parameterPlaceholder(fieldName);
            return valueSQL;
          });
        }
      } else {
        if (value is Entity) {
          var refId = value.getID();

          fieldsValues.putIfAbsent(fieldName, () => refId);
          var valueSQL = _conditionSQLGenerator.parameterPlaceholder(fieldName);
          return valueSQL;
        } else {
          var reflection =
              ReflectionFactory().getRegisterClassReflection(value.runtimeType);
          if (reflection != null) {
            var fieldId = tableScheme.idFieldName ?? 'id';

            var refId = reflection.getField(fieldId, value);

            fieldsValues.putIfAbsent(fieldName, () => refId);
            var valueSQL =
                _conditionSQLGenerator.parameterPlaceholder(fieldName);
            return valueSQL;
          }
        }

        return 'null';
      }
    }
  }

  FutureOr<int> countSQL(
      Transaction transaction, TransactionOperation op, String table, SQL sql) {
    return executeTransaction(transaction, op, (connection) {
      _log.log(logging.Level.INFO, 'countSQL> $sql');
      return doCountSQL(table, sql, connection);
    });
  }

  FutureOr<int> doCountSQL(
    String table,
    SQL sql,
    C connection,
  );

  FutureOr<dynamic> insertSQL(Transaction transaction, TransactionOperation op,
      String table, SQL sql, Map<String, Object?> fields,
      {T Function<T>(dynamic o)? mapper}) {
    return executeTransaction(transaction, op, (connection) {
      _log.log(logging.Level.INFO, 'insertSQL> $sql');
      var retInsert = doInsertSQL(transaction, table, sql, connection);

      if (mapper != null) {
        return retInsert.resolveMapped((e) => mapper(e));
      } else {
        return retInsert;
      }
    });
  }

  FutureOr<R> executeTransaction<R>(Transaction transaction,
          TransactionOperation op, FutureOr<R> Function(C connection) f) =>
      executeWithPool(f);

  FutureOr<dynamic> doInsertSQL(
      Transaction transaction, String table, SQL sql, C connection);

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(
      Transaction transaction, TransactionOperation op, String table, SQL sql,
      {Map<String, dynamic> Function(Map<String, dynamic> r)? mapper}) {
    return executeTransaction(transaction, op, (connection) {
      _log.log(logging.Level.INFO, 'selectSQL> $sql');

      var retSel = doSelectSQL(table, sql, connection);

      if (mapper != null) {
        return retSel.resolveMapped((e) => e.map(mapper));
      } else {
        return retSel;
      }
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
    String table,
    SQL sql,
    C connection,
  );

  FutureOr<Iterable<Map<String, dynamic>>> deleteSQL(
      Transaction transaction, TransactionOperation op, String table, SQL sql,
      {Map<String, dynamic> Function(Map<String, dynamic> r)? mapper}) {
    return executeTransaction(transaction, op, (connection) {
      _log.log(logging.Level.INFO, 'deleteSQL> $sql');

      var retSel = doDeleteSQL(table, sql, connection);

      if (mapper != null) {
        return retSel.resolveMapped((e) => e.map(mapper));
      } else {
        return retSel;
      }
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
    String table,
    SQL sql,
    C connection,
  );

  /// Returns the URL of the [connection].
  String getConnectionURL(C connection);

  /// Creates a connection [C] for this adapte
  FutureOr<C> createConnection();

  /// Returns `true` if [connection] is valid for usage.
  FutureOr<bool> isConnectionValid(C connection);

  FutureOr<bool> closeConnection(C connection);

  /// Checks the connections of the pool. Defaults: calls [removeInvalidElementsFromPool].
  FutureOr<bool> checkConnections() => removeInvalidElementsFromPool();

  /// Defaults: calls [isConnectionValid].
  @override
  FutureOr<bool> isPoolElementValid(C o) => isConnectionValid(o);

  /// Checks the pool connections and limits.
  @override
  FutureOr<bool> checkPool() =>
      checkPoolSize(minConnections, maxConnections, 30000);

  @override
  int get poolSizeDesiredLimit => maxConnections;

  /// Defaults: calls [createConnection].
  @override
  FutureOr<C?> createPoolElement() {
    super.createPoolElement();

    if (poolSize < maxConnections) {
      return createConnection();
    } else {
      return null;
    }
  }

  /// Defaults: calls [closeConnection].
  @override
  FutureOr<bool> closePoolElement(C o) {
    super.closePoolElement(o);
    return closeConnection(o);
  }

  final Map<String, SQLRepositoryAdapter> _repositoriesAdapters =
      <String, SQLRepositoryAdapter>{};

  SQLRepositoryAdapter<O>? getRepositoryAdapter<O>(String name,
      {String? tableName, Type? type}) {
    if (isClosed) {
      return null;
    }

    return _repositoriesAdapters.putIfAbsent(
        name,
        () => SQLRepositoryAdapter<O>(this, name,
            tableName: tableName, type: type)) as SQLRepositoryAdapter<O>;
  }

  final Map<Type, EntityRepository> _entityRepositories =
      <Type, EntityRepository>{};

  @override
  void registerEntityRepository<O>(EntityRepository<O> entityRepository) {
    checkNotClosed();

    _entityRepositories[entityRepository.type] = entityRepository;
  }

  @override
  List<EntityRepository> get registeredEntityRepositories =>
      _entityRepositories.values.toList();

  bool _callingGetEntityRepository = false;

  @override
  EntityRepository<O>? getEntityRepository<O>(
      {O? obj, Type? type, String? name}) {
    if (isClosed) return null;

    if (_callingGetEntityRepository) return null;
    _callingGetEntityRepository = true;

    try {
      return _getEntityRepositoryImpl<O>(obj: obj, type: type, name: name) ??
          EntityRepositoryProvider.globalProvider
              .getEntityRepository<O>(obj: obj, type: type, name: name);
    } finally {
      _callingGetEntityRepository = false;
    }
  }

  EntityRepository<O>? _getEntityRepositoryImpl<O>(
      {O? obj, Type? type, String? name}) {
    if (!isClosed) {
      var entityRepository = _entityRepositories[O];
      if (entityRepository != null && entityRepository.isClosed) {
        entityRepository = null;
      }

      if (entityRepository != null) {
        return entityRepository as EntityRepository<O>;
      } else if (obj != null) {
        entityRepository = _entityRepositories[obj.runtimeType];
        if (entityRepository != null && entityRepository.isClosed) {
          entityRepository = null;
        }
      }

      if (entityRepository != null) {
        return entityRepository as EntityRepository<O>;
      } else if (type != null) {
        entityRepository = _entityRepositories[type];
        if (entityRepository != null && entityRepository.isClosed) {
          entityRepository = null;
        }
      }

      if (entityRepository != null) {
        return entityRepository as EntityRepository<O>;
      } else if (name != null) {
        entityRepository =
            _entityRepositories.values.where((e) => e.name == name).firstOrNull;
        if (entityRepository != null && entityRepository.isClosed) {
          entityRepository = null;
        }

        if (entityRepository != null) {
          return entityRepository as EntityRepository<O>;
        }
      }
    }

    var entityRepository =
        parentRepositoryProvider?.getEntityRepository<O>(obj: obj, type: type);

    if (entityRepository != null) {
      return entityRepository;
    }

    for (var p in _knownEntityRepositoryProviders) {
      entityRepository = p.getEntityRepository<O>(obj: obj, type: type);
      if (entityRepository != null) {
        return entityRepository;
      }
    }

    return null;
  }

  final Set<EntityRepositoryProvider> _knownEntityRepositoryProviders =
      <EntityRepositoryProvider>{};

  @override
  void notifyKnownEntityRepositoryProvider(EntityRepositoryProvider provider) {
    _knownEntityRepositoryProviders.add(provider);
  }
}

class SQLRepositoryAdapter<O> with Initializable {
  final SQLAdapter databaseAdapter;

  final String name;

  final String tableName;

  final Type type;

  SQLRepositoryAdapter(this.databaseAdapter, this.name,
      {String? tableName, Type? type})
      : tableName = tableName ?? name,
        type = type ?? O;

  @override
  void initialize() {
    databaseAdapter.ensureInitialized();
  }

  String get dialect => databaseAdapter.dialect;

  FutureOr<SQL> generateCountSQL(Transaction transaction,
          {EntityMatcher? matcher,
          Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      databaseAdapter.generateCountSQL(transaction, tableName,
          matcher: matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  FutureOr<int> countSQL(
      Transaction transaction, TransactionOperation op, SQL sql) {
    return databaseAdapter.countSQL(transaction, op, tableName, sql);
  }

  FutureOr<SQL> generateSelectSQL(
          Transaction transaction, EntityMatcher matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters,
          int? limit}) =>
      databaseAdapter.generateSelectSQL(transaction, tableName, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit);

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(
      Transaction transaction, TransactionOperation op, SQL sql) {
    return databaseAdapter.selectSQL(transaction, op, tableName, sql);
  }

  FutureOr<SQL> generateInsertSQL(
      Transaction transaction, O o, Map<String, dynamic> fields) {
    return databaseAdapter.generateInsertSQL(transaction, tableName, fields);
  }

  FutureOr<dynamic> insertSQL(Transaction transaction, TransactionOperation op,
      SQL sql, Map<String, dynamic> fields,
      {String? idFieldName}) {
    return databaseAdapter
        .insertSQL(transaction, op, tableName, sql, fields)
        .resolveMapped((ret) => ret ?? {});
  }

  FutureOr<SQL> generateDeleteSQL(
          Transaction transaction, EntityMatcher matcher,
          {Object? parameters,
          List? positionalParameters,
          Map<String, Object?>? namedParameters}) =>
      databaseAdapter.generateDeleteSQL(transaction, tableName, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  FutureOr<Iterable<Map<String, dynamic>>> deleteSQL(
      Transaction transaction, TransactionOperation op, SQL sql) {
    return databaseAdapter.deleteSQL(transaction, op, tableName, sql);
  }
}
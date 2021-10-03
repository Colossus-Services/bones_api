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

  final Set<String>? returnColumns;

  final String? mainTable;

  SQL(this.sql, this.parameters,
      {this.condition,
      this.entityName,
      this.idFieldName,
      this.returnColumns,
      required this.mainTable});

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
    if (mainTable != null) {
      s += ' ; mainTable: $mainTable';
    }
    if (returnColumns != null && returnColumns!.isNotEmpty) {
      s += ' ; returnColumns: $returnColumns';
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
      return SQL(sqlQuery, {}, mainTable: table);
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
              condition: matcher,
              entityName: encodedSQL.entityName,
              mainTable: table);
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
              condition: matcher,
              entityName: encodedSQL.entityName,
              mainTable: table);
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

  /// If `true` indicates that this adapter SQL uses the `IGNORE` syntax for inserts.
  bool get sqlAcceptsInsertIgnore;

  /// If `true` indicates that this adapter SQL uses the `ON CONFLICT` syntax for inserts.
  bool get sqlAcceptsInsertOnConflict;

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
            entityName: table, idFieldName: idFieldName, mainTable: table);
      });
    });
  }

  FutureOr<SQL> generateUpdateSQL(Transaction transaction, String table,
      Object id, Map<String, Object?> fields) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        throw StateError("Can't find TableScheme for table: $table");
      }

      var context = EncodingContext(table,
          namedParameters: fields, transaction: transaction);

      var idFieldName = tableScheme.idFieldName!;
      var idPlaceholder =
          _conditionSQLGenerator.parameterPlaceholder(idFieldName);

      var fieldsValues = tableScheme.getFieldsValues(fields);

      var fieldsNotNull = fieldsValues.entries
          .map((e) => e.value != null && e.key != idFieldName ? e.key : null)
          .whereNotNull()
          .toList(growable: false);

      var fieldsValuesInSQL = <String, Object?>{idFieldName: id};

      return fieldsNotNull
          .map((f) => fieldValueToSQL(
              context, tableScheme, f, fieldsValues[f]!, fieldsValuesInSQL))
          .toList(growable: false)
          .resolveAll()
          .resolveMapped((values) {
        var sql = StringBuffer();

        sql.write('UPDATE "');
        sql.write(table);
        sql.write('" SET ');

        for (var i = 0; i < values.length; ++i) {
          var f = fieldsNotNull[i];
          var v = values[i];

          if (i > 0) sql.write(' , ');
          sql.write(f);
          sql.write(' = ');
          sql.write(v);
        }

        if (sqlAcceptsInsertOutput) {
          sql.write(' OUTPUT INSERTED.');
          sql.write(idFieldName);
        }

        sql.write(' WHERE ');
        sql.write(idFieldName);
        sql.write(' = ');
        sql.write(idPlaceholder);

        if (sqlAcceptsInsertReturning) {
          sql.write(' RETURNING "$table"."$idFieldName"');
        }

        return SQL(sql.toString(), fieldsValuesInSQL,
            entityName: table, idFieldName: idFieldName, mainTable: table);
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

  FutureOr<int> countSQL(TransactionOperation op, String table, SQL sql) {
    return executeTransactionOperation(op, (connection) {
      _log.log(logging.Level.INFO, 'countSQL> $sql');
      return doCountSQL(table, sql, connection);
    });
  }

  FutureOr<int> doCountSQL(
    String table,
    SQL sql,
    C connection,
  );

  FutureOr<dynamic> insertSQL(TransactionOperation op, String table, SQL sql,
      Map<String, Object?> fields,
      {T Function<T>(dynamic o)? mapper}) {
    return executeTransactionOperation(op, (connection) {
      _log.log(logging.Level.INFO, 'insertSQL> $sql');
      var retInsert = doInsertSQL(table, sql, connection);

      if (mapper != null) {
        return retInsert.resolveMapped((e) => mapper(e));
      } else {
        return retInsert;
      }
    });
  }

  FutureOr<dynamic> updateSQL(TransactionOperation op, String table, SQL sql,
      Object id, Map<String, Object?> fields,
      {T Function<T>(dynamic o)? mapper}) {
    return executeTransactionOperation(op, (connection) {
      _log.log(logging.Level.INFO, 'updateSQL> $sql');
      var retInsert = doInsertSQL(table, sql, connection);

      if (mapper != null) {
        return retInsert.resolveMapped((e) => mapper(e));
      } else {
        return retInsert;
      }
    });
  }

  FutureOr<dynamic> doUpdateSQL(String table, SQL sql, C connection);

  FutureOr<List<SQL>> generateInsertRelationshipSQLs(Transaction transaction,
      String table, dynamic id, String otherTableName, List otherIds) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        throw StateError("Can't find TableScheme for table: $table");
      }

      var relationship =
          tableScheme.getTableRelationshipReference(otherTableName);

      if (relationship == null) {
        throw StateError(
            "Can't find TableRelationshipReference for tables: $table -> $otherTableName");
      }

      var sqls = otherIds
          .map((otherId) =>
              _generateInsertRelationshipSQL(relationship, id, otherId))
          .toList();
      return sqls;
    });
  }

  SQL _generateInsertRelationshipSQL(
      TableRelationshipReference relationship, dynamic id, dynamic otherId) {
    var relationshipTable = relationship.relationshipTable;
    var sourceIdField = relationship.sourceRelationshipField;
    var targetIdField = relationship.targetRelationshipField;

    var parameters = {sourceIdField: id, targetIdField: otherId};

    var sql = StringBuffer();

    sql.write('INSERT ');

    if (sqlAcceptsInsertIgnore) {
      sql.write('IGNORE ');
    }

    sql.write('INTO "');
    sql.write(relationshipTable);
    sql.write('" ("');
    sql.write(sourceIdField);
    sql.write('" , "');
    sql.write(targetIdField);
    sql.write('")');
    sql.write(' VALUES ( @$sourceIdField , @$targetIdField )');

    if (sqlAcceptsInsertOnConflict) {
      sql.write(' ON CONFLICT DO NOTHING ');
    }

    return SQL(sql.toString(), parameters, mainTable: relationshipTable);
  }

  FutureOr<bool> insertRelationshipSQLs(TransactionOperation op, String table,
      List<SQL> sqls, dynamic id, String otherTable, List otherIds) {
    return executeTransactionOperation(op, (connection) {
      _log.log(logging.Level.INFO,
          'insertRelationship>${sqls.length == 1 ? ' ' : '\n  - '}${sqls.join('\n  -')}');

      var retInserts = sqls
          .map((sql) => doInsertSQL(sql.mainTable ?? table, sql, connection))
          .resolveAll();
      return retInserts.resolveWithValue(true);
    });
  }

  FutureOr<SQL> generateConstrainRelationshipSQL(Transaction transaction,
      String table, dynamic id, String otherTableName, List otherIds) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        throw StateError("Can't find TableScheme for table: $table");
      }

      var relationship =
          tableScheme.getTableRelationshipReference(otherTableName);

      if (relationship == null) {
        throw StateError(
            "Can't find TableRelationshipReference for tables: $table -> $otherTableName");
      }

      var relationshipTable = relationship.relationshipTable;
      var sourceIdField = relationship.sourceRelationshipField;
      var targetIdField = relationship.targetRelationshipField;

      var parameters = {sourceIdField: id};

      var otherIdsParameters = <String>[];

      var keyPrefix = sourceIdField != 'p' ? 'p' : 'i';

      for (var otherId in otherIds) {
        var i = otherIdsParameters.length + 1;
        var key = '$keyPrefix$i';
        parameters[key] = otherId;
        otherIdsParameters.add('@$key');
      }

      var sql = StringBuffer();

      sql.write('DELETE FROM "');
      sql.write(relationshipTable);
      sql.write('" WHERE ("');
      sql.write(sourceIdField);
      sql.write('" = @$sourceIdField AND "');
      sql.write(targetIdField);
      sql.write('" NOT IN ( ${otherIdsParameters.join(',')} ) )');

      var condition = GroupConditionAND([
        KeyConditionEQ([ConditionKeyField(sourceIdField)], id),
        KeyConditionNotIN([ConditionKeyField(targetIdField)], otherIds),
      ]);

      return SQL(sql.toString(), parameters,
          condition: condition, mainTable: relationshipTable);
    });
  }

  FutureOr<bool> executeConstrainRelationshipSQL(TransactionOperation op,
      String table, SQL sql, dynamic id, String otherTable, List otherIds) {
    return executeTransactionOperation(op, (connection) {
      _log.log(logging.Level.INFO, 'executeConstrainRelationshipSQL> $sql');

      var ret = doConstrainSQL(
          sql.mainTable ?? table, sql, connection, id, otherTable, otherIds);
      return ret;
    });
  }

  FutureOr<bool> doConstrainSQL(String table, SQL sql, C connection, dynamic id,
      String otherTable, List otherIds);

  FutureOr<SQL> generateSelectRelationshipSQL(Transaction transaction,
      String table, dynamic id, String otherTableName) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        throw StateError("Can't find TableScheme for table: $table");
      }

      var relationship =
          tableScheme.getTableRelationshipReference(otherTableName);

      if (relationship == null) {
        throw StateError(
            "Can't find TableRelationshipReference for tables: $table -> $otherTableName");
      }

      var parameters = {'source_id': id};

      var sql = StringBuffer();

      sql.write('SELECT "');
      sql.write(relationship.targetRelationshipField);
      sql.write('" FROM "');
      sql.write(relationship.relationshipTable);
      sql.write('" WHERE ("');
      sql.write(relationship.sourceRelationshipField);
      sql.write('" = @source_id ');
      sql.write(' )');

      var condition = KeyConditionEQ(
          [ConditionKeyField(relationship.sourceRelationshipField)], id);

      return SQL(sql.toString(), parameters,
          condition: condition,
          returnColumns: {relationship.targetRelationshipField},
          mainTable: relationship.relationshipTable);
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipSQL(
      TransactionOperation op,
      String table,
      SQL sql,
      dynamic id,
      String otherTable) {
    return executeTransactionOperation(op, (connection) {
      _log.log(logging.Level.INFO, 'selectRelationshipSQL> $sql');

      var ret = doSelectSQL(sql.mainTable ?? table, sql, connection);
      return ret;
    });
  }

  FutureOr<R> executeTransactionOperation<R>(
          TransactionOperation op, FutureOr<R> Function(C connection) f) =>
      executeWithPool(f);

  FutureOr<dynamic> doInsertSQL(String table, SQL sql, C connection);

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(
      TransactionOperation op, String table, SQL sql,
      {Map<String, dynamic> Function(Map<String, dynamic> r)? mapper}) {
    return executeTransactionOperation(op, (connection) {
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
      TransactionOperation op, String table, SQL sql,
      {Map<String, dynamic> Function(Map<String, dynamic> r)? mapper}) {
    return executeTransactionOperation(op, (connection) {
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

  SQLRepositoryAdapter<O>? createRepositoryAdapter<O>(String name,
      {String? tableName, Type? type}) {
    if (isClosed) {
      return null;
    }

    return _repositoriesAdapters.putIfAbsent(
        name,
        () => SQLRepositoryAdapter<O>(this, name,
            tableName: tableName, type: type)) as SQLRepositoryAdapter<O>;
  }

  SQLRepositoryAdapter<O>? getRepositoryAdapterByName<O>(
    String name,
  ) {
    if (isClosed) return null;
    return _repositoriesAdapters[name] as SQLRepositoryAdapter<O>?;
  }

  SQLRepositoryAdapter<O>? getRepositoryAdapterByType<O>(Type type) {
    if (isClosed) return null;
    return _repositoriesAdapters.values.firstWhereOrNull((e) => e.type == type)
        as SQLRepositoryAdapter<O>?;
  }

  SQLRepositoryAdapter<O>? getRepositoryAdapterByTableName<O>(
      String tableName) {
    if (isClosed) return null;
    return _repositoriesAdapters.values
            .firstWhereOrNull((e) => e.tableName == tableName)
        as SQLRepositoryAdapter<O>?;
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

typedef PreFinishSQLOperation<T, R> = FutureOr<R> Function(T result);

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

  SchemeProvider get schemeProvider => databaseAdapter;

  FutureOr<TableScheme> getTableScheme() =>
      databaseAdapter.getTableScheme(tableName).resolveMapped((t) => t!);

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

  FutureOr<int> countSQL(TransactionOperation op, SQL sql) {
    return databaseAdapter.countSQL(op, tableName, sql);
  }

  FutureOr<int> doCount(TransactionOperation op,
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      PreFinishSQLOperation<int, int>? preFinish}) {
    return generateCountSQL(op.transaction,
            matcher: matcher,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters)
        .resolveMapped((sql) {
      return countSQL(op, sql)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
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
      TransactionOperation op, SQL sql) {
    return databaseAdapter.selectSQL(op, tableName, sql);
  }

  FutureOr<R> doSelect<R>(TransactionOperation op, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit,
      PreFinishSQLOperation<Iterable<Map<String, dynamic>>, R>? preFinish}) {
    return generateSelectSQL(op.transaction, matcher,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters,
            limit: limit)
        .resolveMapped((sql) {
      return selectSQL(op, sql)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  FutureOr<SQL> generateInsertSQL(
      Transaction transaction, O o, Map<String, dynamic> fields) {
    return databaseAdapter.generateInsertSQL(transaction, tableName, fields);
  }

  FutureOr<dynamic> insertSQL(
      TransactionOperation op, SQL sql, Map<String, dynamic> fields,
      {String? idFieldName}) {
    return databaseAdapter
        .insertSQL(op, tableName, sql, fields)
        .resolveMapped((ret) => ret ?? {});
  }

  FutureOr<dynamic> doInsert(
      TransactionOperation op, O o, Map<String, dynamic> fields,
      {String? idFieldName,
      PreFinishSQLOperation<dynamic, dynamic>? preFinish}) {
    return generateInsertSQL(op.transaction, o, fields).resolveMapped((sql) {
      return insertSQL(op, sql, fields, idFieldName: idFieldName)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  FutureOr<SQL> generateUpdateSQL(
      Transaction transaction, O o, Object id, Map<String, dynamic> fields) {
    return databaseAdapter.generateUpdateSQL(
        transaction, tableName, id, fields);
  }

  FutureOr<dynamic> updateSQL(
      TransactionOperation op, SQL sql, Object id, Map<String, dynamic> fields,
      {String? idFieldName}) {
    return databaseAdapter
        .updateSQL(op, tableName, sql, id, fields)
        .resolveMapped((ret) => ret ?? {});
  }

  FutureOr<dynamic> doUpdate(
      TransactionOperation op, O o, Object id, Map<String, dynamic> fields,
      {String? idFieldName,
      PreFinishSQLOperation<dynamic, dynamic>? preFinish}) {
    return generateUpdateSQL(op.transaction, o, id, fields)
        .resolveMapped((sql) {
      return updateSQL(op, sql, id, fields, idFieldName: idFieldName)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  FutureOr<List<SQL>> generateInsertRelationshipSQLs(Transaction transaction,
      dynamic id, String otherTableName, List otherIds) {
    return databaseAdapter.generateInsertRelationshipSQLs(
        transaction, tableName, id, otherTableName, otherIds);
  }

  FutureOr<bool> insertRelationshipSQLs(TransactionOperation op, List<SQL> sqls,
      dynamic id, String otherTableName, List otherIds) {
    return databaseAdapter.insertRelationshipSQLs(
        op, tableName, sqls, id, otherTableName, otherIds);
  }

  FutureOr<bool> doInsertRelationship(
      TransactionOperation op, dynamic id, String otherTableName, List otherIds,
      [PreFinishSQLOperation<bool, bool>? preFinish]) {
    return generateInsertRelationshipSQLs(
            op.transaction, id, otherTableName, otherIds)
        .resolveMapped((sqls) {
      return insertRelationshipSQLs(op, sqls, id, otherTableName, otherIds)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  FutureOr<SQL> generateConstrainRelationshipSQL(Transaction transaction,
      dynamic id, String otherTableName, List othersIds) {
    return databaseAdapter.generateConstrainRelationshipSQL(
        transaction, tableName, id, otherTableName, othersIds);
  }

  FutureOr<bool> executeConstrainRelationshipSQL(TransactionOperation op,
      SQL sql, dynamic id, String otherTableName, List otherIds) {
    return databaseAdapter.executeConstrainRelationshipSQL(
        op, tableName, sql, id, otherTableName, otherIds);
  }

  FutureOr<bool> doConstrainRelationship(TransactionOperation op, dynamic id,
      String otherTableName, List othersIds,
      [PreFinishSQLOperation<bool, bool>? preFinish]) {
    return databaseAdapter
        .generateConstrainRelationshipSQL(
            op.transaction, tableName, id, otherTableName, othersIds)
        .resolveMapped((sql) {
      return executeConstrainRelationshipSQL(
              op, sql, id, otherTableName, othersIds)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  FutureOr<R> _finishOperation<T, R>(
      TransactionOperation op, T res, PreFinishSQLOperation<T, R>? preFinish) {
    if (preFinish != null) {
      return preFinish(res).resolveMapped((res2) => op.finish(res2));
    } else {
      return op.finish<R>(res as R);
    }
  }

  FutureOr<SQL> generateSelectRelationshipSQL(
      Transaction transaction, dynamic id, String otherTableName) {
    return databaseAdapter.generateSelectRelationshipSQL(
        transaction, tableName, id, otherTableName);
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipSQL(
      TransactionOperation op, SQL sql, dynamic id, String otherTableName) {
    return databaseAdapter.selectRelationshipSQL(
        op, tableName, sql, id, otherTableName);
  }

  FutureOr<R> doSelectRelationship<R>(
      TransactionOperation op, dynamic id, String otherTableName,
      [PreFinishSQLOperation<Iterable<Map<String, dynamic>>, R>? preFinish]) {
    return generateSelectRelationshipSQL(op.transaction, id, otherTableName)
        .resolveMapped((sql) {
      return selectRelationshipSQL(op, sql, id, otherTableName)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
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
      TransactionOperation op, SQL sql) {
    return databaseAdapter.deleteSQL(op, tableName, sql);
  }

  FutureOr<R> doDelete<R>(TransactionOperation op, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      PreFinishSQLOperation<Iterable<Map<String, dynamic>>, R>? preFinish}) {
    return generateDeleteSQL(op.transaction, matcher,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters)
        .resolveMapped((sql) {
      return deleteSQL(op, sql)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }
}

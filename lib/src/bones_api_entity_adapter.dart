import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_condition_sql.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_sql.dart';
import 'bones_api_mixin.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';

final _log = logging.Logger('SQLRepositoryAdapter');

typedef PasswordProvider = FutureOr<String> Function(String user);

/// [SQL] wrapper interface.
abstract class SQLWrapper {
  /// The amount of [SQL]s.
  int get sqlsLength;

  /// Returns the main [SQL].
  SQL get mainSQL;

  /// Returns all wrapped [SQL]s.
  Iterable<SQL> get allSQLs;
}

/// Class to wrap multiple [SQL]s.
class MultipleSQL implements SQLWrapper {
  final List<SQL> sqls;

  MultipleSQL(this.sqls);

  @override
  Iterable<SQL> get allSQLs => sqls;

  @override
  SQL get mainSQL => sqls.first;

  @override
  int get sqlsLength => sqls.length;
}

/// An encoded SQL representation.
/// This is used by a [SQLAdapter] to execute queries.
class SQL implements SQLWrapper {
  static final SQL dummy = SQL('dummy', <String, dynamic>{}, mainTable: '_');

  @override
  int get sqlsLength => 1;

  @override
  SQL get mainSQL => this;

  @override
  Iterable<SQL> get allSQLs => [this];

  final Condition? condition;
  final String? entityName;

  final String sql;
  final String? sqlCondition;

  final Map<String, dynamic> parameters;

  final String? idFieldName;

  final Set<String>? returnColumns;

  final String? mainTable;
  final Map<String, String>? tablesAliases;

  final RegExp placeholderRegexp;

  static final RegExp _defaultPlaceholderRegexp = RegExp(r'@(\w+)');

  String? _sqlPositional;

  List<String>? _parametersKeysByPosition;

  List<Object?>? _parametersValuesByPosition;

  List<SQL>? preSQL;

  List<SQL>? posSQL;
  int? posSQLReturnIndex;

  bool get hasPreSQL => preSQL != null && preSQL!.isNotEmpty;

  bool get hasPosSQL => posSQL != null && posSQL!.isNotEmpty;

  bool get hasPreOrPosSQL => hasPreSQL || hasPosSQL;

  SQL(this.sql, this.parameters,
      {this.sqlCondition,
      String? sqlPositional,
      List<String>? parametersKeysByPosition,
      List<Object?>? parametersValuesByPosition,
      this.condition,
      this.entityName,
      this.idFieldName,
      this.returnColumns,
      required this.mainTable,
      this.tablesAliases,
      RegExp? placeholderRegexp})
      : _sqlPositional = sqlPositional,
        _parametersKeysByPosition = parametersKeysByPosition,
        _parametersValuesByPosition = parametersValuesByPosition,
        placeholderRegexp = placeholderRegexp ?? _defaultPlaceholderRegexp;

  bool get isDummy => this == dummy;

  String get sqlPositional {
    if (_sqlPositional == null) _computeSQLPositional();
    return _sqlPositional!;
  }

  List<String> get parametersKeysByPosition {
    if (_parametersKeysByPosition == null) _computeSQLPositional();
    return _parametersKeysByPosition!;
  }

  List<Object?> get parametersValuesByPosition {
    if (_parametersValuesByPosition == null) _computeSQLPositional();
    return _parametersValuesByPosition!;
  }

  void _computeSQLPositional() {
    var keys = <String>[];
    var values = <Object?>[];

    if (parameters.isEmpty) {
      _sqlPositional ??= sql;
      _parametersKeysByPosition ??= keys;
      _parametersValuesByPosition ??= values;

      return;
    }

    var sqlPositional = sql.replaceAllMapped(placeholderRegexp, (m) {
      var k = m.group(1)!;
      var v = parameters[k];
      keys.add(k);
      values.add(v);
      return '?';
    });

    _sqlPositional ??= sqlPositional;

    _parametersKeysByPosition ??= keys;
    _parametersValuesByPosition ??= values;
  }

  @override
  String toString() {
    var s =
        'SQL<< $sql >>( ${Json.encode(parameters, toEncodable: _toEncodable)} )';
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

    if (preSQL != null) {
      s += '\n - preSQL: ';
      s += preSQL.toString();
    }

    if (posSQL != null) {
      s += '\n - posSQL: ';
      s += posSQL.toString();
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
///
/// A [SQLAdapter] implementation is responsible to connect to the database and
/// adjust the generated `SQL`s to the correct dialect.
///
/// All [SQLAdapter]s comes with a built-in connection pool.
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
    _conditionSQLGenerator =
        ConditionSQLEncoder(this, sqlElementQuote: sqlElementQuote);
    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  @override
  void initialize();

  @override
  FutureOr<O?> getEntityByID<O>(dynamic id, {Type? type}) {
    if (id == null) return null;
    var entityRepository = getEntityRepository(type: type);
    return entityRepository?.selectByID(id).resolveMapped((o) => o as O?);
  }

  @override
  FutureOr<String?> getTableForType(TypeInfo type) {
    if (type.hasArguments) {
      if (type.isMap) {
        type = type.arguments[1];
      } else if (type.isIterable || type.isList || type.isSet) {
        type = type.arguments[0];
      }
    }

    var entityType = type.type;

    var entityRepository = getEntityRepository(type: entityType);

    if (entityRepository != null) {
      if (entityRepository is SQLEntityRepository) {
        return entityRepository.tableName;
      } else {
        return entityRepository.name;
      }
    }

    return null;
  }

  EntityRepository? _geAdapterEntityRepository(
      {String? entityName, String? tableName, Type? entityType}) {
    EntityRepository? entityRepository;

    if (entityName != null) {
      entityRepository = getEntityRepository(name: entityName);
    }

    if (entityRepository == null &&
        tableName != null &&
        tableName != entityName) {
      entityRepository = getEntityRepository(tableName: tableName);
    }

    if (entityRepository == null && entityType != null) {
      entityRepository = getEntityRepository(type: entityType);
    }

    return entityRepository;
  }

  @override
  FutureOr<TypeInfo?> getFieldType(String field,
      {String? entityName, String? tableName, Type? entityType}) {
    var entityRepository = _geAdapterEntityRepository(
        entityName: entityName, tableName: tableName, entityType: entityType);

    if (entityRepository != null) {
      var type = entityRepository.entityHandler.getFieldType(null, field);
      return type;
    }

    return null;
  }

  @override
  FutureOr<Object?> getEntityID(Object entity,
      {String? entityName, String? tableName, Type? entityType}) {
    var entityRepository = _geAdapterEntityRepository(
        entityName: entityName, tableName: tableName, entityType: entityType);

    if (entityRepository != null) {
      var entityHandler = entityRepository.entityHandler;

      if (entity is Map) {
        var idFieldsName = entityHandler.idFieldsName();
        return entity[idFieldsName];
      } else {
        return entityHandler.getID(entity);
      }
    }

    return null;
  }

  /// The type of "quote" to use to reference elements (tables and columns).
  String get sqlElementQuote;

  /// If `true` indicates that this adapter SQL uses the `OUTPUT` syntax for inserts/deletes.
  bool get sqlAcceptsOutputSyntax;

  /// If `true` indicates that this adapter SQL uses the `RETURNING` syntax for inserts/deletes.
  bool get sqlAcceptsReturningSyntax;

  /// If `true` indicates that this adapter SQL needs a temporary table to return rows for inserts/deletes.
  bool get sqlAcceptsTemporaryTableForReturning;

  /// If `true` indicates that this adapter SQL uses the `IGNORE` syntax for inserts.
  bool get sqlAcceptsInsertIgnore;

  /// If `true` indicates that this adapter SQL uses the `ON CONFLICT` syntax for inserts.
  bool get sqlAcceptsInsertOnConflict;

  /// Converts [value] to an acceptable SQL value for the adapter.
  Object? valueToSQL(Object? value) {
    if (value == null) {
      return null;
    } else if (value is Time) {
      return value.toString();
    } else if (value is DynamicNumber) {
      return value.toStringStandard();
    } else if (value is Enum) {
      var enumType = value.runtimeType;
      var enumReflection =
          ReflectionFactory().getRegisterEnumReflection(enumType);

      var name = enumReflection?.getName(value);
      name ??= enumToName(value);

      return name;
    } else {
      return value;
    }
  }

  FutureOr<String> fieldValueToSQL(
      EncodingContext context,
      TableScheme tableScheme,
      String fieldName,
      Object? value,
      Map<String, Object?> fieldsValues) {
    var fieldRef = tableScheme.getFieldsReferencedTables(fieldName);

    if (fieldRef == null || value == null) {
      fieldsValues.putIfAbsent(fieldName, () => valueToSQL(value));
      var valueSQL = _conditionSQLGenerator.parameterPlaceholder(fieldName);
      return valueSQL;
    } else {
      var refEntity = value;
      var refEntityRepository = getEntityRepository(obj: refEntity);

      if (refEntityRepository != null) {
        var refId = refEntityRepository.entityHandler
            .getField(refEntity, fieldRef.targetField);

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

  FutureOr<SQL> generateCountSQL(
      Transaction transaction, String entityName, String table,
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var q = sqlElementQuote;

    if (matcher == null) {
      var sqlQuery = 'SELECT count(*) as ${q}count$q FROM $q$table$q ';
      return SQL(sqlQuery, {}, mainTable: table);
    } else {
      return _generateSQLFrom(transaction, entityName, table, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          sqlBuilder: (String from, EncodingContext context) {
        var tableAlias = context.resolveEntityAlias(table);
        return 'SELECT count($q$tableAlias$q.*) as ${q}count$q $from';
      });
    }
  }

  FutureOr<int> countSQL(
      TransactionOperation op, String entityName, String table, SQL sql) {
    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] countSQL> $sql');
      return doCountSQL(entityName, table, sql, connection);
    });
  }

  FutureOr<int> doCountSQL(
    String entityName,
    String table,
    SQL sql,
    C connection,
  );

  FutureOr<SQL> generateInsertSQL(Transaction transaction, String entityName,
      String table, Map<String, Object?> fields) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        throw StateError("Can't find TableScheme for table: $table");
      }

      var context = EncodingContext(entityName,
          namedParameters: fields, transaction: transaction, tableName: table);

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

        var q = sqlElementQuote;

        var sql = StringBuffer();

        sql.write('INSERT INTO $q');
        sql.write(table);
        sql.write('$q ($q');
        sql.write(fieldsNotNull.join('$q,$q'));
        sql.write('$q)');

        if (sqlAcceptsOutputSyntax) {
          sql.write(' OUTPUT INSERTED.');
          sql.write(q);
          sql.write(idFieldName);
          sql.write(q);
        }

        sql.write(' VALUES (');
        sql.write(values.join(' , '));
        sql.write(')');

        if (sqlAcceptsReturningSyntax) {
          sql.write(' RETURNING $q$table$q.$q$idFieldName$q');
        }

        return SQL(sql.toString(), fieldsValuesInSQL,
            entityName: table, idFieldName: idFieldName, mainTable: table);
      });
    });
  }

  FutureOr<dynamic> insertSQL(TransactionOperation op, String entityName,
      String table, SQL sql, Map<String, Object?> fields,
      {T Function<T>(dynamic o)? mapper}) {
    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] insertSQL> $sql');
      var retInsert = doInsertSQL(entityName, table, sql, connection);

      if (mapper != null) {
        return retInsert.resolveMapped((e) => mapper(e));
      } else {
        return retInsert;
      }
    });
  }

  FutureOr<dynamic> doInsertRelationshipSQL(
      String entityName, String table, SQL sql, C connection) {
    return doInsertSQL(entityName, table, sql, connection);
  }

  FutureOr<dynamic> doInsertSQL(
      String entityName, String table, SQL sql, C connection);

  FutureOr<SQL> generateUpdateSQL(Transaction transaction, String entityName,
      String table, Object id, Map<String, Object?> fields) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        throw StateError("Can't find TableScheme for table: $table");
      }

      var context = EncodingContext(entityName,
          namedParameters: fields, transaction: transaction);

      var idFieldName = tableScheme.idFieldName!;
      var idPlaceholder =
          _conditionSQLGenerator.parameterPlaceholder(idFieldName);

      var fieldsValues =
          tableScheme.getFieldsValues(fields, fields: fields.keys.toSet());

      if (fieldsValues.isEmpty) {
        throw StateError("Can't get fields values!");
      }

      var fieldsKeys = fieldsValues.keys.toList();

      var fieldsValuesInSQL = <String, Object?>{idFieldName: id};

      return fieldsKeys
          .map((f) => fieldValueToSQL(
              context, tableScheme, f, fieldsValues[f], fieldsValuesInSQL))
          .toList(growable: false)
          .resolveAll()
          .resolveMapped((values) {
        var q = sqlElementQuote;
        var sql = StringBuffer();

        sql.write('UPDATE $q');
        sql.write(table);
        sql.write('$q SET ');

        for (var i = 0; i < values.length; ++i) {
          var f = fieldsKeys[i];
          var v = values[i];

          if (i > 0) sql.write(' , ');
          sql.write(q);
          sql.write(f);
          sql.write(q);
          sql.write(' = ');
          sql.write(v);
        }

        if (sqlAcceptsOutputSyntax) {
          sql.write(' OUTPUT INSERTED.');
          sql.write(q);
          sql.write(idFieldName);
          sql.write(q);
        }

        sql.write(' WHERE ');

        var conditionSQL = '$idFieldName = $idPlaceholder';
        sql.write(conditionSQL);

        if (sqlAcceptsReturningSyntax) {
          sql.write(' RETURNING $q$table$q.$q$idFieldName$q');
        }

        return SQL(sql.toString(), fieldsValuesInSQL,
            sqlCondition: conditionSQL,
            entityName: table,
            idFieldName: idFieldName,
            mainTable: table);
      });
    });
  }

  FutureOr<dynamic> updateSQL(TransactionOperation op, String entityName,
      String table, SQL sql, Object id, Map<String, Object?> fields,
      {T Function<T>(dynamic o)? mapper}) {
    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] updateSQL> $sql');
      var retInsert = doUpdateSQL(entityName, table, sql, id, connection);

      if (mapper != null) {
        return retInsert.resolveMapped((e) => mapper(e));
      } else {
        return retInsert;
      }
    });
  }

  FutureOr<dynamic> doUpdateSQL(
      String entityName, String table, SQL sql, Object id, C connection);

  FutureOr<List<SQL>> generateInsertRelationshipSQLs(
      Transaction transaction,
      String entityName,
      String table,
      dynamic id,
      String otherTableName,
      List otherIds) {
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

      var sqls = otherIds.isEmpty
          ? [SQL.dummy]
          : otherIds
              .map((otherId) =>
                  _generateInsertRelationshipSQL(relationship, id, otherId))
              .toList();

      var constrainSQL = _generateConstrainRelationshipSQL(
          tableScheme, table, id, otherTableName, otherIds);

      sqls.last.posSQL = [constrainSQL];

      return sqls;
    });
  }

  SQL _generateInsertRelationshipSQL(
      TableRelationshipReference relationship, dynamic id, dynamic otherId) {
    var relationshipTable = relationship.relationshipTable;
    var sourceIdField = relationship.sourceRelationshipField;
    var targetIdField = relationship.targetRelationshipField;

    var parameters = {sourceIdField: id, targetIdField: otherId};

    var q = sqlElementQuote;
    var sql = StringBuffer();

    sql.write('INSERT ');

    if (sqlAcceptsInsertIgnore) {
      sql.write('IGNORE ');
    }

    sql.write('INTO $q');
    sql.write(relationshipTable);
    sql.write('$q ($q');
    sql.write(sourceIdField);
    sql.write('$q , $q');
    sql.write(targetIdField);
    sql.write('$q)');
    sql.write(' VALUES ( @$sourceIdField , @$targetIdField )');

    if (sqlAcceptsInsertOnConflict) {
      sql.write(' ON CONFLICT DO NOTHING ');
    }

    return SQL(sql.toString(), parameters, mainTable: relationshipTable);
  }

  SQL _generateConstrainRelationshipSQL(TableScheme tableScheme, String table,
      dynamic id, String otherTableName, List otherIds) {
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

    var q = sqlElementQuote;

    var sqlCondition = StringBuffer();

    sqlCondition.write(q);
    sqlCondition.write(sourceIdField);
    sqlCondition.write('$q = @$sourceIdField');

    if (otherIdsParameters.isNotEmpty) {
      sqlCondition.write(' AND $q');
      sqlCondition.write(targetIdField);
      sqlCondition.write('$q NOT IN ( ${otherIdsParameters.join(',')} )');
    }

    var conditionSQL = sqlCondition.toString();

    var sql = StringBuffer();

    sql.write('DELETE FROM $q');
    sql.write(relationshipTable);
    sql.write('$q WHERE ( ');
    sql.write(conditionSQL);
    sql.write(' )');

    var condition = GroupConditionAND([
      KeyConditionEQ([ConditionKeyField(sourceIdField)], id),
      KeyConditionNotIN([ConditionKeyField(targetIdField)], otherIds),
    ]);

    return SQL(sql.toString(), parameters,
        condition: condition,
        sqlCondition: conditionSQL,
        mainTable: relationshipTable);
  }

  FutureOr<bool> insertRelationshipSQLs(
      TransactionOperation op,
      String entityName,
      String table,
      List<SQL> sqls,
      dynamic id,
      String otherTable,
      List otherIds) {
    return executeTransactionOperation(op, sqls.first, (connection) {
      _log.info(
          '[transaction:${op.transactionId}] insertRelationship>${sqls.length == 1 ? ' ' : '\n  - '}${sqls.join('\n  -')}');

      var retInserts = sqls.map((sql) {
        var ret = doInsertRelationshipSQL(
            entityName, sql.mainTable ?? table, sql, connection);

        if (sql.hasPosSQL) {
          sql.posSQL!.map((e) {
            _log.info(
                '[transaction:${op.transactionId}] insertRelationship[POS]> $e');
            return doDeleteSQL(entityName, e.mainTable!, e, connection);
          }).resolveAllWithValue(ret);
        } else {
          return ret;
        }
      }).resolveAll();
      return retInserts.resolveWithValue(true);
    });
  }

  FutureOr<SQL> generateSelectRelationshipSQL(Transaction transaction,
      String entityName, String table, dynamic id, String otherTableName) {
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

      var q = sqlElementQuote;

      var conditionSQL =
          '$q${relationship.sourceRelationshipField}$q = @source_id';

      var sql = StringBuffer();

      sql.write('SELECT $q');
      sql.write(relationship.targetRelationshipField);
      sql.write('$q FROM $q');
      sql.write(relationship.relationshipTable);
      sql.write('$q WHERE ( ');
      sql.write(conditionSQL);
      sql.write(' )');

      var condition = KeyConditionEQ(
          [ConditionKeyField(relationship.sourceRelationshipField)], id);

      return SQL(sql.toString(), parameters,
          condition: condition,
          sqlCondition: conditionSQL,
          returnColumns: {relationship.targetRelationshipField},
          mainTable: relationship.relationshipTable);
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipSQL(
      TransactionOperation op,
      String entityName,
      String table,
      SQL sql,
      dynamic id,
      String otherTable) {
    return executeTransactionOperation(op, sql, (connection) {
      _log.info(
          '[transaction:${op.transactionId}] selectRelationshipSQL> $sql');

      var ret =
          doSelectSQL(entityName, sql.mainTable ?? table, sql, connection);
      return ret;
    });
  }

  FutureOr<R> executeTransactionOperation<R>(TransactionOperation op,
          SQLWrapper sql, FutureOr<R> Function(C connection) f) =>
      executeWithPool(f);

  FutureOr<SQL> generateSelectSQL(Transaction transaction, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit}) {
    return _generateSQLFrom(transaction, entityName, table, matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        sqlBuilder: (String from, EncodingContext context) {
      var tableAlias = context.resolveEntityAlias(table);
      var q = sqlElementQuote;
      var limitStr = limit != null && limit > 0 ? ' LIMIT $limit' : '';
      var sql = 'SELECT $q$tableAlias$q.* $from$limitStr';
      return sql;
    });
  }

  FutureOr<SQL> _generateSQLFrom(Transaction transaction, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      required String Function(String from, EncodingContext context)
          sqlBuilder}) {
    if (matcher is! Condition) {
      throw StateError('Invalid SQL condition: $matcher');
    }

    var retEncodedSQL = _conditionSQLGenerator.encode(matcher, entityName,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        tableName: table);

    return retEncodedSQL.resolveMapped((encodedSQL) {
      var conditionSQL = encodedSQL.outputString;

      var tableAlias =
          _conditionSQLGenerator.resolveEntityAlias(encodedSQL, table);

      var q = sqlElementQuote;

      if (encodedSQL.fieldsReferencedTables.isEmpty &&
          encodedSQL.relationshipTables.isEmpty) {
        String from;
        if (conditionSQL.isNotEmpty) {
          from = 'FROM $q$table$q as $q$tableAlias$q WHERE $conditionSQL';
        } else {
          from = 'FROM $q$table$q as $q$tableAlias$q';
        }

        var sqlQuery = sqlBuilder(from, encodedSQL);

        return SQL(sqlQuery, encodedSQL.parametersPlaceholders,
            condition: matcher,
            sqlCondition: conditionSQL,
            entityName: encodedSQL.entityName,
            mainTable: table,
            tablesAliases: encodedSQL.tableAliases);
      } else {
        var innerJoin = StringBuffer();

        for (var e in encodedSQL.referencedTablesFields.entries) {
          var refTable = e.key;
          var refTableAlias = encodedSQL.resolveEntityAlias(refTable);

          innerJoin.write('INNER JOIN $q$refTable$q as $q$refTableAlias$q ON ');

          for (var fieldRef in e.value) {
            var sourceTableAlias = _conditionSQLGenerator.resolveEntityAlias(
                encodedSQL, fieldRef.sourceTable);
            var targetTableAlias = _conditionSQLGenerator.resolveEntityAlias(
                encodedSQL, fieldRef.targetTable);

            innerJoin.write(q);
            innerJoin.write(sourceTableAlias);
            innerJoin.write(q);
            innerJoin.write('.');
            innerJoin.write(q);
            innerJoin.write(fieldRef.sourceField);
            innerJoin.write(q);

            innerJoin.write(' = ');

            innerJoin.write(q);
            innerJoin.write(targetTableAlias);
            innerJoin.write(q);
            innerJoin.write('.');
            innerJoin.write(q);
            innerJoin.write(fieldRef.targetField);
            innerJoin.write(q);
          }
        }

        for (var e in encodedSQL.relationshipTables.entries) {
          var targetTable = e.key;
          var relationship = e.value;

          var relTable = relationship.relationshipTable;
          var relTableAlias = encodedSQL.resolveEntityAlias(relTable);

          String sourceTableField;
          String sourceRelationshipField;

          if (relationship.sourceTable == table) {
            sourceTableField = relationship.sourceField;
            sourceRelationshipField = relationship.sourceRelationshipField;
          } else {
            sourceTableField = relationship.targetField;
            sourceRelationshipField = relationship.targetRelationshipField;
          }

          innerJoin
              .write('INNER JOIN $q$relTable$q as $q$relTableAlias$q ON (');

          innerJoin.write(q);
          innerJoin.write(relTableAlias);
          innerJoin.write(q);
          innerJoin.write('.');
          innerJoin.write(q);
          innerJoin.write(sourceRelationshipField);
          innerJoin.write(q);

          innerJoin.write(' = ');

          innerJoin.write(q);
          innerJoin.write(tableAlias);
          innerJoin.write(q);
          innerJoin.write('.');
          innerJoin.write(q);
          innerJoin.write(sourceTableField);
          innerJoin.write(q);

          innerJoin.write(') ');

          var targetTableAlias = _conditionSQLGenerator.resolveEntityAlias(
              encodedSQL, targetTable);

          String targetTableField;
          String targetRelationshipField;

          if (relationship.targetTable == targetTable) {
            targetTableField = relationship.targetField;
            targetRelationshipField = relationship.targetRelationshipField;
          } else {
            targetTableField = relationship.sourceField;
            targetRelationshipField = relationship.sourceRelationshipField;
          }

          innerJoin.write(
              'INNER JOIN $q$targetTable$q as $q$targetTableAlias$q ON (');

          innerJoin.write(q);
          innerJoin.write(targetTableAlias);
          innerJoin.write(q);
          innerJoin.write('.');
          innerJoin.write(q);
          innerJoin.write(targetTableField);
          innerJoin.write(q);

          innerJoin.write(' = ');

          innerJoin.write(q);
          innerJoin.write(relTableAlias);
          innerJoin.write(q);
          innerJoin.write('.');
          innerJoin.write(q);
          innerJoin.write(targetRelationshipField);
          innerJoin.write(q);

          innerJoin.write(') ');
        }

        var from =
            'FROM $q$table$q as $q$tableAlias$q $innerJoin WHERE $conditionSQL';
        var sqlQuery = sqlBuilder(from, encodedSQL);

        return SQL(sqlQuery, encodedSQL.parametersPlaceholders,
            condition: matcher,
            sqlCondition: conditionSQL,
            entityName: encodedSQL.entityName,
            mainTable: table,
            tablesAliases: encodedSQL.tableAliases);
      }
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(
      TransactionOperation op, String entityName, String table, SQL sql,
      {Map<String, dynamic> Function(Map<String, dynamic> r)? mapper}) {
    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] selectSQL> $sql');

      var retSel = doSelectSQL(entityName, table, sql, connection);

      if (mapper != null) {
        return retSel.resolveMapped((e) => e.map(mapper));
      } else {
        return retSel;
      }
    });
  }

  static int temporaryTableIdCount = 0;

  static String createTemporaryTableName(String prefix) {
    var id = ++temporaryTableIdCount;
    var seed = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${seed}_$id';
  }

  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
    String entityName,
    String table,
    SQL sql,
    C connection,
  );

  FutureOr<SQL> generateDeleteSQL(Transaction transaction, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var retDeleteSQL = _generateSQLFrom(transaction, entityName, table, matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        sqlBuilder: (String from, EncodingContext context) {
      var tableAlias = context.resolveEntityAlias(table);

      var sql = StringBuffer();
      sql.write('DELETE ');

      if (sqlAcceptsOutputSyntax) {
        sql.write(' OUTPUT DELETED.* ');
      }

      sql.write(from);

      if (sqlAcceptsReturningSyntax) {
        sql.write(' RETURNING "$tableAlias".*');
      }

      return sql.toString();
    });

    if (sqlAcceptsTemporaryTableForReturning &&
        !sqlAcceptsOutputSyntax &&
        !sqlAcceptsReturningSyntax) {
      return retDeleteSQL.resolveMapped((deleteSQL) {
        var conditionSQL = deleteSQL.sqlCondition;

        var tableAlias = deleteSQL.tablesAliases?[table];

        var tmpTable = createTemporaryTableName(table);

        var q = sqlElementQuote;

        var sqlSelAll = tableAlias != null ? ' $q$tableAlias$q.* ' : '*';
        var sqlAsTableAlias = tableAlias != null ? ' as $q$tableAlias$q ' : '';

        var preSql = SQL(
            'CREATE TEMPORARY TABLE IF NOT EXISTS $q$tmpTable$q AS ('
            ' SELECT $sqlSelAll FROM $q$table$q$sqlAsTableAlias WHERE $conditionSQL '
            ')',
            deleteSQL.parameters,
            mainTable: tmpTable);

        var posSql1 =
            SQL('SELECT * FROM $q$tmpTable$q', {}, mainTable: tmpTable);

        var posSql2 = SQL('DROP TABLE $q$tmpTable$q', {}, mainTable: tmpTable);

        deleteSQL.preSQL = [preSql];
        deleteSQL.posSQL = [posSql1, posSql2];
        deleteSQL.posSQLReturnIndex = 0;

        return deleteSQL;
      });
    }

    return retDeleteSQL;
  }

  FutureOr<Iterable<Map<String, dynamic>>> deleteSQL(
      TransactionOperation op, String entityName, String table, SQL sql,
      {Map<String, dynamic> Function(Map<String, dynamic> r)? mapper}) {
    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] deleteSQL> $sql');

      var retSel = doDeleteSQL(entityName, table, sql, connection);

      if (mapper != null) {
        return retSel.resolveMapped((e) => e.map(mapper));
      } else {
        return retSel;
      }
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
    String entityName,
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
  void registerEntityRepository<O extends Object>(
      EntityRepository<O> entityRepository) {
    checkNotClosed();

    _entityRepositories[entityRepository.type] = entityRepository;
  }

  @override
  List<EntityRepository> get registeredEntityRepositories =>
      _entityRepositories.values.toList();

  bool _callingGetEntityRepository = false;

  @override
  EntityRepository<O>? getEntityRepository<O extends Object>(
      {O? obj, Type? type, String? name, String? tableName}) {
    if (isClosed) return null;

    if (_callingGetEntityRepository) return null;
    _callingGetEntityRepository = true;

    try {
      return _getEntityRepositoryImpl<O>(
              obj: obj, type: type, name: name, tableName: tableName) ??
          EntityRepositoryProvider.globalProvider
              .getEntityRepository<O>(obj: obj, type: type, name: name);
    } finally {
      _callingGetEntityRepository = false;
    }
  }

  EntityRepository<O>? _getEntityRepositoryImpl<O extends Object>(
      {O? obj, Type? type, String? name, String? tableName}) {
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

      if (tableName != null) {
        entityRepository = _entityRepositories.values
            .where((e) => e is SQLEntityRepository && e.tableName == tableName)
            .firstOrNull;
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
      databaseAdapter.generateCountSQL(transaction, name, tableName,
          matcher: matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  FutureOr<int> countSQL(TransactionOperation op, SQL sql) {
    return databaseAdapter.countSQL(op, name, tableName, sql);
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
      databaseAdapter.generateSelectSQL(transaction, name, tableName, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          limit: limit);

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(
      TransactionOperation op, SQL sql) {
    return databaseAdapter.selectSQL(op, name, tableName, sql);
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
    return databaseAdapter.generateInsertSQL(
        transaction, name, tableName, fields);
  }

  FutureOr<dynamic> insertSQL(
      TransactionOperation op, SQL sql, Map<String, dynamic> fields,
      {String? idFieldName}) {
    return databaseAdapter
        .insertSQL(op, name, tableName, sql, fields)
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
        transaction, name, tableName, id, fields);
  }

  FutureOr<dynamic> updateSQL(
      TransactionOperation op, SQL sql, Object id, Map<String, dynamic> fields,
      {String? idFieldName}) {
    return databaseAdapter
        .updateSQL(op, name, tableName, sql, id, fields)
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
        transaction, name, tableName, id, otherTableName, otherIds);
  }

  FutureOr<bool> insertRelationshipSQLs(TransactionOperation op, List<SQL> sqls,
      dynamic id, String otherTableName, List otherIds) {
    return databaseAdapter.insertRelationshipSQLs(
        op, name, tableName, sqls, id, otherTableName, otherIds);
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
        transaction, name, tableName, id, otherTableName);
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipSQL(
      TransactionOperation op, SQL sql, dynamic id, String otherTableName) {
    return databaseAdapter.selectRelationshipSQL(
        op, name, tableName, sql, id, otherTableName);
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
      databaseAdapter.generateDeleteSQL(transaction, name, tableName, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters);

  FutureOr<Iterable<Map<String, dynamic>>> deleteSQL(
      TransactionOperation op, SQL sql) {
    return databaseAdapter.deleteSQL(op, name, tableName, sql);
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

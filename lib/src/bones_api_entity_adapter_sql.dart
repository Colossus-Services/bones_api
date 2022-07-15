import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_condition_sql.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';
import 'bones_api_entity_adapter_memory.dart';
import 'bones_api_initializable.dart';
import 'bones_api_platform.dart';
import 'bones_api_sql_builder.dart';
import 'bones_api_types.dart';
import 'bones_api_utils_collections.dart';
import 'bones_api_utils_json.dart';

final _log = logging.Logger('SQLAdapter');

/// An encoded SQL representation.
/// This is used by a [SQLAdapter] to execute queries.
class SQL implements SQLWrapper {
  static final SQL dummy = SQL(
      'dummy', <dynamic>[], <String, dynamic>{}, <String, dynamic>{},
      mainTable: '_');

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

  final List<dynamic>? positionalParameters;
  final Map<String, dynamic>? namedParameters;
  final Map<String, dynamic> parametersByPlaceholder;

  final String? idFieldName;

  final Set<String>? returnColumns;

  final Map<String, String>? returnColumnsAliases;

  final String? mainTable;
  final TableRelationshipReference? relationship;

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

  SQL(this.sql, this.positionalParameters, this.namedParameters,
      this.parametersByPlaceholder,
      {this.sqlCondition,
      String? sqlPositional,
      List<String>? parametersKeysByPosition,
      List<Object?>? parametersValuesByPosition,
      this.condition,
      this.entityName,
      this.idFieldName,
      this.returnColumns,
      this.returnColumnsAliases,
      required this.mainTable,
      this.relationship,
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

    if (parametersByPlaceholder.isEmpty) {
      _sqlPositional ??= sql;
      _parametersKeysByPosition ??= keys;
      _parametersValuesByPosition ??= values;

      return;
    }

    var sqlPositional = sql.replaceAllMapped(placeholderRegexp, (m) {
      var k = m.group(1)!;
      var v = parametersByPlaceholder[k];
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
        'SQL<< $sql >>( ${Json.encode(parametersByPlaceholder, toEncodable: _toEncodable)} )';
    if (condition != null) {
      s += ' ; Condition<< $condition >>';
    }
    if (entityName != null) {
      s += ' ; entityName: $entityName';
    }
    if (mainTable != null) {
      s += ' ; mainTable: $mainTable';
    }
    if (relationship != null) {
      s += ' ($relationship)';
    }
    if (returnColumns != null && returnColumns!.isNotEmpty) {
      s += ' ; returnColumns: $returnColumns';
    }

    if (returnColumnsAliases != null && returnColumnsAliases!.isNotEmpty) {
      s += ' ; returnColumnsAliases: $returnColumnsAliases';
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
      return Json.toJson(o);
    } catch (e) {
      return '$o';
    }
  }
}

/// [SQLAdapter] capabilities.
class SQLAdapterCapability extends DBAdapterCapability {
  /// `true` if the adapter supports table SQLs.
  /// See [SQLAdapter.populateTables].
  final bool tableSQL;

  const SQLAdapterCapability(
      {required String dialect,
      required bool transactions,
      required bool transactionAbort,
      required this.tableSQL})
      : super(
            dialect: dialect,
            transactions: transactions,
            transactionAbort: transactionAbort);
}

typedef SQLAdapterInstantiator<C extends Object, A extends SQLAdapter<C>>
    = DBAdapterInstantiator<C, A>;

/// Base class for SQL DB adapters.
///
/// A [SQLAdapter] implementation is responsible to connect to the database and
/// adjust the generated `SQL`s to the correct dialect.
///
/// All [SQLAdapter]s comes with a built-in connection pool.
abstract class SQLAdapter<C extends Object> extends DBAdapter<C>
    with SQLGenerator {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    MemorySQLAdapter.boot();
  }

  static final Map<String, SQLAdapterInstantiator> _registeredAdaptersByName =
      <String, SQLAdapterInstantiator>{};
  static final Map<Type, SQLAdapterInstantiator> _registeredAdaptersByType =
      <Type, SQLAdapterInstantiator>{};

  static List<String> get registeredAdaptersNames =>
      _registeredAdaptersByName.keys.toList();

  static List<Type> get registeredAdaptersTypes =>
      _registeredAdaptersByType.keys.toList();

  static void registerAdapter<C extends Object, A extends SQLAdapter<C>>(
      List<String> names,
      Type type,
      SQLAdapterInstantiator<C, A> adapterInstantiator) {
    for (var name in names) {
      _registeredAdaptersByName[name] = adapterInstantiator;
    }

    _registeredAdaptersByType[type] = adapterInstantiator;

    DBAdapter.registerAdapter(names, type, adapterInstantiator);
  }

  static SQLAdapterInstantiator<C, A>?
      getAdapterInstantiator<C extends Object, A extends SQLAdapter<C>>(
          {String? name, Type? type}) {
    if (name == null && type == null) {
      throw ArgumentError(
          'One of the parameters `name` or `type` should NOT be null!');
    }

    if (name != null) {
      var adapter = _registeredAdaptersByName[name];
      if (adapter is SQLAdapterInstantiator<C, A>) {
        return adapter;
      }
    }

    if (type != null) {
      var adapter = _registeredAdaptersByType[type];
      if (adapter is SQLAdapterInstantiator<C, A>) {
        return adapter;
      }
    }

    return null;
  }

  static List<MapEntry<SQLAdapterInstantiator<C, A>, Map<String, dynamic>>>
      getAdapterInstantiatorsFromConfig<C extends Object,
              A extends SQLAdapter<C>>(Map<String, dynamic> config) =>
          DBAdapter.getAdapterInstantiatorsFromConfigImpl<C, A>(
              config, registeredAdaptersNames, getAdapterInstantiator);

  /// The [SQLAdapter] capability.
  @override
  SQLAdapterCapability get capability =>
      super.capability as SQLAdapterCapability;

  late final ConditionSQLEncoder _conditionSQLGenerator;

  SQLAdapter(
      int minConnections, int maxConnections, SQLAdapterCapability capability,
      {EntityRepositoryProvider? parentRepositoryProvider,
      Object? populateTables,
      Object? populateSource})
      : _populateTables = populateTables,
        super(minConnections, maxConnections, capability,
            parentRepositoryProvider: parentRepositoryProvider,
            populateSource: populateSource) {
    boot();

    _conditionSQLGenerator =
        ConditionSQLEncoder(this, sqlElementQuote: sqlElementQuote);
  }

  static FutureOr<A> fromConfig<C extends Object, A extends SQLAdapter<C>>(
      Map<String, dynamic> config,
      {int minConnections = 1,
      int maxConnections = 3,
      EntityRepositoryProvider? parentRepositoryProvider}) {
    boot();

    var instantiators = getAdapterInstantiatorsFromConfig<C, A>(config);

    if (instantiators.isEmpty) {
      throw StateError(
          "Can't find `$A` instantiator for `config` keys: ${config.keys.toList()}");
    }

    return DBAdapter.instantiateAdaptor<C, A>(instantiators, config,
        minConnections: minConnections,
        maxConnections: maxConnections,
        parentRepositoryProvider: parentRepositoryProvider);
  }

  Object? _populateTables;

  @override
  FutureOr<InitializationResult> populateImpl() {
    var tables = _populateTables;

    if (tables != null) {
      _populateTables = null;

      return populateTables(tables).resolveMapped((_) => super.populateImpl());
    } else {
      return super.populateImpl();
    }
  }

  FutureOr<List<String>> populateTables(Object? tables) {
    if (tables == null) {
      return <String>[];
    } else if (tables is String) {
      if (RegExp(r'^\S+\.sql$').hasMatch(tables)) {
        var apiPlatform = APIPlatform.get();

        _log.info(
            'Reading $this populate tables file: ${apiPlatform.resolveFilePath(tables)}');

        var fileData = apiPlatform.readFileAsString(tables);

        if (fileData != null) {
          return fileData.resolveMapped((data) {
            if (data != null) {
              _log.info(
                  'Populating $this tables [encoded JSON length: ${data.length}]...');

              return populateTablesFromSQLs(data).resolveMapped((res) {
                _log.info('Populate tables finished.');
                return <String>[];
              });
            } else {
              return <String>[];
            }
          });
        }
      }
    }

    return <String>[];
  }

  FutureOr<bool> populateTablesFromSQLs(String sqls) {
    var list = extractTableSQLs(sqls);
    if (list.isEmpty) return true;
    return _populateTablesFromSQLsImpl(list);
  }

  static List<String> extractTableSQLs(String sqls) => extractSQLs(sqls,
      RegExp(r'(?:CREATE|ALTER)\s+TABLE', caseSensitive: false, dotAll: true));

  static List<String> extractSQLs(String sqls, RegExp commandPrefixPattern) {
    sqls =
        sqls.replaceAllMapped(RegExp(r'(?:\n|^)--.*?([\r\n]+)'), (m) => m[1]!);
    sqls = sqls.replaceAllMapped(RegExp(r'/\*.*?\*/'), (m) => m[1]!);
    sqls = '\n$sqls\n;';

    var list = <String>[];

    var regexpCreateTableSQL = RegExp(
        r'\s' + commandPrefixPattern.pattern + r'\s.*?;',
        caseSensitive: false,
        dotAll: true);

    sqls.replaceAllMapped(regexpCreateTableSQL, (m) {
      var sql = m[0]!;
      list.add(sql);
      return '';
    });

    return list;
  }

  Future<bool> _populateTablesFromSQLsImpl(List<String> list) async {
    for (var sql in list) {
      var ok = await executeTableSQL(sql);
      if (!ok) {
        throw StateError("Error creating table SQL: $sql");
      }
    }

    return true;
  }

  /// Generates the [CreateTableSQL] for each [EntityRepository].
  /// See [entityRepositories].
  FutureOr<Map<EntityRepository, CreateTableSQL>>
      generateEntityRepositoresCreateTableSQLs() => entityRepositories
          .map((r) => MapEntry<EntityRepository, FutureOr<CreateTableSQL>>(
              r, generateCreateTableSQL(entityRepository: r)))
          .toMapFromEntries()
          .resolveAllValues();

  /// Generate all the SQLs to create the tables.
  @override
  FutureOr<List<SQLBuilder>> generateCreateTableSQLs() =>
      generateEntityRepositoresCreateTableSQLs().resolveMapped((sqls) {
        List<SQLBuilder> allSQLs =
            sqls.values.expand((e) => e.allSQLBuilders).toList();

        allSQLs.bestOrder();
        return allSQLs;
      });

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
    } else if (value is DateTime) {
      return value.toUtc();
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

  FutureOr<bool> executeTableSQL(String createTableSQL);

  FutureOr<SQL> generateCountSQL(
      Transaction transaction, String entityName, String table,
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
    var q = sqlElementQuote;

    if (matcher == null) {
      var sqlQuery = 'SELECT count(*) as ${q}count$q FROM $q$table$q ';
      return SQL(
        sqlQuery,
        positionalParameters ?? (parameters is List ? parameters : null),
        namedParameters ??
            (parameters is Map<String, dynamic> ? parameters : null),
        {},
        mainTable: table,
      );
    } else {
      return _generateSQLFrom(transaction, entityName, table, matcher,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          sqlBuilder: (String from, EncodingContext context) {
        return 'SELECT count(*) as ${q}count$q $from';
      });
    }
  }

  FutureOr<int> countSQL(
      TransactionOperation op, String entityName, String table, SQL sql) {
    if (sql.isDummy) return 0;

    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] countSQL> $sql');
      return doCountSQL(entityName, table, sql, op.transaction, connection);
    });
  }

  FutureOr<int> doCountSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    C connection,
  );

  @override
  FutureOr<int> doCount(
      TransactionOperation op, String entityName, String table,
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      PreFinishDBOperation<int, int>? preFinish}) {
    return generateCountSQL(op.transaction, entityName, table,
            matcher: matcher,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters)
        .resolveMapped((sql) {
      return countSQL(op, entityName, table, sql)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  FutureOr<SQL> generateInsertSQL(Transaction transaction, String entityName,
      String table, Map<String, Object?> fields) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
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
        assert(fieldsNotNull.length == values.length);

        var idFieldName = tableScheme.idFieldName;
        assert(idFieldName != null && idFieldName.isNotEmpty);

        var q = sqlElementQuote;

        var sql = StringBuffer();

        sql.write('INSERT INTO $q');
        sql.write(table);
        sql.write(q);

        if (fieldsNotNull.isNotEmpty) {
          sql.write('(');
          sql.write(fieldsNotNull.map((f) => '$q$f$q').join(','));
          sql.write(')');
        }

        if (sqlAcceptsOutputSyntax) {
          sql.write(' OUTPUT INSERTED.');
          sql.write(q);
          sql.write(idFieldName);
          sql.write(q);
        }

        if (values.isNotEmpty) {
          sql.write(' VALUES (');
          sql.write(values.join(' , '));
          sql.write(')');
        } else {
          sql.write(' DEFAULT VALUES ');
        }

        if (sqlAcceptsReturningSyntax) {
          sql.write(' RETURNING $q$table$q.$q$idFieldName$q');
        }

        return SQL(sql.toString(), null, fields, fieldsValuesInSQL,
            entityName: table, idFieldName: idFieldName, mainTable: table);
      });
    });
  }

  FutureOr<dynamic> insertSQL(TransactionOperation op, String entityName,
      String table, SQL sql, Map<String, Object?> fields,
      {T Function<T>(dynamic o)? mapper}) {
    if (sql.isDummy) return null;

    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] insertSQL> $sql');
      var retInsert =
          doInsertSQL(entityName, table, sql, op.transaction, connection);

      if (mapper != null) {
        return retInsert.resolveMapped((e) => mapper(e));
      } else {
        return retInsert;
      }
    });
  }

  FutureOr<dynamic> doInsertRelationshipSQL(String entityName, String table,
      SQL sql, Transaction transaction, C connection) {
    return doInsertSQL(entityName, table, sql, transaction, connection);
  }

  FutureOr<dynamic> doInsertSQL(String entityName, String table, SQL sql,
      Transaction transaction, C connection);

  FutureOr<SQL> generateUpdateSQL(Transaction transaction, String entityName,
      String table, Object id, Map<String, Object?> fields) {
    if (fields.isEmpty) return SQL.dummy;

    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var context = EncodingContext(entityName,
          namedParameters: fields, transaction: transaction);

      var idFieldName = tableScheme.idFieldName!;
      var idPlaceholder =
          _conditionSQLGenerator.parameterPlaceholder(idFieldName);

      var fieldsValues =
          tableScheme.getFieldsValues(fields, fields: fields.keys.toSet());

      // No value to update:
      if (fieldsValues.isEmpty) {
        return SQL.dummy;
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

        return SQL(sql.toString(), null, fields, fieldsValuesInSQL,
            sqlCondition: conditionSQL,
            entityName: table,
            idFieldName: idFieldName,
            mainTable: table);
      });
    });
  }

  FutureOr<dynamic> updateSQL(TransactionOperation op, String entityName,
      String table, SQL sql, Object id, Map<String, Object?> fields,
      {T Function<T>(dynamic o)? mapper, bool allowAutoInsert = false}) {
    if (sql.isDummy) return null;

    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] updateSQL> $sql');
      var retInsert = doUpdateSQL(
          entityName, table, sql, id, op.transaction, connection,
          allowAutoInsert: allowAutoInsert);

      if (mapper != null) {
        return retInsert.resolveMapped((e) => mapper(e));
      } else {
        return retInsert;
      }
    });
  }

  FutureOr<dynamic> doUpdateSQL(String entityName, String table, SQL sql,
      Object id, Transaction transaction, C connection,
      {bool allowAutoInsert = false});

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
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var relationship =
          tableScheme.getTableRelationshipReference(otherTableName);

      if (relationship == null) {
        throw StateError(
            "Can't find TableRelationshipReference for tables: $table -> $otherTableName\n$tableScheme");
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

    return SQL(sql.toString(), null, parameters, parameters,
        mainTable: relationshipTable, relationship: relationship);
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

    return SQL(sql.toString(), null, parameters, parameters,
        condition: condition,
        sqlCondition: conditionSQL,
        mainTable: relationshipTable,
        relationship: relationship);
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
        var ret = doInsertRelationshipSQL(entityName, sql.mainTable ?? table,
            sql, op.transaction, connection);

        if (sql.hasPosSQL) {
          sql.posSQL!.map((e) {
            _log.info(
                '[transaction:${op.transactionId}] insertRelationship[POS]> $e');
            return doDeleteSQL(
                entityName, e.mainTable!, e, op.transaction, connection);
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
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
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
      sql.write(relationship.sourceRelationshipField);
      sql.write('$q as ${q}source_id$q , $q');
      sql.write(relationship.targetRelationshipField);
      sql.write('$q as ${q}target_id$q FROM $q');
      sql.write(relationship.relationshipTable);
      sql.write('$q WHERE ( ');
      sql.write(conditionSQL);
      sql.write(' )');

      var condition = KeyConditionEQ(
          [ConditionKeyField(relationship.sourceRelationshipField)], id);

      return SQL(sql.toString(), null, parameters, parameters,
          condition: condition,
          sqlCondition: conditionSQL,
          returnColumnsAliases: {
            relationship.sourceRelationshipField: 'source_id',
            relationship.targetRelationshipField: 'target_id',
          },
          mainTable: relationship.relationshipTable,
          relationship: relationship);
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipSQL(
      TransactionOperation op,
      String entityName,
      String table,
      SQL sql,
      dynamic id,
      String otherTable) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _log.info(
          '[transaction:${op.transactionId}] selectRelationshipSQL> $sql');

      var ret = doSelectSQL(
          entityName, sql.mainTable ?? table, sql, op.transaction, connection);
      return ret;
    });
  }

  FutureOr<SQL> generateSelectRelationshipsSQL(
      Transaction transaction,
      String entityName,
      String table,
      List<dynamic> ids,
      String otherTableName) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var relationship =
          tableScheme.getTableRelationshipReference(otherTableName);

      if (relationship == null) {
        throw StateError(
            "Can't find TableRelationshipReference for tables: $table -> $otherTableName");
      }

      var q = sqlElementQuote;

      var conditionSQL =
          StringBuffer('$q${relationship.sourceRelationshipField}$q IN (');

      var parameters = <String, dynamic>{};
      for (var i = 0; i < ids.length; ++i) {
        var p = 'p$i';
        var id = ids[i];
        parameters[p] = id;
        if (i > 0) conditionSQL.write(', ');
        conditionSQL.write('@$p');
      }

      conditionSQL.write(') ');

      var conditionSQLStr = conditionSQL.toString();

      var sql = StringBuffer();

      sql.write('SELECT $q');
      sql.write(relationship.sourceRelationshipField);
      sql.write('$q as ${q}source_id$q , $q');
      sql.write(relationship.targetRelationshipField);
      sql.write('$q as ${q}target_id$q FROM $q');
      sql.write(relationship.relationshipTable);
      sql.write('$q WHERE ( ');
      sql.write(conditionSQLStr);
      sql.write(' )');

      var condition = KeyConditionIN(
          [ConditionKeyField(relationship.sourceRelationshipField)], ids);

      return SQL(sql.toString(), ids, {'ids': ids}, parameters,
          condition: condition,
          sqlCondition: conditionSQLStr,
          returnColumnsAliases: {
            relationship.sourceRelationshipField: 'source_id',
            relationship.targetRelationshipField: 'target_id',
          },
          mainTable: relationship.relationshipTable,
          relationship: relationship);
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipsSQL(
      TransactionOperation op,
      String entityName,
      String table,
      SQL sql,
      List<dynamic> ids,
      String otherTable) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _log.info(
          '[transaction:${op.transactionId}] selectRelationshipsSQL> $sql');

      var ret = doSelectSQL(
          entityName, sql.mainTable ?? table, sql, op.transaction, connection);
      return ret;
    });
  }

  FutureOr<R> executeTransactionOperation<R>(TransactionOperation op,
      SQLWrapper sql, FutureOr<R> Function(C connection) f) {
    var transaction = op.transaction;

    if (transaction.length == 1 &&
        !transaction.isExecuting &&
        sql.sqlsLength == 1 &&
        !sql.mainSQL.hasPreOrPosSQL) {
      return executeWithPool(f);
    }

    if (!transaction.isOpen && !transaction.isOpening) {
      transaction.open(
        () => openTransaction(transaction),
        callCloseTransactionRequired
            ? () => closeTransaction(transaction, transaction.context as C?)
            : null,
      );
    }

    return transaction.onOpen<R>(() {
      return transaction.addExecution<R, C>((c) => f(c),
          debugInfo: () => sql.mainSQL.toString());
    });
  }

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

        return SQL(
          sqlQuery,
          positionalParameters ?? (parameters is List ? parameters : null),
          namedParameters ??
              (parameters is Map<String, dynamic> ? parameters : null),
          encodedSQL.parametersPlaceholders,
          condition: matcher,
          sqlCondition: conditionSQL,
          entityName: encodedSQL.entityName,
          mainTable: table,
          tablesAliases: encodedSQL.tableAliases,
        );
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

        return SQL(
          sqlQuery,
          positionalParameters ?? (parameters is List ? parameters : null),
          namedParameters ??
              (parameters is Map<String, dynamic> ? parameters : null),
          encodedSQL.parametersPlaceholders,
          condition: matcher,
          sqlCondition: conditionSQL,
          entityName: encodedSQL.entityName,
          mainTable: table,
          tablesAliases: encodedSQL.tableAliases,
        );
      }
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(
      TransactionOperation op, String entityName, String table, SQL sql,
      {Map<String, dynamic> Function(Map<String, dynamic> r)? mapper}) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] selectSQL> $sql');

      var retSel =
          doSelectSQL(entityName, table, sql, op.transaction, connection);

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
    Transaction transaction,
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
            positionalParameters ?? (parameters is List ? parameters : null),
            namedParameters ??
                (parameters is Map<String, dynamic> ? parameters : null),
            deleteSQL.parametersByPlaceholder,
            mainTable: tmpTable);

        var posSql1 =
            SQL('SELECT * FROM $q$tmpTable$q', [], {}, {}, mainTable: tmpTable);

        var posSql2 =
            SQL('DROP TABLE $q$tmpTable$q', [], {}, {}, mainTable: tmpTable);

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
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _log.info('[transaction:${op.transactionId}] deleteSQL> $sql');

      var retSel =
          doDeleteSQL(entityName, table, sql, op.transaction, connection);

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
    Transaction transaction,
    C connection,
  );

  @override
  SQLRepositoryAdapter<O>? createRepositoryAdapter<O>(String name,
          {String? tableName, Type? type}) =>
      super.createRepositoryAdapter<O>(name, tableName: tableName, type: type)
          as SQLRepositoryAdapter<O>?;

  @override
  SQLRepositoryAdapter<O> instantiateRepositoryAdapter<O>(
          String name, String? tableName, Type? type) =>
      SQLRepositoryAdapter<O>(this, name, tableName: tableName, type: type);

  @override
  SQLRepositoryAdapter<O>? getRepositoryAdapterByName<O>(
    String name,
  ) =>
      super.getRepositoryAdapterByName<O>(name) as SQLRepositoryAdapter<O>?;

  @override
  SQLRepositoryAdapter<O>? getRepositoryAdapterByType<O>(Type type) =>
      super.getRepositoryAdapterByType<O>(type) as SQLRepositoryAdapter<O>?;

  @override
  SQLRepositoryAdapter<O>? getRepositoryAdapterByTableName<O>(
          String tableName) =>
      super.getRepositoryAdapterByTableName(tableName)
          as SQLRepositoryAdapter<O>?;

  FutureOr<R> _finishOperation<T, R>(
      TransactionOperation op, T res, PreFinishDBOperation<T, R>? preFinish) {
    if (preFinish != null) {
      return preFinish(res).resolveMapped((res2) => op.finish(res2));
    } else {
      return op.finish<R>(res as R);
    }
  }

  @override
  FutureOr<R> doDelete<R>(TransactionOperation op, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish}) {
    return generateDeleteSQL(op.transaction, entityName, table, matcher,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters)
        .resolveMapped((sql) {
      return deleteSQL(op, entityName, table, sql)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  @override
  FutureOr doInsert<O>(TransactionOperation op, String entityName, String table,
      O o, Map<String, dynamic> fields,
      {String? idFieldName, PreFinishDBOperation? preFinish}) {
    return generateInsertSQL(op.transaction, entityName, table, fields)
        .resolveMapped((sql) {
      return insertSQL(op, entityName, table, sql, fields)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  @override
  FutureOr<bool> doInsertRelationship(TransactionOperation op,
      String entityName, String table, id, String otherTableName, List otherIds,
      [PreFinishDBOperation<bool, bool>? preFinish]) {
    return generateInsertRelationshipSQLs(
            op.transaction, entityName, table, id, otherTableName, otherIds)
        .resolveMapped((sqls) {
      return insertRelationshipSQLs(
              op, entityName, table, sqls, id, otherTableName, otherIds)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  @override
  FutureOr<R> doSelect<R>(TransactionOperation op, String entityName,
      String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit,
      PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish}) {
    return generateSelectSQL(op.transaction, entityName, table, matcher,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters,
            limit: limit)
        .resolveMapped((sql) {
      return selectSQL(op, entityName, table, sql)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  @override
  FutureOr<R> doSelectRelationship<R>(TransactionOperation op,
      String entityName, String table, dynamic id, String otherTableName,
      [PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish]) {
    return generateSelectRelationshipSQL(
            op.transaction, entityName, table, id, otherTableName)
        .resolveMapped((sql) {
      return selectRelationshipSQL(
              op, entityName, table, sql, id, otherTableName)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  @override
  FutureOr<R> doSelectRelationships<R>(TransactionOperation op,
      String entityName, String table, List ids, String otherTableName,
      [PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish]) {
    return generateSelectRelationshipsSQL(
            op.transaction, entityName, table, ids, otherTableName)
        .resolveMapped((sql) {
      return selectRelationshipsSQL(
              op, entityName, table, sql, ids, otherTableName)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }

  @override
  FutureOr doUpdate<O>(TransactionOperation op, String entityName, String table,
      O o, Object id, Map<String, dynamic> fields,
      {String? idFieldName,
      PreFinishDBOperation? preFinish,
      bool allowAutoInsert = false}) {
    return generateUpdateSQL(op.transaction, entityName, table, id, fields)
        .resolveMapped((sql) {
      return updateSQL(op, entityName, table, sql, id, fields,
              allowAutoInsert: allowAutoInsert)
          .resolveMapped((r) => _finishOperation(op, r, preFinish));
    });
  }
}

class SQLRepositoryAdapter<O> extends DBRepositoryAdapter<O> {
  @override
  SQLAdapter get databaseAdapter => super.databaseAdapter as SQLAdapter;

  SQLRepositoryAdapter(SQLAdapter databaseAdapter, String name,
      {String? tableName, Type? type})
      : super(databaseAdapter, name, tableName: tableName, type: type);

  @override
  FutureOr<InitializationResult> initialize() =>
      databaseAdapter.ensureInitialized(parent: this);

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

  FutureOr<SQL> generateUpdateSQL(
      Transaction transaction, O o, Object id, Map<String, dynamic> fields) {
    return databaseAdapter.generateUpdateSQL(
        transaction, name, tableName, id, fields);
  }

  FutureOr<dynamic> updateSQL(
      TransactionOperation op, SQL sql, Object id, Map<String, dynamic> fields,
      {String? idFieldName, bool allowAutoInsert = false}) {
    return databaseAdapter
        .updateSQL(op, name, tableName, sql, id, fields,
            allowAutoInsert: allowAutoInsert)
        .resolveMapped((ret) => ret ?? {});
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

  FutureOr<SQL> generateSelectRelationshipsSQL(
      Transaction transaction, List<dynamic> ids, String otherTableName) {
    return databaseAdapter.generateSelectRelationshipsSQL(
        transaction, name, tableName, ids, otherTableName);
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipsSQL(
      TransactionOperation op,
      SQL sql,
      List<dynamic> ids,
      String otherTableName) {
    return databaseAdapter.selectRelationshipsSQL(
        op, name, tableName, sql, ids, otherTableName);
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

  @override
  String toString() =>
      'SQLRepositoryAdapter{name: $name, tableName: $tableName, type: $type}';
}

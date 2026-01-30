import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mysql1/mysql1.dart';
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart' show Decimal, DynamicInt;

import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_sql.dart';
import 'bones_api_error_zone.dart';
import 'bones_api_initializable.dart';
import 'bones_api_logging.dart';
import 'bones_api_sql_builder.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';
import 'bones_api_utils_timedmap.dart';

final _log = logging.Logger('DBMySQLAdapter')..registerAsDbLogger();

/// A MySQL adapter.
class DBMySQLAdapter extends DBSQLAdapter<DBMySqlConnectionWrapper>
    implements WithRuntimeTypeNameSafe {
  @override
  String get runtimeTypeNameSafe => 'DBMySQLAdapter';

  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBSQLAdapter.boot();

    Transaction.registerErrorFilter((e, s) => e is MySqlException);

    DBSQLAdapter.registerAdapter(
      ['sql.mysql', 'mysql'],
      DBMySQLAdapter,
      _instantiate,
    );
  }

  static FutureOr<DBMySQLAdapter?> _instantiate(
    config, {
    int? minConnections,
    int? maxConnections,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    try {
      return DBMySQLAdapter.fromConfig(
        config,
        minConnections: minConnections,
        maxConnections: maxConnections,
        parentRepositoryProvider: parentRepositoryProvider,
        workingPath: workingPath,
      );
    } catch (e, s) {
      _log.severe("Error instantiating from config", e, s);
      return null;
    }
  }

  final String host;
  final int port;
  final String databaseName;

  final String username;

  final String? _password;
  final PasswordProvider? _passwordProvider;

  DBMySQLAdapter(
    this.databaseName,
    this.username, {
    String? host = 'localhost',
    Object? password,
    PasswordProvider? passwordProvider,
    int? port = 3306,
    int minConnections = 1,
    int maxConnections = 3,
    super.generateTables,
    super.checkTables,
    super.populateTables,
    super.populateSource,
    super.populateSourceVariables,
    super.parentRepositoryProvider,
    super.workingPath,
    super.logSQL,
  }) : host = host ?? 'localhost',
       port = port ?? 3306,
       _password =
           (password != null && password is! PasswordProvider
               ? password.toString()
               : null),
       _passwordProvider =
           passwordProvider ?? (password is PasswordProvider ? password : null),
       super(
         'mysql',
         minConnections,
         maxConnections,
         const DBSQLAdapterCapability(
           dialect: SQLDialect(
             'MySQL',
             elementQuote: '`',
             acceptsTemporaryTableForReturning: true,
             acceptsInsertIgnore: true,
             createIndexIfNotExists: false,
           ),
           transactions: true,
           transactionAbort: true,
           tableSQL: true,
           constraintSupport: false,
           multiIsolateSupport: true,
           connectivity: DBAdapterCapabilityConnectivity.secureAndUnsecure,
         ),
       ) {
    boot();

    if (_password == null && _passwordProvider == null) {
      throw ArgumentError("No `password` or `passwordProvider` ");
    }

    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  factory DBMySQLAdapter.fromConfig(
    Map<String, dynamic>? config, {
    String? defaultDatabase,
    String? defaultUsername,
    String? defaultHost,
    int? defaultPort,
    int? minConnections,
    int? maxConnections,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    boot();

    String? host = config?['host'] ?? defaultHost;
    int? port = config?['port'] ?? defaultPort;
    String? database = config?['database'] ?? config?['db'] ?? defaultDatabase;
    String? username =
        config?['username'] ?? config?['user'] ?? defaultUsername;
    String? password = (config?['password'] ?? config?['pass'])?.toString();

    int? confMinConnections = config?['minConnections'];
    if (confMinConnections != null) {
      minConnections = confMinConnections;
    }

    int? confMaxConnections = config?['maxConnections'];
    if (confMaxConnections != null) {
      maxConnections = confMaxConnections;
    }

    minConnections ??= 1;
    maxConnections ??= 3;

    var (
      generateTables: generateTables,
      checkTables: checkTables,
    ) = DBSQLAdapter.parseConfigDBGenerateTablesAndCheckTables(config);

    var populate = config?['populate'];
    Object? populateTables;
    Object? populateSource;
    Object? populateSourceVariables;

    if (populate is Map) {
      populateTables = populate['tables'];
      populateSource = populate['source'];
      populateSourceVariables = populate['variables'];
    }

    if (database == null) throw ArgumentError.notNull('database');
    if (username == null) throw ArgumentError.notNull('username');

    var logSql = DBSQLAdapter.parseConfigLogSQL(config) ?? false;

    return DBMySQLAdapter(
      database,
      username,
      password: password,
      host: host,
      port: port,
      minConnections: minConnections,
      maxConnections: maxConnections,
      generateTables: generateTables,
      checkTables: checkTables,
      populateTables: populateTables,
      populateSource: populateSource,
      populateSourceVariables: populateSourceVariables,
      parentRepositoryProvider: parentRepositoryProvider,
      workingPath: workingPath,
      logSQL: logSql,
    );
  }

  FutureOr<String> _getPassword() {
    if (_password != null) {
      return _password;
    } else {
      return _passwordProvider!(username);
    }
  }

  @override
  List<Initializable> initializeDependencies() {
    var parentRepositoryProvider = this.parentRepositoryProvider;
    return <Initializable>[
      if (parentRepositoryProvider != null) parentRepositoryProvider,
    ];
  }

  @override
  SQLDialect get dialect => super.dialect as SQLDialect;

  @override
  String getConnectionURL(DBMySqlConnectionWrapper connection) {
    return 'mysql://$username@$host:$port/$databaseName';
  }

  Zone? _errorZoneInstance;

  Zone get _errorZone {
    return _errorZoneInstance ??= createErrorZone(
      uncaughtErrorTitle: 'DBMySQLAdapter ERROR:',
    );
  }

  int _connectionCount = 0;

  @override
  FutureOr<DBMySqlConnectionWrapper> createConnection() async {
    var password = await _getPassword();

    var count = ++_connectionCount;

    var connWrapper = await _createConnectionImpl(password);

    var connUrl = getConnectionURL(connWrapper);

    _log.info(
      'createConnection[#$count $poolAliveElementsSize/$maxConnections]> $connUrl > ${connWrapper.nativeConnection}',
    );

    return connWrapper;
  }

  Future<_DBMySqlConnectionWrapped> _createConnectionImpl(
    String password,
  ) async {
    var connSettings = ConnectionSettings(
      host: host,
      port: port,
      user: username,
      db: databaseName,
      password: password,
      timeout: Duration(seconds: 60),
    );

    var connection = await _errorZone.runGuardedAsync(
      () => MySqlConnection.connect(connSettings),
    );

    var connWrapper = _DBMySqlConnectionWrapped(connection, connSettings);

    _connectionFinalizer.attach(connWrapper, connection);

    return connWrapper;
  }

  late final Finalizer<MySqlConnection> _connectionFinalizer = Finalizer(
    _finalizeConnection,
  );

  void _finalizeConnection(MySqlConnection connection) {
    try {
      // ignore: discarded_futures
      connection.close();
    } catch (_) {}
  }

  @override
  bool closeConnection(DBMySqlConnectionWrapper connection) {
    _log.info('closeConnection> $connection');
    try {
      connection.close();
    } catch (_) {}
    return true;
  }

  @override
  bool isPoolElementValid(
    DBMySqlConnectionWrapper o, {
    bool checkUsage = true,
  }) => isConnectionValid(o, checkUsage: checkUsage);

  @override
  FutureOr<bool> isPoolElementInvalid(
    DBMySqlConnectionWrapper o, {
    bool checkUsage = true,
  }) => !isConnectionValid(o, checkUsage: checkUsage);

  @override
  bool isConnectionValid(
    DBMySqlConnectionWrapper connection, {
    bool checkUsage = true,
  }) {
    if (connection.isClosed) return false;

    if (checkUsage && connection.isInactive(connectionInactivityLimit)) {
      return false;
    }

    return true;
  }

  @override
  Future<Map<String, Type>?> getTableFieldsTypesImpl(String table) async {
    var connection = await catchFromPool();

    try {
      _log.info('getTableFieldsTypesImpl> $table');

      var sql = "SHOW COLUMNS FROM `$table`";
      var results = await connection.query(sql);

      var scheme = results.toList();

      await releaseIntoPool(connection);

      if (scheme.isEmpty) return null;

      var fieldsTypes = Map<String, Type>.fromEntries(
        scheme.map((e) {
          var k = e['Field'] as String;
          var v = _toFieldType(e['Type'].toString());
          return MapEntry(k, v);
        }),
      );

      return fieldsTypes;
    } catch (e) {
      await disposePoolElement(connection);
      rethrow;
    }
  }

  @override
  Future<TableScheme?> getTableSchemeImpl(
    String table,
    TableRelationshipReference? relationship, {
    Object? contextID,
  }) async {
    var connection = await catchFromPool();

    try {
      //_log.info('getTableSchemeImpl> $table ; relationship: $relationship');

      var sql = "SHOW COLUMNS FROM `$table`";
      var results = await connection.query(sql);

      var scheme = results.toList();

      if (scheme.isEmpty) {
        await releaseIntoPool(connection);
        return null;
      }

      var idFieldName = _findIDField(connection, table, scheme);

      var fieldsTypes = Map<String, Type>.fromEntries(
        scheme.map((e) {
          var k = e['Field'] as String;
          var v = _toFieldType(e['Type'].toString());
          return MapEntry(k, v);
        }),
      );

      notifyTableFieldTypes(table, fieldsTypes);

      var fieldsReferencedTables = await _findFieldsReferencedTables(
        connection,
        table,
        contextID: contextID,
      );

      var relationshipTables = await _findRelationshipTables(
        connection,
        table,
        idFieldName,
        contextID: contextID,
      );

      await releaseIntoPool(connection);

      var tableScheme = TableScheme(
        table,
        relationship: relationship != null,
        idFieldName: idFieldName,
        fieldsTypes: fieldsTypes,
        fieldsReferencedTables: fieldsReferencedTables,
        relationshipTables: relationshipTables,
      );

      _log.info('$tableScheme');

      return tableScheme;
    } catch (_) {
      await disposePoolElement(connection);
      rethrow;
    }
  }

  String _findIDField(
    DBMySqlConnectionWrapper connection,
    String table,
    List<ResultRow> scheme,
  ) {
    var primaryFields = scheme.where((f) => f['Key'] == 'PRI');

    var primaryFieldsNames =
        primaryFields.map((e) => e['Field'].toString()).toList();

    return selectIDFieldName(table, primaryFieldsNames);
  }

  static final RegExp _regExpSpaces = RegExp(r'\s+');
  static final RegExp _regExpIgnoreWords = RegExp(
    r'unsigned|signed|varying|precision|\(.*?\)',
  );

  Type _toFieldType(String dataType) {
    dataType = dataType.toLowerCase();
    dataType = dataType.replaceAll(_regExpSpaces, ' ');
    dataType = dataType.trim();

    switch (dataType) {
      case 'tinyint(1)':
        return bool;
      default:
        break;
    }

    dataType = dataType.replaceAll(_regExpIgnoreWords, ' ');
    dataType = dataType.replaceAll(_regExpSpaces, ' ');
    dataType = dataType.trim();

    switch (dataType) {
      case 'boolean':
      case 'bool':
        return bool;
      case 'tinyint':
      case 'smallint':
      case 'mediumint':
      case 'int':
      case 'bigint':
      case 'integer':
        return int;
      case 'decimal':
      case 'numeric':
        return Decimal;
      case 'float':
      case 'double':
        return double;
      case 'text':
      case 'char':
      case 'varchar':
      case 'enum':
        return String;
      case 'time':
        return Time;
      case 'timestamp':
      case 'date':
      case 'datetime':
        return DateTime;
      default:
        return String;
    }
  }

  Future<List<TableRelationshipReference>> _findRelationshipTables(
    DBMySqlConnectionWrapper connection,
    String table,
    String idFieldName, {
    Object? contextID,
  }) async {
    var tablesNames = await _listTablesNames(connection, contextID: contextID);

    var tablesReferences = <Map<String, TableFieldReference>>[];

    for (var t in tablesNames) {
      var refs = await _findFieldsReferencedTables(
        connection,
        t,
        contextID: contextID,
      );
      tablesReferences.add(refs);
    }

    tablesReferences =
        tablesReferences.where((m) {
          return m.length > 1 &&
              m.values.where((r) => r.targetTable == table).isNotEmpty &&
              m.values.where((r) => r.targetTable != table).isNotEmpty;
        }).toList();

    var relationships =
        tablesReferences
            .map((e) {
              var refToTables = e.values
                  .where((r) => r.targetTable == table)
                  .toList(growable: false);

              var otherRefs = e.values
                  .where((r) => r.targetTable != table)
                  .toList(growable: false);

              if (refToTables.length != 1 || otherRefs.length != 1) {
                return null;
              }

              var refToTable = refToTables.first;
              var otherRef = otherRefs.first;

              return TableRelationshipReference(
                refToTable.sourceTable,
                refToTable.targetTable,
                refToTable.targetField,
                refToTable.targetFieldType,
                refToTable.sourceField,
                otherRef.targetTable,
                otherRef.targetField,
                otherRef.targetFieldType,
                otherRef.sourceField,
              );
            })
            .nonNulls
            .toList();

    return relationships;
  }

  final Expando<FutureOr<List<String>>> _listTablesNamesContextCache =
      Expando();

  FutureOr<List<String>> _listTablesNames(
    DBMySqlConnectionWrapper connection, {
    Object? contextID,
  }) => _listTablesNamesContextCache.putIfAbsentAsync(
    contextID,
    () => _listTablesNamesImpl(connection),
  );

  Future<List<String>> _listTablesNamesImpl(
    DBMySqlConnectionWrapper connection,
  ) async {
    var sql = '''
    SHOW TABLES
    ''';

    var results = await connection.query(sql);

    var names = results.map((r) => r[0]).map((e) => '$e').toList();

    return names;
  }

  final TimedMap<String, Map<String, TableFieldReference>>
  _findFieldsReferencedTablesCache =
      TimedMap<String, Map<String, TableFieldReference>>(Duration(seconds: 30));

  final Expando<Map<String, FutureOr<Map<String, TableFieldReference>>>>
  _findFieldsReferencedTablesContextCache = Expando();

  FutureOr<Map<String, TableFieldReference>> _findFieldsReferencedTables(
    DBMySqlConnectionWrapper connection,
    String table, {
    Object? contextID,
  }) {
    if (contextID != null) {
      var cache = _findFieldsReferencedTablesContextCache[contextID] ??= {};
      return cache[table] ??= _findFieldsReferencedTablesImpl(
        connection,
        table,
      ).then((ret) {
        cache[table] = ret;
        _findFieldsReferencedTablesCache[table] = ret;
        return ret;
      });
    }

    return _findFieldsReferencedTablesCache.putIfAbsentCheckedAsync(
      table,
      () => _findFieldsReferencedTablesImpl(connection, table),
    );
  }

  Future<Map<String, TableFieldReference>> _findFieldsReferencedTablesImpl(
    DBMySqlConnectionWrapper connection,
    String table,
  ) async {
    var sql = '''
    SELECT 
      CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME,
      REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
    FROM
      INFORMATION_SCHEMA.KEY_COLUMN_USAGE
    WHERE
      TABLE_SCHEMA = '$databaseName' AND TABLE_NAME = '$table' 
      AND REFERENCED_TABLE_NAME IS NOT NULL AND REFERENCED_COLUMN_NAME IS NOT NULL
    ''';

    var results = await connection.query(sql);

    var referenceFields = results.map((r) => r.fields).toList(growable: false);

    var mapEntriesRet =
        referenceFields
            .map((e) {
              var sourceTable = e['TABLE_NAME'];
              var sourceField = e['COLUMN_NAME'];
              var targetTable = e['REFERENCED_TABLE_NAME'];
              var targetField = e['REFERENCED_COLUMN_NAME'];
              if (targetTable == null || targetField == null) return null;

              var sourceFieldsTypesRet = getTableFieldsTypes(table);
              var targetFieldsTypesRet = getTableFieldsTypes(targetTable);

              return sourceFieldsTypesRet.resolveBoth(targetFieldsTypesRet, (
                sourceFieldsTypes,
                targetFieldsTypes,
              ) {
                var sourceFieldType = sourceFieldsTypes?[sourceField] ?? String;
                var targetFieldType = targetFieldsTypes?[targetField] ?? String;

                var reference = TableFieldReference(
                  sourceTable,
                  sourceField,
                  sourceFieldType,
                  targetTable,
                  targetField,
                  targetFieldType,
                );

                return MapEntry<String, TableFieldReference>(
                  sourceField,
                  reference,
                );
              });
            })
            .nonNulls
            .resolveAll();

    return mapEntriesRet.resolveMapped((mapEntries) {
      var map = Map<String, TableFieldReference>.fromEntries(mapEntries);
      return map;
    });
  }

  @override
  String? typeToSQLType(
    TypeInfo type,
    String column, {
    List<EntityField>? entityFieldAnnotations,
    bool isID = false,
  }) {
    if (type.isInt) {
      final min = entityFieldAnnotations?.minimum.firstOrNull;
      final max = entityFieldAnnotations?.maximum.firstOrNull;

      if (min != null || max != null) {
        const intLimits = [
          ('TINYINT', -128, 127),
          ('SMALLINT', -32768, 32767),
          ('MEDIUMINT', -8388608, 8388607),
          ('INT', -2147483648, 2147483647),
          ('BIGINT', -9223372036854775808, 9223372036854775807),
        ];

        for (final (typeName, minLimit, maxLimit) in intLimits) {
          final minOk = min == null || min >= minLimit;
          final maxOk = max == null || max <= maxLimit;

          if (minOk && maxOk) return typeName;
        }
      }

      if (isID) {
        return 'BIGINT';
      }

      return 'INT'; // default: 32-bits integer
    } else if (type.isBigInt) {
      if (isID) {
        return 'BIGINT';
      }

      return 'DECIMAL(65, 0)'; // integers with maximum of 62 digits.
    } else if (type.type == DynamicInt) {
      return 'DECIMAL(65, 0)'; // integers with maximum of 62 digits.
    }

    var sqlType = super.typeToSQLType(
      type,
      column,
      entityFieldAnnotations: entityFieldAnnotations,
      isID: isID,
    );

    if (sqlType == 'VARCHAR') {
      var sz = getVarcharPreferredSize(column);
      return 'VARCHAR($sz)';
    } else if (sqlType == 'DECIMAL') {
      return 'DECIMAL(27,12)';
    }

    return sqlType;
  }

  @override
  String? foreignKeyTypeToSQLType(
    TypeInfo idType,
    String idName, {
    List<EntityField>? entityFieldAnnotations,
  }) {
    var sqlType = super.foreignKeyTypeToSQLType(
      idType,
      idName,
      entityFieldAnnotations: entityFieldAnnotations,
    );

    if (sqlType == 'BIGINT') {
      return '$sqlType UNSIGNED';
    }

    return sqlType;
  }

  @override
  FutureOr<bool> executeTableSQL(String createTableSQL) => executeWithPool(
    (c) => c
        .query(createTableSQL)
        .then(
          (_) => true,
          onError: (e, s) {
            _log.severe("Error executing table SQL:\n$createTableSQL", e, s);
            return false;
          },
        ),
  );

  @override
  FutureOr<int> doCountSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBMySqlConnectionWrapper connection,
  ) {
    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) {
          var count = results.map((r) => r.values?.first).firstOrNull ?? 0;
          return count is int
              ? count
              : int.tryParse(count.toString().trim()) ?? 0;
        });
  }

  @override
  FutureOr<List<I>> doExistIDsSQL<I extends Object>(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBMySqlConnectionWrapper connection,
  ) {
    if (sql.isDummy) return <I>[];

    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) {
          var ids = results
              .map((e) => e.fields)
              .whereType<Map<String, dynamic>>()
              .map((e) => e['id']);

          return parseIDs<I>(ids);
        });
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBMySqlConnectionWrapper connection,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped(_resultsToEntitiesMaps);
  }

  List<Map<String, dynamic>> _resultsToEntitiesMaps(Results? results) {
    if (results == null) return <Map<String, dynamic>>[];
    return results
        .map((e) => e.fields)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBMySqlConnectionWrapper connection,
  ) {
    if (sql.isFullyDummy) return <Map<String, dynamic>>[];

    var preSQLs = sql.preSQL;

    if (preSQLs != null) {
      return _executeSQLs(
        preSQLs,
        connection,
      ).resolveWith(() => _doDeleteSQLImpl(table, sql, connection));
    } else {
      return _doDeleteSQLImpl(table, sql, connection);
    }
  }

  FutureOr<List<Results>> _executeSQLs(
    List<SQL> sql,
    DBMySqlConnectionWrapper connection,
  ) =>
      sql
          .map(
            (e) =>
                connection.query(e.sqlPositional, e.parametersValuesByPosition),
          )
          .resolveAll();

  FutureOr<Iterable<Map<String, dynamic>>> _doDeleteSQLImpl(
    String table,
    SQL sql,
    DBMySqlConnectionWrapper connection,
  ) {
    FutureOr<Results?> sqlRet =
        sql.isDummy
            ? null
            : connection.query(
              sql.sqlPositional,
              sql.parametersValuesByPosition,
            );

    var posSQLs = sql.posSQL;

    if (posSQLs != null) {
      sqlRet = sqlRet.resolveMapped((results) {
        var retPosSQLs = _executeSQLs(posSQLs, connection);
        return retPosSQLs.resolveMapped((posResults) {
          var idx = sql.posSQLReturnIndex;
          return idx != null ? posResults[idx] : results;
        });
      });
    }

    return sqlRet.resolveMapped(_resultsToEntitiesMaps);
  }

  @override
  FutureOr<dynamic> doInsertSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBMySqlConnectionWrapper connection,
  ) {
    if (sql.isDummy) return null;

    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) => _resolveResultID(results, table, sql));
  }

  @override
  FutureOr doUpdateSQL(
    String entityName,
    String table,
    SQL sql,
    Object id,
    Transaction transaction,
    DBMySqlConnectionWrapper connection, {
    bool allowAutoInsert = false,
  }) {
    if (sql.isDummy) return id;

    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) {
          var affectedRows = results.affectedRows ?? 0;
          if (affectedRows == 0) {
            var entry = sql.parametersByPlaceholder;
            if (!allowAutoInsert) {
              throw StateError(
                "Can't update not stored entity into table `$table`: $entry",
              );
            }

            var fields = sql.namedParameters!;

            return generateInsertSQL(
              transaction,
              entityName,
              table,
              fields,
            ).resolveMapped((insertSQL) {
              _log.info(
                'Update not affecting any row! Auto inserting: $insertSQL',
              );
              return doInsertSQL(
                entityName,
                table,
                insertSQL,
                transaction,
                connection,
              );
            });
          }

          return _resolveResultID(results, table, sql, id);
        });
  }

  _resolveResultID(Results results, String table, SQL sql, [Object? entityId]) {
    if (entityId != null && (results.affectedRows ?? 0) > 0) {
      return entityId;
    }

    var insertId = results.insertId;

    if (insertId != null) {
      return insertId;
    }

    if (results.isEmpty) {
      return null;
    }

    var returning = results.firstOrNull;

    if (returning == null || returning.isEmpty) {
      return null;
    } else if (returning.length == 1) {
      var id = returning.values!.first;
      return id;
    } else {
      var idFieldName = sql.idFieldName;

      if (idFieldName != null) {
        var id = returning[idFieldName];
        return id;
      } else {
        var id = returning.values!.first;
        return id;
      }
    }
  }

  @override
  Object resolveError(
    Object error,
    StackTrace stackTrace,
    Object? operation,
    Object? previousError,
  ) {
    if (error is DBMySQLAdapterException) {
      return error;
    } else if (error is MySqlException) {
      if (error.errorNumber == 1062) {
        var keyMatch = RegExp(
          r"for key '(?:(\w+)\.(.*?)|(.*?))'",
        ).firstMatch(error.message);

        String? tableName;
        String? fieldName;

        if (keyMatch != null) {
          var mTable = keyMatch[1];
          var mField = keyMatch[2];
          var mKey = keyMatch[3];

          if (mTable != null) {
            tableName = mTable;
          }

          fieldName = mField ?? mKey;
        }

        return EntityFieldInvalid(
          "unique",
          error.message,
          tableName: tableName,
          fieldName: fieldName,
          parentError: error,
          parentStackTrace: stackTrace,
          previousError: previousError,
        );
      }
    }

    return DBMySQLAdapterException(
      'error',
      '$error',
      parentError: error,
      parentStackTrace: stackTrace,
      previousError: previousError,
      operation: operation,
    );
  }

  @override
  Future<DBMySqlConnectionWrapper> openTransaction(Transaction transaction) {
    var contextCompleter = Completer<DBMySqlConnectionWrapper>();

    var result = executeWithPool(
      (connection) {
        return connection.openTransaction((transactionWrap) {
          contextCompleter.complete(transactionWrap);

          return transaction.transactionFuture.then(
            (res) => resolveTransactionResult(res, transaction, connection),
            onError: (e, s) {
              cancelTransaction(transaction, connection, e, s);
              throw e;
            },
          );
        });
      },
      validator: (c) => !transaction.isAborted,
      onError:
          (e, s) => transaction.notifyExecutionError(
            e,
            s,
            errorResolver: resolveError,
            debugInfo:
                () => transaction.toString(withExecutedOperations: false),
          ),
    );

    transaction.transactionResult = result;

    return contextCompleter.future;
  }

  @override
  bool get cancelTransactionResultWithError => false;

  @override
  bool get throwTransactionResultWithError => true;

  @override
  bool cancelTransaction(
    Transaction transaction,
    DBMySqlConnectionWrapper? connection,
    Object? error,
    StackTrace? stackTrace,
  ) {
    return true;
  }

  @override
  bool get callCloseTransactionRequired => false;

  @override
  FutureOr<void> closeTransaction(
    Transaction transaction,
    DBMySqlConnectionWrapper? connection,
  ) {}

  @override
  String toString() {
    var closedStr = isClosed ? ', closed' : '';
    return 'DBMySQLAdapter#$instanceID{$databaseName@$host:$port$closedStr}';
  }
}

/// A [DBMySQLAdapter] connection wrapper.
abstract class DBMySqlConnectionWrapper
    extends DBConnectionWrapper<MySqlConnection> {
  DBMySqlConnectionWrapper(super.nativeConnection);

  Future<Results> query(String sql, [List<Object?>? values]);

  Future<List<Results>> queryMulti(String sql, Iterable<List<Object?>> values);

  Future openTransaction(
    Future Function(DBMySqlConnectionWrapper connectionTransaction) queryBlock,
  );

  @override
  bool isClosedImpl() => _nativeClose;

  bool _nativeClose = false;

  @override
  void closeImpl() {
    _nativeClose = true;
    try {
      // ignore: discarded_futures
      nativeConnection.close();
    } catch (_) {}
  }
}

class _DBMySqlConnectionWrapped extends DBMySqlConnectionWrapper {
  final ConnectionSettings _connectionSettings;

  _DBMySqlConnectionWrapped(super.nativeConnection, this._connectionSettings);

  @override
  String get connectionURL {
    var settings = _connectionSettings;
    return 'mysql://${settings.user}@${settings.host}:${settings.port}/${settings.db}';
  }

  @override
  Future<Results> query(String sql, [List<Object?>? values]) {
    updateLastAccessTime();
    return nativeConnection.query(sql, values?.cast<Object?>());
  }

  @override
  Future<List<Results>> queryMulti(String sql, Iterable<List<Object?>> values) {
    updateLastAccessTime();
    return nativeConnection.queryMulti(
      sql,
      values.map((e) => e.cast<Object?>()),
    );
  }

  @override
  Future openTransaction(
    Future Function(_DBMySqlConnectionTransaction connectionTransaction)
    queryBlock,
  ) {
    updateLastAccessTime();
    return nativeConnection.transaction(
      (t) => queryBlock(_DBMySqlConnectionTransaction(this, t)),
    );
  }

  @override
  String get runtimeTypeNameSafe => '_DBMySqlConnectionWrapped';
}

class _DBMySqlConnectionTransaction extends DBMySqlConnectionWrapper {
  final _DBMySqlConnectionWrapped parent;
  final TransactionContext transaction;

  _DBMySqlConnectionTransaction(this.parent, this.transaction)
    : super(parent.nativeConnection);

  @override
  String get connectionURL => parent.connectionURL;

  @override
  Future<Results> query(String sql, [List<Object?>? values]) =>
      transaction.query(sql, values?.cast<Object?>());

  @override
  Future<List<Results>> queryMulti(
    String sql,
    Iterable<List<Object?>> values,
  ) => transaction.queryMulti(sql, values.map((e) => e.cast<Object?>()));

  @override
  String get runtimeTypeNameSafe => '_DBMySqlConnectionTransaction';

  @override
  Future openTransaction(
    Future Function(DBMySqlConnectionWrapper connectionTransaction) queryBlock,
  ) => queryBlock(this);
}

/// Exception thrown by [DBMySQLAdapter] operations.
class DBMySQLAdapterException extends DBSQLAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBMySQLAdapterException';

  DBMySQLAdapterException(
    super.type,
    super.message, {
    super.parentError,
    super.parentStackTrace,
    super.operation,
    super.previousError,
  });
}

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mysql1/mysql1.dart';
import 'package:statistics/statistics.dart' show Decimal;

import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';
import 'bones_api_entity_adapter_sql.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_error_zone.dart';
import 'bones_api_extension.dart';
import 'bones_api_initializable.dart';
import 'bones_api_utils_timedmap.dart';

final _log = logging.Logger('MySQLAdapter');

/// A MySQL adapter.
class MySQLAdapter extends SQLAdapter<MySqlConnectionWrapper> {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    Transaction.registerErrorFilter((e, s) => e is MySqlException);

    SQLAdapter.registerAdapter(['mysql'], MySQLAdapter, _instantiate);
  }

  static FutureOr<MySQLAdapter?> _instantiate(config,
      {int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider}) {
    try {
      return MySQLAdapter.fromConfig(config,
          minConnections: minConnections,
          maxConnections: maxConnections,
          parentRepositoryProvider: parentRepositoryProvider);
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

  MySQLAdapter(this.databaseName, this.username,
      {String? host = 'localhost',
      Object? password,
      PasswordProvider? passwordProvider,
      int? port = 3306,
      int minConnections = 1,
      int maxConnections = 3,
      bool generateTables = false,
      Object? populateTables,
      Object? populateSource,
      EntityRepositoryProvider? parentRepositoryProvider})
      : host = host ?? 'localhost',
        port = port ?? 3306,
        _password = (password != null && password is! PasswordProvider
            ? password.toString()
            : null),
        _passwordProvider = passwordProvider ??
            (password is PasswordProvider ? password : null),
        super(
          minConnections,
          maxConnections,
          const SQLAdapterCapability(
              dialect: 'MySQL',
              transactions: true,
              transactionAbort: true,
              tableSQL: false),
          generateTables: generateTables,
          populateTables: populateTables,
          populateSource: populateSource,
          parentRepositoryProvider: parentRepositoryProvider,
        ) {
    boot();

    if (_password == null && _passwordProvider == null) {
      throw ArgumentError("No `password` or `passwordProvider` ");
    }

    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  factory MySQLAdapter.fromConfig(Map<String, dynamic>? config,
      {String? defaultDatabase,
      String? defaultUsername,
      String? defaultHost,
      int? defaultPort,
      int? minConnections,
      int? maxConnections,
      EntityRepositoryProvider? parentRepositoryProvider}) {
    boot();

    var host = config?['host'] ?? defaultHost;
    var port = config?['port'] ?? defaultPort;
    var database = config?['database'] ?? config?['db'] ?? defaultDatabase;
    var username = config?['username'] ?? config?['user'] ?? defaultUsername;
    var password = config?['password'] ?? config?['pass'];

    minConnections ??= config?['minConnections'] ?? 1;
    maxConnections ??= config?['maxConnections'] ?? 3;

    var populate = config?['populate'];

    var generateTables = false;
    Object? populateTables;
    Object? populateSource;

    if (populate is Map) {
      generateTables = populate.getAsBool('generateTables', ignoreCase: true) ??
          populate.getAsBool('generate-tables', ignoreCase: true) ??
          populate.getAsBool('generate_tables', ignoreCase: true) ??
          false;

      populateTables = populate['tables'];
      populateSource = populate['source'];
    }

    return MySQLAdapter(
      database,
      username,
      password: password,
      host: host,
      port: port,
      minConnections: minConnections!,
      maxConnections: maxConnections!,
      generateTables: generateTables,
      populateTables: populateTables,
      populateSource: populateSource,
      parentRepositoryProvider: parentRepositoryProvider,
    );
  }

  FutureOr<String> _getPassword() {
    if (_password != null) {
      return _password!;
    } else {
      return _passwordProvider!(username);
    }
  }

  @override
  List<Initializable> initializeDependencies() {
    var parentRepositoryProvider = this.parentRepositoryProvider;
    return <Initializable>[
      if (parentRepositoryProvider != null) parentRepositoryProvider
    ];
  }

  @override
  String get sqlElementQuote => '`';

  @override
  bool get sqlAcceptsOutputSyntax => false;

  @override
  bool get sqlAcceptsReturningSyntax => false;

  @override
  bool get sqlAcceptsTemporaryTableForReturning => true;

  @override
  bool get sqlAcceptsInsertDefaultValues => false;

  @override
  bool get sqlAcceptsInsertIgnore => true;

  @override
  bool get sqlAcceptsInsertOnConflict => false;

  @override
  String getConnectionURL(MySqlConnectionWrapper connection) {
    return 'mysql://$username@$host:$port/$databaseName';
  }

  Zone? _errorZoneInstance;

  Zone get _errorZone {
    return _errorZoneInstance ??=
        createErrorZone(uncaughtErrorTitle: 'MySQLAdapter ERROR:');
  }

  int _connectionCount = 0;

  @override
  FutureOr<MySqlConnectionWrapper> createConnection() async {
    var password = await _getPassword();

    var count = ++_connectionCount;

    var connSettings = ConnectionSettings(
      host: host,
      port: port,
      user: username,
      db: databaseName,
      password: password,
      timeout: Duration(seconds: 60),
    );

    var connection = await _errorZone
        .runGuardedAsync(() => MySqlConnection.connect(connSettings));

    var connWrapper = _MySqlConnectionWrapped(connection);

    var connUrl = getConnectionURL(connWrapper);

    _log.info('createConnection[$count]> $connUrl > $connection');

    return connWrapper;
  }

  @override
  FutureOr<bool> closeConnection(MySqlConnectionWrapper connection) {
    _log.info('closeConnection> $connection');

    connection.connection.close();

    return true;
  }

  @override
  FutureOr<bool> isConnectionValid(MySqlConnectionWrapper connection) {
    return true;
  }

  @override
  Future<Map<String, Type>?> getTableFieldsTypesImpl(String table) async {
    var connection = await catchFromPool();

    _log.info('getTableFieldsTypesImpl> $table');

    var sql = "SHOW COLUMNS FROM `$table`";

    var results = await connection.query(sql);

    if (results.isEmpty) return null;

    var scheme = results;

    if (scheme.isEmpty) return null;

    var fieldsTypes = Map<String, Type>.fromEntries(scheme.map((e) {
      var k = e['Field'] as String;
      var v = _toFieldType(e['Type'].toString());
      return MapEntry(k, v);
    }));

    return fieldsTypes;
  }

  @override
  Future<TableScheme?> getTableSchemeImpl(
      String table, TableRelationshipReference? relationship) async {
    var connection = await catchFromPool();

    _log.info('getTableSchemeImpl> $table ; relationship: $relationship');

    var sql = "SHOW COLUMNS FROM `$table`";

    var results = await connection.query(sql);

    if (results.isEmpty) return null;

    var scheme = results;

    if (scheme.isEmpty) return null;

    var idFieldName = await _findIDField(connection, table, scheme);

    var fieldsTypes = Map<String, Type>.fromEntries(scheme.map((e) {
      var k = e['Field'] as String;
      var v = _toFieldType(e['Type'].toString());
      return MapEntry(k, v);
    }));

    notifyTableFieldTypes(table, fieldsTypes);

    var fieldsReferencedTables =
        await _findFieldsReferencedTables(connection, table);

    var relationshipTables =
        await _findRelationshipTables(connection, table, idFieldName);

    await releaseIntoPool(connection);

    var tableScheme = TableScheme(table,
        relationship: relationship != null,
        idFieldName: idFieldName,
        fieldsTypes: fieldsTypes,
        fieldsReferencedTables: fieldsReferencedTables,
        relationshipTables: relationshipTables);

    _log.info('$tableScheme');

    return tableScheme;
  }

  FutureOr<String> _findIDField(
      MySqlConnectionWrapper connection, String table, Results scheme) async {
    var field = scheme.firstWhereOrNull((f) => f['Key'] == 'PRI');
    var name = field?['Field'] ?? 'id';

    return name;
  }

  static final RegExp _regExpSpaces = RegExp(r'\s+');
  static final RegExp _regExpIgnoreWords =
      RegExp(r'unsigned|signed|varying|precision|\(.*?\)');

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
      case 'timestamp':
      case 'date':
      case 'time':
      case 'datetime':
        return DateTime;
      default:
        return String;
    }
  }

  Future<List<TableRelationshipReference>> _findRelationshipTables(
      MySqlConnectionWrapper connection,
      String table,
      String idFieldName) async {
    var tablesNames = await _listTablesNames(connection);

    var tablesReferences = await tablesNames
        .map((t) => _findFieldsReferencedTables(connection, t))
        .resolveAll();

    tablesReferences = tablesReferences.where((m) {
      return m.length > 1 &&
          m.values.where((r) => r.targetTable == table).isNotEmpty &&
          m.values.where((r) => r.targetTable != table).isNotEmpty;
    }).toList();

    var relationships = tablesReferences
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
        .whereNotNull()
        .toList();

    return relationships;
  }

  Future<List<String>> _listTablesNames(
      MySqlConnectionWrapper connection) async {
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

  FutureOr<Map<String, TableFieldReference>> _findFieldsReferencedTables(
      MySqlConnectionWrapper connection, String table) {
    var prev = _findFieldsReferencedTablesCache[table];
    if (prev != null) return prev;

    var referencedTablesRet =
        _findFieldsReferencedTablesImpl(connection, table);

    return referencedTablesRet.resolveMapped((referencedTables) {
      _findFieldsReferencedTablesCache[table] = referencedTables;
      return referencedTables;
    });
  }

  Future<Map<String, TableFieldReference>> _findFieldsReferencedTablesImpl(
      MySqlConnectionWrapper connection, String table) async {
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

    var mapEntriesRet = referenceFields
        .map((e) {
          var sourceTable = e['TABLE_NAME'];
          var sourceField = e['COLUMN_NAME'];
          var targetTable = e['REFERENCED_TABLE_NAME'];
          var targetField = e['REFERENCED_COLUMN_NAME'];
          if (targetTable == null || targetField == null) return null;

          var sourceFieldsTypesRet = getTableFieldsTypes(table);
          var targetFieldsTypesRet = getTableFieldsTypes(targetTable);

          return sourceFieldsTypesRet.resolveBoth(targetFieldsTypesRet,
              (sourceFieldsTypes, targetFieldsTypes) {
            var sourceFieldType = sourceFieldsTypes?[sourceField] ?? String;
            var targetFieldType = targetFieldsTypes?[targetField] ?? String;

            var reference = TableFieldReference(sourceTable, sourceField,
                sourceFieldType, targetTable, targetField, targetFieldType);

            return MapEntry<String, TableFieldReference>(
                sourceField, reference);
          });
        })
        .whereNotNull()
        .resolveAll();

    return mapEntriesRet.resolveMapped((mapEntries) {
      var map = Map<String, TableFieldReference>.fromEntries(mapEntries);
      return map;
    });
  }

  @override
  String? typeToSQLType(Type type, String column,
      {List<EntityField>? entityFieldAnnotations}) {
    var sqlType = super.typeToSQLType(type, column,
        entityFieldAnnotations: entityFieldAnnotations);

    if (sqlType == 'VARCHAR') {
      var sz = getVarcharPreferredSize(column);
      return 'VARCHAR($sz)';
    } else if (sqlType == 'DECIMAL') {
      return 'DECIMAL(27,12)';
    }

    return sqlType;
  }

  @override
  String? foreignKeyTypeToSQLType(Type idType, String idName,
      {List<EntityField>? entityFieldAnnotations}) {
    var sqlType = super.foreignKeyTypeToSQLType(idType, idName,
        entityFieldAnnotations: entityFieldAnnotations);

    if (sqlType == 'BIGINT') {
      return '$sqlType UNSIGNED';
    }

    return sqlType;
  }

  @override
  FutureOr<bool> executeTableSQL(String createTableSQL) => executeWithPool(
      (c) => c.query(createTableSQL).then((_) => true, onError: (e, s) {
            _log.severe("Error executing table SQL:\n$createTableSQL", e, s);
            return false;
          }));

  @override
  FutureOr<int> doCountSQL(String entityName, String table, SQL sql,
      Transaction transaction, MySqlConnectionWrapper connection) {
    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) {
      var count = results.map((r) => r.values?.first).firstOrNull ?? 0;
      return count is int ? count : int.tryParse(count.toString().trim()) ?? 0;
    });
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
      String entityName,
      String table,
      SQL sql,
      Transaction transaction,
      MySqlConnectionWrapper connection) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped(_resultsToEntitiesMaps);
  }

  List<Map<String, dynamic>> _resultsToEntitiesMaps(Results results) =>
      results.map((e) => e.fields).whereType<Map<String, dynamic>>().toList();

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
      String entityName,
      String table,
      SQL sql,
      Transaction transaction,
      MySqlConnectionWrapper connection) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    var preSQLs = sql.preSQL;

    if (preSQLs != null) {
      return _executeSQLs(preSQLs, connection)
          .resolveWith(() => _doDeleteSQLImpl(table, sql, connection));
    } else {
      return _doDeleteSQLImpl(table, sql, connection);
    }
  }

  FutureOr<List<Results>> _executeSQLs(
          List<SQL> sql, MySqlConnectionWrapper connection) =>
      sql
          .map((e) =>
              connection.query(e.sqlPositional, e.parametersValuesByPosition))
          .resolveAll();

  FutureOr<Iterable<Map<String, dynamic>>> _doDeleteSQLImpl(
      String table, SQL sql, MySqlConnectionWrapper connection) {
    FutureOr<Results> sqlRet =
        connection.query(sql.sqlPositional, sql.parametersValuesByPosition);

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
  FutureOr<dynamic> doInsertSQL(String entityName, String table, SQL sql,
      Transaction transaction, MySqlConnectionWrapper connection) {
    if (sql.isDummy) return null;

    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) => _resolveResultID(results, table, sql));
  }

  @override
  FutureOr doUpdateSQL(String entityName, String table, SQL sql, Object id,
      Transaction transaction, MySqlConnectionWrapper connection,
      {bool allowAutoInsert = false}) {
    if (sql.isDummy) return null;

    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) {
      if ((results.affectedRows ?? 0) == 0) {
        var entry = sql.parametersByPlaceholder;
        if (!allowAutoInsert) {
          throw StateError(
              "Can't update not stored entity into table `$table`: $entry");
        }

        var fields = sql.namedParameters!;

        return generateInsertSQL(transaction, entityName, table, fields)
            .resolveMapped((insertSQL) {
          _log.info('Update not affecting any row! Auto inserting: $insertSQL');
          return doInsertSQL(
              entityName, table, insertSQL, transaction, connection);
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
  Object? errorResolver(Object? error, StackTrace? stackTrace) {
    if (error is MySqlException) {
      if (error.errorNumber == 1062) {
        var keyMatch = RegExp(r"for key '(?:(\w+)\.(.*?)|(.*?))'")
            .firstMatch(error.message);

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

        throw EntityFieldInvalid("unique", error.message,
            tableName: tableName, fieldName: fieldName, parentError: error);
      }
    }
    return error;
  }

  @override
  FutureOr<MySqlConnectionWrapper> openTransaction(Transaction transaction) {
    var contextCompleter = Completer<MySqlConnectionWrapper>();

    var result = executeWithPool(
      (connection) {
        return connection.connection.transaction((t) {
          var transactionWrap =
              _MySqlConnectionTransaction(connection.connection, t);
          contextCompleter.complete(transactionWrap);

          return transaction.transactionFuture.catchError((e, s) {
            cancelTransaction(transaction, connection, e, s);
            throw e;
          });
        });
      },
      validator: (c) => !transaction.isAborted,
    );

    transaction.transactionResult = result;

    return contextCompleter.future;
  }

  @override
  bool cancelTransaction(
      Transaction transaction,
      MySqlConnectionWrapper connection,
      Object? error,
      StackTrace? stackTrace) {
    return true;
  }

  @override
  bool get callCloseTransactionRequired => false;

  @override
  FutureOr<void> closeTransaction(
      Transaction transaction, MySqlConnectionWrapper? connection) {}
}

abstract class MySqlConnectionWrapper {
  MySqlConnection get connection;

  Future<Results> query(String sql, [List<Object?>? values]);

  Future<List<Results>> queryMulti(String sql, Iterable<List<Object?>> values);
}

class _MySqlConnectionWrapped implements MySqlConnectionWrapper {
  @override
  final MySqlConnection connection;

  _MySqlConnectionWrapped(this.connection);

  @override
  Future<Results> query(String sql, [List<Object?>? values]) =>
      connection.query(sql, values?.cast<Object?>());

  @override
  Future<List<Results>> queryMulti(
          String sql, Iterable<List<Object?>> values) =>
      connection.queryMulti(sql, values.map((e) => e.cast<Object?>()));
}

class _MySqlConnectionTransaction implements MySqlConnectionWrapper {
  @override
  final MySqlConnection connection;

  final TransactionContext transaction;

  _MySqlConnectionTransaction(this.connection, this.transaction);

  @override
  Future<Results> query(String sql, [List<Object?>? values]) =>
      transaction.query(sql, values?.cast<Object?>());

  @override
  Future<List<Results>> queryMulti(
          String sql, Iterable<List<Object?>> values) =>
      transaction.queryMulti(sql, values.map((e) => e.cast<Object?>()));
}

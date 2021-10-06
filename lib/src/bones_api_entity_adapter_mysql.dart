import 'dart:async';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mysql1/mysql1.dart';

import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';
import 'bones_api_utils.dart';

final _log = logging.Logger('MySQLAdapter');

/// A PostgreSQL adapter.
class MySQLAdapter extends SQLAdapter<MySqlConnectionWrapper> {
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
      EntityRepositoryProvider? parentRepositoryProvider})
      : host = host ?? 'localhost',
        port = port ?? 3306,
        _password = (password != null && password is! PasswordProvider
            ? password.toString()
            : null),
        _passwordProvider = passwordProvider ??
            (password is PasswordProvider ? password : null),
        super(minConnections, maxConnections, 'postgre',
            parentRepositoryProvider: parentRepositoryProvider) {
    if (_password == null && _passwordProvider == null) {
      throw ArgumentError("No `password` or `passwordProvider` ");
    }

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  factory MySQLAdapter.fromConfig(Map<String, dynamic> config,
      {String? defaultDatabase,
      String? defaultUsername,
      String? defaultHost,
      int? defaultPort,
      int minConnections = 1,
      int maxConnections = 3,
      EntityRepositoryProvider? parentRepositoryProvider}) {
    var host = config['host'] ?? defaultHost;
    var port = config['port'] ?? defaultPort;
    var database = config['database'] ?? config['db'] ?? defaultDatabase;
    var username = config['username'] ?? config['user'] ?? defaultUsername;
    var password = config['password'] ?? config['pass'];

    return MySQLAdapter(
      database,
      username,
      password: password,
      host: host,
      port: port,
      minConnections: minConnections,
      maxConnections: maxConnections,
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
  String get sqlElementQuote => '';

  @override
  bool get sqlAcceptsOutputSyntax => false;

  @override
  bool get sqlAcceptsReturningSyntax => false;

  @override
  bool get sqlAcceptsTemporaryTableForReturning => true;

  @override
  bool get sqlAcceptsInsertIgnore => true;

  @override
  bool get sqlAcceptsInsertOnConflict => false;

  @override
  String getConnectionURL(MySqlConnectionWrapper connection) {
    return 'mysql://$username@$host:$port/$databaseName';
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

    var connection = await MySqlConnection.connect(connSettings);

    var connWrapper = _MySqlConnectionWrapped(connection);

    var connUrl = getConnectionURL(connWrapper);

    _log.log(
        logging.Level.INFO, 'createConnection[$count]> $connUrl > $connection');

    return connWrapper;
  }

  @override
  FutureOr<bool> closeConnection(MySqlConnectionWrapper connection) {
    _log.log(logging.Level.INFO, 'closeConnection> $connection');

    connection.connection.close();

    return true;
  }

  @override
  FutureOr<bool> isConnectionValid(MySqlConnectionWrapper connection) {
    return true;
  }

  @override
  Future<TableScheme?> getTableSchemeImpl(String table) async {
    var connection = await catchFromPool();

    _log.log(logging.Level.INFO, 'getTableSchemeImpl> $table');

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

    var fieldsReferencedTables =
        await _findFieldsReferencedTables(connection, table);

    var relationshipTables =
        await _findRelationshipTables(connection, table, idFieldName);

    await releaseIntoPool(connection);

    var tableScheme = TableScheme(table, idFieldName, fieldsTypes,
        fieldsReferencedTables, relationshipTables);

    _log.log(logging.Level.INFO, '$tableScheme');

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
      RegExp(r'(?:unsigned|signed|varying|precision|\(.*?\))');

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

    var relationships = tablesReferences.map((e) {
      var refToTable = e.values.where((r) => r.targetTable == table).first;
      var otherRef = e.values.where((r) => r.targetTable != table).first;
      return TableRelationshipReference(
        refToTable.sourceTable,
        refToTable.targetTable,
        refToTable.targetField,
        refToTable.sourceField,
        otherRef.targetTable,
        otherRef.targetField,
        otherRef.sourceField,
      );
    }).toList();

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
          MySqlConnectionWrapper connection, String table) =>
      _findFieldsReferencedTablesCache.putIfAbsentCheckedAsync(
          table, () => _findFieldsReferencedTablesImpl(connection, table));

  Future<Map<String, TableFieldReference>> _findFieldsReferencedTablesImpl(
      MySqlConnectionWrapper connection, String table) async {
    var sql = '''
    SELECT 
      CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
    FROM
      INFORMATION_SCHEMA.KEY_COLUMN_USAGE
    WHERE
      TABLE_SCHEMA = '$databaseName' AND TABLE_NAME = '$table' 
      AND REFERENCED_TABLE_NAME IS NOT NULL AND REFERENCED_COLUMN_NAME IS NOT NULL
    ''';

    var results = await connection.query(sql);

    var referenceFields = results.map((r) => r.fields).toList(growable: false);

    var map =
        Map<String, TableFieldReference>.fromEntries(referenceFields.map((e) {
      var sourceTable = e['TABLE_NAME'];
      var sourceField = e['COLUMN_NAME'];
      var targetTable = e['REFERENCED_TABLE_NAME'];
      var targetField = e['REFERENCED_COLUMN_NAME'];
      if (targetTable == null || targetField == null) return null;

      var reference = TableFieldReference(
          sourceTable, sourceField, targetTable, targetField);
      return MapEntry<String, TableFieldReference>(sourceField, reference);
    }).whereNotNull());

    return map;
  }

  @override
  FutureOr<int> doCountSQL(
      String table, SQL sql, MySqlConnectionWrapper connection) {
    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) {
      var count = results.map((r) => r.values?.first).firstOrNull ?? 0;
      return count is int ? count : int.tryParse(count.toString().trim()) ?? 0;
    });
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
      String table, SQL sql, MySqlConnectionWrapper connection) {
    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped(_resultsToEntitiesMaps);
  }

  List<Map<String, dynamic>> _resultsToEntitiesMaps(Results results) =>
      results.map((e) => e.fields).whereType<Map<String, dynamic>>().toList();

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
      String table, SQL sql, MySqlConnectionWrapper connection) {
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
  FutureOr<dynamic> doInsertSQL(
      String table, SQL sql, MySqlConnectionWrapper connection) {
    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) => _resolveResultID(results, table, sql));
  }

  @override
  FutureOr doUpdateSQL(
      String table, SQL sql, Object id, MySqlConnectionWrapper connection) {
    return connection
        .query(sql.sqlPositional, sql.parametersValuesByPosition)
        .resolveMapped((results) => _resolveResultID(results, table, sql, id));
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
  FutureOr<R> executeTransactionOperation<R>(TransactionOperation op,
      SQLWrapper sql, TransactionExecution<R, MySqlConnectionWrapper> f) {
    var transaction = op.transaction;

    if (transaction.length == 1 &&
        sql.sqlsLength == 1 &&
        !sql.mainSQL.hasPreOrPosSQL) {
      return executeWithPool((connection) => f(connection));
    }

    if (!transaction.isOpen && !transaction.isOpening) {
      _openTransaction(transaction);
    }

    return transaction.onOpen<R>(() {
      return transaction.addExecution<R, MySqlConnectionWrapper>((c) => f(c));
    });
  }

  void _openTransaction(Transaction transaction) {
    transaction.open(() {
      var contextCompleter = Completer<MySqlConnectionWrapper>();

      var ret = executeWithPool((connection) {
        return connection.connection.transaction((t) {
          var transactionWrap =
              _MySqlConnectionTransaction(connection.connection, t);
          contextCompleter.complete(transactionWrap);
          return transaction.transactionFuture;
        });
      });

      transaction.transactionResult = ret;

      return contextCompleter.future;
    });
  }
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
      connection.query(sql, values);

  @override
  Future<List<Results>> queryMulti(
          String sql, Iterable<List<Object?>> values) =>
      connection.queryMulti(sql, values);
}

class _MySqlConnectionTransaction implements MySqlConnectionWrapper {
  @override
  final MySqlConnection connection;

  final dynamic transaction;

  _MySqlConnectionTransaction(this.connection, this.transaction);

  @override
  Future<Results> query(String sql, [List<Object?>? values]) =>
      transaction.query(sql, values?.cast<Object>());

  @override
  Future<List<Results>> queryMulti(
          String sql, Iterable<List<Object?>> values) =>
      transaction.queryMulti(sql, values.map((e) => e.cast<Object>()));
}

import 'dart:async';

import 'package:async_extension/async_extension.dart';
import 'package:bones_api/src/bones_api_condition_encoder.dart';
import 'package:logging/logging.dart' as logging;
import 'package:postgres/postgres.dart';

import 'bones_api_entity.dart';
import 'bones_api_entity_adapter.dart';

final _log = logging.Logger('PostgreAdapter');

/// A PostgreSQL adapter.
class PostgreSQLAdapter extends SQLAdapter<PostgreSQLConnection> {
  final String host;
  final int port;
  final String databaseName;

  final String username;

  final String? _password;
  final PasswordProvider? _passwordProvider;

  PostgreSQLAdapter(this.databaseName, this.username,
      {String? host = 'localhost',
      Object? password,
      PasswordProvider? passwordProvider,
      int? port = 5432,
      int minConnections = 1,
      int maxConnections = 3,
      EntityRepositoryProvider? parentRepositoryProvider})
      : host = host ?? 'localhost',
        port = port ?? 5432,
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

  factory PostgreSQLAdapter.fromConfig(Map<String, dynamic> config,
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

    return PostgreSQLAdapter(
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
  String getConnectionURL(PostgreSQLConnection connection) {
    return 'postgresql://${connection.username}@${connection.host}:${connection.port}/${connection.databaseName}';
  }

  @override
  FutureOr<PostgreSQLConnection> createConnection() async {
    var password = await _getPassword();

    var connection = PostgreSQLConnection(host, port, databaseName,
        username: username, password: password);
    await connection.open();

    var connUrl = getConnectionURL(connection);

    _log.log(logging.Level.INFO, 'createConnection> $connUrl > $connection');

    return connection;
  }

  @override
  FutureOr<bool> isConnectionValid(PostgreSQLConnection connection) {
    if (connection.isClosed) {
      return false;
    }
    return true;
  }

  @override
  Future<TableScheme?> getTableSchemeImpl(String table) async {
    var connection = await catchFromPool();

    _log.log(logging.Level.INFO, 'getTableSchemeImpl> $table');

    var sql =
        "SELECT column_name, data_type, column_default, is_updatable FROM information_schema.columns WHERE table_name = '$table'";

    var results = await connection.mappedResultsQuery(sql);

    if (results.isEmpty) return null;

    var scheme = results.map((e) => e['']!).toList();

    if (scheme.isEmpty) return null;

    var idFieldName = _findIDField(scheme);

    var fieldsTypes = Map<String, Type>.fromEntries(scheme.map((e) {
      var k = e['column_name'] as String;
      var v = _toFieldType(e['data_type'] as String);
      return MapEntry(k, v);
    }));

    var fieldsNames = fieldsTypes.keys.toList();

    var fieldsReferencedTables =
        await _findFieldsReferencedTables(connection, table, fieldsNames);

    await releaseIntoPool(connection);

    var tableScheme =
        TableScheme(table, idFieldName, fieldsTypes, fieldsReferencedTables);

    _log.log(logging.Level.INFO, '$tableScheme');

    return tableScheme;
  }

  String _findIDField(List<Map<String, dynamic>> scheme) {
    return 'id';
  }

  Type _toFieldType(String dataType) {
    dataType = dataType.toLowerCase().trim();

    switch (dataType) {
      case 'integer':
        return int;
      case 'text':
        return String;
      default:
        return String;
    }
  }

  Future<Map<String, TableFieldReference>> _findFieldsReferencedTables(
      PostgreSQLConnection connection,
      String table,
      List<String> fieldsNames) async {
    var sql = '''
    SELECT
      o.conname AS constraint_name,
      (SELECT nspname FROM pg_namespace WHERE oid=m.relnamespace) AS source_schema,
      m.relname AS source_table,
      (SELECT a.attname FROM pg_attribute a WHERE a.attrelid = m.oid AND a.attnum = o.conkey[1] AND a.attisdropped = false) AS source_column,
      (SELECT nspname FROM pg_namespace WHERE oid=f.relnamespace) AS target_schema,
      f.relname AS target_table,
      (SELECT a.attname FROM pg_attribute a WHERE a.attrelid = f.oid AND a.attnum = o.confkey[1] AND a.attisdropped = false) AS target_column
    FROM
      pg_constraint o LEFT JOIN pg_class f ON f.oid = o.confrelid LEFT JOIN pg_class m ON m.oid = o.conrelid
    WHERE
      o.contype = 'f' AND m.relname = '$table' AND o.conrelid IN (SELECT oid FROM pg_class c WHERE c.relkind = 'r') 
    ''';

    var results = await connection.mappedResultsQuery(sql);

    var referenceFields = results.map((r) {
      return Map.fromEntries(r.values.expand((e) => e.entries));
    }).toList();

    var map =
        Map<String, TableFieldReference>.fromEntries(referenceFields.map((e) {
      var sourceTable = e['source_table'];
      var sourceField = e['source_column'];
      var targetTable = e['target_table'];
      var targetField = e['target_column'];
      return MapEntry(
          sourceField,
          TableFieldReference(
              sourceTable, sourceField, targetTable, targetField));
    }));

    return map;
  }

  @override
  FutureOr<int> doCountSQL(
      String table, SQL sql, PostgreSQLConnection connection) {
    return connection
        .mappedResultsQuery(sql.sql, substitutionValues: sql.parameters)
        .resolveMapped((results) {
      var count = results
          .map((e) {
            var tableResults = e[table] ?? e[''];
            var count = tableResults?['count'] ?? 0;
            return count is int ? count : int.tryParse(count.toString().trim());
          })
          .whereType<int>()
          .first;
      return count;
    });
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
      String table, SQL sql, PostgreSQLConnection connection) {
    return connection
        .mappedResultsQuery(sql.sql, substitutionValues: sql.parameters)
        .resolveMapped((results) {
      var entries = results
          .map((e) => e[table])
          .whereType<Map<String, dynamic>>()
          .toList();

      return entries;
    });
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
      String table, SQL sql, PostgreSQLConnection connection) {
    return connection
        .mappedResultsQuery(sql.sql, substitutionValues: sql.parameters)
        .resolveMapped((results) {
      var entries = results
          .map((e) => e[table])
          .whereType<Map<String, dynamic>>()
          .toList();

      return entries;
    });
  }

  @override
  bool get sqlAcceptsInsertOutput => false;

  @override
  bool get sqlAcceptsInsertReturning => true;

  @override
  FutureOr<dynamic> doInsertSQL(
      String table, SQL sql, PostgreSQLConnection connection) {
    return connection
        .mappedResultsQuery(sql.sql, substitutionValues: sql.parameters)
        .resolveMapped((results) {
      if (results.isEmpty) {
        return null;
      }

      var returning = results.first[table];

      if (returning == null || returning.isEmpty) {
        return null;
      } else if (returning.length == 1) {
        var id = returning.values.first;
        return id;
      } else {
        var idFieldName = sql.idFieldName;

        if (idFieldName != null) {
          var id = returning[idFieldName];
          return id;
        } else {
          var id = returning.values.first;
          return id;
        }
      }
    });
  }
}

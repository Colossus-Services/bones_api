import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:postgres/postgres.dart' hide Time, Type;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_sql.dart';
import 'bones_api_extension.dart';
import 'bones_api_initializable.dart';
import 'bones_api_logging.dart';
import 'bones_api_sql_builder.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';
import 'bones_api_utils_timedmap.dart';

final _log = logging.Logger('DBPostgreSQLAdapter')..registerAsDbLogger();

/// A PostgreSQL adapter.
class DBPostgreSQLAdapter extends DBSQLAdapter<PostgreSQLConnectionWrapper>
    implements WithRuntimeTypeNameSafe {
  @override
  String get runtimeTypeNameSafe => 'DBPostgreSQLAdapter';

  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBSQLAdapter.boot();

    Transaction.registerErrorFilter((e, s) => e is PgException);

    DBSQLAdapter.registerAdapter(
      [
        'sql.postgres',
        'sql.postgre',
        'sql.postgresql',
        'postgres',
        'postgre',
        'postgresql',
      ],
      DBPostgreSQLAdapter,
      _instantiate,
    );
  }

  static FutureOr<DBPostgreSQLAdapter?> _instantiate(
    config, {
    int? minConnections,
    int? maxConnections,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    try {
      return DBPostgreSQLAdapter.fromConfig(
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

  DBPostgreSQLAdapter(
    this.databaseName,
    this.username, {
    String? host = 'localhost',
    Object? password,
    PasswordProvider? passwordProvider,
    int? port = 5432,
    int minConnections = 1,
    int maxConnections = 3,
    super.generateTables,
    super.checkTables,
    super.populateTables,
    super.populateSource,
    super.populateSourceVariables,
    super.parentRepositoryProvider,
    super.connectivity,
    super.workingPath,
    super.logSQL,
  }) : host = host ?? 'localhost',
       port = port ?? 5432,
       _password =
           (password != null && password is! PasswordProvider
               ? password.toString()
               : null),
       _passwordProvider =
           passwordProvider ?? (password is PasswordProvider ? password : null),
       super(
         'postgresql',
         minConnections,
         maxConnections,
         const DBSQLAdapterCapability(
           dialect: SQLDialect(
             'PostgreSQL',
             elementQuote: '"',
             acceptsReturningSyntax: true,
             acceptsInsertDefaultValues: true,
             acceptsInsertOnConflict: true,
             acceptsVarcharWithoutMaximumSize: true,
             foreignKeyCreatesImplicitIndex: false,
           ),
           transactions: true,
           transactionAbort: true,
           tableSQL: true,
           constraintSupport: true,
           multiIsolateSupport: true,
           connectivity: DBAdapterCapabilityConnectivity.secureAndUnsecure,
         ),
       ) {
    boot();

    if (_password == null && _passwordProvider == null) {
      throw ArgumentError("No `password` or `passwordProvider` ");
    }

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  factory DBPostgreSQLAdapter.fromConfig(
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

    var connectivityStr = (config?['connectivity'] ?? '')
        .toString()
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    var connectivity =
        DBAdapterConnectivity.values.firstWhereOrNull(
          (e) => e.name.toLowerCase() == connectivityStr,
        ) ??
        DBAdapterConnectivity.any;

    return DBPostgreSQLAdapter(
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
      connectivity: connectivity,
      workingPath: workingPath,
      logSQL: logSql,
    );
  }

  @override
  SQLDialect get dialect => super.dialect as SQLDialect;

  FutureOr<String> _getPassword() {
    if (_password != null) {
      return _password;
    } else {
      return _passwordProvider!(username);
    }
  }

  @override
  Map<String, dynamic> information({bool extended = false, String? table}) {
    var info = <String, dynamic>{};

    if (table != null) {
      var executingTransaction = Transaction.executingTransaction;
      if (executingTransaction != null) {
        info['executingTransaction'] = executingTransaction;
      }
    }

    return info;
  }

  @override
  List<Initializable> initializeDependencies() {
    var parentRepositoryProvider = this.parentRepositoryProvider;
    return <Initializable>[
      if (parentRepositoryProvider != null) parentRepositoryProvider,
    ];
  }

  @override
  Object resolveError(
    Object error,
    StackTrace stackTrace,
    Object? operation,
    Object? previousError,
  ) {
    if (error is DBPostgreSQLAdapterException) {
      return error;
    } else if (error is ServerException) {
      if (error.severity == Severity.error) {
        if (error.code == '23505') {
          return EntityFieldInvalid(
            "unique",
            error.detail,
            fieldName: error.columnName,
            tableName: error.tableName,
            parentError: error,
            previousError: previousError,
            operation: operation,
          );
        } else if (error.code == '23503') {
          return DBPostgreSQLAdapterException(
            "delete.constraint",
            '${error.message} ; Detail: ${error.detail} ; Table: ${error.tableName} ; Constraint: ${error.constraintName}',
            parentError: error,
            parentStackTrace: stackTrace,
            previousError: previousError,
            operation: operation,
          );
        }
      }
    }

    return DBPostgreSQLAdapterException(
      'error',
      '$error',
      parentError: error,
      parentStackTrace: stackTrace,
      previousError: previousError,
      operation: operation,
    );
  }

  @override
  String getConnectionURL(PostgreSQLConnectionWrapper connection) =>
      connection.connectionURL;

  int _connectionCount = 0;

  @override
  FutureOr<PostgreSQLConnectionWrapper> createConnection() async {
    var password = await _getPassword();

    var count = ++_connectionCount;

    for (var i = 0; i < 3; ++i) {
      final timeoutSec = i == 0 ? 3 : (i == 1 ? 10 : 30);
      final timeout = Duration(seconds: timeoutSec);

      var connection = await _createConnectionImpl(password, timeout);

      if (connection != null) {
        var connUrl = getConnectionURL(connection);
        _log.info(
          'createConnection[#$count $poolAliveElementsSize/$maxConnections]> $connUrl > $connection',
        );

        return connection;
      }

      if (poolSize > 0) {
        var poolConn = peekFromPool();

        if (poolConn != null) {
          return poolConn.resolveMapped((conn) {
            if (conn != null) {
              var connUrl = getConnectionURL(conn);
              _log.severe(
                "Skipping connection retry. Returning connection from pool: $connUrl",
              );
              return conn;
            }

            return _createConnectionImpl(password, timeout).then((conn) {
              if (conn == null) {
                var error = PgException(
                  "Error connecting to: $databaseName@$host:$port",
                );

                _log.severe(
                  "Can't connect to PostgreSQL: $databaseName@$host:$port",
                );

                throw error;
              }
              return conn;
            });
          });
        }
      }
    }

    var error = PgException("Error connecting to: $databaseName@$host:$port");

    _log.severe("Can't connect to PostgreSQL: $databaseName@$host:$port");

    throw error;
  }

  Future<PostgreSQLConnectionWrapper?> _createConnectionImpl(
    String password,
    Duration timeout,
  ) async {
    final endpoint = Endpoint(
      host: host,
      port: port,
      database: databaseName,
      username: username,
      password: password,
    );

    Connection? connection;
    bool? secure;
    if (connectivity == DBAdapterConnectivity.secure) {
      (connection, secure) = await _connectSSLImpl(endpoint, timeout);
    } else if (connectivity == DBAdapterConnectivity.insecure) {
      (connection, secure) = await _connectNoSSLImpl(endpoint, timeout);
    } else {
      (connection, secure) =
          await (_lastConnectSSLSupported
              ? _connectSSLImpl(endpoint, timeout)
              : _connectNoSSLImpl(endpoint, timeout));
    }

    if (connection == null) return null;

    var connWrapper = PostgreSQLConnectionWrapper(
      connection,
      endpoint.username,
      endpoint.host,
      endpoint.port,
      endpoint.database,
      secure ?? false,
    );

    _connectionFinalizer.attach(connWrapper, connection);

    return connWrapper;
  }

  var _lastConnectSSLSupported = true;

  Future<(Connection?, bool?)> _connectSSLImpl(
    Endpoint endpoint,
    Duration timeout,
  ) async {
    try {
      var connection = await Connection.open(
        endpoint,
        settings: ConnectionSettings(
          connectTimeout: timeout,
          sslMode: SslMode.require,
        ),
      );
      _lastConnectSSLSupported = true;
      return (connection, true);
    } catch (e) {
      if (connectivity.allowInsecure) {
        try {
          var connection = await Connection.open(
            endpoint,
            settings: ConnectionSettings(
              connectTimeout: timeout,
              sslMode: SslMode.disable,
            ),
          );
          _lastConnectSSLSupported = false;
          return (connection, false);
        } catch (_) {}
      }

      return (null, null);
    }
  }

  Future<(Connection?, bool?)> _connectNoSSLImpl(
    Endpoint endpoint,
    Duration timeout,
  ) async {
    try {
      var connection = await Connection.open(
        endpoint,
        settings: ConnectionSettings(
          connectTimeout: timeout,
          sslMode: SslMode.disable,
        ),
      );
      _lastConnectSSLSupported = false;
      return (connection, false);
    } catch (e) {
      if (connectivity.allowSecure) {
        try {
          var connection = await Connection.open(
            endpoint,
            settings: ConnectionSettings(
              connectTimeout: timeout,
              sslMode: SslMode.require,
            ),
          );
          _lastConnectSSLSupported = true;
          return (connection, true);
        } catch (_) {}
      }

      return (null, null);
    }
  }

  late final Finalizer<Connection> _connectionFinalizer = Finalizer(
    _finalizeConnection,
  );

  void _finalizeConnection(Connection connection) {
    try {
      // ignore: discarded_futures
      connection.close();
    } catch (_) {}
  }

  @override
  bool closeConnection(PostgreSQLConnectionWrapper connection) {
    _log.info('closeConnection> $connection > poolSize: $poolSize');
    connection.close();
    return true;
  }

  @override
  bool isPoolElementValid(
    PostgreSQLConnectionWrapper o, {
    bool checkUsage = true,
  }) => isConnectionValid(o, checkUsage: checkUsage);

  @override
  FutureOr<bool> isPoolElementInvalid(
    PostgreSQLConnectionWrapper o, {
    bool checkUsage = true,
  }) => !isConnectionValid(o, checkUsage: checkUsage);

  @override
  bool isConnectionValid(
    PostgreSQLConnectionWrapper connection, {
    bool checkUsage = true,
  }) {
    if (connection.isClosed) return false;

    if (checkUsage && connection.isInactive(connectionInactivityLimit)) {
      return false;
    }

    return true;
  }

  @override
  PostgreSQLConnectionWrapper? recyclePoolElement(
    PostgreSQLConnectionWrapper o,
  ) {
    if (o is PostgreSQLConnectionTransactionWrapper) {
      return null;
    }

    var valid = isPoolElementValid(o);
    if (!valid) {
      return null;
    }

    return o;
  }

  @override
  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table) async {
    var connection = await catchFromPool();

    try {
      _log.info('getTableFieldsTypesImpl> $table');

      var sql =
          "SELECT column_name, data_type, column_default, is_updatable FROM information_schema.columns WHERE table_name = '$table'";

      var scheme = await connection.mappedResultsQuery(sql);

      await releaseIntoPool(connection);

      if (scheme.isEmpty) return null;

      var fieldsTypes = Map<String, Type>.fromEntries(
        scheme.map((e) {
          var k = e['column_name'] as String;
          var v = _toFieldType(e['data_type'] as String);
          return MapEntry(k, v);
        }),
      );

      return fieldsTypes;
    } catch (_) {
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

      var sql =
          "SELECT column_name, data_type, column_default, is_updatable FROM information_schema.columns WHERE table_name = '$table'";

      var scheme = await connection.mappedResultsQuery(sql);

      if (scheme.isEmpty) {
        await releaseIntoPool(connection);
        return null;
      }

      var idFieldName = await _findIDField(connection, table, scheme);

      var fieldsTypes = Map<String, Type>.fromEntries(
        scheme.map((e) {
          var k = e['column_name'] as String;
          var v = _toFieldType(e['data_type'] as String);
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

      var constraints = await _findConstraints(connection, table, fieldsTypes);

      await releaseIntoPool(connection);

      var tableScheme = TableScheme(
        table,
        relationship: relationship != null,
        idFieldName: idFieldName,
        fieldsTypes: fieldsTypes,
        constraints: constraints,
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

  Future<Set<TableConstraint>> _findConstraints(
    PostgreSQLConnectionWrapper connection,
    String table,
    Map<String, Type> fieldsTypes,
  ) async {
    var sql = '''
    SELECT 
      pg_get_constraintdef(con.oid) AS constraint_definition
    FROM pg_constraint con
      JOIN pg_class tbl ON con.conrelid = tbl.oid
    WHERE
      tbl.relname = '$table';
    ''';

    var columns = await connection.mappedResultsQuery(sql);

    var constraintsDefinitions =
        columns.map((m) => m['constraint_definition'].toString()).toList();

    var constraints =
        constraintsDefinitions.map(_parseConstraint).nonNulls.toSet();

    return constraints;
  }

  TableConstraint? _parseConstraint(String definition) {
    if (definition.startsWith("PRIMARY KEY")) {
      var field =
          RegExp(r'\(([^()]+?)\)')
              .firstMatch(definition)
              ?.group(1)
              ?.replaceAll("'", '')
              .replaceAll('"', '')
              .trim();
      return field == null ? null : TablePrimaryKeyConstraint(field);
    } else if (definition.startsWith("UNIQUE")) {
      var field =
          RegExp(r'\(([^()]+?)\)')
              .firstMatch(definition)
              ?.group(1)
              ?.replaceAll("'", '')
              .replaceAll('"', '')
              .trim();
      return field == null ? null : TableUniqueConstraint(field);
    } else if (definition.startsWith("CHECK")) {
      var idx1 = definition.indexOf('(');
      var idx2 = definition.lastIndexOf(')');

      var s = definition.substring(idx1 + 1, idx2);

      var field =
          RegExp(r'\(([^()]+?)\)')
              .firstMatch(s)
              ?.group(1)
              ?.replaceAll("'", '')
              .replaceAll('"', '')
              .trim();

      if (field == null || field.isEmpty) return null;

      var arrayDef = RegExp(r'ARRAY\[(.*?)]').firstMatch(s)?.group(1)?.trim();

      Set<String>? values;

      if (arrayDef != null && arrayDef.isNotEmpty) {
        values =
            RegExp(
              r"'(.*?)'",
            ).allMatches(arrayDef).map((m) => m.group(1)).nonNulls.toSet();
      } else {
        var singleValue =
            RegExp(r"\s+=\s+'(.*?)'").firstMatch(s)?.group(1)?.trim();

        if (singleValue != null) {
          values = {singleValue};
        }
      }

      if (values == null || values.isEmpty) return null;

      return TableEnumConstraint(field, values);
    }

    return null;
  }

  Future<String> _findIDField(
    PostgreSQLConnectionWrapper connection,
    String table,
    List<Map<String, dynamic>> scheme,
  ) async {
    var sql = '''
    SELECT
      c.column_name, c.data_type
    FROM
      information_schema.table_constraints tc 
    JOIN
      information_schema.constraint_column_usage AS ccu USING (constraint_schema, constraint_name) 
    JOIN
      information_schema.columns AS c ON c.table_schema = tc.constraint_schema AND tc.table_name = c.table_name AND ccu.column_name = c.column_name
    WHERE
      constraint_type = 'PRIMARY KEY' and tc.table_name = '$table';
    ''';

    var columns = await connection.mappedResultsQuery(sql);

    var primaryFields = Map.fromEntries(
      columns.map((m) => MapEntry(m['column_name'].toString(), m['data_type'])),
    );

    var primaryFieldsNames = primaryFields.keys.toList(growable: false);

    return selectIDFieldName(table, primaryFieldsNames);
  }

  static final RegExp _regExpSpaces = RegExp(r'\s+');
  static final RegExp _regExpIgnoreWords = RegExp(
    r'unsigned|signed|varying|precision|\(.*?\)',
  );

  Type _toFieldType(String dataType) {
    dataType = dataType.toLowerCase();
    dataType = dataType.replaceAll(_regExpIgnoreWords, ' ');
    dataType = dataType.replaceAll(_regExpSpaces, ' ');
    dataType = dataType.trim();

    switch (dataType) {
      case 'boolean':
      case 'bool':
        return bool;
      case 'integer':
      case 'int':
      case 'int2':
      case 'int4':
      case 'int8':
      case 'smallint':
      case 'bigint':
      case 'serial':
      case 'serial2':
      case 'serial4':
      case 'serial8':
      case 'smallserial':
      case 'bigserial':
        return int;
      case 'decimal':
      case 'numeric':
        return Decimal;
      case 'float':
      case 'float4':
      case 'float8':
      case 'double':
        return double;
      case 'text':
      case 'char':
      case 'character':
      case 'varchar':
        return String;
      case 'timestamp':
      case 'timestampz':
      case 'timestamp without time zone':
      case 'timestamp with time zone':
      case 'date':
      case 'datetime':
        return DateTime;
      case 'time':
      case 'timez':
      case 'time without time zone':
      case 'time with time zone':
        return Time;
      default:
        return String;
    }
  }

  Future<List<TableRelationshipReference>> _findRelationshipTables(
    PostgreSQLConnectionWrapper connection,
    String table,
    String idFieldName, {
    Object? contextID,
  }) async {
    final tablesReferences = await _findAllTableFieldsReferences(
      connection,
      table,
      contextID: contextID,
    );

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

              var refToTable = refToTables.single;
              var otherRef = otherRefs.single;

              var tableRelationshipReference = TableRelationshipReference(
                refToTable.sourceTable,
                refToTable.targetTable,
                refToTable.targetField,
                refToTable.targetFieldType,
                refToTable.sourceField,
                otherRef.targetTable,
                otherRef.targetField,
                otherRef.targetFieldType,
                otherRef.sourceField,
                sourceRelationshipFieldIndex: refToTable.indexName,
                targetRelationshipFieldIndex: otherRef.indexName,
              );

              return tableRelationshipReference;
            })
            .nonNulls
            .toList();

    return relationships;
  }

  FutureOr<List<Map<String, TableFieldReference>>>
  _findAllTableFieldsReferences(
    PostgreSQLConnectionWrapper connection,
    String table, {
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
    return tablesReferences;
  }

  final Expando<FutureOr<List<String>>> _listTablesNamesContextCache =
      Expando();

  FutureOr<List<String>> _listTablesNames(
    PostgreSQLConnectionWrapper connection, {
    Object? contextID,
  }) => _listTablesNamesContextCache.putIfAbsentAsync(
    contextID,
    () => _listTablesNamesImpl(connection),
  );

  Future<List<String>> _listTablesNamesImpl(
    PostgreSQLConnectionWrapper connection,
  ) async {
    var sql = '''
    SELECT table_name FROM information_schema.tables WHERE table_schema='public'
    ''';

    var results = await connection.mappedResultsQuery(sql);

    var names = results.map((e) => e.values.first).map((e) => '$e').toList();

    return names;
  }

  final TimedMap<String, Map<String, TableFieldReference>>
  _findFieldsReferencedTablesCache =
      TimedMap<String, Map<String, TableFieldReference>>(Duration(seconds: 30));

  final Expando<Map<String, FutureOr<Map<String, TableFieldReference>>>>
  _findFieldsReferencedTablesContextCache = Expando();

  FutureOr<Map<String, TableFieldReference>> _findFieldsReferencedTables(
    PostgreSQLConnectionWrapper connection,
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
    PostgreSQLConnectionWrapper connection,
    String table,
  ) async {
    var sql = '''
    SELECT
      o.conname AS constraint_name,
      
      m.relname AS source_table,
      stc_attr.attname AS source_column,
      src_inf.data_type AS source_column_type,

      f.relname AS target_table,
      targ_attr.attname AS target_column,
      targ_inf.data_type AS target_column_type,
    
      idx.relname AS fk_index_name

    FROM
      pg_constraint o
      LEFT JOIN pg_class f ON f.oid = o.confrelid 
      LEFT JOIN pg_class m ON m.oid = o.conrelid
    
    INNER JOIN pg_attribute stc_attr
      ON stc_attr.attrelid = m.oid
      AND stc_attr.attnum = o.conkey[1]
      AND stc_attr.attisdropped = false
    
    INNER JOIN information_schema.columns src_inf
      ON src_inf.table_name = m.relname
      AND src_inf.column_name = stc_attr.attname
    
    INNER JOIN pg_attribute targ_attr
      ON targ_attr.attrelid = f.oid
      AND targ_attr.attnum = o.confkey[1]
      AND targ_attr.attisdropped = false
    
    INNER JOIN information_schema.columns targ_inf
      ON targ_inf.table_name = f.relname
      AND targ_inf.column_name = targ_attr.attname
    
  	LEFT JOIN LATERAL (
      SELECT
        i.indexrelid
      FROM pg_index i
      WHERE i.indrelid = m.oid
        -- FK column must be the *first* column of the index. (i.indkey is 0-based)
        AND i.indkey[0] = o.conkey[1]
      ORDER BY
        array_length(i.indkey, 1) ASC,  -- single-column first
        i.indisunique DESC               -- prefer unique
      LIMIT 1
    ) idx_def ON true
    
    LEFT JOIN pg_class idx
      ON idx.oid = idx_def.indexrelid
    
    WHERE
      o.contype = 'f'
      AND m.relname = '$table'
      AND o.conrelid IN (
        SELECT oid FROM pg_class c WHERE c.relkind = 'r'
      );
    ''';

    var referenceFields = await connection.mappedResultsQuery(sql);

    var map = Map<String, TableFieldReference>.fromEntries(
      referenceFields.map((e) {
        var sourceTable = e['source_table'] as String?;
        var sourceField = e['source_column'] as String?;
        var sourceFieldDataType = e['source_column_type'] as String?;
        var targetTable = e['target_table'] as String?;
        var targetField = e['target_column'] as String?;
        var targetFieldDataType = e['target_column_type'] as String?;
        var fkIndexName = e['fk_index_name'] as String?;

        if (sourceTable == null ||
            sourceField == null ||
            targetTable == null ||
            targetField == null) {
          return null;
        }

        if (fkIndexName != null && fkIndexName.isEmpty) {
          fkIndexName = null;
        }

        var sourceFieldType =
            sourceFieldDataType != null
                ? _toFieldType(sourceFieldDataType)
                : String;

        var targetFieldType =
            targetFieldDataType != null
                ? _toFieldType(targetFieldDataType)
                : String;

        var reference = TableFieldReference(
          sourceTable,
          sourceField,
          sourceFieldType,
          targetTable,
          targetField,
          targetFieldType,
          indexName: fkIndexName,
        );

        return MapEntry<String, TableFieldReference>(sourceField, reference);
      }).nonNulls,
    );

    return map;
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
          ('SMALLINT', -32768, 32767),
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

      return 'INT'; // default to 32-bit int
    } else if (type.isBigInt) {
      if (isID) {
        return 'BIGINT';
      }

      return 'NUMERIC'; // arbitrary-precision integers
    } else if (type.type == DynamicInt) {
      return 'NUMERIC'; // arbitrary-precision integers
    }

    var sqlType = super.typeToSQLType(
      type,
      column,
      entityFieldAnnotations: entityFieldAnnotations,
      isID: isID,
    );

    if (sqlType == 'TIME') {
      return 'TIME WITHOUT TIME ZONE';
    }

    return sqlType;
  }

  @override
  MapEntry<String, List<String>>? enumTypeToSQLType(
    Type type,
    String column, {
    List<EntityField>? entityFieldAnnotations,
  }) {
    var enumType = super.enumTypeToSQLType(
      type,
      column,
      entityFieldAnnotations: entityFieldAnnotations,
    );

    if (enumType == null) return null;

    var values = enumType.value;
    if (values.isEmpty) {
      return MapEntry('VARCHAR', values);
    }

    return MapEntry('VARCHAR CHECK', values);
  }

  @override
  FutureOr<bool> executeTableSQL(String createTableSQL) => executeWithPool((c) {
    return c
        .execute(createTableSQL)
        .then(
          (_) => true,
          onError: (e, s) {
            _log.severe("Error executing table SQL:\n$createTableSQL", e, s);
            return false;
          },
        );
  });

  @override
  FutureOr<int> doCountSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    PostgreSQLConnectionWrapper connection,
  ) {
    return connection
        .mappedResultsQuery(
          sql.sql,
          substitutionValues: sql.parametersByPlaceholder,
        )
        .resolveMapped((results) {
          var count =
              results
                  .map((row) {
                    var count = row['count'] ?? 0;
                    return count is int
                        ? count
                        : int.tryParse(count.toString().trim());
                  })
                  .whereType<int>()
                  .first;
          return count;
        });
  }

  @override
  FutureOr<List<I>> doExistIDsSQL<I extends Object>(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    PostgreSQLConnectionWrapper connection,
  ) {
    if (sql.isDummy) return <I>[];

    return connection
        .mappedResultsQuery(
          sql.sql,
          substitutionValues: sql.parametersByPlaceholder,
        )
        .resolveMapped((results) {
          var ids = results.map((row) => _resolveReturningID(row, sql));
          return parseIDs<I>(ids);
        });
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    PostgreSQLConnectionWrapper connection,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return connection.mappedResultsQuery(
      sql.sql,
      substitutionValues: sql.parametersByPlaceholder,
    );
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    PostgreSQLConnectionWrapper connection,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return connection.mappedResultsQuery(
      sql.sql,
      substitutionValues: sql.parametersByPlaceholder,
    );
  }

  @override
  FutureOr<dynamic> doInsertSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    PostgreSQLConnectionWrapper connection,
  ) {
    if (sql.isDummy) return null;

    return connection
        .mappedResultsQuery(
          sql.sql,
          substitutionValues: sql.parametersByPlaceholder,
        )
        .resolveMapped((results) => _resolveResultID(results, table, sql));
  }

  @override
  FutureOr doUpdateSQL(
    String entityName,
    String table,
    SQL sql,
    Object id,
    Transaction transaction,
    PostgreSQLConnectionWrapper connection, {
    bool allowAutoInsert = false,
  }) {
    if (sql.isFullyDummy) return id;

    return connection
        .mappedResultsQuery(
          sql.sql,
          substitutionValues: sql.parametersByPlaceholder,
        )
        .resolveMapped((results) {
          if (results.isEmpty) {
            var entry = sql.parametersByPlaceholder;
            if (!allowAutoInsert) {
              throw StateError(
                "Can't update not stored entity into table `$table`: $entry",
              );
            }

            var fields = sql.namedParameters!;
            return _updateAutoInsert(
              transaction,
              entityName,
              table,
              fields,
              connection,
            );
          }

          return _resolveResultID(results, table, sql);
        });
  }

  FutureOr<dynamic> _updateAutoInsert(
    Transaction transaction,
    String entityName,
    String table,
    Map<String, dynamic> fields,
    PostgreSQLConnectionWrapper connection,
  ) {
    return getTableScheme(table).resolveMapped((tableScheme) {
      if (tableScheme == null) {
        throw StateError("Can't find `TableScheme` for table `$table`");
      }

      var idFieldName = tableScheme.idFieldName ?? 'id';
      var idFieldType = tableScheme.fieldsTypes[idFieldName] ?? int;
      var id = fields[idFieldName];

      if (id == null) {
        throw StateError(
          "Can't auto-insert entry without ID> table: `$table`; idFieldName: $idFieldName",
        );
      }

      return generateInsertSQL(
        transaction,
        entityName,
        table,
        fields,
      ).resolveMapped((insertSQL) {
        _log.info('Update not affecting any row! Auto inserting: $insertSQL');

        return doInsertSQL(
          entityName,
          table,
          insertSQL,
          transaction,
          connection,
        ).resolveMapped(
          (res) => _fixeTableSequence(
            transaction,
            entityName,
            table,
            idFieldName,
            idFieldType,
            connection,
            res,
          ),
        );
      });
    });
  }

  FutureOr<dynamic> _fixeTableSequence(
    Transaction transaction,
    String entityName,
    String table,
    String idFieldName,
    Type idFieldType,
    PostgreSQLConnectionWrapper connection,
    Object? lastInsertResult,
  ) {
    if (!idFieldType.isEntityIDType &&
        !idFieldType.isNumericOrDynamicNumberType) {
      return lastInsertResult;
    }

    var fixSql =
        "SELECT setval(pg_get_serial_sequence('$table', '$idFieldName'), coalesce(max(id),0) + 1, false) FROM \"$table\"";

    _log.info("Fixing table PRIMARY KEY sequence: <$fixSql>");

    return connection.query(fixSql).then((r) => lastInsertResult);
  }

  dynamic _resolveResultID(
    List<Map<String, dynamic>> results,
    String table,
    SQL sql,
  ) {
    if (results.isEmpty) {
      return null;
    }

    var returning = results.first;

    return _resolveReturningID(returning, sql);
  }

  dynamic _resolveReturningID(Map<String, dynamic> returning, SQL sql) {
    if (returning.isEmpty) {
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
  }

  @override
  Future<PostgreSQLConnectionTransactionWrapper> openTransaction(
    Transaction transaction,
  ) {
    var contextCompleter = Completer<PostgreSQLConnectionTransactionWrapper>();

    var result = executeWithPool(
      (connection) {
        return connection.openTransaction((connTransaction) {
          contextCompleter.complete(connTransaction);

          return transaction.transactionFuture.then(
            (res) => resolveTransactionResult(res, transaction, connection),
            onError: (e, s) {
              cancelTransaction(transaction, connTransaction, e, s);
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
    PostgreSQLConnectionWrapper? connection,
    Object? error,
    StackTrace? stackTrace,
  ) {
    var connTransaction = connection as PostgreSQLConnectionTransactionWrapper?;
    connTransaction?.cancelTransaction();
    return true;
  }

  @override
  bool get callCloseTransactionRequired => false;

  @override
  FutureOr<void> closeTransaction(
    Transaction transaction,
    PostgreSQLConnectionWrapper? connection,
  ) {}

  @override
  String toString() {
    var closedStr = isClosed ? ', closed' : '';
    return 'DBPostgreSQLAdapter#$instanceID{$databaseName@$host:$port$closedStr}';
  }
}

/// A [DBPostgreSQLAdapter] connection wrapper.
class PostgreSQLConnectionWrapper extends DBConnectionWrapper<Session> {
  final String? username;
  final String host;
  final int port;
  final String database;
  final bool secure;

  PostgreSQLConnectionWrapper(
    super.nativeConnection,
    this.username,
    this.host,
    this.port,
    this.database,
    this.secure,
  );

  @override
  String get connectionURL {
    return "postgresql://$username@$host:$port/$database${secure ? '?sslmode=require' : ''}";
  }

  Future<List<Map<String, dynamic>>> mappedResultsQuery(
    String sql, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    updateLastAccessTime();

    var rs = await nativeConnection.execute(
      Sql.named(sql),
      parameters: substitutionValues,
    );

    var mappedResult = rs.map((e) => e.toResultsMap()).toList();

    return mappedResult;
  }

  Future<Result> query(
    String sql, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    updateLastAccessTime();
    return nativeConnection.execute(
      Sql.named(sql),
      parameters: substitutionValues,
    );
  }

  Future<int> execute(
    String sql, {
    Map<String, dynamic>? substitutionValues,
  }) async {
    updateLastAccessTime();
    var rs = await nativeConnection.execute(
      Sql.named(sql),
      parameters: substitutionValues,
      ignoreRows: true,
    );
    return rs.affectedRows;
  }

  Future openTransaction(
    Future Function(PostgreSQLConnectionTransactionWrapper connection)
    queryBlock, {
    int? commitTimeoutInSeconds,
  }) {
    var conn = nativeConnection as Connection;
    updateLastAccessTime();

    return conn.runTx(
      (tx) => queryBlock(
        PostgreSQLConnectionTransactionWrapper(
          this,
          tx,
          username,
          host,
          port,
          database,
          secure,
        ),
      ),
    );
  }

  @override
  bool isClosedImpl() {
    final nativeConnection = this.nativeConnection;
    return nativeConnection is Connection && !nativeConnection.isOpen;
  }

  @override
  void closeImpl() {
    final nativeConnection = this.nativeConnection;
    if (nativeConnection is Connection) {
      try {
        // ignore: discarded_futures
        nativeConnection.close();
      } catch (_) {}
    }
  }

  @override
  String get runtimeTypeNameSafe => 'PostgreSQLConnectionWrapper';
}

/// A [DBPostgreSQLAdapter] connection transaction wrapper.
class PostgreSQLConnectionTransactionWrapper
    extends PostgreSQLConnectionWrapper {
  final PostgreSQLConnectionWrapper parent;

  PostgreSQLConnectionTransactionWrapper(
    this.parent,
    super.nativeConnection,
    super.username,
    super.host,
    super.port,
    super.database,
    super.secure,
  );

  @override
  Future openTransaction(
    Future Function(
      PostgreSQLConnectionTransactionWrapper connectionTransaction,
    )
    queryBlock, {
    int? commitTimeoutInSeconds,
  }) => queryBlock(this);

  void cancelTransaction({String? reason}) {
    var tx = nativeConnection as TxSession;
    unawaited(tx.rollback());
  }

  @override
  String get runtimeTypeNameSafe => 'PostgreSQLConnectionTransactionWrapper';

  @override
  String get info => '${super.info}, parent: #${parent.id}';
}

/// Exception thrown by [DBPostgreSQLAdapter] operations.
class DBPostgreSQLAdapterException extends DBSQLAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBPostgreSQLAdapterException';

  DBPostgreSQLAdapterException(
    super.type,
    super.message, {
    super.parentError,
    super.parentStackTrace,
    super.operation,
    super.previousError,
  });
}

extension on ResultRow {
  Map<String, dynamic> toResultsMap() {
    final map = <String, dynamic>{};

    for (final (i, col) in schema.columns.indexed) {
      if (col.columnName case final String name) {
        map[name] = this[i];
      } else {
        map['[$i]'] = this[i];
      }
    }

    return map;
  }
}

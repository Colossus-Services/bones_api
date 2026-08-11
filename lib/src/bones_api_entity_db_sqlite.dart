import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:sqlite3/sqlite3.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_condition_encoder.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_sql.dart';
import 'bones_api_initializable.dart';
import 'bones_api_logging.dart';
import 'bones_api_sql_builder.dart';
import 'bones_api_types.dart';
import 'bones_api_utils.dart';
import 'bones_api_utils_timedmap.dart';

final _log = logging.Logger('DBSQLiteAdapter')..registerAsDbLogger();

/// The `:memory:` path accepted by [DBSQLiteAdapter] to select an in-memory
/// database.
const String sqliteMemoryPath = ':memory:';

/// A SQLite adapter, backed by the `sqlite3` package (bundled SQLite, `dart:ffi`).
///
/// Supports both file databases and in-memory databases (see [inMemory]).
///
/// ## Single native handle
///
/// The `sqlite3` driver is **synchronous** and SQLite allows a single writer at
/// a time. Two native handles in one isolate are a hazard rather than a benefit:
/// a handle blocking on a lock stalls the whole isolate, so the handle holding
/// the lock could never reach its `COMMIT` — `busy_timeout` would elapse and the
/// statement would fail with *"database is locked"*. And there is nothing to
/// gain, since a synchronous driver has no I/O wait to overlap.
///
/// So this adapter opens exactly **one** [Database] and every pooled
/// [DBSQLiteConnectionWrapper] is a cheap view over it. This also makes
/// [inMemory] work without any URI/shared-cache trickery (each
/// `sqlite3.openInMemory()` would otherwise be a *separate* database, and the
/// bundled SQLite is compiled with `OMIT_SHARED_CACHE`), and it keeps the
/// [Pool] machinery intact — note that [Pool.catchFromPool] force-creates
/// elements beyond [maxConnections] under contention, so capping the pool at 1
/// would *not* have been enough to guarantee a single handle.
///
/// The trade-off is that a statement issued outside the current transaction
/// while one is open participates in it, and is committed or rolled back with
/// it. In a single isolate that can only happen for genuinely interleaved work.
/// A transaction started while another is already open nests as a `SAVEPOINT`
/// rather than failing on a second `BEGIN`.
class DBSQLiteAdapter extends DBSQLAdapter<DBSQLiteConnectionWrapper>
    implements WithRuntimeTypeNameSafe {
  @override
  String get runtimeTypeNameSafe => 'DBSQLiteAdapter';

  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBSQLAdapter.boot();

    Transaction.registerErrorFilter(
      (e, s) => e is SqliteException || e is _SQLiteStatementException,
    );

    DBSQLAdapter.registerAdapter(
      ['sql.sqlite', 'sql.sqlite3', 'sqlite', 'sqlite3'],
      DBSQLiteAdapter,
      _instantiate,
    );
  }

  static FutureOr<DBSQLiteAdapter?> _instantiate(
    config, {
    int? minConnections,
    int? maxConnections,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    try {
      return DBSQLiteAdapter.fromConfig(
        config,
        parentRepositoryProvider: parentRepositoryProvider,
        workingPath: workingPath,
      );
    } catch (e, s) {
      _log.severe("Error instantiating from config", e, s);
      return null;
    }
  }

  /// The database file path, or [sqliteMemoryPath] for an in-memory database.
  final String databasePath;

  /// If `true` this is an in-memory database (not backed by a file).
  final bool inMemory;

  /// The `busy_timeout` (in milliseconds) applied to the database handle.
  ///
  /// Only guards against *other OS processes* holding the database file: this
  /// adapter uses a single handle, so it can never contend with itself.
  final int busyTimeout;

  /// The single native handle shared by every pooled connection wrapper.
  Database? _database;

  DBSQLiteAdapter(
    String databasePath, {
    int? busyTimeout,
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
  }) : databasePath = databasePath,
       inMemory = _isMemoryPath(databasePath),
       busyTimeout = busyTimeout ?? 5000,
       super(
         'sqlite',
         minConnections,
         maxConnections,
         DBSQLAdapterCapability(
           dialect: const SQLDialect(
             'SQLite',
             elementQuote: '"',
             acceptsReturningSyntax: true,
             // SQLite rejects `RETURNING "alias".*`:
             // "RETURNING may not use TABLE.* wildcards".
             returningAcceptsTableWildcard: false,
             acceptsInsertDefaultValues: true,
             // `INSERT IGNORE` is MySQL-only; SQLite uses `ON CONFLICT`:
             acceptsInsertIgnore: false,
             acceptsInsertOnConflict: true,
             acceptsVarcharWithoutMaximumSize: true,
             // SQLite does NOT create an implicit index for a foreign key:
             foreignKeyCreatesImplicitIndex: false,
             createIndexIfNotExists: true,
             // SQLite can't parse an `OFFSET` without a preceding `LIMIT`,
             // and uses `LIMIT -1` as "no limit":
             offsetRequiresLimit: true,
             offsetMaxLimitValue: '-1',
           ),
           transactions: true,
           transactionAbort: true,
           tableSQL: true,
           // SQLite can't `ALTER TABLE ... ADD CONSTRAINT`:
           constraintSupport: false,
           // A `sqlite3` handle can't be shared with another isolate:
           multiIsolateSupport: false,
           connectivity: DBAdapterCapabilityConnectivity.none,
         ),
       ) {
    boot();

    parentRepositoryProvider?.notifyKnownEntityRepositoryProvider(this);
  }

  static bool _isMemoryPath(String path) {
    path = path.trim();
    return path.isEmpty ||
        path == sqliteMemoryPath ||
        path.toLowerCase() == 'memory';
  }

  factory DBSQLiteAdapter.fromConfig(
    Map<String, dynamic>? config, {
    String? defaultDatabasePath,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    boot();

    var memory = config?['memory'] ?? config?['inMemory'];

    String? path =
        (config?['path'] ??
                config?['file'] ??
                config?['database'] ??
                config?['db'] ??
                defaultDatabasePath)
            ?.toString();

    if (memory == true || (path == null && memory != false)) {
      path = sqliteMemoryPath;
    }

    if (path == null) throw ArgumentError.notNull('path');

    int? busyTimeout =
        config?['busyTimeout'] ??
        config?['busy-timeout'] ??
        config?['busy_timeout'];

    var (generateTables: generateTables, checkTables: checkTables) =
        DBSQLAdapter.parseConfigDBGenerateTablesAndCheckTables(config);

    var populate = config?['populate'];
    Object? populateTables;
    Object? populateSource;
    Object? populateSourceVariables;

    if (populate is Map) {
      populateTables = populate['tables'];
      populateSource = populate['source'];
      populateSourceVariables = populate['variables'];
    }

    var logSql = DBSQLAdapter.parseConfigLogSQL(config) ?? false;

    return DBSQLiteAdapter(
      path,
      busyTimeout: busyTimeout,
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
  String getConnectionURL(DBSQLiteConnectionWrapper connection) =>
      'sqlite://$databasePath';

  int _connectionCount = 0;

  @override
  DBSQLiteConnectionWrapper createConnection() {
    var count = ++_connectionCount;

    var connWrapper = _DBSQLiteConnectionWrapped(_openDatabase(), this);

    _log.info(
      'createConnection[#$count $poolAliveElementsSize/$maxConnections]> '
      '${getConnectionURL(connWrapper)}',
    );

    return connWrapper;
  }

  /// Opens the shared handle on first use, then returns it.
  Database _openDatabase() {
    var db = _database;
    if (db != null) return db;

    db = _database = inMemory
        ? sqlite3.openInMemory()
        : sqlite3.open(databasePath);

    // Foreign keys are OFF by default and are a per-connection setting.
    db.execute('PRAGMA foreign_keys = ON');

    if (!inMemory) {
      db.execute('PRAGMA busy_timeout = $busyTimeout');
      // WAL lets readers proceed while another *process* writes.
      db.execute('PRAGMA journal_mode = WAL');
      db.execute('PRAGMA synchronous = NORMAL');
    }

    return db;
  }

  /// Runs [sql] directly on the database handle, bypassing the entity layer.
  ///
  /// Useful for maintenance statements (`VACUUM`, `PRAGMA`, `ANALYZE`) and for
  /// test harnesses that need to reach an [inMemory] database, which is
  /// otherwise only accessible through this adapter's handle.
  ResultSet executeRawSQL(String sql, [List<Object?>? parameters]) {
    checkNotClosed();
    return _openDatabase().select(sql, _normalizeParameters(parameters));
  }

  /// The names of the tables in this database (excluding SQLite's internal
  /// `sqlite_*` tables).
  List<String> listTablesNames() => executeRawSQL(
    "SELECT name FROM sqlite_master "
    "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
  ).map((r) => r['name'].toString()).toList();

  @override
  bool closeConnection(DBSQLiteConnectionWrapper connection) {
    _log.info('closeConnection> $connection');
    // Only marks the wrapper closed: the native handle is shared and is
    // disposed by [close].
    try {
      connection.close();
    } catch (_) {}
    return true;
  }

  @override
  bool close() {
    if (!super.close()) return false;

    var db = _database;
    if (db != null) {
      _database = null;
      try {
        db.close();
      } catch (_) {}
    }

    return true;
  }

  @override
  bool isPoolElementValid(
    DBSQLiteConnectionWrapper o, {
    bool checkUsage = true,
  }) => isConnectionValid(o, checkUsage: checkUsage);

  @override
  FutureOr<bool> isPoolElementInvalid(
    DBSQLiteConnectionWrapper o, {
    bool checkUsage = true,
  }) => !isConnectionValid(o, checkUsage: checkUsage);

  @override
  bool isConnectionValid(
    DBSQLiteConnectionWrapper connection, {
    bool checkUsage = true,
  }) {
    if (connection.isClosed) return false;

    if (checkUsage && connection.isInactive(connectionInactivityLimit)) {
      return false;
    }

    return true;
  }

  @override
  DBSQLiteConnectionWrapper? recyclePoolElement(DBSQLiteConnectionWrapper o) {
    // A transaction wrapper is bound to an open transaction: never recycle it.
    if (o is _DBSQLiteConnectionTransaction) return null;
    return o;
  }

  // -------------------------------------------------------------------------
  // Scheme introspection (SQLite `PRAGMA`s, there is no `information_schema`).
  // -------------------------------------------------------------------------

  @override
  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table) =>
      executeWithPool((connection) {
        _log.info('getTableFieldsTypesImpl> $table');

        var columns = _tableInfo(connection, table);
        if (columns.isEmpty) return null;

        return _fieldsTypes(columns);
      });

  List<Row> _tableInfo(DBSQLiteConnectionWrapper connection, String table) {
    // `table_info` accepts the table name as a bound parameter only through the
    // table-valued form (`pragma_table_info`), which is what allows quoting it
    // safely here:
    return connection.select('SELECT * FROM pragma_table_info(?)', [
      table,
    ]).toList();
  }

  Map<String, Type> _fieldsTypes(List<Row> columns) {
    return Map<String, Type>.fromEntries(
      columns.map((c) {
        var name = c['name'] as String;
        var type = _toFieldType((c['type'] ?? '').toString());
        return MapEntry(name, type);
      }),
    );
  }

  @override
  FutureOr<TableScheme?> getTableSchemeImpl(
    String table,
    TableRelationshipReference? relationship, {
    Object? contextID,
  }) => executeWithPool((connection) {
    var columns = _tableInfo(connection, table);
    if (columns.isEmpty) return null;

    var idFieldName = _findIDField(table, columns);

    var fieldsTypes = _fieldsTypes(columns);

    notifyTableFieldTypes(table, fieldsTypes);

    var fieldsReferencedTablesRet = _findFieldsReferencedTables(
      connection,
      table,
      contextID: contextID,
    );

    return fieldsReferencedTablesRet.resolveMapped((fieldsReferencedTables) {
      var relationshipTablesRet = _findRelationshipTables(
        connection,
        table,
        contextID: contextID,
      );

      return relationshipTablesRet.resolveMapped((relationshipTables) {
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
      });
    });
  });

  String _findIDField(String table, List<Row> columns) {
    var primaryFieldsNames = columns
        .where((c) => (c['pk'] as int? ?? 0) > 0)
        .sorted((a, b) => (a['pk'] as int).compareTo(b['pk'] as int))
        .map((c) => c['name'].toString())
        .toList();

    return selectIDFieldName(table, primaryFieldsNames);
  }

  static final RegExp _regExpSpaces = RegExp(r'\s+');
  static final RegExp _regExpIgnoreWords = RegExp(
    r'unsigned|signed|varying|precision|native|\(.*?\)',
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
      case 'tinyint':
      case 'smallint':
      case 'mediumint':
      case 'int':
      case 'int2':
      case 'int8':
      case 'bigint':
      case 'integer':
        return int;
      case 'decimal':
      case 'numeric':
        return Decimal;
      case 'float':
      case 'double':
      case 'real':
        return double;
      case 'blob':
        return Uint8List;
      case 'time':
        return Time;
      case 'timestamp':
      case 'date':
      case 'datetime':
        return DateTime;
      case 'text':
      case 'char':
      case 'varchar':
      case 'clob':
      case 'enum':
        return String;
      default:
        // SQLite keeps the declared type verbatim; fall back to its affinity
        // rules (https://sqlite.org/datatype3.html#determination_of_column_affinity).
        if (dataType.contains('int')) return int;
        if (dataType.contains('char') ||
            dataType.contains('clob') ||
            dataType.contains('text')) {
          return String;
        }
        if (dataType.contains('blob')) return Uint8List;
        if (dataType.contains('real') ||
            dataType.contains('floa') ||
            dataType.contains('doub')) {
          return double;
        }
        return String;
    }
  }

  final Expando<FutureOr<List<String>>> _listTablesNamesContextCache =
      Expando();

  FutureOr<List<String>> _listTablesNames(
    DBSQLiteConnectionWrapper connection, {
    Object? contextID,
  }) => _listTablesNamesContextCache.putIfAbsentAsync(
    contextID,
    () => _listTablesNamesImpl(connection),
  );

  List<String> _listTablesNamesImpl(DBSQLiteConnectionWrapper connection) {
    var results = connection.select(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );

    return results.map((r) => r['name'].toString()).toList();
  }

  final TimedMap<String, Map<String, TableFieldReference>>
  _findFieldsReferencedTablesCache =
      TimedMap<String, Map<String, TableFieldReference>>(Duration(seconds: 30));

  final Expando<Map<String, FutureOr<Map<String, TableFieldReference>>>>
  _findFieldsReferencedTablesContextCache = Expando();

  FutureOr<Map<String, TableFieldReference>> _findFieldsReferencedTables(
    DBSQLiteConnectionWrapper connection,
    String table, {
    Object? contextID,
  }) {
    if (contextID != null) {
      var cache = _findFieldsReferencedTablesContextCache[contextID] ??= {};
      var cached = cache[table];
      if (cached != null) return cached;

      var ret = _findFieldsReferencedTablesImpl(connection, table);
      cache[table] = ret;

      return ret.resolveMapped((r) {
        cache[table] = r;
        _findFieldsReferencedTablesCache[table] = r;
        return r;
      });
    }

    return _findFieldsReferencedTablesCache.putIfAbsentCheckedAsync(
      table,
      () => _findFieldsReferencedTablesImpl(connection, table),
    );
  }

  FutureOr<Map<String, TableFieldReference>> _findFieldsReferencedTablesImpl(
    DBSQLiteConnectionWrapper connection,
    String table,
  ) {
    var results = connection.select(
      'SELECT * FROM pragma_foreign_key_list(?)',
      [table],
    );

    var mapEntriesRet = results
        .map<FutureOr<MapEntry<String, TableFieldReference>?>>((r) {
          var sourceField = r['from']?.toString();
          var targetTable = r['table']?.toString();
          var targetField = r['to']?.toString();

          if (sourceField == null || targetTable == null) {
            return null as FutureOr<MapEntry<String, TableFieldReference>?>;
          }

          // `PRAGMA foreign_key_list` reports a `null` target column when
          // the reference points at the target's PRIMARY KEY implicitly.
          FutureOr<String?> targetFieldRet =
              targetField ??
              getTableScheme(targetTable).resolveMapped((s) => s?.idFieldName);

          return targetFieldRet.resolveMapped<
            MapEntry<String, TableFieldReference>?
          >((targetField) {
            if (targetField == null) return null;

            var sourceFieldsTypesRet = getTableFieldsTypes(table);
            var targetFieldsTypesRet = getTableFieldsTypes(targetTable);

            return sourceFieldsTypesRet.resolveBoth(targetFieldsTypesRet, (
              sourceFieldsTypes,
              targetFieldsTypes,
            ) {
              var sourceFieldType = sourceFieldsTypes?[sourceField] ?? String;
              var targetFieldType = targetFieldsTypes?[targetField] ?? String;

              return MapEntry<String, TableFieldReference>(
                sourceField,
                TableFieldReference(
                  table,
                  sourceField,
                  sourceFieldType,
                  targetTable,
                  targetField,
                  targetFieldType,
                ),
              );
            });
          });
        })
        .toList()
        .resolveAll();

    return mapEntriesRet.resolveMapped(
      (mapEntries) =>
          Map<String, TableFieldReference>.fromEntries(mapEntries.nonNulls),
    );
  }

  FutureOr<List<TableRelationshipReference>> _findRelationshipTables(
    DBSQLiteConnectionWrapper connection,
    String table, {
    Object? contextID,
  }) {
    var tablesNamesRet = _listTablesNames(connection, contextID: contextID);

    return tablesNamesRet.resolveMapped((tablesNames) {
      var tablesReferencesRet = tablesNames
          .map(
            (t) => _findFieldsReferencedTables(
              connection,
              t,
              contextID: contextID,
            ),
          )
          .toList()
          .resolveAll();

      return tablesReferencesRet.resolveMapped((tablesReferences) {
        var candidates = tablesReferences.where((m) {
          return m.length > 1 &&
              m.values.where((r) => r.targetTable == table).isNotEmpty &&
              m.values.where((r) => r.targetTable != table).isNotEmpty;
        }).toList();

        return candidates
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
      });
    });
  }

  // -------------------------------------------------------------------------
  // Type mapping.
  // -------------------------------------------------------------------------

  // `typeToSQLType` and `foreignKeyTypeToSQLType` are deliberately NOT
  // overridden. SQLite has no fixed set of type names — a declared type only
  // selects a storage *affinity* — and every name the base `SQLGenerator`
  // emits maps to the right one: `INT`/`BIGINT` -> INTEGER, `VARCHAR` -> TEXT,
  // `BLOB` -> BLOB, `BOOLEAN`/`DECIMAL` -> NUMERIC, and `TIMESTAMP`/`TIME` ->
  // NUMERIC, which keeps their non-numeric ISO-8601 text as TEXT.
  //
  // The one place a literal type name is load-bearing is the primary key:

  @override
  String? primaryKeyTypeToSQLType(
    Type type, {
    List<EntityField>? entityFieldAnnotations,
  }) {
    // SQLite has no `SERIAL`: an auto-incrementing primary key must be declared
    // exactly as `INTEGER PRIMARY KEY [AUTOINCREMENT]`. Note that `SERIAL` is
    // silently *accepted* by SQLite (unknown type names get NUMERIC affinity)
    // but would leave the ID `NULL` on every insert.
    if (type.isNumericOrDynamicNumberType) {
      return 'INTEGER PRIMARY KEY AUTOINCREMENT';
    }

    return super.primaryKeyTypeToSQLType(
      type,
      entityFieldAnnotations: entityFieldAnnotations,
    );
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

    // SQLite has no `ENUM` type: emulate it with a `CHECK` constraint.
    var values = enumType.value;
    return MapEntry(values.isEmpty ? 'VARCHAR' : 'VARCHAR CHECK', values);
  }

  // -------------------------------------------------------------------------
  // Parameter binding.
  //
  // `sqlite3` only binds `int`, `double`, `String`, `List<int>` and `null`, so
  // the richer values that reach an adapter need to be normalized here. This is
  // the single choke point for every statement executed by this adapter.
  // -------------------------------------------------------------------------

  static List<Object?> _normalizeParameters(List<Object?>? values) {
    if (values == null || values.isEmpty) return const <Object?>[];
    return values.map(_normalizeParameter).toList(growable: false);
  }

  static Object? _normalizeParameter(Object? value) {
    if (value == null || value is int || value is double || value is String) {
      return value;
    }

    if (value is bool) return value ? 1 : 0;
    if (value is Uint8List) return value;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Time) return value.toString();
    if (value is Enum) return value.name;
    if (value is BigInt) {
      return value.isValidInt ? value.toInt() : value.toString();
    }
    if (value is DynamicInt) {
      var n = value.toBigInt();
      return n.isValidInt ? n.toInt() : n.toString();
    }
    if (value is Decimal) return value.toDouble();
    if (value is List<int>) return value;

    return value.toString();
  }

  // -------------------------------------------------------------------------
  // Statement execution.
  // -------------------------------------------------------------------------

  /// Runs [sql] on [connection], tagging any [SqliteException] with the [SQL]
  /// that caused it so [resolveError] can name the offending value.
  ResultSet _select(DBSQLiteConnectionWrapper connection, SQL sql) {
    try {
      return connection.select(
        sql.sqlPositional,
        sql.parametersValuesByPosition,
      );
    } on SqliteException catch (e, s) {
      Error.throwWithStackTrace(_SQLiteStatementException(e, sql), s);
    }
  }

  @override
  FutureOr<bool> executeTableSQL(String createTableSQL) =>
      executeWithPool((connection) {
        try {
          connection.execute(createTableSQL);
          return true;
        } catch (e, s) {
          _log.severe("Error executing table SQL:\n$createTableSQL", e, s);
          return false;
        }
      });

  @override
  FutureOr<int> doCountSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBSQLiteConnectionWrapper connection,
  ) {
    var results = _select(connection, sql);

    var count = results.map((r) => r.values.firstOrNull).firstOrNull ?? 0;

    return count is int ? count : int.tryParse(count.toString().trim()) ?? 0;
  }

  @override
  FutureOr<List<I>> doExistIDsSQL<I extends Object>(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBSQLiteConnectionWrapper connection,
  ) {
    if (sql.isDummy) return <I>[];

    var results = _select(connection, sql);

    return parseIDs<I>(results.map((r) => r['id']));
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doSelectSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBSQLiteConnectionWrapper connection,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    var results = _select(connection, sql);

    return _resultsToEntitiesMaps(results);
  }

  /// `Row` is an unmodifiable `Map` view over the `ResultSet`: copy it, since
  /// the framework mutates the returned entity maps.
  static List<Map<String, dynamic>> _resultsToEntitiesMaps(ResultSet? results) {
    if (results == null) return <Map<String, dynamic>>[];
    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  FutureOr<Iterable<Map<String, dynamic>>> doDeleteSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBSQLiteConnectionWrapper connection,
  ) {
    if (sql.isFullyDummy) return <Map<String, dynamic>>[];

    var preSQLs = sql.preSQL;
    if (preSQLs != null) {
      for (var e in preSQLs) {
        _select(connection, e);
      }
    }

    ResultSet? results;
    if (!sql.isDummy) {
      results = _select(connection, sql);
    }

    var posSQLs = sql.posSQL;
    if (posSQLs != null) {
      var posResults = posSQLs.map((e) => _select(connection, e)).toList();

      var idx = sql.posSQLReturnIndex;
      if (idx != null) results = posResults[idx];
    }

    return _resultsToEntitiesMaps(results);
  }

  @override
  FutureOr<dynamic> doInsertSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    DBSQLiteConnectionWrapper connection,
  ) {
    if (sql.isDummy) return null;

    var results = _select(connection, sql);

    return _resolveResultID(connection, results, sql);
  }

  @override
  FutureOr doUpdateSQL(
    String entityName,
    String table,
    SQL sql,
    Object id,
    Transaction transaction,
    DBSQLiteConnectionWrapper connection, {
    bool allowAutoInsert = false,
  }) {
    if (sql.isDummy) return id;

    var results = _select(connection, sql);

    var affectedRows = connection.updatedRows;

    if (affectedRows == 0 && results.isEmpty) {
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
        _log.info('Update not affecting any row! Auto inserting: $insertSQL');
        return doInsertSQL(
          entityName,
          table,
          insertSQL,
          transaction,
          connection,
        );
      });
    }

    return _resolveResultID(connection, results, sql, id);
  }

  dynamic _resolveResultID(
    DBSQLiteConnectionWrapper connection,
    ResultSet results,
    SQL sql, [
    Object? entityId,
  ]) {
    if (entityId != null) return entityId;

    var returning = results.firstOrNull;

    if (returning != null && returning.isNotEmpty) {
      if (returning.length == 1) {
        return returning.values.first;
      }

      var idFieldName = sql.idFieldName;
      if (idFieldName != null) {
        var id = returning[idFieldName];
        if (id != null) return id;
      }

      return returning.values.first;
    }

    // No `RETURNING` row (e.g. a table with a non-`rowid` primary key):
    var lastInsertRowId = connection.lastInsertRowId;
    return lastInsertRowId != 0 ? lastInsertRowId : null;
  }

  @override
  Object resolveError(
    Object error,
    StackTrace stackTrace,
    Object? operation,
    Object? previousError,
  ) {
    if (error is DBSQLiteAdapterException) {
      return error;
    }

    SQL? failedSQL;
    if (error is _SQLiteStatementException) {
      failedSQL = error.sql;
      error = error.error;
    }

    if (error is SqliteException) {
      var extendedCode = error.extendedResultCode;

      // SQLITE_CONSTRAINT_UNIQUE / SQLITE_CONSTRAINT_PRIMARYKEY:
      if (extendedCode == 2067 || extendedCode == 1555) {
        var (tableName, fieldName) = _parseConstraintTableField(error.message);

        return EntityFieldInvalid(
          "unique",
          _invalidValue(failedSQL, fieldName, error),
          tableName: tableName,
          fieldName: fieldName,
          parentError: error,
          parentStackTrace: stackTrace,
          previousError: previousError,
          operation: operation,
        );
      }

      // SQLITE_CONSTRAINT_FOREIGNKEY:
      if (extendedCode == 787) {
        return DBSQLiteAdapterException(
          'delete.constraint',
          error.message,
          parentError: error,
          parentStackTrace: stackTrace,
          previousError: previousError,
          operation: operation,
        );
      }

      // SQLITE_CONSTRAINT_NOTNULL:
      if (extendedCode == 1299) {
        var (tableName, fieldName) = _parseConstraintTableField(error.message);

        return EntityFieldInvalid(
          "null",
          _invalidValue(failedSQL, fieldName, error),
          tableName: tableName,
          fieldName: fieldName,
          parentError: error,
          parentStackTrace: stackTrace,
          previousError: previousError,
          operation: operation,
        );
      }

      // SQLITE_CONSTRAINT_CHECK: a value outside an emulated `ENUM`.
      // Note SQLite's CHECK message quotes the expression
      // ("CHECK constraint failed: t IN ('a','b')"), not `table.column`, so
      // `_parseConstraintTableField` yields nulls here.
      if (extendedCode == 275) {
        var (tableName, fieldName) = _parseConstraintTableField(error.message);

        return EntityFieldInvalid(
          "check",
          error.message,
          tableName: tableName,
          fieldName: fieldName,
          parentError: error,
          parentStackTrace: stackTrace,
          previousError: previousError,
        );
      }
    }

    return DBSQLiteAdapterException(
      'error',
      '$error',
      parentError: error,
      parentStackTrace: stackTrace,
      previousError: previousError,
      operation: operation,
    );
  }

  /// SQLite constraint messages name the offending columns as
  /// `UNIQUE constraint failed: table.column[, table.column]`.
  static final RegExp _regExpConstraintField = RegExp(
    r'constraint failed:\s*(\w+)\.(\w+)',
    caseSensitive: false,
  );

  static (String?, String?) _parseConstraintTableField(String message) {
    var match = _regExpConstraintField.firstMatch(message);
    if (match == null) return (null, null);
    return (match[1], match[2]);
  }

  /// The value that violated a constraint.
  ///
  /// Unlike PostgreSQL (`Key (email)=(joe@…) already exists`) and MySQL
  /// (`Duplicate entry 'joe@…' for key …`), SQLite's message only names
  /// `table.column`, so the value is recovered from the statement's bound
  /// parameters (keyed by field name). Falls back to the driver message.
  static Object? _invalidValue(
    SQL? sql,
    String? fieldName,
    SqliteException error,
  ) {
    if (sql != null && fieldName != null) {
      var parameters = sql.parametersByPlaceholder;
      if (parameters.containsKey(fieldName)) return parameters[fieldName];
    }
    return error.message;
  }

  // -------------------------------------------------------------------------
  // Transactions.
  // -------------------------------------------------------------------------

  @override
  Future<DBSQLiteConnectionWrapper> openTransaction(Transaction transaction) {
    var contextCompleter = Completer<DBSQLiteConnectionWrapper>();

    var result = executeWithPool(
      (connection) {
        return connection.openTransaction((transactionWrap) {
          contextCompleter.complete(transactionWrap);

          return _runTransaction(transaction, connection);
        });
      },
      validator: (c) => !transaction.isAborted,
      onError: (e, s) => transaction.notifyExecutionError(
        e,
        s,
        errorResolver: resolveError,
        debugInfo: () => transaction.toString(withExecutedOperations: false),
      ),
    );

    transaction.transactionResult = result;

    return contextCompleter.future;
  }

  /// Unlike the PostgreSQL/MySQL drivers, SQLite has no `runTx` helper that
  /// commits or rolls back around a callback, so the `COMMIT`/`ROLLBACK` is
  /// driven by [_DBSQLiteConnectionWrapped.openTransaction] and this must let
  /// the error escape to it.
  ///
  /// Note that [resolveTransactionResult] is what throws on an aborted
  /// transaction (since [throwTransactionResultWithError] is `true`), so it has
  /// to be inside the same `try` as [Transaction.transactionFuture] — a
  /// `.then(onValue, onError:)` pair would not catch it.
  Future<Object?> _runTransaction(
    Transaction transaction,
    DBSQLiteConnectionWrapper connection,
  ) async {
    var res = await transaction.transactionFuture;
    return await resolveTransactionResult(res, transaction, connection);
  }

  @override
  bool get cancelTransactionResultWithError => false;

  @override
  bool get throwTransactionResultWithError => true;

  @override
  bool cancelTransaction(
    Transaction transaction,
    DBSQLiteConnectionWrapper? connection,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // The `ROLLBACK` is issued by `_DBSQLiteConnectionWrapped.openTransaction`
    // when the transaction block throws.
    return true;
  }

  @override
  bool get callCloseTransactionRequired => false;

  @override
  FutureOr<void> closeTransaction(
    Transaction transaction,
    DBSQLiteConnectionWrapper? connection,
  ) {}

  @override
  String toString() {
    var closedStr = isClosed ? ', closed' : '';
    var modeStr = inMemory ? 'memory' : databasePath;
    return 'DBSQLiteAdapter#$instanceID{$modeStr$closedStr}';
  }
}

/// A [DBSQLiteAdapter] connection wrapper.
abstract class DBSQLiteConnectionWrapper extends DBConnectionWrapper<Database> {
  DBSQLiteConnectionWrapper(super.nativeConnection);

  /// Runs [sql] and returns its rows.
  ResultSet select(String sql, [List<Object?>? parameters]);

  /// Runs [sql] discarding any rows.
  void execute(String sql, [List<Object?>? parameters]);

  /// The `rowid` of the most recent successful insert.
  int get lastInsertRowId;

  /// The number of rows changed by the most recent statement.
  int get updatedRows;

  /// Runs [queryBlock] inside a SQL transaction.
  Future openTransaction(
    Future Function(DBSQLiteConnectionWrapper connectionTransaction) queryBlock,
  );

  bool _nativeClosed = false;

  @override
  bool isClosedImpl() => _nativeClosed;

  /// Only marks this wrapper closed: the native [Database] is shared by every
  /// wrapper and is owned (and disposed) by [DBSQLiteAdapter].
  @override
  void closeImpl() {
    _nativeClosed = true;
  }
}

class _DBSQLiteConnectionWrapped extends DBSQLiteConnectionWrapper {
  final DBSQLiteAdapter _adapter;

  _DBSQLiteConnectionWrapped(super.nativeConnection, this._adapter);

  @override
  String get connectionURL => 'sqlite://${_adapter.databasePath}';

  @override
  ResultSet select(String sql, [List<Object?>? parameters]) {
    updateLastAccessTime();
    return nativeConnection.select(
      sql,
      DBSQLiteAdapter._normalizeParameters(parameters),
    );
  }

  @override
  void execute(String sql, [List<Object?>? parameters]) {
    updateLastAccessTime();
    nativeConnection.execute(
      sql,
      DBSQLiteAdapter._normalizeParameters(parameters),
    );
  }

  @override
  int get lastInsertRowId => nativeConnection.lastInsertRowId;

  @override
  int get updatedRows => nativeConnection.updatedRows;

  static int _savePointCount = 0;

  @override
  Future openTransaction(
    Future Function(DBSQLiteConnectionWrapper connectionTransaction) queryBlock,
  ) async {
    updateLastAccessTime();

    // Every wrapper shares one native handle, so a plain `BEGIN` issued while
    // another transaction is already open would fail with "cannot start a
    // transaction within a transaction". `SAVEPOINT` nests, so use it whenever
    // the handle is already in a transaction (`autocommit` is `false`).
    var nested = !nativeConnection.autocommit;
    var savePoint = nested ? 'bones_api_sp_${++_savePointCount}' : null;

    if (savePoint != null) {
      nativeConnection.execute('SAVEPOINT "$savePoint"');
    } else {
      // `IMMEDIATE` takes the write lock upfront: a deferred transaction would
      // only try to upgrade on its first write, which can fail mid-transaction
      // when another *process* holds the database file.
      nativeConnection.execute(_adapter.inMemory ? 'BEGIN' : 'BEGIN IMMEDIATE');
    }

    try {
      var result = await queryBlock(_DBSQLiteConnectionTransaction(this));

      nativeConnection.execute(
        savePoint != null ? 'RELEASE "$savePoint"' : 'COMMIT',
      );

      return result;
    } catch (_) {
      try {
        if (savePoint != null) {
          nativeConnection
            ..execute('ROLLBACK TO "$savePoint"')
            ..execute('RELEASE "$savePoint"');
        } else {
          nativeConnection.execute('ROLLBACK');
        }
      } catch (_) {}
      rethrow;
    }
  }

  @override
  String get info => 'db: ${_adapter.databasePath}, closed: $isClosed';

  @override
  String get runtimeTypeNameSafe => '_DBSQLiteConnectionWrapped';
}

class _DBSQLiteConnectionTransaction extends DBSQLiteConnectionWrapper {
  final _DBSQLiteConnectionWrapped parent;

  _DBSQLiteConnectionTransaction(this.parent) : super(parent.nativeConnection);

  @override
  String get connectionURL => parent.connectionURL;

  @override
  ResultSet select(String sql, [List<Object?>? parameters]) =>
      parent.select(sql, parameters);

  @override
  void execute(String sql, [List<Object?>? parameters]) =>
      parent.execute(sql, parameters);

  @override
  int get lastInsertRowId => parent.lastInsertRowId;

  @override
  int get updatedRows => parent.updatedRows;

  // SQLite has no nested transactions: re-enter the current one (same as the
  // MySQL adapter).
  @override
  Future openTransaction(
    Future Function(DBSQLiteConnectionWrapper connectionTransaction) queryBlock,
  ) => queryBlock(this);

  @override
  String get runtimeTypeNameSafe => '_DBSQLiteConnectionTransaction';
}

/// Pairs a [SqliteException] with the [SQL] that caused it.
///
/// SQLite's constraint messages only name `table.column`, so
/// [DBSQLiteAdapter.resolveError] needs the statement's bound parameters to
/// report *which value* was rejected.
class _SQLiteStatementException implements Exception {
  final SqliteException error;
  final SQL sql;

  _SQLiteStatementException(this.error, this.sql);

  @override
  String toString() => '$error\nCausing SQL: $sql';
}

/// Exception thrown by [DBSQLiteAdapter] operations.
class DBSQLiteAdapterException extends DBSQLAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBSQLiteAdapterException';

  DBSQLiteAdapterException(
    super.type,
    super.message, {
    super.parentError,
    super.parentStackTrace,
    super.operation,
    super.previousError,
  });
}

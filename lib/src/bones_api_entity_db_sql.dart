import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';
import 'package:swiss_knife/swiss_knife.dart' show parseBool;

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';
import 'bones_api_condition_sql.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_annotation.dart';
import 'bones_api_entity_db.dart';
import 'bones_api_entity_db_memory.dart';
import 'bones_api_entity_db_relational.dart';
import 'bones_api_entity_reference.dart';
import 'bones_api_extension.dart';
import 'bones_api_initializable.dart';
import 'bones_api_logging.dart';
import 'bones_api_platform.dart';
import 'bones_api_sql_builder.dart';
import 'bones_api_types.dart';
import 'bones_api_utils_collections.dart';
import 'bones_api_utils_json.dart';

export 'bones_api_entity_db.dart' show DBAdapterCapabilityConnectivity;

final _log = logging.Logger('SQLAdapter')..registerAsDbLogger();

/// Represents a SQL JOIN fragment with explicit alias dependencies.
///
/// - [defs]: Aliases **defined** (introduced) by this JOIN.
/// - [refs]: Aliases **referenced** by this JOIN (typically in the ON clause).
/// - [join]: The rendered JOIN SQL snippet.
typedef _JoinEntry = ({List<String> defs, List<String> refs, String join});

extension on _JoinEntry {
  bool refsResolved(Set<String> resolved) => refs.every(resolved.contains);
}

extension on List<_JoinEntry> {
  /// Sorts JOIN entries so that alias dependency order is respected.
  ///
  /// Ensures that every JOIN appears **after** all aliases it references
  /// are already available, producing a valid SQL JOIN sequence whenever
  /// possible.
  ///
  /// - [initialAliases] are aliases already defined by the FROM clause.
  ///
  /// This performs a dependency-aware (topological) sort:
  /// - Iteratively selects JOINs whose [refs] are fully resolved
  /// - Appends them in a valid order
  /// - Accumulates newly defined aliases from [defs]
  ///
  /// If unresolved or circular dependencies are detected, the remaining
  /// JOINs are appended in their original order and the method returns
  /// `false`.
  ///
  /// Returns `true` if all JOIN dependencies were fully resolved and
  /// ordered correctly, or `false` if a best-effort fallback order was used.
  bool sortJoins(Set<String> initialAliases) {
    final List<_JoinEntry> joins = this;
    // No ordering needed for zero JOINs:
    if (joins.isEmpty) {
      return true;
    }
    // No ordering needed for a single JOIN; only check if it is resolved:
    else if (joins.length == 1) {
      var resolved = joins.first.refsResolved(initialAliases);
      return resolved;
    }

    // Aliases currently available for reference.
    final resolved = <String>{...initialAliases};
    // JOINs not yet placed in the final order.
    final pending = List<_JoinEntry>.from(joins);

    // Clear and rebuild the list in dependency-safe order.
    joins.clear();

    while (pending.isNotEmpty) {
      // Find a JOIN whose referenced aliases are all resolved.
      final index = pending.indexWhere((j) => j.refsResolved(resolved));

      // No JOIN can be resolved → missing alias or circular dependency.
      if (index == -1) {
        // Append remaining JOINs as-is, preserving input order.
        joins.addAll(pending);
        // Not fully resolved; fallback ordering was applied.
        return false;
      }

      // Move the resolvable JOIN to the final list.
      final resolvedJoin = pending.removeAt(index);
      joins.add(resolvedJoin);

      // Register aliases defined by this JOIN.
      resolved.addAll(resolvedJoin.defs);
    }

    // Fully resolved dependency order.
    return true;
  }
}

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
/// This is used by a [DBSQLAdapter] to execute queries.
class SQL implements SQLWrapper {
  static final SQL dummy = SQL(
    'dummy',
    <dynamic>[],
    <String, dynamic>{},
    <String, dynamic>{},
    mainTable: '_',
  );

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

  final int? limit;

  /// The return offset of this select (`OFFSET`), or `null` for no offset.
  final int? offset;

  /// If this select is ordered by the table ID column. `null` means unset:
  /// the generated SQL orders by ID when there's an `OFFSET` or a `LIMIT`
  /// (see [OrderDirection.resolveOrderByID]); `DBSQLMemoryAdapter` orders
  /// only with an `OFFSET` (its rows are already in insertion order).
  final bool? orderByID;

  /// The [OrderDirection] of the ordering.
  /// Only applies while the ordering is active. See [orderByID].
  final OrderDirection? orderDirection;

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

  bool get hasPreSQL {
    var preSQL = this.preSQL;
    return preSQL != null && preSQL.isNotEmpty;
  }

  bool get hasPosSQL {
    var posSQL = this.posSQL;
    return posSQL != null && posSQL.isNotEmpty;
  }

  bool get hasPreOrPosSQL => hasPreSQL || hasPosSQL;

  SQL(
    this.sql,
    this.positionalParameters,
    this.namedParameters,
    this.parametersByPlaceholder, {
    this.sqlCondition,
    String? sqlPositional,
    List<String>? parametersKeysByPosition,
    List<Object?>? parametersValuesByPosition,
    this.condition,
    this.entityName,
    this.idFieldName,
    this.returnColumns,
    this.returnColumnsAliases,
    this.limit,
    this.offset,
    this.orderByID,
    this.orderDirection,
    required this.mainTable,
    this.relationship,
    this.tablesAliases,
    RegExp? placeholderRegexp,
  }) : _sqlPositional = sqlPositional,
       _parametersKeysByPosition = parametersKeysByPosition,
       _parametersValuesByPosition = parametersValuesByPosition,
       placeholderRegexp = placeholderRegexp ?? _defaultPlaceholderRegexp;

  SQL copy() => SQL(
    sql,
    positionalParameters?.toList(),
    namedParameters?.map((k, v) => MapEntry(k, v)),
    parametersByPlaceholder.map((k, v) => MapEntry(k, v)),
    sqlCondition: sqlCondition,
    sqlPositional: _sqlPositional,
    parametersKeysByPosition: _parametersKeysByPosition?.toList(),
    parametersValuesByPosition: _parametersValuesByPosition?.toList(),
    condition: condition,
    entityName: entityName,
    idFieldName: idFieldName,
    returnColumns: returnColumns?.toSet(),
    returnColumnsAliases: returnColumnsAliases?.map((k, v) => MapEntry(k, v)),
    limit: limit,
    offset: offset,
    orderByID: orderByID,
    orderDirection: orderDirection,
    mainTable: mainTable,
    relationship: relationship,
    tablesAliases: tablesAliases?.map((k, v) => MapEntry(k, v)),
    placeholderRegexp: placeholderRegexp,
  );

  /// Ensures that this is not the [dummy] instance.
  /// Returns a [copy] if necessary.
  SQL ensureNotSharedDummy() => identical(this, dummy) ? copy() : this;

  /// Returns `true` if this is the [dummy] instance.
  /// See [ensureNotSharedDummy].
  bool get isSharedDummy => identical(this, dummy);

  bool get isDummy => identical(this, dummy) || sql == 'dummy';

  bool get isFullyDummy => isDummy && !hasPreOrPosSQL;

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

    // With the default placeholder, the positional SQL and its keys depend
    // only on the SQL text: computed once per text (the same statements
    // repeat), and only the values are resolved per instance.
    var cacheable = identical(placeholderRegexp, _defaultPlaceholderRegexp);

    var cached = cacheable ? _positionalCache[sql] : null;

    String sqlPositional;
    if (cached != null) {
      sqlPositional = cached.$1;
      keys = cached.$2;
      for (var k in keys) {
        values.add(parametersByPlaceholder[k]);
      }
    } else {
      sqlPositional = sql.replaceAllMapped(placeholderRegexp, (m) {
        var k = m.group(1)!;
        var v = parametersByPlaceholder[k];
        keys.add(k);
        values.add(v);
        return '?';
      });

      if (cacheable) {
        if (_positionalCache.length >= _positionalCacheLimit) {
          _positionalCache.clear();
        }
        _positionalCache[sql] = (sqlPositional, List.unmodifiable(keys));
      }
    }

    _sqlPositional ??= sqlPositional;

    _parametersKeysByPosition ??= keys;
    _parametersValuesByPosition ??= values;
  }

  /// [sqlPositional] and [parametersKeysByPosition] by SQL text (default
  /// placeholder only). Cleared when it reaches [_positionalCacheLimit]
  /// (e.g. SQLs with inlined values, all different).
  static final Map<String, (String, List<String>)> _positionalCache = {};

  static const int _positionalCacheLimit = 2000;

  @override
  String toString() {
    var s = StringBuffer();

    s.write('SQL<< ');
    s.write(sql);
    s.write(' >>( ');
    s.write(Json.encode(parametersByPlaceholder, toEncodable: _toEncodable));
    s.write(' )');

    if (condition != null) {
      s.write(' ; Condition<< ');
      s.write(condition);
      s.write(' >>');
    }
    if (entityName != null) {
      s.write(' ; entityName: ');
      s.write(entityName);
    }
    if (mainTable != null) {
      s.write(' ; mainTable: ');
      s.write(mainTable);
    }
    if (relationship != null) {
      s.write(' (');
      s.write(relationship);
      s.write(')');
    }
    if (returnColumns != null && returnColumns!.isNotEmpty) {
      s.write(' ; returnColumns: ');
      s.write(returnColumns);
    }

    if (returnColumnsAliases != null && returnColumnsAliases!.isNotEmpty) {
      s.write(' ; returnColumnsAliases: ');
      s.write(returnColumnsAliases);
    }

    if (preSQL != null) {
      s.write('\n - preSQL: ');
      s.write(preSQL);
    }

    if (posSQL != null) {
      s.write('\n - posSQL: ');
      s.write(posSQL);
    }

    return s.toString();
  }

  Object? _toEncodable(dynamic o) {
    try {
      return Json.toJson(o);
    } catch (e) {
      return '$o';
    }
  }
}

/// [DBSQLAdapter] capabilities.
class DBSQLAdapterCapability extends DBAdapterCapability {
  /// `true` if the adapter supports table SQLs.
  /// See [DBSQLAdapter.populateTables].
  final bool tableSQL;

  const DBSQLAdapterCapability({
    required super.dialect,
    required super.transactions,
    required super.transactionAbort,
    required super.constraintSupport,
    required this.tableSQL,
    required super.multiIsolateSupport,
    required super.connectivity,
  });

  @override
  String get info => '${super.info}, tableSQL: $tableSQL';

  @override
  String get runtimeTypeNameSafe => 'DBSQLAdapterCapability';
}

typedef DBSQLAdapterInstantiator<C extends Object, A extends DBSQLAdapter<C>> =
    DBAdapterInstantiator<C, A>;

/// Base class for SQL DB adapters.
///
/// A [DBSQLAdapter] implementation is responsible to connect to the database and
/// adjust the generated `SQL`s to the correct dialect.
///
/// All [DBSQLAdapter]s comes with a built-in connection pool.
abstract class DBSQLAdapter<C extends Object> extends DBRelationalAdapter<C>
    with SQLGenerator {
  static bool _boot = false;

  static void boot() {
    if (_boot) return;
    _boot = true;

    DBAdapter.boot();
    DBRelationalAdapter.boot();
    DBSQLMemoryAdapter.boot();
  }

  static final DBAdapterRegister<Object, DBSQLAdapter<Object>> adapterRegister =
      DBRelationalAdapter.adapterRegister.createRegister();

  static List<String> get registeredAdaptersNames =>
      adapterRegister.registeredAdaptersNames;

  static List<Type> get registeredAdaptersTypes =>
      adapterRegister.registeredAdaptersTypes;

  static void registerAdapter<C extends Object, A extends DBSQLAdapter<C>>(
    List<String> names,
    Type type,
    DBSQLAdapterInstantiator<C, A> adapterInstantiator,
  ) {
    boot();
    adapterRegister.registerAdapter(names, type, adapterInstantiator);
  }

  static DBSQLAdapterInstantiator<C, A>?
  getAdapterInstantiator<C extends Object, A extends DBSQLAdapter<C>>({
    String? name,
    Type? type,
  }) => adapterRegister.getAdapterInstantiator<C, A>(name: name, type: type);

  static List<MapEntry<DBSQLAdapterInstantiator<C, A>, Map<String, dynamic>>>
  getAdapterInstantiatorsFromConfig<
    C extends Object,
    A extends DBSQLAdapter<C>
  >(Map<String, dynamic> config) =>
      adapterRegister.getAdapterInstantiatorsFromConfig<C, A>(config);

  static bool? parseConfigLogSQL(Map<String, dynamic>? config) {
    var logSql = config?.getIgnoreCase('log.sql');
    if (logSql != null) {
      return parseBool(logSql);
    }

    var log = config?['log'];

    if (log is Map) {
      var logSql = log.getIgnoreCase('sql');
      if (logSql != null) {
        return parseBool(logSql);
      }
    }
    if (log != null) {
      return parseBool(log);
    }

    return null;
  }

  static ({bool generateTables, bool checkTables})
  parseConfigDBGenerateTablesAndCheckTables(Map<String, dynamic>? config) {
    bool? checkTables;
    bool? generateTables;

    const generateTablesKeys = [
      'generateTables',
      'generate-tables',
      'generate_tables',
    ];

    const checkTablesKeys = ['checkTables', 'check-tables', 'check_tables'];

    generateTables = config?.getMultiKeyAsBool(
      generateTablesKeys,
      ignoreCase: true,
    );

    checkTables = config?.getMultiKeyAsBool(checkTablesKeys, ignoreCase: true);

    if (generateTables == null || checkTables == null) {
      var populate = config?['populate'];

      if (populate is Map) {
        generateTables ??= populate.getMultiKeyAsBool(
          generateTablesKeys,
          ignoreCase: true,
        );

        checkTables ??= populate.getMultiKeyAsBool(
          checkTablesKeys,
          ignoreCase: true,
        );
      }
    }

    generateTables ??= false;
    checkTables ??= true;

    return (generateTables: generateTables, checkTables: checkTables);
  }

  /// The [DBSQLAdapter] capability.
  @override
  DBSQLAdapterCapability get capability =>
      super.capability as DBSQLAdapterCapability;

  final bool logSQL;

  int _executedSQLsCount = 0;

  /// The number of SQL statements this adapter has executed for entity and
  /// relationship operations (selects, inserts, updates, deletes, counts),
  /// since it was created.
  ///
  /// Each one is a round trip to the database. Transaction control
  /// (`BEGIN`/`COMMIT`), table creation and checks aren't counted.
  ///
  /// It's cumulative and shared by concurrent operations: to measure an
  /// operation, take the difference before and after it, with nothing else
  /// running on this adapter.
  int get executedSQLsCount => _executedSQLsCount;

  /// Whether an ID generated by an insert never has relationship rows: the
  /// database never reuses generated IDs (e.g. a sequence), so no rows of a
  /// deleted entity can refer to it.
  ///
  /// Then storing the relationships of a just inserted entity skips the
  /// `DELETE` of its other relationship rows (there are none): one
  /// statement (round trip) less per relationship field. Default: `false`.
  bool get generatedIDsHaveNoRelationships => false;

  late final ConditionSQLEncoder _conditionSQLGenerator;

  DBSQLAdapter(
    super.name,
    super.minConnections,
    super.maxConnections,
    DBSQLAdapterCapability super.capability, {
    bool generateTables = false,
    bool checkTables = true,
    Object? populateTables,
    super.parentRepositoryProvider,
    super.connectivity,
    super.populateSource,
    super.populateSourceVariables,
    super.workingPath,
    this.logSQL = false,
  }) : _generateTables = generateTables,
       _checkTables = checkTables,
       _populateTables = populateTables {
    boot();

    _conditionSQLGenerator = ConditionSQLEncoder(
      this,
      sqlElementQuote: dialect.elementQuote,
    );
  }

  static FutureOr<A> fromConfig<C extends Object, A extends DBSQLAdapter<C>>(
    Map<String, dynamic> config, {
    int minConnections = 1,
    int maxConnections = 3,
    EntityRepositoryProvider? parentRepositoryProvider,
    String? workingPath,
  }) {
    boot();

    var instantiators = getAdapterInstantiatorsFromConfig<C, A>(config);

    if (instantiators.isEmpty) {
      throw StateError(
        "Can't find `$A` instantiator for `config` keys: ${config.keys.toList()}",
      );
    }

    return DBAdapter.instantiateAdaptor<C, A>(
      instantiators,
      config,
      minConnections: minConnections,
      maxConnections: maxConnections,
      parentRepositoryProvider: parentRepositoryProvider,
      workingPath: workingPath,
    );
  }

  bool _generateTables;
  bool _generatedTables = false;

  /// Return `true` if DB tables where successfully generated.
  /// - [generateTables] is only called if `generateTables: true` is passed to the constructor.
  bool get generatedTables => _generatedTables;

  @override
  FutureOr<bool> checkDB() {
    if (_generateTables && !DBAdapter.auxiliaryMode) {
      _generateTables = false;

      return generateTables().resolveMapped((tables) {
        tables.sort();
        _log.info("Generated tables: $tables");
        return checkDBTables();
      });
    }

    _generateTables = false;
    return checkDBTables();
  }

  bool _checkTables;
  bool _checkedTables = false;

  /// Return `true` if DB tables where successfully checked.
  /// - [checkDBTables] is only called if `checkTables: true` is passed to the constructor.
  bool get checkedTables => _checkedTables;

  final Map<String, TableDuplicates> _tablesDuplicates =
      <String, TableDuplicates>{};

  /// The tables with duplicated indexes or `CHECK` constraints found by the
  /// last [checkDBTables], by table name. Only warned: never an error.
  Map<String, TableDuplicates> get tablesDuplicates =>
      Map<String, TableDuplicates>.unmodifiable(_tablesDuplicates);

  /// The duplicated indexes (over the same columns, in the same order, of
  /// the same kind: [TableScheme.indexesKinds]) and enum `CHECK` constraints
  /// (over the same column) of [scheme]: each group with the one to keep
  /// first, and the suggested SQLs to drop the others.
  ///
  /// - The index kept: the primary key ([TableScheme.primaryKeyIndex]; if
  ///   unknown, by its name: `PRIMARY`, `<table>_pkey`) or a SQLite
  ///   constraint's index (`sqlite_autoindex_*`: can't be dropped), else a
  ///   unique one (the default name, `<table>__<columns>__unique`, first),
  ///   else the default name (`<table>__<columns>__idx`), else the first by
  ///   name.
  /// - The `CHECK` kept: the one with exactly the values of
  ///   [entityHandler]'s enum field, else one with all of them (and others),
  ///   else a default name (PostgreSQL's `<table>_<column>_check`, or the
  ///   `<table>_<column>__check` added by `checkTables`' suggestion), else
  ///   the first by name.
  TableDuplicates findTableDuplicates(
    TableScheme scheme, {
    EntityHandler? entityHandler,
  }) {
    var table = scheme.name;
    var indexes = scheme.indexes ?? const <String, List<String>>{};
    var uniqueIndexes = scheme.uniqueIndexes ?? const <String>{};
    var primaryKeyIndex = scheme.primaryKeyIndex;

    bool isPrimaryKey(String name) => primaryKeyIndex != null
        ? name == primaryKeyIndex
        : name == 'PRIMARY' || name == '${table}_pkey';

    int indexRank(String name) {
      // The primary key, or a constraint's index (SQLite: can't be dropped):
      if (isPrimaryKey(name) || name.startsWith('sqlite_autoindex_')) {
        return 0;
      }
      var unique = uniqueIndexes.contains(name);
      var isDefaultName =
          name ==
          EntityIndex.defaultName(
            table,
            indexes[name] ?? const <String>[],
            maxLength: dialect.maxIdentifierLength,
            unique: unique,
          );
      if (unique) return isDefaultName ? 1 : 2;
      return isDefaultName ? 3 : 4;
    }

    var dropSQLs = <String>[];

    // MySQL `SERIAL` (`... AUTO_INCREMENT UNIQUE`): with `PRIMARY KEY`, the
    // `PRIMARY` key and a unique index over its column, named as it. Of the
    // generated `CREATE TABLE` itself: not reported.
    bool isSerialUniqueIndex(List<String> group, String name) {
      if (!group.any(isPrimaryKey) ||
          isPrimaryKey(name) ||
          !uniqueIndexes.contains(name)) {
        return false;
      }
      var columns = indexes[name];
      return columns != null && columns.length == 1 && columns[0] == name;
    }

    var duplicatedIndexes = <List<String>>[];
    for (var group in scheme.duplicatedIndexes ?? const <List<String>>[]) {
      var reported = group
          .whereNot((name) => isSerialUniqueIndex(group, name))
          .toList();
      if (reported.length < 2) continue;

      var names = _sortedByRank(reported, indexRank);
      duplicatedIndexes.add(names);

      dropSQLs.add(
        '-- `$table` (${indexes[names.first]?.join(', ')}): '
        'keeping `${names.first}`:',
      );

      for (var name in names.skip(1)) {
        if (name.startsWith('sqlite_autoindex_')) {
          dropSQLs.add("-- `$name`: a constraint's index: can't be dropped");
          continue;
        }

        if (uniqueIndexes.contains(name)) {
          dropSQLs.add(
            "-- `$name` is unique: if a foreign key references it, the drop "
            "fails (drop the foreign key first; `CASCADE` drops it too)",
          );
          // A constraint's index can only be dropped with the constraint:
          if (!dialect.dropIndexOnTable && dialect.alterTableAddConstraint) {
            dropSQLs.add(generateDropConstraintSQL(table, name));
          }
        }

        dropSQLs.add(generateDropIndexSQL(table, name));
      }
    }

    var checkConstraints =
        scheme.checkConstraints ?? const <String, TableEnumConstraint>{};

    var schemeToRepoMap = entityHandler == null
        ? null
        : _schemeToRepoFieldsMap(scheme, entityHandler);

    var duplicatedChecks = <String, List<String>>{};
    for (var e
        in (scheme.duplicatedCheckConstraints ?? const <String, List<String>>{})
            .entries) {
      var column = e.key;

      var entityValues = entityHandler == null
          ? null
          : _columnEnumValues(entityHandler, column, schemeToRepoMap!);

      bool hasAllValues(String name) {
        var values = checkConstraints[name]?.values;
        return entityValues != null &&
            values != null &&
            values.containsAll(entityValues);
      }

      int checkRank(String name) {
        if (hasAllValues(name)) {
          var values = checkConstraints[name]!.values;
          return values.length == entityValues!.length ? 0 : 1;
        }
        var lc = name.toLowerCase();
        var prefix = '${table}_$column'.toLowerCase();
        return lc == '${prefix}_check' || lc == '${prefix}__check' ? 2 : 3;
      }

      var names = _sortedByRank(e.value, checkRank);
      duplicatedChecks[column] = names;

      dropSQLs.add(
        '-- `$table`.`$column`: keeping `${names.first}` '
        '${checkConstraints[names.first]?.values}:',
      );

      if (entityValues != null && !hasAllValues(names.first)) {
        dropSQLs.add(
          "-- none has the entity's values $entityValues: review before "
          "dropping",
        );
      }

      for (var name in names.skip(1)) {
        dropSQLs.add(
          '${generateDropConstraintSQL(table, name)}  -- '
          '${checkConstraints[name]?.values}',
        );
      }
    }

    return TableDuplicates(
      table,
      indexes: duplicatedIndexes,
      checkConstraints: duplicatedChecks,
      dropSQLs: dropSQLs,
    );
  }

  /// [names] sorted by [rank], then by name.
  static List<String> _sortedByRank(
    Iterable<String> names,
    int Function(String name) rank,
  ) => names.sorted((a, b) {
    var cmp = rank(a).compareTo(rank(b));
    return cmp != 0 ? cmp : a.compareTo(b);
  });

  /// The hidden fields of [entityHandler] (`EntityField.hidden()`).
  static List<String> _entityHiddenFields(EntityHandler entityHandler) =>
      entityHandler
          .fieldsNames()
          .where((f) {
            var annotations = entityHandler.getFieldEntityAnnotations(null, f);
            return annotations != null &&
                annotations.any((a) => a is EntityField && a.isHidden);
          })
          .toList(growable: false);

  /// The table's columns of [scheme] to the (not hidden) fields of
  /// [entityHandler] (`null`: not a field), as `checkTables` maps them.
  static Map<String, String?> _schemeToRepoFieldsMap(
    TableScheme scheme,
    EntityHandler entityHandler, {
    List<String>? hiddenFields,
  }) {
    hiddenFields ??= _entityHiddenFields(entityHandler);

    var repoFieldsMap = entityHandler
        .fieldsNames()
        .whereNotIn(hiddenFields)
        .map((f) => MapEntry(f, f))
        .toMapFromEntries();

    return scheme.getFieldsKeysInMap(scheme.fieldsNames, repoFieldsMap);
  }

  /// The values of the enum field of [entityHandler] of the table's
  /// [column] (any case): the field mapped to it ([schemeToRepoMap], as
  /// `checkTables` maps them), else the field resolved by name, else
  /// [column]. `null` if it isn't an enum field.
  static Set<String>? _columnEnumValues(
    EntityHandler entityHandler,
    String column,
    Map<String, String?> schemeToRepoMap,
  ) {
    var columnLC = column.toLowerCase();
    var mappedField =
        schemeToRepoMap[column] ??
        schemeToRepoMap.entries
            .firstWhereOrNull((e) => e.key.toLowerCase() == columnLC)
            ?.value;

    var fieldName =
        mappedField ??
        entityHandler.resolveFiledName(
          entityHandler.fieldsNames(),
          column,
          fieldsNamesIndexes: entityHandler.fieldsNamesIndexes(),
          fieldsNamesLC: entityHandler.fieldsNamesLC(),
          fieldsNamesSimple: entityHandler.fieldsNamesSimple(),
        ) ??
        column;

    var fieldType = entityHandler.getFieldType(
      null,
      fieldName,
      resolveFiledName: false,
    );
    if (fieldType == null) return null;

    var enumReflection = ReflectionFactory().getRegisterEnumReflection(
      fieldType.type,
    );
    return enumReflection?.valuesNames.toSet();
  }

  /// Warns (and keeps in [tablesDuplicates]) the duplicated indexes and
  /// `CHECK` constraints of the [repositorySchemes]' tables.
  void _warnTablesDuplicates(
    Map<EntityRepository<Object>, TableScheme?> repositorySchemes,
  ) {
    _tablesDuplicates.clear();

    for (var e in repositorySchemes.entries) {
      var scheme = e.value;
      if (scheme == null || _tablesDuplicates.containsKey(scheme.name)) {
        continue;
      }

      var duplicates = findTableDuplicates(
        scheme,
        entityHandler: e.key.entityHandler,
      );
      if (duplicates.isEmpty) continue;

      _tablesDuplicates[scheme.name] = duplicates;

      _log.warning(
        '$duplicates\n\nSuggestion of SQLs (`$dialectName`) to drop them '
        '(keeping the first of each):\n\n  ${duplicates.dropSQLs.join('\n  ')}\n',
      );
    }
  }

  /// The columns of the index (or unique constraint) [indexName] of [table],
  /// from its loaded scheme ([TableScheme.indexes]), e.g. to resolve a
  /// violated constraint's columns; `null` if unknown.
  List<String>? loadedIndexColumns(String? table, String? indexName) {
    if (table == null || indexName == null) return null;
    return getTableSchemeIfLoaded(table)?.indexes?[indexName];
  }

  /// Of [indexesNames], the ones in use where a new index of [table] would
  /// clash with them: by name, the table of the index using it (`null`: not
  /// an index, e.g. a table). Index names are unique per schema/database in
  /// PostgreSQL and SQLite (any table), but per table in MySQL.
  ///
  /// `null` if unknown (the default): only [TableScheme.indexes] (the same
  /// table) are checked.
  FutureOr<Map<String, String?>?> findIndexesNamesInUse(
    String table,
    Iterable<String> indexesNames,
  ) => null;

  /// Checks the DB tables against the entities (columns, references,
  /// constraints, enums and indexes, including `@EntityIndex`): throws a
  /// [StateError] with the SQLs to fix them when something is missing.
  ///
  /// Only once, and only with `checkTables: true`, unless [force] (e.g. to
  /// check again after a migration): all the loaded table schemes (also of
  /// referenced and relationship tables), fields types and references are
  /// then read again (a scheme load already in progress isn't restarted),
  /// and [checkedTables] is `false` until it passes.
  FutureOr<bool> checkDBTables({bool force = false}) {
    if (!_checkTables && !force) {
      _log.warning("Ignoring check of DB tables for $this.");
      return true;
    }

    if (force) {
      _checkedTables = false;
      disposeTablesSchemesCaches(fieldsTypes: true);
    }

    _checkTables = false;

    _log.info("Checking DB tables for $this> loading tables schemes...");

    var repositorySchemes = getRepositoriesSchemes();

    return repositorySchemes.resolveMapped(_checkDBTablesImpl);
  }

  FutureOr<bool> _checkDBTablesImpl(
    Map<EntityRepository<Object>, TableScheme?> repositorySchemes,
  ) {
    _warnTablesDuplicates(repositorySchemes);

    var repositoriesChecks = repositorySchemes.entries
        .map((e) => _checkDBTableScheme(e.key, e.value))
        .toList();

    return _checkEntityIndexesNamesInUse(
      repositoriesChecks,
    ).resolveMapped((_) => _checkDBTablesResults(repositoriesChecks));
  }

  /// Of the missing `@EntityIndex`es, the ones whose name is in use outside
  /// [TableScheme.indexes] (e.g. by another table's index, in PostgreSQL and
  /// SQLite): added to [_DBTableCheck.entityIndexesNameConflicts].
  FutureOr<bool> _checkEntityIndexesNamesInUse(
    List<_DBTableCheck> repositoriesChecks,
  ) {
    var checks = repositoriesChecks.where(
      (e) => e.scheme != null && (e.missingEntityIndexes?.isNotEmpty ?? false),
    );

    return checks
        .map((check) {
          var table = check.scheme!.name;
          var conflicts = check.entityIndexesNameConflicts ??= {};

          var names = check.missingEntityIndexes!
              .map((sql) => sql.indexName)
              .nonNulls
              .whereNot(conflicts.containsKey)
              .toList();
          if (names.isEmpty) return true;

          return findIndexesNamesInUse(table, names).resolveMapped((inUse) {
            if (inUse == null || inUse.isEmpty) return true;

            for (var e in inUse.entries) {
              var inUseTable = e.value;
              conflicts[e.key] = inUseTable == null
                  ? 'by another relation (not an index)'
                  : inUseTable == table
                  ? 'by an index not usable as it (partial, expression or prefix)'
                  : 'on table `$inUseTable`';
            }

            _log.severe(
              "Table `$table`: `@EntityIndex` names in use (drop them "
              "first): $inUse",
            );
            return true;
          });
        })
        .toList()
        .resolveAll()
        .resolveMapped((_) => true);
  }

  FutureOr<bool> _checkDBTablesResults(List<_DBTableCheck> repositoriesChecks) {
    var repositoriesChecksErrors = repositoriesChecks
        .where((e) => e.isError)
        .toList();

    if (repositoriesChecksErrors.isNotEmpty) {
      var missingColumnsSQLs = repositoriesChecksErrors
          .where((e) => e.missingColumns?.isNotEmpty ?? false)
          .expand((e) => e.generateMissingColumnsSQLs(this))
          .expand((e) => e.buildAllSQLs(ifNotExists: true, multiline: false))
          .toList();

      var missingReferenceColumnsSQLs = repositoriesChecksErrors
          .where((e) => e.missingReferenceColumns?.isNotEmpty ?? false)
          .expand((e) => e.generateMissingReferenceColumnsSQLs(this))
          .expand((e) => e.buildAllSQLs(ifNotExists: true, multiline: false))
          .toList();

      var missingReferenceConstraintsSQLs = repositoriesChecksErrors
          .where((e) => e.missingReferenceConstraints?.isNotEmpty ?? false)
          .expand((e) => e.generateMissingReferenceConstraintsSQLs(this))
          .expand((e) => e.buildAllSQLs(ifNotExists: true, multiline: false))
          .toList();

      var missingReferenceIndexesSQLs = repositoriesChecksErrors
          .where((e) => e.missingReferenceIndexes?.isNotEmpty ?? false)
          .expand((e) => e.generateMissingReferenceIndexesSQLs(this))
          .expand((e) => e.buildAllSQLs(ifNotExists: true, multiline: false))
          .toList();

      var missingRelationshipReferenceIndexesSQLs = repositoriesChecksErrors
          .where(
            (e) => e.missingRelationshipReferenceIndexes?.isNotEmpty ?? false,
          )
          .expand(
            (e) => e.generateMissingRelationshipReferenceIndexesSQLs(this),
          )
          .expand((e) => e.buildAllSQLs(ifNotExists: true, multiline: false))
          .toList();

      var missingUniqueConstraintsSQLs = repositoriesChecksErrors
          .where((e) => e.missingUniqueConstraints?.isNotEmpty ?? false)
          .expand((e) => e.generateMissingUniqueConstraintsSQLs(this))
          .expand((e) => e.buildAllSQLs(ifNotExists: true, multiline: false))
          .toList();

      var missingEnumConstraintsSQLs = repositoriesChecksErrors
          .where((e) => e.missingEnumConstraints?.isNotEmpty ?? false)
          .expand((e) => e.generateMissingEnumConstraintsSQLs(this))
          .expand((e) => e.buildAllSQLs(ifNotExists: true, multiline: false))
          .toList();

      var missingEnumValuesSQLs = repositoriesChecksErrors
          .where((e) => e.missingEnumValues?.isNotEmpty ?? false)
          .expand((e) => e.generateMissingEnumValuesSQLs(this))
          .expand((e) => e.buildAllSQLs(ifNotExists: true, multiline: false))
          .toList();

      var missingEntityIndexesSQLs = repositoriesChecksErrors
          .where((e) => e.missingEntityIndexes?.isNotEmpty ?? false)
          .expand(
            (e) => e.missingEntityIndexes!.expand((sql) {
              var conflict = e.entityIndexesNameConflicts?[sql.indexName];
              var conflictComment = conflict == null
                  ? null
                  : '-- `${sql.indexName}` in use $conflict: drop it first:';

              // A unique one: a constraint, as in the `CREATE TABLE`
              // (SQLite: a unique index).
              var fixSQL = sql.unique
                  ? generateAddUniqueConstraintSQL(
                      sql.table,
                      sql.indexName!,
                      sql.columns,
                    )
                  : sql;

              return [
                ?conflictComment,
                ...fixSQL.buildAllSQLs(ifNotExists: true, multiline: false),
              ];
            }),
          )
          .toList();

      var alterTablesSQLs = [
        ...missingColumnsSQLs,
        '',
        ...missingReferenceColumnsSQLs,
        '',
        ...missingReferenceConstraintsSQLs,
        '',
        ...missingReferenceIndexesSQLs,
        '',
        ...missingRelationshipReferenceIndexesSQLs,
        '',
        ...missingUniqueConstraintsSQLs,
        '',
        ...missingEnumConstraintsSQLs,
        '',
        ...missingEnumValuesSQLs,
        '',
        ...missingEntityIndexesSQLs,
      ];

      alterTablesSQLs = alterTablesSQLs.expandIndexed((i, s) {
        if (i > 0 && s.isEmpty) {
          var prev = alterTablesSQLs[i - 1];
          if (prev.isEmpty) {
            return <String>[];
          }
        }
        return [s];
      }).toList();

      while (alterTablesSQLs.isNotEmpty && alterTablesSQLs.first.isEmpty) {
        alterTablesSQLs.removeAt(0);
      }

      var suggestion = alterTablesSQLs.isEmpty
          ? ''
          : 'Suggestion of SQLs (`$dialectName`) to fix missing columns in tables:\n\n  ${alterTablesSQLs.join('\n  ')}\n';

      if (suggestion.isNotEmpty) {
        _log.info(suggestion);
      }

      var allErrors = repositoriesChecksErrors.join('\n');

      // Also the suggested SQLs (not only logged):
      throw StateError(
        'Error checking DB tables:\n\n$allErrors'
        '${suggestion.isNotEmpty ? '\n$suggestion' : ''}',
      );
    }

    _log.info('All tables OK @ $this');

    _checkedTables = true;
    return true;
  }

  _DBTableCheck _checkDBTableScheme(
    EntityRepository<Object> repository,
    TableScheme? scheme,
  ) {
    var repoType = repository.type;

    if (scheme == null) {
      _log.severe(
        'No scheme for repository `${repository.name}` (`$repoType`) in this adapter> generateTables: $_generateTables @ $this',
      );

      return _DBTableCheck.error(
        'No scheme for repository `${repository.name}` (`$repoType`) in this adapter> generateTables: $_generateTables @ $this',
      );
    }

    var schemeTableName = scheme.name;

    final entityHandler = repository.entityHandler;
    var entityFields = entityHandler.fieldsNames();

    var hiddenFields = _entityHiddenFields(entityHandler);

    if (hiddenFields.isNotEmpty) {
      _log.info(
        "Entity `$repoType` (table: `$schemeTableName`) hidden fields: $hiddenFields",
      );
    }

    var repoFieldsNames = entityFields.whereNotIn(hiddenFields).toList();

    var repoTable = getTableForEntityRepository(repository);

    var schemeToRepoMap = _schemeToRepoFieldsMap(
      scheme,
      entityHandler,
      hiddenFields: hiddenFields,
    );

    var schemesTypes = schemeToRepoMap.entries
        .map((e) {
          var schemeField = e.key;
          var repoField = e.value;
          if (repoField == null) return null;
          return MapEntry(repoField, scheme.fieldsTypes[schemeField]);
        })
        .nonNulls
        .toMapFromEntries();

    for (var e in schemesTypes.entries) {
      var field = e.key;
      var schemeType = e.value;
      var fieldType = entityHandler.getFieldType(
        null,
        field,
        resolveFiledName: true,
      );

      if (!checkDBTableField(repoType, field, schemeType, fieldType)) {
        return _DBTableCheck.error(
          "Invalid scheme type> entityType: $repoType; field: $field ; schemeType: $schemeType ; fieldType: $fieldType",
        );
      }
    }

    var fieldsInScheme = schemeToRepoMap.values.toList();

    var repoFieldsNotInScheme = repoFieldsNames
        .whereNot((f) => fieldsInScheme.contains(f))
        .toList();

    var referenceFields = repoFieldsNotInScheme
        .map(
          (f) => _checkDBTableSchemeReferenceField(
            entityHandler,
            scheme,
            repoTable,
            f,
            collectionFields: false,
          ),
        )
        .nonNulls
        .toMapFromEntries();

    var collectionReferenceFields = repoFieldsNotInScheme
        .map(
          (f) => _checkDBTableSchemeReferenceField(
            entityHandler,
            scheme,
            repoTable,
            f,
            collectionFields: true,
          ),
        )
        .nonNulls
        .toMapFromEntries();

    var missingReferenceColumns = referenceFields.entries
        .where((e) => e.value == null)
        .map((e) => e.key)
        .toList();

    var missingCollectionReferenceColumns = collectionReferenceFields.entries
        .where((e) => e.value == null)
        .map((e) => e.key)
        .toList();

    var missingColumns = repoFieldsNames
        .whereNot(
          (f) =>
              fieldsInScheme.contains(f) ||
              referenceFields.containsKey(f) ||
              collectionReferenceFields.containsKey(f),
        )
        .toList();

    var missingFieldReferenceConstraints = <String>{};
    var missingFieldReferenceIndexes = <String>{};
    var missingRelationshipFieldReferenceIndexes =
        <(String, String, TypeInfo)>{};

    // The table's columns of the entity's fields (e.g. a legacy
    // `creationDate` column), as the other checks map them:
    var repoToSchemeMap = <String, String>{
      for (var e in schemeToRepoMap.entries)
        if (e.value case var field?) field: e.key,
    };

    String fieldColumn(String field) =>
        repoToSchemeMap[field] ?? normalizeColumnName(field);

    var entityUniqueFields = entityHandler
        .getAllFieldsWithEntityAnnotation<EntityField>(null, (a) => a.isUnique)
        .keys
        .toList();

    // UNIQUE fields (`@EntityField.unique()`): a unique index over their
    // column (also of a `UNIQUE` constraint), when the adapter knows the
    // unique indexes (all the SQL adapters). Otherwise from the table's
    // `UNIQUE` constraints (below, with `constraintSupport`).
    var missingUniqueConstraints = scheme.uniqueIndexes == null
        ? <String>{}
        : entityUniqueFields
              .where(
                (f) =>
                    scheme.hasIndexOn([fieldColumn(f)], unique: true) == false,
              )
              .toSet();

    var missingEnumConstraints = <String>{};
    var missingEnumValues = <String, List<String>>{};

    if (capability.constraintSupport) {
      // REF CONSTRAINTS //

      var fieldEntityTypes = entityHandler
          .getFieldsEntityTypes()
          .entries
          .map((e) {
            var entityType = e.value.entityType;
            if (entityType == null) return null;

            var refRepository = repository.provider.getEntityRepositoryByType(
              entityType,
            );

            if (refRepository == null ||
                !refRepository.isSameEntityManager(repository)) {
              return null;
            }

            return MapEntry(e.key, entityType);
          })
          .nonNulls
          .toMapFromEntries();

      if (fieldEntityTypes.isNotEmpty) {
        var fieldsReferencedTables = scheme.fieldsReferencedTables;

        var fieldsReferences = fieldsReferencedTables.entries
            .map((e) {
              var colum = e.key;
              var field = schemeToRepoMap[colum] ?? colum;

              var entityType = fieldEntityTypes[field];
              if (entityType == null) return null;

              var refTable = e.value.targetTable;
              return MapEntry(field, refTable);
            })
            .nonNulls
            .toMapFromEntries();

        missingFieldReferenceConstraints = fieldEntityTypes.keys
            .where((f) => !fieldsReferences.containsKey(f))
            .toSet();

        if (!dialect.foreignKeyCreatesImplicitIndex) {
          missingFieldReferenceIndexes = fieldsReferencedTables.entries
              .where((e) => e.value.indexName == null)
              .map((e) => e.key)
              .toSet();
        }
      }

      // RELATIONSHIP CONSTRAINTS //

      var fieldListEntityTypes = entityHandler
          .getFieldsListEntityTypes()
          .entries
          .map((e) {
            var entityType = e.value.entityType;
            if (entityType == null) return null;

            var refRepository = repository.provider.getEntityRepositoryByType(
              entityType,
            );

            if (refRepository == null ||
                !refRepository.isSameEntityManager(repository)) {
              return null;
            }

            return MapEntry(e.key, entityType);
          })
          .nonNulls
          .toMapFromEntries();

      if (fieldListEntityTypes.isNotEmpty) {
        if (!dialect.foreignKeyCreatesImplicitIndex) {
          missingRelationshipFieldReferenceIndexes = collectionReferenceFields
              .entries
              .expand((e) {
                var relFieldRef = e.value;
                if (relFieldRef == null) {
                  return <(String, String, TypeInfo)>[];
                }

                return [
                  if (relFieldRef.sourceRelationshipFieldIndex == null)
                    (
                      relFieldRef.relationshipTable,
                      relFieldRef.sourceRelationshipField,
                      relFieldRef.sourceFieldEntityType,
                    ),
                  if (relFieldRef.targetRelationshipFieldIndex == null)
                    (
                      relFieldRef.relationshipTable,
                      relFieldRef.targetRelationshipField,
                      relFieldRef.targetFieldEntityType,
                    ),
                ];
              })
              .nonNulls
              .toSet();
        }
      }

      // UNIQUE CONSTRAINTS (unique indexes unknown) //

      if (scheme.uniqueIndexes == null) {
        var uniqueConstraints = scheme.constraints
            .whereType<TableUniqueConstraint>()
            .toList();

        var uniqueConstraintsFields = uniqueConstraints.toFields(
          fieldMap: schemeToRepoMap,
        );

        missingUniqueConstraints = entityUniqueFields
            .whereNotIn(uniqueConstraintsFields)
            .toSet();
      }

      // ENUM CONSTRAINTS //

      var enumConstraints = scheme.constraints
          .whereType<TableEnumConstraint>()
          .toList();

      var enumConstraintsFields = enumConstraints.toFields(
        fieldMap: schemeToRepoMap,
      );

      var entityEnumFields = entityHandler.getFieldsEnumTypes().keys.toList();

      missingEnumConstraints = entityEnumFields
          .whereNotIn(enumConstraintsFields)
          .toSet();

      // A column's enum values are missing only if no `CHECK` over it has
      // them all: with a duplicated `CHECK` (an old one never dropped), the
      // current one has them, and the duplicate is warned
      // (`findTableDuplicates`).
      var columnsWithAllValues = <String>{};
      var columnsMissingValues = <String, List<String>>{};

      for (var e in enumConstraints) {
        var valuesNames = _columnEnumValues(
          entityHandler,
          e.field,
          schemeToRepoMap,
        );
        if (valuesNames == null) continue;

        var missingValues = valuesNames.whereNotIn(e.values).toList();

        if (missingValues.isEmpty) {
          columnsWithAllValues.add(e.field);
        } else {
          columnsMissingValues.putIfAbsent(e.field, () => missingValues);
        }
      }

      for (var e in columnsMissingValues.entries) {
        if (!columnsWithAllValues.contains(e.key)) {
          missingEnumValues[e.key] = e.value;
        }
      }
    }

    // The entity's indexes (`@EntityIndex`) without an index over their
    // columns (in order, any name; unique if `unique`), when the adapter
    // knows the indexes (the table's columns of the fields):
    var missingEntityIndexes = scheme.indexes == null
        ? <CreateIndexSQL>[]
        : generateEntityIndexesSQLs(
                entityHandler,
                schemeTableName,
                fieldColumn: (f) => repoToSchemeMap[f],
              )
              // Only the ones known to be missing (`false`): `null` is unknown
              // (e.g. a unique one with unknown `uniqueIndexes`).
              .where(
                (sql) =>
                    scheme.hasIndexOn(sql.columns, unique: sql.unique) == false,
              )
              .toList();

    // A missing column's unique constraint comes with its `ADD COLUMN` (a
    // constraint, or a unique index): not a missing one (reported twice).
    missingUniqueConstraints.removeWhere(
      (f) => missingColumns.contains(f) || missingReferenceColumns.contains(f),
    );

    // As in the `CREATE TABLE`, not one over the same columns as another
    // missing one: a unique field's constraint (reported with the field), a
    // unique `@EntityIndex` (also serving a non-unique one), or the same
    // index twice.
    var missingUniqueColumns = [
      for (var f in missingUniqueConstraints) [fieldColumn(f)],
    ];
    var missingEntityIndexesKept = <CreateIndexSQL>[];
    for (var sql in [
      ...missingEntityIndexes.where((e) => e.unique),
      ...missingEntityIndexes.where((e) => !e.unique),
    ]) {
      var columns = sql.columns;
      if (missingUniqueColumns.any((c) => c.equals(columns))) continue;
      if (missingEntityIndexesKept.any(
        (e) => e.columns.equals(columns) && (e.unique || !sql.unique),
      )) {
        continue;
      }
      missingEntityIndexesKept.add(sql);
    }
    // In the declared order:
    missingEntityIndexes = missingEntityIndexes
        .where(missingEntityIndexesKept.contains)
        .toList();

    // A missing index whose name is in use by another index (other
    // columns, or not unique): `CREATE INDEX IF NOT EXISTS` would do
    // nothing; it must be dropped first. By index name, where it's in use
    // (other tables: [findIndexesNamesInUse], in `_checkDBTablesImpl`).
    var entityIndexesNameConflicts = <String, String>{
      for (var sql in missingEntityIndexes)
        if (sql.indexName case var indexName?)
          if (scheme.indexes?[indexName] case var columns?)
            indexName:
                'over (${columns.join(', ')})'
                '${sql.unique && !(scheme.uniqueIndexes?.contains(indexName) ?? false) ? ', not unique' : ''}',
    };

    if (entityIndexesNameConflicts.isNotEmpty) {
      _log.severe(
        "Table `$schemeTableName`: `@EntityIndex` names in use by other "
        "indexes (drop them first): $entityIndexesNameConflicts",
      );
    }

    if (missingColumns.isNotEmpty ||
        missingReferenceColumns.isNotEmpty ||
        missingCollectionReferenceColumns.isNotEmpty ||
        missingFieldReferenceConstraints.isNotEmpty ||
        missingFieldReferenceIndexes.isNotEmpty ||
        missingRelationshipFieldReferenceIndexes.isNotEmpty ||
        missingUniqueConstraints.isNotEmpty ||
        missingEnumConstraints.isNotEmpty ||
        missingEnumValues.isNotEmpty ||
        missingEntityIndexes.isNotEmpty) {
      _log.severe(
        "ERROR Checking table `$schemeTableName`> entityType: `$repoType`\n"
        "${missingEntityIndexes.isNotEmpty ? '-- missingEntityIndexes: ${missingEntityIndexes.map((e) => e.indexName).toList()}\n' : ''}"
        "${missingColumns.isNotEmpty ? '-- missingColumns: $missingColumns\n' : ''}"
        "${missingReferenceColumns.isNotEmpty ? '-- missingReferenceColumns: $missingReferenceColumns\n' : ''}"
        "${missingCollectionReferenceColumns.isNotEmpty ? '-- missingCollectionReferenceColumns: $missingCollectionReferenceColumns\n' : ''}"
        "${missingFieldReferenceConstraints.isNotEmpty ? '-- missingFieldReferenceConstraints: $missingFieldReferenceConstraints\n' : ''}"
        "${missingFieldReferenceIndexes.isNotEmpty ? '-- missingFieldReferenceIndexes: $missingFieldReferenceIndexes\n' : ''}"
        "${missingRelationshipFieldReferenceIndexes.isNotEmpty ? '-- missingRelationshipFieldReferenceIndexes: $missingRelationshipFieldReferenceIndexes\n' : ''}"
        "${missingUniqueConstraints.isNotEmpty ? '-- missingUniqueConstraints: $missingUniqueConstraints\n' : ''}"
        "${missingEnumConstraints.isNotEmpty ? '-- missingEnumConstraints: $missingEnumConstraints\n' : ''}"
        "${missingEnumValues.isNotEmpty ? '-- missingEnumValues: $missingEnumValues\n' : ''}",
      );

      return _DBTableCheck.missing(
        repository,
        scheme,
        missingColumns
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingReferenceColumns
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingCollectionReferenceColumns
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingFieldReferenceConstraints
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingFieldReferenceIndexes
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingRelationshipFieldReferenceIndexes
            .map((f) => _DBRelationshipTableColumn(f.$1, f.$2, f.$3, []))
            .toList(),
        missingUniqueConstraints
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingEnumConstraints
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingEnumValues.entries
            .map(
              (e) => MapEntry(
                _DBTableColumn.fromEntityHandler(entityHandler, e.key),
                e.value,
              ),
            )
            .toMapFromEntries(),
        missingEntityIndexes: missingEntityIndexes,
        entityIndexesNameConflicts: entityIndexesNameConflicts,
      );
    }

    _log.info('Checking table `$schemeTableName`: OK');

    return _DBTableCheck.ok();
  }

  MapEntry<String, TableRelationshipReferenceEntityTyped?>?
  _checkDBTableSchemeReferenceField(
    EntityHandler<Object> entityHandler,
    TableScheme scheme,
    String table,
    String fieldName, {
    required bool collectionFields,
  }) {
    var fieldType = entityHandler.getFieldType(
      null,
      fieldName,
      resolveFiledName: false,
    );
    if (fieldType == null) return null;

    // Only the collection fields (`collectionFields`), or only the others:
    if (fieldType.isListEntityOrReference != collectionFields) {
      return null;
    }

    var entityType = fieldType.entityTypeInfo ?? fieldType.listEntityType;
    if (entityType == null) return null;

    var targetTable = getTableForType(entityType);
    if (targetTable == null) return null;

    TableRelationshipReferenceEntityTyped? tableRefEntityTyped;

    try {
      var tableRef = scheme.getTableRelationshipReference(
        sourceTable: table,
        sourceField: fieldName,
        targetTable: targetTable,
      );

      tableRefEntityTyped = tableRef?.copyWithEntityTypes(
        entityHandler.typeInfo,
        entityType,
      );
    } catch (e) {
      _log.warning(
        "Error while getting relationship table for field: `$table`.`$fieldName`",
        e,
      );
    }

    return MapEntry(fieldName, tableRefEntityTyped);
  }

  bool checkDBTableField(
    Type entityType,
    String fieldName,
    Type? schemeType,
    TypeInfo<dynamic>? fieldType,
  ) {
    if (schemeType == null || fieldType == null) {
      throw StateError(
        "Invalid scheme field(`$entityType`.`$fieldName`) type> schemeType: $schemeType ; fieldType: $fieldType > $this",
      );
    }

    var fieldEntityType = fieldType.entityType;

    if (fieldEntityType != null) {
      if (schemeType != fieldEntityType &&
          !schemeType.isEntityIDType &&
          !fieldType.isEntityReferenceBaseType) {
        throw StateError(
          "Invalid scheme field(`$fieldName`) type> fieldEntityType: $fieldEntityType ; schemeType: $schemeType (invalid ID type) > $this",
        );
      }

      return true;
    } else {
      var type = fieldType.type;
      if (schemeType == type) {
        return true;
      }

      if (schemeType == String) {
        var enumReflection = ReflectionFactory().getRegisterEnumReflection(
          type,
        );
        if (enumReflection != null && enumReflection.enumType == type) {
          return true;
        }
      }

      throw StateError(
        "Invalid scheme field(`$fieldName`) type> fieldType: $type != schemeType: $schemeType > $this",
      );
    }
  }

  Future<Map<EntityRepository<Object>, TableScheme?>>
  getRepositoriesSchemes() async {
    var reposBlocks = entityRepositories
        .splitBeforeIndexed((i, r) => i % 2 == 0)
        .toList();

    final allSchemes = <EntityRepository<Object>, TableScheme?>{};

    // Call `getTableSchemeForEntityRepository` with a `contextID` to allow
    // shared internal cache between multiple calls:
    final contextID = List.unmodifiable([this, "getRepositoriesSchemes"]);

    for (var block in reposBlocks) {
      var repositorySchemes = await block
          .map(
            (r) => MapEntry(
              r,
              getTableSchemeForEntityRepository(r, contextID: contextID),
            ),
          )
          .toMapFromEntries()
          // A missing table: a `null` scheme (reported by the check).
          .resolveAllValuesNullable();

      allSchemes.addAll(repositorySchemes);
    }

    return allSchemes;
  }

  Object? _populateTables;

  @override
  FutureOr<InitializationResult> populateImpl() {
    var tables = _populateTables;
    if (tables != null) {
      _populateTables = null;
      return populateTables(tables).resolveWith(super.populateImpl);
    }

    return super.populateImpl();
  }

  FutureOr<List<String>> generateTables() {
    if (!capability.tableSQL) {
      _generatedTables = true;
      return <String>[];
    }

    return generateFullCreateTableSQLs(withDate: false)
        .resolveMapped((fullCreateTableSQLs) {
          return populateTables(fullCreateTableSQLs);
        })
        .resolveMapped((tables) {
          _generatedTables = true;
          return tables;
        });
  }

  FutureOr<List<String>> populateTables(Object? tables) {
    if (tables == null) {
      return <String>[];
    } else if (tables is String) {
      if (RegExp(r'^\S+\.sql$').hasMatch(tables)) {
        var apiPlatform = APIPlatform.get();

        var filePath = apiPlatform.resolveFilePath(tables);

        if (filePath == null) {
          throw StateError("Can't resolve tables file path: $tables");
        }

        _log.info('Reading $this populate tables file: $filePath');

        var fileData = apiPlatform.readFileAsString(filePath);

        if (fileData != null) {
          return fileData.resolveMapped((data) {
            if (data != null) {
              _log.info(
                'Populating $this tables [SQL length: ${data.length}]...',
              );

              return populateTablesFromSQLs(data).resolveMapped((tables) {
                _log.info('Populate tables finished: $tables');
                return tables;
              });
            } else {
              return <String>[];
            }
          });
        }
      } else if (RegExp(
        r'(?:^|\s+)(?:CREATE|ALTER)\s+TABLE\s',
      ).hasMatch(tables)) {
        _log.info('Populating $this tables [SQL length: ${tables.length}]...');

        return populateTablesFromSQLs(tables).resolveMapped((tables) {
          _log.info('Populate tables finished: $tables');
          return tables;
        });
      }
    }

    return <String>[];
  }

  static String? extractTableNameInSQL(String tableSQL) {
    var match = RegExp(
      r'''(?:^|\s)(?:CREATE|ALTER)\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?['"`]?(\w+)['"`]?''',
    ).firstMatch(tableSQL);

    return match?.group(1);
  }

  static List<String> extractTableSQLs(String sqls) => extractSQLs(
    sqls,
    RegExp(
      r'(?:(?:CREATE|ALTER)\s+TABLE|CREATE\s+INDEX)',
      caseSensitive: false,
      dotAll: true,
    ),
  );

  static List<String> extractSQLs(String sqls, RegExp commandPrefixPattern) {
    sqls = removeSQLsComments(sqls);
    sqls = '\n$sqls\n;';

    var list = <String>[];

    var regexpCreateTableSQL = RegExp(
      r'\s' + commandPrefixPattern.pattern + r'\s.*?;',
      caseSensitive: false,
      dotAll: true,
    );

    sqls.replaceAllMapped(regexpCreateTableSQL, (m) {
      var sql = m[0]!;
      list.add(sql);
      return '';
    });

    return list;
  }

  static String removeSQLsComments(String sqls) {
    sqls = sqls.replaceAllMapped(
      RegExp(r'/\*.*?\*/', dotAll: true),
      (m) => ' ',
    );

    while (true) {
      var prev = sqls;
      sqls = sqls.replaceAllMapped(
        RegExp(r'(?:^|\n)--[^\n]*?([\r\n]+)', dotAll: true),
        (m) => m[1]!,
      );
      if (prev == sqls) break;
    }

    sqls = sqls.replaceAllMapped(
      RegExp(r'[ \t]--[ \t][^\n]*?(\n|$)', dotAll: true),
      (m) => m[1]!,
    );

    return sqls;
  }

  FutureOr<List<String>> populateTablesFromSQLs(String sqls) {
    var list = extractTableSQLs(sqls);
    if (list.isEmpty) return <String>[];
    return _populateTablesFromSQLsImpl(list);
  }

  static final RegExp _regExpCreateIndex = RegExp(
    r'CREATE\s+INDEX',
    caseSensitive: false,
  );

  Future<List<String>> _populateTablesFromSQLsImpl(List<String> list) async {
    var tables = <String>[];

    for (var sql in list) {
      _log.info("Populating table:\n<<<\n${sql.trim()}\n>>>");

      var ok = await executeTableSQL(sql);
      if (!ok) {
        if (!dialect.createIndexIfNotExists) {
          if (_regExpCreateIndex.hasMatch(sql)) {
            _log.warning(
              "Ignoring CREATE INDEX error: the SQL dialect does NOT support `IF NOT EXISTS`. SQL> $sql",
            );
            continue;
          }
        }
        throw StateError("Error creating table SQL: $sql");
      }

      var name = extractTableNameInSQL(sql);
      if (name != null) {
        tables.add(name);
      }
    }

    return tables;
  }

  List<EntityRepository>? _entityRepositoriesBuildOrderIn;
  List<EntityRepository>? _entityRepositoriesBuildOrderOut;

  @override
  List<EntityRepository> get entityRepositoriesBuildOrder {
    var repositories = super.entityRepositoriesBuildOrder;

    var entityRepositoriesBuildOrderIn = _entityRepositoriesBuildOrderIn;
    var entityRepositoriesBuildOrderOut = _entityRepositoriesBuildOrderOut;

    if (entityRepositoriesBuildOrderIn != null &&
        entityRepositoriesBuildOrderOut != null &&
        entityRepositoriesBuildOrderIn.equalsElements(repositories)) {
      return entityRepositoriesBuildOrderOut.toList();
    }

    _entityRepositoriesBuildOrderIn = repositories.toList();

    var sqls = generateEntityRepositoresCreateTableSQLs(
      verbose: !DBAdapter.auxiliaryMode,
    );

    var ordered = sqls.entries.toHierarchicalOrder().map((e) => e.key).toList();

    repositories.sort((a, b) {
      var i1 = ordered.indexOf(a);
      var i2 = ordered.indexOf(b);
      var cmp = i1.compareTo(i2);
      return cmp;
    });

    _entityRepositoriesBuildOrderOut = repositories.toList();

    return repositories;
  }

  /// Generates the [CreateTableSQL] for each [EntityRepository].
  /// See [entityRepositories].
  Map<EntityRepository, CreateTableSQL>
  generateEntityRepositoresCreateTableSQLs({
    bool ifNotExists = true,
    bool sortColumns = true,
    bool verbose = false,
  }) => entityRepositories
      .map(
        (r) => MapEntry<EntityRepository, CreateTableSQL>(
          r,
          generateCreateTableSQL(
            entityRepository: r,
            ifNotExists: ifNotExists,
            sortColumns: sortColumns,
          ),
        ),
      )
      .toHierarchicalOrder(verbose: verbose)
      .toMapFromEntries();

  /// Generate all the SQLs to create the tables.
  @override
  List<SQLBuilder> generateCreateTableSQLs({
    bool ifNotExists = true,
    bool sortColumns = true,
  }) {
    var sqls = generateEntityRepositoresCreateTableSQLs(
      ifNotExists: ifNotExists,
      sortColumns: sortColumns,
    );

    var allSQLs = sqls.values
        .expand((e) => e.allSQLBuilders)
        .toList()
        .toHierarchicalOrder();

    return allSQLs;
  }

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
      var enumReflection = ReflectionFactory().getRegisterEnumReflection(
        enumType,
      );

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
    Map<String, Object?> fieldsValues,
  ) => _resolveFieldValueToSQL(context, tableScheme, fieldName, value)
      .resolveMapped((refId) {
        fieldsValues.putIfAbsent(fieldName, () => refId);
        var valueSQL = _conditionSQLGenerator.parameterPlaceholder(fieldName);
        return valueSQL;
      });

  FutureOr<Object?> _resolveFieldValueToSQL(
    EncodingContext context,
    TableScheme tableScheme,
    String fieldName,
    Object? value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is EntityReference) {
      if (value.isNull) {
        return null;
      } else if (value.isIdSet) {
        var refId = value.id!;
        return refId;
      } else if (value.isEntitySet) {
        value = value.entity!;
      }
    }

    final refEntity = value!;

    var refEntityRepository = getEntityRepository(obj: refEntity);

    if (refEntityRepository == null) {
      return _getValueEntityID(refEntity) ?? valueToSQL(refEntity);
    } else {
      var fieldRef = tableScheme.getFieldReferencedTable(fieldName);

      var refEntityHandler = refEntityRepository.entityHandler;

      var refId = fieldRef != null
          ? refEntityHandler.getField(refEntity, fieldRef.targetField)
          : refEntityHandler.getID(refEntity);

      if (refId != null) return refId;

      var retRefId = refEntityRepository.store(
        refEntity,
        transaction: context.transaction,
      );
      return retRefId;
    }
  }

  Object? _getValueEntityID(Object entity) {
    if (entity is Entity) {
      var refId = entity.getID();
      return refId;
    } else {
      var valueType = entity.runtimeType;

      var reflectionFactory = ReflectionFactory();

      var reflection = reflectionFactory.getRegisterClassReflection(valueType);

      var refEntityHandler =
          reflection?.entityHandler ??
          reflectionFactory.getRegisterEntityHandler(valueType);

      var refId = refEntityHandler?.getID(entity);
      return refId;
    }
  }

  FutureOr<bool> executeTableSQL(String createTableSQL);

  FutureOr<SQL> generateCountSQL(
    Transaction transaction,
    String entityName,
    String table, {
    EntityMatcher? matcher,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var q = dialect.elementQuote;

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
      return _generateSQLFrom(
        transaction,
        entityName,
        table,
        matcher,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        sqlBuilder: (String from, EncodingContext context) {
          return 'SELECT count(*) as ${q}count$q $from';
        },
      );
    }
  }

  FutureOr<int> countSQL(
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
  ) {
    if (sql.isDummy) return 0;

    return executeTransactionOperation(op, sql, (connection) {
      _onTransactionOperationSQL('countSQL', op, sql);
      return doCountSQL(entityName, table, sql, op.transaction, connection);
    });
  }

  /// Called right before [sql] (an [SQL] or a `List<SQL>`) is executed:
  /// counts it ([executedSQLsCount]) and logs it ([logSQL]).
  void _onTransactionOperationSQL(
    String method,
    TransactionOperation op,
    Object sql,
  ) {
    if (sql is SQL) {
      if (!sql.isDummy) ++_executedSQLsCount;
    } else if (sql is List<SQL>) {
      for (var s in sql) {
        if (!s.isDummy) ++_executedSQLsCount;
      }
    }

    if (logSQL && _log.handler.isLoggingDB) {
      String msg() {
        String s;
        if (sql is List) {
          if (sql.isEmpty) {
            s = '<empty_sql>';
          } else if (sql.length == 1) {
            s = '${sql[0]}';
          } else {
            s = '\n  -- ${sql.join('\n  -- ')}';
          }
        } else {
          s = '$sql';
        }

        return '[transaction:${op.transactionId}] $method> $s';
      }

      _log.info(msg);
    }
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
    TransactionOperation op,
    String entityName,
    String table, {
    EntityMatcher? matcher,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    PreFinishDBOperation<int, int>? preFinish,
  }) {
    return generateCountSQL(
      op.transaction,
      entityName,
      table,
      matcher: matcher,
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
    ).resolveMapped((sql) {
      return countSQL(
        op,
        entityName,
        table,
        sql,
      ).resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  FutureOr<SQL> generateExistIDsSQL<I extends Object>(
    Transaction transaction,
    String entityName,
    String table,
    List<I> ids,
  ) {
    if (ids.isEmpty) return SQL.dummy;

    return _generateSQLFrom(
      transaction,
      entityName,
      table,
      ConditionIdIN(ids),
      sqlBuilder: (String from, EncodingContext context) {
        var tableFieldID = context.tableFieldID ?? 'id';
        var tableAlias = context.resolveEntityAlias(table);
        var q = dialect.elementQuote;
        var sql = 'SELECT $q$tableAlias$q.$q$tableFieldID$q as ${q}id$q $from';
        return sql;
      },
    );
  }

  FutureOr<List<I>> existIDsSQL<I extends Object>(
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
  ) {
    if (sql.isDummy) return [];

    return executeTransactionOperation(op, sql, (connection) {
      _onTransactionOperationSQL('existIDsSQL', op, sql);
      return doExistIDsSQL(entityName, table, sql, op.transaction, connection);
    });
  }

  FutureOr<List<I>> doExistIDsSQL<I extends Object>(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    C connection,
  );

  @override
  FutureOr<List<I>> doExistIDs<I extends Object>(
    TransactionOperation op,
    String entityName,
    String table,
    List<I> ids,
  ) {
    return generateExistIDsSQL(
      op.transaction,
      entityName,
      table,
      ids,
    ).resolveMapped((sql) {
      return existIDsSQL(op, entityName, table, sql).resolveMapped(
        (r) => _finishSQLOperation(sql, op, r, (ids) => parseIDs<I>(ids)),
      );
    });
  }

  FutureOr<SQL> generateInsertSQL(
    Transaction transaction,
    String entityName,
    String table,
    Map<String, Object?> fields,
  ) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var context = EncodingContext(
        entityName,
        namedParameters: fields,
        transaction: transaction,
        tableName: table,
        tableFieldID: tableScheme.idFieldName,
      );

      var fieldsValues = tableScheme.getFieldsValues(fields);

      var fieldsNotNull = fieldsValues.entries
          .map((e) => e.value != null ? e.key : null)
          .nonNulls
          .toList(growable: false);

      var fieldsValuesInSQL = <String, Object?>{};

      return fieldsNotNull
          .map(
            (f) => fieldValueToSQL(
              context,
              tableScheme,
              f,
              fieldsValues[f]!,
              fieldsValuesInSQL,
            ),
          )
          .toList(growable: false)
          .resolveAll()
          .resolveMapped((values) {
            assert(fieldsNotNull.length == values.length);

            var idFieldName = tableScheme.idFieldName;
            assert(idFieldName != null && idFieldName.isNotEmpty);

            var q = dialect.elementQuote;

            var sql = StringBuffer();

            sql.write('INSERT INTO $q');
            sql.write(table);
            sql.write(q);

            if (fieldsNotNull.isNotEmpty) {
              sql.write('(');
              sql.write(fieldsNotNull.map((f) => '$q$f$q').join(','));
              sql.write(')');
            }

            if (dialect.acceptsOutputSyntax) {
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
              if (dialect.acceptsInsertDefaultValues) {
                sql.write(' DEFAULT VALUES ');
              } else {
                sql.write(' VALUES () ');
              }
            }

            if (dialect.acceptsReturningSyntax) {
              sql.write(' RETURNING $q$table$q.$q$idFieldName$q');
            }

            return SQL(
              sql.toString(),
              null,
              fields,
              fieldsValuesInSQL,
              entityName: table,
              idFieldName: idFieldName,
              mainTable: table,
            );
          });
    });
  }

  FutureOr<dynamic> insertSQL(
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
    Map<String, Object?> fields,
  ) {
    if (sql.isDummy) return null;

    return executeTransactionOperation(op, sql, (connection) {
      _onTransactionOperationSQL('insertSQL', op, sql);
      return doInsertSQL(entityName, table, sql, op.transaction, connection);
    });
  }

  FutureOr<dynamic> doInsertRelationshipSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    C connection,
  ) {
    return doInsertSQL(entityName, table, sql, transaction, connection);
  }

  FutureOr<dynamic> doInsertSQL(
    String entityName,
    String table,
    SQL sql,
    Transaction transaction,
    C connection,
  );

  FutureOr<SQL> generateUpdateSQL(
    Transaction transaction,
    String entityName,
    String table,
    Object id,
    Map<String, Object?> fields,
  ) {
    if (fields.isEmpty) return SQL.dummy;

    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var context = EncodingContext(
        entityName,
        namedParameters: fields,
        transaction: transaction,
        tableFieldID: tableScheme.idFieldName,
      );

      var idFieldName = tableScheme.idFieldName!;
      var idPlaceholder = _conditionSQLGenerator.parameterPlaceholder(
        idFieldName,
      );

      var fieldsValues = tableScheme.getFieldsValues(
        fields,
        fields: fields.keys.toSet(),
      );

      // No value to update:
      if (fieldsValues.isEmpty) {
        return SQL.dummy;
      }

      var fieldsKeys = fieldsValues.keys.toList();

      var fieldsValuesInSQL = <String, Object?>{idFieldName: id};

      return fieldsKeys
          .map(
            (f) => fieldValueToSQL(
              context,
              tableScheme,
              f,
              fieldsValues[f],
              fieldsValuesInSQL,
            ),
          )
          .toList(growable: false)
          .resolveAll()
          .resolveMapped((values) {
            var q = dialect.elementQuote;
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

            if (dialect.acceptsOutputSyntax) {
              sql.write(' OUTPUT INSERTED.');
              sql.write(q);
              sql.write(idFieldName);
              sql.write(q);
            }

            sql.write(' WHERE ');

            var conditionSQL = '$idFieldName = $idPlaceholder';
            sql.write(conditionSQL);

            if (dialect.acceptsReturningSyntax) {
              sql.write(' RETURNING $q$table$q.$q$idFieldName$q');
            }

            return SQL(
              sql.toString(),
              null,
              fields,
              fieldsValuesInSQL,
              sqlCondition: conditionSQL,
              entityName: table,
              idFieldName: idFieldName,
              mainTable: table,
            );
          });
    });
  }

  FutureOr<dynamic> updateSQL(
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
    Object id,
    Map<String, Object?> fields, {
    bool allowAutoInsert = false,
  }) {
    if (sql.isDummy) return id;

    return executeTransactionOperation(op, sql, (connection) {
      _onTransactionOperationSQL('updateSQL', op, sql);
      return doUpdateSQL(
        entityName,
        table,
        sql,
        id,
        op.transaction,
        connection,
        allowAutoInsert: allowAutoInsert,
      );
    });
  }

  FutureOr<dynamic> doUpdateSQL(
    String entityName,
    String table,
    SQL sql,
    Object id,
    Transaction transaction,
    C connection, {
    bool allowAutoInsert = false,
  });

  /// The `INSERT`s of the relationship rows of [id] to [otherIds], and (in
  /// the last one's `posSQL`) the `DELETE` of its other relationship rows.
  ///
  /// [newEntity]: [id] has no relationship rows (just inserted, see
  /// [generatedIDsHaveNoRelationships]): no `DELETE`.
  FutureOr<List<SQL>> generateInsertRelationshipSQLs(
    Transaction transaction,
    String entityName,
    String table,
    String field,
    dynamic id,
    String otherTableName,
    List otherIds, {
    bool newEntity = false,
  }) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var relationship = tableScheme.getTableRelationshipReference(
        sourceTable: table,
        sourceField: field,
        targetTable: otherTableName,
      );

      if (relationship == null) {
        throw StateError(
          "Can't find TableRelationshipReference for tables: $table -> $otherTableName\n$tableScheme",
        );
      }

      var sqls = otherIds.isEmpty
          ? [SQL.dummy]
          : otherIds
                .map(
                  (otherId) =>
                      _generateInsertRelationshipSQL(relationship, id, otherId),
                )
                .toList();

      if (newEntity) return sqls;

      var constrainSQL = _generateConstrainRelationshipSQL(
        tableScheme,
        table,
        field,
        id,
        otherTableName,
        otherIds,
      );

      var lastIdx = sqls.lastIndex;

      var sqlsLast = sqls[lastIdx].ensureNotSharedDummy();
      sqls[lastIdx] = sqlsLast;

      sqlsLast.posSQL = [constrainSQL];

      return sqls;
    });
  }

  SQL _generateInsertRelationshipSQL(
    TableRelationshipReference relationship,
    dynamic id,
    dynamic otherId,
  ) {
    var relationshipTable = relationship.relationshipTable;
    var sourceIdField = relationship.sourceRelationshipField;
    var targetIdField = relationship.targetRelationshipField;

    var parameters = {sourceIdField: id, targetIdField: otherId};

    var q = dialect.elementQuote;
    var sql = StringBuffer();

    sql.write('INSERT ');

    if (dialect.acceptsInsertIgnore) {
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

    if (dialect.acceptsInsertOnConflict) {
      sql.write(' ON CONFLICT DO NOTHING ');
    }

    return SQL(
      sql.toString(),
      null,
      parameters,
      parameters,
      mainTable: relationshipTable,
      relationship: relationship,
    );
  }

  SQL _generateConstrainRelationshipSQL(
    TableScheme tableScheme,
    String table,
    String field,
    dynamic id,
    String otherTableName,
    List otherIds,
  ) {
    var relationship = tableScheme.getTableRelationshipReference(
      sourceTable: table,
      sourceField: field,
      targetTable: otherTableName,
    );

    if (relationship == null) {
      throw StateError(
        "Can't find TableRelationshipReference for tables: $table -> $otherTableName",
      );
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

    var q = dialect.elementQuote;

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

    Condition condition;

    if (otherIdsParameters.isNotEmpty) {
      condition = GroupConditionAND([
        KeyConditionEQ([ConditionKeyField(sourceIdField)], id),
        KeyConditionNotIN([ConditionKeyField(targetIdField)], otherIds),
      ]);
    } else {
      condition = KeyConditionEQ([ConditionKeyField(sourceIdField)], id);
    }

    return SQL(
      sql.toString(),
      null,
      parameters,
      parameters,
      condition: condition,
      sqlCondition: conditionSQL,
      mainTable: relationshipTable,
      relationship: relationship,
    );
  }

  FutureOr<bool> insertRelationshipSQLs(
    TransactionOperation op,
    String entityName,
    String table,
    List<SQL> sqls,
    dynamic id,
    String otherTable,
    List otherIds,
  ) {
    if (sqls.length == 1 && sqls.first.isFullyDummy) {
      return true;
    }

    return executeTransactionOperation(op, sqls.first, (connection) {
      _onTransactionOperationSQL('insertRelationshipSQLs', op, sqls);

      var retInserts = sqls.map((sql) {
        var ret = doInsertRelationshipSQL(
          entityName,
          sql.mainTable ?? table,
          sql,
          op.transaction,
          connection,
        );

        if (sql.hasPosSQL) {
          return sql.posSQL!
              .map((e) {
                _onTransactionOperationSQL('insertRelationship[POS]', op, e);
                return doDeleteSQL(
                  entityName,
                  e.mainTable!,
                  e,
                  op.transaction,
                  connection,
                );
              })
              .resolveAllWithValue(ret);
        } else {
          return ret;
        }
      }).resolveAll();
      return retInserts.resolveWithValue(true);
    });
  }

  FutureOr<SQL> generateSelectRelationshipSQL(
    Transaction transaction,
    String entityName,
    String table,
    String field,
    dynamic id,
    String otherTableName,
  ) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var relationship = tableScheme.getTableRelationshipReference(
        sourceTable: table,
        sourceField: field,
        targetTable: otherTableName,
      );

      if (relationship == null) {
        throw StateError(
          "Can't find TableRelationshipReference for tables: $table -> $otherTableName",
        );
      }

      var parameters = {'source_id': id};

      var q = dialect.elementQuote;

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

      var condition = KeyConditionEQ([
        ConditionKeyField(relationship.sourceRelationshipField),
      ], id);

      return SQL(
        sql.toString(),
        null,
        parameters,
        parameters,
        condition: condition,
        sqlCondition: conditionSQL,
        returnColumnsAliases: {
          relationship.sourceRelationshipField: 'source_id',
          relationship.targetRelationshipField: 'target_id',
        },
        mainTable: relationship.relationshipTable,
        relationship: relationship,
      );
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipSQL(
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
    dynamic id,
    String otherTable,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _onTransactionOperationSQL('selectRelationshipSQL', op, sql);

      var ret = doSelectSQL(
        entityName,
        sql.mainTable ?? table,
        sql,
        op.transaction,
        connection,
      );
      return ret;
    });
  }

  FutureOr<SQL> generateSelectRelationshipsSQL(
    Transaction transaction,
    String entityName,
    String table,
    String field,
    List<dynamic> ids,
    String otherTableName,
  ) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var relationship = tableScheme.getTableRelationshipReference(
        sourceTable: table,
        sourceField: field,
        targetTable: otherTableName,
      );

      if (relationship == null) {
        throw StateError(
          "Can't find TableRelationshipReference for tables: $table -> $otherTableName",
        );
      }

      var q = dialect.elementQuote;

      var conditionSQL = StringBuffer(
        '$q${relationship.sourceRelationshipField}$q IN (',
      );

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

      var condition = KeyConditionIN([
        ConditionKeyField(relationship.sourceRelationshipField),
      ], ids);

      return SQL(
        sql.toString(),
        ids,
        {'ids': ids},
        parameters,
        condition: condition,
        sqlCondition: conditionSQLStr,
        returnColumnsAliases: {
          relationship.sourceRelationshipField: 'source_id',
          relationship.targetRelationshipField: 'target_id',
        },
        mainTable: relationship.relationshipTable,
        relationship: relationship,
      );
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipsSQL(
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
    List<dynamic> ids,
    String otherTable,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _onTransactionOperationSQL('selectRelationshipsSQL', op, sql);

      var ret = doSelectSQL(
        entityName,
        sql.mainTable ?? table,
        sql,
        op.transaction,
        connection,
      );
      return ret;
    });
  }

  Object resolveError(
    Object error,
    StackTrace stackTrace,
    Object? operation,
    Object? previousError,
  ) => DBSQLAdapterException(
    'error',
    '$error',
    parentError: error,
    parentStackTrace: stackTrace,
    previousError: previousError,
    operation: operation,
  );

  @override
  bool isTransactionWithSingleOperation(
    TransactionOperation op, [
    SQLWrapper? sql,
  ]) {
    return super.isTransactionWithSingleOperation(op) &&
        (sql == null || (sql.sqlsLength == 1 && !sql.mainSQL.hasPreOrPosSQL));
  }

  /// If `true`, the reads of a transaction that hasn't written yet run on a
  /// pooled connection, without opening the database transaction (`BEGIN`):
  /// a read-only transaction then costs no `BEGIN`/`COMMIT` round trips. The
  /// database transaction is only opened by its first write.
  ///
  /// It's only equivalent when each statement reads its own snapshot anyway,
  /// as with `READ COMMITTED` and plain `SELECT`s (no locks). Default: `false`.
  bool get readsOutsideTransaction => false;

  /// See [readsOutsideTransaction].
  bool canReadOutsideTransaction(TransactionOperation op, SQLWrapper sql) {
    if (!readsOutsideTransaction) return false;

    var transaction = op.transaction;

    return !transaction.isOpen &&
        !transaction.isOpening &&
        sql.sqlsLength == 1 &&
        !sql.mainSQL.hasPreOrPosSQL &&
        transaction.isReadOnlyUntil(op);
  }

  FutureOr<R> executeTransactionOperation<R>(
    TransactionOperation op,
    SQLWrapper sql,
    FutureOr<R> Function(C connection) f,
  ) {
    var transaction = op.transaction;

    if (isTransactionWithSingleOperation(op, sql) ||
        canReadOutsideTransaction(op, sql)) {
      return executeWithPool(
        f,
        onError: (e, s) => transaction.notifyExecutionError(
          e,
          s,
          errorResolver: resolveError,
          operation: op,
          debugInfo: () => sql.mainSQL.toString(),
        ),
      );
    }

    if (transaction.isOpen) {
      return transaction.addExecution<R, C>(
        f,
        errorResolver: resolveError,
        operation: op,
        debugInfo: () => sql.mainSQL.toString(),
      );
    }

    if (!transaction.isOpening) {
      transaction.open(
        () => openTransaction(transaction),
        callCloseTransactionRequired
            ? () => closeTransaction(transaction, transaction.context as C?)
            : null,
      );
    }

    return transaction.onOpen<R>(() {
      return transaction.addExecution<R, C>(
        f,
        errorResolver: resolveError,
        operation: op,
        debugInfo: () => sql.mainSQL.toString(),
      );
    });
  }

  /// Builds the ` ORDER BY ... LIMIT ... OFFSET ...` tail of a `SELECT`,
  /// shared by [generateSelectSQL] and [generateSelectIDsSQL].
  ///
  /// The `ORDER BY` column is the ID column of the main table, already
  /// resolved by [_generateSQLFrom] (through [TableScheme.idFieldName]) and
  /// exposed as [EncodingContext.tableFieldID].
  String _generateSelectTailSQL(
    EncodingContext context,
    String tableAlias, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) {
    var tail = '';

    // A `limit` of `0` is no `LIMIT` clause here: it doesn't need an order.
    var effectiveLimit = limit != null && limit > 0 ? limit : null;

    if (OrderDirection.resolveOrderByID(orderByID, offset, effectiveLimit)) {
      var tableFieldID = context.tableFieldID ?? 'id';
      tail += dialect.orderBySQL(
        tableAlias,
        tableFieldID,
        direction: orderDirection,
      );
    }

    tail += dialect.limitOffsetSQL(limit: limit, offset: offset);

    return tail;
  }

  FutureOr<SQL> generateSelectSQL(
    Transaction transaction,
    String entityName,
    String table,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) {
    return _generateSQLFrom(
      transaction,
      entityName,
      table,
      matcher,
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
      sqlBuilder: (String from, EncodingContext context) {
        var tableAlias = context.resolveEntityAlias(table);
        var q = dialect.elementQuote;
        var tail = _generateSelectTailSQL(
          context,
          tableAlias,
          limit: limit,
          offset: offset,
          orderByID: orderByID,
          orderDirection: orderDirection,
        );
        var sql = 'SELECT $q$tableAlias$q.* $from$tail';
        return sql;
      },
    );
  }

  FutureOr<SQL> generateSelectIDsSQL(
    Transaction transaction,
    String entityName,
    String table,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) {
    return _generateSQLFrom(
      transaction,
      entityName,
      table,
      matcher,
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
      sqlBuilder: (String from, EncodingContext context) {
        var tableAlias = context.resolveEntityAlias(table);
        var tableFieldID = context.tableFieldID ?? 'id';
        var q = dialect.elementQuote;
        var tail = _generateSelectTailSQL(
          context,
          tableAlias,
          limit: limit,
          offset: offset,
          orderByID: orderByID,
          orderDirection: orderDirection,
        );
        var sql =
            'SELECT $q$tableAlias$q.$q$tableFieldID$q as ${q}id$q $from$tail';
        return sql;
      },
    );
  }

  FutureOr<SQL> _generateSQLFrom(
    Transaction transaction,
    String entityName,
    String table,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
    required String Function(String from, EncodingContext context) sqlBuilder,
  }) {
    if (matcher is! Condition) {
      throw StateError('Invalid SQL condition: $matcher');
    }

    var retEncodedSQL = getTableScheme(table).resolveMapped((tableScheme) {
      var idFieldName = tableScheme?.idFieldName;

      return _conditionSQLGenerator.encode(
        matcher,
        entityName,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        tableName: table,
        tableFieldID: idFieldName,
      );
    });

    return retEncodedSQL.resolveMapped((encodedSQL) {
      var conditionSQL = encodedSQL.outputString;

      var tableAlias = _conditionSQLGenerator.resolveEntityAlias(
        encodedSQL,
        table,
      );

      var q = dialect.elementQuote;

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
          limit: limit,
          offset: offset,
          orderByID: orderByID,
          orderDirection: orderDirection,
        );
      } else {
        var joins = <_JoinEntry>[];

        for (var e in encodedSQL.referencedTablesFields.entries) {
          var refTable = e.key;
          var refTableAlias = encodedSQL.resolveEntityAlias(refTable);

          var innerRef = e.value.every(
            (ref) => encodedSQL.isInnerFieldReference(ref),
          );

          var join = StringBuffer();

          if (innerRef) {
            join.write('INNER JOIN ');
          } else {
            join.write('LEFT OUTER JOIN ');
          }

          join.write('$q$refTable$q as $q$refTableAlias$q ON ');

          var defAliases = <String>[refTableAlias];
          var refAliases = <String>[];

          for (var fieldRef in e.value) {
            var sourceTableAlias = _conditionSQLGenerator.resolveEntityAlias(
              encodedSQL,
              fieldRef.sourceTable,
            );
            var targetTableAlias = _conditionSQLGenerator.resolveEntityAlias(
              encodedSQL,
              fieldRef.targetTable,
            );

            refAliases.add(sourceTableAlias);
            refAliases.add(targetTableAlias);

            join.write(q);
            join.write(sourceTableAlias);
            join.write(q);
            join.write('.');
            join.write(q);
            join.write(fieldRef.sourceField);
            join.write(q);

            join.write(' = ');

            join.write(q);
            join.write(targetTableAlias);
            join.write(q);
            join.write('.');
            join.write(q);
            join.write(fieldRef.targetField);
            join.write(q);
            join.write(' ');
          }

          refAliases.removeAll(defAliases);

          joins.add((
            defs: defAliases,
            refs: refAliases,
            join: join.toString(),
          ));
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

          var innerRel = encodedSQL.isInnerRelationshipTable(relationship);

          var join = StringBuffer();

          if (innerRel) {
            join.write('INNER JOIN ');
          } else {
            join.write('LEFT OUTER JOIN ');
          }

          join.write('$q$relTable$q as $q$relTableAlias$q ON (');

          join.write(q);
          join.write(relTableAlias);
          join.write(q);
          join.write('.');
          join.write(q);
          join.write(sourceRelationshipField);
          join.write(q);

          join.write(' = ');

          join.write(q);
          join.write(tableAlias);
          join.write(q);
          join.write('.');
          join.write(q);
          join.write(sourceTableField);
          join.write(q);

          join.write(') ');

          var targetTableAlias = _conditionSQLGenerator.resolveEntityAlias(
            encodedSQL,
            targetTable,
          );

          String targetTableField;
          String targetRelationshipField;

          if (relationship.targetTable == targetTable) {
            targetTableField = relationship.targetField;
            targetRelationshipField = relationship.targetRelationshipField;
          } else {
            targetTableField = relationship.sourceField;
            targetRelationshipField = relationship.sourceRelationshipField;
          }

          if (innerRel) {
            join.write('INNER JOIN ');
          } else {
            join.write('LEFT OUTER JOIN ');
          }

          join.write('$q$targetTable$q as $q$targetTableAlias$q ON (');

          join.write(q);
          join.write(targetTableAlias);
          join.write(q);
          join.write('.');
          join.write(q);
          join.write(targetTableField);
          join.write(q);

          join.write(' = ');

          join.write(q);
          join.write(relTableAlias);
          join.write(q);
          join.write('.');
          join.write(q);
          join.write(targetRelationshipField);
          join.write(q);

          join.write(') ');

          joins.add((
            defs: [relTableAlias, targetTableAlias],
            refs: [tableAlias],
            join: join.toString(),
          ));
        }

        var allJoinRefsResolved = joins.sortJoins({tableAlias});

        var join = joins.map((e) => e.join).join(' ');

        var from =
            'FROM $q$table$q as $q$tableAlias$q $join WHERE $conditionSQL';

        if (!allJoinRefsResolved) {
          _log.warning(
            "Not all JOIN references where resolved while building SQL>\n"
            "$from\n"
            "$joins\n"
            "$matcher",
          );
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
          limit: limit,
          offset: offset,
          orderByID: orderByID,
          orderDirection: orderDirection,
        );
      }
    });
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _onTransactionOperationSQL('selectSQL', op, sql);
      return doSelectSQL(entityName, table, sql, op.transaction, connection);
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

  FutureOr<SQL> generateDeleteSQL(
    Transaction transaction,
    String entityName,
    String table,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) {
    var retDeleteSQL = _generateSQLFrom(
      transaction,
      entityName,
      table,
      matcher,
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
      sqlBuilder: (String from, EncodingContext context) {
        var tableAlias = context.resolveEntityAlias(table);

        var sql = StringBuffer();
        sql.write('DELETE ');

        if (dialect.acceptsOutputSyntax) {
          sql.write(' OUTPUT DELETED.* ');
        }

        sql.write(from);

        if (dialect.acceptsReturningSyntax) {
          // Some dialects (SQLite) reject a table-qualified wildcard:
          // "RETURNING may not use TABLE.* wildcards".
          if (dialect.returningAcceptsTableWildcard) {
            sql.write(' RETURNING "$tableAlias".*');
          } else {
            sql.write(' RETURNING *');
          }
        }

        return sql.toString();
      },
    );

    if (dialect.acceptsTemporaryTableForReturning &&
        !dialect.acceptsOutputSyntax &&
        !dialect.acceptsReturningSyntax) {
      return retDeleteSQL.resolveMapped((deleteSQL) {
        var conditionSQL = deleteSQL.sqlCondition;

        var tableAlias = deleteSQL.tablesAliases?[table];

        var tmpTable = createTemporaryTableName(table);

        var q = dialect.elementQuote;

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
          mainTable: tmpTable,
        );

        var posSql1 = SQL(
          'SELECT * FROM $q$tmpTable$q',
          [],
          {},
          {},
          mainTable: tmpTable,
        );

        var posSql2 = SQL(
          'DROP TABLE $q$tmpTable$q',
          [],
          {},
          {},
          mainTable: tmpTable,
        );

        deleteSQL = deleteSQL.ensureNotSharedDummy();

        deleteSQL.preSQL = [preSql];
        deleteSQL.posSQL = [posSql1, posSql2];
        deleteSQL.posSQLReturnIndex = 0;

        return deleteSQL;
      });
    }

    return retDeleteSQL;
  }

  FutureOr<Iterable<Map<String, dynamic>>> deleteSQL(
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _onTransactionOperationSQL('deleteSQL', op, sql);
      return doDeleteSQL(entityName, table, sql, op.transaction, connection);
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
  DBSQLRepositoryAdapter<O>? createRepositoryAdapter<O>(
    String name, {
    String? tableName,
    Type? type,
  }) =>
      super.createRepositoryAdapter<O>(name, tableName: tableName, type: type)
          as DBSQLRepositoryAdapter<O>?;

  @override
  DBSQLRepositoryAdapter<O> instantiateRepositoryAdapter<O>(
    String name,
    String? tableName,
    Type? type,
  ) => DBSQLRepositoryAdapter<O>(this, name, tableName: tableName, type: type);

  @override
  DBSQLRepositoryAdapter<O>? getRepositoryAdapterByName<O>(String name) =>
      super.getRepositoryAdapterByName<O>(name) as DBSQLRepositoryAdapter<O>?;

  @override
  DBSQLRepositoryAdapter<O>? getRepositoryAdapterByType<O>(Type type) =>
      super.getRepositoryAdapterByType<O>(type) as DBSQLRepositoryAdapter<O>?;

  @override
  DBSQLRepositoryAdapter<O>? getRepositoryAdapterByTableName<O>(
    String tableName,
  ) =>
      super.getRepositoryAdapterByTableName<O>(tableName)
          as DBSQLRepositoryAdapter<O>?;

  FutureOr<R> _finishOperation<T, R>(
    TransactionOperation op,
    T res,
    PreFinishDBOperation<T, R>? preFinish,
  ) => finishOperation<T, R>(op, res, preFinish, errorResolver: resolveError);

  FutureOr<R> _finishSQLOperation<T, R>(
    Object sql,
    TransactionOperation op,
    T r,
    PreFinishDBOperation<T, R>? preFinish,
  ) {
    var sqlTime = DateTime.now().difference(op.initTime);

    String f() {
      if (sql is Iterable) {
        return '[tID: ${op.transactionId} ; time: ${sqlTime.inMilliseconds}:\n'
            '-- ${sql.join('\n-- ')}';
      } else {
        return '[tID: ${op.transactionId} ; time: ${sqlTime.inMilliseconds} ms] $sql';
      }
    }

    _log.logDB(logging.Level.INFO, f);

    return _finishOperation<T, R>(op, r, preFinish);
  }

  @override
  FutureOr<R> doDelete<R>(
    TransactionOperation op,
    String entityName,
    String table,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish,
  }) {
    return generateDeleteSQL(
      op.transaction,
      entityName,
      table,
      matcher,
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
    ).resolveMapped((sql) {
      return deleteSQL(
        op,
        entityName,
        table,
        sql,
      ).resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr doInsert<O>(
    TransactionOperation op,
    String entityName,
    String table,
    O o,
    Map<String, dynamic> fields, {
    String? idFieldName,
    PreFinishDBOperation<dynamic, dynamic>? preFinish,
  }) {
    return generateInsertSQL(
      op.transaction,
      entityName,
      table,
      fields,
    ).resolveMapped((sql) {
      return insertSQL(
        op,
        entityName,
        table,
        sql,
        fields,
      ).resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr<bool> doInsertRelationship(
    TransactionOperation op,
    String entityName,
    String table,
    String field,
    dynamic id,
    String otherTableName,
    List otherIds, [
    PreFinishDBOperation<bool, bool>? preFinish,
  ]) {
    var newEntity =
        generatedIDsHaveNoRelationships &&
        op is TransactionOperationStoreRelationship &&
        op.newEntity;

    return generateInsertRelationshipSQLs(
      op.transaction,
      entityName,
      table,
      field,
      id,
      otherTableName,
      otherIds,
      newEntity: newEntity,
    ).resolveMapped((sqls) {
      return insertRelationshipSQLs(
        op,
        entityName,
        table,
        sqls,
        id,
        otherTableName,
        otherIds,
      ).resolveMapped((r) => _finishSQLOperation(sqls, op, r, preFinish));
    });
  }

  @override
  FutureOr<R?> doSelectByID<R>(
    TransactionOperation op,
    String entityName,
    String table,
    Object id, {
    PreFinishDBOperation<Map<String, dynamic>?, R?>? preFinish,
  }) {
    return generateSelectSQL(
      op.transaction,
      entityName,
      table,
      ConditionID(id),
    ).resolveMapped((sql) {
      return selectSQL(op, entityName, table, sql).resolveMapped(
        (r) => _finishSQLOperation(sql, op, r.firstOrNull, preFinish),
      );
    });
  }

  @override
  FutureOr<List<R>> doSelectByIDs<R>(
    TransactionOperation op,
    String entityName,
    String table,
    List<Object> ids, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>? preFinish,
  }) {
    return generateSelectSQL(
      op.transaction,
      entityName,
      table,
      ConditionIdIN(ids),
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    ).resolveMapped((sql) {
      return selectSQL(
        op,
        entityName,
        table,
        sql,
      ).resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr<List<R>> doSelectAll<R>(
    TransactionOperation op,
    String entityName,
    String table, {
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>? preFinish,
  }) {
    return generateSelectSQL(
      op.transaction,
      entityName,
      table,
      ConditionANY(),
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    ).resolveMapped((sql) {
      return selectSQL(
        op,
        entityName,
        table,
        sql,
      ).resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr<R> doSelect<R>(
    TransactionOperation op,
    String entityName,
    String table,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish,
  }) {
    return generateSelectSQL(
      op.transaction,
      entityName,
      table,
      matcher,
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    ).resolveMapped((sql) {
      return selectSQL(
        op,
        entityName,
        table,
        sql,
      ).resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr<List<I>> doSelectIDsBy<I extends Object>(
    TransactionOperation op,
    String entityName,
    String table,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) {
    return generateSelectIDsSQL(
      op.transaction,
      entityName,
      table,
      matcher,
      parameters: parameters,
      positionalParameters: positionalParameters,
      namedParameters: namedParameters,
      limit: limit,
      offset: offset,
      orderByID: orderByID,
      orderDirection: orderDirection,
    ).resolveMapped((sql) {
      return selectSQL(op, entityName, table, sql).resolveMapped(
        (r) => _finishSQLOperation(sql, op, r, (results) {
          var ids = results.map((e) => e['id']);
          return parseIDs<I>(ids);
        }),
      );
    });
  }

  @override
  FutureOr<R> doSelectRelationship<R>(
    TransactionOperation op,
    String entityName,
    String table,
    String field,
    dynamic id,
    String otherTableName, [
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish,
  ]) {
    return generateSelectRelationshipSQL(
      op.transaction,
      entityName,
      table,
      field,
      id,
      otherTableName,
    ).resolveMapped((sql) {
      return selectRelationshipSQL(
        op,
        entityName,
        table,
        sql,
        id,
        otherTableName,
      ).resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr<R> doSelectRelationships<R>(
    TransactionOperation op,
    String entityName,
    String table,
    String field,
    List ids,
    String otherTableName, [
    PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish,
  ]) {
    return generateSelectRelationshipsSQL(
      op.transaction,
      entityName,
      table,
      field,
      ids,
      otherTableName,
    ).resolveMapped((sql) {
      return selectRelationshipsSQL(
        op,
        entityName,
        table,
        sql,
        ids,
        otherTableName,
      ).resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr doUpdate<O>(
    TransactionOperation op,
    String entityName,
    String table,
    O o,
    Object id,
    Map<String, dynamic> fields, {
    String? idFieldName,
    PreFinishDBOperation? preFinish,
    bool allowAutoInsert = false,
  }) {
    return generateUpdateSQL(
      op.transaction,
      entityName,
      table,
      id,
      fields,
    ).resolveMapped((sql) {
      return updateSQL(
        op,
        entityName,
        table,
        sql,
        id,
        fields,
        allowAutoInsert: allowAutoInsert,
      ).resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }
}

/// The duplicated indexes and enum `CHECK` constraints of a table
/// ([DBSQLAdapter.findTableDuplicates]). `checkTables` warns them: never an
/// error.
class TableDuplicates {
  final String table;

  /// The indexes over the same columns (in the same order): each group with
  /// the one to keep first.
  final List<List<String>> indexes;

  /// The enum `CHECK` constraints over the same column: by column, the one
  /// to keep first.
  final Map<String, List<String>> checkConstraints;

  /// The suggested SQLs (and comments) to drop the duplicates, keeping the
  /// first of each group.
  final List<String> dropSQLs;

  TableDuplicates(
    this.table, {
    this.indexes = const [],
    this.checkConstraints = const {},
    this.dropSQLs = const [],
  });

  bool get isEmpty => indexes.isEmpty && checkConstraints.isEmpty;

  bool get isNotEmpty => !isEmpty;

  @override
  String toString() {
    var duplicates = [
      if (indexes.isNotEmpty) 'duplicated indexes (same columns): $indexes',
      if (checkConstraints.isNotEmpty)
        'duplicated CHECK constraints (same column): $checkConstraints',
    ];
    return 'Table `$table`: ${duplicates.join('; ')}';
  }
}

class _DBTableCheck {
  EntityRepository<Object>? repository;
  TableScheme? scheme;
  List<_DBTableColumn>? missingColumns;

  List<_DBTableColumn>? missingReferenceColumns;

  List<_DBTableColumn>? missingCollectionReferenceColumns;

  List<_DBTableColumn>? missingReferenceConstraints;

  List<_DBTableColumn>? missingReferenceIndexes;

  List<_DBRelationshipTableColumn>? missingRelationshipReferenceIndexes;

  List<_DBTableColumn>? missingUniqueConstraints;

  List<_DBTableColumn>? missingEnumConstraints;
  Map<_DBTableColumn, List<String>>? missingEnumValues;

  /// The entity's indexes (`@EntityIndex`) missing in the table.
  List<CreateIndexSQL>? missingEntityIndexes;

  /// Of the [missingEntityIndexes], the ones whose name is in use by another
  /// index (or relation): by name, where (e.g. `over (a, b)`, `on table
  /// `t2``).
  Map<String, String>? entityIndexesNameConflicts;

  _DBTableCheck.missing(
    this.repository,
    this.scheme,
    this.missingColumns,
    this.missingReferenceColumns,
    this.missingCollectionReferenceColumns,
    this.missingReferenceConstraints,
    this.missingReferenceIndexes,
    this.missingRelationshipReferenceIndexes,
    this.missingUniqueConstraints,
    this.missingEnumConstraints,
    this.missingEnumValues, {
    this.missingEntityIndexes,
    this.entityIndexesNameConflicts,
  });

  String? error;

  _DBTableCheck.error(this.error);

  _DBTableCheck.ok();

  bool get isOK =>
      error == null &&
      (missingColumns?.isEmpty ?? true) &&
      (missingReferenceColumns?.isEmpty ?? true) &&
      (missingCollectionReferenceColumns?.isEmpty ?? true) &&
      (missingReferenceConstraints?.isEmpty ?? true) &&
      (missingReferenceIndexes?.isEmpty ?? true) &&
      (missingRelationshipReferenceIndexes?.isEmpty ?? true) &&
      (missingUniqueConstraints?.isEmpty ?? true) &&
      (missingEnumConstraints?.isEmpty ?? true) &&
      (missingEnumValues?.isEmpty ?? true) &&
      (missingEntityIndexes?.isEmpty ?? true);

  bool get isError => !isOK;

  List<AlterTableSQL> generateMissingColumnsSQLs(SQLGenerator sqlGenerator) =>
      _generateMissingColumnSQLs(missingColumns, sqlGenerator);

  List<AlterTableSQL> generateMissingReferenceColumnsSQLs(
    SQLGenerator sqlGenerator,
  ) => _generateMissingColumnSQLs(missingReferenceColumns, sqlGenerator);

  List<AlterTableSQL> generateMissingReferenceConstraintsSQLs(
    SQLGenerator sqlGenerator,
  ) {
    var columnsSQLs = _generateMissingColumnSQLs(
      missingReferenceConstraints,
      sqlGenerator,
    );

    var constraints = columnsSQLs
        .expand((e) => e.constraints ?? <AlterTableSQL>[])
        .toList();

    return constraints;
  }

  List<CreateIndexSQL> generateMissingReferenceIndexesSQLs(
    SQLGenerator sqlGenerator,
  ) {
    var columnsSQLs = _generateMissingColumnSQLs(
      missingReferenceIndexes,
      sqlGenerator,
    );

    var indexes = columnsSQLs
        .expand((e) => e.indexes ?? <CreateIndexSQL>[])
        .toList();

    return indexes;
  }

  List<CreateIndexSQL> generateMissingRelationshipReferenceIndexesSQLs(
    SQLGenerator sqlGenerator,
  ) {
    var columnsSQLs = _generateMissingColumnSQLs(
      missingRelationshipReferenceIndexes,
      sqlGenerator,
    );

    var indexes = columnsSQLs
        .expand((e) => e.indexes ?? <CreateIndexSQL>[])
        .toList();

    return indexes;
  }

  List<SQLBuilder> generateMissingUniqueConstraintsSQLs(
    SQLGenerator sqlGenerator,
  ) => _generateMissingUniqueConstraintsSQLs(
    missingUniqueConstraints,
    sqlGenerator,
  );

  List<AlterTableSQL> generateMissingEnumConstraintsSQLs(
    SQLGenerator sqlGenerator,
  ) =>
      _generateMissingEnumConstraintsSQLs(missingEnumConstraints, sqlGenerator);

  List<AlterTableSQL> generateMissingEnumValuesSQLs(
    SQLGenerator sqlGenerator,
  ) => _generateMissingEnumConstraintsSQLs(
    missingEnumValues?.keys,
    sqlGenerator,
  );

  List<AlterTableSQL> _generateMissingColumnSQLs(
    List<_DBTableColumn>? missing,
    SQLGenerator sqlGenerator,
  ) {
    var scheme = this.scheme;
    if (missing == null || missing.isEmpty || scheme == null) {
      return [];
    }

    var sqls = missing.map((f) {
      var schemeName = f is _DBRelationshipTableColumn
          ? f.relationshipTable
          : scheme.name;
      return sqlGenerator.generateAddColumnAlterTableSQL(
        schemeName,
        f.name,
        f.type,
        entityFieldAnnotations: f.annotations,
      );
    }).toList();

    return sqls;
  }

  List<SQLBuilder> _generateMissingUniqueConstraintsSQLs(
    Iterable<_DBTableColumn>? missing,
    SQLGenerator sqlGenerator,
  ) {
    var scheme = this.scheme;
    if (missing == null || missing.isEmpty || scheme == null) {
      return [];
    }

    // As in the `CREATE TABLE` (SQLite: a unique index):
    var sqls = missing.map((f) {
      var table = scheme.name;
      var column = sqlGenerator.normalizeColumnName(f.name);
      return sqlGenerator.generateAddUniqueConstraintSQL(
        table,
        '${table}__${column}__unique',
        [column],
        comment: '${f.type.toString(withT: false)} ${f.name} UNIQUE',
      );
    }).toList();

    return sqls;
  }

  List<AlterTableSQL> _generateMissingEnumConstraintsSQLs(
    Iterable<_DBTableColumn>? missing,
    SQLGenerator sqlGenerator,
  ) {
    var scheme = this.scheme;
    if (missing == null || missing.isEmpty || scheme == null) {
      return [];
    }

    var sqls = missing.map((f) {
      return sqlGenerator.generateAddEnumConstraintAlterTableSQL(
        scheme.name,
        f.name,
        f.type,
        entityFieldAnnotations: f.annotations,
      );
    }).toList();

    return sqls;
  }

  @override
  String toString() {
    var missingColumns = this.missingColumns ?? [];
    var missingReferenceColumns = this.missingReferenceColumns ?? [];
    var missingCollectionReferenceColumns =
        this.missingCollectionReferenceColumns ?? [];

    var missingReferenceConstraints = this.missingReferenceConstraints ?? [];
    var missingReferenceIndexes = this.missingReferenceIndexes ?? [];
    var missingRelationshipReferenceIndexes =
        this.missingRelationshipReferenceIndexes ?? [];
    var missingEntityIndexes = this.missingEntityIndexes ?? [];
    var missingUniqueConstraints = this.missingUniqueConstraints ?? [];
    var missingEnumConstraints = this.missingEnumConstraints ?? [];
    var missingEnumValues = this.missingEnumValues ?? {};

    if (missingColumns.isNotEmpty ||
        missingReferenceColumns.isNotEmpty ||
        missingCollectionReferenceColumns.isNotEmpty ||
        missingReferenceConstraints.isNotEmpty ||
        missingReferenceIndexes.isNotEmpty ||
        missingRelationshipReferenceIndexes.isNotEmpty ||
        missingUniqueConstraints.isNotEmpty ||
        missingEnumConstraints.isNotEmpty ||
        missingEnumValues.isNotEmpty ||
        missingEntityIndexes.isNotEmpty) {
      var repoType = repository?.type;
      var schemeTableName = scheme?.name;

      var missingColumnsStr = missingColumns
          .map((e) => '${e.type.toString(withT: false)} ${e.name}')
          .join(' , ');

      var missingReferenceColumnsStr = missingReferenceColumns
          .map((e) => '${e.type.toString(withT: false)} ${e.name}')
          .join(' , ');

      var missingReferenceConstraintsStr = missingReferenceConstraints
          .map((e) => '${e.type.toString(withT: false)} ${e.name}')
          .join(' , ');

      var missingReferenceIndexesStr = missingReferenceIndexes
          .map((e) => '${e.type.toString(withT: false)} ${e.name}')
          .join(' , ');

      var missingRelationshipReferenceIndexesStr =
          missingRelationshipReferenceIndexes
              .map((e) => '${e.type.toString(withT: false)} ${e.name}')
              .join(' , ');

      var missingCollectionReferenceColumnsStr =
          missingCollectionReferenceColumns
              .map((e) => '${e.type.toString(withT: false)} ${e.name}')
              .join(' , ');

      var errorMsg = [
        "Can't find all `$repoType` fields in table `$schemeTableName` scheme:",
        "  -- repository: $repository\n  -- scheme: $scheme",
        if (missingColumns.isNotEmpty)
          "  -- missingColumns: [$missingColumnsStr]",
        if (missingReferenceColumns.isNotEmpty)
          "  -- missingReferenceColumns: [$missingReferenceColumnsStr]",
        if (missingReferenceConstraints.isNotEmpty)
          "  -- missingReferenceConstraints: [$missingReferenceConstraintsStr]",
        if (missingReferenceIndexes.isNotEmpty)
          "  -- missingReferenceIndexes: [$missingReferenceIndexesStr]",
        if (missingRelationshipReferenceIndexes.isNotEmpty)
          "  -- missingRelationshipReferenceIndexes: [$missingRelationshipReferenceIndexesStr]",
        if (missingCollectionReferenceColumns.isNotEmpty)
          "  -- missingCollectionReferenceColumns: [$missingCollectionReferenceColumnsStr]",
        if (missingUniqueConstraints.isNotEmpty)
          "  -- missingUniqueConstraints: [${missingUniqueConstraints.map((e) => e.name).join(' , ')}]",
        if (missingEnumConstraints.isNotEmpty)
          "  -- missingEnumConstraints: [${missingEnumConstraints.map((e) => '${e.type.toString(withT: false)} ${e.name}').join(' , ')}]",
        if (missingEnumValues.isNotEmpty)
          "  -- missingEnumValues: [${missingEnumValues.entries.map((e) => '${e.key.name}: ${e.value.join(', ')}').join(' , ')}]",
        if (missingEntityIndexes.isNotEmpty)
          "  -- missingEntityIndexes: [${missingEntityIndexes.map((e) {
            var conflict = entityIndexesNameConflicts?[e.indexName];
            var desc = '${e.indexName}(${e.columns.join(', ')})${e.unique ? ' UNIQUE' : ''}';
            return conflict == null ? desc : '$desc <name in use $conflict: drop it first>';
          }).join(' , ')}]",
      ].join('\n');

      return '$errorMsg\n';
    }

    return error?.toString() ?? '';
  }
}

class _DBRelationshipTableColumn extends _DBTableColumn {
  final String relationshipTable;

  _DBRelationshipTableColumn(
    this.relationshipTable,
    super.name,
    super.type,
    super.annotations,
  );

  @override
  String toString() => '{$relationshipTable.$name: $type}';
}

class _DBTableColumn {
  final String name;
  final TypeInfo type;
  final List<EntityField>? annotations;

  _DBTableColumn(this.name, this.type, this.annotations);

  factory _DBTableColumn.fromEntityHandler(
    EntityHandler<Object> entityHandler,
    String fieldName,
  ) {
    var type =
        entityHandler.getFieldType(null, fieldName, resolveFiledName: true) ??
        TypeInfo.tString;

    var annotations = entityHandler
        .getFieldEntityAnnotations(null, fieldName)
        ?.whereType<EntityField>()
        .toList();
    return _DBTableColumn(fieldName, type, annotations);
  }

  @override
  String toString() => '{$name: $type}';
}

/// An adapter for [EntityRepository] and [DBSQLAdapter].
class DBSQLRepositoryAdapter<O> extends DBRelationalRepositoryAdapter<O> {
  @override
  DBSQLAdapter get databaseAdapter => super.databaseAdapter as DBSQLAdapter;

  DBSQLRepositoryAdapter(
    DBSQLAdapter super.databaseAdapter,
    super.name, {
    super.tableName,
    super.type,
  });

  @override
  SQLDialect get dialect => super.dialect as SQLDialect;

  FutureOr<SQL> generateCountSQL(
    Transaction transaction, {
    EntityMatcher? matcher,
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => databaseAdapter.generateCountSQL(
    transaction,
    name,
    tableName,
    matcher: matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
  );

  FutureOr<int> countSQL(TransactionOperation op, SQL sql) {
    return databaseAdapter.countSQL(op, name, tableName, sql);
  }

  FutureOr<SQL> generateSelectSQL(
    Transaction transaction,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
    int? limit,
    int? offset,
    bool? orderByID,
    OrderDirection? orderDirection,
  }) => databaseAdapter.generateSelectSQL(
    transaction,
    name,
    tableName,
    matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
    limit: limit,
    offset: offset,
    orderByID: orderByID,
    orderDirection: orderDirection,
  );

  FutureOr<Iterable<Map<String, dynamic>>> selectSQL(
    TransactionOperation op,
    SQL sql,
  ) {
    return databaseAdapter.selectSQL(op, name, tableName, sql);
  }

  FutureOr<SQL> generateInsertSQL(
    Transaction transaction,
    O o,
    Map<String, dynamic> fields,
  ) {
    return databaseAdapter.generateInsertSQL(
      transaction,
      name,
      tableName,
      fields,
    );
  }

  FutureOr<dynamic> insertSQL(
    TransactionOperation op,
    SQL sql,
    Map<String, dynamic> fields, {
    String? idFieldName,
  }) {
    return databaseAdapter
        .insertSQL(op, name, tableName, sql, fields)
        .resolveMapped((ret) => ret ?? {});
  }

  FutureOr<SQL> generateUpdateSQL(
    Transaction transaction,
    O o,
    Object id,
    Map<String, dynamic> fields,
  ) {
    return databaseAdapter.generateUpdateSQL(
      transaction,
      name,
      tableName,
      id,
      fields,
    );
  }

  FutureOr<dynamic> updateSQL(
    TransactionOperation op,
    SQL sql,
    Object id,
    Map<String, dynamic> fields, {
    String? idFieldName,
    bool allowAutoInsert = false,
  }) {
    return databaseAdapter
        .updateSQL(
          op,
          name,
          tableName,
          sql,
          id,
          fields,
          allowAutoInsert: allowAutoInsert,
        )
        .resolveMapped((ret) => ret ?? {});
  }

  FutureOr<List<SQL>> generateInsertRelationshipSQLs(
    Transaction transaction,
    String field,
    dynamic id,
    String otherTableName,
    List otherIds,
  ) {
    return databaseAdapter.generateInsertRelationshipSQLs(
      transaction,
      name,
      tableName,
      field,
      id,
      otherTableName,
      otherIds,
    );
  }

  FutureOr<bool> insertRelationshipSQLs(
    TransactionOperation op,
    List<SQL> sqls,
    dynamic id,
    String otherTableName,
    List otherIds,
  ) {
    return databaseAdapter.insertRelationshipSQLs(
      op,
      name,
      tableName,
      sqls,
      id,
      otherTableName,
      otherIds,
    );
  }

  FutureOr<SQL> generateSelectRelationshipSQL(
    Transaction transaction,
    String field,
    dynamic id,
    String otherTableName,
  ) {
    return databaseAdapter.generateSelectRelationshipSQL(
      transaction,
      name,
      tableName,
      field,
      id,
      otherTableName,
    );
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipSQL(
    TransactionOperation op,
    SQL sql,
    dynamic id,
    String otherTableName,
  ) {
    return databaseAdapter.selectRelationshipSQL(
      op,
      name,
      tableName,
      sql,
      id,
      otherTableName,
    );
  }

  FutureOr<SQL> generateSelectRelationshipsSQL(
    Transaction transaction,
    String field,
    List<dynamic> ids,
    String otherTableName,
  ) {
    return databaseAdapter.generateSelectRelationshipsSQL(
      transaction,
      name,
      tableName,
      field,
      ids,
      otherTableName,
    );
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipsSQL(
    TransactionOperation op,
    SQL sql,
    List<dynamic> ids,
    String otherTableName,
  ) {
    return databaseAdapter.selectRelationshipsSQL(
      op,
      name,
      tableName,
      sql,
      ids,
      otherTableName,
    );
  }

  FutureOr<SQL> generateDeleteSQL(
    Transaction transaction,
    EntityMatcher matcher, {
    Object? parameters,
    List? positionalParameters,
    Map<String, Object?>? namedParameters,
  }) => databaseAdapter.generateDeleteSQL(
    transaction,
    name,
    tableName,
    matcher,
    parameters: parameters,
    positionalParameters: positionalParameters,
    namedParameters: namedParameters,
  );

  FutureOr<Iterable<Map<String, dynamic>>> deleteSQL(
    TransactionOperation op,
    SQL sql,
  ) {
    return databaseAdapter.deleteSQL(op, name, tableName, sql);
  }

  @override
  String toString() =>
      'SQLRepositoryAdapter{name: $name, tableName: $tableName, type: $type}';
}

/// A [SQLAdapter] [Exception].
class DBSQLAdapterException extends DBAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBSQLAdapterException';

  DBSQLAdapterException(
    super.type,
    super.message, {
    super.parentError,
    super.parentStackTrace,
    super.operation,
    super.previousError,
  });
}

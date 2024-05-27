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

final _log = logging.Logger('SQLAdapter')..registerAsDbLogger();

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

  bool get hasPreSQL {
    var preSQL = this.preSQL;
    return preSQL != null && preSQL.isNotEmpty;
  }

  bool get hasPosSQL {
    var posSQL = this.posSQL;
    return posSQL != null && posSQL.isNotEmpty;
  }

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

  const DBSQLAdapterCapability(
      {required super.dialect,
      required super.transactions,
      required super.transactionAbort,
      required super.constraintSupport,
      required this.tableSQL,
      required super.multiIsolateSupport});

  @override
  String get info => '${super.info}, tableSQL: $tableSQL';

  @override
  String get runtimeTypeNameSafe => 'DBSQLAdapterCapability';
}

typedef DBSQLAdapterInstantiator<C extends Object, A extends DBSQLAdapter<C>>
    = DBAdapterInstantiator<C, A>;

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
      DBSQLAdapterInstantiator<C, A> adapterInstantiator) {
    boot();
    adapterRegister.registerAdapter(names, type, adapterInstantiator);
  }

  static DBSQLAdapterInstantiator<C, A>?
      getAdapterInstantiator<C extends Object, A extends DBSQLAdapter<C>>(
              {String? name, Type? type}) =>
          adapterRegister.getAdapterInstantiator<C, A>(name: name, type: type);

  static List<MapEntry<DBSQLAdapterInstantiator<C, A>, Map<String, dynamic>>>
      getAdapterInstantiatorsFromConfig<C extends Object,
              A extends DBSQLAdapter<C>>(Map<String, dynamic> config) =>
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
        return parseBool(log);
      }
    }
    if (log != null) {
      return parseBool(log);
    }

    return null;
  }

  static List<bool> parseConfigDBGenerateTablesAndCheckTables(
      Map<String, dynamic>? config) {
    bool? checkTables;
    bool? generateTables;

    const generateTablesKeys = [
      'generateTables',
      'generate-tables',
      'generate_tables',
    ];

    const checkTablesKeys = [
      'checkTables',
      'check-tables',
      'check_tables',
    ];

    generateTables =
        config?.getMultiKeyAsBool(generateTablesKeys, ignoreCase: true);

    checkTables = config?.getMultiKeyAsBool(checkTablesKeys, ignoreCase: true);

    if (generateTables == null || checkTables == null) {
      var populate = config?['populate'];

      if (populate is Map) {
        generateTables ??=
            populate.getMultiKeyAsBool(generateTablesKeys, ignoreCase: true);

        checkTables ??=
            populate.getMultiKeyAsBool(checkTablesKeys, ignoreCase: true);
      }
    }

    generateTables ??= false;
    checkTables ??= true;

    return [generateTables, checkTables];
  }

  /// The [DBSQLAdapter] capability.
  @override
  DBSQLAdapterCapability get capability =>
      super.capability as DBSQLAdapterCapability;

  final bool logSQL;

  late final ConditionSQLEncoder _conditionSQLGenerator;

  DBSQLAdapter(super.name, super.minConnections, super.maxConnections,
      DBSQLAdapterCapability super.capability,
      {bool generateTables = false,
      bool checkTables = true,
      Object? populateTables,
      super.parentRepositoryProvider,
      super.populateSource,
      super.populateSourceVariables,
      super.workingPath,
      this.logSQL = false})
      : _generateTables = generateTables,
        _checkTables = checkTables,
        _populateTables = populateTables {
    boot();

    _conditionSQLGenerator =
        ConditionSQLEncoder(this, sqlElementQuote: dialect.elementQuote);
  }

  static FutureOr<A> fromConfig<C extends Object, A extends DBSQLAdapter<C>>(
      Map<String, dynamic> config,
      {int minConnections = 1,
      int maxConnections = 3,
      EntityRepositoryProvider? parentRepositoryProvider,
      String? workingPath}) {
    boot();

    var instantiators = getAdapterInstantiatorsFromConfig<C, A>(config);

    if (instantiators.isEmpty) {
      throw StateError(
          "Can't find `$A` instantiator for `config` keys: ${config.keys.toList()}");
    }

    return DBAdapter.instantiateAdaptor<C, A>(instantiators, config,
        minConnections: minConnections,
        maxConnections: maxConnections,
        parentRepositoryProvider: parentRepositoryProvider,
        workingPath: workingPath);
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

  FutureOr<bool> checkDBTables() {
    if (!_checkTables) {
      _log.warning("Ignoring check of DB tables for $this.");
      return true;
    }

    _checkTables = false;

    _log.info("Checking DB tables for $this> loading tables schemes...");

    var repositorySchemes = getRepositoriesSchemes();

    return repositorySchemes.resolveMapped(_checkDBTablesImpl);
  }

  FutureOr<bool> _checkDBTablesImpl(
      Map<EntityRepository<Object>, TableScheme?> repositorySchemes) {
    var repositoriesChecks = repositorySchemes.entries
        .map((e) => _checkDBTableScheme(e.key, e.value))
        .toList();

    var repositoriesChecksErrors =
        repositoriesChecks.where((e) => e.isError).toList();

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

      var alterTablesSQLs = [
        ...missingColumnsSQLs,
        '',
        ...missingReferenceColumnsSQLs,
        '',
        ...missingReferenceConstraintsSQLs,
        '',
        ...missingUniqueConstraintsSQLs,
        '',
        ...missingEnumConstraintsSQLs,
        '',
        ...missingEnumValuesSQLs,
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

      _log.info(
          'Suggestion of SQLs (`$dialectName`) to fix missing columns in tables:\n\n  ${alterTablesSQLs.join('\n  ')}\n');

      var allErrors = repositoriesChecksErrors.join('\n');

      throw StateError('Error checking DB tables:\n\n$allErrors');
    }

    _log.info('All tables OK @ $this');

    _checkedTables = true;
    return true;
  }

  _DBTableCheck _checkDBTableScheme(
      EntityRepository<Object> repository, TableScheme? scheme) {
    var repoType = repository.type;

    if (scheme == null) {
      _log.severe(
          'No scheme for repository `${repository.name}` (`$repoType`) in this adapter> generateTables: $_generateTables @ $this');

      return _DBTableCheck.error(
          'No scheme for repository `${repository.name}` (`$repoType`) in this adapter> generateTables: $_generateTables @ $this');
    }

    var schemeTableName = scheme.name;

    final entityHandler = repository.entityHandler;
    var entityFields = entityHandler.fieldsNames();

    var hiddenFields = entityFields
        .map((f) {
          var annotations = entityHandler.getFieldEntityAnnotations(null, f);
          if (annotations == null) return null;
          var hidden = annotations.any((a) => a is EntityField && a.isHidden);
          return hidden ? f : null;
        })
        .whereNotNull()
        .toList(growable: false);

    if (hiddenFields.isNotEmpty) {
      _log.info(
          "Entity `$repoType` (table: `$schemeTableName`) hidden fields: $hiddenFields");
    }

    var repoFieldsNames = entityFields.whereNotIn(hiddenFields).toList();

    var repoFieldsMap =
        repoFieldsNames.map((f) => MapEntry(f, f)).toMapFromEntries();

    var repoTable = getTableForEntityRepository(repository);

    var schemeToRepoMap =
        scheme.getFieldsKeysInMap(scheme.fieldsNames, repoFieldsMap);

    var schemesTypes = schemeToRepoMap.entries
        .map((e) {
          var schemeField = e.key;
          var repoField = e.value;
          if (repoField == null) return null;
          return MapEntry(repoField, scheme.fieldsTypes[schemeField]);
        })
        .whereNotNull()
        .toMapFromEntries();

    for (var e in schemesTypes.entries) {
      var field = e.key;
      var schemeType = e.value;
      var fieldType = entityHandler.getFieldType(null, field);

      if (!checkDBTableField(repoType, field, schemeType, fieldType)) {
        return _DBTableCheck.error(
            "Invalid scheme type> entityType: $repoType; field: $field ; schemeType: $schemeType ; fieldType: $fieldType");
      }
    }

    var fieldsInScheme = schemeToRepoMap.values.toList();

    var repoFieldsNotInScheme =
        repoFieldsNames.whereNot((f) => fieldsInScheme.contains(f)).toList();

    var referenceFields = repoFieldsNotInScheme
        .map((f) => _checkDBTableSchemeReferenceField(
            entityHandler, scheme, repoTable, f))
        .whereNotNull()
        .toMapFromEntries();

    var missingReferenceColumns = referenceFields.entries
        .where((e) => e.value == null)
        .map((e) => e.key)
        .toList();

    var missingColumns = repoFieldsNames
        .whereNot(
            (f) => fieldsInScheme.contains(f) || referenceFields.containsKey(f))
        .toList();

    var missingFieldReferenceConstraints = <String>{};

    var missingUniqueConstraints = <String>{};

    var missingEnumConstraints = <String>{};
    var missingEnumValues = <String, List<String>>{};

    if (capability.constraintSupport) {
      final reflectionFactory = ReflectionFactory();

      // REF CONSTRAINTS //

      var fieldEntityTypes = entityHandler
          .getFieldsEntityTypes()
          .entries
          .map((e) {
            var entityType = e.value.entityType;
            if (entityType == null) return null;

            var refRepository =
                repository.provider.getEntityRepositoryByType(entityType);

            if (refRepository == null ||
                !refRepository.isSameEntityManager(repository)) {
              return null;
            }

            return MapEntry(e.key, entityType);
          })
          .whereNotNull()
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
            .whereNotNull()
            .toMapFromEntries();

        missingFieldReferenceConstraints = fieldEntityTypes.keys
            .where((f) => !fieldsReferences.containsKey(f))
            .toSet();
      }

      // UNIQUE CONSTRAINTS //

      var uniqueConstraints =
          scheme.constraints.whereType<TableUniqueConstraint>().toList();

      var uniqueConstraintsFields =
          uniqueConstraints.toFields(fieldMap: schemeToRepoMap);

      var entityUniqueFields = entityHandler
          .getAllFieldsWithEntityAnnotation<EntityField>(
              null, (a) => a.isUnique)
          .keys
          .toList();

      missingUniqueConstraints =
          entityUniqueFields.whereNotIn(uniqueConstraintsFields).toSet();

      // ENUM CONSTRAINTS //

      var enumConstraints =
          scheme.constraints.whereType<TableEnumConstraint>().toList();

      var enumConstraintsFields =
          enumConstraints.toFields(fieldMap: schemeToRepoMap);

      var entityEnumFields = entityHandler.getFieldsEnumTypes().keys.toList();

      missingEnumConstraints =
          entityEnumFields.whereNotIn(enumConstraintsFields).toSet();

      for (var e in enumConstraints) {
        var fieldType = entityHandler.getFieldType(null, e.field);
        if (fieldType == null) continue;

        var enumReflection =
            reflectionFactory.getRegisterEnumReflection(fieldType.type);
        if (enumReflection == null) continue;

        var valuesNames = enumReflection.valuesNames;

        var missingValues = valuesNames.whereNotIn(e.values).toList();

        if (missingValues.isNotEmpty) {
          missingEnumValues[e.field] = missingValues;
        }
      }
    }

    if (missingColumns.isNotEmpty ||
        missingReferenceColumns.isNotEmpty ||
        missingFieldReferenceConstraints.isNotEmpty ||
        missingUniqueConstraints.isNotEmpty ||
        missingEnumConstraints.isNotEmpty ||
        missingEnumValues.isNotEmpty) {
      _log.severe(
          "ERROR Checking table `$schemeTableName`> entityType: `$repoType`\n"
          "${missingColumns.isNotEmpty ? '-- missingColumns: $missingColumns\n' : ''}"
          "${missingReferenceColumns.isNotEmpty ? '-- missingReferenceColumns: $missingReferenceColumns\n' : ''}"
          "${missingFieldReferenceConstraints.isNotEmpty ? '-- missingFieldReferenceConstraints: $missingFieldReferenceConstraints\n' : ''}"
          "${missingUniqueConstraints.isNotEmpty ? '-- missingUniqueConstraints: $missingUniqueConstraints\n' : ''}"
          "${missingEnumConstraints.isNotEmpty ? '-- missingEnumConstraints: $missingEnumConstraints\n' : ''}"
          "${missingEnumValues.isNotEmpty ? '-- missingEnumValues: $missingEnumValues\n' : ''}");

      return _DBTableCheck.missing(
        repository,
        scheme,
        missingColumns
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingReferenceColumns
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingFieldReferenceConstraints
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingUniqueConstraints
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingEnumConstraints
            .map((f) => _DBTableColumn.fromEntityHandler(entityHandler, f))
            .toList(),
        missingEnumValues.entries
            .map((e) => MapEntry(
                _DBTableColumn.fromEntityHandler(entityHandler, e.key),
                e.value))
            .toMapFromEntries(),
      );
    }

    _log.info('Checking table `$schemeTableName`: OK');

    return _DBTableCheck.ok();
  }

  MapEntry<String, TableRelationshipReference?>?
      _checkDBTableSchemeReferenceField(
    EntityHandler<Object> entityHandler,
    TableScheme scheme,
    String table,
    String fieldName,
  ) {
    var fieldType = entityHandler.getFieldType(null, fieldName);
    if (fieldType == null) return null;
    var entityType = fieldType.entityTypeInfo ?? fieldType.listEntityType;
    if (entityType == null) return null;
    var targetTable = getTableForType(entityType);
    if (targetTable == null) return null;

    TableRelationshipReference? tableRef;

    try {
      tableRef = scheme.getTableRelationshipReference(
          sourceTable: table, sourceField: fieldName, targetTable: targetTable);
    } catch (e) {
      _log.warning(
          "Error while getting relationship table for field: `$table`.`$fieldName`",
          e);
    }

    return MapEntry(fieldName, tableRef);
  }

  bool checkDBTableField(Type entityType, String fieldName, Type? schemeType,
      TypeInfo<dynamic>? fieldType) {
    if (schemeType == null || fieldType == null) {
      throw StateError(
          "Invalid scheme field(`$entityType`.`$fieldName`) type> schemeType: $schemeType ; fieldType: $fieldType > $this");
    }

    var fieldEntityType = fieldType.entityType;

    if (fieldEntityType != null) {
      if (schemeType != fieldEntityType &&
          !schemeType.isEntityIDType &&
          !fieldType.isEntityReferenceBaseType) {
        throw StateError(
            "Invalid scheme field(`$fieldName`) type> fieldEntityType: $fieldEntityType ; schemeType: $schemeType (invalid ID type) > $this");
      }

      return true;
    } else {
      var type = fieldType.type;
      if (schemeType == type) {
        return true;
      }

      if (schemeType == String) {
        var enumReflection =
            ReflectionFactory().getRegisterEnumReflection(type);
        if (enumReflection != null && enumReflection.enumType == type) {
          return true;
        }
      }

      throw StateError(
          "Invalid scheme field(`$fieldName`) type> fieldType: $type != schemeType: $schemeType > $this");
    }
  }

  Future<Map<EntityRepository<Object>, TableScheme?>>
      getRepositoriesSchemes() async {
    var reposBlocks =
        entityRepositories.splitBeforeIndexed((i, r) => i % 2 == 0).toList();

    final allSchemes = <EntityRepository<Object>, TableScheme?>{};

    // Call `getTableSchemeForEntityRepository` with a `contextID` to allow
    // shared internal cache between multiple calls:
    final contextID = List.unmodifiable([this, "getRepositoriesSchemes"]);

    for (var block in reposBlocks) {
      var repositorySchemes = await block
          .map((r) => MapEntry(
              r, getTableSchemeForEntityRepository(r, contextID: contextID)))
          .toMapFromEntries()
          .resolveAllValues();

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
    }).resolveMapped((tables) {
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
                  'Populating $this tables [SQL length: ${data.length}]...');

              return populateTablesFromSQLs(data).resolveMapped((tables) {
                _log.info('Populate tables finished: $tables');
                return tables;
              });
            } else {
              return <String>[];
            }
          });
        }
      } else if (RegExp(r'(?:^|\s+)(?:CREATE|ALTER)\s+TABLE\s')
          .hasMatch(tables)) {
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
            r'''(?:^|\s)(?:CREATE|ALTER)\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?['"`]?(\w+)['"`]?''')
        .firstMatch(tableSQL);

    return match?.group(1);
  }

  static List<String> extractTableSQLs(String sqls) => extractSQLs(sqls,
      RegExp(r'(?:CREATE|ALTER)\s+TABLE', caseSensitive: false, dotAll: true));

  static List<String> extractSQLs(String sqls, RegExp commandPrefixPattern) {
    sqls = removeSQLsComments(sqls);
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

  static String removeSQLsComments(String sqls) {
    sqls =
        sqls.replaceAllMapped(RegExp(r'/\*.*?\*/', dotAll: true), (m) => m[1]!);

    while (true) {
      var prev = sqls;
      sqls = sqls.replaceAllMapped(
          RegExp(r'(?:^|\n)--[^\n]*?([\r\n]+)', dotAll: true), (m) => m[1]!);
      if (prev == sqls) break;
    }

    sqls = sqls.replaceAllMapped(
        RegExp(r'[ \t]--[ \t][^\n]*?(\n|$)', dotAll: true), (m) => m[1]!);

    return sqls;
  }

  FutureOr<List<String>> populateTablesFromSQLs(String sqls) {
    var list = extractTableSQLs(sqls);
    if (list.isEmpty) return <String>[];
    return _populateTablesFromSQLsImpl(list);
  }

  Future<List<String>> _populateTablesFromSQLsImpl(List<String> list) async {
    var tables = <String>[];

    for (var sql in list) {
      _log.info("Populating table:\n<<<\n${sql.trim()}\n>>>");

      var ok = await executeTableSQL(sql);
      if (!ok) {
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
        verbose: !DBAdapter.auxiliaryMode);

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
      generateEntityRepositoresCreateTableSQLs(
              {bool ifNotExists = true,
              bool sortColumns = true,
              bool verbose = false}) =>
          entityRepositories
              .map((r) => MapEntry<EntityRepository, CreateTableSQL>(
                  r,
                  generateCreateTableSQL(
                      entityRepository: r,
                      ifNotExists: ifNotExists,
                      sortColumns: sortColumns)))
              .toHierarchicalOrder(verbose: verbose)
              .toMapFromEntries();

  /// Generate all the SQLs to create the tables.
  @override
  List<SQLBuilder> generateCreateTableSQLs(
      {bool ifNotExists = true, bool sortColumns = true}) {
    var sqls = generateEntityRepositoresCreateTableSQLs(
        ifNotExists: ifNotExists, sortColumns: sortColumns);

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
          Map<String, Object?> fieldsValues) =>
      _resolveFieldValueToSQL(context, tableScheme, fieldName, value)
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

      var retRefId = refEntityRepository.store(refEntity,
          transaction: context.transaction);
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

      var refEntityHandler = reflection?.entityHandler ??
          reflectionFactory.getRegisterEntityHandler(valueType);

      var refId = refEntityHandler?.getID(entity);
      return refId;
    }
  }

  FutureOr<bool> executeTableSQL(String createTableSQL);

  FutureOr<SQL> generateCountSQL(
      Transaction transaction, String entityName, String table,
      {EntityMatcher? matcher,
      Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters}) {
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
      _logTransactionOperationSQL('countSQL', op, sql);
      return doCountSQL(entityName, table, sql, op.transaction, connection);
    });
  }

  void _logTransactionOperationSQL(
      String method, TransactionOperation op, Object sql) {
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
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  FutureOr<SQL> generateExistIDsSQL<I extends Object>(
      Transaction transaction, String entityName, String table, List<I> ids) {
    if (ids.isEmpty) return SQL.dummy;

    return _generateSQLFrom(transaction, entityName, table, ConditionIdIN(ids),
        sqlBuilder: (String from, EncodingContext context) {
      var tableFieldID = context.tableFieldID ?? 'id';
      var tableAlias = context.resolveEntityAlias(table);
      var q = dialect.elementQuote;
      var sql = 'SELECT $q$tableAlias$q.$q$tableFieldID$q as ${q}id$q $from';
      return sql;
    });
  }

  FutureOr<List<I>> existIDsSQL<I extends Object>(
      TransactionOperation op, String entityName, String table, SQL sql) {
    if (sql.isDummy) return [];

    return executeTransactionOperation(op, sql, (connection) {
      _logTransactionOperationSQL('existIDsSQL', op, sql);
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
      TransactionOperation op, String entityName, String table, List<I> ids) {
    return generateExistIDsSQL(op.transaction, entityName, table, ids)
        .resolveMapped((sql) {
      return existIDsSQL(op, entityName, table, sql).resolveMapped(
          (r) => _finishSQLOperation(sql, op, r, (ids) => parseIDs<I>(ids)));
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
          namedParameters: fields,
          transaction: transaction,
          tableName: table,
          tableFieldID: tableScheme.idFieldName);

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

        return SQL(sql.toString(), null, fields, fieldsValuesInSQL,
            entityName: table, idFieldName: idFieldName, mainTable: table);
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
      _logTransactionOperationSQL('insertSQL', op, sql);
      return doInsertSQL(entityName, table, sql, op.transaction, connection);
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
          namedParameters: fields,
          transaction: transaction,
          tableFieldID: tableScheme.idFieldName);

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
      {bool allowAutoInsert = false}) {
    if (sql.isDummy) return id;

    return executeTransactionOperation(op, sql, (connection) {
      _logTransactionOperationSQL('updateSQL', op, sql);
      return doUpdateSQL(entityName, table, sql, id, op.transaction, connection,
          allowAutoInsert: allowAutoInsert);
    });
  }

  FutureOr<dynamic> doUpdateSQL(String entityName, String table, SQL sql,
      Object id, Transaction transaction, C connection,
      {bool allowAutoInsert = false});

  FutureOr<List<SQL>> generateInsertRelationshipSQLs(
      Transaction transaction,
      String entityName,
      String table,
      String field,
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

      var relationship = tableScheme.getTableRelationshipReference(
          sourceTable: table, sourceField: field, targetTable: otherTableName);

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
          tableScheme, table, field, id, otherTableName, otherIds);

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

    return SQL(sql.toString(), null, parameters, parameters,
        mainTable: relationshipTable, relationship: relationship);
  }

  SQL _generateConstrainRelationshipSQL(TableScheme tableScheme, String table,
      String field, dynamic id, String otherTableName, List otherIds) {
    var relationship = tableScheme.getTableRelationshipReference(
        sourceTable: table, sourceField: field, targetTable: otherTableName);

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
    if (sqls.length == 1 && sqls.first.isFullyDummy) {
      return true;
    }

    return executeTransactionOperation(op, sqls.first, (connection) {
      _logTransactionOperationSQL('insertRelationshipSQLs', op, sqls);

      var retInserts = sqls.map((sql) {
        var ret = doInsertRelationshipSQL(entityName, sql.mainTable ?? table,
            sql, op.transaction, connection);

        if (sql.hasPosSQL) {
          sql.posSQL!.map((e) {
            _logTransactionOperationSQL('insertRelationship[POS]', op, e);
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

  FutureOr<SQL> generateSelectRelationshipSQL(
      Transaction transaction,
      String entityName,
      String table,
      String field,
      dynamic id,
      String otherTableName) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var relationship = tableScheme.getTableRelationshipReference(
          sourceTable: table, sourceField: field, targetTable: otherTableName);

      if (relationship == null) {
        throw StateError(
            "Can't find TableRelationshipReference for tables: $table -> $otherTableName");
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
      _logTransactionOperationSQL('selectRelationshipSQL', op, sql);

      var ret = doSelectSQL(
          entityName, sql.mainTable ?? table, sql, op.transaction, connection);
      return ret;
    });
  }

  FutureOr<SQL> generateSelectRelationshipsSQL(
      Transaction transaction,
      String entityName,
      String table,
      String field,
      List<dynamic> ids,
      String otherTableName) {
    var retTableScheme = getTableScheme(table);

    return retTableScheme.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for table: $table";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var relationship = tableScheme.getTableRelationshipReference(
          sourceTable: table, sourceField: field, targetTable: otherTableName);

      if (relationship == null) {
        throw StateError(
            "Can't find TableRelationshipReference for tables: $table -> $otherTableName");
      }

      var q = dialect.elementQuote;

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
      _logTransactionOperationSQL('selectRelationshipsSQL', op, sql);

      var ret = doSelectSQL(
          entityName, sql.mainTable ?? table, sql, op.transaction, connection);
      return ret;
    });
  }

  Object resolveError(Object error, StackTrace stackTrace, Object? operation,
          Object? previousError) =>
      DBSQLAdapterException('error', '$error',
          parentError: error,
          parentStackTrace: stackTrace,
          previousError: previousError,
          operation: operation);

  @override
  bool isTransactionWithSingleOperation(TransactionOperation op,
      [SQLWrapper? sql]) {
    return super.isTransactionWithSingleOperation(op) &&
        (sql == null || (sql.sqlsLength == 1 && !sql.mainSQL.hasPreOrPosSQL));
  }

  FutureOr<R> executeTransactionOperation<R>(TransactionOperation op,
      SQLWrapper sql, FutureOr<R> Function(C connection) f) {
    var transaction = op.transaction;

    if (isTransactionWithSingleOperation(op, sql)) {
      return executeWithPool(f,
          onError: (e, s) => transaction.notifyExecutionError(
                e,
                s,
                errorResolver: resolveError,
                operation: op,
                debugInfo: () => sql.mainSQL.toString(),
              ));
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
      var q = dialect.elementQuote;
      var limitStr = limit != null && limit > 0 ? ' LIMIT $limit' : '';
      var sql = 'SELECT $q$tableAlias$q.* $from$limitStr';
      return sql;
    });
  }

  FutureOr<SQL> generateSelectIDsSQL(Transaction transaction, String entityName,
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
      var tableFieldID = context.tableFieldID ?? 'id';
      var q = dialect.elementQuote;
      var limitStr = limit != null && limit > 0 ? ' LIMIT $limit' : '';
      var sql =
          'SELECT $q$tableAlias$q.$q$tableFieldID$q as ${q}id$q $from$limitStr';
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

    var retEncodedSQL = getTableScheme(table).resolveMapped((tableScheme) {
      var idFieldName = tableScheme?.idFieldName;

      return _conditionSQLGenerator.encode(matcher, entityName,
          parameters: parameters,
          positionalParameters: positionalParameters,
          namedParameters: namedParameters,
          tableName: table,
          tableFieldID: idFieldName);
    });

    return retEncodedSQL.resolveMapped((encodedSQL) {
      var conditionSQL = encodedSQL.outputString;

      var tableAlias =
          _conditionSQLGenerator.resolveEntityAlias(encodedSQL, table);

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
        );
      } else {
        var join = StringBuffer();

        for (var e in encodedSQL.referencedTablesFields.entries) {
          var refTable = e.key;
          var refTableAlias = encodedSQL.resolveEntityAlias(refTable);

          var innerRef =
              e.value.every((ref) => encodedSQL.isInnerFieldReference(ref));

          if (innerRef) {
            join.write('INNER JOIN ');
          } else {
            join.write('LEFT OUTER JOIN ');
          }

          join.write('$q$refTable$q as $q$refTableAlias$q ON ');

          for (var fieldRef in e.value) {
            var sourceTableAlias = _conditionSQLGenerator.resolveEntityAlias(
                encodedSQL, fieldRef.sourceTable);
            var targetTableAlias = _conditionSQLGenerator.resolveEntityAlias(
                encodedSQL, fieldRef.targetTable);

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

          var innerRel = encodedSQL.isInnerRelationshipTable(relationship);

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
        }

        var from =
            'FROM $q$table$q as $q$tableAlias$q $join WHERE $conditionSQL';
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
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _logTransactionOperationSQL('selectSQL', op, sql);
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

      if (dialect.acceptsOutputSyntax) {
        sql.write(' OUTPUT DELETED.* ');
      }

      sql.write(from);

      if (dialect.acceptsReturningSyntax) {
        sql.write(' RETURNING "$tableAlias".*');
      }

      return sql.toString();
    });

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
    TransactionOperation op,
    String entityName,
    String table,
    SQL sql,
  ) {
    if (sql.isDummy) return <Map<String, dynamic>>[];

    return executeTransactionOperation(op, sql, (connection) {
      _logTransactionOperationSQL('deleteSQL', op, sql);
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
  DBSQLRepositoryAdapter<O>? createRepositoryAdapter<O>(String name,
          {String? tableName, Type? type}) =>
      super.createRepositoryAdapter<O>(name, tableName: tableName, type: type)
          as DBSQLRepositoryAdapter<O>?;

  @override
  DBSQLRepositoryAdapter<O> instantiateRepositoryAdapter<O>(
          String name, String? tableName, Type? type) =>
      DBSQLRepositoryAdapter<O>(this, name, tableName: tableName, type: type);

  @override
  DBSQLRepositoryAdapter<O>? getRepositoryAdapterByName<O>(
    String name,
  ) =>
      super.getRepositoryAdapterByName<O>(name) as DBSQLRepositoryAdapter<O>?;

  @override
  DBSQLRepositoryAdapter<O>? getRepositoryAdapterByType<O>(Type type) =>
      super.getRepositoryAdapterByType<O>(type) as DBSQLRepositoryAdapter<O>?;

  @override
  DBSQLRepositoryAdapter<O>? getRepositoryAdapterByTableName<O>(
          String tableName) =>
      super.getRepositoryAdapterByTableName<O>(tableName)
          as DBSQLRepositoryAdapter<O>?;

  FutureOr<R> _finishOperation<T, R>(
      TransactionOperation op, T res, PreFinishDBOperation<T, R>? preFinish) {
    if (preFinish != null) {
      return preFinish(res).resolveMapped((res2) => op.finish(res2));
    } else {
      return op.finish<R>(res as R);
    }
  }

  FutureOr<R> _finishSQLOperation<T, R>(Object sql, TransactionOperation op,
      T r, PreFinishDBOperation<T, R>? preFinish) {
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
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr doInsert<O>(TransactionOperation op, String entityName, String table,
      O o, Map<String, dynamic> fields,
      {String? idFieldName,
      PreFinishDBOperation<dynamic, dynamic>? preFinish}) {
    return generateInsertSQL(op.transaction, entityName, table, fields)
        .resolveMapped((sql) {
      return insertSQL(op, entityName, table, sql, fields)
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
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
      List otherIds,
      [PreFinishDBOperation<bool, bool>? preFinish]) {
    return generateInsertRelationshipSQLs(op.transaction, entityName, table,
            field, id, otherTableName, otherIds)
        .resolveMapped((sqls) {
      return insertRelationshipSQLs(
              op, entityName, table, sqls, id, otherTableName, otherIds)
          .resolveMapped((r) => _finishSQLOperation(sqls, op, r, preFinish));
    });
  }

  @override
  FutureOr<R?> doSelectByID<R>(
      TransactionOperation op, String entityName, String table, Object id,
      {PreFinishDBOperation<Map<String, dynamic>?, R?>? preFinish}) {
    return generateSelectSQL(op.transaction, entityName, table, ConditionID(id))
        .resolveMapped((sql) {
      return selectSQL(op, entityName, table, sql).resolveMapped(
          (r) => _finishSQLOperation(sql, op, r.firstOrNull, preFinish));
    });
  }

  @override
  FutureOr<List<R>> doSelectByIDs<R>(TransactionOperation op, String entityName,
      String table, List<Object> ids,
      {PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>?
          preFinish}) {
    return generateSelectSQL(
            op.transaction, entityName, table, ConditionIdIN(ids))
        .resolveMapped((sql) {
      return selectSQL(op, entityName, table, sql)
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr<List<R>> doSelectAll<R>(
      TransactionOperation op, String entityName, String table,
      {PreFinishDBOperation<Iterable<Map<String, dynamic>>, List<R>>?
          preFinish}) {
    return generateSelectSQL(op.transaction, entityName, table, ConditionANY())
        .resolveMapped((sql) {
      return selectSQL(op, entityName, table, sql)
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
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
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr<List<I>> doSelectIDsBy<I extends Object>(TransactionOperation op,
      String entityName, String table, EntityMatcher matcher,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      int? limit}) {
    return generateSelectIDsSQL(op.transaction, entityName, table, matcher,
            parameters: parameters,
            positionalParameters: positionalParameters,
            namedParameters: namedParameters,
            limit: limit)
        .resolveMapped((sql) {
      return selectSQL(op, entityName, table, sql)
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, (results) {
                var ids = results.map((e) => e['id']);
                return parseIDs<I>(ids);
              }));
    });
  }

  @override
  FutureOr<R> doSelectRelationship<R>(
      TransactionOperation op,
      String entityName,
      String table,
      String field,
      dynamic id,
      String otherTableName,
      [PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish]) {
    return generateSelectRelationshipSQL(
            op.transaction, entityName, table, field, id, otherTableName)
        .resolveMapped((sql) {
      return selectRelationshipSQL(
              op, entityName, table, sql, id, otherTableName)
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }

  @override
  FutureOr<R> doSelectRelationships<R>(
      TransactionOperation op,
      String entityName,
      String table,
      String field,
      List ids,
      String otherTableName,
      [PreFinishDBOperation<Iterable<Map<String, dynamic>>, R>? preFinish]) {
    return generateSelectRelationshipsSQL(
            op.transaction, entityName, table, field, ids, otherTableName)
        .resolveMapped((sql) {
      return selectRelationshipsSQL(
              op, entityName, table, sql, ids, otherTableName)
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
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
          .resolveMapped((r) => _finishSQLOperation(sql, op, r, preFinish));
    });
  }
}

class _DBTableCheck {
  EntityRepository<Object>? repository;
  TableScheme? scheme;
  List<_DBTableColumn>? missingColumns;

  List<_DBTableColumn>? missingReferenceColumns;

  List<_DBTableColumn>? missingReferenceConstraints;

  List<_DBTableColumn>? missingUniqueConstraints;

  List<_DBTableColumn>? missingEnumConstraints;
  Map<_DBTableColumn, List<String>>? missingEnumValues;

  _DBTableCheck.missing(
      this.repository,
      this.scheme,
      this.missingColumns,
      this.missingReferenceColumns,
      this.missingReferenceConstraints,
      this.missingUniqueConstraints,
      this.missingEnumConstraints,
      this.missingEnumValues);

  String? error;

  _DBTableCheck.error(this.error);

  _DBTableCheck.ok();

  bool get isOK =>
      error == null &&
      (missingColumns?.isEmpty ?? true) &&
      (missingReferenceColumns?.isEmpty ?? true) &&
      (missingReferenceConstraints?.isEmpty ?? true) &&
      (missingUniqueConstraints?.isEmpty ?? true) &&
      (missingEnumConstraints?.isEmpty ?? true) &&
      (missingEnumValues?.isEmpty ?? true);

  bool get isError => !isOK;

  List<AlterTableSQL> generateMissingColumnsSQLs(SQLGenerator sqlGenerator) =>
      _generateMissingSQLs(missingColumns, sqlGenerator);

  List<AlterTableSQL> generateMissingReferenceColumnsSQLs(
          SQLGenerator sqlGenerator) =>
      _generateMissingSQLs(missingReferenceColumns, sqlGenerator);

  List<AlterTableSQL> generateMissingReferenceConstraintsSQLs(
      SQLGenerator sqlGenerator) {
    var columnsSQLs =
        _generateMissingSQLs(missingReferenceConstraints, sqlGenerator);

    var constraints =
        columnsSQLs.expand((e) => e.constraints ?? <AlterTableSQL>[]).toList();

    return constraints;
  }

  List<AlterTableSQL> generateMissingUniqueConstraintsSQLs(
          SQLGenerator sqlGenerator) =>
      _generateMissingUniqueConstraintsSQLs(
          missingUniqueConstraints, sqlGenerator);

  List<AlterTableSQL> generateMissingEnumConstraintsSQLs(
          SQLGenerator sqlGenerator) =>
      _generateMissingEnumConstraintsSQLs(missingEnumConstraints, sqlGenerator);

  List<AlterTableSQL> generateMissingEnumValuesSQLs(
          SQLGenerator sqlGenerator) =>
      _generateMissingEnumConstraintsSQLs(
          missingEnumValues?.keys, sqlGenerator);

  List<AlterTableSQL> _generateMissingSQLs(
      List<_DBTableColumn>? missing, SQLGenerator sqlGenerator) {
    var scheme = this.scheme;
    if (missing == null || missing.isEmpty || scheme == null) {
      return [];
    }

    var sqls = missing
        .map((f) => sqlGenerator.generateAddColumnAlterTableSQL(
            scheme.name, f.name, f.type,
            entityFieldAnnotations: f.annotations))
        .toList();

    return sqls;
  }

  List<AlterTableSQL> _generateMissingUniqueConstraintsSQLs(
      Iterable<_DBTableColumn>? missing, SQLGenerator sqlGenerator) {
    var scheme = this.scheme;
    if (missing == null || missing.isEmpty || scheme == null) {
      return [];
    }

    var sqls = missing.map((f) {
      return sqlGenerator.generateAddUniqueConstraintAlterTableSQL(
          scheme.name, f.name, f.type,
          entityFieldAnnotations: f.annotations);
    }).toList();

    return sqls;
  }

  List<AlterTableSQL> _generateMissingEnumConstraintsSQLs(
      Iterable<_DBTableColumn>? missing, SQLGenerator sqlGenerator) {
    var scheme = this.scheme;
    if (missing == null || missing.isEmpty || scheme == null) {
      return [];
    }

    var sqls = missing.map((f) {
      return sqlGenerator.generateAddEnumConstraintAlterTableSQL(
          scheme.name, f.name, f.type,
          entityFieldAnnotations: f.annotations);
    }).toList();

    return sqls;
  }

  @override
  String toString() {
    var missingColumns = this.missingColumns ?? [];
    var missingReferenceColumns = this.missingReferenceColumns ?? [];

    if (missingColumns.isNotEmpty || missingReferenceColumns.isNotEmpty) {
      var repoType = repository?.type;
      var schemeTableName = scheme?.name;

      var missingColumnsStr = missingColumns
          .map((e) => '${e.type.toString(withT: false)} ${e.name}')
          .join(' , ');

      var missingReferenceColumnsStr = missingReferenceColumns
          .map((e) => '${e.type.toString(withT: false)} ${e.name}')
          .join(' , ');

      var errorMsg = [
        "Can't find all `$repoType` fields in table `$schemeTableName` scheme:",
        "  -- repository: $repository\n  -- scheme: $scheme",
        if (missingColumns.isNotEmpty)
          "  -- missingColumns: [$missingColumnsStr]",
        if (missingReferenceColumns.isNotEmpty)
          "  -- missingReferenceColumns: [$missingReferenceColumnsStr]",
      ].join('\n');

      return '$errorMsg\n';
    }

    return error?.toString() ?? '';
  }
}

class _DBTableColumn {
  final String name;
  final TypeInfo type;
  final List<EntityField>? annotations;

  _DBTableColumn(this.name, this.type, this.annotations);

  factory _DBTableColumn.fromEntityHandler(
      EntityHandler<Object> entityHandler, String fieldName) {
    var type = entityHandler.getFieldType(null, fieldName) ?? TypeInfo.tString;
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

  DBSQLRepositoryAdapter(DBSQLAdapter super.databaseAdapter, super.name,
      {super.tableName, super.type});

  @override
  SQLDialect get dialect => super.dialect as SQLDialect;

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
      String field, dynamic id, String otherTableName, List otherIds) {
    return databaseAdapter.generateInsertRelationshipSQLs(
        transaction, name, tableName, field, id, otherTableName, otherIds);
  }

  FutureOr<bool> insertRelationshipSQLs(TransactionOperation op, List<SQL> sqls,
      dynamic id, String otherTableName, List otherIds) {
    return databaseAdapter.insertRelationshipSQLs(
        op, name, tableName, sqls, id, otherTableName, otherIds);
  }

  FutureOr<SQL> generateSelectRelationshipSQL(Transaction transaction,
      String field, dynamic id, String otherTableName) {
    return databaseAdapter.generateSelectRelationshipSQL(
        transaction, name, tableName, field, id, otherTableName);
  }

  FutureOr<Iterable<Map<String, dynamic>>> selectRelationshipSQL(
      TransactionOperation op, SQL sql, dynamic id, String otherTableName) {
    return databaseAdapter.selectRelationshipSQL(
        op, name, tableName, sql, id, otherTableName);
  }

  FutureOr<SQL> generateSelectRelationshipsSQL(Transaction transaction,
      String field, List<dynamic> ids, String otherTableName) {
    return databaseAdapter.generateSelectRelationshipsSQL(
        transaction, name, tableName, field, ids, otherTableName);
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

/// A [SQLAdapter] [Exception].
class DBSQLAdapterException extends DBAdapterException {
  @override
  String get runtimeTypeNameSafe => 'DBSQLAdapterException';

  DBSQLAdapterException(super.type, super.message,
      {super.parentError,
      super.parentStackTrace,
      super.operation,
      super.previousError});
}

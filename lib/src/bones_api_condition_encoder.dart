import 'dart:math' as math;

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:reflection_factory/reflection_factory.dart';
import 'package:statistics/statistics.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_sql.dart';
import 'bones_api_logging.dart';
import 'bones_api_mixin.dart';
import 'bones_api_utils.dart';

final _logSchemeProvider = logging.Logger('SchemeProvider')
  ..registerAsDbLogger();

/// A field that is a reference to another table field.
class TableFieldReference {
  static final TableFieldReference _dummy =
      TableFieldReference('dummy', 'dummy', int, 'dummy', 'dummy', int);

  /// The source table name.
  final String sourceTable;

  /// The source table field name.
  final String sourceField;

  /// The source table field type.
  final Type sourceFieldType;

  /// The target table name.
  final String targetTable;

  /// The target table field name.
  final String targetField;

  /// The target table field type.
  final Type targetFieldType;

  TableFieldReference(this.sourceTable, this.sourceField, this.sourceFieldType,
      this.targetTable, this.targetField, this.targetFieldType);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableFieldReference &&
          runtimeType == other.runtimeType &&
          sourceTable == other.sourceTable &&
          sourceField == other.sourceField &&
          targetTable == other.targetTable &&
          targetField == other.targetField;

  @override
  int get hashCode =>
      sourceTable.hashCode ^
      sourceField.hashCode ^
      targetTable.hashCode ^
      targetField.hashCode;

  @override
  String toString() {
    return 'TableFieldReference{"$sourceTable"."$sourceField"($sourceFieldType) -> "$targetTable"."$targetField"($targetFieldType)}';
  }
}

/// A relationship table between two tables.
class TableRelationshipReference {
  /// The source table name.
  final String relationshipTable;

  /// The source table field name.
  final String sourceTable;

  /// The source table field name.
  final String sourceField;

  /// The source table field type.
  final Type sourceFieldType;

  /// The source relationship field name, int the [relationshipTable].
  final String sourceRelationshipField;

  /// The target table name.
  final String targetTable;

  /// The target table field name.
  final String targetField;

  /// The target table field type.
  final Type targetFieldType;

  /// The target relationship field name, int the [relationshipTable].
  final String targetRelationshipField;

  /// The virtual/entity relationship field name.
  final String? relationshipField;

  TableRelationshipReference(
      this.relationshipTable,
      this.sourceTable,
      this.sourceField,
      this.sourceFieldType,
      this.sourceRelationshipField,
      this.targetTable,
      this.targetField,
      this.targetFieldType,
      this.targetRelationshipField,
      {this.relationshipField});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableRelationshipReference &&
          runtimeType == other.runtimeType &&
          relationshipTable == other.relationshipTable &&
          sourceTable == other.sourceTable &&
          sourceField == other.sourceField &&
          targetTable == other.targetTable &&
          targetField == other.targetField;

  @override
  int get hashCode =>
      relationshipTable.hashCode ^
      sourceTable.hashCode ^
      sourceField.hashCode ^
      targetTable.hashCode ^
      targetField.hashCode;

  @override
  String toString() {
    return 'TableRelationshipReference[$relationshipTable]{"$sourceTable"."$sourceField"($sourceFieldType) -> "$targetTable"."$targetField"($targetFieldType)}';
  }
}

class _TableRelationshipKey {
  final String? sourceTable;
  final String? sourceField;
  final String? targetTable;

  _TableRelationshipKey(this.sourceTable, this.sourceField, this.targetTable);

  bool get isValid => sourceTable != null || targetTable != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TableRelationshipKey &&
          sourceTable == other.sourceTable &&
          sourceField == other.sourceField &&
          targetTable == other.targetTable;

  @override
  int get hashCode =>
      sourceTable.hashCode ^ sourceField.hashCode ^ targetTable.hashCode;
}

/// A generic table scheme.
class TableScheme with FieldsFromMap {
  /// The table name
  final String name;

  /// If `true` is a relationship table.
  final bool relationship;

  /// The ID field name.
  final String? idFieldName;

  /// Table fields names.
  final List<String> fieldsNames;

  /// Fields types.
  final Map<String, Type> fieldsTypes;

  /// Table constraints.
  final Set<TableConstraint> constraints;

  /// Fields that are references to another table field.
  final Map<String, TableFieldReference> _fieldsReferencedTables;

  /// Reference tables (many-to-many).
  final Set<TableRelationshipReference> _relationshipTables;

  late final Map<String, int> _fieldsNamesIndexes;
  late final List<String> _fieldsNamesLC;
  late final List<String> _fieldsNamesSimple;

  final Map<String, List<TableRelationshipReference>>
      _tableRelationshipReference =
      <String, List<TableRelationshipReference>>{};

  TableScheme(
    this.name, {
    required this.idFieldName,
    required Map<String, Type> fieldsTypes,
    Map<String, TableFieldReference> fieldsReferencedTables =
        const <String, TableFieldReference>{},
    Iterable<TableRelationshipReference>? relationshipTables,
    Iterable<TableConstraint>? constraints,
    this.relationship = false,
  })  : fieldsNames = List<String>.unmodifiable(fieldsTypes.keys),
        fieldsTypes = Map.unmodifiable(fieldsTypes),
        constraints = ((constraints?.toList() ?? [])..sort()).toSet(),
        _fieldsReferencedTables = Map<String, TableFieldReference>.unmodifiable(
            fieldsReferencedTables),
        _relationshipTables = Set<TableRelationshipReference>.unmodifiable(
            relationshipTables ?? <TableRelationshipReference>[]) {
    _fieldsNamesIndexes = buildFieldsNamesIndexes(fieldsNames);
    _fieldsNamesLC = buildFieldsNamesLC(fieldsNames);
    _fieldsNamesSimple = buildFieldsNamesSimple(fieldsNames);

    for (var t in _relationshipTables) {
      if (t.sourceTable == name) {
        var l = _tableRelationshipReference.putIfAbsent(
            t.targetTable, () => <TableRelationshipReference>[]);
        l.add(t);
      }
    }

    _tableRelationshipReference.updateAll((key, value) =>
        UnmodifiableListView<TableRelationshipReference>(value));
  }

  /// Returns [_relationshipTables] length.
  int get relationshipTablesLength => _relationshipTables.length;

  Set<TableRelationshipReference> get relationshipTables =>
      UnmodifiableSetView(_relationshipTables);

  bool get hasTableReferences =>
      fieldsReferencedTablesLength > 0 || tableRelationshipReferenceLength > 0;

  /// Returns [_fieldsReferencedTables] length.
  int get fieldsReferencedTablesLength => _fieldsReferencedTables.length;

  Map<String, TableFieldReference> get fieldsReferencedTables =>
      UnmodifiableMapView<String, TableFieldReference>(_fieldsReferencedTables);

  /// Returns [_tableRelationshipReference] length.
  int get tableRelationshipReferenceLength =>
      _tableRelationshipReference.length;

  /// Returns [_tableRelationshipReference].
  Map<String, List<TableRelationshipReference>>
      get tableRelationshipReference =>
          UnmodifiableMapView<String, List<TableRelationshipReference>>(
              _tableRelationshipReference);

  /// Returns a [Map] with the table fields values populated from the provided [map].
  ///
  /// The field name resolution is case insensitive. See [getFieldValue].
  Map<String, Object?> getFieldsValues(Map<String, Object?> map,
      {Iterable<String>? fields}) {
    var fieldsNames = this.fieldsNames;

    if (fields != null) {
      var fieldsSimple = fields.map(fieldToSimpleKey).toList();

      fieldsNames = fieldsNames
          .mapIndexed((i, e) => MapEntry(e, _fieldsNamesSimple[i]))
          .where((e) => fieldsSimple.contains(e.value))
          .map((e) => e.key)
          .toList();
    }

    return getFieldsValuesFromMap(fieldsNames, map,
        fieldsNamesIndexes: _fieldsNamesIndexes,
        fieldsNamesLC: _fieldsNamesLC,
        fieldsNamesSimple: _fieldsNamesSimple,
        includeAbsentFields: true);
  }

  final Map<_TableRelationshipKey, TableRelationshipReference?>
      _tableRelationshipReferenceResolved =
      <_TableRelationshipKey, TableRelationshipReference?>{};

  /// Returns the [TableRelationshipReference] with the [targetTable].
  TableRelationshipReference? getTableRelationshipReference(
      {String? sourceTable, String? sourceField, String? targetTable}) {
    var key = _TableRelationshipKey(sourceTable, sourceField, targetTable);
    if (!key.isValid) {
      throw ArgumentError(
          "Parameter `sourceTable` or `targetTable` should be provided.");
    }

    return _tableRelationshipReferenceResolved.putIfAbsent(
        key,
        () => _getTableRelationshipReferenceImpl(
            sourceTable, sourceField, targetTable));
  }

  TableRelationshipReference? _getTableRelationshipReferenceImpl(
      String? sourceTable, String? sourceField, String? targetTable) {
    var byTarget = _tableRelationshipReference[targetTable];

    var rel = _resolveTableRelationshipReference(
        byTarget, sourceTable, sourceField, targetTable);
    if (rel != null) return rel;

    var bySource = _tableRelationshipReference[sourceTable];

    rel = _resolveTableRelationshipReference(
        bySource, sourceTable, sourceField, targetTable);
    if (rel != null) return rel;

    return null;
  }

  TableRelationshipReference? _resolveTableRelationshipReference(
      List<TableRelationshipReference>? l,
      String? sourceTable,
      String? sourceField,
      String? targetTable) {
    if (l == null || l.isEmpty) return null;
    if (l.isEmpty) return null;
    if (l.length == 1) return l.first;

    var rels = l;

    if (sourceTable != null) {
      rels = l.where((rel) => rel.sourceTable == sourceTable).toList();
      if (rels.length == 1) return rels.first;

      if (rels.isEmpty) {
        var sourceTableSimple =
            StringUtils.toLowerCaseSimpleCached(sourceTable);

        rels = l
            .where((rel) =>
                StringUtils.toLowerCaseSimpleCached(rel.sourceTable) ==
                sourceTableSimple)
            .toList();

        if (rels.length == 1) return rels.first;
      }
    }

    // Expects to have the field in the relationship table name:
    if (sourceField != null) {
      var sourceFieldSimpleUnderscored =
          StringUtils.toLowerCaseSimpleUnderscored(sourceField);

      var rels1 = rels
          .where((rel) =>
              StringUtils.toLowerCaseSimpleUnderscored(rel.relationshipTable)
                  .contains(sourceFieldSimpleUnderscored))
          .toList();

      if (rels1.length == 1) return rels1.first;

      var sourceFieldSimple =
          StringUtils.toLowerCaseSimpleUnderscored(sourceField);

      if (rels1.isEmpty) {
        rels1 = rels
            .where((rel) =>
                StringUtils.toLowerCaseSimpleCached(rel.relationshipTable)
                    .contains(sourceFieldSimple))
            .toList();
      }

      var relsNames = StringUtils.trimEqualitiesMap(
        rels1.map((e) => e.relationshipTable).toList(),
        delimiter: '_',
        normalizer: (s) => StringUtils.toLowerCaseSimpleUnderscored(s),
        validator: (s) =>
            !StringUtils.toLowerCaseSimpleCached(s).contains(sourceFieldSimple),
      );

      var relsNamesSimple = relsNames.map((key, value) =>
          MapEntry(key, StringUtils.toLowerCaseSimpleCached(value)));

      var rels2 = rels1.where((rel) {
        var f = relsNamesSimple[rel.relationshipTable]!;
        return f.contains(sourceFieldSimple);
      }).toList();

      if (rels2.length == 1) return rels2.first;

      var rels3 = rels1.where((rel) {
        var f = relsNamesSimple[rel.relationshipTable]!;
        return f == sourceFieldSimple;
      }).toList();

      if (rels3.length == 1) return rels3.first;

      if (rels1.length > 1) {
        rels1.sort((a, b) =>
            a.relationshipTable.length.compareTo(b.relationshipTable.length));
        var short = rels.first;
        return short;
      }
    }

    if (rels.isEmpty) {
      rels = l;
    }

    throw StateError(
        "Ambiguous relationship tables for ${sourceTable ?? '?'}.${sourceField ?? '?'} -> ${targetTable ?? '?'}:\n"
        "${rels.map((r) => ' -- $r\n').join('\n')}\n");
  }

  static final TableFieldReference _tableFieldReferenceDummy =
      TableFieldReference._dummy;

  final Map<String, TableFieldReference> _fieldsReferencedTablesResolved =
      <String, TableFieldReference>{};

  /// Returns a [TableFieldReference] from [_fieldsReferencedTables] with a resolved [fieldKey].
  /// See [resolveTableFieldName].
  TableFieldReference? getFieldReferencedTable(String fieldKey) {
    var resolvedRef = _fieldsReferencedTablesResolved[fieldKey];
    if (resolvedRef != null) {
      return identical(resolvedRef, _tableFieldReferenceDummy)
          ? null
          : resolvedRef;
    }

    var ref = _getFieldReferencedTableImpl(fieldKey);

    _fieldsReferencedTablesResolved[fieldKey] =
        ref ?? _tableFieldReferenceDummy;

    return ref;
  }

  TableFieldReference? _getFieldReferencedTableImpl(String fieldKey) {
    var ref = _fieldsReferencedTables[fieldKey];
    if (ref != null) return ref;

    var resolvedName = resolveTableFieldName(fieldKey);
    if (resolvedName == null || fieldKey == resolvedName) return null;

    ref = _fieldsReferencedTables[resolvedName];
    return ref;
  }

  /// Resolves [key] to a matching field in [fieldsNames].
  String? resolveTableFieldName(String key) {
    if (fieldsNames.contains(key)) {
      return key;
    }

    var keyLC = fieldToLCKey(key);
    var keySimple = fieldToSimpleKey(key);

    for (var name in fieldsNames) {
      var nameLC = fieldToLCKey(name);
      if (nameLC == keyLC) {
        return name;
      }

      var nameSimple = fieldToSimpleKey(name);
      if (nameSimple == keySimple) {
        return name;
      }
    }

    return null;
  }

  @override
  String toString() {
    var constraintNotPrimary =
        constraints.where((e) => e is! TablePrimaryKeyConstraint).toList();

    return 'TableScheme{name: $name, '
        'idFieldName: $idFieldName, '
        'fieldsTypes: $fieldsTypes, '
        'fieldsReferencedTables: $_fieldsReferencedTables, '
        'relationshipTables: $_relationshipTables}${constraintNotPrimary.isNotEmpty ? '\n-- ${constraintNotPrimary.join('\n-- ')}' : ''}';
  }
}

/// Base class for table constraints.
abstract class TableConstraint implements Comparable<TableConstraint> {
  /// The constraint filed/column name.
  final String field;

  TableConstraint(this.field);

  /// The constraint priority to use in sorting.
  int get priority;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TableConstraint &&
          runtimeType == other.runtimeType &&
          field == other.field;

  @override
  int get hashCode => field.hashCode;

  @override
  int compareTo(TableConstraint other) {
    var cmp = priority.compareTo(other.priority);
    if (cmp == 0) {
      cmp = field.compareTo(other.field);
    }
    return cmp;
  }
}

extension IterableTableConstraintExtension on Iterable<TableConstraint> {
  List<String> toFields({Map<String, String?>? fieldMap}) {
    var fields = map((e) => e.field);
    if (fieldMap != null) {
      fields = fields.map((f) => fieldMap[f] ?? f);
    }
    return fields.toList();
  }
}

/// Table primary key field constraint.
class TablePrimaryKeyConstraint extends TableConstraint {
  TablePrimaryKeyConstraint(super.field);

  @override
  int get priority => 0;

  @override
  String toString() => 'TablePrimaryKeyConstraint($field)';
}

/// Unique field constraint.
class TableUniqueConstraint extends TableConstraint {
  TableUniqueConstraint(super.field);

  @override
  int get priority => 1;

  @override
  String toString() => 'TableUniqueConstraint($field)';
}

/// Table enum field constraint.
class TableEnumConstraint extends TableConstraint {
  /// The possible values of the enum.
  final Set<String> values;

  TableEnumConstraint(super.field, Iterable<String> values)
      : values = values.toSet();

  @override
  int get priority => 2;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is TableEnumConstraint &&
          runtimeType == other.runtimeType &&
          SetEquality<String>().equals(values, other.values);

  @override
  int get hashCode => super.hashCode ^ SetEquality<String>().hash(values);

  @override
  String toString() => 'TableEnumConstraint($field)$values';
}

/// Base class for [TableScheme] providers.
abstract class SchemeProvider {
  final Map<String, TableScheme> _tablesSchemes = <String, TableScheme>{};

  final Map<String, Completer<TableScheme?>> _tablesSchemesResolving =
      <String, Completer<TableScheme?>>{};

  TableScheme? getTableSchemeIfLoaded(String table) {
    return _tablesSchemes[table];
  }

  /// Returns a [TableScheme] for [table].
  /// Calls [getTableSchemeImpl] handling asynchronous calls.
  /// - [contextID] should be [Expando] compatible. It informs that other
  ///   calls to [getTableScheme] are in the same context and could have
  ///   shared internal caches for the same [contextID] instance.
  FutureOr<TableScheme?> getTableScheme(String table,
      {TableRelationshipReference? relationship, Object? contextID}) {
    var tablesScheme = _tablesSchemes[table];
    if (tablesScheme != null) return tablesScheme;

    var resolving = _tablesSchemesResolving[table];
    if (resolving != null) {
      return resolving.future;
    }

    var completer = Completer<TableScheme?>();
    _tablesSchemesResolving[table] = completer;

    var ret = getTableSchemeImpl(table, relationship, contextID: contextID);

    return ret.resolveMapped((tablesScheme) {
      if (tablesScheme != null) {
        _tablesSchemes[table] = tablesScheme;
      }

      completer.complete(tablesScheme);
      _tablesSchemesResolving.remove(table);

      return tablesScheme;
    });
  }

  /// Implementation that returns a [TableScheme] for [table].
  /// - [contextID] should be [Expando] compatible. It informs that other
  ///   calls to [getTableSchemeImpl] are in the same context and could have
  ///   shared internal caches for the same [contextID] instance.
  FutureOr<TableScheme?> getTableSchemeImpl(
      String table, TableRelationshipReference? relationship,
      {Object? contextID});

  /// Selects the `ID` field name from [primaryKeyCandidates] candidates:
  String selectIDFieldName(String table, List<String> primaryKeyCandidates) {
    if (primaryKeyCandidates.isEmpty) {
      return 'id';
    }

    if (primaryKeyCandidates.length == 1) {
      return primaryKeyCandidates.first;
    }

    var idField = _selectIDFieldNameFromMultiple(table, primaryKeyCandidates);

    _logSchemeProvider.info(
        "Multiple PRIMARY KEY candidates for ID field at table `$table`> picked `$idField` from $primaryKeyCandidates");

    return idField;
  }

  String _selectIDFieldNameFromMultiple(
      String table, List<String> primaryFieldsCandidates) {
    for (var pk in primaryFieldsCandidates) {
      if (equalsIgnoreAsciiCase(pk, 'id')) {
        return pk;
      }
    }

    var pk = primaryFieldsCandidates
        .firstWhereOrNull((k) => k.toLowerCase().endsWith('_id'));
    if (pk != null) return pk;

    var possibleIDFields = ['code', 'serial'];

    for (var k in possibleIDFields) {
      for (var pk in primaryFieldsCandidates) {
        if (equalsIgnoreAsciiCase(pk, k)) {
          return pk;
        }
      }
    }

    return primaryFieldsCandidates.first;
  }

  final Map<String, Map<String, Type>> _tablesFieldsTypes =
      <String, Map<String, Type>>{};

  /// Returns a [TableScheme.fieldsTypes] for [table].
  FutureOr<Map<String, Type>?> getTableFieldsTypes(String table) {
    var prev = _tablesFieldsTypes[table];
    if (prev != null) return prev;

    var tableSchemeLoaded = getTableSchemeIfLoaded(table);
    if (tableSchemeLoaded != null) {
      var fieldsTypes = tableSchemeLoaded.fieldsTypes;
      return notifyTableFieldTypes(table, fieldsTypes);
    }

    return getTableFieldsTypesImpl(table).resolveMapped((fieldsTypes) {
      if (fieldsTypes != null) {
        return notifyTableFieldTypes(table, fieldsTypes);
      } else {
        return null;
      }
    });
  }

  FutureOr<Map<String, Type>?> getTableFieldsTypesImpl(String table);

  Map<String, Type> notifyTableFieldTypes(
      String table, Map<String, Type> fieldsTypes) {
    return _tablesFieldsTypes.putIfAbsent(
        table, () => Map<String, Type>.unmodifiable(fieldsTypes));
  }

  /// Disposes a [TableScheme] for [table]. Forces refresh of previous scheme.
  TableScheme? disposeTableSchemeCache(String table) =>
      _tablesSchemes.remove(table);

  /// Returns the table name for [entityRepository].
  String getTableForEntityRepository(EntityRepository entityRepository) {
    if (entityRepository is DBSQLEntityRepository) {
      return entityRepository.tableName;
    } else {
      return entityRepository.name;
    }
  }

  /// Returns a [TableScheme] for [entityRepository].
  FutureOr<TableScheme?> getTableSchemeForEntityRepository(
      EntityRepository entityRepository,
      {Object? contextID}) {
    var table = getTableForEntityRepository(entityRepository);
    return getTableScheme(table, contextID: contextID);
  }

  /// Returns the table name for [type].
  FutureOr<String?> getTableForType(TypeInfo type);

  /// Returns a [TableScheme] for [type].
  FutureOr<TableScheme?> getTableSchemeForType(TypeInfo type) {
    return getTableForType(type).resolveMapped((table) {
      if (table == null) return null;
      return getTableScheme(table);
    });
  }

  /// Returns the [type] for the [field] at [tableName] or by [entityName].
  FutureOr<TypeInfo?> getFieldType(String field,
      {String? entityName, String? tableName});

  /// Returns the [entity] ID for [entityName], [tableName] or [entityType].
  Object? getEntityID(Object entity,
      {String? entityName,
      String? tableName,
      Type? entityType,
      EntityHandler? entityHandler});
}

/// An encoding context for [ConditionEncoder].
class EncodingContext {
  /// The main entity for [ConditionEncoder].
  String entityName;

  Object? parameters;

  List? positionalParameters;

  Map<String, Object?>? namedParameters;

  Map<String, Object?>? encodingParameters;

  Transaction? transaction;

  String? tableName;

  String? tableFieldID;

  EncodingContext(this.entityName,
      {this.parameters,
      this.positionalParameters,
      this.namedParameters,
      this.transaction,
      this.tableName,
      this.tableFieldID});

  /// The encoded parameters placeholders and values.
  final Map<String, dynamic> parametersPlaceholders = <String, dynamic>{};

  /// The table aliases used in the encoded output.
  final Map<String, String> tableAliases = <String, String>{};

  final StringBuffer output = StringBuffer();

  /// The referenced tables fields in the encoded [Condition].
  final Set<TableFieldReference> _fieldsReferencedTables =
      <TableFieldReference>{};

  Set<TableFieldReference> get fieldsReferencedTables =>
      UnmodifiableSetView(_fieldsReferencedTables);

  /// The [Condition]s of each used [TableFieldReference].
  final Map<TableFieldReference, List<Condition>> _fieldReferencesConditions =
      {};

  void addFieldReference(TableFieldReference ref, Condition? c) {
    _fieldsReferencedTables.add(ref);

    if (c != null) {
      var l = _fieldReferencesConditions[ref] ??= [];
      l.add(c);
    }
  }

  bool isInnerFieldReference(TableFieldReference ref) {
    var l = _fieldReferencesConditions[ref];
    return l?.every((c) => c.isInner) ?? true;
  }

  /// The relationship tables fields in the encoded [Condition].
  final Map<String, TableRelationshipReference> _relationshipTables =
      <String, TableRelationshipReference>{};

  Map<String, TableRelationshipReference> get relationshipTables =>
      UnmodifiableMapView(_relationshipTables);

  /// The [Condition]s of each used [TableRelationshipReference].
  final Map<TableRelationshipReference, List<Condition>>
      _relationshipsConditions = {};

  void addRelationshipTable(
      String tableName, TableRelationshipReference relationship, Condition? c) {
    _relationshipTables[tableName] ??= relationship;

    if (c != null) {
      var l = _relationshipsConditions[relationship] ??= [];
      l.add(c);
    }
  }

  bool isInnerRelationshipTable(TableRelationshipReference relationship) {
    var l = _relationshipsConditions[relationship];
    return l?.every((c) => c.isInner) ?? true;
  }

  String get tableNameOrEntityName => tableName ?? entityName;

  String get outputString => output.toString();

  Map<String, List<TableFieldReference>> get referencedTablesFields =>
      _fieldsReferencedTables.groupListsBy((e) => e.targetTable);

  void write(Object o) => output.write(o);

  static final RegExp _regExpTableNameDelimiter = RegExp(r'_+');

  String resolveEntityAlias(String entityName) {
    var alias = tableAliases[entityName];
    if (alias != null) {
      return alias;
    }

    var allAliases = tableAliases.values.toSet();

    if (entityName.isEmpty) {
      return _resolveEntityAliasDefault(entityName, allAliases);
    }

    var entityNameLC = entityName.toLowerCase().trim();

    var length = entityNameLC.length;

    List<String>? entityNameParts;

    for (var sz = 2; sz <= length; ++sz) {
      alias = entityNameLC.substring(0, sz);
      if (!allAliases.contains(alias) && isValidAlias(alias)) {
        tableAliases[entityName] = alias;
        return alias;
      }

      if (sz == 2) {
        entityNameParts ??= entityNameLC.split(_regExpTableNameDelimiter);

        if (entityNameParts.length > 1) {
          for (var partSz = 1; partSz < 3; ++partSz) {
            var aliasFromParts = entityNameParts
                .map((w) => w.substring(0, math.min(partSz, w.length)))
                .join('_');

            if (!allAliases.contains(aliasFromParts) &&
                isValidAlias(aliasFromParts)) {
              alias = aliasFromParts;
              tableAliases[entityName] = alias;
              return alias;
            }
          }
        }
      }
    }

    var c0 = entityName.substring(0, 1);

    alias = _resolveEntityAliasByPrefix(entityName, allAliases, c0, 9);
    if (alias != null) return alias;

    alias = _resolveEntityAliasByPrefix(entityName, allAliases, 't', 9);
    if (alias != null) return alias;

    return _resolveEntityAliasDefault(entityName, allAliases);
  }

  String _resolveEntityAliasDefault(String entityName, Set<String> allAliases) {
    var alias =
        _resolveEntityAliasByPrefix(entityName, allAliases, 'alias', 1000);
    if (alias == null) {
      throw StateError("Can't resolve entity alias: $entityName");
    }
    return alias;
  }

  String? _resolveEntityAliasByPrefix(
      String entityName, Set<String> allAliases, String prefix, int limit) {
    if (prefix.isEmpty) return null;

    for (var i = 1; i <= limit; ++i) {
      var alias = '$prefix$i';
      if (!allAliases.contains(alias)) {
        tableAliases[entityName] = alias;
        return alias;
      }
    }

    return null;
  }

  bool isValidAlias(String alias) {
    if (isReservedWord(alias)) {
      return false;
    }

    return true;
  }

  bool isReservedWord(String alias) {
    return alias == 'as' ||
        alias == 'eq' ||
        alias == 'by' ||
        alias == 'null' ||
        alias == 'not' ||
        alias == 'def' ||
        alias == 'sum' ||
        alias == 'add' ||
        alias == 'from' ||
        alias == 'default' ||
        alias == 'alias' ||
        alias == 'equals' ||
        alias == 'count' ||
        alias == 'order' ||
        alias == 'table' ||
        alias == 'column' ||
        alias == 'select' ||
        alias == 'alter' ||
        alias == 'drop' ||
        alias == 'delete' ||
        alias == 'sql' ||
        alias == 'empty';
  }

  String addEncodingParameter(String suggestedKey, Object? value,
      {String parameterPrefix = 'param_'}) {
    var encodingParameters = (this.encodingParameters ??= <String, Object?>{});

    var namedParameters = this.namedParameters;
    if (namedParameters == null || !namedParameters.containsKey(suggestedKey)) {
      encodingParameters[suggestedKey] = value;
      return suggestedKey;
    }

    for (var i = 0; i < 1000; ++i) {
      var k = i == 0
          ? '$parameterPrefix$suggestedKey'
          : '$parameterPrefix$suggestedKey$i';

      if (!namedParameters.containsKey(k)) {
        encodingParameters[k] = value;
        return k;
      }
    }

    throw StateError("Can't create encoding parameter: $suggestedKey = $value");
  }
}

/// Base class to encode [Condition].
abstract class ConditionEncoder {
  final SchemeProvider? schemeProvider;

  ConditionEncoder([this.schemeProvider]);

  FutureOr<EncodingContext> encode(Condition condition, String entityName,
      {Object? parameters,
      List? positionalParameters,
      Map<String, Object?>? namedParameters,
      Transaction? transaction,
      String? tableName,
      String? tableFieldID}) {
    var context = EncodingContext(entityName,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction,
        tableName: tableName,
        tableFieldID: tableFieldID);

    if (condition is ConditionANY) {
      return context;
    }

    bool rootIsGroup;

    if (condition is GroupCondition) {
      rootIsGroup = true;

      if (condition.conditions.isEmpty) {
        return context;
      } else if (condition.conditions.length == 1 &&
          condition.conditions.first is ConditionANY) {
        return context;
      }
    } else {
      rootIsGroup = false;
      context.write(groupOpener);
    }

    var ret = encodeCondition(condition, context);

    return ret.resolveMapped((s) {
      if (!rootIsGroup) {
        s.write(groupCloser);
      }

      return context;
    });
  }

  FutureOr<EncodingContext> encodeCondition(
      Condition c, EncodingContext context) {
    if (c is KeyCondition) {
      return encodeKeyCondition(c, context);
    } else if (c is GroupCondition) {
      return encodeGroupCondition(c, context);
    } else if (c is ConditionID) {
      return encodeIDCondition(c, context);
    } else if (c is ConditionIdIN) {
      return encodeIDConditionIN(c, context);
    } else if (c is ConditionANY) {
      return context;
    } else {
      throw ConditionEncodingError("$c");
    }
  }

  FutureOr<EncodingContext> encodeIDCondition(
      ConditionID c, EncodingContext context);

  FutureOr<EncodingContext> encodeIDConditionIN(
      ConditionIdIN c, EncodingContext context);

  FutureOr<EncodingContext> encodeGroupCondition(
      GroupCondition c, EncodingContext context) {
    if (c is GroupConditionAND) {
      return encodeGroupConditionAND(c, context);
    } else if (c is GroupConditionOR) {
      return encodeGroupConditionOR(c, context);
    } else {
      throw ConditionEncodingError("$c");
    }
  }

  String get groupOpener;

  String get groupCloser;

  String get groupOperatorAND;

  String get groupOperatorOR;

  FutureOr<EncodingContext> encodeGroupConditionAND(
          GroupConditionAND c, EncodingContext context) =>
      encodeGroupConditionOperator(c, context, groupOperatorAND);

  FutureOr<EncodingContext> encodeGroupConditionOR(
          GroupConditionOR c, EncodingContext context) =>
      encodeGroupConditionOperator(c, context, groupOperatorOR);

  FutureOr<EncodingContext> encodeGroupConditionOperator(
      GroupCondition c, EncodingContext context, String operator) {
    var conditions = c.conditions;
    var length = conditions.length;

    if (length == 0) {
      return context;
    }

    if (length == 1) {
      var c1 = conditions.first;
      return encodeCondition(c1, context);
    }

    context.write(groupOpener);

    var c1 = conditions.first;
    var c1Ret = encodeCondition(c1, context);

    return c1Ret.resolveMapped((s) {
      var rets = conditions.skip(1).map((c2) {
        s.write(operator);
        return encodeCondition(c2, context);
      }).toList(growable: false);

      return rets
          .resolveAllReduced((value, element) => element)
          .resolveMapped((s) {
        s.write(groupCloser);
        return s;
      });
    });
  }

  FutureOr<EncodingContext> encodeKeyCondition(
      KeyCondition c, EncodingContext context) {
    if (c is KeyConditionEQ) {
      return encodeKeyConditionEQ(c, context);
    } else if (c is KeyConditionNotEQ) {
      return encodeKeyConditionNotEQ(c, context);
    } else if (c is KeyConditionIN) {
      return encodeKeyConditionIN(c, context);
    } else if (c is KeyConditionNotIN) {
      return encodeKeyConditionNotIN(c, context);
    } else if (c is KeyConditionGreaterThan) {
      return encodeKeyConditionGreaterThan(c, context);
    } else if (c is KeyConditionGreaterThanOrEqual) {
      return encodeKeyConditionGreaterThanOrEqual(c, context);
    } else if (c is KeyConditionLessThan) {
      return encodeKeyConditionLessThan(c, context);
    } else if (c is KeyConditionLessThanOrEqual) {
      return encodeKeyConditionLessThanOrEqual(c, context);
    } else {
      throw ConditionEncodingError("$c");
    }
  }

  FutureOr<EncodingContext> encodeKeyConditionEQ(
      KeyConditionEQ c, EncodingContext context);

  FutureOr<EncodingContext> encodeKeyConditionNotEQ(
      KeyConditionNotEQ c, EncodingContext context);

  FutureOr<EncodingContext> encodeKeyConditionIN(
      KeyConditionIN c, EncodingContext context);

  FutureOr<EncodingContext> encodeKeyConditionNotIN(
      KeyConditionNotIN c, EncodingContext context);

  FutureOr<EncodingContext> encodeKeyConditionGreaterThan(
      KeyConditionGreaterThan c, EncodingContext context);

  FutureOr<EncodingContext> encodeKeyConditionGreaterThanOrEqual(
      KeyConditionGreaterThanOrEqual c, EncodingContext context);

  FutureOr<EncodingContext> encodeKeyConditionLessThan(
      KeyConditionLessThan c, EncodingContext context);

  FutureOr<EncodingContext> encodeKeyConditionLessThanOrEqual(
      KeyConditionLessThanOrEqual c, EncodingContext context);

  FutureOr<EncodingValue<String, Object?>> resolveParameterValue(
      String valueKey,
      ConditionParameter value,
      EncodingContext context,
      Type? valueType,
      {bool valueAsList = false}) {
    if (valueAsList) {
      return _resolveParameterValueImpl(value, context, valueType, true)
          .resolveMapped((values) {
        if (values is EncodingValue<String, Object?>) {
          return values.asEncodingValueList();
        }

        var list = values is List
            ? values
            : (values is Iterable ? values.toList(growable: false) : [values]);

        var placeHolders = list.mapIndexed((i, v) {
          var k = parameterPlaceholderIndexKey(valueKey, i);
          context.parametersPlaceholders[k] ??= v;
          var placeholder = parameterPlaceholder(k);
          return EncodingPlaceholderIndex(valueKey, valueType, placeholder, i,
              encodeEncodingPlaceholderIndex);
        }).toList();

        return EncodingValueList(
            valueKey, valueType, placeHolders, encodeEncodingValueList);
      });
    } else {
      var placeholder = parameterPlaceholder(valueKey);

      if (!context.parametersPlaceholders.containsKey(valueKey)) {
        return _resolveParameterValueImpl(value, context, valueType, false)
            .resolveMapped((val) {
          if (val is EncodingValue<String, Object?>) {
            return val;
          }

          context.parametersPlaceholders[valueKey] ??= val;
          return EncodingPlaceholder(
              valueKey, valueType, placeholder, encodeEncodingPlaceholder);
        });
      } else {
        return EncodingPlaceholder(
            valueKey, valueType, placeholder, encodeEncodingPlaceholder);
      }
    }
  }

  FutureOr<Object?> _resolveParameterValueImpl(ConditionParameter value,
      EncodingContext context, Type? valueType, bool valueAsList) {
    var paramValue = value.getValue(
        parameters: context.parameters,
        positionalParameters: context.positionalParameters,
        namedParameters: context.namedParameters,
        encodingParameters: context.encodingParameters);

    if (paramValue is EncodingValue) {
      return paramValue;
    }

    if (valueType != null) {
      return resolveValueToType(paramValue, valueType,
          valueAsList: valueAsList);
    } else {
      return paramValue;
    }
  }

  FutureOr<Object?> resolveValueToType(Object? value, Type valueType,
      {bool valueAsList = false}) {
    if (valueAsList) {
      if (value == null) {
        return [];
      } else if (value is Iterable) {
        var list = value
            .map((v) => _resolveValueToTypeCompatibleImpl(v, valueType))
            .toList(growable: false)
            .resolveAll();
        return list;
      } else {
        var list = _resolveValueToTypeCompatibleImpl(value, valueType)
            .resolveMapped((val) => [val]);
        return list;
      }
    } else {
      return _resolveValueToTypeCompatibleImpl(value, valueType);
    }
  }

  FutureOr<Object?> _resolveValueToTypeCompatibleImpl(
      Object? value, Type valueType) {
    value = _resolveValueToTypeImpl(value, valueType);
    value = resolveValueToCompatibleType(value);
    return value;
  }

  FutureOr<Object?> resolveValueToCompatibleType(Object? value) {
    return value;
  }

  FutureOr<Object?> _resolveValueToTypeImpl(Object? value, Type valueType) {
    if (value == null) {
      return null;
    }

    if (value.runtimeType == valueType) {
      return value;
    }

    if (value is Enum) {
      if (valueType == String) {
        return value.name;
      } else if (valueType == int || valueType == num) {
        return value.index;
      } else if (valueType == double) {
        return value.index.toDouble();
      } else if (valueType == BigInt) {
        return value.index.toBigInt();
      }
    }

    var valueTypeInfo = TypeInfo.from(valueType);

    var valueParser = TypeParser.parserForTypeInfo(valueTypeInfo);
    if (valueParser != null) {
      if (value is Iterable && valueTypeInfo.isPrimitiveType) {
        var list = value.asList;
        var listLength = list.length;

        if (listLength == 0) {
          return null;
        } else if (listLength == 1) {
          value == list.first;
        } else {
          throw ArgumentError(
              "Can't resolve a `List` with multiple values to a primitive type: $valueTypeInfo >> $value");
        }
      }

      var parsedValue = valueParser(value);
      if (parsedValue != null) {
        return parsedValue;
      }
    }

    var schemeProvider = this.schemeProvider;

    if (schemeProvider != null) {
      if (!TypeParser.isPrimitiveType(valueType)) {
        var entityID = schemeProvider.getEntityID(value, entityType: valueType);
        return entityID;
      } else {
        var entityID =
            schemeProvider.getEntityID(value, entityType: value.runtimeType);
        return entityID;
      }
    } else {
      return value;
    }
  }

  String encodeEncodingValueNull(EncodingValueNull<String> p) => 'null';

  String encodeEncodingValuePrimitive(
          EncodingValuePrimitive<String, Object?> p) =>
      p.resolvedValue.toString();

  String encodeEncodingValueText(EncodingValueText<String> p) {
    var valueStr = p.resolvedValue.toString();
    valueStr = escapeStringQuotes(valueStr, "'");
    return "'$valueStr'";
  }

  String encodeEncodingValueList(EncodingValueList p) {
    if (p.list.isEmpty) {
      return '( null )';
    }
    return '( ${p.list.map((e) => e.encode).join(' , ')} )';
  }

  String encodeEncodingPlaceholder(EncodingPlaceholder p) => p.placeholder;

  String encodeEncodingPlaceholderIndex(EncodingPlaceholderIndex p) =>
      p.placeholder;

  String escapeStringQuotes(String valueStr, String quote) =>
      valueStr.replaceAll(quote, "\\$quote");

  FutureOr<String> resolveFieldName(String tableName, String fieldName) =>
      fieldName;

  String resolveEntityAlias(EncodingContext context, String entityName) =>
      context.resolveEntityAlias(entityName);

  String parameterPlaceholder(String parameterKey);

  String parameterPlaceholderIndexKey(String parameterKey, int index) =>
      '${parameterKey}__$index';
}

typedef ValueEncoder<E, P extends EncodingValue<E, P>> = E Function(
    P parameterValue);

abstract class EncodingValue<E, T extends EncodingValue<E, T>> {
  final String key;
  final Type? type;

  EncodingValue(this.key, this.type);

  E get encode;

  List<EncodingValue<E, Object?>> get asList =>
      <EncodingValue<E, Object?>>[this];

  @override
  String toString() => encode.toString();

  EncodingValueList<E> asEncodingValueList() {
    var values = this;
    if (values is EncodingValueList<E>) {
      return values as EncodingValueList<E>;
    } else {
      return EncodingValueList(values.key, values.type, [values], (p) {
        var v = values.encode;
        return '( $v )' as E;
      });
    }
  }
}

abstract class EncodingValueResolved<E, T extends EncodingValueResolved<E, T>>
    extends EncodingValue<E, T> {
  EncodingValueResolved(super.key, super.type);

  Object? get resolvedValue;
}

class EncodingValueNull<E>
    extends EncodingValueResolved<E, EncodingValueNull<E>> {
  final ValueEncoder<E, EncodingValueNull<E>> valueEncoder;

  EncodingValueNull(super.key, super.type, this.valueEncoder);

  @override
  Object? get resolvedValue => null;

  @override
  E get encode => valueEncoder(this);
}

class EncodingValuePrimitive<E, T>
    extends EncodingValueResolved<E, EncodingValuePrimitive<E, T>> {
  final ValueEncoder<E, EncodingValuePrimitive<E, T>> valueEncoder;

  @override
  final T resolvedValue;

  EncodingValuePrimitive(
      super.key, super.type, this.resolvedValue, this.valueEncoder);

  @override
  E get encode => valueEncoder(this);
}

class EncodingValueText<E>
    extends EncodingValueResolved<E, EncodingValueText<E>> {
  final ValueEncoder<E, EncodingValueText<E>> valueEncoder;

  @override
  final String resolvedValue;

  EncodingValueText(
      super.key, super.type, this.resolvedValue, this.valueEncoder);

  @override
  E get encode => valueEncoder(this);
}

class EncodingPlaceholder<E> extends EncodingValue<E, EncodingPlaceholder<E>> {
  final ValueEncoder<E, EncodingPlaceholder<E>> valueEncoder;

  final String placeholder;

  EncodingPlaceholder(
      super.key, super.type, this.placeholder, this.valueEncoder);

  @override
  E get encode => valueEncoder(this);
}

class EncodingPlaceholderIndex<E>
    extends EncodingValue<E, EncodingPlaceholderIndex<E>> {
  final ValueEncoder<E, EncodingPlaceholderIndex<E>> valueEncoder;

  final String placeholder;
  final int index;

  EncodingPlaceholderIndex(
      super.key, super.type, this.placeholder, this.index, this.valueEncoder);

  @override
  E get encode => valueEncoder(this);
}

class EncodingValueList<E> extends EncodingValue<E, EncodingValueList<E>> {
  final ValueEncoder<E, EncodingValueList<E>> valueEncoder;

  final List<EncodingValue<E, Object?>> list;

  EncodingValueList(super.key, super.type, this.list, this.valueEncoder);

  @override
  List<EncodingValue<E, Object?>> get asList =>
      list.expand((v) => v.asList).toList();

  @override
  E get encode => valueEncoder(this);
}

class ConditionEncodingError extends Error {
  final String message;

  ConditionEncodingError(this.message);

  @override
  String toString() => "Encoding error: $message";
}

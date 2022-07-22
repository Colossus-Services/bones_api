import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:reflection_factory/reflection_factory.dart';

import 'bones_api_condition.dart';
import 'bones_api_entity.dart';
import 'bones_api_entity_sql.dart';
import 'bones_api_mixin.dart';
import 'bones_api_utils.dart';

/// A field that is a reference to another table field.
class TableFieldReference {
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

  TableRelationshipReference(
      this.relationshipTable,
      this.sourceTable,
      this.sourceField,
      this.sourceFieldType,
      this.sourceRelationshipField,
      this.targetTable,
      this.targetField,
      this.targetFieldType,
      this.targetRelationshipField);

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
    this.relationship = false,
  })  : fieldsNames = List<String>.unmodifiable(fieldsTypes.keys),
        fieldsTypes = Map.unmodifiable(fieldsTypes),
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

  bool get hasTableReferences =>
      fieldsReferencedTablesLength > 0 || tableRelationshipReferenceLength > 0;

  /// Returns [_fieldsReferencedTables] length.
  int get fieldsReferencedTablesLength => _fieldsReferencedTables.length;

  Map<String, TableFieldReference> get fieldsReferencedTables =>
      UnmodifiableMapView<String, TableFieldReference>(_fieldsReferencedTables);

  /// Returns [_tableRelationshipReference] length.
  int get tableRelationshipReferenceLength =>
      _tableRelationshipReference.length;

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
      var fieldsSimple = fields.map((e) => fieldToSimpleKey(e)).toList();

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
        var sourceTableSimple = StringUtils.toLowerCaseSimple(sourceTable);

        rels = l
            .where((rel) =>
                StringUtils.toLowerCaseSimple(rel.sourceTable) ==
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
            .where((rel) => StringUtils.toLowerCaseSimple(rel.relationshipTable)
                .contains(sourceFieldSimple))
            .toList();
      }

      var relsNames = StringUtils.trimEqualitiesMap(
        rels1.map((e) => e.relationshipTable).toList(),
        delimiter: '_',
        normalizer: (s) => StringUtils.toLowerCaseSimpleUnderscored(s),
        validator: (s) =>
            !StringUtils.toLowerCaseSimple(s).contains(sourceFieldSimple),
      );

      var relsNamesSimple = relsNames.map(
          (key, value) => MapEntry(key, StringUtils.toLowerCaseSimple(value)));

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

  /// Returns a [TableFieldReference] from [_fieldsReferencedTables] with a resolved [fieldKey].
  /// See [resolveTableFiledName].
  TableFieldReference? getFieldsReferencedTables(String fieldKey) {
    var ref = _fieldsReferencedTables[fieldKey];
    if (ref != null) return ref;

    var resolvedName = resolveTableFiledName(fieldKey);
    if (resolvedName == null) return null;

    ref = _fieldsReferencedTables[resolvedName];
    return ref;
  }

  /// Resolves [key] to a matching field in [fieldsNames].
  String? resolveTableFiledName(String key) {
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
    return 'TableScheme{name: $name, '
        'idFieldName: $idFieldName, '
        'fieldsTypes: $fieldsTypes, '
        'fieldsReferencedTables: $_fieldsReferencedTables, '
        'relationshipTables: $_relationshipTables}';
  }
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
  FutureOr<TableScheme?> getTableScheme(String table,
      {TableRelationshipReference? relationship}) {
    var tablesScheme = _tablesSchemes[table];
    if (tablesScheme != null) return tablesScheme;

    var resolving = _tablesSchemesResolving[table];
    if (resolving != null) {
      return resolving.future;
    }

    var completer = Completer<TableScheme?>();
    _tablesSchemesResolving[table] = completer;

    var ret = getTableSchemeImpl(table, relationship);

    return ret.resolveMapped((tablesScheme) {
      if (tablesScheme == null) {
        completer.complete(null);
        _tablesSchemesResolving.remove(table);
        return null;
      } else {
        _tablesSchemes[table] = tablesScheme;
        completer.complete(tablesScheme);
        _tablesSchemesResolving.remove(table);
        return tablesScheme;
      }
    });
  }

  /// Implementation that returns a [TableScheme] for [table].
  FutureOr<TableScheme?> getTableSchemeImpl(
      String table, TableRelationshipReference? relationship);

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
  FutureOr<String> getTableForEntityRepository(
      EntityRepository entityRepository) {
    if (entityRepository is SQLEntityRepository) {
      return entityRepository.tableName;
    } else {
      return entityRepository.name;
    }
  }

  /// Returns a [TableScheme] for [entityRepository].
  FutureOr<TableScheme?> getTableSchemeForEntityRepository(
          EntityRepository entityRepository) =>
      getTableForEntityRepository(entityRepository)
          .resolveMapped((table) => getTableScheme(table));

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
  FutureOr<Object?> getEntityID(Object entity,
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

  /// The encoded parameters placeholders and values.
  final Map<String, dynamic> parametersPlaceholders = <String, dynamic>{};

  /// The table aliases used in the encoded output.
  final Map<String, String> tableAliases = <String, String>{};

  final StringBuffer output = StringBuffer();

  /// The referenced tables fields in the encoded [Condition].
  final Set<TableFieldReference> fieldsReferencedTables =
      <TableFieldReference>{};

  /// The relationship tables fields in the encoded [Condition].
  final Map<String, TableRelationshipReference> relationshipTables =
      <String, TableRelationshipReference>{};

  EncodingContext(this.entityName,
      {this.parameters,
      this.positionalParameters,
      this.namedParameters,
      this.transaction,
      this.tableName});

  String get tableNameOrEntityName => tableName ?? entityName;

  String get outputString => output.toString();

  Map<String, List<TableFieldReference>> get referencedTablesFields =>
      fieldsReferencedTables.groupListsBy((e) => e.targetTable);

  void write(Object o) => output.write(o);

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

    for (var sz = 2; sz <= length; ++sz) {
      alias = entityNameLC.substring(0, sz);
      if (!allAliases.contains(alias) && isValidAlias(alias)) {
        tableAliases[entityName] = alias;
        return alias;
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
    return alias != 'as' &&
        alias != 'eq' &&
        alias != 'null' &&
        alias != 'not' &&
        alias != 'def' &&
        alias != 'default' &&
        alias != 'alias' &&
        alias != 'equals' &&
        alias != 'count' &&
        alias != 'sum' &&
        alias != 'empty';
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
      String? tableName}) {
    var context = EncodingContext(entityName,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters,
        transaction: transaction,
        tableName: tableName);

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

  FutureOr<EncodingValue<String, Object?>> resolveParameterValue(
      String valueKey,
      ConditionParameter value,
      EncodingContext context,
      Type? valueType,
      {bool valueAsList = false}) {
    if (valueAsList) {
      return _resolveParameterValueImpl(value, context, valueType, true)
          .resolveMapped((values) {
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
            .map((v) => _resolveValueToTypeImpl(v, valueType))
            .toList(growable: false)
            .resolveAll();
        return list;
      } else {
        var list = _resolveValueToTypeImpl(value, valueType)
            .resolveMapped((val) => [val]);
        return list;
      }
    } else {
      return _resolveValueToTypeImpl(value, valueType);
    }
  }

  FutureOr<Object?> _resolveValueToTypeImpl(Object? value, Type valueType) {
    if (value == null) {
      return null;
    }

    var parsedValue = TypeParser.parseValueForType(valueType, value);
    if (parsedValue != null) {
      return parsedValue;
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

  String encodeEncodingValueList(EncodingValueList p) =>
      '( ${p.list.map((e) => e.encode).join(' , ')} )';

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
}

abstract class EncodingValueResolved<E, T extends EncodingValueResolved<E, T>>
    extends EncodingValue<E, T> {
  EncodingValueResolved(String key, Type? type) : super(key, type);

  Object? get resolvedValue;
}

class EncodingValueNull<E>
    extends EncodingValueResolved<E, EncodingValueNull<E>> {
  final ValueEncoder<E, EncodingValueNull<E>> valueEncoder;

  EncodingValueNull(String key, Type? type, this.valueEncoder)
      : super(key, type);

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
      String key, Type? type, this.resolvedValue, this.valueEncoder)
      : super(key, type);

  @override
  E get encode => valueEncoder(this);
}

class EncodingValueText<E>
    extends EncodingValueResolved<E, EncodingValueText<E>> {
  final ValueEncoder<E, EncodingValueText<E>> valueEncoder;

  @override
  final String resolvedValue;

  EncodingValueText(
      String key, Type? type, this.resolvedValue, this.valueEncoder)
      : super(key, type);

  @override
  E get encode => valueEncoder(this);
}

class EncodingPlaceholder<E> extends EncodingValue<E, EncodingPlaceholder<E>> {
  final ValueEncoder<E, EncodingPlaceholder<E>> valueEncoder;

  final String placeholder;

  EncodingPlaceholder(
      String key, Type? type, this.placeholder, this.valueEncoder)
      : super(key, type);

  @override
  E get encode => valueEncoder(this);
}

class EncodingPlaceholderIndex<E>
    extends EncodingValue<E, EncodingPlaceholderIndex<E>> {
  final ValueEncoder<E, EncodingPlaceholderIndex<E>> valueEncoder;

  final String placeholder;
  final int index;

  EncodingPlaceholderIndex(
      String key, Type? type, this.placeholder, this.index, this.valueEncoder)
      : super(key, type);

  @override
  E get encode => valueEncoder(this);
}

class EncodingValueList<E> extends EncodingValue<E, EncodingValueList<E>> {
  final ValueEncoder<E, EncodingValueList<E>> valueEncoder;

  final List<EncodingValue<E, Object?>> list;

  EncodingValueList(String key, Type? type, this.list, this.valueEncoder)
      : super(key, type);

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

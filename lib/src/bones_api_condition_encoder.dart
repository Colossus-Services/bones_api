import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';

import 'bones_api_condition.dart';
import 'bones_api_mixin.dart';

/// A field that is a reference to another table field.
class TableFieldReference {
  /// The source table name.
  final String sourceTable;

  /// The source table field name.
  final String sourceField;

  /// The target table name.
  final String targetTable;

  /// The target table field name.
  final String targetField;

  TableFieldReference(
      this.sourceTable, this.sourceField, this.targetTable, this.targetField);

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
    return 'TableFieldReference{"$sourceTable"."$sourceField" -> "$targetTable"."$targetField"}';
  }
}

/// A generic table scheme.
class TableScheme with FieldsFromMap {
  /// The table name
  final String name;

  /// The ID field name.
  final String? idFieldName;

  /// Table fields names.
  final List<String> fieldsNames;

  /// Fields types.
  final Map<String, Type> fieldsTypes;

  /// Fields that are references to another table field.
  final Map<String, TableFieldReference> fieldsReferencedTables;

  late final Map<String, int> _fieldsNamesIndexes;
  late final List<String> _fieldsNamesLC;
  late final List<String> _fieldsNamesSimple;

  TableScheme(this.name, this.idFieldName, Map<String, Type> fieldsTypes,
      [Map<String, TableFieldReference> fieldsReferencedTables =
          const <String, TableFieldReference>{}])
      : fieldsNames = List<String>.unmodifiable(fieldsTypes.keys),
        fieldsTypes = Map.unmodifiable(fieldsTypes),
        fieldsReferencedTables = Map<String, TableFieldReference>.unmodifiable(
            fieldsReferencedTables) {
    _fieldsNamesIndexes = buildFieldsNamesIndexes(fieldsNames);
    _fieldsNamesLC = buildFieldsNamesLC(fieldsNames);
    _fieldsNamesSimple = buildFieldsNamesSimple(fieldsNames);
  }

  /// Returns a [Map] with the table fields values populated from the provided [map].
  ///
  /// The field name resolution is case insensitive. See [getFieldValue].
  Map<String, Object?> getFieldsValues(Map<String, Object?> map) {
    return getFieldsValuesFromMap(fieldsNames, map,
        fieldsNamesIndexes: _fieldsNamesIndexes,
        fieldsNamesLC: _fieldsNamesLC,
        fieldsNamesSimple: _fieldsNamesSimple);
  }

  @override
  String toString() {
    return 'TableScheme{name: $name, idFieldName: $idFieldName, fieldsNames: $fieldsNames, fieldsTypes: $fieldsTypes, fieldsReferencedTables: $fieldsReferencedTables}';
  }
}

/// Base class for [TableScheme] providers.
abstract class SchemeProvider {
  final Map<String, TableScheme> _tablesSchemes = <String, TableScheme>{};

  final Map<String, Completer<TableScheme?>> _tablesSchemesResolving =
      <String, Completer<TableScheme?>>{};

  /// Returns a [TableScheme] for [table].
  FutureOr<TableScheme?> getTableScheme(String table) {
    var tablesScheme = _tablesSchemes[table];
    if (tablesScheme != null) return tablesScheme;

    var resolving = _tablesSchemesResolving[table];
    if (resolving != null) {
      return resolving.future;
    }

    var completer = Completer<TableScheme?>();
    _tablesSchemesResolving[table] = completer;

    var ret = getTableSchemeImpl(table);

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
  FutureOr<TableScheme?> getTableSchemeImpl(String table);

  /// Disposes a [TableScheme] for [table]. Forces refresh of previous scheme.
  TableScheme? disposeTableSchemeCache(String table) =>
      _tablesSchemes.remove(table);
}

/// An encoding context for [ConditionEncoder].
class EncodingContext {
  /// The main entity for [ConditionEncoder].
  String entityName;

  Object? parameters;

  List? positionalParameters;

  Map<String, Object?>? namedParameters;

  Map<String, Object?>? encodingParameters;

  /// The encoded parameters placeholders and values.
  final Map<String, dynamic> parametersPlaceholders = <String, dynamic>{};

  /// The table aliases used in the encoded output.
  final Map<String, String> tableAliases = <String, String>{};

  final StringBuffer output = StringBuffer();

  /// The referenced tables fields in the encoded [Condition].
  final Set<TableFieldReference> fieldsReferencedTables =
      <TableFieldReference>{};

  EncodingContext(this.entityName,
      {this.parameters, this.positionalParameters, this.namedParameters});

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
      Map<String, Object?>? namedParameters}) {
    var context = EncodingContext(entityName,
        parameters: parameters,
        positionalParameters: positionalParameters,
        namedParameters: namedParameters);

    var rootIsGroup = condition is GroupCondition;

    if (!rootIsGroup) {
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
    } else {
      throw ConditionEncodingError("$c");
    }
  }

  FutureOr<EncodingContext> encodeIDCondition(
      ConditionID c, EncodingContext context);

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
      }).toList();

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
    } else {
      throw ConditionEncodingError("$c");
    }
  }

  FutureOr<EncodingContext> encodeKeyConditionEQ(
      KeyConditionEQ c, EncodingContext context);

  FutureOr<EncodingContext> encodeKeyConditionNotEQ(
      KeyConditionNotEQ c, EncodingContext context);

  String resolveParameterValue(
      String valueKey, ConditionParameter value, EncodingContext context) {
    context.parametersPlaceholders.putIfAbsent(
        valueKey,
        () => value.getValue(
            parameters: context.parameters,
            positionalParameters: context.positionalParameters,
            namedParameters: context.namedParameters,
            encodingParameters: context.encodingParameters));

    var placeholder = parameterPlaceholder(valueKey);
    return placeholder;
  }

  String resolveEntityAlias(EncodingContext context, String entityName) =>
      context.resolveEntityAlias(entityName);

  String parameterPlaceholder(String parameterKey);
}

class ConditionEncodingError extends Error {
  final String message;

  ConditionEncodingError(this.message);

  @override
  String toString() => "Encoding error: $message";
}

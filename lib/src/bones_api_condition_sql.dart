import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:statistics/statistics.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';

final _log = logging.Logger('ConditionSQLEncoder');

/// A [Condition] encoder for SQL.
class ConditionSQLEncoder extends ConditionEncoder {
  final String sqlElementQuote;

  ConditionSQLEncoder(SchemeProvider schemeProvider,
      {required this.sqlElementQuote})
      : super(schemeProvider);

  @override
  String get groupOpener => '(';

  @override
  String get groupCloser => ')';

  @override
  String get groupOperatorAND => 'AND';

  @override
  String get groupOperatorOR => 'OR';

  @override
  String parameterPlaceholder(String parameterKey) => '@$parameterKey';

  @override
  FutureOr<EncodingContext> encodeIDCondition(
      ConditionID c, EncodingContext context) {
    var tableName = context.tableNameOrEntityName;
    var tableAlias = context.resolveEntityAlias(tableName);

    var schemeProvider = this.schemeProvider;
    if (schemeProvider == null) {
      var idKey = context.addEncodingParameter('id', c.idValue);
      var q = sqlElementQuote;
      var tableKey = '$q$tableAlias$q.$q$idKey$q';

      return encodeConditionValuesWithOperator(
          context, int, idKey, tableKey, '=', c.idValue, false);
    } else {
      var tableSchemeRet = schemeProvider.getTableScheme(tableName);

      return tableSchemeRet.resolveMapped((tableScheme) {
        if (tableScheme == null) {
          var errorMsg =
              "Can't find `TableScheme` for entity/table: $tableName";
          _log.severe(errorMsg);
          throw StateError(errorMsg);
        }

        var idFieldName = tableScheme.idFieldName ?? 'id';
        var idType = tableScheme.fieldsTypes[idFieldName] ?? int;

        var idKey = context.addEncodingParameter(idFieldName, c.idValue);
        var q = sqlElementQuote;
        var tableKey = '$q$tableAlias$q.$q$idKey$q';

        return encodeConditionValuesWithOperator(
            context, idType, idKey, tableKey, '=', c.idValue, false);
      });
    }
  }

  @override
  FutureOr<EncodingContext> encodeIDConditionIN(
      ConditionIdIN c, EncodingContext context) {
    var tableName = context.tableNameOrEntityName;
    var tableAlias = context.resolveEntityAlias(tableName);

    var schemeProvider = this.schemeProvider;
    if (schemeProvider == null) {
      var idKey = context.addEncodingParameter('id', c.idsValues);
      var q = sqlElementQuote;
      var tableKey = '$q$tableAlias$q.$q$idKey$q';

      return encodeConditionValuesWithOperator(
          context, int, idKey, tableKey, 'IN', c.idsValues, true);
    } else {
      var tableSchemeRet = schemeProvider.getTableScheme(tableName);

      return tableSchemeRet.resolveMapped((tableScheme) {
        if (tableScheme == null) {
          var errorMsg =
              "Can't find `TableScheme` for entity/table: $tableName";
          _log.severe(errorMsg);
          throw StateError(errorMsg);
        }

        var idFieldName = tableScheme.idFieldName ?? 'id';
        var idType = tableScheme.fieldsTypes[idFieldName] ?? int;

        var idKey = context.addEncodingParameter(idFieldName, c.idsValues);
        var q = sqlElementQuote;
        var tableKey = '$q$tableAlias$q.$q$idKey$q';

        return encodeConditionValuesWithOperator(
            context, idType, idFieldName, tableKey, 'IN', c.idsValues, true);
      });
    }
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionEQ(
      KeyConditionEQ c, EncodingContext context) {
    return encodeKeyConditionOperator(c, context, '=');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionNotEQ(
      KeyConditionNotEQ c, EncodingContext context) {
    return encodeKeyConditionOperator(c, context, '!=');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionIN(
      KeyConditionIN c, EncodingContext context) {
    return encodeKeyConditionOperator(c, context, 'IN', valueAsList: true);
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionGreaterThan(
      KeyConditionGreaterThan c, EncodingContext context) {
    return encodeKeyConditionOperator(c, context, '>');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionGreaterThanOrEqual(
      KeyConditionGreaterThanOrEqual c, EncodingContext context) {
    return encodeKeyConditionOperator(c, context, '>=');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionLessThan(
      KeyConditionLessThan c, EncodingContext context) {
    return encodeKeyConditionOperator(c, context, '<');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionLessThanOrEqual(
      KeyConditionLessThanOrEqual c, EncodingContext context) {
    return encodeKeyConditionOperator(c, context, '<=');
  }

  FutureOr<EncodingContext> encodeKeyConditionOperator(
      KeyCondition c, EncodingContext context, String operator,
      {bool valueAsList = false}) {
    var retKeySQL = keyToSQL(c, context);

    return retKeySQL.resolveMapped((keySQL) {
      var keyType = keySQL.key;
      var tableKey = keySQL.value;

      return encodeConditionValuesWithOperator(
          context, keyType, null, tableKey, operator, c.value, valueAsList);
    });
  }

  @override
  FutureOr<String> resolveFieldName(String tableName, String fieldName) {
    var schemeProvider = this.schemeProvider;
    if (schemeProvider == null) return fieldName;

    return schemeProvider
        .getTableScheme(tableName)
        .resolveMapped((tableScheme) {
      if (tableScheme == null) return fieldName;
      return tableScheme.resolveTableFieldName(fieldName) ?? fieldName;
    });
  }

  FutureOr<EncodingContext> encodeConditionValuesWithOperator(
      EncodingContext context,
      Type keyType,
      String? fieldKey,
      String tableKey,
      String operator,
      dynamic values,
      bool valueAsList) {
    context.write(' ');
    context.write(tableKey);
    context.write(' ');
    context.write(operator);
    context.write(' ');

    var valueSQLRet = valueToSQL(context, values,
        fieldKey: fieldKey, fieldType: keyType, valueAsList: valueAsList);

    return valueSQLRet.resolveMapped((valueSQL) {
      context.write(valueSQL);
      context.write(' ');
      return context;
    });
  }

  FutureOr<MapEntry<Type, String>> keyToSQL(
      KeyCondition<dynamic, dynamic> c, EncodingContext context) {
    var keys = c.keys;

    if (keys.first is! ConditionKeyField) {
      throw ConditionEncodingError('Root Key should be a field key: $c');
    }

    if (keys.length == 1) {
      return keyFieldToSQL(c, context);
    } else if (keys.length == 2) {
      return keyFieldReferenceToSQL(c, context);
    } else {
      throw ConditionEncodingError('keys > 2: $c');
    }
  }

  FutureOr<MapEntry<Type, String>> keyFieldToSQL(
    KeyCondition<dynamic, dynamic> c,
    EncodingContext context,
  ) {
    var schemeProvider = this.schemeProvider;

    var tableName = context.tableNameOrEntityName;
    var tableAlias = context.resolveEntityAlias(tableName);

    if (schemeProvider == null) {
      throw ConditionEncodingError(
          'No SchemeProvider> tableName: $tableName > $this');
    }

    var keys = c.keys;
    var key0 = keys.first as ConditionKeyField;

    var tableSchemeRet = schemeProvider.getTableScheme(tableName);

    return tableSchemeRet.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for entity/table: $tableName";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var q = sqlElementQuote;

      var fieldName = key0.name;
      var tableFieldName = tableScheme.resolveTableFieldName(fieldName);
      var tableFieldType = tableFieldName != null
          ? tableScheme.fieldsTypes[tableFieldName]
          : null;

      if (tableFieldType != null) {
        return MapEntry(tableFieldType, '$q$tableAlias$q.$q$tableFieldName$q');
      }

      var retFieldType = schemeProvider.getFieldType(fieldName,
          entityName: context.entityName, tableName: context.tableName);

      return retFieldType.resolveMapped((refFieldType) {
        if (refFieldType == null) {
          throw ConditionEncodingError(
              'No field type for key[0]> keys: $key0 $keys ; entityName: ${context.entityName} ; tableName: ${context.tableName} > $this ; tableScheme: $tableScheme');
        }

        var retTableNameRef = schemeProvider.getTableForType(refFieldType);

        return retTableNameRef.resolveMapped((tableNameRef) {
          if (tableNameRef == null) {
            throw ConditionEncodingError(
                'No referenced table or relationship table for key[0]> keys: $key0 $keys ; tableName: $tableName ; fieldType: $refFieldType> $this ; tableScheme: $tableScheme');
          }

          var relationship = tableScheme.getTableRelationshipReference(
              sourceTable: tableName,
              sourceField: fieldName,
              targetTable: tableNameRef);

          if (relationship == null) {
            throw ConditionEncodingError(
                'No relationship table with target table $tableNameRef> keys: $key0 $keys ; tableName: $tableName ; fieldType: $refFieldType> $this ; tableScheme: $tableScheme');
          }

          context.addRelationshipTable(tableNameRef, relationship, c);

          var relationshipAlias =
              context.resolveEntityAlias(relationship.relationshipTable);

          String relationshipTargetField;
          Type relationshipTargetFieldType;
          if (relationship.sourceTable == tableName) {
            relationshipTargetField = relationship.targetRelationshipField;
            relationshipTargetFieldType = relationship.targetFieldType;
          } else {
            relationshipTargetField = relationship.sourceRelationshipField;
            relationshipTargetFieldType = relationship.sourceFieldType;
          }

          return MapEntry(relationshipTargetFieldType,
              '$q$relationshipAlias$q.$q$relationshipTargetField$q');
        });
      });
    });
  }

  FutureOr<MapEntry<Type, String>> keyFieldReferenceToSQL(
    KeyCondition<dynamic, dynamic> c,
    EncodingContext context,
  ) {
    var schemeProvider = this.schemeProvider;
    var tableName = context.tableNameOrEntityName;

    if (schemeProvider == null) {
      throw ConditionEncodingError(
          'No SchemeProvider> tableName: $tableName > $this');
    }

    var keys = c.keys;
    var key0 = keys.first as ConditionKeyField;

    var tableSchemeRet = schemeProvider.getTableScheme(tableName);

    return tableSchemeRet.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for entity/table: $tableName";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var fieldName = key0.name;
      var fieldRef = tableScheme.getFieldReferencedTable(fieldName);

      if (fieldRef != null) {
        context.addFieldReference(fieldRef, c);

        var entityAlias = context.resolveEntityAlias(fieldRef.targetTable);

        var key1 = keys[1];

        if (key1 is ConditionKeyField) {
          var targetTableSchemeRet =
              schemeProvider.getTableScheme(fieldRef.targetTable);

          return targetTableSchemeRet.resolveMapped((targetTableScheme) {
            if (targetTableScheme == null) {
              var errorMsg =
                  "Can't find `TableScheme` for target table: $fieldRef";
              _log.severe(errorMsg);
              throw StateError(errorMsg);
            }

            var q = sqlElementQuote;
            var targetFieldName =
                targetTableScheme.resolveTableFieldName(key1.name);
            var targetFieldType =
                targetTableScheme.fieldsTypes[targetFieldName]!;
            return MapEntry(
                targetFieldType, '$q$entityAlias$q.$q$targetFieldName$q');
          });
        } else {
          throw ConditionEncodingError('Key: $c');
        }
      }

      var retFieldType = schemeProvider.getFieldType(fieldName,
          entityName: context.entityName, tableName: context.tableName);

      return retFieldType.resolveMapped((refFieldType) {
        if (refFieldType == null) {
          throw ConditionEncodingError(
              'No field type for key[0]> keys: $key0 $keys ; entityName: ${context.entityName} ; tableName: ${context.tableName} > $this ; tableScheme: $tableScheme');
        }

        var retTableNameRef = schemeProvider.getTableForType(refFieldType);

        return retTableNameRef.resolveMapped((tableNameRef) {
          if (tableNameRef == null) {
            throw ConditionEncodingError(
                'No referenced table or relationship table for key[0]> keys: $key0 $keys ; tableName: $tableName ; fieldType: $refFieldType> $this ; tableScheme: $tableScheme');
          }

          var relationship = tableScheme.getTableRelationshipReference(
              sourceTable: tableName,
              sourceField: fieldName,
              targetTable: tableNameRef);

          if (relationship == null) {
            throw ConditionEncodingError(
                'No relationship table with target table $tableNameRef> keys: $key0 $keys ; tableName: $tableName ; fieldType: $refFieldType> $this ; tableScheme: $tableScheme');
          }

          context.addRelationshipTable(tableNameRef, relationship, c);

          var targetAlias =
              context.resolveEntityAlias(relationship.targetTable);

          var key1 = keys[1];

          if (key1 is ConditionKeyField) {
            var targetTableSchemeRet =
                schemeProvider.getTableScheme(relationship.targetTable);

            return targetTableSchemeRet.resolveMapped((targetTableScheme) {
              if (targetTableScheme == null) {
                var errorMsg =
                    "Can't find `TableScheme` for target table: $fieldRef";
                _log.severe(errorMsg);
                throw StateError(errorMsg);
              }

              var q = sqlElementQuote;
              var targetFieldName =
                  targetTableScheme.resolveTableFieldName(key1.name);

              if (targetFieldName == null) {
                var errorMsg =
                    "Can't find field `${key1.name}` for target `${targetTableScheme.name}`. relationship: $relationship";
                _log.severe(errorMsg);
                throw StateError(errorMsg);
              }

              var targetFieldType =
                  targetTableScheme.fieldsTypes[targetFieldName]!;
              return MapEntry(
                  targetFieldType, '$q$targetAlias$q.$q$targetFieldName$q');
            });
          } else {
            throw ConditionEncodingError('Key: $c');
          }
        });
      });
    });
  }

  static List<T> _valueToList<T>(Object value) {
    if (value is List<T>) {
      return value;
    } else if (value is List) {
      return value.cast<T>();
    } else if (value is Iterable<T>) {
      return value.toList();
    } else if (value is Iterable) {
      return value.cast<T>().toList();
    } else {
      return <T>[value as T];
    }
  }

  @override
  FutureOr<Object?> resolveValueToCompatibleType(Object? value) {
    if (value is Decimal) {
      return value.toDouble();
    } else if (value is DynamicInt) {
      return value.toBigInt();
    } else {
      return value;
    }
  }

  FutureOr<String> valueToSQL(EncodingContext context, dynamic value,
          {String? fieldKey, Type? fieldType, bool valueAsList = false}) =>
      valueToParameterValue(context, value,
              fieldKey: fieldKey,
              fieldType: fieldType,
              valueAsList: valueAsList)
          .resolveMapped((val) => val.encode);

  FutureOr<EncodingValue<String, Object?>> valueToParameterValue(
      EncodingContext context, dynamic value,
      {String? fieldKey, Type? fieldType, bool valueAsList = false}) {
    if (value == null || value == Null) {
      return _valueToParameterValueImpl(value, fieldType,
          key: fieldKey, valueAsList: valueAsList);
    }

    if (value is Iterable) {
      var values = _valueToList(value);

      if (values.isEmpty) {
        return EncodingValueNull(
            fieldKey ?? '?', fieldType, encodeEncodingValueNull);
      } else if (values.length == 1) {
        var v = value.first;
        value = v;
      }
    }

    if (value is ConditionParameter) {
      return conditionParameterToParameterValue(
          value, context, fieldKey, fieldType,
          valueAsList: valueAsList);
    } else if (value is List &&
        value.whereType<ConditionParameter>().isNotEmpty) {
      var parametersValues = value.map((v) {
        if (v is ConditionParameter) {
          return conditionParameterToParameterValue(
              value, context, fieldKey, fieldType,
              valueAsList: valueAsList);
        } else {
          return _valueToParameterValueImpl(value, fieldType,
              key: fieldKey, valueAsList: valueAsList);
        }
      }).resolveAll();

      return parametersValues.resolveMapped((values) => EncodingValueList(
          fieldKey ?? '?', fieldType, values, encodeEncodingValueList));
    } else {
      return _valueToParameterValueImpl(value, fieldType,
          key: fieldKey, valueAsList: valueAsList);
    }
  }

  FutureOr<EncodingValue<String, Object?>> _valueToParameterValueImpl(
      Object? value, Type? type,
      {String? key, bool valueAsList = false}) {
    if (type != null) {
      return resolveValueToType(value, type, valueAsList: valueAsList)
          .resolveMapped((resolvedVal) {
        if (valueAsList) {
          return valueToParameterValueList(resolvedVal, type, key: key);
        } else {
          return valueToSQLPlain(resolvedVal, type, key: key);
        }
      });
    } else {
      if (valueAsList) {
        return valueToParameterValueList(value, null, key: key);
      } else {
        return valueToSQLPlain(value, null, key: key);
      }
    }
  }

  EncodingValue<String, Object?> valueToSQLPlain(Object? value, Type? type,
      {String? key}) {
    key ??= '?';

    if (value == null || value == Null) {
      return EncodingValueNull(key, type, encodeEncodingValueNull);
    } else if (value is num || value is bool) {
      return EncodingValuePrimitive(
          key, type, value, encodeEncodingValuePrimitive);
    } else if (value is Decimal) {
      return EncodingValuePrimitive(
          key, type, value.toDouble(), encodeEncodingValuePrimitive);
    } else if (value is DynamicInt) {
      return EncodingValuePrimitive(
          key, type, value.toBigInt(), encodeEncodingValuePrimitive);
    } else {
      return EncodingValueText(
          key, type, value.toString(), encodeEncodingValueText);
    }
  }

  EncodingValueList<String> valueToParameterValueList(Object? value, Type? type,
      {String? key}) {
    key ??= '?';

    var list = value is Iterable
        ? value.map((v) => valueToSQLPlain(v, type, key: key)).toList()
        : [valueToSQLPlain(value, type, key: key)];

    return EncodingValueList(key, type, list, encodeEncodingValueList);
  }

  FutureOr<EncodingValue<String, Object?>> conditionParameterToParameterValue(
      ConditionParameter parameter,
      EncodingContext context,
      String? fieldKey,
      Type? fieldType,
      {bool valueAsList = false}) {
    var parameterKey =
        (parameter.hasKey ? parameter.key : parameter.contextKey) ?? fieldKey;

    if (parameterKey == null) {
      throw ConditionEncodingError(
          'Field key not in context: $parameter > $this');
    }

    var parameterValue = resolveParameterValue(
        parameterKey, parameter, context, fieldType,
        valueAsList: valueAsList);

    return parameterValue;
  }
}

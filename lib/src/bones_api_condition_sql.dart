import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:statistics/statistics.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';

final _log = logging.Logger('ConditionSQLEncoder');

/// A [Condition] encoder for SQL.
class ConditionSQLEncoder extends ConditionEncoder {
  final String sqlElementQuote;

  ConditionSQLEncoder(
    SchemeProvider super.schemeProvider, {
    required this.sqlElementQuote,
  });

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
    ConditionID c,
    EncodingContext context,
  ) {
    var tableName = context.tableNameOrEntityName;
    var tableAlias = context.resolveEntityAlias(tableName);

    var schemeProvider = this.schemeProvider;
    if (schemeProvider == null) {
      var idKey = context.addEncodingParameter('id', c.idValue);
      var q = sqlElementQuote;
      var tableKey = '$q$tableAlias$q.$q$idKey$q';

      return encodeConditionValuesWithOperator(
        context,
        int,
        idKey,
        tableKey,
        '=',
        c.idValue,
        false,
      );
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
          context,
          idType,
          idKey,
          tableKey,
          '=',
          c.idValue,
          false,
        );
      });
    }
  }

  @override
  FutureOr<EncodingContext> encodeIDConditionIN(
    ConditionIdIN c,
    EncodingContext context,
  ) {
    var tableName = context.tableNameOrEntityName;
    var tableAlias = context.resolveEntityAlias(tableName);

    var schemeProvider = this.schemeProvider;
    if (schemeProvider == null) {
      var idKey = context.addEncodingParameter('id', c.idsValues);
      var q = sqlElementQuote;
      var tableKey = '$q$tableAlias$q.$q$idKey$q';

      return encodeConditionValuesWithOperator(
        context,
        int,
        idKey,
        tableKey,
        'IN',
        c.idsValues,
        true,
      );
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
          context,
          idType,
          idFieldName,
          tableKey,
          'IN',
          c.idsValues,
          true,
        );
      });
    }
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionEQ(
    KeyConditionEQ c,
    EncodingContext context,
  ) {
    return encodeKeyConditionOperator(c, context, '=');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionNotEQ(
    KeyConditionNotEQ c,
    EncodingContext context,
  ) {
    return encodeKeyConditionOperator(c, context, '!=');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionIN(
    KeyConditionIN c,
    EncodingContext context,
  ) {
    return encodeKeyConditionOperator(c, context, 'IN', valueAsList: true);
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionNotIN(
    KeyConditionNotIN c,
    EncodingContext context,
  ) {
    return encodeKeyConditionOperator(c, context, 'NOT IN', valueAsList: true);
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionGreaterThan(
    KeyConditionGreaterThan c,
    EncodingContext context,
  ) {
    return encodeKeyConditionOperator(c, context, '>');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionGreaterThanOrEqual(
    KeyConditionGreaterThanOrEqual c,
    EncodingContext context,
  ) {
    return encodeKeyConditionOperator(c, context, '>=');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionLessThan(
    KeyConditionLessThan c,
    EncodingContext context,
  ) {
    return encodeKeyConditionOperator(c, context, '<');
  }

  @override
  FutureOr<EncodingContext> encodeKeyConditionLessThanOrEqual(
    KeyConditionLessThanOrEqual c,
    EncodingContext context,
  ) {
    return encodeKeyConditionOperator(c, context, '<=');
  }

  FutureOr<EncodingContext> encodeKeyConditionOperator(
    KeyCondition c,
    EncodingContext context,
    String operator, {
    bool valueAsList = false,
  }) {
    var retKeySQL = keyToSQL(c, context);

    return retKeySQL.resolveMapped((keySQL) {
      var keyType = keySQL.key;
      var tableKey = keySQL.value;

      return encodeConditionValuesWithOperator(
        context,
        keyType,
        null,
        tableKey,
        operator,
        c.value,
        valueAsList,
      );
    });
  }

  @override
  FutureOr<String> resolveFieldName(String tableName, String fieldName) {
    var schemeProvider = this.schemeProvider;
    if (schemeProvider == null) return fieldName;

    return schemeProvider.getTableScheme(tableName).resolveMapped((
      tableScheme,
    ) {
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
    bool valueAsList,
  ) {
    context.write(' ');
    context.write(tableKey);
    context.write(' ');

    var valueSQLRet = valueToSQL(
      context,
      values,
      fieldKey: fieldKey,
      fieldType: keyType,
      valueAsList: valueAsList,
    );

    return valueSQLRet.resolveMapped((valueSQL) {
      if (valueSQL == 'null') {
        switch (operator) {
          case '=':
          case 'IN':
            {
              context.write('IS NULL ');
              return context;
            }
          case '!=':
          case 'NOT IN':
            {
              context.write('IS NOT NULL ');
              return context;
            }
        }
      }

      context.write(operator);
      context.write(' ');
      context.write(valueSQL);
      context.write(' ');
      return context;
    });
  }

  FutureOr<MapEntry<Type, String>> keyToSQL(
    KeyCondition<dynamic, dynamic> c,
    EncodingContext context,
  ) {
    var keys = c.keys;
    if (keys.isEmpty) {
      throw ConditionEncodingError('keys empty: $c');
    }

    if (keys.first is! ConditionKeyField) {
      throw ConditionEncodingError('Root Key should be a field key: $c');
    }

    if (keys.length == 1) {
      return keyFieldToSQL(c, context);
    }
    // keys.length >= 2
    else {
      return keyFieldReferenceToSQL(c, context);
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
        'No SchemeProvider> tableName: $tableName > $this',
      );
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
      var tableFieldType =
          tableFieldName != null
              ? tableScheme.fieldsTypes[tableFieldName]
              : null;

      if (tableFieldType != null) {
        return MapEntry(tableFieldType, '$q$tableAlias$q.$q$tableFieldName$q');
      }

      var retFieldType = schemeProvider.getFieldType(
        fieldName,
        entityName: context.entityName,
        tableName: context.tableName,
      );

      return retFieldType.resolveMapped((refFieldType) {
        if (refFieldType == null) {
          throw ConditionEncodingError(
            'No field type for key[0]> keys: $key0 $keys ; entityName: ${context.entityName} ; tableName: ${context.tableName} > $this ; tableScheme: $tableScheme',
          );
        }

        var retTableNameRef = schemeProvider.getTableForType(refFieldType);

        return retTableNameRef.resolveMapped((tableNameRef) {
          if (tableNameRef == null) {
            throw ConditionEncodingError(
              'No referenced table or relationship table for key[0]> keys: $key0 $keys ; tableName: $tableName ; fieldType: $refFieldType> $this ; tableScheme: $tableScheme',
            );
          }

          var relationship = tableScheme.getTableRelationshipReference(
            sourceTable: tableName,
            sourceField: fieldName,
            targetTable: tableNameRef,
          );

          if (relationship == null) {
            throw ConditionEncodingError(
              'No relationship table with target table $tableNameRef> keys: $key0 $keys ; tableName: $tableName ; fieldType: $refFieldType> $this ; tableScheme: $tableScheme',
            );
          }

          context.addRelationshipTable(tableNameRef, relationship, c);

          var relationshipAlias = context.resolveEntityAlias(
            relationship.relationshipTable,
          );

          String relationshipTargetField;
          Type relationshipTargetFieldType;
          if (relationship.sourceTable == tableName) {
            relationshipTargetField = relationship.targetRelationshipField;
            relationshipTargetFieldType = relationship.targetFieldType;
          } else {
            relationshipTargetField = relationship.sourceRelationshipField;
            relationshipTargetFieldType = relationship.sourceFieldType;
          }

          return MapEntry(
            relationshipTargetFieldType,
            '$q$relationshipAlias$q.$q$relationshipTargetField$q',
          );
        });
      });
    });
  }

  FutureOr<String> _resolveReferenceField({
    required SchemeProvider schemeProvider,
    required EncodingContext context,
    required KeyCondition c,
    required TableScheme sourceScheme,
    required String sourceTable,
    required ConditionKeyField key,
  }) {
    final fieldRef = sourceScheme.getFieldReferencedTable(key.name);

    // Normal reference field, pointing to another entity table:
    if (fieldRef != null) {
      context.addFieldReference(fieldRef, c);
      context.resolveEntityAlias(fieldRef.targetTable);
      return fieldRef.targetTable;
    }

    return schemeProvider
        .getFieldType(key.name, tableName: sourceTable)
        .resolveMapped((fieldType) {
          if (fieldType == null) {
            throw ConditionEncodingError('No field type for ${key.name}');
          }

          return schemeProvider.getTableForType(fieldType).resolveMapped((
            targetTable,
          ) {
            if (targetTable == null) {
              throw ConditionEncodingError('No table for type $fieldType');
            }

            final rel = sourceScheme.getTableRelationshipReference(
              sourceTable: sourceTable,
              sourceField: key.name,
              targetTable: targetTable,
            );

            if (rel == null) {
              throw ConditionEncodingError(
                'No relationship table for: `$sourceTable` -> `$targetTable`',
              );
            }

            context.addRelationshipTable(targetTable, rel, c);
            context.resolveEntityAlias(rel.targetTable);

            return rel.targetTable;
          });
        });
  }

  FutureOr<MapEntry<Type, String>> _resolveFinalField({
    required SchemeProvider schemeProvider,
    required EncodingContext context,
    required String targetTable,
    required ConditionKeyField key,
  }) {
    return schemeProvider.getTableScheme(targetTable).resolveMapped((scheme) {
      if (scheme == null) {
        throw StateError("Can't find TableScheme for $targetTable");
      }

      final fieldName = scheme.resolveTableFieldName(key.name);
      if (fieldName == null) {
        throw StateError(
          "Can't find field `${key.name}` on table `${scheme.name}`",
        );
      }

      final alias = context.resolveEntityAlias(targetTable);
      final type = scheme.fieldsTypes[fieldName]!;
      final q = sqlElementQuote;

      return MapEntry(type, '$q$alias$q.$q$fieldName$q');
    });
  }

  FutureOr<MapEntry<Type, String>> keyFieldReferenceToSQL(
    KeyCondition<dynamic, dynamic> c,
    EncodingContext context,
  ) {
    final rootTable = context.tableNameOrEntityName;

    final schemeProvider = this.schemeProvider;
    if (schemeProvider == null) {
      throw ConditionEncodingError(
        'No SchemeProvider> tableName: $rootTable > $this',
      );
    }

    final keys = c.keys.cast<ConditionKeyField>();
    if (keys.isEmpty) {
      throw ConditionEncodingError('Empty key path: $c');
    }

    FutureOr<MapEntry<Type, String>> walkKeys({
      required int index,
      required String sourceTable,
    }) {
      if (index == keys.length - 1) {
        return _resolveFinalField(
          schemeProvider: schemeProvider,
          context: context,
          targetTable: sourceTable,
          key: keys[index],
        );
      }

      return schemeProvider.getTableScheme(sourceTable).resolveMapped((scheme) {
        if (scheme == null) {
          throw StateError("Can't find `TableScheme` for table: $sourceTable");
        }

        return _resolveReferenceField(
          schemeProvider: schemeProvider,
          context: context,
          c: c,
          sourceScheme: scheme,
          sourceTable: sourceTable,
          key: keys[index],
        ).resolveMapped(
          (nextTable) => walkKeys(index: index + 1, sourceTable: nextTable),
        );
      });
    }

    return walkKeys(index: 0, sourceTable: rootTable);
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
    if (value is DateTime) {
      return value.toUtc();
    } else if (value is Decimal) {
      return value.toDouble();
    } else if (value is DynamicInt) {
      return value.toBigInt();
    } else {
      return value;
    }
  }

  FutureOr<String> valueToSQL(
    EncodingContext context,
    dynamic value, {
    String? fieldKey,
    Type? fieldType,
    bool valueAsList = false,
  }) => valueToParameterValue(
    context,
    value,
    fieldKey: fieldKey,
    fieldType: fieldType,
    valueAsList: valueAsList,
  ).resolveMapped((val) => val.encode);

  FutureOr<EncodingValue<String, Object?>> valueToParameterValue(
    EncodingContext context,
    dynamic value, {
    String? fieldKey,
    Type? fieldType,
    bool valueAsList = false,
  }) {
    if (value == null || value == Null) {
      return _valueToParameterValueImpl(
        value,
        fieldType,
        key: fieldKey,
        valueAsList: valueAsList,
      );
    }

    if (value is Iterable) {
      var values = _valueToList(value);

      if (values.isEmpty) {
        return EncodingValueNull(
          fieldKey ?? '?',
          fieldType,
          encodeEncodingValueNull,
        );
      } else if (values.length == 1) {
        var v = value.first;
        value = v;
      }
    }

    if (value is ConditionParameter) {
      return conditionParameterToParameterValue(
        value,
        context,
        fieldKey,
        fieldType,
        valueAsList: valueAsList,
      );
    } else if (value is List &&
        value.whereType<ConditionParameter>().isNotEmpty) {
      var parametersValues =
          value.map((v) {
            if (v is ConditionParameter) {
              return conditionParameterToParameterValue(
                value,
                context,
                fieldKey,
                fieldType,
                valueAsList: valueAsList,
              );
            } else {
              return _valueToParameterValueImpl(
                value,
                fieldType,
                key: fieldKey,
                valueAsList: valueAsList,
              );
            }
          }).resolveAll();

      return parametersValues.resolveMapped(
        (values) => EncodingValueList(
          fieldKey ?? '?',
          fieldType,
          values,
          encodeEncodingValueList,
        ),
      );
    } else {
      return _valueToParameterValueImpl(
        value,
        fieldType,
        key: fieldKey,
        valueAsList: valueAsList,
      );
    }
  }

  FutureOr<EncodingValue<String, Object?>> _valueToParameterValueImpl(
    Object? value,
    Type? type, {
    String? key,
    bool valueAsList = false,
  }) {
    if (type != null) {
      return resolveValueToType(
        value,
        type,
        valueAsList: valueAsList,
      ).resolveMapped((resolvedVal) {
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

  EncodingValue<String, Object?> valueToSQLPlain(
    Object? value,
    Type? type, {
    String? key,
  }) {
    key ??= '?';

    if (value == null || value == Null) {
      return EncodingValueNull(key, type, encodeEncodingValueNull);
    } else if (value is num || value is bool) {
      return EncodingValuePrimitive(
        key,
        type,
        value,
        encodeEncodingValuePrimitive,
      );
    } else if (value is Decimal) {
      return EncodingValuePrimitive(
        key,
        type,
        value.toDouble(),
        encodeEncodingValuePrimitive,
      );
    } else if (value is DynamicInt) {
      return EncodingValuePrimitive(
        key,
        type,
        value.toBigInt(),
        encodeEncodingValuePrimitive,
      );
    } else {
      return EncodingValueText(
        key,
        type,
        value.toString(),
        encodeEncodingValueText,
      );
    }
  }

  EncodingValueList<String> valueToParameterValueList(
    Object? value,
    Type? type, {
    String? key,
  }) {
    key ??= '?';

    var list =
        value is Iterable
            ? value.map((v) => valueToSQLPlain(v, type, key: key)).toList()
            : [valueToSQLPlain(value, type, key: key)];

    return EncodingValueList(key, type, list, encodeEncodingValueList);
  }

  FutureOr<EncodingValue<String, Object?>> conditionParameterToParameterValue(
    ConditionParameter parameter,
    EncodingContext context,
    String? fieldKey,
    Type? fieldType, {
    bool valueAsList = false,
  }) {
    var parameterKey =
        (parameter.hasKey ? parameter.key : parameter.contextKey) ?? fieldKey;

    if (parameterKey == null) {
      throw ConditionEncodingError(
        'Field key not in context: $parameter > $this',
      );
    }

    var parameterValue = resolveParameterValue(
      parameterKey,
      parameter,
      context,
      fieldType,
      valueAsList: valueAsList,
    );

    return parameterValue;
  }
}

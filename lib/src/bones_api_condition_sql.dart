import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';

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
      var valueSQLRet =
          valueToSQL(context, c.idValue, fieldKey: idKey, fieldType: int);

      return valueSQLRet.resolveMapped((valueSQL) {
        context.write(' $tableAlias.id = ');
        context.write(valueSQL);
        context.write(' ');

        return context;
      });
    } else {
      var tableSchemeRet = schemeProvider.getTableScheme(tableName);

      return tableSchemeRet.resolveMapped((tableScheme) {
        if (tableScheme == null) {
          throw StateError("Can't find TableScheme for entity: $tableName");
        }

        var idFieldName = tableScheme.idFieldName ?? 'id';
        var idType = tableScheme.fieldsTypes[idFieldName];

        var idKey = context.addEncodingParameter(idFieldName, c.idValue);
        var valueSQLRet =
            valueToSQL(context, c.idValue, fieldKey: idKey, fieldType: idType);

        return valueSQLRet.resolveMapped((valueSQL) {
          var q = sqlElementQuote;

          context.write(' $q$tableAlias$q.$q$idFieldName$q = ');
          context.write(valueSQL);
          context.write(' ');

          return context;
        });
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

  FutureOr<EncodingContext> encodeKeyConditionOperator(
      KeyCondition c, EncodingContext context, String operator) {
    var retKeySQL = keyToSQL(c, context);

    return retKeySQL.resolveMapped((keySQL) {
      var keyType = keySQL.key;
      var keyName = keySQL.value;

      context.write(' ');
      context.write(keyName);

      context.write(' ');
      context.write(operator);
      context.write(' ');

      var valueSQLRet = valueToSQL(context, c.value, fieldType: keyType);

      return valueSQLRet.resolveMapped((valueSQL) {
        context.write(valueSQL);
        context.write(' ');

        return context;
      });
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
        throw StateError("Can't find TableScheme for: $tableName");
      }

      var q = sqlElementQuote;

      var tableFieldName = tableScheme.resolveTableFiledName(key0.name);
      var tableFieldType = tableFieldName != null
          ? tableScheme.fieldsTypes[tableFieldName]
          : null;

      if (tableFieldType != null) {
        return MapEntry(tableFieldType, '$q$tableAlias$q.$q${key0.name}$q');
      }

      var retFieldType = schemeProvider.getFieldType(key0.name,
          entityName: context.entityName, tableName: context.tableName);

      return retFieldType.resolveMapped((fieldType) {
        if (fieldType == null) {
          throw ConditionEncodingError(
              'No field type for key[0]> keys: $key0 $keys ; entityName: ${context.entityName} ; tableName: ${context.tableName} > $this ; tableScheme: $tableScheme');
        }

        var retTableNameRef = schemeProvider.getTableForType(fieldType);

        return retTableNameRef.resolveMapped((tableNameRef) {
          if (tableNameRef == null) {
            throw ConditionEncodingError(
                'No referenced table or relationship table for key[0]> keys: $key0 $keys ; tableName: $tableName ; fieldType: $fieldType> $this ; tableScheme: $tableScheme');
          }

          var relationship = tableScheme.getTableRelationshipReference(
              tableNameRef, tableNameRef);

          if (relationship == null) {
            throw ConditionEncodingError(
                'No relationship table with target table $tableNameRef> keys: $key0 $keys ; tableName: $tableName ; fieldType: $fieldType> $this ; tableScheme: $tableScheme');
          }

          context.relationshipTables[tableNameRef] ??= relationship;

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
        throw StateError("Can't find TableScheme for: $tableName");
      }

      var fieldRef = tableScheme.getFieldsReferencedTables(key0.name);

      if (fieldRef != null) {
        context.fieldsReferencedTables.add(fieldRef);
        var entityAlias = context.resolveEntityAlias(fieldRef.targetTable);

        var key1 = keys[1];

        if (key1 is ConditionKeyField) {
          var targetTableSchemeRet =
              schemeProvider.getTableScheme(fieldRef.targetTable);

          return targetTableSchemeRet.resolveMapped((targetTableScheme) {
            if (targetTableScheme == null) {
              throw StateError(
                  "Can't find TableScheme for target table: $fieldRef");
            }
            var q = sqlElementQuote;
            var targetFieldName =
                targetTableScheme.resolveTableFiledName(key1.name);
            var targetFieldType =
                targetTableScheme.fieldsTypes[targetFieldName]!;
            return MapEntry(
                targetFieldType, '$q$entityAlias$q.$q$targetFieldName$q');
          });
        } else {
          throw ConditionEncodingError('Key: $c');
        }
      }

      var retFieldType = schemeProvider.getFieldType(key0.name,
          entityName: context.entityName, tableName: context.tableName);

      return retFieldType.resolveMapped((fieldType) {
        if (fieldType == null) {
          throw ConditionEncodingError(
              'No field type for key[0]> keys: $key0 $keys ; entityName: ${context.entityName} ; tableName: ${context.tableName} > $this ; tableScheme: $tableScheme');
        }

        var retTableNameRef = schemeProvider.getTableForType(fieldType);

        return retTableNameRef.resolveMapped((tableNameRef) {
          if (tableNameRef == null) {
            throw ConditionEncodingError(
                'No referenced table or relationship table for key[0]> keys: $key0 $keys ; tableName: $tableName ; fieldType: $fieldType> $this ; tableScheme: $tableScheme');
          }

          var relationship = tableScheme.getTableRelationshipReference(
              tableNameRef, tableNameRef);

          if (relationship == null) {
            throw ConditionEncodingError(
                'No relationship table with target table $tableNameRef> keys: $key0 $keys ; tableName: $tableName ; fieldType: $fieldType> $this ; tableScheme: $tableScheme');
          }

          context.relationshipTables[tableNameRef] ??= relationship;

          var targetAlias =
              context.resolveEntityAlias(relationship.targetTable);

          var key1 = keys[1];

          if (key1 is ConditionKeyField) {
            var targetTableSchemeRet =
                schemeProvider.getTableScheme(relationship.targetTable);

            return targetTableSchemeRet.resolveMapped((targetTableScheme) {
              if (targetTableScheme == null) {
                throw StateError(
                    "Can't find TableScheme for target table: $relationship");
              }
              var q = sqlElementQuote;
              var targetFieldName =
                  targetTableScheme.resolveTableFiledName(key1.name);
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

  FutureOr<String> valueToSQL(EncodingContext context, dynamic value,
      {String? fieldKey, Type? fieldType}) {
    if (value == null || value == Null) {
      return 'null';
    } else if (value is ConditionParameter) {
      return conditionParameterToSQL(value, context, fieldKey, fieldType);
    }

    if (fieldType != null) {
      return resolveValueToType(value, fieldType).resolveMapped((resolvedVal) {
        return valueToPlainSQL(resolvedVal);
      });
    } else {
      return valueToPlainSQL(value);
    }
  }

  String valueToPlainSQL(Object? value) {
    if (value == null || value == Null) {
      return 'null';
    } else if (value is num || value is bool) {
      return value.toString();
    } else {
      var valueStr = '$value';
      valueStr = escapeStringQuotes(valueStr, "'");
      return "'$valueStr'";
    }
  }

  String escapeStringQuotes(String valueStr, String quote) =>
      valueStr.replaceAll(quote, "\\$quote");

  String conditionParameterToSQL(ConditionParameter parameter,
      EncodingContext context, String? fieldKey, Type? fieldType) {
    if (parameter.hasKey) {
      return resolveParameterValue(
          parameter.key!, parameter, context, fieldType);
    }

    var contextKey = parameter.contextKey;

    if (contextKey != null) {
      return resolveParameterValue(contextKey, parameter, context, fieldType);
    }

    if (fieldKey != null) {
      return resolveParameterValue(fieldKey, parameter, context, fieldType);
    }

    throw ConditionEncodingError(
        'Field key not in context: $parameter > $this');
  }
}

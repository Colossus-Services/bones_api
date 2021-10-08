import 'package:async_extension/async_extension.dart';

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
      var valueSQL = valueToSQL(context, c.idValue, idKey);

      context.write(' $tableAlias.id = ');
      context.write(valueSQL);
      context.write(' ');

      return context;
    } else {
      var tableSchemeRet = schemeProvider.getTableScheme(tableName);

      return tableSchemeRet.resolveMapped((tableScheme) {
        if (tableScheme == null) {
          throw StateError("Can't find TableScheme for entity: $tableName");
        }

        var idFieldName = tableScheme.idFieldName ?? 'id';

        var idKey = context.addEncodingParameter(idFieldName, c.idValue);
        var valueSQL = valueToSQL(context, c.idValue, idKey);

        var q = sqlElementQuote;

        context.write(' $q$tableAlias$q.$q$idFieldName$q = ');
        context.write(valueSQL);
        context.write(' ');

        return context;
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
      context.write(' ');
      context.write(keySQL);

      context.write(' ');
      context.write(operator);
      context.write(' ');

      var valueSQL = valueToSQL(context, c.value);

      context.write(valueSQL);
      context.write(' ');

      return context;
    });
  }

  FutureOr<String> keyToSQL(
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

  String keyFieldToSQL(
    KeyCondition<dynamic, dynamic> c,
    EncodingContext context,
  ) {
    var tableName = context.tableNameOrEntityName;
    var tableAlias = context.resolveEntityAlias(tableName);

    var keys = c.keys;
    var key0 = keys.first as ConditionKeyField;

    var q = sqlElementQuote;
    return '$q$tableAlias$q.$q${key0.name}$q';
  }

  FutureOr<String> keyFieldReferenceToSQL(
    KeyCondition<dynamic, dynamic> c,
    EncodingContext context,
  ) {
    var schemeProvider = this.schemeProvider;
    var tableName = context.tableNameOrEntityName;

    if (schemeProvider == null) {
      throw ConditionEncodingError(
          'No SchemeProvider> entityName: $tableName > $this');
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
          var q = sqlElementQuote;
          return '$q$entityAlias$q.$q${key1.name}$q';
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
            var q = sqlElementQuote;
            return '$q$targetAlias$q.$q${key1.name}$q';
          } else {
            throw ConditionEncodingError('Key: $c');
          }
        });
      });
    });
  }

  String valueToSQL(EncodingContext context, dynamic value,
      [String? fieldKey]) {
    if (value == null || value == Null) {
      return 'null';
    }

    if (value is ConditionParameter) {
      return conditionParameterToSQL(value, context, fieldKey);
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

  String conditionParameterToSQL(
      ConditionParameter parameter, EncodingContext context, String? fieldKey) {
    if (parameter.hasKey) {
      return resolveParameterValue(parameter.key!, parameter, context);
    }

    var contextKey = parameter.contextKey;

    if (contextKey != null) {
      return resolveParameterValue(contextKey, parameter, context);
    }

    if (fieldKey != null) {
      return resolveParameterValue(fieldKey, parameter, context);
    }

    throw ConditionEncodingError(
        'Field key not in context: $parameter > $this');
  }
}

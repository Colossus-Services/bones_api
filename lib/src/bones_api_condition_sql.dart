import 'package:async_extension/async_extension.dart';
import 'package:logging/logging.dart' as logging;
import 'package:statistics/statistics.dart';

import 'bones_api_condition.dart';
import 'bones_api_condition_encoder.dart';

final _log = logging.Logger('ConditionSQLEncoder');

/// A [Condition] encoder for SQL.
class ConditionSQLEncoder extends ConditionEncoder {
  final String sqlElementQuote;

  /// See `SQLDialect.intParameterTypeSuffix`.
  final String? intParameterTypeSuffix;

  /// See `SQLDialect.maxIDsAsParameters`.
  final int maxIDsAsParameters;

  /// See `SQLDialect.regExpSyntax`.
  final SQLRegExpSyntax regExpSyntax;

  ConditionSQLEncoder(
    SchemeProvider super.schemeProvider, {
    required this.sqlElementQuote,
    this.intParameterTypeSuffix,
    this.maxIDsAsParameters = 512,
    this.regExpSyntax = SQLRegExpSyntax.function,
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

    // Never `null`: required by the constructor.
    var tableSchemeRet = schemeProvider!.getTableScheme(tableName);

    return tableSchemeRet.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for entity/table: $tableName";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var idFieldName = tableScheme.idFieldName ?? 'id';
      var idType = tableScheme.fieldsTypes[idFieldName] ?? int;

      var idKey = context.addEncodingParameter(idFieldName, c.idValue);
      var q = sqlElementQuote;
      // The column, not `idKey` (renamed if a query parameter has its name):
      var tableKey = '$q$tableAlias$q.$q$idFieldName$q';

      return encodeIDValues(context, idType, idKey, tableKey, c.idValue, false);
    });
  }

  @override
  FutureOr<EncodingContext> encodeIDConditionIN(
    ConditionIdIN c,
    EncodingContext context,
  ) {
    var tableName = context.tableNameOrEntityName;
    var tableAlias = context.resolveEntityAlias(tableName);

    // Never `null`: required by the constructor.
    var tableSchemeRet = schemeProvider!.getTableScheme(tableName);

    return tableSchemeRet.resolveMapped((tableScheme) {
      if (tableScheme == null) {
        var errorMsg = "Can't find `TableScheme` for entity/table: $tableName";
        _log.severe(errorMsg);
        throw StateError(errorMsg);
      }

      var idFieldName = tableScheme.idFieldName ?? 'id';
      var idType = tableScheme.fieldsTypes[idFieldName] ?? int;

      var idKey = context.addEncodingParameter(idFieldName, c.idsValues);
      var q = sqlElementQuote;
      // The column, not `idKey` (renamed if a query parameter has its name):
      var tableKey = '$q$tableAlias$q.$q$idFieldName$q';

      return encodeIDValues(
        context,
        idType,
        idKey,
        tableKey,
        c.idsValues,
        true,
      );
    });
  }

  /// Writes the comparison of the ID column ([tableKey]) with [idValue] (`=`)
  /// or with the [idValue] list (`IN`), as parameters (placeholders) rather
  /// than values written into the SQL: the statement text is the same for
  /// any ID, so it can be reused (prepared statements, SQL caches).
  ///
  /// An `IN` list is padded (repeating its last ID, which doesn't change what
  /// it matches) to a few sizes ([idsListPaddedLength]), so its text is also
  /// the same for lists of similar lengths.
  ///
  /// With [maxIDsAsParameters] `0` (MySQL), for a list padded beyond
  /// [maxIDsAsParameters], and for a `null` ID, an empty list, or a
  /// [ConditionParameter] (`#ID == ?`: already a parameter of the query), the
  /// IDs are encoded as before (written as values).
  FutureOr<EncodingContext> encodeIDValues(
    EncodingContext context,
    Type idType,
    String idKey,
    String tableKey,
    Object? idValue,
    bool isList,
  ) {
    if (maxIDsAsParameters < 1 ||
        idValue == null ||
        idValue is ConditionParameter ||
        (idValue is Iterable &&
            (idValue.isEmpty ||
                idsListPaddedLength(idValue.length) > maxIDsAsParameters ||
                idValue.any((e) => e is ConditionParameter)))) {
      return encodeConditionValuesWithOperator(
        context,
        idType,
        idKey,
        tableKey,
        isList ? 'IN' : '=',
        idValue,
        isList,
      );
    }

    var resolvedRet = resolveValueToType(idValue, idType, valueAsList: isList);

    return resolvedRet.resolveMapped((resolved) {
      var parameterKey = _newIDParameterKey(context);
      var placeholders = context.parametersPlaceholders;

      context.write(' ');
      context.write(tableKey);

      var intSuffix = intParameterTypeSuffix;

      void writePlaceholder(String key, Object? value) {
        context.write(parameterPlaceholder(key));
        if (intSuffix != null && value is int) context.write(intSuffix);
      }

      if (!isList) {
        placeholders[parameterKey] = resolved;
        context.write(' = ');
        writePlaceholder(parameterKey, resolved);
        context.write(' ');
        return context;
      }

      var ids = resolved is Iterable ? resolved.toList() : [resolved];
      var length = idsListPaddedLength(ids.length);
      var last = ids.last;

      context.write(' IN ( ');
      for (var i = 0; i < length; ++i) {
        var k = parameterPlaceholderIndexKey(parameterKey, i);
        var v = i < ids.length ? ids[i] : last;
        placeholders[k] = v;
        if (i > 0) context.write(' , ');
        writePlaceholder(k, v);
      }
      context.write(' ) ');

      return context;
    });
  }

  /// The length an `IN` list of IDs is padded to: `1`, `2`, `4`, `8` ... up to
  /// `256`, then multiples of `256`.
  static int idsListPaddedLength(int length) {
    if (length <= 1) return 1;
    if (length > 256) return ((length + 255) ~/ 256) * 256;
    var n = 2;
    while (n < length) {
      n <<= 1;
    }
    return n;
  }

  /// A parameter key for an ID not used by the [context]'s parameters.
  String _newIDParameterKey(EncodingContext context) =>
      newParameterKey(context, 'id__p');

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

  /// Encodes a [KeyConditionRegExp] with the [regExpSyntax]. The pattern is
  /// always a parameter (never written in the SQL): a literal pattern in a new
  /// parameter, and a pattern parameter (`/?:name/`) in its own key, holding
  /// its pattern ([SQLRegExpSyntax.adaptPattern]), or for
  /// [SQLRegExpSyntax.dart], its value as is (a `RegExp` keeps its `i` flag
  /// when the condition is matched in memory).
  @override
  FutureOr<EncodingContext> encodeKeyConditionRegExp(
    KeyConditionRegExp c,
    EncodingContext context,
  ) {
    return keyToSQL(c, context).resolveMapped((keySQL) {
      var keyType = keySQL.key;
      var tableKey = keySQL.value;

      var placeholders = context.parametersPlaceholders;
      var syntax = regExpSyntax;

      String parameterKey;
      String pattern;
      bool caseInsensitive;

      var patternParameter = c.patternParameter;
      if (patternParameter != null) {
        var paramValue = patternParameter.getValue(
          parameters: context.parameters,
          positionalParameters: context.positionalParameters,
          namedParameters: context.namedParameters,
          encodingParameters: context.encodingParameters,
        );

        (pattern, caseInsensitive) = KeyConditionRegExp.resolvePatternValue(
          paramValue,
          caseInsensitive: c.caseInsensitive,
        );

        var placeholderValue = syntax == SQLRegExpSyntax.dart
            ? paramValue
            : syntax.adaptPattern(pattern);

        var key = patternParameter.hasKey
            ? patternParameter.key
            : patternParameter.contextKey;

        if (key == null || key.isEmpty) key = 'regexp__p';

        // The parameter's own key, unless already used for another value
        // (e.g. `name == ? && name =~ /?/`, both keyed by `name`):
        parameterKey =
            !placeholders.containsKey(key) ||
                placeholders[key] == placeholderValue
            ? key
            : newParameterKey(context, key);

        placeholders[parameterKey] = placeholderValue;
      } else {
        pattern = c.pattern!;
        caseInsensitive = c.caseInsensitive;

        parameterKey = newParameterKey(context, 'regexp__p');
        placeholders[parameterKey] = syntax.adaptPattern(pattern);
      }

      context.write(' ');
      context.write(
        syntax.matchSQL(
          tableKey,
          parameterPlaceholder(parameterKey),
          caseInsensitive: caseInsensitive,
          not: c.not,
          castToText: keyType != String,
        ),
      );
      context.write(' ');

      return context;
    });
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

    // The encoding value rather than only its text: a null supplied as a
    // parameter encodes to a placeholder, so the text alone cannot say whether
    // the comparison is against null.
    var valueRet = valueToParameterValue(
      context,
      values,
      fieldKey: fieldKey,
      fieldType: keyType,
      valueAsList: valueAsList,
    );

    return valueRet.resolveMapped((value) {
      if (isNullEncodingValue(value, context)) {
        switch (operator) {
          case '=':
          case 'IN':
            {
              context.write('IS NULL ');
              _markPlaceholderInlinedAsNull(value, context);
              return context;
            }
          case '!=':
          case 'NOT IN':
            {
              context.write('IS NOT NULL ');
              _markPlaceholderInlinedAsNull(value, context);
              return context;
            }
        }
      }

      context.write(operator);
      context.write(' ');
      context.write(value.encode);
      context.write(' ');
      return context;
    });
  }

  /// Records that [value]'s placeholder was written as `IS NULL`/`IS NOT NULL`,
  /// so its parameter can be dropped if nothing else references it.
  ///
  /// Only a placeholder is registered as a parameter; an inlined
  /// [EncodingValueNull] never was, so it has nothing to drop.
  void _markPlaceholderInlinedAsNull(
    EncodingValue<String, Object?> value,
    EncodingContext context,
  ) {
    if (value is EncodingPlaceholder) {
      context.markPlaceholderInlinedAsNull(value.key);
    }
  }

  /// Whether [value] is a comparison against SQL `NULL`.
  ///
  /// A null written straight into the statement arrives as an
  /// [EncodingValueNull], which is the case this encoder has always handled. A
  /// null supplied as a *parameter* arrives as an [EncodingPlaceholder]: its
  /// text is the placeholder and the value itself is held in the context, so
  /// it has to be looked up there.
  ///
  /// Missing that produced `field = ?` bound to null. `= NULL` is never true
  /// in SQL, so such a query returned nothing at all rather than the rows whose
  /// column is null.
  bool isNullEncodingValue(
    EncodingValue<String, Object?> value,
    EncodingContext context,
  ) {
    if (value is EncodingValueNull) return true;

    if (value is EncodingPlaceholder) {
      // Absent and present-but-null both mean the statement binds null.
      return context.parametersPlaceholders[value.key] == null;
    }

    return false;
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
      var tableFieldType = tableFieldName != null
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

    final keys = c.keys;
    if (keys.isEmpty) {
      throw ConditionEncodingError('Empty key path: $c');
    }

    ConditionKeyField getKey(int index) {
      var k = keys[index];
      if (k is! ConditionKeyField) {
        throw ConditionEncodingError(
          "key[$index] is not a `ConditionKeyField`: $k",
        );
      }
      return k;
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
          key: getKey(index),
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
          key: getKey(index),
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
      var parametersValues = value.map((v) {
        if (v is ConditionParameter) {
          return conditionParameterToParameterValue(
            v,
            context,
            fieldKey,
            fieldType,
            valueAsList: valueAsList,
          );
        } else {
          return _valueToParameterValueImpl(
            v,
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

    var list = value is Iterable
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

/// How a SQL dialect matches a regular expression ([KeyConditionRegExp]).
///
/// Every syntax has the same semantics (PostgreSQL's): the pattern matches
/// anywhere in the value, `.` also matches a line terminator, and `^`/`$` match
/// only at the start/end of the whole value.
enum SQLRegExpSyntax {
  /// PostgreSQL: `value ~ pattern` (`~*`, `!~`, `!~*`). A non-text value is
  /// cast to `TEXT`. A word boundary `\b`/`\B` is rewritten as `\y`/`\Y` (in
  /// PostgreSQL `\b` is a backspace, and `\B` a backslash).
  postgres,

  /// MySQL 8.0.4+: `REGEXP_LIKE(value, pattern, 'cn')`: `c`/`i` (case), `n`
  /// (`.` matches a line terminator). A `$` is rewritten as `\z`: ICU's `$`
  /// also matches before a final line terminator.
  mysql,

  /// A `regexp(pattern, value, flags)` function, that the adapter registers
  /// (SQLite), with the semantics of [KeyConditionRegExp.toDartRegExp].
  function,

  /// Not executed by a database: the condition is matched in memory
  /// ([KeyConditionRegExp.matchesEntityMap]). Written as [function].
  dart;

  /// The pattern to bind as the parameter of [matchSQL].
  String adaptPattern(String pattern) => switch (this) {
    postgres => wordBoundaryAsPostgres(pattern),
    mysql => dollarAsEndOfInput(pattern),
    _ => pattern,
  };

  /// The SQL matching the regexp [pattern] (a placeholder) against [value]
  /// (a column). [castToText] for a column that may not be text.
  String matchSQL(
    String value,
    String pattern, {
    required bool caseInsensitive,
    required bool not,
    bool castToText = false,
  }) {
    switch (this) {
      case postgres:
        {
          var v = castToText ? 'CAST($value AS TEXT)' : value;
          return '$v ${not ? '!' : ''}~${caseInsensitive ? '*' : ''} $pattern';
        }
      case mysql:
        {
          var flags = caseInsensitive ? 'in' : 'cn';
          return "${not ? 'NOT ' : ''}REGEXP_LIKE($value, $pattern, '$flags')";
        }
      case function:
      case dart:
        {
          var flags = caseInsensitive ? 'i' : '';
          return "${not ? 'NOT ' : ''}regexp($pattern, $value, '$flags')";
        }
    }
  }

  /// Rewrites each `$` of [pattern] as `\z` (end of input) for ICU (MySQL):
  /// not an escaped one (`\$`), nor in a class (`[...]`, also nested:
  /// `[[:digit:]$]`), nor quoted (`\Q...\E`).
  static String dollarAsEndOfInput(String pattern) {
    if (!pattern.contains(r'$')) return pattern;

    return _rewritePattern(
      pattern,
      nestedClasses: true,
      quoting: true,
      rewrite: (token) => token == r'$' ? r'\z' : null,
    );
  }

  /// Rewrites each word boundary `\b`/`\B` of [pattern] as PostgreSQL's
  /// `\y`/`\Y`: not in a class (`[\b]` is a backspace, as in PostgreSQL).
  static String wordBoundaryAsPostgres(String pattern) {
    if (!pattern.contains(r'\b') && !pattern.contains(r'\B')) return pattern;

    return _rewritePattern(
      pattern,
      nestedClasses: false,
      quoting: false,
      rewrite: (token) => switch (token) {
        r'\b' => r'\y',
        r'\B' => r'\Y',
        _ => null,
      },
    );
  }

  /// Scans [pattern] by token (`\x` escapes, characters), and replaces each
  /// one outside of a class (`[...]`) by [rewrite] (unless `null`).
  ///
  /// - In a class, a POSIX class (`[:alpha:]`, `[=a=]`, `[.a.]`) is a token,
  ///   and a `]` right after `[` or `[^` is a literal.
  /// - [nestedClasses]: a `[` in a class opens a nested class (ICU).
  /// - [quoting]: `\Q...\E` is kept as is (ICU).
  static String _rewritePattern(
    String pattern, {
    required bool nestedClasses,
    required bool quoting,
    required String? Function(String token) rewrite,
  }) {
    var s = StringBuffer();
    var classDepth = 0;
    // The index after a class opening (`[` or `[^`):
    var classStart = -1;

    for (var i = 0; i < pattern.length; ++i) {
      var c = pattern[i];

      if (c == r'\' && i + 1 < pattern.length) {
        var n = pattern[i + 1];

        if (quoting && n == 'Q') {
          var end = pattern.indexOf(r'\E', i + 2);
          var stop = end < 0 ? pattern.length : end + 2;
          s.write(pattern.substring(i, stop));
          i = stop - 1;
          continue;
        }

        var token = '$c$n';
        ++i;
        s.write((classDepth == 0 ? rewrite(token) : null) ?? token);
        continue;
      }

      if (classDepth > 0) {
        if (c == ']' && i != classStart) {
          --classDepth;
        } else if (c == '[' && i + 1 < pattern.length) {
          var n = pattern[i + 1];
          if (n == ':' || n == '=' || n == '.') {
            // A POSIX class: up to its closing `:]`, `=]` or `.]`.
            var end = pattern.indexOf('$n]', i + 2);
            if (end >= 0) {
              s.write(pattern.substring(i, end + 2));
              i = end + 1;
              continue;
            }
          }
          if (nestedClasses) {
            ++classDepth;
            classStart = _classContentStart(pattern, i);
          }
        }
        s.write(c);
        continue;
      }

      if (c == '[') {
        ++classDepth;
        classStart = _classContentStart(pattern, i);
        s.write(c);
        continue;
      }

      s.write(rewrite(c) ?? c);
    }

    return s.toString();
  }

  /// The index of the first character of the class opened at [i] (`[`),
  /// after a `^`.
  static int _classContentStart(String pattern, int i) =>
      i + 1 < pattern.length && pattern[i + 1] == '^' ? i + 2 : i + 1;

  /// The SQL function [function] (see [SQLRegExpSyntax.function]):
  /// `regexp(pattern, value [, flags])`, or `null` for a `null` argument.
  static bool? regexpFunction(Object? pattern, Object? value, [Object? flags]) {
    if (pattern == null || value == null) return null;

    var caseInsensitive = flags != null && '$flags'.contains('i');

    var regExp = KeyConditionRegExp.toDartRegExp(
      pattern.toString(),
      caseInsensitive: caseInsensitive,
    );

    return regExp.hasMatch(KeyConditionRegExp.valueToText(value));
  }
}

import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta_meta.dart';
import 'package:statistics/statistics.dart';

abstract class EntityAnnotation {
  const EntityAnnotation();
}

/// Configuration of a entity field.
/// - `hidden`: this field won't be stored if is hidden.
/// - `unique`: this filed should be unique in the repository/table.
/// - `minimum`: defines the minimum value or minimum size of the field.
/// - `maximum`: defines the maximum value or maximum size of the field.
/// - `regexp`: defines the [RegExp] pattern of the field.
/// - `validator`: defines a validation [Function] for the field.
@Target({TargetKind.field, TargetKind.getter})
class EntityField extends EntityAnnotation {
  final bool _hidden;
  final bool _unique;
  final num? minimum;
  final num? maximum;
  final String? regexp;
  final bool Function(Object? value)? validator;

  const EntityField(
      {bool hidden = false,
      bool unique = false,
      this.minimum,
      this.maximum,
      this.validator,
      this.regexp})
      : _hidden = hidden,
        _unique = unique;

  const EntityField.visible() : this(hidden: false);

  const EntityField.hidden() : this(hidden: true);

  const EntityField.unique() : this(unique: true);

  const EntityField.minimum(int minimum) : this(minimum: minimum);

  const EntityField.maximum(int maximum) : this(maximum: maximum);

  const EntityField.limits(int minimum, int maximum)
      : this(minimum: minimum, maximum: maximum);

  const EntityField.regexp(String regexp) : this(regexp: regexp);

  const EntityField.validator(bool Function(Object? value) validator)
      : this(validator: validator);

  /// Returns `true` if the annotated field should be hidden from storage.
  bool get isHidden => _hidden;

  /// Returns `true` if the annotated field should be visible to storage.
  bool get isVisible => !_hidden;

  /// Returns `true` if the annotated field should be unique.
  bool get isUnique => _unique;

  /// Returns `true` if [value] is valid for this [EntityField] configuration.
  bool isValidValue(Object? value, {String? fieldName}) =>
      validateValue(value, fieldName: fieldName) == null;

  /// Returns a [EntityFieldInvalid] if [value] is invalid for this [EntityField] configuration.
  EntityFieldInvalid? validateValue(Object? value,
      {String? fieldName, Type? entityType}) {
    var validator = this.validator;
    if (validator != null) {
      if (!validator(value)) {
        return EntityFieldInvalid('validator', value,
            fieldName: fieldName, entityType: entityType);
      }
    }

    var regexp = this.regexp;
    if (regexp != null) {
      var s = value == null ? '' : value.toString();

      var re = RegExp(regexp, dotAll: true);
      var valid = re.hasMatch(s);

      if (!valid) {
        return EntityFieldInvalid('regexp(${re.pattern})', value,
            entityType: entityType, fieldName: fieldName);
      }
    }

    if (value != null) {
      var maximum = this.maximum;

      if (maximum != null) {
        var invalid = false;
        String? valueStr;

        if (value is num) {
          if (value > maximum) invalid = true;
        } else if (value is BigInt) {
          if (value > maximum.toBigInt()) invalid = true;
        } else if (value is DynamicNumber) {
          if (value > maximum.toDynamicNumber()) invalid = true;
        } else if (value is String) {
          if (value.length > maximum) invalid = true;
        } else if (value is Iterable) {
          if (value.length > maximum) {
            invalid = true;
            valueStr = '${value.runtimeType}{length: ${value.length}';
          }
        }

        if (invalid) {
          valueStr ??= '$value';
          return EntityFieldInvalid('maximum($maximum)', value,
              entityType: entityType, fieldName: fieldName);
        }
      }

      var minimum = this.minimum;
      if (minimum != null) {
        var invalid = false;
        String? valueStr;

        if (value is num) {
          if (value < minimum) invalid = true;
        } else if (value is BigInt) {
          if (value < minimum.toBigInt()) invalid = true;
        } else if (value is DynamicNumber) {
          if (value < minimum.toDynamicNumber()) invalid = true;
        } else if (value is String) {
          if (value.length < minimum) invalid = true;
        } else if (value is Iterable) {
          if (value.length < minimum) {
            invalid = true;
            valueStr = '${value.runtimeType}{length: ${value.length}';
          }
        }

        if (invalid) {
          valueStr ??= '$value';
          return EntityFieldInvalid('minimum($minimum)', value,
              entityType: entityType, fieldName: fieldName);
        }
      }
    }

    return null;
  }
}

extension EntityFieldExtension on Iterable<EntityField> {
  List<num> get maximum => map((e) => e.maximum).whereNotNull().toList();

  List<num> get minimum => map((e) => e.minimum).whereNotNull().toList();

  List<String> get regexp => map((e) => e.regexp).whereNotNull().toList();

  List<EntityField> get isHidden => where((e) => e.isHidden).toList();

  List<EntityField> get isVisible => where((e) => e.isVisible).toList();
}

/// An entity field validation error.
class EntityFieldInvalid extends Error {
  /// The reason of the invalid error.
  final String reason;

  /// The invalid value.
  final Object? value;

  /// The entity [Type].
  final Type? entityType;

  /// The field name of the [value].
  final String? fieldName;

  Map<String, EntityFieldInvalid>? fieldEntityErrors;

  EntityFieldInvalid(this.reason, this.value,
      {this.entityType, this.fieldName, this.fieldEntityErrors});

  String get message {
    var msg = 'reason: $reason ; value: <${value?.toString().truncate(20)}>';

    var fieldEntityErrors = this.fieldEntityErrors;
    if (fieldEntityErrors != null && fieldEntityErrors.isNotEmpty) {
      for (var e in fieldEntityErrors.values) {
        msg += '\n- $e';
      }
    }

    return msg;
  }

  @override
  String toString() {
    var typeStr = entityType != null ? '($entityType)' : '';
    var fieldStr =
        fieldName != null && fieldName!.isNotEmpty ? '($fieldName)' : '';

    return 'Invalid entity$typeStr field$fieldStr> $message';
  }
}

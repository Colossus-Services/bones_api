//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.13.0
// BUILD COMMAND: dart run build_runner build
//

// coverage:ignore-file
// ignore_for_file: unused_element
// ignore_for_file: no_leading_underscores_for_local_identifiers
// ignore_for_file: camel_case_types
// ignore_for_file: camel_case_extensions
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: unnecessary_const
// ignore_for_file: unnecessary_cast
// ignore_for_file: unnecessary_type_check

part of 'bones_api_entity_instantiate_test.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

T __argOr$<T>(Object? a, T d) => ConstructorReflection.argOrDefault<T>(a, d);

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.13.0');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

Symbol? _getSymbol(String? key) {
  if (key == null) return null;

  switch (key) {
    case r"active":
      return const Symbol(r"active");
    case r"budget":
      return const Symbol(r"budget");
    case r"color":
      return const Symbol(r"color");
    case r"created":
      return const Symbol(r"created");
    case r"createdAt":
      return const Symbol(r"createdAt");
    case r"flags":
      return const Symbol(r"flags");
    case r"id":
      return const Symbol(r"id");
    case r"meta":
      return const Symbol(r"meta");
    case r"ranks":
      return const Symbol(r"ranks");
    case r"reviewStep":
      return const Symbol(r"reviewStep");
    case r"score":
      return const Symbol(r"score");
    case r"startTime":
      return const Symbol(r"startTime");
    case r"tags":
      return const Symbol(r"tags");
    case r"uses":
      return const Symbol(r"uses");
    case r"value":
      return const Symbol(r"value");
    default:
      return null;
  }
}

// ignore: non_constant_identifier_names
Counter Counter$fromJson(Map<String, Object?> map) =>
    Counter$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Counter Counter$fromJsonEncoded(String jsonEncoded) =>
    Counter$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Coupon Coupon$fromJson(Map<String, Object?> map) =>
    Coupon$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Coupon Coupon$fromJsonEncoded(String jsonEncoded) =>
    Coupon$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Invoice Invoice$fromJson(Map<String, Object?> map) =>
    Invoice$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Invoice Invoice$fromJsonEncoded(String jsonEncoded) =>
    Invoice$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Label Label$fromJson(Map<String, Object?> map) =>
    Label$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Label Label$fromJsonEncoded(String jsonEncoded) =>
    Label$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Note Note$fromJson(Map<String, Object?> map) =>
    Note$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Note Note$fromJsonEncoded(String jsonEncoded) =>
    Note$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Profile Profile$fromJson(Map<String, Object?> map) =>
    Profile$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Profile Profile$fromJsonEncoded(String jsonEncoded) =>
    Profile$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Project Project$fromJson(Map<String, Object?> map) =>
    Project$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Project Project$fromJsonEncoded(String jsonEncoded) =>
    Project$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Seat Seat$fromJson(Map<String, Object?> map) =>
    Seat$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Seat Seat$fromJsonEncoded(String jsonEncoded) =>
    Seat$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Settings Settings$fromJson(Map<String, Object?> map) =>
    Settings$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Settings Settings$fromJsonEncoded(String jsonEncoded) =>
    Settings$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Tag Tag$fromJson(Map<String, Object?> map) =>
    Tag$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Tag Tag$fromJsonEncoded(String jsonEncoded) =>
    Tag$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Task Task$fromJson(Map<String, Object?> map) =>
    Task$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Task Task$fromJsonEncoded(String jsonEncoded) =>
    Task$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
TaskState? TaskState$from(Object? o) =>
    TaskState$reflection.staticInstance.from(o);
// ignore: non_constant_identifier_names
TaskStep TaskStep$fromJson(Map<String, Object?> map) =>
    TaskStep$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
TaskStep TaskStep$fromJsonEncoded(String jsonEncoded) =>
    TaskStep$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Ticket Ticket$fromJson(Map<String, Object?> map) =>
    Ticket$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Ticket Ticket$fromJsonEncoded(String jsonEncoded) =>
    Ticket$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class Counter$reflection extends ClassReflection<Counter>
    with __ReflectionMixin {
  static final Expando<Counter$reflection> _objectReflections = Expando();

  factory Counter$reflection([Counter? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Counter$reflection._(object);
  }

  Counter$reflection._([Counter? object]) : super(Counter, r'Counter', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Counter$reflection withObject([Counter? obj]) =>
      Counter$reflection(obj)..setupInternalsWith(this);

  static Counter$reflection? _withoutObjectInstance;
  @override
  Counter$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Counter$reflection get staticInstance =>
      _withoutObjectInstance ??= Counter$reflection._();

  @override
  Counter$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Counter$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Counter? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Counter? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Counter? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Counter>> _constructors = {};

  @override
  ConstructorReflection<Counter>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Counter>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Counter>(
          this,
          Counter,
          '',
          () => Counter.new,
          const <__PR>[__PR(__TR.tListInt, 'values', false, true)],
          null,
          const <String, __PR>{
            'id': __PR(__TR.tInt, 'id', true, false),
            'value': __PR(__TR.tInt, 'value', true, false),
          },
          null,
          invoker: (a) => Counter(
            a[0] as List<int>,
            id: __argOr$<int?>(a[1], null),
            value: __argOr$<int?>(a[2], null),
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[Counted];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Counter? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'id',
    'value',
    'values',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Counter, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Counter, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Counter, T>? field<T>(String fieldName, [Counter? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Counter, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Counter, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Counter, T>;
  }

  FieldReflection<Counter, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Counter, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Counter, dynamic>? _fieldImpl(
    String fieldName,
    Counter? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Counter, int?>(
          this,
          Counter,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'value':
        return FieldReflection<Counter, int?>(
          this,
          Counted,
          __TR.tDynamic,
          'value',
          true,
          (o) =>
              () => o!.value,
          (o) =>
              (v) => o!.value = v,
          obj,
          false,
        );
      case 'values':
        return FieldReflection<Counter, List<int>>(
          this,
          Counted,
          __TR.tListDynamic,
          'values',
          false,
          (o) =>
              () => o!.values,
          (o) =>
              (v) => o!.values = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Counter? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'value': obj?.value,
      'values': obj?.values,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Counter, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Counter, R>? method<R>(String methodName, [Counter? obj]) =>
      null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Counter, R>? staticMethod<R>(String methodName) =>
      null;
}

class Coupon$reflection extends ClassReflection<Coupon> with __ReflectionMixin {
  static final Expando<Coupon$reflection> _objectReflections = Expando();

  factory Coupon$reflection([Coupon? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Coupon$reflection._(object);
  }

  Coupon$reflection._([Coupon? object]) : super(Coupon, r'Coupon', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Coupon$reflection withObject([Coupon? obj]) =>
      Coupon$reflection(obj)..setupInternalsWith(this);

  static Coupon$reflection? _withoutObjectInstance;
  @override
  Coupon$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Coupon$reflection get staticInstance =>
      _withoutObjectInstance ??= Coupon$reflection._();

  @override
  Coupon$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Coupon$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Coupon? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Coupon? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Coupon? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Coupon>> _constructors = {};

  @override
  ConstructorReflection<Coupon>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Coupon>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Coupon>(
          this,
          Coupon,
          '',
          () => Coupon.new,
          const <__PR>[__PR(__TR.tString, 'key', false, true)],
          null,
          const <String, __PR>{
            'uses': __PR(__TR.tInt, 'uses', false, false, 0),
          },
          null,
          invoker: (a) => Coupon(a[0] as String, uses: __argOr$<int>(a[1], 0)),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Coupon? obj]) => null;

  static const List<String> _fieldsNames = const <String>['key', 'uses'];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Coupon, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Coupon, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Coupon, T>? field<T>(String fieldName, [Coupon? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Coupon, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Coupon, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Coupon, T>;
  }

  FieldReflection<Coupon, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Coupon, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Coupon, dynamic>? _fieldImpl(String fieldName, Coupon? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'key':
        return FieldReflection<Coupon, String>(
          this,
          Coupon,
          __TR.tString,
          'key',
          false,
          (o) =>
              () => o!.key,
          (o) =>
              (v) => o!.key = v,
          obj,
          false,
        );
      case 'uses':
        return FieldReflection<Coupon, int>(
          this,
          Coupon,
          __TR.tInt,
          'uses',
          false,
          (o) =>
              () => o!.uses,
          (o) =>
              (v) => o!.uses = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Coupon? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'key': obj?.key,
      'uses': obj?.uses,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Coupon, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Coupon, R>? method<R>(String methodName, [Coupon? obj]) =>
      null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Coupon, R>? staticMethod<R>(String methodName) => null;
}

class Invoice$reflection extends ClassReflection<Invoice>
    with __ReflectionMixin {
  static final Expando<Invoice$reflection> _objectReflections = Expando();

  factory Invoice$reflection([Invoice? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Invoice$reflection._(object);
  }

  Invoice$reflection._([Invoice? object]) : super(Invoice, r'Invoice', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Invoice$reflection withObject([Invoice? obj]) =>
      Invoice$reflection(obj)..setupInternalsWith(this);

  static Invoice$reflection? _withoutObjectInstance;
  @override
  Invoice$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Invoice$reflection get staticInstance =>
      _withoutObjectInstance ??= Invoice$reflection._();

  @override
  Invoice$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Invoice$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Invoice? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Invoice? createInstanceWithEmptyConstructor() => Invoice.empty();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Invoice? createInstanceWithNoRequiredArgsConstructor() => Invoice.empty();

  static const List<String> _constructorsNames = const <String>['', 'empty'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Invoice>> _constructors = {};

  @override
  ConstructorReflection<Invoice>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Invoice>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Invoice>(
          this,
          Invoice,
          '',
          () => Invoice.new,
          const <__PR>[
            __PR(__TR.tString, 'number', false, true),
            __PR(__TR<Decimal>(Decimal), 'total', false, true),
          ],
          null,
          const <String, __PR>{'id': __PR(__TR.tInt, 'id', true, false)},
          const [JsonConstructor()],
          invoker: (a) => Invoice(
            a[0] as String,
            a[1] as Decimal,
            id: __argOr$<int?>(a[2], null),
          ),
        );
      case 'empty':
        return ConstructorReflection<Invoice>(
          this,
          Invoice,
          'empty',
          () => Invoice.empty,
          null,
          null,
          null,
          null,
          invoker: (a) => Invoice.empty(),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Invoice? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'id',
    'number',
    'total',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Invoice, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Invoice, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Invoice, T>? field<T>(String fieldName, [Invoice? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Invoice, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Invoice, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Invoice, T>;
  }

  FieldReflection<Invoice, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Invoice, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Invoice, dynamic>? _fieldImpl(
    String fieldName,
    Invoice? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Invoice, int?>(
          this,
          Invoice,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'number':
        return FieldReflection<Invoice, String>(
          this,
          Invoice,
          __TR.tString,
          'number',
          false,
          (o) =>
              () => o!.number,
          (o) =>
              (v) => o!.number = v,
          obj,
          false,
        );
      case 'total':
        return FieldReflection<Invoice, Decimal>(
          this,
          Invoice,
          const __TR<Decimal>(Decimal),
          'total',
          false,
          (o) =>
              () => o!.total,
          (o) =>
              (v) => o!.total = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Invoice? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'number': obj?.number,
      'total': obj?.total,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Invoice, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Invoice, R>? method<R>(String methodName, [Invoice? obj]) =>
      null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Invoice, R>? staticMethod<R>(String methodName) =>
      null;
}

class Label$reflection extends ClassReflection<Label> with __ReflectionMixin {
  static final Expando<Label$reflection> _objectReflections = Expando();

  factory Label$reflection([Label? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Label$reflection._(object);
  }

  Label$reflection._([Label? object]) : super(Label, r'Label', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Label$reflection withObject([Label? obj]) =>
      Label$reflection(obj)..setupInternalsWith(this);

  static Label$reflection? _withoutObjectInstance;
  @override
  Label$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Label$reflection get staticInstance =>
      _withoutObjectInstance ??= Label$reflection._();

  @override
  Label$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Label$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Label? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Label? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Label? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Label>> _constructors = {};

  @override
  ConstructorReflection<Label>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Label>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Label>(
          this,
          Label,
          '',
          () => Label.new,
          const <__PR>[__PR(__TR.tString, 'name', false, true)],
          null,
          const <String, __PR>{
            'color': __PR(__TR.tString, 'color', true, false),
            'id': __PR(__TR.tInt, 'id', true, false),
          },
          null,
          invoker: (a) => Label(
            a[0] as String,
            color: __argOr$<String?>(a[1], null),
            id: __argOr$<int?>(a[2], null),
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Label? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'color',
    'id',
    'name',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Label, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Label, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Label, T>? field<T>(String fieldName, [Label? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Label, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Label, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Label, T>;
  }

  FieldReflection<Label, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Label, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Label, dynamic>? _fieldImpl(String fieldName, Label? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Label, int?>(
          this,
          Label,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'name':
        return FieldReflection<Label, String>(
          this,
          Label,
          __TR.tString,
          'name',
          false,
          (o) =>
              () => o!.name,
          (o) =>
              (v) => o!.name = v,
          obj,
          false,
        );
      case 'color':
        return FieldReflection<Label, String?>(
          this,
          Label,
          __TR.tString,
          'color',
          true,
          (o) =>
              () => o!.color,
          (o) =>
              (v) => o!.color = v,
          obj,
          false,
          const [JsonFieldAlias('colorCode')],
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Label? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      'color': obj?.color,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Label, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Label, R>? method<R>(String methodName, [Label? obj]) =>
      null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Label, R>? staticMethod<R>(String methodName) => null;
}

class Note$reflection extends ClassReflection<Note> with __ReflectionMixin {
  static final Expando<Note$reflection> _objectReflections = Expando();

  factory Note$reflection([Note? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Note$reflection._(object);
  }

  Note$reflection._([Note? object]) : super(Note, r'Note', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Note$reflection withObject([Note? obj]) =>
      Note$reflection(obj)..setupInternalsWith(this);

  static Note$reflection? _withoutObjectInstance;
  @override
  Note$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Note$reflection get staticInstance =>
      _withoutObjectInstance ??= Note$reflection._();

  @override
  Note$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Note$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Note? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Note? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Note? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Note>> _constructors = {};

  @override
  ConstructorReflection<Note>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Note>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Note>(
          this,
          Note,
          '',
          () => Note.new,
          const <__PR>[__PR(__TR.tString, 'text', false, true)],
          null,
          const <String, __PR>{
            'created': __PR(__TR.tObject, 'created', true, false),
            'id': __PR(__TR.tInt, 'id', true, false),
          },
          null,
          invoker: (a) => Note(
            a[0] as String,
            created: __argOr$<Object?>(a[1], null),
            id: __argOr$<int?>(a[2], null),
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Note? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'created',
    'id',
    'text',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Note, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<Note, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Note, T>? field<T>(String fieldName, [Note? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Note, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Note, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Note, T>;
  }

  FieldReflection<Note, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Note, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Note, dynamic>? _fieldImpl(String fieldName, Note? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Note, int?>(
          this,
          Note,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'text':
        return FieldReflection<Note, String>(
          this,
          Note,
          __TR.tString,
          'text',
          false,
          (o) =>
              () => o!.text,
          (o) =>
              (v) => o!.text = v,
          obj,
          false,
        );
      case 'created':
        return FieldReflection<Note, DateTime>(
          this,
          Note,
          const __TR<DateTime>(DateTime),
          'created',
          false,
          (o) =>
              () => o!.created,
          (o) =>
              (v) => o!.created = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(Note? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'text': obj?.text,
      'created': obj?.created,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Note, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Note, R>? method<R>(String methodName, [Note? obj]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Note, R>? staticMethod<R>(String methodName) => null;
}

class Profile$reflection extends ClassReflection<Profile>
    with __ReflectionMixin {
  static final Expando<Profile$reflection> _objectReflections = Expando();

  factory Profile$reflection([Profile? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Profile$reflection._(object);
  }

  Profile$reflection._([Profile? object]) : super(Profile, r'Profile', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Profile$reflection withObject([Profile? obj]) =>
      Profile$reflection(obj)..setupInternalsWith(this);

  static Profile$reflection? _withoutObjectInstance;
  @override
  Profile$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Profile$reflection get staticInstance =>
      _withoutObjectInstance ??= Profile$reflection._();

  @override
  Profile$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Profile$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => true;
  @override
  Profile? createInstanceWithDefaultConstructor() => Profile();

  @override
  bool get hasEmptyConstructor => false;
  @override
  Profile? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Profile? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Profile>> _constructors = {};

  @override
  ConstructorReflection<Profile>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Profile>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Profile>(
          this,
          Profile,
          '',
          () => Profile.new,
          null,
          null,
          null,
          null,
          invoker: (a) => Profile(),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Profile? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'balance',
    'bio',
    'id',
    'lastSeen',
    'name',
    'verified',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Profile, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Profile, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Profile, T>? field<T>(String fieldName, [Profile? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Profile, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Profile, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Profile, T>;
  }

  FieldReflection<Profile, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Profile, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Profile, dynamic>? _fieldImpl(
    String fieldName,
    Profile? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Profile, int?>(
          this,
          Profile,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'name':
        return FieldReflection<Profile, String>(
          this,
          Profile,
          __TR.tString,
          'name',
          false,
          (o) =>
              () => o!.name,
          (o) =>
              (v) => o!.name = v,
          obj,
          false,
        );
      case 'bio':
        return FieldReflection<Profile, String?>(
          this,
          Profile,
          __TR.tString,
          'bio',
          true,
          (o) =>
              () => o!.bio,
          (o) =>
              (v) => o!.bio = v,
          obj,
          false,
        );
      case 'verified':
        return FieldReflection<Profile, bool>(
          this,
          Profile,
          __TR.tBool,
          'verified',
          false,
          (o) =>
              () => o!.verified,
          (o) =>
              (v) => o!.verified = v,
          obj,
          false,
        );
      case 'lastseen':
        return FieldReflection<Profile, DateTime?>(
          this,
          Profile,
          const __TR<DateTime>(DateTime),
          'lastSeen',
          true,
          (o) =>
              () => o!.lastSeen,
          (o) =>
              (v) => o!.lastSeen = v,
          obj,
          false,
        );
      case 'balance':
        return FieldReflection<Profile, Decimal?>(
          this,
          Profile,
          const __TR<Decimal>(Decimal),
          'balance',
          true,
          (o) =>
              () => o!.balance,
          (o) =>
              (v) => o!.balance = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Profile? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      'bio': obj?.bio,
      'verified': obj?.verified,
      'lastSeen': obj?.lastSeen,
      'balance': obj?.balance,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Profile, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Profile, R>? method<R>(String methodName, [Profile? obj]) =>
      null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Profile, R>? staticMethod<R>(String methodName) =>
      null;
}

class Project$reflection extends ClassReflection<Project>
    with __ReflectionMixin {
  static final Expando<Project$reflection> _objectReflections = Expando();

  factory Project$reflection([Project? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Project$reflection._(object);
  }

  Project$reflection._([Project? object]) : super(Project, r'Project', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Project$reflection withObject([Project? obj]) =>
      Project$reflection(obj)..setupInternalsWith(this);

  static Project$reflection? _withoutObjectInstance;
  @override
  Project$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Project$reflection get staticInstance =>
      _withoutObjectInstance ??= Project$reflection._();

  @override
  Project$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Project$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Project? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Project? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Project? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Project>> _constructors = {};

  @override
  ConstructorReflection<Project>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Project>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Project>(
          this,
          Project,
          '',
          () => Project.new,
          const <__PR>[
            __PR(__TR.tString, 'name', false, true),
            __PR(
              __TR<EntityReference<TaskStep>>(EntityReference, <__TR>[
                __TR<TaskStep>(TaskStep),
              ]),
              'mainStep',
              false,
              true,
            ),
            __PR(
              __TR<EntityReferenceList<TaskStep>>(EntityReferenceList, <__TR>[
                __TR<TaskStep>(TaskStep),
              ]),
              'steps',
              false,
              true,
            ),
          ],
          null,
          const <String, __PR>{
            'active': __PR(__TR.tBool, 'active', false, false, true),
            'budget': __PR(__TR<Decimal>(Decimal), 'budget', true, false),
            'createdAt': __PR(
              __TR<DateTime>(DateTime),
              'createdAt',
              true,
              false,
            ),
            'id': __PR(__TR.tInt, 'id', true, false),
            'reviewStep': __PR(
              __TR<EntityReference<TaskStep>>(EntityReference, <__TR>[
                __TR<TaskStep>(TaskStep),
              ]),
              'reviewStep',
              true,
              false,
            ),
            'startTime': __PR(__TR<Time>(Time), 'startTime', true, false),
          },
          null,
          invoker: (a) => Project(
            a[0] as String,
            a[1] as EntityReference<TaskStep>,
            a[2] as EntityReferenceList<TaskStep>,
            active: __argOr$<bool>(a[3], true),
            budget: __argOr$<Decimal?>(a[4], null),
            createdAt: __argOr$<DateTime?>(a[5], null),
            id: __argOr$<int?>(a[6], null),
            reviewStep: __argOr$<EntityReference<TaskStep>?>(a[7], null),
            startTime: __argOr$<Time?>(a[8], null),
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Project? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'active',
    'budget',
    'createdAt',
    'id',
    'mainStep',
    'name',
    'reviewStep',
    'startTime',
    'steps',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Project, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Project, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Project, T>? field<T>(String fieldName, [Project? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Project, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Project, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Project, T>;
  }

  FieldReflection<Project, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Project, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Project, dynamic>? _fieldImpl(
    String fieldName,
    Project? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Project, int?>(
          this,
          Project,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'name':
        return FieldReflection<Project, String>(
          this,
          Project,
          __TR.tString,
          'name',
          false,
          (o) =>
              () => o!.name,
          (o) =>
              (v) => o!.name = v,
          obj,
          false,
        );
      case 'mainstep':
        return FieldReflection<Project, EntityReference<TaskStep>>(
          this,
          Project,
          const __TR<EntityReference<TaskStep>>(EntityReference, <__TR>[
            __TR<TaskStep>(TaskStep),
          ]),
          'mainStep',
          false,
          (o) =>
              () => o!.mainStep,
          (o) =>
              (v) => o!.mainStep = v,
          obj,
          false,
        );
      case 'reviewstep':
        return FieldReflection<Project, EntityReference<TaskStep>?>(
          this,
          Project,
          const __TR<EntityReference<TaskStep>>(EntityReference, <__TR>[
            __TR<TaskStep>(TaskStep),
          ]),
          'reviewStep',
          true,
          (o) =>
              () => o!.reviewStep,
          (o) =>
              (v) => o!.reviewStep = v,
          obj,
          false,
        );
      case 'steps':
        return FieldReflection<Project, EntityReferenceList<TaskStep>>(
          this,
          Project,
          const __TR<EntityReferenceList<TaskStep>>(EntityReferenceList, <__TR>[
            __TR<TaskStep>(TaskStep),
          ]),
          'steps',
          false,
          (o) =>
              () => o!.steps,
          (o) =>
              (v) => o!.steps = v,
          obj,
          false,
        );
      case 'budget':
        return FieldReflection<Project, Decimal?>(
          this,
          Project,
          const __TR<Decimal>(Decimal),
          'budget',
          true,
          (o) =>
              () => o!.budget,
          (o) =>
              (v) => o!.budget = v,
          obj,
          false,
        );
      case 'active':
        return FieldReflection<Project, bool>(
          this,
          Project,
          __TR.tBool,
          'active',
          false,
          (o) =>
              () => o!.active,
          (o) =>
              (v) => o!.active = v,
          obj,
          false,
        );
      case 'starttime':
        return FieldReflection<Project, Time?>(
          this,
          Project,
          const __TR<Time>(Time),
          'startTime',
          true,
          (o) =>
              () => o!.startTime,
          (o) =>
              (v) => o!.startTime = v,
          obj,
          false,
        );
      case 'createdat':
        return FieldReflection<Project, DateTime?>(
          this,
          Project,
          const __TR<DateTime>(DateTime),
          'createdAt',
          true,
          (o) =>
              () => o!.createdAt,
          (o) =>
              (v) => o!.createdAt = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Project? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      'mainStep': obj?.mainStep,
      'reviewStep': obj?.reviewStep,
      'steps': obj?.steps,
      'budget': obj?.budget,
      'active': obj?.active,
      'startTime': obj?.startTime,
      'createdAt': obj?.createdAt,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Project, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Project, R>? method<R>(String methodName, [Project? obj]) =>
      null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Project, R>? staticMethod<R>(String methodName) =>
      null;
}

class Seat$reflection extends ClassReflection<Seat> with __ReflectionMixin {
  static final Expando<Seat$reflection> _objectReflections = Expando();

  factory Seat$reflection([Seat? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Seat$reflection._(object);
  }

  Seat$reflection._([Seat? object]) : super(Seat, r'Seat', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Seat$reflection withObject([Seat? obj]) =>
      Seat$reflection(obj)..setupInternalsWith(this);

  static Seat$reflection? _withoutObjectInstance;
  @override
  Seat$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Seat$reflection get staticInstance =>
      _withoutObjectInstance ??= Seat$reflection._();

  @override
  Seat$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Seat$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Seat? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Seat? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Seat? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Seat>> _constructors = {};

  @override
  ConstructorReflection<Seat>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Seat>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Seat>(
          this,
          Seat,
          '',
          () => Seat.new,
          const <__PR>[
            __PR(__TR.tInt, 'number', false, true),
            __PR(__TR.tString, 'label', false, true),
          ],
          null,
          null,
          null,
          invoker: (a) => Seat(a[0] as int, a[1] as String),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Seat? obj]) => null;

  static const List<String> _fieldsNames = const <String>['label', 'number'];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Seat, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<Seat, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Seat, T>? field<T>(String fieldName, [Seat? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Seat, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Seat, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Seat, T>;
  }

  FieldReflection<Seat, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Seat, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Seat, dynamic>? _fieldImpl(String fieldName, Seat? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'number':
        return FieldReflection<Seat, int>(
          this,
          Seat,
          __TR.tInt,
          'number',
          false,
          (o) =>
              () => o!.number,
          (o) =>
              (v) => o!.number = v,
          obj,
          false,
        );
      case 'label':
        return FieldReflection<Seat, String>(
          this,
          Seat,
          __TR.tString,
          'label',
          false,
          (o) =>
              () => o!.label,
          (o) =>
              (v) => o!.label = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(Seat? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'number': obj?.number,
      'label': obj?.label,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Seat, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Seat, R>? method<R>(String methodName, [Seat? obj]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Seat, R>? staticMethod<R>(String methodName) => null;
}

class Settings$reflection extends ClassReflection<Settings>
    with __ReflectionMixin {
  static final Expando<Settings$reflection> _objectReflections = Expando();

  factory Settings$reflection([Settings? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Settings$reflection._(object);
  }

  Settings$reflection._([Settings? object])
    : super(Settings, r'Settings', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Settings$reflection withObject([Settings? obj]) =>
      Settings$reflection(obj)..setupInternalsWith(this);

  static Settings$reflection? _withoutObjectInstance;
  @override
  Settings$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Settings$reflection get staticInstance =>
      _withoutObjectInstance ??= Settings$reflection._();

  @override
  Settings$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Settings$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => true;
  @override
  Settings? createInstanceWithDefaultConstructor() => Settings();

  @override
  bool get hasEmptyConstructor => false;
  @override
  Settings? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Settings? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Settings>> _constructors = {};

  @override
  ConstructorReflection<Settings>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Settings>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Settings>(
          this,
          Settings,
          '',
          () => Settings.new,
          null,
          null,
          const <String, __PR>{
            'flags': __PR(__TR.tSetString, 'flags', true, false),
            'id': __PR(__TR.tInt, 'id', true, false),
            'meta': __PR(__TR.tMapStringDynamic, 'meta', true, false),
            'ranks': __PR(__TR.tListInt, 'ranks', true, false),
            'tags': __PR(__TR.tListString, 'tags', false, false, const []),
          },
          null,
          invoker: (a) => Settings(
            flags: __argOr$<Set<String>?>(a[0], null),
            id: __argOr$<int?>(a[1], null),
            meta: __argOr$<Map<String, dynamic>?>(a[2], null),
            ranks: __argOr$<List<int>?>(a[3], null),
            tags: __argOr$<List<String>>(a[4], const []),
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Settings? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'flags',
    'id',
    'meta',
    'ranks',
    'tags',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Settings, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Settings, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Settings, T>? field<T>(String fieldName, [Settings? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Settings, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Settings, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Settings, T>;
  }

  FieldReflection<Settings, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Settings, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Settings, dynamic>? _fieldImpl(
    String fieldName,
    Settings? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Settings, int?>(
          this,
          Settings,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'tags':
        return FieldReflection<Settings, List<String>>(
          this,
          Settings,
          __TR.tListString,
          'tags',
          false,
          (o) =>
              () => o!.tags,
          (o) =>
              (v) => o!.tags = v,
          obj,
          false,
        );
      case 'ranks':
        return FieldReflection<Settings, List<int>?>(
          this,
          Settings,
          __TR.tListInt,
          'ranks',
          true,
          (o) =>
              () => o!.ranks,
          (o) =>
              (v) => o!.ranks = v,
          obj,
          false,
        );
      case 'meta':
        return FieldReflection<Settings, Map<String, dynamic>?>(
          this,
          Settings,
          __TR.tMapStringDynamic,
          'meta',
          true,
          (o) =>
              () => o!.meta,
          (o) =>
              (v) => o!.meta = v,
          obj,
          false,
        );
      case 'flags':
        return FieldReflection<Settings, Set<String>?>(
          this,
          Settings,
          __TR.tSetString,
          'flags',
          true,
          (o) =>
              () => o!.flags,
          (o) =>
              (v) => o!.flags = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Settings? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'tags': obj?.tags,
      'ranks': obj?.ranks,
      'meta': obj?.meta,
      'flags': obj?.flags,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Settings, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Settings, R>? method<R>(
    String methodName, [
    Settings? obj,
  ]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Settings, R>? staticMethod<R>(String methodName) =>
      null;
}

class Tag$reflection extends ClassReflection<Tag> with __ReflectionMixin {
  static final Expando<Tag$reflection> _objectReflections = Expando();

  factory Tag$reflection([Tag? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Tag$reflection._(object);
  }

  Tag$reflection._([Tag? object]) : super(Tag, r'Tag', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Tag$reflection withObject([Tag? obj]) =>
      Tag$reflection(obj)..setupInternalsWith(this);

  static Tag$reflection? _withoutObjectInstance;
  @override
  Tag$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Tag$reflection get staticInstance =>
      _withoutObjectInstance ??= Tag$reflection._();

  @override
  Tag$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Tag$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Tag? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Tag? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Tag? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Tag>> _constructors = {};

  @override
  ConstructorReflection<Tag>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Tag>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Tag>(
          this,
          Tag,
          '',
          () => Tag.new,
          const <__PR>[
            __PR(__TR.tString, 'name', false, true),
            __PR(__TR.tString, 'color', false, true),
          ],
          null,
          null,
          null,
          invoker: (a) => Tag(a[0] as String, a[1] as String),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Tag? obj]) => null;

  static const List<String> _fieldsNames = const <String>['color', 'name'];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Tag, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<Tag, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Tag, T>? field<T>(String fieldName, [Tag? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Tag, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Tag, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Tag, T>;
  }

  FieldReflection<Tag, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Tag, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Tag, dynamic>? _fieldImpl(String fieldName, Tag? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'name':
        return FieldReflection<Tag, String>(
          this,
          Tag,
          __TR.tString,
          'name',
          false,
          (o) =>
              () => o!.name,
          (o) =>
              (v) => o!.name = v,
          obj,
          false,
        );
      case 'color':
        return FieldReflection<Tag, String>(
          this,
          Tag,
          __TR.tString,
          'color',
          false,
          (o) =>
              () => o!.color,
          (o) =>
              (v) => o!.color = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(Tag? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'name': obj?.name,
      'color': obj?.color,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Tag, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Tag, R>? method<R>(String methodName, [Tag? obj]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Tag, R>? staticMethod<R>(String methodName) => null;
}

class Task$reflection extends ClassReflection<Task> with __ReflectionMixin {
  static final Expando<Task$reflection> _objectReflections = Expando();

  factory Task$reflection([Task? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Task$reflection._(object);
  }

  Task$reflection._([Task? object]) : super(Task, r'Task', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Task$reflection withObject([Task? obj]) =>
      Task$reflection(obj)..setupInternalsWith(this);

  static Task$reflection? _withoutObjectInstance;
  @override
  Task$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Task$reflection get staticInstance =>
      _withoutObjectInstance ??= Task$reflection._();

  @override
  Task$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Task$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Task? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Task? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Task? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Task>> _constructors = {};

  @override
  ConstructorReflection<Task>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Task>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Task>(
          this,
          Task,
          '',
          () => Task.new,
          const <__PR>[
            __PR(__TR.tString, 'title', false, true),
            __PR(__TR<TaskState>(TaskState), 'state', false, true),
            __PR(__TR<DateTime>(DateTime), 'due', false, true),
            __PR(
              __TR<List<TaskStep>>(List, <__TR>[__TR<TaskStep>(TaskStep)]),
              'steps',
              false,
              true,
            ),
          ],
          null,
          const <String, __PR>{
            'id': __PR(__TR.tInt, 'id', true, false),
            'score': __PR(__TR.tDouble, 'score', false, false, 0),
          },
          null,
          invoker: (a) => Task(
            a[0] as String,
            a[1] as TaskState,
            a[2] as DateTime,
            a[3] as List<TaskStep>,
            id: __argOr$<int?>(a[4], null),
            score: __argOr$<double>(a[5], 0),
          ),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Task? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'due',
    'id',
    'score',
    'state',
    'steps',
    'title',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Task, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<Task, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Task, T>? field<T>(String fieldName, [Task? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Task, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Task, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Task, T>;
  }

  FieldReflection<Task, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Task, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Task, dynamic>? _fieldImpl(String fieldName, Task? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Task, int?>(
          this,
          Task,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'title':
        return FieldReflection<Task, String>(
          this,
          Task,
          __TR.tString,
          'title',
          false,
          (o) =>
              () => o!.title,
          (o) =>
              (v) => o!.title = v,
          obj,
          false,
        );
      case 'state':
        return FieldReflection<Task, TaskState>(
          this,
          Task,
          const __TR<TaskState>(TaskState),
          'state',
          false,
          (o) =>
              () => o!.state,
          (o) =>
              (v) => o!.state = v,
          obj,
          false,
        );
      case 'due':
        return FieldReflection<Task, DateTime>(
          this,
          Task,
          const __TR<DateTime>(DateTime),
          'due',
          false,
          (o) =>
              () => o!.due,
          (o) =>
              (v) => o!.due = v,
          obj,
          false,
        );
      case 'score':
        return FieldReflection<Task, double>(
          this,
          Task,
          __TR.tDouble,
          'score',
          false,
          (o) =>
              () => o!.score,
          (o) =>
              (v) => o!.score = v,
          obj,
          false,
        );
      case 'steps':
        return FieldReflection<Task, List<TaskStep>>(
          this,
          Task,
          const __TR<List<TaskStep>>(List, <__TR>[__TR<TaskStep>(TaskStep)]),
          'steps',
          false,
          (o) =>
              () => o!.steps,
          (o) =>
              (v) => o!.steps = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(Task? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'title': obj?.title,
      'state': obj?.state,
      'due': obj?.due,
      'score': obj?.score,
      'steps': obj?.steps,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Task, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Task, R>? method<R>(String methodName, [Task? obj]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Task, R>? staticMethod<R>(String methodName) => null;
}

class TaskState$reflection extends EnumReflection<TaskState>
    with __ReflectionMixin {
  static final Expando<TaskState$reflection> _objectReflections = Expando();

  factory TaskState$reflection([TaskState? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= TaskState$reflection._(object);
  }

  TaskState$reflection._([TaskState? object])
    : super(TaskState, r'TaskState', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  TaskState$reflection withObject([TaskState? obj]) =>
      TaskState$reflection(obj);

  static TaskState$reflection? _withoutObjectInstance;
  @override
  TaskState$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static TaskState$reflection get staticInstance =>
      _withoutObjectInstance ??= TaskState$reflection._();

  @override
  TaskState$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    TaskState$reflection.staticInstance;
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<String> _staticFieldsNames = const <String>[
    'closed',
    'open',
  ];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  static const Map<String, TaskState> _valuesByName = const <String, TaskState>{
    'closed': TaskState.closed,
    'open': TaskState.open,
  };

  @override
  Map<String, TaskState> get valuesByName => _valuesByName;
  @override
  List<TaskState> get values => TaskState.values;

  static const List<String> _fieldsNames = const <String>[];

  @override
  List<String> get fieldsNames => _fieldsNames;
}

class TaskStep$reflection extends ClassReflection<TaskStep>
    with __ReflectionMixin {
  static final Expando<TaskStep$reflection> _objectReflections = Expando();

  factory TaskStep$reflection([TaskStep? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= TaskStep$reflection._(object);
  }

  TaskStep$reflection._([TaskStep? object])
    : super(TaskStep, r'TaskStep', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  TaskStep$reflection withObject([TaskStep? obj]) =>
      TaskStep$reflection(obj)..setupInternalsWith(this);

  static TaskStep$reflection? _withoutObjectInstance;
  @override
  TaskStep$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static TaskStep$reflection get staticInstance =>
      _withoutObjectInstance ??= TaskStep$reflection._();

  @override
  TaskStep$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    TaskStep$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  TaskStep? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  TaskStep? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  TaskStep? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<TaskStep>> _constructors = {};

  @override
  ConstructorReflection<TaskStep>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<TaskStep>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<TaskStep>(
          this,
          TaskStep,
          '',
          () => TaskStep.new,
          const <__PR>[__PR(__TR.tString, 'name', false, true)],
          null,
          const <String, __PR>{'id': __PR(__TR.tInt, 'id', true, false)},
          null,
          invoker: (a) =>
              TaskStep(a[0] as String, id: __argOr$<int?>(a[1], null)),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([TaskStep? obj]) => null;

  static const List<String> _fieldsNames = const <String>['id', 'name'];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<TaskStep, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<TaskStep, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<TaskStep, T>? field<T>(String fieldName, [TaskStep? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<TaskStep, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<TaskStep, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<TaskStep, T>;
  }

  FieldReflection<TaskStep, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<TaskStep, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<TaskStep, dynamic>? _fieldImpl(
    String fieldName,
    TaskStep? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<TaskStep, int?>(
          this,
          TaskStep,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'name':
        return FieldReflection<TaskStep, String>(
          this,
          TaskStep,
          __TR.tString,
          'name',
          false,
          (o) =>
              () => o!.name,
          (o) =>
              (v) => o!.name = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    TaskStep? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'name': obj?.name,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<TaskStep, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<TaskStep, R>? method<R>(
    String methodName, [
    TaskStep? obj,
  ]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<TaskStep, R>? staticMethod<R>(String methodName) =>
      null;
}

class Ticket$reflection extends ClassReflection<Ticket> with __ReflectionMixin {
  static final Expando<Ticket$reflection> _objectReflections = Expando();

  factory Ticket$reflection([Ticket? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Ticket$reflection._(object);
  }

  Ticket$reflection._([Ticket? object]) : super(Ticket, r'Ticket', object);

  static bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
      _registerSiblingsReflection();
    }
  }

  @override
  Version get languageVersion => Version.parse('3.13.0');

  @override
  Ticket$reflection withObject([Ticket? obj]) =>
      Ticket$reflection(obj)..setupInternalsWith(this);

  static Ticket$reflection? _withoutObjectInstance;
  @override
  Ticket$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Ticket$reflection get staticInstance =>
      _withoutObjectInstance ??= Ticket$reflection._();

  @override
  Ticket$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Ticket$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Ticket? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => false;
  @override
  Ticket? createInstanceWithEmptyConstructor() => null;
  @override
  bool get hasNoRequiredArgsConstructor => false;
  @override
  Ticket? createInstanceWithNoRequiredArgsConstructor() => null;

  static const List<String> _constructorsNames = const <String>[''];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Ticket>> _constructors = {};

  @override
  ConstructorReflection<Ticket>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Ticket>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Ticket>(
          this,
          Ticket,
          '',
          () => Ticket.new,
          const <__PR>[__PR(__TR.tString, 'titleText', false, true)],
          null,
          const <String, __PR>{'id': __PR(__TR.tInt, 'id', true, false)},
          null,
          invoker: (a) =>
              Ticket(a[0] as String, id: __argOr$<int?>(a[1], null)),
        );
      default:
        return null;
    }
  }

  static const List<Object> _classAnnotations = <Object>[];

  @override
  List<Object> get classAnnotations => _classAnnotations;

  static const List<Type> _supperTypes = const <Type>[];

  @override
  List<Type> get supperTypes => _supperTypes;

  @override
  bool get hasMethodToJson => false;

  @override
  Object? callMethodToJson([Ticket? obj]) => null;

  static const List<String> _fieldsNames = const <String>['id', 'title'];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Ticket, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Ticket, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Ticket, T>? field<T>(String fieldName, [Ticket? obj]) {
    if (obj == null) {
      if (object != null) {
        return _fieldObjectImpl<T>(fieldName);
      } else {
        return _fieldNoObjectImpl<T>(fieldName);
      }
    } else if (identical(obj, object)) {
      return _fieldObjectImpl<T>(fieldName);
    }
    return _fieldNoObjectImpl<T>(fieldName)?.withObject(obj);
  }

  FieldReflection<Ticket, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Ticket, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Ticket, T>;
  }

  FieldReflection<Ticket, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Ticket, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Ticket, dynamic>? _fieldImpl(String fieldName, Ticket? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Ticket, int?>(
          this,
          Ticket,
          __TR.tInt,
          'id',
          true,
          (o) =>
              () => o!.id,
          (o) =>
              (v) => o!.id = v,
          obj,
          false,
        );
      case 'title':
        return FieldReflection<Ticket, String>(
          this,
          Ticket,
          __TR.tString,
          'title',
          false,
          (o) =>
              () => o!.title,
          (o) =>
              (v) => o!.title = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Ticket? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'title': obj?.title,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Ticket, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Ticket, R>? method<R>(String methodName, [Ticket? obj]) =>
      null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Ticket, R>? staticMethod<R>(String methodName) => null;
}

extension Counter$reflectionExtension on Counter {
  /// Returns a [ClassReflection] for type [Counter]. (Generated by [ReflectionFactory])
  ClassReflection<Counter> get reflection => Counter$reflection(this);

  /// Returns a JSON for type [Counter]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Counter]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Counter]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Counter] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Coupon$reflectionExtension on Coupon {
  /// Returns a [ClassReflection] for type [Coupon]. (Generated by [ReflectionFactory])
  ClassReflection<Coupon> get reflection => Coupon$reflection(this);

  /// Returns a JSON for type [Coupon]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Coupon]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Coupon]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Coupon] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Invoice$reflectionExtension on Invoice {
  /// Returns a [ClassReflection] for type [Invoice]. (Generated by [ReflectionFactory])
  ClassReflection<Invoice> get reflection => Invoice$reflection(this);

  /// Returns a JSON for type [Invoice]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Invoice]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Invoice]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Invoice] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Label$reflectionExtension on Label {
  /// Returns a [ClassReflection] for type [Label]. (Generated by [ReflectionFactory])
  ClassReflection<Label> get reflection => Label$reflection(this);

  /// Returns a JSON for type [Label]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Label]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Label]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Label] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Note$reflectionExtension on Note {
  /// Returns a [ClassReflection] for type [Note]. (Generated by [ReflectionFactory])
  ClassReflection<Note> get reflection => Note$reflection(this);

  /// Returns a JSON for type [Note]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Note]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Note]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Note] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Profile$reflectionExtension on Profile {
  /// Returns a [ClassReflection] for type [Profile]. (Generated by [ReflectionFactory])
  ClassReflection<Profile> get reflection => Profile$reflection(this);

  /// Returns a JSON for type [Profile]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Profile]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Profile]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Profile] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Project$reflectionExtension on Project {
  /// Returns a [ClassReflection] for type [Project]. (Generated by [ReflectionFactory])
  ClassReflection<Project> get reflection => Project$reflection(this);

  /// Returns a JSON for type [Project]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Project]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Project]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Project] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Seat$reflectionExtension on Seat {
  /// Returns a [ClassReflection] for type [Seat]. (Generated by [ReflectionFactory])
  ClassReflection<Seat> get reflection => Seat$reflection(this);

  /// Returns a JSON for type [Seat]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Seat]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Seat]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Seat] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Settings$reflectionExtension on Settings {
  /// Returns a [ClassReflection] for type [Settings]. (Generated by [ReflectionFactory])
  ClassReflection<Settings> get reflection => Settings$reflection(this);

  /// Returns a JSON for type [Settings]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Settings]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Settings]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Settings] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Tag$reflectionExtension on Tag {
  /// Returns a [ClassReflection] for type [Tag]. (Generated by [ReflectionFactory])
  ClassReflection<Tag> get reflection => Tag$reflection(this);

  /// Returns a JSON for type [Tag]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Tag]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Tag]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Tag] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Task$reflectionExtension on Task {
  /// Returns a [ClassReflection] for type [Task]. (Generated by [ReflectionFactory])
  ClassReflection<Task> get reflection => Task$reflection(this);

  /// Returns a JSON for type [Task]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Task]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Task]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Task] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension TaskState$reflectionExtension on TaskState {
  /// Returns a [EnumReflection] for type [TaskState]. (Generated by [ReflectionFactory])
  EnumReflection<TaskState> get reflection => TaskState$reflection(this);

  /// Returns the name of the [TaskState] instance. (Generated by [ReflectionFactory])
  String get enumName => TaskState$reflection(this).name()!;

  /// Returns a JSON for type [TaskState]. (Generated by [ReflectionFactory])
  String? toJson() => reflection.toJson();

  /// Returns a JSON [Map] for type [TaskState]. (Generated by [ReflectionFactory])
  Map<String, Object>? toJsonMap() => reflection.toJsonMap();

  /// Returns an encoded JSON [String] for type [TaskState]. (Generated by [ReflectionFactory])
  String toJsonEncoded({bool pretty = false}) =>
      reflection.toJsonEncoded(pretty: pretty);
}

extension TaskStep$reflectionExtension on TaskStep {
  /// Returns a [ClassReflection] for type [TaskStep]. (Generated by [ReflectionFactory])
  ClassReflection<TaskStep> get reflection => TaskStep$reflection(this);

  /// Returns a JSON for type [TaskStep]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [TaskStep]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [TaskStep]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [TaskStep] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Ticket$reflectionExtension on Ticket {
  /// Returns a [ClassReflection] for type [Ticket]. (Generated by [ReflectionFactory])
  ClassReflection<Ticket> get reflection => Ticket$reflection(this);

  /// Returns a JSON for type [Ticket]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Ticket]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Ticket]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Ticket] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
  Counter$reflection(),
  Coupon$reflection(),
  Invoice$reflection(),
  Label$reflection(),
  Note$reflection(),
  Profile$reflection(),
  Project$reflection(),
  Seat$reflection(),
  Settings$reflection(),
  Tag$reflection(),
  Task$reflection(),
  TaskState$reflection(),
  TaskStep$reflection(),
  Ticket$reflection(),
];

List<Reflection>? _siblingsReflectionList;
List<Reflection> _siblingsReflection() => _siblingsReflectionList ??=
    List<Reflection>.unmodifiable(_listSiblingsReflection());

bool _registerSiblingsReflectionCalled = false;
void _registerSiblingsReflection() {
  if (_registerSiblingsReflectionCalled) return;
  _registerSiblingsReflectionCalled = true;
  var length = _listSiblingsReflection().length;
  assert(length > 0);
}

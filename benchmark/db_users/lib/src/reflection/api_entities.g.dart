//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/2.10.1
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

part of '../api_entities.dart';

typedef __TR<T> = TypeReflection<T>;
typedef __TI<T> = TypeInfo<T>;
typedef __PR = ParameterReflection;

mixin __ReflectionMixin {
  static final Version _version = Version.parse('2.10.1');

  Version get reflectionFactoryVersion => _version;

  List<Reflection> siblingsReflection() => _siblingsReflection();
}

Symbol? _getSymbol(String? key) {
  if (key == null) return null;

  switch (key) {
    case r"creationTime":
      return const Symbol(r"creationTime");
    case r"enabled":
      return const Symbol(r"enabled");
    case r"id":
      return const Symbol(r"id");
    default:
      return null;
  }
}

// ignore: non_constant_identifier_names
Address Address$fromJson(Map<String, Object?> map) =>
    Address$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Address Address$fromJsonEncoded(String jsonEncoded) =>
    Address$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
Role Role$fromJson(Map<String, Object?> map) =>
    Role$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
Role Role$fromJsonEncoded(String jsonEncoded) =>
    Role$reflection.staticInstance.fromJsonEncoded(jsonEncoded);
// ignore: non_constant_identifier_names
User User$fromJson(Map<String, Object?> map) =>
    User$reflection.staticInstance.fromJson(map);
// ignore: non_constant_identifier_names
User User$fromJsonEncoded(String jsonEncoded) =>
    User$reflection.staticInstance.fromJsonEncoded(jsonEncoded);

class Address$reflection extends ClassReflection<Address>
    with __ReflectionMixin {
  static final Expando<Address$reflection> _objectReflections = Expando();

  factory Address$reflection([Address? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Address$reflection._(object);
  }

  Address$reflection._([Address? object]) : super(Address, r'Address', object);

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
  Version get languageVersion => Version.parse('3.10.0');

  @override
  Address$reflection withObject([Address? obj]) =>
      Address$reflection(obj)..setupInternalsWith(this);

  static Address$reflection? _withoutObjectInstance;
  @override
  Address$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Address$reflection get staticInstance =>
      _withoutObjectInstance ??= Address$reflection._();

  @override
  Address$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Address$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Address? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Address? createInstanceWithEmptyConstructor() => Address.create();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Address? createInstanceWithNoRequiredArgsConstructor() => Address.create();

  static const List<String> _constructorsNames = const <String>['', 'create'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Address>> _constructors = {};

  @override
  ConstructorReflection<Address>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Address>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Address>(
          this,
          Address,
          '',
          () => Address.new,
          const <__PR>[
            __PR(__TR.tString, 'countryCode', false, true),
            __PR(__TR.tString, 'state', false, true),
            __PR(__TR.tString, 'city', false, true),
            __PR(__TR.tString, 'addressLine1', false, true),
            __PR(__TR.tString, 'zipCode', false, true),
          ],
          null,
          const <String, __PR>{'id': __PR(__TR.tInt, 'id', true, false)},
          null,
        );
      case 'create':
        return ConstructorReflection<Address>(
          this,
          Address,
          'create',
          () => Address.create,
          null,
          null,
          null,
          null,
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
  Object? callMethodToJson([Address? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'addressLine1',
    'city',
    'countryCode',
    'id',
    'state',
    'zipCode',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Address, dynamic>> _fieldsNoObject =
      {};

  final Map<String, FieldReflection<Address, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Address, T>? field<T>(String fieldName, [Address? obj]) {
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

  FieldReflection<Address, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Address, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Address, T>;
  }

  FieldReflection<Address, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Address, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Address, dynamic>? _fieldImpl(
    String fieldName,
    Address? obj,
  ) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Address, int?>(
          this,
          Address,
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
      case 'countrycode':
        return FieldReflection<Address, String>(
          this,
          Address,
          __TR.tString,
          'countryCode',
          false,
          (o) =>
              () => o!.countryCode,
          (o) =>
              (v) => o!.countryCode = v,
          obj,
          false,
          const [EntityField.maximum(3)],
        );
      case 'state':
        return FieldReflection<Address, String>(
          this,
          Address,
          __TR.tString,
          'state',
          false,
          (o) =>
              () => o!.state,
          (o) =>
              (v) => o!.state = v,
          obj,
          false,
        );
      case 'city':
        return FieldReflection<Address, String>(
          this,
          Address,
          __TR.tString,
          'city',
          false,
          (o) =>
              () => o!.city,
          (o) =>
              (v) => o!.city = v,
          obj,
          false,
        );
      case 'addressline1':
        return FieldReflection<Address, String>(
          this,
          Address,
          __TR.tString,
          'addressLine1',
          false,
          (o) =>
              () => o!.addressLine1,
          (o) =>
              (v) => o!.addressLine1 = v,
          obj,
          false,
        );
      case 'zipcode':
        return FieldReflection<Address, String>(
          this,
          Address,
          __TR.tString,
          'zipCode',
          false,
          (o) =>
              () => o!.zipCode,
          (o) =>
              (v) => o!.zipCode = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(
    Address? obj, {
    bool withHashCode = false,
  }) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'countryCode': obj?.countryCode,
      'state': obj?.state,
      'city': obj?.city,
      'addressLine1': obj?.addressLine1,
      'zipCode': obj?.zipCode,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<Address, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Address, R>? method<R>(String methodName, [Address? obj]) =>
      null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Address, R>? staticMethod<R>(String methodName) =>
      null;
}

class Role$reflection extends ClassReflection<Role> with __ReflectionMixin {
  static final Expando<Role$reflection> _objectReflections = Expando();

  factory Role$reflection([Role? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= Role$reflection._(object);
  }

  Role$reflection._([Role? object]) : super(Role, r'Role', object);

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
  Version get languageVersion => Version.parse('3.10.0');

  @override
  Role$reflection withObject([Role? obj]) =>
      Role$reflection(obj)..setupInternalsWith(this);

  static Role$reflection? _withoutObjectInstance;
  @override
  Role$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static Role$reflection get staticInstance =>
      _withoutObjectInstance ??= Role$reflection._();

  @override
  Role$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    Role$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  Role? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Role? createInstanceWithEmptyConstructor() => Role.create();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  Role? createInstanceWithNoRequiredArgsConstructor() => Role.create();

  static const List<String> _constructorsNames = const <String>['', 'create'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<Role>> _constructors = {};

  @override
  ConstructorReflection<Role>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<Role>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Role>(
          this,
          Role,
          '',
          () => Role.new,
          const <__PR>[__PR(__TR.tString, 'name', false, true)],
          null,
          const <String, __PR>{'id': __PR(__TR.tInt, 'id', true, false)},
          null,
        );
      case 'create':
        return ConstructorReflection<Role>(
          this,
          Role,
          'create',
          () => Role.create,
          null,
          null,
          null,
          null,
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
  Object? callMethodToJson([Role? obj]) => null;

  static const List<String> _fieldsNames = const <String>['id', 'name'];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<Role, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<Role, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<Role, T>? field<T>(String fieldName, [Role? obj]) {
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

  FieldReflection<Role, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Role, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<Role, T>;
  }

  FieldReflection<Role, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<Role, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<Role, dynamic>? _fieldImpl(String fieldName, Role? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Role, int?>(
          this,
          Role,
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
        return FieldReflection<Role, String>(
          this,
          Role,
          __TR.tString,
          'name',
          false,
          (o) =>
              () => o!.name,
          (o) =>
              (v) => o!.name = v,
          obj,
          false,
          const [EntityField.unique(), EntityField.maximum(50)],
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(Role? obj, {bool withHashCode = false}) {
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
  StaticFieldReflection<Role, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<Role, R>? method<R>(String methodName, [Role? obj]) => null;
  static const List<String> _staticMethodsNames = const <String>[];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  @override
  StaticMethodReflection<Role, R>? staticMethod<R>(String methodName) => null;
}

class User$reflection extends ClassReflection<User> with __ReflectionMixin {
  static final Expando<User$reflection> _objectReflections = Expando();

  factory User$reflection([User? object]) {
    if (object == null) return staticInstance;
    return _objectReflections[object] ??= User$reflection._(object);
  }

  User$reflection._([User? object]) : super(User, r'User', object);

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
  Version get languageVersion => Version.parse('3.10.0');

  @override
  User$reflection withObject([User? obj]) =>
      User$reflection(obj)..setupInternalsWith(this);

  static User$reflection? _withoutObjectInstance;
  @override
  User$reflection withoutObjectInstance() => staticInstance;

  @override
  Symbol? getSymbol(String? key) => _getSymbol(key);

  static User$reflection get staticInstance =>
      _withoutObjectInstance ??= User$reflection._();

  @override
  User$reflection getStaticInstance() => staticInstance;

  static bool _boot = false;
  static void boot() {
    if (_boot) return;
    _boot = true;
    User$reflection.staticInstance;
  }

  @override
  bool get hasDefaultConstructor => false;
  @override
  User? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  User? createInstanceWithEmptyConstructor() => User.create();
  @override
  bool get hasNoRequiredArgsConstructor => true;
  @override
  User? createInstanceWithNoRequiredArgsConstructor() => User.create();

  static const List<String> _constructorsNames = const <String>['', 'create'];

  @override
  List<String> get constructorsNames => _constructorsNames;

  static final Map<String, ConstructorReflection<User>> _constructors = {};

  @override
  ConstructorReflection<User>? constructor(String constructorName) {
    var c = _constructors[constructorName];
    if (c != null) return c;
    c = _constructorImpl(constructorName);
    if (c == null) return null;
    _constructors[constructorName] = c;
    return c;
  }

  ConstructorReflection<User>? _constructorImpl(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<User>(
          this,
          User,
          '',
          () => User.new,
          const <__PR>[
            __PR(__TR.tString, 'email', false, true),
            __PR(__TR.tString, 'name', false, true),
            __PR(__TR.tString, 'passwordOrHash', false, true),
            __PR(__TR<Address>(Address), 'address', false, true),
            __PR(
              __TR<List<Role>>(List, <__TR>[__TR<Role>(Role)]),
              'roles',
              false,
              true,
            ),
          ],
          null,
          const <String, __PR>{
            'creationTime': __PR(
              __TR<DateTime>(DateTime),
              'creationTime',
              true,
              false,
            ),
            'enabled': __PR(__TR.tBool, 'enabled', false, false, true),
            'id': __PR(__TR.tInt, 'id', true, false),
          },
          null,
        );
      case 'create':
        return ConstructorReflection<User>(
          this,
          User,
          'create',
          () => User.create,
          null,
          null,
          null,
          null,
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
  Object? callMethodToJson([User? obj]) => null;

  static const List<String> _fieldsNames = const <String>[
    'address',
    'creationTime',
    'email',
    'enabled',
    'id',
    'name',
    'passwordHash',
    'roles',
  ];

  @override
  List<String> get fieldsNames => _fieldsNames;

  static final Map<String, FieldReflection<User, dynamic>> _fieldsNoObject = {};

  final Map<String, FieldReflection<User, dynamic>> _fieldsObject = {};

  @override
  FieldReflection<User, T>? field<T>(String fieldName, [User? obj]) {
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

  FieldReflection<User, T>? _fieldNoObjectImpl<T>(String fieldName) {
    final f = _fieldsNoObject[fieldName];
    if (f != null) {
      return f as FieldReflection<User, T>;
    }
    final f2 = _fieldImpl(fieldName, null);
    if (f2 == null) return null;
    _fieldsNoObject[fieldName] = f2;
    return f2 as FieldReflection<User, T>;
  }

  FieldReflection<User, T>? _fieldObjectImpl<T>(String fieldName) {
    final f = _fieldsObject[fieldName];
    if (f != null) {
      return f as FieldReflection<User, T>;
    }
    var f2 = _fieldNoObjectImpl<T>(fieldName);
    if (f2 == null) return null;
    f2 = f2.withObject(object!);
    _fieldsObject[fieldName] = f2;
    return f2;
  }

  FieldReflection<User, dynamic>? _fieldImpl(String fieldName, User? obj) {
    obj ??= object;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<User, int?>(
          this,
          User,
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
      case 'email':
        return FieldReflection<User, String>(
          this,
          User,
          __TR.tString,
          'email',
          false,
          (o) =>
              () => o!.email,
          (o) =>
              (v) => o!.email = v,
          obj,
          false,
          const [EntityField.unique(), EntityField.maximum(200)],
        );
      case 'name':
        return FieldReflection<User, String>(
          this,
          User,
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
      case 'passwordhash':
        return FieldReflection<User, String>(
          this,
          User,
          __TR.tString,
          'passwordHash',
          false,
          (o) =>
              () => o!.passwordHash,
          (o) =>
              (v) => o!.passwordHash = v,
          obj,
          false,
          const [EntityField.maximum(64)],
        );
      case 'enabled':
        return FieldReflection<User, bool>(
          this,
          User,
          __TR.tBool,
          'enabled',
          false,
          (o) =>
              () => o!.enabled,
          (o) =>
              (v) => o!.enabled = v,
          obj,
          false,
        );
      case 'creationtime':
        return FieldReflection<User, DateTime>(
          this,
          User,
          const __TR<DateTime>(DateTime),
          'creationTime',
          false,
          (o) =>
              () => o!.creationTime,
          (o) =>
              (v) => o!.creationTime = v,
          obj,
          false,
        );
      case 'address':
        return FieldReflection<User, Address>(
          this,
          User,
          const __TR<Address>(Address),
          'address',
          false,
          (o) =>
              () => o!.address,
          (o) =>
              (v) => o!.address = v,
          obj,
          false,
        );
      case 'roles':
        return FieldReflection<User, List<Role>>(
          this,
          User,
          const __TR<List<Role>>(List, <__TR>[__TR<Role>(Role)]),
          'roles',
          false,
          (o) =>
              () => o!.roles,
          (o) =>
              (v) => o!.roles = v,
          obj,
          false,
        );
      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> getFieldsValues(User? obj, {bool withHashCode = false}) {
    obj ??= object;
    return <String, dynamic>{
      'id': obj?.id,
      'email': obj?.email,
      'name': obj?.name,
      'passwordHash': obj?.passwordHash,
      'enabled': obj?.enabled,
      'creationTime': obj?.creationTime,
      'address': obj?.address,
      'roles': obj?.roles,
      if (withHashCode) 'hashCode': obj?.hashCode,
    };
  }

  static const List<String> _staticFieldsNames = const <String>[];

  @override
  List<String> get staticFieldsNames => _staticFieldsNames;

  @override
  StaticFieldReflection<User, T>? staticField<T>(String fieldName) => null;

  static const List<String> _methodsNames = const <String>[];

  @override
  List<String> get methodsNames => _methodsNames;

  @override
  MethodReflection<User, R>? method<R>(String methodName, [User? obj]) => null;
  static const List<String> _staticMethodsNames = const <String>[
    'hashPassword',
  ];

  @override
  List<String> get staticMethodsNames => _staticMethodsNames;

  static final Map<String, StaticMethodReflection<User, dynamic>>
  _staticMethods = {};

  @override
  StaticMethodReflection<User, R>? staticMethod<R>(String methodName) {
    var m = _staticMethods[methodName];
    if (m != null) {
      return m as StaticMethodReflection<User, R>;
    }
    m = _staticMethodImpl(methodName);
    if (m == null) return null;
    _staticMethods[methodName] = m;
    return m as StaticMethodReflection<User, R>;
  }

  StaticMethodReflection<User, dynamic>? _staticMethodImpl(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'hashpassword':
        return StaticMethodReflection<User, String>(
          this,
          User,
          'hashPassword',
          __TR.tString,
          false,
          () => User.hashPassword,
          const <__PR>[__PR(__TR.tString, 'passwordOrHash', false, true)],
          null,
          null,
          null,
        );
      default:
        return null;
    }
  }
}

extension Address$reflectionExtension on Address {
  /// Returns a [ClassReflection] for type [Address]. (Generated by [ReflectionFactory])
  ClassReflection<Address> get reflection => Address$reflection(this);

  /// Returns a JSON for type [Address]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Address]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Address]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Address] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension Role$reflectionExtension on Role {
  /// Returns a [ClassReflection] for type [Role]. (Generated by [ReflectionFactory])
  ClassReflection<Role> get reflection => Role$reflection(this);

  /// Returns a JSON for type [Role]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [Role]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [Role]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [Role] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

extension User$reflectionExtension on User {
  /// Returns a [ClassReflection] for type [User]. (Generated by [ReflectionFactory])
  ClassReflection<User> get reflection => User$reflection(this);

  /// Returns a JSON for type [User]. (Generated by [ReflectionFactory])
  Object? toJson({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJson(null, null, duplicatedEntitiesAsID);

  /// Returns a JSON [Map] for type [User]. (Generated by [ReflectionFactory])
  Map<String, dynamic>? toJsonMap({bool duplicatedEntitiesAsID = false}) =>
      reflection.toJsonMap(duplicatedEntitiesAsID: duplicatedEntitiesAsID);

  /// Returns an encoded JSON [String] for type [User]. (Generated by [ReflectionFactory])
  String toJsonEncoded({
    bool pretty = false,
    bool duplicatedEntitiesAsID = false,
  }) => reflection.toJsonEncoded(
    pretty: pretty,
    duplicatedEntitiesAsID: duplicatedEntitiesAsID,
  );

  /// Returns a JSON for type [User] using the class fields. (Generated by [ReflectionFactory])
  Object? toJsonFromFields({bool duplicatedEntitiesAsID = false}) => reflection
      .toJsonFromFields(duplicatedEntitiesAsID: duplicatedEntitiesAsID);
}

List<Reflection> _listSiblingsReflection() => <Reflection>[
  Address$reflection(),
  Role$reflection(),
  User$reflection(),
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

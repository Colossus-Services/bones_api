//
// GENERATED CODE - DO NOT MODIFY BY HAND!
// BUILDER: reflection_factory/1.0.11
// BUILD COMMAND: dart run build_runner build
//

part of 'bones_api_test_entities.dart';

class Address$reflection extends ClassReflection<Address> {
  Address$reflection([Address? object]) : super(Address, object);

  bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
    }
  }

  @override
  Version get languageVersion => Version.parse('2.13.0');

  @override
  Address$reflection withObject([Address? obj]) => Address$reflection(obj);

  @override
  bool get hasDefaultConstructor => false;
  @override
  Address? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Address? createInstanceWithEmptyConstructor() => Address.empty();

  @override
  List<String> get constructorsNames => const <String>['', 'empty', 'fromMap'];

  @override
  ConstructorReflection<Address>? constructor<R>(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Address>(
            this,
            '',
            () => (String state, String city, String street, int number,
                    {int? id}) =>
                Address(state, city, street, number, id: id),
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'state', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tString, 'city', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tString, 'street', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tInt, 'number', false, true, null, null)
            ],
            null,
            const <String, ParameterReflection>{
              'id': ParameterReflection(
                  TypeReflection.tInt, 'id', true, false, null, null)
            },
            null);
      case 'empty':
        return ConstructorReflection<Address>(
            this, 'empty', () => () => Address.empty(), null, null, null, null);
      case 'frommap':
        return ConstructorReflection<Address>(
            this,
            'fromMap',
            () => (Map<String, dynamic> map) => Address.fromMap(map),
            const <ParameterReflection>[
              ParameterReflection(TypeReflection.tMapStringDynamic, 'map',
                  false, true, null, null)
            ],
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<String> get fieldsNames => const <String>[
        'city',
        'fieldsNames',
        'hashCode',
        'id',
        'idFieldName',
        'number',
        'state',
        'street'
      ];

  @override
  FieldReflection<Address, T>? field<T>(String fieldName, [Address? obj]) {
    obj ??= object!;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Address, T>(
          this,
          TypeReflection.tInt,
          'id',
          true,
          (o) => () => o!.id as T,
          (o) => (T? v) => o!.id = v as int?,
          obj,
          false,
          false,
          null,
        );
      case 'state':
        return FieldReflection<Address, T>(
          this,
          TypeReflection.tString,
          'state',
          false,
          (o) => () => o!.state as T,
          (o) => (T? v) => o!.state = v as String,
          obj,
          false,
          false,
          null,
        );
      case 'city':
        return FieldReflection<Address, T>(
          this,
          TypeReflection.tString,
          'city',
          false,
          (o) => () => o!.city as T,
          (o) => (T? v) => o!.city = v as String,
          obj,
          false,
          false,
          null,
        );
      case 'street':
        return FieldReflection<Address, T>(
          this,
          TypeReflection.tString,
          'street',
          false,
          (o) => () => o!.street as T,
          (o) => (T? v) => o!.street = v as String,
          obj,
          false,
          false,
          null,
        );
      case 'number':
        return FieldReflection<Address, T>(
          this,
          TypeReflection.tInt,
          'number',
          false,
          (o) => () => o!.number as T,
          (o) => (T? v) => o!.number = v as int,
          obj,
          false,
          false,
          null,
        );
      case 'hashcode':
        return FieldReflection<Address, T>(
          this,
          TypeReflection.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'idfieldname':
        return FieldReflection<Address, T>(
          this,
          TypeReflection.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'fieldsnames':
        return FieldReflection<Address, T>(
          this,
          TypeReflection.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames as T,
          null,
          obj,
          false,
          false,
          null,
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<Address, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames =>
      const <String>['getField', 'getFieldType', 'setField', 'toJson'];

  @override
  MethodReflection<Address, R>? method<R>(String methodName, [Address? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Address, R>(
            this,
            'getField',
            TypeReflection.tObject,
            true,
            (o) => o!.getField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldtype':
        return MethodReflection<Address, R>(
            this,
            'getFieldType',
            TypeReflection(TypeInfo),
            true,
            (o) => o!.getFieldType,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'setfield':
        return MethodReflection<Address, R>(
            this,
            'setField',
            null,
            false,
            (o) => o!.setField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tObject, 'value', true, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'tojson':
        return MethodReflection<Address, R>(
            this,
            'toJson',
            TypeReflection.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      default:
        return null;
    }
  }

  @override
  List<String> get staticMethodsNames => const <String>[];

  @override
  MethodReflection<Address, R>? staticMethod<R>(String methodName) {
    return null;
  }
}

class Role$reflection extends ClassReflection<Role> {
  Role$reflection([Role? object]) : super(Role, object);

  bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
    }
  }

  @override
  Version get languageVersion => Version.parse('2.13.0');

  @override
  Role$reflection withObject([Role? obj]) => Role$reflection(obj);

  @override
  bool get hasDefaultConstructor => false;
  @override
  Role? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  Role? createInstanceWithEmptyConstructor() => Role.empty();

  @override
  List<String> get constructorsNames => const <String>['', 'empty', 'fromMap'];

  @override
  ConstructorReflection<Role>? constructor<R>(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<Role>(
            this,
            '',
            () => (String type, {int? id, bool enabled = true}) =>
                Role(type, id: id, enabled: enabled),
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'type', false, true, null, null)
            ],
            null,
            const <String, ParameterReflection>{
              'enabled': ParameterReflection(
                  TypeReflection.tBool, 'enabled', false, false, true, null),
              'id': ParameterReflection(
                  TypeReflection.tInt, 'id', true, false, null, null)
            },
            null);
      case 'empty':
        return ConstructorReflection<Role>(
            this, 'empty', () => () => Role.empty(), null, null, null, null);
      case 'frommap':
        return ConstructorReflection<Role>(
            this,
            'fromMap',
            () => (Map<String, dynamic> map) => Role.fromMap(map),
            const <ParameterReflection>[
              ParameterReflection(TypeReflection.tMapStringDynamic, 'map',
                  false, true, null, null)
            ],
            null,
            null,
            null);
      default:
        return null;
    }
  }

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<String> get fieldsNames => const <String>[
        'enabled',
        'fieldsNames',
        'hashCode',
        'id',
        'idFieldName',
        'type'
      ];

  @override
  FieldReflection<Role, T>? field<T>(String fieldName, [Role? obj]) {
    obj ??= object!;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<Role, T>(
          this,
          TypeReflection.tInt,
          'id',
          true,
          (o) => () => o!.id as T,
          (o) => (T? v) => o!.id = v as int?,
          obj,
          false,
          false,
          null,
        );
      case 'type':
        return FieldReflection<Role, T>(
          this,
          TypeReflection.tString,
          'type',
          false,
          (o) => () => o!.type as T,
          (o) => (T? v) => o!.type = v as String,
          obj,
          false,
          false,
          null,
        );
      case 'enabled':
        return FieldReflection<Role, T>(
          this,
          TypeReflection.tBool,
          'enabled',
          false,
          (o) => () => o!.enabled as T,
          (o) => (T? v) => o!.enabled = v as bool,
          obj,
          false,
          false,
          null,
        );
      case 'hashcode':
        return FieldReflection<Role, T>(
          this,
          TypeReflection.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'idfieldname':
        return FieldReflection<Role, T>(
          this,
          TypeReflection.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'fieldsnames':
        return FieldReflection<Role, T>(
          this,
          TypeReflection.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames as T,
          null,
          obj,
          false,
          false,
          null,
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<Role, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames =>
      const <String>['getField', 'getFieldType', 'setField', 'toJson'];

  @override
  MethodReflection<Role, R>? method<R>(String methodName, [Role? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<Role, R>(
            this,
            'getField',
            TypeReflection.tObject,
            true,
            (o) => o!.getField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldtype':
        return MethodReflection<Role, R>(
            this,
            'getFieldType',
            TypeReflection(TypeInfo),
            true,
            (o) => o!.getFieldType,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'setfield':
        return MethodReflection<Role, R>(
            this,
            'setField',
            null,
            false,
            (o) => o!.setField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tObject, 'value', true, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'tojson':
        return MethodReflection<Role, R>(
            this,
            'toJson',
            TypeReflection.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      default:
        return null;
    }
  }

  @override
  List<String> get staticMethodsNames => const <String>[];

  @override
  MethodReflection<Role, R>? staticMethod<R>(String methodName) {
    return null;
  }
}

class User$reflection extends ClassReflection<User> {
  User$reflection([User? object]) : super(User, object);

  bool _registered = false;
  @override
  void register() {
    if (!_registered) {
      _registered = true;
      super.register();
    }
  }

  @override
  Version get languageVersion => Version.parse('2.13.0');

  @override
  User$reflection withObject([User? obj]) => User$reflection(obj);

  @override
  bool get hasDefaultConstructor => false;
  @override
  User? createInstanceWithDefaultConstructor() => null;

  @override
  bool get hasEmptyConstructor => true;
  @override
  User? createInstanceWithEmptyConstructor() => User.empty();

  @override
  List<String> get constructorsNames => const <String>['', 'empty'];

  @override
  ConstructorReflection<User>? constructor<R>(String constructorName) {
    var lc = constructorName.trim().toLowerCase();

    switch (lc) {
      case '':
        return ConstructorReflection<User>(
            this,
            '',
            () => (String email, String password, Address address,
                    List<Role> roles, {int? id, DateTime? creationTime}) =>
                User(email, password, address, roles,
                    id: id, creationTime: creationTime),
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'email', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tString, 'password', false, true, null, null),
              ParameterReflection(
                  TypeReflection(Address), 'address', false, true, null, null),
              ParameterReflection(TypeReflection(List, [Role]), 'roles', false,
                  true, null, null)
            ],
            null,
            const <String, ParameterReflection>{
              'creationTime': ParameterReflection(TypeReflection(DateTime),
                  'creationTime', true, false, null, null),
              'id': ParameterReflection(
                  TypeReflection.tInt, 'id', true, false, null, null)
            },
            null);
      case 'empty':
        return ConstructorReflection<User>(
            this, 'empty', () => () => User.empty(), null, null, null, null);
      default:
        return null;
    }
  }

  @override
  List<Object> get classAnnotations => List<Object>.unmodifiable(<Object>[]);

  @override
  List<String> get fieldsNames => const <String>[
        'address',
        'creationTime',
        'email',
        'fieldsNames',
        'hashCode',
        'id',
        'idFieldName',
        'password',
        'roles'
      ];

  @override
  FieldReflection<User, T>? field<T>(String fieldName, [User? obj]) {
    obj ??= object!;

    var lc = fieldName.trim().toLowerCase();

    switch (lc) {
      case 'id':
        return FieldReflection<User, T>(
          this,
          TypeReflection.tInt,
          'id',
          true,
          (o) => () => o!.id as T,
          (o) => (T? v) => o!.id = v as int?,
          obj,
          false,
          false,
          null,
        );
      case 'email':
        return FieldReflection<User, T>(
          this,
          TypeReflection.tString,
          'email',
          false,
          (o) => () => o!.email as T,
          (o) => (T? v) => o!.email = v as String,
          obj,
          false,
          false,
          null,
        );
      case 'password':
        return FieldReflection<User, T>(
          this,
          TypeReflection.tString,
          'password',
          false,
          (o) => () => o!.password as T,
          (o) => (T? v) => o!.password = v as String,
          obj,
          false,
          false,
          null,
        );
      case 'address':
        return FieldReflection<User, T>(
          this,
          TypeReflection(Address),
          'address',
          false,
          (o) => () => o!.address as T,
          (o) => (T? v) => o!.address = v as Address,
          obj,
          false,
          false,
          null,
        );
      case 'roles':
        return FieldReflection<User, T>(
          this,
          TypeReflection(List, [Role]),
          'roles',
          false,
          (o) => () => o!.roles as T,
          (o) => (T? v) => o!.roles = v as List<Role>,
          obj,
          false,
          false,
          null,
        );
      case 'creationtime':
        return FieldReflection<User, T>(
          this,
          TypeReflection(DateTime),
          'creationTime',
          false,
          (o) => () => o!.creationTime as T,
          (o) => (T? v) => o!.creationTime = v as DateTime,
          obj,
          false,
          false,
          null,
        );
      case 'hashcode':
        return FieldReflection<User, T>(
          this,
          TypeReflection.tInt,
          'hashCode',
          false,
          (o) => () => o!.hashCode as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'idfieldname':
        return FieldReflection<User, T>(
          this,
          TypeReflection.tString,
          'idFieldName',
          false,
          (o) => () => o!.idFieldName as T,
          null,
          obj,
          false,
          false,
          null,
        );
      case 'fieldsnames':
        return FieldReflection<User, T>(
          this,
          TypeReflection.tListString,
          'fieldsNames',
          false,
          (o) => () => o!.fieldsNames as T,
          null,
          obj,
          false,
          false,
          null,
        );
      default:
        return null;
    }
  }

  @override
  List<String> get staticFieldsNames => const <String>[];

  @override
  FieldReflection<User, T>? staticField<T>(String fieldName) {
    return null;
  }

  @override
  List<String> get methodsNames =>
      const <String>['getField', 'getFieldType', 'setField', 'toJson'];

  @override
  MethodReflection<User, R>? method<R>(String methodName, [User? obj]) {
    obj ??= object;

    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'getfield':
        return MethodReflection<User, R>(
            this,
            'getField',
            TypeReflection.tObject,
            true,
            (o) => o!.getField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'getfieldtype':
        return MethodReflection<User, R>(
            this,
            'getFieldType',
            TypeReflection(TypeInfo),
            true,
            (o) => o!.getFieldType,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'setfield':
        return MethodReflection<User, R>(
            this,
            'setField',
            null,
            false,
            (o) => o!.setField,
            obj,
            false,
            const <ParameterReflection>[
              ParameterReflection(
                  TypeReflection.tString, 'key', false, true, null, null),
              ParameterReflection(
                  TypeReflection.tObject, 'value', true, true, null, null)
            ],
            null,
            null,
            [override]);
      case 'tojson':
        return MethodReflection<User, R>(
            this,
            'toJson',
            TypeReflection.tMapStringDynamic,
            false,
            (o) => o!.toJson,
            obj,
            false,
            null,
            null,
            null,
            [override]);
      default:
        return null;
    }
  }

  @override
  List<String> get staticMethodsNames => const <String>['fromMap'];

  @override
  MethodReflection<User, R>? staticMethod<R>(String methodName) {
    var lc = methodName.trim().toLowerCase();

    switch (lc) {
      case 'frommap':
        return MethodReflection<User, R>(
            this,
            'fromMap',
            TypeReflection(FutureOr, [User]),
            false,
            (o) => User.fromMap,
            null,
            true,
            const <ParameterReflection>[
              ParameterReflection(TypeReflection.tMapStringDynamic, 'map',
                  false, true, null, null)
            ],
            null,
            null,
            null);
      default:
        return null;
    }
  }
}

extension Address$reflectionExtension on Address {
  /// Returns a [ClassReflection] for type [Address]. (Generated by [ReflectionFactory])
  ClassReflection<Address> get reflection => Address$reflection(this);

  /// Returns an encoded JSON [String] for type [Address]. (Generated by [ReflectionFactory])
  String toJsonEncoded() => reflection.toJsonEncoded();
}

extension Role$reflectionExtension on Role {
  /// Returns a [ClassReflection] for type [Role]. (Generated by [ReflectionFactory])
  ClassReflection<Role> get reflection => Role$reflection(this);

  /// Returns an encoded JSON [String] for type [Role]. (Generated by [ReflectionFactory])
  String toJsonEncoded() => reflection.toJsonEncoded();
}

extension User$reflectionExtension on User {
  /// Returns a [ClassReflection] for type [User]. (Generated by [ReflectionFactory])
  ClassReflection<User> get reflection => User$reflection(this);

  /// Returns an encoded JSON [String] for type [User]. (Generated by [ReflectionFactory])
  String toJsonEncoded() => reflection.toJsonEncoded();
}

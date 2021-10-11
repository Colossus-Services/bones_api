import 'dart:async';

import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api.dart';
import 'package:reflection_factory/reflection_factory.dart';

part 'bones_api_test_entities.reflection.g.dart';

final addressEntityHandler = GenericEntityHandler<Address>(
    instantiatorFromMap: (m) => Address.fromMap(m));

final roleEntityHandler =
    GenericEntityHandler<Role>(instantiatorFromMap: (m) => Role.fromMap(m));

final userEntityHandler =
    GenericEntityHandler<User>(instantiatorFromMap: (m) => User.fromMap(m));

class AddressAPIRepository extends APIRepository<Address> {
  AddressAPIRepository(EntityRepositoryProvider provider)
      : super(provider: provider);

  FutureOr<Iterable<Address>> selectByState(String state) {
    return selectByQuery(' state == ? ', parameters: {'state': state});
  }
}

class RoleAPIRepository extends APIRepository<Role> {
  RoleAPIRepository(EntityRepositoryProvider provider)
      : super(provider: provider);
}

class UserAPIRepository extends APIRepository<User> {
  UserAPIRepository(EntityRepositoryProvider provider)
      : super(provider: provider);

  FutureOr<Iterable<User>> selectByEmail(String email) {
    return selectByQuery(' email == ? ', parameters: {'email': email});
  }

  FutureOr<Iterable<User>> selectByAddressState(String state) {
    return selectByQuery(' address.state == ? ', parameters: [state]);
  }

  FutureOr<Iterable<User>> selectByRoleType(String type) {
    return selectByQuery(' roles.type == ? ', parameters: [type]);
  }

  FutureOr<Iterable<User>> selectByRole(Role role) {
    return selectByQuery(' roles == ? ', parameters: [role]);
  }
}

@EnableReflection()
class User extends Entity {
  int? id;

  String email;

  String password;

  Address address;

  List<Role> roles;

  DateTime creationTime;

  User(this.email, this.password, this.address, this.roles,
      {this.id, DateTime? creationTime})
      : creationTime = creationTime ?? DateTime.now();

  User.empty() : this('', '', Address.empty(), <Role>[]);

  static FutureOr<User> fromMap(Map<String, dynamic> map) => User(
      map.getAsString('email')!,
      map.getAsString('password')!,
      map.get<Address>('address')!,
      map.getAsList<Role>('roles', def: [])!,
      id: map['id'],
      creationTime: map['creationTime']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const <String>[
        'id',
        'email',
        'password',
        'address',
        'roles',
        'creationTime'
      ];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'email':
        return email as V?;
      case 'password':
        return password as V?;
      case 'address':
        return address as V?;
      case 'roles':
        return roles as V?;
      case 'creationTime':
        return creationTime as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tInt;
      case 'email':
        return TypeInfo.tString;
      case 'password':
        return TypeInfo.tString;
      case 'address':
        return TypeInfo(Address);
      case 'roles':
        return TypeInfo(List, [Role]);
      case 'creationTime':
        return TypeInfo(DateTime);
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        {
          id = value as int?;
          break;
        }
      case 'email':
        {
          email = value as String;
          break;
        }
      case 'password':
        {
          password = value as String;
          break;
        }
      case 'address':
        {
          address = value as Address;
          break;
        }
      case 'roles':
        {
          roles = value as List<Role>;
          break;
        }
      case 'creationTime':
        {
          creationTime = value as DateTime;
          break;
        }
      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'email': email,
        'password': password,
        'address': address.toJson(),
        'roles': roles.map((e) => e.toJson()).toList(),
        'creationTime': creationTime.millisecondsSinceEpoch,
      };
}

@EnableReflection()
class Address extends Entity {
  int? id;

  String state;

  String city;

  String street;

  int number;

  Address(
    this.state,
    this.city,
    this.street,
    this.number, {
    this.id,
  });

  Address.empty() : this('', '', '', 0);

  Address.fromMap(Map<String, dynamic> map)
      : this(map.getAsString('state')!, map.getAsString('city')!,
            map.getAsString('street')!, map.getAsInt('number')!,
            id: map.getAsInt('id'));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Address &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          state == other.state &&
          city == other.city &&
          street == other.street &&
          number == other.number;

  @override
  int get hashCode =>
      id.hashCode ^
      state.hashCode ^
      city.hashCode ^
      street.hashCode ^
      number.hashCode;

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames =>
      const <String>['id', 'state', 'city', 'street', 'number'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'state':
        return state as V?;
      case 'city':
        return city as V?;
      case 'street':
        return street as V?;
      case 'number':
        return number as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tInt;
      case 'state':
        return TypeInfo.tString;
      case 'city':
        return TypeInfo.tString;
      case 'street':
        return TypeInfo.tString;
      case 'number':
        return TypeInfo.tInt;
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        {
          id = value as int?;
          break;
        }
      case 'state':
        {
          state = value as String;
          break;
        }
      case 'city':
        {
          city = value as String;
          break;
        }
      case 'street':
        {
          street = value as String;
          break;
        }
      case 'number':
        {
          number = int.parse('$value');
          break;
        }
      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'state': state,
        'city': city,
        'street': street,
        'number': number,
      };
}

@EnableReflection()
class Role extends Entity {
  int? id;

  String type;

  bool enabled;

  Role(this.type, {this.id, this.enabled = true});

  Role.empty() : this('');

  Role.fromMap(Map<String, dynamic> map)
      : this(map.getAsString('type')!,
            enabled: map.getAsBool('enabled', false)!, id: map.getAsInt('id'));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Role &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          enabled == other.enabled;

  @override
  int get hashCode => id.hashCode ^ type.hashCode ^ enabled.hashCode;

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => const <String>['id', 'type', 'enabled'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'type':
        return type as V?;
      case 'enabled':
        return enabled as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tInt;
      case 'type':
        return TypeInfo.tString;
      case 'enabled':
        return TypeInfo.tBool;
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        {
          id = value as int?;
          break;
        }
      case 'type':
        {
          type = value as String;
          break;
        }
      case 'enabled':
        {
          enabled = value as bool;
          break;
        }
      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'type': type,
        'enabled': enabled,
      };
}

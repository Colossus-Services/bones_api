import 'package:bones_api/bones_api.dart';
import 'package:statistics/statistics.dart';

part 'bones_api_test_entities.reflection.g.dart';

final storeEntityHandler =
    GenericEntityHandler<Store>(instantiatorFromMap: (m) => Store.fromMap(m));

final addressEntityHandler = GenericEntityHandler<Address>(
    instantiatorFromMap: (m) => Address.fromMap(m));

final roleEntityHandler =
    GenericEntityHandler<Role>(instantiatorFromMap: (m) => Role.fromMap(m));

final userEntityHandler =
    GenericEntityHandler<User>(instantiatorFromMap: (m) => User.fromMap(m));

class StoreAPIRepository extends APIRepository<Store> {
  StoreAPIRepository(EntityRepositoryProvider provider)
      : super(provider: provider);
}

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

  FutureOr<User?> selectByEmail(String email) {
    return selectFirstByQuery(' email == ? ', parameters: {'email': email});
  }

  FutureOr<Iterable<User>> selectByAddress(Address address) {
    return selectByQuery(' address == ? ', parameters: [address]);
  }

  FutureOr<Iterable<User>> selectByAddressID(int addressId) {
    return selectByQuery(' address == ? ', parameters: [addressId]);
  }

  FutureOr<Iterable<User>> selectByAddressState(String state) {
    return selectByQuery(' address.state == ? ', parameters: [state]);
  }

  FutureOr<Iterable<User>> selectByINAddressStates(List<String> states) {
    return selectByQuery(' address.state =~ ? ',
        namedParameters: {'state': states});
  }

  FutureOr<Iterable<User>> selectByINAddressStatesSingleValue(String state) {
    return selectByQuery(' address.state =~ ? ',
        namedParameters: {'state': state});
  }

  FutureOr<Iterable<User>> selectByRoleType(String type) {
    return selectByQuery(' roles.type == ? ', parameters: [type]);
  }

  FutureOr<Iterable<User>> selectByRole(Role role) {
    return selectByQuery(' roles =~ ? ', parameters: [role]);
  }

  FutureOr<Iterable<User>> selectByRoleId(int roleId) {
    return selectByQuery(' roles =~ ? ', parameters: [roleId]);
  }
}

@EnableReflection()
class User extends Entity {
  int? id;

  @EntityField.unique()
  @EntityField.maximum(100)
  @EntityField.regexp(r'[\w-.]+@\w+(?:\.\w+)*')
  String email;

  String password;

  Address address;

  List<Role> roles;

  int? level;

  Time? wakeUpTime;

  DateTime creationTime;

  User(this.email, this.password, this.address, this.roles,
      {this.id, this.level, this.wakeUpTime, DateTime? creationTime})
      : creationTime = creationTime ?? DateTime.now();

  User.empty() : this('', '', Address.empty(), <Role>[]);

  static FutureOr<User> fromMap(Map<String, dynamic> map) => User(
      map.getAsString('email')!,
      map.getAsString('password')!,
      map.getAs<Address>('address')!,
      map.getAsList<Role>('roles', def: <Role>[])!,
      id: map['id'],
      level: map['level'],
      wakeUpTime: map['wakeUpTime'],
      creationTime: map['creationTime']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String get idFieldName => 'id';

  @JsonField.hidden()
  @override
  List<String> get fieldsNames => const <String>[
        'id',
        'email',
        'password',
        'address',
        'roles',
        'level',
        'wakeUpTime',
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
      case 'level':
        return level as V?;
      case 'wakeUpTime':
        return wakeUpTime as V?;
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
      case 'level':
        return TypeInfo.tInt;
      case 'wakeUpTime':
        return TypeInfo(Time);
      case 'creationTime':
        return TypeInfo(DateTime);
      default:
        return null;
    }
  }

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) {
    switch (key) {
      case 'email':
        return [
          EntityField.unique(),
          EntityField.maximum(100),
          EntityField.regexp(r'[\w-.]+@\w+(?:\.\w+)*'),
        ];
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
      case 'level':
        {
          level = value as int?;
          break;
        }
      case 'wakeUpTime':
        {
          wakeUpTime = value as Time?;
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
        'level': level,
        'wakeUpTime': wakeUpTime,
        'creationTime': creationTime.millisecondsSinceEpoch,
      };
}

@EnableReflection()
class Store extends Entity {
  int? id;

  @EntityField.maximum(100)
  String name;

  int? number;

  Store(this.name, this.number, {this.id});

  Store.empty() : this('', 0);

  static FutureOr<Store> fromMap(Map<String, dynamic> map) =>
      Store(map.getAsString('name')!, map.getAsInt('number')!, id: map['id']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String get idFieldName => 'id';

  @JsonField.hidden()
  @override
  List<String> get fieldsNames => const <String>['id', 'name', 'number'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'name':
        return name as V?;
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
      case 'name':
        return TypeInfo.tString;
      case 'number':
        return TypeInfo.tInt;
      default:
        return null;
    }
  }

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) {
    switch (key) {
      case 'name':
        return [
          EntityField.maximum(100),
        ];
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
      case 'name':
        {
          name = value as String;
          break;
        }

      case 'number':
        {
          number = value as int?;
          break;
        }

      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'number': number,
      };
}

@EnableReflection()
class Address extends Entity {
  int? id;

  @EntityField.maximum(3)
  String state;

  @EntityField.maximum(100)
  String city;

  @EntityField.maximum(200)
  String street;

  int number;

  List<Store> stores;
  List<Store> closedStores;

  Address(this.state, this.city, this.street, this.number,
      {this.id, List<Store>? stores, List<Store>? closedStores})
      : stores = stores ?? <Store>[],
        closedStores = closedStores ?? <Store>[];

  Address.empty() : this('', '', '', 0);

  Address.fromMap(Map<String, dynamic> map)
      : this(map.getAsString('state')!, map.getAsString('city')!,
            map.getAsString('street')!, map.getAsInt('number')!,
            stores: map.getAsList<Store>('stores', def: <Store>[])!,
            closedStores: map.getAsList<Store>('closedStores', def: <Store>[])!,
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

  @JsonField.hidden()
  @override
  List<String> get fieldsNames => const <String>[
        'id',
        'state',
        'city',
        'street',
        'number',
        'stores',
        'closedStores'
      ];

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
      case 'stores':
        return stores as V?;
      case 'closedStores':
        return closedStores as V?;
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
      case 'stores':
        return TypeInfo(List, [Store]);
      case 'closedStores':
        return TypeInfo(List, [Store]);
      default:
        return null;
    }
  }

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) {
    switch (key) {
      case 'state':
        return [EntityField.maximum(3)];
      case 'city':
        return [EntityField.maximum(100)];
      case 'street':
        return [EntityField.maximum(100)];

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
      case 'stores':
        {
          stores = value as List<Store>;
          break;
        }
      case 'closedStores':
        {
          closedStores = value as List<Store>;
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
        'stores': stores.map((e) => e.toJson()).toList(),
        'closedStores': closedStores.map((e) => e.toJson()).toList(),
      };
}

@EnableReflection()
enum RoleType {
  admin,
  guest,
  unknown,
}

@EnableReflection()
class Role extends Entity {
  int? id;

  RoleType type;

  bool enabled;

  Decimal? value;

  Role(this.type, {this.id, this.enabled = true, this.value});

  Role.empty() : this(RoleType.unknown);

  Role.fromMap(Map<String, dynamic> map)
      : this(RoleType$from(map.get('type')) ?? RoleType.unknown,
            enabled: map.getAsBool('enabled', defaultValue: false)!,
            value: Decimal.from(map.get('value')),
            id: map.getAsInt('id'));

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

  @JsonField.hidden()
  @override
  List<String> get fieldsNames =>
      const <String>['enabled', 'id', 'type', 'value'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'type':
        return type as V?;
      case 'enabled':
        return enabled as V?;
      case 'value':
        return value as V?;
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
        return TypeInfo(RoleType);
      case 'enabled':
        return TypeInfo.tBool;
      case 'value':
        return TypeInfo(Decimal);
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
          type = RoleType$from(value)!;
          break;
        }
      case 'enabled':
        {
          enabled = value as bool;
          break;
        }
      case 'value':
        {
          this.value = value as Decimal?;
          break;
        }
      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (id != null) 'id': id,
        'type': type.enumName,
        'value': value?.toStringStandard(),
      };
}

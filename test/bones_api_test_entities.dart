import 'dart:convert';
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:crypto/crypto.dart';
import 'package:statistics/statistics.dart';

part 'bones_api_test_entities.reflection.g.dart';

final storeEntityHandler = GenericEntityHandler<Store>(
    instantiatorDefault: Store.empty,
    instantiatorFromMap: Store.fromMap,
    type: Store,
    typeName: 'Store');

final addressEntityHandler = GenericEntityHandler<Address>(
    instantiatorDefault: Address.empty,
    instantiatorFromMap: (m) => Address.fromMap(m));

final roleEntityHandler =
    GenericEntityHandler<Role>(instantiatorFromMap: Role.fromMap);

final photoEntityHandler =
    GenericEntityHandler<Photo>(instantiatorFromMap: Photo.from);

final userInfoEntityHandler = GenericEntityHandler<UserInfo>(
    instantiatorDefault: UserInfo.empty, instantiatorFromMap: UserInfo.fromMap);

final userEntityHandler = GenericEntityHandler<User>(
    instantiatorDefault: User.empty, instantiatorFromMap: User.fromMap);

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

  FutureOr<Iterable<Address>> selectByStore(Store store) {
    return selectByQuery(' stores =~ ? ', parameters: {'stores': store});
  }

  FutureOr<Iterable<Address>> selectByClosedStore(Store store) {
    return selectByQuery(' closedStores =~ ? ',
        parameters: {'closedStores': store});
  }
}

class RoleAPIRepository extends APIRepository<Role> {
  RoleAPIRepository(EntityRepositoryProvider provider)
      : super(provider: provider);
}

class PhotoAPIRepository extends APIRepository<Photo> {
  PhotoAPIRepository(EntityRepositoryProvider provider)
      : super(provider: provider);
}

class UserInfoAPIRepository extends APIRepository<UserInfo> {
  UserInfoAPIRepository(EntityRepositoryProvider provider)
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

  FutureOr<Iterable<User>> selectByINAddressStates(List<String> states,
      {EntityResolutionRules? resolutionRules}) {
    return selectByQuery(' address.state =~ ? ',
        namedParameters: {'state': states}, resolutionRules: resolutionRules);
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
class Account extends Entity {
  int? id;

  User user;
  EntityReference<UserInfo> userInfo;

  Account.entityReference(this.user, {required this.userInfo});

  Account(this.user, {Object? userInfo})
      : userInfo = EntityReference<UserInfo>.from(userInfo);

  Account.empty() : this(User.empty());

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
        'user',
        'userInfo',
      ];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'user':
        return user as V?;
      case 'userInfo':
        return userInfo as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tInt;
      case 'user':
        return TypeInfo<User>(Address);
      case 'userInfo':
        return TypeInfo<EntityReference<UserInfo>>.fromType(
            EntityReference, [TypeInfo<UserInfo>.fromType(UserInfo)]);
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
      case 'user':
        {
          user = value as User;
          break;
        }
      case 'userInfo':
        {
          userInfo = EntityReference<UserInfo>.from(value);
          break;
        }
      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'user': user.toJson(),
        'userInfo': userInfo.toJson(),
      };
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

  EntityReference<UserInfo> userInfo;

  Photo? photo;

  DateTime creationTime;

  User(this.email, this.password, this.address, this.roles,
      {this.id,
      this.level,
      this.wakeUpTime,
      Object? userInfo,
      Object? photo,
      DateTime? creationTime})
      : userInfo = EntityReference<UserInfo>.from(userInfo,
            entityHandler: userInfoEntityHandler),
        photo = photo != null ? Photo.from(photo) : null,
        creationTime = creationTime ?? DateTime.now();

  User.empty() : this('', '', Address.empty(), <Role>[]);

  static FutureOr<User> fromMap(Map<String, dynamic> map) => User(
      map.getAsString('email')!,
      map.getAsString('password')!,
      map.getAs<Address>('address')!,
      map.getAsList<Role>('roles', def: <Role>[])!,
      id: map['id'],
      level: map['level'],
      wakeUpTime: map['wakeUpTime'],
      userInfo: map['userInfo'],
      photo: map['photo'],
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
        'userInfo',
        'photo',
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
      case 'userInfo':
        return userInfo as V?;
      case 'photo':
        return photo as V?;
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
        return TypeInfo<Address>(Address);
      case 'roles':
        return TypeInfo<List<Role>>(List, [TypeInfo<Role>(Role)]);
      case 'level':
        return TypeInfo.tInt;
      case 'wakeUpTime':
        return TypeInfo<Time>(Time);
      case 'userInfo':
        return TypeInfo<EntityReference<UserInfo>>.fromType(
            EntityReference, [TypeInfo<UserInfo>.fromType(UserInfo)]);
      case 'photo':
        return TypeInfo<Photo>(Photo);
      case 'creationTime':
        return TypeInfo<DateTime>(DateTime);
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
      case 'userInfo':
        {
          userInfo = EntityReference<UserInfo>.from(value);
          break;
        }
      case 'photo':
        {
          photo = value != null ? Photo.from(value) : null;
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
        'userInfo': userInfo.toJson(),
        if (photo != null) 'photo': photo?.toJson(),
        'creationTime': creationTime.toUtc().millisecondsSinceEpoch,
      };
}

@EnableReflection()
class UserInfo extends Entity {
  int? id;

  @EntityField.maximum(1000)
  String info;

  UserInfo(this.info, {this.id});

  UserInfo.empty() : this('');

  static FutureOr<UserInfo> fromMap(Map<String, dynamic> map) =>
      UserInfo(map.getAsString('info')!, id: map['id']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String get idFieldName => 'id';

  @JsonField.hidden()
  @override
  List<String> get fieldsNames => const <String>['id', 'info'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'info':
        return info as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tInt;
      case 'info':
        return TypeInfo.tString;
      default:
        return null;
    }
  }

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) {
    switch (key) {
      case 'info':
        return [
          EntityField.maximum(1000),
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
      case 'info':
        {
          info = value as String;
          break;
        }

      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'info': info,
      };
}

@EnableReflection()
class Photo extends Entity {
  static String computeID(Uint8List data) => sha256.convert(data).toString();

  String id;

  Uint8List? data;

  Photo._(this.id, this.data);

  Photo.fromID(this.id);

  Photo.fromData(Uint8List data, {String? id})
      : this._(id ?? computeID(data), data);

  factory Photo.from(Object o, {String? id}) {
    if (o is Photo) return o;

    if (o is Uint8List) return Photo.fromData(o, id: id);

    if (o is Map) {
      var map = o is Map<String, Object?>
          ? o
          : o.map((key, value) => MapEntry('$key', value));
      return Photo.fromMap(map);
    }

    if (o is String) {
      try {
        var data = base64.decode(o);
        return Photo.fromData(data, id: id);
      } catch (_) {
        return Photo.fromID(o);
      }
    }

    throw ArgumentError("Can't resolve `${o.runtimeType}`");
  }

  Photo.empty() : this.fromID('');

  static Photo fromMap(Map<String, dynamic> map) {
    var id = map['id'];
    var data = map['data'];
    return Photo.from(data!, id: id);
  }

  String? get dataUrl {
    var data = this.data;
    if (data == null || data.isEmpty) return null;
    var encoded = base64.encode(data);
    var mimeType =
        jsonMimeTypeResolver.lookup('jpeg', headerBytes: data) ?? 'image/jpeg';

    return 'data:$mimeType;base64,$encoded';
  }

  @override
  String get idFieldName => 'id';

  @JsonField.hidden()
  @override
  List<String> get fieldsNames => const <String>['id', 'data'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'data':
        return data as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tString;
      case 'data':
        return TypeInfo.tUint8List;
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        {
          id = value as String;
          break;
        }
      case 'data':
        {
          data = value as Uint8List;
          break;
        }

      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        if (data != null) 'data': base64.encode(data!),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Photo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Photo{id: $id}';
  }
}

@EnableReflection()
class Store extends Entity {
  int? id;

  @EntityField.maximum(100)
  String name;

  int? number;

  User? owner;

  Store(this.name, this.number, {this.id, this.owner});

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
  List<String> get fieldsNames =>
      const <String>['id', 'name', 'number', 'owner'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'name':
        return name as V?;
      case 'number':
        return number as V?;
      case 'owner':
        return owner as V?;
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
      case 'owner':
        return TypeInfo.fromType(User);
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

      case 'owner':
        {
          owner = value as User?;
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
        'owner': owner?.toJson(),
      };
}

@EnableReflection()
class Address extends Entity {
  int? id;

  @EntityField.indexed()
  @EntityField.maximum(3)
  String state;

  @EntityField.maximum(100)
  String city;

  @EntityField.maximum(200)
  String street;

  int number;

  Decimal latitude;
  Decimal longitude;

  List<Store> stores;
  EntityReferenceList<Store> closedStores;

  Address(this.state, this.city, this.street, this.number,
      {this.id,
      List<Store>? stores,
      Object? closedStores,
      Object? latitude,
      Object? longitude})
      : stores = stores ?? <Store>[],
        closedStores = EntityReferenceList<Store>.from(
            closedStores ?? <Store>[],
            entityHandler: storeEntityHandler),
        latitude = Decimal.from(latitude) ?? Decimal.zero,
        longitude = Decimal.from(longitude) ?? Decimal.zero;

  Address.empty() : this('', '', '', 0);

  Address.fromMap(Map<String, dynamic> map)
      : this(map.getAsString('state')!, map.getAsString('city')!,
            map.getAsString('street')!, map.getAsInt('number')!,
            stores: map.getAsList<Store>('stores', def: <Store>[])!,
            closedStores: map['closedStores'],
            latitude: map['latitude'],
            longitude: map['longitude'],
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
          number == other.number &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode =>
      id.hashCode ^
      state.hashCode ^
      city.hashCode ^
      street.hashCode ^
      number.hashCode ^
      latitude.hashCode ^
      longitude.hashCode;

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
        'closedStores',
        'latitude',
        'longitude',
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
      case 'latitude':
        return latitude as V?;
      case 'longitude':
        return longitude as V?;
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
        return TypeInfo<List<Store>>(List, [TypeInfo<Store>(Store)]);
      case 'closedStores':
        return TypeInfo<EntityReferenceList<Store>>.fromType(
            EntityReferenceList, [TypeInfo<Store>.fromType(Store)]);
      case 'latitude':
        return TypeInfo.fromType(Decimal);
      case 'longitude':
        return TypeInfo.fromType(Decimal);
      default:
        return null;
    }
  }

  @override
  List<EntityAnnotation>? getFieldEntityAnnotations(String key) {
    switch (key) {
      case 'state':
        return [EntityField.indexed(), EntityField.maximum(3)];
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
          closedStores = EntityReferenceList<Store>.from(value);
          break;
        }
      case 'latitude':
        {
          latitude = Decimal.from(value) ?? Decimal.zero;
          break;
        }
      case 'longitude':
        {
          longitude = Decimal.from(value) ?? Decimal.zero;
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
        'closedStores': closedStores.toJson(),
        'latitude': latitude.toDouble(),
        'longitude': longitude.toDouble(),
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
        return TypeInfo<RoleType>(RoleType);
      case 'enabled':
        return TypeInfo.tBool;
      case 'value':
        return TypeInfo<Decimal>(Decimal);
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

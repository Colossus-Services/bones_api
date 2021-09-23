import 'dart:async';

import 'package:async_extension/async_extension.dart';
import 'package:bones_api/bones_api.dart';
import 'package:reflection_factory/reflection_factory.dart';

part 'bones_api_test_entities.reflection.g.dart';

final addressEntityHandler = GenericEntityHandler<Address>(
    instantiatorFromMap: (m) => Address.fromMap(m));

final userEntityHandler =
    GenericEntityHandler<User>(instantiatorFromMap: (m) => User.fromMap(m));

class AddressAPIRepository extends APIRepository<Address> {
  AddressAPIRepository(EntityRepositoryProvider provider)
      : super(provider: provider);

  FutureOr<Iterable<Address>> selectByState(String state) {
    return selectByQuery(' state == ? ', parameters: {'state': state});
  }
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
}

@EnableReflection()
class User extends Entity {
  int? id;

  String email;

  String password;

  Address address;

  DateTime creationTime;

  User(this.email, this.password, this.address,
      {this.id, DateTime? creationTime})
      : creationTime = creationTime ?? DateTime.now();

  User.empty() : this('', '', Address.empty());

  static FutureOr<User> fromMap(Map<String, dynamic> map) =>
      User(map['email'], map['password'], map['address']!,
          id: map['id'], creationTime: map['creationTime']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames =>
      const <String>['id', 'email', 'password', 'address', 'creationTime'];

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
      case 'creationTime':
        return creationTime as V?;
      default:
        return null;
    }
  }

  @override
  Type? getFieldType(String key) {
    switch (key) {
      case 'id':
        return int;
      case 'email':
        return String;
      case 'password':
        return String;
      case 'address':
        return Address;
      case 'creationTime':
        return DateTime;
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        {
          id = value as int;
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
      : this(map['state'], map['city'], map['street'], map['number'],
            id: map['id']);

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
  Type? getFieldType(String key) {
    switch (key) {
      case 'id':
        return int;
      case 'state':
        return String;
      case 'city':
        return String;
      case 'street':
        return String;
      case 'number':
        return int;
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        {
          id = value as int;
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

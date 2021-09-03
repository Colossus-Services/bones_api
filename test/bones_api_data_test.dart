import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('Data', () {
    setUp(() {});

    test('basic', () async {
      var repository =
          SetDataRepository<User>('user', EntityDataHandler<User>());

      expect(repository.nextID(), equals(1));
      expect(repository.selectByID(1), isNull);

      var user1 = User('joe@mail.com', '123',
          Address('NY', 'New York', 'Fifth Avenue', 101));
      var user2 = User('smith@mail.com', 'abc',
          Address('CA', 'Los Angeles', 'Hollywood Boulevard', 404));

      repository.store(user1);
      repository.store(user2);

      var user1Json = user1.toJsonEncoded();
      var user2Json = user2.toJsonEncoded();

      expect(repository.nextID(), equals(3));

      expect(repository.selectByID(1)!.toJsonEncoded(), equals(user1Json));

      expect(
          repository
              .select(Condition.parse('email == "joe@mail.com"'))
              .map((e) => e.toJsonEncoded()),
          equals([user1Json]));

      expect(
          repository
              .select(Condition.parse('email != "smith@mail.com"'))
              .map((e) => e.toJsonEncoded()),
          equals([user1Json]));

      expect(
          repository
              .select(Condition.parse(' email != "joe@mail.com" '))
              .map((e) => e.toJsonEncoded()),
          equals([user2Json]));

      expect(repository.select(Condition.parse('email == "foo@mail.com"')),
          isEmpty);

      expect(
          repository
              .select(Condition.parse('email != "foo@mail.com"'))
              .map((e) => e.toJsonEncoded()),
          equals([user1Json, user2Json]));

      expect(repository.selectByQuery('address.state == ?', parameters: ['NY']),
          equals([user1]));

      expect(
          repository.selectByQuery('address.state == ?#0', parameters: ['NY']),
          equals([user1]));

      expect(
          repository.selectByQuery('address.state == ?#', parameters: ['NY']),
          equals([user1]));

      expect(
          repository
              .selectByQuery('address.state == ?', parameters: {'state': 'CA'}),
          equals([user2]));

      expect(
          repository.selectByQuery('address.state == ?:the_state',
              parameters: {'the_state': 'CA'}),
          equals([user2]));

      expect(
          repository.selectByQuery('address.state == ?:',
              parameters: {'state': 'CA'}),
          equals([user2]));

      expect(
          repository.selectByQuery('address.state == ?',
              parameters: {'state': 'FL'}).map((e) => e.toJsonEncoded()),
          isEmpty);
    });
  });
}

class User extends DataEntity {
  int? id;

  String email;

  String password;

  Address address;

  User(this.email, this.password, this.address, {this.id});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  List<String> get fieldsNames =>
      const <String>['id', 'email', 'password', 'address'];

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
      };
}

class Address extends DataEntity {
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

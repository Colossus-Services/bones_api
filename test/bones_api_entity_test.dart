import 'dart:async';

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_entity_adapter_memory.dart';
import 'package:bones_api/src/bones_api_logging.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

final _log = logging.Logger('bones_api_entity_test');

final addressEntityHandler = GenericEntityHandler<Address>(
    instantiatorFromMap: (m) => Address.fromMap(m));

final userEntityHandler =
    GenericEntityHandler<User>(instantiatorFromMap: (m) => User.fromMap(m));

class APIEntityRepositoryProvider extends EntityRepositoryProvider {
  static final APIEntityRepositoryProvider _instance =
      APIEntityRepositoryProvider._();

  factory APIEntityRepositoryProvider() => _instance;

  late final MemorySQLAdapter sqlAdapter;

  late final SQLEntityRepository<Address> addressSQLRepository;
  late final SQLEntityRepository<User> userSQLRepository;

  late final AddressAPIRepository addressAPIRepository;

  late final UserAPIRepository userAPIRepository;

  APIEntityRepositoryProvider._() {
    sqlAdapter = MemorySQLAdapter(parentRepositoryProvider: this)
      ..addTableSchemes([
        TableScheme(
          'user',
          'id',
          {
            'id': int,
            'email': String,
            'password': String,
            'address': int,
          },
          {
            'address':
                TableFieldReference('account', 'address', 'address', 'id')
          },
        ),
        TableScheme(
          'address',
          'id',
          {
            'id': int,
            'state': String,
            'city': String,
            'street': String,
            'number': int
          },
        )
      ]);

    addressSQLRepository = SQLEntityRepository<Address>(
        sqlAdapter, 'address', addressEntityHandler)
      ..ensureInitialized();

    userSQLRepository =
        SQLEntityRepository<User>(sqlAdapter, 'user', userEntityHandler)
          ..ensureInitialized();

    addressAPIRepository = AddressAPIRepository(this)..ensureConfigured();

    userAPIRepository = UserAPIRepository(this)..ensureConfigured();
  }
}

class AddressAPIRepository extends APIRepository<Address> {
  AddressAPIRepository(APIEntityRepositoryProvider provider)
      : super(provider: provider);

  FutureOr<Iterable<Address>> selectByState(String state) {
    return selectByQuery(' state == ? ', parameters: {'state': state});
  }
}

class UserAPIRepository extends APIRepository<User> {
  UserAPIRepository(APIEntityRepositoryProvider provider)
      : super(provider: provider);

  FutureOr<Iterable<User>> selectByEmail(String email) {
    return selectByQuery(' email == ? ', parameters: {'email': email});
  }

  FutureOr<Iterable<User>> selectByAddressState(String state) {
    return selectByQuery(' address.state == ? ', parameters: [state]);
  }
}

void main() {
  _log.handler.logToConsole();

  group('Entity', () {
    setUp(() {});

    test('basic', () async {
      APIEntityRepositoryProvider();

      var user1 = User('joe@mail.com', '123',
          Address('NY', 'New York', 'Fifth Avenue', 101));
      var user2 = User('smith@mail.com', 'abc',
          Address('CA', 'Los Angeles', 'Hollywood Boulevard', 404));

      var user1Json =
          '{"email":"joe@mail.com","password":"123","address":{"state":"NY","city":"New York","street":"Fifth Avenue","number":101}}';
      var user2Json =
          '{"email":"smith@mail.com","password":"abc","address":{"state":"CA","city":"Los Angeles","street":"Hollywood Boulevard","number":404}}';

      expect(userEntityHandler.encodeJson(user1), equals(user1Json));
      expect(userEntityHandler.decodeJson(user1Json), equals(user1));
      expect(userEntityHandler.decodeObjectJson(user1Json), equals(user1));

      expect(userEntityHandler.encodeObjectJson(user2), equals(user2Json));

      var user1b = userEntityHandler.decodeObjectJson(user1Json);

      expect(user1b, equals(user1));

      await userEntityHandler.setFieldsFromMap(user1b, user2.toJson());
      expect(user1b, equals(user2));
    });

    test('SetEntityRepository', () async {
      var repository = SetEntityRepository<User>('user', userEntityHandler);

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
          (await repository.selectByQuery('address.state == ?',
                  parameters: {'state': 'FL'}))
              .map((e) => e.toJsonEncoded()),
          isEmpty);
    });
  });

  group('SQLEntityRepository', () {
    setUp(() {
      APIEntityRepositoryProvider();
    });

    test('store, selectByID, selectByQuery', () async {
      var userSQLRepository = APIEntityRepositoryProvider().userSQLRepository;

      expect(await userSQLRepository.length(), equals(0));

      {
        var user = await userSQLRepository.selectByID(1);
        expect(user, isNull);
      }

      {
        var del = await userSQLRepository.deleteByQuery(' email == "foo" ');
        expect(del, isEmpty);
      }

      {
        var address = Address('NY', 'New York', 'street A', 101);
        var user = User('joe@mail.com', '123', address);
        var id = userSQLRepository.store(user);
        expect(id, equals(1));
      }
      {
        var address = Address('CA', 'Los Angeles', 'street B', 201);
        var user = User('smith@mail.com', 'abc', address);
        var id = userSQLRepository.store(user);
        expect(id, equals(2));
      }

      expect(
          await userSQLRepository
              .countByQuery(' email == ? ', parameters: ['smith@mail.com']),
          equals(2));

      {
        var user = await userSQLRepository.selectByID(1);
        expect(user!.email, equals('joe@mail.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var user = await userSQLRepository.selectByID(2);
        expect(user!.email, equals('smith@mail.com'));
        expect(user.address.state, equals('CA'));
      }

      {
        var user = await userSQLRepository.selectByID(3000);
        expect(user, isNull);
      }

      {
        var sel = await userSQLRepository
            .selectByQuery(' email == ? ', parameters: ['joe@mail.com']);
        var user = sel.first;
        expect(user.email, equals('joe@mail.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userSQLRepository.selectByQuery(' email == ? ',
            parameters: {'email': 'smith@mail.com'});
        var user = sel.first;
        expect(user.email, equals('smith@mail.com'));
        expect(user.address.state, equals('CA'));
      }

      {
        var sel = await userSQLRepository
            .selectByQuery(' address.state == ?:st ', parameters: {'st': 'NY'});
        var user = sel.first;
        expect(user.email, equals('joe@mail.com'));
        expect(user.address.state, equals('NY'));
      }
    });
  });

  group('APIRepository', () {
    setUp(() {
      APIEntityRepositoryProvider();
    });

    test('selectByEmail, selectByAddressState, selectByState', () async {
      var userAPIRepository = APIEntityRepositoryProvider().userAPIRepository;
      var addressAPIRepository =
          APIEntityRepositoryProvider().addressAPIRepository;

      // User:
      {
        var count = await userAPIRepository.length();
        expect(count, equals(2));
      }

      {
        var user = await userAPIRepository.selectByID(1);
        expect(user!.id, equals(1));
        expect(user.email, equals('joe@mail.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userAPIRepository.selectByEmail('joe@mail.com');
        var user = sel.first;
        expect(user.email, equals('joe@mail.com'));
        expect(user.address.state, equals('NY'));
      }

      {
        var sel = await userAPIRepository.selectByAddressState('CA');
        var user = sel.first;
        expect(user.email, equals('smith@mail.com'));
        expect(user.address.state, equals('CA'));
      }

      {
        var sel = await userAPIRepository.selectByEmail('XX');
        expect(sel, isEmpty);
      }

      {
        var sel = await addressAPIRepository
            .deleteByQuery(' state == ? ', parameters: ['ZZ']);
        expect(sel, isEmpty);
      }

      {
        var sel = await userAPIRepository.selectByAddressState('XX');
        expect(sel, isEmpty);
      }

      // Address:
      {
        var count = await addressAPIRepository.length();
        expect(count, equals(2));
      }

      {
        var address = await addressAPIRepository.selectByID(2);
        expect(address!.id, equals(2));
        expect(address.state, equals('CA'));
        expect(address.city, equals('Los Angeles'));

        var sel2 = await addressAPIRepository.selectByQuery(' #ID == 2 ');
        var address2 = sel2.first;
        expect(address2.toJson(), equals(address.toJson()));

        var sel3 = await addressAPIRepository
            .selectByQuery(' #ID == ? ', parameters: [2]);
        var address3 = sel3.first;
        expect(address3.toJson(), equals(address.toJson()));

        var sel4 = await addressAPIRepository
            .selectByQuery(' #ID == ?:theId ', parameters: {'theId': 2});
        var address4 = sel4.first;
        expect(address4.toJson(), equals(address.toJson()));
      }

      {
        var sel = await addressAPIRepository.selectByState('CA');
        var address = sel.first;
        expect(address.state, equals('CA'));
        expect(address.city, equals('Los Angeles'));
      }

      {
        var sel = await addressAPIRepository.selectByState('XX');
        expect(sel, isEmpty);
      }

      // Add User:
      {
        var address = Address('FL', 'Miami', 'Ocean Drive', 11);
        var user = User('mary@mail.com', 'xyz', address);
        var id = userAPIRepository.store(user);
        expect(id, equals(3));
      }

      {
        var sel = await userAPIRepository.selectByAddressState('FL');
        var user = sel.first;
        expect(user.email, equals('mary@mail.com'));
        expect(user.address.state, equals('FL'));
      }

      // Del User:

      {
        var count = await userAPIRepository.length();
        expect(count, equals(3));
      }

      {
        var del = await userAPIRepository
            .deleteByQuery(' email == ? ', parameters: ['smith@mail.com']);
        var user = del.first;
        expect(user.email, equals('smith@mail.com'));
        expect(user.address.state, equals('CA'));
      }

      {
        var count = await userAPIRepository.length();
        expect(count, equals(2));
      }

      // Del Address:

      {
        var count = await addressAPIRepository.length();
        expect(count, equals(3));
      }

      {
        var del = await addressAPIRepository
            .deleteByQuery(' state == ? ', parameters: ['CA']);
        var address = del.first;
        expect(address.state, equals('CA'));
        expect(address.city, equals('Los Angeles'));
      }

      {
        var count = await addressAPIRepository.length();
        expect(count, equals(2));
      }
    });
  });
}

class User extends Entity {
  int? id;

  String email;

  String password;

  Address address;

  User(this.email, this.password, this.address, {this.id});

  User.empty()
      : email = '',
        password = '',
        address = Address.empty();

  User.fromMap(Map<String, dynamic> map)
      : email = map['email'],
        password = map['email'],
        address = map['address'] is Map
            ? Address.fromMap(map['address'])
            : (map['address'] is int
                    ? APIEntityRepositoryProvider()
                        .getEntityRepository<Address>()!
                        .selectByID(map['address']) as Address?
                    : null) ??
                Address.empty(),
        id = map['id'];

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

  Address.empty()
      : state = '',
        city = '',
        street = '',
        number = 0;

  Address.fromMap(Map<String, dynamic> map)
      : state = map['state'],
        city = map['city'],
        street = map['street'],
        number = map['number'],
        id = map['id'];

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

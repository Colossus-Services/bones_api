import 'package:bones_api/bones_api.dart';

part 'reflection/api_entities.g.dart';

@EnableReflection()
class Role {
  int? id;

  @EntityField.unique()
  @EntityField.maximum(50)
  String name;

  Role(this.name, {this.id});

  Role.create() : this('');
}

@EnableReflection()
class Address {
  int? id;

  @EntityField.maximum(3)
  String countryCode;

  String state;

  String city;

  String addressLine1;

  String zipCode;

  Address(
    this.countryCode,
    this.state,
    this.city,
    this.addressLine1,
    this.zipCode, {
    this.id,
  });

  Address.create() : this('', '', '', '', '');
}

@EnableReflection()
class User {
  int? id;

  @EntityField.unique()
  @EntityField.maximum(200)
  String email;

  String name;

  @EntityField.maximum(64)
  String passwordHash;

  bool enabled;

  DateTime creationTime;

  Address address;

  List<Role> roles;

  User(
    this.email,
    this.name,
    String passwordOrHash,
    this.address,
    this.roles, {
    this.id,
    this.enabled = true,
    DateTime? creationTime,
  }) : passwordHash = hashPassword(passwordOrHash),
       creationTime = creationTime ?? DateTime.now();

  User.create() : this('', '', '', Address.create(), <Role>[]);

  /// The same hashing `APICredential.checkPassword` uses, so a stored
  /// [passwordHash] can be checked against a login credential.
  static String hashPassword(String passwordOrHash) =>
      APIPasswordSHA256().hashPassword(passwordOrHash);
}

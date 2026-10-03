import 'package:bones_api/bones_api.dart';

import 'api_entities.dart';
import 'api_repositories.dart';
import 'api_root.dart';

part 'reflection/module_user.g.dart';

@EnableReflection()
class ModuleUser extends APIModule {
  ModuleUser(UsersAPIRoot apiRoot) : super(apiRoot, 'user');

  UsersEntityRepositoryProvider get _provider =>
      (apiRoot as UsersAPIRoot).entityRepositoryProvider;

  late final RoleAPIRepository roleRepository = RoleAPIRepository(_provider);

  late final UserAPIRepository userRepository = UserAPIRepository(_provider);

  late final UsersAPISecurity _security = UsersAPISecurity(userRepository);

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  @override
  APISecurity get security => _security;

  // -------------------------------------------------------------------------
  // CRUD
  // -------------------------------------------------------------------------

  /// Registers a [User]. [roles] is a comma-separated list of [Role] names,
  /// which must already exist (see `role/create`).
  Future<APIResponse<User>> register({
    required String email,
    required String password,
    required String name,
    required String countryCode,
    required String state,
    required String city,
    String? addressLine1,
    String? zipCode,
    String? roles,
  }) async {
    var userRoles = <Role>[];
    for (var roleName in _splitNames(roles)) {
      var role = await roleRepository.selectByName(roleName);
      if (role == null) {
        return APIResponse.error(error: 'Unknown `Role`: $roleName');
      }
      userRoles.add(role);
    }

    var address = Address(
      countryCode,
      state,
      city,
      addressLine1 ?? '',
      zipCode ?? '',
    );

    var user = User(email, name, password, address, userRoles);

    var stored = await userRepository.store(user);

    return stored != null
        ? APIResponse.ok(user)
        : APIResponse.error(error: "Can't register `User`: $email");
  }

  Future<APIResponse<User>> byId(int id) async {
    var user = await userRepository.selectByID(id);
    return user != null
        ? APIResponse.ok(user)
        : APIResponse.notFound(payloadDynamic: 'No `User` with id: $id');
  }

  Future<APIResponse<User>> update({
    required int id,
    String? name,
    bool? enabled,
    String? state,
    String? city,
  }) async {
    var user = await userRepository.selectByID(id);
    if (user == null) {
      return APIResponse.notFound(payloadDynamic: 'No `User` with id: $id');
    }

    if (name != null) user.name = name;
    if (enabled != null) user.enabled = enabled;
    if (state != null) user.address.state = state;
    if (city != null) user.address.city = city;

    var stored = await userRepository.store(user);

    return stored != null
        ? APIResponse.ok(user)
        : APIResponse.error(error: "Can't update `User` with id: $id");
  }

  Future<APIResponse<int>> remove(int id) async {
    var user = await userRepository.deleteByID(id);
    return user != null
        ? APIResponse.ok(id)
        : APIResponse.notFound(payloadDynamic: 'No `User` with id: $id');
  }

  // -------------------------------------------------------------------------
  // Queries
  // -------------------------------------------------------------------------

  Future<APIResponse<User>> byEmail(String email) async {
    var user = await userRepository.selectByEmail(email);
    return user != null
        ? APIResponse.ok(user)
        : APIResponse.notFound(payloadDynamic: 'No `User` with email: $email');
  }

  /// Users whose `address.state` is [state] (a join with `address`).
  Future<APIResponse<List<User>>> byState(String state, {int? limit}) async {
    var users = await userRepository.selectByAddressState(
      state,
      limit: limit ?? 20,
    );
    return APIResponse.ok(users.toList());
  }

  /// A page of users, ordered by ID. [page] is zero-based.
  Future<APIResponse<List<User>>> list({int? page, int? pageSize}) async {
    var limit = pageSize ?? 20;
    var users = await userRepository.selectAll(
      limit: limit,
      offset: (page ?? 0) * limit,
      orderByID: true,
    );
    return APIResponse.ok(users.toList());
  }

  Future<APIResponse<int>> count() async {
    var count = await userRepository.length();
    return APIResponse.ok(count);
  }

  static List<String> _splitNames(String? names) => names == null
      ? const <String>[]
      : names
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
}

/// Login by `email` + `password` (route `/authenticate`).
class UsersAPISecurity extends APISecurity {
  final UserAPIRepository userRepository;

  UsersAPISecurity(this.userRepository);

  @override
  Future<bool> checkCredentialPassword(APICredential credential) async {
    var user = await _getUserByCredential(credential);
    if (user == null || !user.enabled) return false;
    return credential.checkPassword(user.passwordHash);
  }

  @override
  FutureOr<Object?> getAuthenticationData(
    APICredential credential,
    Object? previousData,
  ) async {
    if (previousData != null) return previousData;

    var user = await _getUserByCredential(credential);
    if (user == null) return null;

    return {'id': user.id, 'email': user.email, 'name': user.name};
  }

  @override
  FutureOr<List<APIPermission>> getCredentialPermissions(
    APICredential credential,
    List<APIPermission>? previousPermissions,
  ) async {
    if (previousPermissions != null) return previousPermissions;

    var user = await _getUserByCredential(credential);
    if (user == null) return <APIPermission>[];

    return user.roles.map((r) => APIPermission(r.name)).toList();
  }

  Future<User?> _getUserByCredential(APICredential credential) async {
    var user = credential.usernameEntity;
    if (user is User) return user;

    user = await userRepository.selectByEmail(credential.username);
    credential.usernameEntity = user;
    return user;
  }
}

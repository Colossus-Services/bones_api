import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_db_postgre.dart';
import 'package:bones_api/bones_api_db_sqlite.dart';

import 'api_entities.dart';

/// Provides the `Role`, `Address` and `User` repositories.
///
/// The adapter is chosen purely by [adapterConfig] (the `db` section of the
/// API config): `sql.memory`, `sqlite` or `postgres`.
class UsersEntityRepositoryProvider extends DBSQLEntityRepositoryProvider {
  @override
  final Map<String, dynamic> adapterConfig;

  UsersEntityRepositoryProvider(this.adapterConfig) {
    // Boot the adapters that the config may select:
    DBPostgreSQLAdapter.boot();
    DBSQLiteAdapter.boot();
  }

  @override
  List<DBSQLEntityRepository> buildRepositories(DBSQLAdapter adapter) =>
      <DBSQLEntityRepository>[
        DBSQLEntityRepository<Role>(
          adapter,
          'role',
          Role$reflection().entityHandler,
        ),
        DBSQLEntityRepository<Address>(
          adapter,
          'address',
          Address$reflection().entityHandler,
        ),
        DBSQLEntityRepository<User>(
          adapter,
          'user',
          User$reflection().entityHandler,
        ),
      ];
}

class RoleAPIRepository extends APIRepository<Role> {
  RoleAPIRepository(EntityRepositoryProvider provider)
    : super(provider: provider);

  FutureOr<Role?> selectByName(String name) =>
      selectFirstByQuery(' name == ? ', parameters: {'name': name});
}

class AddressAPIRepository extends APIRepository<Address> {
  AddressAPIRepository(EntityRepositoryProvider provider)
    : super(provider: provider);
}

class UserAPIRepository extends APIRepository<User> {
  UserAPIRepository(EntityRepositoryProvider provider)
    : super(provider: provider);

  FutureOr<User?> selectByEmail(String email) =>
      selectFirstByQuery(' email == ? ', parameters: {'email': email});

  FutureOr<Iterable<User>> selectByAddressState(String state, {int? limit}) =>
      selectByQuery(
        ' address.state == ? ',
        parameters: {'state': state},
        limit: limit,
      );
}

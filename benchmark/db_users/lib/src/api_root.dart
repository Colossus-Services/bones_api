import 'package:bones_api/bones_api.dart';

import 'api_repositories.dart';
import 'module_role.dart';
import 'module_user.dart';

/// The Users API: modules `role` and `user`, with `user` as the security
/// module (`/authenticate`).
class UsersAPIRoot extends APIRoot {
  static const String apiVersion = '1.0.0';

  UsersAPIRoot({super.apiConfig}) : super('db_users', apiVersion);

  UsersEntityRepositoryProvider? _entityRepositoryProvider;

  UsersEntityRepositoryProvider get entityRepositoryProvider =>
      _entityRepositoryProvider ??= UsersEntityRepositoryProvider(
        (apiConfig['db'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      );

  @override
  List<EntityRepositoryProvider> loadEntityRepositoryProviders() =>
      <EntityRepositoryProvider>[entityRepositoryProvider];

  @override
  Set<APIModule> loadModules() => {ModuleRole(this), ModuleUser(this)};

  @override
  String? get securityModuleName => 'user';

  @override
  void onClose() {
    _entityRepositoryProvider?.close();
  }
}

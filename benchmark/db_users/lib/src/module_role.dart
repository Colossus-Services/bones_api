import 'package:bones_api/bones_api.dart';

import 'api_entities.dart';
import 'api_repositories.dart';
import 'api_root.dart';

part 'reflection/module_role.g.dart';

@EnableReflection()
class ModuleRole extends APIModule {
  ModuleRole(UsersAPIRoot apiRoot) : super(apiRoot, 'role');

  late final RoleAPIRepository roleRepository = RoleAPIRepository(
    (apiRoot as UsersAPIRoot).entityRepositoryProvider,
  );

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  Future<APIResponse<Role>> create(String name) async {
    var role = await roleRepository.selectByName(name);
    if (role != null) return APIResponse.ok(role);

    role = Role(name);
    await roleRepository.store(role);
    return APIResponse.ok(role);
  }

  Future<APIResponse<List<Role>>> list() async {
    var roles = await roleRepository.selectAll();
    return APIResponse.ok(roles.toList());
  }
}

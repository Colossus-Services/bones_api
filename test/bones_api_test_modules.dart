import 'package:bones_api/bones_api.dart';
import 'package:collection/collection.dart';

import 'bones_api_test_entities.dart';

part 'bones_api_test_modules.reflection.g.dart';

class TestAPIRoot extends APIRoot {
  TestAPIRoot() : super('Test', '1.0');

  @override
  Set<APIModule> loadModules() => {AboutModule(this), UserModule(this)};
}

@EnableReflection()
class AboutModule extends APIModule {
  AboutModule(APIRoot apiRoot) : super(apiRoot, 'about');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  APIResponse<String> about() => APIResponse.ok('About...');
}

@EnableReflection()
class UserModule extends APIModule {
  UserModule(APIRoot apiRoot) : super(apiRoot, 'user');

  @override
  void configure() {
    routes.anyFrom(reflection);
  }

  String notARoute(int n) => 'foo';

  Future<String> notARouteAsync(int n) async => 'foo';

  APIResponse<User> getUser(int id) => APIResponse.ok(User(
      'joe@email.com', 'pass123', Address('SC', 'NY', '', 123), [],
      creationTime: DateTime.utc(2021, 10, 11, 12, 13, 14)));

  APIResponse<User> echoUser(User user) =>
      APIResponse.ok(user..email += '.echo');

  APIResponse<List<User>> echoListUser(List<User> users) => APIResponse.ok(
      users.mapIndexed((i, e) => e..email += '.echo[$i]').toList());

  APIResponse<List<User>> echoListUser2(String msg, List<User> users) =>
      APIResponse.ok(
          users.mapIndexed((i, e) => e..email += '.echo[$i]{$msg}').toList());

  APIResponse getDynamic(int id) => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<APIResponse<User>> getUserAsync(int id) async => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<APIResponse> geDynamicAsync(int id) async => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));

  Future<dynamic> geDynamicAsync2(int id) async => APIResponse.ok(
      User('joe@email.com', 'pass123', Address('SC', 'NY', '', 123), []));
}

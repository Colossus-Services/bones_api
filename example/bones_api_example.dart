import 'package:bones_api/bones_api_server.dart';

void main() async {
  var configJson = '{"not_found_msg": "This is 404!"}';

  var api = MyAPI(apiConfig: configJson);

  print(api);

  await apiLocalCall(api);

  await apiServer(api);
}

// Calls the API locally, without start a server:
Future<void> apiLocalCall(MyAPI api) async {
  var r1 = await api.call(APIRequest.get('/service/base/foo'));
  print(r1);

  var r2 = await api
      .call(APIRequest.post('/service/base/foo', parameters: {'a': 1}));
  print(r2);

  var r3 = await api.call(APIRequest.get('/service/base/bar'));
  print(r3);
}

// Start an APIServer with Hot Reload
// (if `--enable-vm-service` is passed to the Dart VM):
Future<void> apiServer(MyAPI api) async {
  print('-----');

  var apiServer = APIServer(api, '*', 8088, hotReload: true);
  await apiServer.start();

  print('Running: $apiServer');
  print('URL: ${apiServer.url}');
}

class MyAPI extends APIRoot {
  MyAPI({dynamic apiConfig}) : super('example', '1.0', apiConfig: apiConfig);

  @override
  Set<APIModule> loadModules() => {MyBaseModule(this)};
}

class MyBaseModule extends APIModule {
  MyBaseModule(APIRoot apiRoot) : super(apiRoot, 'base');

  @override
  String? get defaultRouteName => '404';

  @override
  void configure() {
    routes.get('foo', (request) => APIResponse.ok('Hi[GET]!'));
    routes.post(
        'foo', (request) => APIResponse.ok('Hi[POST]! ${request.parameters}'));

    routes.any('time', (request) => APIResponse.ok(DateTime.now()));

    routes.any('404', (request) {
      var msg = apiConfig['not_found_msg'] ?? '404';
      var body = '404: ${request.path} ; msg: $msg';
      return APIResponse.notFound(payload: body);
    });
  }
}

// -----------------------
// OUTPUT:
// -----------------------
// example[1.0]{base}
// Hi[GET]!
// Hi[POST]! {a: 1}
// 404: /service/base/bar ; msg: This is 404!
// -----
// 2021-09-13 04:35:10.481131 [WARNING] (main) APIHotReload > Hot Reloaded not allowed. Dart VM not running with: --enable-vm-service
// 2021-09-13 04:35:10.498983 [INFO]    (main) APIServer    > Started HTTP server: 0.0.0.0:8088
// Running: APIServer{ apiType: MyAPI, apiRoot: example[1.0]{base}, address: 0.0.0.0, port: 8088, hotReload: true, started: true, stopped: false }
// URL: http://0.0.0.0:8088/
//

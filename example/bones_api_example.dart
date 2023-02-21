import 'dart:io';

import 'package:bones_api/bones_api_server.dart';
import 'package:mercury_client/mercury_client.dart';

/// APIs are organized in modules:
class MyBTCModule extends APIModule {
  MyBTCModule(APIRoot apiRoot) : super(apiRoot, 'btc');

  /// The default route for not matching routes:
  @override
  String? get defaultRouteName => '404';

  /// A configuration property from `apiConfig`.
  String get notFoundMsg => apiConfig['not_found_msg'] ?? 'Unknown route!';

  @override
  void configure() {
    routes.get('usd', (request) => fetchBtcUsd());

    routes.any('time', (request) => APIResponse.ok(DateTime.now()));

    routes.any('404', notFound);
  }

  /// A HTTP client for `fetchBtcUsd`:
  static final coinDeskClient = HttpClient("https://api.coindesk.com/v1/bpi");

  /// Fetches the BTS-USD price.
  Future<APIResponse<num>> fetchBtcUsd() async {
    var response = await coinDeskClient.get('currentprice.json');
    if (response.isNotOK) {
      return APIResponse.notFound();
    }

    // ignore: avoid_dynamic_calls
    var btcUsd = response.json['bpi']['USD']['rate_float'] as num?;
    return btcUsd != null ? APIResponse.ok(btcUsd) : APIResponse.notFound();
  }

  /// Not found route (`404`):
  FutureOr<APIResponse> notFound(APIRequest request) {
    // The requested path:
    var path = request.path;

    var body = '''
    <h1>404</h1><br>
    <b>PATH:<b> $path
    <p>
    <i>$notFoundMsg</i>
    ''';

    // `APIResponse` with `content-type` and `cache-control`:
    return APIResponse.notFound(payload: body)
      ..payloadMimeType = 'text/html'
      ..headers['cache-control'] = 'no-store';
  }
}

/// The `APIRoot` defines the API version and modules to use:
class MyAPI extends APIRoot {
  MyAPI({dynamic apiConfig}) : super('example', '1.0', apiConfig: apiConfig);

  // Load the modules used by this API:
  @override
  Set<APIModule> loadModules() => {MyBTCModule(this)};
}

void main() async {
  // A JSON to configure the API:
  var apiConfigJson = '''
    {"not_found_msg": "This is 404!"}
  ''';

  var api = MyAPI(apiConfig: apiConfigJson);

  print('API: $api');

  // Example: calling the API locally, without a server:
  await exampleAPILocalCall(api);

  // Example: calling the API using an HTTP server:
  await exampleAPIServer(api);

  print('-------------------');
  print('By!');
  exit(0);
}

/// Calls the API locally, without start a server:
Future<void> exampleAPILocalCall(MyAPI api) async {
  print('-------------------');
  print('Example: API local:\n');

  var btcUsd = await api.call(APIRequest.get('/btc/usd'));
  print('BTC-USD: $btcUsd');

  var time = await api.call(APIRequest.post('/btc/time'));
  print('TIME: $time');

  var foo = await api.call(APIRequest.get('/btc/foo'));
  print('FOO:\n$foo');
}

/// Starts an [APIServer] and calls the routes through [HttpClient]:
Future<void> exampleAPIServer(MyAPI api) async {
  print('-------------------');
  print('Example: APIServer:\n');

  int? serverPort = await startAPIServer(api);

  var httpClient = HttpClient("http://localhost:$serverPort/");

  var btcUsd = (await httpClient.get('/btc/usd')).bodyAsString;
  print('BTC-USD: $btcUsd');

  var time = (await httpClient.post('/btc/time')).bodyAsString;
  print('TIME: $time');

  var foo = (await httpClient.get('/btc/foo')).bodyAsString;
  print('FOO:\n$foo');

  await stopAPIServer();
}

late final APIServer apiServer;

/// Starts the [APIServer] (HTTP Server) and returns the port.
/// - With Hot Reload if `--enable-vm-service` is passed to the Dart VM.
Future<int?> startAPIServer(MyAPI api) async {
  var serverPort = 8088;

  print('Starting APIServer...\n');

  apiServer = APIServer(api, '*', serverPort, hotReload: true);
  await apiServer.start();

  print('\n$apiServer');
  print('URL: ${apiServer.url}\n');

  return serverPort;
}

/// Stops the [APIServer].
Future<bool> stopAPIServer() async {
  await apiServer.stop();
  return true;
}

// ---------------------------------
// OUTPUT:
// ---------------------------------
// API: example[1.0]{btc}
// -------------------
// Example: API local:
//
// BTC-USD: 53742.76
// TIME: 2021-10-08 02:15:17.804569
// FOO:
//     <h1>404</h1><br>
//     <b>PATH:<b> /btc/foo
//     <p>
//     <i>This is 404!</i>
//
// -------------------
// Example: APIServer:
//
// Starting APIServer...
//
// 2021-10-08 02:15:17.924328 [CONFIG]  (main) APIHotReload > pkgConfigURL: ~/workspace/bones_api/.dart_tool/package_config.json
// 2021-10-08 02:15:17.959068 [CONFIG]  (main) APIHotReload > Watching [~/workspace/bones_api] with [MacOSDirectoryWatcher]...
// 2021-10-08 02:15:18.185128 [INFO]    (main) APIHotReload > Created HotReloader
// 2021-10-08 02:15:18.185624 [INFO]    (main) APIHotReload > Enabled Hot Reload: true
// 2021-10-08 02:15:18.185852 [INFO]    (main) APIServer    > Started HTTP server: 0.0.0.0:8088
//
// APIServer{ apiType: MyAPI, apiRoot: example[1.0]{btc}, address: 0.0.0.0, port: 8088, hotReload: true, started: true, stopped: false }
// URL: http://0.0.0.0:8088/
//
// BTC-USD: 53742.76
// TIME: 2021-10-08 02:15:18.294076
// FOO:
//     <h1>404</h1><br>
//     <b>PATH:<b> /btc/foo
//     <p>
//     <i>This is 404!</i>
//
// -------------------
// By!
//

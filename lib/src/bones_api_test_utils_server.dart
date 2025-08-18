import 'package:bones_api/bones_api_server.dart';
import 'package:stream_channel/stream_channel.dart';

import 'bones_api_test_utils_freeport.dart';

/// Runs a test API server, looking for a free port and sending the server
/// port to [channel] or [portCallback].
/// - [testServerName] is the name of the test server to be used in the logging messages.
/// - [apiConfigJson] is the API configuration JSON to be used to instantiate the [APIRoot].
/// - [apiInstantiator] is the [Function] that instantiates the [APIRoot].
/// - [logPrintter] is the [Function] to print logging messages. Default: [print]
///
/// See the function [spawnHybridUri](https://pub.dev/documentation/test_api/latest/test_api.scaffolding/spawnHybridUri.html)
/// from `test` package.
Future<APIServer> runTestAPIServer<A extends APIRoot>(
  String testServerName,
  Map<String, dynamic> apiConfigJson,
  A Function(APIConfig apiConfig) apiInstantiator, {
  bool cookieless = true,
  StreamChannel? channel,
  dynamic Function(int port)? portCallback,
  void Function(Object? o)? logPrintter,
}) async {
  logPrintter ??= print;

  logPrintter('** Resolving free port...');

  var port = await resolveFreePort(4455);

  logPrintter('** Test `$testServerName` API >> port: $port...');

  var apiConfig = APIConfig.fromJson(apiConfigJson);

  var api = apiInstantiator(apiConfig);

  var apiServer = APIServer(
    api,
    'localhost',
    port,
    hotReload: false,
    useSessionID: false,
    cookieless: cookieless,
  );

  await apiServer.start();

  logPrintter(
    '\n===========================================================================\n',
  );
  logPrintter('$testServerName\n');
  logPrintter('$apiServer\n');
  logPrintter('${apiServer.apiRoot}\n');
  logPrintter('${api.apiConfig}\n');
  logPrintter('URL: ${apiServer.url}');
  logPrintter('API-INFO URL: ${apiServer.apiInfoURL}\n');
  logPrintter(
    '===========================================================================\n',
  );

  if (portCallback != null) {
    portCallback(port);
  }

  if (channel != null) {
    channel.sink.add(port);

    var cmd = await channel.stream.first;

    logPrintter('** Test `$testServerName` API Server CMD: $cmd');

    if (cmd == 'stop') {
      logPrintter('** Stopping Test `$testServerName` API Server...');
      await apiServer.stop();
      channel.sink.close();
    } else {
      throw UnsupportedError("CMD: $cmd");
    }
  }

  return apiServer;
}

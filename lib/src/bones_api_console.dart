import 'dart:async';

import 'package:bones_api/bones_api.dart';

/// API Console
class APIConsole {
  /// The API root of this server.
  final APIRoot apiRoot;

  /// The name of this server.
  ///
  /// This is used for the `server` header.
  final String name;

  /// The version of this server.
  ///
  /// This is used for the `server` header.
  final String version;

  APIConsole(this.apiRoot,
      {this.name = 'APIConsole', this.version = APIRoot.VERSION});

  /// Processes an API [line] request.
  FutureOr<APIResponse> processRequestLine(String line) {
    var apiRequest = APIRequest.fromArgsLine(line);
    return processRequest(apiRequest);
  }

  /// Processes an API [request].
  FutureOr<APIResponse> processRequest(APIRequest request) {
    var apiResponse = apiRoot.call(request);
    return apiResponse;
  }

  /// Runs the console interaction.
  Future<List<APIResponse>> run(
    FutureOr<String?> Function() nextLine, {
    bool returnResponses = true,
    Function(APIRequest request)? onRequest,
    Function(APIResponse response)? onResponse,
  }) async {
    var responses = <APIResponse>[];

    while (true) {
      var ret = nextLine();

      String? line;
      if (ret is Future) {
        line = await ret;
      } else {
        line = ret;
      }

      if (line == null) {
        return responses;
      }

      var request = APIRequest.fromArgsLine(line);

      if (onRequest != null) {
        var ret = onRequest(request);
        if (ret is Future) {
          ret = await ret;
        }

        if (ret is APIRequest) {
          request = ret;
        }
      }

      var response = await processRequest(request);

      if (returnResponses) {
        responses.add(response);
      }

      if (onResponse != null) {
        var ret = onResponse(response);
        if (ret is Future) {
          await ret;
        }
      }
    }
  }

  @override
  String toString() {
    return 'APIConsole{ apiType: ${apiRoot.runtimeType}, apiRoot: $apiRoot }';
  }
}

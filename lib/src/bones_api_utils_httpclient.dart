import 'package:async_extension/async_extension.dart';
import 'package:mercury_client/mercury_client.dart';

/// Decodes [queryString], allowing single and multiple values per key.
Map<String, dynamic> decodeQueryStringParameters(String? queryString) {
  if (queryString == null || queryString.isEmpty) return {};

  var pairs = queryString.split('&');

  var parameters = <String, dynamic>{};

  for (var pair in pairs) {
    if (pair.isEmpty) continue;
    var kv = pair.split('=');

    var k = kv[0];
    var v = kv.length > 1 ? kv[1] : '';

    k = Uri.decodeQueryComponent(k);
    v = Uri.decodeQueryComponent(v);

    var prev = parameters[k];

    if (prev == null) {
      parameters[k] = v;
    } else if (prev is List) {
      prev.add(v);
    } else {
      parameters[k] = [prev, v];
    }
  }

  return parameters;
}

Future<HttpResponse> getURL(String url, {HttpClient? client, String? method}) {
  method ??= 'GET';
  var httpMethod = getHttpMethod(method) ?? HttpMethod.GET;

  client ??= HttpClient(url);

  return client.requestURL(httpMethod, url);
}

FutureOr<String?> getURLAsString(String url,
    {HttpClient? client, String? method}) {
  var response = getURL(url, client: client, method: method);
  return response.then((response) => response.bodyAsString,
      onError: (e) => null);
}

FutureOr<List<int>?> getURLAsByteArray(String url,
    {HttpClient? client, String? method}) {
  var response = getURL(url, client: client, method: method);
  return response.then((response) => response.body?.asByteArrayAsync,
      onError: (e) => null);
}

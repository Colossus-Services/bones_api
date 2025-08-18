import 'dart:convert' as dart_convert;

import 'package:async_extension/async_extension.dart';
import 'package:mercury_client/mercury_client.dart';
import 'package:swiss_knife/swiss_knife.dart';

/// Decodes [queryString], allowing single and multiple values per key.
Map<String, dynamic> decodeQueryStringParameters(
  String? queryString, {
  String? charset,
}) {
  if (queryString == null || queryString.isEmpty) return {};

  var encoding = getCharsetEncoding(charset);

  var pairs = queryString.split('&');

  var parameters = <String, dynamic>{};

  for (var pair in pairs) {
    if (pair.isEmpty) continue;
    var kv = pair.split('=');

    var k = kv[0];
    var v = kv.length > 1 ? kv[1] : '';

    k = _decodeQueryComponent(k, encoding);
    v = _decodeQueryComponent(v, encoding);

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

String _decodeQueryComponent(String s, dart_convert.Encoding? encoding) {
  if (encoding == null) {
    try {
      return Uri.decodeQueryComponent(s, encoding: dart_convert.utf8);
    } catch (_) {
      try {
        return Uri.decodeQueryComponent(s, encoding: dart_convert.latin1);
      } catch (_) {
        return s;
      }
    }
  }

  try {
    return Uri.decodeQueryComponent(s, encoding: encoding);
  } catch (_) {
    if (identical(encoding, dart_convert.latin1)) {
      return s;
    }

    try {
      return Uri.decodeQueryComponent(s, encoding: dart_convert.latin1);
    } catch (_) {
      return s;
    }
  }
}

Future<HttpResponse> getURL(String url, {HttpClient? client, String? method}) {
  method ??= 'GET';
  var httpMethod = getHttpMethod(method) ?? HttpMethod.GET;

  client ??= HttpClient(url);

  return client.requestURL(httpMethod, url);
}

FutureOr<String?> getURLAsString(
  String url, {
  HttpClient? client,
  String? method,
}) {
  var response = getURL(url, client: client, method: method);
  return response.then(
    (response) => response.bodyAsString,
    onError: (e) => null,
  );
}

FutureOr<List<int>?> getURLAsByteArray(
  String url, {
  HttpClient? client,
  String? method,
}) {
  var response = getURL(url, client: client, method: method);
  return response.then(
    (response) => response.body?.asByteArrayAsync,
    onError: (e) => null,
  );
}

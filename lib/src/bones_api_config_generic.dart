import 'dart:async';

import 'package:mercury_client/mercury_client.dart';

import 'bones_api_config.dart';

FutureOr<APIConfig?> loadAPIConfigFromUri(Uri o, {bool allowAsync = true}) {
  if (o is Uri && allowAsync) {
    if (o.scheme == 'http' || o.scheme == 'https') {
      var url = o.toString();
      var ext = APIConfig.resolveFileExtension(url);

      var ret = HttpClient(url).get('');
      ret.then((response) {
        var content = response.bodyAsString;
        return content == null || content.isEmpty
            ? null
            : APIConfig.fromContent(content, type: ext, source: url);
      }, onError: (e) => null);
    }
  }

  return null;
}

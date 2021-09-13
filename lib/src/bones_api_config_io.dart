import 'dart:async';
import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:mercury_client/mercury_client.dart';

FutureOr<APIConfig?> loadAPIConfigFromUri(Uri o, {bool allowAsync = true}) {
  if (o is Uri) {
    if ((o.scheme == 'http' || o.scheme == 'https') && allowAsync) {
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

    if (o.scheme == 'file') {
      try {
        var filePath = o.toString();
        var ext = APIConfig.resolveFileExtension(filePath);
        var content = File.fromUri(o).readAsStringSync();
        return content.isEmpty
            ? null
            : APIConfig.fromContent(content, type: ext, source: filePath);
      } catch (_) {
        return null;
      }
    }
  }
}

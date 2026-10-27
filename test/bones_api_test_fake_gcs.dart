import 'dart:convert';
import 'dart:typed_data';

import 'package:crclib/catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An in-memory fake of the Google Cloud Storage JSON API (the requests of
/// `package:gcloud`), for a `DBObjectGCSAdapter` (with [client]).
class FakeGCS {
  final String bucket;

  FakeGCS(this.bucket);

  /// The stored objects, by name.
  final Map<String, Uint8List> objects = {};

  /// The object names whose media read fails (a 5xx response).
  final Set<String> failingReads = {};

  final List<String> requests = [];

  late final MockClient client = MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    var url = request.url;
    requests.add('${request.method} ${url.path}?${url.query}');

    var path = url.path;
    var objectsPrefix = '/storage/v1/b/$bucket/o';
    var downloadPrefix = '/download$objectsPrefix';
    var uploadPrefix = '/upload$objectsPrefix';

    if (request.method == 'POST' && path == uploadPrefix) {
      return _upload(request);
    }

    if (path.startsWith(downloadPrefix) || path.startsWith(objectsPrefix)) {
      var rest = path.startsWith(downloadPrefix)
          ? path.substring(downloadPrefix.length)
          : path.substring(objectsPrefix.length);

      if (rest.isEmpty || rest == '/') {
        return _list(url.queryParameters['prefix'] ?? '');
      }

      var name = Uri.decodeComponent(rest.substring(1));

      if (request.method == 'DELETE') {
        var removed = objects.remove(name);
        return removed == null ? _notFound() : http.Response('', 204);
      }

      var media =
          url.queryParameters['alt'] == 'media' ||
          path.startsWith(downloadPrefix);

      if (media && failingReads.contains(name)) {
        return _json({
          'error': {'code': 503, 'message': 'Service Unavailable'},
        }, status: 503);
      }

      var data = objects[name];
      if (data == null) return _notFound();

      return media
          ? http.Response.bytes(
              data,
              200,
              headers: {
                'content-type': 'application/json',
                'content-length': '${data.length}',
              },
            )
          : _json(_objectInfo(name, data));
    }

    return http.Response('Unexpected request: ${request.url}', 400);
  }

  http.Response _upload(http.Request request) {
    var contentType = request.headers['content-type'] ?? '';
    var boundary = RegExp(r'boundary="?([^";]+)"?')
        .firstMatch(contentType)![1]!;

    var body = latin1.decode(request.bodyBytes);
    var parts = body
        .split('--$boundary')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p != '--')
        .toList();

    String partBody(String part) {
      var idx = part.indexOf('\r\n\r\n');
      return part.substring(idx + 4).trim();
    }

    var metadata = json.decode(partBody(parts[0])) as Map<String, dynamic>;
    var name = metadata['name'] as String;

    var mediaPart = parts[1];
    var mediaBody = partBody(mediaPart);
    var bytes = mediaPart.toLowerCase().contains('base64')
        ? base64.decode(mediaBody.replaceAll(RegExp(r'\s'), ''))
        : latin1.encode(mediaBody);

    objects[name] = Uint8List.fromList(bytes);

    return _json(_objectInfo(name, objects[name]!));
  }

  http.Response _list(String prefix) => _json({
    'kind': 'storage#objects',
    'items': [
      for (var e in objects.entries)
        if (e.key.startsWith(prefix)) _objectInfo(e.key, e.value),
    ],
  });

  Map<String, dynamic> _objectInfo(String name, Uint8List data) {
    var crc = Crc32C().convert(data).toBigInt().toInt();
    var crcBytes = Uint8List(4)..buffer.asByteData().setUint32(0, crc);
    return {
      'kind': 'storage#object',
      'bucket': bucket,
      'name': name,
      'size': '${data.length}',
      'crc32c': base64.encode(crcBytes),
      'md5Hash': base64.encode(Uint8List(16)),
      'contentType': 'application/json',
      'generation': '1',
      'metageneration': '1',
      'updated': DateTime.utc(2020).toIso8601String(),
    };
  }

  http.Response _notFound() => _json({
    'error': {'code': 404, 'message': 'Not Found'},
  }, status: 404);

  http.Response _json(Object o, {int status = 200}) => http.Response(
    json.encode(o),
    status,
    headers: {'content-type': 'application/json'},
  );
}

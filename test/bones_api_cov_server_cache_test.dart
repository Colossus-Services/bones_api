@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:bones_api/src/bones_api_server_cache.dart';
import 'package:path/path.dart' as pack_path;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// A fake static files handler, serving files from [rootDir] with the
/// same `context` entries set by `APIServerWorker`.
class _FakeStaticHandler {
  final Directory rootDir;

  int calls = 0;

  /// Overrides the response of a path.
  final Map<String, Response Function(Request request)> overrides = {};

  _FakeStaticHandler(this.rootDir);

  Response call(Request request) {
    ++calls;

    var path = request.url.path;

    var override = overrides[path];
    if (override != null) return override(request);

    var file = File(pack_path.join(rootDir.path, path));

    if (!file.existsSync()) {
      return Response.notFound(
        utf8.encode('Not Found: $path'),
        headers: {'server': 'fake'},
        context: {'file_not_found': file},
      );
    }

    var lastModified = HttpDate.format(file.lastModifiedSync());

    var ifModifiedSince = request.headers['if-modified-since'];
    if (ifModifiedSince != null && ifModifiedSince == lastModified) {
      return Response.notModified(
        headers: {
          'last-modified': lastModified,
          'cache-control': 'max-age=1',
          'server': 'fake',
        },
        context: {'file': file},
      );
    }

    var bytes = file.readAsBytesSync();

    return Response.ok(
      bytes,
      headers: {
        'content-type': path.endsWith('.txt')
            ? 'text/plain'
            : 'application/octet-stream',
        'last-modified': lastModified,
        'cache-control': 'max-age=1',
        'server': 'fake',
        'date': HttpDate.format(DateTime.now()),
      },
      context: {'file': file},
    );
  }
}

Request _get(
  String path, {
  Map<String, String>? headers,
  String method = 'GET',
}) => Request(method, Uri.parse('http://localhost/$path'), headers: headers);

Future<String> _readBody(Response response) async {
  var bytes = await response.read().expand((e) => e).toList();
  if (response.headers['content-encoding'] == 'gzip') {
    bytes = gzip.decode(bytes);
  }
  return utf8.decode(bytes);
}

void main() {
  group('APIServerResponseCache', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('bones_api_cov_cache_');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) {
        await tmpDir.delete(recursive: true);
      }
    });

    File writeFile(String name, String content) {
      var file = File(pack_path.join(tmpDir.path, name));
      file.writeAsStringSync(content);
      return file;
    }

    test('200 + 304 caching', () async {
      writeFile('a.txt', 'Hello A');

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      expect(cache.cachedResponsesLength, equals(0));

      var r1 = await handler(_get('a.txt'));
      expect(r1.statusCode, equals(200));
      expect(await _readBody(r1), equals('Hello A'));
      expect(inner.calls, equals(1));

      // 200 + 304 entries:
      expect(cache.cachedResponsesLength, equals(2));
      expect(cache.totalMemorySize, greaterThan(0));

      var r2 = await handler(_get('a.txt'));
      expect(r2.statusCode, equals(200));
      expect(await _readBody(r2), equals('Hello A'));
      expect(r2.headers['X-API-Server-Cache'], isNotNull);
      expect(r2.headers['server-timing'], contains('API-Server-Response;dur='));
      expect(r2.headers['date'], isNull);
      expect(inner.calls, equals(1));

      // Cached again: the `server-timing` entry is replaced, not appended:
      var r2b = await handler(_get('a.txt'));
      expect(
        'API-Server-Response;'.allMatches(r2b.headers['server-timing']!).length,
        equals(1),
      );
      expect(inner.calls, equals(1));

      var lastModified = r1.headers['last-modified']!;

      var r3 = await handler(
        _get('a.txt', headers: {'if-modified-since': lastModified}),
      );
      expect(r3.statusCode, equals(304));
      expect(r3.headers['last-modified'], equals(lastModified));
      expect(r3.headers['cache-control'], equals('max-age=1'));
      expect(r3.headers['server'], equals('fake'));
      expect(inner.calls, equals(1));

      // Not GET: not served from cache, nor cached:
      var r4 = await handler(_get('a.txt', method: 'HEAD'));
      expect(r4.statusCode, equals(200));
      expect(inner.calls, equals(2));
      expect(cache.getCachedResponse(_get('a.txt', method: 'POST')), isNull);
      expect(
        cache.cacheResponse(_get('a.txt', method: 'POST'), Response.ok('x')),
        isNull,
      );

      // Other status: not cached:
      expect(
        cache.cacheResponse(_get('a.txt'), Response.forbidden('x')),
        isNull,
      );

      expect(cache.toString(), contains('cachedResponses: 2'));
      expect(cache.toString(), contains('maxMemorySize: 50.0 MB'));
      expect(cache.toString(), contains('maxContentLength: 10.0 MB'));
      expect(cache.toString(), contains('fileStatTimeout: 5 min'));

      cache.clear();
      expect(cache.cachedResponsesLength, equals(0));
      expect(cache.totalMemorySize, equals(0));
    });

    test('304 from inner handler', () async {
      var file = writeFile('b.txt', 'Hello B');
      var lastModified = HttpDate.format(file.lastModifiedSync());

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      var r1 = await handler(
        _get('b.txt', headers: {'if-modified-since': lastModified}),
      );
      expect(r1.statusCode, equals(304));
      expect(inner.calls, equals(1));

      // The 304 is cached asynchronously:
      for (var i = 0; i < 50 && cache.cachedResponsesLength == 0; ++i) {
        await Future.delayed(Duration(milliseconds: 10));
      }
      expect(cache.cachedResponsesLength, equals(1));

      var r2 = await handler(
        _get('b.txt', headers: {'if-modified-since': lastModified}),
      );
      expect(r2.statusCode, equals(304));
      expect(r2.headers['X-API-Server-Cache'], isNotNull);
      expect(inner.calls, equals(1));

      // A 304 response without `If-Modified-Since` is not cached:
      expect(
        cache.cacheResponse(
          _get('b.txt'),
          Response.notModified(context: {'file': file}),
        ),
        isNull,
      );
      expect(
        cache.cacheResponse(
          _get('b.txt', method: 'POST'),
          Response.notModified(context: {'file': file}),
        ),
        isNull,
      );
    });

    test('404 caching and expiration', () async {
      var cache = APIServerResponseCache(fileStatTimeout: Duration.zero);
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      var r1 = await handler(_get('c.txt'));
      expect(r1.statusCode, equals(404));
      expect(await _readBody(r1), equals('Not Found: c.txt'));
      expect(inner.calls, equals(1));
      expect(cache.cachedResponsesLength, equals(1));

      var r2 = await handler(_get('c.txt'));
      expect(r2.statusCode, equals(404));
      expect(r2.headers['server'], equals('fake'));
      expect(r2.headers['X-API-Server-Cache'], isNotNull);
      expect(await _readBody(r2), equals('Not Found: c.txt'));
      expect(inner.calls, equals(1));

      expect(
        cache.cacheResponse(
          _get('c.txt', method: 'POST'),
          Response.notFound('x'),
        ),
        isNull,
      );

      // The file now exists: the cached 404 is expired.
      writeFile('c.txt', 'Hello C');

      var r3 = await handler(_get('c.txt'));
      expect(r3.statusCode, equals(200));
      expect(await _readBody(r3), equals('Hello C'));
      expect(inner.calls, equals(2));

      // 404 entry removed, 200 and 304 added:
      expect(cache.cachedResponsesLength, equals(2));
    });

    test('file modified expiration', () async {
      var file = writeFile('d.txt', 'Hello D');

      var cache = APIServerResponseCache(fileStatTimeout: Duration.zero);
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      var r1 = await handler(_get('d.txt'));
      expect(await _readBody(r1), equals('Hello D'));
      expect(inner.calls, equals(1));

      var r2 = await handler(_get('d.txt'));
      expect(await _readBody(r2), equals('Hello D'));
      expect(inner.calls, equals(1));

      file.writeAsStringSync('Hello D - modified!');
      file.setLastModifiedSync(DateTime.now().add(Duration(seconds: 10)));

      // Ensure that the stat is expired (timeout zero):
      await Future.delayed(Duration(milliseconds: 5));

      var r3 = await handler(_get('d.txt'));
      expect(await _readBody(r3), equals('Hello D - modified!'));
      expect(inner.calls, equals(2));

      var r4 = await handler(_get('d.txt'));
      expect(await _readBody(r4), equals('Hello D - modified!'));
      expect(inner.calls, equals(2));

      // Deleted file: cache expired, inner handler returns 404:
      file.deleteSync();
      await Future.delayed(Duration(milliseconds: 5));

      var r5 = await handler(_get('d.txt'));
      expect(r5.statusCode, equals(404));
      expect(inner.calls, equals(3));
    });

    test('gzip alternatives (compress)', () async {
      var content = List.generate(200, (i) => 'line $i').join('\n');
      writeFile('big.txt', content);

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      // Cached uncompressed:
      var r1 = await handler(_get('big.txt'));
      expect(r1.headers['content-encoding'], isNull);
      expect(await _readBody(r1), equals(content));
      expect(inner.calls, equals(1));

      // Accepts gzip: an alternative compressed entry is created:
      var r2 = await handler(
        _get('big.txt', headers: {'accept-encoding': 'gzip, deflate'}),
      );
      expect(r2.statusCode, equals(200));
      expect(r2.headers['content-encoding'], equals('gzip'));
      expect(await _readBody(r2), equals(content));
      expect(inner.calls, equals(1));

      var r3 = await handler(
        _get('big.txt', headers: {'accept-encoding': 'gzip'}),
      );
      expect(r3.headers['content-encoding'], equals('gzip'));
      expect(await _readBody(r3), equals(content));

      var r4 = await handler(_get('big.txt'));
      expect(r4.headers['content-encoding'], isNull);
      expect(await _readBody(r4), equals(content));
      expect(inner.calls, equals(1));
    });

    test('gzip alternatives (decompress)', () async {
      var content = List.generate(200, (i) => 'row $i').join('\n');
      var compressed = gzip.encode(utf8.encode(content));

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      inner.overrides['gz.txt'] = (request) => Response.ok(
        compressed,
        headers: {
          'content-type': 'text/plain',
          'content-encoding': 'gzip',
          'server': 'fake',
        },
      );

      var handler = cache.middleware(inner.call);

      var r1 = await handler(
        _get('gz.txt', headers: {'accept-encoding': 'gzip'}),
      );
      expect(r1.headers['content-encoding'], equals('gzip'));
      expect(await _readBody(r1), equals(content));
      expect(inner.calls, equals(1));
      expect(cache.cachedResponsesLength, equals(1));

      var r2 = await handler(_get('gz.txt'));
      expect(r2.headers['content-encoding'], isNull);
      expect(r2.headers['content-length'], equals('${content.length}'));
      expect(await _readBody(r2), equals(content));
      expect(inner.calls, equals(1));

      var r3 = await handler(
        _get('gz.txt', headers: {'accept-encoding': 'gzip'}),
      );
      expect(r3.headers['content-encoding'], equals('gzip'));
      expect(inner.calls, equals(1));
    });

    test('not cacheable responses', () async {
      var cache = APIServerResponseCache(maxContentLength: 10);
      var inner = _FakeStaticHandler(tmpDir);

      inner.overrides['stream.bin'] = (request) => Response.ok(
        Stream<List<int>>.fromIterable([
          [1, 2, 3],
        ]),
      );
      inner.overrides['large.bin'] = (request) =>
          Response.ok(List<int>.filled(100, 1));
      inner.overrides['forbidden'] = (request) => Response.forbidden('no');

      var handler = cache.middleware(inner.call);

      for (var path in ['stream.bin', 'large.bin', 'forbidden']) {
        var r1 = await handler(_get(path));
        var r2 = await handler(_get(path));
        expect(r1.statusCode, equals(r2.statusCode));
      }

      expect(inner.calls, equals(6));
      expect(cache.cachedResponsesLength, equals(0));
    });

    test('string file context + small files', () async {
      var file = writeFile('s.txt', 'Hello S');

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      inner.overrides['s.txt'] = (request) => Response.ok(
        utf8.encode('Hello S'),
        headers: {'content-type': 'text/plain'},
        context: {'file': file.path},
      );
      inner.overrides['none.txt'] = (request) => Response.ok(
        utf8.encode('none'),
        headers: {'content-type': 'text/plain'},
        context: {'file': pack_path.join(tmpDir.path, 'none.txt')},
      );

      var handler = cache.middleware(inner.call);

      expect(await _readBody(await handler(_get('s.txt'))), 'Hello S');
      expect(await _readBody(await handler(_get('s.txt'))), 'Hello S');
      expect(inner.calls, equals(1));

      expect(await _readBody(await handler(_get('none.txt'))), 'none');
      expect(await _readBody(await handler(_get('none.txt'))), 'none');
      expect(inner.calls, equals(2));

      // Small content: no gzip alternative, the uncompressed one is served:
      var r = await handler(
        _get('s.txt', headers: {'accept-encoding': 'gzip'}),
      );
      expect(r.headers['content-encoding'], isNull);
      expect(inner.calls, equals(2));
    });

    test('max memory size cleaning', () async {
      var cache = APIServerResponseCache(
        maxMemorySize: 1024 * 1024,
        fileStatTimeout: Duration(days: 2),
      );

      var inner = _FakeStaticHandler(tmpDir);
      for (var i = 0; i < 8; ++i) {
        inner.overrides['m$i.bin'] = (request) => Response.ok(
          List<int>.filled(300 * 1024, i),
          headers: {'content-type': 'application/octet-stream'},
        );
      }

      var handler = cache.middleware(inner.call);

      for (var i = 0; i < 8; ++i) {
        var r = await handler(_get('m$i.bin'));
        expect(r.statusCode, equals(200));
      }

      expect(inner.calls, equals(8));
      expect(cache.totalMemorySize, lessThanOrEqualTo(1024 * 1024 * 1.5));
      expect(cache.cachedResponsesLength, lessThan(8));
      expect(cache.toString(), contains('fileStatTimeout: 2 d'));
    });

    test('multi-value headers + previous server-timing', () async {
      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      inner.overrides['h.txt'] = (request) => Response.ok(
        utf8.encode('Hello H'),
        headers: {
          'content-type': 'text/plain',
          'x-multi': ['a', 'b'],
          'x-empty': <String>[],
          'server-timing': 'gzip;dur=1, API-Server-Response;dur=5',
        },
      );

      var handler = cache.middleware(inner.call);

      var r1 = await handler(_get('h.txt'));
      expect(await _readBody(r1), equals('Hello H'));
      expect(r1.headersAll['x-multi'], equals(['a', 'b']));

      var r2 = await handler(_get('h.txt'));
      expect(inner.calls, equals(1));
      expect(await _readBody(r2), equals('Hello H'));
      expect(r2.headersAll['x-multi'], equals(['a', 'b']));
      // The previous entries are kept and the `API-Server-Response` entry is
      // replaced (not appended):
      var serverTiming = r2.headers['server-timing']!;
      expect(serverTiming, startsWith('gzip;dur=1,'));
      expect(
        'API-Server-Response;dur='.allMatches(serverTiming).length,
        equals(1),
      );
    });

    test('toString units', () {
      expect(
        APIServerResponseCache(fileStatTimeout: Duration(hours: 3)).toString(),
        contains('fileStatTimeout: 3 h'),
      );
      expect(
        APIServerResponseCache(
          fileStatTimeout: Duration(seconds: 7),
        ).toString(),
        contains('fileStatTimeout: 7 sec'),
      );
      expect(
        APIServerResponseCache(
          fileStatTimeout: Duration(milliseconds: 7),
        ).toString(),
        contains('fileStatTimeout: 7.000 ms'),
      );
      expect(
        APIServerResponseCache(maxContentLength: 2048).toString(),
        contains('maxContentLength: 2.0 KB'),
      );
      expect(
        APIServerResponseCache(maxContentLength: 100).toString(),
        contains('maxContentLength: 100 bytes'),
      );
    });
  });
}

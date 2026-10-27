@TestOn('vm')
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bones_api/src/bones_api_server_cache.dart';
import 'package:bones_api/src/bones_api_utils_compression.dart';
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

/// A top-level function: sendable to the `Isolate` of
/// [APIBrotli.encodeAsync].
Uint8List _failingBrotliEncoder(Uint8List bytes, int quality) =>
    throw StateError('Simulated Brotli encoder failure');

Future<String> _readBody(Response response) async {
  var bytes = await response.read().expand((e) => e).toList();
  switch (response.headers['content-encoding']) {
    case 'gzip':
      bytes = gzip.decode(bytes);
    case 'br':
      bytes = APIBrotli.decode(Uint8List.fromList(bytes));
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

    test('br alternatives (compress)', () async {
      var content = List.generate(200, (i) => 'line $i').join('\n');
      writeFile('big.txt', content);

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      var r1 = await handler(_get('big.txt'));
      expect(r1.headers['content-encoding'], isNull);
      expect(await _readBody(r1), equals(content));
      expect(inner.calls, equals(1));

      // Prefers `br` (server order) when both are accepted:
      var r2 = await handler(
        _get('big.txt', headers: {'accept-encoding': 'gzip, deflate, br'}),
      );
      expect(r2.headers['content-encoding'], equals('br'));
      expect(r2.headers['vary'], contains('Accept-Encoding'));
      expect(
        int.parse(r2.headers['content-length']!),
        lessThan(content.length),
      );
      expect(await _readBody(r2), equals(content));

      var r3 = await handler(
        _get('big.txt', headers: {'accept-encoding': 'gzip'}),
      );
      expect(r3.headers['content-encoding'], equals('gzip'));
      expect(await _readBody(r3), equals(content));

      // A higher `q` wins over the server order:
      var r4 = await handler(
        _get('big.txt', headers: {'accept-encoding': 'br;q=0.5, gzip'}),
      );
      expect(r4.headers['content-encoding'], equals('gzip'));

      // All the variants are cached:
      var r5 = await handler(
        _get('big.txt', headers: {'accept-encoding': 'br'}),
      );
      expect(r5.headers['content-encoding'], equals('br'));
      expect(await _readBody(r5), equals(content));

      var r6 = await handler(_get('big.txt'));
      expect(r6.headers['content-encoding'], isNull);
      expect(await _readBody(r6), equals(content));

      expect(inner.calls, equals(1));
    });

    test('alternatives: `q=0` and `identity`', () async {
      var content = List.generate(200, (i) => 'line $i').join('\n');
      writeFile('big.txt', content);

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      var r1 = await handler(
        _get('big.txt', headers: {'accept-encoding': 'br;q=0, gzip;q=0'}),
      );
      expect(r1.headers['content-encoding'], isNull);
      expect(await _readBody(r1), equals(content));

      // `*` accepts `br`, but `gzip` is excluded:
      var r2 = await handler(
        _get('big.txt', headers: {'accept-encoding': '*, gzip;q=0'}),
      );
      expect(r2.headers['content-encoding'], equals('br'));
      expect(await _readBody(r2), equals(content));

      // Not a substring match (`gzip` is not `x-gzip-foo`):
      var r3 = await handler(
        _get('big.txt', headers: {'accept-encoding': 'x-gzip-foo'}),
      );
      expect(r3.headers['content-encoding'], isNull);

      expect(inner.calls, equals(1));
    });

    test('alternatives: gzip transcoded to br', () async {
      var content = List.generate(200, (i) => 'row $i').join('\n');
      var compressed = gzip.encode(utf8.encode(content));

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      inner.overrides['gz.txt'] = (request) => Response.ok(
        compressed,
        headers: {
          'content-type': 'text/plain',
          'content-encoding': 'gzip',
          'X-Compression-Ratio': '0.1 (1/10)',
          'server': 'fake',
        },
      );

      var handler = cache.middleware(inner.call);

      var r1 = await handler(
        _get('gz.txt', headers: {'accept-encoding': 'gzip'}),
      );
      expect(r1.headers['content-encoding'], equals('gzip'));
      expect(inner.calls, equals(1));

      var r2 = await handler(
        _get('gz.txt', headers: {'accept-encoding': 'br, gzip'}),
      );
      expect(r2.headers['content-encoding'], equals('br'));
      // The stale ratio of the original encoding is not copied:
      expect(r2.headers['x-compression-ratio'], isNull);
      expect(await _readBody(r2), equals(content));
      expect(inner.calls, equals(1));

      // A cached `br` alternative decompressed for a client without encodings:
      var cache2 = APIServerResponseCache();
      var handler2 = cache2.middleware(inner.call);
      await handler2(_get('gz.txt', headers: {'accept-encoding': 'br'}));
      var r3 = await handler2(_get('gz.txt'));
      expect(r3.headers['content-encoding'], isNull);
      expect(await _readBody(r3), equals(content));
    });

    test('alternatives: Brotli encoder failure', () async {
      APIBrotli.encoder = _failingBrotliEncoder;
      addTearDown(() => APIBrotli.encoder = APIBrotli.defaultEncoder);

      var small = List.generate(200, (i) => 'line $i').join('\n');
      writeFile('small.txt', small);

      // Over `APIBrotli.isolateMinLength(9)`: fails in the `Isolate`.
      var large = List.generate(
        30000,
        (i) => 'row $i: ${i * 7919 % 10007}',
      ).join('\n');
      expect(large.length, greaterThan(APIBrotli.isolateMinLength(9)));
      writeFile('large.txt', large);

      for (var (path, content) in [
        ('small.txt', small),
        ('large.txt', large),
      ]) {
        var cache = APIServerResponseCache();
        var inner = _FakeStaticHandler(tmpDir);
        var handler = cache.middleware(inner.call);

        await handler(_get(path));
        expect(inner.calls, equals(1), reason: path);

        // `br` fails: not cached, from the inner handler:
        var r1 = await handler(
          _get(path, headers: {'accept-encoding': 'br, gzip'}),
        );
        expect(r1.headers['content-encoding'], isNull, reason: path);
        expect(await _readBody(r1), equals(content));
        expect(inner.calls, equals(2), reason: path);

        // Not retried: the next accepted encoding (`gzip`), from the cache:
        var r2 = await handler(
          _get(path, headers: {'accept-encoding': 'br, gzip'}),
        );
        expect(r2.headers['content-encoding'], equals('gzip'), reason: path);
        expect(await _readBody(r2), equals(content));

        // Only `br` accepted: the uncompressed entry, from the cache:
        var r3 = await handler(_get(path, headers: {'accept-encoding': 'br'}));
        expect(r3.headers['content-encoding'], isNull, reason: path);
        expect(await _readBody(r3), equals(content));

        expect(inner.calls, equals(2), reason: path);
      }
    });

    test('alternatives: a failed conversion is not retried', () async {
      // Not valid GZip data: the conversion to `br` fails (it can't be
      // decompressed), and the content is no longer taken as convertible.
      var invalidGzip = List<int>.generate(2000, (i) => i & 0xFF);

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      inner.overrides['bad.txt'] = (request) => Response.ok(
        invalidGzip,
        headers: {
          'content-type': 'text/plain',
          'content-encoding': 'gzip',
          'server': 'fake',
        },
      );

      var handler = cache.middleware(inner.call);

      var r1 = await handler(
        _get('bad.txt', headers: {'accept-encoding': 'gzip'}),
      );
      expect(r1.headers['content-encoding'], equals('gzip'));
      expect(inner.calls, equals(1));

      // Prefers `br`: the conversion fails, so the inner handler is called
      // once more, then the cached `gzip` entry is used:
      for (var i = 0; i < 3; ++i) {
        var r = await handler(
          _get('bad.txt', headers: {'accept-encoding': 'br, gzip'}),
        );
        expect(r.headers['content-encoding'], equals('gzip'));
        expect(await r.read().expand((e) => e).toList(), equals(invalidGzip));
      }
      expect(inner.calls, equals(2));
    });

    test('404: compressed body', () async {
      var body = utf8.encode('Not Found! ' * 200);
      var compressed = APIBrotli.encode(Uint8List.fromList(body))!;

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      inner.overrides['nf.txt'] = (request) {
        var accepts =
            request.headers['accept-encoding']?.contains('br') ?? false;
        return Response.notFound(
          accepts ? compressed : body,
          headers: {
            'content-type': 'text/plain',
            'server': 'fake',
            if (accepts) 'content-encoding': 'br',
          },
          context: {'file_not_found': File('${tmpDir.path}/nf.txt')},
        );
      };

      var handler = cache.middleware(inner.call);

      var r1 = await handler(
        _get('nf.txt', headers: {'accept-encoding': 'br'}),
      );
      expect(r1.statusCode, equals(404));
      expect(r1.headers['content-encoding'], equals('br'));
      expect(inner.calls, equals(1));

      // Cached: keeps the `Content-Encoding`:
      var r2 = await handler(
        _get('nf.txt', headers: {'accept-encoding': 'br'}),
      );
      expect(r2.statusCode, equals(404));
      expect(r2.headers['content-encoding'], equals('br'));
      expect(r2.headers['vary'], equals('Accept-Encoding'));
      expect(await _readBody(r2), equals(utf8.decode(body)));
      expect(inner.calls, equals(1));

      // Not accepted: not served from the compressed cached entry:
      var r3 = await handler(_get('nf.txt'));
      expect(r3.statusCode, equals(404));
      expect(r3.headers['content-encoding'], isNull);
      expect(await _readBody(r3), equals(utf8.decode(body)));
      expect(inner.calls, equals(2));
    });

    test('alternatives: 304 and memory accounting', () async {
      var content = List.generate(300, (i) => 'line $i').join('\n');
      writeFile('alt.txt', content);

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      var r0 = await handler(_get('alt.txt'));
      var lastModified = r0.headers['last-modified']!;
      // 200 + 304:
      expect(cache.cachedResponsesLength, equals(2));
      var memory0 = cache.totalMemorySize;

      // The `br` and `gzip` alternatives: added to the same 200 entry,
      // their memory counted.
      var rBr = await handler(
        _get('alt.txt', headers: {'accept-encoding': 'br'}),
      );
      expect(rBr.headers['content-encoding'], equals('br'));
      var memoryBr = cache.totalMemorySize;
      expect(memoryBr, greaterThan(memory0));

      var rGz = await handler(
        _get('alt.txt', headers: {'accept-encoding': 'gzip'}),
      );
      expect(rGz.headers['content-encoding'], equals('gzip'));
      expect(cache.totalMemorySize, greaterThan(memoryBr));
      expect(cache.cachedResponsesLength, equals(2));

      // Served again: nothing new.
      var memory = cache.totalMemorySize;
      for (var encoding in ['br', 'gzip', 'identity']) {
        var r = await handler(
          _get('alt.txt', headers: {'accept-encoding': encoding}),
        );
        expect(await _readBody(r), equals(content), reason: encoding);
      }
      expect(cache.totalMemorySize, equals(memory));
      expect(inner.calls, equals(1));

      // 304, whatever the `Accept-Encoding`:
      for (var encoding in ['br', 'gzip', '']) {
        var r304 = await handler(
          _get(
            'alt.txt',
            headers: {
              'if-modified-since': lastModified,
              if (encoding.isNotEmpty) 'accept-encoding': encoding,
            },
          ),
        );
        expect(r304.statusCode, equals(304), reason: encoding);
        expect(r304.headers['content-encoding'], isNull, reason: encoding);
      }
      expect(inner.calls, equals(1));

      cache.clear();
      expect(cache.totalMemorySize, equals(0));
    });

    test('alternatives: unsupported encoding (`deflate`)', () async {
      var content = List.generate(200, (i) => 'row $i').join('\n');
      var deflated = ZLibEncoder().convert(utf8.encode(content));

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      inner.overrides['df.txt'] = (request) => Response.ok(
        deflated,
        headers: {
          'content-type': 'text/plain',
          'content-encoding': 'deflate',
          'server': 'fake',
        },
      );

      var handler = cache.middleware(inner.call);

      var r1 = await handler(
        _get('df.txt', headers: {'accept-encoding': 'deflate'}),
      );
      expect(r1.headers['content-encoding'], equals('deflate'));
      expect(inner.calls, equals(1));

      // Can't be converted: not served from the cache.
      for (var encoding in ['br', 'gzip', 'br, gzip']) {
        var r = await handler(
          _get('df.txt', headers: {'accept-encoding': encoding}),
        );
        expect(r.headers['content-encoding'], equals('deflate'));
      }
      expect(inner.calls, equals(4));

      // Still served from the cache when accepted (even if `br` is
      // preferred, since it can't be converted):
      for (var encoding in ['deflate', 'br, deflate', 'gzip, deflate']) {
        var r = await handler(
          _get('df.txt', headers: {'accept-encoding': encoding}),
        );
        expect(r.headers['content-encoding'], equals('deflate'));
        expect(await r.read().expand((e) => e).toList(), equals(deflated));
      }
      expect(inner.calls, equals(4));
    });

    test('alternatives: large br, encoded in an `Isolate`', () async {
      var content = List.generate(
        30000,
        (i) => 'row $i: ${i * 7919 % 10007}',
      ).join('\n');
      expect(content.length, greaterThan(APIBrotli.isolateMinLength(9)));
      writeFile('large.txt', content);

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      var r0 = await handler(_get('large.txt'));
      expect(r0.headers['content-encoding'], isNull);
      expect(inner.calls, equals(1));

      // Concurrent requests: one `br` alternative, encoded once:
      var responses = await Future.wait([
        for (var i = 0; i < 4; ++i)
          Future.sync(
            () =>
                handler(_get('large.txt', headers: {'accept-encoding': 'br'})),
          ),
      ]);

      for (var r in responses) {
        expect(r.headers['content-encoding'], equals('br'));
        expect(await _readBody(r), equals(content));
      }
      expect(inner.calls, equals(1));

      var brEntries = cache.cachedResponsesLength;

      var r2 = await handler(
        _get('large.txt', headers: {'accept-encoding': 'br'}),
      );
      expect(r2.headers['content-encoding'], equals('br'));
      expect(cache.cachedResponsesLength, equals(brEntries));
      expect(inner.calls, equals(1));
    });

    test('alternatives: not cached if removed while encoding', () async {
      var content = List.generate(
        30000,
        (i) => 'row $i: ${i * 7919 % 10007}',
      ).join('\n');
      writeFile('rm.txt', content);

      var cache = APIServerResponseCache();
      var inner = _FakeStaticHandler(tmpDir);
      var handler = cache.middleware(inner.call);

      await handler(_get('rm.txt'));
      expect(inner.calls, equals(1));

      // Starts the `br` encoding (asynchronous), then clears the cache
      // (as an expiration would):
      var rBr = Future.sync(
        () => handler(_get('rm.txt', headers: {'accept-encoding': 'br'})),
      );
      await Future<void>.delayed(Duration.zero);
      cache.clear();

      var r = await rBr;
      expect(r.headers['content-encoding'], equals('br'));
      expect(await _readBody(r), equals(content));

      // The `br` alternative was not added after the entry was removed:
      expect(cache.cachedResponsesLength, equals(0));
    });

    test('isCacheable', () {
      var cache = APIServerResponseCache(maxContentLength: 100);

      expect(cache.isCacheable(_get('a'), Response.ok('x' * 100)), isTrue);
      expect(cache.isCacheable(_get('a'), Response.ok('x' * 101)), isFalse);

      // A response compressed by `compressResponse`: its uncompressed length.
      expect(
        cache.isCacheable(
          _get('a'),
          Response.ok('x' * 50, context: {uncompressedLengthContextKey: 101}),
        ),
        isFalse,
      );
      expect(
        cache.isCacheable(
          _get('a'),
          Response.ok('x' * 50, context: {uncompressedLengthContextKey: 100}),
        ),
        isTrue,
      );
      expect(
        cache.isCacheable(_get('a', method: 'POST'), Response.ok('x')),
        isFalse,
      );
      expect(cache.isCacheable(_get('a'), Response.notFound('x')), isFalse);
      expect(
        cache.isCacheable(
          _get('a'),
          Response.ok(
            Stream<List<int>>.fromIterable([
              [1],
            ]),
          ),
        ),
        isFalse,
      );
    });

    test('compression middleware: same cacheability as the cache', () async {
      // Over `maxContentLength` uncompressed, under it compressed:
      var content = List.generate(400, (i) => 'line ${i % 10}').join('\n');
      writeFile('edge.txt', content);

      var cache = APIServerResponseCache(maxContentLength: 2000);
      expect(content.length, greaterThan(cache.maxContentLength));

      var inner = _FakeStaticHandler(tmpDir);

      var resolved = <int>[];
      var handler = const Pipeline()
          .addMiddleware(cache.middleware)
          .addMiddleware(
            createCompressionMiddleware(
              resolveCompression: (request, response) {
                var cacheable = cache.isCacheable(request, response);
                var q = cacheable ? 9 : 5;
                resolved.add(q);
                return APIResponseCompression(brotliQuality: q);
              },
            ),
          )
          .addHandler(inner.call);

      for (var i = 0; i < 2; ++i) {
        var r = await handler(
          _get('edge.txt', headers: {'accept-encoding': 'br'}),
        );
        expect(r.headers['content-encoding'], equals('br'));
        expect(r.contentLength, lessThan(cache.maxContentLength));
        expect(await _readBody(r), equals(content));
      }

      // Not cached (the q5 response is not kept): compressed each time.
      expect(resolved, equals([5, 5]));
      expect(inner.calls, equals(2));
      expect(cache.cachedResponsesLength, equals(0));
    });

    test('alternatives: custom compression', () async {
      var content = List.generate(200, (i) => 'line $i').join('\n');
      writeFile('big.txt', content);

      var inner = _FakeStaticHandler(tmpDir);

      // Compression disabled:
      var cacheNone = APIServerResponseCache(
        compression: APIResponseCompression.none,
      );
      var handlerNone = cacheNone.middleware(inner.call);
      await handlerNone(_get('big.txt'));

      var r1 = await handlerNone(
        _get('big.txt', headers: {'accept-encoding': 'br, gzip'}),
      );
      expect(r1.headers['content-encoding'], isNull);

      // Only `gzip`:
      var cacheGzip = APIServerResponseCache(
        compression: APIResponseCompression(
          encodings: [APIContentEncoding.gzip],
        ),
      );
      var handlerGzip = cacheGzip.middleware(inner.call);
      await handlerGzip(_get('big.txt'));

      var r2 = await handlerGzip(
        _get('big.txt', headers: {'accept-encoding': 'br, gzip'}),
      );
      expect(r2.headers['content-encoding'], equals('gzip'));
      expect(await _readBody(r2), equals(content));

      var r3 = await handlerGzip(
        _get('big.txt', headers: {'accept-encoding': 'br'}),
      );
      expect(r3.headers['content-encoding'], isNull);
      expect(await _readBody(r3), equals(content));
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
      expect(serverTiming, startsWith('gzip;dur=1, API-Server-Response;dur='));
      expect(serverTiming, isNot(contains(',,')));
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
        APIServerResponseCache(fileStatTimeout: Duration(seconds: 7))
            .toString(),
        contains('fileStatTimeout: 7 sec'),
      );
      expect(
        APIServerResponseCache(fileStatTimeout: Duration(milliseconds: 7))
            .toString(),
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

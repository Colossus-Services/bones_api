@TestOn('vm')
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bones_api/src/bones_api_utils_compression.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Uint8List _textBytes([int lines = 200]) =>
    utf8.encode(List.generate(lines, (i) => 'line $i: hello world').join('\n'));

Request _get({String? acceptEncoding}) => Request(
  'GET',
  Uri.parse('http://localhost/x'),
  headers: {'accept-encoding': ?acceptEncoding},
);

Future<Uint8List> _read(Response response) async {
  var b = BytesBuilder(copy: false);
  await for (var chunk in response.read()) {
    b.add(chunk);
  }
  return b.takeBytes();
}

void main() {
  group('APIContentEncoding', () {
    test('parse', () {
      expect(APIContentEncoding.parse('br'), equals(APIContentEncoding.br));
      expect(APIContentEncoding.parse(' BR '), equals(APIContentEncoding.br));
      expect(APIContentEncoding.parse('brotli'), equals(APIContentEncoding.br));
      expect(APIContentEncoding.parse('gzip'), equals(APIContentEncoding.gzip));
      expect(
        APIContentEncoding.parse('x-gzip'),
        equals(APIContentEncoding.gzip),
      );
      expect(
        APIContentEncoding.parse(APIContentEncoding.gzip),
        equals(APIContentEncoding.gzip),
      );
      expect(APIContentEncoding.parse('deflate'), isNull);
      expect(APIContentEncoding.parse(''), isNull);
      expect(APIContentEncoding.parse(null), isNull);
    });

    test('parseList', () {
      expect(APIContentEncoding.parseList(null), isNull);
      expect(APIContentEncoding.parseList(''), isEmpty);
      expect(APIContentEncoding.parseList([]), isEmpty);
      expect(
        APIContentEncoding.parseList('gzip, br'),
        equals([APIContentEncoding.gzip, APIContentEncoding.br]),
      );
      expect(
        APIContentEncoding.parseList(['br', 'deflate', 'BR', 'gzip']),
        equals([APIContentEncoding.br, APIContentEncoding.gzip]),
      );
    });

    test('headerValue', () {
      expect(APIContentEncoding.br.headerValue, equals('br'));
      expect(APIContentEncoding.gzip.headerValue, equals('gzip'));
      expect(
        APIContentEncoding.defaultEncodings,
        equals([APIContentEncoding.br, APIContentEncoding.gzip]),
      );
    });
  });

  group('Accept-Encoding', () {
    test('parseAcceptEncoding', () {
      expect(parseAcceptEncoding(null), isEmpty);
      expect(parseAcceptEncoding('  '), isEmpty);
      expect(
        parseAcceptEncoding('gzip, deflate, br'),
        equals({'gzip': 1.0, 'deflate': 1.0, 'br': 1.0}),
      );
      expect(
        parseAcceptEncoding('BR;q=0.8, gzip; Q=0.5 ,*;q=0'),
        equals({'br': 0.8, 'gzip': 0.5, '*': 0.0}),
      );
      // Clamped, invalid `q` ignored, highest repeated kept, empty skipped:
      expect(
        parseAcceptEncoding('br;q=2, gzip;q=abc, ,deflate;q=0.1,deflate;q=0.3'),
        equals({'br': 1.0, 'deflate': 0.3}),
      );
      // Other parameters are ignored:
      expect(parseAcceptEncoding('br;level=1;q=0.4'), equals({'br': 0.4}));
      // `x-gzip` is `gzip`:
      expect(parseAcceptEncoding('x-gzip'), equals({'gzip': 1.0}));
      expect(
        parseAcceptEncoding('gzip;q=0.2, x-gzip;q=0.6'),
        equals({'gzip': 0.6}),
      );
    });

    test('x-gzip', () {
      expect(acceptsContentEncoding('x-gzip', 'gzip'), isTrue);
      expect(acceptsContentEncoding('gzip', 'x-gzip'), isTrue);
      expect(
        resolveContentEncoding('x-gzip', APIContentEncoding.defaultEncodings),
        equals(APIContentEncoding.gzip),
      );
      expect(
        resolveContentEncodingFrom({
          'gzip': 1.0,
        }, APIContentEncoding.defaultEncodings),
        equals(APIContentEncoding.gzip),
      );
      expect(
        const APIResponseCompression().resolveAcceptedEncoding({'br': 0.5}),
        equals(APIContentEncoding.br),
      );
    });

    test('acceptsContentEncoding', () {
      expect(acceptsContentEncoding('gzip, br', 'br'), isTrue);
      expect(acceptsContentEncoding('gzip, br', 'BR'), isTrue);
      expect(acceptsContentEncoding('gzip', 'br'), isFalse);
      expect(acceptsContentEncoding('br;q=0', 'br'), isFalse);
      expect(acceptsContentEncoding('*', 'br'), isTrue);
      expect(acceptsContentEncoding('*, br;q=0', 'br'), isFalse);
      // Not a substring match:
      expect(acceptsContentEncoding('x-brotli', 'br'), isFalse);
      expect(acceptsContentEncoding(null, 'gzip'), isFalse);
    });

    test('resolveContentEncoding', () {
      const all = APIContentEncoding.defaultEncodings;

      expect(resolveContentEncoding(null, all), isNull);
      expect(resolveContentEncoding('', all), isNull);
      expect(resolveContentEncoding('identity', all), isNull);
      expect(resolveContentEncoding('deflate', all), isNull);

      expect(
        resolveContentEncoding('gzip, deflate, br', all),
        equals(APIContentEncoding.br),
      );
      expect(
        resolveContentEncoding('gzip', all),
        equals(APIContentEncoding.gzip),
      );
      expect(
        resolveContentEncoding('br;q=0.5, gzip', all),
        equals(APIContentEncoding.gzip),
      );
      expect(resolveContentEncoding('br;q=0, gzip;q=0', all), isNull);
      expect(resolveContentEncoding('*', all), equals(APIContentEncoding.br));
      expect(
        resolveContentEncoding('*;q=0.1, gzip;q=0.2', all),
        equals(APIContentEncoding.gzip),
      );

      // Tie: the server order wins:
      expect(
        resolveContentEncoding('br, gzip', [
          APIContentEncoding.gzip,
          APIContentEncoding.br,
        ]),
        equals(APIContentEncoding.gzip),
      );

      // Only the available ones:
      expect(resolveContentEncoding('br', [APIContentEncoding.gzip]), isNull);
      expect(resolveContentEncoding('br, gzip', []), isNull);
    });
  });

  group('APIBrotli', () {
    test('encode/decode', () {
      var data = _textBytes();

      for (var q in [0, 1, 5, 9, 11, -1, 99]) {
        var encoded = APIBrotli.encode(data, quality: q)!;
        expect(encoded.length, lessThan(data.length), reason: 'q: $q');
        expect(APIBrotli.decode(encoded), equals(data), reason: 'q: $q');
      }

      var empty = APIBrotli.encode(Uint8List(0))!;
      expect(APIBrotli.decode(empty), isEmpty);
    });

    test('decode: maxOutputSize', () {
      var data = _textBytes();
      var encoded = APIBrotli.encode(data)!;

      expect(
        APIBrotli.decode(encoded, maxOutputSize: data.length),
        equals(data),
      );

      expect(
        () => APIBrotli.decode(encoded, maxOutputSize: data.length - 1),
        throwsFormatException,
      );
    });

    test('decode: maxOutputSize above the last buffer doubling', () {
      // The decoder buffer doubles from ~1 MB: 1, 2, 4 MB... A 4.5 MB output
      // under a 5 MB limit needs the last step to grow up to the limit.
      var data = Uint8List(1024 * 1024 * 9 ~/ 2);
      for (var i = 0; i < data.length; ++i) {
        data[i] = (i * 31 + (i >> 9)) & 0xFF;
      }
      var encoded = APIBrotli.encode(data, quality: 1)!;

      expect(
        APIBrotli.decode(encoded, maxOutputSize: 1024 * 1024 * 5),
        equals(data),
      );
      expect(
        APIBrotli.decode(encoded, maxOutputSize: data.length),
        equals(data),
      );
      expect(
        () => APIBrotli.decode(encoded, maxOutputSize: data.length - 1),
        throwsFormatException,
      );
    });

    test('decode: corrupted', () {
      expect(() => APIBrotli.decode(_textBytes(5)), throwsFormatException);
    });

    test('interoperability with the `brotli` CLI', () async {
      var data = _textBytes(2000);
      var encoded = APIBrotli.encode(data)!;

      var tmp = await Directory.systemTemp.createTemp('bones_api_brotli_');
      try {
        var file = File('${tmp.path}/data.br')..writeAsBytesSync(encoded);

        var decoded = await Process.run('brotli', [
          '-dc',
          file.path,
        ], stdoutEncoding: null);
        expect(decoded.exitCode, equals(0));
        expect(decoded.stdout, equals(data));

        var raw = File('${tmp.path}/raw.txt')..writeAsBytesSync(data);
        var cliEncoded = await Process.run('brotli', [
          '-c',
          raw.path,
        ], stdoutEncoding: null);
        expect(cliEncoded.exitCode, equals(0));
        expect(
          APIBrotli.decode(Uint8List.fromList(cliEncoded.stdout)),
          equals(data),
        );
      } finally {
        await tmp.delete(recursive: true);
      }
    }, skip: _hasBrotliCLI() ? false : 'No `brotli` CLI in the PATH');
  });

  group('encodeContent/decodeContent', () {
    test('round trip', () {
      var data = _textBytes();

      for (var encoding in APIContentEncoding.values) {
        var encoded = encodeContent(data, encoding)!;
        expect(encoded.length, lessThan(data.length));
        expect(decodeContent(encoded, encoding), equals(data));
      }

      expect(
        gzip.decode(encodeContent(data, APIContentEncoding.gzip)!),
        equals(data),
      );
    });

    test('decodeContent: maxOutputSize (br)', () {
      var data = _textBytes();
      var encoded = encodeContent(data, APIContentEncoding.br)!;
      expect(
        () => decodeContent(encoded, APIContentEncoding.br, maxOutputSize: 10),
        throwsFormatException,
      );
    });
  });

  group('APIResponseCompression', () {
    test('basic', () {
      const c = APIResponseCompression();
      expect(c.isEnabled, isTrue);
      expect(c.encodings, equals(APIContentEncoding.defaultEncodings));
      expect(c.gzipLevel, equals(4));
      expect(c.brotliQuality, equals(5));
      expect(c.minLength, equals(512));
      expect(APIResponseCompression.none.isEnabled, isFalse);

      expect(c.resolveEncoding('gzip, br'), equals(APIContentEncoding.br));
      expect(
        c.resolveRequestEncoding(_get(acceptEncoding: 'gzip')),
        equals(APIContentEncoding.gzip),
      );
      expect(c.resolveRequestEncoding(_get()), isNull);
      expect(APIResponseCompression.none.resolveEncoding('br'), isNull);

      var data = _textBytes();
      expect(
        APIBrotli.decode(c.encode(data, APIContentEncoding.br)!),
        equals(data),
      );
    });

    test('copyWith / == / toString', () {
      const c = APIResponseCompression();
      var c2 = c.copyWith(brotliQuality: 9, gzipLevel: 7, minLength: 10);
      expect(c2.brotliQuality, equals(9));
      expect(c2.gzipLevel, equals(7));
      expect(c2.minLength, equals(10));
      expect(c2.encodings, equals(c.encodings));

      expect(c.copyWith(), equals(c));
      expect(c.copyWith().hashCode, equals(c.hashCode));
      expect(c2, isNot(equals(c)));
      expect(
        c.copyWith(encodings: [APIContentEncoding.gzip]),
        isNot(equals(c)),
      );

      expect(c.toString(), contains('encodings: [br, gzip]'));
    });
  });

  group('mergeVaryHeader', () {
    test('basic', () {
      expect(mergeVaryHeader(null, 'Accept-Encoding'), 'Accept-Encoding');
      expect(mergeVaryHeader('', 'Accept-Encoding'), 'Accept-Encoding');
      expect(mergeVaryHeader('*', 'Accept-Encoding'), '*');
      expect(
        mergeVaryHeader('Origin', 'Accept-Encoding'),
        'Origin, Accept-Encoding',
      );
      expect(
        mergeVaryHeader('origin, accept-encoding', 'Accept-Encoding'),
        'origin, accept-encoding',
      );
      expect(
        mergeVaryHeader(['Origin', 'Cookie'], 'Accept-Encoding'),
        'Origin, Cookie, Accept-Encoding',
      );
      expect(mergeVaryHeader('a,, b', 'c'), 'a, b, c');
    });
  });

  group('compressResponse', () {
    Response textResponse(
      List<int> body, {
      String contentType = 'text/plain',
      Map<String, String>? headers,
    }) =>
        Response.ok(body, headers: {'content-type': contentType, ...?headers});

    test('br', () async {
      var data = _textBytes();

      var r = await compressResponse(
        _get(acceptEncoding: 'gzip, br'),
        textResponse(data, headers: {'server-timing': 'prev;dur=1'}),
      );

      expect(r.headers['content-encoding'], equals('br'));
      expect(r.headers['vary'], equals('Accept-Encoding'));
      expect(
        r.headers['x-compression-ratio'],
        matches(r'^0\.\d+ \(\d+/\d+\)$'),
      );
      expect(r.headers['server-timing'], startsWith('prev;dur=1,br;dur='));

      var body = await _read(r);
      expect(r.contentLength, equals(body.length));
      expect(APIBrotli.decode(body), equals(data));
    });

    test('gzip', () async {
      var data = _textBytes();

      var r = await compressResponse(
        _get(acceptEncoding: 'gzip'),
        textResponse(data, headers: {'vary': 'Origin'}),
        addServerTiming: false,
        addCompressionRatioHeader: false,
      );

      expect(r.headers['content-encoding'], equals('gzip'));
      expect(r.headers['vary'], equals('Origin, Accept-Encoding'));
      expect(r.headers['x-compression-ratio'], isNull);
      expect(r.headers['server-timing'], isNull);
      expect(gzip.decode(await _read(r)), equals(data));
    });

    test('not accepted: only `Vary`', () async {
      var data = _textBytes();

      var r = await compressResponse(_get(), textResponse(data));
      expect(r.headers['content-encoding'], isNull);
      expect(r.headers['vary'], equals('Accept-Encoding'));
      expect(await _read(r), equals(data));
    });

    test('not compressible: unchanged', () async {
      var data = _textBytes();
      var req = _get(acceptEncoding: 'br, gzip');

      // Too small:
      var small = textResponse(utf8.encode('small'));
      expect(await compressResponse(req, small), same(small));

      // Already compressed `Content-Type`:
      var png = textResponse(data, contentType: 'image/png');
      expect(await compressResponse(req, png), same(png));

      // Already with a `Content-Encoding`:
      var encoded = textResponse(data, headers: {'content-encoding': 'gzip'});
      expect(await compressResponse(req, encoded), same(encoded));

      // Partial content / no full body:
      var partial = Response(
        206,
        body: data,
        headers: {
          'content-type': 'text/plain',
          'content-range': 'bytes 0-${data.length - 1}/${data.length * 2}',
        },
      );
      expect(await compressResponse(req, partial), same(partial));

      var range = Response.ok(
        data,
        headers: {'content-type': 'text/plain', 'content-range': 'bytes */1'},
      );
      expect(await compressResponse(req, range), same(range));

      var notModified = Response.notModified();
      expect(await compressResponse(req, notModified), same(notModified));

      // Error responses with a full body are compressed:
      var notFound = Response.notFound(
        data,
        headers: {'content-type': 'text/plain'},
      );
      var notFoundBr = await compressResponse(req, notFound);
      expect(notFoundBr.statusCode, equals(404));
      expect(notFoundBr.headers['content-encoding'], equals('br'));

      // Disabled:
      var plain = textResponse(data);
      expect(
        await compressResponse(
          req,
          plain,
          compression: APIResponseCompression.none,
        ),
        same(plain),
      );
    });

    test('stream body: small after read', () async {
      var req = _get(acceptEncoding: 'br');

      var r = await compressResponse(
        req,
        Response.ok(
          Stream<List<int>>.fromIterable([
            [1, 2, 3],
          ]),
          headers: {'content-type': 'text/plain'},
        ),
      );
      expect(r.headers['content-encoding'], isNull);
      expect(r.headers['vary'], equals('Accept-Encoding'));
      expect(await _read(r), equals([1, 2, 3]));

      var data = _textBytes();
      var r2 = await compressResponse(
        req,
        Response.ok(
          Stream<List<int>>.fromIterable([
            data.sublist(0, 10),
            data.sublist(10),
          ]),
          headers: {'content-type': 'text/plain'},
        ),
      );
      expect(r2.headers['content-encoding'], equals('br'));
      expect(APIBrotli.decode(await _read(r2)), equals(data));
    });

    test('custom encodings', () async {
      var data = _textBytes();

      var r = await compressResponse(
        _get(acceptEncoding: 'br, gzip'),
        textResponse(data),
        compression: APIResponseCompression(
          encodings: [APIContentEncoding.gzip],
          gzipLevel: 9,
        ),
      );
      expect(r.headers['content-encoding'], equals('gzip'));
      expect(gzip.decode(await _read(r)), equals(data));
    });
  });

  group('createCompressionMiddleware', () {
    test('basic', () async {
      var data = _textBytes();

      var handler = createCompressionMiddleware()(
        (request) =>
            Response.ok(data, headers: {'content-type': 'application/json'}),
      );

      var r1 = await handler(_get(acceptEncoding: 'br'));
      expect(r1.headers['content-encoding'], equals('br'));
      expect(APIBrotli.decode(await _read(r1)), equals(data));

      var r2 = await handler(_get(acceptEncoding: 'gzip'));
      expect(r2.headers['content-encoding'], equals('gzip'));
      expect(gzip.decode(await _read(r2)), equals(data));

      var r3 = await handler(_get());
      expect(r3.headers['content-encoding'], isNull);
      expect(await _read(r3), equals(data));
    });

    test('resolveCompression', () async {
      var data = _textBytes();

      var resolved = <String>[];

      var handler =
          createCompressionMiddleware(
            resolveCompression: (request, response) {
              resolved.add(request.url.path);
              return APIResponseCompression(
                encodings: [APIContentEncoding.gzip],
              );
            },
          )(
            (request) =>
                Response.ok(data, headers: {'content-type': 'text/plain'}),
          );

      var r = await handler(_get(acceptEncoding: 'br, gzip'));
      expect(r.headers['content-encoding'], equals('gzip'));
      expect(resolved, equals(['x']));
    });
  });

  group('defineContentEncodingHeaders', () {
    test('basic', () {
      var headers = <String, dynamic>{'server-timing': 'a;dur=1'};

      defineContentEncodingHeaders(
        headers,
        encoding: APIContentEncoding.br,
        bodyLength: 1000,
        compressedBodyLength: 100,
        compressionCapacity: 128,
        initTime: DateTime.now(),
        serverTimingEntryName: 'obj-json-br',
      );

      expect(headers['content-encoding'], equals('br'));
      expect(headers['content-length'], equals('100'));
      expect(headers['X-Compression-Ratio'], equals('0.1 (100/1000/128)'));
      expect(headers['server-timing'], startsWith('a;dur=1,obj-json-br;dur='));

      var headers2 = <String, dynamic>{};
      defineContentEncodingHeaders(
        headers2,
        encoding: APIContentEncoding.gzip,
        bodyLength: 3,
        compressedBodyLength: 1,
        serverTimingEntryName: 'gzip',
      );
      expect(headers2['X-Compression-Ratio'], equals('0.3333 (1/3)'));
      // No `initTime`:
      expect(headers2['server-timing'], isNull);
    });
  });
}

bool _hasBrotliCLI() {
  try {
    return Process.runSync('brotli', ['--version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

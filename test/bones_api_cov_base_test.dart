@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('APIRequestMethod', () {
    test('name', () {
      expect(
        APIRequestMethod.values.map((e) => e.name).toList(),
        equals(['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS', 'HEAD']),
      );
    });

    test('parseAPIRequestMethod', () {
      expect(parseAPIRequestMethod(null), isNull);
      expect(parseAPIRequestMethod(' get '), equals(APIRequestMethod.GET));
      expect(parseAPIRequestMethod('GET'), equals(APIRequestMethod.GET));
      expect(parseAPIRequestMethod('post'), equals(APIRequestMethod.POST));
      expect(parseAPIRequestMethod('POST'), equals(APIRequestMethod.POST));
      expect(parseAPIRequestMethod('put'), equals(APIRequestMethod.PUT));
      expect(parseAPIRequestMethod('PUT'), equals(APIRequestMethod.PUT));
      expect(parseAPIRequestMethod('delete'), equals(APIRequestMethod.DELETE));
      expect(parseAPIRequestMethod('DELETE'), equals(APIRequestMethod.DELETE));
      expect(parseAPIRequestMethod('patch'), equals(APIRequestMethod.PATCH));
      expect(parseAPIRequestMethod('PATCH'), equals(APIRequestMethod.PATCH));
      expect(
        parseAPIRequestMethod('OPTIONS'),
        equals(APIRequestMethod.OPTIONS),
      );
      expect(parseAPIRequestMethod('head'), equals(APIRequestMethod.HEAD));
      expect(parseAPIRequestMethod('HEAD'), equals(APIRequestMethod.HEAD));
      expect(parseAPIRequestMethod('foo'), isNull);
    });

    test('APIRequesterSource.name', () {
      expect(
        APIRequesterSource.values.map((e) => e.name).toList(),
        equals(['internal', 'local', 'remote', 'unknown']),
      );
    });
  });

  group('APIMetric', () {
    test('equality and toString', () {
      var m1 = APIMetric('db', duration: Duration(milliseconds: 10), n: 2);
      var m2 = APIMetric('db', description: 'other');
      var m3 = APIMetric('cache');

      expect(m1 == m2, isTrue);
      expect(m1 == m3, isFalse);
      expect(m1.hashCode, equals('db'.hashCode));

      expect(
        m1.toString(),
        equals('APIMetric[db]{duration: 0:00:00.010000, n: 2'),
      );
      expect(m2.toString(), equals('APIMetric[db]{description: "other"'));
    });

    test('start/stop metrics', () async {
      var request = APIRequest.get('/a/b');
      expect(request.hasMetrics, isFalse);

      var start = request.startMetric('m1', description: 'desc');
      // Starting again keeps the first start time:
      expect(request.startMetric('m1'), equals(start));
      request.startMetric('m2');

      expect(request.stopMetric('unknown'), isNull);

      var d = request.stopMetric('m1', now: start.add(Duration(seconds: 2)));
      expect(d, equals(Duration(seconds: 2)));
      expect(request.getMetric('m1')?.description, equals('desc'));
      expect(request.hasMetrics, isTrue);

      request.stopAllMetrics();
      expect(request.metrics.keys, containsAll(['m1', 'm2']));

      request.setMetric('m3', n: 3);
      expect(request.getMetric('m3')?.n, equals(3));

      await request.disposeAsync();
      expect(request.hasMetrics, isFalse);
      expect(request.stopMetric('m2'), isNull);
    });
  });

  group('APIRequest', () {
    test('factories', () {
      var cred = APICredential('joe');

      var get = APIRequest.get('/a', credential: cred);
      expect(get.method, equals(APIRequestMethod.GET));
      expect(get.credential, same(cred));
      expect(get.originalCredential, same(cred));

      var post = APIRequest.post(
        '/a',
        payload: '{}',
        payloadMimeType: 'application/json',
      );
      expect(post.method, equals(APIRequestMethod.POST));
      expect(post.payloadMimeType?.isJSON, isTrue);

      var put = APIRequest.put('/a', payloadMimeType: 'text/plain');
      expect(put.method, equals(APIRequestMethod.PUT));
      expect(put.payloadMimeType.toString(), startsWith('text/plain'));

      var del = APIRequest.delete('/a', parameters: {'x': 1});
      expect(del.method, equals(APIRequestMethod.DELETE));
      expect(del.parameters, equals({'x': 1}));

      var patch = APIRequest.patch('/a', headers: {'h': 'v'});
      expect(patch.method, equals(APIRequestMethod.PATCH));
      expect(patch.headers, equals({'h': 'v'}));

      var head = APIRequest.head('/a');
      expect(head.method, equals(APIRequestMethod.HEAD));
      expect(head.hasPayload, isFalse);
      expect(head.payloadLength, equals(-1));

      put.payloadMimeType = 'application/json';
      expect(put.payloadMimeType?.isJSON, isTrue);
    });

    test('requestedUri default', () {
      var r = APIRequest(
        APIRequestMethod.GET,
        '/a/b',
        parameters: {
          'x': 1,
          'l': [1, 2],
        },
        requesterAddress: 'localhost',
      );
      expect(r.requestedUri.path, equals('/a/b'));
      expect(r.requestedUri.queryParametersAll['l'], equals(['1', '2']));
      expect(r.requestedUri.queryParameters['x'], equals('1'));
    });

    test('fromArgsLine', () {
      var r = APIRequest.fromArgsLine(
        '/mod/route --method post --a 1 --header_x_foo bar --query b=2&c=3 --payload abc -flag',
      );
      expect(r.method, equals(APIRequestMethod.POST));
      expect(r.path, equals('/mod/route'));
      expect(r.parameters['a'], equals('1'));
      expect(r.parameters['b'], equals('2'));
      expect(r.parameters['c'], equals('3'));
      expect(r.parameters['flag'], isTrue);
      expect(r.parameters.containsKey('header_x_foo'), isFalse);
      expect(r.headers['x_foo'], equals('bar'));
      expect(r.payload, equals('abc'));

      var r2 = APIRequest.fromArgsLine('/mod/route --m unknown');
      expect(r2.method, equals(APIRequestMethod.GET));
    });

    test('payload', () {
      expect(APIRequest.get('/a').payloadAsBytes, isNull);

      var bytes = Uint8List.fromList([1, 2, 3]);
      expect(APIRequest.get('/a', payload: bytes).payloadAsBytes, same(bytes));
      expect(
        APIRequest.get('/a', payload: [4, 5]).payloadAsBytes,
        equals([4, 5]),
      );
      expect(
        APIRequest.get('/a', payload: 'abc').payloadAsBytes,
        equals(utf8.encode('abc')),
      );

      expect(APIRequest.get('/a', payload: 'abc').payloadLength, equals(3));
      expect(
        APIRequest.get(
          '/a',
          payload: [
            [1, 2],
            [3],
          ],
        ).payloadLength,
        equals(3),
      );
      expect(APIRequest.get('/a', payload: [1, 2]).payloadLength, equals(2));
      expect(APIRequest.get('/a', payload: 12345).payloadLength, equals(5));

      expect(APIPayload.resolveMimeType(null), isNull);
      var mime = MimeType.parse('text/html')!;
      expect(APIPayload.resolveMimeType(mime), same(mime));
      expect(APIPayload.resolveMimeType('application/json')?.isJSON, isTrue);
    });

    test('path parts', () {
      var r = APIRequest.get(' /a/b/c/ ');
      expect(r.pathParts, equals(['a', 'b', 'c']));
      expect(r.pathPartFirst, equals('a'));
      expect(r.pathPartLast, equals('c'));
      expect(r.pathPartAt(1), equals('b'));
      expect(r.pathPartAt(3), isNull);
      expect(r.pathPart(0), equals('a'));
      expect(r.pathPart(5), equals(''));
      expect(r.pathPart(0, reversed: true), equals('c'));
      expect(r.pathPart(2, reversed: true), equals('a'));
      expect(r.pathPartReversed(1), equals('b'));
      expect(r.pathPartReversed(9), equals(''));
      expect(r.lastPathPart, equals('c'));
    });

    test('parameters', () {
      var r = APIRequest.get(
        '/a',
        parameters: {'Name': 'joe', 'age': 10, 'City': 'NY'},
      );

      expect(r.getParameter('Name'), equals('joe'));
      expect(r.getParameter('x', 'def'), equals('def'));

      expect(r.getParameterFirstOf('x', 'age'), equals(10));
      expect(r.getParameterFirstOf('x', 'y', 'Name'), equals('joe'));
      expect(r.getParameterFirstOf('x', 'y', 'z', 'age'), equals(10));
      expect(r.getParameterFirstOf('x', 'y', 'z', 'w', 'age'), equals(10));
      expect(r.getParameterFirstOf('x', 'y', 'z', 'w', 'v', 'age'), equals(10));
      expect(r.getParameterFirstOf('x', 'y', 'z', 'w', 'v', 'u'), isNull);

      expect(r.getParameterIgnoreCase('Name'), equals('joe'));
      expect(r.getParameterIgnoreCase('name'), equals('joe'));
      expect(r.getParameterIgnoreCase('none', 'def'), equals('def'));

      expect(r.getParameterIgnoreCaseFirstOf('age'), equals(10));
      expect(r.getParameterIgnoreCaseFirstOf('NAME'), equals('joe'));
      expect(r.getParameterIgnoreCaseFirstOf('x', 'AGE'), equals(10));
      expect(r.getParameterIgnoreCaseFirstOf('x', 'y', 'city'), equals('NY'));
      expect(
        r.getParameterIgnoreCaseFirstOf('x', 'y', 'z', 'CITY'),
        equals('NY'),
      );
      expect(
        r.getParameterIgnoreCaseFirstOf('x', 'y', 'z', 'w', 'NAME'),
        equals('joe'),
      );
      expect(
        r.getParameterIgnoreCaseFirstOf('x', 'y', 'z', 'w', 'v', 'NAME'),
        equals('joe'),
      );
      expect(
        r.getParameterIgnoreCaseFirstOf('x', 'y', 'z', 'w', 'v', 'u'),
        isNull,
      );
    });

    test('payload parameters', () {
      var r = APIRequest.post('/a', payload: {'Name': 'joe'});
      expect(r.getPayloadParameter('Name'), equals('joe'));
      expect(r.getPayloadParameter('x', 'def'), equals('def'));
      expect(r.getPayloadParameterIgnoreCase('Name'), equals('joe'));
      expect(r.getPayloadParameterIgnoreCase('name'), equals('joe'));
      expect(r.getPayloadParameterIgnoreCase('x', 'def'), equals('def'));

      var r2 = APIRequest.post('/a', payload: 'text');
      expect(r2.getPayloadParameter('x', 'def'), equals('def'));
      expect(r2.getPayloadParameterIgnoreCase('x', 'def'), equals('def'));
    });

    test('headers', () {
      var r = APIRequest.get(
        '/a',
        headers: {
          'Host': 'example.com:8080',
          'X-A': 'a',
          'X-B': 'b',
          'X-C': 'c',
          'X-D': 'd',
          'X-E': 'e',
        },
      );

      expect(r.getHeader('Host'), equals('example.com:8080'));
      expect(r.getHeader(' host '), equals('example.com:8080'));
      expect(r.getHeader('none', def: 'def'), equals('def'));

      expect(r.getHeaderFirstOf('X-A'), equals('a'));
      expect(r.getHeaderFirstOf('n', 'X-B'), equals('b'));
      expect(r.getHeaderFirstOf('n', 'n', 'X-C'), equals('c'));
      expect(r.getHeaderFirstOf('n', 'n', 'n', 'X-D'), equals('d'));
      expect(r.getHeaderFirstOf('n', 'n', 'n', 'n', 'X-E'), equals('e'));
      expect(r.getHeaderFirstOf('n', 'n', 'n', 'n', 'n', 'X-A'), equals('a'));
      expect(r.getHeaderFirstOf('n', 'n', 'n', 'n', 'n', 'n'), isNull);

      // Case-insensitive fallback:
      expect(r.getHeaderFirstOf('n', 'x-b'), equals('b'));
      expect(r.getHeaderFirstOf('n', 'n', 'x-c'), equals('c'));
      expect(r.getHeaderFirstOf('n', 'n', 'n', 'x-d'), equals('d'));
      expect(r.getHeaderFirstOf('n', 'n', 'n', 'n', 'x-e'), equals('e'));
      expect(r.getHeaderFirstOf('n', 'n', 'n', 'n', 'n', 'x-a'), equals('a'));

      expect(r.hostname, equals('example.com'));
      expect(r.port, equals(8080));
      expect(r.hostnameAndPort, equals('example.com:8080'));
      expect(r.origin, equals('http://example.com:8080/'));

      expect(r.matchesHostname('example.com'), isTrue);
      expect(r.matchesHostname(RegExp(r'^ex.*\.com$')), isTrue);
      expect(r.matchesHostname('other.com'), isFalse);
    });

    test('host, port and origin resolution', () {
      var noHost = APIRequest.get('/a');
      expect(noHost.hostname, equals('localhost'));
      expect(noHost.port, equals(0));
      expect(noHost.origin, equals('http://localhost/'));

      var portHeader = APIRequest.get(
        '/a',
        headers: {'host': 'h.com', 'port': ' 81 '},
      );
      expect(portHeader.hostname, equals('h.com'));
      expect(portHeader.port, equals(81));

      var badPort = APIRequest.get('/a', headers: {'host': 'h.com:xx'});
      expect(badPort.port, equals(0));

      var emptyHost = APIRequest.get('/a', headers: {'host': ' :80'});
      expect(emptyHost.hostname, equals('localhost'));

      var withOrigin = APIRequest.get(
        '/a',
        headers: {'origin': ' https://foo.com '},
      );
      expect(withOrigin.origin, equals('https://foo.com'));

      var withScheme = APIRequest(
        APIRequestMethod.GET,
        '/a',
        scheme: ' https ',
        headers: {'host': 'h.com'},
      );
      expect(withScheme.scheme, equals('https'));
      expect(withScheme.origin, equals('https://h.com/'));
    });

    test('requester address and source', () {
      expect(
        APIRequest(APIRequestMethod.GET, '/a').requesterSource,
        equals(APIRequesterSource.unknown),
      );
      expect(
        APIRequest(
          APIRequestMethod.GET,
          '/a',
          requesterAddress: ' ? ',
        ).requesterSource,
        equals(APIRequesterSource.unknown),
      );

      for (var local in ['localhost', '127.0.0.1', '0.0.0.0', '::1', '::']) {
        expect(
          APIRequest(
            APIRequestMethod.GET,
            '/a',
            requesterAddress: local,
          ).requesterSource,
          equals(APIRequesterSource.local),
          reason: local,
        );
      }

      expect(
        APIRequest(
          APIRequestMethod.GET,
          '/a',
          requesterAddress: 'internal',
        ).requesterSource,
        equals(APIRequesterSource.internal),
      );
      expect(
        APIRequest(
          APIRequestMethod.GET,
          '/a',
          requesterAddress: '.',
        ).requesterSource,
        equals(APIRequesterSource.internal),
      );

      var remote = APIRequest(
        APIRequestMethod.GET,
        '/a',
        requesterAddress: '10.0.0.1',
      );
      expect(remote.requesterSource, equals(APIRequesterSource.remote));
      expect(remote.requesterAddress, equals('10.0.0.1'));

      var proxied = APIRequest.get(
        '/a',
        headers: {'x-forwarded-for': '1.2.3.4, 5.6.7.8'},
      );
      expect(proxied.requesterAddress, equals('1.2.3.4'));

      var proxied2 = APIRequest.get(
        '/a',
        headers: {'x-forwarded-for': '1.2.3.4'},
      );
      expect(proxied2.requesterAddress, equals('1.2.3.4'));

      var remoteHeader = APIRequest.get(
        '/a',
        headers: {'remote-address': ' 9.9.9.9 '},
      );
      expect(remoteHeader.requesterAddress, equals('9.9.9.9'));

      expect(APIRequest.get('/a').requesterAddress, isNull);
    });

    test('isAuthenticated', () {
      var r = APIRequest.get('/a');
      expect(r.isAuthenticated, isFalse);
    });

    test('elapsedTime', () {
      var r = APIRequest(
        APIRequestMethod.GET,
        '/a',
        time: DateTime.now().subtract(Duration(seconds: 5)),
      );
      expect(r.elapsedTime.inSeconds, greaterThanOrEqualTo(5));
    });

    test('toString', () {
      var r = APIRequest(
        APIRequestMethod.POST,
        '/a/b',
        parameters: {'x': 1},
        headers: {'h': 'v'},
        payload: 'abc',
        payloadMimeType: 'text/plain',
        requesterAddress: '127.0.0.1',
      );

      var s = r.toString();
      expect(s, startsWith('APIRequest#${r.id}{ method: POST, path: /a/b, '));
      expect(s, contains('parameters: {x: 1}'));
      expect(s, contains('requester: 127.0.0.1 (local)'));
      expect(s, contains('headers: {h: v}'));
      expect(s, contains('payloadLength: 3'));

      var s2 = r.toString(withHeaders: false, withPayload: false);
      expect(s2, isNot(contains('headers:')));
      expect(s2, isNot(contains('payloadLength')));
    });
  });

  group('APIResponseStatus', () {
    test('parseAPIResponseStatus', () {
      expect(
        parseAPIResponseStatus(APIResponseStatus.OK),
        equals(APIResponseStatus.OK),
      );

      for (var s in [200, 201, 202, 204, 205, 206]) {
        expect(parseAPIResponseStatus(s), equals(APIResponseStatus.OK));
      }
      expect(parseAPIResponseStatus(304), APIResponseStatus.NOT_MODIFIED);
      expect(parseAPIResponseStatus(400), APIResponseStatus.BAD_REQUEST);
      for (var s in [401, 402, 403]) {
        expect(parseAPIResponseStatus(s), APIResponseStatus.UNAUTHORIZED);
      }
      for (var s in [404, 405, 410]) {
        expect(parseAPIResponseStatus(s), APIResponseStatus.NOT_FOUND);
      }
      for (var s in [429, 500, 501, 503]) {
        expect(parseAPIResponseStatus(s), APIResponseStatus.ERROR);
      }
      expect(parseAPIResponseStatus(999), isNull);

      expect(parseAPIResponseStatus(' OK '), APIResponseStatus.OK);
      for (var s in [
        'internalservererror',
        'internal server error',
        'internal_server_error',
        'error',
      ]) {
        expect(parseAPIResponseStatus(s), APIResponseStatus.ERROR);
      }
      for (var s in ['notfound', 'not found', 'not_found']) {
        expect(parseAPIResponseStatus(s), APIResponseStatus.NOT_FOUND);
      }
      for (var s in ['notmodified', 'not modified', 'not_modified']) {
        expect(parseAPIResponseStatus(s), APIResponseStatus.NOT_MODIFIED);
      }
      expect(
        parseAPIResponseStatus('Unauthorized'),
        APIResponseStatus.UNAUTHORIZED,
      );
      for (var s in ['badrequest', 'bad request', 'bad_request']) {
        expect(parseAPIResponseStatus(s), APIResponseStatus.BAD_REQUEST);
      }
      expect(parseAPIResponseStatus('foo'), isNull);
    });
  });

  group('Etag', () {
    test('parse', () {
      expect(Etag.parse(''), isA<WeakEtag>());
      expect(Etag.parse('').isEmpty, isTrue);

      var strong = Etag.parse(' "abc" ');
      expect(strong, isA<StrongEtag>());
      expect(strong.tag, equals('abc'));
      expect(strong.toString(), equals('"abc"'));

      var weak = Etag.parse('W/"1,2,3"');
      expect(weak, isA<WeakEtag>());
      expect((weak as WeakEtag).values, equals(['1', '2', '3']));
      expect(weak.toString(), equals('W/"1,2,3"'));
    });

    test('StrongEtag', () {
      expect(StrongEtag.parse('').isEmpty, isTrue);
      expect(StrongEtag.parse('""').isEmpty, isTrue);
      expect(StrongEtag.parse('xyz').tag, equals('xyz'));

      expect(StrongEtag.sha256([]).isEmpty, isTrue);
      expect(StrongEtag.sha384([]).isEmpty, isTrue);
      expect(StrongEtag.sha512([]).isEmpty, isTrue);

      var bytes = utf8.encode('abc');
      expect(
        StrongEtag.sha256(bytes).tag,
        equals(
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
      );
      expect(StrongEtag.sha384(bytes).tag.length, equals(96));
      expect(StrongEtag.sha512(bytes).tag.length, equals(128));

      var e = StrongEtag('abc');
      expect(e.equals(e), isTrue);
      expect(e == StrongEtag('abc'), isTrue);
      expect(e.equals('"abc"'), isTrue);
      expect(e.equals(123), isFalse);
      expect(e.hashCode, equals('abc'.hashCode));
    });

    test('WeakEtag', () {
      expect(WeakEtag.parse('').isEmpty, isTrue);
      expect(WeakEtag.parse('W/""').isEmpty, isTrue);
      expect(WeakEtag.parse('a;b', delimiter: ';').values, equals(['a', 'b']));

      expect(WeakEtag.adler32([]).isEmpty, isTrue);
      expect(WeakEtag.crc32([]).isEmpty, isTrue);

      expect(WeakEtag.adler32([1]).values.last, equals('01'));
      expect(WeakEtag.adler32([1, 2]).values.last, equals('0102'));
      expect(WeakEtag.crc32([1, 2, 3]).values.last, equals('010203'));
      expect(WeakEtag.crc32([1, 2, 3, 4, 5]).values.last, equals('01020305'));
      expect(WeakEtag.crc32([1, 2, 3, 4, 5]).values.first, equals('5'));

      var e = WeakEtag(['a', 'b']);
      expect(e.tag, equals('a,b'));
      expect(e.equals(e), isTrue);
      expect(e == WeakEtag(['a', 'b']), isTrue);
      expect(e.equals('W/"a,b"'), isTrue);
      expect(e.equals(1), isFalse);
      expect(e.hashCode, equals('a,b'.hashCode));
    });
  });

  group('CacheControl', () {
    test('default', () {
      var c = CacheControl.defaultCacheControl;
      expect(c.hasDirective(CacheControlDirective.private), isTrue);
      expect(
        c.toString(),
        equals(
          'private, no-transform, max-age=10, stale-while-revalidate=300, stale-if-error=600',
        ),
      );
      expect(c == CacheControl(), isTrue);
      expect(c.hashCode, equals(CacheControl().hashCode));
      expect(c == CacheControl(maxAge: Duration(seconds: 1)), isFalse);
    });

    test('no-cache', () {
      var c = CacheControl(
        directives: [
          CacheControlDirective.noCache,
          CacheControlDirective.noStore,
          CacheControlDirective.noTransform,
        ],
      );
      expect(
        c.toString(),
        equals('no-cache, no-store, no-transform, max-age=0'),
      );

      expect(
        CacheControl(directives: [CacheControlDirective.noCache]).toString(),
        equals('no-cache, max-age=0'),
      );
    });

    test('public', () {
      var c = CacheControl(
        directives: [
          CacheControlDirective.public,
          CacheControlDirective.noStore,
          CacheControlDirective.mustRevalidate,
          CacheControlDirective.staleWhileRevalidate,
          CacheControlDirective.staleIfError,
        ],
        maxAge: Duration(minutes: 20),
      );
      // Stale ages are never below `maxAge`:
      expect(
        c.toString(),
        equals(
          'public, no-store, must-revalidate, max-age=1200, stale-while-revalidate=1200, stale-if-error=1200',
        ),
      );
    });
  });

  group('APIResponse', () {
    test('payloadAs', () {
      var r = APIResponse.ok('abc');
      expect(r.payloadAs<String>(), equals('abc'));
      expect(() => r.payloadAs<int>(), throwsStateError);
    });

    test('status helpers', () {
      expect(APIResponse.ok(1).isValid, isTrue);
      expect(APIResponse.notFound().isValid, isTrue);
      expect(APIResponse.error().isNotValid, isTrue);
      expect(APIResponse.error().isError, isTrue);
      expect(APIResponse.notModified().isNotModified, isTrue);
      expect(APIResponse.unauthorized().isUnauthorized, isTrue);
      expect(APIResponse.badRequest().isBadRequest, isTrue);
      expect(APIResponse.notFound().isNotFound, isTrue);
      expect(APIResponse.notFound().isNotOK, isTrue);
    });

    test('cast and copy', () {
      var r = APIResponse<Object>.ok(
        'abc',
        mimeType: 'text/plain',
        fileExtension: 'txt',
        payloadETag: StrongEtag('x'),
        cacheControl: CacheControl.defaultCacheControl,
        headers: {'h': 'v'},
      )..requireAuthentication(realm: 'R', type: 'Bearer');

      r.startMetric('m');

      var c = r.cast<String>();
      expect(c.payload, equals('abc'));
      expect(c.payloadFileExtension, equals('txt'));
      expect(c.payloadETag, equals(StrongEtag('x')));
      expect(c.requiresAuthentication, isTrue);
      expect(c.authenticationRealm, equals('R'));
      expect(c.authenticationType, equals('Bearer'));
      expect(c.stopMetric('m'), isNotNull);

      var c2 = r.cast<String>(payload: 'def', error: 'err');
      expect(c2.payload, equals('def'));
      expect(c2.error, equals('err'));

      var copy = r.copy(status: APIResponseStatus.NOT_FOUND);
      expect(copy.status, equals(APIResponseStatus.NOT_FOUND));
      expect(copy.payload, equals('abc'));
      expect(copy.headers, equals({'h': 'v'}));
      expect(copy.requiresAuthentication, isTrue);

      expect(r.copy(nullPayload: true).payload, isNull);
      expect(r.copy(payloadDynamic: 'dyn').payload, equals('dyn'));
      expect(r.copy(payload: 'p').payload, equals('p'));
      expect(
        r.copy(mimeType: 'application/json').payloadMimeType?.isJSON,
        isTrue,
      );
    });

    test('as* conversions', () {
      var r = APIResponse<Object>.error(
        error: 'e',
        headers: {'h': 'v'},
        stackTrace: StackTrace.current,
      )..startMetric('m');

      var ok = r.asOk(payload: 'x', eTag: StrongEtag('t'));
      expect(ok.isOK, isTrue);
      expect(ok.payload, equals('x'));
      expect(ok.payloadETag, equals(StrongEtag('t')));
      expect(ok.headers, equals({'h': 'v'}));
      expect(ok.stopMetric('m'), isNotNull);

      expect(r.asOk(payloadDynamic: 'd').payload, equals('d'));

      var nf = ok.asNotFound();
      expect(nf.isNotFound, isTrue);
      expect(nf.payload, equals('x'));

      var nm = ok.asNotModified(eTag: WeakEtag(['1']));
      expect(nm.isNotModified, isTrue);
      expect(nm.payloadETag, equals(WeakEtag(['1'])));

      var un = ok.asUnauthorized();
      expect(un.isUnauthorized, isTrue);
      expect(un.payload, equals('x'));

      var br = ok.asBadRequest(payloadDynamic: 'bad');
      expect(br.isBadRequest, isTrue);
      expect(br.payload, equals('bad'));

      var err = ok.asError(error: 'boom');
      expect(err.isError, isTrue);
      expect(err.error, equals('boom'));
      expect(r.asError().error, equals('e'));

      var redirect = APIResponse<Object>.ok(' http://foo.com/x ').asRedirect();
      expect(redirect.status, equals(APIResponseStatus.REDIRECT));
      expect(redirect.payload, equals(Uri.parse('http://foo.com/x')));

      // ignore: deprecated_member_use_from_same_package
      var redirect2 = ok.asRedirecy(location: Uri.parse('http://bar.com/'));
      expect(redirect2.payload, equals(Uri.parse('http://bar.com/')));

      // ignore: deprecated_member_use_from_same_package
      var redirect3 = APIResponse<Object>.redirecy(Uri.parse('http://a.com/'));
      expect(redirect3.status, equals(APIResponseStatus.REDIRECT));
      expect(redirect3.payload, equals(Uri.parse('http://a.com/')));
    });

    test('from', () {
      expect(APIResponse.from(null).isNotFound, isTrue);

      var ok = APIResponse<String>.ok('x');
      expect(APIResponse<String>.from(ok), same(ok));

      var casted = APIResponse<Object>.from(APIResponse<int>.ok(1));
      expect(casted, isA<APIResponse<Object>>());
      expect(casted.payload, equals(1));

      var error = StateError('x');
      var fromError = APIResponse.from(error);
      expect(fromError.isError, isTrue);
      expect(fromError.error, same(error));

      var fromException = APIResponse.from(FormatException('f'));
      expect(fromException.isError, isTrue);

      expect(APIResponse.from(123).payload, equals(123));
    });

    test('headers and CORS', () {
      var r = APIResponse.ok('x', headers: {'Content-Type': 'text/plain'});
      expect(r.getHeader('Content-Type'), equals('text/plain'));
      expect(r.getHeader(' content-type '), equals('text/plain'));
      expect(r.getHeader('none', def: 'd'), equals('d'));

      r.headers['x-lower'] = 'l';
      expect(r.getHeader('X-LOWER'), equals('l'));

      expect(r.hasCORS, isFalse);

      r.setCORS(
        APIRequest.get('/a', headers: {'origin': 'http://localhost:8080'}),
      );
      expect(r.hasCORS, isTrue);
      expect(
        r.headers['Access-Control-Allow-Origin'],
        equals('http://localhost:8080'),
      );
      expect(r.headers['Access-Control-Allow-Headers'], contains('x-ijt'));
      expect(r.headers['Access-Control-Allow-Credentials'], equals('true'));
      expect(
        r.headers['Access-Control-Expose-Headers'],
        equals(APIResponse.exposeHeaders),
      );

      var r2 = APIResponse.ok('x');
      r2.setCORS(
        APIRequest.get('/a', headers: {'origin': 'https://foo.com'}),
        allowCredentials: false,
        allowMethods: ['GET'],
        allowHeaders: ['A', 'B'],
        exposeHeaders: ['C'],
      );
      expect(r2.headers['Access-Control-Allow-Methods'], equals('GET'));
      expect(r2.headers['Access-Control-Allow-Headers'], equals('A, B'));
      expect(r2.headers['Access-Control-Expose-Headers'], equals('C'));
      expect(r2.headers['Access-Control-Allow-Credentials'], equals('false'));

      var r3 = APIResponse.ok('x')
        ..setCORS(APIRequest.get('/a', headers: {'origin': 'https://foo.com'}));
      expect(
        r3.headers['Access-Control-Allow-Headers'],
        isNot(contains('x-ijt')),
      );
    });

    test('toInfos and toString', () {
      var r = APIResponse.ok('abc', mimeType: 'text/plain');
      expect(r.toInfos(), contains('status: APIResponseStatus.OK'));
      expect(r.toInfos(), contains('payloadLength: 3'));
      expect(r.toInfos(), contains('payloadMimeType: text/plain'));
      expect(r.toString(), equals('abc'));

      var e = APIResponse.error(error: 'boom');
      expect(e.toInfos(), contains('error: boom'));
      expect(e.toString(), equals('boom'));

      expect(
        APIResponse.notFound().toString(),
        equals('APIResponseStatus.NOT_FOUND'),
      );

      r.payloadMimeType = 'application/json';
      expect(r.payloadMimeType?.isJSON, isTrue);

      r.setMetric('x');
      r.dispose();
      expect(r.hasMetrics, isFalse);
      expect(r.apiRequest, isNull);
    });
  });
}

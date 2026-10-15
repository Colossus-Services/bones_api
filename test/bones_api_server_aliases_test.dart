@TestOn('vm')
import 'dart:convert';
import 'dart:io';

import 'package:bones_api/bones_api_server.dart';
import 'package:bones_api/bones_api_test_vm.dart';
import 'package:bones_api/src/bones_api_server_aliases.dart';
import 'package:path/path.dart' as pack_path;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _AliasesAPIRoot extends APIRoot {
  _AliasesAPIRoot(String name) : super(name, '1.0.0');

  @override
  Set<APIModule> loadModules() => {_AliasesModule(this)};
}

class _AliasesModule extends APIModule {
  _AliasesModule(APIRoot apiRoot) : super(apiRoot, 'mod');

  @override
  void configure() {
    routes.any('ok', (request) => APIResponse.ok('OK'));
  }
}

void _write(Directory root, String path, String content) {
  var file = File(pack_path.joinAll([root.path, ...path.split('/')]));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

AliasesTable _parse(String content, [List<String>? invalid]) =>
    AliasesTable.parse(
      content,
      onInvalid: (line, reason) => invalid?.add('$line: $reason'),
    );

List<List<String>> _candidates(AliasesTable table, String path) =>
    table.candidates(path.split('/')).toList();

typedef _Res = ({int status, HttpHeaders headers, List<int> body});

Future<_Res> _request(String url, {Map<String, String>? headers}) async {
  var client = HttpClient();
  client.autoUncompress = false;

  try {
    var req = await client.getUrl(Uri.parse(url));
    req.followRedirects = false;
    headers?.forEach(req.headers.set);

    var res = await req.close();
    var bytes = await res.expand((e) => e).toList();

    return (status: res.statusCode, headers: res.headers, body: bytes);
  } finally {
    client.close(force: true);
  }
}

String _bodyStr(_Res res) {
  var bytes = res.body;
  if (res.headers.value('content-encoding') == 'gzip') {
    bytes = gzip.decode(bytes);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// Sends a raw HTTP request line, to keep the [path] exactly as written
/// (no client side normalization). Returns the status code.
Future<int> _rawStatus(int port, String path) async {
  var socket = await Socket.connect('localhost', port);
  try {
    socket.write(
      'GET $path HTTP/1.1\r\nHost: localhost:$port\r\nConnection: close\r\n\r\n',
    );
    await socket.flush();
    var response = await utf8.decoder
        .bind(socket)
        .join()
        .timeout(Duration(seconds: 10));
    var statusLine = response.split('\r\n').first;
    return int.parse(statusLine.split(' ')[1]);
  } finally {
    socket.destroy();
  }
}

void main() {
  group('AliasesTable.parse', () {
    test('kinds, comments and whitespace', () {
      var invalid = <String>[];
      var table = _parse('''
# a comment

food.png   = sections/food.png
  menu/ = sections/   # inline comment
./ = sections/
*.png = sections/*.png
a#b.png = sections/a#b.png
''', invalid);

      expect(invalid, isEmpty);
      expect(table.entries.map((e) => e.kind), [
        AliasKind.file,
        AliasKind.directory,
        AliasKind.overlay,
        AliasKind.pattern,
        AliasKind.file,
      ]);
      expect(table.entries.map((e) => e.line), [3, 4, 5, 6, 7]);
      expect(table.entries[1].virtualPath, equals('menu/'));
      expect(table.entries[1].targetPath, equals('sections/'));
      expect(table.entries[4].virtualSegments, ['a#b.png']);
      expect(table.entries[4].targetSegments, ['sections', 'a#b.png']);
      expect(table.entries[0].toString(), contains('file'));
    });

    test('empty content', () {
      expect(_parse('').isEmpty, isTrue);
      expect(_parse('\n# only comments\n\n').isEmpty, isTrue);
      expect(_parse('a = b').isNotEmpty, isTrue);
    });

    test('invalid lines are skipped, valid lines kept', () {
      var invalid = <String>[];
      var table = _parse('''
secret.txt = ../../etc/passwd
/abs.png = sections/food.png
abs2.png = /etc/passwd
x.png = sections/
x/ = sections/x.png
.aliases = sections/food.png
y.png = sections/.ALIASES
just-a-name
= empty.png
empty.png =
win.png = sections\\win.png
a//b.png = c.png
./x.png = c.png
ctl.png = c\u0001.png
food.png = sections/food.png
food.png = sections/other.png
w.png = sections/*.png
./ = sections/x.png
''', invalid);

      expect(table.entries.map((e) => e.virtualPath), ['food.png']);
      expect(table.entries.single.targetSegments, ['sections', 'food.png']);
      expect(invalid, hasLength(17));
      expect(invalid.last, startsWith('18:'));
      expect(invalid.firstWhere((e) => e.startsWith('16:')), contains('dup'));
    });

    test('patterns: valid', () {
      var invalid = <String>[];
      var table = _parse('''
*.png = sections/*.png
*.webp = sections/
**/*.svg = vector/**/*.svg
img-??.jpg = photos/img-??.jpg
v*/logo.png = brand/v*/logo.png
*-*.gif = x/*.gif
''', invalid);

      expect(invalid, isEmpty);
      expect(table.entries, hasLength(6));
      expect(table.entries.every((e) => e.kind == AliasKind.pattern), isTrue);
    });

    test('patterns: invalid', () {
      var invalid = <String>[];
      var table = _parse('''
*.png = x/**/a.png
*.png = x/*/*.png
*.png = x/?.png
*.png = x/*.png/
a/**/ = x/
a/** = x/
a**b/c.png = x/
*/ = x/
*.png = x.png
${'a' * 300}*.png = x/
${'*' * 9}.png = x/
''', invalid);

      expect(table.isEmpty, isTrue);
      expect(invalid, hasLength(11));
    });
  });

  group('AliasesTable.candidates', () {
    test('precedence: exact > directory prefix > pattern > overlay', () {
      var table = _parse('''
./ = overlay/
*.png = pattern/*.png
v2/ = dir2/
v2/sub/ = dir2sub/
v2/sub/a.png = exact/a.png
''');

      expect(_candidates(table, 'v2/sub/a.png'), [
        ['exact', 'a.png'],
        ['dir2sub', 'a.png'],
        ['dir2', 'sub', 'a.png'],
        ['overlay', 'v2', 'sub', 'a.png'],
      ]);

      expect(_candidates(table, 'a.png'), [
        ['pattern', 'a.png'],
        ['overlay', 'a.png'],
      ]);

      expect(_candidates(table, 'a.jpg'), [
        ['overlay', 'a.jpg'],
      ]);
    });

    test('patterns', () {
      var table = _parse('''
*.png = sections/*.png
*.webp = sections/
**/*.svg = vector/**/*.svg
img-??.jpg = photos/img-??.jpg
v*/logo.png = brand/v*/logo.png
*-*.gif = x/*.gif
''');

      expect(_candidates(table, 'food.png'), [
        ['sections', 'food.png'],
      ]);
      expect(_candidates(table, 'food.jpg'), isEmpty);
      // `*` never crosses `/`:
      expect(_candidates(table, 'a/food.png'), isEmpty);

      expect(_candidates(table, 'x.webp'), [
        ['sections', 'x.webp'],
      ]);

      expect(_candidates(table, 'logo.svg'), [
        ['vector', 'logo.svg'],
      ]);
      expect(_candidates(table, 'a/b/logo.svg'), [
        ['vector', 'a', 'b', 'logo.svg'],
      ]);

      expect(_candidates(table, 'img-01.jpg'), [
        ['photos', 'img-01.jpg'],
      ]);
      expect(_candidates(table, 'img-1.jpg'), isEmpty);
      expect(_candidates(table, 'img-001.jpg'), isEmpty);

      expect(_candidates(table, 'v3/logo.png'), [
        ['brand', 'v3', 'logo.png'],
      ]);

      expect(_candidates(table, 'a-b.gif'), [
        ['x', 'a.gif'],
      ]);
    });

    test('patterns: file order', () {
      var table = _parse('''
a*.png = first/
*.png = second/
''');
      expect(_candidates(table, 'ab.png'), [
        ['first', 'ab.png'],
        ['second', 'ab.png'],
      ]);
    });

    test('patterns: empty capture producing an invalid path', () {
      var table = _parse('x-*.png = y/*/a.png');
      expect(_candidates(table, 'x-.png'), isEmpty);
      expect(_candidates(table, 'x-k.png'), [
        ['y', 'k', 'a.png'],
      ]);
    });

    test('directory alias: longest prefix first', () {
      var table = _parse('''
a/ = short/
a/b/ = long/
''');
      expect(_candidates(table, 'a/b/c.png'), [
        ['long', 'c.png'],
        ['short', 'b', 'c.png'],
      ]);
      expect(_candidates(table, 'a'), [
        ['short'],
      ]);
    });
  });

  group('StaticFilesAliases.resolve', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('bones_api_aliases_');
      _write(root, 'icons/sections/food.png', 'FOOD');
      _write(root, 'icons/sections/drinks.png', 'DRINKS');
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    StaticFilesAliases newAliases() =>
        StaticFilesAliases(root, checkInterval: Duration.zero);

    String? resolve(StaticFilesAliases aliases, String path) =>
        aliases.resolve(path.split('/'))?.toString();

    test('overlay', () {
      _write(root, 'icons/.aliases', './ = sections/\n');
      var aliases = newAliases();

      expect(resolve(aliases, 'icons/food.png'), 'icons/sections/food.png');
      expect(resolve(aliases, 'icons/drinks.png'), 'icons/sections/drinks.png');
      // Physical path: unchanged.
      expect(resolve(aliases, 'icons/sections/food.png'), isNull);
      // Missing target:
      expect(resolve(aliases, 'icons/none.png'), isNull);
      // Outside the aliased directory:
      expect(resolve(aliases, 'food.png'), isNull);
    });

    test('file alias and rename', () {
      _write(root, 'icons/.aliases', '''
food.png = sections/food.png
beer.png = sections/drinks.png
missing.png = sections/missing.png
''');
      var aliases = newAliases();

      expect(resolve(aliases, 'icons/food.png'), 'icons/sections/food.png');
      expect(resolve(aliases, 'icons/beer.png'), 'icons/sections/drinks.png');
      expect(resolve(aliases, 'icons/missing.png'), isNull);
      expect(resolve(aliases, 'icons/drinks.png'), isNull);
    });

    test('directory alias', () {
      _write(root, 'icons/sections/index.html', 'IDX');
      _write(root, 'icons/.aliases', 'menu/ = sections/\n');
      var aliases = newAliases();

      expect(
        resolve(aliases, 'icons/menu/food.png'),
        'icons/sections/food.png',
      );
      expect(resolve(aliases, 'icons/menu'), 'icons/sections/');
      expect(resolve(aliases, 'icons/menu/'), 'icons/sections/');
      // A file requested as a directory:
      expect(resolve(aliases, 'icons/menu/food.png/'), isNull);
    });

    test('physical file wins over an alias', () {
      _write(root, 'icons/food.png', 'PHYSICAL');
      _write(root, 'icons/.aliases', 'food.png = sections/food.png\n');
      var aliases = newAliases();

      expect(resolve(aliases, 'icons/food.png'), isNull);
    });

    test('nested: the closest `.aliases` wins', () {
      _write(root, 'a/b/x.png', 'B');
      _write(root, 'a/c/x.png', 'C');
      _write(root, '.aliases', 'a/v/ = a/c/\n');
      _write(root, 'a/.aliases', 'v/ = b/\n');
      var aliases = newAliases();

      expect(resolve(aliases, 'a/v/x.png'), 'a/b/x.png');

      // Falls back to the outer `.aliases` when the closest has no target:
      _write(root, 'a/c/y.png', 'Y');
      expect(resolve(aliases, 'a/v/y.png'), 'a/c/y.png');
    });

    test('chaining', () {
      _write(root, 'icons/.aliases', '''
a.png = b.png
b.png = sections/food.png
''');
      var aliases = newAliases();

      expect(resolve(aliases, 'icons/a.png'), 'icons/sections/food.png');
    });

    test('cycle', () {
      _write(root, 'icons/.aliases', '''
a.png = b.png
b.png = a.png
x/ = y/
y/ = x/
''');
      var aliases = newAliases();

      expect(resolve(aliases, 'icons/a.png'), isNull);
      expect(resolve(aliases, 'icons/x/food.png'), isNull);
    });

    test('depth limit', () {
      var lines = [
        for (var i = 0; i < 12; ++i) 'f$i.png = f${i + 1}.png',
        'f12.png = sections/food.png',
      ];
      _write(root, 'icons/.aliases', lines.join('\n'));
      var aliases = newAliases();

      expect(resolve(aliases, 'icons/f6.png'), 'icons/sections/food.png');
      expect(resolve(aliases, 'icons/f0.png'), isNull);
    });

    test('patterns', () {
      _write(root, 'icons/vector/a/b/logo.svg', 'SVG');
      _write(root, 'icons/.aliases', '''
*.png = sections/*.png
**/*.svg = vector/**/*.svg
''');
      var aliases = newAliases();

      expect(resolve(aliases, 'icons/food.png'), 'icons/sections/food.png');
      expect(resolve(aliases, 'icons/food.jpg'), isNull);
      expect(
        resolve(aliases, 'icons/a/b/logo.svg'),
        'icons/vector/a/b/logo.svg',
      );
    });

    test('invalid request segments are never aliased', () {
      _write(root, 'icons/.aliases', './ = sections/\n');
      var aliases = newAliases();

      expect(aliases.resolve([]), isNull);
      expect(aliases.resolve(['']), isNull);
      expect(aliases.resolve(['icons', '..', 'food.png']), isNull);
      expect(aliases.resolve(['icons', '.', 'food.png']), isNull);
      expect(aliases.resolve(['icons', '', 'food.png']), isNull);
      expect(aliases.resolve(['icons', 'x/../food.png']), isNull);
      expect(aliases.resolve(['icons', r'x\food.png']), isNull);
      expect(
        aliases.resolve(List.filled(StaticFilesAliases.maxSegments + 1, 'a')),
        isNull,
      );
    });

    test('reload after a `.aliases` edit', () {
      _write(root, 'icons/.aliases', 'a.png = sections/food.png\n');
      var aliases = newAliases();

      expect(resolve(aliases, 'icons/a.png'), 'icons/sections/food.png');

      _write(root, 'icons/.aliases', 'a.png = sections/drinks.png # changed\n');
      expect(resolve(aliases, 'icons/a.png'), 'icons/sections/drinks.png');

      File(pack_path.join(root.path, 'icons', '.aliases')).deleteSync();
      expect(resolve(aliases, 'icons/a.png'), isNull);
    });

    test('cached until `checkInterval`', () {
      _write(root, 'icons/.aliases', 'a.png = sections/food.png\n');
      var aliases = StaticFilesAliases(root, checkInterval: Duration(hours: 1));

      expect(resolve(aliases, 'icons/a.png'), 'icons/sections/food.png');

      _write(root, 'icons/.aliases', 'a.png = sections/drinks.png # changed\n');
      expect(resolve(aliases, 'icons/a.png'), 'icons/sections/food.png');

      aliases.clearCache();
      expect(resolve(aliases, 'icons/a.png'), 'icons/sections/drinks.png');
    });

    test('malformed `.aliases` content', () {
      var file = File(pack_path.join(root.path, 'icons', '.aliases'));
      file.writeAsBytesSync([0xff, 0xfe, 0x00, 0xc3, 0x28]);
      var aliases = newAliases();
      expect(resolve(aliases, 'icons/food.png'), isNull);

      file.writeAsStringSync('x' * (StaticFilesAliases.maxFileSize + 1));
      expect(resolve(aliases, 'icons/food.png'), isNull);

      file.writeAsStringSync('garbage\n= =\n./ = sections/\n');
      expect(resolve(aliases, 'icons/food.png'), 'icons/sections/food.png');
    });

    test('`.aliases` as a directory is ignored', () {
      Directory(pack_path.join(root.path, 'icons', '.aliases')).createSync();
      var aliases = newAliases();
      expect(resolve(aliases, 'icons/food.png'), isNull);
    });

    test('`.aliases` symlink outside the root is ignored', () async {
      var outside = await Directory.systemTemp.createTemp('bones_api_out_');
      try {
        var outsideAliases = File(pack_path.join(outside.path, 'aliases'))
          ..writeAsStringSync('./ = sections/\n');
        Link(
          pack_path.join(root.path, 'icons', '.aliases'),
        ).createSync(outsideAliases.path);

        var aliases = newAliases();
        expect(resolve(aliases, 'icons/food.png'), isNull);
      } finally {
        await outside.delete(recursive: true);
      }
    });

    test('isAliasesFileRequest', () {
      expect(StaticFilesAliases.isAliasesFileRequest(['.aliases']), isTrue);
      expect(
        StaticFilesAliases.isAliasesFileRequest(['icons', '.ALIASES']),
        isTrue,
      );
      expect(
        StaticFilesAliases.isAliasesFileRequest(['icons/.aliases']),
        isTrue,
      );
      expect(
        StaticFilesAliases.isAliasesFileRequest([r'icons\.aliases']),
        isTrue,
      );
      expect(StaticFilesAliases.isAliasesFileRequest(['.aliases', '']), isTrue);
      expect(StaticFilesAliases.isAliasesFileRequest(['x.aliases']), isFalse);
      expect(StaticFilesAliases.isAliasesFileRequest(['.aliasesx']), isFalse);
      expect(StaticFilesAliases.isAliasesFileRequest([]), isFalse);
    });
  });

  group('StaticFilesAliases.middleware', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('bones_api_aliases_mw_');
      _write(root, 'icons/sections/food.png', 'FOOD');
      _write(root, 'icons/.aliases', './ = sections/\nmenu/ = sections/\n');
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    test('rewrites the request, keeping query, headers and context', () async {
      Request? inner;
      var handler = StaticFilesAliases(root).middleware((request) {
        inner = request;
        return Response.ok('ok');
      });

      var response = await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/icons/food.png?v=1'),
          headers: {'x-test': 'yes'},
          context: {'ctx': 1},
        ),
      );

      expect(response.statusCode, 200);
      expect(inner!.url.path, 'icons/sections/food.png');
      expect(inner!.url.query, 'v=1');
      expect(inner!.requestedUri.path, '/icons/sections/food.png');
      expect(inner!.requestedUri.query, 'v=1');
      expect(inner!.headers['x-test'], 'yes');
      expect(inner!.context['ctx'], 1);
    });

    test('rewrites a request whose body was already read', () async {
      Request? inner;
      var handler = StaticFilesAliases(root).middleware((request) {
        inner = request;
        return Response.ok('ok');
      });

      var request = Request(
        'POST',
        Uri.parse('http://localhost/icons/food.png'),
        body: 'payload',
      );
      // The `APIServer` reads the body before the static files handler:
      expect(await request.readAsString(), 'payload');

      var response = await handler(request);
      expect(response.statusCode, 200);
      expect(inner!.method, 'POST');
      expect(inner!.url.path, 'icons/sections/food.png');
    });

    test('unchanged request, `.aliases` 404, directory 301', () async {
      var decorated = 0;
      Request? inner;
      var handler =
          StaticFilesAliases(
            root,
            decorateResponse: (request, response) {
              decorated++;
              return response.change(headers: {'x-decorated': 'yes'});
            },
          ).middleware((request) {
            inner = request;
            return Response.ok('ok');
          });

      var original = Request('GET', Uri.parse('http://localhost/other.png'));
      await handler(original);
      expect(identical(inner, original), isTrue);

      var r404 = await handler(
        Request('GET', Uri.parse('http://localhost/icons/.aliases')),
      );
      expect(r404.statusCode, 404);
      expect(r404.headers['x-decorated'], 'yes');

      var r301 = await handler(
        Request('GET', Uri.parse('http://localhost/icons/menu?q=1')),
      );
      expect(r301.statusCode, 301);
      expect(r301.headers['location'], 'http://localhost/icons/menu/?q=1');
      expect(decorated, 2);

      await handler(Request('GET', Uri.parse('http://localhost/icons/menu/')));
      expect(inner!.url.path, 'icons/sections/');
    });
  });

  group('APIServer + .aliases', () {
    late Directory docRoot;
    late Directory outside;
    late APIServer apiServer;
    late int port;

    setUpAll(() async {
      docRoot = await Directory.systemTemp.createTemp('bones_api_aliases_www_');
      outside = await Directory.systemTemp.createTemp('bones_api_aliases_out_');

      File(
        pack_path.join(outside.path, 'secret.txt'),
      ).writeAsStringSync('SECRET');

      _write(docRoot, 'index.html', '<html>ROOT</html>');
      _write(docRoot, 'icons/sections/food.png', 'FOOD-PNG');
      _write(docRoot, 'icons/sections/drinks.png', 'DRINKS-PNG');
      _write(docRoot, 'icons/sections/index.html', '<html>SECTIONS</html>');
      _write(docRoot, 'icons/sections/my file.png', 'SPACE-PNG');
      _write(docRoot, 'icons/vector/a/b/logo.svg', '<svg>LOGO</svg>');
      _write(docRoot, 'icons/both.png', 'PHYSICAL');
      _write(docRoot, 'icons/sections/both.png', 'ALIASED');
      _write(docRoot, 'icons/big/data.txt', 'BIG DATA ' * 500);
      _write(docRoot, 'icons/.aliases', '''
# Serve icons/sections/* also as icons/*
./ = sections/
menu/ = sections/
**/*.svg = vector/**/*.svg
*.txt = big/*.txt
beer.png = sections/drinks.png
both.png = sections/both.png
missing.png = sections/missing.png
a.png = b.png
b.png = a.png
secret.txt = sections/secret.txt
garbage line
../x = y
''');

      Link(
        pack_path.join(docRoot.path, 'icons', 'sections', 'secret.txt'),
      ).createSync(pack_path.join(outside.path, 'secret.txt'));

      port = await resolveFreePort(6700);

      apiServer = APIServer(
        _AliasesAPIRoot('aliases-http'),
        'localhost',
        port,
        documentRoot: docRoot.path,
        cookieless: true,
        logToConsole: false,
      );

      await apiServer.start();
    });

    tearDownAll(() async {
      await apiServer.stop();
      await docRoot.delete(recursive: true);
      await outside.delete(recursive: true);
    });

    String url(String path) => '${apiServer.url}$path';

    test('overlay alias and physical path', () async {
      var res = await _request(url('icons/food.png'));
      expect(res.status, 200);
      expect(_bodyStr(res), 'FOOD-PNG');
      expect(res.headers.contentType?.mimeType, 'image/png');
      expect(
        res.headers.value(APIServer.headerXCookielessServer),
        APIServer.headerXCookielessServerValue,
      );

      var res2 = await _request(url('icons/sections/food.png'));
      expect(res2.status, 200);
      expect(_bodyStr(res2), 'FOOD-PNG');

      // Cached (second request through the alias):
      var res3 = await _request(url('icons/food.png'));
      expect(res3.status, 200);
      expect(_bodyStr(res3), 'FOOD-PNG');
    });

    test('file alias, rename and encoded names', () async {
      var res = await _request(url('icons/beer.png'));
      expect(res.status, 200);
      expect(_bodyStr(res), 'DRINKS-PNG');

      var res2 = await _request(url('icons/my%20file.png'));
      expect(res2.status, 200);
      expect(_bodyStr(res2), 'SPACE-PNG');
    });

    test('pattern aliases', () async {
      var res = await _request(url('icons/a/b/logo.svg'));
      expect(res.status, 200);
      expect(_bodyStr(res), '<svg>LOGO</svg>');

      var res2 = await _request(
        url('icons/data.txt'),
        headers: {'accept-encoding': 'gzip'},
      );
      expect(res2.status, 200);
      expect(res2.headers.value('content-encoding'), 'gzip');
      expect(_bodyStr(res2), 'BIG DATA ' * 500);
    });

    test('physical file wins over an alias', () async {
      var res = await _request(url('icons/both.png'));
      expect(res.status, 200);
      expect(_bodyStr(res), 'PHYSICAL');
    });

    test('directory alias: 301 to the virtual path, then index.html', () async {
      var res = await _request(url('icons/menu?x=1'));
      expect(res.status, 301);
      expect(Uri.parse(res.headers.value('location')!).path, '/icons/menu/');
      expect(Uri.parse(res.headers.value('location')!).query, 'x=1');

      var res2 = await _request(url('icons/menu/'));
      expect(res2.status, 200);
      expect(_bodyStr(res2), contains('SECTIONS'));

      var res3 = await _request(url('icons/menu/food.png?v=2'));
      expect(res3.status, 200);
      expect(_bodyStr(res3), 'FOOD-PNG');
    });

    test('missing target, cycle and no alias: 404', () async {
      for (var path in [
        'icons/missing.png',
        'icons/a.png',
        'icons/none.png',
        'none.png',
      ]) {
        var res = await _request(url(path));
        expect(res.status, 404, reason: path);
      }
    });

    test('`.aliases` is never served', () async {
      for (var path in [
        '/.aliases',
        '/icons/.aliases',
        '/icons/.ALIASES',
        '/icons/%2Ealiases',
        '/icons%2F.aliases',
        '/icons/sections/../.aliases',
        '/icons/menu/../.aliases',
      ]) {
        expect(await _rawStatus(port, path), 404, reason: path);
      }
    });

    test('path traversal', () async {
      for (var path in [
        '/icons/%2e%2e/%2e%2e/etc/passwd',
        '/icons/..%2f..%2fetc%2fpasswd',
        '/icons/menu/%2e%2e/%2e%2e/%2e%2e/etc/passwd',
        '/../../etc/passwd',
        // An alias whose target is a symlink to a file outside the root:
        '/icons/secret.txt',
        '/icons/sections/secret.txt',
      ]) {
        expect(await _rawStatus(port, path), 404, reason: path);
      }
    });

    test('routes and the root document are unaffected', () async {
      var res = await _request(url('mod/ok'));
      expect(res.status, 200);
      expect(_bodyStr(res), contains('OK'));

      var res2 = await _request(url(''));
      expect(res2.status, 200);
      expect(_bodyStr(res2), contains('ROOT'));
    });
  });
}

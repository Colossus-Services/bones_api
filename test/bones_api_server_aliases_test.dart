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
/// (no client side normalization). Returns the status code and the body.
Future<({int status, String body})> _raw(
  int port,
  String path, {
  String? host,
}) async {
  var socket = await Socket.connect('localhost', port);
  try {
    socket.write(
      'GET $path HTTP/1.1\r\nHost: ${host ?? 'localhost:$port'}\r\n'
      'Connection: close\r\n\r\n',
    );
    await socket.flush();
    var response = await utf8.decoder
        .bind(socket)
        .join()
        .timeout(Duration(seconds: 10));
    var statusLine = response.split('\r\n').first;
    var idx = response.indexOf('\r\n\r\n');
    return (
      status: int.parse(statusLine.split(' ')[1]),
      body: idx >= 0 ? response.substring(idx + 4) : '',
    );
  } finally {
    socket.destroy();
  }
}

Future<int> _rawStatus(int port, String path) async =>
    (await _raw(port, path)).status;

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

    test('AliasEntry.match', () {
      var table = _parse('''
v2/favicon.ico = brand/favicon.ico
menu/ = sections/
./ = all/
''');
      var file = table.entries[0];
      expect(file.match(['v2', 'favicon.ico']), ['brand', 'favicon.ico']);
      expect(file.match(['v2', 'other.ico']), isNull);
      expect(file.match(['favicon.ico']), isNull);

      var dir = table.entries[1];
      expect(dir.match(['menu', 'a', 'b.png']), ['sections', 'a', 'b.png']);
      expect(dir.match(['menux', 'b.png']), isNull);

      expect(table.entries[2].match(['x.png']), ['all', 'x.png']);
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
${'?' * 9}.png = x/
''', invalid);

      expect(table.isEmpty, isTrue);
      expect(invalid, hasLength(12));
      expect(invalid.last, contains('too many wildcards'));
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

    test('patterns: greedy captures', () {
      var table = _parse('''
*-*.gif = x/*-*.gif
**/*.svg = v/**/*.svg
''');
      // Like a `RegExp`, the first `*` takes the longest match:
      expect(_candidates(table, 'a-b-c.gif'), [
        ['x', 'a-b-c.gif'],
      ]);
      expect(_candidates(table, 'a/b/c.svg'), [
        ['v', 'a', 'b', 'c.svg'],
      ]);

      var table2 = _parse('*-*.gif = x/*.gif');
      expect(_candidates(table2, 'a-b-c.gif'), [
        ['x', 'a-b.gif'],
      ]);
    });

    test('patterns: no catastrophic backtracking', () {
      var table = _parse('''
**/**/**/**/**/**/**/*.png = x/
*a*a*a*a*a*a*a*b = y/
''');
      expect(table.entries, hasLength(2));

      var deepPath = [for (var i = 0; i < 63; ++i) 's$i', 'z.jpg'].join('/');
      var longSegment = 'a' * 1000;

      var sw = Stopwatch()..start();
      expect(_candidates(table, deepPath), isEmpty);
      expect(_candidates(table, longSegment), isEmpty);
      // Over the max match length, never matched:
      expect(_candidates(table, '${'a' * 2000}b'), isEmpty);
      expect(sw.elapsed, lessThan(Duration(seconds: 5)));

      // Still matching:
      expect(_candidates(table, 'a/b/c.png'), [
        ['x', 'a', 'b', 'c.png'],
      ]);
      expect(_candidates(table, 'aaaaaaaab'), [
        ['y', 'aaaaaaaab'],
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

    test('an entry is applied once per chain (no nested overlay)', () {
      _write(root, 'icons/sections/sections/deep.png', 'DEEP');
      _write(root, 'icons/vector/vector/x.svg', 'SVG');
      _write(root, 'icons/.aliases', '''
./ = sections/
**/*.svg = vector/**/*.svg
''');
      var aliases = newAliases();

      // Only `icons/sections/sections/deep.png` exists: reaching it from
      // `icons/deep.png` would need the overlay applied twice.
      expect(resolve(aliases, 'icons/deep.png'), isNull);
      expect(
        resolve(aliases, 'icons/sections/deep.png'),
        'icons/sections/sections/deep.png',
      );
      expect(resolve(aliases, 'icons/sections/missing.png'), isNull);

      expect(resolve(aliases, 'icons/x.svg'), isNull);
      expect(
        resolve(aliases, 'icons/vector/x.svg'),
        'icons/vector/vector/x.svg',
      );
    });

    test('a chain through several entries and nested `.aliases`', () {
      _write(root, 'icons/.aliases', '''
a*.png = x-*.png
x-.png = b.png
./ = sections/
''');
      _write(root, 'icons/sections/.aliases', 'b.png = food.png\n');
      var aliases = newAliases();

      // a.png → x-.png → b.png → sections/b.png → sections/food.png
      expect(resolve(aliases, 'icons/a.png'), 'icons/sections/food.png');
      expect(resolve(aliases, 'icons/b.png'), 'icons/sections/food.png');
      expect(resolve(aliases, 'icons/x-.png'), 'icons/sections/food.png');
    });

    test('the caches are bounded', () {
      var total = StaticFilesAliases.maxCacheEntries + 10;
      for (var i = 0; i < total; ++i) {
        Directory(pack_path.join(root.path, 'd$i')).createSync();
      }
      // An overlay applies to every path: each one is a cached resolution.
      _write(root, '.aliases', './ = icons/\n');
      var aliases = StaticFilesAliases(root);

      for (var i = 0; i < total; ++i) {
        expect(resolve(aliases, 'd$i/x.png'), isNull);
      }
      expect(resolve(aliases, 'sections/food.png'), 'icons/sections/food.png');

      expect(
        aliases.cachedDirectoriesLength,
        lessThanOrEqualTo(StaticFilesAliases.maxCacheEntries),
      );
      expect(
        aliases.cachedResolutionsLength,
        lessThanOrEqualTo(StaticFilesAliases.maxCacheEntries),
      );
      // Only the oldest entries are evicted (not a full clear):
      expect(
        aliases.cachedDirectoriesLength,
        greaterThan(StaticFilesAliases.maxCacheEntries ~/ 2),
      );
      expect(
        aliases.cachedResolutionsLength,
        greaterThan(StaticFilesAliases.maxCacheEntries ~/ 2),
      );
    });

    test('the caches are bounded: directories with `.aliases`', () {
      var total = StaticFilesAliases.maxCacheEntries + 10;
      for (var i = 0; i < total; ++i) {
        _write(root, 'd$i/.aliases', 'x.png = y.png\n');
      }
      _write(root, 'd0/y.png', 'Y');
      var aliases = StaticFilesAliases(root);

      for (var i = 0; i < total; ++i) {
        expect(resolve(aliases, 'd$i/x.png'), i == 0 ? 'd0/y.png' : isNull);
      }

      expect(
        aliases.cachedDirectoriesLength,
        lessThanOrEqualTo(StaticFilesAliases.maxCacheEntries),
      );
      expect(resolve(aliases, 'd0/x.png'), 'd0/y.png');
    });

    test('missing directories are cached until `checkInterval`', () {
      var aliases = StaticFilesAliases(root, checkInterval: Duration(hours: 1));

      expect(resolve(aliases, 'late/x.png'), isNull);

      _write(root, 'late/y.png', 'Y');
      _write(root, 'late/.aliases', 'x.png = y.png\n');

      // `late` is still known as missing:
      expect(resolve(aliases, 'late/x.png'), isNull);
      expect(aliases.cachedDirectoriesLength, 1);

      aliases.clearCache();
      expect(resolve(aliases, 'late/x.png'), 'late/y.png');
    });

    test('a directory removed after being cached', () {
      _write(root, 'gone/y.png', 'Y');
      _write(root, 'gone/.aliases', 'x.png = y.png\n');
      var aliases = newAliases();

      expect(resolve(aliases, 'gone/x.png'), 'gone/y.png');

      Directory(pack_path.join(root.path, 'gone')).deleteSync(recursive: true);
      expect(resolve(aliases, 'gone/x.png'), isNull);
      expect(aliases.cachedResolutionsLength, 0);

      // Re-created: no longer missing (`checkInterval` zero).
      _write(root, 'gone/y.png', 'Y');
      _write(root, 'gone/.aliases', 'x.png = y.png\n');
      expect(resolve(aliases, 'gone/x.png'), 'gone/y.png');
    });

    test('random paths are not cached', () {
      _write(root, 'icons/.aliases', './ = sections/\n');
      var aliases = StaticFilesAliases(root);

      for (var i = 0; i < 50; ++i) {
        expect(resolve(aliases, 'r$i/s$i/t$i/x.png'), isNull);
      }
      // Only the root (an existing directory) is cached:
      expect(aliases.cachedDirectoriesLength, 1);
      expect(aliases.cachedResolutionsLength, 0);

      expect(resolve(aliases, 'icons/food.png'), 'icons/sections/food.png');
      expect(aliases.cachedDirectoriesLength, 2);
      expect(aliases.cachedResolutionsLength, 1);

      // A physical file under an overlay: cached as unchanged.
      expect(resolve(aliases, 'icons/sections/food.png'), isNull);
      expect(aliases.cachedResolutionsLength, 2);
      // No applicable alias: nothing cached.
      expect(resolve(aliases, 'other/x.png'), isNull);
      expect(aliases.cachedResolutionsLength, 2);
    });

    test('a removed `.aliases` invalidates the cached resolutions', () async {
      _write(root, 'icons/.aliases', 'a.png = sections/food.png\n');
      var aliases = StaticFilesAliases(
        root,
        checkInterval: Duration(milliseconds: 200),
      );

      expect(resolve(aliases, 'icons/a.png'), 'icons/sections/food.png');
      expect(aliases.cachedResolutionsLength, 1);

      File(pack_path.join(root.path, 'icons', '.aliases')).deleteSync();
      await Future.delayed(Duration(milliseconds: 250));

      // Any request re-checking `icons/.aliases` drops all resolutions:
      expect(resolve(aliases, 'icons/b.png'), isNull);
      expect(aliases.cachedResolutionsLength, 0);
      expect(resolve(aliases, 'icons/a.png'), isNull);
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

    test('unchanged request, `.aliases` 404, directory 302', () async {
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

      var r302 = await handler(
        Request('GET', Uri.parse('http://localhost/icons/menu?q=1')),
      );
      expect(r302.statusCode, 302);
      expect(r302.headers['location'], 'http://localhost/icons/menu/?q=1');
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

      _write(docRoot, '.aliases', 'logo.svg = icons/vector/a/b/logo.svg\n');
      _write(docRoot, 'icons/sections/.aliases', 'special.png = food.png\n');

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

    test('root and nested `.aliases`', () async {
      var res = await _request(url('logo.svg'));
      expect(res.status, 200);
      expect(_bodyStr(res), '<svg>LOGO</svg>');

      // `icons/sections/.aliases` (closest), also through the overlay:
      for (var path in ['icons/sections/special.png', 'icons/special.png']) {
        var res2 = await _request(url(path));
        expect(res2.status, 200, reason: path);
        expect(_bodyStr(res2), 'FOOD-PNG', reason: path);
      }

      // The overlay is not nested (`sections/sections/...`):
      expect((await _request(url('icons/sections/none.png'))).status, 404);
    });

    test('HEAD and conditional requests', () async {
      var client = HttpClient();
      try {
        var req = await client.openUrl(
          'HEAD',
          Uri.parse(url('icons/food.png')),
        );
        var res = await req.close();
        var body = await res.expand((e) => e).toList();
        expect(res.statusCode, 200);
        expect(body, isEmpty);

        var lastModified = res.headers.value(HttpHeaders.lastModifiedHeader);
        expect(lastModified, isNotNull);

        var res304 = await _request(
          url('icons/food.png'),
          headers: {HttpHeaders.ifModifiedSinceHeader: lastModified!},
        );
        expect(res304.status, 304);
        expect(res304.body, isEmpty);
      } finally {
        client.close(force: true);
      }
    });

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

    test('directory alias: 302 to the virtual path, then index.html', () async {
      var res = await _request(url('icons/menu?x=1'));
      expect(res.status, 302);
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

  group('APIServer + .aliases: same pipeline as a physical file', () {
    late Directory docRoot;
    late APIServer apiServer;

    setUpAll(() async {
      docRoot = await Directory.systemTemp.createTemp('bones_api_aliases_mw_');

      _write(docRoot, 'site/pages/page.html', '<html>${'PAGE ' * 300}</html>');
      _write(docRoot, 'site/pages/page2.html', '<html>PAGE2</html>');
      _write(docRoot, 'styles/main/app.css', 'body { color: red; }');
      _write(docRoot, 'big/data.txt', 'BIG DATA ' * 500);
      _write(docRoot, 'img/food.png', 'FOOD-PNG');
      _write(docRoot, '.aliases', '''
page.html = site/pages/page.html
page2.html = site/pages/page2.html
app.css = styles/main/app.css
data.txt = big/data.txt
food.png = img/food.png
''');

      var port = await resolveFreePort(6800);

      apiServer = APIServer(
        _AliasesAPIRoot('aliases-pipeline'),
        'localhost',
        port,
        documentRoot: docRoot.path,
        cookieless: true,
        logToConsole: false,
        cacheStaticFilesResponses: true,
        longLivedStaticFilesCached: [RegExp(r'\.css$')],
        longLivedStaticFilesCacheControl: 'max-age=7777',
        staticFilesCacheControl: 'max-age=11',
        crossOrigin: APICrossOriginConfig(
          staticFiles: APICrossOriginPolicies(
            embedderPolicy: 'require-corp',
            resourcePolicy: 'same-site',
          ),
        ),
      );

      await apiServer.start();
    });

    tearDownAll(() async {
      await apiServer.stop();
      await docRoot.delete(recursive: true);
    });

    String url(String path) => '${apiServer.url}$path';

    /// The headers set by the static files pipeline (not request dependent).
    const pipelineHeaders = [
      'content-type',
      'content-length',
      'content-encoding',
      'last-modified',
      'accept-ranges',
      'cache-control',
      'server',
      'cross-origin-resource-policy',
      'cross-origin-opener-policy',
      'cross-origin-embedder-policy',
      APIServer.headerXCookielessServer,
    ];

    Map<String, String?> headersOf(_Res res) => {
      for (var h in pipelineHeaders) h: res.headers.value(h),
    };

    test('HTML: headers, cross-origin policies and response cache', () async {
      // Via the alias first: a fresh (un-cached) response.
      var aliased = await _request(url('page.html'));
      expect(aliased.status, 200);
      expect(_bodyStr(aliased), startsWith('<html>PAGE'));
      expect(aliased.headers.value('x-api-server-cache'), isNull);

      expect(aliased.headers.contentType?.mimeType, 'text/html');
      expect(aliased.headers.value('cache-control'), 'max-age=11');
      expect(aliased.headers.value('server'), isNotEmpty);
      expect(
        aliased.headers.value('cross-origin-embedder-policy'),
        'require-corp',
      );
      expect(
        aliased.headers.value('cross-origin-opener-policy'),
        APICrossOriginPolicies.defaultOpenerPolicy,
      );
      expect(
        aliased.headers.value('cross-origin-resource-policy'),
        'same-site',
      );
      expect(
        aliased.headers.value(APIServer.headerXCookielessServer),
        APIServer.headerXCookielessServerValue,
      );
      expect(aliased.headers.value('set-cookie'), isNull);

      // The physical path: the same cached response (the cache key is the
      // physical path), with the same pipeline headers.
      var physical = await _request(url('site/pages/page.html'));
      expect(physical.status, 200);
      expect(physical.body, aliased.body);
      expect(physical.headers.value('x-api-server-cache'), isNotNull);
      expect(headersOf(physical), headersOf(aliased));

      // The alias again: also served from the cache.
      var aliased2 = await _request(url('page.html'));
      expect(aliased2.status, 200);
      expect(aliased2.body, aliased.body);
      expect(aliased2.headers.value('x-api-server-cache'), isNotNull);
      expect(headersOf(aliased2), headersOf(aliased));
    });

    test('physical first, then alias: cached', () async {
      var physical = await _request(url('site/pages/page2.html'));
      expect(physical.status, 200);
      expect(physical.headers.value('x-api-server-cache'), isNull);

      var aliased = await _request(url('page2.html'));
      expect(aliased.status, 200);
      expect(_bodyStr(aliased), '<html>PAGE2</html>');
      expect(aliased.headers.value('x-api-server-cache'), isNotNull);
      expect(headersOf(aliased), headersOf(physical));
    });

    test('long-lived Cache-Control (physical path rules)', () async {
      var aliased = await _request(url('app.css'));
      expect(aliased.status, 200);
      expect(aliased.headers.contentType?.mimeType, 'text/css');
      expect(aliased.headers.value('cache-control'), 'max-age=7777');
      // Not an HTML document: no COOP/COEP, only CORP.
      expect(aliased.headers.value('cross-origin-opener-policy'), isNull);
      expect(
        aliased.headers.value('cross-origin-resource-policy'),
        'same-site',
      );

      var physical = await _request(url('styles/main/app.css'));
      expect(headersOf(physical), headersOf(aliased));
    });

    test('gzip', () async {
      var gzipHeaders = {'accept-encoding': 'gzip'};

      var aliased = await _request(url('data.txt'), headers: gzipHeaders);
      expect(aliased.status, 200);
      expect(aliased.headers.value('content-encoding'), 'gzip');
      expect(aliased.body.length, lessThan(500 * 9));
      expect(_bodyStr(aliased), 'BIG DATA ' * 500);

      var physical = await _request(url('big/data.txt'), headers: gzipHeaders);
      expect(physical.headers.value('content-encoding'), 'gzip');
      expect(_bodyStr(physical), _bodyStr(aliased));
      expect(headersOf(physical), headersOf(aliased));

      // Without gzip (`HttpClient` sends `accept-encoding: gzip` by default):
      var identity = {'accept-encoding': 'identity'};
      var aliasedPlain = await _request(url('data.txt'), headers: identity);
      expect(aliasedPlain.headers.value('content-encoding'), isNull);
      expect(_bodyStr(aliasedPlain), 'BIG DATA ' * 500);

      var physicalPlain = await _request(
        url('big/data.txt'),
        headers: identity,
      );
      expect(headersOf(physicalPlain), headersOf(aliasedPlain));
    });

    test('conditional request: 304 (cached) via the alias', () async {
      var aliased = await _request(url('food.png'));
      expect(aliased.status, 200);
      expect(aliased.headers.contentType?.mimeType, 'image/png');

      var lastModified = aliased.headers.value(HttpHeaders.lastModifiedHeader);
      expect(lastModified, isNotNull);

      for (var path in ['food.png', 'img/food.png']) {
        var res = await _request(
          url(path),
          headers: {HttpHeaders.ifModifiedSinceHeader: lastModified!},
        );
        expect(res.status, 304, reason: path);
        expect(res.body, isEmpty, reason: path);
      }

      // The second 304 is served by the response cache:
      var res = await _request(
        url('food.png'),
        headers: {HttpHeaders.ifModifiedSinceHeader: lastModified!},
      );
      expect(res.headers.value('x-api-server-cache'), isNotNull);
    });
  });

  group('APIServer + .aliases + domains', () {
    late Directory rootA;
    late Directory rootB;
    late APIServer apiServer;
    late int port;

    setUpAll(() async {
      rootA = await Directory.systemTemp.createTemp('bones_api_aliases_a_');
      rootB = await Directory.systemTemp.createTemp('bones_api_aliases_b_');

      _write(rootA, 'img/a.png', 'A-PNG');
      _write(rootA, '.aliases', 'logo.png = img/a.png\n');
      _write(rootB, 'img/b.png', 'B-PNG');
      _write(rootB, '.aliases', 'logo.png = img/b.png\n');

      port = await resolveFreePort(6750);

      apiServer = APIServer(
        _AliasesAPIRoot('aliases-domains'),
        'localhost',
        port,
        domains: {'a.local': rootA.path, 'b.local': rootB.path},
        logToConsole: false,
      );

      await apiServer.start();
    });

    tearDownAll(() async {
      await apiServer.stop();
      await rootA.delete(recursive: true);
      await rootB.delete(recursive: true);
    });

    test('each domain root has its own `.aliases`', () async {
      var a = await _raw(port, '/logo.png', host: 'a.local');
      expect(a.status, 200);
      expect(a.body, 'A-PNG');

      var b = await _raw(port, '/logo.png', host: 'b.local');
      expect(b.status, 200);
      expect(b.body, 'B-PNG');

      expect((await _raw(port, '/.aliases', host: 'a.local')).status, 404);
      expect((await _raw(port, '/img/b.png', host: 'a.local')).status, 404);
    });
  });
}

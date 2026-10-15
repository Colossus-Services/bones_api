import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart' show mergeSort;
import 'package:logging/logging.dart' as logging;
import 'package:path/path.dart' as pack_path;
import 'package:shelf/shelf.dart';

final _log = logging.Logger('StaticFilesAliases');

/// The kind of an [AliasEntry].
enum AliasKind {
  /// `food.png = sections/food.png`: an exact virtual file path.
  file,

  /// `menu/ = sections/`: a virtual directory prefix.
  directory,

  /// `*.png = sections/*.png` or `**/*.svg = vector/`: a wildcard pattern.
  pattern,

  /// `./ = sections/`: a fallback directory for any unresolved path.
  overlay,
}

/// A parsed entry of a `.aliases` file. See [AliasesTable].
class AliasEntry {
  /// The kind of this alias.
  final AliasKind kind;

  /// The line number (1-based) of this entry in the `.aliases` file.
  final int line;

  /// The virtual side, as written (trimmed).
  final String virtualPath;

  /// The target side, as written (trimmed).
  final String targetPath;

  /// The virtual path segments ([AliasKind.file] and [AliasKind.directory]).
  final List<String> virtualSegments;

  /// The target path segments (all kinds, except a [AliasKind.pattern] with
  /// a substitution target).
  final List<String> targetSegments;

  /// The tokens of a [AliasKind.pattern]: [String] literals and [_Wildcard]s.
  final List<Object>? _patternTokens;

  /// The substitution target of a [AliasKind.pattern]: a [String] literal
  /// or an [int] capture index.
  final List<Object>? _targetParts;

  AliasEntry._(
    this.kind,
    this.line,
    this.virtualPath,
    this.targetPath, {
    this.virtualSegments = const [],
    this.targetSegments = const [],
    List<Object>? patternTokens,
    List<Object>? targetParts,
  }) : _patternTokens = patternTokens,
       _targetParts = targetParts;

  /// Returns the target segments for the [remaining] request path segments
  /// (relative to the `.aliases` directory), or `null` if it doesn't match.
  List<String>? match(List<String> remaining) {
    switch (kind) {
      case AliasKind.file:
        return _equalsSegments(remaining, virtualSegments)
            ? targetSegments
            : null;
      case AliasKind.directory:
        if (remaining.length < virtualSegments.length) return null;
        for (var i = 0; i < virtualSegments.length; ++i) {
          if (remaining[i] != virtualSegments[i]) return null;
        }
        return [
          ...targetSegments,
          ...remaining.sublist(virtualSegments.length),
        ];
      case AliasKind.overlay:
        return [...targetSegments, ...remaining];
      case AliasKind.pattern:
        return _matchPattern(remaining);
    }
  }

  List<String>? _matchPattern(List<String> remaining) {
    var path = remaining.join('/');
    if (path.length > AliasesTable.maxPatternMatchLength) return null;

    var captures = _matchGlob(_patternTokens!, path);
    if (captures == null) return null;

    var targetParts = _targetParts;
    if (targetParts == null) {
      return [...targetSegments, ...remaining];
    }

    var s = StringBuffer();
    for (var p in targetParts) {
      if (p is int) {
        s.write(captures[p]);
      } else {
        s.write(p);
      }
    }

    var segments = s.toString().split('/');
    // A capture can be empty (`*` matches nothing), producing an invalid path:
    if (!segments.every(AliasesTable._isValidSegment)) return null;
    return segments;
  }

  /// Matches [s] against the pattern [tokens], returning the wildcards
  /// captures (in order), or `null` if it doesn't match.
  ///
  /// Wildcards are greedy (longest match first), like a `RegExp`, but the
  /// failed `(token, position)` states are memoized, so the matching is
  /// polynomial (no catastrophic backtracking).
  static List<String>? _matchGlob(List<Object> tokens, String s) {
    var wildcardsIndexes = <int>[];
    for (var i = 0; i < tokens.length; ++i) {
      if (tokens[i] is _Wildcard) wildcardsIndexes.add(i);
    }

    var captures = List<String>.filled(tokens.length, '');
    var failed = <int>{};
    var width = s.length + 1;

    bool go(int i, int p) {
      if (i == tokens.length) return p == s.length;

      var key = i * width + p;
      if (failed.contains(key)) return false;

      var t = tokens[i];
      var ok = false;

      if (t is String) {
        ok = s.startsWith(t, p) && go(i + 1, p + t.length);
      } else if (t == _Wildcard.question) {
        if (p < s.length &&
            s.codeUnitAt(p) != 0x2F /* / */ &&
            go(i + 1, p + 1)) {
          captures[i] = s.substring(p, p + 1);
          ok = true;
        }
      } else if (t == _Wildcard.star) {
        var end = s.indexOf('/', p);
        if (end < 0) end = s.length;
        for (var e = end; e >= p; --e) {
          if (go(i + 1, e)) {
            captures[i] = s.substring(p, e);
            ok = true;
            break;
          }
        }
      } else {
        // `**/`: zero or more whole segments, each followed by `/`:
        var ends = <int>[p];
        var e = p;
        while (true) {
          var slash = s.indexOf('/', e);
          if (slash < 0 || slash == e) break;
          e = slash + 1;
          ends.add(e);
        }
        for (var e in ends.reversed) {
          if (go(i + 1, e)) {
            captures[i] = s.substring(p, e);
            ok = true;
            break;
          }
        }
      }

      if (!ok) failed.add(key);
      return ok;
    }

    if (!go(0, 0)) return null;

    return [for (var i in wildcardsIndexes) captures[i]];
  }

  static bool _equalsSegments(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; ++i) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => '$virtualPath = $targetPath  # ${kind.name} @$line';
}

/// The parsed content of a `.aliases` file.
///
/// One mapping per line: `<virtual> = <target>`, both relative to the
/// directory of the `.aliases` file. See the README section
/// "Static files: `.aliases`".
class AliasesTable {
  /// The maximum length of a pattern (each side).
  static const int maxPatternLength = 256;

  /// The maximum number of wildcards of a pattern.
  static const int maxPatternWildcards = 8;

  /// Request paths (relative to the `.aliases` directory) longer than this
  /// are not matched against patterns.
  static const int maxPatternMatchLength = 1024;

  /// All the valid entries, in file order.
  final List<AliasEntry> entries;

  final Map<String, AliasEntry> _files;
  final List<AliasEntry> _directories;
  final List<AliasEntry> _patterns;
  final AliasEntry? _overlay;

  AliasesTable._(this.entries)
    : _files = {
        for (var e in entries.where((e) => e.kind == AliasKind.file))
          e.virtualSegments.join('/'): e,
      },
      // Longest prefix first (stable: same length keeps the file order):
      _directories = _sortedByPrefixLength(
        entries.where((e) => e.kind == AliasKind.directory),
      ),
      _patterns = entries.where((e) => e.kind == AliasKind.pattern).toList(),
      _overlay = entries.where((e) => e.kind == AliasKind.overlay).firstOrNull;

  static List<AliasEntry> _sortedByPrefixLength(Iterable<AliasEntry> entries) {
    var list = entries.toList();
    // `mergeSort` is stable: the same length keeps the file order.
    mergeSort<AliasEntry>(
      list,
      compare: (a, b) =>
          b.virtualSegments.length.compareTo(a.virtualSegments.length),
    );
    return list;
  }

  bool get isEmpty => entries.isEmpty;

  bool get isNotEmpty => entries.isNotEmpty;

  /// The candidate targets for the [remaining] request path segments
  /// (relative to the `.aliases` directory), in precedence order:
  /// exact file alias, longest directory prefix, patterns (file order),
  /// overlay.
  Iterable<List<String>> candidates(List<String> remaining) =>
      matches(remaining).map((m) => m.target);

  /// Same as [candidates], with the matching [AliasEntry].
  Iterable<({AliasEntry entry, List<String> target})> matches(
    List<String> remaining,
  ) sync* {
    var file = _files[remaining.join('/')];
    if (file != null) yield (entry: file, target: file.targetSegments);

    for (var e in _directories) {
      var t = e.match(remaining);
      if (t != null) yield (entry: e, target: t);
    }

    for (var e in _patterns) {
      var t = e.match(remaining);
      if (t != null) yield (entry: e, target: t);
    }

    var overlay = _overlay;
    if (overlay != null) {
      yield (entry: overlay, target: overlay.match(remaining)!);
    }
  }

  /// Parses a `.aliases` [content]. Invalid lines are skipped and reported
  /// to [onInvalid]; this never throws.
  factory AliasesTable.parse(
    String content, {
    void Function(int line, String reason)? onInvalid,
  }) {
    var entries = <AliasEntry>[];
    var keys = <String>{};

    var lines = const LineSplitter().convert(content);

    for (var i = 0; i < lines.length; ++i) {
      var lineNumber = i + 1;
      var line = _stripComment(lines[i]).trim();
      if (line.isEmpty) continue;

      try {
        var entry = _parseLine(lineNumber, line);
        if (!keys.add(entry.virtualPath)) {
          throw FormatException(
            "duplicated virtual path: ${entry.virtualPath}",
          );
        }
        entries.add(entry);
      } on FormatException catch (e) {
        onInvalid?.call(lineNumber, e.message);
      }
    }

    return AliasesTable._(entries);
  }

  /// A `#` starts a comment at the line start or after a whitespace,
  /// so a file name like `a#b.png` is kept.
  static String _stripComment(String line) {
    for (var i = 0; i < line.length; ++i) {
      if (line.codeUnitAt(i) == 0x23 /* # */ &&
          (i == 0 || _isWhitespace(line.codeUnitAt(i - 1)))) {
        return line.substring(0, i);
      }
    }
    return line;
  }

  static bool _isWhitespace(int c) => c == 0x20 || c == 0x09;

  static AliasEntry _parseLine(int lineNumber, String line) {
    var idx = line.indexOf('=');
    if (idx < 0) throw FormatException("missing '='");

    var v = line.substring(0, idx).trim();
    var t = line.substring(idx + 1).trim();

    if (v.isEmpty || t.isEmpty) throw FormatException("empty path");

    _checkChars(v);
    _checkChars(t);

    var vIsPattern = _hasWildcard(v);
    var tHasWildcards = _hasWildcard(t);
    var vIsDir = v.endsWith('/');
    var tIsDir = t.endsWith('/');

    if (!vIsPattern && tHasWildcards) {
      throw FormatException("wildcards in the target of a non-pattern alias");
    }

    if (v == './') {
      if (!tIsDir) {
        throw FormatException("an overlay (`./`) target must be a directory");
      }
      return AliasEntry._(
        AliasKind.overlay,
        lineNumber,
        v,
        t,
        targetSegments: _segments(t),
      );
    }

    var virtualSegments = _segments(v, allowWildcards: vIsPattern);

    if (vIsPattern) {
      return _parsePattern(lineNumber, v, t, virtualSegments);
    }

    if (vIsDir != tIsDir) {
      throw FormatException(
        "file/directory mismatch (a directory alias ends both sides with '/')",
      );
    }

    return AliasEntry._(
      vIsDir ? AliasKind.directory : AliasKind.file,
      lineNumber,
      v,
      t,
      virtualSegments: virtualSegments,
      targetSegments: _segments(t),
    );
  }

  static AliasEntry _parsePattern(
    int lineNumber,
    String v,
    String t,
    List<String> virtualSegments,
  ) {
    if (v.length > maxPatternLength || t.length > maxPatternLength) {
      throw FormatException("pattern too long (max: $maxPatternLength)");
    }

    if (v.endsWith('/')) {
      throw FormatException("a pattern can't end with '/'");
    }

    var vTokens = _tokenize(v);
    var vWildcards = vTokens.whereType<_Wildcard>().toList();

    if (vWildcards.length > maxPatternWildcards) {
      throw FormatException("too many wildcards (max: $maxPatternWildcards)");
    }

    if (!_hasWildcard(t)) {
      if (!t.endsWith('/')) {
        throw FormatException(
          "a pattern target must use the same wildcards or be a directory "
          "(ending with '/')",
        );
      }
      return AliasEntry._(
        AliasKind.pattern,
        lineNumber,
        v,
        t,
        targetSegments: _segments(t),
        patternTokens: vTokens,
      );
    }

    if (t.endsWith('/')) {
      throw FormatException(
        "a pattern target with wildcards can't end with '/'",
      );
    }

    _segments(t, allowWildcards: true);

    var tTokens = _tokenize(t);
    var tWildcards = tTokens.whereType<_Wildcard>().toList();

    if (tWildcards.length > vWildcards.length) {
      throw FormatException("the target has more wildcards than the pattern");
    }
    for (var i = 0; i < tWildcards.length; ++i) {
      if (tWildcards[i] != vWildcards[i]) {
        throw FormatException(
          "the target wildcards must follow the pattern wildcards in order",
        );
      }
    }

    var targetParts = <Object>[];
    var capture = 0;
    for (var tk in tTokens) {
      if (tk is _Wildcard) {
        targetParts.add(capture++);
      } else {
        targetParts.add(tk);
      }
    }

    return AliasEntry._(
      AliasKind.pattern,
      lineNumber,
      v,
      t,
      patternTokens: vTokens,
      targetParts: targetParts,
    );
  }

  static bool _hasWildcard(String s) => s.contains('*') || s.contains('?');

  static void _checkChars(String s) {
    if (s.startsWith('/')) throw FormatException("absolute path: $s");
    if (s.contains('\\')) throw FormatException("'\\' not allowed: $s");
    for (var c in s.codeUnits) {
      if (c < 0x20 || c == 0x7f) {
        throw FormatException("control character not allowed");
      }
    }
  }

  /// Splits [path] (an optional trailing `/` is ignored) and validates
  /// each segment.
  static List<String> _segments(String path, {bool allowWildcards = false}) {
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);

    var segments = path.split('/');
    for (var s in segments) {
      if (!_isValidSegment(s)) {
        throw FormatException("invalid path segment: `$s`");
      }
      if (allowWildcards && s.contains('**') && s != '**') {
        throw FormatException("`**` must be a whole path segment");
      }
    }

    if (allowWildcards && segments.last == '**') {
      throw FormatException(
        "a pattern can't end with `**` (use a directory alias)",
      );
    }

    return segments;
  }

  static bool _isValidSegment(String s) =>
      s.isNotEmpty &&
      s != '.' &&
      s != '..' &&
      !s.contains('/') &&
      !s.contains('\\') &&
      !StaticFilesAliases.isAliasesFileName(s);

  /// Tokenizes a pattern into [String] literals and [_Wildcard]s.
  /// A `**` segment is tokenized together with its following `/`.
  static List<Object> _tokenize(String pattern) {
    var tokens = <Object>[];
    var literal = StringBuffer();

    void flush() {
      if (literal.isNotEmpty) {
        tokens.add(literal.toString());
        literal.clear();
      }
    }

    for (var i = 0; i < pattern.length; ++i) {
      var c = pattern[i];
      if (c == '*' &&
          pattern.startsWith('**/', i) &&
          (i == 0 || pattern[i - 1] == '/')) {
        flush();
        tokens.add(_Wildcard.anySegments);
        i += 2;
      } else if (c == '*') {
        flush();
        tokens.add(_Wildcard.star);
      } else if (c == '?') {
        flush();
        tokens.add(_Wildcard.question);
      } else {
        literal.write(c);
      }
    }

    flush();
    return tokens;
  }
}

enum _Wildcard {
  /// `*`: any characters inside a segment.
  star,

  /// `?`: one character inside a segment.
  question,

  /// `**/`: zero or more whole segments (the capture keeps the trailing `/`).
  anySegments,
}

/// The result of [StaticFilesAliases.resolve].
class StaticFileAliasResolution {
  /// The physical path segments, relative to the root directory.
  final List<String> segments;

  /// `true` if the resolved path is a directory.
  final bool isDirectory;

  const StaticFileAliasResolution(this.segments, {required this.isDirectory});

  String get path => segments.join('/');

  @override
  String toString() => '$path${isDirectory ? '/' : ''}';
}

class _CachedTable {
  final AliasesTable? table;
  final DateTime? modified;
  final int? size;
  DateTime checkTime;

  _CachedTable(this.table, this.modified, this.size, this.checkTime);
}

class _ResolveState {
  /// The remaining candidates to check (see [StaticFilesAliases.maxResolutionAttempts]).
  int attempts = StaticFilesAliases.maxResolutionAttempts;

  /// `true` once any alias applies to the request path.
  bool sawCandidate = false;

  /// `true` if the request path exists physically (served unchanged).
  bool aborted = false;
}

class _CachedResolution {
  final StaticFileAliasResolution? resolution;
  final DateTime time;

  _CachedResolution(this.resolution, this.time);
}

/// Virtual file and directory aliases for static files, defined by
/// `.aliases` files inside the served directory tree.
///
/// - A request for an existing physical path is never changed.
/// - Otherwise the closest `.aliases` (deepest directory first) is
///   consulted: exact file alias, longest directory prefix, patterns
///   (file order), overlay `./`. The first existing target wins.
/// - Targets can chain up to [maxResolutionDepth]; cycles are ignored.
/// - Requests for any `.aliases` file respond `404`.
///
/// `.aliases` files are re-checked at most every [checkInterval].
///
/// See the README section "Static files: `.aliases`".
class StaticFilesAliases {
  /// The aliases file name.
  static const String fileName = '.aliases';

  static const Duration defaultCheckInterval = Duration(seconds: 10);

  /// The maximum length of an aliases chain.
  static const int maxResolutionDepth = 8;

  /// Request paths with more segments are not aliased.
  static const int maxSegments = 64;

  /// The maximum size of a `.aliases` file.
  static const int maxFileSize = 1024 * 64;

  /// The maximum entries of each internal cache, cleared when exceeded.
  static const int maxCacheEntries = 4096;

  /// The maximum candidates checked to resolve a request path.
  static const int maxResolutionAttempts = 64;

  /// Returns `true` if [segment] is the [fileName] (case-insensitive).
  static bool isAliasesFileName(String segment) =>
      segment.length == fileName.length && segment.toLowerCase() == fileName;

  /// Returns `true` if any of the decoded URL [segments] points to a
  /// [fileName], including segments with an encoded `/` or `\`.
  static bool isAliasesFileRequest(List<String> segments) => segments.any(
    (s) =>
        isAliasesFileName(s) ||
        ((s.contains('/') || s.contains('\\')) &&
            s.split(RegExp(r'[/\\]')).any(isAliasesFileName)),
  );

  /// The root directory (normalized, absolute).
  final Directory rootDirectory;

  /// The interval to re-check a `.aliases` file and a resolved path.
  final Duration checkInterval;

  /// Applied to the responses created by this instance (`404` and `302`).
  final Response Function(Request request, Response response)? decorateResponse;

  StaticFilesAliases(
    Directory rootDirectory, {
    this.checkInterval = defaultCheckInterval,
    this.decorateResponse,
  }) : rootDirectory = Directory(
         pack_path.normalize(rootDirectory.absolute.path),
       );

  final Map<String, _CachedTable> _tables = {};
  final Map<String, _CachedResolution> _resolutions = {};

  /// The number of cached directories (only existing ones are cached).
  int get cachedDirectoriesLength => _tables.length;

  /// The number of cached resolutions (only paths with an applicable alias).
  int get cachedResolutionsLength => _resolutions.length;

  /// Clears the cached `.aliases` tables and resolutions.
  void clearCache() {
    _tables.clear();
    _resolutions.clear();
  }

  /// The `shelf` [Middleware]: blocks `.aliases` requests and rewrites
  /// aliased requests to their physical path.
  Middleware get middleware =>
      (innerHandler) => (request) {
        var segments = request.url.pathSegments;

        if (isAliasesFileRequest(segments)) {
          return _decorate(request, Response.notFound('Not Found'));
        }

        var trailingSlash = segments.isNotEmpty && segments.last.isEmpty;

        StaticFileAliasResolution? resolution;
        try {
          resolution = resolve(segments);
        } catch (e, s) {
          // Never break the static files serving:
          _log.severe("Error resolving aliases: /${request.url.path}", e, s);
        }

        if (resolution == null) return innerHandler(request);

        // A `302` (not a cached `301`): an alias can change at any time.
        if (resolution.isDirectory && !trailingSlash) {
          var uri = request.requestedUri;
          return _decorate(
            request,
            Response.found(uri.replace(path: '${uri.path}/')),
          );
        }

        var physical = [...resolution.segments, if (trailingSlash) ''];
        return innerHandler(_rewriteRequest(request, physical));
      };

  Response _decorate(Request request, Response response) {
    var decorateResponse = this.decorateResponse;
    return decorateResponse != null
        ? decorateResponse(request, response)
        : response;
  }

  /// Rewrites [request] to the physical path [segments].
  ///
  /// The body is not carried: a static file handler never reads it, and the
  /// [APIServer] may have already read it (a body can only be read once).
  static Request _rewriteRequest(Request request, List<String> segments) {
    var url = Uri(
      pathSegments: segments,
      query: request.url.hasQuery ? request.url.query : null,
    );

    var handlerPath = request.handlerPath;
    var requestedUri = request.requestedUri.replace(
      path: '$handlerPath${url.path}',
    );

    return Request(
      request.method,
      requestedUri,
      protocolVersion: request.protocolVersion,
      headers: request.headersAll,
      handlerPath: handlerPath,
      url: url,
      context: request.context,
    );
  }

  /// Resolves the decoded URL path [urlSegments] (as `Uri.pathSegments`) to
  /// a physical path through the `.aliases` files. Returns `null` if the
  /// request should be served unchanged (a physical path, no alias, or no
  /// existing target).
  StaticFileAliasResolution? resolve(List<String> urlSegments) {
    var segments = urlSegments;
    var trailingSlash = false;

    if (segments.isNotEmpty && segments.last.isEmpty) {
      trailingSlash = true;
      segments = segments.sublist(0, segments.length - 1);
    }

    if (segments.isEmpty || segments.length > maxSegments) return null;
    if (!segments.every(AliasesTable._isValidSegment)) return null;

    var key = segments.join('/');
    var now = DateTime.now();

    StaticFileAliasResolution? resolution;

    var cached = _resolutions[key];
    if (cached != null && now.difference(cached.time) < checkInterval) {
      resolution = cached.resolution;
    } else {
      var state = _ResolveState();
      resolution = _resolveAliases(segments, 0, {key}, const {}, state);

      if (!state.sawCandidate) {
        // No alias applies: nothing worth caching.
        _resolutions.remove(key);
        return null;
      }

      if (_resolutions.length >= maxCacheEntries) _resolutions.clear();
      _resolutions[key] = _CachedResolution(resolution, now);
    }

    // A file can't be requested as a directory:
    if (resolution != null && trailingSlash && !resolution.isDirectory) {
      return null;
    }

    return resolution;
  }

  /// Resolves [segments] through the `.aliases` of its existing directories,
  /// the deepest first.
  ///
  /// [chainPaths] and [chainEntries] are the paths and entries of the
  /// current chain: a path is never visited twice (a cycle) and an entry is
  /// never applied twice (an overlay or a self-matching pattern would nest
  /// its target forever: `sections/sections/...`).
  StaticFileAliasResolution? _resolveAliases(
    List<String> segments,
    int depth,
    Set<String> chainPaths,
    Set<AliasEntry> chainEntries,
    _ResolveState state,
  ) {
    if (depth >= maxResolutionDepth) return null;

    var tables = _tablesAlong(segments);

    for (var (i, table) in tables.reversed) {
      var dir = segments.sublist(0, i);

      for (var m in table.matches(segments.sublist(i))) {
        if (chainEntries.contains(m.entry)) continue;

        if (!state.sawCandidate) {
          state.sawCandidate = true;
          // The physical path always wins (only checked when an alias applies):
          if (_typeOf(segments) != FileSystemEntityType.notFound) {
            state.aborted = true;
            return null;
          }
        }

        var candidate = [...dir, ...m.target];
        if (candidate.length > maxSegments) continue;

        var candidateKey = candidate.join('/');
        if (chainPaths.contains(candidateKey)) continue;

        if (--state.attempts < 0) return null;

        var type = _typeOf(candidate);
        if (type == FileSystemEntityType.file) {
          return StaticFileAliasResolution(candidate, isDirectory: false);
        } else if (type == FileSystemEntityType.directory) {
          return StaticFileAliasResolution(candidate, isDirectory: true);
        }

        var resolved = _resolveAliases(
          candidate,
          depth + 1,
          {...chainPaths, candidateKey},
          {...chainEntries, m.entry},
          state,
        );
        if (resolved != null) return resolved;
        if (state.aborted || state.attempts < 0) return null;
      }
    }

    return null;
  }

  /// The `.aliases` tables (with their directory depth) of the directories
  /// of [segments], from the root, stopping at the first directory that
  /// doesn't exist (an alias can't be defined below it).
  List<(int, AliasesTable)> _tablesAlong(List<String> segments) {
    var tables = <(int, AliasesTable)>[];
    for (var i = 0; i < segments.length; ++i) {
      var dir = _directory(segments, i);
      if (dir == null) break;
      var table = dir.table;
      if (table != null) tables.add((i, table));
    }
    return tables;
  }

  String _pathOf(List<String> segments) =>
      pack_path.joinAll([rootDirectory.path, ...segments]);

  FileSystemEntityType _typeOf(List<String> segments) {
    var path = _pathOf(segments);
    // Segments are validated, but never look outside the root:
    if (!pack_path.isWithin(rootDirectory.path, path)) {
      return FileSystemEntityType.notFound;
    }
    return FileSystemEntity.typeSync(path);
  }

  /// The cached directory of the first [length] [segments], or `null` if it
  /// doesn't exist. Only existing directories are cached, so random request
  /// paths can't fill the cache.
  _CachedTable? _directory(List<String> segments, int length) {
    var dirSegments = segments.sublist(0, length);
    var key = dirSegments.join('/');
    var now = DateTime.now();

    var cached = _tables[key];
    if (cached != null && now.difference(cached.checkTime) < checkInterval) {
      return cached;
    }

    if (length > 0 && _typeOf(dirSegments) != FileSystemEntityType.directory) {
      if (_tables.remove(key)?.table != null) _resolutions.clear();
      return null;
    }

    var file = File(_pathOf([...dirSegments, fileName]));
    var stat = file.statSync();

    if (stat.type != FileSystemEntityType.file) {
      // A removed `.aliases`: previous resolutions may be stale.
      if (cached?.table != null) _resolutions.clear();
      return _putTable(key, _CachedTable(null, null, null, now));
    }

    if (cached != null &&
        cached.modified == stat.modified &&
        cached.size == stat.size) {
      cached.checkTime = now;
      return cached;
    }

    var table = _loadTable(file, stat);

    // A new or changed `.aliases`: previous resolutions may be stale.
    _resolutions.clear();

    return _putTable(key, _CachedTable(table, stat.modified, stat.size, now));
  }

  _CachedTable _putTable(String key, _CachedTable cached) {
    if (_tables.length >= maxCacheEntries) {
      _tables.clear();
      _resolutions.clear();
    }
    _tables[key] = cached;
    return cached;
  }

  String? _rootResolved;

  AliasesTable? _loadTable(File file, FileStat stat) {
    try {
      var rootResolved = _rootResolved ??= rootDirectory
          .resolveSymbolicLinksSync();

      var fileResolved = file.resolveSymbolicLinksSync();
      if (!pack_path.isWithin(rootResolved, fileResolved)) {
        _log.warning("Ignoring `${file.path}`: outside the root directory.");
        return null;
      }

      if (stat.size > maxFileSize) {
        _log.warning(
          "Ignoring `${file.path}`: size ${stat.size} > $maxFileSize.",
        );
        return null;
      }

      var content = utf8.decode(file.readAsBytesSync());

      var table = AliasesTable.parse(
        content,
        onInvalid: (line, reason) =>
            _log.warning("Ignoring `${file.path}:$line`: $reason"),
      );

      return table.isNotEmpty ? table : null;
    } catch (e) {
      _log.warning("Ignoring `${file.path}`: $e");
      return null;
    }
  }
}

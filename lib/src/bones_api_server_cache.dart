import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async_extension/async_extension.dart';
import 'package:collection/collection.dart';
import 'package:data_serializer/data_serializer.dart';
import 'package:logging/logging.dart' as logging;
import 'package:shelf/shelf.dart';
// ignore: implementation_imports
import 'package:shelf/src/body.dart';
// ignore: implementation_imports
import 'package:shelf/src/message.dart';
import 'package:shelf_gzip/shelf_gzip.dart';

final _log = logging.Logger('APIServerResponseCache');

const _headerServerTime = 'server-timing';
const _headerAPIServerCache = 'X-API-Server-Cache';

/// An [APIServer] in-memory [Response] cache.
class APIServerResponseCache {
  static const int defaultMaxContentLength = 1024 * 1024 * 10;

  /// The maximum `Content-Length` allowed for a cached [Response].
  final int maxContentLength;

  static const int defaultMaxMemorySize = 1024 * 1024 * 50;

  /// The maximum memory size for storing all cached [Response]s.
  final int maxMemorySize;

  /// The timeout of a resolved [File.stat].
  final Duration fileStatTimeout;

  APIServerResponseCache({
    int maxContentLength = defaultMaxContentLength,
    int maxMemorySize = defaultMaxMemorySize,
    this.fileStatTimeout = _FileStat.defaultStatTimeout,
  })  : maxContentLength = maxContentLength.clamp(0, 1024 * 1024 * 1024 * 8),
        maxMemorySize =
            maxMemorySize.clamp(1024 * 1024, 1024 * 1024 * 1024 * 32);

  final Map<_CachedResponseKey, Object> _cachedResponses = {};

  int get cachedResponsesLength => _cachedResponses.length;

  int _totalCachedResponsesMemorySize = 0;

  int get totalMemorySize => _totalCachedResponsesMemorySize;

  /// Clears all the cached entries.
  void clear() {
    _log.info(() =>
        "Cleared Cache> Remove Entries: $cachedResponsesLength, Freed Memory: ${totalMemorySize.asBestUnit}");

    _cachedResponses.clear();
    _totalCachedResponsesMemorySize = 0;
  }

  Handler middleware(Handler innerHandler) {
    return (request) {
      final requestInit = DateTime.now();
      var cachedResponse =
          getCachedResponse(request, requestInitTime: requestInit);

      if (cachedResponse is Future<Response?>) {
        return cachedResponse.then((cachedResponse) =>
            _middlewareCachedResponse(
                innerHandler, request, requestInit, cachedResponse));
      } else {
        return _middlewareCachedResponse(
            innerHandler, request, requestInit, cachedResponse);
      }
    };
  }

  FutureOr<Response> _middlewareCachedResponse(Handler innerHandler,
      Request request, DateTime requestInit, Response? cachedResponse) {
    if (cachedResponse != null) {
      _log.info(() =>
          "CACHED File Response in ms ${requestInit.elapsedTime.toMillisecondsFormatted()} [${cachedResponse.statusCode}]> /${request.url.path} (${cachedResponse.contentLengthHeader})");
      return cachedResponse;
    }

    return _middlewareUncachedResponse(innerHandler, request, requestInit);
  }

  Future<Response> _middlewareUncachedResponse(
      Handler innerHandler, Request request, DateTime requestInit) {
    return Future.sync(() => innerHandler(request)).then((response) {
      _log.info(() =>
          "UN-CACHED File Response in ms ${requestInit.elapsedTime.toMillisecondsFormatted()} [${response.statusCode}]> /${request.url.path} (${response.contentLengthHeader})");

      var cachedResponse = cacheResponse(request, response);
      if (cachedResponse != null) {
        return cachedResponse;
      }
      return response;
    });
  }

  Object? _get(_CachedResponseKey key) {
    var prev = _cachedResponses[key];

    if (prev == null) return null;

    var modified = prev.isFileModified(timeout: fileStatTimeout);

    if (modified) {
      _expire(key, prev);
      return null;
    }

    return prev;
  }

  FutureOr<Object?> _getAsync(_CachedResponseKey key) {
    var prev = _cachedResponses[key];

    if (prev == null) return null;

    var modified = prev.isFileModifiedAsync(timeout: fileStatTimeout);

    if (modified is Future<bool>) {
      return modified.then((modified) {
        if (modified) {
          _expire(key, prev);
          return null;
        }

        return prev;
      });
    } else if (modified) {
      _expire(key, prev);
      return null;
    }

    return prev;
  }

  void _expire(_CachedResponseKey key, Object prev) {
    _log.info(
        () => "REMOVED $key > File modified: ${prev.file?.path ?? key.path}");
    _cachedResponses.remove(key);

    if (key.statusCode == 200) {
      var key304 = _CachedResponseKey(304, key.path);
      var prev304 = _cachedResponses.remove(key304);
      if (prev304 != null) {
        _log.info(() =>
            "REMOVED $key304 > File modified: ${prev304.file?.path ?? key.path}");
      }
    }
  }

  bool _put(_CachedResponse cachedResponse) {
    _checkMaxMemorySize();

    var key = cachedResponse.key;

    if (key.statusCode != 404) {
      final key404 = _CachedResponseKey(404, key.path);
      _remove(key404);
    }

    var prev = _get(key);

    if (prev != null) {
      var cachedEntries = prev.asCachedEntries!;

      // Already cached:
      if (cachedEntries.contains(cachedResponse)) {
        return false;
      }

      var fileStat = cachedEntries.firstOrNull?.fileStat;
      cachedResponse.replaceFileStat(fileStat);

      _cachedResponses[key] = [...cachedEntries, cachedResponse];

      _log.info(() =>
          "CACHE[entries: $cachedResponsesLength, memory: ${totalMemorySize.asBestUnit}] Added alternative: $cachedResponse");
    } else {
      _cachedResponses[key] = cachedResponse;

      _log.info(() =>
          "CACHE[entries: $cachedResponsesLength, memory: ${totalMemorySize.asBestUnit}] Added: $cachedResponse");
    }

    _totalCachedResponsesMemorySize += cachedResponse.memorySize;

    return true;
  }

  void _remove(_CachedResponseKey key) {
    var prev = _cachedResponses.remove(key);

    if (prev != null) {
      var cachedEntries = prev.asCachedEntries;

      if (cachedEntries != null) {
        for (var cached in cachedEntries) {
          _totalCachedResponsesMemorySize -= cached.memorySize;
        }
      }
    }
  }

  bool _checkMaxMemorySize() {
    if (_totalCachedResponsesMemorySize < maxMemorySize) return false;

    var targetMemory = maxMemorySize * 0.80;

    var cachedResponses = _cachedResponses.values.toList();
    cachedResponses.sort();

    var totalRemoved = 0;
    var totalMemoryRemoved = 0;

    for (var entry in cachedResponses) {
      var cachedEntries = entry.asCachedEntries;

      if (cachedEntries != null) {
        for (var cached in cachedEntries) {
          ++totalRemoved;
          totalMemoryRemoved += cached.memorySize;

          _remove(cached.key);
        }

        if (_totalCachedResponsesMemorySize <= targetMemory) {
          break;
        }
      }
    }

    _log.info(() =>
        "Cache Cleaning> Removed Entries: $totalRemoved ; Freed Memory: ${totalMemoryRemoved.asBestUnit}");

    return true;
  }

  FutureOr<Response?> getCachedResponse(Request request,
      {DateTime? requestInitTime}) {
    var method = request.method;
    if (method != 'GET') {
      return null;
    }

    var cached304 = _getCachedResponse304(request, requestInitTime);

    return cached304.resolveResponseAsync(
        request, requestInitTime, _getCachedResponse200Then404);
  }

  FutureOr<Response?> _getCachedResponse304(
      Request request, DateTime? requestInitTime) {
    final key304 = _CachedResponseKey.status304(request);
    if (key304 == null) return null;

    var cached304 = _getAsync(key304);
    return cached304.toValidResponseAsync(request, requestInitTime);
  }

  FutureOr<Response?> _getCachedResponse200Then404(
      Request request, DateTime? requestInitTime) {
    return _getCachedResponse200(request, requestInitTime)
        .resolveResponseAsync(request, requestInitTime, _getCachedResponse404);
  }

  FutureOr<Response?> _getCachedResponse200(
      Request request, DateTime? requestInitTime) {
    final key200 = _CachedResponseKey.status200(request);

    var cached200 = _getAsync(key200);

    return cached200
        .toValidResponseAsync(request, requestInitTime)
        .resolveResponseAsync(
            request,
            requestInitTime,
            (request, requestInitTime) => _getCachedResponse200Alternative(
                request, requestInitTime, cached200));
  }

  FutureOr<Response?> _getCachedResponse200Alternative(
      Request request, DateTime? requestInitTime, FutureOr<Object?> cached200) {
    if (cached200 == null) return null;

    return cached200.resolveMapped((cached200) {
      var cachedEntries = cached200.asCachedEntries;

      var cached2 = cachedEntries.resolveAlternative(request);
      if (cached2 == null) return null;

      assert(cached2.validate(request));
      _put(cached2);

      if (cached2 is _CachedResponse200) {
        var cachedResponse304 = cached2.asCachedResponse304;
        if (cachedResponse304 != null) {
          _put(cachedResponse304);
        }
      }

      return cached2.toResponse(request);
    });
  }

  FutureOr<Response?> _getCachedResponse404(
      Request request, DateTime? requestInitTime) {
    final key404 = _CachedResponseKey.status404(request);

    var cached404 = _getAsync(key404);
    return cached404.toValidResponseAsync(request, requestInitTime);
  }

  Future<Response>? cacheResponse(Request request, Response response) {
    switch (response.statusCode) {
      case 200:
        return _cacheResponse200(request, response);
      case 304:
        return _cacheResponse304(request, response);
      case 404:
        return _cacheResponse404(request, response);
      default:
        return null;
    }
  }

  Future<Response>? _cacheResponse200(Request request, Response response) {
    var method = request.method;
    if (method != 'GET') {
      return null;
    }

    var contentLength = response.contentLength;
    if (contentLength == null || contentLength > maxContentLength) return null;

    var path = request.url.path;

    return _cacheResponse200Impl(path, response);
  }

  Future<Response> _cacheResponse200Impl(String path, Response response) async {
    var headers = _copyHeaders(response.headersAll);

    var (content, contentEncoding, encoding) = await _copyBody(response);

    var file = response.context['file'];

    var cachedResponse = _CachedResponse200(
        path: path,
        file: file,
        headers: headers,
        content: content,
        contentEncoding: contentEncoding,
        encoding: encoding);

    assert(cachedResponse.statusCode == 200);
    assert(cachedResponse.key.statusCode == 200);

    _put(cachedResponse);

    var cachedResponse304 = cachedResponse.asCachedResponse304;
    if (cachedResponse304 != null) {
      _put(cachedResponse304);
    }

    var response2 = response.change(body: cachedResponse.createBody());
    return response2;
  }

  Future<Response>? _cacheResponse304(Request request, Response response) {
    var method = request.method;
    if (method != 'GET') {
      return null;
    }

    var requestIfModifiableSince = request.ifModifiedSinceHeader;

    if (requestIfModifiableSince == null) return null;

    var file = response.context['file'];

    var cachedResponse = _CachedResponse304(
      path: request.url.path,
      file: file,
      requestIfModifiableSince: requestIfModifiableSince,
    );

    var key = cachedResponse.key;

    assert(cachedResponse.statusCode == 304);
    assert(key.statusCode == 304);

    _put(cachedResponse);

    return null;
  }

  Future<Response>? _cacheResponse404(Request request, Response response) {
    var method = request.method;
    if (method != 'GET') {
      return null;
    }

    var path = request.url.path;

    return _cacheResponse404Impl(path, response);
  }

  Future<Response> _cacheResponse404Impl(String path, Response response) async {
    var (content, contentEncoding, encoding) = await _copyBody(response);

    var file = response.context['file_not_found'] ?? response.context['file'];

    var cachedResponse = _CachedResponse404(
      path: path,
      file: file,
      content: content,
      contentEncoding: contentEncoding,
      encoding: encoding,
    );

    var key = cachedResponse.key;

    assert(cachedResponse.statusCode == 404);
    assert(key.statusCode == 404);

    _put(cachedResponse);

    return response.change(body: cachedResponse.createBody());
  }

  Map<String, List<String>> _copyHeaders(Map<String, List<String>> headers) {
    var headers2 = headers.map((key, value) {
      var length = value.length;

      List<String> val;
      if (length == 0) {
        val = [];
      } else if (length == 1) {
        val = [value[0]];
      } else {
        val = value.toList();
      }

      return MapEntry(key, val);
    });

    headers2.remove(HttpHeaders.dateHeader);

    return headers2;
  }

  Future<(List<int> content, String? contentEncoding, Encoding? encoding)>
      _copyBody(Response response) async {
    var body = extractBody(response);

    var content = await _streamToList(body.read());

    var contentEncoding = response.headers[HttpHeaders.contentEncodingHeader];

    return (content, contentEncoding, body.encoding);
  }

  Future<List<int>> _streamToList(Stream<List<int>> stream) async {
    final all = <int>[];
    await for (var chunk in stream) {
      all.addAll(chunk);
    }
    return all;
  }

  @override
  String toString() => 'APIServerResponseCache{ '
      'maxContentLength: ${maxContentLength.asBestUnit}, '
      'maxMemorySize: ${maxMemorySize.asBestUnit}, '
      'fileStatTimeout: ${fileStatTimeout.asBestUnit}, '
      'cachedResponses: ${_cachedResponses.length}, '
      'totalMemorySize: $_totalCachedResponsesMemorySize '
      '}';
}

class _CachedResponseKey {
  final int statusCode;
  final String path;

  _CachedResponseKey(this.statusCode, this.path);

  factory _CachedResponseKey.status200(Request request) =>
      _CachedResponseKey(200, request.url.path);

  static _CachedResponseKey? status304(Request request) {
    var requestIfModifiableSince = request.ifModifiedSinceHeader;
    if (requestIfModifiableSince == null) return null;

    return _CachedResponseKey304(request.url.path,
        requestIfModifiableSince: requestIfModifiableSince);
  }

  factory _CachedResponseKey.status404(Request request) =>
      _CachedResponseKey(404, request.url.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CachedResponseKey &&
          statusCode == other.statusCode &&
          path == other.path;

  @override
  int get hashCode => statusCode.hashCode ^ path.hashCode;

  @override
  String toString() => '[$statusCode]@$path';
}

class _CachedResponseKey304 extends _CachedResponseKey {
  final String? requestIfModifiableSince;

  _CachedResponseKey304(String path, {this.requestIfModifiableSince})
      : super(304, path);
}

abstract class WithMemorySize {
  int get memorySize;
}

class _FileStat implements WithMemorySize {
  final File file;
  late final bool fileExists;
  late final int fileLength;
  late final DateTime fileLastModified;

  _FileStat._(this.file) {
    var stat = this.stat();

    fileExists = stat.type != FileSystemEntityType.notFound;
    fileLength = stat.size;
    fileLastModified = stat.modified;
  }

  static _FileStat? from(Object? file) {
    var fileResolved = _resolveFile(file);
    if (fileResolved == null) return null;
    return _FileStat._(fileResolved);
  }

  static File? _resolveFile(Object? file) {
    if (file == null) return null;
    if (file is File) return file;

    if (file is String && file.isNotEmpty) {
      var f = File(file).absolute;
      if (f.existsSync()) {
        return f;
      }
    }

    return null;
  }

  @override
  int get memorySize => (8 + file.path.memorySize) + (8 + 8 + (8 + 8));

  FileStat? _stat;
  DateTime? _statTime;

  FileStat stat({Duration timeout = defaultStatTimeout}) {
    var stat = _stat;

    if (stat == null) {
      // ignore: discarded_futures
      _updateStat(sync: true);
      stat = _stat!;
      return stat;
    } else if (isStatExpired(timeout: timeout)) {
      // ignore: discarded_futures
      _updateStat();
    }

    return stat;
  }

  FutureOr<FileStat> statAsync({Duration timeout = defaultStatTimeout}) {
    var stat = _stat;

    if (stat == null || isStatExpired(timeout: timeout)) {
      return _updateStat();
    }

    return stat;
  }

  static const Duration defaultStatTimeout = Duration(minutes: 5);

  bool isStatExpired({Duration timeout = defaultStatTimeout}) {
    var statTime = _statTime;
    if (statTime == null) return false;

    var statElapsedTime = DateTime.now().difference(statTime);
    return statElapsedTime > timeout;
  }

  Future<FileStat>? _updating;

  FutureOr<FileStat> _updateStat({bool sync = false}) {
    if (sync) {
      _log.info("Updating File.stat (sync): ${file.path}");
      return _setStart(file.statSync());
    }

    final updating = _updating;
    if (updating != null) {
      return updating;
    }

    _log.info("Updating File.stat: ${file.path}");

    return _updating = file.stat().then((stat) {
      _setStart(stat);
      _updating = null;
      return stat;
    });
  }

  FileStat _setStart(FileStat stat) {
    _stat = stat;
    _statTime = DateTime.now();
    return stat;
  }

  void updateFrom(_FileStat? other) {
    if (other == null || identical(this, other)) return;

    var otherStatTime = other._statTime;
    if (otherStatTime == null) return;

    var myStatTime = _statTime;

    if (myStatTime == null || myStatTime.compareTo(otherStatTime) < 0) {
      _statTime = otherStatTime;
      _stat = other._stat!;
    }
  }

  bool isFileModified({Duration timeout = defaultStatTimeout}) {
    var stat = this.stat(timeout: timeout);
    return _isFileModifiedImpl(stat);
  }

  FutureOr<bool> isFileModifiedAsync({Duration timeout = defaultStatTimeout}) {
    return statAsync(timeout: timeout).resolveMapped(_isFileModifiedImpl);
  }

  bool _isFileModifiedImpl(FileStat stat) {
    if (!fileExists) {
      var existsOk = stat.type == FileSystemEntityType.notFound;
      return !existsOk;
    }

    var contentOk = stat.size == fileLength;
    var modifiedOk = stat.modified == fileLastModified;

    return !contentOk || !modifiedOk;
  }
}

abstract class _CachedResponse
    implements WithMemorySize, Comparable<_CachedResponse> {
  final int statusCode;
  final String path;

  _FileStat? _fileStat;

  _FileStat? get fileStat => _fileStat;

  late final _CachedResponseKey key;

  @override
  late final int memorySize;

  final DateTime date = DateTime.now();

  _CachedResponse(
      {required this.statusCode,
      required this.path,
      required Object? file,
      required _FileStat? fileStat})
      : _fileStat = fileStat ?? _FileStat.from(file) {
    key = _resolveKey();
    memorySize = _computeMemorySize();
    _lastUsageTime = date;
  }

  void replaceFileStat(_FileStat? fileStat) {
    if (fileStat == null) return;

    var myFileStat = _fileStat;
    if (identical(myFileStat, myFileStat)) return;

    if (myFileStat == null || myFileStat.file == fileStat.file) {
      fileStat.updateFrom(myFileStat);
      _fileStat = fileStat;
    }
  }

  Duration get cacheTime => DateTime.now().difference(date);

  late DateTime _lastUsageTime;

  int _usageCount = 0;

  int get usageCount => _usageCount;

  void markUsage() {
    ++_usageCount;
    _lastUsageTime = DateTime.now();
  }

  Duration get idleTime => DateTime.now().difference(_lastUsageTime);

  _CachedResponseKey _resolveKey() => _CachedResponseKey(statusCode, path);

  int _computeMemorySize() =>
      (8 + 8) + (8 + path.memorySize) + (8 + _fileStat.memorySize);

  bool isFileModified({Duration timeout = _FileStat.defaultStatTimeout}) =>
      fileStat?.isFileModified(timeout: timeout) ?? false;

  FutureOr<bool> isFileModifiedAsync(
          {Duration timeout = _FileStat.defaultStatTimeout}) =>
      fileStat?.isFileModifiedAsync(timeout: timeout) ?? false;

  _CachedResponse? resolveAlternative(Request request) => null;

  Response? toValidResponse(Request request, DateTime? requestInitTime) {
    if (validate(request)) {
      return toResponse(request, requestInitTime: requestInitTime);
    }
    return null;
  }

  void configureMetricsHeaders(Map<String, List<String>> headers,
      {DateTime? requestInitTime}) {
    var cacheTime = date.elapsedTime;

    if (requestInitTime != null) {
      var info =
          'API-Server-Response;dur=${requestInitTime.elapsedTime.inMicroseconds / 1000}';
      var serverTime = headers[_headerServerTime]?.firstOrNull;

      String? serverTimeInfo;

      if (serverTime != null) {
        var idx = serverTime.indexOf('API-Server-Response;');
        if (idx > 0) {
          serverTime = serverTime.substring(0, idx).trim();

          if (serverTime.isNotEmpty) {
            serverTimeInfo = '$serverTime, $info';
          } else {
            serverTimeInfo = info;
          }
        } else {
          serverTimeInfo = info;
        }
      } else {
        serverTimeInfo = info;
      }

      headers[_headerServerTime] = [serverTimeInfo];
    }

    headers[_headerAPIServerCache] = [cacheTime.asBestUnit];
  }

  Response toResponse(Request request, {DateTime? requestInitTime});

  bool validate(Request request);

  @override
  int compareTo(_CachedResponse other) {
    int cmp;

    {
      var use1 = usageCount ~/ 1000;
      var use2 = other.usageCount ~/ 1000;
      cmp = use2.compareTo(use1);
    }

    if (cmp == 0) {
      var m1 = memorySize ~/ (1024 * 8);
      var m2 = other.memorySize ~/ (1024 * 8);
      cmp = m2.compareTo(m1);
    }

    return cmp;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CachedResponse &&
          runtimeType == other.runtimeType &&
          statusCode == other.statusCode &&
          path == other.path;

  @override
  int get hashCode => statusCode.hashCode ^ path.hashCode;
}

abstract class _CachedResponseWithBody extends _CachedResponse {
  final Uint8List? content;
  final String? contentEncoding;
  final Encoding? encoding;

  _CachedResponseWithBody({
    required super.statusCode,
    required super.path,
    required super.file,
    super.fileStat,
    List<int>? content,
    this.contentEncoding,
    this.encoding,
  })  : content = content?.asUint8List.asUnmodifiableView,
        super();

  @override
  int _computeMemorySize() =>
      super._computeMemorySize() +
      (8 + content.memorySize) +
      (8 + contentEncoding.memorySize) +
      (8 + encoding.memorySize);

  int get contentLength => content?.length ?? 0;

  Body createBody() => Body(content, encoding);

  bool get isCompressedContent => contentEncoding == 'gzip';

  static final _defaultGzipDecoder = ZLibDecoder();

  Uint8List? decompressContent() {
    final content = this.content;
    if (content == null || encoding != null) return null;

    final contentEncoding = this.contentEncoding;
    if (contentEncoding == null) return content;

    if (contentEncoding == 'gzip') {
      return _defaultGzipDecoder.convert(content).asUint8List;
    }

    return null;
  }

  static final _defaultGzipEncoder = ZLibEncoder(gzip: true, level: 4);

  (Uint8List, String)? compressContent() {
    final content = this.content;
    if (content == null || encoding != null) return null;

    final contentEncoding = this.contentEncoding;
    if (contentEncoding != null) {
      if (contentEncoding == 'gzip') return (content, 'gzip');
      return null;
    }

    var compressed = _defaultGzipEncoder.convert(content).asUint8List;

    return (compressed, 'gzip');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is _CachedResponseWithBody &&
          contentEncoding == other.contentEncoding;

  @override
  int get hashCode => super.hashCode ^ contentEncoding.hashCode;
}

class _CachedResponse200 extends _CachedResponseWithBody {
  final Map<String, List<String>> headers;

  _CachedResponse200({
    required super.path,
    required super.file,
    super.fileStat,
    required this.headers,
    super.content,
    super.contentEncoding,
    super.encoding,
  }) : super(statusCode: 200);

  @override
  int _computeMemorySize() =>
      super._computeMemorySize() + (8 + headers.memorySize);

  _CachedResponse200? decompressedCopy() {
    var decompressContent = this.decompressContent();
    if (decompressContent == null) return null;

    var headers2 = Map<String, List<String>>.from(headers);

    headers2.remove(HttpHeaders.contentEncodingHeader);

    headers2[HttpHeaders.contentLengthHeader] = ['${decompressContent.length}'];

    return _CachedResponse200(
        path: path,
        file: file,
        fileStat: fileStat,
        headers: headers2,
        content: decompressContent);
  }

  _CachedResponse200? compressedCopy() {
    var compressed = this.compressContent();
    if (compressed == null) return null;

    var (compressContent, compressedEncoding) = compressed;

    var headers2 = Map<String, List<String>>.from(headers);

    headers2[HttpHeaders.contentEncodingHeader] = [compressedEncoding];

    headers2[HttpHeaders.contentLengthHeader] = ['${compressContent.length}'];

    return _CachedResponse200(
        path: path,
        file: file,
        fileStat: fileStat,
        headers: headers2,
        content: compressContent,
        contentEncoding: compressedEncoding);
  }

  @override
  bool validate(Request request) {
    final contentEncoding = this.contentEncoding;

    if (contentEncoding != null) {
      if (!request.requestAcceptsEncoding(contentEncoding)) {
        return false;
      }
    } else if (request.requestAcceptsGzipEncoding() && shouldGzipCompress()) {
      return false;
    }

    return true;
  }

  bool shouldGzipCompress() {
    var contentLength = this.contentLength;
    if (contentLength < 1024) {
      return false;
    }

    if (isCompressedContent) {
      return false;
    }

    var contentType = headers[HttpHeaders.contentTypeHeader]?.firstOrNull;
    if (contentType == null || isAlreadyCompressedContentType(contentType)) {
      return false;
    }

    return true;
  }

  @override
  _CachedResponse? resolveAlternative(Request request) {
    if (isCompressedContent) {
      if (!request.requestAcceptsEncoding(contentEncoding!)) {
        return decompressedCopy();
      }
    } else if (request.requestAcceptsGzipEncoding() && shouldGzipCompress()) {
      return compressedCopy();
    }

    return null;
  }

  @override
  Response toResponse(Request request, {DateTime? requestInitTime}) {
    markUsage();

    configureMetricsHeaders(headers, requestInitTime: requestInitTime);

    var response = Response(statusCode, headers: headers, body: createBody());
    return response;
  }

  @override
  String toString() => '[200]{ '
      'headers: ${headers.length}, '
      'content: $contentLength, '
      '${contentEncoding != null ? 'Content-Encoding: $contentEncoding, ' : ''}'
      'memory: ${memorySize.asBestUnit} '
      '}'
      '->$path'
      '@${file?.path ?? '?'}';

  _CachedResponse304? get asCachedResponse304 {
    var lastModified = headers[HttpHeaders.lastModifiedHeader]?.firstOrNull;
    if (lastModified is! String || lastModified.isEmpty) {
      return null;
    }

    var cachedResponse304 = _CachedResponse304(
      path: path,
      file: file,
      fileStat: fileStat,
      requestIfModifiableSince: lastModified,
    );

    assert(cachedResponse304.statusCode == 304);
    assert(cachedResponse304.key.statusCode == 304);

    return cachedResponse304;
  }
}

class _CachedResponse304 extends _CachedResponse {
  final String requestIfModifiableSince;

  _CachedResponse304({
    required super.path,
    required super.file,
    super.fileStat,
    required this.requestIfModifiableSince,
  }) : super(statusCode: 304);

  @override
  _CachedResponseKey _resolveKey() => _CachedResponseKey304(path,
      requestIfModifiableSince: requestIfModifiableSince);

  @override
  int _computeMemorySize() =>
      super._computeMemorySize() + (8 + requestIfModifiableSince.memorySize);

  @override
  bool validate(Request request) {
    var requestIfModifiableSince = request.ifModifiedSinceHeader;

    var ok = requestIfModifiableSince != null &&
        requestIfModifiableSince == this.requestIfModifiableSince;

    return ok;
  }

  @override
  Response toResponse(Request request, {DateTime? requestInitTime}) {
    markUsage();

    var headers = <String, List<String>>{};
    configureMetricsHeaders(headers, requestInitTime: requestInitTime);

    return Response(statusCode, headers: headers);
  }

  @override
  String toString() => '[304]{ '
      'If-Modifiable-Since: $requestIfModifiableSince, '
      'memory: ${memorySize.asBestUnit} '
      '}'
      '->$path'
      '@${file?.path ?? '?'}';
}

class _CachedResponse404 extends _CachedResponseWithBody {
  _CachedResponse404({
    required super.path,
    required super.file,
    super.content,
    super.contentEncoding,
    super.encoding,
  }) : super(statusCode: 404, fileStat: null);

  @override
  bool validate(Request request) {
    return true;
  }

  @override
  Response toResponse(Request request, {DateTime? requestInitTime}) {
    markUsage();

    var headers = <String, List<String>>{};
    configureMetricsHeaders(headers, requestInitTime: requestInitTime);

    return Response(statusCode, headers: headers, body: Body(content));
  }

  @override
  String toString() => '[404]{ '
      'content: $contentLength, '
      '${contentEncoding != null ? 'Content-Encoding: $contentEncoding, ' : ''}'
      'memory: ${memorySize.asBestUnit} '
      '}'
      '->$path'
      '@${file?.path ?? '?'}';
}

extension _WithMemorySizeExtension on WithMemorySize? {
  int get memorySize {
    final self = this;
    return self == null ? 0 : self.memorySize;
  }
}

extension _StringMemorySize on String? {
  int get memorySize {
    final self = this;
    return self == null ? 0 : 8 + self.length;
  }
}

extension _Uint8ListMemorySize on Uint8List? {
  int get memorySize {
    final self = this;
    return self == null ? 0 : 8 + self.length;
  }
}

extension _EncodingMemorySize on Encoding? {
  int get memorySize {
    final self = this;
    return self == null ? 0 : 8 + self.name.memorySize;
  }
}

extension _MapMemorySize on Map<Object?, Object?>? {
  int get memorySize {
    final self = this;
    return self == null
        ? 0
        : 8 +
            self.entries
                .map((e) => 32 + e.key.memorySize + e.value.memorySize)
                .sum;
  }
}

extension _MapStringObjectMemorySize on Map<String, Object?>? {
  int get memorySize {
    final self = this;
    return self == null
        ? 0
        : 8 +
            self.entries
                .map((e) => 32 + e.key.memorySize + e.value.memorySize)
                .sum;
  }
}

extension _ListMemorySize on List<Object?>? {
  int get memorySize {
    final self = this;
    return self == null ? 0 : 8 + self.map((e) => 32 + e.memorySize).sum;
  }
}

extension _ObjectExtension on Object? {
  int get memorySize {
    final self = this;
    if (self == null) return 0;

    if (self is WithMemorySize) {
      return self.memorySize;
    } else if (self is String) {
      return self.memorySize;
    } else if (self is List) {
      return self.memorySize;
    } else if (self is Map<String, Object>) {
      return self.memorySize;
    } else if (self is Map) {
      return self.memorySize;
    }

    // Generic size:
    return 32;
  }

  List<_CachedResponse>? get asCachedEntries {
    final self = this;
    if (self == null) return null;

    if (self is List<_CachedResponse>) {
      return self;
    } else if (self is _CachedResponse) {
      return [self];
    } else {
      throw StateError("Invalid `CachedEntry`: $self");
    }
  }

  Response? toValidResponse(Request request, DateTime? requestInitTime) {
    final self = this;
    if (self == null) return null;

    if (self is _CachedResponse) {
      return self.toValidResponse(request, requestInitTime);
    } else if (self is List<_CachedResponse>) {
      for (var cached in self) {
        if (cached.validate(request)) {
          return cached.toResponse(request, requestInitTime: requestInitTime);
        }
      }
    }

    return null;
  }

  bool isFileModified({Duration timeout = _FileStat.defaultStatTimeout}) {
    var self = this;
    if (self == null) return false;

    if (self is _FileStat) {
      return self.isFileModified(timeout: timeout);
    } else if (self is _CachedResponse) {
      return self.isFileModified(timeout: timeout);
    } else if (self is List<_CachedResponse>) {
      return self.any((e) => e.isFileModified(timeout: timeout));
    }

    return false;
  }

  FutureOr<bool> isFileModifiedAsync(
      {Duration timeout = _FileStat.defaultStatTimeout}) {
    var self = this;
    if (self == null) return false;

    if (self is _FileStat) {
      return self.isFileModifiedAsync(timeout: timeout);
    } else if (self is _CachedResponse) {
      return self.isFileModifiedAsync(timeout: timeout);
    } else if (self is List<_CachedResponse>) {
      List<Future<bool>>? futures;

      for (var e in self) {
        var modified = e.isFileModifiedAsync(timeout: timeout);
        if (modified is Future<bool>) {
          futures ??= <Future<bool>>[];
          futures.add(modified);
        } else if (modified) {
          return true;
        }
      }

      if (futures != null) {
        return Future.wait(futures).then((l) => l.contains(true));
      } else {
        return false;
      }
    }

    return false;
  }

  File? get file => fileStat?.file;

  _FileStat? get fileStat {
    var self = this;
    if (self == null) return null;

    if (self is _CachedResponse) {
      return self.fileStat;
    } else if (self is List<_CachedResponse>) {
      return self.map((e) => e.fileStat).whereNotNull().firstOrNull;
    }
    if (self is _FileStat) {
      return self;
    }

    return null;
  }
}

extension _FutureOrObjectExtension on FutureOr<Object?> {
  FutureOr<Response?> toValidResponseAsync(
      Request request, DateTime? requestInitTime) {
    final self = this;
    if (self == null) return null;

    if (self is Future<Object?>) {
      return self.then((e) => e.toValidResponse(request, requestInitTime));
    } else {
      return self.toValidResponse(request, requestInitTime);
    }
  }
}

extension _ListCachedResponseExtension on List<_CachedResponse>? {
  _CachedResponse? resolveAlternative(Request request) {
    final self = this;
    if (self == null) return null;

    for (var cached in self) {
      var cached2 = cached.resolveAlternative(request);
      if (cached2 != null) {
        return cached2;
      }
    }

    return null;
  }
}

extension _IntExtension on int {
  String get asBestUnit {
    if (this >= 1024 * 1024) {
      return asMB;
    } else if (this >= 1024) {
      return asKB;
    } else {
      return asBytes;
    }
  }

  String get asBytes {
    return '$this bytes';
  }

  String get asKB {
    var kb = this / 1024;
    return '${kb.toStringAsFixed(1)} KB';
  }

  String get asMB {
    var kb = this / (1024 * 1024);
    return '${kb.toStringAsFixed(1)} MB';
  }
}

extension _RequestExtension on Request {
  String? get ifModifiedSinceHeader =>
      headers[HttpHeaders.ifModifiedSinceHeader];

  bool requestAcceptsGzipEncoding() => requestAcceptsEncoding('gzip');

  bool requestAcceptsEncoding(String contentEncoding) {
    var acceptEncoding = headers[HttpHeaders.acceptEncodingHeader];
    return acceptEncoding?.contains(contentEncoding) ?? false;
  }
}

extension _ResponseExtension on Response {
  String get contentLengthHeader =>
      headers[HttpHeaders.contentLengthHeader] ?? '0';
}

extension _FutureOrResponseExtension on FutureOr<Response?> {
  FutureOr<Response?> resolveResponseAsync(
    Request request,
    DateTime? requestInitTime,
    FutureOr<Response?> Function(Request request, DateTime? requestInitTime)
        alternative,
  ) {
    final self = this;

    if (self is Future<Response?>) {
      return self.then((response) {
        if (response != null) return response;
        return alternative(request, requestInitTime);
      });
    } else if (self != null) {
      return self;
    }

    return alternative(request, requestInitTime);
  }
}

extension on DateTime {
  Duration get elapsedTime => DateTime.now().difference(this);
}

extension on Duration {
  String toMillisecondsFormatted() {
    var ms = (inMicroseconds / 1000).toStringAsFixed(3);
    return '$ms ms';
  }

  String get asBestUnit {
    if (inDays >= 1) {
      return asDay;
    } else if (inHours >= 1) {
      return asHour;
    } else if (inMinutes >= 1) {
      return asMin;
    } else if (inSeconds >= 1) {
      return asSec;
    } else {
      return asMs;
    }
  }

  String get asDay => '$inDays d';

  String get asHour => '$inHours h';

  String get asMin => '$inMinutes min';

  String get asSec => '$inSeconds sec';

  String get asMs => toMillisecondsFormatted();
}

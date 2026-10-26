import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:brotli_fast/brotli_fast.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart' as logging;
import 'package:shelf/shelf.dart';
import 'package:shelf_gzip/shelf_gzip.dart';

final _log = logging.Logger('APIContentEncoding');

/// A `Content-Encoding` that the server can use to compress a response.
enum APIContentEncoding {
  /// Brotli (RFC 7932).
  br,

  /// GZip (RFC 1952).
  gzip;

  /// The default encodings, in order of preference.
  static const List<APIContentEncoding> defaultEncodings = [br, gzip];

  /// The `Content-Encoding` header value.
  String get headerValue => name;

  /// Parses [o] to an [APIContentEncoding] (case insensitive).
  static APIContentEncoding? parse(Object? o) {
    if (o == null) return null;
    if (o is APIContentEncoding) return o;

    var s = o.toString().trim().toLowerCase();
    if (s.isEmpty) return null;

    return switch (s) {
      'br' || 'brotli' => br,
      'gzip' || 'x-gzip' => gzip,
      _ => null,
    };
  }

  /// Parses [o] to a list of [APIContentEncoding], keeping the order and
  /// ignoring unknown and duplicated entries. Accepts a [List] or a comma
  /// separated [String]. Returns `null` if [o] is `null`.
  static List<APIContentEncoding>? parseList(Object? o) {
    if (o == null) return null;

    Iterable<Object?> list;
    if (o is Iterable) {
      list = o;
    } else {
      list = o.toString().split(',');
    }

    var encodings = <APIContentEncoding>[];
    for (var e in list) {
      var encoding = parse(e);
      if (encoding != null && !encodings.contains(encoding)) {
        encodings.add(encoding);
      }
    }

    return encodings;
  }
}

/// Parses an `Accept-Encoding` header [value] into a map of
/// lowercase coding names to their `q` value (`0.0` to `1.0`).
///
/// An entry with an invalid `q` value is ignored. If a coding is
/// repeated, its highest `q` value is kept. `x-gzip` is taken as `gzip`
/// (RFC 9110, 8.4.1.3).
Map<String, double> parseAcceptEncoding(String? value) {
  if (value == null) return {};
  value = value.trim();
  if (value.isEmpty) return {};

  var accepted = <String, double>{};

  for (var entry in value.split(',')) {
    var parts = entry.split(';');

    var coding = normalizeContentCoding(parts[0]);
    if (coding.isEmpty) continue;

    double? q = 1.0;

    for (var i = 1; i < parts.length; ++i) {
      var param = parts[i].trim();
      var idx = param.indexOf('=');
      if (idx <= 0) continue;

      var key = param.substring(0, idx).trim().toLowerCase();
      if (key != 'q') continue;

      q = double.tryParse(param.substring(idx + 1).trim());
      break;
    }

    if (q == null || q.isNaN) continue;
    q = q.clamp(0.0, 1.0);

    var prev = accepted[coding];
    if (prev == null || q > prev) {
      accepted[coding] = q;
    }
  }

  return accepted;
}

/// Returns the `q` value of [coding] in [accepted] (see [parseAcceptEncoding]),
/// using the `*` entry when [coding] is not listed.
double acceptEncodingQuality(Map<String, double> accepted, String coding) =>
    accepted[coding] ?? accepted['*'] ?? 0.0;

/// Returns `true` if the `Accept-Encoding` header [value] accepts [coding]
/// (`q > 0`).
bool acceptsContentEncoding(String? value, String coding) =>
    acceptsContentEncodingFrom(parseAcceptEncoding(value), coding);

/// Same as [acceptsContentEncoding], with an already parsed
/// `Accept-Encoding` ([parseAcceptEncoding]).
bool acceptsContentEncodingFrom(Map<String, double> accepted, String coding) =>
    acceptEncodingQuality(accepted, normalizeContentCoding(coding)) > 0;

/// Normalizes a content [coding] name, as used in `Accept-Encoding` and
/// `Content-Encoding`: trimmed and lowercase, with `x-gzip` taken as `gzip`
/// (RFC 9110, 8.4.1.3).
String normalizeContentCoding(String coding) {
  coding = coding.trim().toLowerCase();
  return coding == 'x-gzip' ? 'gzip' : coding;
}

/// Resolves the best [APIContentEncoding] in [available] for the
/// `Accept-Encoding` header [value]: the one with the highest `q` value.
/// On a tie, the first one in [available] wins.
///
/// Returns `null` if none is accepted (the response should not be compressed).
APIContentEncoding? resolveContentEncoding(
  String? value,
  List<APIContentEncoding> available,
) {
  if (available.isEmpty) return null;
  return resolveContentEncodingFrom(parseAcceptEncoding(value), available);
}

/// Same as [resolveContentEncoding], with an already parsed
/// `Accept-Encoding` ([parseAcceptEncoding]).
APIContentEncoding? resolveContentEncodingFrom(
  Map<String, double> accepted,
  List<APIContentEncoding> available,
) {
  if (available.isEmpty || accepted.isEmpty) return null;

  APIContentEncoding? best;
  var bestQ = 0.0;

  for (var encoding in available) {
    var q = acceptEncodingQuality(accepted, encoding.headerValue);
    if (q > bestQ) {
      best = encoding;
      bestQ = q;
    }
  }

  return best;
}

/// Brotli encoding/decoding, using `package:brotli_fast`.
abstract final class APIBrotli {
  /// The default Brotli quality for dynamic responses.
  static const int defaultQuality = 5;

  static bool _encodeErrorLogged = false;

  /// Encodes [bytes] with Brotli at [quality] (`0` to `11`).
  ///
  /// Returns `null` if the encoder fails (the error is logged), so the
  /// caller can fall back to another encoding.
  static Uint8List? encode(Uint8List bytes, {int quality = defaultQuality}) {
    try {
      return brotliEncode(bytes, quality: quality.clamp(0, 11));
    } catch (e, s) {
      _logEncodeError(bytes.length, quality, e, s);
      return null;
    }
  }

  /// The minimal length to [encodeAsync] in a background [Isolate] at
  /// [quality]: Brotli is pure Dart, and a slow encoding would block the
  /// event loop (and all the other requests of the isolate).
  ///
  /// Starts at about 5ms of encoding (JSON, AOT). `Isolate.run` itself is
  /// cheap (~0.05ms), but a new isolate initializes the encoder tables
  /// again: about +1.5ms at quality `6` and +2.5ms at `9`
  /// (nothing at `0..5`).
  static int isolateMinLength(int quality) {
    if (quality >= 9) return 128 * 1024; // ~7ms inline.
    if (quality >= 6) return 256 * 1024; // ~5ms inline.
    return 1024 * 1024; // ~5ms inline.
  }

  /// Same as [encode], but encodes in a background [Isolate] if [bytes]
  /// is large for [quality] (see [isolateMinLength]).
  static FutureOr<Uint8List?> encodeAsync(
    Uint8List bytes, {
    int quality = defaultQuality,
  }) {
    quality = quality.clamp(0, 11);
    if (bytes.length < isolateMinLength(quality)) {
      return encode(bytes, quality: quality);
    }

    return Isolate.run(() => brotliEncode(bytes, quality: quality))
        .then<Uint8List?>(
          (encoded) => encoded,
          onError: (Object e, StackTrace s) {
            _logEncodeError(bytes.length, quality, e, s);
            return null;
          },
        );
  }

  static void _logEncodeError(int length, int quality, Object e, StackTrace s) {
    if (!_encodeErrorLogged) {
      _encodeErrorLogged = true;
      _log.severe(
        "Brotli encoding failed ($length bytes, quality: $quality). "
        "Falling back to another encoding. (Next failures are logged as `FINE`)",
        e,
        s,
      );
    } else {
      _log.fine("Brotli encoding failed: $e");
    }
  }

  /// Decodes the Brotli [bytes].
  ///
  /// If [maxOutputSize] is provided, throws a [BrotliException] when the
  /// decoded size exceeds it (checked while decoding). Without it, the
  /// `brotli_fast` default limit applies ([brotliDefaultMaxOutputSize]).
  static Uint8List decode(Uint8List bytes, {int? maxOutputSize}) =>
      brotliDecode(
        bytes,
        maxOutputSize: maxOutputSize ?? brotliDefaultMaxOutputSize,
      );
}

/// Encodes [bytes] with [encoding].
///
/// Returns `null` if the encoding fails.
Uint8List? encodeContent(
  Uint8List bytes,
  APIContentEncoding encoding, {
  int gzipLevel = 4,
  int brotliQuality = APIBrotli.defaultQuality,
}) {
  switch (encoding) {
    case APIContentEncoding.br:
      return APIBrotli.encode(bytes, quality: brotliQuality);
    case APIContentEncoding.gzip:
      var encoded = ZLibEncoder(gzip: true, level: gzipLevel).convert(bytes);
      return encoded is Uint8List ? encoded : Uint8List.fromList(encoded);
  }
}

/// Same as [encodeContent], but a large Brotli encoding runs in a background
/// [Isolate] (see [APIBrotli.encodeAsync]). GZip uses the native `zlib`.
FutureOr<Uint8List?> encodeContentAsync(
  Uint8List bytes,
  APIContentEncoding encoding, {
  int gzipLevel = 4,
  int brotliQuality = APIBrotli.defaultQuality,
}) {
  switch (encoding) {
    case APIContentEncoding.br:
      return APIBrotli.encodeAsync(bytes, quality: brotliQuality);
    case APIContentEncoding.gzip:
      return encodeContent(bytes, encoding, gzipLevel: gzipLevel);
  }
}

/// Decodes [bytes] encoded with [encoding].
Uint8List decodeContent(
  Uint8List bytes,
  APIContentEncoding encoding, {
  int? maxOutputSize,
}) {
  switch (encoding) {
    case APIContentEncoding.br:
      return APIBrotli.decode(bytes, maxOutputSize: maxOutputSize);
    case APIContentEncoding.gzip:
      var decoded = gzip.decode(bytes);
      return decoded is Uint8List ? decoded : Uint8List.fromList(decoded);
  }
}

/// The response compression configuration.
class APIResponseCompression {
  /// The default minimal content length to compress.
  static const int defaultMinLength = 512;

  /// The default GZip compression level.
  static const int defaultGzipLevel = 4;

  /// The accepted encodings, in order of preference.
  /// An empty list disables the compression.
  final List<APIContentEncoding> encodings;

  /// The GZip compression level (`1` to `9`).
  final int gzipLevel;

  /// The Brotli quality (`0` to `11`).
  final int brotliQuality;

  /// The minimal content length to compress.
  final int minLength;

  const APIResponseCompression({
    this.encodings = APIContentEncoding.defaultEncodings,
    this.gzipLevel = defaultGzipLevel,
    this.brotliQuality = APIBrotli.defaultQuality,
    this.minLength = defaultMinLength,
  });

  /// No compression.
  static const none = APIResponseCompression(encodings: []);

  /// Returns `true` if any encoding is enabled.
  bool get isEnabled => encodings.isNotEmpty;

  /// Resolves the [APIContentEncoding] for the `Accept-Encoding` header [value].
  /// See [resolveContentEncoding].
  APIContentEncoding? resolveEncoding(String? value) =>
      resolveContentEncoding(value, encodings);

  /// Resolves the [APIContentEncoding] for an already parsed
  /// `Accept-Encoding` ([parseAcceptEncoding]).
  APIContentEncoding? resolveAcceptedEncoding(Map<String, double> accepted) =>
      resolveContentEncodingFrom(accepted, encodings);

  /// Resolves the [APIContentEncoding] for [request].
  APIContentEncoding? resolveRequestEncoding(Request request) =>
      resolveEncoding(request.headers[HttpHeaders.acceptEncodingHeader]);

  /// Encodes [bytes] with [encoding], using this configuration.
  Uint8List? encode(Uint8List bytes, APIContentEncoding encoding) =>
      encodeContent(
        bytes,
        encoding,
        gzipLevel: gzipLevel,
        brotliQuality: brotliQuality,
      );

  /// Same as [encode], but a large Brotli encoding runs in a background
  /// [Isolate]. See [encodeContentAsync].
  FutureOr<Uint8List?> encodeAsync(
    Uint8List bytes,
    APIContentEncoding encoding,
  ) => encodeContentAsync(
    bytes,
    encoding,
    gzipLevel: gzipLevel,
    brotliQuality: brotliQuality,
  );

  APIResponseCompression copyWith({
    List<APIContentEncoding>? encodings,
    int? gzipLevel,
    int? brotliQuality,
    int? minLength,
  }) => APIResponseCompression(
    encodings: encodings ?? this.encodings,
    gzipLevel: gzipLevel ?? this.gzipLevel,
    brotliQuality: brotliQuality ?? this.brotliQuality,
    minLength: minLength ?? this.minLength,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is APIResponseCompression &&
          const ListEquality<APIContentEncoding>().equals(
            encodings,
            other.encodings,
          ) &&
          gzipLevel == other.gzipLevel &&
          brotliQuality == other.brotliQuality &&
          minLength == other.minLength;

  @override
  int get hashCode =>
      const ListEquality<APIContentEncoding>().hash(encodings) ^
      gzipLevel.hashCode ^
      brotliQuality.hashCode ^
      minLength.hashCode;

  @override
  String toString() =>
      'APIResponseCompression{encodings: ${encodings.map((e) => e.name).toList()}, '
      'gzipLevel: $gzipLevel, brotliQuality: $brotliQuality, minLength: $minLength}';
}

/// Merges [field] into the `Vary` header value [currentVary].
String mergeVaryHeader(Object? currentVary, String field) {
  var vary =
      (currentVary is Iterable ? currentVary.join(', ') : currentVary)
          ?.toString()
          .trim() ??
      '';

  if (vary.isEmpty || vary == '*') {
    return vary.isEmpty ? field : vary;
  }

  var fields = vary
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  if (fields.any((e) => equalsIgnoreAsciiCase(e, field))) return vary;

  return [...fields, field].join(', ');
}

/// Returns `true` if [response] can be compressed: a status with a full
/// body (not `1xx`, `204`, `206` or `304`, and no `Content-Range`),
/// no `Content-Encoding`, not an already compressed `Content-Type`, and
/// not smaller than [minLength]. See [canGzipEncodeResponse].
bool canCompressResponse(
  Response response, {
  int minLength = APIResponseCompression.defaultMinLength,
}) {
  final statusCode = response.statusCode;
  if (statusCode < 200 ||
      statusCode == HttpStatus.noContent ||
      statusCode == HttpStatus.partialContent ||
      statusCode == HttpStatus.notModified) {
    return false;
  }

  // A range of the (uncompressed) representation:
  if (response.headers.containsKey(HttpHeaders.contentRangeHeader)) {
    return false;
  }

  return canGzipEncodeResponse(response, minimalGzipContentLength: minLength);
}

/// The [Response.context] key with the uncompressed body length of a
/// response compressed by [compressResponse].
const String uncompressedLengthContextKey =
    'bones_api.compression.uncompressed_length';

/// Returns the uncompressed body length of [response]: the
/// [uncompressedLengthContextKey] if compressed by [compressResponse],
/// otherwise its [Response.contentLength].
int? uncompressedContentLength(Response response) {
  var length = response.context[uncompressedLengthContextKey];
  return length is int ? length : response.contentLength;
}

/// Compresses [response] with the best encoding accepted by [request]
/// (see [APIResponseCompression.resolveRequestEncoding]).
///
/// - `HEAD` requests are not compressed (no body to compress): only the
///   `Vary` header is added, and the `Content-Length` is kept.
/// - Adds `Vary: Accept-Encoding` if [response] can be compressed, even if
///   [request] does not accept any encoding (for caches).
/// - Falls back to the next accepted encoding if one fails.
/// - A large Brotli encoding runs in a background [Isolate]
///   (see [APIBrotli.encodeAsync]).
/// - The uncompressed length is set in the [Response.context]
///   (see [uncompressedContentLength]).
/// - If [addCompressionRatioHeader] is `true` it adds the header
///   `X-Compression-Ratio`, with compression info, e.g.: `0.55 (550/1000)`
/// - If [addServerTiming] is `true`, includes or appends the encoding
///   timing to the `server-timing` header (entries `br` or `gzip`).
FutureOr<Response> compressResponse(
  Request request,
  Response response, {
  APIResponseCompression compression = const APIResponseCompression(),
  bool addCompressionRatioHeader = true,
  bool addServerTiming = true,
}) {
  if (!compression.isEnabled) return response;

  if (!canCompressResponse(response, minLength: compression.minLength)) {
    return response;
  }

  var vary = mergeVaryHeader(
    response.headers[HttpHeaders.varyHeader],
    'Accept-Encoding',
  );

  // Same `Vary` as the `GET`, without a body to compress:
  if (request.method == 'HEAD') {
    return response.change(headers: {HttpHeaders.varyHeader: vary});
  }

  var accepted = parseAcceptEncoding(
    request.headers[HttpHeaders.acceptEncodingHeader],
  );

  var encoding = compression.resolveAcceptedEncoding(accepted);
  if (encoding == null) {
    return response.change(headers: {HttpHeaders.varyHeader: vary});
  }

  return _compressResponseImpl(
    response,
    accepted,
    encoding,
    vary,
    compression,
    addCompressionRatioHeader,
    addServerTiming,
  );
}

Future<Response> _compressResponseImpl(
  Response response,
  Map<String, double> accepted,
  APIContentEncoding encoding,
  String vary,
  APIResponseCompression compression,
  bool addCompressionRatioHeader,
  bool addServerTiming,
) async {
  var initTime = DateTime.now();

  var bytesBuilder = BytesBuilder(copy: false);
  await for (var chunk in response.read()) {
    bytesBuilder.add(chunk);
  }
  var bytes = bytesBuilder.takeBytes();

  if (bytes.length < compression.minLength) {
    return response.change(
      headers: {HttpHeaders.varyHeader: vary},
      body: bytes,
    );
  }

  var compressed = await compression.encodeAsync(bytes, encoding);

  if (compressed == null) {
    // Fallback to the next accepted encoding:
    var others = compression.encodings.where((e) => e != encoding).toList();
    var fallback = resolveContentEncodingFrom(accepted, others);

    if (fallback != null) {
      encoding = fallback;
      compressed = await compression.encodeAsync(bytes, encoding);
    }
  }

  if (compressed == null) {
    return response.change(
      headers: {HttpHeaders.varyHeader: vary},
      body: bytes,
    );
  }

  var headers = <String, String>{HttpHeaders.varyHeader: vary};

  defineContentEncodingHeaders(
    headers,
    encoding: encoding,
    bodyLength: bytes.length,
    compressedBodyLength: compressed.length,
    currentServerTiming: response.headers['server-timing'],
    addCompressionRatioHeader: addCompressionRatioHeader,
    addServerTiming: addServerTiming,
    initTime: initTime,
    serverTimingEntryName: encoding.headerValue,
  );

  return response.change(
    headers: headers,
    body: compressed,
    context: {uncompressedLengthContextKey: bytes.length},
  );
}

/// Sets the `Content-Encoding` and `Content-Length` headers in [headers]
/// for a body compressed with [encoding]. Optionally adds:
///
/// - `X-Compression-Ratio`: with detailed compression info
///   (`ratio (compressed/body)` or `ratio (compressed/body/capacity)`).
/// - `Server-Timing`: duration of the compression step (if [initTime] is
///   provided), appended to [currentServerTiming]
///   (or to the current `server-timing` entry in [headers]).
void defineContentEncodingHeaders(
  Map<String, dynamic> headers, {
  required APIContentEncoding encoding,
  required int bodyLength,
  required int compressedBodyLength,
  int? compressionCapacity,
  String? currentServerTiming,
  bool addCompressionRatioHeader = true,
  bool addServerTiming = true,
  DateTime? initTime,
  required String serverTimingEntryName,
}) {
  headers[HttpHeaders.contentEncodingHeader] = encoding.headerValue;
  headers[HttpHeaders.contentLengthHeader] = compressedBodyLength.toString();

  if (addCompressionRatioHeader) {
    var compressionRatio = compressedBodyLength / bodyLength;

    var compressionRatioStr = '$compressionRatio';
    if (compressionRatioStr.length > 6) {
      compressionRatioStr = compressionRatio.toStringAsFixed(4);
    }

    headers['X-Compression-Ratio'] = compressionCapacity != null
        ? '$compressionRatioStr ($compressedBodyLength/$bodyLength/$compressionCapacity)'
        : '$compressionRatioStr ($compressedBodyLength/$bodyLength)';
  }

  if (addServerTiming && initTime != null) {
    const headerServerTiming = 'server-timing';

    var time = DateTime.now().difference(initTime);
    var dur = time.inMicroseconds / 1000;

    var serverTiming2 = StringBuffer();

    var serverTiming =
        currentServerTiming ?? headers[headerServerTiming]?.toString();
    if (serverTiming != null && serverTiming.isNotEmpty) {
      serverTiming2.write(serverTiming);
      serverTiming2.write(',');
    }

    serverTiming2.write(serverTimingEntryName);
    serverTiming2.write(';dur=');
    serverTiming2.write(dur);

    headers[headerServerTiming] = serverTiming2.toString();
  }
}

/// A [Middleware] that compresses the responses using [compressResponse].
///
/// If [resolveCompression] is provided, it chooses the compression of each
/// response (e.g., a higher quality for responses that will be cached),
/// otherwise [compression] is used.
Middleware createCompressionMiddleware({
  APIResponseCompression compression = const APIResponseCompression(),
  APIResponseCompression Function(Request request, Response response)?
  resolveCompression,
  bool addCompressionRatioHeader = true,
  bool addServerTiming = true,
}) {
  return (innerHandler) {
    return (request) {
      return Future.sync(() => innerHandler(request)).then(
        (response) => compressResponse(
          request,
          response,
          compression: resolveCompression != null
              ? resolveCompression(request, response)
              : compression,
          addCompressionRatioHeader: addCompressionRatioHeader,
          addServerTiming: addServerTiming,
        ),
      );
    };
  };
}

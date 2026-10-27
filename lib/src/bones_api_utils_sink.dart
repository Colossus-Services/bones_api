import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'bones_api_utils_compression.dart';

/// Automatically switches to [encoding] compression when the input reaches
/// [minCompressLength]. If [encoding] is `null` it never compresses.
class AutoCompressSink extends ByteConversionSinkBuffered {
  /// Inner sink that may switch between plain and compressed modes.
  ByteConversionSinkBuffered _sink;

  /// The compression to use. If `null` it never compresses.
  final APIContentEncoding? encoding;

  /// Minimum input size to trigger the compression.
  final int minCompressLength;

  /// The GZip compression level.
  final int gzipLevel;

  /// The Brotli quality.
  final int brotliQuality;

  AutoCompressSink({
    required this.encoding,
    this.minCompressLength = 512,
    this.gzipLevel = 4,
    this.brotliQuality = APIBrotli.defaultQuality,
    int capacity = 1024,
  }) : _sink = BytesSink(capacity: capacity);

  @override
  int get inputLength => _sink.inputLength;

  bool _compressing = false;

  /// Returns `true` if the compression is active.
  bool get isCompressing => _compressing;

  /// The active encoding, or `null` if not compressing.
  ///
  /// After [close], a [BrotliSink] that fell back to GZip reports
  /// [APIContentEncoding.gzip].
  APIContentEncoding? get activeEncoding {
    if (!_compressing) return null;
    final sink = _sink;
    return sink is BrotliSink ? sink.encoding : APIContentEncoding.gzip;
  }

  /// Returns `true` if GZip compression is active.
  bool get isGzip => activeEncoding == APIContentEncoding.gzip;

  /// Returns `true` if Brotli compression is active.
  bool get isBrotli => activeEncoding == APIContentEncoding.br;

  /// Switches to [encoding] compression. Keeps previously added data.
  void switchToCompression() {
    final encoding = this.encoding;
    if (_compressing || encoding == null) return;
    var prevBytes = _sink.toBytes(copy: true);
    _sink.reset();
    _sink = switch (encoding) {
      APIContentEncoding.br => BrotliSink(
        quality: brotliQuality,
        gzipLevel: gzipLevel,
        bytesSink: _sink,
      ),
      APIContentEncoding.gzip => GZipSink(level: gzipLevel, bytesSink: _sink),
    };
    _compressing = true;
    _sink.add(prevBytes);
  }

  @override
  void add(List<int> chunk) {
    if (!_compressing &&
        encoding != null &&
        _sink.length + chunk.length >= minCompressLength) {
      switchToCompression();
    }
    _sink.add(chunk);
  }

  @override
  void close() => _sink.close();

  @override
  Uint8List toBytes({bool copy = false}) => _sink.toBytes(copy: copy);

  @override
  int get capacity => _sink.capacity;

  @override
  int get length => _sink.length;

  /// Resets internal state and disables the compression if active.
  @override
  void reset() {
    if (!_compressing) {
      _sink.reset();
    } else {
      final sink = _sink;
      if (sink is GZipSink) {
        sink.close(); // Avoid memory leak
        _sink = sink._bytesSink;
      } else if (sink is BrotliSink) {
        _sink = sink._bytesSink;
      }
      _sink.reset();
      _compressing = false;
    }
  }
}

/// Automatically switches to GZip compression when input exceeds [minGZipLength].
/// See [AutoCompressSink].
class AutoGZipSink extends AutoCompressSink {
  AutoGZipSink({int minGZipLength = 512, super.capacity})
    : super(
        encoding: APIContentEncoding.gzip,
        minCompressLength: minGZipLength,
      );

  /// Minimum input size to trigger GZip compression.
  int get minGZipLength => minCompressLength;

  /// Switches to GZip compression. Keeps previously added data.
  void switchToGzip() => switchToCompression();
}

/// Buffers the input and encodes it with Brotli on [close].
///
/// If the Brotli encoder fails, the input is encoded with GZip instead
/// (see [encoding]).
class BrotliSink extends ByteConversionSinkBuffered {
  final ByteConversionSinkBuffered _bytesSink;
  final BytesSink _input;

  /// The Brotli quality.
  final int quality;

  /// The GZip level used in the fallback.
  final int gzipLevel;

  BrotliSink({
    this.quality = APIBrotli.defaultQuality,
    this.gzipLevel = 4,
    ByteConversionSinkBuffered? bytesSink,
    int capacity = 1024 * 4,
  }) : _bytesSink = bytesSink ?? BytesSink(capacity: capacity),
       _input = BytesSink(capacity: capacity);

  APIContentEncoding _encoding = APIContentEncoding.br;

  /// The encoding of the output: [APIContentEncoding.br], or
  /// [APIContentEncoding.gzip] if the Brotli encoder failed.
  APIContentEncoding get encoding => _encoding;

  bool _closed = false;

  @override
  int get length => _bytesSink.length;

  @override
  int get capacity => _bytesSink.capacity;

  @override
  int get inputLength => _input.length;

  @override
  void add(List<int> chunk) => _input.add(chunk);

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    _input.addSlice(chunk, start, end, false);
    if (isLast) close();
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;

    final input = _input.toBytes();

    var output = APIBrotli.encode(input, quality: quality);
    if (output == null) {
      output = encodeContent(
        input,
        APIContentEncoding.gzip,
        gzipLevel: gzipLevel,
      )!;
      _encoding = APIContentEncoding.gzip;
    }

    _bytesSink.add(output);
  }

  @override
  Uint8List toBytes({bool copy = false}) => _bytesSink.toBytes(copy: copy);

  /// Resets the input and output buffers.
  @override
  void reset() {
    _input.reset();
    _bytesSink.reset();
    _encoding = APIContentEncoding.br;
    _closed = false;
  }
}

/// Wraps a sink to apply GZip compression using [ZLibEncoder].
class GZipSink extends ByteConversionSinkBuffered {
  final ByteConversionSinkBuffered _bytesSink;
  late ByteConversionSink _gzipSink;
  final int level;

  GZipSink({
    this.level = 4,
    ByteConversionSinkBuffered? bytesSink,
    int capacity = 1024 * 4,
  }) : _bytesSink = bytesSink ?? BytesSink(capacity: capacity) {
    _gzipSink = _createGZipEncoder(level);
  }

  ByteConversionSink _createGZipEncoder(int level) => ZLibEncoder(
    gzip: true,
    level: level,
    windowBits: ZLibOption.defaultWindowBits,
    memLevel: ZLibOption.defaultMemLevel,
    strategy: ZLibOption.strategyDefault,
    dictionary: null,
    raw: false,
  ).startChunkedConversion(_bytesSink);

  @override
  int get length => _bytesSink.length;

  @override
  int get capacity => _bytesSink.capacity;

  int _inputLength = 0;

  @override
  int get inputLength => _inputLength;

  @override
  void add(List<int> chunk) {
    _inputLength += chunk.length;
    _gzipSink.add(chunk);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    final chunkLength = chunk.length;
    if (start != 0 || end != chunkLength) {
      var length = end - start;
      _inputLength += length;
      _gzipSink.addSlice(chunk, start, end, isLast);
    } else {
      _inputLength += chunkLength;
      _gzipSink.add(chunk);
      if (isLast) _gzipSink.close();
    }
  }

  @override
  void close() => _gzipSink.close();

  @override
  Uint8List toBytes({bool copy = false}) => _bytesSink.toBytes();

  /// Resets the compressor and underlying buffer.
  @override
  void reset() {
    _gzipSink.close();
    _bytesSink.reset();
    _gzipSink = _createGZipEncoder(level);
    _inputLength = 0;
  }
}

/// Buffer that accumulates bytes and supports reset and conversion to [Uint8List].
class BytesSink extends BytesBuffer implements ByteConversionSinkBuffered {
  BytesSink({super.capacity});

  @override
  int get inputLength => length;

  @override
  void close() {}

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    var length = end - start;
    addPart(chunk, start, length);
    if (isLast) close();
  }
}

/// Base class for sinks with tracking and reset support.
abstract class ByteConversionSinkBuffered extends ByteConversionSink {
  int get length;

  int get capacity;

  int get inputLength;

  Uint8List toBytes({bool copy = false});

  void reset();
}

/// A growing byte buffer with auto-resize and slice access.
class BytesBuffer {
  Uint8List _buffer;
  int _length = 0;

  BytesBuffer({int capacity = 1204 * 4}) : _buffer = Uint8List(capacity);

  int get length => _length;

  int get capacity => _buffer.length;

  /// Returns buffer contents. May return internal buffer if fully used and [copy] is false.
  Uint8List toBytes({bool copy = false}) {
    if (!copy && _length == _buffer.length) {
      return _buffer;
    }
    return Uint8List.sublistView(_buffer, 0, _length);
  }

  /// Adds [bytes] to buffer, resizing if needed.
  void add(List<int> bytes) {
    addPart(bytes, 0, bytes.length);
  }

  void addPart(List<int> bytes, int offset, int length) {
    final requiredLength = _length + length;
    if (requiredLength > _buffer.length) {
      _increaseCapacity(requiredLength);
    }
    _buffer.setRange(_length, _length + length, bytes, offset);
    _length += length;
  }

  void _increaseCapacity(int requiredLength) {
    final newLength = computeNewLength(_buffer.length, requiredLength);
    assert(newLength >= requiredLength);
    final newBuffer = Uint8List(newLength);
    newBuffer.setRange(0, _length, _buffer);
    _buffer = newBuffer;
  }

  /// Calculates next buffer size based on usage pattern.
  int computeNewLength(int prevLength, int requiredLength) {
    assert(prevLength < requiredLength);

    if (requiredLength < 1024 * 1024 * 8) {
      var newLength = prevLength * 2;
      while (newLength < requiredLength) {
        newLength *= 2;
      }
      return newLength;
    } else if (requiredLength < 1024 * 1024 * 32) {
      var newLength = (prevLength * 1.5).toInt();
      while (newLength < requiredLength) {
        newLength = (newLength * 1.5).toInt();
      }
      return newLength;
    } else {
      var newLength = (prevLength * 1.25).toInt();
      while (newLength < requiredLength) {
        newLength = (newLength * 1.25).toInt();
      }
      return newLength;
    }
  }

  /// Clears the buffer content without releasing memory.
  void reset() {
    _length = 0;
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Automatically switches to GZip compression when input exceeds [minGZipLength].
class AutoGZipSink extends ByteConversionSinkBuffered {
  /// Inner sink that may switch between plain and gzip modes.
  ByteConversionSinkBuffered _sink;

  /// Minimum input size to trigger GZip compression.
  final int minGZipLength;

  AutoGZipSink({this.minGZipLength = 512, int capacity = 1024})
    : _sink = BytesSink(capacity: capacity);

  @override
  int get inputLength => _sink.inputLength;

  bool _gzip = false;

  /// Returns `true` if GZip compression is active.
  bool get isGzip => _gzip;

  /// Switches to GZip compression. Keeps previously added data.
  void switchToGzip() {
    if (_gzip) return;
    var prevBytes = _sink.toBytes(copy: true);
    _sink.reset();
    _sink = GZipSink(bytesSink: _sink);
    _gzip = true;
    _sink.add(prevBytes);
  }

  @override
  void add(List<int> chunk) {
    if (!_gzip && _sink.length + chunk.length >= minGZipLength) {
      switchToGzip();
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

  /// Resets internal state and disables GZip if active.
  @override
  void reset() {
    if (!_gzip) {
      _sink.reset();
    } else {
      var gzipSink = _sink as GZipSink;
      gzipSink.close(); // Avoid memory leak
      _sink = gzipSink._bytesSink;
      _sink.reset();
      _gzip = false;
    }
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

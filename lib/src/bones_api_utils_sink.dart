import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class AutoGZipSink extends ByteConversionSinkBuffered {
  ByteConversionSinkBuffered _sink;

  final int minGZipLength;

  AutoGZipSink({this.minGZipLength = 512, int capacity = 1024})
      : _sink = BytesSink(capacity: capacity);

  @override
  int get inputLength => _sink.inputLength;

  bool _gzip = false;

  bool get isGzip => _gzip;

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
  void close() {
    _sink.close();
  }

  @override
  Uint8List toBytes({bool copy = false}) {
    return _sink.toBytes();
  }

  @override
  int get capacity => _sink.capacity;

  @override
  int get length => _sink.length;

  @override
  void reset() {
    if (!_gzip) {
      _sink.reset();
    } else {
      var gzipSink = _sink as GZipSink;

      // Close to avoid memory leak:
      gzipSink.close();

      _sink = gzipSink._bytesSink;
      _sink.reset();
      _gzip = false;
    }
  }
}

class GZipSink extends ByteConversionSinkBuffered {
  final ByteConversionSinkBuffered _bytesSink;
  late ByteConversionSink _gzipSink;
  final int level;

  GZipSink(
      {this.level = 4,
      ByteConversionSinkBuffered? bytesSink,
      int capacity = 1024 * 4})
      : _bytesSink = bytesSink ?? BytesSink(capacity: capacity) {
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
  void close() => _gzipSink.close();

  @override
  Uint8List toBytes({bool copy = false}) => _bytesSink.toBytes();

  @override
  void reset() {
    _gzipSink.close();
    _bytesSink.reset();
    _gzipSink = _createGZipEncoder(level);
    _inputLength = 0;
  }
}

class BytesSink extends BytesBuffer implements ByteConversionSinkBuffered {
  BytesSink({super.capacity});

  @override
  int get inputLength => length;

  @override
  void close() {}

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    if (start != 0 || end != chunk.length) {
      chunk = chunk.sublist(start, end);
    }
    add(chunk);
    if (isLast) close();
  }
}

abstract class ByteConversionSinkBuffered extends ByteConversionSink {
  int get length;

  int get capacity;

  int get inputLength;

  Uint8List toBytes({bool copy = false});

  void reset();
}

class BytesBuffer {
  Uint8List _buffer;
  int _length = 0;

  BytesBuffer({int capacity = 1204 * 4}) : _buffer = Uint8List(capacity);

  int get length => _length;

  int get capacity => _buffer.length;

  /// Returns the added bytes as a [Uint8List]. See [add]
  ///
  /// If [copy] is `false` and the buffer is fully used (`_length == _buffer.length`),
  /// returns the internal buffer directly to avoid copying.
  /// Otherwise, returns a view of the buffer up to the actual written length.
  Uint8List toBytes({bool copy = false}) {
    if (!copy && _length == _buffer.length) {
      return _buffer;
    }
    return Uint8List.sublistView(_buffer, 0, _length);
  }

  /// Add butes to the buffer.
  void add(List<int> bytes) {
    final chunkLength = bytes.length;
    final requiredLength = _length + chunkLength;

    if (requiredLength > _buffer.length) {
      _increaseCapacity(requiredLength);
    }

    _buffer.setRange(_length, _length + chunkLength, bytes);
    _length += chunkLength;
  }

  void _increaseCapacity(int requiredLength) {
    final newLength = computeNewLength(_buffer.length, requiredLength);
    assert(newLength >= requiredLength);
    final newBuffer = Uint8List(newLength);
    newBuffer.setRange(0, _length, _buffer);
    _buffer = newBuffer;
  }

  int computeNewLength(int prevLength, int requiredLength) {
    assert(prevLength < requiredLength);

    if (requiredLength < 1024 * 1024 * 8) {
      var newLength = prevLength * 2;
      while (newLength < requiredLength) {
        newLength = newLength * 2;
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

  void reset() {
    _length = 0;
  }
}

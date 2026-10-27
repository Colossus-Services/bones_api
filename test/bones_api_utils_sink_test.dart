@TestOn('vm')
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bones_api/src/bones_api_utils_compression.dart';
import 'package:bones_api/src/bones_api_utils_sink.dart';
import 'package:test/test.dart';

Uint8List _failingBrotliEncoder(Uint8List bytes, int quality) =>
    throw StateError('Simulated Brotli encoder failure');

void main() {
  group('BytesBuffer', () {
    test('basic', () {
      var bs = BytesBuffer();

      expect(bs.length, equals(0));
      expect(bs.toBytes(), equals([]));

      bs.add([1, 2, 3]);
      expect(bs.length, equals(3));
      expect(bs.toBytes(), equals([1, 2, 3]));

      bs.add([4, 5, 6, 7, 8, 9, 10]);
      expect(bs.length, equals(10));
      expect(bs.toBytes(), equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));

      bs.reset();
      expect(bs.length, equals(0));
      expect(bs.toBytes(), equals([]));

      bs.add([10, 20, 30]);
      expect(bs.length, equals(3));
      expect(bs.toBytes(), equals([10, 20, 30]));
    });
  });

  group('BytesSink', () {
    test('basic', () {
      var bs = BytesSink(capacity: 8);

      expect(bs.capacity, equals(8));
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(0));
      expect(bs.toBytes(), equals([]));

      bs.add([1, 2, 3]);
      expect(bs.length, equals(3));
      expect(bs.inputLength, equals(3));
      expect(bs.toBytes(), equals([1, 2, 3]));

      bs.add([4, 5, 6, 7, 8, 9, 10]);
      expect(bs.length, equals(10));
      expect(bs.inputLength, equals(10));
      expect(bs.toBytes(), equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));

      bs.addSlice([100, 101, 102], 1, 3, false);
      expect(bs.capacity, equals(16));
      expect(bs.length, equals(12));
      expect(bs.inputLength, equals(12));
      expect(bs.toBytes(), equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 101, 102]));

      bs.reset();
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(0));
      expect(bs.toBytes(), equals([]));

      bs.add([10, 20, 30]);
      expect(bs.length, equals(3));
      expect(bs.inputLength, equals(3));
      expect(bs.toBytes(), equals([10, 20, 30]));
    });
  });

  group('GZipSink', () {
    test('basic', () {
      var gzipHeader = _getGZipHeader();

      var bs = GZipSink(capacity: 8);

      expect(bs.capacity, equals(8));
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(0));
      expect(bs.toBytes(), equals([]));

      bs.add([1, 2, 3]);
      expect(bs.capacity, equals(16));
      expect(bs.length, equals(10));
      expect(bs.inputLength, equals(3));
      expect(bs.toBytes(), equals(gzipHeader));

      bs.add([4, 5, 6, 7, 8, 9, 10]);
      expect(bs.length, equals(10));
      expect(bs.inputLength, equals(10));
      expect(bs.toBytes(), equals(gzipHeader));

      bs.addSlice([100, 101, 102], 1, 3, false);
      expect(bs.capacity, equals(16));
      expect(bs.length, equals(10));
      expect(bs.inputLength, equals(12));
      expect(bs.toBytes(), equals(gzipHeader));

      bs.close();
      expect(bs.capacity, equals(32));
      expect(bs.length, equals(32));
      expect(bs.inputLength, equals(12));
      print(bs.toBytes());
      expect(
        bs.toBytes(),
        equals([
          ...gzipHeader,
          99,
          100,
          98,
          102,
          97,
          101,
          99,
          231,
          224,
          228,
          74,
          77,
          3,
          0,
          58,
          8,
          70,
          196,
          12,
          0,
          0,
          0,
        ]),
      );

      bs.reset();
      expect(bs.capacity, equals(32));
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(0));
      expect(bs.toBytes(), equals([]));

      bs.add([1, 2, 3]);
      expect(bs.capacity, equals(32));
      expect(bs.length, equals(10));
      expect(bs.inputLength, equals(3));
      expect(bs.toBytes(), equals(gzipHeader));

      bs.close();
      expect(bs.capacity, equals(32));
      expect(bs.length, equals(23));
      expect(bs.inputLength, equals(3));
      expect(
        bs.toBytes(),
        equals([
          ...gzipHeader,
          99,
          100,
          98,
          6,
          0,
          29,
          128,
          188,
          85,
          3,
          0,
          0,
          0,
        ]),
      );
    });
  });

  group('AutoGZipSink', () {
    test('basic', () {
      var gzipHeader = _getGZipHeader();

      var bs = AutoGZipSink(minGZipLength: 10, capacity: 8);

      expect(bs.isGzip, isFalse);
      expect(bs.capacity, equals(8));
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(0));
      expect(bs.toBytes(), equals([]));

      bs.add([1, 2, 3]);
      expect(bs.isGzip, isFalse);
      expect(bs.capacity, equals(8));
      expect(bs.length, equals(3));
      expect(bs.inputLength, equals(3));
      expect(bs.toBytes(), equals([1, 2, 3]));

      bs.add([4, 5, 6, 7, 8]);
      expect(bs.isGzip, isFalse);
      expect(bs.capacity, equals(8));
      expect(bs.length, equals(8));
      expect(bs.inputLength, equals(8));
      expect(bs.toBytes(), equals([1, 2, 3, 4, 5, 6, 7, 8]));

      bs.add([9, 10]);
      expect(bs.isGzip, isTrue);
      expect(bs.length, equals(10));
      expect(bs.inputLength, equals(10));
      expect(bs.toBytes(), equals(gzipHeader));

      bs.addSlice([100, 101, 102], 1, 3, false);
      expect(bs.isGzip, isTrue);
      expect(bs.capacity, equals(16));
      expect(bs.length, equals(10));
      expect(bs.inputLength, equals(12));
      expect(bs.toBytes(), equals(gzipHeader));

      bs.close();
      expect(bs.isGzip, isTrue);
      expect(bs.capacity, equals(32));
      expect(bs.length, equals(32));
      expect(bs.inputLength, equals(12));
      print(bs.toBytes());
      expect(
        bs.toBytes(),
        equals([
          ...gzipHeader,
          99,
          100,
          98,
          102,
          97,
          101,
          99,
          231,
          224,
          228,
          74,
          77,
          3,
          0,
          58,
          8,
          70,
          196,
          12,
          0,
          0,
          0,
        ]),
      );

      bs.reset();
      expect(bs.isGzip, isFalse);
      expect(bs.capacity, equals(32));
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(0));
      expect(bs.toBytes(), equals([]));

      bs.add([1, 2, 3]);
      expect(bs.isGzip, isFalse);
      expect(bs.capacity, equals(32));
      expect(bs.length, equals(3));
      expect(bs.inputLength, equals(3));
      expect(bs.toBytes(), equals([1, 2, 3]));

      bs.close();
      expect(bs.isGzip, isFalse);
      expect(bs.capacity, equals(32));
      expect(bs.length, equals(3));
      expect(bs.inputLength, equals(3));
      expect(bs.toBytes(), equals([1, 2, 3]));
    });

    test('compatibility', () {
      var bs = AutoGZipSink(minGZipLength: 4);
      expect(bs.minGZipLength, equals(4));
      expect(bs.encoding, equals(APIContentEncoding.gzip));
      expect(bs.activeEncoding, isNull);

      bs.switchToGzip();
      expect(bs.isGzip, isTrue);
      expect(bs.isCompressing, isTrue);
      expect(bs.activeEncoding, equals(APIContentEncoding.gzip));
    });
  });

  group('BrotliSink', () {
    test('basic', () {
      var data = _text();

      var bs = BrotliSink(capacity: 8);
      expect(bs.encoding, equals(APIContentEncoding.br));
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(0));

      // Buffered until `close`:
      bs.add(data.sublist(0, 100));
      bs.addSlice(data, 100, data.length, false);
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(data.length));

      bs.close();
      expect(bs.inputLength, equals(data.length));
      expect(bs.length, lessThan(data.length));
      expect(APIBrotli.decode(bs.toBytes()), equals(data));

      // `close` is idempotent:
      var length = bs.length;
      bs.close();
      expect(bs.length, equals(length));

      bs.reset();
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(0));
      expect(bs.encoding, equals(APIContentEncoding.br));

      bs.addSlice([1, 2, 3, 4], 1, 3, true);
      expect(bs.inputLength, equals(2));
      expect(APIBrotli.decode(bs.toBytes()), equals([2, 3]));
    });

    test('encoder failure: falls back to GZip', () {
      APIBrotli.encoder = _failingBrotliEncoder;
      addTearDown(() => APIBrotli.encoder = APIBrotli.defaultEncoder);

      var data = _text();

      var bs = BrotliSink();
      bs.add(data);
      bs.close();

      expect(bs.encoding, equals(APIContentEncoding.gzip));
      expect(gzip.decode(bs.toBytes()), equals(data));

      var sink = AutoCompressSink(encoding: APIContentEncoding.br);
      sink.add(data);
      sink.close();
      expect(sink.activeEncoding, equals(APIContentEncoding.gzip));
      expect(gzip.decode(sink.toBytes()), equals(data));
    });
  });

  group('AutoCompressSink', () {
    test('br', () {
      var data = _text();

      var bs = AutoCompressSink(
        encoding: APIContentEncoding.br,
        minCompressLength: 10,
        capacity: 8,
      );

      bs.add([1, 2, 3]);
      expect(bs.isCompressing, isFalse);
      expect(bs.activeEncoding, isNull);
      expect(bs.toBytes(), equals([1, 2, 3]));

      bs.add(data);
      expect(bs.isCompressing, isTrue);
      expect(bs.isBrotli, isTrue);
      expect(bs.isGzip, isFalse);
      expect(bs.inputLength, equals(data.length + 3));

      bs.close();
      expect(bs.activeEncoding, equals(APIContentEncoding.br));
      expect(APIBrotli.decode(bs.toBytes()), equals([1, 2, 3, ...data]));

      bs.reset();
      expect(bs.isCompressing, isFalse);
      expect(bs.length, equals(0));
      expect(bs.inputLength, equals(0));

      bs.add([7, 8]);
      bs.close();
      expect(bs.toBytes(), equals([7, 8]));

      // Reused for another large payload: nothing from the previous ones.
      bs.reset();
      var data2 = utf8.encode('other payload ' * 100);
      bs.add(data2);
      expect(bs.isBrotli, isTrue);
      bs.close();
      expect(bs.activeEncoding, equals(APIContentEncoding.br));
      expect(bs.inputLength, equals(data2.length));
      expect(APIBrotli.decode(bs.toBytes()), equals(data2));
    });

    test('gzip level', () {
      var data = _text();

      var bs = AutoCompressSink(
        encoding: APIContentEncoding.gzip,
        gzipLevel: 9,
      );
      bs.add(data);
      bs.close();
      expect(bs.isGzip, isTrue);
      expect(gzip.decode(bs.toBytes()), equals(data));
    });

    test('no encoding', () {
      var data = _text();

      var bs = AutoCompressSink(encoding: null, minCompressLength: 1);
      bs.add(data);
      bs.switchToCompression();
      bs.close();

      expect(bs.isCompressing, isFalse);
      expect(bs.activeEncoding, isNull);
      expect(bs.toBytes(), equals(data));
    });
  });
}

List<int> _text() =>
    utf8.encode(List.generate(100, (i) => 'line $i: hello').join('\n'));

List<int> _getGZipHeader() {
  //[31, 139, 8, 0, 0, 0, 0, 0, 0, 19]
  var compressed = gzip.encode([1, 2, 3]);
  return compressed.sublist(0, 10);
}

import 'dart:io';

import 'package:bones_api/src/bones_api_utils_sink.dart';
import 'package:test/test.dart';

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
            0
          ]));

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
            0
          ]));
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
            0
          ]));

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
  });
}

List<int> _getGZipHeader() {
  //[31, 139, 8, 0, 0, 0, 0, 0, 0, 19]
  var compressed = gzip.encode([1, 2, 3]);
  return compressed.sublist(0, 10);
}

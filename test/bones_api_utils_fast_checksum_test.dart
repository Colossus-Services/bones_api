import 'dart:convert';
import 'dart:typed_data';

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('Adler32', () {
    final samples = <List<int>>[
      [],
      [0],
      [1, 2, 3, 4, 5],
      utf8.encode('hello'),
      utf8.encode('The quick brown fox jumps over the lazy dog'),
      List.generate(256, (i) => i),
    ];

    test('Uint8List matches archive integer', () {
      for (final data in samples) {
        final expected = getAdler32(data);
        final bytes = getAdler32Uint8List(data);

        expect(bytes.length, 4);

        final reconstructed =
            (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];

        expect(reconstructed, expected, reason: 'Mismatch for $data');
      }
    });

    test('Hex matches Uint8List encoding', () {
      for (final data in samples) {
        final hex = getAdler32Hex(data);
        final bytes = getAdler32Uint8List(data);

        expect(hex, _bytesToHex(bytes));
        expect(hex.length, 8);
      }
    });

    test('Deterministic output', () {
      final data = utf8.encode('deterministic');
      expect(getAdler32Hex(data), getAdler32Hex(data));
      expect(getAdler32Uint8List(data), getAdler32Uint8List(data));
    });
  });

  group('CRC32', () {
    final samples = <List<int>>[
      [],
      [0],
      [1, 2, 3, 4, 5],
      utf8.encode('hello'),
      utf8.encode('The quick brown fox jumps over the lazy dog'),
      List.generate(256, (i) => i),
    ];

    test('Uint8List matches archive integer', () {
      for (final data in samples) {
        final expected = getCrc32(data);
        final bytes = getCrc32Uint8List(data);

        expect(bytes.length, 4);

        final reconstructed =
            (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];

        expect(reconstructed, expected, reason: 'Mismatch for $data');
      }
    });

    test('Hex matches Uint8List encoding', () {
      for (final data in samples) {
        final hex = getCrc32Hex(data);
        final bytes = getCrc32Uint8List(data);

        expect(hex, _bytesToHex(bytes));
        expect(hex.length, 8);
      }
    });

    test('Deterministic output', () {
      final data = utf8.encode('deterministic');
      expect(getCrc32Hex(data), getCrc32Hex(data));
      expect(getCrc32Uint8List(data), getCrc32Uint8List(data));
    });
  });

  group('getAdler32Uint8List', () {
    test('empty input', () {
      final bytes = <int>[];
      final result = getAdler32Uint8List(bytes);

      expect(result.length, 4);
      expect(result, Uint8List.fromList([0x00, 0x00, 0x00, 0x01]));
    });

    test('single byte', () {
      final bytes = [1];
      final result = getAdler32Uint8List(bytes);

      expect(result, _intToBytes(getAdler32(bytes)));
    });

    test('multiple bytes', () {
      final bytes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      final result = getAdler32Uint8List(bytes);

      expect(result, _intToBytes(getAdler32(bytes)));
    });

    test('all 0xFF', () {
      final bytes = List<int>.filled(32, 0xFF);
      final result = getAdler32Uint8List(bytes);

      expect(result, _intToBytes(getAdler32(bytes)));
    });

    test('big endian order', () {
      final bytes = [10, 20, 30];
      final hash = getAdler32(bytes);
      final result = getAdler32Uint8List(bytes);

      expect(result[0], (hash >> 24) & 0xff);
      expect(result[1], (hash >> 16) & 0xff);
      expect(result[2], (hash >> 8) & 0xff);
      expect(result[3], hash & 0xff);
    });
  });

  group('getCrc32Uint8List', () {
    test('empty input', () {
      final bytes = <int>[];
      final result = getCrc32Uint8List(bytes);

      expect(result.length, 4);
      expect(result, _intToBytes(getCrc32(bytes)));
    });

    test('single byte', () {
      final bytes = [1];
      final result = getCrc32Uint8List(bytes);

      expect(result, _intToBytes(getCrc32(bytes)));
    });

    test('multiple bytes', () {
      final bytes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      final result = getCrc32Uint8List(bytes);

      expect(result, _intToBytes(getCrc32(bytes)));
    });

    test('all 0xFF', () {
      final bytes = List<int>.filled(32, 0xFF);
      final result = getCrc32Uint8List(bytes);

      expect(result, _intToBytes(getCrc32(bytes)));
    });

    test('big endian order', () {
      final bytes = [10, 20, 30];
      final hash = getCrc32(bytes);
      final result = getCrc32Uint8List(bytes);

      expect(result[0], (hash >> 24) & 0xff);
      expect(result[1], (hash >> 16) & 0xff);
      expect(result[2], (hash >> 8) & 0xff);
      expect(result[3], hash & 0xff);
    });
  });

  group('getAdler32Hex', () {
    test('empty string', () {
      expect(getAdler32Hex(''.codeUnits), '00000001');
    });

    test('a', () {
      expect(getAdler32Hex('a'.codeUnits), '00620062');
    });

    test('hello', () {
      expect(getAdler32Hex('hello'.codeUnits), '062c0215');
    });

    test('hello world', () {
      expect(getAdler32Hex('hello world'.codeUnits), '1a0b045d');
    });

    test('quick fox', () {
      expect(
        getAdler32Hex('The quick brown fox jumps over the lazy dog'.codeUnits),
        '5bdc0fda',
      );
    });
  });

  group('getCrc32Hex', () {
    test('empty string', () {
      expect(getCrc32Hex(''.codeUnits), '00000000');
    });

    test('a', () {
      expect(getCrc32Hex('a'.codeUnits), 'e8b7be43');
    });

    test('hello', () {
      expect(getCrc32Hex('hello'.codeUnits), '3610a686');
    });

    test('hello world', () {
      expect(getCrc32Hex('hello world'.codeUnits), '0d4a1185');
    });

    test('quick fox', () {
      expect(
        getCrc32Hex('The quick brown fox jumps over the lazy dog'.codeUnits),
        '414fa339',
      );
    });
  });
}

String _bytesToHex(List<int> bytes) {
  final b = StringBuffer();
  for (final v in bytes) {
    b.write(v.toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}

Uint8List _intToBytes(int hash) => Uint8List.fromList([
  (hash >> 24) & 0xff,
  (hash >> 16) & 0xff,
  (hash >> 8) & 0xff,
  hash & 0xff,
]);

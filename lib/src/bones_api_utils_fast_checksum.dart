import 'dart:typed_data';

import 'package:archive/archive.dart' show getAdler32, getCrc32;

export 'package:archive/archive.dart' show getAdler32, getCrc32;

/// Returns the Adler-32 checksum of [bs] as a 4-byte [Uint8List] (big-endian).
///
/// See also: [getAdler32].
Uint8List getAdler32Uint8List(List<int> bs) {
  final hash = getAdler32(bs);
  return _uint32ToBytesBE(hash);
}

/// Returns the Adler-32 checksum of [bs] as a lowercase hexadecimal string.
///
/// The output is an 8-character hex representation (big-endian).
///
/// See also: [getAdler32Uint8List], [getAdler32].
String getAdler32Hex(List<int> bs) {
  final hash = getAdler32Uint8List(bs);
  return _hexEncode(hash);
}

/// Returns the CRC-32 checksum of [bs] as a 4-byte [Uint8List] (big-endian).
///
/// See also: [getCrc32].
Uint8List getCrc32Uint8List(List<int> bs) {
  final hash = getCrc32(bs);
  return _uint32ToBytesBE(hash);
}

/// Returns the CRC-32 checksum of [bs] as a lowercase hexadecimal string.
///
/// The output is an 8-character hex representation (big-endian).
///
/// See also: [getCrc32Uint8List], [getCrc32].
String getCrc32Hex(List<int> bs) {
  final hash = getCrc32Uint8List(bs);
  return _hexEncode(hash);
}

/// Converts a 32-bit integer to a 4-byte Uint8List (big-endian).
Uint8List _uint32ToBytesBE(int hash) {
  return Uint8List.fromList([
    (hash >> 24) & 0xff,
    (hash >> 16) & 0xff,
    (hash >> 8) & 0xff,
    hash & 0xff,
  ]);
}

/// Encodes [bytes] into a lowercase hexadecimal string.
///
/// Each byte is converted into two hex characters (00–ff),
/// preserving the original byte order.
String _hexEncode(List<int> bytes) {
  const hexDigits = '0123456789abcdef';
  var charCodes = Uint8List(bytes.length * 2);
  for (var i = 0, j = 0; i < bytes.length; i++) {
    var byte = bytes[i];
    charCodes[j++] = hexDigits.codeUnitAt((byte >> 4) & 0xF);
    charCodes[j++] = hexDigits.codeUnitAt(byte & 0xF);
  }
  return String.fromCharCodes(charCodes);
}

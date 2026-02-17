// ignore_for_file: unrelated_type_equality_checks

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

void main() {
  group('WeakEtag.parse', () {
    test('empty string -> empty etag', () {
      final e = WeakEtag.parse('');
      expect(e.isEmpty, isTrue);
      expect(e.values, isEmpty);
      expect(e.tag, '');
      expect(e.toString(), 'W/""');
    });

    test('parses raw value', () {
      final e = WeakEtag.parse('a,b,c');
      expect(e.values, ['a', 'b', 'c']);
      expect(e.tag, 'a,b,c');
    });

    test('parses with W/ prefix and quotes', () {
      final e = WeakEtag.parse('W/"a,b,c"');
      expect(e.values, ['a', 'b', 'c']);
      expect(e.toString(), 'W/"a,b,c"');
    });

    test('trims spaces', () {
      final e = WeakEtag.parse('  W/"a,b"  ');
      expect(e.values, ['a', 'b']);
    });

    test('custom delimiter', () {
      final e = WeakEtag.parse('W/"a|b|c"', delimiter: '|');
      expect(e.values, ['a', 'b', 'c']);
      expect(e.tag, 'a|b|c');
    });
  });

  group('WeakEtag.parse edge cases', () {
    test('W/ only -> empty', () {
      final e = WeakEtag.parse('W/');
      expect(e.isEmpty, isTrue);
      expect(e.tag, '');
    });

    test('quotes only -> empty', () {
      final e = WeakEtag.parse('""');
      expect(e.isEmpty, isTrue);
    });

    test('spaces only -> empty', () {
      final e = WeakEtag.parse('   ');
      expect(e.isEmpty, isTrue);
    });

    test('keeps provided delimiter for tag', () {
      final e = WeakEtag.parse('W/"a|b"', delimiter: '|');
      expect(e.tag, 'a|b');
      expect(e.toString(), 'W/"a|b"');
    });
  });

  group('WeakEtag.adler32 / crc32', () {
    test('empty bytes -> empty etag', () {
      expect(WeakEtag.adler32([]).isEmpty, isTrue);
      expect(WeakEtag.crc32([]).isEmpty, isTrue);
    });

    test('non-empty bytes include length + hash + fragments', () {
      final bytes = [1, 2, 3, 4];

      final a = WeakEtag.adler32(bytes);
      final c = WeakEtag.crc32(bytes);

      expect(a.values.length, 3);
      expect(c.values.length, 3);

      expect(a.values.first, '4');
      expect(c.values.first, '4');

      expect(a.tag.contains(','), isTrue);
      expect(c.tag.contains(','), isTrue);
    });
  });

  group('_computeFragments behavior (via factories)', () {
    test('length 1', () {
      final e = WeakEtag.adler32([0xAB]);
      expect(e.values.last.length, 2); // single hex8
    });

    test('length 2', () {
      final e = WeakEtag.adler32([0xAA, 0xBB]);
      expect(e.values.last.length, 4);
    });

    test('length 3', () {
      final e = WeakEtag.adler32([1, 2, 3]);
      expect(e.values.last.length, 6);
    });

    test('length >= 4 uses first, center-1, center, last', () {
      final bytes = [10, 20, 30, 40, 50, 60];
      final e = WeakEtag.adler32(bytes);

      final fragments = e.values.last;
      expect(fragments.length, 8); // 4 hex8 fragments
    });
  });

  group('Fragments exact positions', () {
    test('length 4 uses first, mid-1, mid, last', () {
      final e = WeakEtag.adler32([0x10, 0x20, 0x30, 0x40]);

      // expected: 10 20 30 40 (hex8)
      expect(e.values.last.toLowerCase(), '10203040');
    });

    test('length 5 center rounding', () {
      final e = WeakEtag.adler32([1, 2, 3, 4, 5]);

      // center = 2 → picks: 1,2,3,5
      expect(e.values.last.toLowerCase(), '01020305');
    });
  });

  group('Equality', () {
    test('same values -> equal', () {
      final a = WeakEtag(['1', 'abc']);
      final b = WeakEtag(['1', 'abc']);

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('different values -> not equal', () {
      final a = WeakEtag(['1', 'abc']);
      final b = WeakEtag(['2', 'abc']);

      expect(a == b, isFalse);
    });

    test('equals string representation', () {
      final e = WeakEtag(['a', 'b']);
      expect(e == 'W/"a,b"', isTrue);
      expect(e == 'a,b', isTrue);
    });

    test('not equal to unrelated type', () {
      final e = WeakEtag(['a']);
      expect(e == 123, isFalse);
    });
  });

  group('Equality deeper behavior', () {
    test('identical fast path', () {
      final a = WeakEtag(['x']);
      expect(a.equals(a), isTrue);
    });

    test('string equality ignores W/ and quotes', () {
      final e = WeakEtag(['a', 'b']);
      expect(e.equals('"a,b"'), isTrue);
      expect(e.equals('W/a,b'), isTrue);
    });

    test('delimiter mismatch string not equal', () {
      final e = WeakEtag(['a', 'b'], delimiter: '|');
      expect(e == 'a,b', isTrue);
      expect(e == 'a,c', isFalse);
    });

    test('empty equals empty string', () {
      final e = WeakEtag([]);
      expect(e == '', isTrue);
      expect(e == 'W/""', isTrue);
    });
  });

  group('Hash & cache stability', () {
    test('hashCode stable across calls', () {
      final e = WeakEtag(['a', 'b']);
      final h1 = e.hashCode;
      final h2 = e.hashCode;
      expect(h1, h2);
    });

    test('tag cache survives equality calls', () {
      final e = WeakEtag(['x', 'y']);
      final t1 = e.tag;
      expect(e == 'x,y', isTrue);
      final t2 = e.tag;
      expect(identical(t1, t2), isTrue);
    });
  });

  group('Immutability', () {
    test('values is unmodifiable', () {
      final e = WeakEtag(['a', 'b']);

      expect(() => e.values.add('c'), throwsUnsupportedError);
    });
  });

  group('Deep immutability', () {
    test('cannot modify via cast', () {
      final e = WeakEtag(['a', 'b']);
      expect(() => (e.values as List).removeAt(0), throwsUnsupportedError);
    });
  });

  group('Caching behavior', () {
    test('tag is memoized', () {
      final e = WeakEtag(['x', 'y']);
      final t1 = e.tag;
      final t2 = e.tag;

      expect(identical(t1, t2), isTrue);
    });

    test('toString is memoized', () {
      final e = WeakEtag(['x']);
      final s1 = e.toString();
      final s2 = e.toString();

      expect(identical(s1, s2), isTrue);
    });
  });

  group('Algorithm distinction', () {
    test('crc32 and adler32 generate different tags', () {
      final bytes = [1, 2, 3, 4, 5, 6, 7, 8];

      final a = WeakEtag.adler32(bytes);
      final c = WeakEtag.crc32(bytes);

      expect(a.tag, isNot(c.tag));
      expect(a != c, isTrue);
    });
  });
}

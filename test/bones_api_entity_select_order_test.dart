@Tags(['entities'])
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

/// A minimal row, so [applySelectOrderAndPagination] is exercised over a type
/// that is not a `Map` (as the object adapters use) nor an entity.
class _Row {
  final Object? id;

  _Row(this.id);

  @override
  String toString() => 'Row($id)';
}

List<Object?> _ids(Iterable<_Row> rows) => rows.map((e) => e.id).toList();

Iterable<_Row> _apply(
  List<Object?> ids, {
  int? limit,
  int? offset,
  bool? orderByID,
  OrderDirection? orderDirection,
  bool zeroLimitIsUnlimited = false,
}) => applySelectOrderAndPagination(
  ids.map(_Row.new),
  (r) => r.id,
  limit: limit,
  offset: offset,
  orderByID: orderByID,
  orderDirection: orderDirection,
  zeroLimitIsUnlimited: zeroLimitIsUnlimited,
);

void main() {
  group('OrderDirection', () {
    test('defaults', () {
      expect(OrderDirection.defaultDirection, equals(OrderDirection.ascending));
      expect(OrderDirection.resolve(null), equals(OrderDirection.ascending));
      expect(
        OrderDirection.resolve(OrderDirection.descending),
        equals(OrderDirection.descending),
      );
    });

    test('isAscending/isDescending/sqlKeyword', () {
      expect(OrderDirection.ascending.isAscending, isTrue);
      expect(OrderDirection.ascending.isDescending, isFalse);
      expect(OrderDirection.ascending.sqlKeyword, equals('ASC'));

      expect(OrderDirection.descending.isAscending, isFalse);
      expect(OrderDirection.descending.isDescending, isTrue);
      expect(OrderDirection.descending.sqlKeyword, equals('DESC'));
    });

    test('parse', () {
      for (var s in ['asc', 'ASC', ' Ascending ', 'up', '+']) {
        expect(
          OrderDirection.parse(s),
          equals(OrderDirection.ascending),
          reason: 'parse($s)',
        );
      }

      for (var s in ['desc', 'DESC', ' Descending ', 'down', '-']) {
        expect(
          OrderDirection.parse(s),
          equals(OrderDirection.descending),
          reason: 'parse($s)',
        );
      }

      expect(OrderDirection.parse(null), isNull);
      expect(OrderDirection.parse(''), isNull);
      expect(OrderDirection.parse('   '), isNull);
      expect(OrderDirection.parse('bogus'), isNull);

      // Round-trip of an `OrderDirection` instance:
      expect(
        OrderDirection.parse(OrderDirection.descending),
        equals(OrderDirection.descending),
      );
    });

    test('resolveOrderByID', () {
      // Unset and no offset: no ordering (the pre-existing behavior).
      expect(OrderDirection.resolveOrderByID(null, null), isFalse);

      // An `offset` implies the ordering, so the pagination is stable:
      expect(OrderDirection.resolveOrderByID(null, 0), isTrue);
      expect(OrderDirection.resolveOrderByID(null, 10), isTrue);

      // An explicit value always wins:
      expect(OrderDirection.resolveOrderByID(false, 10), isFalse);
      expect(OrderDirection.resolveOrderByID(true, null), isTrue);
    });
  });

  group('compareEntityIDs', () {
    test('num', () {
      expect(compareEntityIDs(1, 2), lessThan(0));
      expect(compareEntityIDs(2, 1), greaterThan(0));
      expect(compareEntityIDs(2, 2), equals(0));
      expect(compareEntityIDs(1, 1.5), lessThan(0));
    });

    test('String', () {
      expect(compareEntityIDs('a', 'b'), lessThan(0));
      expect(compareEntityIDs('b', 'a'), greaterThan(0));
      expect(compareEntityIDs('a', 'a'), equals(0));
    });

    test('null is ordered last', () {
      expect(compareEntityIDs(null, null), equals(0));
      expect(compareEntityIDs(null, 1), greaterThan(0));
      expect(compareEntityIDs(1, null), lessThan(0));
    });

    test('mismatched types are undefined (0)', () {
      expect(compareEntityIDs(1, 'a'), equals(0));
      expect(compareEntityIDs('a', 1), equals(0));
    });

    test('sort round-trip', () {
      var ids = <Object?>[3, null, 1, 2];
      ids.sort(compareEntityIDs);
      expect(ids, equals([1, 2, 3, null]));
    });
  });

  group('resolveSelectOffset', () {
    test('no page returns the offset unchanged', () {
      expect(resolveSelectOffset(), isNull);
      expect(resolveSelectOffset(offset: 40), equals(40));
      expect(resolveSelectOffset(offset: 40, limit: 20), equals(40));
      expect(resolveSelectOffset(offset: 0), equals(0));
    });

    test('page is 1-based', () {
      expect(resolveSelectOffset(page: 1, limit: 20), equals(0));
      expect(resolveSelectOffset(page: 2, limit: 20), equals(20));
      expect(resolveSelectOffset(page: 3, limit: 20), equals(40));
      expect(resolveSelectOffset(page: 10, limit: 3), equals(27));
      expect(resolveSelectOffset(page: 2, limit: 1), equals(1));
    });

    test('page 1 resolves to offset 0, which activates the ordering', () {
      var offset = resolveSelectOffset(page: 1, limit: 20);
      expect(offset, equals(0));
      // A paginated select must be stable even on the first page:
      expect(OrderDirection.resolveOrderByID(null, offset), isTrue);
    });

    test('page requires a positive limit', () {
      expect(
        () => resolveSelectOffset(page: 3),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('requires a positive `limit`'),
          ),
        ),
      );

      // No special case for page 1: the rule stays predictable.
      expect(() => resolveSelectOffset(page: 1), throwsArgumentError);

      // A `limit` of 0 means "no limit", so it is not a page size:
      expect(() => resolveSelectOffset(page: 2, limit: 0), throwsArgumentError);
      expect(
        () => resolveSelectOffset(page: 2, limit: -1),
        throwsArgumentError,
      );
    });

    test('page and offset are mutually exclusive', () {
      expect(
        () => resolveSelectOffset(page: 3, offset: 100, limit: 20),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('mutually exclusive'),
          ),
        ),
      );

      // Even when they would agree, and even for an offset of 0:
      expect(
        () => resolveSelectOffset(page: 3, offset: 40, limit: 20),
        throwsArgumentError,
      );
      expect(
        () => resolveSelectOffset(page: 1, offset: 0, limit: 20),
        throwsArgumentError,
      );
    });

    test('page must be >= 1', () {
      expect(
        () => resolveSelectOffset(page: 0, limit: 20),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('1-based'),
          ),
        ),
      );

      expect(
        () => resolveSelectOffset(page: -1, limit: 20),
        throwsArgumentError,
      );
    });
  });

  group('applySelectOrderAndPagination', () {
    // Deliberately unsorted, so an ordered result can't pass by accident:
    final ids = <Object?>[3, 1, 5, 2, 4];

    test('no ordering and no pagination is a pass-through', () {
      expect(_ids(_apply(ids)), equals(ids));
    });

    test('orderDirection alone is ignored', () {
      expect(
        _ids(_apply(ids, orderDirection: OrderDirection.descending)),
        equals(ids),
      );
    });

    test('orderByID ascending/descending', () {
      expect(_ids(_apply(ids, orderByID: true)), equals([1, 2, 3, 4, 5]));

      expect(
        _ids(
          _apply(
            ids,
            orderByID: true,
            orderDirection: OrderDirection.ascending,
          ),
        ),
        equals([1, 2, 3, 4, 5]),
      );

      expect(
        _ids(
          _apply(
            ids,
            orderByID: true,
            orderDirection: OrderDirection.descending,
          ),
        ),
        equals([5, 4, 3, 2, 1]),
      );
    });

    test('offset implies the ordering', () {
      expect(_ids(_apply(ids, offset: 2)), equals([3, 4, 5]));

      expect(
        _ids(_apply(ids, offset: 1, orderDirection: OrderDirection.descending)),
        equals([4, 3, 2, 1]),
      );
    });

    test('orderByID: false opts out of the implied ordering', () {
      // Skips 2 elements of the natural (unordered) sequence:
      expect(_ids(_apply(ids, offset: 2, orderByID: false)), equals([5, 2, 4]));
    });

    test('offset + limit', () {
      expect(_ids(_apply(ids, offset: 1, limit: 2)), equals([2, 3]));

      expect(
        _ids(
          _apply(
            ids,
            offset: 1,
            limit: 2,
            orderDirection: OrderDirection.descending,
          ),
        ),
        equals([4, 3]),
      );
    });

    test('offset past the end returns empty', () {
      expect(_ids(_apply(ids, offset: 5)), isEmpty);
      expect(_ids(_apply(ids, offset: 100)), isEmpty);
    });

    test('limit greater than the length returns all', () {
      expect(
        _ids(_apply(ids, orderByID: true, limit: 100)),
        equals([1, 2, 3, 4, 5]),
      );
    });

    test('non-positive offset is ignored, but still implies the ordering', () {
      expect(_ids(_apply(ids, offset: 0)), equals([1, 2, 3, 4, 5]));
      expect(_ids(_apply(ids, offset: -1)), equals([1, 2, 3, 4, 5]));
    });

    test('zeroLimitIsUnlimited', () {
      // In-memory selects: a `limit` of 0 returns an empty result.
      expect(_ids(_apply(ids, limit: 0)), isEmpty);

      // Generated SQL: a `limit` of 0 emits no `LIMIT` clause.
      expect(
        _ids(_apply(ids, limit: 0, zeroLimitIsUnlimited: true)),
        equals(ids),
      );
    });

    test('null IDs are ordered last', () {
      expect(
        _ids(_apply(<Object?>[2, null, 1], orderByID: true)),
        equals([1, 2, null]),
      );

      expect(
        _ids(
          _apply(
            <Object?>[2, null, 1],
            orderByID: true,
            orderDirection: OrderDirection.descending,
          ),
        ),
        equals([null, 2, 1]),
      );
    });

    test('String IDs', () {
      expect(
        _ids(_apply(<Object?>['c', 'a', 'b'], offset: 1)),
        equals(['b', 'c']),
      );
    });
  });

  group('SQLDialect', () {
    // The dialects actually declared by the adapters:
    const generic = SQLDialect('generic');
    const postgres = SQLDialect('PostgreSQL', elementQuote: '"');
    const mysql = SQLDialect(
      'MySQL',
      elementQuote: '`',
      offsetRequiresLimit: true,
    );

    test('defaults', () {
      expect(generic.offsetRequiresLimit, isFalse);
      expect(postgres.offsetRequiresLimit, isFalse);
      expect(mysql.offsetRequiresLimit, isTrue);
      expect(generic.offsetMaxLimitValue, equals('18446744073709551615'));
    });

    test('limitOffsetSQL: no clause', () {
      for (var d in [generic, postgres, mysql]) {
        expect(d.limitOffsetSQL(), equals(''), reason: d.name);
        expect(
          d.limitOffsetSQL(limit: 0, offset: 0),
          equals(''),
          reason: d.name,
        );
        expect(
          d.limitOffsetSQL(limit: -1, offset: -1),
          equals(''),
          reason: d.name,
        );
      }
    });

    test('limitOffsetSQL: limit only', () {
      for (var d in [generic, postgres, mysql]) {
        expect(
          d.limitOffsetSQL(limit: 10),
          equals(' LIMIT 10'),
          reason: d.name,
        );
      }
    });

    test('limitOffsetSQL: limit and offset', () {
      for (var d in [generic, postgres, mysql]) {
        expect(
          d.limitOffsetSQL(limit: 10, offset: 20),
          equals(' LIMIT 10 OFFSET 20'),
          reason: d.name,
        );
      }
    });

    test('limitOffsetSQL: offset only', () {
      expect(generic.limitOffsetSQL(offset: 20), equals(' OFFSET 20'));
      expect(postgres.limitOffsetSQL(offset: 20), equals(' OFFSET 20'));

      // MySQL can't parse a standalone `OFFSET`:
      expect(
        mysql.limitOffsetSQL(offset: 20),
        equals(' LIMIT 18446744073709551615 OFFSET 20'),
      );
    });

    test('orderBySQL', () {
      expect(postgres.orderBySQL('u', 'id'), equals(' ORDER BY "u"."id" ASC'));

      expect(
        postgres.orderBySQL('u', 'id', direction: OrderDirection.descending),
        equals(' ORDER BY "u"."id" DESC'),
      );

      expect(
        mysql.orderBySQL('u', 'user_id'),
        equals(' ORDER BY `u`.`user_id` ASC'),
      );

      // The `generic` dialect has no element quote:
      expect(generic.orderBySQL('u', 'id'), equals(' ORDER BY u.id ASC'));
    });
  });
}

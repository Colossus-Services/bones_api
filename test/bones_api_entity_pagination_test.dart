@Tags(['entities'])
// ignore_for_file: discarded_futures
import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

/// A trivial entity, so the pagination state machine can be exercised without
/// a DB.
class _Item {
  final int id;

  _Item(this.id);

  @override
  String toString() => 'Item($id)';
}

/// A fake backing store of [total] items, recording every page fetch.
class _FakeSource {
  final int total;
  final bool async;

  /// Every page requested, in order. Duplicates here mean a page was fetched
  /// more than once.
  final List<int> fetches = [];

  _FakeSource(this.total, {this.async = true});

  FutureOr<List<_Item>> load(int page, int limit) {
    fetches.add(page);

    var start = (page - 1) * limit;
    var entries = <_Item>[
      for (var i = start; i < start + limit && i < total; ++i) _Item(i),
    ];

    return async ? Future.value(entries) : entries;
  }

  EntityPagination<_Item> pagination({int limit = 10}) =>
      EntityPagination<_Item>(limit: limit, pageLoader: load, query: 'fake');
}

List<int> _ids(Iterable<_Item> items) => items.map((e) => e.id).toList();

void main() {
  group('EntityPagination: construction', () {
    test('rejects a non-positive limit', () {
      var source = _FakeSource(10);

      expect(
        () => EntityPagination<_Item>(limit: 0, pageLoader: source.load),
        throwsArgumentError,
      );
      expect(
        () => EntityPagination<_Item>(limit: -1, pageLoader: source.load),
        throwsArgumentError,
      );
    });

    test('starts empty and loads nothing', () {
      var source = _FakeSource(100);
      var p = source.pagination();

      expect(source.fetches, isEmpty, reason: 'Must not fetch eagerly');

      expect(p.loadedPages, isEmpty);
      expect(p.loadedPagesLength, equals(0));
      expect(p.loadedEntities, isEmpty);
      expect(p.loadedEntitiesLength, equals(0));
      expect(p.maxLoadedPage, isNull);
      expect(p.maxLoadedIndex, isNull);
      expect(p.maxKnownPage, isNull);
      expect(p.isFinalPageResolved, isFalse);
      expect(p.finalPage, isNull);
      expect(p.totalLength, isNull);
      expect(p.isKnownEmpty, isFalse);
      expect(p[0], isNull);
    });
  });

  group('EntityPagination: page/index mapping', () {
    test('pages are 1-based and indexes 0-based', () {
      var p = _FakeSource(100).pagination(limit: 20);

      expect(p.indexOfPage(1), equals(0));
      expect(p.indexOfPage(2), equals(20));
      expect(p.indexOfPage(3), equals(40));

      expect(p.pageOfIndex(0), equals(1));
      expect(p.pageOfIndex(19), equals(1));
      expect(p.pageOfIndex(20), equals(2));
      expect(p.pageOfIndex(45), equals(3));
    });

    test('loadPage rejects a page below 1', () {
      var p = _FakeSource(100).pagination();

      expect(() => p.loadPage(0), throwsArgumentError);
      expect(() => p.loadPage(-1), throwsArgumentError);
    });
  });

  group('EntityPagination: sequential loading', () {
    test('loadNextPage walks the pages', () async {
      var source = _FakeSource(25);
      var p = source.pagination(limit: 10);

      expect(
        _ids((await p.loadNextPage())!),
        equals([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
      );
      expect(p.maxLoadedPage, equals(1));
      expect(p.maxLoadedIndex, equals(9));
      expect(p.maxKnownPage, equals(1));
      expect(
        p.isFinalPageResolved,
        isFalse,
        reason: 'A full page is not final',
      );
      expect(p.totalLength, isNull);

      expect(
        _ids((await p.loadNextPage())!),
        equals([10, 11, 12, 13, 14, 15, 16, 17, 18, 19]),
      );
      expect(p.isFinalPageResolved, isFalse);

      // Page 3 is short -> it is the final page:
      expect(_ids((await p.loadNextPage())!), equals([20, 21, 22, 23, 24]));
      expect(p.isFinalPageResolved, isTrue);
      expect(p.finalPage, equals(3));
      expect(p.totalLength, equals(25));
      expect(p.maxLoadedIndex, equals(24));

      // Nothing more:
      expect(await p.loadNextPage(), isNull);
      expect(source.fetches, equals([1, 2, 3]), reason: 'No extra fetch');
    });

    test('sync page loader works without awaiting', () {
      var source = _FakeSource(5, async: false);
      var p = source.pagination(limit: 10);

      var entries = p.loadPage(1);
      expect(entries, isA<List<_Item>>());
      expect(_ids(entries as List<_Item>), equals([0, 1, 2, 3, 4]));
      expect(p.totalLength, equals(5));
    });
  });

  group('EntityPagination: final page resolution', () {
    test('a short page is the final page', () async {
      var p = _FakeSource(7).pagination(limit: 10);

      await p.loadPage(1);
      expect(p.finalPage, equals(1));
      expect(p.totalLength, equals(7));
      expect(p.isKnownEmpty, isFalse);
    });

    test('an exactly-full last page needs the next page to resolve', () async {
      var source = _FakeSource(20);
      var p = source.pagination(limit: 10);

      await p.loadPage(1);
      await p.loadPage(2);
      expect(
        p.isFinalPageResolved,
        isFalse,
        reason: 'Page 2 is full, page 3 might exist',
      );

      // Page 3 is empty and page 2 is loaded and full -> page 2 is final:
      expect(await p.loadPage(3), isEmpty);
      expect(p.isFinalPageResolved, isTrue);
      expect(p.finalPage, equals(2));
      expect(p.totalLength, equals(20));
    });

    test('an empty page 1 means the select matches nothing', () async {
      var p = _FakeSource(0).pagination(limit: 10);

      expect(await p.loadPage(1), isEmpty);
      expect(p.isFinalPageResolved, isTrue);
      expect(p.finalPage, equals(1));
      expect(p.totalLength, equals(0));
      expect(p.isKnownEmpty, isTrue);
      expect(p.maxKnownPage, isNull, reason: 'No page holds entries');
      expect(p.maxLoadedIndex, isNull);
    });

    test(
      'an empty page far past the end does NOT resolve the final page',
      () async {
        var source = _FakeSource(25);
        var p = source.pagination(limit: 10);

        // Jump way past the end: only tells that the end is before page 50.
        expect(await p.loadPage(50), isEmpty);
        expect(p.isFinalPageResolved, isFalse);
        expect(p.finalPage, isNull);
        expect(p.totalLength, isNull);
        expect(p.maxKnownPage, isNull);
        expect(
          p.maxLoadedPage,
          equals(50),
          reason: 'It was loaded, though empty',
        );

        // But it is enough to skip fetching that page, and any page after it:
        source.fetches.clear();
        expect(await p.loadPage(50), isEmpty);
        expect(await p.loadPage(60), isEmpty);
        expect(source.fetches, isEmpty, reason: 'Known to be past the end');

        // Reaching the short page still resolves it:
        await p.loadPage(3);
        expect(p.finalPage, equals(3));
        expect(p.totalLength, equals(25));
      },
    );

    test(
      'a later empty page resolves once its predecessor is loaded full',
      () async {
        var p = _FakeSource(20).pagination(limit: 10);

        // Page 3 is empty, but page 2 is not loaded yet: unresolved.
        expect(await p.loadPage(3), isEmpty);
        expect(p.isFinalPageResolved, isFalse);

        // Loading page 2 (full) now pins the end at page 2:
        await p.loadPage(2);
        expect(p.isFinalPageResolved, isTrue);
        expect(p.finalPage, equals(2));
        expect(p.totalLength, equals(20));
      },
    );
  });

  group('EntityPagination: sparse loading (gaps)', () {
    test('getAt loads only the page it needs', () async {
      var source = _FakeSource(100);
      var p = source.pagination(limit: 20);

      var item = await p.getAt(45);
      expect(item?.id, equals(45));

      expect(source.fetches, equals([3]), reason: 'Only page 3');
      expect(p.loadedPages, equals([3]));
      expect(p.maxLoadedPage, equals(3));
      expect(p.maxLoadedIndex, equals(59));
      expect(p.maxKnownPage, equals(3));
      expect(p.loadedEntitiesLength, equals(20));

      // Everything before page 3 is a gap:
      expect(p[0], isNull);
      expect(p[25], isNull);
      expect(p.isIndexLoaded(25), isFalse);
      expect(p[40], isNotNull);
      expect(p.isIndexLoaded(40), isTrue);
    });

    test('loadedEntities is in index order, gaps skipped', () async {
      var p = _FakeSource(100).pagination(limit: 10);

      // Deliberately out of order:
      await p.loadPage(3);
      await p.loadPage(1);

      expect(p.loadedPages, equals([1, 3]));
      expect(
        _ids(p.loadedEntities),
        equals([
          0,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          20,
          21,
          22,
          23,
          24,
          25,
          26,
          27,
          28,
          29,
        ]),
      );
      expect(p.loadedEntitiesLength, equals(20));
      expect(
        p.maxLoadedIndex,
        equals(29),
        reason: 'maxLoadedIndex counts the gap, loadedEntitiesLength does not',
      );
    });

    test('loadNextPage continues after the highest loaded page', () async {
      var source = _FakeSource(100);
      var p = source.pagination(limit: 10);

      await p.loadPage(5);
      source.fetches.clear();

      var next = await p.loadNextPage();
      expect(_ids(next!).first, equals(50));
      expect(source.fetches, equals([6]));
    });
  });

  group('EntityPagination: access', () {
    test('operator [] never fetches', () async {
      var source = _FakeSource(100);
      var p = source.pagination(limit: 10);

      expect(p[5], isNull);
      expect(source.fetches, isEmpty);

      await p.loadPage(1);
      source.fetches.clear();

      expect(p[5]?.id, equals(5));
      expect(p[50], isNull);
      expect(source.fetches, isEmpty, reason: 'Sync access must not fetch');
    });

    test('getAt returns null out of range without fetching twice', () async {
      var source = _FakeSource(5);
      var p = source.pagination(limit: 10);

      expect((await p.getAt(3))?.id, equals(3));
      expect(await p.getAt(7), isNull, reason: 'Page loaded but shorter');

      expect(source.fetches, equals([1]));
    });

    test('getAt with a negative index', () async {
      var p = _FakeSource(10).pagination();
      expect(await p.getAt(-1), isNull);
      expect(p[-1], isNull);
    });

    test('getRange loads every page spanning the range', () async {
      var source = _FakeSource(100);
      var p = source.pagination(limit: 10);

      var range = await p.getRange(5, 25);
      expect(_ids(range), equals([for (var i = 5; i < 25; ++i) i]));
      expect(source.fetches, equals([1, 2, 3]));
    });

    test('getRange fills a gap', () async {
      var source = _FakeSource(100);
      var p = source.pagination(limit: 10);

      await p.loadPage(1);
      await p.loadPage(3);
      source.fetches.clear();

      var range = await p.getRange(0, 30);
      expect(_ids(range), equals([for (var i = 0; i < 30; ++i) i]));
      expect(source.fetches, equals([2]), reason: 'Only the missing page');
    });

    test('getRange edge cases', () async {
      var p = _FakeSource(100).pagination(limit: 10);

      expect(await p.getRange(5, 5), isEmpty);
      expect(await p.getRange(5, 1), isEmpty);
      expect(() => p.getRange(-1, 5), throwsArgumentError);
    });

    test('getRange past the end returns what exists', () async {
      var p = _FakeSource(12).pagination(limit: 10);

      var range = await p.getRange(8, 30);
      expect(_ids(range), equals([8, 9, 10, 11]));
      expect(p.totalLength, equals(12));
    });
  });

  group('EntityPagination: loadAll and stream', () {
    test('loadAll resolves the total', () async {
      var source = _FakeSource(25);
      var p = source.pagination(limit: 10);

      expect(await p.loadAll(), equals(25));
      expect(p.isFinalPageResolved, isTrue);
      expect(p.finalPage, equals(3));
      expect(_ids(p.loadedEntities), equals([for (var i = 0; i < 25; ++i) i]));
      expect(source.fetches, equals([1, 2, 3]));
    });

    test('loadAll on an empty result', () async {
      var p = _FakeSource(0).pagination(limit: 10);

      expect(await p.loadAll(), equals(0));
      expect(p.isKnownEmpty, isTrue);
    });

    test('loadAll on an exact multiple of the page size', () async {
      var source = _FakeSource(20);
      var p = source.pagination(limit: 10);

      expect(await p.loadAll(), equals(20));
      expect(p.finalPage, equals(2));
      expect(
        source.fetches,
        equals([1, 2, 3]),
        reason: 'Needs the empty page 3 to know page 2 was the last',
      );
    });

    test(
      'loadAll with maxPages stops early and leaves it unresolved',
      () async {
        var source = _FakeSource(100);
        var p = source.pagination(limit: 10);

        expect(await p.loadAll(maxPages: 2), isNull);
        expect(p.isFinalPageResolved, isFalse);
        expect(p.loadedPages, equals([1, 2]));
        expect(source.fetches, equals([1, 2]));

        // Resuming continues from where it stopped:
        expect(await p.loadAll(), equals(100));
        expect(p.finalPage, equals(10));
      },
    );

    test('stream walks every entry', () async {
      var source = _FakeSource(25);
      var p = source.pagination(limit: 10);

      expect(
        _ids(await p.stream().toList()),
        equals([for (var i = 0; i < 25; ++i) i]),
      );
      expect(p.totalLength, equals(25));
    });

    test('stream from a given page', () async {
      var p = _FakeSource(25).pagination(limit: 10);

      expect(
        _ids(await p.stream(fromPage: 3).toList()),
        equals([20, 21, 22, 23, 24]),
      );
    });

    test('stream of an empty result', () async {
      var p = _FakeSource(0).pagination(limit: 10);
      expect(await p.stream().toList(), isEmpty);
    });
  });

  group('EntityPagination: caching and dedupe', () {
    test('a loaded page is not fetched again', () async {
      var source = _FakeSource(100);
      var p = source.pagination(limit: 10);

      await p.loadPage(2);
      await p.loadPage(2);
      await p.getPage(2);
      await p.getAt(15);

      expect(source.fetches, equals([2]));
    });

    test(
      'concurrent requests for the same page share a single fetch',
      () async {
        var source = _FakeSource(100);
        var p = source.pagination(limit: 10);

        // Started together, before any completes:
        var results = await Future.wait([
          Future.value(p.getAt(3)),
          Future.value(p.getAt(7)),
          Future.value(p.loadPage(1)),
        ]);

        expect((results[0] as _Item?)?.id, equals(3));
        expect((results[1] as _Item?)?.id, equals(7));
        expect(
          source.fetches,
          equals([1]),
          reason: 'Page 1 must be fetched once, not 3 times',
        );
      },
    );

    test(
      'a failing page load does not leave a stuck in-flight entry',
      () async {
        var attempts = 0;

        var p = EntityPagination<_Item>(
          limit: 10,
          pageLoader: (page, limit) async {
            ++attempts;
            if (attempts == 1) throw StateError('boom');
            return [_Item(0)];
          },
        );

        await expectLater(p.loadPage(1), throwsA(isA<StateError>()));
        expect(p.isPageLoaded(1), isFalse);

        // Retrying must actually retry, not replay the failed future:
        var entries = await p.loadPage(1);
        expect(_ids(entries), equals([0]));
        expect(attempts, equals(2));
      },
    );
  });

  group('EntityPagination: control', () {
    test('reset drops everything and keeps the query', () async {
      var source = _FakeSource(25);
      var p = source.pagination(limit: 10);

      await p.loadAll();
      expect(p.totalLength, equals(25));

      p.reset();

      expect(p.loadedPages, isEmpty);
      expect(p.loadedEntitiesLength, equals(0));
      expect(p.isFinalPageResolved, isFalse);
      expect(p.totalLength, isNull);
      expect(p.maxLoadedIndex, isNull);

      // Still usable:
      source.fetches.clear();
      expect(_ids((await p.loadNextPage())!).first, equals(0));
      expect(source.fetches, equals([1]));
    });

    test('refresh re-fetches exactly the loaded pages', () async {
      var source = _FakeSource(100);
      var p = source.pagination(limit: 10);

      await p.loadPage(1);
      await p.loadPage(4);
      source.fetches.clear();

      await p.refresh();

      expect(source.fetches..sort(), equals([1, 4]));
      expect(p.loadedPages, equals([1, 4]));
      expect(p.loadedEntitiesLength, equals(20));
    });

    test('refresh on an untouched pagination is a no-op', () async {
      var source = _FakeSource(100);
      var p = source.pagination();

      await p.refresh();
      expect(source.fetches, isEmpty);
    });

    test('refresh discards a resolved end', () async {
      var source = _FakeSource(25);
      var p = source.pagination(limit: 10);

      await p.loadAll();
      expect(p.finalPage, equals(3));

      await p.refresh();

      // Page 3 is short, so reloading it resolves the end again:
      expect(p.finalPage, equals(3));
      expect(p.totalLength, equals(25));
    });
  });

  group('EntityPagination: information', () {
    test('reports the state', () async {
      var p = _FakeSource(25).pagination(limit: 10);

      var before = p.information();
      expect(before['limit'], equals(10));
      expect(before['loadedPages'], isEmpty);
      expect(before['isFinalPageResolved'], isFalse);
      expect(before.containsKey('totalLength'), isFalse);

      await p.loadAll();

      var after = p.information();
      expect(after['loadedPages'], equals([1, 2, 3]));
      expect(after['loadedEntitiesLength'], equals(25));
      expect(after['maxLoadedIndex'], equals(24));
      expect(after['maxKnownPage'], equals(3));
      expect(after['isFinalPageResolved'], isTrue);
      expect(after['finalPage'], equals(3));
      expect(after['totalLength'], equals(25));

      expect(p.information(extended: true)['query'], equals('fake'));
      expect(p.toString(), contains('totalLength: 25'));
    });

    test('toString marks an unresolved total', () {
      var p = _FakeSource(25).pagination();
      expect(p.toString(), contains('<unresolved>'));
    });

    test('isIndexKnownOutOfRange', () async {
      var p = _FakeSource(25).pagination(limit: 10);

      expect(p.isIndexKnownOutOfRange(-1), isTrue);
      expect(
        p.isIndexKnownOutOfRange(1000),
        isFalse,
        reason: 'The end is not known yet',
      );

      await p.loadAll();

      expect(p.isIndexKnownOutOfRange(24), isFalse);
      expect(p.isIndexKnownOutOfRange(25), isTrue);
    });
  });
}

import 'package:async_extension/async_extension.dart';

/// Loads the entries of [page] (1-based) of an [EntityPagination],
/// with at most [limit] entries.
typedef EntityPageLoader<O extends Object> =
    FutureOr<List<O>> Function(int page, int limit);

/// A lazily loaded, paginated view over a select operation.
///
/// It keeps the pages it has already loaded and never fetches implicitly:
/// the synchronous accessors ([operator []], [loadedEntities]) only ever see
/// what is loaded, and only the `FutureOr` methods ([getAt], [getPage],
/// [loadNextPage], [loadAll], [stream]) fetch.
///
/// Pages are **1-based** (matching the `page` parameter of the `select*`
/// methods) and entry indexes are **0-based** (matching a Dart `List`):
/// see [indexOfPage] and [pageOfIndex].
///
/// Pages can be loaded out of order, leaving gaps: `getAt(45)` with a [limit]
/// of 20 loads only page 3, so [loadedPages] is `[3]` while indexes `0..39`
/// stay unloaded.
///
/// ## The total length is not known upfront
///
/// A paginated select doesn't count the matching entries, so [totalLength] is
/// `null` until the final page is identified. Since every page except the last
/// one holds exactly [limit] entries, identifying the final page is enough to
/// compute the total — even when there are gaps:
///
/// ```
/// totalLength == (finalPage - 1) * limit + <entries of finalPage>
/// ```
///
/// See [isFinalPageResolved] for when that happens.
///
/// ## Not a `List`
///
/// This is deliberately not a `List` or an `Iterable`: both require a `length`,
/// which is exactly what a paginated select can't answer until it reaches the
/// end. Use [operator []] for what is loaded, and [loadAll] when a full list is
/// really needed.
///
/// ## Consistency
///
/// Each page is an independent select, without a shared `Transaction`. Entries
/// inserted or deleted between two page loads shift the offsets, so a page
/// loaded later can repeat or skip entries. This is inherent to offset-based
/// pagination; ordering by ID (the default of the `paginate*` methods) makes it
/// as stable as it can be.
class EntityPagination<O extends Object> {
  /// The page size: the maximum number of entries of a page.
  ///
  /// Every page except the final one holds exactly [limit] entries.
  final int limit;

  /// Loads a page. See [EntityPageLoader].
  final EntityPageLoader<O> pageLoader;

  /// An optional description of the paginated query, for [toString].
  final String? query;

  EntityPagination({
    required this.limit,
    required this.pageLoader,
    this.query,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'The page size must be > 0');
    }
  }

  /// The loaded pages, by page number.
  final Map<int, List<O>> _pages = <int, List<O>>{};

  /// The in-flight page loads, so 2 concurrent requests for the same page
  /// share a single fetch.
  final Map<int, Future<List<O>>> _loadingPages = <int, Future<List<O>>>{};

  int? _finalPage;

  /// The lowest page known to be empty.
  ///
  /// An empty page only tells that the final page is *before* it, not which
  /// one it is, so it can't resolve [finalPage] by itself. It is still enough
  /// to avoid fetching that page (or any page after it) again.
  int? _minEmptyPage;

  /// The index of the 1st entry of [page].
  int indexOfPage(int page) => (page - 1) * limit;

  /// The page holding the entry at [index].
  int pageOfIndex(int index) => (index ~/ limit) + 1;

  // ---------------------------------------------------------------------
  // What is loaded:
  // ---------------------------------------------------------------------

  /// Returns `true` if [page] was already loaded (even if it came back empty).
  bool isPageLoaded(int page) => _pages.containsKey(page);

  /// Returns `true` if the entry at [index] is loaded.
  bool isIndexLoaded(int index) => this[index] != null;

  /// The loaded page numbers, ascending. Can have gaps.
  List<int> get loadedPages => _pages.keys.toList()..sort();

  /// The number of loaded pages.
  int get loadedPagesLength => _pages.length;

  /// The highest loaded page, or `null` if nothing was loaded yet.
  ///
  /// Counts a page that came back empty; see [maxKnownPage] for the highest
  /// page known to actually hold entries.
  int? get maxLoadedPage {
    int? max;
    for (var page in _pages.keys) {
      if (max == null || page > max) max = page;
    }
    return max;
  }

  /// The highest entry index that is loaded, or `null` if none is.
  int? get maxLoadedIndex {
    int? max;
    for (var e in _pages.entries) {
      var entries = e.value;
      if (entries.isEmpty) continue;
      var last = indexOfPage(e.key) + entries.length - 1;
      if (max == null || last > max) max = last;
    }
    return max;
  }

  /// The number of loaded entries. Entries in a gap are not counted, so this
  /// can be less than `maxLoadedIndex + 1`.
  int get loadedEntitiesLength =>
      _pages.values.fold(0, (total, entries) => total + entries.length);

  /// The loaded entries, in index order. Gaps are skipped.
  List<O> get loadedEntities => [
    for (var page in loadedPages) ..._pages[page]!,
  ];

  /// The loaded entries of [page], or `null` if it is not loaded.
  List<O>? loadedPageEntities(int page) => _pages[page];

  // ---------------------------------------------------------------------
  // What is known:
  // ---------------------------------------------------------------------

  /// The highest page known to exist: the highest loaded page that came back
  /// with entries. `null` if no page with entries was loaded yet.
  int? get maxKnownPage {
    int? max;
    for (var e in _pages.entries) {
      if (e.value.isEmpty) continue;
      if (max == null || e.key > max) max = e.key;
    }
    return max;
  }

  /// Whether the final page has been identified.
  ///
  /// Resolved when:
  /// - a page comes back with `1..limit-1` entries: it is the final page;
  /// - a page comes back empty and its previous page is loaded and full:
  ///   the previous page is the final one;
  /// - page 1 comes back empty: the select matches nothing.
  ///
  /// A page that comes back empty *without* a loaded, full predecessor does
  /// not resolve it: it only says the final page is somewhere before.
  bool get isFinalPageResolved => _finalPage != null;

  /// The final page, or `null` while unresolved. See [isFinalPageResolved].
  int? get finalPage => _finalPage;

  /// The total number of entries, or `null` while [isFinalPageResolved]
  /// is `false`.
  int? get totalLength {
    var finalPage = _finalPage;
    if (finalPage == null) return null;

    var entries = _pages[finalPage];
    if (entries == null) return null;

    return indexOfPage(finalPage) + entries.length;
  }

  /// Whether the select is known to match no entry at all.
  bool get isKnownEmpty => totalLength == 0;

  /// Whether [index] is known to be out of range.
  ///
  /// Always `false` while [isFinalPageResolved] is `false`, since the end is
  /// not known yet.
  bool isIndexKnownOutOfRange(int index) {
    if (index < 0) return true;
    var total = totalLength;
    return total != null && index >= total;
  }

  // ---------------------------------------------------------------------
  // Synchronous access: never fetches.
  // ---------------------------------------------------------------------

  /// The loaded entry at [index], or `null` if it is not loaded (in a gap, in
  /// a page not loaded yet, or out of range).
  ///
  /// Never fetches: use [getAt] to load on demand, and [isPageLoaded] to tell
  /// "not loaded" from "out of range".
  O? operator [](int index) {
    if (index < 0) return null;

    var page = pageOfIndex(index);
    var entries = _pages[page];
    if (entries == null) return null;

    var offset = index - indexOfPage(page);
    if (offset < 0 || offset >= entries.length) return null;

    return entries[offset];
  }

  // ---------------------------------------------------------------------
  // Asynchronous access: loads what it needs.
  // ---------------------------------------------------------------------

  /// The entry at [index], loading its page if needed.
  /// Returns `null` if [index] is out of range.
  FutureOr<O?> getAt(int index) {
    if (index < 0) return null;

    var cached = this[index];
    if (cached != null) return cached;

    var page = pageOfIndex(index);
    // Loaded, but shorter than `index`: out of range.
    if (isPageLoaded(page)) return null;

    return loadPage(page).resolveMapped((_) => this[index]);
  }

  /// The entries of [page], loading it if needed.
  FutureOr<List<O>> getPage(int page) => loadPage(page);

  /// The entries from [startIndex] (inclusive) to [endIndex] (exclusive),
  /// loading every page spanning the range, including pages inside a gap.
  FutureOr<List<O>> getRange(int startIndex, int endIndex) {
    if (startIndex < 0) {
      throw ArgumentError.value(startIndex, 'startIndex', 'Must be >= 0');
    }

    if (endIndex <= startIndex) return <O>[];

    var firstPage = pageOfIndex(startIndex);
    var lastPage = pageOfIndex(endIndex - 1);

    var loads = [
      for (var page = firstPage; page <= lastPage; ++page) loadPage(page),
    ];

    return loads.resolveAll().resolveMapped((_) {
      var range = <O>[];
      for (var i = startIndex; i < endIndex; ++i) {
        var o = this[i];
        if (o != null) range.add(o);
      }
      return range;
    });
  }

  /// Loads [page] (1-based), or returns it if already loaded.
  ///
  /// Concurrent calls for the same page share a single fetch.
  FutureOr<List<O>> loadPage(int page) {
    if (page < 1) {
      throw ArgumentError.value(
        page,
        'page',
        'Pages are 1-based, must be >= 1',
      );
    }

    var loaded = _pages[page];
    if (loaded != null) return loaded;

    // Already known to be past the end, no need to fetch:
    if (_isPageKnownEmpty(page)) return <O>[];

    var loading = _loadingPages[page];
    if (loading != null) return loading;

    var ret = pageLoader(page, limit);

    if (ret is! Future<List<O>>) {
      _setPage(page, ret);
      return _pages[page]!;
    }

    var future = ret
        .then((entries) {
          _loadingPages.remove(page);
          _setPage(page, entries);
          return _pages[page]!;
        })
        .onError<Object>((e, s) {
          _loadingPages.remove(page);
          throw e;
        });

    _loadingPages[page] = future;
    return future;
  }

  bool _isPageKnownEmpty(int page) {
    var finalPage = _finalPage;
    if (finalPage != null && page > finalPage) return true;

    var minEmptyPage = _minEmptyPage;
    return minEmptyPage != null && page >= minEmptyPage;
  }

  /// Loads the page after [maxLoadedPage] (or page 1 when nothing is loaded).
  ///
  /// Returns `null` when there is nothing more to load.
  FutureOr<List<O>?> loadNextPage() {
    var next = (maxLoadedPage ?? 0) + 1;

    if (_isPageKnownEmpty(next)) return null;

    return loadPage(
      next,
    ).resolveMapped((entries) => entries.isEmpty ? null : entries);
  }

  /// Loads every page from page 1 until the end, so that afterwards
  /// [loadedEntities] holds the complete result with no gap.
  ///
  /// Pages already loaded are skipped without re-fetching (and without
  /// counting against [maxPages]), so this also fills the gaps left by a
  /// sparse [getAt].
  ///
  /// Returns [totalLength], which is `null` if [maxPages] stopped it before
  /// the end was reached.
  FutureOr<int?> loadAll({int? maxPages}) => _loadAllImpl(maxPages, 0, 1);

  FutureOr<int?> _loadAllImpl(int? maxPages, int fetchCount, int page) {
    // Skip what is already loaded: no fetch, no budget spent.
    while (isPageLoaded(page)) {
      var finalPage = _finalPage;
      if (finalPage != null && page >= finalPage) return totalLength;
      ++page;
    }

    var finalPage = _finalPage;
    if (finalPage != null && page > finalPage) return totalLength;

    if (_isPageKnownEmpty(page)) return totalLength;

    if (maxPages != null && fetchCount >= maxPages) return totalLength;

    return loadPage(page).resolveMapped((entries) {
      if (entries.isEmpty) return totalLength;
      return _loadAllImpl(maxPages, fetchCount + 1, page + 1);
    });
  }

  /// Streams the entries from [fromPage], loading the pages as it goes.
  Stream<O> stream({int fromPage = 1}) async* {
    var page = fromPage;

    while (true) {
      var entries = await loadPage(page);
      if (entries.isEmpty) break;

      for (var o in entries) {
        yield o;
      }

      var finalPage = _finalPage;
      if (finalPage != null && page >= finalPage) break;

      ++page;
    }
  }

  // ---------------------------------------------------------------------
  // Control:
  // ---------------------------------------------------------------------

  void _setPage(int page, List<O> entries) {
    var list = List<O>.unmodifiable(entries);
    _pages[page] = list;
    _resolveFinalPage(page, list);
  }

  void _resolveFinalPage(int page, List<O> entries) {
    if (_finalPage != null) return;

    if (entries.isEmpty) {
      var minEmptyPage = _minEmptyPage;
      if (minEmptyPage == null || page < minEmptyPage) {
        _minEmptyPage = page;
      }

      // Nothing at all:
      if (page == 1) {
        _finalPage = 1;
        return;
      }
    } else if (entries.length < limit) {
      // A short page can only be the last one:
      _finalPage = page;
      return;
    }

    // An empty page whose previous page is loaded and full pins the end:
    var minEmptyPage = _minEmptyPage;
    if (minEmptyPage != null && minEmptyPage > 1) {
      var previous = _pages[minEmptyPage - 1];
      if (previous != null && previous.length == limit) {
        _finalPage = minEmptyPage - 1;
      }
    }
  }

  /// Discards every loaded page and everything known about the end,
  /// keeping the query.
  void reset() {
    _pages.clear();
    _loadingPages.clear();
    _finalPage = null;
    _minEmptyPage = null;
  }

  /// Re-fetches the currently loaded pages, discarding what was known about
  /// the end (it may have moved).
  FutureOr<void> refresh() {
    var pages = loadedPages;
    reset();

    if (pages.isEmpty) return null;

    return pages
        .map((page) => loadPage(page))
        .resolveAll()
        .resolveMapped((_) => null);
  }

  Map<String, dynamic> information({bool extended = false}) => {
    'limit': limit,
    'loadedPages': loadedPages,
    'loadedPagesLength': loadedPagesLength,
    'loadedEntitiesLength': loadedEntitiesLength,
    if (maxLoadedPage != null) 'maxLoadedPage': maxLoadedPage,
    if (maxLoadedIndex != null) 'maxLoadedIndex': maxLoadedIndex,
    if (maxKnownPage != null) 'maxKnownPage': maxKnownPage,
    'isFinalPageResolved': isFinalPageResolved,
    if (finalPage != null) 'finalPage': finalPage,
    if (totalLength != null) 'totalLength': totalLength,
    if (extended && query != null) 'query': query,
  };

  @override
  String toString() {
    var total = totalLength;
    return 'EntityPagination<$O>{'
        'limit: $limit, '
        'loadedPages: ${loadedPages.length}, '
        'loadedEntities: $loadedEntitiesLength, '
        'maxLoadedIndex: $maxLoadedIndex, '
        'maxKnownPage: $maxKnownPage, '
        '${total != null ? 'totalLength: $total' : 'totalLength: <unresolved>'}'
        '${query != null ? ' ; query: $query' : ''}'
        '}';
  }
}

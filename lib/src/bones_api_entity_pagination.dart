import 'package:async_extension/async_extension.dart';

/// Loads the entries of [page] (1-based) of an [EntityPagination],
/// with at most [limit] entries.
typedef EntityPageLoader<O extends Object> =
    FutureOr<List<O>> Function(int page, int limit);

/// Notified of what an [EntityPagination] is fetching.
/// See [EntityPagination.onEvent] and [EntityPaginationEvent].
typedef EntityPaginationListener<O extends Object> =
    void Function(EntityPaginationEvent<O> event);

/// An event of an [EntityPagination]. See [EntityPagination.onEvent].
///
/// Delivered **synchronously**, at the point where it happens and in order, so
/// it is also correct for a synchronous [EntityPageLoader]. To consume it as a
/// `Stream` instead, forward it: `onEvent: myEventStream.add`.
///
/// Every event but [EntityPaginationReset] refers to a page, and is an
/// [EntityPaginationPageEvent]. Switch over it exhaustively:
///
/// ```dart
/// switch (event) {
///   case EntityPaginationPageLoading(:var page):
///     print('fetching page $page...');
///   case EntityPaginationPageLoaded(:var page, :var entries):
///     print('page $page: ${entries.length} entries');
///   case EntityPaginationPageError(:var page, :var error):
///     print('page $page failed: $error');
///   case EntityPaginationPageSkipped(:var page, :var reason):
///     print('page $page not fetched: ${reason.name}');
///   case EntityPaginationEnd(:var totalLength):
///     print('done: $totalLength entries');
///   case EntityPaginationReset(:var discardedPages):
///     print('discarded ${discardedPages.length} pages');
/// }
/// ```
sealed class EntityPaginationEvent<O extends Object> {
  /// The [EntityPagination] that emitted this event.
  final EntityPagination<O> pagination;

  EntityPaginationEvent(this.pagination);

  /// The page size. Same as `pagination.limit`.
  int get limit => pagination.limit;
}

/// An [EntityPaginationEvent] about a specific [page].
///
/// Everything but [EntityPaginationReset], which is about the whole
/// pagination.
sealed class EntityPaginationPageEvent<O extends Object>
    extends EntityPaginationEvent<O> {
  /// The page (1-based) this event refers to.
  final int page;

  EntityPaginationPageEvent(super.pagination, this.page);
}

/// A page fetch is about to start: [EntityPagination.pageLoader] is called
/// immediately after this event.
///
/// Emitted once per *actual* fetch. A page that is already loaded, already
/// in-flight, or known to be past the end emits an
/// [EntityPaginationPageSkipped] instead.
final class EntityPaginationPageLoading<O extends Object>
    extends EntityPaginationPageEvent<O> {
  EntityPaginationPageLoading(super.pagination, super.page);

  @override
  String toString() => 'EntityPaginationPageLoading{page: $page}';
}

/// A page fetch finished. Always preceded by an
/// [EntityPaginationPageLoading] for the same [page].
final class EntityPaginationPageLoaded<O extends Object>
    extends EntityPaginationPageEvent<O> {
  /// The loaded entries (unmodifiable).
  final List<O> entries;

  /// How long [EntityPagination.pageLoader] took.
  final Duration elapsedTime;

  EntityPaginationPageLoaded(
    super.pagination,
    super.page,
    this.entries,
    this.elapsedTime,
  );

  /// The number of loaded entries. A value below [limit] means this is the
  /// last page.
  int get entriesLength => entries.length;

  /// Whether this page turned out to be the final one.
  bool get isFinalPage => pagination.finalPage == page;

  @override
  String toString() =>
      'EntityPaginationPageLoaded{page: $page, '
      'entries: ${entries.length}, elapsedTime: $elapsedTime}';
}

/// A page fetch failed. The error is rethrown to the caller right after this
/// event, and the failed page is evicted so a retry actually retries.
final class EntityPaginationPageError<O extends Object>
    extends EntityPaginationPageEvent<O> {
  /// The error thrown by [EntityPagination.pageLoader].
  final Object error;

  /// The stack trace of [error].
  final StackTrace stackTrace;

  /// How long the failed fetch took.
  final Duration elapsedTime;

  EntityPaginationPageError(
    super.pagination,
    super.page,
    this.error,
    this.stackTrace,
    this.elapsedTime,
  );

  @override
  String toString() => 'EntityPaginationPageError{page: $page, error: $error}';
}

/// Why a page was served without calling [EntityPagination.pageLoader].
/// See [EntityPaginationPageSkipped].
enum EntityPaginationSkipReason {
  /// The page was already loaded, and was served from [EntityPagination].
  alreadyLoaded,

  /// A fetch of the same page was already in-flight, and is shared with it.
  inFlight,

  /// The page is known to be past the end, so it can only be empty.
  knownEmpty,
}

/// A page was served without a fetch. See [EntityPaginationSkipReason].
///
/// Not an error: it is what makes a repeated read, a concurrent read and a
/// read past the end free. Ignore it to only observe real fetches.
final class EntityPaginationPageSkipped<O extends Object>
    extends EntityPaginationPageEvent<O> {
  /// Why the page was not fetched.
  final EntityPaginationSkipReason reason;

  EntityPaginationPageSkipped(super.pagination, super.page, this.reason);

  @override
  String toString() =>
      'EntityPaginationPageSkipped{page: $page, reason: ${reason.name}}';
}

/// The end of the result was resolved: [EntityPagination.finalPage] and
/// [EntityPagination.totalLength] are now known.
///
/// Emitted once, immediately after the [EntityPaginationPageLoaded] that
/// resolved it — which is not necessarily the final page itself, since an
/// empty page can pin the end at its predecessor.
/// See [EntityPagination.isFinalPageResolved].
final class EntityPaginationEnd<O extends Object>
    extends EntityPaginationPageEvent<O> {
  /// The total number of entries.
  final int totalLength;

  /// The final page. Same as [page].
  int get finalPage => page;

  EntityPaginationEnd(super.pagination, super.page, this.totalLength);

  /// Whether the select matched no entry at all.
  bool get isEmpty => totalLength == 0;

  @override
  String toString() =>
      'EntityPaginationEnd{finalPage: $page, totalLength: $totalLength}';
}

/// Every loaded page was discarded by [EntityPagination.reset] or
/// [EntityPagination.refresh], and everything known about the end with them.
///
/// Emitted *after* the state is cleared, so the [pagination] already reads as
/// empty. The discarded state is on the event itself.
///
/// The only event that is not an [EntityPaginationPageEvent]: it is about the
/// whole pagination.
final class EntityPaginationReset<O extends Object>
    extends EntityPaginationEvent<O> {
  /// The pages that were loaded before the reset, ascending.
  final List<int> discardedPages;

  /// The number of entries that were loaded before the reset.
  final int discardedEntitiesLength;

  /// Whether this is the reset of an [EntityPagination.refresh], which
  /// re-fetches [discardedPages] right after — so a consumer can tell an
  /// in-progress refresh from a pagination that was simply emptied.
  final bool isRefresh;

  EntityPaginationReset(
    super.pagination,
    this.discardedPages,
    this.discardedEntitiesLength,
    this.isRefresh,
  );

  /// Whether there was nothing to discard.
  bool get isEmpty => discardedPages.isEmpty;

  @override
  String toString() =>
      'EntityPaginationReset{discardedPages: ${discardedPages.length}, '
      'discardedEntities: $discardedEntitiesLength, isRefresh: $isRefresh}';
}

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

  /// An optional hook notified of what is being fetched, or `null` (the
  /// default) to notify nothing. See [EntityPaginationEvent].
  ///
  /// Called **synchronously** at the point where the event happens, so the
  /// order is meaningful even for a synchronous [pageLoader]. Not `final`, so
  /// it can also be attached to an already built [EntityPagination] — only
  /// events emitted afterwards are seen.
  ///
  /// An exception thrown by the listener is reported to the current [Zone] and
  /// does not break the fetch.
  EntityPaginationListener<O>? onEvent;

  EntityPagination({
    required this.limit,
    required this.pageLoader,
    this.query,
    this.onEvent,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'The page size must be > 0');
    }
  }

  /// Notifies [onEvent], isolating it: a broken listener must not break a
  /// fetch, but must not be silently swallowed either.
  void _notify(EntityPaginationEvent<O> event) {
    var onEvent = this.onEvent;
    if (onEvent == null) return;

    try {
      onEvent(event);
    } catch (e, s) {
      Zone.current.handleUncaughtError(e, s);
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
    if (loaded != null) {
      _notifySkipped(page, EntityPaginationSkipReason.alreadyLoaded);
      return loaded;
    }

    // Already known to be past the end, no need to fetch:
    if (_isPageKnownEmpty(page)) {
      _notifySkipped(page, EntityPaginationSkipReason.knownEmpty);
      return <O>[];
    }

    var loading = _loadingPages[page];
    if (loading != null) {
      _notifySkipped(page, EntityPaginationSkipReason.inFlight);
      return loading;
    }

    _notify(EntityPaginationPageLoading<O>(this, page));

    // Only timed while there is a listener to receive it:
    var stopwatch = onEvent != null ? (Stopwatch()..start()) : null;

    var ret = pageLoader(page, limit);

    if (ret is! Future<List<O>>) {
      var elapsedTime = stopwatch?.elapsed ?? Duration.zero;
      var resolvedEnd = _setPage(page, ret);
      var entries = _pages[page]!;

      _notifyLoaded(page, entries, elapsedTime, resolvedEnd);

      return entries;
    }

    var future = ret
        .then((pageEntries) {
          var elapsedTime = stopwatch?.elapsed ?? Duration.zero;
          _loadingPages.remove(page);
          var resolvedEnd = _setPage(page, pageEntries);
          var entries = _pages[page]!;

          _notifyLoaded(page, entries, elapsedTime, resolvedEnd);

          return entries;
        })
        .onError<Object>((e, s) {
          var elapsedTime = stopwatch?.elapsed ?? Duration.zero;
          _loadingPages.remove(page);

          _notify(EntityPaginationPageError<O>(this, page, e, s, elapsedTime));

          throw e;
        });

    _loadingPages[page] = future;
    return future;
  }

  void _notifySkipped(int page, EntityPaginationSkipReason reason) {
    if (onEvent == null) return;
    _notify(EntityPaginationPageSkipped<O>(this, page, reason));
  }

  /// Notifies the loaded page, then the end of the result when this page
  /// resolved it (in that order).
  void _notifyLoaded(
    int page,
    List<O> entries,
    Duration elapsedTime,
    bool resolvedEnd,
  ) {
    if (onEvent == null) return;

    _notify(EntityPaginationPageLoaded<O>(this, page, entries, elapsedTime));

    if (resolvedEnd) {
      var finalPage = _finalPage;
      var totalLength = this.totalLength;

      if (finalPage != null && totalLength != null) {
        _notify(EntityPaginationEnd<O>(this, finalPage, totalLength));
      }
    }
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

  /// Stores the entries of [page], and returns `true` if this call resolved
  /// [finalPage] (so that [EntityPaginationEnd] is emitted exactly once, and
  /// after the [EntityPaginationPageLoaded] that caused it).
  bool _setPage(int page, List<O> entries) {
    var list = List<O>.unmodifiable(entries);
    _pages[page] = list;

    var wasResolved = _finalPage != null;
    _resolveFinalPage(page, list);

    return !wasResolved && _finalPage != null;
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
  ///
  /// Notifies an [EntityPaginationReset].
  void reset() => _resetImpl(isRefresh: false);

  void _resetImpl({required bool isRefresh}) {
    // Captured before clearing: the event reports what was discarded, while
    // the pagination itself already reads as empty.
    var discardedPages = onEvent != null ? loadedPages : const <int>[];
    var discardedEntitiesLength = onEvent != null ? loadedEntitiesLength : 0;

    _pages.clear();
    _loadingPages.clear();
    _finalPage = null;
    _minEmptyPage = null;

    if (onEvent != null) {
      _notify(
        EntityPaginationReset<O>(
          this,
          discardedPages,
          discardedEntitiesLength,
          isRefresh,
        ),
      );
    }
  }

  /// Re-fetches the currently loaded pages, discarding what was known about
  /// the end (it may have moved).
  ///
  /// Notifies an [EntityPaginationReset] with `isRefresh: true`, then the
  /// events of the re-fetched pages.
  FutureOr<void> refresh() {
    var pages = loadedPages;
    _resetImpl(isRefresh: true);

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

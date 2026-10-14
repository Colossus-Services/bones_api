import 'dart:collection';

/// The prepared statements counters of a `DBSQLAdapter` (all of its
/// connections): see `DBSQLAdapter.preparedStatementsInfo`.
class PreparedStatementsInfo {
  /// The statements run with a prepared statement from a cache.
  int hits = 0;

  /// The statements prepared (and cached).
  int prepared = 0;

  /// The prepared statements evicted from a cache (the least recently used,
  /// over its size) and released.
  int evicted = 0;

  /// The cached statements that failed as stale (e.g. a schema change
  /// changed their result columns) and were evicted.
  int stale = 0;

  @override
  String toString() =>
      'PreparedStatementsInfo{hits: $hits, prepared: $prepared, '
      'evicted: $evicted, stale: $stale}';
}

/// A cache of prepared statements [S] by SQL text, of one connection (or one
/// database handle): the least recently used one is evicted (and released
/// by [onEvict]) when it's over [maxSize].
///
/// A SQL text is prepared at its [prepareOnSighting]th use ([shouldPrepare]):
/// `1` prepares it the first time, `2` only when it repeats (when preparing
/// costs a round trip, a statement run once doesn't pay it).
class PreparedStatementsCache<S extends Object> {
  /// The maximum number of cached statements.
  final int maxSize;

  /// The use of a SQL text at which it's prepared (`>= 1`).
  final int prepareOnSighting;

  /// Releases an evicted (or cleared) statement.
  final void Function(S statement) onEvict;

  /// The counters (shared by the caches of an adapter).
  final PreparedStatementsInfo info;

  PreparedStatementsCache({
    required this.maxSize,
    required this.onEvict,
    this.prepareOnSighting = 1,
    PreparedStatementsInfo? info,
  }) : info = info ?? PreparedStatementsInfo() {
    checkMaxSize(maxSize);
    if (prepareOnSighting < 1) {
      throw ArgumentError.value(
        prepareOnSighting,
        'prepareOnSighting',
        'must be >= 1',
      );
    }
  }

  /// Throws an [ArgumentError] if [maxSize] is not a valid [maxSize] (`>= 1`):
  /// for an adapter to reject it when constructed, before opening a
  /// connection for its cache.
  static void checkMaxSize(int maxSize, [String name = 'maxSize']) {
    if (maxSize < 1) {
      throw ArgumentError.value(maxSize, name, 'must be >= 1');
    }
  }

  // Insertion ordered: the first entries are the least recently used.
  final LinkedHashMap<String, S> _statements = LinkedHashMap();

  // The SQL texts seen but not prepared yet, and how many times.
  final LinkedHashMap<String, int> _sightings = LinkedHashMap();

  /// The number of cached statements.
  int get length => _statements.length;

  /// Whether [sql] has a cached statement.
  bool contains(String sql) => _statements.containsKey(sql);

  /// The cached statement of [sql] (marked as the most recently used), or
  /// `null`.
  S? get(String sql) {
    var statement = _statements.remove(sql);
    if (statement == null) return null;
    _statements[sql] = statement;
    ++info.hits;
    return statement;
  }

  /// Whether [sql] (not cached) should be prepared now: counts its use, and
  /// returns `true` at its [prepareOnSighting]th one.
  bool shouldPrepare(String sql) {
    if (prepareOnSighting <= 1) return true;

    var count = (_sightings.remove(sql) ?? 0) + 1;
    if (count >= prepareOnSighting) return true;

    _sightings[sql] = count;

    // Bounded: the oldest sightings are forgotten.
    var maxSightings = maxSize * 4;
    while (_sightings.length > maxSightings) {
      _sightings.remove(_sightings.keys.first);
    }

    return false;
  }

  /// Caches [statement] of [sql], evicting the least recently used ones
  /// over [maxSize].
  void put(String sql, S statement) {
    var previous = _statements.remove(sql);
    if (previous != null && !identical(previous, statement)) {
      onEvict(previous);
    }

    _statements[sql] = statement;
    ++info.prepared;

    while (_statements.length > maxSize) {
      var oldest = _statements.keys.first;
      var evicted = _statements.remove(oldest)!;
      ++info.evicted;
      onEvict(evicted);
    }
  }

  /// Removes (and releases) the statement of [sql], when it's stale.
  void removeStale(String sql) {
    var statement = _statements.remove(sql);
    if (statement != null) {
      ++info.stale;
      onEvict(statement);
    }
  }

  /// Removes (and releases) all the statements.
  void clear() {
    var statements = _statements.values.toList();
    _statements.clear();
    _sightings.clear();
    for (var s in statements) {
      onEvict(s);
    }
  }
}

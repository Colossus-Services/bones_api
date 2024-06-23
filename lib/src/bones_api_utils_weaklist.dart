import 'dart:collection';

/// A [List] that stores elements using [WeakReference].
class WeakList<E extends Object> extends ListBase<E?> {
  /// If `true` [autoPurge] will automatically call [purge] before a list operation.
  final bool allowAutoPurge;

  /// The interval that [purge] will force a full check of the entries.
  final Duration purgeInterval;

  WeakList(
      {bool autoPurge = true, this.purgeInterval = const Duration(seconds: 30)})
      : allowAutoPurge = autoPurge;

  final List<WeakReference<E>> _entries = <WeakReference<E>>[];

  int _modCount = 0;

  int _purgeModCount = 0;

  DateTime _purgeTime = DateTime.now();

  /// The time of the last [purge] check.
  DateTime get lastPurgeTime => _purgeTime;

  /// Removes lost references.
  /// - If any [WeakReference] is not pointing to its target it will reduce
  ///   the [length] of this list.
  /// - If [force] is `true` will force a full check of entries. IF `false` will
  ///   only check entries if there's a new operation in the list.
  /// - Returns `true` if a full check of entries was performed.
  bool purge({bool force = false}) {
    var now = DateTime.now();

    if (_purgeModCount == _modCount && !force) {
      var purgeElapsedTime = now.difference(_purgeTime);

      if (purgeElapsedTime < purgeInterval) {
        return false;
      }
    }

    for (var i = 0; i < _entries.length;) {
      var weakRef = _entries[i];

      if (weakRef.target == null) {
        _entries.removeAt(i);
      } else {
        ++i;
      }
    }

    ++_modCount;

    _purgeModCount = _modCount;

    _purgeTime = now;

    return true;
  }

  /// Automatically calls [purge].
  void autoPurge() {
    if (allowAutoPurge) {
      purge();
    }
  }

  @override
  int get length {
    autoPurge();
    return _entries.length;
  }

  @override
  void add(E? element) {
    if (element == null) return;

    autoPurge();
    _entries.add(WeakReference(element));
    ++_modCount;
  }

  E? get(int index) {
    autoPurge();
    var weakRef = _entries[index];
    return weakRef.target;
  }

  E? set(int index, E? value) {
    autoPurge();

    var prevWeakRef = _entries[index];

    if (value == null) {
      _entries.removeAt(index);
    } else {
      _entries[index] = WeakReference(value);
    }

    return prevWeakRef.target;
  }

  @override
  E? operator [](int index) => get(index);

  @override
  void operator []=(int index, E? value) => set(index, value);

  @override
  set length(int newLength) {
    autoPurge();

    if (newLength < _entries.length) {
      _entries.length = newLength;
    }
  }

  @override
  void clear() {
    _entries.clear();
    _modCount = 0;
    _purgeModCount = 0;
    _purgeTime = DateTime.now();
  }

  @override
  bool contains(Object? element) {
    var match = _entries.any((weakRef) => element == weakRef.target);
    autoPurge();
    return match;
  }

  @override
  Iterator<E?> get iterator {
    autoPurge();
    return super.iterator;
  }

  @override
  bool remove(Object? element) {
    if (element == null) return false;

    var idx = _entries.indexWhere((weakRef) => element == weakRef.target);
    if (idx < 0) {
      autoPurge();
      return false;
    }

    var weakRef = _entries.removeAt(idx);
    assert(element == weakRef.target);

    ++_modCount;
    autoPurge();

    return true;
  }

  @override
  E? removeAt(int index) {
    var rm = _entries.removeAt(index);
    ++_modCount;
    autoPurge();
    return rm.target;
  }

  @override
  void removeWhere(bool Function(E? element) test) {
    var lng = _entries.length;
    _entries.removeWhere((weakRef) => test(weakRef.target));
    var modified = lng != _entries.length;
    if (modified) {
      ++_modCount;
    }
    autoPurge();
  }

  @override
  List<E> toList({bool growable = true}) {
    autoPurge();

    return _entries.map((e) => e.target).nonNulls.toList(growable: growable);
  }
}

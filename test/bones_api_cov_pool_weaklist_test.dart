@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:bones_api/src/bones_api_mixin.dart';
import 'package:test/test.dart';

class _Element with Closable {
  final int id;

  _Element(this.id);

  bool valid = true;

  @override
  String toString() => '_Element#$id';
}

class _TestPool with Pool<_Element> {
  final int limit;

  /// If `true` [isPoolElementValid] returns a `Future`.
  bool asyncValid;

  /// If `true` won't create elements if not forced.
  bool refuseNonForced;

  /// If `true` won't create elements (even if forced).
  bool neverCreate;

  /// If `true` won't create elements, if not forced, when [limit] is reached.
  bool respectLimit;

  _TestPool(
    this.limit, {
    this.asyncValid = false,
    this.refuseNonForced = false,
    this.neverCreate = false,
    this.respectLimit = false,
  });

  int _idCount = 0;

  final List<_Element> closed = [];

  @override
  Duration get poolYieldTimeout => const Duration(milliseconds: 10);

  @override
  Duration get poolFullYieldTimeout => const Duration(milliseconds: 10);

  @override
  Duration get poolFullWaitTimeout => const Duration(milliseconds: 10);

  @override
  FutureOr<_Element?> createPoolElement({bool force = false}) {
    if (neverCreate) return null;
    if (!force && refuseNonForced) return null;
    if (!force && respectLimit && poolAliveElementsSize >= limit) return null;

    super.createPoolElement(force: force);
    return _Element(++_idCount);
  }

  @override
  FutureOr<bool> isPoolElementValid(_Element o, {bool checkUsage = true}) {
    var valid = o.valid && !o.isClosed;
    return asyncValid ? Future.value(valid) : valid;
  }

  @override
  FutureOr<bool> closePoolElement(_Element o) {
    closed.add(o);
    o.close();
    return super.closePoolElement(o);
  }

  @override
  int get poolSizeDesiredLimit => limit;
}

class _DefaultPool with Pool<_Element> {
  @override
  FutureOr<bool> isPoolElementValid(_Element o, {bool checkUsage = true}) =>
      true;

  @override
  int get poolSizeDesiredLimit => 1;
}

class _Fields with FieldsFromMap {}

void main() {
  group('Closable', () {
    test('close / checkNotClosed', () async {
      var e = _Element(1);
      expect(e.isClosed, isFalse);
      e.checkNotClosed();

      expect(await e.close(), isTrue);
      expect(e.isClosed, isTrue);
      expect(await e.close(), isFalse);

      expect(
        () => e.checkNotClosed(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Closed: _Element#1'),
          ),
        ),
      );
    });
  });

  group('PoolError', () {
    test('toString', () {
      expect(PoolTimeoutError('t1').toString(), equals('PoolTimeoutError: t1'));
      expect(PoolFullError('f1').toString(), equals('PoolFullError: f1'));
      expect(PoolFullError('f2').message, equals('f2'));
    });
  });

  group('Pool', () {
    Future<List<_Element>> fill(_TestPool pool, int n) async {
      var l = <_Element>[];
      for (var i = 0; i < n; ++i) {
        l.add(await pool.createPoolElementForced());
      }
      for (var e in l) {
        await pool.releaseIntoPool(e);
      }
      return l;
    }

    test('elements, filters and removal', () async {
      var pool = _TestPool(10);
      var l = await fill(pool, 4);

      expect(pool.poolSize, equals(4));
      expect(pool.poolElements.toList(), equals(l));
      expect(pool.poolCreatedElementsCount, equals(4));

      l[1].valid = false;

      expect(await pool.validPoolElements(), equals([l[0], l[2], l[3]]));
      expect(await pool.invalidPoolElements(), equals([l[1]]));

      pool.asyncValid = true;
      expect(await pool.validPoolElements(), equals([l[0], l[2], l[3]]));
      expect(await pool.invalidPoolElements(), equals([l[1]]));
      expect(
        await pool.filterPoolElements((o) => Future.value(o.id.isEven)),
        equals([l[1], l[3]]),
      );

      expect(pool.removeElementsFromPool(2), equals(2));
      expect(pool.poolSize, equals(2));
      expect(pool.closed, equals([l[0], l[1]]));
      expect(pool.removeElementsFromPool(10), equals(2));
      expect(pool.poolSize, equals(0));
      expect(pool.removeElementsFromPool(1), equals(0));

      expect(pool.peekFromPool(), isNull);
      expect(pool.catchFromPopulatedPool(), isNull);
    });

    test('default timeouts', () {
      var pool = _DefaultPool();
      expect(pool.poolYieldTimeout, equals(Duration(milliseconds: 200)));
      expect(pool.poolFullYieldTimeout, equals(Duration(milliseconds: 120)));
      expect(pool.poolFullWaitTimeout, equals(Duration(milliseconds: 240)));
      expect(pool.createPoolElement(), isNull);
      expect(pool.poolCreatedElementsCount, equals(1));
    });

    test('createPoolElementForced: PoolFullError', () {
      var pool = _TestPool(1, neverCreate: true);
      expect(
        () => pool.createPoolElementForced(),
        throwsA(isA<PoolFullError>()),
      );
    });

    test('peek / catchFromPopulatedPool', () async {
      var pool = _TestPool(10);
      var l = await fill(pool, 2);

      expect(await pool.peekFromPool(), same(l[1]));
      expect(await pool.catchFromPopulatedPool(), same(l[0]));
      expect(pool.poolSize, equals(0));
    });

    for (var asyncValid in [false, true]) {
      test('catch with invalid elements (asyncValid: $asyncValid)', () async {
        var pool = _TestPool(10, asyncValid: asyncValid);
        var l = await fill(pool, 3);

        // The last 2 elements are invalid:
        l[2].valid = false;
        l[1].valid = false;

        // `_catchFromPopulatedPool` -> invalid -> `_catchFromPopulatedPool2` -> invalid -> null
        // -> `createPoolElementForced`
        var e1 = await pool.catchFromPool();
        expect(e1.id, equals(4));
        expect(pool.poolSize, equals(1));

        // `_catchFromPopulatedPool` -> invalid -> `_catchFromPopulatedPool2` -> valid
        var pool2 = _TestPool(10, asyncValid: asyncValid);
        var l2 = await fill(pool2, 2);
        l2[1].valid = false;
        var e2 = await pool2.catchFromPool();
        expect(e2, same(l2[0]));

        // Peek with only invalid elements:
        var pool3 = _TestPool(10, asyncValid: asyncValid);
        var l3 = await fill(pool3, 1);
        l3[0].valid = false;
        expect(await pool3.peekFromPool(), isNull);
        expect(pool3.poolSize, equals(0));

        // Only valid elements:
        var pool4 = _TestPool(10, asyncValid: asyncValid);
        var l4 = await fill(pool4, 1);
        expect(await pool4.catchFromPool(), same(l4[0]));
      });
    }

    test('catch from full pool: forced after waiting', () async {
      var pool = _TestPool(1, respectLimit: true);

      var e1 = await pool.catchFromPool();
      expect(e1.id, equals(1));
      expect(pool.poolAliveElementsSize, equals(1));

      // Pool full: yield timeout -> forced wait -> `_waitElementInPool` -> forced
      var e2 = await pool.catchFromPool();
      expect(e2.id, equals(2));
      expect(pool.poolAliveElementsSize, equals(2));

      // Release both and catch again (a pending `_waitingPoolElement` is
      // completed by `_catchFromPopulatedPool`):
      await pool.releaseIntoPool(e1);
      await pool.releaseIntoPool(e2);
      expect(pool.poolSize, equals(2));

      var e3 = await pool.catchFromPool();
      expect(e3, same(e2));
    });

    test('catch from full pool: released while waiting', () async {
      var pool = _TestPool(1, respectLimit: true);

      var e1 = await pool.catchFromPool();

      var f = pool.catchFromPool();
      await Future.delayed(const Duration(milliseconds: 2));
      await pool.releaseIntoPool(e1);

      var e2 = await f;
      expect(e2, same(e1));
      expect(pool.poolCreatedElementsCount, equals(1));
    });

    test('catch from full pool: timeout', () async {
      var pool = _TestPool(1, respectLimit: true);

      await pool.catchFromPool();

      await expectLater(
        () async =>
            await pool.catchFromPool(timeout: const Duration(milliseconds: 1)),
        throwsA(isA<PoolTimeoutError>()),
      );

      // Let pending internal waits finish:
      await Future.delayed(const Duration(milliseconds: 80));
    });

    test('catch with waiting element (not forced creation refused)', () async {
      var pool = _TestPool(5, refuseNonForced: true);

      var f = pool.catchFromPool();

      await Future.delayed(const Duration(milliseconds: 2));

      var e = await pool.createPoolElementForced();
      await pool.releaseIntoPool(e);

      var caught = await f;
      expect(caught, same(e));
    });

    test('checkPoolSize', () async {
      var pool = _TestPool(10);
      var l = await fill(pool, 5);

      // poolSize <= minSize:
      expect(await pool.checkPoolSize(5, 10, 1000000), isTrue);
      l[0].valid = false;
      expect(await pool.checkPoolSize(5, 10, -1), isTrue);
      expect(pool.poolSize, equals(4));

      // poolSize > maxSize:
      expect(await pool.checkPoolSize(1, 2, 1000000), isTrue);
      expect(pool.poolSize, equals(2));

      // Between min and max:
      var pool2 = _TestPool(10);
      var l2 = await fill(pool2, 4);
      l2[3].valid = false;
      expect(await pool2.checkPoolSize(1, 10, 1000000), isTrue);
      expect(pool2.poolSize, equals(4));
      expect(await pool2.checkPoolSize(1, 10, -1), isTrue);
      expect(pool2.poolSize, equals(3));
    });

    test('recyclePoolElement (async)', () async {
      var pool = _TestPool(10, asyncValid: true);
      var e = _Element(100);
      expect(await pool.recyclePoolElement(e), same(e));
      e.valid = false;
      expect(await pool.recyclePoolElement(e), isNull);

      expect(await pool.releaseIntoPool(e), isFalse);
      // Counted as unrecycled and as closed:
      expect(pool.poolDisposedElementsCount, equals(2));
      expect(pool.closed, equals([e]));
    });

    test('executeWithPool', () async {
      var pool = _TestPool(10);

      var r1 = await pool.executeWithPool((o) => o.id * 10);
      expect(r1, equals(10));
      expect(pool.poolSize, equals(1));

      // Validator rejects the element:
      var r2 = await pool.executeWithPool(
        (o) => o.id * 10,
        validator: (o) => false,
      );
      expect(r2, equals(10));
      expect(pool.poolSize, equals(0));
      expect(pool.closed.map((e) => e.id), equals([1]));

      // Synchronous error with `onError`:
      var r3 = await pool.executeWithPool<int>(
        (o) => throw StateError('sync error'),
        onError: (e, s) => -1,
      );
      expect(r3, equals(-1));

      // Synchronous error without `onError`:
      await expectLater(
        () async =>
            await pool.executeWithPool<int>((o) => throw StateError('sync2')),
        throwsStateError,
      );

      // Asynchronous error with `onError`:
      var r4 = await pool.executeWithPool<int>(
        (o) => Future<int>.error(StateError('async error')),
        onError: (e, s) => -2,
      );
      expect(r4, equals(-2));

      // Asynchronous error without `onError`:
      await expectLater(
        () async => await pool.executeWithPool<int>(
          (o) => Future<int>.error(StateError('async error 2')),
        ),
        throwsStateError,
      );

      expect(pool.poolSize, equals(0));
    });
  });

  group('FieldsFromMap', () {
    test('resolveFiledName', () {
      var f = _Fields();
      var fieldsNames = ['id', 'countryCode', 'state_or_province'];

      expect(f.resolveFiledName(fieldsNames, 'id'), equals('id'));
      expect(
        f.resolveFiledName(fieldsNames, 'COUNTRYCODE'),
        equals('countryCode'),
      );
      expect(
        f.resolveFiledName(fieldsNames, 'country_code'),
        equals('countryCode'),
      );
      expect(
        f.resolveFiledName(fieldsNames, 'stateOrProvince'),
        equals('state_or_province'),
      );
      expect(f.resolveFiledName(fieldsNames, 'unknown'), isNull);

      var indexes = f.buildFieldsNamesIndexes(fieldsNames);
      var lc = f.buildFieldsNamesLC(fieldsNames);
      var simple = f.buildFieldsNamesSimple(fieldsNames);

      expect(
        f.resolveFiledName(
          fieldsNames,
          'Country_Code',
          fieldsNamesIndexes: indexes,
          fieldsNamesLC: lc,
          fieldsNamesSimple: simple,
        ),
        equals('countryCode'),
      );
      expect(
        f.resolveFiledName(
          fieldsNames,
          'ID',
          fieldsNamesIndexes: indexes,
          fieldsNamesLC: lc,
          fieldsNamesSimple: simple,
        ),
        equals('id'),
      );
      expect(
        f.resolveFiledName(
          fieldsNames,
          'nope',
          fieldsNamesIndexes: indexes,
          fieldsNamesLC: lc,
          fieldsNamesSimple: simple,
        ),
        isNull,
      );
    });

    test('getFieldsValuesFromMap: includeAbsentFields', () {
      var f = _Fields();

      var usedKeys = <String>[];

      expect(
        f.getFieldsValuesFromMap(
          ['id', 'name', 'email'],
          {'ID': 1, 'Name': 'n'},
          includeAbsentFields: true,
          returnMapUsedKeys: usedKeys,
        ),
        equals({'id': 1, 'name': 'n', 'email': null}),
      );
      expect(usedKeys, equals(['ID', 'Name']));

      expect(
        f.getFieldsKeysInMap(['id', 'email'], {'ID': 1}),
        equals({'id': 'ID', 'email': null}),
      );
    });
  });

  group('WeakList', () {
    test('operations (strong referenced elements)', () {
      var a = _Element(1);
      var b = _Element(2);
      var c = _Element(3);
      var d = _Element(4);

      var l = WeakList<_Element>();
      expect(l.lastPurgeTime, isA<DateTime>());

      l.addAll([a, b, c]);
      l.add(null);
      expect(l.length, equals(3));

      expect(l.set(1, d), same(b));
      expect(l[1], same(d));

      l[1] = b;
      expect(l.toList(), equals([a, b, c]));

      // Setting `null` removes the entry:
      expect(l.set(0, null), same(a));
      expect(l.toList(), equals([b, c]));

      expect(l.contains(b), isTrue);
      expect(l.contains(a), isFalse);

      l.add(a);
      expect(l.removeAt(0), same(b));
      expect(l.toList(), equals([c, a]));

      l.removeWhere((e) => e == c);
      expect(l.toList(), equals([a]));
      l.removeWhere((e) => e == d);
      expect(l.toList(), equals([a]));

      l.addAll([b, c]);
      l.length = 2;
      expect(l.toList(), equals([a, b]));
      l.length = 10;
      expect(l.length, equals(2));

      expect(l.toList(growable: false), equals([a, b]));

      l.clear();
      expect(l.length, equals(0));
      expect(l.isEmpty, isTrue);

      var l2 = WeakList<_Element>(autoPurge: false);
      l2.add(a);
      expect(l2.purge(), isTrue);
      expect(l2.purge(), isFalse);
      expect(l2.purge(force: true), isTrue);
      expect(l2.length, equals(1));
    });
  });
}

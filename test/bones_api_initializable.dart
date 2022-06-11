import 'package:bones_api/bones_api_logging.dart';
import 'package:test/test.dart';

import 'package:logging/logging.dart' as logging;

final _log = logging.Logger('Initializable');

void main() {
  group('Initializable', () {
    setUpAll(() {
      _log.handler.logToConsole();
      _log.info('Activated logging to console.');
    });

    test('basic', () {
      var initA = _InitA();

      expect(initA.isInitialized, isFalse);
      expect(initA.isInitializing, isFalse);

      var ok = initA.doInitialization();

      expect(ok, isTrue);

      expect(initA.isInitialized, isTrue);
      expect(initA.isInitializing, isFalse);
      expect(initA.initializedDependenciesLength, equals(0));
      expect(initA.initializedDependencies, isEmpty);
      expect(initA.initializedDependenciesDeeplyLength, equals(0));
      expect(initA.initializedDependenciesDeeply, isEmpty);
    });

    test('with dependency', () {
      var initB = _InitB();

      expect(initB.isInitialized, isFalse);
      expect(initB.isInitializing, isFalse);

      var ok = initB.doInitialization();

      expect(ok, isTrue);

      expect(initB.isInitialized, isTrue);
      expect(initB.isInitializing, isFalse);
      expect(initB.initializedDependenciesLength, equals(1));
      expect(initB.initializedDependencies.length, equals(1));
      expect(
          initB.initializedDependencies.whereType<_InitA>().length, equals(1));
      expect(initB.initializedDependenciesDeeplyLength, equals(1));
      expect(initB.initializedDependenciesDeeply.length, equals(1));
      expect(initB.initializedDependenciesDeeply.whereType<_InitA>().length,
          equals(1));

      expect(
          initB.initializedDependencies.any((d) => !d.isInitialized), isFalse);
      expect(
          initB.initializedDependencies.any((d) => d.isInitializing), isFalse);
    });

    test('with sub-dependency', () {
      var initC = _InitC();

      expect(initC.isInitialized, isFalse);
      expect(initC.isInitializing, isFalse);

      var ok = initC.doInitialization();

      expect(ok, isTrue);

      expect(initC.isInitialized, isTrue);
      expect(initC.isInitializing, isFalse);
      expect(initC.initializedDependenciesLength, equals(1));
      expect(initC.initializedDependencies.length, equals(1));
      expect(
          initC.initializedDependencies.whereType<_InitB>().length, equals(1));
      expect(initC.initializedDependenciesDeeplyLength, equals(2));
      expect(initC.initializedDependenciesDeeply.length, equals(2));
      expect(initC.initializedDependenciesDeeply.whereType<_InitA>().length,
          equals(1));
      expect(initC.initializedDependenciesDeeply.whereType<_InitB>().length,
          equals(1));

      expect(
          initC.initializedDependencies.any((d) => !d.isInitialized), isFalse);
      expect(
          initC.initializedDependencies.any((d) => d.isInitializing), isFalse);

      expect(initC.initializedDependenciesDeeply.any((d) => !d.isInitialized),
          isFalse);
      expect(initC.initializedDependenciesDeeply.any((d) => d.isInitializing),
          isFalse);
    });

    test('with recursive dependency (sync)', () {
      var initD = _InitD();

      expect(initD.isInitialized, isFalse);
      expect(initD.isInitializing, isFalse);

      var ok = initD.doInitialization();

      expect(ok, isTrue);

      expect(initD.isInitialized, isTrue);
      expect(initD.isInitializing, isFalse);
      expect(initD.initializedDependenciesLength, equals(1));
    });

    test('with recursive dependency (async)', () async {
      var initD = _InitDAsync();

      expect(initD.isInitialized, isFalse);
      expect(initD.isInitializing, isFalse);

      var ok = await initD.doInitialization();

      print('>> $initD: $ok');

      expect(ok, isTrue);

      expect(initD.isInitialized, isTrue);
      expect(initD.isInitializing, isFalse);
      expect(initD.initializedDependenciesLength, equals(1));
    });
  });
}

class _Init with Initializable {
  final Map<Type, _Init> context;

  _Init(this.context);

  DateTime? initDate;

  @override
  FutureOr<bool> initialize() {
    initDate = DateTime.now();
    return true;
  }

  @override
  String toString() {
    return '$runtimeType{${initDate?.millisecondsSinceEpoch}, $initializationStatus}';
  }
}

class _InitAsync extends _Init {
  final Duration delay;

  _InitAsync(this.delay, Map<Type, _Init> context) : super(context);

  @override
  Future<bool> initialize() => Future.delayed(delay, () {
        initDate = DateTime.now();
        return true;
      });
}

class _InitA extends _Init {
  _InitA([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});
}

class _InitB extends _Init {
  _InitB([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      <Initializable>[context.putIfAbsent(_InitA, () => _InitA(context))];
}

class _InitC extends _Init {
  _InitC([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      <Initializable>[context.putIfAbsent(_InitB, () => _InitB(context))];
}

class _InitD extends _Init {
  _InitD([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{}) {
    this.context[_InitD] = this;
  }

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      <Initializable>[context.putIfAbsent(_InitE, () => _InitE(context))];
}

class _InitE extends _Init {
  _InitE([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{}) {
    this.context[_InitE] = this;
  }

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      <Initializable>[context.putIfAbsent(_InitD, () => _InitD(context))];
}

// --

class _InitDAsync extends _InitAsync {
  _InitDAsync([Map<Type, _Init>? context])
      : super(Duration(milliseconds: 200), context ?? <Type, _Init>{}) {
    this.context[_InitD] = this;
  }

  @override
  FutureOr<List<Initializable>> initializeDependencies() => Future.delayed(
      Duration(milliseconds: 200),
      () => <Initializable>[
            context.putIfAbsent(_InitE, () => _InitEAsync(context))
          ]);
}

class _InitEAsync extends _InitAsync {
  _InitEAsync([Map<Type, _Init>? context])
      : super(Duration(milliseconds: 200), context ?? <Type, _Init>{}) {
    this.context[_InitE] = this;
  }

  @override
  FutureOr<List<Initializable>> initializeDependencies() => Future.delayed(
      Duration(milliseconds: 200),
      () => <Initializable>[
            context.putIfAbsent(_InitD, () => _InitDAsync(context))
          ]);
}

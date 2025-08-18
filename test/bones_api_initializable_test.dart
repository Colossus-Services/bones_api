@Timeout(Duration(seconds: 180))
// ignore_for_file: discarded_futures
import 'package:bones_api/bones_api.dart';
import 'package:bones_api/bones_api_logging.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

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

      var result = initA.doInitialization() as InitializationResult;

      expect(result.ok, isTrue);

      expect(initA.isInitialized, isTrue);
      expect(initA.isInitializing, isFalse);
    });

    test('with dependency', () {
      var initB = _InitB();

      expect(initB.isInitialized, isFalse);
      expect(initB.isInitializing, isFalse);

      var result = initB.doInitialization() as InitializationResult;

      expect(result.ok, isTrue);

      expect(initB.isInitialized, isTrue);
      expect(initB.isInitializing, isFalse);
    });

    test('with sub-dependency', () {
      var initC = _InitC();

      expect(initC.isInitialized, isFalse);
      expect(initC.isInitializing, isFalse);

      var result = initC.doInitialization() as InitializationResult;

      expect(result.ok, isTrue);

      expect(initC.isInitialized, isTrue);
      expect(initC.isInitializing, isFalse);
    });

    test('with recursive dependency (sync)', () async {
      var initD = _InitD();

      expect(initD.isInitialized, isFalse);
      expect(initD.isInitializing, isFalse);

      var resultAsync = initD.doInitialization();
      expect(resultAsync, isA<Future>());

      var result = await resultAsync;

      expect(result.ok, isTrue);

      expect(initD.isInitialized, isTrue);
      expect(initD.isInitializing, isFalse);
    });

    test('with recursive dependency (async)', () async {
      var initD = _InitDAsync();

      expect(initD.isInitialized, isFalse);
      expect(initD.isInitializing, isFalse);

      var result = await initD.doInitialization();

      print('>> $initD: $result');

      expect(result.ok, isTrue);

      expect(initD.isInitialized, isTrue);
      expect(initD.isInitializing, isFalse);
    });

    test('with recursive dependency (async 2)', () async {
      var initD = _InitDAsync2();

      expect(initD.isInitialized, isFalse);
      expect(initD.isInitializing, isFalse);

      var result = await initD.doInitialization();

      print('>> $initD: $result');

      expect(result.ok, isTrue);

      expect(initD.isInitialized, isTrue);
      expect(initD.isInitializing, isFalse);
    });
  });
}

class _Init with Initializable {
  final Map<Type, _Init> context;

  _Init(this.context) {
    context[runtimeType] = this;
  }

  T inContext<T extends _Init>(T Function() instantiator) =>
      context.putIfAbsent(T, instantiator) as T;

  List<T> inContextAsList<T extends _Init>(T Function() instantiator) => <T>[
    inContext<T>(instantiator),
  ];

  DateTime? initDate;

  @override
  FutureOr<InitializationResult> initialize() {
    initDate = DateTime.now();
    return InitializationResult.ok(this);
  }

  @override
  String toString() {
    return '$runtimeTypeNameUnsafe{${initDate?.millisecondsSinceEpoch}, $initializationStatus}';
  }
}

class _InitAsync extends _Init {
  final Duration delay = Duration(milliseconds: 200);

  _InitAsync(super.context);

  @override
  Future<InitializationResult> initialize() => Future.delayed(delay, () {
    initDate = DateTime.now();
    return InitializationResult.ok(this);
  });
}

class _InitA extends _Init {
  _InitA([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});
}

class _InitB extends _Init {
  _InitB([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() => <Initializable>[
    context.putIfAbsent(_InitA, () => _InitA(context)),
  ];
}

class _InitC extends _Init {
  _InitC([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      inContextAsList<_InitB>(() => _InitB(context));
}

class _InitD extends _Init {
  _InitD([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      inContextAsList<_InitE>(() => _InitE(context));
}

class _InitE extends _Init {
  _InitE([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() =>
      inContextAsList<_InitD>(() => _InitD(context));
}

class _InitDAsync extends _InitAsync {
  _InitDAsync([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() => Future.delayed(
    Duration(milliseconds: 200),
    () => inContextAsList<_InitEAsync>(() => _InitEAsync(context)),
  );
}

class _InitEAsync extends _InitAsync {
  _InitEAsync([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  FutureOr<List<Initializable>> initializeDependencies() => Future.delayed(
    Duration(milliseconds: 200),
    () => inContextAsList<_InitDAsync>(() => _InitDAsync(context)),
  );
}

class _InitDAsync2 extends _InitAsync {
  _InitDAsync2([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  Future<InitializationResult> initialize() => Future.delayed(delay, () {
    initDate = DateTime.now();
    return InitializationResult.ok(
      this,
      dependencies: inContextAsList<_InitEAsync2>(() => _InitEAsync2(context)),
    );
  });
}

class _InitEAsync2 extends _InitAsync {
  _InitEAsync2([Map<Type, _Init>? context]) : super(context ?? <Type, _Init>{});

  @override
  Future<InitializationResult> initialize() => Future.delayed(delay, () {
    initDate = DateTime.now();
    return InitializationResult.ok(
      this,
      dependencies: inContextAsList<_InitDAsync2>(() => _InitDAsync2(context)),
    );
  });
}

@TestOn('vm')
import 'dart:io';

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

/// A [Map]-backed entity: `id` and `name` (plus `extra`, a field it can type
/// but doesn't list in [fieldsNames]).
class _FixItem extends Entity {
  final Map<String, Object?> values;

  _FixItem([Map<String, Object?>? values]) : values = values ?? {};

  static const _types = <String, TypeInfo>{
    'id': TypeInfo.tInt,
    'name': TypeInfo.tString,
  };

  @override
  String get idFieldName => 'id';

  @override
  List<String> get fieldsNames => _types.keys.toList();

  @override
  V? getField<V>(String key) => values[key] as V?;

  @override
  TypeInfo? getFieldType(String key) =>
      key == 'extra' ? TypeInfo.tString : _types[key];

  @override
  void setField<V>(String key, V? value) => values[key] = value;

  @override
  Map<String, dynamic> toJson() => Map<String, dynamic>.from(values);
}

/// A handler listing one more field (`extra`) than the entity instances:
/// `getFieldType` resolves it, but the cached field types (from the
/// instances) don't have it.
class _ExtraFieldHandler extends GenericEntityHandler<_FixItem> {
  _ExtraFieldHandler({super.provider})
    : super(
        instantiatorDefault: _FixItem.new,
        instantiatorFromMap: (m) => _FixItem(Map<String, Object?>.from(m)),
      );

  @override
  List<String> fieldsNames([_FixItem? o]) => [...super.fieldsNames(o), 'extra'];
}

/// Records the [Transaction] passed to [storeAllFromJson] and [deleteByID].
class _RecordingRepository extends SetEntityRepository<_FixItem> {
  _RecordingRepository(super.name, super.entityHandler, {super.provider});

  final List<Transaction?> storeAllFromJsonTransactions = [];
  final List<Transaction?> deleteByIDTransactions = [];

  @override
  FutureOr<List<_FixItem>> storeAllFromJson(
    Iterable<Map<String, dynamic>> entitiesJson, {
    Transaction? transaction,
    EntityResolutionRules? resolutionRules,
  }) {
    storeAllFromJsonTransactions.add(transaction);
    return super.storeAllFromJson(
      entitiesJson,
      transaction: transaction,
      resolutionRules: resolutionRules,
    );
  }

  @override
  FutureOr<_FixItem?> deleteByID(dynamic id, {Transaction? transaction}) {
    deleteByIDTransactions.add(transaction);
    return null;
  }
}

void main() {
  group('GenericEntityHandler.getFieldType', () {
    test('resolves the field name for the entity instance lookup', () {
      var handler = _ExtraFieldHandler(provider: EntityHandlerProvider());
      var o = _FixItem({'id': 1, 'name': 'a'});

      expect(handler.getFieldType(o, 'extra'), equals(TypeInfo.tString));

      // `EXTRA` resolves to `extra` (not in the cached types, from `o`'s
      // fields): the instance is asked for the resolved name.
      expect(
        handler.getFieldType(o, 'EXTRA', resolveFiledName: true),
        equals(TypeInfo.tString),
      );
      expect(handler.getFieldType(o, 'EXTRA'), isNull);
    });
  });

  group('EntityRepositoryProvider seed JSON', () {
    late EntityRepositoryProvider provider;
    late _RecordingRepository repo;

    setUp(() {
      provider = EntityRepositoryProvider();
      repo = _RecordingRepository(
        'fix_item',
        _ExtraFieldHandler(provider: EntityHandlerProvider()),
        provider: provider,
      )..ensureInitialized();
    });

    tearDown(() {
      repo.close();
      provider.close();
    });

    test('storeAllFromJson resolves `variables`', () async {
      var res = await provider.storeAllFromJsonEncoded(
        '{"fix_item": [{"name": "%v1%"}, {"name": "plain"}]}',
        variables: {'v1': 'var_value'},
      );
      expect(res['fix_item'], hasLength(2));

      var names = (await repo.selectAll()).map((e) => e.values['name']);
      expect(names, unorderedEquals(['var_value', 'plain']));
    });

    test('storeAllFromJson forwards the `transaction`', () async {
      var transaction = Transaction();

      await provider.storeAllFromJson({
        'fix_item': [
          {'name': 'a'},
        ],
      }, transaction: transaction);

      expect(repo.storeAllFromJsonTransactions, hasLength(1));
      expect(repo.storeAllFromJsonTransactions.single, same(transaction));
    });

    test('populateFromSource resolves the source in `workingPath`', () async {
      var dir = await Directory.systemTemp.createTemp('bones_api_fix_');
      addTearDown(() => dir.delete(recursive: true));

      await File('${dir.path}/seed.json')
          .writeAsString('{"fix_item": [{"name": "from_working_path"}]}');

      var res = await provider.populateFromSource(
        'seed.json',
        workingPath: dir.path,
      );
      expect(res['fix_item'], hasLength(1));
      expect(
        (await repo.selectAll()).single.values['name'],
        equals('from_working_path'),
      );
    });

    test('IterableEntityRepository.deleteEntity forwards `transaction`', () {
      var transaction = Transaction();

      repo.deleteEntity(_FixItem({'id': 1}), transaction: transaction);

      expect(repo.deleteByIDTransactions.single, same(transaction));
    });
  });

  group('EntityReference(List).from', () {
    test('forwards `entityHandlerProvider`', () {
      // A handler registered only in a local provider (not the global one):
      var entityHandlerProvider = EntityHandlerProvider();
      var handler = _ExtraFieldHandler(provider: entityHandlerProvider);

      var o = _FixItem({'id': 1, 'name': 'a'});

      for (var value in <Object?>[
        null,
        1,
        {'id': 1, 'name': 'a'},
        o,
      ]) {
        var ref = EntityReference<_FixItem>.from(
          value,
          entityHandlerProvider: entityHandlerProvider,
        );
        expect(ref.entityHandler, same(handler), reason: 'value: $value');
      }

      for (var value in <Object?>[
        null,
        [1],
        [o],
        o,
      ]) {
        var refs = EntityReferenceList<_FixItem>.from(
          value,
          entityHandlerProvider: entityHandlerProvider,
        );
        expect(refs.entityHandler, same(handler), reason: 'value: $value');
      }
    });
  });

  group('EntityAccessRules', () {
    test('`==`/`hashCode` compare `entityFields` element-wise', () {
      var r1 = EntityAccessRules.block(_FixItem, entityFields: ['name']);
      var r2 = EntityAccessRules.block(_FixItem, entityFields: ['name']);
      var r3 = EntityAccessRules.block(_FixItem, entityFields: ['id']);

      expect(r1 == r2, isTrue);
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1 == r3, isFalse);
    });
  });

  group('EntityResolutionRules', () {
    test('`allEager` and `allLazy` both `true` is rejected', () {
      var rules = EntityResolutionRules(allEager: true, allLazy: true);

      expect(rules.isValid, isFalse);
      expect(rules.validate, throwsA(isA<ValidateEntityRulesError>()));

      // No infinite recursion:
      expect(rules.isEagerEntityType(_FixItem), isTrue);
      expect(rules.isLazyEntityType(_FixItem), isTrue);

      // A merge that would produce it:
      expect(
        () =>
            EntityResolutionRules(allEager: true)
                .merge(EntityResolutionRules(allLazy: true)),
        throwsA(isA<ValidateEntityRulesError>()),
      );
    });

    test('a tolerant merge drops the `allEager`/`allLazy` conflict', () {
      // Both tolerant: both flags dropped (as a same-flag conflict).
      var both = EntityResolutionRules(
        allEager: true,
        mergeTolerant: true,
      ).merge(EntityResolutionRules(allLazy: true, mergeTolerant: true));
      expect(both.allEager, isNull);
      expect(both.allLazy, isNull);

      // One tolerant: it yields its flag to the intolerant side.
      var tolerantEager = EntityResolutionRules(
        allEager: true,
        mergeTolerant: true,
      ).merge(EntityResolutionRules(allLazy: true));
      expect(tolerantEager.allEager, isNull);
      expect(tolerantEager.allLazy, isTrue);

      var tolerantLazy = EntityResolutionRules(allEager: true)
          .merge(EntityResolutionRules(allLazy: true, mergeTolerant: true));
      expect(tolerantLazy.allEager, isTrue);
      expect(tolerantLazy.allLazy, isNull);
    });

    test('`allEager`/`allLazy` with explicit exceptions (unchanged)', () {
      var eager = EntityResolutionRules(
        allEager: true,
        lazyEntityTypes: [_FixItem],
      );
      expect(eager.isEagerEntityType(_FixItem), isFalse);
      expect(eager.isEagerEntityType(String), isTrue);
      expect(eager.isLazyEntityType(_FixItem), isTrue);

      var lazy = EntityResolutionRules(
        allLazy: true,
        eagerEntityTypes: [_FixItem],
      );
      expect(lazy.isLazyEntityType(_FixItem), isFalse);
      expect(lazy.isLazyEntityType(String), isTrue);
      expect(lazy.isEagerEntityType(_FixItem), isTrue);
    });
  });
}

@TestOn('vm')
library;

import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

/// A plain (non reflected) class with `toJson`.
class _Plain {
  final int id;
  final String name;
  final String secret;

  _Plain(this.id, this.name, this.secret);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'secret': secret};
}

class _Resolver with EntityRulesResolver {}

class _ContextProvider implements EntityRulesContextProvider {
  EntityResolutionRules? rules;

  _ContextProvider(this.rules);

  int calls = 0;

  @override
  EntityResolutionRules? getContextEntityResolutionRules({
    Zone? contextZone,
    Object? contextIdentifier,
  }) {
    ++calls;
    return rules;
  }
}

void main() {
  group('EntityAccessRulesContext', () {
    test('objectAs / contextAs', () {
      var rules = EntityAccessRules.block(User);

      var c1 = EntityAccessRulesContext(rules, 'str', context: 123);
      expect(c1.objectAs<String>(), equals('str'));
      expect(c1.objectAs<int>(), isNull);
      expect(c1.objectAsListOf<String>(), equals(['str']));
      expect(c1.objectAsListOf<int>(), isEmpty);
      expect(c1.contextAs<int>(), equals(123));
      expect(c1.contextAsListOf<int>(), equals([123]));
      expect(c1.toString(), contains('EntityAccessRulesContext->'));
      expect(c1.toString(), contains('@str+123'));

      var c2 = EntityAccessRulesContext(rules, <Object>['a', 1, 'b', 2]);
      expect(c2.objectAs<int>(), equals(1));
      expect(c2.objectAs<double>(), isNull);
      expect(c2.objectAsListOf<String>(), equals(['a', 'b']));
      expect(c2.objectAsListOf<Object>(), equals(['a', 1, 'b', 2]));
      expect(c2.contextAs<int>(), isNull);
      expect(c2.contextAsListOf<int>(), isEmpty);
      expect(c2.toString(), endsWith('+'));
    });
  });

  group('EntityAccessRules', () {
    test('totalRules', () {
      expect(EntityAccessRules.innocuous.totalRules(), equals(0));
      expect(EntityAccessRules().totalRules(), equals(0));
      expect(EntityAccessRules.block(User).totalRules(), equals(1));
      expect(EntityAccessRules.group([]).totalRules(), equals(0));

      var r = EntityAccessRules.group([
        EntityAccessRules.block(User),
        EntityAccessRules.group([
          EntityAccessRules.allow(Address),
          EntityAccessRules.mask(Role),
        ]),
      ]);
      expect(r.totalRules(), equals(3));

      var r2 = EntityAccessRules(
        ruleType: EntityAccessRuleType.block,
        entityType: Store,
        rules: [EntityAccessRules.block(User)],
      );
      expect(r2.totalRules(), equals(2));
    });

    test('simplified: fields only and entityType with rules', () {
      var rFields = EntityAccessRules(entityFields: ['a']);
      expect(rFields.isInnocuous, isFalse);
      var s = rFields.simplified();
      expect(s.isInnocuous, isFalse);
      expect(s.entityFields, equals(['a']));

      var r = EntityAccessRules(
        ruleType: EntityAccessRuleType.block,
        entityType: Store,
        rules: [
          EntityAccessRules.group([
            EntityAccessRules.allow(Address),
            EntityAccessRules.block(Role),
          ]),
          EntityAccessRules.innocuous,
        ],
      );

      var rs = r.simplified();
      expect(rs.ruleType, isNull);
      expect(rs.entityType, isNull);
      expect(rs.rules!.length, equals(3));
      expect(rs.rules![0].entityType, equals(Store));
      expect(rs.rules![0].rules, isNull);
      expect(rs.rules![1].entityType, equals(Address));
      expect(rs.rules![2].entityType, equals(Role));

      var rOnlyInnocuous = EntityAccessRules(
        ruleType: EntityAccessRuleType.block,
        entityType: Store,
        rules: [EntityAccessRules.innocuous],
      );
      var rs2 = rOnlyInnocuous.simplified();
      expect(rs2.entityType, equals(Store));
      expect(rs2.rules, isNull);
    });

    test('merge groups', () {
      var a = EntityAccessRules.group([
        EntityAccessRules.block(User),
        EntityAccessRules.block(Address),
      ]);
      var b = EntityAccessRules.group([
        EntityAccessRules.allow(Role),
        EntityAccessRules.mask(Store),
      ]);

      var m = a.merge(b);
      expect(m.rules!.map((e) => e.entityType), [User, Address, Role, Store]);
      expect(m.totalRules(), equals(4));

      expect(EntityAccessRules.innocuous.merge(null), isA<EntityAccessRules>());
      expect(EntityAccessRules.innocuous.merge(null).isInnocuous, isTrue);
      expect(
        EntityAccessRules.innocuous.merge(EntityAccessRules()).isInnocuous,
        isTrue,
      );
      expect(EntityAccessRules.innocuous.merge(a), same(a));
    });

    test('isAllowedEntityTypeField with allow condition', () {
      var allowed = true;

      var r = EntityAccessRules.allowFields(User, [
        'email',
      ], condition: (c) => allowed);

      expect(r.isAllowedEntityTypeField(User, 'email'), isTrue);
      expect(r.isAllowedEntityTypeField(User, 'EMAIL'), isTrue);
      expect(r.isAllowedEntityTypeField(User, 'password'), isNull);
      allowed = false;
      expect(r.isAllowedEntityTypeField(User, 'email'), isFalse);
    });

    test('applyMask on a mask rule', () {
      var r = EntityAccessRules.maskFields(User, ['password']);

      var user = User.empty();

      expect(r.applyMask(user, 'password', 'secret'), equals(''));
      expect(r.applyMask(user, 'password', 123), equals(0));
      expect(r.applyMask(user, 'email', 'x@y'), equals('x@y'));

      var rMasker = EntityAccessRules.maskFields(User, [
        'password',
      ], masker: (context, object, field, value) => '<$field>');
      expect(
        rMasker.applyMask(user, 'password', 'secret'),
        equals('<password>'),
      );
    });

    test('defaultMask', () {
      Object? mask(Object? v) =>
          EntityAccessRules.defaultMask<Object, Object?>(null, 'o', 'f', v);

      expect(mask(null), isNull);
      expect(mask('abc'), equals(''));
      expect(mask(10), equals(0));
      expect(mask(1.5), equals(0.0));
      expect(mask(true), isFalse);
      expect(
        mask(DateTime(2020)),
        equals(DateTime.fromMillisecondsSinceEpoch(0)),
      );
      expect(mask(Time(10, 20)), equals(Time(0)));
      expect(mask(<String, String>{'a': 'b'}), equals(<String, String>{}));
      expect(mask(<String, int>{'a': 1}), equals(<String, int>{}));
      expect(mask(<String, double>{'a': 1.0}), equals(<String, double>{}));
      expect(mask(<String, num>{'a': 1}), equals(<String, num>{}));
      expect(mask(<String, Object>{'a': 1}), equals(<String, Object>{}));
      expect(mask(<String, dynamic>{'a': null}), equals(<String, dynamic>{}));
      expect(mask(<int, int>{1: 2}), equals({}));
      expect(mask(['a']), equals(<String>[]));
      expect(mask([1]), equals(<int>[]));
      expect(mask([1.0]), equals(<double>[]));
      expect(mask(<num>[1]), equals(<num>[]));
      expect(mask(<Object>[1]), equals(<Object>[]));
      expect(mask(<Object?>[null]), equals([]));
      var other = Object();
      expect(mask(other), same(other));
    });

    test('toString and toJson', () {
      var r = EntityAccessRules(
        ruleType: EntityAccessRuleType.block,
        entityType: User,
        entityFields: ['email'],
        rules: [EntityAccessRules.allow(Address)],
      );

      var s = r.toString();
      expect(s, startsWith('EntityAccessRules[block]{entityType: User'));
      expect(s, contains('entityFields: [email]'));
      expect(s, contains('EntityAccessRules[allow]{entityType: Address}'));

      expect(
        r.toJson(),
        equals({
          'ruleType': 'block',
          'entityType': 'User',
          'entityFields': ['email'],
          'rules': [
            {'ruleType': 'allow', 'entityType': 'Address'},
          ],
        }),
      );
    });

    test('== and hashCode (innocuous)', () {
      expect(EntityAccessRules() == EntityAccessRules.innocuous, isTrue);
      expect(
        EntityAccessRules().hashCode,
        equals(EntityAccessRules.innocuous.hashCode),
      );
      expect(
        EntityAccessRules.block(User) == EntityAccessRules.block(User),
        isTrue,
      );
      expect(
        EntityAccessRules.block(User) == EntityAccessRules.block(Address),
        isFalse,
      );
    });

    test('innocuous instance', () {
      const r = EntityAccessRules.innocuous;

      expect(r.totalRules(), equals(0));
      expect(r.isInnocuous, isTrue);
      expect(r.isValid, isTrue);
      r.validate();
      expect(identical(r.cached, r), isTrue);
      expect(r.ruleType, isNull);
      expect(r.rules, isNull);
      expect(r.entityFields, isNull);
      expect(r.entityType, isNull);
      expect(r.condition, isNull);
      expect(r.masker, isNull);
      expect(r.hasRuleType([EntityAccessRuleType.block]), isFalse);
      expect(r.hasRuleForEntityType(User), isFalse);
      expect(r.hasRuleForEntityTypeField(User), isFalse);
      expect(r.isAllowedEntityType(User), isNull);
      expect(r.isAllowedEntityTypeField(User, 'email'), isNull);
      expect(r.isMaskedEntityTypeField(User, 'email'), isNull);
      expect(r.applyMask('o', 'f', 'v'), equals('v'));
      expect(identical(r.simplified(), r), isTrue);
      expect(r.toJson(), isEmpty);
      expect(r.toString(), equals('EntityAccessRules{innocuous}'));

      var apiRequest = APIRequest(APIRequestMethod.GET, '/foo');
      expect(
        r.toJsonEncodable(
          apiRequest,
          Json.defaultToEncodableJsonProvider(),
          'x',
        ),
        isNull,
      );

      var cp = r.copyWith(
        ruleType: EntityAccessRuleType.block,
        entityType: User,
      );
      expect(cp.ruleType, equals(EntityAccessRuleType.block));
      expect(cp.entityType, equals(User));

      // `_innocuous._equals` and `_innocuous._hashCode`
      // (through a non-cached innocuous instance):
      expect(
        EntityAccessRules.group([]) == EntityAccessRules.innocuous,
        isTrue,
      );
      expect(EntityAccessRules.group([]).hashCode, isA<int>());
    });

    test('EntityAccessRulesCached', () {
      bool condition(EntityAccessRulesContext? c) => true;
      Object? masker(
        EntityAccessRulesContext? c,
        Object o,
        String f,
        Object? v,
      ) => '#';

      var base = EntityAccessRules.group([
        EntityAccessRules.blockFields(User, ['password'], condition: condition),
        EntityAccessRules.maskFields(Address, ['street'], masker: masker),
      ]);

      var r = base.cached;
      expect(r, isA<EntityAccessRulesCached>());
      expect(identical(r.cached, r), isTrue);

      expect(r.totalRules(), equals(2));
      expect(r.totalRules(), equals(2));
      expect(r.isInnocuous, isFalse);
      expect(r.isValid, isTrue);
      r.validate();
      expect(r.ruleType, isNull);
      expect(r.entityType, isNull);
      expect(r.entityFields, isNull);
      expect(r.rules!.length, equals(2));
      expect(r.condition, isNull);
      expect(r.masker, isNull);

      expect(r.hasRuleType([EntityAccessRuleType.mask]), isTrue);
      // Cached:
      expect(r.hasRuleType([EntityAccessRuleType.mask]), isTrue);
      expect(r.hasRuleType([EntityAccessRuleType.allow]), isFalse);

      expect(r.hasRuleForEntityType(User), isTrue);
      expect(r.hasRuleForEntityTypeField(Address), isTrue);
      expect(r.isAllowedEntityType(User), isTrue);
      expect(r.isAllowedEntityTypeField(User, 'password'), isFalse);
      expect(r.isMaskedEntityTypeField(Address, 'street'), isTrue);
      expect(
        r.applyMask(Address.empty(), 'street', 'Main St.', type: Address),
        equals('#'),
      );

      var cp = r.copyWith(
        entityType: Role,
        ruleType: EntityAccessRuleType.block,
      );
      expect(cp.entityType, equals(Role));

      var m = r.merge(EntityAccessRules.block(Store));
      expect(m.rules!.length, equals(3));

      var s = r.simplified();
      expect(s.rules!.length, equals(2));

      expect(r == base, isTrue);
      expect(r.hashCode, equals(base.hashCode));
      expect(r.toString(), equals(base.toString()));
      expect(r.toJson(), equals(base.toJson()));

      // Merging into a cached instance uses `_simplifiedImpl`/`_equals`:
      var m2 = EntityAccessRules.group([r, EntityAccessRules.allow(Role)]);
      expect(m2.simplified().rules!.length, equals(3));
      expect(
        EntityAccessRules.group([r]).simplified() ==
            EntityAccessRules.group([base]).simplified(),
        isTrue,
      );
    });

    test('toJsonEncodable', () {
      var apiRequest = APIRequest(APIRequestMethod.GET, '/foo');

      var rBlockType = EntityAccessRules.block(_Plain);

      var encBlock = rBlockType.toJsonEncodable(
        apiRequest,
        Json.defaultToEncodableJsonProvider(),
        _Plain(1, 'a', 's'),
      );
      expect(encBlock, isNotNull);
      expect(encBlock!(_Plain(1, 'a', 's'), JsonEncoder()), equals({}));

      // Ignored types:
      expect(
        rBlockType.toJsonEncodable(
          apiRequest,
          Json.defaultToEncodableJsonProvider(),
          DateTime(2020),
        ),
        isNull,
      );

      var rFields = EntityAccessRules.group([
        EntityAccessRules.blockFields(_Plain, ['secret']),
        EntityAccessRules.maskFields(_Plain, ['name']),
      ]);

      // No `ToEncodableJson` from provider (uses `JsonEncoder.toJson`):
      var enc = rFields.toJsonEncodable(
        apiRequest,
        (o) => null,
        _Plain(1, 'a', 's'),
      );
      expect(enc, isNotNull);
      expect(enc!(null, JsonEncoder()), isNull);
      expect(
        enc(_Plain(1, 'joe', 's'), JsonEncoder()),
        equals({'id': 1, 'name': ''}),
      );

      // `ToEncodableJson` from provider:
      var enc2 = rFields.toJsonEncodable(
        apiRequest,
        (o) =>
            (o, j) => {'id': 2, 'name': 'x', 'secret': 'y', 'extra': true},
        _Plain(2, 'x', 'y'),
      );
      expect(
        enc2!(_Plain(2, 'x', 'y'), JsonEncoder()),
        equals({'id': 2, 'name': '', 'extra': true}),
      );

      // Provider returning a non `Map`:
      var enc3 = rFields.toJsonEncodable(
        apiRequest,
        (o) =>
            (o, j) => 'not-a-map',
        _Plain(3, 'x', 'y'),
      );
      expect(enc3!(_Plain(3, 'x', 'y'), JsonEncoder()), equals('not-a-map'));

      // No field rules for type:
      expect(
        EntityAccessRules.allow(_Plain).toJsonEncodable(
          apiRequest,
          Json.defaultToEncodableJsonProvider(),
          _Plain(4, 'x', 'y'),
        ),
        isNull,
      );

      // No rule for type:
      expect(
        rFields.toJsonEncodable(
          apiRequest,
          Json.defaultToEncodableJsonProvider(),
          'str',
        ),
        isNull,
      );

      // Cached:
      var encCached = rFields.cached.toJsonEncodable(
        apiRequest,
        (o) => null,
        _Plain(5, 'n', 's'),
      );
      expect(
        encCached!(_Plain(5, 'n', 's'), JsonEncoder()),
        equals({'id': 5, 'name': ''}),
      );
    });
  });

  group('MergeEntityRulesError', () {
    test('toString', () {
      var a = EntityResolutionRules(allEager: true);
      var b = EntityResolutionRules(allEager: false);

      expect(
        () => a.merge(b),
        throwsA(
          isA<MergeEntityRulesError>()
              .having((e) => e.conflict, 'conflict', equals('allEager'))
              .having(
                (e) => e.toString(),
                'toString',
                contains(
                  "Can't merge `EntityResolutionRules`! Conflict: allEager",
                ),
              ),
        ),
      );
    });
  });

  group('EntityResolutionRules', () {
    test('fetchTypes: allEager/allLazy without exceptions', () {
      var r1 = EntityResolutionRules.fetchTypes(
        allEager: true,
        eagerTypes: {User: true},
      );
      expect(r1, equals(EntityResolutionRules.fetchEagerAll()));
      expect(r1.allEager, isTrue);

      var r2 = EntityResolutionRules.fetchTypes(
        allLazy: true,
        lazyTypes: {User: true},
        mergeTolerant: true,
      );
      expect(
        r2,
        equals(EntityResolutionRules.fetchLazyAll(mergeTolerant: true)),
      );
      expect(r2.allLazy, isTrue);
    });

    test('isAny*', () {
      var r = EntityResolutionRules(
        eagerEntityTypes: [User],
        lazyEntityTypes: [Address],
      );

      expect(r.isAnyEagerEntityType([Role, User]), isTrue);
      expect(r.isAnyEagerEntityType([Role]), isFalse);
      expect(r.isAnyLazyEntityType([Role, Address]), isTrue);
      expect(r.isAnyLazyEntityType([User]), isFalse);

      expect(r.isAnyEagerEntityTypeInfo([TypeInfo.fromType(User)]), isTrue);
      expect(r.isAnyEagerEntityTypeInfo([TypeInfo.fromType(Role)]), isFalse);
      expect(r.isAnyLazyEntityTypeInfo([TypeInfo.fromType(Address)]), isTrue);
      expect(r.isAnyLazyEntityTypeInfo([TypeInfo.fromType(Role)]), isFalse);
    });

    test('hashCode and toJson', () {
      var r1 = EntityResolutionRules(
        allowReadFile: true,
        eagerEntityTypes: [User],
        lazyEntityTypes: [Address],
      );
      var r2 = EntityResolutionRules(
        allowReadFile: true,
        eagerEntityTypes: [User],
        lazyEntityTypes: [Address],
      );

      expect(r1 == r2, isTrue);
      expect(r1.hashCode, equals(r2.hashCode));

      expect(
        r1.toJson(),
        equals({
          'allowEntityFetch': true,
          'allowReadFile': true,
          'lazyEntityTypes': ['Address'],
          'eagerEntityTypes': ['User'],
        }),
      );

      expect(EntityResolutionRules().toJson(), isEmpty);
    });

    test('innocuous instance', () {
      const r = EntityResolutionRules.innocuous;

      expect(r.isInnocuous, isTrue);
      expect(r.isValid, isTrue);
      r.validate();
      expect(r.allEager, isNull);
      expect(r.allLazy, isNull);
      expect(r.allowEntityFetch, isFalse);
      expect(r.allowReadFile, isFalse);
      expect(r.mergeTolerant, isFalse);
      expect(r.eagerEntityTypes, isNull);
      expect(r.lazyEntityTypes, isNull);
      expect(r.isEagerEntityType(User), isFalse);
      expect(r.isLazyEntityType(User), isFalse);
      expect(r.isEagerEntityTypeInfo(TypeInfo.fromType(User)), isFalse);
      expect(r.isLazyEntityTypeInfo(TypeInfo.fromType(User)), isFalse);
      expect(r.isAnyEagerEntityType([User]), isFalse);
      expect(r.isAnyEagerEntityTypeInfo([TypeInfo.fromType(User)]), isFalse);
      expect(r.isAnyLazyEntityType([User]), isFalse);
      expect(r.isAnyLazyEntityTypeInfo([TypeInfo.fromType(User)]), isFalse);
      expect(r.toJson(), isEmpty);
      expect(r.toString(), equals('EntityResolutionRules{innocuous}'));

      var cp = r.copyWith(
        lazyEntityTypes: [User, Address],
        eagerEntityTypes: [Role, Address],
        conflictingEntityTypes: [Address],
      );
      expect(cp.lazyEntityTypes, equals([User]));
      expect(cp.eagerEntityTypes, equals([Role]));

      var cp2 = r.copyWith(lazyEntityTypes: [], allowReadFile: true);
      expect(cp2.lazyEntityTypes, isNull);
      expect(cp2.allowReadFile, isTrue);

      expect(r.merge(null), same(r));
      expect(r.merge(EntityResolutionRules()), same(r));
      var other = EntityResolutionRules.fetchEager([User]);
      expect(r.merge(other), same(other));

      // `validate` of a merge with the innocuous (`_validateImpl`):
      var resolved = EntityResolutionRulesResolved(
        r,
        contextRules: null,
        rules: r,
      );
      expect(resolved.isValid, isTrue);
    });

    test('EntityResolutionRulesResolved', () {
      var rules = EntityResolutionRules(
        allowReadFile: true,
        mergeTolerant: true,
        eagerEntityTypes: [User],
        lazyEntityTypes: [Address],
      );

      var r = EntityResolutionRulesResolved(
        rules,
        contextRules: null,
        rules: rules,
      );

      expect(r.isInnocuous, isFalse);
      expect(r.isValid, isTrue);
      r.validate();
      expect(r.allowEntityFetch, isTrue);
      expect(r.allowReadFile, isTrue);
      expect(r.mergeTolerant, isTrue);
      expect(r.allEager, isNull);
      expect(r.allLazy, isNull);
      expect(r.eagerEntityTypes, equals([User]));
      expect(r.lazyEntityTypes, equals([Address]));
      expect(r.isEagerEntityType(User), isTrue);
      expect(r.isEagerEntityTypeInfo(TypeInfo.fromType(User)), isTrue);
      expect(r.isLazyEntityType(Address), isTrue);
      expect(r.isLazyEntityTypeInfo(TypeInfo.fromType(Address)), isTrue);
      expect(r.isAnyEagerEntityType([User]), isTrue);
      expect(r.isAnyEagerEntityTypeInfo([TypeInfo.fromType(User)]), isTrue);
      expect(r.isAnyLazyEntityType([Address]), isTrue);
      expect(r.isAnyLazyEntityTypeInfo([TypeInfo.fromType(Address)]), isTrue);

      var cp = r.copyWith(allEager: true);
      expect(cp.allEager, isTrue);
      expect(cp.eagerEntityTypes, equals([User]));

      var m = r.merge(EntityResolutionRules(allowReadFile: true));
      expect(m.allowReadFile, isTrue);

      expect(r.toString(), endsWith('[resolved]'));
      expect(r.toString(), contains('allowReadFile'));
      expect(r.toJson(), equals(rules.toJson()));

      // Conflicting resolved rules:
      var conflicting = EntityResolutionRulesResolved(
        EntityResolutionRules(
          eagerEntityTypes: [User],
          lazyEntityTypes: [User],
        ),
        contextRules: null,
        rules: null,
      );
      expect(conflicting.isValid, isFalse);
      expect(
        () => conflicting.validate(),
        throwsA(isA<ValidateEntityRulesError>()),
      );

      // Merging with a resolved instance uses its private getters:
      var m2 = EntityResolutionRules.fetchEager([Role]).merge(r);
      expect(m2.eagerEntityTypes, equals([Role, User]));
      expect(m2.lazyEntityTypes, equals([Address]));
    });
  });

  group('EntityRulesResolver', () {
    test('multiple context providers', () {
      var resolver = _Resolver();

      expect(resolver.getContextEntityResolutionRules(), isNull);

      var p1 = _ContextProvider(EntityResolutionRules.fetchEager([User]));
      var p2 = _ContextProvider(EntityResolutionRules.fetchLazy([Address]));
      var p3 = _ContextProvider(null);

      expect(EntityRulesResolver.registerContextProvider(p1), isTrue);
      expect(EntityRulesResolver.registerContextProvider(p2), isTrue);
      expect(EntityRulesResolver.registerContextProvider(p3), isTrue);

      try {
        expect(EntityRulesResolver.cotextProviders.length, equals(3));

        var context = resolver.getContextEntityResolutionRules()!;
        expect(context.eagerEntityTypes, equals([User]));
        expect(context.lazyEntityTypes, equals([Address]));
        expect(p1.calls, equals(1));
        expect(p2.calls, equals(1));
        expect(p3.calls, equals(1));

        // Resolve innocuous rules with context:
        var r1 = resolver.resolveEntityResolutionRules(
          EntityResolutionRules.innocuous,
        );
        expect(r1.contextRules, isNotNull);
        expect(r1.rules, same(EntityResolutionRules.innocuous));
        expect(r1.eagerEntityTypes, equals([User]));

        // Resolve null with context:
        var r2 = resolver.resolveEntityResolutionRules(null);
        expect(r2.rules, isNull);
        expect(r2.lazyEntityTypes, equals([Address]));

        // Resolve rules with context (merge):
        var r3 = resolver.resolveEntityResolutionRules(
          EntityResolutionRules.fetchEager([Role]),
        );
        expect(r3.eagerEntityTypes, containsAll([User, Role]));
      } finally {
        EntityRulesResolver.unregisterContextProvider(p1);
        EntityRulesResolver.unregisterContextProvider(p2);
        EntityRulesResolver.unregisterContextProvider(p3);
      }

      expect(EntityRulesResolver.cotextProviders, isEmpty);
    });

    test('resolved context provider', () {
      var resolver = _Resolver();

      var ctxRules = EntityResolutionRules.fetchEager([User]);
      var resolvedCtx = EntityResolutionRulesResolved(
        ctxRules,
        contextRules: ctxRules,
        rules: null,
      );

      var p1 = _ContextProvider(resolvedCtx);
      EntityRulesResolver.registerContextProvider(p1);

      try {
        expect(resolver.resolveEntityResolutionRules(null), same(resolvedCtx));

        var r = resolver.resolveEntityResolutionRules(
          EntityResolutionRules.fetchLazy([Address]),
        );
        expect(r.eagerEntityTypes, equals([User]));
        expect(r.lazyEntityTypes, equals([Address]));

        // A resolved rule with the same context:
        var sameCtx = EntityResolutionRulesResolved(
          EntityResolutionRules.fetchLazy([Role]),
          contextRules: ctxRules,
          rules: EntityResolutionRules.fetchLazy([Role]),
        );
        expect(resolver.resolveEntityResolutionRules(sameCtx), same(sameCtx));

        // A resolved rule with another context:
        var otherCtx = EntityResolutionRulesResolved(
          EntityResolutionRules.fetchLazy([Role]),
          contextRules: EntityResolutionRules.fetchLazy([Store]),
          rules: EntityResolutionRules.fetchLazy([Role]),
        );
        var r2 = resolver.resolveEntityResolutionRules(otherCtx);
        expect(r2.lazyEntityTypes, equals([Role]));
        expect(r2.eagerEntityTypes, equals([User]));
      } finally {
        EntityRulesResolver.unregisterContextProvider(p1);
      }

      // No context:
      var resolvedNoCtx = EntityResolutionRulesResolved(
        ctxRules,
        contextRules: null,
        rules: ctxRules,
      );
      expect(
        resolver.resolveEntityResolutionRules(resolvedNoCtx),
        same(resolvedNoCtx),
      );
      expect(resolver.resolveEntityResolutionRules(null).isInnocuous, isTrue);
      expect(
        resolver.resolveEntityResolutionRules(ctxRules).eagerEntityTypes,
        equals([User]),
      );
    });
  });
}

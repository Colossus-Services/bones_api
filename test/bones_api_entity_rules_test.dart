import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

void main() {
  group('EntityAccessRules', () {
    testInnocuous(EntityAccessRules r1) {
      expect(r1.isInnocuous, isTrue);
      expect(r1.isValid, isTrue);
      expect(r1.ruleType, isNull);
      expect(r1.entityType, isNull);
      expect(r1.entityFields, anyOf(isNull, isEmpty));
      expect(r1.rules, anyOf(isNull, isEmpty));
      expect(r1.condition, isNull);
      r1.validate();
      expect(r1.toString(), equals('EntityAccessRules{innocuous}'));

      expect(r1.isAllowedEntityType(User), isNull);
      expect(r1.isAllowedEntityTypeField(User, 'email'), isNull);
      expect(r1.simplified(), equals(EntityAccessRules.innocuous));
      expect(r1.simplified().isInnocuous, isTrue);

      expect(r1.hasRuleForEntityTypeField(User), isFalse);
      expect(r1.hasRuleForEntityTypeField(Account), isFalse);

      expect(r1.toJson(), equals({}));

      expect(r1.merge(EntityAccessRules.innocuous).isInnocuous, isTrue);
      expect(r1.copyWith().isInnocuous, isTrue);

      var r2 = r1.copyWith(entityType: User);
      expect(r2.isInnocuous, isFalse);
      expect(r2.entityType, equals(User));
      expect(r1.entityFields, anyOf(isNull, isEmpty));
      expect(r1.rules, anyOf(isNull, isEmpty));
      expect(r1.condition, isNull);

      expect(r2.toString(), equals('EntityAccessRules{entityType: User}'));

      var r3 = r1.merge(r2);
      expect(r3.isInnocuous, isFalse);
      expect(r3.entityType, equals(User));
      expect(r3.entityFields, anyOf(isNull, isEmpty));
      expect(r3.rules, anyOf(isNull, isEmpty));
      expect(r3.condition, isNull);

      var r4 = r2.merge(r1);
      expect(r4.entityType, equals(User));
      expect(r4.entityFields, anyOf(isNull, isEmpty));
      expect(r4.rules, anyOf(isNull, isEmpty));
      expect(r4.condition, isNull);
    }

    test('empty', () => testInnocuous(EntityAccessRules()));

    test('innocuous', () => testInnocuous(EntityAccessRules.innocuous));

    test('isInnocuous', () {
      expect(EntityAccessRules().isInnocuous, isTrue);

      expect(EntityAccessRules.block(User).isInnocuous, isFalse);
      expect(EntityAccessRules.allow(User).isInnocuous, isFalse);
      expect(EntityAccessRules.mask(User).isInnocuous, isFalse);

      expect(
          EntityAccessRules.group([EntityAccessRules.block(User)]).isInnocuous,
          isFalse);

      expect(
          EntityAccessRules.group([EntityAccessRules.mask(Account)])
              .isInnocuous,
          isFalse);

      expect(
          EntityAccessRules.group([
            EntityAccessRules.block(User),
            EntityAccessRules.block(Account),
            EntityAccessRules.mask(Account)
          ]).isInnocuous,
          isFalse);

      expect(EntityAccessRules.group([]).simplified().isInnocuous, isTrue);
    });

    test('block', () {
      var r1 = EntityAccessRules.block(User);

      expect(r1.isInnocuous, isFalse);
      expect(r1.ruleType, equals(EntityAccessRuleType.block));
      expect(r1.entityType, equals(User));
      expect(r1.entityFields, anyOf(isNull, isEmpty));

      expect(r1.hasRuleForEntityType(User), isTrue);
      expect(r1.hasRuleForEntityType(Account), isFalse);

      expect(r1.hasRuleForEntityTypeField(User), isFalse);
      expect(r1.hasRuleForEntityTypeField(Account), isFalse);

      expect(r1.isAllowedEntityType(User), isFalse);
      expect(r1.isAllowedEntityType(Account), isNull);
    });

    test('allow', () {
      var r1 = EntityAccessRules.allow(User);

      expect(r1.isInnocuous, isFalse);
      expect(r1.ruleType, equals(EntityAccessRuleType.allow));
      expect(r1.entityType, equals(User));
      expect(r1.entityFields, anyOf(isNull, isEmpty));

      expect(r1.hasRuleForEntityType(User), isTrue);
      expect(r1.hasRuleForEntityType(Account), isFalse);

      expect(r1.hasRuleForEntityTypeField(User), isFalse);
      expect(r1.hasRuleForEntityTypeField(Account), isFalse);

      expect(r1.isAllowedEntityType(User), isTrue);
      expect(r1.isAllowedEntityType(Account), isNull);
    });

    test('mask', () {
      var r1 = EntityAccessRules.mask(User);

      expect(r1.isInnocuous, isFalse);
      expect(r1.ruleType, equals(EntityAccessRuleType.mask));
      expect(r1.entityType, equals(User));
      expect(r1.entityFields, anyOf(isNull, isEmpty));

      expect(r1.hasRuleForEntityType(User), isTrue);
      expect(r1.hasRuleForEntityType(Account), isFalse);

      expect(r1.hasRuleForEntityTypeField(User), isFalse);
      expect(r1.hasRuleForEntityTypeField(Account), isFalse);

      expect(r1.isAllowedEntityType(User), isTrue);
      expect(r1.isAllowedEntityType(Account), isNull);
    });

    test('blockFields', () {
      var r1 = EntityAccessRules.blockFields(User, ['email', 'password']);

      expect(r1.isInnocuous, isFalse);
      expect(r1.ruleType, equals(EntityAccessRuleType.block));
      expect(r1.entityType, equals(User));
      expect(r1.entityFields, equals(['email', 'password']));

      expect(r1.hasRuleForEntityType(User), isTrue);
      expect(r1.hasRuleForEntityType(Account), isFalse);
      expect(r1.hasRuleForEntityType(Address), isFalse);

      expect(r1.hasRuleForEntityTypeField(User), isTrue);
      expect(r1.hasRuleForEntityTypeField(Account), isFalse);
      expect(r1.hasRuleForEntityTypeField(Address), isFalse);

      expect(r1.isAllowedEntityType(User), isTrue);
      expect(r1.isAllowedEntityType(Account), isNull);

      expect(r1.isAllowedEntityTypeField(User, 'email'), isFalse);
      expect(r1.isAllowedEntityTypeField(User, 'password'), isFalse);
      expect(r1.isAllowedEntityTypeField(User, 'address'), isNull);

      expect(r1.isAllowedEntityTypeField(Account, 'user'), isNull);
      expect(r1.isAllowedEntityTypeField(Account, 'userInfo'), isNull);
    });

    test('allowFields', () {
      var r1 = EntityAccessRules.allowFields(User, ['email', 'password']);

      expect(r1.isInnocuous, isFalse);
      expect(r1.ruleType, equals(EntityAccessRuleType.allow));
      expect(r1.entityType, equals(User));
      expect(r1.entityFields, equals(['email', 'password']));

      expect(r1.hasRuleForEntityType(User), isTrue);
      expect(r1.hasRuleForEntityType(Account), isFalse);
      expect(r1.hasRuleForEntityType(Address), isFalse);

      expect(r1.hasRuleForEntityTypeField(User), isTrue);
      expect(r1.hasRuleForEntityTypeField(Account), isFalse);
      expect(r1.hasRuleForEntityTypeField(Address), isFalse);

      expect(r1.isAllowedEntityType(User), isTrue);
      expect(r1.isAllowedEntityType(Account), isNull);

      expect(r1.isAllowedEntityTypeField(User, 'email'), isTrue);
      expect(r1.isAllowedEntityTypeField(User, 'password'), isTrue);
      expect(r1.isAllowedEntityTypeField(User, 'address'), isNull);

      expect(r1.isAllowedEntityTypeField(Account, 'user'), isNull);
      expect(r1.isAllowedEntityTypeField(Account, 'userInfo'), isNull);
    });

    testMaskFields(bool cached) {
      var r1 = EntityAccessRules.maskFields(User, ['email', 'password']);

      if (cached) {
        r1 = r1.cached;
      }

      expect(r1.isInnocuous, isFalse);
      expect(r1.ruleType, equals(EntityAccessRuleType.mask));
      expect(r1.entityType, equals(User));
      expect(r1.entityFields, equals(['email', 'password']));

      expect(r1.hasRuleForEntityType(User), isTrue);
      expect(r1.hasRuleForEntityType(Account), isFalse);
      expect(r1.hasRuleForEntityType(Address), isFalse);

      expect(r1.hasRuleForEntityTypeField(User), isTrue);
      expect(r1.hasRuleForEntityTypeField(Account), isFalse);
      expect(r1.hasRuleForEntityTypeField(Address), isFalse);

      expect(r1.isAllowedEntityType(User), isTrue);
      expect(r1.isAllowedEntityType(Account), isNull);

      expect(r1.isAllowedEntityTypeField(User, 'email'), isNull);
      expect(r1.isAllowedEntityTypeField(User, 'password'), isNull);
      expect(r1.isAllowedEntityTypeField(User, 'address'), isNull);

      expect(r1.isAllowedEntityTypeField(Account, 'user'), isNull);
      expect(r1.isAllowedEntityTypeField(Account, 'userInfo'), isNull);

      expect(r1.isMaskedEntityTypeField(User, 'email'), isTrue);
      expect(r1.isMaskedEntityTypeField(User, 'password'), isTrue);
      expect(r1.isMaskedEntityTypeField(User, 'address'), isNull);

      expect(r1.isMaskedEntityTypeField(Account, 'user'), isNull);
      expect(r1.isMaskedEntityTypeField(Account, 'userInfo'), isNull);
    }

    test('maskFields', () => testMaskFields(false));

    test('maskFields (cached)', () => testMaskFields(true));

    void testBlockFields(bool cached) {
      var r1 = EntityAccessRules.group([
        EntityAccessRules.blockFields(User, ['password']),
        EntityAccessRules.blockFields(User, ['email'], condition: (context) {
          var apiRequest = context?.contextAs<APIRequest>();
          var o = context?.object;

          if (o is User) {
            var username = apiRequest?.credential?.username;
            var sameAccount = username == o.email;
            return !sameAccount;
          } else {
            return true;
          }
        }),
      ]);

      if (cached) {
        r1 = r1.cached;
      }

      expect(r1.isInnocuous, isFalse);

      var user1 = User('joe@mail.com', '123456',
          Address('NY', 'New York', 'Street A', 101), [],
          id: 101);

      var user2 = User('smith@mail.com', '654321',
          Address('NY', 'New York', 'Street A', 102), [],
          id: 102);

      var apiRequest = APIRequest(APIRequestMethod.GET, '/foo',
          credential: APICredential('joe@mail.com'));

      User$reflection.boot();

      var j0 = Json.toJson(user1) as Map;

      expect(j0['id'], equals(101));
      expect(j0['email'], equals(user1.email));
      expect(j0['password'], equals(user1.password));

      var j1 = Json.toJson(
        user1,
        toEncodableProvider: (o) => r1.toJsonEncodable(
            apiRequest, Json.defaultToEncodableJsonProvider(), o),
      ) as Map;

      expect(j1['id'], equals(101));
      expect(j1['email'], equals(user1.email));
      expect(j1['password'], isNull);

      var j2 = Json.toJson(
        user2,
        toEncodableProvider: (o) => r1.toJsonEncodable(
            apiRequest, Json.defaultToEncodableJsonProvider(), o),
      ) as Map;

      expect(j2['id'], equals(102));
      expect(j2['email'], isNull);
      expect(j2['password'], isNull);
    }

    test('blockFields(condition) + toJsonEncodable',
        () => testBlockFields(false));

    test('blockFields(condition) + toJsonEncodable (cached)',
        () => testBlockFields(true));

    void testMaskFieldsJson(bool cached) {
      var r1 = EntityAccessRules.group([
        EntityAccessRules.blockFields(User, ['password']),
        EntityAccessRules.maskFields(User, ['email'], condition: (context) {
          var apiRequest = context?.contextAs<APIRequest>();
          var o = context?.object;

          if (o is User) {
            var username = apiRequest?.credential?.username;
            var sameAccount = username == o.email;
            return !sameAccount;
          } else {
            return true;
          }
        }, masker: (context, object, field, value) {
          switch (field) {
            case 'email':
              return '@';
            default:
              return value;
          }
        }),
      ]);

      expect(r1.isInnocuous, isFalse);

      var user1 = User('joe@mail.com', '123456',
          Address('NY', 'New York', 'Street A', 101), [],
          id: 101);

      var user2 = User('smith@mail.com', '654321',
          Address('NY', 'New York', 'Street A', 102), [],
          id: 102);

      var apiRequest = APIRequest(APIRequestMethod.GET, '/foo',
          credential: APICredential('joe@mail.com'));

      User$reflection.boot();

      var j0 = Json.toJson(user1) as Map;

      expect(j0['id'], equals(101));
      expect(j0['email'], equals(user1.email));
      expect(j0['password'], equals(user1.password));

      var j1 = Json.toJson(
        user1,
        toEncodableProvider: (o) => r1.toJsonEncodable(
            apiRequest, Json.defaultToEncodableJsonProvider(), o),
      ) as Map;

      expect(j1['id'], equals(101));
      expect(j1['email'], equals(user1.email));
      expect(j1['password'], isNull);

      var j2 = Json.toJson(
        user2,
        toEncodableProvider: (o) => r1.toJsonEncodable(
            apiRequest, Json.defaultToEncodableJsonProvider(), o),
      ) as Map;

      expect(j2['id'], equals(102));
      expect(j2['email'], equals('@'));
      expect(j2['password'], isNull);
    }

    test('maskFields(condition) + toJsonEncodable',
        () => testMaskFieldsJson(false));

    test('maskFields(condition) + toJsonEncodable (cached)',
        () => testMaskFieldsJson(true));

    void testMaskFieldsSubgroupJson(bool cached) {
      var r1 = EntityAccessRules.group([
        EntityAccessRules.blockFields(User, ['password']),
        EntityAccessRules.group([
          EntityAccessRules.maskFields(User, ['email'], condition: (context) {
            var apiRequest = context?.contextAs<APIRequest>();
            var o = context?.object;

            if (o is User) {
              var username = apiRequest?.credential?.username;
              var sameAccount = username == o.email;
              return !sameAccount;
            } else {
              return true;
            }
          }, masker: (context, object, field, value) {
            switch (field) {
              case 'email':
                return '@';
              default:
                return value;
            }
          })
        ]),
      ]);

      expect(r1.isInnocuous, isFalse);

      var user1 = User('joe@mail.com', '123456',
          Address('NY', 'New York', 'Street A', 101), [],
          id: 101);

      var user2 = User('smith@mail.com', '654321',
          Address('NY', 'New York', 'Street A', 102), [],
          id: 102);

      var apiRequest = APIRequest(APIRequestMethod.GET, '/foo',
          credential: APICredential('joe@mail.com'));

      User$reflection.boot();

      var j0 = Json.toJson(user1) as Map;

      expect(j0['id'], equals(101));
      expect(j0['email'], equals(user1.email));
      expect(j0['password'], equals(user1.password));

      var j1 = Json.toJson(
        user1,
        toEncodableProvider: (o) => r1.toJsonEncodable(
            apiRequest, Json.defaultToEncodableJsonProvider(), o),
      ) as Map;

      expect(j1['id'], equals(101));
      expect(j1['email'], equals(user1.email));
      expect(j1['password'], isNull);

      var j2 = Json.toJson(
        user2,
        toEncodableProvider: (o) => r1.toJsonEncodable(
            apiRequest, Json.defaultToEncodableJsonProvider(), o),
      ) as Map;

      expect(j2['id'], equals(102));
      expect(j2['email'], equals('@'));
      expect(j2['password'], isNull);
    }

    test('maskFields(condition,subgroup) + toJsonEncodable',
        () => testMaskFieldsSubgroupJson(false));

    test('maskFields(condition,subgroup) + toJsonEncodable (cached)',
        () => testMaskFieldsSubgroupJson(true));

    test('group: blockFields', () {
      var r1 = EntityAccessRules.group([
        EntityAccessRules.blockFields(User, ['email', 'password']),
        EntityAccessRules.blockFields(Account, ['user'])
      ]);

      expect(r1.isInnocuous, isFalse);
      expect(r1.ruleType, isNull);
      expect(r1.entityType, isNull);
      expect(r1.entityFields, isNull);
      expect(r1.rules?.length, equals(2));

      expect(r1.hasRuleForEntityType(User), isTrue);
      expect(r1.hasRuleForEntityType(Account), isTrue);
      expect(r1.hasRuleForEntityType(Address), isFalse);

      expect(r1.hasRuleForEntityTypeField(User), isTrue);
      expect(r1.hasRuleForEntityTypeField(Account), isTrue);

      expect(r1.isAllowedEntityType(User), isTrue);
      expect(r1.isAllowedEntityType(Account), isTrue);

      expect(r1.isAllowedEntityTypeField(User, 'email'), isFalse);
      expect(r1.isAllowedEntityTypeField(User, 'password'), isFalse);
      expect(r1.isAllowedEntityTypeField(User, 'address'), isNull);

      expect(r1.isAllowedEntityTypeField(Account, 'user'), isFalse);
      expect(r1.isAllowedEntityTypeField(Account, 'userInfo'), isNull);

      expect(r1.isMaskedEntityTypeField(Account, 'user'), isNull);
    });

    test('group: allowFields', () {
      var r1 = EntityAccessRules.group([
        EntityAccessRules.allowFields(User, ['email', 'password']),
        EntityAccessRules.allowFields(Account, ['user'])
      ]);

      expect(r1.isInnocuous, isFalse);
      expect(r1.ruleType, isNull);
      expect(r1.entityType, isNull);
      expect(r1.entityFields, isNull);
      expect(r1.rules?.length, equals(2));

      expect(r1.hasRuleForEntityType(User), isTrue);
      expect(r1.hasRuleForEntityType(Account), isTrue);
      expect(r1.hasRuleForEntityType(Address), isFalse);

      expect(r1.hasRuleForEntityTypeField(User), isTrue);
      expect(r1.hasRuleForEntityTypeField(Account), isTrue);

      expect(r1.isAllowedEntityType(User), isTrue);
      expect(r1.isAllowedEntityType(Account), isTrue);

      expect(r1.isAllowedEntityTypeField(User, 'email'), isTrue);
      expect(r1.isAllowedEntityTypeField(User, 'password'), isTrue);
      expect(r1.isAllowedEntityTypeField(User, 'address'), isNull);

      expect(r1.isAllowedEntityTypeField(Account, 'user'), isTrue);
      expect(r1.isAllowedEntityTypeField(Account, 'userInfo'), isNull);
    });

    test('group -> simplified', () {
      var r1 = EntityAccessRules.group([
        EntityAccessRules.blockFields(User, ['email', 'password']),
      ]);

      expect(r1.isInnocuous, isFalse);
      expect(r1.ruleType, isNull);
      expect(r1.entityType, isNull);
      expect(r1.entityFields, isNull);
      expect(r1.rules?.length, equals(1));

      expect(r1.hasRuleForEntityType(User), isTrue);
      expect(r1.hasRuleForEntityType(Account), isFalse);
      expect(r1.hasRuleForEntityType(Address), isFalse);

      expect(r1.hasRuleForEntityTypeField(User), isTrue);
      expect(r1.hasRuleForEntityTypeField(Account), isFalse);

      expect(r1.isAllowedEntityType(User), isTrue);
      expect(r1.isAllowedEntityType(Account), isNull);

      expect(r1.isAllowedEntityTypeField(User, 'email'), isFalse);
      expect(r1.isAllowedEntityTypeField(User, 'password'), isFalse);
      expect(r1.isAllowedEntityTypeField(User, 'address'), isNull);

      expect(r1.isAllowedEntityTypeField(Account, 'user'), isNull);
      expect(r1.isAllowedEntityTypeField(Account, 'userInfo'), isNull);

      {
        var r2 = r1.simplified();
        expect(r2.isInnocuous, isFalse);
        expect(r2.ruleType, equals(EntityAccessRuleType.block));
        expect(r2.entityType, equals(User));
        expect(r2.entityFields, equals(['email', 'password']));
        expect(r2.rules, isNull);

        expect(r2.hasRuleForEntityType(User), isTrue);
        expect(r2.hasRuleForEntityType(Account), isFalse);
        expect(r2.hasRuleForEntityType(Address), isFalse);

        expect(r2.hasRuleForEntityTypeField(User), isTrue);
        expect(r2.hasRuleForEntityTypeField(Account), isFalse);

        expect(r2.isAllowedEntityType(User), isTrue);
        expect(r2.isAllowedEntityType(Account), isNull);

        expect(r2.isAllowedEntityTypeField(User, 'email'), isFalse);
        expect(r2.isAllowedEntityTypeField(User, 'password'), isFalse);
        expect(r2.isAllowedEntityTypeField(User, 'address'), isNull);

        expect(r2.isAllowedEntityTypeField(Account, 'user'), isNull);
        expect(r2.isAllowedEntityTypeField(Account, 'userInfo'), isNull);
      }
    });

    test('merge', () {
      var r1 = EntityAccessRules.blockFields(User, ['email', 'password']);
      var r2 = EntityAccessRules.allowFields(Account, ['user']);

      var r3 = r1.merge(r2);

      expect(r3.isInnocuous, isFalse);
      expect(r3.ruleType, isNull);
      expect(r3.entityType, isNull);
      expect(r3.entityFields, isNull);
      expect(r3.rules?.length, equals(2));

      expect(r3.rules?[0].ruleType, equals(EntityAccessRuleType.block));
      expect(r3.rules?[1].ruleType, equals(EntityAccessRuleType.allow));
    });
  });

  group('EntityResolutionRules', () {
    testInnocuous(EntityResolutionRules r1) {
      expect(r1.isInnocuous, isTrue);
      expect(r1.isValid, isTrue);
      expect(r1.allEager, isNull);
      expect(r1.allLazy, isNull);
      expect(r1.allowEntityFetch, isFalse);
      expect(r1.allowReadFile, isFalse);
      expect(r1.eagerEntityTypes, anyOf(isNull, isEmpty));
      expect(r1.lazyEntityTypes, anyOf(isNull, isEmpty));
      r1.validate();
      expect(r1.toString(), equals('EntityResolutionRules{innocuous}'));

      expect(r1.isLazyEntityType(User), isFalse);
      expect(r1.isEagerEntityType(User), isFalse);

      expect(r1.isLazyEntityTypeInfo(TypeInfo.from(User)), isFalse);
      expect(r1.isEagerEntityTypeInfo(TypeInfo.from(User)), isFalse);

      expect(r1.merge(EntityResolutionRules.innocuous).isInnocuous, isTrue);
      expect(r1.copyWith().isInnocuous, isTrue);

      var r2 = r1.copyWith(allEager: true);
      expect(r2.isInnocuous, isFalse);
      expect(r2.allEager, isTrue);
      expect(r2.allLazy, isNull);
      expect(r2.allowEntityFetch, isTrue);
      expect(r2.allowReadFile, isFalse);
      expect(r2.toString(),
          equals('EntityResolutionRules{allEager: true, allowEntityFetch}'));

      var r3 = r1.merge(r2);
      expect(r3.isInnocuous, isFalse);
      expect(r3.allEager, isTrue);
      expect(r3.allEager, isTrue);
      expect(r3.allLazy, isNull);
      expect(r3.allowEntityFetch, isTrue);
      expect(r3.allowReadFile, isFalse);

      var r4 = r2.merge(r1);
      expect(r4.isInnocuous, isFalse);
      expect(r4.allEager, isTrue);
      expect(r4.allEager, isTrue);
      expect(r4.allLazy, isNull);
      expect(r4.allowEntityFetch, isTrue);
      expect(r4.allowReadFile, isFalse);
    }

    test('empty', () => testInnocuous(EntityResolutionRules()));

    test('innocuous', () => testInnocuous(EntityResolutionRules.innocuous));

    test('isInnocuous', () {
      expect(EntityResolutionRules().isInnocuous, isTrue);

      expect(EntityResolutionRules(allEager: true).isInnocuous, isFalse);
      expect(EntityResolutionRules(allLazy: true).isInnocuous, isFalse);
      expect(EntityResolutionRules(allowReadFile: true).isInnocuous, isFalse);
      expect(
          EntityResolutionRules(allowEntityFetch: true).isInnocuous, isFalse);
      expect(
          EntityResolutionRules(eagerEntityTypes: [User]).isInnocuous, isFalse);
      expect(
          EntityResolutionRules(lazyEntityTypes: [User]).isInnocuous, isFalse);

      expect(EntityResolutionRules(eagerEntityTypes: []).isInnocuous, isTrue);
      expect(EntityResolutionRules(lazyEntityTypes: []).isInnocuous, isTrue);
    });

    test('fetchEagerAll', () {
      var r1 = EntityResolutionRules.fetchEagerAll();

      expect(r1.isInnocuous, isFalse);
      expect(r1.allEager, isTrue);
      expect(r1.allLazy, isNull);
      expect(r1.allowEntityFetch, isTrue);
      expect(r1.allowReadFile, isFalse);
      expect(r1.eagerEntityTypes, isNull);
      expect(r1.lazyEntityTypes, isNull);
      expect(r1.isValid, isTrue);
      r1.validate();

      expect(r1.isEagerEntityType(User), isTrue);
      expect(r1.isEagerEntityType(Account), isTrue);

      expect(r1.isLazyEntityType(User), isFalse);
      expect(r1.isLazyEntityType(Account), isFalse);

      var r2 = r1.merge(EntityResolutionRules.fetchEager([Account]));

      expect(r2.isInnocuous, isFalse);
      expect(r2.allEager, isTrue);
      expect(r2.allLazy, isNull);
      expect(r2.allowEntityFetch, isTrue);
      expect(r2.allowReadFile, isFalse);
      expect(r2.eagerEntityTypes, equals([Account]));
      expect(r2.lazyEntityTypes, isNull);
      expect(r2.isValid, isTrue);
      r2.validate();

      expect(r2.isEagerEntityType(User), isTrue);
      expect(r2.isEagerEntityType(Account), isTrue);

      expect(r2.isLazyEntityType(User), isFalse);
      expect(r2.isLazyEntityType(Account), isFalse);

      expect(r2.isEagerEntityTypeInfo(TypeInfo.from(User)), isTrue);
      expect(r2.isEagerEntityTypeInfo(TypeInfo.from(Account)), isTrue);

      expect(r2.isLazyEntityTypeInfo(TypeInfo.from(User)), isFalse);
      expect(r2.isLazyEntityTypeInfo(TypeInfo.from(Account)), isFalse);

      var r3 = r1.merge(EntityResolutionRules.fetchLazy([Account]));

      expect(r3.isInnocuous, isFalse);
      expect(r3.allEager, isTrue);
      expect(r3.allLazy, isNull);
      expect(r3.allowEntityFetch, isTrue);
      expect(r3.allowReadFile, isFalse);
      expect(r3.eagerEntityTypes, isNull);
      expect(r3.lazyEntityTypes, equals([Account]));
      expect(r3.isValid, isTrue);
      r3.validate();

      expect(r3.isEagerEntityType(User), isTrue);
      expect(r3.isEagerEntityType(Account), isFalse);

      expect(r3.isLazyEntityType(User), isFalse);
      expect(r3.isLazyEntityType(Account), isTrue);
    });

    test('fetchLazyAll', () {
      var r1 = EntityResolutionRules.fetchLazyAll();

      expect(r1.isInnocuous, isFalse);
      expect(r1.allEager, isFalse);
      expect(r1.allLazy, isTrue);
      expect(r1.allowEntityFetch, isTrue);
      expect(r1.allowReadFile, isFalse);
      expect(r1.eagerEntityTypes, isNull);
      expect(r1.lazyEntityTypes, isNull);
      expect(r1.isValid, isTrue);
      r1.validate();

      expect(r1.isEagerEntityType(User), isFalse);
      expect(r1.isEagerEntityType(Account), isFalse);

      expect(r1.isLazyEntityType(User), isTrue);
      expect(r1.isLazyEntityType(Account), isTrue);

      expect(r1.isEagerEntityTypeInfo(TypeInfo.from(User)), isFalse);
      expect(r1.isEagerEntityTypeInfo(TypeInfo.from(Account)), isFalse);

      expect(r1.isLazyEntityTypeInfo(TypeInfo.from(User)), isTrue);
      expect(r1.isLazyEntityTypeInfo(TypeInfo.from(Account)), isTrue);

      var r2 = r1.merge(EntityResolutionRules.fetchEager([Account]));

      expect(r2.isInnocuous, isFalse);
      expect(r2.allEager, isFalse);
      expect(r2.allLazy, isTrue);
      expect(r2.allowEntityFetch, isTrue);
      expect(r2.allowReadFile, isFalse);
      expect(r2.eagerEntityTypes, equals([Account]));
      expect(r2.lazyEntityTypes, isNull);
      expect(r2.isValid, isTrue);
      r2.validate();

      expect(r2.isEagerEntityType(User), isFalse);
      expect(r2.isEagerEntityType(Account), isTrue);

      expect(r2.isLazyEntityType(User), isTrue);
      expect(r2.isLazyEntityType(Account), isFalse);

      var r3 = r1.merge(EntityResolutionRules.fetchLazy([Account]));

      expect(r3.isInnocuous, isFalse);
      expect(r3.allEager, isFalse);
      expect(r3.allLazy, isTrue);
      expect(r3.allowEntityFetch, isTrue);
      expect(r3.allowReadFile, isFalse);
      expect(r3.eagerEntityTypes, isNull);
      expect(r3.lazyEntityTypes, equals([Account]));
      expect(r3.isValid, isTrue);
      r3.validate();

      expect(r3.isEagerEntityType(User), isFalse);
      expect(r3.isEagerEntityType(Account), isFalse);

      expect(r3.isLazyEntityType(User), isTrue);
      expect(r3.isLazyEntityType(Account), isTrue);
    });

    test('fetchEager', () {
      var r1 = EntityResolutionRules.fetchEager([User]);

      expect(r1.isInnocuous, isFalse);
      expect(r1.allEager, isNull);
      expect(r1.allLazy, isNull);
      expect(r1.allowEntityFetch, isTrue);
      expect(r1.allowReadFile, isFalse);
      expect(r1.eagerEntityTypes, equals([User]));
      expect(r1.lazyEntityTypes, isNull);
      expect(r1.isValid, isTrue);
      r1.validate();

      expect(r1.isEagerEntityType(User), isTrue);
      expect(r1.isEagerEntityType(Account), isFalse);

      expect(r1.isLazyEntityType(User), isFalse);
      expect(r1.isLazyEntityType(Account), isFalse);

      var r2 = EntityResolutionRules.fetchEager([Account]);

      expect(r2.isInnocuous, isFalse);
      expect(r2.allEager, isNull);
      expect(r2.allLazy, isNull);
      expect(r2.allowEntityFetch, isTrue);
      expect(r2.allowReadFile, isFalse);
      expect(r2.eagerEntityTypes, equals([Account]));
      expect(r2.lazyEntityTypes, isNull);
      expect(r2.isValid, isTrue);
      r2.validate();

      expect(r2.isEagerEntityType(User), isFalse);
      expect(r2.isEagerEntityType(Account), isTrue);

      expect(r2.isLazyEntityType(User), isFalse);
      expect(r2.isLazyEntityType(Account), isFalse);

      var r3 = r1.merge(r2);

      expect(r3.isInnocuous, isFalse);
      expect(r3.allEager, isNull);
      expect(r3.allLazy, isNull);
      expect(r3.allowEntityFetch, isTrue);
      expect(r3.allowReadFile, isFalse);
      expect(r3.eagerEntityTypes, equals([User, Account]));
      expect(r3.lazyEntityTypes, isNull);
      expect(r3.isValid, isTrue);
      r3.validate();

      expect(r3.isEagerEntityType(User), isTrue);
      expect(r3.isEagerEntityType(Account), isTrue);

      expect(r3.isLazyEntityType(User), isFalse);
      expect(r3.isLazyEntityType(Account), isFalse);
    });

    test('fetchLazy', () {
      var r1 = EntityResolutionRules.fetchLazy([User]);

      expect(r1.isInnocuous, isFalse);
      expect(r1.allEager, isNull);
      expect(r1.allLazy, isNull);
      expect(r1.allowEntityFetch, isTrue);
      expect(r1.allowReadFile, isFalse);
      expect(r1.eagerEntityTypes, isNull);
      expect(r1.lazyEntityTypes, equals([User]));
      expect(r1.isValid, isTrue);
      r1.validate();

      expect(r1.isEagerEntityType(User), isFalse);
      expect(r1.isEagerEntityType(Account), isFalse);

      expect(r1.isLazyEntityType(User), isTrue);
      expect(r1.isLazyEntityType(Account), isFalse);

      var r2 = EntityResolutionRules.fetchLazy([Account]);

      expect(r2.isInnocuous, isFalse);
      expect(r2.allEager, isNull);
      expect(r2.allLazy, isNull);
      expect(r2.allowEntityFetch, isTrue);
      expect(r2.allowReadFile, isFalse);
      expect(r2.eagerEntityTypes, isNull);
      expect(r2.lazyEntityTypes, equals([Account]));
      expect(r2.isValid, isTrue);
      r2.validate();

      expect(r2.isEagerEntityType(User), isFalse);
      expect(r2.isEagerEntityType(Account), isFalse);

      expect(r2.isLazyEntityType(User), isFalse);
      expect(r2.isLazyEntityType(Account), isTrue);

      var r3 = r1.merge(r2);

      expect(r3.isInnocuous, isFalse);
      expect(r3.allEager, isNull);
      expect(r3.allLazy, isNull);
      expect(r3.allowEntityFetch, isTrue);
      expect(r3.allowReadFile, isFalse);
      expect(r3.eagerEntityTypes, isNull);
      expect(r3.lazyEntityTypes, equals([User, Account]));
      expect(r3.isValid, isTrue);
      r3.validate();

      expect(r3.isEagerEntityType(User), isFalse);
      expect(r3.isEagerEntityType(Account), isFalse);

      expect(r3.isLazyEntityType(User), isTrue);
      expect(r3.isLazyEntityType(Account), isTrue);
    });

    test('fetchTypes', () {
      {
        var r1 = EntityResolutionRules.fetchTypes(eagerTypes: {
          User: true,
          Account: true,
        });
        expect(r1.allLazy, isNull);
        expect(r1.allEager, isNull);
        expect(r1.allowReadFile, isFalse);
        expect(r1.mergeTolerant, isFalse);
        expect(r1.allowEntityFetch, isTrue);
        expect(r1.eagerEntityTypes, equals([User, Account]));

        var r2 = EntityResolutionRules.fetchTypes(eagerTypes: {
          [User, Account]: true,
        });
        expect(r2.allLazy, isNull);
        expect(r2.allEager, isNull);
        expect(r2.allowReadFile, isFalse);
        expect(r2.mergeTolerant, isFalse);
        expect(r2.allowEntityFetch, isTrue);
        expect(r2.eagerEntityTypes, equals([User, Account]));

        expect(r2, equals(r1));
      }

      {
        var r1 = EntityResolutionRules.fetchTypes(eagerTypes: {
          User: true,
          Account: true,
          UserInfo: false,
        });
        expect(r1.eagerEntityTypes, equals([User, Account]));
        expect(r1.lazyEntityTypes, equals([UserInfo]));

        var r2 = EntityResolutionRules.fetchTypes(eagerTypes: {
          [User, Account]: true,
          [UserInfo]: false,
        });
        expect(r2.eagerEntityTypes, equals([User, Account]));
        expect(r2.lazyEntityTypes, equals([UserInfo]));

        expect(r2, equals(r1));
      }

      {
        var r1 = EntityResolutionRules.fetchTypes(allEager: true, eagerTypes: {
          UserInfo: false,
        });
        expect(r1.eagerEntityTypes, isNull);
        expect(r1.lazyEntityTypes, equals([UserInfo]));

        var r2 = EntityResolutionRules.fetchTypes(allEager: true, eagerTypes: {
          [UserInfo]: false,
        });
        expect(r2.eagerEntityTypes, isNull);
        expect(r2.lazyEntityTypes, equals([UserInfo]));

        expect(r2, equals(r1));
      }

      {
        var r1 = EntityResolutionRules.fetchTypes(allEager: true, lazyTypes: {
          UserInfo: true,
        });
        expect(r1.eagerEntityTypes, isNull);
        expect(r1.lazyEntityTypes, equals([UserInfo]));

        var r2 = EntityResolutionRules.fetchTypes(allEager: true, lazyTypes: {
          [UserInfo]: true,
        });
        expect(r2.eagerEntityTypes, isNull);
        expect(r2.lazyEntityTypes, equals([UserInfo]));

        expect(r2, equals(r1));
      }

      {
        var r1 = EntityResolutionRules.fetchTypes(allLazy: true, eagerTypes: {
          UserInfo: true,
        });
        expect(r1.eagerEntityTypes, equals([UserInfo]));
        expect(r1.lazyEntityTypes, isNull);

        var r2 = EntityResolutionRules.fetchTypes(allLazy: true, eagerTypes: {
          [UserInfo]: true,
        });
        expect(r2.eagerEntityTypes, equals([UserInfo]));
        expect(r2.lazyEntityTypes, isNull);

        expect(r2, equals(r1));
      }

      {
        var r1 = EntityResolutionRules.fetchTypes(allLazy: true, lazyTypes: {
          UserInfo: false,
        });
        expect(r1.eagerEntityTypes, equals([UserInfo]));
        expect(r1.lazyEntityTypes, isNull);

        var r2 = EntityResolutionRules.fetchTypes(allLazy: true, lazyTypes: {
          [UserInfo]: false,
        });
        expect(r2.eagerEntityTypes, equals([UserInfo]));
        expect(r2.lazyEntityTypes, isNull);

        expect(r2, equals(r1));
      }
    });

    test('merge: fetchEager + fetchLazy', () {
      var r1 = EntityResolutionRules.fetchEager([User]);
      var r2 = EntityResolutionRules.fetchLazy([Account]);

      var r3 = r1.merge(r2);

      expect(r3.isInnocuous, isFalse);
      expect(r3.allEager, isNull);
      expect(r3.allLazy, isNull);
      expect(r3.allowEntityFetch, isTrue);
      expect(r3.allowReadFile, isFalse);
      expect(r3.eagerEntityTypes, equals([User]));
      expect(r3.lazyEntityTypes, equals([Account]));
      expect(r3.isValid, isTrue);
      r3.validate();

      expect(r3.isEagerEntityType(User), isTrue);
      expect(r3.isEagerEntityType(Account), isFalse);

      expect(r3.isLazyEntityType(User), isFalse);
      expect(r3.isLazyEntityType(Account), isTrue);
    });

    test('merge: allowReadFile 1', () {
      var r1 = EntityResolutionRules(allowReadFile: true);
      var r2 = EntityResolutionRules(allowReadFile: false);

      expect(r1.merge(r2).allowReadFile, isTrue);
      expect(r2.merge(r1).allowReadFile, isTrue);
    });

    test('merge: allowReadFile 2', () {
      var r1 = EntityResolutionRules(allowReadFile: true);
      var r2 =
          EntityResolutionRules(allowReadFile: false, eagerEntityTypes: [User]);

      expect(r1.merge(r2).allowReadFile, isTrue);
      expect(r2.merge(r1).allowReadFile, isTrue);
    });

    test('merge error 1', () {
      var r1 = EntityResolutionRules.fetchEager([User]);
      var r2 = EntityResolutionRules.fetchLazy([User]);

      expect(
          () => r1.merge(r2),
          throwsA(isA<ValidateEntityRulesError>().having(
              (e) => e.toString(),
              'toString',
              allOf(
                contains('EntityResolutionRules'),
                contains('Conflicting'),
              ))));

      expect(() => r2.merge(r1), throwsA(isA<ValidateEntityRulesError>()));
    });

    test('merge error: conflict allEager', () {
      var r1 = EntityResolutionRules(allEager: true);
      var r2 = EntityResolutionRules(allEager: false);

      expect(
          () => r1.merge(r2),
          throwsA(isA<MergeEntityRulesError>()
              .having((e) => e.conflict, 'conflict', contains('allEager'))));

      expect(
          () => r2.merge(r1),
          throwsA(isA<MergeEntityRulesError>()
              .having((e) => e.conflict, 'conflict', contains('allEager'))));
    });

    test('merge error: conflict allLazy', () {
      var r1 = EntityResolutionRules(allLazy: true);
      var r2 = EntityResolutionRules(allLazy: false);

      expect(
          () => r1.merge(r2),
          throwsA(isA<MergeEntityRulesError>()
              .having((e) => e.conflict, 'conflict', contains('allLazy'))));

      expect(
          () => r2.merge(r1),
          throwsA(isA<MergeEntityRulesError>()
              .having((e) => e.conflict, 'conflict', contains('allLazy'))));
    });

    test('merge error: conflict allowEntityFetch', () {
      var r1 = EntityResolutionRules(allowEntityFetch: true);
      var r2 = EntityResolutionRules(allowEntityFetch: false);

      expect(
          () => r1.merge(r2),
          throwsA(isA<MergeEntityRulesError>().having(
              (e) => e.conflict, 'conflict', contains('allowEntityFetch'))));

      expect(
          () => r2.merge(r1),
          throwsA(isA<MergeEntityRulesError>().having(
              (e) => e.conflict, 'conflict', contains('allowEntityFetch'))));
    });

    test('merge mergeTolerant: conflict allLazy', () {
      {
        var r1 = EntityResolutionRules(allLazy: true, mergeTolerant: true);
        var r2 = EntityResolutionRules(allLazy: false);

        expect(r1.merge(r2).allLazy, isFalse);
        expect(r2.merge(r1).allLazy, isFalse);
      }
      {
        var r1 = EntityResolutionRules(allLazy: false, mergeTolerant: true);
        var r2 = EntityResolutionRules(allLazy: true);

        expect(r1.merge(r2).allLazy, isTrue);
        expect(r2.merge(r1).allLazy, isTrue);
      }
      {
        var r1 = EntityResolutionRules(allLazy: null, mergeTolerant: true);
        var r2 = EntityResolutionRules(allLazy: false);

        expect(r1.merge(r2).allLazy, isFalse);
        expect(r2.merge(r1).allLazy, isFalse);
      }
      {
        var r1 = EntityResolutionRules(allLazy: null, mergeTolerant: true);
        var r2 = EntityResolutionRules(allLazy: true);

        expect(r1.merge(r2).allLazy, isTrue);
        expect(r2.merge(r1).allLazy, isTrue);
      }
      {
        var r1 = EntityResolutionRules(allLazy: false, mergeTolerant: true);
        var r2 = EntityResolutionRules(allLazy: true, mergeTolerant: true);

        expect(r1.merge(r2).allLazy, isNull);
        expect(r2.merge(r1).allLazy, isNull);
      }
    });

    test('merge mergeTolerant: conflict allEager', () {
      {
        var r1 = EntityResolutionRules(allEager: true, mergeTolerant: true);
        var r2 = EntityResolutionRules(allEager: false);

        expect(r1.merge(r2).allEager, isFalse);
        expect(r2.merge(r1).allEager, isFalse);
      }
      {
        var r1 = EntityResolutionRules(allEager: false, mergeTolerant: true);
        var r2 = EntityResolutionRules(allEager: true);

        expect(r1.merge(r2).allEager, isTrue);
        expect(r2.merge(r1).allEager, isTrue);
      }
      {
        var r1 = EntityResolutionRules(allEager: null, mergeTolerant: true);
        var r2 = EntityResolutionRules(allEager: false);

        expect(r1.merge(r2).allEager, isFalse);
        expect(r2.merge(r1).allEager, isFalse);
      }
      {
        var r1 = EntityResolutionRules(allEager: null, mergeTolerant: true);
        var r2 = EntityResolutionRules(allEager: true);

        expect(r1.merge(r2).allEager, isTrue);
        expect(r2.merge(r1).allEager, isTrue);
      }
      {
        var r1 = EntityResolutionRules(allEager: false, mergeTolerant: true);
        var r2 = EntityResolutionRules(allEager: true, mergeTolerant: true);

        expect(r1.merge(r2).allEager, isNull);
        expect(r2.merge(r1).allEager, isNull);
      }
    });

    test('merge mergeTolerant: conflict allowEntityFetch', () {
      {
        var r1 =
            EntityResolutionRules(allowEntityFetch: true, mergeTolerant: true);
        var r2 = EntityResolutionRules(allowEntityFetch: false);

        expect(r1.merge(r2).allowEntityFetch, isFalse);
        expect(r2.merge(r1).allowEntityFetch, isFalse);
      }
      {
        var r1 =
            EntityResolutionRules(allowEntityFetch: false, mergeTolerant: true);
        var r2 = EntityResolutionRules(allowEntityFetch: true);

        expect(r1.merge(r2).allowEntityFetch, isTrue);
        expect(r2.merge(r1).allowEntityFetch, isTrue);
      }
      {
        var r1 =
            EntityResolutionRules(allowEntityFetch: null, mergeTolerant: true);
        var r2 = EntityResolutionRules(allowEntityFetch: false);

        expect(r1.merge(r2).allowEntityFetch, isFalse);
        expect(r2.merge(r1).allowEntityFetch, isFalse);
      }
      {
        var r1 =
            EntityResolutionRules(allowEntityFetch: null, mergeTolerant: true);
        var r2 = EntityResolutionRules(allowEntityFetch: true);

        expect(r1.merge(r2).allowEntityFetch, isTrue);
        expect(r2.merge(r1).allowEntityFetch, isTrue);
      }
      {
        var r1 =
            EntityResolutionRules(allowEntityFetch: false, mergeTolerant: true);
        var r2 =
            EntityResolutionRules(allowEntityFetch: true, mergeTolerant: true);

        expect(r1.merge(r2).allowEntityFetch, isFalse);
        expect(r2.merge(r1).allowEntityFetch, isFalse);
      }
    });

    test('merge mergeTolerant: conflict eagerEntityTypes/lazyEntityTypes', () {
      {
        var r1 = EntityResolutionRules(
            eagerEntityTypes: [User], mergeTolerant: true);
        var r2 = EntityResolutionRules(lazyEntityTypes: [User]);

        expect(r1.merge(r2).eagerEntityTypes, isNull);
        expect(r1.merge(r2).lazyEntityTypes, equals([User]));

        expect(r2.merge(r1).eagerEntityTypes, isNull);
        expect(r2.merge(r1).lazyEntityTypes, equals([User]));
      }
      {
        var r1 =
            EntityResolutionRules(lazyEntityTypes: [User], mergeTolerant: true);
        var r2 = EntityResolutionRules(eagerEntityTypes: [User]);

        expect(r1.merge(r2).lazyEntityTypes, isNull);
        expect(r1.merge(r2).eagerEntityTypes, equals([User]));

        expect(r2.merge(r1).lazyEntityTypes, isNull);
        expect(r2.merge(r1).eagerEntityTypes, equals([User]));
      }
      {
        var r1 =
            EntityResolutionRules(lazyEntityTypes: [User], mergeTolerant: true);
        var r2 = EntityResolutionRules(
            eagerEntityTypes: [User], mergeTolerant: true);

        expect(r1.merge(r2).lazyEntityTypes, isNull);
        expect(r1.merge(r2).eagerEntityTypes, isNull);

        expect(r2.merge(r1).lazyEntityTypes, isNull);
        expect(r2.merge(r1).eagerEntityTypes, isNull);
      }
    });
  });
}

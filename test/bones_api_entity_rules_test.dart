import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

void main() {
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

      expect(() => r1.merge(r2),
          throwsA(isA<ValidateEntityResolutionRulesError>()));

      expect(() => r2.merge(r1),
          throwsA(isA<ValidateEntityResolutionRulesError>()));
    });

    test('merge error: conflict allEager', () {
      var r1 = EntityResolutionRules(allEager: true);
      var r2 = EntityResolutionRules(allEager: false);

      expect(
          () => r1.merge(r2),
          throwsA(isA<MergeEntityResolutionRulesError>()
              .having((e) => e.conflict, 'conflict', contains('allEager'))));

      expect(
          () => r2.merge(r1),
          throwsA(isA<MergeEntityResolutionRulesError>()
              .having((e) => e.conflict, 'conflict', contains('allEager'))));
    });

    test('merge error: conflict allLazy', () {
      var r1 = EntityResolutionRules(allLazy: true);
      var r2 = EntityResolutionRules(allLazy: false);

      expect(
          () => r1.merge(r2),
          throwsA(isA<MergeEntityResolutionRulesError>()
              .having((e) => e.conflict, 'conflict', contains('allLazy'))));

      expect(
          () => r2.merge(r1),
          throwsA(isA<MergeEntityResolutionRulesError>()
              .having((e) => e.conflict, 'conflict', contains('allLazy'))));
    });

    test('merge error: conflict allowEntityFetch', () {
      var r1 = EntityResolutionRules(allowEntityFetch: true);
      var r2 = EntityResolutionRules(allowEntityFetch: false);

      expect(
          () => r1.merge(r2),
          throwsA(isA<MergeEntityResolutionRulesError>().having(
              (e) => e.conflict, 'conflict', contains('allowEntityFetch'))));

      expect(
          () => r2.merge(r1),
          throwsA(isA<MergeEntityResolutionRulesError>().having(
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

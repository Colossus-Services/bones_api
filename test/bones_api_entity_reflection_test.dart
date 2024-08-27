import 'package:bones_api/bones_api.dart';
import 'package:test/test.dart';

import 'bones_api_test_entities.dart';

void main() {
  Json.boot();
  UserInfo$reflection.boot();

  group('EntityReference', () {
    test('toEntityReference', () {
      var t = TypeInfo<EntityReference<UserInfo>>.fromType(
          EntityReference, [TypeInfo<UserInfo>.fromType(UserInfo)]);
      expect(t.isFuture, isFalse);
      expect(t.isFutureOr, isFalse);
      expect(t.type, equals(EntityReference));
      expect(t.isEntityReferenceType, isTrue);
      expect(t.isEntityReferenceBaseType, isTrue);
      expect(t.isEntityReferenceListType, isFalse);

      var ref1 = t.arguments0!.toEntityReference(UserInfo('info 1', id: 11));
      expect(ref1.isNull, isFalse);
      expect(ref1.id, equals(11));
      expect(ref1.idNotNull, equals(11));
      expect(ref1.idAs<int>(), equals(11));
      expect(ref1.idNotNullAs<int>(), equals(11));
      expect(ref1.entity, equals(UserInfo('info 1', id: 11)));

      var ref2 = t.arguments0!.toEntityReference(null);
      expect(ref2.isNull, isTrue);
      expect(ref2.id, isNull);
      expect(ref2.entity, isNull);

      var ref3 = t.arguments0!.toEntityReference(11);
      expect(ref3.isNull, isFalse);
      expect(ref3.id, equals(11));
      expect(ref3.entity, isNull);

      var ref4 = t.arguments0!.toEntityReference({'info': 'info 2', 'id': 12});
      expect(ref4.isNull, isFalse);
      expect(ref4.id, equals(12));
      expect(ref4.entity, equals(UserInfo('info 2', id: 12)));
    });

    test('from', () {
      var ref = EntityReference.fromEntity(
          Address('NY', 'New York', 'Street 1', 123, id: 101));

      expect(ref.id, equals(101));
      expect(ref.entity, isNotNull);

      var ref1 = ref.copy(withEntity: false);
      expect(ref1.isNull, isFalse);
      expect(ref1.id, equals(101));
      expect(ref1.entity, isNull);

      ref1.set(null);

      expect(ref1.isNull, isTrue);
      expect(ref1.id, isNull);
      expect(ref1.entity, isNull);

      ref1.set(Address('NY', 'New York', 'Street 1', 124, id: 102));
      expect(ref1.isNull, isFalse);
      expect(ref1.id, equals(102));
      expect(ref1.entity, isNotNull);
    });

    test('fromJson', () {
      {
        var address = Address('NY', 'New York', 'Street 1', 123);
        var user =
            User('joe@mail.com', '123', address, [], userInfo: UserInfo('ABC'));

        var json = user.toJson();

        var user2 = User$fromJson(json);

        expect(user2.toJson(), equals(json));
      }

      {
        var address = Address('NY', 'New York', 'Street 1', 123);
        var user = User('joe@mail.com', '123', address, [],
            userInfo: UserInfo('ABC').reflection.toEntityReference());

        var json = user.toJson();

        var user2 = User$fromJson(json);

        expect(user2.toJson(), equals(json));
      }

      {
        var address = Address('NY', 'New York', 'Street 1', 123);
        var user = User('joe@mail.com', '123', address, []);

        var json = user.toJson();

        var user2 = User$fromJson(json);

        expect(user2.toJson(), equals(json));
      }

      {
        var address = Address('NY', 'New York', 'Street 1', 123);
        var user = User('joe@mail.com', '123', address, []);

        var json = user.toJson();

        var user2 = TypeInfo<User>(User).fromJson(json) as User;

        expect(user2.toJson(), equals(json));
      }

      {
        var address = Address('NY', 'New York', 'Street 1', 123);
        var user = User('joe@mail.com', '123', address, []);
        var account = Account(user, userInfo: UserInfo('ABC'));

        var json = account.toJson();

        var account2 = Account$fromJson(json);

        expect(account2.userInfo.isNull, isFalse);
        expect(account2.toJson(), equals(json));
      }

      {
        var address = Address('NY', 'New York', 'Street 1', 123);
        var user = User('joe@mail.com', '123', address, []);
        var account = Account(user);

        var json = account.toJson();

        var account2 = Account$fromJson(json);

        expect(account2.userInfo.isNull, isTrue);
        expect(account2.toJson(), equals(json));
      }

      Object? fieldValueResolver(String f, Object? v, TypeReflection t) {
        if (t.isIterableType && v is Iterable) {
          return t.typeInfo.castIterable(v);
        } else {
          return Json.fromJson(v, typeInfo: t.typeInfo);
        }
      }

      {
        var address = Address('NY', 'New York', 'Street 1', 123);
        var user = User('joe@mail.com', '123', address, []);
        var account = Account(user, userInfo: UserInfo('ABC'));

        var json = account.toJson();

        var account2 = Account$reflection.staticInstance
            .createInstanceWithConstructorByName('entityReference', json,
                fieldValueResolver: fieldValueResolver)!;

        expect(account2.userInfo.isNull, isFalse);
        expect(account2.toJson(), equals(json));
      }

      {
        var address = Address('NY', 'New York', 'Street 1', 123);
        var user = User('joe@mail.com', '123', address, []);
        var account = Account(user);

        var json = account.toJson();

        var account2 = Account$reflection.staticInstance
            .createInstanceWithConstructorByName('entityReference', json,
                fieldValueResolver: fieldValueResolver)!;

        expect(account2.userInfo.isNull, isTrue);
        expect(account2.toJson(), equals(json));
      }
    });
  });

  group('EntityReferenceList', () {
    test('toEntityReferenceList', () {
      var t = TypeInfo<EntityReferenceList<UserInfo>>.fromType(
          EntityReferenceList, [TypeInfo<UserInfo>.fromType(UserInfo)]);
      expect(t.isFuture, isFalse);
      expect(t.isFutureOr, isFalse);
      expect(t.type, equals(EntityReferenceList));
      expect(t.isEntityReferenceType, isFalse);
      expect(t.isEntityReferenceBaseType, isTrue);
      expect(t.isEntityReferenceListType, isTrue);

      var ref1 =
          t.arguments0!.toEntityReferenceList(UserInfo('info 1', id: 11));
      expect(ref1.isNull, isFalse);
      expect(ref1.ids, equals([11]));
      expect(ref1.idsNotNull, equals([11]));
      expect(ref1.idsAs<int>(), equals([11]));
      expect(ref1.idsNotNullAs<int>(), equals([11]));
      expect(ref1.entities, equals([UserInfo('info 1', id: 11)]));

      var ref2 = t.arguments0!.toEntityReferenceList(
          [UserInfo('info 1', id: 11), UserInfo('info 2', id: 12)]);
      expect(ref2.isNull, isFalse);
      expect(ref2.ids, equals([11, 12]));
      expect(ref2.entities,
          equals([UserInfo('info 1', id: 11), UserInfo('info 2', id: 12)]));

      var ref3 = t.arguments0!.toEntityReferenceList(null);
      expect(ref3.isNull, isTrue);
      expect(ref3.ids, isNull);
      expect(ref3.entities, isNull);

      var ref4 = t.arguments0!.toEntityReferenceList(11);
      expect(ref4.isNull, isFalse);
      expect(ref4.ids, equals([11]));
      expect(ref4.entities, isNull);

      var ref5 = t.arguments0!.toEntityReferenceList([11, 12]);
      expect(ref5.isNull, isFalse);
      expect(ref5.ids, equals([11, 12]));
      expect(ref5.entities, isNull);

      var ref6 =
          t.arguments0!.toEntityReferenceList({'info': 'info 2', 'id': 12});
      expect(ref6.isNull, isFalse);
      expect(ref6.ids, equals([12]));
      expect(ref6.entities, equals([UserInfo('info 2', id: 12)]));

      var ref7 = t.arguments0!.toEntityReferenceList([
        {'info': 'info 2', 'id': 12},
        {'info': 'info 3', 'id': 13}
      ]);
      expect(ref7.isNull, isFalse);
      expect(ref7.ids, equals([12, 13]));
      expect(ref7.entities,
          equals([UserInfo('info 2', id: 12), UserInfo('info 3', id: 13)]));
    });
  });
}

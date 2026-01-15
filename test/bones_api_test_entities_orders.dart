import 'package:bones_api/bones_api.dart';

part 'bones_api_test_entities_orders.reflection.g.dart';

final campaignEntityHandler = GenericEntityHandler<Campaign>(
  instantiatorDefault: Campaign.empty,
  instantiatorFromMap: Campaign.fromMap,
  type: Campaign,
  typeName: 'Campaign',
);

final bonusEntityHandler = GenericEntityHandler<Bonus>(
  instantiatorDefault: Bonus.empty,
  instantiatorFromMap: Bonus.fromMap,
  type: Bonus,
  typeName: 'Bonus',
);

final itemEntityHandler = GenericEntityHandler<Item>(
  instantiatorDefault: Item.empty,
  instantiatorFromMap: Item.fromMap,
  type: Item,
  typeName: 'Item',
);

final orderEntityHandler = GenericEntityHandler<Order>(
  instantiatorDefault: Order.empty,
  instantiatorFromMap: Order.fromMap,
  type: Order,
  typeName: 'Order',
);

class CampaignAPIRepository extends APIRepository<Campaign> {
  CampaignAPIRepository(EntityRepositoryProvider provider)
    : super(provider: provider);
}

class BonusAPIRepository extends APIRepository<Bonus> {
  BonusAPIRepository(EntityRepositoryProvider provider)
    : super(provider: provider);
}

class ItemAPIRepository extends APIRepository<Item> {
  ItemAPIRepository(EntityRepositoryProvider provider)
    : super(provider: provider);
}

class OrderAPIRepository extends APIRepository<Order> {
  OrderAPIRepository(EntityRepositoryProvider provider)
    : super(provider: provider);

  // convenience: select orders that reference campaign id via chain items.bonus.campaign
  FutureOr<Iterable<Order>> selectByCampaignId(int campaignId) {
    return selectByQuery(
      ' items.bonus.campaign == ? ',
      parameters: [campaignId],
    );
  }
}

@EnableReflection()
class Campaign extends Entity {
  int? id;
  String name;

  Campaign(this.name, {this.id});
  Campaign.empty() : this('');

  static FutureOr<Campaign> fromMap(Map<String, dynamic> map) =>
      Campaign(map.getAsString('name')!, id: map['id']);

  @override
  String get idFieldName => 'id';

  @JsonField.hidden()
  @override
  List<String> get fieldsNames => const ['id', 'name'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'name':
        return name as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tInt;
      case 'name':
        return TypeInfo.tString;
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
        break;
      case 'name':
        name = value as String;
        break;
      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {if (id != null) 'id': id, 'name': name};
}

@EnableReflection()
class Bonus extends Entity {
  int? id;
  // campaign is a reference to Campaign (one-to-one)
  EntityReference<Campaign> campaign;

  Bonus({Object? campaign, this.id})
    : campaign = EntityReference<Campaign>.from(campaign);

  Bonus.empty() : this();

  static FutureOr<Bonus> fromMap(Map<String, dynamic> map) =>
      Bonus(campaign: map['campaign'], id: map['id']);

  @override
  String get idFieldName => 'id';

  @JsonField.hidden()
  @override
  List<String> get fieldsNames => const ['id', 'campaign'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'campaign':
        return campaign as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tInt;
      case 'campaign':
        return TypeInfo<EntityReference<Campaign>>.fromType(EntityReference, [
          TypeInfo<Campaign>.fromType(Campaign),
        ]);
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
        break;
      case 'campaign':
        campaign = EntityReference<Campaign>.from(value);
        break;
      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'campaign': campaign.toJson(),
  };
}

@EnableReflection()
class Item extends Entity {
  int? id;
  String name;
  // bonus is a reference to Bonus (nullable)
  EntityReference<Bonus> bonus;

  Item(this.name, {Object? bonus, this.id})
    : bonus = EntityReference<Bonus>.from(bonus);

  Item.empty() : this('', bonus: null);

  static FutureOr<Item> fromMap(Map<String, dynamic> map) =>
      Item(map.getAsString('name')!, bonus: map['bonus'], id: map['id']);

  @override
  String get idFieldName => 'id';

  @JsonField.hidden()
  @override
  List<String> get fieldsNames => const ['id', 'name', 'bonus'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'name':
        return name as V?;
      case 'bonus':
        return bonus as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tInt;
      case 'name':
        return TypeInfo.tString;
      case 'bonus':
        return TypeInfo<EntityReference<Bonus>>.fromType(EntityReference, [
          TypeInfo<Bonus>.fromType(Bonus),
        ]);
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
        break;
      case 'name':
        name = value as String;
        break;
      case 'bonus':
        bonus = EntityReference<Bonus>.from(value);
        break;
      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'bonus': bonus.toJson(),
  };
}

@EnableReflection()
class Order extends Entity {
  int? id;
  String orderNumber;

  // items is an embedded list of Item objects (similar style to Address.stores)
  List<Item> items;

  Order(this.orderNumber, {List<Item>? items, this.id})
    : items = items ?? <Item>[];

  Order.empty() : this('');

  static FutureOr<Order> fromMap(Map<String, dynamic> map) => Order(
    map.getAsString('orderNumber')!,
    items: map.getAsList<Item>('items', def: <Item>[])!,
    id: map['id'],
  );

  @override
  String get idFieldName => 'id';

  @JsonField.hidden()
  @override
  List<String> get fieldsNames => const ['id', 'orderNumber', 'items'];

  @override
  V? getField<V>(String key) {
    switch (key) {
      case 'id':
        return id as V?;
      case 'orderNumber':
        return orderNumber as V?;
      case 'items':
        return items as V?;
      default:
        return null;
    }
  }

  @override
  TypeInfo? getFieldType(String key) {
    switch (key) {
      case 'id':
        return TypeInfo.tInt;
      case 'orderNumber':
        return TypeInfo.tString;
      case 'items':
        return TypeInfo<List<Item>>(List, [TypeInfo<Item>(Item)]);
      default:
        return null;
    }
  }

  @override
  void setField<V>(String key, V? value) {
    switch (key) {
      case 'id':
        id = value as int?;
        break;
      case 'orderNumber':
        orderNumber = value as String;
        break;
      case 'items':
        items = value as List<Item>;
        break;
      default:
        return;
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'orderNumber': orderNumber,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class_name ShopItem
extends Resource
## One ware on the Pale Merchant's table: a card, a relic, a full heal, or a card upgrade
## (`payload` is the CardData / RelicData / upgraded CardData; null for heal), for `price` shards.

var kind: StringName = &"card"
var payload: Resource
var price: int = 30


static func make(ware_kind: StringName, ware: Resource, cost: int) -> ShopItem:
    var item: ShopItem = ShopItem.new()
    item.kind = ware_kind
    item.payload = ware
    item.price = cost
    return item

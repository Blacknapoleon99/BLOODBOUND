class_name ItemPool
extends RefCounted
## Every item that exists. Starter items are always owned; the rest are earned as spoils.

const ALL: Array[ItemData] = [
    preload("res://resources/items/rusted_blade.tres"),
    preload("res://resources/items/bloodletter_sabre.tres"),
    preload("res://resources/items/gravecleaver.tres"),
    preload("res://resources/items/twin_fangs.tres"),
    preload("res://resources/items/penitents_flail.tres"),
    preload("res://resources/items/pilgrim_rags.tres"),
    preload("res://resources/items/ossuary_plate.tres"),
    preload("res://resources/items/shroud_of_ash.tres"),
    preload("res://resources/items/martyrs_mail.tres"),
    preload("res://resources/items/hunters_leathers.tres"),
    preload("res://resources/items/censer_locket.tres"),
    preload("res://resources/items/wolf_tooth.tres"),
    preload("res://resources/items/saints_knucklebone.tres"),
]
const STARTERS: Array[StringName] = [&"rusted_blade", &"pilgrim_rags"]


static func by_id(id: StringName) -> ItemData:
    for item: ItemData in ALL:
        if item.id == id:
            return item
    return null


## Up to `count` distinct items not in `exclude` (never starters), weighted by offer_weight.
static func offer(rng: RandomNumberGenerator, count: int, exclude: Array = []) -> Array[ItemData]:
    var candidates: Array[ItemData] = []
    for item: ItemData in ALL:
        if not exclude.has(item.id) and not STARTERS.has(item.id):
            candidates.append(item)
    var picks: Array[ItemData] = []
    while picks.size() < count and not candidates.is_empty():
        var total: float = 0.0
        for item: ItemData in candidates:
            total += item.offer_weight
        var roll: float = rng.randf() * total
        var chosen: int = candidates.size() - 1
        for i in candidates.size():
            roll -= candidates[i].offer_weight
            if roll <= 0.0:
                chosen = i
                break
        picks.append(candidates[chosen])
        candidates.remove_at(chosen)
    return picks

class_name RelicPool
extends RefCounted
## Every relic that can be offered. Add new relics here and give them an effect in main.gd.

const ALL: Array[RelicData] = [
    preload("res://resources/relics/leech_fang.tres"),
    preload("res://resources/relics/executioners_seal.tres"),
    preload("res://resources/relics/thorned_reliquary.tres"),
    preload("res://resources/relics/wraith_step.tres"),
    preload("res://resources/relics/vessel_of_plenty.tres"),
    preload("res://resources/relics/bone_ward.tres"),
    preload("res://resources/relics/penitents_rosary.tres"),
    preload("res://resources/relics/gravebloom.tres"),
]


static func by_id(id: StringName) -> RelicData:
    for relic: RelicData in ALL:
        if relic.id == id:
            return relic
    return null


## Up to `count` distinct relics not in `exclude`, weighted by offer_weight. Unlike cards,
## relics never repeat: when the pool runs dry the offer is simply shorter.
static func offer(rng: RandomNumberGenerator, count: int, exclude: Array = []) -> Array[RelicData]:
    var candidates: Array[RelicData] = []
    for relic: RelicData in ALL:
        if not exclude.has(relic.id):
            candidates.append(relic)
    var picks: Array[RelicData] = []
    while picks.size() < count and not candidates.is_empty():
        var total: float = 0.0
        for relic: RelicData in candidates:
            total += relic.offer_weight
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

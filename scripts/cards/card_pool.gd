class_name CardPool
extends RefCounted
## Every Bloodbound Card that can appear in a draft or at a Blood Altar. Add new cards here.

const ALL: Array[CardData] = [
    preload("res://resources/cards/blood_spear.tres"),
    preload("res://resources/cards/grave_shield.tres"),
    preload("res://resources/cards/ritual_chains.tres"),
    preload("res://resources/cards/hemorrhage_pact.tres"),
    preload("res://resources/cards/epitaph.tres"),
    preload("res://resources/cards/ashen_choir.tres"),
    preload("res://resources/cards/bell_of_silence.tres"),
    preload("res://resources/cards/transfusion.tres"),
]


static func by_id(id: StringName) -> CardData:
    for card: CardData in ALL:
        if card.id == id:
            return card
    return null


## `count` distinct cards, weighted by CardData.offer_weight, skipping ids in `exclude`
## (falls back to the full pool when exclusions leave too few). Deterministic for a given RNG state.
static func offer(rng: RandomNumberGenerator, count: int, exclude: Array = []) -> Array[CardData]:
    var candidates: Array[CardData] = []
    for card: CardData in ALL:
        if not exclude.has(card.id):
            candidates.append(card)
    if candidates.size() < count:
        candidates = ALL.duplicate()
    var picks: Array[CardData] = []
    while picks.size() < count and not candidates.is_empty():
        var total: float = 0.0
        for card: CardData in candidates:
            total += card.offer_weight
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

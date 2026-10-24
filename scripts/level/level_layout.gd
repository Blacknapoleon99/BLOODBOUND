class_name LevelLayout
extends RefCounted
## Chooses the run's rooms (design: docs/superpowers/specs/2026-10-21-first-map-design.md):
##   opening (fixed) → 3 Act I rooms → Gravewarden elite → 3 Act II rooms → Pale Merchant →
##   pursuit approach + Bishop (fixed).
## Seeded by the run seed, so a seed always rebuilds the same map. Inside each act the rooms run
## easiest → hardest, with one random neighbour swap so the order still varies.
## `LevelLayout.classic = true` (scripted tests) inserts no rooms: the original short layout.
##
## The 3D run is an open world instead (DEC-063, `OpenWorld`): every room of both acts, the elite
## and the merchant at once (`world_rooms`), laid out round the opening hub by the run seed.
## `plan` still deals the side view's (and co-op's) chain.

static var classic: bool = false

const ACT1: Array[Script] = [
    preload("res://scripts/level/sections/crypt_stairs.gd"),
    preload("res://scripts/level/sections/flooded_nave.gd"),
    preload("res://scripts/level/sections/ossuary_ambush.gd"),
    preload("res://scripts/level/sections/bell_tower_gap.gd"),
    preload("res://scripts/level/sections/catacomb_crawl.gd"),
]
const ACT2: Array[Script] = [
    preload("res://scripts/level/sections/collapsing_gallery.gd"),
    preload("res://scripts/level/sections/blade_corridor.gd"),
    preload("res://scripts/level/sections/wraith_belfry.gd"),
    preload("res://scripts/level/sections/charnel_arena.gd"),
    preload("res://scripts/level/sections/sunken_reliquary.gd"),
]
const ELITE: Script = preload("res://scripts/level/sections/gravewarden_hall.gd")
const MERCHANT: Script = preload("res://scripts/level/sections/pale_merchant.gd")
const ROOMS_PER_ACT: int = 3


## The ordered room scripts for a run seed (empty in classic mode).
static func plan(run_seed: int) -> Array[Script]:
    var order: Array[Script] = []
    if classic:
        return order
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = run_seed * 7919 + 17
    order.append_array(_pick(rng, ACT1))
    order.append(ELITE)
    order.append_array(_pick(rng, ACT2))
    order.append(MERCHANT)
    return order


## Every 3D room for the open world, in a fixed order (OpenWorld shuffles their places by seed):
## Act I, Act II, the elite, the merchant. Empty in classic mode.
static func world_rooms() -> Array[Script]:
    var rooms: Array[Script] = []
    if classic:
        return rooms
    rooms.append_array(ACT1)
    rooms.append_array(ACT2)
    rooms.append(ELITE)
    rooms.append(MERCHANT)
    return rooms


static func _pick(rng: RandomNumberGenerator, pool: Array[Script]) -> Array[Script]:
    var bag: Array[Script] = pool.duplicate()
    var picks: Array[Script] = []
    for i in ROOMS_PER_ACT:
        picks.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
    picks.sort_custom(func(a: Script, b: Script) -> bool: return difficulty_of(a) < difficulty_of(b))
    var swap: int = rng.randi_range(0, picks.size() - 2)
    if rng.randf() < 0.5:
        var tmp: Script = picks[swap]
        picks[swap] = picks[swap + 1]
        picks[swap + 1] = tmp
    return picks


static func difficulty_of(script: Script) -> int:
    return int(script.get_script_constant_map().get("DIFFICULTY", 1))

class_name Equipment
extends RefCounted
## Turns equipped items into attributes, and attributes into the player's numbers.
##
##   VIGOR     +1 max HP per point.
##   MIGHT     +1 damage per point on the combo finisher and heavy strike; +1 on the opening
##             jabs per 2 points.
##   AGILITY   +4% run speed, -0.02 s dodge cooldown and +0.015 s dodge i-frames per point
##             (negative Agility slows you down).
##   DEVOTION  +0.1 blood per melee hit per point; +1 max blood per 2 points.
## The weapon also sets attack speed (all melee phases scale) and may add heavy damage.

const ATTRIBUTES: Array[StringName] = [&"vigor", &"might", &"agility", &"devotion"]
## Base numbers of the player scene, for the Armory's stat preview (checked by the smoke test).
const BASE_HP: int = 5
const BASE_LIGHT: int = 1
const BASE_FINISHER: int = 2
const BASE_HEAVY: int = 2
const BASE_SPEED: float = 8.5
const BASE_DODGE_COOLDOWN: float = 0.4
const BASE_BLOOD_PER_HIT: float = 0.5
const BASE_MAX_BLOOD: float = 6.0


static func attributes(items: Array[ItemData]) -> Dictionary:
    var totals: Dictionary = {&"vigor": 0, &"might": 0, &"agility": 0, &"devotion": 0}
    for item: ItemData in items:
        totals[&"vigor"] += item.vigor
        totals[&"might"] += item.might
        totals[&"agility"] += item.agility
        totals[&"devotion"] += item.devotion
    return totals


static func weapon_of(items: Array[ItemData]) -> ItemData:
    for item: ItemData in items:
        if item.slot == ItemData.Slot.WEAPON:
            return item
    return null


## The numbers the Armory shows, from base values plus the given items.
static func derived(items: Array[ItemData]) -> Dictionary:
    var a: Dictionary = attributes(items)
    var weapon: ItemData = weapon_of(items)
    var might: int = int(a[&"might"])
    return {
        "hp": BASE_HP + int(a[&"vigor"]),
        "light": BASE_LIGHT + maxi(0, might) / 2,
        "finisher": BASE_FINISHER + maxi(0, might),
        "heavy": BASE_HEAVY + maxi(0, might) + (weapon.heavy_damage if weapon else 0),
        "attack_speed": weapon.attack_speed if weapon else 1.0,
        "speed": BASE_SPEED * (1.0 + 0.04 * int(a[&"agility"])),
        "dodge_cooldown": maxf(0.2, BASE_DODGE_COOLDOWN - 0.02 * int(a[&"agility"])),
        "blood_per_hit": BASE_BLOOD_PER_HIT + 0.1 * int(a[&"devotion"]),
        "max_blood": BASE_MAX_BLOOD + float(maxi(0, int(a[&"devotion"])) / 2),
    }


## Applies the equipped items to a freshly spawned player (main.gd calls this once per level load).
static func apply(player: Node, cards: CardSystem, items: Array[ItemData]) -> void:
    var a: Dictionary = attributes(items)
    var weapon: ItemData = weapon_of(items)
    var health: Health = player.get("health")
    var melee: MeleeAttack = player.get("melee")
    var energy: BloodEnergy = cards.energy
    var vigor: int = int(a[&"vigor"])
    if vigor != 0:
        health.max_health = maxi(1, health.max_health + vigor)
        health.restore_full()
    var might: int = maxi(0, int(a[&"might"]))
    var bonuses: Dictionary = {
        &"player_light": might / 2, &"player_light_2": might / 2,
        &"player_light_finisher": might, &"player_heavy": might + (weapon.heavy_damage if weapon else 0),
    }
    for id: StringName in bonuses:
        if int(bonuses[id]) != 0:
            melee.bonus_damage[id] = int(melee.bonus_damage.get(id, 0)) + int(bonuses[id])
    if weapon != null:
        melee.speed_scale = weapon.attack_speed
    var agility: int = int(a[&"agility"])
    if agility != 0:
        player.set("move_speed", float(player.get("move_speed")) * (1.0 + 0.04 * agility))
        player.set("dodge_cooldown", maxf(0.2, float(player.get("dodge_cooldown")) - 0.02 * agility))
        if agility > 0:
            player.set("dodge_invulnerable_time", float(player.get("dodge_invulnerable_time")) + 0.015 * agility)
    var devotion: int = int(a[&"devotion"])
    if devotion != 0:
        energy.per_hit = maxf(0.1, energy.per_hit + 0.1 * devotion)
        if devotion >= 2:
            energy.maximum += float(devotion / 2)
            energy.changed.emit(energy.current, energy.maximum)

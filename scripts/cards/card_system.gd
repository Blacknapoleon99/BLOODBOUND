class_name CardSystem
extends Node
## Plays Bloodbound Cards for the player. Every play is validated in a fixed order and only a
## fully valid play spends energy, starts the cooldown, moves the card to discard and applies
## its effect. Invalid plays change nothing and report a reason.
##
## Validation order and failure reasons:
##   &"empty"     no card in that slot
##   &"blocked"   player cannot act (dead, stunned, frozen)
##   &"cooldown"  that card's cooldown is still running
##   &"no_target" targeting rule found nothing legal (no living enemy or exposed weak point /
##                no interruptible action)
##   &"out_of_range" a target exists but is beyond the card's range
##   &"energy"    not enough blood energy
## Success returns &"ok". A press while the player is in hitstun is not a failure: it is held
## (&"queued") and played when the stun ends, as long as that is within the stun plus
## `stun_buffer_time` (the same courtesy melee attacks get).

signal card_played(card: CardData, slot: int)
signal card_failed(card: CardData, slot: int, reason: StringName)

const SLOT_ACTIONS: Array[StringName] = [&"card_1", &"card_2", &"card_3"]
## Used when no starter deck is assigned in the scene.
const DEFAULT_CARDS: Array[CardData] = [
    preload("res://resources/cards/blood_spear.tres"),
    preload("res://resources/cards/grave_shield.tres"),
    preload("res://resources/cards/ritual_chains.tres"),
]

@export var starter_cards: Array[CardData] = []
@export var deck_seed: int = 1337
@export var energy: BloodEnergy
@export var player: CharacterBody3D
@export var stun_buffer_time: float = 0.15
## 2.5D only: enemies further than this from the play plane (e.g. the Bishop's body) are not targets.
@export var plane_target_depth: float = 2.5

var deck: CardDeck = CardDeck.new()
var _cooldowns: Dictionary = {}  # card id -> seconds left
var _queued_slot: int = -1
var _queued_left: float = 0.0


func _ready() -> void:
    if starter_cards.is_empty():
        starter_cards = DEFAULT_CARDS.duplicate()
    deck.setup(starter_cards, deck_seed, SLOT_ACTIONS.size())
    var melee: MeleeAttack = player.get("melee") as MeleeAttack
    melee.hitbox.hit_landed.connect(func(_target: Hurtbox, _info: DamageInfo) -> void: energy.add(energy.per_hit))


func _physics_process(delta: float) -> void:
    for id: StringName in _cooldowns.keys():
        _cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)
    if _queued_slot >= 0:
        _queued_left -= delta
        if _queued_left <= 0.0:
            _queued_slot = -1
        elif not bool(player.call("is_stunned")):
            var slot: int = _queued_slot
            _queued_slot = -1
            play_slot(slot)


func cooldown_left(card: CardData) -> float:
    return float(_cooldowns.get(card.id, 0.0)) if card else 0.0


## UI status that does not depend on targets: &"ready", &"cooldown", &"energy", &"empty".
func slot_status(slot: int) -> StringName:
    var card: CardData = deck.card_in_slot(slot)
    if card == null:
        return &"empty"
    if cooldown_left(card) > 0.0:
        return &"cooldown"
    if not energy.can_afford(card.cost):
        return &"energy"
    return &"ready"


func play_slot(slot: int) -> StringName:
    var card: CardData = deck.card_in_slot(slot)
    if card != null and _is_only_stunned():
        _queued_slot = slot
        _queued_left = float(player.call("stun_time_left")) + stun_buffer_time
        return &"queued"
    var reason: StringName = _validate(card)
    var target: Variant = null
    if reason == &"ok":
        var found: Dictionary = _find_target(card)
        reason = found["reason"]
        target = found.get("target")
    if reason == &"ok" and not energy.can_afford(card.cost):
        reason = &"energy"
    if reason != &"ok":
        card_failed.emit(card, slot, reason)
        return reason

    energy.spend(card.cost)
    _cooldowns[card.id] = card.cooldown
    deck.play_slot(slot)
    _apply(card, target)
    card_played.emit(card, slot)
    return &"ok"


func _is_only_stunned() -> bool:
    var health: Health = player.get("health") as Health
    return bool(player.call("is_stunned")) and not health.is_dead() and not bool(player.get("game_frozen"))


func _validate(card: CardData) -> StringName:
    if card == null:
        return &"empty"
    var health: Health = player.get("health") as Health
    if health.is_dead() or bool(player.get("game_frozen")) or bool(player.call("is_stunned")):
        return &"blocked"
    if cooldown_left(card) > 0.0:
        return &"cooldown"
    return &"ok"


func _find_target(card: CardData) -> Dictionary:
    match card.targeting:
        CardData.Targeting.SELF:
            return {"reason": &"ok", "target": player}
        CardData.Targeting.BOSS_WEAK_POINT:
            var best: Hurtbox = null
            var best_distance: float = INF
            for node: Node in get_tree().get_nodes_in_group(&"weak_point"):
                var hurtbox: Hurtbox = node as Hurtbox
                var owner_node: Node = hurtbox.get_parent()
                if not hurtbox.monitorable or (owner_node.has_method("is_invulnerable") and owner_node.call("is_invulnerable")):
                    continue
                var distance: float = hurtbox.global_position.distance_to(player.global_position)
                if distance < best_distance:
                    best = hurtbox
                    best_distance = distance
            if best == null:
                return {"reason": &"no_target"}
            if best_distance > card.card_range:
                return {"reason": &"out_of_range"}
            return {"reason": &"ok", "target": best}
        CardData.Targeting.ENEMY:
            return _find_enemy_target(card.card_range)
        CardData.Targeting.BOSS_TELEGRAPH:
            for node: Node in get_tree().get_nodes_in_group(&"interruptible"):
                if node.has_method("can_be_interrupted") and node.call("can_be_interrupted"):
                    return {"reason": &"ok", "target": node}
            return {"reason": &"no_target"}
    return {"reason": &"no_target"}


## Nearest living, hittable enemy hurtbox in range. An exposed weak point anywhere in range
## wins over ordinary enemies (it is the reason to hold a spear during a boss fight).
func _find_enemy_target(card_range: float) -> Dictionary:
    var in_3d: bool = bool(player.get("in_3d_mode"))
    var nearest: Hurtbox = null
    var nearest_distance: float = INF
    var weak: Hurtbox = null
    var weak_distance: float = INF
    var any_out_of_range: bool = false
    for node: Node in get_tree().get_nodes_in_group(&"hurtboxes"):
        var hurtbox: Hurtbox = node as Hurtbox
        if hurtbox == null or hurtbox.team == &"player" or not hurtbox.monitorable:
            continue
        if hurtbox.health == null or hurtbox.health.is_dead():
            continue
        var owner_node: Node = hurtbox.get_parent()
        if owner_node.has_method("is_invulnerable") and owner_node.call("is_invulnerable"):
            continue
        var aim: Vector3 = _aim_point(hurtbox)
        if not in_3d and absf(aim.z - player.global_position.z) > plane_target_depth:
            continue
        var distance: float = aim.distance_to(player.global_position)
        if distance > card_range:
            any_out_of_range = true
            continue
        if hurtbox.is_in_group(&"weak_point") and distance < weak_distance:
            weak = hurtbox
            weak_distance = distance
        elif distance < nearest_distance:
            nearest = hurtbox
            nearest_distance = distance
    var best: Hurtbox = weak if weak != null else nearest
    if best != null:
        return {"reason": &"ok", "target": best}
    return {"reason": &"out_of_range" if any_out_of_range else &"no_target"}


func _aim_point(hurtbox: Hurtbox) -> Vector3:
    var shape: CollisionShape3D = hurtbox.get_child(0) as CollisionShape3D
    return shape.global_position if shape else hurtbox.global_position


func _apply(card: CardData, target: Variant) -> void:
    match card.effect:
        &"blood_spear":
            var aim: Vector3 = _aim_point(target as Hurtbox)
            var from: Vector3 = player.global_position + Vector3(0.0, 0.6, 0.0)
            get_tree().current_scene.add_child(BloodSpearProjectile.create(from, aim, card))
        &"grave_shield":
            player.call("raise_shield", card.blocks_category, card.duration)
        &"ritual_chains":
            target.call("interrupt_with_chains", card.duration)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_echo():
        return
    for i in SLOT_ACTIONS.size():
        if event.is_action_pressed(SLOT_ACTIONS[i]):
            play_slot(i)
            return

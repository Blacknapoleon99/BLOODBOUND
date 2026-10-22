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
##   &"not_exposed" the chosen target is currently invulnerable (e.g. the Bishop's closed stigmata)
##   &"out_of_range" a target exists but is beyond the card's range
##   &"energy"    not enough blood energy
##   &"too_weak"  the card costs HP the player cannot spare (Hemorrhage Pact)
##   &"full_health" a healing card at full health (Transfusion)
## Success returns &"ok". A press while the player is in hitstun is not a failure: it is held
## (&"queued") and played when the stun ends, as long as that is within the stun plus
## `stun_buffer_time` (the same courtesy melee attacks get).

signal card_played(card: CardData, slot: int)
signal card_failed(card: CardData, slot: int, reason: StringName)
signal deck_changed

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
## Relic modifiers (set by main.gd): cooldown multiplier, and bonus damage for Blood Spear / Epitaph.
var cooldown_scale: float = 1.0
var spell_damage_bonus: int = 0
var _cooldowns: Dictionary = {}  # card id -> seconds left
var _queued_slot: int = -1
var _queued_target: Hurtbox
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
            var had_target: bool = _queued_target != null
            var target: Hurtbox = _queued_target if is_instance_valid(_queued_target) else null
            _queued_slot = -1
            _queued_target = null
            if had_target and target == null:
                card_failed.emit(deck.card_in_slot(slot), slot, &"no_target")  # your target is gone
            else:
                play_slot(slot, target)


## This hand's input action for slot `i` (player 2's are prefixed "p2_").
func slot_action(i: int) -> StringName:
    var prefix: String = String(player.get("input_prefix")) if player != null else ""
    return StringName(prefix + String(SLOT_ACTIONS[i]))


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


## `chosen_target` (optional) is a Hurtbox the player picked, e.g. by clicking it. It is validated
## exactly like an automatic target; without it, enemy-targeting cards pick the nearest enemy.
func play_slot(slot: int, chosen_target: Hurtbox = null) -> StringName:
    var card: CardData = deck.card_in_slot(slot)
    if card != null and _is_only_stunned():
        _queued_slot = slot
        _queued_target = chosen_target
        _queued_left = float(player.call("stun_time_left")) + stun_buffer_time
        return &"queued"
    var reason: StringName = _validate(card)
    var target: Variant = null
    if reason == &"ok":
        if chosen_target == null:
            chosen_target = _locked_hurtbox(card)
        var found: Dictionary = _check_chosen_target(card, chosen_target) if chosen_target != null else _find_target(card)
        reason = found["reason"]
        target = found.get("target")
    if reason == &"ok" and not energy.can_afford(card.cost):
        reason = &"energy"
    if reason != &"ok":
        card_failed.emit(card, slot, reason)
        return reason

    energy.spend(card.cost)
    _cooldowns[card.id] = card.cooldown * cooldown_scale
    deck.play_slot(slot)
    _apply(card, target)
    card_played.emit(card, slot)
    return &"ok"


## Full-3D lock-on: enemy-targeting cards aim at the locked enemy's hurtbox (weak points win).
func _locked_hurtbox(card: CardData) -> Hurtbox:
    if card == null or (card.targeting != CardData.Targeting.ENEMY and card.targeting != CardData.Targeting.BOSS_WEAK_POINT):
        return null
    var target: Node3D = player.get("lock_target") as Node3D if "lock_target" in player else null
    if target == null or not is_instance_valid(target):
        return null
    for child: Node in target.get_children():
        if child is Hurtbox:
            return child
    return null


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
    if card.hp_cost > 0 and health.current <= card.hp_cost:
        return &"too_weak"
    if card.effect == &"transfusion" and health.current >= health.max_health:
        return &"full_health"
    if card.effect == &"bell_of_silence" and not _anyone_to_silence(card.card_range):
        return &"no_target"
    return &"ok"


func _anyone_to_silence(reach: float) -> bool:
    for node: Node in get_tree().get_nodes_in_group(&"silenceable"):
        var foe: Node3D = node as Node3D
        if foe == null or (foe.has_method("is_dead") and foe.call("is_dead")):
            continue
        if foe is HollowBishop:
            if (foe as HollowBishop).is_active() or (foe as HollowBishop).phase == HollowBishop.Phase.PURSUIT:
                return true
        elif foe.global_position.distance_to(player.global_position) <= reach:
            return true
    return false


## Adds a card to the deck mid-run (Blood Altar reward).
func add_card(card: CardData) -> void:
    deck.add_card(card)
    deck_changed.emit()


## Replaces a deck card with its upgraded copy (fracture reward).
func upgrade_card(old: CardData, new: CardData) -> void:
    deck.replace_card(old, new)
    deck_changed.emit()


## Public target query for summons (Ashen Choir): same rules as enemy-targeting cards.
func find_enemy_target(card_range: float, from: Vector3 = Vector3.INF) -> Dictionary:
    return _find_enemy_target(card_range, from)


func aim_point(hurtbox: Hurtbox) -> Vector3:
    return _aim_point(hurtbox)


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
func _find_enemy_target(card_range: float, from: Vector3 = Vector3.INF) -> Dictionary:
    var origin: Vector3 = player.global_position if from == Vector3.INF else from
    var in_3d: bool = bool(player.get("in_3d_mode"))
    var nearest: Hurtbox = null
    var nearest_distance: float = INF
    var weak: Hurtbox = null
    var weak_distance: float = INF
    var any_out_of_range: bool = false
    for node: Node in get_tree().get_nodes_in_group(&"hurtboxes"):
        var hurtbox: Hurtbox = node as Hurtbox
        if hurtbox == null or hurtbox.team == &"player" or not hurtbox.monitorable or hurtbox.is_in_group(&"no_card_target"):
            continue
        if hurtbox.health == null or hurtbox.health.is_dead():
            continue
        var owner_node: Node = hurtbox.get_parent()
        if owner_node.has_method("is_invulnerable") and owner_node.call("is_invulnerable"):
            continue
        var aim: Vector3 = _aim_point(hurtbox)
        if not in_3d and absf(aim.z - player.global_position.z) > plane_target_depth:
            continue
        var distance: float = aim.distance_to(origin)
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


func _check_chosen_target(card: CardData, hurtbox: Hurtbox) -> Dictionary:
    if card.targeting != CardData.Targeting.ENEMY and card.targeting != CardData.Targeting.BOSS_WEAK_POINT:
        return _find_target(card)  # self / telegraph cards have only one possible target
    if hurtbox.team == &"player" or hurtbox.health == null or hurtbox.health.is_dead():
        return {"reason": &"no_target"}
    var owner_node: Node = hurtbox.get_parent()
    if not hurtbox.monitorable or (owner_node.has_method("is_invulnerable") and owner_node.call("is_invulnerable")):
        return {"reason": &"not_exposed"}
    var aim: Vector3 = _aim_point(hurtbox)
    if not bool(player.get("in_3d_mode")) and absf(aim.z - player.global_position.z) > plane_target_depth:
        return {"reason": &"no_target"}
    if aim.distance_to(player.global_position) > card.card_range:
        return {"reason": &"out_of_range"}
    return {"reason": &"ok", "target": hurtbox}


func _aim_point(hurtbox: Hurtbox) -> Vector3:
    var shape: CollisionShape3D = hurtbox.get_child(0) as CollisionShape3D
    return shape.global_position if shape else hurtbox.global_position


func _apply(card: CardData, target: Variant) -> void:
    match card.effect:
        &"blood_spear":
            var aim: Vector3 = _aim_point(target as Hurtbox)
            var from: Vector3 = player.global_position + Vector3(0.0, 0.6, 0.0)
            var spear: BloodSpearProjectile = BloodSpearProjectile.create(from, aim, card)
            spear.hitbox.damage += spell_damage_bonus
            get_tree().current_scene.add_child(spear)
        &"grave_shield":
            player.call("raise_shield", card.blocks_category, card.duration)
        &"ritual_chains":
            target.call("interrupt_with_chains", card.duration)
        &"hemorrhage_pact":
            (player.get("health") as Health).apply_damage(card.hp_cost)
            energy.add(card.amount)
        &"transfusion":
            (player.get("health") as Health).heal(int(card.amount))
        &"epitaph":
            var spot: Vector3 = _aim_point(target as Hurtbox)
            var spike: EpitaphSpike = EpitaphSpike.create(spot, card)
            spike.hitbox.damage += spell_damage_bonus
            get_tree().current_scene.add_child(spike)
        &"ashen_choir":
            get_tree().current_scene.add_child(AshenPhantom.create(self, player, card))
        &"shadow_step":
            player.call("blink", card.amount, card.duration)
        &"grave_hook":
            var hook: Hurtbox = target as Hurtbox
            var to: Vector3 = _aim_point(hook) - player.global_position
            to.y = 0.0
            if not bool(player.get("in_3d_mode")):
                to.z = 0.0
            var lift: float = clampf(_aim_point(hook).y - 0.3 - player.global_position.y, 0.0, 2.5)
            player.call("blink", maxf(0.0, to.length() - 1.1), card.duration, to, lift)
            if to.length() > 0.01 and not bool(player.get("in_3d_mode")):
                player.set("facing_direction", signf(to.x))
            var info: DamageInfo = DamageInfo.new()
            info.amount = card.damage
            info.category = &"spell"
            info.poise_damage = 2
            info.hitstun = 0.4
            info.attack_id = &"grave_hook"
            info.source = player
            info.hit_position = _aim_point(hook)
            hook.receive(info)
        &"ossuary_bridge":
            var ahead: Vector3 = player.call("get_facing_vector")
            var feet: Vector3 = player.global_position + Vector3(0.0, -0.85, 0.0)
            get_tree().current_scene.add_child(BoneBridge.create(feet + ahead * (card.amount * 0.5 + 0.4), ahead, card.amount, card.duration))
        &"blood_nova":
            var nova: StrikeZone = StrikeZone.create(player.global_position + Vector3(0.0, -0.85, 0.0), card.amount, 0.5, 0.05, card.damage + spell_damage_bonus, &"blood_nova", &"burst")
            nova.hitbox.team = &"player"
            nova.hitbox.knockback = 7.0
            nova.hitbox.poise_damage = 3
            get_tree().current_scene.add_child(nova)
            get_tree().call_group(&"camera_shaker", &"add_trauma", 0.3)
        &"haste_sigil":
            player.call("haste", card.duration, card.amount)
        &"bell_of_silence":
            for node: Node in get_tree().get_nodes_in_group(&"silenceable"):
                var foe: Node3D = node as Node3D
                if foe == null:
                    continue
                # The Bishop stands 22 m back but fights on the play plane: always in earshot.
                var in_reach: bool = foe is HollowBishop or foe.global_position.distance_to(player.global_position) <= card.card_range
                if in_reach:
                    foe.call("silence", card.duration)
            get_tree().call_group(&"camera_shaker", &"add_trauma", 0.2)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_echo():
        return
    for i in SLOT_ACTIONS.size():
        if event.is_action_pressed(slot_action(i)):
            play_slot(i)
            return

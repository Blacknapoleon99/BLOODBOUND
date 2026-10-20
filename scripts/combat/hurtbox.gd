class_name Hurtbox
extends Area3D
## Receives hits for its parent combatant. The parent may implement `is_invulnerable()`
## (dodge / post-hit i-frames); a rejected hit is not counted, so the attacker may retry later.

signal hit_received(info: DamageInfo)

const COMBAT_LAYER: int = 1 << 2  # physics layer 3: hit/hurt areas only

@export var team: StringName = &"neutral"
@export var health: Health
@export var hit_feedback: bool = true


func _ready() -> void:
    collision_layer = COMBAT_LAYER
    collision_mask = 0
    monitoring = false
    monitorable = true


func receive(info: DamageInfo) -> bool:
    var body: Node = get_parent()
    if body.has_method("is_invulnerable") and body.call("is_invulnerable"):
        return false
    if health == null or health.is_dead():
        return false
    health.apply_damage(info.amount)
    if hit_feedback:
        HitFeedback.play(self, info)
    hit_received.emit(info)
    return true


func set_enabled(enabled: bool) -> void:
    set_deferred(&"monitorable", enabled)

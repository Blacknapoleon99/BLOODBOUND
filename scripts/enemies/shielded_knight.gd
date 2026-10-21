class_name ShieldedKnight
extends CodeEnemy
## A skeleton knight behind a tower shield. Hits from the FRONT are blocked while it guards
## (a clang, no damage). Get behind it, or break the guard with a heavy strike, Grave Hook or
## any hit with poise damage >= 3: it staggers for `stagger_time` s with the shield down.
## It advances and Shield Bashes: glows for `bash_windup` s, then charges ~2.5 m (1 damage, big
## knockback) and is exposed from the front during `recover_time`.
## States: idle (advance) → windup → bash → recover → idle ; stagger ; hitstun ; dead.

@export var walk_speed: float = 2.2
@export var bash_range: float = 3.2
@export var bash_windup: float = 0.6
@export var bash_speed: float = 9.0
@export var bash_time: float = 0.3
@export var recover_time: float = 0.9
@export var stagger_time: float = 1.5

var bash: Hitbox
var blocks: int = 0
var _shield: MeshInstance3D


func _init() -> void:
    max_health = 6
    poise_max = 4
    shard_value = 4
    _base_color = Color(0.55, 0.55, 0.6)


func _build_body() -> void:
    _add_collider(Vector3(0.8, 1.9, 0.6), -0.0)
    _add_hurt_shape(Vector3(0.9, 1.95, 0.8), 0.0)
    _add_mesh(Vector3(0.7, 1.8, 0.5), Vector3.ZERO, null, "Body")
    var iron: StandardMaterial3D = StandardMaterial3D.new()
    iron.albedo_color = Color(0.32, 0.3, 0.34)
    iron.metallic = 0.7
    _shield = _add_mesh(Vector3(0.18, 1.5, 1.0), Vector3(0.5, 0.05, 0.0), iron, "Shield")
    bash = _make_hitbox(Vector3(1.2, 1.6, 1.2), Vector3(0.0, 0.0, 0.0), 1, &"knight_bash", 8.0)


func is_guarding() -> bool:
    return not _dead and state != &"recover" and state != &"stagger" and state != &"bash"


## Hurtbox hook: block frontal hits while guarding; heavy hits break the guard instead.
func try_block(info: DamageInfo) -> bool:
    if not is_guarding():
        return false
    var from_x: float = info.source.global_position.x if info.source != null else info.hit_position.x
    var from_front: bool = (from_x - global_position.x) * facing > 0.0
    if not from_front:
        return false
    if info.category == &"heavy" or info.poise_damage >= 3 or info.attack_id == &"grave_hook":
        _stun_left = stagger_time
        set_state(&"stagger")
        return false  # the breaking hit lands
    blocks += 1
    _flash_left = 0.06
    Audio.sfx(&"shield_block", 0.08)
    return true


func _tick(delta: float, target: Node3D) -> void:
    match state:
        &"idle":
            velocity.x = 0.0
            if ai_enabled and target != null:
                var dx: float = target.global_position.x - global_position.x
                if absf(dx) > 0.05:
                    facing = signf(dx)
                if absf(dx) < bash_range and _silenced_left <= 0.0 and is_on_floor():
                    set_state(&"windup")
                elif absf(dx) > 1.2:
                    velocity.x = facing * walk_speed
        &"windup":
            velocity.x = 0.0
            if _t >= bash_windup:
                bash.activate()
                Audio.sfx(&"soldier_lunge", 0.05)
                set_state(&"bash")
        &"bash":
            velocity.x = facing * bash_speed
            if _t >= bash_time:
                bash.deactivate()
                set_state(&"recover")
        &"recover":
            velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
            if _t >= recover_time:
                set_state(&"idle")


func _on_poise_break(info: DamageInfo) -> void:
    bash.deactivate()
    super._on_poise_break(info)


func _on_silenced() -> void:
    if state == &"windup":
        set_state(&"idle")


func _on_died() -> void:
    bash.deactivate()
    super._on_died()


func _glow() -> Color:
    if state == &"windup":
        return Color(1.0, 0.25, 0.05) * (0.4 + 0.6 * _t / bash_window())
    if state == &"stagger":
        return Color(0.9, 0.8, 0.2) * 0.5
    return Color.BLACK


func bash_window() -> float:
    return maxf(0.01, bash_windup)


func _update_look() -> void:
    super._update_look()
    if not _dead:
        _shield.position = Vector3(0.5, 0.05, 0.0) if is_guarding() else Vector3(0.2, -0.6, 0.0)
        _shield.rotation.z = 0.0 if is_guarding() else 1.2

class_name FlyingWraith
extends CodeEnemy
## A wraith that floats over gaps and hazards (no gravity, passes through walls). It hovers
## `hover_height` above the player, drifting to a spot `keep_distance` to the side; then it
## locks a red line onto the player for `dive_windup` s and dives along it (1 damage), and
## drifts back up. Fragile: 2 HP, dies to one finisher.
## States: idle (hover) → windup → dive → rise → idle ; hitstun ; dead.

@export var hover_height: float = 3.2
@export var keep_distance: float = 4.0
@export var drift_speed: float = 3.5
@export var dive_windup: float = 0.65
@export var dive_speed: float = 13.0
@export var dive_time: float = 0.7
@export var rest_time: float = 1.4

var claws: Hitbox
var dives: int = 0
var _dive_dir: Vector3 = Vector3.DOWN
var _line: MeshInstance3D


func _init() -> void:
    max_health = 2
    poise_max = 1
    shard_value = 2
    _base_color = Color(0.6, 0.7, 0.85)


func _ready() -> void:
    super._ready()
    collision_layer = 0
    collision_mask = 0  # a ghost: no body collision with the world or the player


func _build_body() -> void:
    _add_collider(Vector3(0.6, 0.9, 0.6), 0.0)
    _add_hurt_shape(Vector3(0.9, 1.1, 0.8), 0.0)
    _material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material.albedo_color = Color(_base_color, 0.75)
    _add_mesh(Vector3(0.6, 1.0, 0.4), Vector3.ZERO, null, "Shroud")
    _add_mesh(Vector3(0.35, 0.35, 0.35), Vector3(0.0, 0.65, 0.0), null, "Skull")
    claws = _make_hitbox(Vector3(0.9, 0.9, 1.0), Vector3.ZERO, 1, &"wraith_dive", 5.0)
    _line = MeshInstance3D.new()
    var line_mesh: BoxMesh = BoxMesh.new()
    line_mesh.size = Vector3(0.06, 0.06, 1.0)
    _line.mesh = line_mesh
    _line.material_override = BishopHand._warning_material()
    _line.top_level = true
    _line.visible = false
    add_child(_line)


func _apply_motion(delta: float) -> void:
    if _dead:
        velocity.y -= 20.0 * delta  # the shroud collapses to the ground
    global_position += velocity * delta
    global_position.z = 0.0
    global_position.x = clampf(global_position.x, min_x, max_x)
    if global_position.y < -9.0 and not _dead:
        health.apply_damage(health.current)


func _tick(delta: float, target: Node3D) -> void:
    match state:
        &"idle", &"rise":
            if target == null or not ai_enabled:
                velocity = velocity.move_toward(Vector3.ZERO, 6.0 * delta)
                return
            var side: float = -1.0 if global_position.x < target.global_position.x else 1.0
            var spot: Vector3 = target.global_position + Vector3(side * keep_distance, hover_height + sin(_t * 2.0) * 0.3, 0.0)
            var to: Vector3 = spot - global_position
            velocity = to.limit_length(1.0) * drift_speed if to.length() > 0.2 else Vector3.ZERO
            facing = signf(target.global_position.x - global_position.x) if absf(target.global_position.x - global_position.x) > 0.05 else facing
            if _t >= rest_time and to.length() < 1.2 and _silenced_left <= 0.0:
                _dive_dir = (target.global_position - global_position).normalized()
                set_state(&"windup")
        &"windup":
            velocity = Vector3.ZERO
            _show_line(true)
            if _t >= dive_windup:
                _show_line(false)
                claws.activate()
                dives += 1
                Audio.sfx(&"hound_pounce", 0.1)
                set_state(&"dive")
        &"dive":
            velocity = _dive_dir * dive_speed
            if _t >= dive_time:
                claws.deactivate()
                set_state(&"rise")


func _show_line(show: bool) -> void:
    _line.visible = show
    if show:
        var length: float = dive_speed * dive_time
        var from: Vector3 = global_position
        var to: Vector3 = from + _dive_dir * length
        var up: Vector3 = Vector3.UP if absf(_dive_dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
        _line.global_transform = Transform3D(Basis.looking_at(_dive_dir, up).scaled_local(Vector3(1.0, 1.0, length)), (from + to) * 0.5)


func _on_poise_break(info: DamageInfo) -> void:
    claws.deactivate()
    _show_line(false)
    velocity = info.knockback * 0.5
    _stun_left = info.hitstun
    set_state(&"hitstun")


func _on_silenced() -> void:
    if state == &"windup":
        _show_line(false)
        set_state(&"idle")


func _on_died() -> void:
    claws.deactivate()
    _show_line(false)
    super._on_died()


func _glow() -> Color:
    if state == &"windup":
        return Color(1.0, 0.2, 0.1) * (0.5 + 0.5 * _t / dive_windup)
    return Color(0.3, 0.45, 0.8) * 0.4

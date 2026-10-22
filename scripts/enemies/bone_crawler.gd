class_name BoneCrawler
extends CodeEnemy
## A small skittering bundle of bones packed with grave-gas. It runs at you, and within
## `fuse_range` it stops, flashes for `fuse_time` s and bursts (StrikeZone, 1.6 m, 1 damage),
## destroying itself. Killed before that, it bursts where it fell after a short 0.45 s fuse —
## kill it, then step back.
## States: idle (run) → fuse → (burst, dead) ; hitstun ; dead.

@export var run_speed: float = 6.0
@export var fuse_range: float = 1.6
@export var fuse_time: float = 0.8
@export var burst_radius: float = 1.6

var burst_spawned: bool = false


func _init() -> void:
    max_health = 1
    poise_max = 1
    shard_value = 1
    _base_color = Color(0.75, 0.7, 0.55)


func _build_body() -> void:
    _add_collider(Vector3(0.7, 0.5, 0.5), -0.55)
    _add_hurt_shape(Vector3(0.8, 0.6, 0.7), -0.5)
    _add_mesh(Vector3(0.7, 0.4, 0.45), Vector3(0.0, -0.6, 0.0), null, "Carapace")
    for side: float in [-0.25, 0.25]:
        _add_mesh(Vector3(0.08, 0.3, 0.6), Vector3(side, -0.75, 0.0), null, "Legs")


func _tick(_delta: float, target: Node3D) -> void:
    match state:
        &"idle":
            stop()
            if ai_enabled and target != null:
                var off: Vector3 = planar_to(target)
                face(off)
                if off.length() < fuse_range and absf(target.global_position.y - global_position.y) < 1.6 and _silenced_left <= 0.0:
                    set_state(&"fuse")
                else:
                    move_dir(chase_dir(target), run_speed)
        &"fuse":
            stop()
            if _t >= fuse_time:
                _burst(0.05)
                health.apply_damage(health.current)


func _on_died() -> void:
    _burst(0.45)  # no-op if it already burst
    super._on_died()


func _burst(delay: float) -> void:
    if burst_spawned or not is_inside_tree():
        return
    burst_spawned = true
    var feet: Vector3 = global_position + Vector3(0.0, -0.8, 0.0)
    get_parent().add_child(StrikeZone.create(feet, burst_radius, 0.5, delay, 1, &"crawler_burst", &"burst"))
    get_tree().create_timer(delay).timeout.connect(func() -> void: Audio.sfx(&"husk_burst", 0.1))


func _on_silenced() -> void:
    pass  # gas does not listen to bells: a fusing crawler still bursts


func _glow() -> Color:
    if state == &"fuse":
        return Color(1.0, 0.6, 0.1) * (1.0 if int(_t * 12.0) % 2 == 0 else 0.2)
    return Color.BLACK

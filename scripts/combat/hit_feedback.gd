class_name HitFeedback
extends RefCounted
## Presentation-only hit reactions: blood (Gore.hit: spurts, mist, splats), hitstop, a
## camera-shake request and, for hits on enemies, a floating damage number (so a landed hit is
## unmistakable).
## Nothing here changes combat outcomes, so it can be swapped for authored VFX later.

const BLOOD_COLOR: Color = Color(0.55, 0.02, 0.04)
const ASH_COLOR: Color = Color(0.22, 0.21, 0.24)
const HITSTOP_SCALE: float = 0.08
const HITSTOP_SECONDS: float = 0.05
const HEAVY_HITSTOP_SECONDS: float = 0.065
## A killing blow freezes a touch longer so the death burst lands (kept under 0.09 s).
const KILL_HITSTOP_SECONDS: float = 0.085

static var _hitstop_depth: int = 0


static func play(at_node: Node3D, info: DamageInfo) -> void:
    var tree: SceneTree = at_node.get_tree()
    if tree == null:
        return
    var strength: float = 1.6 if info.category == &"heavy" else 1.0
    var hurtbox: Hurtbox = at_node as Hurtbox
    var killed: bool = hurtbox != null and hurtbox.health != null and hurtbox.health.is_dead()
    var victim: Node = hurtbox.get_parent() if hurtbox != null else at_node
    Gore.hit(tree, info, victim, hurtbox.team if hurtbox != null else &"neutral", strength, killed)
    if hurtbox != null and hurtbox.team != &"player":
        var weak: bool = hurtbox.is_in_group(&"weak_point")
        _spawn_damage_number(tree, info, weak)
        Audio.sfx(&"hit_weak" if weak else &"hit_flesh")
    if GameSettings.hitstop_enabled:
        _hitstop(tree, KILL_HITSTOP_SECONDS if killed else HEAVY_HITSTOP_SECONDS if strength > 1.0 else HITSTOP_SECONDS)
    tree.call_group(&"camera_shaker", &"add_trauma", 0.3 * strength + (0.15 if killed else 0.0))


static func _spawn_damage_number(tree: SceneTree, info: DamageInfo, weak_point: bool) -> void:
    var host: Node = tree.current_scene
    if host == null:
        return
    var label: Label3D = Label3D.new()
    label.name = "DamageNumber"
    label.add_to_group(&"damage_number")
    label.text = str(info.amount)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.fixed_size = true
    label.pixel_size = 0.0012 if weak_point else 0.0009
    label.font_size = 64
    label.outline_size = 14
    label.modulate = Color(1.0, 0.85, 0.3) if weak_point else Color(1.0, 0.95, 0.9)
    label.outline_modulate = Color(0.25, 0.0, 0.02)
    host.add_child(label)
    label.global_position = info.hit_position + Vector3(randf_range(-0.2, 0.2), 0.9, 0.0)
    var tween: Tween = label.create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "global_position:y", label.global_position.y + 1.1, 0.7).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
    tween.chain().tween_callback(label.queue_free)


static func _hitstop(tree: SceneTree, seconds: float) -> void:
    _hitstop_depth += 1
    Engine.time_scale = HITSTOP_SCALE
    var timer: SceneTreeTimer = tree.create_timer(seconds, true, false, true)
    timer.timeout.connect(func() -> void:
        _hitstop_depth -= 1
        if _hitstop_depth <= 0:
            _hitstop_depth = 0
            Engine.time_scale = 1.0)

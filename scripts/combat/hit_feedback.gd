class_name HitFeedback
extends RefCounted
## Presentation-only hit reactions: blood spray, hitstop, a camera-shake request and, for hits
## on enemies, a floating damage number (so a landed hit is unmistakable).
## Nothing here changes combat outcomes, so it can be swapped for authored VFX later.

const BLOOD_COLOR: Color = Color(0.55, 0.02, 0.04)
const ASH_COLOR: Color = Color(0.22, 0.21, 0.24)
const HITSTOP_SCALE: float = 0.08
const HITSTOP_SECONDS: float = 0.05

static var _hitstop_depth: int = 0


static func play(at_node: Node3D, info: DamageInfo) -> void:
    var tree: SceneTree = at_node.get_tree()
    if tree == null:
        return
    var strength: float = 1.6 if info.category == &"heavy" else 1.0
    _spawn_spray(tree, info, strength)
    var hurtbox: Hurtbox = at_node as Hurtbox
    if hurtbox != null and hurtbox.team != &"player":
        var weak: bool = hurtbox.is_in_group(&"weak_point")
        _spawn_damage_number(tree, info, weak)
        Audio.sfx(&"hit_weak" if weak else &"hit_flesh")
    if GameSettings.hitstop_enabled:
        _hitstop(tree)
    tree.call_group(&"camera_shaker", &"add_trauma", 0.3 * strength)


static func _spawn_spray(tree: SceneTree, info: DamageInfo, strength: float) -> void:
    var host: Node = tree.current_scene
    if host == null:
        return
    var gore_off: bool = GameSettings.reduced_gore
    var color: Color = ASH_COLOR if gore_off else BLOOD_COLOR
    var spray: CPUParticles3D = CPUParticles3D.new()
    spray.name = "HitSpray"
    spray.add_to_group(&"hit_fx")
    spray.set_meta(&"spray_color", color)
    spray.one_shot = true
    spray.explosiveness = 0.9
    spray.amount = int((10 if gore_off else 26) * strength)
    spray.lifetime = 0.6
    var push: Vector3 = info.knockback
    push.y = 0.0
    spray.direction = (push.normalized() + Vector3.UP * 0.6).normalized() if push.length_squared() > 0.01 else Vector3.UP
    spray.spread = 38.0
    spray.initial_velocity_min = 2.5
    spray.initial_velocity_max = 6.0 * strength
    spray.gravity = Vector3(0.0, -18.0, 0.0)
    spray.scale_amount_min = 0.5
    spray.scale_amount_max = 1.2
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 0.05
    mesh.height = 0.1
    mesh.radial_segments = 6
    mesh.rings = 3
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.4
    mesh.material = material
    spray.mesh = mesh
    host.add_child(spray)
    spray.global_position = info.hit_position
    spray.emitting = true
    spray.finished.connect(spray.queue_free)


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


static func _hitstop(tree: SceneTree) -> void:
    _hitstop_depth += 1
    Engine.time_scale = HITSTOP_SCALE
    var timer: SceneTreeTimer = tree.create_timer(HITSTOP_SECONDS, true, false, true)
    timer.timeout.connect(func() -> void:
        _hitstop_depth -= 1
        if _hitstop_depth <= 0:
            _hitstop_depth = 0
            Engine.time_scale = 1.0)

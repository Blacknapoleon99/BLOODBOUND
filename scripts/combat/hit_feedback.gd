class_name HitFeedback
extends RefCounted
## Presentation-only hit reactions: blood spray, hitstop and a camera-shake request.
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


static func _hitstop(tree: SceneTree) -> void:
    _hitstop_depth += 1
    Engine.time_scale = HITSTOP_SCALE
    var timer: SceneTreeTimer = tree.create_timer(HITSTOP_SECONDS, true, false, true)
    timer.timeout.connect(func() -> void:
        _hitstop_depth -= 1
        if _hitstop_depth <= 0:
            _hitstop_depth = 0
            Engine.time_scale = 1.0)

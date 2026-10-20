class_name CenserSweep
extends Node3D
## The Bishop's Censer Sweep: a red band marks the whole causeway while a huge censer swings in
## from depth to knee height at one end (`telegraph` s); then it sweeps along the causeway.
## Answer: jump over it (it only reaches ~1.35 m) or dodge through it.

const HEIGHT: float = 0.7
const RADIUS: float = 0.65

var telegraph: float = 1.1
var speed: float = 16.0
var from_x: float
var to_x: float
var anchor: Node3D
var hitbox: Hitbox
var done: bool = false
var _t: float = 0.0
var _band: MeshInstance3D
var _censer: Node3D
var _chain: MeshInstance3D


static func create(bishop: Node3D, start_x: float, end_x: float) -> CenserSweep:
    var sweep: CenserSweep = CenserSweep.new()
    sweep.name = "CenserSweep"
    sweep.add_to_group(&"boss_censer")
    sweep.top_level = true
    sweep.anchor = bishop
    sweep.from_x = start_x
    sweep.to_x = end_x
    sweep._band = MeshInstance3D.new()
    var band: BoxMesh = BoxMesh.new()
    band.size = Vector3(absf(end_x - start_x) + 2.0, 0.05, 1.4)
    sweep._band.mesh = band
    sweep._band.material_override = BishopHand._warning_material()
    sweep._band.position = Vector3((start_x + end_x) * 0.5, 0.03, 0.0)
    sweep.add_child(sweep._band)
    sweep._censer = Node3D.new()
    sweep.add_child(sweep._censer)
    var bowl: MeshInstance3D = MeshInstance3D.new()
    var bowl_mesh: SphereMesh = SphereMesh.new()
    bowl_mesh.radius = RADIUS
    bowl_mesh.height = RADIUS * 2.0
    bowl.mesh = bowl_mesh
    var brass: StandardMaterial3D = StandardMaterial3D.new()
    brass.albedo_color = Color(0.45, 0.32, 0.15)
    brass.metallic = 0.7
    brass.emission_enabled = true
    brass.emission = Color(0.9, 0.3, 0.05) * 0.8
    bowl.material_override = brass
    sweep._censer.add_child(bowl)
    sweep.hitbox = Hitbox.new()
    sweep.hitbox.team = &"enemy"
    sweep.hitbox.damage = 1
    sweep.hitbox.category = &"sweep"
    sweep.hitbox.knockback = 5.0
    sweep.hitbox.knockback_up = 4.0
    sweep.hitbox.hitstun = 0.35
    sweep.hitbox.attack_id = &"bishop_censer"
    var shape: CollisionShape3D = CollisionShape3D.new()
    var sphere: SphereShape3D = SphereShape3D.new()
    sphere.radius = RADIUS
    shape.shape = sphere
    sweep.hitbox.add_child(shape)
    sweep._censer.add_child(sweep.hitbox)
    sweep._chain = MeshInstance3D.new()
    var chain_mesh: BoxMesh = BoxMesh.new()
    chain_mesh.size = Vector3(0.12, 0.12, 1.0)
    sweep._chain.mesh = chain_mesh
    sweep._chain.material_override = brass
    sweep._chain.top_level = true
    sweep.add_child(sweep._chain)
    return sweep


func is_telegraphing() -> bool:
    return not done and _t < telegraph


func censer_position() -> Vector3:
    return _censer.global_position


func cancel() -> void:
    hitbox.deactivate()
    done = true
    queue_free()


func _physics_process(delta: float) -> void:
    if done:
        return
    _t += delta
    var start: Vector3 = Vector3(from_x, HEIGHT, 0.0)
    if _t < telegraph:
        _censer.global_position = Vector3(from_x, 6.0, -10.0).lerp(start, _t / telegraph)
    else:
        if not hitbox.is_active():
            hitbox.activate()
            _band.visible = false
        var travel: float = (_t - telegraph) * speed
        var length: float = absf(to_x - from_x)
        _censer.global_position = start + Vector3(signf(to_x - from_x) * minf(travel, length), 0.0, 0.0)
        if travel >= length + 2.0:
            hitbox.deactivate()
            done = true
            queue_free()
            return
    _update_chain()


func _update_chain() -> void:
    if not is_instance_valid(anchor):
        return
    var top: Vector3 = anchor.global_position + Vector3(-4.8, 9.4, 0.5)
    var bottom: Vector3 = _censer.global_position
    var span: Vector3 = bottom - top
    if span.length() < 0.1:
        return
    var up: Vector3 = Vector3.UP if absf(span.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
    _chain.global_transform = Transform3D(Basis.looking_at(span, up).scaled_local(Vector3(1.0, 1.0, span.length())), top + span * 0.5)

class_name RequiemBeam
extends Node3D
## The Bishop's Requiem Beam: its heart charges (`telegraph` s) while a red line marks the whole
## causeway and a pillar of light marks where the sweep begins; then the beam sweeps the full
## length of the causeway faster than anyone can run. Answer: dodge through it (i-frames).

var telegraph: float = 1.3
var speed: float = 18.0
var from_x: float
var to_x: float
var heart: Node3D
var hitbox: Hitbox
var done: bool = false
var _t: float = 0.0
var _line: MeshInstance3D
var _pillar: Node3D
var _ray: MeshInstance3D
var _glow: StandardMaterial3D


static func create(heart_node: Node3D, start_x: float, end_x: float) -> RequiemBeam:
    var beam: RequiemBeam = RequiemBeam.new()
    beam.name = "RequiemBeam"
    beam.add_to_group(&"boss_beam")
    beam.top_level = true
    beam.heart = heart_node
    beam.from_x = start_x
    beam.to_x = end_x
    beam._line = MeshInstance3D.new()
    var line: BoxMesh = BoxMesh.new()
    line.size = Vector3(absf(end_x - start_x) + 2.0, 0.04, 0.25)
    beam._line.mesh = line
    beam._line.material_override = BishopHand._warning_material()
    beam._line.position = Vector3((start_x + end_x) * 0.5, 0.03, 0.0)
    beam.add_child(beam._line)
    beam._glow = StandardMaterial3D.new()
    beam._glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beam._glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beam._glow.albedo_color = Color(1.0, 0.15, 0.2, 0.35)
    beam._pillar = Node3D.new()
    beam.add_child(beam._pillar)
    var column: MeshInstance3D = MeshInstance3D.new()
    var column_mesh: BoxMesh = BoxMesh.new()
    column_mesh.size = Vector3(1.0, 5.0, 1.0)
    column.mesh = column_mesh
    column.material_override = beam._glow
    column.position = Vector3(0.0, 2.5, 0.0)
    beam._pillar.add_child(column)
    beam.hitbox = Hitbox.new()
    beam.hitbox.team = &"enemy"
    beam.hitbox.damage = 2
    beam.hitbox.category = &"beam"
    beam.hitbox.knockback = 4.0
    beam.hitbox.knockback_up = 3.0
    beam.hitbox.hitstun = 0.4
    beam.hitbox.attack_id = &"bishop_beam"
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(1.0, 5.0, 2.0)
    shape.shape = box
    shape.position = Vector3(0.0, 2.5, 0.0)
    beam.hitbox.add_child(shape)
    beam._pillar.add_child(beam.hitbox)
    beam._ray = MeshInstance3D.new()
    var ray_mesh: BoxMesh = BoxMesh.new()
    ray_mesh.size = Vector3(0.6, 0.6, 1.0)
    beam._ray.mesh = ray_mesh
    beam._ray.material_override = beam._glow
    beam._ray.top_level = true
    beam._ray.visible = false
    beam.add_child(beam._ray)
    return beam


func is_telegraphing() -> bool:
    return not done and _t < telegraph


func beam_x() -> float:
    return _pillar.global_position.x


func cancel() -> void:
    hitbox.deactivate()
    done = true
    queue_free()


func _physics_process(delta: float) -> void:
    if done:
        return
    _t += delta
    if _t < telegraph:
        _pillar.global_position = Vector3(from_x, 0.0, 0.0)
        # Charging: the start pillar flickers brighter as the beam is about to fire.
        _glow.albedo_color.a = 0.2 + 0.3 * (_t / telegraph) * (0.5 + 0.5 * sin(_t * 30.0))
        return
    if not hitbox.is_active():
        hitbox.activate()
        Audio.sfx(&"beam_fire", 0.02)
        _line.visible = false
        _ray.visible = true
        _glow.albedo_color = Color(1.0, 0.2, 0.25, 0.85)
    var travel: float = (_t - telegraph) * speed
    var length: float = absf(to_x - from_x)
    _pillar.global_position = Vector3(from_x + signf(to_x - from_x) * minf(travel, length), 0.0, 0.0)
    _update_ray()
    if travel >= length + 1.5:
        hitbox.deactivate()
        done = true
        queue_free()


func _update_ray() -> void:
    if not is_instance_valid(heart):
        return
    var from: Vector3 = heart.global_position
    var to: Vector3 = _pillar.global_position + Vector3(0.0, 1.5, 0.0)
    var span: Vector3 = to - from
    var up: Vector3 = Vector3.UP if absf(span.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
    _ray.global_transform = Transform3D(Basis.looking_at(span, up).scaled_local(Vector3(1.0, 1.0, span.length())), from + span * 0.5)

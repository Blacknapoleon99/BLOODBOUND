class_name MovingPlatform
extends AnimatableBody3D
## Ferries the player across a gap: travels between `point_a` and `point_b`, pausing at each
## end. Moves in _physics_process with sync_to_physics so riders inherit its velocity.

@export var point_a: Vector3
@export var point_b: Vector3
@export var travel_time: float = 2.8
@export var pause_time: float = 0.9

var _t: float = 0.0


static func create(label: String, from: Vector3, to: Vector3, slab_size: Vector3) -> MovingPlatform:
    var platform: MovingPlatform = MovingPlatform.new()
    platform.name = label
    platform.point_a = from
    platform.point_b = to
    platform.position = from
    platform.sync_to_physics = true
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = slab_size
    shape.shape = box
    platform.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = slab_size
    mesh_node.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.42, 0.3, 0.2)
    material.emission_enabled = true
    material.emission = Color(0.25, 0.08, 0.02)
    mesh_node.material_override = material
    platform.add_child(mesh_node)
    return platform


## 0 at point_a, 1 at point_b.
func progress() -> float:
    var span: float = point_a.distance_to(point_b)
    return point_a.distance_to(global_position) / span if span > 0.0 else 0.0


func _physics_process(delta: float) -> void:
    var cycle: float = 2.0 * (travel_time + pause_time)
    _t = fmod(_t + delta, cycle)
    var p: float
    if _t < pause_time:
        p = 0.0
    elif _t < pause_time + travel_time:
        p = smoothstep(0.0, 1.0, (_t - pause_time) / travel_time)
    elif _t < 2.0 * pause_time + travel_time:
        p = 1.0
    else:
        p = 1.0 - smoothstep(0.0, 1.0, (_t - 2.0 * pause_time - travel_time) / travel_time)
    global_position = point_a.lerp(point_b, p)

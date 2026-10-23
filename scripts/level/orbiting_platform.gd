class_name OrbitingPlatform
extends AnimatableBody3D
## A platform circling a fixed centre at a steady speed (open 3D courses, DEC-052): bone
## carousels in the belfry, ferries swinging round a pillar. Moves in _physics_process with
## sync_to_physics so riders inherit its velocity. Always turns the same way, so a jump onto it
## is a matter of waiting for it to come round.

@export var center: Vector3
@export var radius: float = 6.0
@export var period: float = 8.0  # seconds per lap
@export var start_angle: float = 0.0

var _t: float = 0.0


static func create(label: String, at_center: Vector3, orbit_radius: float, lap_time: float, angle0: float, slab_size: Vector3) -> OrbitingPlatform:
    var p: OrbitingPlatform = OrbitingPlatform.new()
    p.name = label
    p.add_to_group(&"orbiting_platform")
    p.center = at_center
    p.radius = orbit_radius
    p.period = lap_time
    p.start_angle = angle0
    p.sync_to_physics = true
    p.position = p.point_at(0.0)
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = slab_size
    shape.shape = box
    p.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = slab_size
    mesh_node.mesh = mesh
    mesh_node.material_override = GothicMaterials.block(&"iron")  # rusted iron, ember rim (DEC-054)
    p.add_child(mesh_node)
    return p


## Where the platform is `t` seconds into its orbit.
func point_at(t: float) -> Vector3:
    var a: float = start_angle + TAU * t / maxf(0.1, period)
    return center + Vector3(cos(a), 0.0, sin(a)) * radius


func _physics_process(delta: float) -> void:
    _t = fmod(_t + delta, maxf(0.1, period))
    global_position = point_at(_t)

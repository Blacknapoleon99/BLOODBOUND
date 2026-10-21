class_name BoneBridge
extends StaticBody3D
## Ossuary Bridge: a slab of fused bone that grows out ahead of the player at foot level, solid
## for `lifetime` seconds, then trembles (last 0.8 s) and crumbles. Crosses gaps and catches falls.

var lifetime: float = 5.0
var _t: float = 0.0
var _material: StandardMaterial3D
var _mesh: MeshInstance3D


## `top_center` is the point on the bridge's top surface; `along` is the direction it extends.
static func create(top_center: Vector3, along: Vector3, length: float, seconds: float) -> BoneBridge:
    var bridge: BoneBridge = BoneBridge.new()
    bridge.name = "OssuaryBridge"
    bridge.add_to_group(&"bone_bridge")
    bridge.lifetime = seconds
    bridge.position = top_center + Vector3(0.0, -0.2, 0.0)
    if absf(along.z) > absf(along.x):
        bridge.rotation.y = PI * 0.5
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(length, 0.4, 2.4)
    shape.shape = box
    bridge.add_child(shape)
    bridge._mesh = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = box.size
    bridge._mesh.mesh = mesh
    bridge._material = StandardMaterial3D.new()
    bridge._material.albedo_color = Color(0.85, 0.8, 0.68)
    bridge._material.emission_enabled = true
    bridge._material.emission = Color(0.5, 0.05, 0.05) * 0.3
    bridge._mesh.material_override = bridge._material
    bridge.add_child(bridge._mesh)
    bridge.scale = Vector3(0.1, 1.0, 1.0)
    return bridge


func _physics_process(delta: float) -> void:
    _t += delta
    scale.x = minf(1.0, scale.x + delta * 8.0)  # grows out in ~0.1 s
    if _t > lifetime - 0.8:
        _mesh.position.x = randf_range(-0.04, 0.04)  # trembling: it is about to go
        _material.albedo_color = Color(0.85, 0.8, 0.68).lerp(Color(0.5, 0.2, 0.15), (_t - lifetime + 0.8) / 0.8)
    if _t >= lifetime:
        queue_free()

class_name LeverShortcut
extends Node3D
## A one-way shortcut: a lever on the far side of a hard stretch and a bone bridge back over it.
## The bridge is a faint outline (no collision) until the lever is pulled (E); then it is solid
## for the rest of the run, so after a death you walk straight back over what you cleared.

signal opened

var is_open: bool = false
var lever: Node3D
var bridge: StaticBody3D
var _bridge_material: StandardMaterial3D
var _shape: CollisionShape3D


## `lever_at` world position of the lever; the bridge spans x0..x1 (world) with its top at `top`.
## `z`/`depth`: where the bridge runs in depth and how wide it is (open 3D courses).
static func create(lever_at: Vector3, x0: float, x1: float, top: float, z: float = 0.0, depth: float = 2.4) -> LeverShortcut:
    var s: LeverShortcut = LeverShortcut.new()
    s.name = "Shortcut"
    s.add_to_group(&"shortcut")
    s.lever = Node3D.new()
    s.lever.position = lever_at
    var post: MeshInstance3D = MeshInstance3D.new()
    var post_mesh: BoxMesh = BoxMesh.new()
    post_mesh.size = Vector3(0.2, 1.2, 0.2)
    post.mesh = post_mesh
    var brass: StandardMaterial3D = StandardMaterial3D.new()
    brass.albedo_color = Color(0.7, 0.55, 0.2)
    brass.emission_enabled = true
    brass.emission = Color(0.6, 0.4, 0.1) * 0.5
    post.material_override = brass
    post.position.y = 0.6
    post.rotation.z = 0.5
    post.name = "Handle"
    s.lever.add_child(post)
    s.add_child(s.lever)
    s.bridge = StaticBody3D.new()
    s.bridge.position = Vector3((x0 + x1) * 0.5, top - 0.2, z)
    s._shape = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(x1 - x0, 0.4, depth)
    s._shape.shape = box
    s._shape.disabled = true
    s.bridge.add_child(s._shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = box.size
    mesh_node.mesh = mesh
    s._bridge_material = StandardMaterial3D.new()
    s._bridge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    s._bridge_material.albedo_color = Color(0.85, 0.8, 0.68, 0.12)
    mesh_node.material_override = s._bridge_material
    s.bridge.add_child(mesh_node)
    s.add_child(s.bridge)
    return s


func lever_in_reach(player: Node3D) -> bool:
    return not is_open and player != null and player.global_position.distance_to(lever.global_position + Vector3(0.0, 0.8, 0.0)) < 2.0


func pull() -> void:
    if is_open:
        return
    is_open = true
    _shape.set_deferred(&"disabled", false)
    (lever.get_node("Handle") as Node3D).rotation.z = -0.5
    var tween: Tween = create_tween()
    tween.tween_property(_bridge_material, "albedo_color:a", 1.0, 0.6)
    Audio.sfx(&"card_bridge", 0.0)
    opened.emit()

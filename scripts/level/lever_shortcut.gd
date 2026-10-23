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
var _iron_material: StandardMaterial3D
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
    var brass: StandardMaterial3D = GothicMaterials.standard("rust_iron", Color(1.0, 0.78, 0.35), 0.5, false)  # DEC-054
    brass.emission_enabled = true
    brass.emission = Color(0.6, 0.4, 0.1) * 0.5
    # Modelled lever (DEC-057): a carved stone plinth with an axle, and an iron arm with a
    # bone grip pivoting on it. Same "Handle" node and pull rotation as before.
    var base: MeshInstance3D = GothicProps.instance("lever_base", {}, "Lever base")
    var handle_mesh: ArrayMesh = GothicProps.mesh("lever_handle", {&"iron": brass, &"gold": brass})
    if base != null and handle_mesh != null:
        s.lever.add_child(base)
        post.mesh = handle_mesh
        post.position.y = 0.62
    else:
        var post_mesh: BoxMesh = BoxMesh.new()
        post_mesh.size = Vector3(0.2, 1.2, 0.2)
        post.mesh = post_mesh
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
    var plank: ArrayMesh = GothicProps.raw("bridge_plank")
    var rail: ArrayMesh = GothicProps.raw("bridge_rail")
    if plank != null and rail != null:
        # A plank-and-iron bridge (DEC-057), ghostly until the lever is pulled.
        s._bridge_material = GothicMaterials.standard("wood", Color(0.8, 0.7, 0.6), 1.0)
        s._bridge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        s._bridge_material.albedo_color = Color(0.8, 0.7, 0.6, 0.12)
        s._iron_material = GothicMaterials.standard("rust_iron", Color(0.6, 0.5, 0.46, 0.12), 0.6)
        s._iron_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        s.bridge.add_child(s._bridge_visual(box.size, GothicProps.mesh("bridge_plank", {&"wood": s._bridge_material, &"iron": s._iron_material}),
                GothicProps.mesh("bridge_rail", {&"iron": s._iron_material})))
    else:
        var mesh_node: MeshInstance3D = MeshInstance3D.new()
        var mesh: BoxMesh = BoxMesh.new()
        mesh.size = box.size
        mesh_node.mesh = mesh
        s._bridge_material = GothicMaterials.standard("cracked", Color(0.85, 0.78, 0.66), 1.6)  # bone-pale stone
        s._bridge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        s._bridge_material.albedo_color = Color(0.85, 0.8, 0.68, 0.12)
        mesh_node.material_override = s._bridge_material
        s.bridge.add_child(mesh_node)
    s.add_child(s.bridge)
    return s


## Planks across the span (slightly uneven) on two iron stringers and cross straps. The deck
## top sits at the collision top (local y = +0.2).
func _bridge_visual(size: Vector3, plank: ArrayMesh, rail: ArrayMesh) -> Node3D:
    var root: Node3D = Node3D.new()
    root.name = "Bridge visual"
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = int(size.x * 100.0)
    var count: int = maxi(1, int(size.x / 0.31))
    var pitch: float = size.x / count
    var multi: MultiMesh = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = plank
    multi.instance_count = count
    for k in count:
        var b: Basis = Basis(Vector3.UP, rng.randf_range(-0.04, 0.04)) * Basis(Vector3.FORWARD, rng.randf_range(-0.02, 0.02))
        b = b.scaled(Vector3(pitch / 0.3, 1.0, size.z * rng.randf_range(0.94, 1.0)))
        multi.set_instance_transform(k, Transform3D(b, Vector3(-size.x * 0.5 + (k + 0.5) * pitch, 0.2 - rng.randf_range(0.0, 0.025), rng.randf_range(-0.05, 0.05))))
    var deck: MultiMeshInstance3D = MultiMeshInstance3D.new()
    deck.name = "Planks"
    deck.multimesh = multi
    root.add_child(deck)
    for side: float in [-1.0, 1.0]:
        var stringer: MeshInstance3D = MeshInstance3D.new()
        stringer.mesh = rail
        stringer.scale = Vector3(size.x, 1.2, 1.0)
        stringer.position = Vector3(0.0, 0.12, side * (size.z * 0.5 - 0.2))
        root.add_child(stringer)
    return root


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
    if _iron_material != null:
        tween.parallel().tween_property(_iron_material, "albedo_color:a", 1.0, 0.6)
    Audio.sfx(&"card_bridge", 0.0)
    opened.emit()

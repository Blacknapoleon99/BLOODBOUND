class_name BishopHand
extends Node3D
## The Bishop's skeletal hand. The boss drives its position; the hand owns the slam
## hitbox, the floor telegraph, and the stigmata weak point that only accepts hits while open.

const SLAM_ZONE: Vector3 = Vector3(3.0, 2.4, 3.0)

var hitbox: Hitbox
var weak_point: Hurtbox
var marker: MeshInstance3D
var weak_open: bool = false
var _stigmata_material: StandardMaterial3D


static func create(boss_health: Health) -> BishopHand:
    var hand: BishopHand = BishopHand.new()
    hand.name = "BishopHand"
    hand.top_level = true
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.72, 0.68, 0.58)
    bone.roughness = 0.8
    hand._add_box("Palm", Vector3(2.4, 0.6, 2.2), Vector3.ZERO, bone)
    for i in 4:
        hand._add_box("Finger%d" % i, Vector3(0.35, 0.35, 1.6), Vector3(-0.9 + 0.6 * i, -0.05, 1.7), bone)
    hand._add_box("Thumb", Vector3(0.35, 0.35, 1.2), Vector3(-1.5, -0.05, 0.4), bone)

    hand._stigmata_material = StandardMaterial3D.new()
    hand._stigmata_material.albedo_color = Color(0.35, 0.05, 0.08)
    hand._stigmata_material.emission_enabled = true
    hand._stigmata_material.emission = Color(0.3, 0.02, 0.04)
    var stigmata: MeshInstance3D = MeshInstance3D.new()
    stigmata.name = "Stigmata"
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.45
    sphere.height = 0.9
    stigmata.mesh = sphere
    stigmata.material_override = hand._stigmata_material
    stigmata.position = Vector3(0.0, 0.35, 0.0)
    hand.add_child(stigmata)

    hand.hitbox = Hitbox.new()
    hand.hitbox.name = "SlamHitbox"
    hand.hitbox.team = &"enemy"
    hand.hitbox.damage = 2
    hand.hitbox.category = &"heavy"
    hand.hitbox.knockback = 7.0
    hand.hitbox.knockback_up = 5.0
    hand.hitbox.hitstun = 0.5
    hand.hitbox.attack_id = &"bishop_slam"
    hand.hitbox.add_child(_box_shape(SLAM_ZONE, Vector3(0.0, 0.6, 0.0)))
    hand.add_child(hand.hitbox)

    hand.weak_point = Hurtbox.new()
    hand.weak_point.name = "StigmataWeakPoint"
    hand.weak_point.team = &"enemy"
    hand.weak_point.health = boss_health
    hand.weak_point.add_child(_box_shape(Vector3(2.6, 1.6, 2.8), Vector3(0.0, 0.5, 0.4)))
    hand.add_child(hand.weak_point)

    hand.marker = MeshInstance3D.new()
    hand.marker.name = "SlamTelegraph"
    hand.marker.top_level = true
    var plate: BoxMesh = BoxMesh.new()
    plate.size = Vector3(SLAM_ZONE.x, 0.06, 3.6)
    hand.marker.mesh = plate
    hand.marker.material_override = _warning_material()
    hand.marker.visible = false
    hand.add_child(hand.marker)
    return hand


func _ready() -> void:
    weak_point.set_enabled(false)


## Hurtbox asks the parent: the stigmata only takes damage while exposed.
func is_invulnerable() -> bool:
    return not weak_open


func show_telegraph(x: float, visible_now: bool) -> void:
    marker.visible = visible_now
    marker.global_position = Vector3(x, 0.04, 0.0)


func set_weak(open: bool) -> void:
    weak_open = open
    weak_point.set_enabled(open)
    _stigmata_material.albedo_color = Color(0.95, 0.15, 0.2) if open else Color(0.35, 0.05, 0.08)
    _stigmata_material.emission = Color(1.0, 0.1, 0.15) * 2.0 if open else Color(0.3, 0.02, 0.04)


func _add_box(label: String, box_size: Vector3, at: Vector3, material: Material) -> void:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = label
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = box_size
    node.mesh = mesh
    node.material_override = material
    node.position = at
    add_child(node)


static func _box_shape(box_size: Vector3, at: Vector3) -> CollisionShape3D:
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = box_size
    shape.shape = box
    shape.position = at
    return shape


static func _warning_material() -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.95, 0.08, 0.05, 0.5)
    return material

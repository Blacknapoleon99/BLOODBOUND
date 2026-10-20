class_name BoneLance
extends Node3D
## A lance hurled from the Bishop's depth toward the player plane. The root sits at the
## impact point on Z=0 (where the red column telegraph is); the shaft travels along +Z
## from `start_z` and is only dangerous while crossing the plane (|z| <= DANGER_HALF_DEPTH).
## Avoid it by stepping out of the column, jumping over it, or dodging through it.

const DANGER_HALF_DEPTH: float = 1.3
const HEIGHT: float = 0.9

var speed: float = 16.0
var start_z: float = -21.0
var end_z: float = 5.0
var shaft: Node3D
var hitbox: Hitbox
var column: MeshInstance3D


static func create(target_x: float, from_z: float, travel_speed: float) -> BoneLance:
    var lance: BoneLance = BoneLance.new()
    lance.name = "BoneLance"
    lance.add_to_group(&"boss_lance")
    lance.top_level = true
    lance.position = Vector3(target_x, HEIGHT, 0.0)
    lance.start_z = from_z
    lance.speed = travel_speed

    lance.shaft = Node3D.new()
    lance.shaft.name = "Shaft"
    lance.shaft.position = Vector3(0.0, 0.0, from_z)
    lance.add_child(lance.shaft)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(0.28, 0.28, 3.4)
    mesh_node.mesh = mesh
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.8, 0.76, 0.66)
    bone.emission_enabled = true
    bone.emission = Color(0.35, 0.05, 0.05)
    mesh_node.material_override = bone
    lance.shaft.add_child(mesh_node)

    lance.hitbox = Hitbox.new()
    lance.hitbox.name = "LanceHitbox"
    lance.hitbox.team = &"enemy"
    lance.hitbox.damage = 1
    lance.hitbox.category = &"projectile"
    lance.hitbox.knockback = 5.0
    lance.hitbox.knockback_up = 3.0
    lance.hitbox.hitstun = 0.3
    lance.hitbox.attack_id = &"bishop_lance"
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(1.2, 0.9, 1.6)
    shape.shape = box
    lance.hitbox.add_child(shape)
    lance.shaft.add_child(lance.hitbox)

    lance.column = MeshInstance3D.new()
    lance.column.name = "LaneTelegraph"
    var column_mesh: BoxMesh = BoxMesh.new()
    column_mesh.size = Vector3(1.2, 4.0, 0.25)
    lance.column.mesh = column_mesh
    lance.column.material_override = BishopHand._warning_material()
    lance.column.position = Vector3(0.0, 1.1, 0.0)
    lance.add_child(lance.column)
    return lance


func shaft_z() -> float:
    return shaft.position.z


func _physics_process(delta: float) -> void:
    shaft.position.z += speed * delta
    var dangerous: bool = absf(shaft.position.z) <= DANGER_HALF_DEPTH
    if dangerous and not hitbox.is_active():
        hitbox.activate()
    elif not dangerous and hitbox.is_active():
        hitbox.deactivate()
    column.visible = shaft.position.z < DANGER_HALF_DEPTH
    if shaft.position.z > end_z:
        queue_free()

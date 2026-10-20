class_name BoneArrow
extends Node3D
## An archer's arrow: flies straight along its direction at chest height (Hitbox, team enemy,
## category "projectile"). Jump it, dodge through it, or out-range it.

var direction: Vector3 = Vector3.RIGHT
var speed: float = 14.0
var lifetime: float = 2.0
var hitbox: Hitbox


static func create(from: Vector3, dir: Vector3) -> BoneArrow:
    var arrow: BoneArrow = BoneArrow.new()
    arrow.name = "BoneArrow"
    arrow.add_to_group(&"bone_arrow")
    arrow.top_level = true
    arrow.position = from
    arrow.direction = dir.normalized()
    var shaft: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(0.9, 0.08, 0.08)
    shaft.mesh = mesh
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.85, 0.8, 0.7)
    bone.emission_enabled = true
    bone.emission = Color(0.5, 0.1, 0.05)
    shaft.material_override = bone
    arrow.add_child(shaft)
    arrow.hitbox = Hitbox.new()
    arrow.hitbox.team = &"enemy"
    arrow.hitbox.damage = 1
    arrow.hitbox.category = &"projectile"
    arrow.hitbox.knockback = 3.0
    arrow.hitbox.knockback_up = 2.0
    arrow.hitbox.hitstun = 0.25
    arrow.hitbox.attack_id = &"bone_arrow"
    arrow.hitbox.start_active = true
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(0.9, 0.3, 0.6)
    shape.shape = box
    arrow.hitbox.add_child(shape)
    arrow.hitbox.hit_landed.connect(func(_t: Hurtbox, _i: DamageInfo) -> void: arrow.queue_free())
    arrow.add_child(arrow.hitbox)
    return arrow


func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

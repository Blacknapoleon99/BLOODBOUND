class_name BreakableFloor
extends StaticBody3D
## A cracked slab hiding a secret: it has a Hurtbox (4 HP) — two heavy strikes, a Blood Nova or
## a few jabs break it, and it crumbles away. Never targeted by cards (group no_card_target).

signal broken

var health: Health
var hurtbox: Hurtbox
var is_broken: bool = false
var _material: ShaderMaterial
var _shape: CollisionShape3D


static func create(center: Vector3, size: Vector3) -> BreakableFloor:
    var slab: BreakableFloor = BreakableFloor.new()
    slab.name = "Cracked floor"
    slab.add_to_group(&"breakable")
    slab.position = center
    slab._shape = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    slab._shape.shape = box
    slab.add_child(slab._shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    slab._material = GothicMaterials.block(&"breakable")  # faint red light in the cracks gives it away
    mesh_node.material_override = slab._material
    slab.add_child(mesh_node)
    slab.health = Health.new()
    slab.health.max_health = 4
    slab.add_child(slab.health)
    slab.hurtbox = Hurtbox.new()
    slab.hurtbox.team = &"breakable"
    slab.hurtbox.health = slab.health
    slab.hurtbox.add_to_group(&"no_card_target")
    var hurt_shape: CollisionShape3D = CollisionShape3D.new()
    var hurt_box: BoxShape3D = BoxShape3D.new()
    hurt_box.size = size + Vector3(0.0, 1.2, 0.0)  # reachable by swings from standing on it
    hurt_shape.shape = hurt_box
    hurt_shape.position.y = 0.5
    slab.hurtbox.add_child(hurt_shape)
    slab.add_child(slab.hurtbox)
    slab.health.died.connect(slab._crumble)
    return slab


func _crumble() -> void:
    is_broken = true
    _shape.set_deferred(&"disabled", true)
    hurtbox.set_enabled(false)
    Audio.sfx(&"walls_rise", 0.1, -4.0)
    var tween: Tween = create_tween()
    tween.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.3)
    tween.tween_callback(func() -> void: visible = false)
    broken.emit()

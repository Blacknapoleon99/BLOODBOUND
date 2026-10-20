class_name BloodSpearProjectile
extends Node3D
## Blood Spear in flight: a real moving Hitbox that flies at the target point and damages
## whatever enemy Hurtbox it overlaps. If the weak point closes before it lands, the hurtbox
## rejects the hit — no guaranteed damage.

var speed: float = 30.0
var lifetime: float = 1.2
var target_point: Vector3
var hitbox: Hitbox
var _arrived_frames: int = 0


static func create(from: Vector3, to: Vector3, card: CardData, poise: int = 2) -> BloodSpearProjectile:
    var spear: BloodSpearProjectile = BloodSpearProjectile.new()
    spear.name = "BloodSpear"
    spear.add_to_group(&"blood_spear")
    spear.top_level = true
    spear.position = from
    spear.target_point = to
    spear.hitbox = Hitbox.new()
    spear.hitbox.team = &"player"
    spear.hitbox.damage = card.damage
    spear.hitbox.category = &"card"
    spear.hitbox.knockback = 2.0
    spear.hitbox.knockback_up = 1.0
    spear.hitbox.hitstun = 0.35
    spear.hitbox.poise_damage = poise
    spear.hitbox.attack_id = card.id
    spear.hitbox.start_active = true
    var shape: CollisionShape3D = CollisionShape3D.new()
    var sphere: SphereShape3D = SphereShape3D.new()
    sphere.radius = 0.5
    shape.shape = sphere
    spear.hitbox.add_child(shape)
    spear.add_child(spear.hitbox)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(0.14, 0.14, 1.6)
    mesh_node.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.75, 0.03, 0.06)
    material.emission_enabled = true
    material.emission = Color(1.0, 0.05, 0.08) * 1.5
    mesh_node.material_override = material
    spear.add_child(mesh_node)
    return spear


func _ready() -> void:
    var direction: Vector3 = target_point - global_position
    if direction.length_squared() > 0.001:
        look_at(target_point, Vector3.UP if absf(direction.normalized().y) < 0.98 else Vector3.FORWARD)


func _physics_process(delta: float) -> void:
    lifetime -= delta
    global_position = global_position.move_toward(target_point, speed * delta)
    if global_position.distance_to(target_point) < 0.05:
        _arrived_frames += 1
    # Linger a few frames at the target so the overlap is registered, then vanish.
    if _arrived_frames > 4 or lifetime <= 0.0:
        queue_free()

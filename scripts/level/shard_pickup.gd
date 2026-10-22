class_name ShardPickup
extends Area3D
## A loose Bone Shard floating over an open course (DEC-052): a small glowing bone that spins
## and bobs. Touching it collects it once (`collected` carries the amount; main.gd adds it to
## the run). Placed on optional spots — off the main path, on top of climb towers, at the end
## of a hard jump — to reward the moveset.

signal collected(amount: int, at: Vector3)

var amount: int = 3
var taken: bool = false
var _visual: Node3D
var _t: float = 0.0


static func create(at: Vector3, value: int = 3) -> ShardPickup:
    var pickup: ShardPickup = ShardPickup.new()
    pickup.name = "Bone shard"
    pickup.add_to_group(&"shard_pickup")
    pickup.position = at
    pickup.amount = value
    var shape: CollisionShape3D = CollisionShape3D.new()
    var sphere: SphereShape3D = SphereShape3D.new()
    sphere.radius = 0.7
    shape.shape = sphere
    pickup.add_child(shape)
    pickup._visual = Node3D.new()
    pickup.add_child(pickup._visual)
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.92, 0.86, 0.68)
    bone.emission_enabled = true
    bone.emission = Color(0.95, 0.7, 0.35) * 0.8
    var shard: MeshInstance3D = MeshInstance3D.new()
    var prism: PrismMesh = PrismMesh.new()
    prism.size = Vector3(0.28, 0.5, 0.14)
    shard.mesh = prism
    shard.material_override = bone
    pickup._visual.add_child(shard)
    var tip: MeshInstance3D = MeshInstance3D.new()
    var tip_mesh: PrismMesh = PrismMesh.new()
    tip_mesh.size = Vector3(0.28, 0.3, 0.14)
    tip.mesh = tip_mesh
    tip.material_override = bone
    tip.rotation.z = PI
    tip.position.y = -0.4
    pickup._visual.add_child(tip)
    return pickup


func _ready() -> void:
    monitoring = true
    monitorable = false
    body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
    if taken:
        return
    _t += delta
    _visual.rotation.y = _t * 2.4
    _visual.position.y = sin(_t * 2.0) * 0.12


func _on_body_entered(body: Node3D) -> void:
    if taken or not body.is_in_group(&"player"):
        return
    take()


## Collects the shard (also called by tests).
func take() -> void:
    if taken:
        return
    taken = true
    visible = false
    set_deferred(&"monitoring", false)
    collected.emit(amount, global_position)

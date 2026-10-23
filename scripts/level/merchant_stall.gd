class_name MerchantStall
extends Node3D
## The Pale Merchant's table. E in reach opens the shop (see main.gd _open_shop). Its stock is
## rolled once, on first visit: a card, a relic, a full heal and a card upgrade.

const REACH: float = 2.4

var stock: Array = []  # ShopItem
var stocked: bool = false


static func create(at: Vector3) -> MerchantStall:
    var stall: MerchantStall = MerchantStall.new()
    stall.name = "The Pale Merchant"
    stall.add_to_group(&"merchant")
    stall.position = at
    stall._build()
    return stall


func player_in_reach(player: Node3D) -> bool:
    return player != null and player.global_position.distance_to(global_position + Vector3(0.0, 0.9, 0.0)) < REACH


func _build() -> void:
    var wood: StandardMaterial3D = GothicMaterials.standard("wood", Color(0.75, 0.62, 0.52), 1.2)  # DEC-054
    var table: MeshInstance3D = MeshInstance3D.new()
    var table_mesh: BoxMesh = BoxMesh.new()
    table_mesh.size = Vector3(2.4, 0.9, 1.0)
    table.mesh = table_mesh
    table.material_override = wood
    table.position = Vector3(0.0, 0.45, -1.0)
    add_child(table)
    var pale: StandardMaterial3D = StandardMaterial3D.new()
    pale.albedo_color = Color(0.85, 0.85, 0.8)
    pale.emission_enabled = true
    pale.emission = Color(0.4, 0.45, 0.5) * 0.3
    var body: MeshInstance3D = MeshInstance3D.new()
    var body_mesh: CapsuleMesh = CapsuleMesh.new()
    body_mesh.radius = 0.35
    body_mesh.height = 2.0
    body.mesh = body_mesh
    body.material_override = pale
    body.position = Vector3(0.0, 1.0, -1.9)
    add_child(body)
    var lamp: OmniLight3D = OmniLight3D.new()
    lamp.light_color = Color(0.7, 0.85, 1.0)
    lamp.light_energy = 1.6
    lamp.omni_range = 6.0
    lamp.position = Vector3(0.0, 2.2, -1.0)
    add_child(lamp)

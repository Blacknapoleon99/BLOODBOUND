class_name BloodAltar
extends Node3D
## A one-use shrine: stand by it and press E to choose 1 of 3 new cards for the run's deck.
## Glows while unused, goes dark once used.

const RADIUS: float = 1.3

var used: bool = false
var _glow: StandardMaterial3D


static func create(label: String, at: Vector3) -> BloodAltar:
    var altar: BloodAltar = BloodAltar.new()
    altar.name = label
    altar.add_to_group(&"blood_altar")
    altar.position = at
    var stone: StandardMaterial3D = GothicMaterials.standard("masonry", Color(0.62, 0.56, 0.56), 1.2)  # DEC-054
    var pillar: MeshInstance3D = MeshInstance3D.new()
    var pillar_mesh: BoxMesh = BoxMesh.new()
    pillar_mesh.size = Vector3(0.7, 1.0, 0.7)
    pillar.mesh = pillar_mesh
    pillar.material_override = stone
    pillar.position = Vector3(0.0, 0.5, -1.2)
    altar.add_child(pillar)
    var bowl: MeshInstance3D = MeshInstance3D.new()
    var bowl_mesh: CylinderMesh = CylinderMesh.new()
    bowl_mesh.top_radius = 0.55
    bowl_mesh.bottom_radius = 0.3
    bowl_mesh.height = 0.25
    bowl.mesh = bowl_mesh
    altar._glow = StandardMaterial3D.new()
    altar._glow.albedo_color = Color(0.7, 0.05, 0.08)
    altar._glow.emission_enabled = true
    altar._glow.emission = Color(1.0, 0.1, 0.12) * 1.5
    bowl.material_override = altar._glow
    bowl.position = Vector3(0.0, 1.12, -1.2)
    altar.add_child(bowl)
    return altar


func player_in_reach(player: Node3D) -> bool:
    return not used and absf(player.global_position.x - global_position.x) <= RADIUS and absf(player.global_position.y - global_position.y) < 2.0 and absf(player.global_position.z - global_position.z) < 3.0


func consume() -> void:
    used = true
    _glow.albedo_color = Color(0.15, 0.12, 0.13)
    _glow.emission = Color.BLACK

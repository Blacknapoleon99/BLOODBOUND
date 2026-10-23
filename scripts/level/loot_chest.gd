class_name LootChest
extends Node3D
## A reliquary: rises glowing from the floor. E in reach opens its offer, by `kind`:
## &"items" (the Bishop: 1 of 3 unowned items into the stash), &"relics" (elite: 1 of 3 relics),
## &"card" (secret: 1 of 3 cards), &"shards" (secret: `shards` Bone Shards at once).

signal opened

const REACH: float = 2.2

var used: bool = false
var kind: StringName = &"items"
var shards: int = 0
## Rolled on first open and kept, so skipping and reopening never rerolls.
var offer: Array = []
var _lid: MeshInstance3D
var _glow: StandardMaterial3D
var _light: OmniLight3D
var _t: float = 0.0


static func create(at: Vector3) -> LootChest:
    var chest: LootChest = LootChest.new()
    chest.name = "BishopReliquary"
    chest.add_to_group(&"loot_chest")
    chest.position = at
    chest._build()
    return chest


func player_in_reach(player: Node3D) -> bool:
    return not used and player != null and player.global_position.distance_to(global_position + Vector3(0.0, 0.8, 0.0)) < REACH


func consume() -> void:
    used = true
    _glow.emission = Color(0.3, 0.2, 0.1)
    _light.light_energy = 0.3
    _lid.rotation.z = -1.1
    opened.emit()


func _build() -> void:
    var gold: StandardMaterial3D = GothicMaterials.standard("wood", Color(0.85, 0.66, 0.42), 0.8)  # DEC-054
    var model_body: ArrayMesh = GothicProps.mesh("chest_body", {&"wood": gold})
    if model_body != null and GothicProps.available("chest_lid"):
        _build_model(gold)
        return
    var body: MeshInstance3D = MeshInstance3D.new()
    var body_mesh: BoxMesh = BoxMesh.new()
    body_mesh.size = Vector3(1.2, 0.7, 0.8)
    body.mesh = body_mesh
    body.material_override = gold
    body.position.y = 0.35
    add_child(body)
    _glow = StandardMaterial3D.new()
    _glow.albedo_color = Color(0.9, 0.15, 0.12)
    _glow.emission_enabled = true
    _glow.emission = Color(1.0, 0.25, 0.1) * 2.0
    _lid = MeshInstance3D.new()
    var lid_mesh: BoxMesh = BoxMesh.new()
    lid_mesh.size = Vector3(1.25, 0.18, 0.85)
    _lid.mesh = lid_mesh
    _lid.material_override = _glow
    _lid.position = Vector3(0.0, 0.79, 0.0)
    add_child(_lid)
    _light = OmniLight3D.new()
    _light.light_color = Color(1.0, 0.4, 0.2)
    _light.light_energy = 2.5
    _light.omni_range = 5.0
    _light.position.y = 1.4
    add_child(_light)
    scale = Vector3(0.01, 0.01, 0.01)


## The modelled reliquary (DEC-057): planked, iron-banded chest with corner brackets, a lock
## plate, a glowing interior and keyhole, and a barrel lid hinged at the back (+X) edge, so the
## same `_lid.rotation.z = -1.1` swings it open. `_glow` drives the keyhole, gem and interior.
func _build_model(wood: StandardMaterial3D) -> void:
    _glow = StandardMaterial3D.new()
    _glow.albedo_color = Color(0.9, 0.15, 0.12)
    _glow.emission_enabled = true
    _glow.emission = Color(1.0, 0.25, 0.1) * 2.0
    var body: MeshInstance3D = GothicProps.instance("chest_body", {&"wood": wood, &"glow": _glow}, "Chest")
    add_child(body)
    _lid = MeshInstance3D.new()
    _lid.name = "Lid"
    _lid.mesh = GothicProps.mesh("chest_lid", {&"wood": wood, &"glow": _glow})
    _lid.position = Vector3(0.62, 0.62, 0.0)
    add_child(_lid)
    _light = OmniLight3D.new()
    _light.light_color = Color(1.0, 0.4, 0.2)
    _light.light_energy = 2.5
    _light.omni_range = 5.0
    _light.position.y = 1.4
    add_child(_light)
    scale = Vector3(0.01, 0.01, 0.01)


func _process(delta: float) -> void:
    _t += delta
    scale = scale.lerp(Vector3.ONE, minf(1.0, 6.0 * delta))  # rises out of the stone
    if not used:
        _light.light_energy = 2.0 + 0.8 * sin(_t * 4.0)

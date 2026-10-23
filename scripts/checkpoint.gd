class_name Checkpoint
extends Area3D
## Trigger volume that records a respawn point when the player enters it.
## Built in code so greybox levels can place one with a single call.

signal activated(checkpoint: Checkpoint)

const IDLE_COLOR: Color = Color(0.35, 0.33, 0.40)
const ACTIVE_COLOR: Color = Color(0.86, 0.10, 0.16)

## World position the player is restored to; defaults to the trigger's position.
var respawn_position: Vector3
var is_active: bool = false
var _banner_material: StandardMaterial3D


static func create(at: Vector3, trigger_size: Vector3 = Vector3(2.0, 3.0, 3.0)) -> Checkpoint:
    var checkpoint: Checkpoint = Checkpoint.new()
    checkpoint.name = "Checkpoint"
    checkpoint.position = at
    checkpoint.respawn_position = at
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = trigger_size
    shape.shape = box
    checkpoint.add_child(shape)

    # Modelled standard (DEC-057): stone foot, iron pole and crossbar, skull finial and a
    # tattered cloth banner whose material turns from ash-grey to blood-red when lit. The
    # checkpoint origin is 1.2 m above the floor.
    var cloth: ArrayMesh = GothicProps.raw("checkpoint_cloth")
    var standard: MeshInstance3D = GothicProps.instance("checkpoint_banner", {}, "Standard")
    if cloth != null and standard != null:
        standard.position = Vector3(0.0, -1.2, -0.9)
        checkpoint.add_child(standard)
        checkpoint._banner_material = GothicMaterials.standard("cloth", IDLE_COLOR * 1.6, 0.5, false)
        checkpoint._banner_material.cull_mode = BaseMaterial3D.CULL_DISABLED
        var flag: MeshInstance3D = GothicProps.instance("checkpoint_cloth", {&"cloth": checkpoint._banner_material}, "Banner")
        flag.position = standard.position
        checkpoint.add_child(flag)
        return checkpoint
    var banner: MeshInstance3D = MeshInstance3D.new()
    banner.name = "Banner"
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(0.18, 2.2, 0.18)
    banner.mesh = mesh
    banner.position = Vector3(0.0, 0.2, -0.9)
    checkpoint._banner_material = StandardMaterial3D.new()
    checkpoint._banner_material.albedo_color = IDLE_COLOR
    banner.material_override = checkpoint._banner_material
    checkpoint.add_child(banner)
    return checkpoint


func _ready() -> void:
    monitoring = true
    monitorable = false
    body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
    if is_active or not body.is_in_group(&"player"):
        return
    is_active = true
    if _banner_material:
        _banner_material.albedo_color = ACTIVE_COLOR
        _banner_material.emission_enabled = true
        _banner_material.emission = ACTIVE_COLOR * 0.6
    activated.emit(self)

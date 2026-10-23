class_name CollapsingSlab
extends StaticBody3D
## A slab that trembles once the player stands on it, drops after `collapse_delay`, and
## returns after `respawn_delay` (or immediately via `restore()` when the player respawns).
## Running across never triggers a fall; standing still does.

signal collapsed(slab: CollapsingSlab)

@export var collapse_delay: float = 0.7
@export var respawn_delay: float = 4.0

var is_collapsed: bool = false
var size: Vector3
var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _base_color: Color
var _trigger: Area3D
var _armed_left: float = -1.0
var _respawn_left: float = 0.0


static func create(label: String, center: Vector3, slab_size: Vector3) -> CollapsingSlab:
    var slab: CollapsingSlab = CollapsingSlab.new()
    slab.name = label
    slab.position = center
    slab.size = slab_size
    slab._shape = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = slab_size
    slab._shape.shape = box
    slab.add_child(slab._shape)
    slab._mesh = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = slab_size
    slab._mesh.mesh = mesh
    slab._base_color = Color(0.32, 0.24, 0.22)
    slab._material = GothicMaterials.unique(&"cracked")  # its own copy: it flashes red (DEC-054)
    slab._mesh.material_override = slab._material
    slab.add_child(slab._mesh)
    # Thin sensor on top: detects the player standing on the slab.
    slab._trigger = Area3D.new()
    var sensor: CollisionShape3D = CollisionShape3D.new()
    var sensor_box: BoxShape3D = BoxShape3D.new()
    sensor_box.size = Vector3(slab_size.x - 0.1, 0.3, slab_size.z)
    sensor.shape = sensor_box
    sensor.position = Vector3(0.0, slab_size.y * 0.5 + 0.15, 0.0)
    slab._trigger.add_child(sensor)
    slab.add_child(slab._trigger)
    return slab


func _ready() -> void:
    _trigger.body_entered.connect(func(body: Node3D) -> void:
        if body.is_in_group(&"player") and not is_collapsed and _armed_left < 0.0:
            _armed_left = collapse_delay)


func _physics_process(delta: float) -> void:
    if is_collapsed:
        _respawn_left -= delta
        if _respawn_left <= 0.0:
            restore()
        return
    if _armed_left >= 0.0:
        _armed_left -= delta
        # Tremble: readable warning before the drop.
        _mesh.position = Vector3(randf_range(-0.05, 0.05), randf_range(-0.03, 0.03), 0.0)
        _material.set_shader_parameter(&"flash", Color(0.6, 0.15, 0.1, 1.0 - maxf(0.0, _armed_left) / collapse_delay))
        if _armed_left <= 0.0:
            _collapse()


func _collapse() -> void:
    is_collapsed = true
    _armed_left = -1.0
    _respawn_left = respawn_delay
    _shape.set_deferred(&"disabled", true)
    _mesh.visible = false
    collapsed.emit(self)


func restore() -> void:
    is_collapsed = false
    _armed_left = -1.0
    _mesh.visible = true
    _mesh.position = Vector3.ZERO
    _material.set_shader_parameter(&"flash", Color(0.6, 0.15, 0.1, 0.0))
    _shape.set_deferred(&"disabled", false)

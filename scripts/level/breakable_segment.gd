class_name BreakableSegment
extends StaticBody3D
## One causeway slab that a boss attack can knock away. Breaking only disables collision and
## drops the visual, so restoring is exact and cheap (no physics debris to clean up).

signal broken(segment: BreakableSegment)
signal restored(segment: BreakableSegment)

var breakable: bool = true
var is_broken: bool = false
var size: Vector3
var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _tween: Tween


static func create(label: String, center: Vector3, slab_size: Vector3, color: Color, can_break: bool) -> BreakableSegment:
    var segment: BreakableSegment = BreakableSegment.new()
    segment.name = label
    segment.position = center
    segment.size = slab_size
    segment.breakable = can_break
    segment._shape = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = slab_size
    segment._shape.shape = box
    segment.add_child(segment._shape)
    segment._mesh = MeshInstance3D.new()
    segment._mesh.name = "Slab"
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = slab_size
    segment._mesh.mesh = mesh
    # Flagstone (DEC-054); breakable slabs stay a shade lighter than the solid ends.
    var tone: Color = Color(0.82, 0.78, 0.74) if can_break else Color(0.6, 0.57, 0.56)
    segment._material = GothicMaterials.standard("flagstone", tone.lerp(color * 4.0, 0.15), 2.6)
    segment._mesh.material_override = segment._material
    segment.add_child(segment._mesh)
    return segment


func top_y() -> float:
    return global_position.y + size.y * 0.5


func contains_x(x: float) -> bool:
    return absf(x - global_position.x) <= size.x * 0.5


func break_apart() -> void:
    if is_broken:
        return
    is_broken = true
    _shape.set_deferred(&"disabled", true)
    _kill_tween()
    _tween = create_tween()
    _tween.tween_property(_mesh, "position", Vector3(0.0, -7.0, 0.0), 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    _tween.parallel().tween_property(_mesh, "rotation", Vector3(0.0, 0.0, randf_range(-0.5, 0.5)), 0.9)
    _tween.tween_callback(func() -> void: _mesh.visible = false)
    broken.emit(self)


func restore() -> void:
    if not is_broken:
        return
    is_broken = false
    _kill_tween()
    _mesh.visible = true
    _mesh.position = Vector3.ZERO
    _mesh.rotation = Vector3.ZERO
    _shape.set_deferred(&"disabled", false)
    restored.emit(self)


func _kill_tween() -> void:
    if _tween and _tween.is_valid():
        _tween.kill()

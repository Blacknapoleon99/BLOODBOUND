class_name BossArena
extends Node3D
## The Bishop's causeway: a row of BreakableSegments plus the rules that keep it winnable.
##
## Recoverability rules (a broken causeway must never softlock the fight):
## - The first and last segments never break (arena entry / checkpoint and the far wall).
## - A segment next to an already-broken one never breaks, so every gap is one segment
##   (4 m) wide: a full-speed jump spans ~5.6 m.
## - At most `max_broken` segments are down at once.
## - Each broken segment has a low rubble ledge (top 1 m below the causeway) as a fallback step.
## - Broken segments reknit after `restore_after` seconds, and all of them reset when the
##   player dies or falls (`restore_all`).

signal segment_broken(index: int)

@export var segment_count: int = 7
@export var segment_length: float = 4.0
@export var max_broken: int = 2
@export var restore_after: float = 14.0

var segments: Array[BreakableSegment] = []
var rubble: Array[StaticBody3D] = []
var _restore_timers: Array[float] = []


## Builds the causeway starting at `start_x` (left edge), with its top surface at y = 0.
func build(start_x: float) -> void:
    for i in segment_count:
        var center: Vector3 = Vector3(start_x + segment_length * (i + 0.5), -0.5, 0.0)
        var can_break: bool = i != 0 and i != segment_count - 1
        var tint: float = 0.02 * float(i % 2)
        var segment: BreakableSegment = BreakableSegment.create("Bishop causeway %d" % i, center,
            Vector3(segment_length - 0.04, 1.0, 4.0), Color(0.19 + tint, 0.17, 0.21), can_break)
        add_child(segment)
        segments.append(segment)
        _restore_timers.append(0.0)
        rubble.append(_make_rubble(center))


func left_x() -> float:
    return segments[0].global_position.x - segment_length * 0.5


func right_x() -> float:
    return segments[segment_count - 1].global_position.x + segment_length * 0.5


func segment_index_at(x: float) -> int:
    for i in segments.size():
        if segments[i].contains_x(x):
            return i
    return -1


func broken_count() -> int:
    var count: int = 0
    for segment: BreakableSegment in segments:
        if segment.is_broken:
            count += 1
    return count


func can_break(index: int) -> bool:
    if index < 0 or index >= segments.size():
        return false
    var segment: BreakableSegment = segments[index]
    if not segment.breakable or segment.is_broken or broken_count() >= max_broken:
        return false
    for n: int in [index - 1, index + 1]:
        if n >= 0 and n < segments.size() and segments[n].is_broken:
            return false
    return true


## Breaks the segment under `x` if the rules allow it. Returns true when it broke.
func break_at(x: float) -> bool:
    var index: int = segment_index_at(x)
    if not can_break(index):
        return false
    segments[index].break_apart()
    _set_rubble(index, true)
    _restore_timers[index] = restore_after
    segment_broken.emit(index)
    return true


func restore_all() -> void:
    for i in segments.size():
        _restore(i)


func _physics_process(delta: float) -> void:
    for i in segments.size():
        if segments[i].is_broken:
            _restore_timers[i] -= delta
            if _restore_timers[i] <= 0.0:
                _restore(i)


func _restore(index: int) -> void:
    segments[index].restore()
    _set_rubble(index, false)


func _make_rubble(center: Vector3) -> StaticBody3D:
    var body: StaticBody3D = StaticBody3D.new()
    body.name = "Rubble ledge"
    body.position = Vector3(center.x, -1.2, 0.0)
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(1.6, 0.4, 3.0)
    shape.shape = box
    shape.disabled = true
    body.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = box.size
    mesh_node.mesh = mesh
    mesh_node.material_override = GothicMaterials.block(&"wall")  # DEC-054
    body.add_child(mesh_node)
    body.visible = false
    add_child(body)
    return body


func _set_rubble(index: int, enabled: bool) -> void:
    var body: StaticBody3D = rubble[index]
    body.visible = enabled
    (body.get_child(0) as CollisionShape3D).set_deferred(&"disabled", not enabled)

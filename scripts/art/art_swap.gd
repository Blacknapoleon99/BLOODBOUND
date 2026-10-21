class_name ArtSwap
extends RefCounted
## Visual-only swap of greybox meshes for authored GLB models (see docs/ASSET_LIST.md).
## Collision and gameplay nodes are never touched: the greybox MeshInstance3D is hidden and the
## model is added next to it under an "ArtModel" node, so turning art off restores the greybox.
## Toggle: `ArtSwap.enabled = false` before the level builds, or launch with `-- --greybox`.

static var enabled: bool = true

## Modular causeway segment: 4 x 1 x 4 m, pivot at its centre (matches a BoxMesh), front face +Z.
const CAUSEWAY_SEGMENT_PATH: String = "res://assets/models/environment/causeway_segment_4m.glb"
const CAUSEWAY_SEGMENT_LENGTH: float = 4.0
## Greybox solids (main.gd `_make_solid` labels) that get the causeway segment. One for now.
const CAUSEWAY_SOLIDS: Array[String] = ["Starting causeway"]


static func is_active() -> bool:
    return enabled and not OS.get_cmdline_user_args().has("--greybox")


## Swaps every listed greybox solid under `level`. Returns how many were swapped.
static func apply(level: Node3D) -> int:
    if not is_active():
        return 0
    var segment: PackedScene = load(CAUSEWAY_SEGMENT_PATH) as PackedScene
    if segment == null:
        push_warning("ArtSwap: %s missing, keeping greybox" % CAUSEWAY_SEGMENT_PATH)
        return 0
    var swapped: int = 0
    for label: String in CAUSEWAY_SOLIDS:
        var body: Node3D = level.get_node_or_null(NodePath(label)) as Node3D
        if body != null and tile_box(body, label + " appearance", segment, CAUSEWAY_SEGMENT_LENGTH):
            swapped += 1
    return swapped


## Hides `body`'s box MeshInstance3D and covers the same box with copies of `model` laid end to
## end along X (stretched slightly so whole segments fit; Y and Z scaled to the box).
static func tile_box(body: Node3D, mesh_name: String, model: PackedScene, length: float) -> bool:
    var greybox: MeshInstance3D = body.get_node_or_null(NodePath(mesh_name)) as MeshInstance3D
    if greybox == null or not (greybox.mesh is BoxMesh):
        return false
    var size: Vector3 = (greybox.mesh as BoxMesh).size
    var count: int = maxi(1, roundi(size.x / length))
    var step: float = size.x / count
    var art: Node3D = Node3D.new()
    art.name = "ArtModel"
    art.position = greybox.position
    for i in count:
        var piece: Node3D = model.instantiate() as Node3D
        piece.position = Vector3(-size.x * 0.5 + step * (i + 0.5), 0.0, 0.0)
        piece.scale = Vector3(step / length, size.y, size.z / length)
        art.add_child(piece)
    body.add_child(art)
    greybox.visible = false
    return true

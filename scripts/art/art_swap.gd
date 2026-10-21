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

## The Hollow Bishop (Tripo3D, cleaned in Blender): body authored in boss-local metres (hem at
## y -12, mitre tip at 18.5) and the slam hand palm-up with its origin on the stigmata socket.
const BISHOP_BODY_PATH: String = "res://assets/models/boss/bishop_body.glb"
const BISHOP_HAND_PATH: String = "res://assets/models/boss/bishop_hand.glb"
## Greybox boxes the body model replaces (Heart stays: its glow is the weak-window cue;
## SlamArm stays: the code stretches it to the hand every frame).
const BISHOP_PARTS: Array[String] = ["Robe", "Spine", "Shoulders", "Mitre", "LeftArm", "Skull", "Rib", "Eye"]
const HAND_PARTS: Array[String] = ["Palm", "Finger", "Thumb"]

## Enemies spawn at runtime (rooms, ambushes), so they are dressed as they enter the tree.
## Per enemy class: the visual node (property or child path), greybox meshes to hide, and the
## model's fit. Tripo models are 1 m tall, feet at the origin, facing +Z; `yaw` turns that front
## to the visual's own forward (-Z for scripts that aim it with looking_at, +X for ones that
## mirror scale.x), `height` is metres, `feet` the y of the soles inside the visual.
const ENEMY_MODELS: Dictionary = {
    &"PlaguedSoldier": {"path": "res://assets/models/enemies/plagued_soldier.glb", "visual": "visual",
        "hide": ["Body", "Head"], "yaw": PI, "height": 1.8, "feet": -0.9},
    &"FlyingWraith": {"path": "res://assets/models/enemies/flying_wraith.glb", "visual": "_visual",
        "hide": ["Shroud", "Skull"], "yaw": PI * 0.5, "height": 1.5, "feet": -0.65},
}


static func is_active() -> bool:
    return enabled and not OS.get_cmdline_user_args().has("--greybox")


## Swaps every listed greybox solid under `level`. Returns how many were swapped.
static func apply(level: Node3D) -> int:
    if not is_active():
        return 0
    var tree: SceneTree = level.get_tree()
    if tree != null and not tree.node_added.is_connected(_on_node_added):
        tree.node_added.connect(_on_node_added)
    for node: Node in level.find_children("*", "", true, false):  # enemies placed by the build
        var cfg: Dictionary = _enemy_config(node)
        if not cfg.is_empty() and node.is_node_ready():
            _dress_enemy(node, cfg)
    var segment: PackedScene = load(CAUSEWAY_SEGMENT_PATH) as PackedScene
    if segment == null:
        push_warning("ArtSwap: %s missing, keeping greybox" % CAUSEWAY_SEGMENT_PATH)
        return 0
    var swapped: int = 0
    for label: String in CAUSEWAY_SOLIDS:
        var body: Node3D = level.get_node_or_null(NodePath(label)) as Node3D
        if body != null and tile_box(body, label + " appearance", segment, CAUSEWAY_SEGMENT_LENGTH):
            swapped += 1
    var bishop: Node3D = level.get_node_or_null("HollowBishop") as Node3D
    if bishop != null and dress(bishop, BISHOP_PARTS, BISHOP_BODY_PATH) != null:
        swapped += 1
        var hand: Node3D = bishop.get("hand") as Node3D
        if hand != null and dress(hand, HAND_PARTS, BISHOP_HAND_PATH) != null:
            swapped += 1
    return swapped


## Hides `owner`'s direct MeshInstance3D children whose names contain any of `prefixes` and
## adds the model at `owner`'s origin. Returns the model, or null (greybox untouched) if missing.
static func dress(owner: Node3D, prefixes: Array[String], model_path: String) -> Node3D:
    var model: PackedScene = load(model_path) as PackedScene
    if model == null:
        push_warning("ArtSwap: %s missing, keeping greybox" % model_path)
        return null
    for child: Node in owner.get_children():
        # Duplicate greybox labels (the Bishop's two "Eye" boxes) come back auto-named "@...@n".
        var label: String = String(child.name)
        if child is MeshInstance3D and (label.begins_with("@") or prefixes.any(func(p: String) -> bool: return label.contains(p))):
            (child as MeshInstance3D).visible = false
    var art: Node3D = model.instantiate() as Node3D
    art.name = "ArtModel"
    owner.add_child(art)
    return art


static func _on_node_added(node: Node) -> void:
    if not is_active():
        return
    var cfg: Dictionary = _enemy_config(node)
    if not cfg.is_empty():
        node.ready.connect(_dress_enemy.bind(node, cfg), CONNECT_ONE_SHOT)


static func _enemy_config(node: Node) -> Dictionary:
    var script: Script = node.get_script() as Script
    return {} if script == null else ENEMY_MODELS.get(StringName(script.get_global_name()), {})


## Runs after the enemy's own _ready has built its greybox visual.
static func _dress_enemy(enemy: Node, cfg: Dictionary) -> void:
    var visual_ref: Variant = enemy.get(cfg["visual"])
    var visual: Node3D = visual_ref as Node3D if visual_ref is Node3D else enemy.get_node_or_null(String(cfg["visual"])) as Node3D
    if visual == null or visual.has_node("ArtModel"):
        return
    var hide: Array[String] = []
    hide.assign(cfg["hide"])
    var art: Node3D = dress(visual, hide, cfg["path"])
    if art == null:
        return
    var h: float = cfg["height"]
    art.transform = Transform3D(Basis(Vector3.UP, cfg["yaw"]).scaled(Vector3.ONE * h), Vector3(0.0, cfg["feet"], 0.0))
    play_loop(art, &"idle")


## Plays `anim` looped on the model's AnimationPlayer, if it has one.
static func play_loop(model: Node, anim: StringName) -> void:
    var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
    if players.is_empty():
        return
    var player: AnimationPlayer = players[0] as AnimationPlayer
    if not player.has_animation(anim):
        return
    player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
    player.play(anim)


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

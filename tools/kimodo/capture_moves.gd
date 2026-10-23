extends SceneTree
## In-game capture of the 3D hero's moveset (DEC-059), windowed (needs a renderer):
##   godot --path . -s res://tools/kimodo/capture_moves.gd -- <out dir>
## Plays the movement playground with real input and saves contact sheets of the game camera:
## anim_3d_combo.png (light combo 1-2-3, then the heavy), anim_3d_moves.png (run, jump, triple
## jump flip, backflip, crouch slide, roll), anim_3d_wall.png (ledge hang, shimmy, pull-up, climb).

const CELL: Vector2i = Vector2i(320, 240)
const COLS: int = 8

var _out: String = "docs/screenshots"
var _p: CharacterBody3D
var _cam: ThirdPersonCamera
var _stations: Dictionary = {}


func _init() -> void:
    _run.call_deferred()


func _key(code: Key, pressed: bool) -> void:
    var ev: InputEventKey = InputEventKey.new()
    ev.keycode = code
    ev.physical_keycode = code
    ev.pressed = pressed
    Input.parse_input_event(ev)


func _wait(seconds: float) -> void:
    var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
    while Time.get_ticks_msec() < end:
        await physics_frame


func _shot() -> Image:
    await RenderingServer.frame_post_draw
    var img: Image = root.get_viewport().get_texture().get_image()
    img.convert(Image.FORMAT_RGB8)
    # Crop a box around the hero (projected from the game camera), then scale to a cell.
    var w: int = img.get_width()
    var h: int = img.get_height()
    var cam3d: Camera3D = root.get_viewport().get_camera_3d()
    var centre: Vector2 = Vector2(w, h) * 0.5
    if cam3d != null:
        centre = cam3d.unproject_position(_p.global_position + Vector3.UP * 0.4)
    var ch: int = int(h * 0.5)
    var cw: int = int(ch * 4.0 / 3.0)
    var x0: int = clampi(int(centre.x) - cw / 2, 0, w - cw)
    var y0: int = clampi(int(centre.y) - ch / 2, 0, h - ch)
    var crop: Image = img.get_region(Rect2i(x0, y0, cw, ch))
    crop.resize(CELL.x, CELL.y)
    return crop


## Captures `count` frames `step` seconds apart while `action` (a Callable started first) runs.
func _sequence(frames: Array[Image], count: int, step: float, action: Callable) -> void:
    action.call()
    for i in count:
        frames.append(await _shot())
        await _wait(step)


func _save(frames: Array[Image], name: String) -> void:
    var rows: int = int(ceil(frames.size() / float(COLS)))
    var sheet: Image = Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGB8)
    sheet.fill(Color(0.1, 0.1, 0.1))
    for i in frames.size():
        sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y))
    sheet.save_png("%s/%s" % [_out, name])
    print("wrote %s/%s (%d frames)" % [_out, name, frames.size()])


func _station(spot: Vector3, yaw: float) -> void:
    for k: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_CTRL, KEY_J, KEY_L]:
        _key(k, false)
    _p.call("teleport_to", spot)
    _cam.yaw = yaw
    await _wait(0.6)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() > 0:
        _out = args[0]
    root.size = Vector2i(1280, 720)
    change_scene_to_file("res://scenes/playground_3d.tscn")
    for i in 20:
        await process_frame
    var room: Node = current_scene
    _p = room.get("player")
    _cam = room.get("cam")
    _stations = room.get("stations")

    # Combo: the light swings 1-2-3 (held J), then the heavy (L).
    var combo: Array[Image] = []
    await _station(_stations["momentum"], -PI * 0.5 + 0.9)
    await _sequence(combo, 16, 0.05, func() -> void: _key(KEY_J, true))
    _key(KEY_J, false)
    await _wait(0.6)
    await _sequence(combo, 16, 0.06, func() -> void: _key(KEY_L, true))
    _key(KEY_L, false)
    _save(combo, "anim_3d_combo.png")

    # Moves: run, jump, triple jump flip, backflip, crouch slide, dodge roll.
    var moves: Array[Image] = []
    await _station(_stations["momentum"], -PI * 0.5 + 1.2)
    _key(KEY_W, true)
    await _sequence(moves, 4, 0.25, func() -> void: pass)
    await _sequence(moves, 4, 0.1, func() -> void: _key(KEY_SPACE, true))
    _key(KEY_SPACE, false)
    _key(KEY_W, false)
    await _station(_stations["triple"], 1.2)
    _key(KEY_CTRL, true)
    await _wait(0.1)
    await _sequence(moves, 8, 0.08, func() -> void: _key(KEY_SPACE, true))
    _key(KEY_SPACE, false)
    _key(KEY_CTRL, false)
    await _station(_stations["momentum"], -PI * 0.5 + 1.2)
    _key(KEY_W, true)
    await _wait(0.9)
    await _sequence(moves, 4, 0.12, func() -> void: _key(KEY_CTRL, true))
    _key(KEY_CTRL, false)
    _key(KEY_W, false)
    await _wait(0.5)
    await _sequence(moves, 4, 0.1, func() -> void: _key(KEY_SHIFT, true))
    _key(KEY_SHIFT, false)
    _save(moves, "anim_3d_moves.png")

    # Wall: grab the ledge, hang, shimmy, pull up; climb.
    var wall: Array[Image] = []
    await _station(_stations["ledge"], 0.6)
    _key(KEY_W, true)
    await _wait(0.13)
    _key(KEY_SPACE, true)
    await _wait(0.8)
    _key(KEY_W, false)
    _key(KEY_SPACE, false)
    await _sequence(wall, 3, 0.2, func() -> void: pass)
    await _sequence(wall, 5, 0.12, func() -> void: _key(KEY_D, true))
    _key(KEY_D, false)
    await _wait(0.4)
    await _sequence(wall, 4, 0.08, func() -> void: _key(KEY_SPACE, true))
    _key(KEY_SPACE, false)
    await _station(_stations["climb"], 0.6)
    _key(KEY_W, true)
    await _wait(0.1)
    _key(KEY_SPACE, true)
    await _wait(0.07)
    _key(KEY_SPACE, false)
    await _sequence(wall, 8, 0.15, func() -> void: pass)
    _key(KEY_W, false)
    _save(wall, "anim_3d_wall.png")
    quit(0)

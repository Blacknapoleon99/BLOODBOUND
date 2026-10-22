extends SceneTree
## Captures the full-3D prototype room (visible window only): free camera, running, and locked
## onto a soldier mid-swing. Writes docs/screenshots/22_proto3d_*.png. The mouse stays free.

func _initialize() -> void:
    _run.call_deferred()


func _key(code: Key, down: bool) -> void:
    var ev: InputEventKey = InputEventKey.new()
    ev.keycode = code
    ev.physical_keycode = code
    ev.pressed = down
    Input.parse_input_event(ev)


func _wait(seconds: float) -> void:
    for i in int(seconds * 60.0):
        await physics_frame


func _shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/" + ("22_proto3d_%s.png" % name))


func _run() -> void:
    GameSettings.persistence_enabled = false
    change_scene_to_file("res://scenes/proto_3d.tscn")
    for i in 20:
        await process_frame
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var room: Node3D = current_scene
    var cam: ThirdPersonCamera = room.get("cam")
    for s: Node in room.get("soldiers"):
        (s as PlaguedSoldier).set_ai_enabled(false)
    cam.yaw = 0.6
    await _wait(1.0)
    await _shot("1_overview")
    _key(KEY_W, true)
    await _wait(0.5)
    await _shot("2_running")
    _key(KEY_W, false)
    cam.yaw = 0.0
    await _wait(0.4)
    _key(KEY_Q, true)
    await _wait(0.05)
    _key(KEY_Q, false)
    await _wait(0.8)
    _key(KEY_J, true)
    await _wait(0.25)
    await _shot("3_locked_swing")
    _key(KEY_J, false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    quit()

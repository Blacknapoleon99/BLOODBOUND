extends SceneTree
## Captures the gothic full-3D look (DEC-053; visible window only): the 3D run from the play
## camera (toward the moon, side-on, back) and an overview, then the movement playground.
## Prints the average fps over a 3 s settle per scene. Writes docs/screenshots/23_gothic_*.png
## (or to the folder given after "--"). Pass "low" as the 2nd user arg for the low preset.

var out: String = "res://docs/screenshots"


func _initialize() -> void:
    _run.call_deferred()


func _wait(seconds: float) -> void:
    for i in int(seconds * 60.0):
        await process_frame


func _shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png(out.path_join("23_gothic_%s.png" % name))


func _fps(label: String) -> void:
    var frames: int = 0
    var start: int = Time.get_ticks_usec()
    while Time.get_ticks_usec() - start < 3000000:
        await process_frame
        frames += 1
    print("FPS %s: %.1f (%s, %s)" % [label, frames / ((Time.get_ticks_usec() - start) / 1e6),
        RenderingServer.get_current_rendering_method(), "high" if GameSettings.high_quality else "low"])


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if not args.is_empty():
        out = args[0]
    GameSettings.persistence_enabled = false
    GameSettings.high_quality = not (args.size() > 1 and args[1] == "low")
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    LevelLayout.classic = false
    RunState.full_3d = true
    RunState.new_run(77)
    change_scene_to_file("res://scenes/main.tscn")
    await _wait(0.5)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var main: Node3D = current_scene as Node3D
    var cam: ThirdPersonCamera = main.get("cam3d")
    await _fps("3D run")
    var views: Array = [["run_moon", -1.15, -0.12], ["run_ahead", -PI * 0.5, -0.3], ["run_side", 0.2, -0.25], ["run_back", PI * 0.5, -0.2]]
    for v: Array in views:
        cam.yaw = v[1]
        cam.pitch = v[2]
        await _wait(0.6)
        await _shot(v[0])
    var player: Node3D = main.get("player")
    var eye: Camera3D = Camera3D.new()
    eye.fov = 60.0
    main.add_child(eye)
    var c: Vector3 = player.global_position + Vector3(14.0, 0.0, 0.0)
    eye.global_position = c + Vector3(-22.0, 14.0, 20.0)
    eye.look_at(c, Vector3.UP)
    eye.current = true
    await _wait(0.6)
    await _shot("run_overview")
    eye.queue_free()
    RunState.full_3d = false
    RunState.end_run()

    change_scene_to_file("res://scenes/playground_3d.tscn")
    await _wait(0.5)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var pg: Node3D = current_scene as Node3D
    var pcam: ThirdPersonCamera = pg.get("cam")
    await _fps("playground")
    for v: Array in [["playground_moon", -1.15, -0.1], ["playground_towers", PI * 0.15, -0.2]]:
        pcam.yaw = v[1]
        pcam.pitch = v[2]
        await _wait(0.6)
        await _shot(v[0])
    quit()

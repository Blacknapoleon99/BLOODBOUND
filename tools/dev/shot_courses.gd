extends SceneTree
## Dev capture (visible window only): an overview of every open 3D course in a 3D run, plus the
## opening's practice grounds. Writes PNGs to the folder given after "--" (default user://).


func _initialize() -> void:
    _run.call_deferred()


func _wait(frames: int) -> void:
    for i in frames:
        await process_frame


func _run() -> void:
    var out: String = "user://"
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if not args.is_empty():
        out = args[0]
    GameSettings.persistence_enabled = false
    LevelLayout.classic = false
    RunState.full_3d = true
    RunState.new_run(int(args[1]) if args.size() > 1 else 77)
    change_scene_to_file("res://scenes/main.tscn")
    await _wait(20)
    var main: Node3D = current_scene as Node3D
    main.set("_cull_clock", 1e9)  # every room drawn whatever the camera
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var eye: Camera3D = Camera3D.new()
    eye.fov = 60.0
    eye.far = 400.0
    main.add_child(eye)
    eye.current = true
    var spots: Array = [["opening", Vector3(0.0, 1.0, 0.0), 30.0]]
    for room: LevelSection in main.get("sections"):
        var r: Rect2 = room.world_rect()  # DEC-063: rooms spread in X and Z at varied heights
        spots.append([String(room.id), Vector3(r.get_center().x, room.origin_y + 2.0, r.get_center().y), room.width])
    for spot: Array in spots:
        var c: Vector3 = spot[1]
        var size: float = spot[2]
        eye.global_position = c + Vector3(-size * 0.55, size * 0.6, size * 0.75)
        eye.look_at(c, Vector3.UP)
        eye.current = true
        await _wait(8)
        await RenderingServer.frame_post_draw
        root.get_viewport().get_texture().get_image().save_png(out.path_join("course_%s.png" % spot[0]))
    RunState.full_3d = false
    RunState.end_run()
    quit()

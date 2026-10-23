extends SceneTree
## Dev capture (visible window only, DEC-054): close, player-height views of the level geometry
## look (materials, bevels, rubble undersides, props) in a 3D run. Writes PNGs to the folder
## given after "--" (default user://). Optional second arg: run seed.
##   godot --path . -s res://tools/dev/shot_ground.gd -- C:/tmp/shots 77


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
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var hud: Node = main.get_node_or_null("MinimalHUD")
    if hud is CanvasLayer:
        (hud as CanvasLayer).visible = false
    var eye: Camera3D = Camera3D.new()
    eye.fov = 55.0
    eye.far = 400.0
    main.add_child(eye)
    var shots: Array = [["opening_close", Vector3(-6.0, 4.0, 9.0), Vector3(6.0, 0.0, 0.0)]]
    var n: int = 0
    for room: LevelSection in main.get("sections"):
        if n >= 4:
            break
        n += 1
        var x: float = room.origin_x
        shots.append(["%s_entry" % room.id, Vector3(x + 2.0, 4.5, 8.0), Vector3(x + 14.0, 0.5, -1.0)])
        shots.append(["%s_mid" % room.id, Vector3(x + room.width * 0.5 - 6.0, 6.0, 14.0), Vector3(x + room.width * 0.5, 1.0, 0.0)])
        shots.append(["%s_under" % room.id, Vector3(x + room.width * 0.4, -6.0, 18.0), Vector3(x + room.width * 0.5, 2.0, 0.0)])
        shots.append(["%s_exit" % room.id, Vector3(x + room.width - 11.0, 3.0, 4.0), Vector3(x + room.width - 1.0, 4.0, 0.0)])
    var arena: BossArena = main.get("boss_arena")
    if arena != null:
        var ax: float = arena.left_x()
        shots.append(["bishop_causeway", Vector3(ax - 3.0, 4.0, 6.0), Vector3(ax + 10.0, 0.0, 0.0)])
    for shot: Array in shots:
        eye.global_position = shot[1]
        eye.look_at(shot[2], Vector3.UP)
        eye.current = true
        await _wait(8)
        await RenderingServer.frame_post_draw
        root.get_viewport().get_texture().get_image().save_png(out.path_join("ground_%s.png" % shot[0]))
    RunState.full_3d = false
    RunState.end_run()
    quit()

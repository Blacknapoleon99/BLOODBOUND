extends SceneTree
## Dev capture (visible window only) of the background world (DEC-055) from the GAMEPLAY camera:
## the opening, a few rooms of a 3D run (looking down the run, and out to the sides), and the
## movement playground. Writes PNGs to the folder given after "--" (default user://).
##   godot --path . -s res://tools/dev/shot_backdrop.gd -- <out_dir> [seed]


func _initialize() -> void:
    _run.call_deferred()


func _wait(frames: int) -> void:
    for i in frames:
        await process_frame


func _shot(out: String, label: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png(out.path_join("backdrop_%s.png" % label))


func _pose(main: Node, cam: ThirdPersonCamera, at: Vector3, yaw: float, pitch_deg: float = -12.0) -> void:
    var p: CharacterBody3D = main.get("player")
    p.call("teleport_to", at)
    cam.yaw = yaw
    cam.pitch = deg_to_rad(pitch_deg)
    await _wait(45)


func _render_info() -> Array:
    await RenderingServer.frame_post_draw
    return [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]


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
    var cam: ThirdPersonCamera = main.get("cam3d")
    var sections: Array = main.get("sections")
    for e: Node in get_nodes_in_group(&"enemies"):
        if e.has_method("set_ai_enabled"):
            e.call("set_ai_enabled", false)
    await _pose(main, cam, Vector3(-6.0, 1.2, 0.0), -PI * 0.5)
    await _shot(out, "opening_ahead")
    await _pose(main, cam, Vector3(-6.0, 1.2, 0.0), -PI * 0.5, 6.0)
    await _shot(out, "opening_horizon")
    await _pose(main, cam, Vector3(-6.0, 1.2, 0.0), 0.0, 4.0)
    await _shot(out, "opening_horizon_side")
    # Cost of the background world at this pose: draw calls with and without it.
    var with_bd: Array = await _render_info()
    var decor: Array[Node] = []
    decor.append_array(get_nodes_in_group(&"backdrop_room"))
    decor.append_array(get_nodes_in_group(&"backdrop_horizon"))
    for n: Node in decor:
        (n as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
        (n as Node3D).visible = false
    await _wait(10)
    var without: Array = await _render_info()
    for n: Node in decor:
        (n as Node3D).process_mode = Node.PROCESS_MODE_INHERIT
        (n as Node3D).visible = true
    print("draw calls / primitives: with backdrop %s, without %s, fps %d" % [with_bd, without, Engine.get_frames_per_second()])
    var picks: Array[int] = [0, sections.size() / 2, sections.size() - 1]
    for i: int in picks:
        var room: LevelSection = sections[i]
        var at: Vector3 = Vector3(room.origin_x + 3.0, 1.2, 0.0)
        await _pose(main, cam, at, -PI * 0.5)
        await _shot(out, "%d_%s_ahead" % [i, room.id])
        await _pose(main, cam, at, 0.0, -8.0)
        await _shot(out, "%d_%s_side" % [i, room.id])
        await _pose(main, cam, at, PI * 0.75, -20.0)
        await _shot(out, "%d_%s_back" % [i, room.id])
    RunState.full_3d = false
    RunState.end_run()
    change_scene_to_file("res://scenes/playground_3d.tscn")
    await _wait(30)
    var pg: Node3D = current_scene as Node3D
    var pcam: ThirdPersonCamera = pg.get("cam")
    for spec: Array in [[-PI * 0.5, "ahead"], [PI * 0.5, "behind"], [0.0, "side"]]:
        pcam.yaw = spec[0]
        await _wait(30)
        await _shot(out, "playground_%s" % spec[1])
    quit()

extends SceneTree
## Dev perf probe (visible window, DEC-056): starts a 3D run (seed 77, high preset, vsync off),
## parks a camera over the opening and the first rooms and prints fps, draw calls, objects and
## primitives per view. Run it before/after level-geometry changes.
##   godot --path . -s res://tools/dev/kit_perf.gd [-- low] [nokit]
## `nokit`: draw the plain textured boxes instead of the modelled kit (A/B in the same session).


func _initialize() -> void:
    _run.call_deferred()


func _wait(frames: int) -> void:
    for i in frames:
        await process_frame


func _measure(label: String) -> void:
    await _wait(30)
    var frames: int = 0
    var draws: int = 0
    var objs: int = 0
    var prims: int = 0
    var start: int = Time.get_ticks_usec()
    while Time.get_ticks_usec() - start < 2000000:
        await process_frame
        frames += 1
        draws = maxi(draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
        objs = maxi(objs, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
        prims = maxi(prims, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
    var fps: float = frames / ((Time.get_ticks_usec() - start) / 1e6)
    print("PERF %-28s fps %6.1f  draws %5d  objects %5d  prims %8d" % [label, fps, draws, objs, prims])


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    GameSettings.persistence_enabled = false
    GameSettings.high_quality = not args.has("low")
    GothicKit.enabled = not args.has("nokit")
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    LevelLayout.classic = false
    RunState.full_3d = true
    RunState.new_run(77)
    var t0: int = Time.get_ticks_msec()
    change_scene_to_file("res://scenes/main.tscn")
    await _wait(2)
    print("PERF scene build + first frames: %d ms" % (Time.get_ticks_msec() - t0))
    await _wait(20)
    var main: Node3D = current_scene as Node3D
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var hud: Node = main.get_node_or_null("MinimalHUD")
    if hud is CanvasLayer:
        (hud as CanvasLayer).visible = false
    var eye: Camera3D = Camera3D.new()
    eye.fov = 60.0
    eye.far = 500.0
    main.add_child(eye)
    eye.current = true
    eye.global_position = Vector3(-6.0, 4.0, 9.0)
    eye.look_at(Vector3(6.0, 0.0, 0.0), Vector3.UP)
    var tally: Dictionary = {}
    var per_mesh: Dictionary = {}
    for node: Node in main.find_children("*", "MultiMeshInstance3D", true, false):
        var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
        if mm == null or mm.mesh == null:
            continue
        var piece: String = String(node.name).get_slice(" ", 0)
        if not per_mesh.has(mm.mesh):
            per_mesh[mm.mesh] = mm.mesh.get_faces().size() / 3
        var tris: int = per_mesh[mm.mesh]
        tally[piece] = int(tally.get(piece, 0)) + tris * mm.instance_count
    var keys: Array = tally.keys()
    keys.sort_custom(func(a: Variant, b: Variant) -> bool: return tally[a] > tally[b])
    for k: Variant in keys.slice(0, 12):
        print("PERF tris %-18s %9d" % [k, tally[k]])
    await _measure("opening")
    var n: int = 0
    for room: LevelSection in main.get("sections"):
        if n >= 3:
            break
        n += 1
        var c: Vector3 = Vector3(room.origin_x + room.width * 0.5, 0.0, 0.0)
        eye.global_position = c + Vector3(-room.width * 0.55, 12.0, 22.0)
        eye.look_at(c, Vector3.UP)
        await _measure(String(room.id) + " overview")
        eye.global_position = Vector3(room.origin_x + 3.0, 3.5, 6.0)
        eye.look_at(Vector3(room.origin_x + 16.0, 1.0, 0.0), Vector3.UP)
        await _measure(String(room.id) + " player")
    RunState.full_3d = false
    RunState.end_run()
    quit()

extends SceneTree
## Dev capture (visible window only, DEC-056): close-ups of the modelled gothic kit in a 3D run:
## a platform's cornice edge, a pier capital and shaft, a climb wall's handholds, an iron grate
## mover, a shattered collapsing slab, a tall face (blind arcade), plus a player-height view.
## Writes kit_*.png to the folder given after "--" (default user://). Optional 2nd arg: seed.
##   godot --path . -s res://tools/dev/shot_kit.gd -- C:/tmp/shots 77


func _initialize() -> void:
    _run.call_deferred()


func _wait(frames: int) -> void:
    for i in frames:
        await process_frame


func _first(room: Node, type: String) -> Node3D:
    for n: Node in room.find_children("*", type, true, false):
        return n as Node3D
    return null


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
    var shots: Array = []
    var have: Dictionary = {}
    for room: LevelSection in main.get("sections"):
        for b: Dictionary in room.dress_blocks:
            var p: Vector3 = b["pos"]
            var s: Vector3 = b["size"]
            var top: float = p.y + s.y * 0.5
            if b["kind"] == &"pillar" and not have.has("pillar"):
                have["pillar"] = true
                shots.append(["pillar", Vector3(p.x - 3.2, top + 0.6, p.z + 3.6), Vector3(p.x, top - 1.6, p.z)])
            elif b["walkable"] and s.x >= 4.0 and s.z >= 4.0 and not have.has("edge"):
                have["edge"] = true
                shots.append(["edge", Vector3(p.x + s.x * 0.5 + 1.6, top + 0.9, p.z + s.z * 0.5 + 2.6), Vector3(p.x + s.x * 0.3, top - 0.5, p.z + s.z * 0.5)])
                shots.append(["paving", Vector3(p.x - 1.0, top + 2.2, p.z + 2.0), Vector3(p.x + 1.5, top, p.z - 1.0)])
            elif s.y >= 4.0 and (s.x >= 3.0 or s.z >= 3.0) and b["kind"] != &"climb" and b["kind"] != &"pillar" and not have.has("tall"):
                have["tall"] = true
                var face: Vector3 = Vector3(p.x, top - 2.0, p.z + s.z * 0.5) if s.x >= s.z else Vector3(p.x + s.x * 0.5, top - 2.0, p.z)
                var away: Vector3 = Vector3(0.0, 1.0, 7.0) if s.x >= s.z else Vector3(7.0, 1.0, 0.0)
                shots.append(["tall", face + away, face])
                var back: Vector3 = Vector3(p.x, top - 2.0, p.z - s.z * 0.5) if s.x >= s.z else Vector3(p.x - s.x * 0.5, top - 2.0, p.z)
                shots.append(["tall_back", back + Vector3(-away.x, away.y, -away.z), back])
        if not room.climb_walls.is_empty() and not have.has("climb"):
            have["climb"] = true
            var w: ClimbWall = room.climb_walls[0]
            shots.append(["climb", w.global_position + Vector3(-2.0, 0.5, 5.0), w.global_position])
        if not room.slabs.is_empty() and not have.has("slab"):
            have["slab"] = true
            var sl: Node3D = room.slabs[0]
            shots.append(["slab", sl.global_position + Vector3(-2.2, 2.2, 2.6), sl.global_position])
        var mover: Node3D = _first(room, "AnimatableBody3D")
        if mover != null and not have.has("mover"):
            have["mover"] = true
            shots.append(["mover", mover.global_position + Vector3(-2.5, 2.0, 3.0), mover.global_position])
        if not have.has("player"):
            have["player"] = true
            var x: float = room.origin_x
            shots.append(["player", Vector3(x + 1.0, 2.2, 3.5), Vector3(x + 9.0, 0.6, 0.0)])
    for shot: Array in shots:
        eye.global_position = shot[1]
        eye.look_at(shot[2], Vector3.UP)
        eye.current = true
        await _wait(10)
        await RenderingServer.frame_post_draw
        root.get_viewport().get_texture().get_image().save_png(out.path_join("kit_%s.png" % shot[0]))
    RunState.full_3d = false
    RunState.end_run()
    quit()

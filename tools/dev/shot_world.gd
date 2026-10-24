extends SceneTree
## Dev capture (visible window only, DEC-063): the 3D run's open world. A high overview of the
## whole world (fog off, every room drawn), a lower oblique one, then gameplay-camera views from
## the hub, a bridge, a room and the cathedral forecourt. Writes world_*.png to the folder
## given after "--" (default user://); an optional second argument is the run seed.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s res://tools/dev/shot_world.gd -- <outdir> [seed]

var _out: String = "user://"


func _initialize() -> void:
    _run.call_deferred()


func _frames(n: int) -> void:
    for i in n:
        await process_frame


func _shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png(_out.path_join("world_%s.png" % name))
    print("shot ", name)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if not args.is_empty():
        _out = args[0]
    GameSettings.persistence_enabled = false
    LevelLayout.classic = false
    RunState.full_3d = true
    RunState.new_run(int(args[1]) if args.size() > 1 else 77)
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(20)
    var main: Node3D = current_scene as Node3D
    var world: OpenWorld = main.get("world")
    var player: CharacterBody3D = main.get("player")
    var cam: ThirdPersonCamera = main.get("cam3d")
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    (main.get("enemy") as Node).call("set_ai_enabled", false)
    # Overviews: fog off, culling off, a far camera.
    main.set("_cull_clock", 1e9)
    for sec: LevelSection in main.get("sections"):
        sec.visible = true
        if sec.backdrop != null:
            sec.backdrop.visible = true
    var env_node: WorldEnvironment = main.find_children("*", "WorldEnvironment", true, false)[0] as WorldEnvironment
    var fog: bool = env_node.environment.fog_enabled
    var vfog: bool = env_node.environment.volumetric_fog_enabled
    env_node.environment.fog_enabled = false
    env_node.environment.volumetric_fog_enabled = false
    var eye: Camera3D = Camera3D.new()
    eye.fov = 55.0
    eye.far = 3000.0
    main.add_child(eye)
    var b: Rect2 = world.bounds
    var c: Vector3 = Vector3(b.get_center().x, 0.0, b.get_center().y)
    var span: float = maxf(b.size.x, b.size.y)
    eye.global_position = c + Vector3(0.0, span * 1.05, span * 0.18)
    eye.look_at(c, Vector3.UP)
    eye.current = true
    await _frames(10)
    await _shot("0_overview_top")
    eye.global_position = c + Vector3(-span * 0.15, span * 0.45, span * 0.75)
    eye.look_at(c + Vector3(0.0, 0.0, -span * 0.05), Vector3.UP)
    await _frames(6)
    await _shot("1_overview_oblique")
    eye.global_position = Vector3(-30.0, 40.0, 40.0)
    eye.look_at(Vector3(40.0, 0.0, -10.0), Vector3.UP)
    await _frames(6)
    await _shot("2_from_hub_high")
    env_node.environment.fog_enabled = fog
    env_node.environment.volumetric_fog_enabled = vfog
    eye.queue_free()
    main.set("_cull_clock", 0.0)
    cam.camera.current = true
    # Gameplay views: the hub, out on a bridge, inside a room, the forecourt.
    var views: Array = []
    views.append(["3_hub", Vector3(-12.0, 1.2, 0.0), -PI * 0.5])
    var bridge: Dictionary = world.links[0]
    var mid: int = (bridge["pieces"] as Array)[(bridge["pieces"] as Array).size() / 2]
    var r: Rect2 = OpenWorld._port_rect(world.wilds, mid)
    views.append(["4_bridge", Vector3(r.get_center().x, world.wilds.platforms[mid].position.y + 1.2, r.get_center().y), 0.6])
    var room: LevelSection = world.rooms[3]
    views.append(["5_room", room.checkpoint.global_position + Vector3(0.0, 0.3, 0.0), -PI * 0.5])
    var fr: Rect2 = OpenWorld._port_rect(world.wilds, world.forecourt)
    views.append(["6_forecourt", Vector3(fr.get_center().x - 3.0, 1.2, fr.get_center().y), -PI * 0.5])
    for v: Array in views:
        player.call("teleport_to", v[1])
        cam.yaw = v[2]
        for i in 50:
            await physics_frame
        await _frames(4)
        await _shot(v[0])
    RunState.full_3d = false
    RunState.end_run()
    quit()

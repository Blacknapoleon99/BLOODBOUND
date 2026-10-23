extends SceneTree
## Dev capture (visible window only, DEC-057): close-ups of every modelled prop and hazard
## under the real gothic lighting. Loads a 3D run (for GothicEnvironment, sky and fog), builds a
## prop gallery on a flagstone slab off to the side of the course, and photographs each piece.
##   godot --path . -s res://tools/dev/shot_props.gd -- C:/tmp/shots
## Prints the frame time with the gallery in view.

const AT: Vector3 = Vector3(-60.0, 30.0, 60.0)  # gallery origin, away from the course


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
    RunState.new_run(77)
    change_scene_to_file("res://scenes/main.tscn")
    await _wait(20)
    var main: Node3D = current_scene as Node3D
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var hud: Node = main.get_node_or_null("MinimalHUD")
    if hud is CanvasLayer:
        (hud as CanvasLayer).visible = false
    var gallery: Node3D = Node3D.new()
    gallery.name = "Prop gallery"
    gallery.position = AT
    main.add_child(gallery)
    var slab: MeshInstance3D = MeshInstance3D.new()
    var box: BoxMesh = BoxMesh.new()
    box.size = Vector3(60.0, 1.0, 14.0)
    slab.mesh = box
    slab.material_override = GothicMaterials.block(&"floor")
    slab.position = Vector3(24.0, -0.5, 0.0)
    gallery.add_child(slab)
    var shots: Array = []
    # Hazards and interactables (built by their own scripts, so this is what the game shows).
    var spikes: SpikeTrap = SpikeTrap.create("Gallery spikes", 0.0, 0.0, 3.0, 0.0, 0.0, 2.6)
    spikes.position = Vector3(0.0, 0.0, 0.0)
    gallery.add_child(spikes)
    spikes.set_physics_process(false)
    spikes._set_state(SpikeTrap.State.UP)
    shots.append(["spike_trap", Vector3(-2.6, 1.6, 3.2), Vector3(0.0, 0.4, 0.0)])
    var blade: PendulumBlade = PendulumBlade.create("Gallery pendulum", Vector3(6.0, 6.0, 0.0), 5.0, 0.0, 4.0)
    gallery.add_child(blade)
    blade.set_physics_process(false)
    shots.append(["pendulum", Vector3(2.5, 2.2, 5.5), Vector3(6.0, 1.2, 0.0)])
    var lever: LeverShortcut = LeverShortcut.create(Vector3(11.0, 0.0, -1.5), 12.5, 16.5, 0.6, 1.5, 2.4)
    gallery.add_child(lever)
    shots.append(["lever", Vector3(9.4, 1.6, 0.6), Vector3(11.0, 0.6, -1.5)])
    var lever2: LeverShortcut = LeverShortcut.create(Vector3(11.0, 0.0, 4.0), 12.5, 16.5, 0.6, 4.5, 2.4)
    gallery.add_child(lever2)
    lever2.is_open = true
    lever2._bridge_material.albedo_color.a = 1.0
    if lever2._iron_material:
        lever2._iron_material.albedo_color.a = 1.0
    shots.append(["bridge", Vector3(12.0, 2.2, 8.0), Vector3(14.5, 0.3, 4.5)])
    var altar: BloodAltar = BloodAltar.create("Gallery altar", Vector3(20.0, 0.0, 1.2))
    gallery.add_child(altar)
    shots.append(["altar", Vector3(18.2, 1.8, 2.6), Vector3(20.0, 0.8, 0.0)])
    var stall: MerchantStall = MerchantStall.create(Vector3(25.5, 0.0, 1.5))
    gallery.add_child(stall)
    shots.append(["merchant", Vector3(24.0, 2.0, 3.6), Vector3(25.5, 1.3, -0.2)])
    var chest: LootChest = LootChest.create(Vector3(30.0, 0.0, 0.0))
    gallery.add_child(chest)
    var chest2: LootChest = LootChest.create(Vector3(32.0, 0.0, 0.0))
    gallery.add_child(chest2)
    shots.append(["chests", Vector3(29.6, 1.6, 2.4), Vector3(31.0, 0.4, 0.0)])
    var shard: ShardPickup = ShardPickup.create(Vector3(34.5, 1.0, 1.0))
    gallery.add_child(shard)
    shots.append(["shard", Vector3(34.0, 1.2, 2.2), Vector3(34.5, 1.0, 1.0)])
    var cp: Checkpoint = Checkpoint.create(Vector3(37.0, 1.2, 1.5))
    gallery.add_child(cp)
    var cp2: Checkpoint = Checkpoint.create(Vector3(38.6, 1.2, 1.5))
    gallery.add_child(cp2)
    cp2._banner_material.albedo_color = Checkpoint.ACTIVE_COLOR  # as when lit
    cp2._banner_material.emission_enabled = true
    cp2._banner_material.emission = Checkpoint.ACTIVE_COLOR * 0.6
    shots.append(["checkpoint", Vector3(36.4, 1.5, 3.5), Vector3(37.8, 1.3, 0.6)])
    var arch: Node3D = GothicDressing.exit_arch()
    arch.position = Vector3(44.0, 0.0, 0.0)
    gallery.add_child(arch)
    shots.append(["exit_arch", Vector3(37.5, 3.5, 4.0), Vector3(44.0, 3.5, 0.0)])
    var wall: Node3D = Node3D.new()
    wall.position = Vector3(50.0, 3.0, 0.0)
    wall.add_child(Ambush._bone_modules(6.0, false))
    gallery.add_child(wall)
    shots.append(["bone_wall", Vector3(49.0, 2.6, 5.0), Vector3(50.0, 2.6, 0.0)])
    # Corner props.
    var props: Array = ["skull_pile_a", "skull_pile_b", "candles_a", "candles_b", "candelabra", "column_tall", "column_short", "column_drum",
            "gravestone_a", "gravestone_b", "sarcophagus", "fence_section", "fence_bent", "iron_cage"]
    for i in props.size():
        var mi: MeshInstance3D = GothicProps.instance(props[i])
        if mi == null:
            continue
        mi.position = Vector3(i * 2.6, 0.0 if props[i] != "iron_cage" else 1.9, -5.0)
        gallery.add_child(mi)
    gallery.add_child(GothicEnvironment.torch_light(Vector3(5.5, 0.8, -4.2), 1.4, 4.5))
    shots.append(["props_bones_candles", Vector3(4.2, 1.7, -1.8), Vector3(5.2, 0.3, -5.0)])
    shots.append(["props_stone", Vector3(18.0, 2.0, -0.8), Vector3(20.5, 0.6, -5.0)])
    shots.append(["props_iron", Vector3(31.5, 1.8, -1.6), Vector3(32.5, 0.8, -5.0)])
    shots.append(["gallery_wide", Vector3(-4.0, 9.0, 16.0), Vector3(24.0, 0.0, -2.0)])
    var eye: Camera3D = Camera3D.new()
    eye.fov = 50.0
    eye.far = 600.0
    main.add_child(eye)
    for shot: Array in shots:
        eye.global_position = AT + (shot[1] as Vector3)
        eye.look_at(AT + (shot[2] as Vector3), Vector3.UP)
        eye.current = true
        await _wait(10)
        await RenderingServer.frame_post_draw
        root.get_viewport().get_texture().get_image().save_png(out.path_join("props_%s.png" % shot[0]))
    var t0: int = Time.get_ticks_usec()
    await _wait(60)
    print("gallery frame: %.2f ms" % ((Time.get_ticks_usec() - t0) / 60000.0))
    RunState.full_3d = false
    RunState.end_run()
    quit()

extends SceneTree
## Close-ups of the player hero model: sword sheathed on the back, then drawn after an attack.
## Visible window only; run with `--audio-driver Dummy`. Writes docs/screenshots/19_hero_*.png.


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    Ambush.enabled = false
    ArtSwap.enabled = true
    change_scene_to_file("res://scenes/main.tscn")
    for i in 30:
        await process_frame
    var main: Node = current_scene
    var player: CharacterBody3D = main.get("player")
    var cam: Camera3D = Camera3D.new()
    main.add_child(cam)
    cam.fov = 40.0
    cam.current = true
    for i in 30:
        await physics_frame
    if OS.get_cmdline_user_args().has("--no-cloth"):
        for sim: Node in player.find_children("ArtCloth", "", true, false):
            sim.set("active", false)
        for i in 10:
            await physics_frame
    await _shot(cam, player, "19_hero_sheathed.png")
    player.emit_signal(&"attack_started", &"light")
    for i in 3:
        await physics_frame
    await _shot(cam, player, "19_hero_drawing.png")  # mid-draw: hand at the scabbard
    for i in 20:
        await physics_frame
    await _shot(cam, player, "19_hero_drawn.png")
    var weapon: Node = player.find_child("ArtWeapon", true, false)
    var cloth: Node = player.find_child("ArtCloth", true, false)
    var anim: AnimationPlayer = player.find_children("*", "AnimationPlayer", true, false)[0]
    print("hero weapon=", weapon != null, " drawn=", weapon != null and bool(weapon.get("drawn")),
        " cloth=", cloth != null, " chains=", cloth.get("setting_count") if cloth else 0,
        " clips=", anim.get_animation_list())
    # Run so the cloth swings: move the player and capture a short strip.
    player.velocity = Vector3.ZERO
    Input.action_press(&"move_right")
    for i in 30:
        await physics_frame
    await _shot(cam, player, "19_hero_running.png")
    Input.action_release(&"move_right")
    quit()


func _shot(cam: Camera3D, player: Node3D, file: String) -> void:
    cam.global_position = player.global_position + Vector3(0.8, 0.6, 3.4)
    cam.look_at(player.global_position + Vector3(0.0, 0.1, 0.0), Vector3.UP)
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/" + file)

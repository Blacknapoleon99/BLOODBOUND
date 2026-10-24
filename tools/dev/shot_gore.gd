extends SceneTree
## Dev capture (needs a display; xvfb works): starts the full-3D run, spawns enemies in front of
## the hero, hits and kills them through their real Hurtbox and screenshots the gore.
##   godot --path . -s res://tools/dev/shot_gore.gd -- <outdir> [fallback]
## "fallback" forces Gore's flat-quad splats (what Compatibility gets) even on Forward+.

var _out: String = "user://"


func _initialize() -> void:
    _run.call_deferred()


func _wait(seconds: float) -> void:
    for i in int(seconds * 60.0):
        await physics_frame


func _shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png(_out.path_join("gore_%s.png" % name))
    print("%-12s decals=%d gibs=%d renderer=%s" % [name, Gore.live_decals(), Gore.live_gibs(), RenderingServer.get_current_rendering_method()])


func _hit(enemy: Node3D, from: Vector3, amount: int, heavy: bool) -> void:
    var hb: Hurtbox = enemy.get("hurtbox") as Hurtbox
    if hb == null:
        return
    var info: DamageInfo = DamageInfo.new()
    info.amount = amount
    info.category = &"heavy" if heavy else &"melee"
    var push: Vector3 = enemy.global_position - from
    push.y = 0.0
    info.knockback = push.normalized() * (6.0 if heavy else 3.0)
    info.hit_position = enemy.global_position + Vector3(0.0, 0.4, 0.0) - push.normalized() * 0.3
    hb.receive(info)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if not args.is_empty():
        _out = args[0]
    Gore.force_fallback = args.size() > 1 and args[1] == "fallback"
    GameSettings.persistence_enabled = false
    LevelLayout.classic = false
    RunState.full_3d = true
    RunState.new_run(77)
    change_scene_to_file("res://scenes/main.tscn")
    await _wait(1.5)
    var p: Node3D = current_scene.get("player") as Node3D
    var cam: Camera3D = root.get_viewport().get_camera_3d()
    var fwd: Vector3 = -cam.global_basis.z
    fwd.y = 0.0
    fwd = fwd.normalized()
    var side: Vector3 = fwd.cross(Vector3.UP)
    print("player=%s cam=%s fwd=%s" % [p.global_position, cam.global_position, fwd])
    var base: Vector3 = p.global_position + fwd * 1.8
    var types: Array[StringName] = [&"husk", &"archer", &"wraith"]
    var enemies: Array[Node3D] = []
    # A close dev camera on the spot (the gameplay camera stays where it is).
    var close: Camera3D = Camera3D.new()
    current_scene.add_child(close)
    close.global_position = base - fwd * 3.0 + Vector3.UP * 2.3 + side * 0.8
    close.look_at(base + Vector3.UP * 0.2)
    close.current = true
    for i in types.size():
        var at: Vector3 = base + side * [0.0, 1.7, -1.1][i] + fwd * [0.0, 0.6, 1.8][i]
        var e: Node3D = EnemyFactory.spawn(types[i], current_scene, at.x, at.x - 3.0, at.x + 3.0, p.global_position.y + 1.0, at.z)
        if e.has_method("set_ai_enabled"):
            e.call("set_ai_enabled", false)
        else:
            e.set_physics_process(false)
        if types[i] == &"wraith":
            e.global_position = at + Vector3.UP * (p.global_position.y + 1.4 - at.y)
        enemies.append(e)
    await _wait(0.6)
    print("enemy0=%s" % enemies[0].global_position)
    # Two hits on the husk: spurts toward the camera's right.
    _hit(enemies[0], p.global_position, 1, false)
    await _wait(0.2)
    await _shot("0_hit_spray")
    await _wait(0.6)
    _hit(enemies[0], p.global_position, 5, true)
    await _wait(0.1)
    await _shot("1_kill_burst")
    await _wait(0.5)
    await _shot("2_kill_gibs")
    _hit(enemies[1], p.global_position, 9, true)
    _hit(enemies[2], p.global_position, 9, true)
    await _wait(0.25)
    await _shot("3_bone_wraith")
    await _wait(1.8)
    await _shot("4_pool")
    # The hero bleeds too.
    var phb: Hurtbox = p.get("hurtbox") as Hurtbox
    var info: DamageInfo = DamageInfo.new()
    info.amount = 1
    info.knockback = -fwd * 4.0
    info.hit_position = p.global_position + Vector3(0.0, 1.0, 0.0)
    if phb != null:
        HitFeedback.play(phb, info)
    await _wait(0.15)
    await _shot("5_player_hurt")
    await _wait(1.0)
    await _shot("6_after")
    print("time_scale=%.2f" % Engine.time_scale)
    RunState.full_3d = false
    RunState.end_run()
    quit()

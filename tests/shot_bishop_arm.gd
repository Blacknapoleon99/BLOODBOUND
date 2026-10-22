extends SceneTree
## Captures the Hollow Bishop's slam (hover + impact) to check the bone arm reaches the hand
## (visible window only). Writes docs/screenshots/21_bishop_arm_*.png.

func _initialize() -> void:
    _run.call_deferred()


func _shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/" + ("21_bishop_arm_%s.png" % name))


func _run() -> void:
    GameSettings.persistence_enabled = false
    Ambush.enabled = false
    SpikeTrap.enabled = false
    PendulumBlade.enabled = false
    LevelLayout.classic = true
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    for i in 20:
        await process_frame
    var main: Node = current_scene
    var player: CharacterBody3D = main.get("player")
    var boss: HollowBishop = main.get("boss")
    var arena: BossArena = main.get("boss_arena")
    player.call("teleport_to", Vector3(arena.left_x() + 6.0, 1.0, 0.0))
    for i in 30:
        await physics_frame
    boss.begin_fight()
    boss.set_ai_enabled(false)
    for i in 150:
        await physics_frame
    await _shot("1_rest")
    boss.debug_attack(&"slam", arena.left_x() + 9.0)
    for i in 30:
        await physics_frame
    await _shot("2_hover")
    while boss.hand.hitbox.is_active() == false and boss.is_attacking():
        await physics_frame
    for i in 6:
        await physics_frame
    await _shot("3_impact")
    quit()

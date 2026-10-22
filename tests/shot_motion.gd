extends SceneTree
## Captures the Bone Revenant in motion (visible window only) to check animation fluidity:
## idle, running, a swing while running (legs must keep running), a standing swing, a dodge,
## a jump and the fall. Writes docs/screenshots/20_motion_*.png and prints the animation state.

func _initialize() -> void:
    _run.call_deferred()


func _key(code: Key, down: bool) -> void:
    var ev: InputEventKey = InputEventKey.new()
    ev.keycode = code
    ev.physical_keycode = code
    ev.pressed = down
    Input.parse_input_event(ev)


func _wait(seconds: float) -> void:
    for i in int(seconds * 60.0):
        await physics_frame


func _shot(name: String, player: Node3D) -> void:
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/" + ("20_motion_%s.png" % name))
    var tree: AnimationTree = player.find_child("ArtAnimationTree", true, false) as AnimationTree
    if tree != null:
        print("%-12s blend=%.2f loco_scale=%.2f full=%s upper=%s" % [name, float(tree.get("parameters/loco/blend_position")),
            float(tree.get("parameters/loco_speed/scale")), tree.get("parameters/full/active"), tree.get("parameters/upper/active")])


func _run() -> void:
    GameSettings.persistence_enabled = false
    GameSettings.reset_defaults()
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
    (main.get("enemy") as Node).call("set_ai_enabled", false)
    await _wait(1.0)
    await _shot("1_idle", player)
    _key(KEY_SPACE, true)
    await _wait(0.2)
    await _shot("7_jump", player)
    _key(KEY_SPACE, false)
    await _wait(0.35)
    await _shot("8_fall", player)
    await _wait(0.8)
    _key(KEY_D, true)
    await _wait(0.6)
    await _shot("2_run", player)
    _key(KEY_J, true)
    await _wait(0.12)
    await _shot("3_draw_running", player)
    await _wait(0.18)
    await _shot("4_swing_running", player)
    _key(KEY_J, false)
    _key(KEY_D, false)
    await _wait(0.8)
    _key(KEY_L, true)
    await _wait(0.25)
    await _shot("5_heavy_standing", player)
    _key(KEY_L, false)
    await _wait(0.9)
    _key(KEY_K, true)
    await _wait(0.1)
    await _shot("6_dodge", player)
    _key(KEY_K, false)
    await _wait(0.6)
    quit()

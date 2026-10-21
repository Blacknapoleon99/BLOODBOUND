extends SceneTree
## Captures the co-op HUD (both hands, both players) to docs/screenshots (visible window only).

func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    RunState.coop = true
    RunState.new_run(5)
    change_scene_to_file("res://scenes/main.tscn")
    for i in 60:
        await physics_frame
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/13_coop.png")
    RunState.coop = false
    RunState.end_run()
    quit()

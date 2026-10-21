extends SceneTree
## Captures a few rooms of the full first map to docs/screenshots (visible window only).

func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    Ambush.enabled = false
    RunState.new_run(77)
    change_scene_to_file("res://scenes/main.tscn")
    for i in 20:
        await process_frame
    var main: Node = current_scene
    var player: CharacterBody3D = main.get("player")
    var sections: Array = main.get("sections")
    var n: int = 0
    for index: int in [0, 3, 4, 7]:
        var room: LevelSection = sections[index]
        player.call("teleport_to", Vector3(room.origin_x + room.width * 0.35, 8.0, 0.0))
        for i in 90:
            await physics_frame
        await RenderingServer.frame_post_draw
        n += 1
        root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/" + ("12_map_%d_%s.png" % [n, room.id]))
    RunState.end_run()
    quit()

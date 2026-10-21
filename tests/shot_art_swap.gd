extends SceneTree
## Captures the opening causeway with the ArtSwap model and with the greybox, to docs/screenshots
## (visible window only). Also prints whether the swap kept the collision intact.

func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    Ambush.enabled = false
    for art: bool in [true, false]:
        ArtSwap.enabled = art
        change_scene_to_file("res://scenes/main.tscn")
        for i in 20:
            await process_frame
        var body: Node3D = current_scene.get_node("Starting causeway")
        var model: Node = body.get_node_or_null("ArtModel")
        var greybox: MeshInstance3D = body.get_node("Starting causeway appearance")
        var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
        print("art=%s model=%s greybox_visible=%s collision=%s" % [art, model != null, greybox.visible, (shape.shape as BoxShape3D).size])
        for i in 90:
            await physics_frame
        await RenderingServer.frame_post_draw
        var file: String = "15_art_causeway.png" if art else "15_art_causeway_greybox.png"
        root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/" + file)
    ArtSwap.enabled = true
    quit()

extends SceneTree
## Captures the draft screen and a Blood Altar offer to docs/screenshots (visible window only).

func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    RunState.new_run(2026)
    change_scene_to_file("res://scenes/draft.tscn")
    for i in 20:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/09_draft.png")
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    for i in 20:
        await process_frame
    var main: Node = current_scene
    var overlay: CardOfferOverlay = main.get("offer_overlay")
    overlay.open("BLOOD ALTAR — choose a card for your deck", CardPool.offer(RandomNumberGenerator.new(), 3, []))
    for i in 10:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/09_altar_offer.png")
    paused = false
    quit()

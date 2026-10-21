extends SceneTree
## Captures the Armory, the draft screen, a Blood Altar offer and a fracture reward to docs/screenshots (visible window only).

func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    Profile.reset()
    Profile.add_item(&"gravecleaver")
    Profile.add_item(&"shroud_of_ash")
    Profile.add_item(&"censer_locket")
    Profile.equip(&"gravecleaver")
    Profile.equip(&"censer_locket")
    change_scene_to_file("res://scenes/armory.tscn")
    for i in 20:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/11_armory.png")
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
    overlay.open("BLOOD ALTAR — a card for your deck, or a relic", main.call("_altar_offer"))
    for i in 10:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/09_altar_offer.png")
    overlay.skip_button.pressed.emit()
    overlay.open("THE FRACTURE YIELDS — a relic, or temper a card", main.call("_fracture_offer"))
    for i in 10:
        await process_frame
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png("res://docs/screenshots/10_fracture_offer.png")
    paused = false
    quit()

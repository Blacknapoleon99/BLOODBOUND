extends SceneTree
## Frame strips proving the ArtSwap models animate in play: the first Plagued Soldier chasing and
## swinging at the player, and the Hollow Bishop attacking on the approach. Visible window only;
## run with `--audio-driver Dummy` for silence. Writes docs/screenshots/18_anim_*.png.

const FRAMES: int = 6
const GAP: int = 14  # physics frames between captures (~0.23 s)


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    Ambush.enabled = false
    ArtSwap.enabled = true
    change_scene_to_file("res://scenes/main.tscn")
    for i in 20:
        await process_frame
    var main: Node = current_scene
    var player: CharacterBody3D = main.get("player")
    player.call("teleport_to", Vector3(2.0, 1.5, 0.0))  # the soldier at x=5 aggroes and swings
    await _strip("18_anim_soldier.png", Rect2i(380, 250, 520, 330))
    player.call("teleport_to", Vector3(main.BOSS_ARENA_START_X + float(main.get("map_offset")) - 3.0, 1.5, 0.0))
    for i in 120:
        await physics_frame
    await _strip("18_anim_bishop.png", Rect2i(200, 0, 880, 560))
    quit()


## Captures FRAMES crops of the viewport side by side into one PNG.
func _strip(file: String, crop: Rect2i) -> void:
    var strip: Image = Image.create(crop.size.x * FRAMES / 2, crop.size.y / 2, false, Image.FORMAT_RGB8)
    for f in FRAMES:
        for i in GAP:
            await physics_frame
        await RenderingServer.frame_post_draw
        var shot: Image = root.get_viewport().get_texture().get_image().get_region(crop)
        shot.convert(Image.FORMAT_RGB8)
        shot.resize(crop.size.x / 2, crop.size.y / 2)
        strip.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(f * crop.size.x / 2, 0))
    strip.save_png("res://docs/screenshots/" + file)

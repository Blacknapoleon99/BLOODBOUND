class_name ExportProbe
extends Node
## Smoke probe for *exported* builds, where `--script` (editor-only) is unavailable.
## Activated only by the user argument `--export-probe` (e.g. `Bloodbound.exe -- --export-probe`),
## or on the web build by the URL query `index.html?export-probe`.
## Drives the real game through Input.parse_input_event, prints results, saves a screenshot to
## user://export_probe.png when a display exists, and quits with 0 (all passed) or 1.

var _checks: int = 0
var _failures: int = 0


static func requested() -> bool:
    if OS.has_feature("web"):
        # Browsers pass no command line: use the page URL (index.html?export-probe).
        return bool(JavaScriptBridge.eval("window.location.search.indexOf('export-probe') >= 0", true))
    return OS.get_cmdline_user_args().has("--export-probe")


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _run.call_deferred()


func _run() -> void:
    var tree: SceneTree = get_tree()
    print("EXPORT PROBE: platform=%s web=%s debug=%s" % [OS.get_name(), OS.has_feature("web"), OS.is_debug_build()])
    GameSettings.persistence_enabled = false  # never touch the player's saved settings/profile
    var menu: Node = tree.current_scene
    _check(menu != null and menu.scene_file_path.ends_with("main_menu.tscn"), "title screen is the main scene")
    var start: Button = menu.get("start_button")
    start.pressed.emit()
    for i in 15:
        await tree.process_frame
    _check(tree.current_scene != null and tree.current_scene.scene_file_path.ends_with("armory.tscn"), "Start opens the Armory")
    (tree.current_scene.get("continue_button") as Button).pressed.emit()
    for i in 15:
        await tree.process_frame
    _check(tree.current_scene != null and tree.current_scene.scene_file_path.ends_with("draft.tscn"), "the Armory continues to the card draft")
    for round in RunState.DRAFT_ROUNDS:
        var view: CardOfferView = tree.current_scene.find_child("Offers", true, false) as CardOfferView
        if view == null or view.offers.is_empty():
            break
        view.buttons[0].pressed.emit()
        for i in 6:
            await tree.process_frame
    for i in 15:
        await tree.process_frame
    var main: Node = tree.current_scene
    if main == null or not main.scene_file_path.ends_with("main.tscn"):
        _check(false, "the draft leads into the game scene")
        print("EXPORT PROBE RESULT: %d/%d checks passed" % [_checks - _failures, _checks])
        tree.quit(1)
        return
    _check(RunState.deck.size() == RunState.DRAFT_ROUNDS, "three drafted cards form the run deck")
    var player: CharacterBody3D = main.get("player")
    for i in 60:
        await tree.physics_frame
    _check(player.is_on_floor(), "player lands on the causeway")
    var p0: Vector3 = player.global_position
    _key(KEY_D, true)  # side view: right; 3D run: strafe right of the camera
    for i in 30:
        await tree.physics_frame
    _key(KEY_D, false)
    var moved: float = Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
    _check(moved > 1.0, "D moves the player (%.2f m)" % moved)
    var y0: float = player.global_position.y
    _key(KEY_SPACE, true)
    var peak: float = y0
    for i in 30:
        await tree.physics_frame
        peak = maxf(peak, player.global_position.y)
    _key(KEY_SPACE, false)
    _check(peak > y0 + 1.5, "Space jumps (rise=%.2f)" % (peak - y0))
    for i in 60:
        await tree.physics_frame
    _key(KEY_J, true)
    await tree.physics_frame
    await tree.physics_frame
    _key(KEY_J, false)
    _check((player.get("melee") as MeleeAttack).is_busy(), "J starts a melee attack")
    _check(main.find_child("CardHand", true, false) != null and (player.get_node("Cards") as CardSystem).deck.hand.size() == 3, "card hand is dealt")
    _check(main.get("boss") != null and main.get("fracture") != null and main.get("boss_arena") != null, "Bishop, arena and Reality Fracture are built")
    for i in 30:
        await tree.physics_frame
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        tree.root.get_viewport().get_texture().get_image().save_png("user://export_probe.png")
        print("EXPORT PROBE: screenshot ", ProjectSettings.globalize_path("user://export_probe.png"))
    _key(KEY_ESCAPE, true)
    await tree.process_frame
    _key(KEY_ESCAPE, false)
    await tree.process_frame
    _check(tree.paused, "Esc pauses")
    _key(KEY_ESCAPE, true)
    await tree.process_frame
    _key(KEY_ESCAPE, false)
    await tree.process_frame
    _check(not tree.paused, "Esc resumes")
    print("EXPORT PROBE RESULT: %d/%d checks passed" % [_checks - _failures, _checks])
    tree.quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
    _checks += 1
    if not ok:
        _failures += 1
    print(("PASS  " if ok else "FAIL  ") + label)


func _key(code: Key, pressed: bool) -> void:
    var ev: InputEventKey = InputEventKey.new()
    ev.keycode = code
    ev.physical_keycode = code
    ev.pressed = pressed
    Input.parse_input_event(ev)

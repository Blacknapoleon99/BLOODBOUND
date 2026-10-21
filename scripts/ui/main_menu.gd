extends Control
## Title screen: Start / Settings / Quit. Loads saved settings before anything else runs.
## Quit is hidden on the web build, where a page cannot close itself.

## Start goes to the Armory (equipment, spoils), then the pre-run card draft, then the level.
const GAME_SCENE: String = "res://scenes/armory.tscn"

var start_button: Button
var settings_button: Button
var quit_button: Button
var settings: SettingsPanel
var _menu: Control


func _ready() -> void:
    InputBindings.ensure_defaults()
    GameSettings.load_settings()
    Audio.apply_volumes()
    Audio.music(&"music_level")
    set_anchors_preset(Control.PRESET_FULL_RECT)

    var background: ColorRect = ColorRect.new()
    background.color = Color(0.03, 0.02, 0.035)
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var glow: ColorRect = ColorRect.new()
    glow.color = Color(0.35, 0.02, 0.05, 0.25)
    glow.anchor_top = 0.62
    glow.anchor_right = 1.0
    glow.anchor_bottom = 1.0
    add_child(glow)

    _menu = CenterContainer.new()
    _menu.name = "Menu"
    _menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_menu)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    _menu.add_child(column)
    column.add_child(MenuStyle.label("BLOODBOUND", 64, MenuStyle.BONE))
    column.add_child(MenuStyle.label("THE HOLLOW COVENANT", 24, Color(0.8, 0.2, 0.22)))
    var spacer: Control = Control.new()
    spacer.custom_minimum_size = Vector2(0, 24)
    column.add_child(spacer)

    start_button = _add_button(column, "Start", "Start")
    start_button.pressed.connect(_on_start)
    settings_button = _add_button(column, "Settings", "Settings")
    settings_button.pressed.connect(_on_settings)
    quit_button = _add_button(column, "Quit", "Quit")
    quit_button.pressed.connect(func() -> void: get_tree().quit())
    quit_button.visible = not OS.has_feature("web")

    column.add_child(MenuStyle.label("Greybox vertical slice — keyboard: A/D move · Space jump · J/L attack · K dodge · cards: 1-3 or click card, then click target · Esc pause", 14, Color(0.6, 0.56, 0.52)))

    settings = SettingsPanel.create()
    settings.visible = false
    settings.closed.connect(_on_settings_closed)
    add_child(settings)
    start_button.grab_focus()
    if ExportProbe.requested():
        get_tree().root.add_child.call_deferred(ExportProbe.new())


func _add_button(parent: Control, text: String, node_name: String) -> Button:
    var b: Button = MenuStyle.button(text)
    b.name = node_name
    b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    parent.add_child(b)
    return b


func _on_start() -> void:
    RunState.end_run()
    get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings() -> void:
    _menu.visible = false
    settings.open()


func _on_settings_closed() -> void:
    _menu.visible = true
    settings_button.grab_focus()

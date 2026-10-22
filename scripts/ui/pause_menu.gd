class_name PauseMenu
extends CanvasLayer
## Esc / Start toggles pause. While paused the whole tree stops except this menu.
## Resume / Settings / Restart run / Main menu.

const MENU_SCENE: String = "res://scenes/main_menu.tscn"

var resume_button: Button
var settings_button: Button
var restart_button: Button
var menu_button: Button
var settings: SettingsPanel
var _root: Control
var _menu: Control


static func create() -> PauseMenu:
    var pause: PauseMenu = PauseMenu.new()
    pause.name = "PauseMenu"
    pause.add_to_group(&"pause_menu")
    pause.layer = 20
    pause.process_mode = Node.PROCESS_MODE_ALWAYS
    pause._build()
    return pause


func is_open() -> bool:
    return _root.visible


func _build() -> void:
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.visible = false
    add_child(_root)
    var dim: ColorRect = ColorRect.new()
    dim.color = Color(0.0, 0.0, 0.0, 0.6)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.add_child(dim)
    _menu = CenterContainer.new()
    _menu.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.add_child(_menu)
    var frame: PanelContainer = MenuStyle.panel()
    _menu.add_child(frame)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    frame.add_child(column)
    column.add_child(MenuStyle.label("PAUSED", 34))
    resume_button = _button(column, "Resume", "Resume")
    resume_button.pressed.connect(close)
    settings_button = _button(column, "Settings", "Settings")
    settings_button.pressed.connect(_on_settings)
    restart_button = _button(column, "Restart run", "Restart")
    restart_button.pressed.connect(func() -> void:
        close()
        RunState.end_run()
        get_tree().change_scene_to_file("res://scenes/draft.tscn"))
    menu_button = _button(column, "Main menu", "MainMenu")
    menu_button.pressed.connect(func() -> void:
        close()
        RunState.end_run()
        get_tree().change_scene_to_file(MENU_SCENE))
    settings = SettingsPanel.create()
    settings.visible = false
    settings.closed.connect(func() -> void:
        _menu.visible = true
        settings_button.grab_focus())
    _root.add_child(settings)


var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func open() -> void:
    _mouse_before = Input.mouse_mode
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _root.visible = true
    _menu.visible = true
    settings.visible = false
    get_tree().paused = true
    resume_button.grab_focus()


func close() -> void:
    _root.visible = false
    # Stay paused if a reward/shop overlay is still waiting underneath.
    get_tree().paused = _modal_open()
    if not _modal_open():
        Input.mouse_mode = _mouse_before


func _modal_open() -> bool:
    for node: Node in get_tree().get_nodes_in_group(&"modal_overlay"):
        if node.has_method("is_open") and node.call("is_open"):
            return true
    return false


func _on_settings() -> void:
    _menu.visible = false
    settings.open()


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed(&"pause") or event.is_echo():
        return
    if settings.visible:
        return  # the settings panel closes itself first
    get_viewport().set_input_as_handled()
    if is_open():
        close()
    else:
        open()


func _button(parent: Control, text: String, node_name: String) -> Button:
    var b: Button = MenuStyle.button(text)
    b.name = node_name
    parent.add_child(b)
    return b

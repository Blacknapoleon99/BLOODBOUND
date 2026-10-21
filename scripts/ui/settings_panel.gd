class_name SettingsPanel
extends CenterContainer
## Settings screen shared by the title and pause menus. Every change applies immediately
## and is saved to user://settings.cfg.

signal closed

var gore_toggle: CheckButton
var shake_slider: HSlider
var shake_value: Label
var hitstop_toggle: CheckButton
var music_slider: HSlider
var sfx_slider: HSlider
var back_button: Button
var save_path: String = GameSettings.DEFAULT_PATH


static func create() -> SettingsPanel:
    var panel: SettingsPanel = SettingsPanel.new()
    panel.name = "SettingsPanel"
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.process_mode = Node.PROCESS_MODE_ALWAYS
    panel._build()
    return panel


func _build() -> void:
    var frame: PanelContainer = MenuStyle.panel()
    add_child(frame)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 14)
    frame.add_child(column)
    column.add_child(MenuStyle.label("SETTINGS", 30))

    gore_toggle = _toggle("Reduced gore (ash instead of blood)")
    gore_toggle.name = "ReducedGore"
    gore_toggle.toggled.connect(func(on: bool) -> void:
        GameSettings.reduced_gore = on
        _save())
    column.add_child(gore_toggle)

    var shake_row: HBoxContainer = HBoxContainer.new()
    var shake_label: Label = MenuStyle.label("Camera shake", 18)
    shake_label.custom_minimum_size = Vector2(170, 0)
    shake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    shake_row.add_child(shake_label)
    shake_slider = HSlider.new()
    shake_slider.name = "CameraShake"
    shake_slider.min_value = 0.0
    shake_slider.max_value = 1.0
    shake_slider.step = 0.25
    shake_slider.custom_minimum_size = Vector2(200, 24)
    shake_slider.value_changed.connect(func(v: float) -> void:
        GameSettings.camera_shake = v
        shake_value.text = "%d%%" % roundi(v * 100.0)
        _save())
    shake_row.add_child(shake_slider)
    shake_value = MenuStyle.label("", 18)
    shake_value.custom_minimum_size = Vector2(60, 0)
    shake_row.add_child(shake_value)
    column.add_child(shake_row)

    hitstop_toggle = _toggle("Hit-stop (brief freeze on impact)")
    hitstop_toggle.name = "Hitstop"
    hitstop_toggle.toggled.connect(func(on: bool) -> void:
        GameSettings.hitstop_enabled = on
        _save())
    column.add_child(hitstop_toggle)


    music_slider = _volume_row(column, "Music", "MusicVolume", func(v: float) -> void:
        GameSettings.music_volume = v
        Audio.apply_volumes()
        _save())
    sfx_slider = _volume_row(column, "Sound effects", "SfxVolume", func(v: float) -> void:
        GameSettings.sfx_volume = v
        Audio.apply_volumes()
        Audio.sfx(&"ui_click")
        _save())

    back_button = MenuStyle.button("Back")
    back_button.name = "Back"
    back_button.pressed.connect(close)
    column.add_child(back_button)


func open() -> void:
    gore_toggle.set_pressed_no_signal(GameSettings.reduced_gore)
    shake_slider.set_value_no_signal(GameSettings.camera_shake)
    shake_value.text = "%d%%" % roundi(GameSettings.camera_shake * 100.0)
    hitstop_toggle.set_pressed_no_signal(GameSettings.hitstop_enabled)
    music_slider.set_value_no_signal(GameSettings.music_volume)
    sfx_slider.set_value_no_signal(GameSettings.sfx_volume)
    visible = true
    gore_toggle.grab_focus()


func close() -> void:
    visible = false
    closed.emit()


func _unhandled_input(event: InputEvent) -> void:
    if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
        get_viewport().set_input_as_handled()
        close()


func _save() -> void:
    GameSettings.save_settings(save_path)


func _volume_row(column: VBoxContainer, title: String, node_name: String, on_change: Callable) -> HSlider:
    var row: HBoxContainer = HBoxContainer.new()
    var label: Label = MenuStyle.label(title, 18)
    label.custom_minimum_size = Vector2(170, 0)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    row.add_child(label)
    var slider: HSlider = HSlider.new()
    slider.name = node_name
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.1
    slider.custom_minimum_size = Vector2(200, 24)
    slider.value_changed.connect(on_change)
    row.add_child(slider)
    column.add_child(row)
    return slider


static func _toggle(text: String) -> CheckButton:
    var t: CheckButton = CheckButton.new()
    t.text = text
    t.add_theme_font_size_override("font_size", 18)
    t.add_theme_color_override("font_color", MenuStyle.BONE)
    t.add_theme_color_override("font_focus_color", Color.WHITE)
    t.add_theme_color_override("font_hover_color", Color.WHITE)
    return t

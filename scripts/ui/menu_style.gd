class_name MenuStyle
extends RefCounted
## Shared look for menus (title, pause, settings) so they read as one game.

const BONE: Color = Color(0.93, 0.88, 0.8)
const BLOOD: Color = Color(0.72, 0.05, 0.09)
const PANEL: Color = Color(0.06, 0.04, 0.05, 0.94)


static func button(text: String) -> Button:
    var b: Button = Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(280, 46)
    b.add_theme_font_size_override("font_size", 22)
    b.add_theme_color_override("font_color", BONE)
    b.add_theme_color_override("font_focus_color", Color.WHITE)
    b.add_theme_color_override("font_hover_color", Color.WHITE)
    var normal: StyleBoxFlat = _box(Color(0.12, 0.08, 0.09, 0.9), Color(0.35, 0.25, 0.25))
    var focus: StyleBoxFlat = _box(Color(0.3, 0.05, 0.08, 0.95), BLOOD)
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", focus)
    b.add_theme_stylebox_override("focus", focus)
    b.add_theme_stylebox_override("pressed", focus)
    return b


static func label(text: String, size: int, color: Color = BONE) -> Label:
    var l: Label = Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_shadow_color", Color.BLACK)
    l.add_theme_constant_override("shadow_offset_x", 2)
    l.add_theme_constant_override("shadow_offset_y", 2)
    return l


static func panel() -> PanelContainer:
    var p: PanelContainer = PanelContainer.new()
    var box: StyleBoxFlat = _box(PANEL, Color(0.4, 0.28, 0.27))
    box.content_margin_left = 28
    box.content_margin_right = 28
    box.content_margin_top = 22
    box.content_margin_bottom = 22
    p.add_theme_stylebox_override("panel", box)
    return p


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
    var s: StyleBoxFlat = StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(2)
    s.set_corner_radius_all(3)
    return s

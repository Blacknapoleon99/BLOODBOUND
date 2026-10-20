class_name CardHandUI
extends VBoxContainer
## Bottom-left HUD for Bloodbound Cards: blood-energy bar plus one panel per hand slot.
## Read-only view of CardSystem; a failed play flashes its slot and shows the reason.

const REASON_TEXT: Dictionary = {
    &"empty": "NO CARD",
    &"blocked": "CAN'T ACT",
    &"cooldown": "COOLING",
    &"no_target": "NO TARGET",
    &"out_of_range": "TOO FAR",
    &"energy": "NEED BLOOD",
}

var cards: CardSystem
var energy_bar: ProgressBar
var energy_label: Label
var slots: Array[PanelContainer] = []
var _name_labels: Array[Label] = []
var _status_labels: Array[Label] = []
var _styles: Array[StyleBoxFlat] = []
var _flash_left: Array[float] = []
var _flash_text: Array[String] = []


static func create(card_system: CardSystem) -> CardHandUI:
    var ui: CardHandUI = CardHandUI.new()
    ui.name = "CardHand"
    ui.cards = card_system
    ui.anchor_top = 1.0
    ui.anchor_bottom = 1.0
    ui.offset_left = 22.0
    ui.offset_top = -150.0
    ui.offset_bottom = -20.0
    ui.add_theme_constant_override("separation", 6)
    ui._build()
    card_system.card_failed.connect(ui._on_card_failed)
    return ui


func _build() -> void:
    var energy_row: HBoxContainer = HBoxContainer.new()
    add_child(energy_row)
    energy_label = _label("BLOOD", 15, Color(0.95, 0.75, 0.72))
    energy_label.custom_minimum_size = Vector2(108, 0)
    energy_row.add_child(energy_label)
    energy_bar = ProgressBar.new()
    energy_bar.name = "EnergyBar"
    energy_bar.custom_minimum_size = Vector2(250, 14)
    energy_bar.show_percentage = false
    var fill: StyleBoxFlat = StyleBoxFlat.new()
    fill.bg_color = Color(0.75, 0.04, 0.09)
    var back: StyleBoxFlat = StyleBoxFlat.new()
    back.bg_color = Color(0.08, 0.04, 0.05, 0.85)
    energy_bar.add_theme_stylebox_override("fill", fill)
    energy_bar.add_theme_stylebox_override("background", back)
    energy_row.add_child(energy_bar)

    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    add_child(row)
    for i in CardSystem.SLOT_ACTIONS.size():
        var panel: PanelContainer = PanelContainer.new()
        panel.name = "CardSlot%d" % (i + 1)
        panel.custom_minimum_size = Vector2(118, 96)
        var style: StyleBoxFlat = StyleBoxFlat.new()
        style.bg_color = Color(0.1, 0.07, 0.08, 0.9)
        style.set_border_width_all(2)
        style.set_corner_radius_all(4)
        style.content_margin_left = 6
        style.content_margin_right = 6
        style.content_margin_top = 4
        panel.add_theme_stylebox_override("panel", style)
        var column: VBoxContainer = VBoxContainer.new()
        panel.add_child(column)
        var name_label: Label = _label("", 14, Color(0.97, 0.92, 0.86))
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        name_label.custom_minimum_size = Vector2(104, 38)
        column.add_child(name_label)
        var status: Label = _label("", 13, Color(0.85, 0.8, 0.75))
        column.add_child(status)
        row.add_child(panel)
        slots.append(panel)
        _name_labels.append(name_label)
        _status_labels.append(status)
        _styles.append(style)
        _flash_left.append(0.0)
        _flash_text.append("")


func _process(delta: float) -> void:
    if cards == null:
        return
    var energy: BloodEnergy = cards.energy
    energy_bar.max_value = energy.maximum
    energy_bar.value = energy.current
    energy_label.text = "BLOOD %d/%d" % [floori(energy.current + 0.0001), int(energy.maximum)]
    for i in slots.size():
        var card: CardData = cards.deck.card_in_slot(i)
        var status: StringName = cards.slot_status(i)
        _name_labels[i].text = "[%d] %s" % [i + 1, card.display_name.to_upper() if card else "—"]
        var text: String = ""
        match status:
            &"ready":
                text = "◆%d  READY" % card.cost
            &"cooldown":
                text = "◆%d  %.1fs" % [card.cost, cards.cooldown_left(card)]
            &"energy":
                text = "◆%d  NEED BLOOD" % card.cost
        _flash_left[i] = maxf(0.0, _flash_left[i] - delta)
        var border: Color = card.ui_color if card else Color.DIM_GRAY
        if _flash_left[i] > 0.0:
            text = _flash_text[i]
            border = Color(1.0, 0.15, 0.1)
        _status_labels[i].text = text
        _styles[i].border_color = border
        slots[i].modulate.a = 1.0 if status == &"ready" else 0.5


func _on_card_failed(_card: CardData, slot: int, reason: StringName) -> void:
    if slot < 0 or slot >= slots.size():
        return
    _flash_left[slot] = 0.8
    _flash_text[slot] = REASON_TEXT.get(reason, String(reason).to_upper())


static func _label(text: String, size: int, color: Color) -> Label:
    var label: Label = Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    return label

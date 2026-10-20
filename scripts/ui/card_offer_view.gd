class_name CardOfferView
extends HBoxContainer
## A row of offered cards (draft and Blood Altar rewards). Click a card or press 1-3 to pick.

signal picked(card: CardData)

var offers: Array[CardData] = []
var buttons: Array[Button] = []


func show_offers(cards: Array[CardData]) -> void:
    offers = cards
    for child: Node in get_children():
        child.queue_free()
    buttons.clear()
    add_theme_constant_override("separation", 18)
    alignment = BoxContainer.ALIGNMENT_CENTER
    for i in cards.size():
        var card: CardData = cards[i]
        var b: Button = MenuStyle.button("")
        b.name = "Offer%d" % (i + 1)
        b.custom_minimum_size = Vector2(250, 230)
        b.autowrap_mode = TextServer.AUTOWRAP_WORD
        b.add_theme_font_size_override("font_size", 17)
        b.text = "[%d]  %s\n\n%s\n\n%s" % [i + 1, card.display_name.to_upper(), _cost_line(card), card.description]
        var border: StyleBoxFlat = (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
        border.border_color = card.ui_color
        border.set_border_width_all(3)
        b.add_theme_stylebox_override("normal", border)
        var index: int = i
        b.pressed.connect(func() -> void: _pick(index))
        add_child(b)
        buttons.append(b)
    if not buttons.is_empty():
        buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    for i in mini(offers.size(), CardSystem.SLOT_ACTIONS.size()):
        if event.is_action_pressed(CardSystem.SLOT_ACTIONS[i]):
            get_viewport().set_input_as_handled()
            _pick(i)
            return


func _pick(index: int) -> void:
    if index < 0 or index >= offers.size():
        return
    var card: CardData = offers[index]
    offers = []  # one pick per offer
    picked.emit(card)


static func _cost_line(card: CardData) -> String:
    var parts: Array[String] = []
    parts.append("Cost %d blood" % card.cost if card.cost > 0 else "Free")
    if card.hp_cost > 0:
        parts.append("%d HP" % card.hp_cost)
    parts.append("cooldown %ss" % str(card.cooldown))
    return " · ".join(parts)

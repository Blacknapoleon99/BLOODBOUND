class_name CardOfferView
extends HBoxContainer
## A row of offered choices (draft, Blood Altars, fracture reward): CardData (a new card, or an
## upgrade when `upgrade_source` is set) or RelicData. Click one or press 1-3 to pick.

signal picked(choice: Resource)

var offers: Array = []
var buttons: Array[Button] = []


func show_offers(cards: Array) -> void:
    offers = cards
    for child: Node in get_children():
        child.queue_free()
    buttons.clear()
    add_theme_constant_override("separation", 18)
    alignment = BoxContainer.ALIGNMENT_CENTER
    for i in cards.size():
        var choice: Resource = cards[i]
        var b: Button = MenuStyle.button("")
        b.name = "Offer%d" % (i + 1)
        b.custom_minimum_size = Vector2(250, 230)
        b.autowrap_mode = TextServer.AUTOWRAP_WORD
        b.add_theme_font_size_override("font_size", 17)
        b.text = "[%d]  %s" % [i + 1, describe(choice)]
        var border: StyleBoxFlat = (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
        var tint: Variant = choice.get("ui_color")
        if choice is ShopItem:
            tint = (choice as ShopItem).payload.get("ui_color") if (choice as ShopItem).payload != null else Color(0.4, 0.8, 0.5)
        border.border_color = tint
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
    var pause_menu: Node = get_tree().get_first_node_in_group(&"pause_menu")
    if pause_menu != null and pause_menu.call("is_open"):
        return  # the pause menu is on top: no picking through it
    for i in mini(offers.size(), CardSystem.SLOT_ACTIONS.size()):
        if event.is_action_pressed(CardSystem.SLOT_ACTIONS[i]):
            get_viewport().set_input_as_handled()
            _pick(i)
            return


func _pick(index: int) -> void:
    if index < 0 or index >= offers.size():
        return
    var choice: Resource = offers[index]
    offers = []  # one pick per offer
    picked.emit(choice)


static func describe(choice: Resource) -> String:
    if choice is ShopItem:
        var ware: ShopItem = choice
        var price: String = "%d SHARDS%s" % [ware.price, "" if RunState.shards >= ware.price else "  (can't afford)"]
        if ware.kind == &"heal":
            return "%s\n\nFULL HEAL\n\nThe merchant's tonic restores all your health." % price
        return "%s\n\n%s" % [price, describe(ware.payload)]
    if choice is ItemData:
        var item: ItemData = choice
        return "%s: %s\n\n%s\n\n%s" % [ItemData.slot_name(item.slot), item.display_name.to_upper(), item.stat_line(), item.description]
    if choice is RelicData:
        var relic: RelicData = choice
        return "RELIC: %s\n\nPassive, lasts the run\n\n%s" % [relic.display_name.to_upper(), relic.description]
    var card: CardData = choice
    if card.upgrade_source != null:
        var old: CardData = card.upgrade_source
        return "UPGRADE: %s\n\nCost %d -> %d · cooldown %ss -> %ss\n\n%s" % [card.display_name.to_upper(), old.cost, card.cost, str(old.cooldown), str(card.cooldown), card.description]
    return "%s\n\n%s\n\n%s" % [card.display_name.to_upper(), _cost_line(card), card.description]


static func _cost_line(card: CardData) -> String:
    var parts: Array[String] = []
    parts.append("Cost %d blood" % card.cost if card.cost > 0 else "Free")
    if card.hp_cost > 0:
        parts.append("%d HP" % card.hp_cost)
    parts.append("cooldown %ss" % str(card.cooldown))
    return " · ".join(parts)

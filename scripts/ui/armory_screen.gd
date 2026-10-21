extends Control
## Between runs: claim spoils (pick 1 of 3 new items), equip a weapon, armour and charm from
## the stash, and see the resulting attributes and stats. Continue leads to the card draft.

const DRAFT_SCENE: String = "res://scenes/draft.tscn"
const MENU_SCENE: String = "res://scenes/main_menu.tscn"

var spoils_box: VBoxContainer
var spoils_label: Label
var spoil_buttons: Array[Button] = []
var spoil_offer: Array[ItemData] = []
var item_buttons: Dictionary = {}  # item id -> Button
var equipped_label: Label
var attributes_label: Label
var stats_label: Label
var continue_button: Button
var _columns: Dictionary = {}  # ItemData.Slot -> VBoxContainer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
    InputBindings.ensure_defaults()
    GameSettings.load_settings()
    Profile.ensure_loaded()
    _rng.randomize()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var background: ColorRect = ColorRect.new()
    background.color = Color(0.03, 0.02, 0.035)
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var margin: MarginContainer = MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for side: String in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 28 if side != "top" else 18)
    add_child(margin)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    margin.add_child(column)
    column.add_child(MenuStyle.label("THE ARMORY", 38))
    column.add_child(MenuStyle.label("Equip a weapon, armor and a charm. What you wear carries into every run.", 16, Color(0.7, 0.66, 0.6)))

    spoils_box = VBoxContainer.new()
    spoils_box.name = "Spoils"
    spoils_box.add_theme_constant_override("separation", 8)
    column.add_child(spoils_box)
    spoils_label = MenuStyle.label("", 20, Color(0.95, 0.75, 0.3))
    spoils_box.add_child(spoils_label)
    var spoil_row: HBoxContainer = HBoxContainer.new()
    spoil_row.alignment = BoxContainer.ALIGNMENT_CENTER
    spoil_row.add_theme_constant_override("separation", 14)
    spoils_box.add_child(spoil_row)
    for i in 3:
        var b: Button = _item_button(Vector2(260, 92))
        b.name = "Spoil%d" % (i + 1)
        var index: int = i
        b.pressed.connect(func() -> void: claim_spoil(index))
        spoil_row.add_child(b)
        spoil_buttons.append(b)

    var body: HBoxContainer = HBoxContainer.new()
    body.add_theme_constant_override("separation", 26)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(body)
    var left: VBoxContainer = VBoxContainer.new()
    left.custom_minimum_size = Vector2(330, 0)
    left.add_theme_constant_override("separation", 8)
    body.add_child(left)
    left.add_child(_header("EQUIPPED"))
    equipped_label = _text_label()
    equipped_label.name = "Equipped"
    left.add_child(equipped_label)
    left.add_child(_header("ATTRIBUTES"))
    attributes_label = _text_label()
    attributes_label.name = "Attributes"
    left.add_child(attributes_label)
    left.add_child(_header("STATS"))
    stats_label = _text_label()
    stats_label.name = "Stats"
    left.add_child(stats_label)
    for slot: int in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.CHARM]:
        var list: VBoxContainer = VBoxContainer.new()
        list.add_theme_constant_override("separation", 6)
        list.add_child(_header(ItemData.slot_name(slot) + "S" if slot != ItemData.Slot.ARMOR else "ARMOR"))
        body.add_child(list)
        _columns[slot] = list

    var bottom: HBoxContainer = HBoxContainer.new()
    bottom.alignment = BoxContainer.ALIGNMENT_CENTER
    bottom.add_theme_constant_override("separation", 20)
    column.add_child(bottom)
    var back: Button = MenuStyle.button("Back")
    back.name = "Back"
    back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
    bottom.add_child(back)
    continue_button = MenuStyle.button("Continue to the card draft")
    continue_button.name = "Continue"
    continue_button.custom_minimum_size = Vector2(360, 46)
    continue_button.pressed.connect(continue_to_draft)
    bottom.add_child(continue_button)
    _roll_spoils()
    refresh()
    continue_button.grab_focus()


func continue_to_draft() -> void:
    Profile.save()
    RunState.end_run()
    get_tree().change_scene_to_file(DRAFT_SCENE)


## Equips an owned item (stash button) and refreshes the screen.
func equip(id: StringName) -> void:
    if Profile.equip(id):
        Audio.sfx(&"equip", 0.03)
        Profile.save()
        refresh()


## Takes spoil `index` into the stash, equips it, and rolls the next offer if more are pending.
func claim_spoil(index: int) -> void:
    if index < 0 or index >= spoil_offer.size() or Profile.pending_spoils <= 0:
        return
    var item: ItemData = spoil_offer[index]
    Profile.add_item(item.id)
    Profile.equip(item.id)
    Profile.pending_spoils -= 1
    Audio.sfx(&"equip", 0.0)
    Profile.save()
    _roll_spoils()
    refresh()


func _roll_spoils() -> void:
    spoil_offer.clear()
    if Profile.pending_spoils > 0:
        spoil_offer = ItemPool.offer(_rng, 3, Profile.stash)
    if spoil_offer.is_empty():
        Profile.pending_spoils = 0  # everything is owned already
    spoils_box.visible = not spoil_offer.is_empty()
    spoils_label.text = "SPOILS OF THE HUNT: click one or press 1-3 (%d waiting)" % Profile.pending_spoils
    for i in spoil_buttons.size():
        var b: Button = spoil_buttons[i]
        b.visible = i < spoil_offer.size()
        if b.visible:
            _dress(b, spoil_offer[i], false, "NEW %s" % ItemData.slot_name(spoil_offer[i].slot))


func refresh() -> void:
    for slot: int in _columns:
        var list: VBoxContainer = _columns[slot]
        for child: Node in list.get_children().slice(1):
            child.queue_free()
    item_buttons.clear()
    for item: ItemData in ItemPool.ALL:
        if not Profile.stash.has(item.id):
            continue
        var b: Button = _item_button(Vector2(270, 64))
        b.name = "Item_" + String(item.id)
        var worn: bool = Profile.equipped.get(item.slot, &"") == item.id
        _dress(b, item, worn, "EQUIPPED" if worn else "")
        var id: StringName = item.id
        b.pressed.connect(func() -> void: equip(id))
        (_columns[item.slot] as VBoxContainer).add_child(b)
        item_buttons[item.id] = b
    var lines: Array[String] = []
    for slot: int in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.CHARM]:
        var worn_item: ItemData = Profile.item_in(slot)
        lines.append("%s: %s" % [ItemData.slot_name(slot), worn_item.display_name if worn_item else "-"])
    equipped_label.text = "\n".join(lines)
    var items: Array[ItemData] = Profile.equipped_items()
    var a: Dictionary = Equipment.attributes(items)
    attributes_label.text = "Vigor %d   Might %d\nAgility %d   Devotion %d" % [a[&"vigor"], a[&"might"], a[&"agility"], a[&"devotion"]]
    var d: Dictionary = Equipment.derived(items)
    stats_label.text = "\n".join([
        "Health %d" % d["hp"],
        "Damage: jab %d / finisher %d / heavy %d" % [d["light"], d["finisher"], d["heavy"]],
        "Attack speed x%.2f" % d["attack_speed"],
        "Run speed %.1f m/s   Dodge every %.2f s" % [d["speed"], d["dodge_cooldown"]],
        "Blood per hit %.1f   Max blood %d" % [d["blood_per_hit"], int(d["max_blood"])],
    ])


func _item_button(min_size: Vector2) -> Button:
    var b: Button = MenuStyle.button("")
    b.custom_minimum_size = min_size
    b.autowrap_mode = TextServer.AUTOWRAP_WORD
    b.add_theme_font_size_override("font_size", 14)
    return b


func _dress(b: Button, item: ItemData, highlighted: bool, tag: String) -> void:
    b.text = "%s%s\n%s" % [item.display_name.to_upper(), ("  [%s]" % tag) if tag != "" else "", item.stat_line()]
    b.tooltip_text = item.description
    var box: StyleBoxFlat = (b.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
    box.border_color = item.ui_color if not highlighted else Color(0.95, 0.75, 0.3)
    box.set_border_width_all(3 if highlighted else 2)
    if highlighted:
        box.bg_color = Color(0.22, 0.12, 0.06, 0.95)
    b.add_theme_stylebox_override("normal", box)


func _header(text: String) -> Label:
    var l: Label = MenuStyle.label(text, 18, Color(0.8, 0.2, 0.22))
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    return l


func _text_label() -> Label:
    var l: Label = MenuStyle.label("", 15, Color(0.88, 0.84, 0.78))
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    return l


func _unhandled_input(event: InputEvent) -> void:
    if not spoils_box.visible:
        return
    for i in mini(spoil_offer.size(), CardSystem.SLOT_ACTIONS.size()):
        if event.is_action_pressed(CardSystem.SLOT_ACTIONS[i]):
            get_viewport().set_input_as_handled()
            claim_spoil(i)
            return

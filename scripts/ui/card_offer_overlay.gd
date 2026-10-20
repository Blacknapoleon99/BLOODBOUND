class_name CardOfferOverlay
extends CanvasLayer
## Mid-run reward: pauses the game and offers 1 of 3 cards (Blood Altars, cleared fracture).
## Picking or skipping resumes play.

signal resolved(card: CardData)

var offer_view: CardOfferView
var title_label: Label
var skip_button: Button
var _root: Control


static func create() -> CardOfferOverlay:
    var overlay: CardOfferOverlay = CardOfferOverlay.new()
    overlay.name = "CardOfferOverlay"
    overlay.layer = 18
    overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    overlay._build()
    return overlay


func is_open() -> bool:
    return _root.visible


func _build() -> void:
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.visible = false
    add_child(_root)
    var dim: ColorRect = ColorRect.new()
    dim.color = Color(0.02, 0.0, 0.01, 0.78)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.add_child(dim)
    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.add_child(center)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 18)
    center.add_child(column)
    title_label = MenuStyle.label("", 30)
    column.add_child(title_label)
    offer_view = CardOfferView.new()
    offer_view.name = "Offers"
    offer_view.picked.connect(_finish)
    column.add_child(offer_view)
    skip_button = MenuStyle.button("Take nothing")
    skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    skip_button.pressed.connect(func() -> void: _finish(null))
    column.add_child(skip_button)


func open(title: String, cards: Array[CardData]) -> void:
    title_label.text = title
    _root.visible = true
    get_tree().paused = true
    offer_view.show_offers(cards)


func _finish(card: CardData) -> void:
    _root.visible = false
    get_tree().paused = false
    resolved.emit(card)

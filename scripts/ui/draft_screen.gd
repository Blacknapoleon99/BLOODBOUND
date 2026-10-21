extends Control
## Pre-run draft: three rounds of "pick 1 of 3" random cards build the starting deck.
## Starts a new run (random seed) unless one was already started, e.g. with a fixed seed by tests.

const GAME_SCENE: String = "res://scenes/main.tscn"

var offer_view: CardOfferView
var round_label: Label
var chosen_label: Label


func _ready() -> void:
    InputBindings.ensure_defaults()
    set_anchors_preset(Control.PRESET_FULL_RECT)
    if not RunState.active or RunState.draft_done():
        RunState.new_run()
    var background: ColorRect = ColorRect.new()
    background.color = Color(0.03, 0.02, 0.035)
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 20)
    center.add_child(column)
    column.add_child(MenuStyle.label("CHOOSE YOUR COVENANT", 40))
    round_label = MenuStyle.label("", 20, Color(0.8, 0.2, 0.22))
    column.add_child(round_label)
    offer_view = CardOfferView.new()
    offer_view.name = "Offers"
    offer_view.picked.connect(_on_picked)
    column.add_child(offer_view)
    chosen_label = MenuStyle.label("", 16, Color(0.7, 0.66, 0.6))
    column.add_child(chosen_label)
    column.add_child(MenuStyle.label("Click a card or press 1 / 2 / 3", 14, Color(0.55, 0.5, 0.48)))
    _next_round()


func _next_round() -> void:
    if RunState.draft_done():
        get_tree().change_scene_to_file(GAME_SCENE)
        return
    round_label.text = "Pick %d of %d  ·  run seed %d" % [RunState.deck.size() + 1, RunState.DRAFT_ROUNDS, RunState.seed_value]
    var names: Array = RunState.deck.map(func(c: CardData) -> String: return c.display_name)
    chosen_label.text = "Your deck: " + (", ".join(names) if not names.is_empty() else "—")
    offer_view.show_offers(RunState.next_offer())


func _on_picked(choice: Resource) -> void:
    RunState.deck.append(choice as CardData)
    _next_round.call_deferred()

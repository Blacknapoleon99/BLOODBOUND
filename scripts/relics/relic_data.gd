class_name RelicData
extends Resource
## A passive run modifier. Relics are picked at Blood Altars and from a cleared fracture,
## kept in RunState.relics for the rest of the run, and applied by main.gd (see `id` list in
## docs/CARDS.md). They have no cost and no button: they just change the rules a little.

@export var id: StringName = &"relic"
@export var display_name: String = "Relic"
@export_multiline var description: String = ""
## Relative chance to appear in a random offer.
@export var offer_weight: float = 1.0
@export var ui_color: Color = Color(0.85, 0.7, 0.3)

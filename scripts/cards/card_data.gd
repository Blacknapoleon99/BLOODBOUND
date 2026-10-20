class_name CardData
extends Resource
## Data definition for one Bloodbound Card. Cards are real-time abilities: playing one is
## validated (state → cooldown → target → energy) before anything is spent or applied.

enum Targeting {
    SELF,              ## always has a target (the player)
    BOSS_WEAK_POINT,   ## needs an exposed weak-point Hurtbox within `card_range`
    BOSS_TELEGRAPH,    ## needs a boss action that is currently interruptible
    ENEMY,             ## nearest living enemy Hurtbox within `card_range`; exposed weak points first
}
## (Append new values at the end: .tres files store these as integers.)

@export var id: StringName = &"card"
@export var display_name: String = "Card"
@export_multiline var description: String = ""
@export var cost: int = 1
@export var cooldown: float = 1.0
@export var targeting: Targeting = Targeting.SELF
## Which effect CardSystem runs: &"blood_spear", &"grave_shield", &"ritual_chains".
@export var effect: StringName = &""
@export var tags: PackedStringArray = PackedStringArray()
@export_group("Effect parameters")
@export var damage: int = 0
@export var duration: float = 0.0
@export var card_range: float = 0.0
## Damage category a defensive card blocks (Grave Shield).
@export var blocks_category: StringName = &""
## Generic magnitude for effects that are not damage (blood gained, HP healed, radius...).
@export var amount: float = 0.0
## Health the card costs to play (Hemorrhage Pact). Refused if it would kill the player.
@export var hp_cost: int = 0
@export_group("Draft")
## Relative chance to appear in a random offer (draft, altars).
@export var offer_weight: float = 1.0
@export_group("Presentation")
@export var ui_color: Color = Color(0.6, 0.1, 0.12)
## Hook for later authored VFX; unused by the greybox.
@export var vfx_id: StringName = &""

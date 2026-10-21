class_name ItemData
extends Resource
## A piece of equipment: one weapon, one armor and one charm can be worn. Items grant
## attributes (see Equipment for what each attribute does); weapons also set the attack speed
## and may add heavy-strike damage. Owned items persist between runs (see Profile).

enum Slot { WEAPON, ARMOR, CHARM }

@export var id: StringName = &"item"
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var slot: Slot = Slot.WEAPON
@export_group("Attributes")
@export var vigor: int = 0
@export var might: int = 0
@export var agility: int = 0
@export var devotion: int = 0
@export_group("Weapon")
## Multiplier on melee attack speed (1.25 = every phase 25% shorter).
@export var attack_speed: float = 1.0
@export var heavy_damage: int = 0
@export_group("Presentation")
@export var offer_weight: float = 1.0
@export var ui_color: Color = Color(0.6, 0.55, 0.45)


static func slot_name(which: Slot) -> String:
    return ["WEAPON", "ARMOR", "CHARM"][which]


## One line such as "Might +2 · Agility -1 · speed x0.85 · heavy +2".
func stat_line() -> String:
    var parts: Array[String] = []
    for pair: Array in [["Vigor", vigor], ["Might", might], ["Agility", agility], ["Devotion", devotion]]:
        if int(pair[1]) != 0:
            parts.append("%s %+d" % [pair[0], pair[1]])
    if not is_equal_approx(attack_speed, 1.0):
        parts.append("attack speed x%.2f" % attack_speed)
    if heavy_damage != 0:
        parts.append("heavy %+d" % heavy_damage)
    return " · ".join(parts) if not parts.is_empty() else "No bonuses"

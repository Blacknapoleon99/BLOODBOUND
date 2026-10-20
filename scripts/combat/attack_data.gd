class_name AttackData
extends Resource
## Data definition for one melee attack. Timings are seconds.
##
## Phases: STARTUP (wind-up / telegraph, no hitbox) → ACTIVE (hitbox live) → RECOVERY
## (no hitbox, attacker vulnerable). Cancel rule: only RECOVERY may be cancelled into a
## dodge, and only when `dodge_cancel_recovery` is true. STARTUP and ACTIVE always commit.

@export var id: StringName = &"attack"
@export_group("Timing")
@export var startup: float = 0.1
@export var active: float = 0.1
@export var recovery: float = 0.2
@export_group("Effect")
@export var damage: int = 1
@export var category: StringName = &"melee"
@export var knockback: float = 4.0
@export var knockback_up: float = 2.0
@export var hitstun: float = 0.3
## How much this hit wears down an enemy's poise (stagger meter). See PlaguedSoldier.
@export var poise_damage: int = 1
@export_group("Combo")
## Next step when the attack is pressed again (or held) within the combo window.
@export var next_combo: AttackData
@export_group("Hitbox (attacker-local, along facing)")
## Distance from the attacker's centre to the hitbox centre along facing.
@export var reach_offset: float = 0.9
## Hitbox length along facing.
@export var reach: float = 1.3
@export var width: float = 1.0
@export var height: float = 1.4
@export var height_offset: float = 0.0
@export_group("Movement")
## Multiplier on the attacker's run speed while the attack plays.
@export var move_multiplier: float = 0.2
## Forward speed during ACTIVE.
@export var lunge_speed: float = 0.0
@export var dodge_cancel_recovery: bool = true


func total_time() -> float:
    return startup + active + recovery

class_name DamageInfo
extends RefCounted
## One delivered hit. Created per target by Hitbox so knockback points away from the attacker.

var amount: int = 1
## Final knockback velocity applied to the victim (already directed).
var knockback: Vector3 = Vector3.ZERO
var hitstun: float = 0.25
## Stagger-meter damage (see PlaguedSoldier poise).
var poise_damage: int = 1
## Damage category, e.g. &"melee" or &"heavy". Cards (Grave Shield) will filter on this.
var category: StringName = &"melee"
var source: Node3D
var hit_position: Vector3 = Vector3.ZERO
var attack_id: StringName = &""

class_name Health
extends Node
## Hit points for any combatant. Knows nothing about hitboxes, AI or UI.

signal changed(current: int, maximum: int)
signal damaged(amount: int)
signal died

@export var max_health: int = 5

var current: int = 0


func _ready() -> void:
    current = max_health


func is_dead() -> bool:
    return current <= 0


func apply_damage(amount: int) -> void:
    if is_dead() or amount <= 0:
        return
    current = maxi(0, current - amount)
    damaged.emit(amount)
    changed.emit(current, max_health)
    if current == 0:
        died.emit()


func restore_full() -> void:
    current = max_health
    changed.emit(current, max_health)

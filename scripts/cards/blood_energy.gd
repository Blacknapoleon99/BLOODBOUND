class_name BloodEnergy
extends Node
## The resource cards spend. Earned by landing melee hits, plus a slow passive trickle so a
## player who is only dodging is never locked out of cards forever.

signal changed(current: float, maximum: float)

@export var maximum: float = 6.0
@export var start_amount: float = 2.0
@export var per_hit: float = 1.0
@export var regen_per_second: float = 0.25

var current: float = 0.0


func _ready() -> void:
    current = start_amount


func _physics_process(delta: float) -> void:
    if current < maximum and regen_per_second > 0.0:
        add(regen_per_second * delta)


func can_afford(cost: float) -> bool:
    return current + 0.0001 >= cost


func add(amount: float) -> void:
    var before: float = current
    current = clampf(current + amount, 0.0, maximum)
    if not is_equal_approx(before, current):
        changed.emit(current, maximum)


## Spends `cost` if affordable; returns false (and spends nothing) otherwise.
func spend(cost: float) -> bool:
    if not can_afford(cost):
        return false
    add(-cost)
    return true


## Direct setter for tests, debug tools and save/load.
func set_amount(amount: float) -> void:
    current = clampf(amount, 0.0, maximum)
    changed.emit(current, maximum)

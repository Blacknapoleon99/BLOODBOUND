extends LevelSection
## Blade Corridor (Act 2, difficulty 3): A corridor of swinging blades and spike strips in rhythm, ending at a Shielded Knight
## who holds the exit.

const DIFFICULTY: int = 3


func _init() -> void:
    id = &"blade_corridor"
    title = "Blade Corridor"
    act = 2
    difficulty = DIFFICULTY
    width = 56.0
    _palette = Color(0.2, 0.18, 0.18)


func _design() -> void:
    ground(0.0, 33.0)
    secret_cellar(33.0, &"shards", 20)
    ground(35.0, 56.0)
    pendulum(12.0, 0.0, 0.0)
    spikes(16.0, 2.0, 0.5)
    pendulum(20.0, 0.0, 1.1)
    spikes(24.5, 2.0, 1.0)
    spikes(29.0, 2.0, 1.6)
    enemy(&"knight", 44.0, 37.0, 52.0)
    enemy(&"crawler", 40.0, 33.0, 52.0)

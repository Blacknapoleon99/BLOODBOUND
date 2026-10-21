extends LevelSection
## Sunken Reliquary (Act 2, difficulty 3): A flooded reliquary with two roads: the LOW road is a straight fight through a sunken hall
## (knight, crawlers); the HIGH road is a hazard run along the rafters. Both reach the exit.

const DIFFICULTY: int = 3


func _init() -> void:
    id = &"sunken_reliquary"
    title = "Sunken Reliquary"
    act = 2
    difficulty = DIFFICULTY
    width = 64.0
    _palette = Color(0.16, 0.19, 0.2)


func _design() -> void:
    ground(0.0, 8.0)
    ground(8.0, 52.0, -2.0, -3.0, "Sunken hall")
    ground(52.0, 56.0, -1.0, -3.0, "Hall steps")
    enemy(&"crawler", 20.0, 9.0, 51.5, -2.0)
    enemy(&"knight", 32.0, 9.0, 51.5, -2.0)
    enemy(&"crawler", 44.0, 9.0, 51.5, -2.0)
    ledge(9.0, 13.0, 1.4, "Rafter")
    ledge(15.0, 19.0, 3.0, "Rafter")
    spikes(17.0, 1.6, 0.4, 3.0)
    ledge(21.5, 25.5, 3.0, "Rafter")
    ledge(28.0, 32.0, 3.0, "Rafter")
    pendulum(30.0, 3.0, 0.6)
    ledge(34.5, 38.5, 3.0, "Rafter")
    ledge(41.0, 45.0, 3.0, "Rafter")
    ledge(47.5, 51.5, 1.6, "Rafter")
    ground(56.0, 64.0)

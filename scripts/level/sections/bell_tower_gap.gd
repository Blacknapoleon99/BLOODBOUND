extends LevelSection
## Bell Tower Gap (Act 1, difficulty 2): Two wide gaps under the bell tower, crossed on swinging ferries; a pendulum guards the
## island between them, and crawlers nest beyond.

const DIFFICULTY: int = 2


func _init() -> void:
    id = &"bell_tower_gap"
    title = "Bell Tower Gap"
    act = 1
    difficulty = DIFFICULTY
    width = 54.0
    _palette = Color(0.19, 0.18, 0.24)


func _design() -> void:
    ground(0.0, 8.0)
    mover(9.5, 16.5)
    ground(18.0, 26.0, 0.0, -1.0, "Bell island")
    pendulum(22.0)
    mover(27.5, 35.5, 0.0, 3.0, 2.6)
    ground(37.0, 54.0)
    enemy(&"crawler", 42.0, 37.5, 53.5)
    enemy(&"crawler", 47.0, 37.5, 53.5)
    enemy(&"husk", 50.0, 37.5, 53.5)

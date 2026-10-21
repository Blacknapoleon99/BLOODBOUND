extends LevelSection
## Crypt Stairs (Act 1, difficulty 1): A climb up crypt steps to a high hall (archer + husk), then a drop across floating ledges
## over the abyss.

const DIFFICULTY: int = 1


func _init() -> void:
    id = &"crypt_stairs"
    title = "Crypt Stairs"
    act = 1
    difficulty = DIFFICULTY
    width = 50.0
    _palette = Color(0.2, 0.19, 0.23)


func _design() -> void:
    ground(0.0, 6.0)
    ground(6.0, 9.0, 1.4)
    ground(9.0, 12.0, 2.8)
    ground(12.0, 15.0, 4.2)
    ground(15.0, 25.0, 5.6, -1.0, "High hall")
    enemy(&"husk", 19.0, 15.5, 24.5, 5.6)
    enemy(&"archer", 23.5, 15.5, 24.5, 5.6)
    ledge(27.0, 30.0, 4.0)
    ledge(32.0, 34.5, 2.4)
    ledge(36.5, 39.0, 1.0)
    ground(41.0, 50.0)
    enemy(&"crawler", 46.0, 41.0, 50.0)

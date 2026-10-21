extends LevelSection
## Wraith Belfry (Act 2, difficulty 4): A broken belfry: hop between floating beams up and down over the abyss while Flying
## Wraiths dive at you. Standing still is death.

const DIFFICULTY: int = 4


func _init() -> void:
    id = &"wraith_belfry"
    title = "Wraith Belfry"
    act = 2
    difficulty = DIFFICULTY
    width = 50.0
    _palette = Color(0.17, 0.18, 0.25)


func _design() -> void:
    ground(0.0, 6.0)
    ledge(8.0, 11.0, 1.5)
    ledge(13.0, 16.0, 3.0)
    ledge(18.0, 21.0, 4.5)
    ledge(23.0, 27.0, 3.0)
    ledge(29.0, 32.0, 1.5)
    ledge(34.0, 37.0, 3.0)
    ledge(39.0, 42.0, 1.5)
    ground(44.0, 50.0)
    enemy(&"wraith", 15.0, 2.0, 48.0, 3.0)
    enemy(&"wraith", 27.0, 2.0, 48.0, 3.0)
    enemy(&"wraith", 38.0, 2.0, 48.0, 1.5)

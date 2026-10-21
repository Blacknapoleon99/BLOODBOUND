extends LevelSection
## The Gravewarden's Hall (elite, fixed after Act I): a sealed arena with the act's mini-boss.

const DIFFICULTY: int = 5


func _init() -> void:
    id = &"gravewarden_hall"
    title = "The Gravewarden's Hall"
    act = 0
    difficulty = DIFFICULTY
    width = 44.0
    _palette = Color(0.23, 0.19, 0.16)


func _design() -> void:
    ground(0.0, 44.0)

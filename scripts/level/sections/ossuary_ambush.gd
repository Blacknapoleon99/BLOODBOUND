extends LevelSection
## Ossuary Ambush (Act 1, difficulty 2): An ossuary that seals itself: hounds, Husks and an archer, with raised bone shelves to
## fight from. A Blood Altar waits as the reward.

const DIFFICULTY: int = 2


func _init() -> void:
    id = &"ossuary_ambush"
    title = "Ossuary Ambush"
    act = 1
    difficulty = DIFFICULTY
    width = 44.0
    _palette = Color(0.22, 0.2, 0.2)


func _design() -> void:
    ground(0.0, 44.0)
    ledge(15.0, 18.0, 1.8, "Bone shelf")
    ledge(26.0, 29.0, 1.8, "Bone shelf")
    ambush("Ambush: Ossuary", 12.0, 10.0, 34.0, [
        {"type": &"hound", "x": 20.0}, {"type": &"husk", "x": 24.0},
        {"type": &"husk", "x": 28.0}, {"type": &"archer", "x": 31.5},
    ])
    altar(38.0)

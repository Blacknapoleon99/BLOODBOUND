extends LevelSection
## Charnel Arena (Act 2, difficulty 4): A charnel pit that seals itself for two waves: every kind of foe, Shielded Knight
## included. A Blood Altar rewards the survivor.

const DIFFICULTY: int = 4


func _init() -> void:
    id = &"charnel_arena"
    title = "Charnel Arena"
    act = 2
    difficulty = DIFFICULTY
    width = 48.0
    _palette = Color(0.24, 0.17, 0.17)


func _design() -> void:
    ground(0.0, 48.0)
    ledge(14.0, 17.0, 2.0, "Bone shelf")
    ledge(29.0, 32.0, 2.0, "Bone shelf")
    ambush("Ambush: Charnel", 9.0, 7.0, 39.0, [
        {"type": &"hound", "x": 18.0}, {"type": &"crawler", "x": 22.0},
        {"type": &"archer", "x": 33.0}, {"type": &"husk", "x": 26.0},
        {"type": &"knight", "x": 30.0, "wave": 1}, {"type": &"wraith", "x": 20.0, "wave": 1},
        {"type": &"hound", "x": 35.0, "wave": 1},
    ])
    altar(43.0)

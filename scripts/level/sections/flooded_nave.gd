extends LevelSection
## Flooded Nave (Act 1, difficulty 1): A long flooded corridor: three spike strips in sequence (time the run), Husks wading in,
## and an archer on a choir loft.

const DIFFICULTY: int = 1


func _init() -> void:
    id = &"flooded_nave"
    title = "Flooded Nave"
    act = 1
    difficulty = DIFFICULTY
    width = 56.0
    _palette = Color(0.15, 0.2, 0.24)


func _design() -> void:
    ground(0.0, 56.0)
    spikes(10.0, 2.4, 0.0)
    spikes(16.0, 2.4, 0.7)
    spikes(22.0, 2.4, 1.4)
    enemy(&"husk", 28.0, 25.0, 35.0)
    enemy(&"husk", 33.0, 25.0, 35.0)
    ledge(36.0, 41.0, 2.2, "Choir loft")
    enemy(&"archer", 39.0, 36.5, 40.5, 2.2)
    spikes(45.0, 2.0, 0.3)
    spikes(49.5, 2.0, 1.1)

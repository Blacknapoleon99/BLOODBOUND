extends LevelSection
## Collapsing Gallery (Act 2, difficulty 3): A gallery collapsing into the abyss: two chains of crumbling slabs either side of a stone
## pillar, under archer fire. Shadow Step and Ossuary Bridge shine here.

const DIFFICULTY: int = 3


func _init() -> void:
    id = &"collapsing_gallery"
    title = "Collapsing Gallery"
    act = 2
    difficulty = DIFFICULTY
    width = 60.0
    _palette = Color(0.22, 0.17, 0.2)


func _design() -> void:
    ground(0.0, 6.0)
    for x: float in [8.0, 11.8, 15.6, 19.4, 23.2]:
        slab(x)
    ground(25.5, 30.0, 1.0, -3.0, "Gallery pillar")
    enemy(&"archer", 28.5, 26.0, 29.5, 1.0)
    shortcut(27.0, 1.0, 6.0, 25.5, 0.0)  # pull it at the pillar: a bridge over the first slabs
    for x: float in [32.3, 36.1, 39.9, 43.7, 47.5]:
        slab(x)
    ground(49.8, 60.0)
    enemy(&"archer", 57.0, 50.5, 59.5)

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


## 3D course (DEC-052): the charnel pit seals itself (a ring of bone walls) for two waves of
## every kind of foe; the Blood Altar rewards the survivor in the pit. PIT (middle): through the
## fight. RIM (north): the crumbling rim round the pit's edge. GALLOWS (south): climb the gallows
## post and cross its beam. Off the paths: a card cellar off the rim stairs, shards on the
## gallows and a shelf.
func _course() -> void:
    pads()
    route(&"pit")
    plat(12.0, 0.0, 4.0, 4.0, 0.0, "Pit bridge")
    plat(24.0, 0.0, 20.0, 20.0, 0.0, "Charnel pit", 1.5)
    plat(37.0, 0.0, 6.0, 4.0, 0.0, "Pit bridge")
    plat(19.0, -5.0, 3.0, 3.0, 2.0, "Bone shelf")
    plat(29.0, 5.0, 3.0, 3.0, 2.0, "Bone shelf")
    arena("Ambush: Charnel", 24.0, 0.0, 9.0, [
        {"type": &"hound"}, {"type": &"crawler"}, {"type": &"archer"}, {"type": &"husk"},
        {"type": &"knight", "wave": 1}, {"type": &"wraith", "wave": 1}, {"type": &"hound", "wave": 1},
    ], 0.0, 9.2)
    altar(27.0, 0.0, -4.0)
    shard(29.0, 5.0, 2.0)
    route(&"rim")
    plat(9.0, -7.0, 4.0, 3.0, 1.4, "Rim stair")
    plat(13.0, -10.5, 4.0, 3.0, 2.8, "Rim stair")
    for x: float in [17.8, 21.6, 25.4, 29.2, 33.0]:
        crumble(x, -13.5, 2.8)
    plat(37.0, -10.0, 3.0, 3.0, 1.4, "Rim stair")
    plat(39.5, -6.0, 3.0, 3.0, 0.7, "Rim stair")
    route(&"gallows")
    plat(10.0, 8.0, 4.0, 4.0, 0.0, "Gallows foot")
    climb(14.5, 12.5, 3.0, 3.0, -2.0, 7.0, "Gallows post")
    plat(24.0, 13.5, 12.0, 2.0, 6.0, "Gallows beam", 0.5)
    plat(33.5, 12.0, 3.0, 3.0, 4.5, "Gallows stair", 0.5)
    plat(38.0, 8.5, 3.0, 3.0, 3.0, "Gallows stair", 0.5)
    shard(24.0, 13.5, 6.0)
    route(&"side")
    cellar(13.0, -16.5, 2.8, &"card")

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


## 3D course (DEC-052): the ossuary floor is an arena that seals itself (a ring of bone walls)
## when you step in; the Blood Altar waits inside it. Fight through it (FLOOR), or skirt it:
## RAFTERS (north: bone columns and a guarded beam) or BONES (south: climb the bone heap, cross
## the bone bridge). A pillar beside the floor holds shards for a triple jump.
func _course() -> void:
    pads()
    route(&"floor")
    plat(22.0, 0.0, 18.0, 18.0, 0.0, "Ossuary floor", 1.5)
    plat(33.5, 0.0, 5.0, 4.0, 0.0, "Ossuary bridge")
    plat(18.0, -5.0, 3.0, 3.0, 1.8, "Bone shelf")
    plat(26.0, 5.0, 3.0, 3.0, 1.8, "Bone shelf")
    arena("Ambush: Ossuary", 22.0, 0.0, 8.0, [
        {"type": &"hound"}, {"type": &"husk"}, {"type": &"husk"}, {"type": &"archer"},
    ], 0.0, 8.2)
    altar(22.0, 0.0, 0.0)
    route(&"rafters")
    pillar(9.0, -7.5, 3.0, 1.2, "Bone column")
    pillar(13.0, -12.0, 3.0, 2.4, "Bone column")
    plat(23.0, -14.0, 14.0, 2.5, 3.6, "Rafter", 0.6)
    foe(&"archer", 27.0, -14.0, 3.6)
    pillar(33.0, -10.0, 3.0, 2.4, "Bone column")
    pillar(37.0, -6.0, 3.0, 1.2, "Bone column")
    shard(19.0, -14.0, 3.6)
    route(&"bones")
    plat(9.0, 9.0, 5.0, 5.0, 0.0, "Bone heap foot")
    climb(15.0, 13.0, 3.0, 3.0, -1.0, 5.0, "Bone heap")
    plat(23.0, 14.0, 10.0, 2.0, 5.0, "Bone bridge", 0.5)
    plat(31.5, 11.0, 3.0, 3.0, 4.0, "Bone ledge", 0.5)
    plat(36.0, 7.0, 3.0, 3.0, 2.5, "Bone ledge", 0.5)
    shard(23.0, 14.0, 5.0)
    route(&"side")
    pillar(22.0, 11.5, 2.5, 2.6, "Reliquary pillar")
    shard(22.0, 11.5, 2.6, 5)

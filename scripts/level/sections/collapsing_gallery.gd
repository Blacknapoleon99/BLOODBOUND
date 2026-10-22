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


## 3D course (DEC-052): a gallery falling into the abyss. SLABS (middle): two chains of
## crumbling slabs either side of the stone pillar (archer; its lever knits a bone bridge back
## beside the first chain). BALCONY (north): the high gallery, archers along it and a crumbling
## gap. FERRY (south): a long ride on a bone ferry under fire. Off the paths: a chandelier climb
## on the pillar and a far post, both with shards.
func _course() -> void:
    pads()
    route(&"slabs")
    for x: float in [12.5, 16.3, 20.1, 23.9]:
        crumble(x, 0.0, 0.0)
    plat(30.0, 0.0, 6.0, 6.0, 1.0, "Gallery pillar", 4.0)
    foe(&"archer", 31.0, 0.0, 1.0)
    lever(29.0, 2.0, 1.0, 10.0, 27.0, 3.4, 0.0, 2.0)
    for x: float in [36.5, 40.3, 44.1, 47.9]:
        crumble(x, 0.0, 0.0)
    route(&"balcony")
    plat(8.0, -7.0, 4.0, 3.0, 1.4, "Gallery stair")
    plat(12.0, -10.0, 4.0, 3.0, 2.8, "Gallery stair")
    plat(22.0, -12.0, 14.0, 4.0, 3.5, "High gallery", 1.0)
    foe(&"archer", 24.0, -12.0, 3.5)
    crumble(31.0, -12.0, 3.5, 2.6, 3.0)
    plat(39.0, -12.0, 12.0, 4.0, 3.5, "High gallery", 1.0)
    foe(&"archer", 41.0, -12.0, 3.5)
    plat(48.0, -8.0, 3.0, 3.0, 2.2, "Gallery stair")
    route(&"ferry")
    plat(9.0, 8.0, 4.0, 4.0, 0.0, "Ferry landing")
    lift(Vector3(14.0, 0.0, 10.0), Vector3(44.0, 0.0, 10.0), 3.0, 3.0, 5.5)
    plat(48.5, 8.0, 4.0, 4.0, 0.0, "Ferry landing")
    route(&"side")
    climb(30.0, -5.0, 3.0, 2.0, -2.0, 7.5, "Chandelier chain")
    shard(30.0, -5.0, 7.5, 5)
    pillar(44.0, 15.0, 2.5, 2.0, "Far post")
    shard(44.0, 15.0, 2.0, 5)

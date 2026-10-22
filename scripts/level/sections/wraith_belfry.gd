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
    shortcut(45.0, 0.0, 6.0, 44.0, -1.5)  # at the far side: a low bridge back under the beams
    enemy(&"wraith", 15.0, 2.0, 48.0, 3.0)
    enemy(&"wraith", 27.0, 2.0, 48.0, 3.0)
    enemy(&"wraith", 38.0, 2.0, 48.0, 1.5)


## 3D course (DEC-052): a broken belfry hanging in the void while Flying Wraiths dive. BEAMS
## (middle): hop up and down a zig-zag of floating beams. CAROUSEL (south): ride the bone
## carousel round the bell. TOWER (north): climb the belfry tower and run its high beams down.
## At the far side a lever knits a low bridge back under everything (a shortcut after a death).
func _course() -> void:
    pads()
    route(&"beams")
    plat(13.0, -3.0, 3.0, 3.0, 1.5, "Beam", 0.5)
    plat(16.5, -7.0, 3.0, 3.0, 3.0, "Beam", 0.5)
    plat(21.0, -9.0, 3.0, 3.0, 4.5, "Beam", 0.5)
    plat(25.5, -6.0, 3.0, 3.0, 3.0, "Beam", 0.5)
    plat(29.0, -2.5, 3.0, 3.0, 1.5, "Beam", 0.5)
    plat(33.5, -5.0, 3.0, 3.0, 3.0, "Beam", 0.5)
    plat(38.0, -3.0, 3.0, 3.0, 1.5, "Beam", 0.5)
    shard(21.0, -9.0, 4.5)
    route(&"carousel")
    plat(11.0, 7.0, 4.0, 4.0, 1.0, "Carousel step")
    orbit(25.0, 9.0, 2.0, 8.0, 10.0, PI, 3.0)
    plat(38.0, 6.5, 3.0, 3.0, 1.0, "Carousel step")
    route(&"tower")
    plat(9.0, -9.0, 4.0, 4.0, 0.0, "Tower foot")
    climb(14.0, -14.0, 3.0, 3.0, -3.0, 9.0, "Belfry tower")
    plat(20.5, -14.0, 4.0, 2.0, 8.0, "High beam", 0.4)
    plat(27.0, -14.0, 4.0, 2.0, 7.0, "High beam", 0.4)
    plat(33.5, -13.0, 4.0, 2.0, 6.0, "High beam", 0.4)
    plat(38.5, -9.0, 3.0, 3.0, 4.0, "High beam", 0.5)
    shard(14.0, -14.0, 9.0, 5)
    shard(27.0, -14.0, 7.0, 5)
    lever(46.0, 2.0, 0.0, 10.5, 41.5, 0.0, -1.5, 2.4)
    foe(&"wraith", 21.0, -9.0, 4.5)
    foe(&"wraith", 25.0, 9.0, 2.0)
    foe(&"wraith", 33.5, -5.0, 3.0)

extends LevelSection
## Bell Tower Gap (Act 1, difficulty 2): Two wide gaps under the bell tower, crossed on swinging ferries; a pendulum guards the
## island between them, and crawlers nest beyond.

const DIFFICULTY: int = 2


func _init() -> void:
    id = &"bell_tower_gap"
    title = "Bell Tower Gap"
    act = 1
    difficulty = DIFFICULTY
    width = 54.0
    _palette = Color(0.19, 0.18, 0.24)


func _design() -> void:
    ground(0.0, 8.0)
    mover(9.5, 16.5)
    ground(18.0, 26.0, 0.0, -1.0, "Bell island")
    pendulum(22.0)
    mover(27.5, 35.5, 0.0, 3.0, 2.6)
    ground(37.0, 54.0)
    enemy(&"crawler", 42.0, 37.5, 53.5)
    enemy(&"crawler", 47.0, 37.5, 53.5)
    enemy(&"husk", 50.0, 37.5, 53.5)


## 3D course (DEC-052): a great gap round the bell island. FERRY (middle): two swinging ferries
## and the bell island between them, guarded by a pendulum. CAROUSEL (north): stairs up to a
## bone platform circling the island. TOWER (south): climb the bell tower and walk the bell
## rope down. Crawlers nest on the far landing; a cellar hides beside the island.
func _course() -> void:
    pads(10.0, 12.0)
    foe(&"crawler", 47.0, 2.0)
    foe(&"crawler", 51.0, -2.0)
    route(&"ferry")
    lift(Vector3(12.5, 0.0, 0.0), Vector3(19.5, 0.0, 0.0), 3.0, 3.0, 2.2)
    plat(27.0, 0.0, 10.0, 10.0, 0.0, "Bell island", 1.5)
    blade(27.0, 0.0, 0.0, 0.0, 9.0)
    lift(Vector3(34.0, 0.0, 0.0), Vector3(38.5, 0.0, 0.0), 3.0, 3.0, 2.0)
    route(&"carousel")
    plat(8.0, -8.0, 4.0, 4.0, 1.4, "Belfry stair")
    plat(13.0, -10.5, 4.0, 3.0, 2.8, "Belfry stair")
    pillar(17.5, -11.0, 3.0, 4.0, "Belfry post")
    orbit(27.0, 0.0, 4.0, 11.0, 12.0, 0.0, 3.0)
    pillar(38.5, -10.0, 3.0, 4.0, "Belfry post")
    plat(42.0, -7.0, 3.0, 3.0, 2.6, "Belfry stair")
    route(&"tower")
    pillar(9.5, 8.5, 3.5, 0.0, "Tower footing")
    climb(15.0, 12.0, 4.0, 4.0, -3.0, 9.0, "Bell tower")
    plat(24.0, 12.0, 10.0, 2.0, 8.0, "Bell rope", 0.4)
    plat(33.0, 10.0, 3.0, 3.0, 6.5, "Bell frame", 0.5)
    plat(37.5, 7.0, 3.0, 3.0, 5.0, "Bell frame", 0.5)
    plat(41.5, 5.0, 3.0, 3.0, 3.5, "Bell frame", 0.5)
    shard(15.0, 12.0, 9.0, 5)
    shard(24.0, 12.0, 8.0)
    route(&"side")
    cellar(27.0, 9.0, 0.0, &"shards", 20)
    pillar(27.0, -16.0, 2.5, 4.0, "Lone post")
    shard(27.0, -16.0, 4.0, 5)

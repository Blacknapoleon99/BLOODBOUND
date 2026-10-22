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
    ground(0.0, 52.0)
    secret_cellar(52.0, &"card")
    ground(54.0, 56.0)
    spikes(10.0, 2.4, 0.0)
    spikes(16.0, 2.4, 0.7)
    spikes(22.0, 2.4, 1.4)
    enemy(&"husk", 28.0, 25.0, 35.0)
    enemy(&"husk", 33.0, 25.0, 35.0)
    ledge(36.0, 41.0, 2.2, "Choir loft")
    enemy(&"archer", 39.0, 36.5, 40.5, 2.2)
    spikes(45.0, 2.0, 0.3)
    spikes(49.5, 2.0, 1.1)


## 3D course (DEC-052): three ways. NAVE (middle): three flooded islands, each crossed by a
## timed spike bed, Husks wading. LOFT (north): up to the choir loft (archer), past a swinging
## blade. AISLE (south): drowned columns and a long run of crumbling pews (shards on the way).
## Off the paths: the card cellar at the aisle's end, a bell perch above the loft.
func _course() -> void:
    pads()
    route(&"nave")
    plat(17.0, 3.0, 10.0, 10.0, 0.0, "Flooded nave", 1.5)
    plat(29.0, 4.0, 8.0, 10.0, 0.0, "Flooded nave", 1.5)
    plat(40.5, 4.0, 9.0, 10.0, 0.0, "Flooded nave", 1.5)
    spike_bed(16.0, 3.0, 2.4, 9.6, 0.0, 0.0)
    spike_bed(29.0, 4.0, 2.4, 9.6, 0.0, 0.7)
    spike_bed(40.5, 4.0, 2.4, 9.6, 0.0, 1.4)
    foe(&"husk", 31.0, 5.0)
    foe(&"husk", 42.5, 2.0)
    route(&"loft")
    plat(9.0, -8.0, 4.0, 4.0, 1.2, "Loft stair")
    plat(15.0, -10.0, 5.0, 4.0, 2.4, "Loft stair")
    plat(25.0, -11.0, 12.0, 5.0, 2.4, "Choir loft", 1.5)
    foe(&"archer", 28.0, -11.0, 2.4)
    plat(36.0, -10.0, 6.0, 4.0, 2.4, "Choir walk", 0.5)
    blade(36.0, -10.0, 2.4, 0.3, 4.0)
    plat(44.0, -7.0, 5.0, 4.0, 1.2, "Loft stair")
    route(&"aisle")
    pillar(8.0, 7.5, 2.5, 0.0, "Drowned column")
    pillar(10.0, 12.0, 2.5, 0.0, "Drowned column")
    for x: float in [15.0, 19.5, 24.0, 28.5, 33.0, 37.5, 42.0]:
        crumble(x, 14.0, 0.0)
    pillar(46.0, 11.0, 3.0, 0.0, "Drowned column")
    pillar(49.5, 7.0, 3.0, 0.0, "Drowned column")
    shard(24.0, 14.0, 0.0, 2)
    shard(37.5, 14.0, 0.0, 2)
    route(&"side")
    cellar(52.0, 13.0, 0.0, &"card")
    climb(22.0, -15.5, 3.0, 2.0, -2.0, 8.0, "Bell perch")
    shard(22.0, -15.5, 8.0, 5)

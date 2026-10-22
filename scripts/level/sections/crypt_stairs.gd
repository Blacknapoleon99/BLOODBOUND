extends LevelSection
## Crypt Stairs (Act 1, difficulty 1): A climb up crypt steps to a high hall (archer + husk), then a drop across floating ledges
## over the abyss.
##
## 3D course (DEC-052): three ways to the exit arch. GROUND (south): through the crypt yard and
## a spiked cloister, husk and crawlers. HIGH (north): the crypt stairs up to the high hall
## (husk + archer), then down across floating ledges. CLIMB (middle): scale the ossuary spire
## and walk its beams. Off the paths: a relic cellar beside the yard, a balcony and a bell
## spire above the high hall (shards).

const DIFFICULTY: int = 1


func _init() -> void:
    id = &"crypt_stairs"
    title = "Crypt Stairs"
    act = 1
    difficulty = DIFFICULTY
    width = 50.0
    _palette = Color(0.2, 0.19, 0.23)


func _design() -> void:
    ground(0.0, 6.0)
    ground(6.0, 9.0, 1.4)
    ground(9.0, 12.0, 2.8)
    ground(12.0, 15.0, 4.2)
    ground(15.0, 25.0, 5.6, -1.0, "High hall")
    enemy(&"husk", 19.0, 15.5, 24.5, 5.6)
    enemy(&"archer", 23.5, 15.5, 24.5, 5.6)
    ledge(27.0, 30.0, 4.0)
    ledge(32.0, 34.5, 2.4)
    ledge(36.5, 39.0, 1.0)
    ground(41.0, 46.0)
    secret_cellar(46.0, &"relics")
    ground(48.0, 50.0)
    enemy(&"crawler", 46.0, 41.0, 50.0)


func _course() -> void:
    pads()
    # GROUND: the crypt yard and the spiked cloister (south).
    route(&"ground")
    plat(17.0, 8.0, 10.0, 10.0, 0.0, "Crypt yard", 1.5)
    plat(30.0, 9.0, 10.0, 8.0, 0.0, "Cloister", 1.5)
    plat(41.0, 7.0, 6.0, 6.0, 0.0, "Cloister steps", 1.5)
    spike_bed(27.0, 9.0, 2.0, 7.6, 0.0, 0.4)
    foe(&"husk", 18.0, 8.0)
    foe(&"crawler", 31.0, 9.0)
    foe(&"crawler", 41.0, 7.0)
    # HIGH: the crypt stairs to the high hall, then the floating ledges down (north).
    route(&"high")
    plat(8.0, -7.0, 4.0, 3.0, 1.4, "Crypt step")
    plat(12.0, -10.0, 4.0, 3.0, 2.8, "Crypt step")
    plat(16.0, -13.0, 4.0, 3.0, 4.2, "Crypt step")
    plat(24.0, -12.0, 10.0, 8.0, 5.6, "High hall", 1.5)
    foe(&"husk", 22.0, -11.0, 5.6)
    foe(&"archer", 27.0, -13.0, 5.6)
    plat(33.0, -9.0, 4.0, 4.0, 4.0, "Ledge", 0.5)
    plat(38.0, -6.0, 4.0, 4.0, 2.4, "Ledge", 0.5)
    # CLIMB: up the ossuary spire, along its beams (middle).
    route(&"climb")
    plat(16.0, 0.0, 6.0, 5.0, 0.0, "Spire foot")
    climb(21.0, 0.0, 3.0, 4.0, -1.0, 6.5, "Ossuary spire")
    plat(27.5, 0.0, 4.0, 3.0, 6.0, "Spire beam", 0.5)
    plat(33.5, 0.0, 4.0, 3.0, 5.0, "Spire beam", 0.5)
    plat(39.0, 0.0, 3.0, 3.0, 3.5, "Spire beam", 0.5)
    shard(21.0, 0.0, 6.5, 5)
    shard(33.5, 0.0, 5.0)
    # Off the paths.
    route(&"side")
    cellar(17.0, 16.0, 0.0, &"relics")
    plat(24.0, -18.5, 4.0, 3.0, 7.0, "Balcony", 0.5)
    shard(24.0, -18.5, 7.0, 5)
    climb(28.0, -17.5, 2.5, 2.5, -2.0, 11.0, "Bell spire")
    shard(28.0, -17.5, 11.0, 5)

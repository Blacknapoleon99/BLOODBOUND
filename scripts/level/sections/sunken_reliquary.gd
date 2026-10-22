extends LevelSection
## Sunken Reliquary (Act 2, difficulty 3): A flooded reliquary with two roads: the LOW road is a straight fight through a sunken hall
## (knight, crawlers); the HIGH road is a hazard run along the rafters. Both reach the exit.

const DIFFICULTY: int = 3


func _init() -> void:
    id = &"sunken_reliquary"
    title = "Sunken Reliquary"
    act = 2
    difficulty = DIFFICULTY
    width = 64.0
    _palette = Color(0.16, 0.19, 0.2)


func _design() -> void:
    ground(0.0, 8.0)
    ground(8.0, 52.0, -2.0, -3.0, "Sunken hall")
    ground(52.0, 56.0, -1.0, -3.0, "Hall steps")
    enemy(&"crawler", 20.0, 9.0, 51.5, -2.0)
    enemy(&"knight", 32.0, 9.0, 51.5, -2.0)
    enemy(&"crawler", 44.0, 9.0, 51.5, -2.0)
    ledge(9.0, 13.0, 1.4, "Rafter")
    ledge(15.0, 19.0, 3.0, "Rafter")
    spikes(17.0, 1.6, 0.4, 3.0)
    ledge(21.5, 25.5, 3.0, "Rafter")
    ledge(28.0, 32.0, 3.0, "Rafter")
    pendulum(30.0, 3.0, 0.6)
    ledge(34.5, 38.5, 3.0, "Rafter")
    ledge(41.0, 45.0, 3.0, "Rafter")
    ledge(47.5, 51.5, 1.6, "Rafter")
    ground(56.0, 64.0)


## 3D course (DEC-052): a flooded reliquary, three roads. LOW (middle): down into the sunken
## hall and fight through (Shielded Knight, crawlers). HIGH (north): the hazard run along the
## rafters (spikes, a blade). CRYPT (south): a rising ferry to the reliquary island and a
## sinking ferry on to the exit. Off the paths: a card cellar off the rafters, and a climb on
## the island to a shard.
func _course() -> void:
    pads()
    route(&"low")
    plat(12.0, 0.0, 4.0, 6.0, -1.0, "Hall steps")
    plat(32.0, 0.0, 34.0, 12.0, -2.0, "Sunken hall", 1.5)
    plat(51.5, 0.0, 5.0, 6.0, -1.0, "Hall steps")
    foe(&"crawler", 22.0, 0.0, -2.0)
    foe(&"knight", 32.0, 2.0, -2.0)
    foe(&"crawler", 42.0, -2.0, -2.0)
    route(&"high")
    plat(11.0, -7.0, 4.0, 3.0, 1.4, "Rafter stair")
    for x: float in [17.0, 23.5, 30.0, 36.5, 43.0, 49.5]:
        plat(x, -9.0, 4.0, 2.5, 3.0, "Rafter", 0.4)
    spike_bed(17.0, -9.0, 1.6, 2.2, 3.0, 0.4)
    blade(30.0, -9.0, 3.0, 0.6, 3.0)
    spike_bed(43.0, -9.0, 1.6, 2.2, 3.0, 1.2)
    plat(54.0, -6.0, 3.0, 3.0, 1.5, "Rafter stair")
    shard(36.5, -9.0, 3.0)
    route(&"crypt")
    plat(10.5, 9.0, 5.0, 4.0, 0.0, "Crypt landing")
    lift(Vector3(16.0, 0.0, 11.0), Vector3(28.0, 4.0, 11.0), 3.0, 3.0, 2.8)
    plat(34.0, 11.0, 6.0, 6.0, 4.0, "Reliquary island", 1.5)
    lift(Vector3(40.0, 4.0, 11.0), Vector3(50.0, 0.0, 9.0), 3.0, 3.0, 2.8)
    plat(54.0, 7.0, 4.0, 4.0, 0.0, "Crypt landing")
    shard(34.0, 11.0, 4.0, 5)
    route(&"side")
    cellar(25.0, -15.0, 3.0, &"card")
    climb(34.0, 15.5, 3.0, 2.0, -1.0, 10.0, "Reliquary spire")
    shard(34.0, 15.5, 10.0, 5)

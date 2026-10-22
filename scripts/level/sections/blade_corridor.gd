extends LevelSection
## Blade Corridor (Act 2, difficulty 3): A corridor of swinging blades and spike strips in rhythm, ending at a Shielded Knight
## who holds the exit.

const DIFFICULTY: int = 3


func _init() -> void:
    id = &"blade_corridor"
    title = "Blade Corridor"
    act = 2
    difficulty = DIFFICULTY
    width = 56.0
    _palette = Color(0.2, 0.18, 0.18)


func _design() -> void:
    ground(0.0, 33.0)
    secret_cellar(33.0, &"shards", 20)
    ground(35.0, 56.0)
    pendulum(12.0, 0.0, 0.0)
    spikes(16.0, 2.0, 0.5)
    pendulum(20.0, 0.0, 1.1)
    spikes(24.5, 2.0, 1.0)
    spikes(29.0, 2.0, 1.6)
    enemy(&"knight", 44.0, 37.0, 52.0)
    enemy(&"crawler", 40.0, 33.0, 52.0)


## 3D course (DEC-052): the blades in rhythm, three ways. CORRIDOR (middle): three pendulums
## and three spike beds in sequence. RAFTERS (north): narrow beams above the blades, one with
## timed spikes. GANTRY (south): climb the outer wall and cross the gantry under its own blade.
## A Shielded Knight holds the exit landing for everyone. Off the paths: a shard cellar beside
## the corridor and a perch beyond the rafters.
func _course() -> void:
    pads(10.0, 12.0)
    foe(&"knight", 50.0, 0.0)
    route(&"corridor")
    plat(25.5, 0.0, 31.0, 6.0, 0.0, "Blade corridor", 1.5)
    blade(16.0, 0.0, 0.0, 0.0, 5.5)
    spike_bed(19.0, 0.0, 2.0, 5.6, 0.0, 0.5)
    blade(22.0, 0.0, 0.0, 1.1, 5.5)
    spike_bed(26.0, 0.0, 2.0, 5.6, 0.0, 1.0)
    blade(30.0, 0.0, 0.0, 0.5, 5.5)
    spike_bed(34.0, 0.0, 2.0, 5.6, 0.0, 1.6)
    foe(&"crawler", 38.0, 0.0)
    route(&"rafters")
    plat(8.0, -7.0, 4.0, 3.0, 1.4, "Rafter stair")
    plat(12.0, -10.0, 4.0, 3.0, 2.8, "Rafter stair")
    for x: float in [18.0, 24.0, 30.0, 36.0]:
        plat(x, -12.0, 4.0, 2.0, 4.2, "Rafter", 0.4)
    spike_bed(24.0, -12.0, 1.6, 1.8, 4.2, 0.4)
    plat(41.5, -7.0, 3.0, 3.0, 2.6, "Rafter stair")
    shard(30.0, -12.0, 4.2)
    route(&"gantry")
    plat(9.0, 9.5, 5.0, 5.0, 0.0, "Outer footing")
    climb(15.5, 13.0, 3.0, 3.0, -2.0, 6.0, "Outer wall")
    plat(25.0, 13.0, 12.0, 2.5, 6.0, "Gantry", 0.5)
    blade(25.0, 13.0, 6.0, 0.7, 3.0)
    plat(35.0, 10.5, 3.0, 3.0, 4.5, "Gantry stair", 0.5)
    plat(39.5, 7.0, 3.0, 3.0, 3.0, "Gantry stair", 0.5)
    shard(25.0, 13.0, 6.0)
    route(&"side")
    cellar(25.0, 6.0, 0.0, &"shards", 20)
    pillar(30.0, -17.0, 2.5, 5.5, "Rafter perch")
    shard(30.0, -17.0, 5.5, 5)

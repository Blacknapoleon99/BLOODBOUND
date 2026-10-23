extends LevelSection
## The Gravewarden's Hall (elite, fixed after Act I): crossing in seals the hall with bone walls
## and wakes the Gravewarden (see Gravewarden). When it falls, the walls drop and a relic
## reliquary rises (pick 1 of 3 relics).
##
## 3D course (DEC-052): the warden's floor floats in the void inside a ring of bone walls wider
## than the floor itself, so every way onto it seals the fight and the only way on to the exit
## crosses it. Three approaches converge on it: the CAUSEWAY (straight in), the north BALCONY
## (stairs up and a drop in) and the south STAIR (broken steps and a crumbling slab). Off the
## paths: a climb to a shard perch and a post to catch off the floor's corner.

const DIFFICULTY: int = 5

var reliquary: LootChest
var hall: Ambush


func _init() -> void:
    id = &"gravewarden_hall"
    title = "The Gravewarden's Hall"
    act = 0
    difficulty = DIFFICULTY
    width = 44.0
    _palette = Color(0.23, 0.19, 0.16)


func _design() -> void:
    ground(0.0, 44.0)
    ledge(10.0, 13.0, 2.0, "Broken balcony")
    ledge(30.0, 33.0, 2.0, "Broken balcony")
    hall = ambush("Elite: The Gravewarden", 8.0, 6.0, 38.0, [{"type": &"gravewarden", "x": 30.0}])
    hall.cleared.connect(_on_cleared)


func _course() -> void:
    pads()
    # The warden's floor and the exit bridge are common to every approach.
    plat(25.0, 0.0, 14.0, 14.0, 0.0, "Warden's floor", 2.0)
    plat(34.0, 0.0, 4.0, 4.0, 0.0, "Exit bridge")
    plat(20.5, -4.0, 3.0, 3.0, 2.0, "Broken balcony", 0.5)
    plat(29.5, 4.0, 3.0, 3.0, 2.0, "Broken balcony", 0.5)
    hall = arena("Elite: The Gravewarden", 25.0, 0.0, 10.5, [{"type": &"gravewarden"}], 0.0, 6.2)
    hall.cleared.connect(_on_cleared)
    route(&"causeway")
    plat(14.0, 0.0, 8.0, 4.0, 0.0, "Causeway")
    route(&"balcony")
    plat(9.0, -8.0, 4.0, 3.0, 1.4, "Balcony stair")
    plat(14.0, -12.0, 4.0, 4.0, 2.8, "North balcony", 0.6)
    plat(18.5, -11.5, 3.0, 3.0, 1.4, "Balcony stair")
    shard(14.0, -12.0, 2.8)
    route(&"stair")
    plat(9.0, 8.0, 4.0, 3.0, 1.0, "Broken stair")
    plat(14.0, 12.0, 4.0, 4.0, 2.0, "Broken stair", 0.6)
    crumble(18.5, 11.0, 2.0)
    route(&"side")
    climb(14.0, -16.0, 3.0, 2.0, -2.0, 6.5, "Warden's buttress")
    shard(14.0, -16.0, 6.5, 5)
    # DEC-061: off the floor's south-east corner, a 2.2 m jump-and-grab at the 5 m/s run (was
    # 3.25 m off the floor's side, out of reach at the slower pace).
    pillar(34.8, 9.8, 2.5, 2.4, "Ossuary post")
    shard(34.8, 9.8, 2.4, 5)


func warden() -> Gravewarden:
    for e: Node3D in hall.enemies:
        if is_instance_valid(e) and e is Gravewarden:
            return e
    return null


func _on_cleared(_a: Ambush) -> void:
    if reliquary != null:
        return
    var at: Vector3 = Vector3(gx(34.0), 0.0, 0.0)
    if hall.ring and hall.three_d:  # 3D: on the warden's floor, toward the exit
        at = Vector3(hall.ring_center.x + 4.0, 0.0, hall.ring_center.y)
    reliquary = LootChest.create(at)
    reliquary.kind = &"relics"
    add_child(reliquary)

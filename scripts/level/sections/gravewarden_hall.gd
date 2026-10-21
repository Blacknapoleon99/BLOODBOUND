extends LevelSection
## The Gravewarden's Hall (elite, fixed after Act I): crossing in seals the hall with bone walls
## and wakes the Gravewarden (see Gravewarden). When it falls, the walls drop and a relic
## reliquary rises (pick 1 of 3 relics).

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


func warden() -> Gravewarden:
    for e: Node3D in hall.enemies:
        if is_instance_valid(e) and e is Gravewarden:
            return e
    return null


func _on_cleared(_a: Ambush) -> void:
    if reliquary != null:
        return
    reliquary = LootChest.create(Vector3(gx(34.0), 0.0, 0.0))
    reliquary.kind = &"relics"
    add_child(reliquary)

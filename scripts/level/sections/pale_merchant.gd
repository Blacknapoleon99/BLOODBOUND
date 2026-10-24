extends LevelSection
## The Pale Merchant (fixed before the Bishop): a quiet chapel with a shop and an altar.

const DIFFICULTY: int = 0


func _init() -> void:
    id = &"pale_merchant"
    title = "The Pale Merchant"
    act = 0
    difficulty = DIFFICULTY
    width = 30.0 if Lane.full_3d else 26.0  # the 3D course has room for its garden and loft
    _palette = Color(0.2, 0.2, 0.17)


var stall: MerchantStall


func _design() -> void:
    ground(0.0, 26.0)
    stall = MerchantStall.create(Vector3(gx(12.0), 0.0, 0.0))
    add_child(stall)
    altar(19.0)


## 3D course (DEC-052): a quiet chapel floating in the void. CHAPEL (middle): the merchant's
## stall and the altar on the chapel floor. GARDEN (south): stepping stones through a bone
## garden. LOFT (north): climb the bell wall to the loft and drop to the exit. Shards in the
## garden and on the bell wall.
func _course() -> void:
    pads(8.0, 8.0)
    route(&"chapel")
    plat(15.0, 0.0, 10.0, 12.0, 0.0, "Chapel floor", 1.5)
    stall = MerchantStall.create(Vector3(gx(14.0), gy(0.0), gz(-2.5)))
    add_child(stall)
    altar(16.0, 0.0, 3.5)
    route(&"garden")
    plat(9.0, 9.0, 4.0, 4.0, 0.8, "Garden stone")
    plat(15.0, 12.0, 6.0, 4.0, 1.6, "Garden stone")
    plat(21.0, 9.0, 4.0, 4.0, 0.8, "Garden stone")
    shard(15.0, 12.0, 1.6)
    route(&"loft")
    plat(9.0, -8.5, 4.0, 3.0, 0.0, "Loft foot")
    climb(14.0, -9.0, 3.0, 3.0, -2.0, 5.0, "Bell wall")
    plat(19.5, -9.0, 5.0, 3.0, 4.0, "Bell loft", 0.6)
    shard(14.0, -9.0, 5.0, 5)

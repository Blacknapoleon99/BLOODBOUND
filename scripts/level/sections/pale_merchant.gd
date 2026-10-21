extends LevelSection
## The Pale Merchant (fixed before the Bishop): a quiet chapel with a shop and an altar.

const DIFFICULTY: int = 0


func _init() -> void:
    id = &"pale_merchant"
    title = "The Pale Merchant"
    act = 0
    difficulty = DIFFICULTY
    width = 26.0
    _palette = Color(0.2, 0.2, 0.17)


var stall: MerchantStall


func _design() -> void:
    ground(0.0, 26.0)
    stall = MerchantStall.create(Vector3(gx(12.0), 0.0, 0.0))
    add_child(stall)
    altar(19.0)

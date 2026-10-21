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


func _design() -> void:
    ground(0.0, 26.0)
    altar(19.0)

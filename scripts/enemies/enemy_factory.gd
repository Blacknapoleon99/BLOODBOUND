class_name EnemyFactory
extends RefCounted
## Builds configured enemies so the Bishop's summons and level ambushes share one definition.

const SOLDIER_SCENE: PackedScene = preload("res://scenes/enemies/plagued_soldier.tscn")


## A Husk: a weak, pale Plagued Soldier (2 HP, poise 1, slower) roaming [roam_min, roam_max].
static func husk(parent: Node, x: float, roam_min: float, roam_max: float) -> PlaguedSoldier:
    var husk_node: PlaguedSoldier = SOLDIER_SCENE.instantiate() as PlaguedSoldier
    husk_node.name = "Husk"
    husk_node.plane_locked = true
    husk_node.patrol_min_x = roam_min
    husk_node.patrol_max_x = roam_max
    husk_node.aggro_range = 9.0
    husk_node.chase_speed = 3.6
    husk_node.attack_cooldown = 1.2
    husk_node.poise_max = 1
    (husk_node.get_node("Health") as Health).max_health = 2
    parent.add_child(husk_node)
    husk_node.global_position = Vector3(x, 1.0, 0.0)
    husk_node.set("_home", husk_node.position)
    (husk_node.get("visual") as Node3D).scale = Vector3(0.85, 0.85, 0.85)
    husk_node.set("_base_color", Color(0.55, 0.52, 0.45))
    husk_node.defeated.connect(func() -> void: husk_node.get_tree().create_timer(1.5).timeout.connect(husk_node.queue_free))
    return husk_node


## A Bone Archer kept between [min_x, max_x] (e.g. an ambush's walls).
static func archer(parent: Node, x: float, min_x: float, max_x: float) -> BoneArcher:
    var archer_node: BoneArcher = BoneArcher.new()
    archer_node.name = "BoneArcher"
    archer_node.min_x = min_x
    archer_node.max_x = max_x
    parent.add_child(archer_node)
    archer_node.global_position = Vector3(x, 1.0, 0.0)
    archer_node.defeated.connect(func() -> void: archer_node.get_tree().create_timer(1.5).timeout.connect(archer_node.queue_free))
    return archer_node

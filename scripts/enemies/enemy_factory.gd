class_name EnemyFactory
extends RefCounted
## Builds configured enemies so the Bishop's summons and level ambushes share one definition.

const SOLDIER_SCENE: PackedScene = preload("res://scenes/enemies/plagued_soldier.tscn")


## A Husk: a weak, pale Plagued Soldier (2 HP, poise 1, slower) roaming [roam_min, roam_max].
static func husk(parent: Node, x: float, roam_min: float, roam_max: float, z: float = 0.0) -> PlaguedSoldier:
    var husk_node: PlaguedSoldier = SOLDIER_SCENE.instantiate() as PlaguedSoldier
    husk_node.name = "Husk"
    husk_node.plane_locked = true
    husk_node.patrol_min_x = roam_min
    husk_node.patrol_max_x = roam_max
    husk_node.aggro_range = 9.0
    husk_node.chase_speed = 3.6
    husk_node.attack_cooldown = 1.2
    husk_node.poise_max = 1
    husk_node.lunge_enabled = false  # Husks swarm; their trick is the death burst
    husk_node.burst_on_death = true
    (husk_node.get_node("Health") as Health).max_health = 2
    _place(husk_node, parent, Vector3(x, 1.0, z))
    parent.add_child(husk_node)
    husk_node.global_position = Vector3(x, 1.0, z)
    husk_node.set("_home", husk_node.position)
    (husk_node.get("visual") as Node3D).scale = Vector3(0.85, 0.85, 0.85)
    husk_node.set("_base_color", Color(0.55, 0.52, 0.45))
    husk_node.defeated.connect(func() -> void: husk_node.get_tree().create_timer(1.5).timeout.connect(husk_node.queue_free))
    return husk_node


## A Bone Archer kept between [min_x, max_x] (e.g. an ambush's walls).
static func archer(parent: Node, x: float, min_x: float, max_x: float, z: float = 0.0) -> BoneArcher:
    var archer_node: BoneArcher = BoneArcher.new()
    archer_node.name = "BoneArcher"
    archer_node.min_x = min_x
    archer_node.max_x = max_x
    _place(archer_node, parent, Vector3(x, 1.0, z))
    parent.add_child(archer_node)
    archer_node.global_position = Vector3(x, 1.0, z)
    archer_node.defeated.connect(func() -> void: archer_node.get_tree().create_timer(1.5).timeout.connect(archer_node.queue_free))
    return archer_node


## A Crypt Hound kept between [min_x, max_x].
static func hound(parent: Node, x: float, min_x: float, max_x: float, z: float = 0.0) -> CryptHound:
    var hound_node: CryptHound = CryptHound.new()
    hound_node.name = "CryptHound"
    hound_node.min_x = min_x
    hound_node.max_x = max_x
    _place(hound_node, parent, Vector3(x, 1.0, z))
    parent.add_child(hound_node)
    hound_node.global_position = Vector3(x, 1.0, z)
    hound_node.defeated.connect(func() -> void: hound_node.get_tree().create_timer(1.5).timeout.connect(hound_node.queue_free))
    return hound_node


## Any enemy type by name, standing at world x with its origin at height `y`, kept in [min_x, max_x].
## Types: husk, archer, hound, knight, wraith, crawler, gravewarden, and the full-3D creatures
## (DEC-064) flayed_stalker, stitched_brute, limb_spider, hollow_mourner, lantern_wight, plus
## limb_spider_pack (a leader returned, with up to two more spiders beside it on solid ground).
## Unknown names fall back to a husk.
## Full 3D (a 3D level sets this): enemies chase on X/Z within a leash instead of a line.
static var full_3d: bool = false


static func spawn(type: StringName, parent: Node, x: float, lo: float, hi: float, y: float = 1.0, z: float = 0.0) -> Node3D:
    var e: Node3D
    match type:
        &"archer":
            e = archer(parent, x, lo, hi, z)  # placed at z from the start: never inside whoever stands at z = 0
        &"hound":
            e = hound(parent, x, lo, hi, z)
        &"knight", &"wraith", &"crawler", &"gravewarden":
            var code: CodeEnemy
            match type:
                &"knight":
                    code = ShieldedKnight.new()
                &"wraith":
                    code = FlyingWraith.new()
                &"gravewarden":
                    code = Gravewarden.new()
                _:
                    code = BoneCrawler.new()
            code.name = String(type).capitalize()
            code.min_x = lo
            code.max_x = hi
            code.plane_locked = not full_3d
            _place(code, parent, Vector3(x, y + (2.2 if type == &"wraith" else 0.5 if type == &"gravewarden" else 0.0), z))
            parent.add_child(code)
            code.global_position = Vector3(x, y + (2.2 if type == &"wraith" else 0.5 if type == &"gravewarden" else 0.0), z)
            code.defeated.connect(func() -> void: code.get_tree().create_timer(1.5).timeout.connect(code.queue_free))
            return code
        &"flayed_stalker", &"stitched_brute", &"limb_spider", &"hollow_mourner", &"lantern_wight", &"limb_spider_pack":
            return creature(type, parent, x, lo, hi, y, z)
        _:
            e = husk(parent, x, lo, hi, z)
    e.global_position = Vector3(x, y, z)
    e.reset_physics_interpolation()
    if full_3d:
        e.set("plane_locked", false)
        if e is PlaguedSoldier:
            (e as PlaguedSoldier).leash_radius = 12.0
    if e is PlaguedSoldier:
        e.set("_home", e.position)
    return e


## One of the full-3D creatures (DEC-064), its feet on the floor below `y` (origin ~1 m up, like
## every code enemy). `limb_spider_pack` adds up to two more spiders beside the returned leader,
## only where a ray finds floor at the same height (never over a ledge).
static func creature(type: StringName, parent: Node, x: float, lo: float, hi: float, y: float = 1.0, z: float = 0.0) -> CreatureEnemy:
    var c: CreatureEnemy
    match type:
        &"flayed_stalker":
            c = FlayedStalker.new()
        &"stitched_brute":
            c = StitchedBrute.new()
        &"hollow_mourner":
            c = HollowMourner.new()
        &"lantern_wight":
            c = LanternWight.new()
        _:
            c = LimbSpider.new()
    c.name = String(type).trim_suffix("_pack").to_pascal_case()
    c.min_x = lo
    c.max_x = hi
    c.plane_locked = not full_3d
    var at: Vector3 = Vector3(x, y + 0.05, z)
    _place(c, parent, at)
    parent.add_child(c)
    c.global_position = at
    c.reset_physics_interpolation()
    c.defeated.connect(func() -> void: c.get_tree().create_timer(1.6).timeout.connect(c.queue_free))
    if type == &"limb_spider_pack":
        var side: Vector3 = Vector3(0.0, 0.0, 1.0) if full_3d else Vector3(1.0, 0.0, 0.0)
        for k: float in [1.0, -1.0]:
            var p: Vector3 = at + side * 1.4 * k + (Vector3(-0.6, 0.0, 0.0) if full_3d else Vector3.ZERO)
            if not full_3d and (p.x < lo or p.x > hi):
                continue
            if not _floor_at(parent, p, y - 1.0):
                continue
            var sib: CreatureEnemy = creature(&"limb_spider", parent, p.x, lo, hi, y, p.z)
            sib.shard_value = 1
            sib.add_to_group(&"spider_brood")
    return c


## True if a ray finds world floor at about `floor_y` under `p`.
static func _floor_at(parent: Node, p: Vector3, floor_y: float) -> bool:
    var n3: Node3D = parent as Node3D
    if n3 == null or not n3.is_inside_tree():
        return false
    var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(p.x, floor_y + 1.2, p.z), Vector3(p.x, floor_y - 0.6, p.z), 1)
    var hit: Dictionary = n3.get_world_3d().direct_space_state.intersect_ray(q)
    return not hit.is_empty() and not (hit["collider"] is CharacterBody3D)


## Puts `node` at world `at` before it enters the tree, so it never exists for a physics step at
## the parent's origin (a body there would be swept along by its jump to `at`).
static func _place(node: Node3D, parent: Node, at: Vector3) -> void:
    var parent_3d: Node3D = parent as Node3D
    node.position = parent_3d.to_local(at) if parent_3d != null and parent_3d.is_inside_tree() else at

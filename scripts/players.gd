class_name Players
extends RefCounted
## Every player in the level (group "player"): one in solo, two in local co-op. Enemies, bosses
## and level triggers ask here instead of assuming a single player.
## "Standing" = alive and not downed (a downed co-op player is ignored by enemies).


static func all() -> Array[Node3D]:
    var list: Array[Node3D] = []
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if tree == null:
        return list
    for node: Node in tree.get_nodes_in_group(&"player"):
        if node is Node3D and node.is_inside_tree():
            list.append(node)
    return list


static func is_standing(player: Node3D) -> bool:
    if player == null or not is_instance_valid(player):
        return false
    var health: Health = player.get("health") as Health
    if health != null and health.is_dead():
        return false
    return not bool(player.get("is_downed"))


static func standing() -> Array[Node3D]:
    return all().filter(func(p: Node3D) -> bool: return is_standing(p))


## The nearest standing player to `from` (null if none). `in_3d` filters by mode (null = any).
static func nearest(from: Vector3, in_3d: Variant = null) -> Node3D:
    var best: Node3D = null
    var best_distance: float = INF
    for p: Node3D in standing():
        if in_3d != null and bool(p.get("in_3d_mode")) != bool(in_3d):
            continue
        var d: float = p.global_position.distance_squared_to(from)
        if d < best_distance:
            best = p
            best_distance = d
    return best


## The player furthest along the level (largest x), for level triggers. Downed players count.
static func leader() -> Node3D:
    var best: Node3D = null
    for p: Node3D in all():
        if best == null or p.global_position.x > best.global_position.x:
            best = p
    return best

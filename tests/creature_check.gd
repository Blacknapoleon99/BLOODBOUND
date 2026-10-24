extends SceneTree
## The five full-3D creatures (DEC-064), headless:
##   godot --headless --path . -s res://tests/creature_check.gd
## Each type spawns through EnemyFactory in full 3D with its modelled rig; roams its platform
## without falling off; engages a real hero and damages it through its own hitboxes; dies to
## damage through its Hurtbox, reaching the death listeners (Bone Shards) with a shard value;
## bleeds the right Gore fluid. The Lantern Wight freezes while the active camera watches it
## and moves when it looks away. The side view (plane-locked) runs each type without errors.
## Exit code 0 when every check passes.

const TYPES: Array[StringName] = [&"flayed_stalker", &"stitched_brute", &"limb_spider", &"hollow_mourner", &"lantern_wight"]
const FLUID: Dictionary = {
    &"flayed_stalker": Gore.Fluid.BLOOD, &"stitched_brute": Gore.Fluid.BLOOD, &"limb_spider": Gore.Fluid.BLOOD,
    &"hollow_mourner": Gore.Fluid.ECTO, &"lantern_wight": Gore.Fluid.WAX,
}

var _passed: int = 0
var _failed: int = 0
var _scene: Node3D
var _player: Node3D


class DeathListener:
    extends Node
    var seen: Array[Node] = []

    func _ready() -> void:
        add_to_group(&"death_listeners")

    func on_combatant_died(body: Node) -> void:
        seen.append(body)


func _initialize() -> void:
    _run.call_deferred()


func _check(ok: bool, what: String) -> void:
    if ok:
        _passed += 1
        print("  ok  ", what)
    else:
        _failed += 1
        print("  FAIL ", what)


func _frames(n: int) -> void:
    for i in n:
        await physics_frame


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
    var body: StaticBody3D = StaticBody3D.new()
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    _scene.add_child(body)
    body.global_position = at
    return body


func _hit(e: Node3D, amount: int) -> void:
    var info: DamageInfo = DamageInfo.new()
    info.amount = amount
    info.knockback = Vector3(2.0, 0.0, 0.0)
    info.hit_position = e.global_position
    info.source = _player
    (e.get("hurtbox") as Hurtbox).receive(info)


func _player_health() -> Health:
    return _player.get("health") as Health


func _run() -> void:
    GameSettings.persistence_enabled = false
    GameSettings.reduced_gore = false
    GameSettings.hitstop_enabled = false
    _scene = Node3D.new()
    _scene.name = "CreatureCheck"
    root.add_child(_scene)
    current_scene = _scene
    var listener: DeathListener = DeathListener.new()
    _scene.add_child(listener)
    # Arena: a 40 m floor (top at y = 0) for the fights, and five 5 m islands over the void.
    _box(Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0))
    for i in TYPES.size():
        _box(Vector3(120.0 + i * 30.0, -0.5, 0.0), Vector3(5.0, 1.0, 5.0))
    _player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Node3D
    _player.add_to_group(&"player")  # as main.gd does
    _scene.add_child(_player)
    _player.set("in_3d_mode", true)
    _player.global_position = Vector3(0.0, 1.0, 0.0)
    _player_health().max_health = 999
    _player_health().restore_full()
    await _frames(10)
    EnemyFactory.full_3d = true

    print("-- spawn, rig, gore fluid")
    for type: StringName in TYPES:
        var e: CreatureEnemy = EnemyFactory.spawn(type, _scene, 120.0 + TYPES.find(type) * 30.0, 0.0, 0.0, 1.0, 0.0) as CreatureEnemy
        _check(e != null and not e.plane_locked and e.rig != null and e.rig.meshes.size() >= 8,
            "%s spawns from the factory in full 3D with its modelled rig (%d parts)" % [type, e.rig.meshes.size() if e and e.rig else 0])
        _check(Gore.fluid_for(e, &"enemy") == FLUID[type], "%s bleeds the right fluid" % type)
        _check(e.shard_value > 0 and e.max_health >= 2, "%s has shards (%d) and health (%d)" % [type, e.shard_value, e.max_health])

    print("-- idle roaming stays on its island")
    var islanders: Array[CreatureEnemy] = []
    for n: Node in _scene.get_children():
        if n is CreatureEnemy:
            islanders.append(n as CreatureEnemy)
    var start: Dictionary = {}
    var travelled: Dictionary = {}
    for e: CreatureEnemy in islanders:
        start[e] = e.global_position
        travelled[e] = 0.0
    var lowest: Dictionary = {}
    for f in 600:
        await physics_frame
        for e: CreatureEnemy in islanders:
            if not is_instance_valid(e):
                continue
            travelled[e] = float(travelled[e]) + Vector2(e.velocity.x, e.velocity.z).length() / 60.0
            lowest[e] = minf(float(lowest.get(e, 99.0)), e.global_position.y)
    for e: CreatureEnemy in islanders:
        var c: Vector3 = start[e]
        var off: Vector3 = e.global_position - c
        var on_island: bool = absf(off.x) < 2.5 and absf(off.z) < 2.5 and float(lowest[e]) > 0.5 and not e.is_dead()
        _check(on_island, "%s idles on its 5 m island (offset %.2f, %.2f, lowest y %.2f)" % [e.name, off.x, off.z, float(lowest[e])])
        _check(float(travelled[e]) > 0.6, "%s roams (%.1f m walked)" % [e.name, float(travelled[e])])
        e.queue_free()
    await _frames(5)

    print("-- engages the hero and hurts it through its hitboxes")
    for type: StringName in TYPES:
        _player.global_position = Vector3(0.0, 1.0, 0.0)
        _player.set("velocity", Vector3.ZERO)
        _player_health().restore_full()
        await _frames(20)
        var e: CreatureEnemy = EnemyFactory.spawn(type, _scene, 6.5, -20.0, 20.0, 1.0, 2.0) as CreatureEnemy
        var before: int = _player_health().current
        var hurt_at: float = -1.0
        var states: Dictionary = {}
        for f in 60 * 14:
            await physics_frame
            states[e.state] = true
            if _player_health().current < before:
                hurt_at = f / 60.0
                break
            if _player.global_position.y < -3.0 or _player.global_position.length() > 15.0:
                _player.global_position = Vector3(0.0, 1.0, 0.0)
                _player.set("velocity", Vector3.ZERO)
        _check(hurt_at >= 0.0, "%s engages and damages the hero (after %.1f s; states %s)" % [type, hurt_at, ", ".join(states.keys().map(func(k: StringName) -> String: return String(k)))])
        # Kill it through its Hurtbox.
        listener.seen.clear()
        var died: Array[bool] = [false]
        e.defeated.connect(func() -> void: died[0] = true)
        for i in 30:
            if e.is_dead():
                break
            _hit(e, 3)
            await _frames(2)
        await _frames(2)
        _check(e.is_dead() and died[0] and listener.seen.has(e), "%s dies to hits through its Hurtbox and reaches the death listeners (shards)" % type)
        _check(not e.hurtbox.monitorable or e.collision_layer == 0, "%s stops colliding/being hit once dead" % type)
        await _frames(110)
        _check(not is_instance_valid(e), "%s's corpse is cleared after its death animation" % type)

    print("-- the Lantern Wight freezes while watched")
    _player.global_position = Vector3(0.0, 1.0, -8.0)
    _player_health().restore_full()
    var w: LanternWight = EnemyFactory.spawn(&"lantern_wight", _scene, 0.0, -20.0, 20.0, 1.0, 4.0) as LanternWight
    var cam: Camera3D = Camera3D.new()
    _scene.add_child(cam)
    cam.global_position = Vector3(0.0, 2.5, -14.0)
    cam.look_at(Vector3(0.0, 1.5, 4.0))
    cam.current = true
    await _frames(30)
    var w0: Vector3 = w.global_position
    var frozen_all: bool = true
    for f in 120:
        await physics_frame
        frozen_all = frozen_all and w.watched
    var moved_watched: float = Vector2(w.global_position.x - w0.x, w.global_position.z - w0.z).length()
    _check(frozen_all and moved_watched < 0.05 and w.freezes >= 1, "watched by the camera it stands still (moved %.3f m, freezes %d)" % [moved_watched, w.freezes])
    cam.look_at(Vector3(0.0, 1.5, -40.0))  # look away
    var w1: Vector3 = w.global_position
    for f in 120:
        await physics_frame
    var moved_free: float = Vector2(w.global_position.x - w1.x, w.global_position.z - w1.z).length()
    _check(not w.watched and moved_free > 1.0, "unwatched it lurches toward the hero (moved %.2f m)" % moved_free)
    var wall: StaticBody3D = _box(Vector3(0.0, 3.0, -12.5), Vector3(14.0, 6.0, 0.4))  # right in front of the lens
    cam.look_at(w.global_position + Vector3.UP * 1.5)
    await _frames(4)
    _check(not w.is_watched(), "a wall between the camera and the wight hides it (it may move)")
    wall.queue_free()
    cam.queue_free()
    w.queue_free()
    await _frames(5)

    print("-- side view (plane-locked) runs every type")
    EnemyFactory.full_3d = false
    _player.set("in_3d_mode", false)
    _player.global_position = Vector3(0.0, 1.0, 0.0)
    _player_health().restore_full()
    var side: Array[CreatureEnemy] = []
    for i in TYPES.size():
        var x: float = -10.0 + i * 5.0
        side.append(EnemyFactory.spawn(TYPES[i], _scene, x, x - 4.0, x + 4.0, 1.0, 0.0) as CreatureEnemy)
    for f in 240:
        await physics_frame
    for e: CreatureEnemy in side:
        if not is_instance_valid(e):
            _check(false, "side-view creature still exists")
            continue
        _check(e.plane_locked and absf(e.global_position.z) < 0.01 and e.global_position.y > -1.0,
            "%s runs plane-locked on the line (z %.3f, x %.2f in [%.1f, %.1f])" % [e.name, e.global_position.z, e.global_position.x, e.min_x, e.max_x])
        e.queue_free()
    await _frames(5)

    print("-- limb_spider_pack spawns a brood on solid ground")
    EnemyFactory.full_3d = true
    var before_pack: int = get_nodes_in_group(&"limb_spider").size()
    var leader: Node3D = EnemyFactory.spawn(&"limb_spider_pack", _scene, 0.0, -20.0, 20.0, 1.0, 10.0)
    await _frames(2)
    var pack: int = get_nodes_in_group(&"limb_spider").size() - before_pack
    _check(leader is LimbSpider and pack == 3, "a pack is the leader plus two (%d)" % pack)
    var edge_pack: Node3D = EnemyFactory.spawn(&"limb_spider_pack", _scene, 120.0, 0.0, 0.0, 1.0, 0.0)
    await _frames(2)
    var island_count: int = 0
    for n: Node in get_nodes_in_group(&"limb_spider"):
        if (n as Node3D).global_position.x > 100.0:
            island_count += 1
    _check(edge_pack != null and island_count == 3, "on a 5 m island the brood still fits there (%d)" % island_count)

    EnemyFactory.full_3d = false
    print("creature_check: %d passed, %d failed" % [_passed, _failed])
    quit(0 if _failed == 0 else 1)

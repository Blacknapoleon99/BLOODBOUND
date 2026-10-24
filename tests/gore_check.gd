extends SceneTree
## Gore presentation checks, headless:
##   godot --headless --path . -s res://tests/gore_check.gd
## A hit spawns a spray (tagged hit_fx, blood red) and droplets that splat on the floor; a kill
## spawns a pool and gibs; the decal cap holds; reduced gore yields ash and no decals, pools or
## gibs; the flat-quad fallback works; Engine.time_scale returns to 1.0 after hitstop.

var _passed: int = 0
var _failed: int = 0
var _scene: Node3D


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


func _real(seconds: float) -> void:
    await create_timer(seconds, true, false, true).timeout


func _box(at: Vector3, size: Vector3) -> void:
    var body: StaticBody3D = StaticBody3D.new()
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    _scene.add_child(body)
    body.global_position = at


func _enemy(type: StringName, x: float) -> Node3D:
    var e: Node3D = EnemyFactory.spawn(type, _scene, x, x - 2.0, x + 2.0, 1.0, 0.0)
    if e.has_method("set_ai_enabled"):
        e.call("set_ai_enabled", false)
    return e


func _hit(enemy: Node3D, amount: int, heavy: bool) -> void:
    var info: DamageInfo = DamageInfo.new()
    info.amount = amount
    info.category = &"heavy" if heavy else &"melee"
    info.knockback = Vector3(5.0, 0.0, 0.0)
    info.hit_position = enemy.global_position + Vector3(0.0, 0.3, 0.0)
    (enemy.get("hurtbox") as Hurtbox).receive(info)


func _count(group: StringName) -> int:
    return get_nodes_in_group(group).size()


func _clear_gore() -> void:
    for g: StringName in [&"gore_decal", &"gore_pool", &"gore_gibs"]:
        for n: Node in get_nodes_in_group(g):
            n.free()


func _run() -> void:
    GameSettings.persistence_enabled = false
    GameSettings.reduced_gore = false
    GameSettings.hitstop_enabled = true
    _scene = Node3D.new()
    _scene.name = "GoreCheck"
    root.add_child(_scene)
    current_scene = _scene
    _box(Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0))
    _box(Vector3(6.0, 2.0, 0.0), Vector3(0.5, 4.0, 10.0))
    await _frames(2)

    # --- a hit ---
    var husk: Node3D = _enemy(&"husk", 0.0)
    await _frames(3)
    _hit(husk, 1, false)
    var fx: Array[Node] = get_nodes_in_group(&"hit_fx")
    _check(not fx.is_empty(), "a hit spawns a spray tagged hit_fx")
    var c: Color = fx[fx.size() - 1].get_meta(&"spray_color") if not fx.is_empty() else Color.BLACK
    _check(c.r > 0.4 and c.g < 0.1, "the spray is blood red (%s)" % c)
    var drops: BloodDroplets = get_first_node_in_group(&"gore_droplets") as BloodDroplets
    _check(drops != null and drops.active_count() > 10, "the hit launches droplets (%d)" % (drops.active_count() if drops else 0))
    _check(Engine.time_scale < 1.0, "hitstop slows time on a hit (%.2f)" % Engine.time_scale)
    await _real(0.2)
    _check(is_equal_approx(Engine.time_scale, 1.0), "time_scale returns to 1.0 after hitstop")
    await _frames(120)
    _check(_count(&"gore_decal") > 0, "landed droplets leave splats (%d)" % _count(&"gore_decal"))
    _check(drops.active_count() == 0, "every droplet has landed or expired (%d)" % drops.active_count())

    # --- a kill ---
    var splats_before: int = _count(&"gore_decal")
    _hit(husk, 5, true)
    _check((husk.get("health") as Health).is_dead(), "the heavy hit kills the husk")
    await _real(0.2)
    _check(is_equal_approx(Engine.time_scale, 1.0), "time_scale returns to 1.0 after the kill hitstop")
    var pools: Array[Node] = get_nodes_in_group(&"gore_pool")
    _check(pools.size() == 1, "a kill spreads one pool under the body (%d)" % pools.size())
    _check(Gore.live_gibs() > 0, "a kill throws gibs (%d)" % Gore.live_gibs())
    var start_size: float = _pool_width(pools[0] as Node3D) if not pools.is_empty() else 0.0
    await _frames(120)
    var end_size: float = _pool_width(pools[0] as Node3D) if not pools.is_empty() and is_instance_valid(pools[0]) else 0.0
    _check(end_size > start_size * 2.0, "the pool grows (%.2f -> %.2f m)" % [start_size, end_size])
    _check(_count(&"gore_decal") > splats_before + 1, "the burst and gibs leave more splats (%d -> %d)" % [splats_before, _count(&"gore_decal")])

    # --- archetypes ---
    var archer: Node3D = _enemy(&"archer", -4.0)
    await _frames(3)
    _hit(archer, 9, true)
    await _frames(2)
    var shards: int = 0
    for g: Node in get_nodes_in_group(&"gore_gibs"):
        shards += 1 if (g as MeshInstance3D).mesh is CylinderMesh else 0
    _check(shards >= 6, "a Bone Archer sheds bone shards (%d)" % shards)
    _check(Gore.fluid_for(archer) == Gore.Fluid.ICHOR, "bone things bleed ichor")

    # --- cap ---
    for i in 300:
        Gore.splat(_scene, Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0)), Vector3.UP, 0.4, Gore.BLOOD_TINT)
    _check(Gore.live_decals() <= Gore.MAX_DECALS and _count(&"gore_decal") <= Gore.MAX_DECALS, "decal cap holds (%d live, %d in group)" % [Gore.live_decals(), _count(&"gore_decal")])
    await _frames(60)
    var all_splats: int = _scene.find_children("BloodSplat*", "", false, false).size() + _scene.find_children("BloodPool*", "", false, false).size()
    _check(all_splats <= Gore.MAX_DECALS, "evicted splats are freed after fading (%d nodes)" % all_splats)

    # --- fallback ---
    Gore.force_fallback = true
    var quad: Node3D = Gore.splat(_scene, Vector3.ZERO, Vector3.UP, 0.5, Gore.BLOOD_TINT)
    _check(quad is MeshInstance3D, "Compatibility fallback lays a flat quad")
    Gore.force_fallback = false

    # --- reduced gore ---
    await _frames(30)
    _clear_gore()
    GameSettings.reduced_gore = true
    var husk2: Node3D = _enemy(&"husk", 2.0)
    await _frames(3)
    _hit(husk2, 1, false)
    fx = get_nodes_in_group(&"hit_fx")
    c = fx[fx.size() - 1].get_meta(&"spray_color")
    _check(c.r < 0.3 and absf(c.r - c.b) < 0.1, "reduced gore sprays ash (%s)" % c)
    _hit(husk2, 5, true)
    await _frames(150)
    _check(_count(&"gore_decal") == 0 and _count(&"gore_pool") == 0, "reduced gore leaves no blood decals or pools (%d)" % _count(&"gore_decal"))
    _check(Gore.live_gibs() == 0, "reduced gore throws no gibs (%d)" % Gore.live_gibs())
    GameSettings.reduced_gore = false
    await _real(0.15)
    _check(is_equal_approx(Engine.time_scale, 1.0), "time_scale is 1.0 at the end")

    print("gore_check: %d passed, %d failed" % [_passed, _failed])
    quit(0 if _failed == 0 else 1)


func _pool_width(n: Node3D) -> float:
    if n is Decal:
        return (n as Decal).size.x
    return n.global_transform.basis.x.length()

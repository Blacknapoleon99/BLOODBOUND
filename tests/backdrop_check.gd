extends SceneTree
## Background world checks (DEC-055), headless:
##   godot --headless --path . -s res://tests/backdrop_check.gd
## Every open course of a 3D run (and the opening) gets a backdrop, the scene gets exactly one
## horizon, the decor has no collision and casts no shadow, and no backdrop geometry enters a
## course's play volume (x span, z span + 6 m, y from 3 m below to 25 m above its pads).
## DEC-063 (the open world): one near-only backdrop per room and the hub, plus one for the whole
## world; the play volumes sit at each room's height, and the bridges have theirs too.

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
    _run.call_deferred()


func _check(ok: bool, what: String) -> void:
    if ok:
        _passed += 1
        print("  ok  ", what)
    else:
        _failed += 1
        print("  FAIL ", what)


func _run() -> void:
    GameSettings.persistence_enabled = false
    LevelLayout.classic = false
    RunState.full_3d = true
    RunState.new_run(77)
    var t0: int = Time.get_ticks_msec()
    change_scene_to_file("res://scenes/main.tscn")
    for i in 5:
        await process_frame
    var main: Node = current_scene
    var sections: Array = main.get("sections")
    print("main built in %d ms" % (Time.get_ticks_msec() - t0))
    var rooms: Array[Node] = main.find_children("Backdrop", "Backdrop3D", true, false)
    var world: OpenWorld = main.get("world")
    _check(world != null and rooms.size() == sections.size() + 2, "one backdrop per course plus the hub and the whole world (%d for %d rooms)" % [rooms.size(), sections.size()])
    _check(get_nodes_in_group(&"backdrop_horizon").size() == 1, "exactly one horizon")
    var bodies: int = 0
    var shadowed: int = 0
    var draws: int = 0
    var decor: Array[Node] = []
    decor.append_array(rooms)
    decor.append_array(get_nodes_in_group(&"backdrop_horizon"))
    for root: Node in decor:
        for n: Node in root.find_children("*", "", true, false):
            if n is CollisionObject3D or n is CollisionShape3D:
                bodies += 1
            if n is GeometryInstance3D:
                draws += 1
                if (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
                    shadowed += 1
    _check(bodies == 0, "backdrop has no collision (%d bodies)" % bodies)
    _check(shadowed == 0, "backdrop casts no shadows (%d casters)" % shadowed)
    print("backdrop geometry instances: %d (%d per room on average)" % [draws, draws / maxi(rooms.size(), 1)])
    # Nothing in any course's play volume.
    var intrusions: Array[String] = []
    for room: LevelSection in sections:
        var zmin: float = INF
        var zmax: float = -INF
        for zr: Vector2 in room.platform_z:
            zmin = minf(zmin, zr.x)
            zmax = maxf(zmax, zr.y)
        var play: AABB = AABB(Vector3(room.origin_x, room.origin_y - 3.0, zmin - 6.0), Vector3(room.width, 28.0, zmax - zmin + 12.0))
        intrusions.append_array(_intrusions(rooms, play, String(room.id)))
    # The bridges of the wilds: 3 m round each piece, from 3 m under it to 6 m over it.
    var bridge_hits: Array[String] = []
    for i in world.wilds.platforms.size():
        var r: Rect2 = world.wilds.platforms[i]
        var z: Vector2 = world.wilds.platform_z[i]
        var vol: AABB = AABB(Vector3(r.position.x - 3.0, r.position.y - 3.0, z.x - 3.0), Vector3(r.size.x + 6.0, 9.0, z.y - z.x + 6.0))
        bridge_hits.append_array(_intrusions(rooms, vol, "bridge %d" % i))
    _check(intrusions.is_empty(), "no backdrop geometry inside any course's play volume %s" % [intrusions])
    _check(bridge_hits.is_empty(), "no backdrop geometry on or over any bridge of the wilds %s" % [bridge_hits.slice(0, 6)])
    print("backdrop_check: %d passed, %d failed" % [_passed, _failed])
    RunState.full_3d = false
    RunState.end_run()
    quit(1 if _failed > 0 else 0)


## Backdrop meshes with a vertex inside `play`, as "parent/mesh in what".
func _intrusions(rooms: Array[Node], play: AABB, what: String) -> Array[String]:
    var intrusions: Array[String] = []
    for b: Node in rooms:
        for n: Node in b.find_children("*", "MeshInstance3D", true, false):
            var mi: MeshInstance3D = n as MeshInstance3D
            if mi.mesh == null:
                continue
            var box: AABB = mi.global_transform * mi.mesh.get_aabb()
            # Merged meshes are big; test their vertices, not their bounds.
            if not box.intersects(play):
                continue
            var arrays: Array = mi.mesh.surface_get_arrays(0)
            var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var xf: Transform3D = mi.global_transform
            for v: Vector3 in verts:
                if play.has_point(xf * v):
                    intrusions.append("%s/%s in %s" % [b.get_parent().name, mi.name, what])
                    break
    return intrusions

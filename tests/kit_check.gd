extends SceneTree
## Headless checks for the modelled gothic kit (DEC-056):
##   godot --headless --path . -s res://tests/kit_check.gd
## - the kit GLB loads with every piece GothicKit uses;
## - every room (3D course and side view) and the opening grounds draw their blocks with kit
##   MultiMeshes, and no level body is left with a plain BoxMesh look;
## - every kit piece stays within its collision box (footing contract: nothing above the walkable
##   top, lips/buttresses at most GothicKit.SIDE_TOLERANCE past the sides);
## - collision is untouched: every level body still has exactly one BoxShape3D;
## - climb walls carry handholds, movers/slabs/secret floors/causeway slabs use kit meshes.

const PIECES: Array[String] = ["top_a", "top_b", "top_c", "edge", "edge_b", "corner", "ashlar_a", "ashlar_b",
    "ashlar_c", "arcade", "quoin", "buttress", "base", "pillar_capital", "pillar_shaft", "pillar_band",
    "pillar_broken", "handhold", "grate", "cracked", "portcullis"]

var _pass: int = 0
var _fail: int = 0


func _check(ok: bool, what: String) -> void:
    if ok:
        _pass += 1
    else:
        _fail += 1
        print("FAIL: ", what)


func _initialize() -> void:
    _run.call_deferred()


func _rooms() -> Array[Script]:
    var all_rooms: Array[Script] = []
    all_rooms.append_array(LevelLayout.ACT1)
    all_rooms.append_array(LevelLayout.ACT2)
    all_rooms.append(LevelLayout.ELITE)
    all_rooms.append(LevelLayout.MERCHANT)
    return all_rooms


func _box_bodies(room: Node) -> Array[StaticBody3D]:
    var out: Array[StaticBody3D] = []
    for child: Node in room.get_children():
        if child is StaticBody3D and not (child is CollapsingSlab) and not (child is BreakableFloor) \
                and child.get_child_count() > 0 and child.get_child(0) is CollisionShape3D:
            out.append(child as StaticBody3D)
    return out


func _check_room(room: LevelSection, mode: String) -> void:
    var kit_node: Node = room.get_node_or_null("Gothic architecture")
    _check(kit_node != null and kit_node.get_child_count() > 0, "%s (%s) has kit MultiMeshes" % [room.id, mode])
    _check(room.kit != null and room.kit.violations.is_empty(), "%s (%s) kit stays inside collision: %s" % [room.id, mode, [] if room.kit == null else Array(room.kit.violations).slice(0, 3)])
    var plain: int = 0
    var shapes_ok: bool = true
    for body: StaticBody3D in _box_bodies(room):
        var boxes: int = 0
        for c: Node in body.get_children():
            if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
                boxes += 1
            if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
                plain += 1
        if boxes != 1:
            shapes_ok = false
    _check(plain == 0, "%s (%s): no level body keeps a plain BoxMesh (%d)" % [room.id, mode, plain])
    _check(shapes_ok, "%s (%s): every level body keeps exactly one BoxShape3D" % [room.id, mode])
    for wall: ClimbWall in room.climb_walls:
        _check(wall.get_child_count() == 1, "%s: climb wall %s is drawn by the room batch (collision only)" % [room.id, wall.name])
    if not room.climb_walls.is_empty():
        var holds: int = 0
        for n: Node in kit_node.get_children():
            if String(n.name).begins_with("handhold"):
                holds += (n as MultiMeshInstance3D).multimesh.instance_count
        _check(holds > 0, "%s: climb walls carry carved handholds (%d)" % [room.id, holds])


func _run() -> void:
    _check(GothicKit.available(), "the kit GLB is imported and loads")
    for p: String in PIECES:
        _check(GothicKit.mesh(p) != null, "kit piece %s exists" % p)
    var holder: Node3D = Node3D.new()
    root.add_child(holder)
    var x: float = 1000.0
    for mode: String in ["3d", "side"]:
        Lane.full_3d = mode == "3d"
        EnemyFactory.full_3d = Lane.full_3d
        for script: Script in _rooms():
            var room: LevelSection = script.new() as LevelSection
            holder.add_child(room)
            room.build(x)
            x += room.width
            _check_room(room, mode)
    Lane.full_3d = true
    var grounds: OpeningGrounds = OpeningGrounds.new()
    holder.add_child(grounds)
    grounds.build_grounds()
    _check_room(grounds, "opening")
    # Dynamic pieces.
    var mover: MovingPlatform = MovingPlatform.create("m", Vector3.ZERO, Vector3.ONE, Vector3(3.0, 0.6, 3.0))
    _check(mover.get_child(1) is MeshInstance3D and (mover.get_child(1) as MeshInstance3D).mesh == GothicKit.mesh("grate"), "moving platforms are iron grates")
    var orbit: OrbitingPlatform = OrbitingPlatform.create("o", Vector3.ZERO, 4.0, 8.0, 0.0, Vector3(3.0, 0.6, 3.0))
    _check((orbit.get_child(1) as MeshInstance3D).mesh == GothicKit.mesh("grate"), "orbiting platforms are iron grates")
    var slab: CollapsingSlab = CollapsingSlab.create("s", Vector3.ZERO, Vector3(2.6, 1.0, 2.6))
    holder.add_child(slab)
    _check(slab._mesh.mesh == GothicKit.mesh("cracked") and slab._material != GothicKit.material(&"cracked", Color(0, 0, 0, 0), true, 0.5), "collapsing slabs are shattered stone with their own (flashing) material")
    var crack: BreakableFloor = BreakableFloor.create(Vector3.ZERO, Vector3(2.0, 1.0, 2.0))
    _check(crack.get_child(1) is MeshInstance3D and (crack.get_child(1) as MeshInstance3D).mesh == GothicKit.mesh("cracked"), "secret floors are shattered stone")
    var seg: BreakableSegment = BreakableSegment.create("c", Vector3(0, -0.5, 0), Vector3(4.0, 1.0, 4.0), Color(0.2, 0.2, 0.2), true)
    _check(seg.get_node_or_null("Slab/Kit") != null, "Bishop causeway slabs are modelled flagstone")
    var climb: ClimbWall = ClimbWall.create("c", Vector3.ZERO, Vector3(4.0, 6.0, 3.0))
    _check(climb.get_node_or_null("Kit") != null, "a standalone climb wall draws its own kit")
    for n: Node in [mover, orbit, crack, seg, climb]:
        n.free()
    Lane.full_3d = false
    EnemyFactory.full_3d = false
    print("kit_check: %d passed, %d failed" % [_pass, _fail])
    quit(1 if _fail > 0 else 0)

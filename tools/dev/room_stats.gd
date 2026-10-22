extends SceneTree
## Dev tool: builds every room as a 3D course and prints the validator's view of it.


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    Lane.full_3d = true
    EnemyFactory.full_3d = true
    var holder: Node3D = Node3D.new()
    root.add_child(holder)
    var all_rooms: Array[Script] = []
    all_rooms.append_array(LevelLayout.ACT1)
    all_rooms.append_array(LevelLayout.ACT2)
    all_rooms.append(LevelLayout.ELITE)
    all_rooms.append(LevelLayout.MERCHANT)
    var x: float = 1000.0
    for script: Script in all_rooms:
        var room: LevelSection = script.new() as LevelSection
        holder.add_child(room)
        room.build(x)
        x += room.width
        var fp: Rect2 = room.footprint()
        print("%-24s w%.0f basic=%s routes=%s working=%s basicR=%s corridor=%s unreach=%s fp=x%.1f..%.1f z%.1f..%.1f h=%s plats=%d" % [
            room.id, room.width, room.is_completable(), room.routes, room.working_routes(), room.basic_routes(),
            room.is_corridor(), room.unreachable_rewards(), fp.position.x, fp.end.x, fp.position.y, fp.end.y,
            room.height_range(), room.platforms.size()])
    var grounds: OpeningGrounds = OpeningGrounds.new()
    holder.add_child(grounds)
    grounds.build_grounds()
    print("opening grounds: unreach=%s pickups=%d caches=%d" % [grounds.unreachable_rewards(), grounds.pickups.size(), grounds.caches.size()])
    Lane.full_3d = false
    EnemyFactory.full_3d = false
    quit()

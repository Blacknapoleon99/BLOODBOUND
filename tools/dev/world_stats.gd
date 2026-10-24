extends SceneTree
## Dev tool (DEC-063): builds the 3D run's open world for a few seeds and prints its layout,
## links and the world validator's verdict.
##   godot --headless --path . -s res://tools/dev/world_stats.gd -- --seeds=77,1,2,3


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    var seeds: Array[int] = [77, 1, 2, 3]
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--seeds="):
            seeds.clear()
            for part: String in arg.trim_prefix("--seeds=").split(","):
                seeds.append(int(part))
    LevelLayout.classic = false
    RunState.full_3d = true
    for s: int in seeds:
        RunState.new_run(s)
        var t0: int = Time.get_ticks_msec()
        change_scene_to_file("res://scenes/main.tscn")
        for i in 4:
            await process_frame
        var main: Node = current_scene
        var world: OpenWorld = main.get("world")
        print("=== seed %d: built in %d ms" % [s, Time.get_ticks_msec() - t0])
        for room: LevelSection in world.rooms:
            var r: Rect2 = room.world_rect()
            print("  %-22s x %6.1f..%6.1f  z %6.1f..%6.1f  y %4.1f" % [room.id, r.position.x, r.end.x, r.position.y, r.end.y, room.origin_y])
        var kinds: Dictionary = {}
        for l: Dictionary in world.links:
            kinds[l["kind"]] = int(kinds.get(l["kind"], 0)) + 1
            print("  link %2d-%2d %-6s %-9s %5.1f m  %d pieces%s" % [l["a"], l["b"], l["kind"], l["style"], l["length"], (l["pieces"] as Array).size(), "  (gated)" if l["gated"] else ""])
        var t1: int = Time.get_ticks_msec()
        var nodes: Array[Dictionary] = world.world_nodes()
        var adj: Array[PackedInt32Array] = world.adjacency(nodes, false, true)
        var start: int = OpenWorld.node_of(nodes, world.hub, world.hub.entry_platform())
        var there: Dictionary = OpenWorld.reach(adj, start)
        var back: Dictionary = OpenWorld.reach(adj, start, true)
        var missing: Array[String] = []
        var stranded: Array[String] = []
        for room: LevelSection in world.rooms:
            var n: int = OpenWorld.node_of(nodes, room, room.entry_platform())
            if not there.has(n):
                missing.append(String(room.id))
            if not back.has(n):
                stranded.append(String(room.id))
        var fore: bool = there.has(OpenWorld.node_of(nodes, world.wilds, world.forecourt))
        var deg: Array[int] = []
        for k in world.rooms.size():
            deg.append(world._degree(k + 1))
        print("  links %d %s, loops %d, degrees %s, wild foes %d, bounds %s" % [world.links.size(), kinds, world.loop_count(), deg, world.wild_foes.size(), world.bounds])
        print("  basic: unreachable %s, stranded %s, forecourt %s (graph %d nodes, %d ms)" % [missing, stranded, fore, nodes.size(), Time.get_ticks_msec() - t1])
    RunState.full_3d = false
    RunState.end_run()
    quit()

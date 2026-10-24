extends SceneTree
## Dev capture (needs a display; xvfb works): the five full-3D creatures (DEC-064) in the 3D run.
##   godot --path . -s res://tools/dev/shot_creatures.gd -- <outdir> [type ...] [--no-play] [--studio]
## --studio: a small lit floor with the run's GothicEnvironment and a hero, instead of the whole
## 3D run (far quicker under software rendering; for iterating on the looks).
## Per creature, with a close dev camera: an idle frame sequence, a walk sequence while it
## engages the hero, its attack telegraph and its death. Then all of them together through
## the gameplay camera (unless --no-play). Writes creature_<type>_<shot>.png.

const TYPES: Array[StringName] = [&"flayed_stalker", &"stitched_brute", &"limb_spider", &"hollow_mourner", &"lantern_wight"]
const WINDUP: Dictionary = {
    &"flayed_stalker": [&"rise", 0.4], &"stitched_brute": [&"slam_windup", 0.85], &"limb_spider": [&"leap_windup", 0.4],
    &"hollow_mourner": [&"wail_windup", 1.0], &"lantern_wight": [&"swing_windup", 0.42],
}
const FRAME: Dictionary = {
    &"flayed_stalker": [3.4, 1.4, 0.9], &"stitched_brute": [4.6, 1.9, 1.3], &"limb_spider": [3.0, 1.3, 0.5],
    &"hollow_mourner": [3.6, 1.6, 1.2], &"lantern_wight": [5.4, 2.2, 1.7],
}

var _out: String = "user://"
var _player: Node3D
var _cam: Camera3D


func _initialize() -> void:
    _run.call_deferred()


func _wait(seconds: float) -> void:
    for i in int(seconds * 60.0):
        await physics_frame


func _shot(name: String) -> void:
    await RenderingServer.frame_post_draw
    root.get_viewport().get_texture().get_image().save_png(_out.path_join("creature_%s.png" % name))
    var c: Camera3D = root.get_viewport().get_camera_3d()
    print("shot %s  t=%.1fs cam=%s at %s" % [name, Time.get_ticks_msec() / 1000.0, c.name if c else "-", c.global_position if c else Vector3.ZERO])


func _frame(e: Node3D, type: StringName, side: float = 0.0) -> void:
    var f: Array = FRAME[type]
    var fwd: Vector3 = (e.get("heading") as Vector3)
    var right: Vector3 = fwd.cross(Vector3.UP)
    var look: Vector3 = e.global_position + Vector3(0.0, float(f[2]) - 1.0, 0.0)
    var dir: Vector3 = (fwd * cos(0.6 + side) + right * sin(0.6 + side)).normalized()
    _cam.global_position = look + dir * float(f[0]) + Vector3.UP * (float(f[1]) - float(f[2]))
    _cam.look_at(look)


func _hit(e: Node3D, amount: int) -> void:
    var info: DamageInfo = DamageInfo.new()
    info.amount = amount
    info.category = &"heavy"
    var push: Vector3 = e.global_position - _player.global_position
    push.y = 0.0
    info.knockback = push.normalized() * 4.0
    info.hit_position = e.global_position + Vector3(0.0, 0.2, 0.0)
    info.source = _player
    (e.get("hurtbox") as Hurtbox).receive(info)


## A 30 m stone floor under the run's gothic sky, fog and lights, a hero and a game camera.
func _studio() -> void:
    var scene: Node3D = Node3D.new()
    scene.name = "CreatureStudio"
    root.add_child(scene)
    current_scene = scene
    scene.add_child(GothicEnvironment.create())
    var floor_body: StaticBody3D = StaticBody3D.new()
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(30.0, 1.0, 30.0)
    shape.shape = box
    floor_body.add_child(shape)
    var mi: MeshInstance3D = MeshInstance3D.new()
    var bm: BoxMesh = BoxMesh.new()
    bm.size = box.size
    mi.mesh = bm
    mi.material_override = GothicMaterials.standard("flagstone", Color(0.7, 0.66, 0.66), 2.0)
    floor_body.add_child(mi)
    scene.add_child(floor_body)
    floor_body.position = Vector3(0.0, -0.5, 0.0)
    scene.add_child(GothicEnvironment.torch_light(Vector3(-2.0, 2.6, -3.0), 2.4, 9.0))
    EnemyFactory.full_3d = true
    _player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Node3D
    scene.add_child(_player)
    _player.global_position = Vector3(-6.0, 1.0, 0.0)
    _player.set("in_3d_mode", true)
    var cam: Camera3D = Camera3D.new()
    scene.add_child(cam)
    cam.global_position = Vector3(-10.5, 3.2, 0.0)
    cam.look_at(Vector3(0.0, 1.0, 0.0))
    cam.current = true
    await _wait(0.5)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var types: Array[StringName] = []
    var play: bool = true
    var studio: bool = false
    for i in args.size():
        if i == 0:
            _out = args[0]
        elif args[i] == "--no-play":
            play = false
        elif args[i] == "--studio":
            studio = true
        else:
            types.append(StringName(args[i]))
    if types.is_empty():
        types = TYPES
    DirAccess.make_dir_recursive_absolute(_out)
    GameSettings.persistence_enabled = false
    if studio:
        await _studio()
    else:
        LevelLayout.classic = false
        RunState.full_3d = true
        RunState.new_run(77)
        change_scene_to_file("res://scenes/main.tscn")
        await _wait(1.5)
        _player = current_scene.get("player") as Node3D
    var ph: Health = _player.get("health") as Health
    ph.max_health = 999
    ph.restore_full()
    var game_cam: Camera3D = root.get_viewport().get_camera_3d()
    var fwd: Vector3 = -game_cam.global_basis.z
    fwd.y = 0.0
    fwd = fwd.normalized()
    var floor_y: float = _player.global_position.y - 0.9
    print("player=%s floor~%.2f fwd=%s" % [_player.global_position, floor_y, fwd])
    _cam = Camera3D.new()
    _cam.fov = 42.0
    current_scene.add_child(_cam)
    for type: StringName in types:
        _cam.current = true
        var at: Vector3 = _player.global_position + fwd * 5.0
        var e: CreatureEnemy = EnemyFactory.spawn(type, current_scene, at.x, at.x - 8.0, at.x + 8.0, _player.global_position.y + 0.1, at.z) as CreatureEnemy
        e.set_ai_enabled(false)
        if e is LanternWight:
            (e as LanternWight).freeze_when_seen = false  # so the close camera can film it moving
        e.face(-fwd)
        await _wait(0.8)
        for i in 4:
            _frame(e, type)
            await _shot("%s_idle%d" % [type, i])
            await _wait(0.2)
        # Walk: let it engage the hero for a moment (the camera follows from the side).
        e.set_ai_enabled(true)
        for i in 6:
            await _wait(0.15)
            _frame(e, type, 0.9)
            await _shot("%s_walk%d" % [type, i])
        e.set_ai_enabled(false)
        await _wait(0.3)
        var w: Array = WINDUP[type]
        e.face(_player.global_position - e.global_position)
        await _wait(0.2)
        e.set_state(w[0])
        await _wait(float(w[1]) * 0.5)
        _frame(e, type, -0.3)
        await _shot("%s_tele0" % type)
        await _wait(float(w[1]) * 0.5)
        _frame(e, type, -0.3)
        await _shot("%s_tele1" % type)
        await _wait(0.12)
        _frame(e, type, -0.3)
        await _shot("%s_strike" % type)
        await _wait(1.2)
        _frame(e, type, 0.2)
        _hit(e, 99)
        await _wait(0.12)
        await _shot("%s_death0" % type)
        await _wait(0.45)
        await _shot("%s_death1" % type)
        await _wait(0.6)
        await _shot("%s_death2" % type)
        print("%s ok state=%s" % [type, e.state if is_instance_valid(e) else &"freed"])
        await _wait(0.6)
    if play:
        game_cam.current = true
        var spawned: Array[Node3D] = []
        for i in types.size():
            var side: Vector3 = fwd.cross(Vector3.UP)
            var at2: Vector3 = _player.global_position + fwd * (6.0 + 1.5 * (i % 2)) + side * (float(i) - (types.size() - 1) * 0.5) * 2.2
            var e2: Node3D = EnemyFactory.spawn(types[i], current_scene, at2.x, at2.x - 8.0, at2.x + 8.0, _player.global_position.y + 0.1, at2.z)
            (e2 as CodeEnemy).face(-fwd)
            spawned.append(e2)
        await _wait(0.3)
        await _shot("play0")
        await _wait(1.0)
        await _shot("play1")
        await _wait(1.0)
        await _shot("play2")
    RunState.full_3d = false
    RunState.end_run()
    quit()

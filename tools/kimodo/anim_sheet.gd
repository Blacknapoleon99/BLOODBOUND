extends SceneTree
## Contact sheets of hero clips, rendered by Godot (windowed: it needs a renderer) (DEC-059).
##   godot --path . -s res://tools/kimodo/anim_sheet.gd -- <out.png> <clip,clip,...> [frames] [library.res] [yaw_deg] [sword]
## One row per clip, `frames` evenly spaced frames from the first to the last. The hero GLB is
## shown at game scale (1.8 m) with the sword in the right hand when "sword" is passed, lit like
## a studio turntable. Clips come from the GLB and, if given, an extra AnimationLibrary.

const HERO: String = "res://assets/models/player/bone_revenant.glb"
const SWORD: String = "res://assets/models/player/revenant_sword.glb"
const CELL: int = 300


func _init() -> void:
    _run.call_deferred()


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var out: String = args[0]
    var clips: PackedStringArray = args[1].split(",")
    var frames: int = int(args[2]) if args.size() > 2 else 8
    var lib_path: String = args[3] if args.size() > 3 else ""
    var yaw: float = deg_to_rad(float(args[4])) if args.size() > 4 else deg_to_rad(-50.0)
    var with_sword: bool = args.size() > 5 and args[5] == "sword"
    var vp: SubViewport = SubViewport.new()
    vp.size = Vector2i(CELL, CELL)
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    vp.own_world_3d = true
    root.add_child(vp)
    var world: Node3D = Node3D.new()
    vp.add_child(world)
    var env: WorldEnvironment = WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color(0.22, 0.22, 0.25)
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
    env.environment.ambient_light_energy = 0.9
    world.add_child(env)
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
    sun.light_energy = 1.6
    world.add_child(sun)
    var hero: Node3D = (load(HERO) as PackedScene).instantiate() as Node3D
    hero.scale = Vector3.ONE * 1.8
    hero.rotation.y = yaw
    world.add_child(hero)
    var player: AnimationPlayer = hero.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
    if lib_path != "" and lib_path != "-":
        var lib: AnimationLibrary = load(lib_path) as AnimationLibrary
        var own: AnimationLibrary = player.get_animation_library(&"")
        for n: StringName in lib.get_animation_list():
            if not own.has_animation(n):
                own.add_animation(n, lib.get_animation(n))
    if with_sword:
        var weapon: ArtWeapon = ArtWeapon.attach(hero, hero, load(SWORD) as PackedScene, 1.8)
        if weapon != null:
            weapon.begin_draw(0.0)
            weapon.set_process(false)  # stay drawn (no auto-sheathe)
    # Floor line for grounding checks.
    var floor_mesh: MeshInstance3D = MeshInstance3D.new()
    var plane: BoxMesh = BoxMesh.new()
    plane.size = Vector3(3.0, 0.02, 3.0)
    floor_mesh.mesh = plane
    floor_mesh.position.y = -0.01
    world.add_child(floor_mesh)
    var cam: Camera3D = Camera3D.new()
    cam.projection = Camera3D.PROJECTION_ORTHOGONAL
    cam.size = 2.3
    cam.position = Vector3(0.0, 1.1, 5.0)
    world.add_child(cam)
    cam.look_at(Vector3(0.0, 1.0, 0.0))
    cam.current = true
    var sheet: Image = Image.create(CELL * frames, CELL * clips.size(), false, Image.FORMAT_RGB8)
    sheet.fill(Color(0.1, 0.1, 0.1))
    for r in clips.size():
        # "clip" or "clip@from-to" (seconds): the window the game plays.
        var parts: PackedStringArray = clips[r].split("@")
        var clip: StringName = StringName(parts[0])
        if not player.has_animation(clip):
            push_warning("missing clip %s" % clip)
            continue
        var anim: Animation = player.get_animation(clip)
        var from: float = 0.0
        var to: float = anim.length
        if parts.size() > 1:
            from = float(parts[1].split("-")[0])
            to = float(parts[1].split("-")[1])
        player.play(clip)
        player.speed_scale = 0.0
        for c in frames:
            var t: float = lerpf(from, to, c / maxf(1.0, frames - 1))
            player.seek(minf(t, anim.length - 0.001), true)
            await process_frame
            await process_frame
            await RenderingServer.frame_post_draw
            var img: Image = vp.get_texture().get_image()
            img.convert(Image.FORMAT_RGB8)
            if img.get_width() != CELL:
                img.resize(CELL, CELL)
            sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, r * CELL))
            sheet.fill_rect(Rect2i(c * CELL, r * CELL, 1, CELL), Color(0.45, 0.45, 0.45))
        sheet.fill_rect(Rect2i(0, r * CELL, CELL * frames, 1), Color(0.45, 0.45, 0.45))
    sheet.save_png(out)
    print("wrote %s (%d clips x %d frames)" % [out, clips.size(), frames])
    quit(0)

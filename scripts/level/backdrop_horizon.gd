class_name BackdropHorizon
extends Node3D
## The far band of the background world (DEC-055), one per scene: it follows the camera in X/Z
## so it reads as infinitely far (like a skybox made of geometry).
##
##   * the colossal ruined cathedral 700 m ahead (+X, where the run is heading), its rose
##     window and lancets glowing, torn up on a rock and chained over the abyss;
##   * broken spires on floating rocks all round the horizon, and a titan's carcass;
##   * two rings of jagged mountains/cliffs;
##   * the blood sea far below (world-space shader, ember glints), a translucent mist layer
##     above it, and embers drifting up out of the abyss.
##
## Everything is unshadowed, collision-free and uses its own distance haze (fog_disabled
## shaders) synced to the environment's fog/sky colour, so it stays readable whatever the
## lighting setup is, in Compatibility and Forward+.

const ABYSS_SHADER: Shader = preload("res://assets/shaders/backdrop/backdrop_abyss.gdshader")
const MIST_SHADER: Shader = preload("res://assets/shaders/backdrop/backdrop_mist.gdshader")
const GLOW_SHADER: Shader = preload("res://assets/shaders/backdrop/backdrop_glow.gdshader")
const CATHEDRAL_AT: Vector3 = Vector3(820.0, -60.0, -170.0)
const CATHEDRAL_SCALE: float = 1.35
const SEA_Y: float = -110.0
const MIST_Y: float = -55.0

static var _far_mesh: ArrayMesh

var act: int = -1
var far: MeshInstance3D
var sea: MeshInstance3D
var mist: MeshInstance3D
var embers: CPUParticles3D
## Additive ring of sea-glow behind the mountains that backlights the far silhouettes.
var glow_band: MeshInstance3D
var _glow_mat: ShaderMaterial
var _sea_mat: ShaderMaterial
var _mist_mat: ShaderMaterial
var _ember_mat: StandardMaterial3D
var _check_in: float = 0.0


## Returns the scene's horizon under `parent`, creating it on first call.
static func ensure(parent: Node, act_value: int) -> BackdropHorizon:
    for child: Node in parent.get_children():
        if child is BackdropHorizon:
            return child
    var h: BackdropHorizon = BackdropHorizon.new()
    h.name = "Backdrop horizon"
    h.add_to_group(&"backdrop_horizon")
    h.set_process(not Backdrop3D.headless())
    parent.add_child(h)
    h._build()
    h.set_act(act_value)
    return h


func _build() -> void:
    far = MeshInstance3D.new()
    far.name = "Horizon silhouettes"
    far.mesh = _far()
    far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    far.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    far.custom_aabb = AABB(Vector3(-2500, -400, -2500), Vector3(5000, 1200, 5000))
    add_child(far)

    var noise: FastNoiseLite = FastNoiseLite.new()
    noise.seed = 66
    noise.frequency = 0.012
    noise.fractal_octaves = 4
    var tex: NoiseTexture2D = NoiseTexture2D.new()
    tex.width = 256
    tex.height = 256
    tex.seamless = true
    tex.generate_mipmaps = true
    tex.noise = noise

    _sea_mat = ShaderMaterial.new()
    _sea_mat.shader = ABYSS_SHADER
    _sea_mat.set_shader_parameter("noise_tex", tex)
    sea = _plane("Blood sea", 6000.0, SEA_Y, _sea_mat)

    _mist_mat = ShaderMaterial.new()
    _mist_mat.shader = MIST_SHADER
    _mist_mat.set_shader_parameter("noise_tex", tex)
    mist = _plane("Abyss mist", 3200.0, MIST_Y, _mist_mat)

    var ring: CylinderMesh = CylinderMesh.new()
    ring.top_radius = 1750.0
    ring.bottom_radius = 1750.0
    ring.height = 700.0
    ring.radial_segments = 48
    ring.rings = 1
    ring.cap_top = false
    ring.cap_bottom = false
    _glow_mat = ShaderMaterial.new()
    _glow_mat.shader = GLOW_SHADER
    _glow_mat.set_shader_parameter("base_y", SEA_Y - 150.0)
    _glow_mat.set_shader_parameter("top_y", 350.0)
    _glow_mat.set_shader_parameter("intensity", 1.6)
    glow_band = MeshInstance3D.new()
    glow_band.name = "Horizon sea-glow"
    glow_band.mesh = ring
    glow_band.material_override = _glow_mat
    glow_band.position = Vector3(0, 150.0, 0)
    glow_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(glow_band)

    embers = CPUParticles3D.new()
    embers.name = "Rising embers"
    embers.amount = 160
    embers.lifetime = 16.0
    embers.preprocess = 16.0
    embers.local_coords = false
    embers.position = Vector3(0, -40, 0)
    embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    embers.emission_box_extents = Vector3(150, 12, 150)
    embers.direction = Vector3.UP
    embers.spread = 30.0
    embers.initial_velocity_min = 1.5
    embers.initial_velocity_max = 4.0
    embers.gravity = Vector3(0.3, 0.5, 0.0)
    embers.scale_amount_min = 0.5
    embers.scale_amount_max = 1.6
    var ramp: Gradient = Gradient.new()
    ramp.set_color(0, Color(1, 1, 1, 0))
    ramp.set_color(1, Color(1, 1, 1, 0))
    ramp.add_point(0.15, Color(1, 1, 1, 1))
    ramp.add_point(0.7, Color(1, 0.8, 0.8, 0.8))
    embers.color_ramp = ramp
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2(0.28, 0.28)
    _ember_mat = StandardMaterial3D.new()
    _ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    _ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    _ember_mat.vertex_color_use_as_albedo = true
    _ember_mat.disable_fog = true
    quad.material = _ember_mat
    embers.mesh = quad
    embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    embers.emitting = not Backdrop3D.headless()
    add_child(embers)


func _plane(label: String, size: float, y: float, mat: Material) -> MeshInstance3D:
    var plane: PlaneMesh = PlaneMesh.new()
    plane.size = Vector2(size, size)
    var mi: MeshInstance3D = MeshInstance3D.new()
    mi.name = label
    mi.mesh = plane
    mi.material_override = mat
    mi.position = Vector3(0, y, 0)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    add_child(mi)
    return mi


## Every far silhouette merged into one mesh (built once per game session).
static func _far() -> ArrayMesh:
    if _far_mesh != null:
        return _far_mesh
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 6660
    var m: BackdropKit.Merge = BackdropKit.mountain_ring(1500.0, 150.0, 430.0, -320.0, 11, BackdropKit.C_STONE)
    BackdropKit.append(m, BackdropKit.mountain_ring(1080.0, 70.0, 250.0, -280.0, 23, BackdropKit.C_LIGHT), Transform3D.IDENTITY)
    BackdropKit.cathedral(m, Transform3D(Basis.from_scale(Vector3.ONE * CATHEDRAL_SCALE), CATHEDRAL_AT), rng)
    # Broken spires on floating rocks round the rest of the horizon.
    for i in 9:
        var a: float = deg_to_rad(40.0 + i * 31.0 + rng.randf_range(-8.0, 8.0))
        var dist: float = rng.randf_range(430.0, 700.0)
        var at: Vector3 = Vector3(cos(a) * dist, rng.randf_range(-60.0, 30.0), sin(a) * dist)
        var rock_r: float = rng.randf_range(35.0, 60.0)
        BackdropKit.rock(m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(rock_r, rock_r * 1.2, rock_r)), at), rng.randi() % 8, BackdropKit.C_DARK)
        var tw: float = rng.randf_range(14.0, 26.0)
        BackdropKit.gothic_tower(m, at + Vector3(0, rock_r * 0.12, 0), tw, tw * rng.randf_range(4.0, 7.0), tw * 3.0, rng.randf() < 0.5, rng)
        if rng.randf() < 0.6:
            BackdropKit.chain(m, at + Vector3(rock_r * 0.4, -rock_r * 0.6, 0), rng.randf_range(60.0, 140.0), 3.0)
    # A titan's carcass off to the side, half sunk in the blood sea.
    BackdropKit.ribcage(m, Transform3D(Basis(Vector3.UP, 0.6), Vector3(-150.0, SEA_Y - 10.0, 560.0)), 420.0, rng)
    _far_mesh = m.commit()
    return _far_mesh


## Re-themes the horizon for an act (stone, glow, sea and embers).
func set_act(value: int) -> void:
    var a: int = mini(value, 2)
    if a == act:
        return
    act = a
    var t: Dictionary = BackdropKit.theme(act)
    far.material_override = BackdropKit.stone_material(act, true)
    _sea_mat.set_shader_parameter("top_color", t["sea_top"])
    _sea_mat.set_shader_parameter("deep_color", t["sea_deep"])
    _sea_mat.set_shader_parameter("ember_color", t["ember"])
    _mist_mat.set_shader_parameter("mist_color", (t["sea_top"] as Color).darkened(0.25))
    _glow_mat.set_shader_parameter("glow_color", t["band"])
    var e: Color = t["ember"]
    _ember_mat.albedo_color = Color(e.r, e.g, e.b, 1.0)
    _sync_haze()


## Pulls the distant haze toward the scene's own fog / sky / background colour, so the
## silhouettes melt into whatever sky the environment draws.
func _sync_haze() -> void:
    if not is_inside_tree():
        return
    var theme_haze: Color = BackdropKit.theme(maxi(act, 0))["haze"]
    var target: Color = theme_haze
    var world: World3D = get_viewport().find_world_3d()
    var env: Environment = world.environment if world != null else null
    if env == null and world != null:
        env = world.fallback_environment
    if env != null:
        var env_col: Color = theme_haze
        var found: bool = false
        if env.background_mode == Environment.BG_SKY and env.sky != null:
            var sm: Material = env.sky.sky_material
            if sm is ProceduralSkyMaterial:
                env_col = (sm as ProceduralSkyMaterial).sky_horizon_color
                found = true
            elif sm is PhysicalSkyMaterial:
                env_col = (sm as PhysicalSkyMaterial).ground_color
                found = true
        if not found and env.fog_enabled:
            env_col = env.fog_light_color
            found = true
        if not found and env.background_mode == Environment.BG_COLOR:
            env_col = env.background_color
            found = true
        if found:
            target = env_col.lerp(theme_haze, 0.35)
    for mat: ShaderMaterial in BackdropKit.all_materials():
        mat.set_shader_parameter("haze_color", target)
    for mat: ShaderMaterial in BackdropFlock.all_materials():
        mat.set_shader_parameter("haze_color", target)
    _sea_mat.set_shader_parameter("haze_color", target)


func _process(delta: float) -> void:
    var cam: Camera3D = get_viewport().get_camera_3d()
    if cam != null:
        var p: Vector3 = cam.global_position
        global_position = Vector3(p.x, 0.0, p.z)
    _check_in -= delta
    if _check_in > 0.0:
        return
    _check_in = 0.5
    if cam != null:
        var best: Backdrop3D = null
        var best_d: float = INF
        for node: Node in get_tree().get_nodes_in_group(&"backdrop_room"):
            var room: Backdrop3D = node as Backdrop3D
            var d: float = absf(room.center().x - cam.global_position.x)
            if d < best_d:
                best_d = d
                best = room
        if best != null:
            set_act(best.act)
    _sync_haze()

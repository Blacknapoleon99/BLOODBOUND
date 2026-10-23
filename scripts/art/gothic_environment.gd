class_name GothicEnvironment
extends Node3D
## The full-3D look (DEC-053): "Super Mario 64, but gory, dark and gothic". One node builds the
## WorldEnvironment (procedural blood-moon sky, fog, SSAO/SSIL, glow, ACES + gothic grade), the
## moonlight with 4-split soft shadows, a cool shadow-free fill, a sinking abyss fog volume and
## ash/ember particles that follow the active camera. Used by the 3D run (main.gd), the movement
## playground and the 3D prototype; the side view keeps its own flat lighting.
##
## Quality: GameSettings.high_quality picks the preset (refresh_quality() re-applies it live).
## Low drops volumetric fog, SSIL, PCSS-soft shadows and most particles. On the Compatibility
## renderer (the Web build) the Forward+-only effects are simply never switched on.
##
## Warm accents: GothicEnvironment.torch_light(pos) returns a flickering OmniLight3D (add it
## where the torch/candle mesh is).

const GROUP: StringName = &"gothic_environment"
const SKY_SHADER: Shader = preload("res://assets/shaders/gothic_sky.gdshader")
## Direction toward the moonlight: ahead-left of the default view down +X, ~38° up (raking but
## readable shadows). The visible moon disc (SKY_MOON_DIR) sits in the same azimuth but lower, so
## it stays in frame above the horizon behind a play camera that looks slightly down.
const MOON_DIR: Vector3 = Vector3(0.70, 0.62, -0.36)
const SKY_MOON_DIR: Vector3 = Vector3(0.86, 0.21, -0.44)
const FOG_COLOR: Color = Color(0.05, 0.035, 0.05)

var world_env: WorldEnvironment
var env: Environment
var moon: DirectionalLight3D
var fill: DirectionalLight3D
var abyss_fog: FogVolume
var ash: GPUParticles3D
var embers: GPUParticles3D
var sky_material: ShaderMaterial


static func create() -> GothicEnvironment:
    var g: GothicEnvironment = GothicEnvironment.new()
    g.name = "GothicEnvironment"
    g._build()
    return g


## The Forward+ renderer is the desktop target; Compatibility (Web) gets the reduced look.
static func is_forward_plus() -> bool:
    return RenderingServer.get_current_rendering_method() == "forward_plus"


## Re-applies GameSettings.high_quality to every GothicEnvironment in the tree.
static func refresh_quality(tree: SceneTree) -> void:
    if tree == null:
        return
    for node: Node in tree.get_nodes_in_group(GROUP):
        (node as GothicEnvironment).apply_quality(GameSettings.high_quality)


## A warm flickering point light for torches, braziers and candles (shadowless: cheap).
static func torch_light(pos: Vector3, energy: float = 2.4, light_range: float = 7.0) -> OmniLight3D:
    var t: TorchLight = TorchLight.new()
    t.name = "TorchLight"
    t.position = pos
    t.light_color = Color(1.0, 0.52, 0.22)
    t.base_energy = energy
    t.light_energy = energy
    t.omni_range = light_range
    t.omni_attenuation = 1.4
    t.shadow_enabled = false
    t.light_volumetric_fog_energy = 1.5
    return t


func _build() -> void:
    add_to_group(GROUP)
    # --- sky ---
    sky_material = ShaderMaterial.new()
    sky_material.shader = SKY_SHADER
    sky_material.set_shader_parameter(&"moon_dir_uniform", SKY_MOON_DIR.normalized())
    var sky: Sky = Sky.new()
    sky.sky_material = sky_material
    sky.radiance_size = Sky.RADIANCE_SIZE_128
    sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL  # clouds drift: refresh radiance over frames

    env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.background_energy_multiplier = 1.0
    # Ambient: mostly the sky's colour (cool-crimson) plus a cool floor so shadows stay readable.
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.34, 0.38, 0.56)
    env.ambient_light_energy = 0.4
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

    # Tonemap + grade: ACES, a touch of contrast, desaturated with cold shadows / warm highlights.
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 1.05
    env.tonemap_white = 6.0
    env.adjustment_enabled = true
    env.adjustment_brightness = 1.0
    env.adjustment_contrast = 1.08
    env.adjustment_saturation = 0.78
    env.adjustment_color_correction = _grade_ramp()

    # Glow for the moon, embers and blood.
    env.glow_enabled = true
    env.glow_normalized = false
    env.glow_intensity = 0.35
    env.glow_strength = 1.0
    env.glow_bloom = 0.04
    env.glow_hdr_threshold = 0.8
    env.glow_hdr_scale = 2.0
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
    for i in 7:
        env.set_glow_level(i, 1.0 if i in [2, 3, 4, 5] else 0.0)

    # Depth fog with a heavy floor: the void under the courses sinks into crimson murk.
    env.fog_enabled = true
    env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
    env.fog_light_color = FOG_COLOR
    env.fog_light_energy = 1.0
    env.fog_sun_scatter = 0.25
    env.fog_density = 0.0065
    env.fog_aerial_perspective = 0.12
    env.fog_sky_affect = 0.0
    env.fog_height = -3.0
    env.fog_height_density = 0.09

    env.ssao_enabled = true
    env.ssao_radius = 1.4
    env.ssao_intensity = 2.2
    env.ssao_power = 1.6
    env.ssao_detail = 0.6
    env.ssao_light_affect = 0.15

    world_env = WorldEnvironment.new()
    world_env.name = "WorldEnvironment"
    world_env.environment = env
    add_child(world_env)

    # --- moonlight: crimson-rose key with long soft shadows ---
    moon = DirectionalLight3D.new()
    moon.name = "Moonlight"
    add_child(moon)
    moon.basis = Basis.looking_at(-MOON_DIR.normalized(), Vector3.UP)
    moon.light_color = Color(1.0, 0.74, 0.7)
    moon.light_energy = 2.0
    moon.light_volumetric_fog_energy = 1.4
    moon.shadow_enabled = true
    moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    moon.directional_shadow_max_distance = 70.0
    moon.directional_shadow_split_1 = 0.08
    moon.directional_shadow_split_2 = 0.22
    moon.directional_shadow_split_3 = 0.5
    moon.directional_shadow_blend_splits = true
    moon.directional_shadow_fade_start = 0.85
    moon.shadow_bias = 0.04
    moon.shadow_normal_bias = 1.2

    # --- cool fill from opposite the moon (lights what the camera sees when facing it) ---
    fill = DirectionalLight3D.new()
    fill.name = "SkyFill"
    add_child(fill)
    fill.basis = Basis.looking_at(Vector3(0.62, -0.5, -0.4).normalized(), Vector3.UP)  # opposite the key
    fill.light_color = Color(0.48, 0.58, 1.0)
    fill.light_energy = 0.55
    fill.light_specular = 0.2
    fill.shadow_enabled = false
    fill.light_volumetric_fog_energy = 0.0

    # --- the abyss: a dense fog slab under the courses, following the camera ---
    abyss_fog = FogVolume.new()
    abyss_fog.name = "AbyssFog"
    abyss_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
    abyss_fog.size = Vector3(220.0, 40.0, 220.0)
    var fog_mat: FogMaterial = FogMaterial.new()
    fog_mat.density = 0.35
    fog_mat.albedo = Color(0.32, 0.1, 0.12)
    fog_mat.emission = Color(0.09, 0.012, 0.008)
    fog_mat.height_falloff = 0.12
    fog_mat.edge_fade = 0.6
    abyss_fog.material = fog_mat
    abyss_fog.position = Vector3(0.0, -23.0, 0.0)  # top at y = -3
    add_child(abyss_fog)

    ash = _make_ash()
    add_child(ash)
    embers = _make_embers()
    add_child(embers)

    apply_quality(GameSettings.high_quality)


func apply_quality(high: bool) -> void:
    var fplus: bool = is_forward_plus()
    var vol: bool = high and fplus
    env.volumetric_fog_enabled = vol
    env.volumetric_fog_density = 0.008
    env.volumetric_fog_albedo = Color(0.42, 0.4, 0.5)
    env.volumetric_fog_emission = Color(0.006, 0.003, 0.005)
    env.volumetric_fog_emission_energy = 1.0
    env.volumetric_fog_anisotropy = 0.55
    env.volumetric_fog_length = 80.0
    env.volumetric_fog_detail_spread = 2.0
    env.volumetric_fog_ambient_inject = 0.2
    env.volumetric_fog_sky_affect = 0.0
    env.volumetric_fog_gi_inject = 0.0
    # With volumetrics the abyss volume does the floor; without, the height fog does it alone.
    env.fog_density = 0.0045 if vol else 0.0075
    env.fog_height_density = 0.05 if vol else 0.12
    abyss_fog.visible = vol
    env.ssil_enabled = high and fplus
    env.ssil_radius = 4.0
    env.ssil_intensity = 0.8
    env.ssil_normal_rejection = 1.0
    env.ssao_enabled = fplus or high  # SSAO works on Forward+ and Mobile only
    env.sdfgi_enabled = false  # measured too costly for procedurally built courses (DEC-053)
    moon.light_angular_distance = 0.6 if high else 0.0  # PCSS softening at distance
    moon.shadow_blur = 1.2 if high else 1.0
    moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    ash.amount = 900 if high else 260
    embers.amount = 140 if high else 50
    var sky: Sky = env.sky
    sky.radiance_size = Sky.RADIANCE_SIZE_128 if high else Sky.RADIANCE_SIZE_64


func _process(_delta: float) -> void:
    var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
    if cam == null:
        return
    var p: Vector3 = cam.global_position
    ash.global_position = p
    embers.global_position = p + Vector3(0.0, -4.0, 0.0)
    abyss_fog.global_position = Vector3(snappedf(p.x, 4.0), -23.0, snappedf(p.z, 4.0))


## Cold blue-black shadows, desaturated mids, a faint warm lift in the highlights.
func _grade_ramp() -> GradientTexture1D:
    var g: Gradient = Gradient.new()
    g.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 0.82, 1.0])
    g.colors = PackedColorArray([
        Color(0.0, 0.004, 0.018),
        Color(0.15, 0.155, 0.2),
        Color(0.5, 0.48, 0.49),
        Color(0.85, 0.8, 0.77),
        Color(1.0, 0.96, 0.92),
    ])
    var tex: GradientTexture1D = GradientTexture1D.new()
    tex.gradient = g
    tex.width = 256
    return tex


func _make_ash() -> GPUParticles3D:
    var p: GPUParticles3D = GPUParticles3D.new()
    p.name = "Ash"
    p.amount = 900
    p.lifetime = 9.0
    p.preprocess = 9.0
    p.local_coords = false
    p.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
    var m: ParticleProcessMaterial = ParticleProcessMaterial.new()
    m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    m.emission_box_extents = Vector3(22.0, 10.0, 22.0)
    m.direction = Vector3(0.3, -1.0, 0.1)
    m.spread = 35.0
    m.initial_velocity_min = 0.2
    m.initial_velocity_max = 0.7
    m.gravity = Vector3(0.25, -0.18, 0.08)
    m.turbulence_enabled = true
    m.turbulence_noise_strength = 1.2
    m.turbulence_noise_scale = 6.0
    m.turbulence_influence_min = 0.05
    m.turbulence_influence_max = 0.15
    m.scale_min = 0.5
    m.scale_max = 1.4
    m.color = Color(0.55, 0.52, 0.55, 0.7)
    var fade: Gradient = Gradient.new()
    fade.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
    fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
    var ramp: GradientTexture1D = GradientTexture1D.new()
    ramp.gradient = fade
    m.color_ramp = ramp
    p.process_material = m
    p.draw_pass_1 = _particle_quad(0.045, Color(0.6, 0.57, 0.6), 0.0)
    return p


func _make_embers() -> GPUParticles3D:
    var p: GPUParticles3D = GPUParticles3D.new()
    p.name = "Embers"
    p.amount = 140
    p.lifetime = 7.0
    p.preprocess = 7.0
    p.local_coords = false
    p.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
    var m: ParticleProcessMaterial = ParticleProcessMaterial.new()
    m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    m.emission_box_extents = Vector3(24.0, 4.0, 24.0)
    m.direction = Vector3(0.0, 1.0, 0.0)
    m.spread = 25.0
    m.initial_velocity_min = 0.8
    m.initial_velocity_max = 2.0
    m.gravity = Vector3(0.3, 0.35, 0.0)
    m.turbulence_enabled = true
    m.turbulence_noise_strength = 2.0
    m.turbulence_noise_scale = 4.0
    m.turbulence_influence_min = 0.1
    m.turbulence_influence_max = 0.3
    m.scale_min = 0.4
    m.scale_max = 1.1
    var fade: Gradient = Gradient.new()
    fade.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
    fade.colors = PackedColorArray([Color(1, 0.6, 0.2, 0), Color(1, 0.55, 0.2, 1), Color(1, 0.25, 0.08, 0.9), Color(0.6, 0.05, 0.02, 0)])
    var ramp: GradientTexture1D = GradientTexture1D.new()
    ramp.gradient = fade
    m.color_ramp = ramp
    p.process_material = m
    p.draw_pass_1 = _particle_quad(0.05, Color(1.0, 0.45, 0.15), 5.0)
    return p


## A camera-facing soft dot; emission > 0 makes it glow (embers).
func _particle_quad(size: float, tint: Color, emission: float) -> QuadMesh:
    var q: QuadMesh = QuadMesh.new()
    q.size = Vector2(size, size)
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.vertex_color_use_as_albedo = true
    mat.albedo_color = Color(tint.r * maxf(emission, 1.0), tint.g * maxf(emission, 1.0), tint.b * maxf(emission, 1.0), 1.0)
    mat.albedo_texture = _soft_dot()
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    q.material = mat
    return q


static func _soft_dot() -> Texture2D:
    var g: Gradient = Gradient.new()
    g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
    g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
    var t: GradientTexture2D = GradientTexture2D.new()
    t.gradient = g
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to = Vector2(1.0, 0.5)
    t.width = 32
    t.height = 32
    return t


## A torch/candle light with a slow organic flicker.
class TorchLight extends OmniLight3D:
    var base_energy: float = 2.4
    var _t: float = randf() * 10.0

    func _process(delta: float) -> void:
        _t += delta
        light_energy = base_energy * (0.86 + 0.09 * sin(_t * 7.3) + 0.05 * sin(_t * 17.1 + 1.3))

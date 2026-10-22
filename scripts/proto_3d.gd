extends Node3D
## Full-3D phase 1 test room (docs/superpowers/specs/2026-10-22-full-3d-conversion-plan.md):
## the real player (Bone Revenant, cards, blood, combo, dodge) with the third-person camera and
## lock-on, in a small 3D space: open ground, a stair to a raised platform, a pit crossed on
## floating platforms, pillars for camera collision.
## Phase 2: every enemy type fights in full 3D (EnemyFactory.full_3d), chasing around pillars on
## a navigation mesh baked at load from the room's solids. Three waves: soldiers and husks;
## knight, hound, archer and crawlers; wraiths and the Gravewarden. Clearing the last wave
## starts again from the first.
## Reached from the main menu ("3D Prototype"). Esc pauses (and frees the mouse).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SOLDIER_SCENE: PackedScene = preload("res://scenes/enemies/plagued_soldier.tscn")
## [type, x, z] per enemy, one array per wave.
const WAVES: Array = [
    [[&"soldier", -6.0, -6.0], [&"soldier", 6.0, -8.0], [&"soldier", 0.0, -14.0], [&"husk", -10.0, -10.0], [&"husk", 10.0, -2.0]],
    [[&"knight", 0.0, -10.0], [&"hound", -9.0, -8.0], [&"archer", 10.0, -14.0], [&"crawler", -4.0, -15.0], [&"crawler", 5.0, -4.0]],
    [[&"wraith", -7.0, -10.0], [&"wraith", 7.0, -10.0], [&"gravewarden", 0.0, -12.0]],
]
const SPAWN: Vector3 = Vector3(0.0, 1.5, 8.0)

var player: CharacterBody3D
var cam: ThirdPersonCamera
var hud: Label
var enemies: Array[Node3D] = []
var wave: int = 0
var nav_region: NavigationRegion3D
var _next_wave_in: float = -1.0
var auto_waves: bool = true  # tests turn this off to stage one enemy at a time


func _ready() -> void:
    InputBindings.configure_players(false)
    EnemyFactory.full_3d = true
    GameSettings.load_settings()
    _environment()
    _build_space()
    player = PLAYER_SCENE.instantiate() as CharacterBody3D
    player.add_to_group(&"player")
    add_child(player)
    player.global_position = SPAWN
    player.set("in_3d_mode", true)
    player.floor_snap_length = 0.35  # hug slopes and stair noses instead of hopping off them
    player.floor_max_angle = deg_to_rad(50.0)
    player.connect("died", func() -> void: player.call_deferred("revive_at", SPAWN), CONNECT_DEFERRED)
    cam = ThirdPersonCamera.create(player)
    add_child(cam)
    player.set("view_camera", cam)
    _bake_navigation()
    spawn_wave(0)
    ArtSwap.apply(self)
    var canvas: CanvasLayer = CanvasLayer.new()
    add_child(canvas)
    hud = MenuStyle.label("", 17)
    hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    hud.position = Vector2(22, 18)
    canvas.add_child(hud)
    canvas.add_child(CardHandUI.create(player.get_node("Cards") as CardSystem))
    add_child(PauseMenu.create())
    Audio.apply_volumes()
    Audio.music(&"music_level")


func _exit_tree() -> void:
    EnemyFactory.full_3d = false  # the side-view game spawns plane-locked enemies again


## Spawns wave `index` (wrapping) through the factory, so every enemy runs its full-3D AI.
func spawn_wave(index: int) -> void:
    wave = index % WAVES.size()
    enemies.clear()
    for entry: Array in WAVES[wave]:
        var type: StringName = entry[0]
        var e: Node3D
        if type == &"soldier":
            var soldier: PlaguedSoldier = SOLDIER_SCENE.instantiate() as PlaguedSoldier
            soldier.plane_locked = false
            soldier.leash_radius = 12.0
            add_child(soldier)
            soldier.global_position = Vector3(entry[1], 1.0, entry[2])
            soldier.set("_home", soldier.position)
            e = soldier
        else:
            e = EnemyFactory.spawn(type, self, entry[1], -INF, INF, 1.0, entry[2])
        enemies.append(e)


## Removes every enemy and pending strike zone (tests).
func clear_enemies() -> void:
    for child: Node in get_children():
        if child is CodeEnemy or child is PlaguedSoldier or child is CryptHound or child is BoneArcher or child is StrikeZone or child is BoneArrow:
            child.queue_free()
    enemies.clear()


func alive_count() -> int:
    var alive: int = 0
    for e: Node3D in enemies:
        if not is_instance_valid(e):
            continue
        var h: Health = e.get("health") as Health
        if h == null:
            h = e.get_node_or_null("Health") as Health
        if h != null and not h.is_dead():
            alive += 1
    return alive


## Bakes the room's navigation mesh from the static solids (all children of the region).
func _bake_navigation() -> void:
    var navmesh: NavigationMesh = NavigationMesh.new()
    navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
    navmesh.agent_radius = 0.5
    navmesh.agent_height = 1.8
    navmesh.agent_max_climb = 0.5
    navmesh.agent_max_slope = 50.0
    var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
    NavigationServer3D.parse_source_geometry_data(navmesh, source, nav_region)
    # Baked off the main thread (the synchronous bake logs an internal list error in 4.7); until
    # it lands, enemies chase straight at you.
    NavigationServer3D.bake_from_source_geometry_data_async(navmesh, source, func() -> void:
        if is_instance_valid(nav_region):
            nav_region.navigation_mesh = navmesh)


func _process(delta: float) -> void:
    if player.global_position.y < -10.0:
        player.call("teleport_to", SPAWN)
    var alive: int = alive_count()
    if alive == 0 and _next_wave_in < 0.0 and auto_waves:
        _next_wave_in = 2.5
    if _next_wave_in >= 0.0:
        _next_wave_in -= delta
        if _next_wave_in < 0.0:
            spawn_wave(wave + 1)
    var locked: String = "LOCKED: " + cam.lock_target.name if cam.lock_target != null else "Q / middle mouse: lock on"
    hud.text = "3D PROTOTYPE (phase 2: enemies)\nWASD move (camera-relative) · mouse look · Space jump · Shift dodge · left/right click attack · 1-3 cards\n%s · Tab / wheel: next target · Esc pause\nHP %d/%d    wave %d/%d    enemies left %d" % [
        locked, (player.get("health") as Health).current, (player.get("health") as Health).max_health, wave + 1, WAVES.size(), alive]


func _environment() -> void:
    var world: WorldEnvironment = WorldEnvironment.new()
    var env: Environment = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.02, 0.022, 0.035)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.3, 0.32, 0.45)
    env.ambient_light_energy = 0.8
    env.fog_enabled = true
    env.fog_light_color = Color(0.08, 0.07, 0.1)
    env.fog_density = 0.012
    world.environment = env
    add_child(world)
    var moon: DirectionalLight3D = DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
    moon.light_color = Color(0.62, 0.68, 1.0)
    moon.light_energy = 1.3
    moon.shadow_enabled = true
    add_child(moon)


func _build_space() -> void:
    nav_region = NavigationRegion3D.new()
    nav_region.name = "Navigation"
    add_child(nav_region)
    var stone: Color = Color(0.2, 0.2, 0.25)
    _solid("Ground", Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0), stone)
    # A stair up to a raised platform.
    for i in 5:
        _solid("Step %d" % i, Vector3(14.0, 0.2 + i * 0.4, -2.0 + i * 1.2), Vector3(5.0, 0.4 + i * 0.8, 1.2), stone.lightened(0.05 * i))
    _solid("Raised platform", Vector3(14.0, 0.8, 7.5), Vector3(8.0, 3.6, 8.0), stone.lightened(0.15))
    # A pit beyond the ground, crossed on floating platforms.
    _solid("Far ground", Vector3(0.0, -0.5, -40.0), Vector3(20.0, 1.0, 12.0), stone)
    for p: Vector3 in [Vector3(0.0, 0.0, -23.5), Vector3(3.0, 0.6, -27.5), Vector3(-1.0, 1.2, -31.0), Vector3(0.0, 0.4, -34.5)]:
        _solid("Floating platform", p, Vector3(3.0, 0.5, 3.0), Color(0.3, 0.27, 0.3))
    # Pillars (camera collision) and a low wall to hop.
    for p: Vector3 in [Vector3(-8.0, 3.0, 4.0), Vector3(-12.0, 3.0, -4.0), Vector3(8.0, 3.0, -16.0)]:
        _solid("Pillar", p, Vector3(1.6, 6.0, 1.6), stone.darkened(0.2))
    _solid("Low wall", Vector3(-6.0, 0.5, 12.0), Vector3(6.0, 1.0, 0.6), stone.darkened(0.1))


func _solid(label: String, center: Vector3, size: Vector3, color: Color) -> void:
    var body: StaticBody3D = StaticBody3D.new()
    body.name = label
    body.position = center
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    mesh_node.material_override = material
    body.add_child(mesh_node)
    nav_region.add_child(body)

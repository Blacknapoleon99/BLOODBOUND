extends Node3D
## Movement playground (3D platformer phase 1): one station per move of the PlatformerMotor, each
## with a sign, so the moveset can be felt and tuned before stages are rebuilt around it.
## Opened from the title screen with F1 (a developer shortcut; the menu itself stays Play /
## Co-op). Esc pauses.
##
## Stations (all reachable from the start pad, x grows to the right of the spawn):
##   Momentum strip   60 m straight run: speed builds to 11 m/s.
##   Triple tower     a 3.4 m ledge: out of reach of a single jump; triple jump or backflip.
##   Long-jump gap    an 8 m gap over the abyss.
##   Wall-jump shaft  two walls 3 m apart, 10 m tall, a ledge on top.
##   Ledge wall       a 3 m wall to catch, shimmy along and pull up.
##   Slide tunnel     a 1.2 m-high gap under a slab.
##   Pound floor      a cracked slab over a shard cache: ground pound through it.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SPAWN: Vector3 = Vector3(0.0, 1.2, 0.0)

var player: CharacterBody3D
var cam: ThirdPersonCamera
var hud: Label
## Station name -> a spot just in front of it (tests teleport here).
var stations: Dictionary = {}
var crack: BreakableFloor
var _last_event: String = ""


func _ready() -> void:
    InputBindings.configure_players(false)
    GameSettings.load_settings()
    Lane.full_3d = false
    _environment()
    _build()
    player = PLAYER_SCENE.instantiate() as CharacterBody3D
    player.add_to_group(&"player")
    add_child(player)
    player.global_position = SPAWN
    player.set("in_3d_mode", true)
    player.floor_snap_length = 0.35
    player.floor_max_angle = deg_to_rad(50.0)
    player.connect("died", func() -> void: player.call_deferred("revive_at", SPAWN), CONNECT_DEFERRED)
    player.connect("move_event", func(n: StringName) -> void: _last_event = String(n))
    cam = ThirdPersonCamera.create(player)
    add_child(cam)
    player.set("view_camera", cam)
    cam.yaw = -PI * 0.5  # looking down the course (+X)
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


func _process(_delta: float) -> void:
    if player.global_position.y < -12.0:
        player.call("teleport_to", SPAWN)
    var motor: PlatformerMotor = player.get("motor")
    var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
    hud.text = "MOVEMENT PLAYGROUND (3D platformer phase 1)\n" \
        + "WASD move · mouse look · Space jump (hold = higher) · Ctrl/C crouch · Shift dash · Esc pause\n" \
        + "Triple jump: jump again right as you land, running · Long jump: run, Ctrl, Space · Backflip: stand, Ctrl, Space\n" \
        + "Side flip: reverse hard while running, Space · Wall kick: push into a wall in the air, Space · Ground pound: Ctrl in the air\n" \
        + "state %s · jump %s · speed %.1f m/s · last %s" % [
            PlatformerMotor.State.keys()[motor.state], PlatformerMotor.Jump.keys()[motor.jump_kind], speed, _last_event]


func _environment() -> void:
    var world: WorldEnvironment = WorldEnvironment.new()
    var env: Environment = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.03, 0.03, 0.05)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.35, 0.36, 0.48)
    env.ambient_light_energy = 0.85
    world.environment = env
    add_child(world)
    var moon: DirectionalLight3D = DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
    moon.light_color = Color(0.7, 0.72, 1.0)
    moon.light_energy = 1.3
    moon.shadow_enabled = true
    add_child(moon)


func _build() -> void:
    var stone: Color = Color(0.22, 0.22, 0.27)
    var accent: Color = Color(0.32, 0.27, 0.3)
    # Start pad and the momentum strip (+X).
    _solid("Start pad", Vector3(0.0, -0.5, 0.0), Vector3(12.0, 1.0, 12.0), stone)
    _solid("Momentum strip", Vector3(36.0, -0.5, 0.0), Vector3(60.0, 1.0, 5.0), stone.darkened(0.1))
    _sign("MOMENTUM RUN  →\nrun straight: speed builds", Vector3(7.0, 2.6, -2.0))
    stations["momentum"] = Vector3(6.0, 1.2, 0.0)
    # Triple tower (-Z side of the pad): a 3.4 m ledge.
    _solid("Triple ground", Vector3(0.0, -0.5, -16.0), Vector3(12.0, 1.0, 20.0), stone)
    _solid("Triple tower", Vector3(0.0, 1.7, -24.0), Vector3(8.0, 3.4, 4.0), accent)
    _sign("TRIPLE JUMP / BACKFLIP\n3.4 m ledge", Vector3(-4.5, 2.6, -10.0))
    stations["triple"] = Vector3(0.0, 1.2, -9.0)
    # Long-jump gap (-X): run-up, 8 m of abyss, landing.
    _solid("Long run-up", Vector3(-16.0, -0.5, 0.0), Vector3(20.0, 1.0, 5.0), stone)
    _solid("Long landing", Vector3(-36.0, -0.5, 0.0), Vector3(4.0, 1.0, 5.0), accent)
    _sign("LONG JUMP  ←\n8 m gap: run, Ctrl, Space", Vector3(-8.0, 2.6, -2.5))
    stations["long"] = Vector3(-8.0, 1.2, 0.0)
    # Wall-jump shaft (+Z): two walls 3 m apart, 10 m tall, a ledge on top.
    _solid("Shaft floor", Vector3(0.0, -0.5, 14.0), Vector3(10.0, 1.0, 16.0), stone)
    _solid("Shaft wall L", Vector3(-1.8, 5.0, 22.0), Vector3(0.6, 10.0, 6.0), accent)
    _solid("Shaft wall R", Vector3(1.8, 5.0, 22.0), Vector3(0.6, 10.0, 6.0), accent)
    _solid("Shaft top", Vector3(0.0, 9.75, 27.0), Vector3(4.2, 0.5, 4.0), stone.lightened(0.1))
    _sign("WALL KICK SHAFT\npush into a wall, Space", Vector3(-3.5, 2.6, 15.0))
    stations["shaft"] = Vector3(0.0, 1.2, 19.5)
    # Ledge wall (+X, -Z): a 3 m wall to catch and shimmy along.
    _solid("Ledge ground", Vector3(20.0, -0.5, -14.0), Vector3(14.0, 1.0, 14.0), stone)
    _solid("Ledge wall", Vector3(20.0, 1.5, -19.5), Vector3(10.0, 3.0, 3.0), accent)
    _sign("LEDGE GRAB\njump at the wall, hang, A/D shimmy, W pull up", Vector3(15.0, 2.6, -10.0))
    stations["ledge"] = Vector3(20.0, 1.2, -14.0)
    # Slide tunnel (+X, +Z): a slab with 1.2 m clearance.
    _solid("Tunnel ground", Vector3(22.0, -0.5, 14.0), Vector3(20.0, 1.0, 6.0), stone)
    _solid("Tunnel slab", Vector3(22.0, 2.2, 14.0), Vector3(6.0, 2.0, 6.0), accent)
    _sign("SLIDE TUNNEL\nrun, Ctrl: slide under", Vector3(14.0, 2.6, 11.0))
    stations["tunnel"] = Vector3(14.0, 1.2, 14.0)
    # Pound floor (-X, +Z): cracked slab over a cache.
    _solid("Pound ground", Vector3(-14.0, -0.5, 14.0), Vector3(8.0, 1.0, 8.0), stone)
    crack = BreakableFloor.create(Vector3(-20.0, -0.5, 14.0), Vector3(4.0, 1.0, 4.0))
    add_child(crack)
    _solid("Pound pit floor", Vector3(-20.0, -3.0, 14.0), Vector3(4.0, 1.0, 4.0), stone.darkened(0.2))
    var chest: LootChest = LootChest.create(Vector3(-20.0, -2.5, 14.0))
    chest.kind = &"shards"
    chest.shards = 10
    add_child(chest)
    _solid("Pound ledge", Vector3(-20.0, 1.9, 18.6), Vector3(4.0, 0.4, 2.6), stone.lightened(0.1))
    _sign("GROUND POUND\njump, Ctrl in the air", Vector3(-14.0, 2.6, 10.5))
    stations["pound"] = Vector3(-15.0, 1.2, 14.0)


func _solid(label: String, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
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
    add_child(body)
    return body


func _sign(text: String, at: Vector3) -> void:
    var label: Label3D = Label3D.new()
    label.text = text
    label.position = at
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 48
    label.pixel_size = 0.006
    label.modulate = Color(0.95, 0.88, 0.8)
    label.outline_size = 10
    add_child(label)

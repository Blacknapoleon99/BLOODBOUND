extends Node3D
## Movement playground (3D platformer phase 1): one station per move of the PlatformerMotor, each
## with a sign, so the moveset can be felt and tuned before stages are rebuilt around it.
## Opened from the title screen with F1 (a developer shortcut; the menu itself stays Play /
## Co-op). Esc pauses.
##
## Stations (all reachable from the start pad, x grows to the right of the spawn):
##   Momentum strip   60 m straight run: speed builds to 10.8 m/s over ~1.5 s (SM64 curve).
##   Triple tower     a 3.4 m ledge: out of reach of a single jump; triple jump or backflip.
##   Long-jump gap    an 8 m gap over the abyss.
##   Wall-jump shaft  two walls 3 m apart, 10 m tall, a ledge on top.
##   Ledge wall       a 3 m wall to catch, shimmy along and pull up.
##   Slide tunnel     a 1.2 m-high gap under a slab.
##   Pound floor      a cracked slab over a shard cache: ground pound through it.
##   Climb tower      (phase 2) an 8 m climbable tower, a 3 m climbable wall to run up
##                    ("parkour up"), and a plain 8 m wall beside it that does NOT climb.
##   Slopes           (DEC-051) a 25° ramp to walk, a 45° ramp that slides you down, and a
##                    60° face that is no floor at all (the steep-face fallback).
##   Bonk wall        (DEC-051) a run-up into a tall wall: jump into it and let go to bonk.

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
    hud.text = "MOVEMENT PLAYGROUND (3D platformer, SM64-style feel)\n" \
        + "WASD move (the hero turns toward the stick; speed builds) · mouse look · Space jump (hold = higher) · Ctrl/C crouch · Shift dash · Esc pause\n" \
        + "Triple jump: jump again within 0.25 s of landing, running fast · Long jump: run, Ctrl, Space · Backflip: stand, Ctrl, Space\n" \
        + "Side flip: reverse hard while running, Space · Wall kick: push into a wall in the air, Space · Ground pound: Ctrl in the air\n" \
        + "Jumps keep their facing (the stick only trims the arc) · Let go at a run: brake · Jump into a wall without pushing: bonk\n" \
        + "Climb: jump into a wall with bone handholds · W/S up/down · A/D across · Space leap · back+Space jump off · Ctrl let go\n" \
        + "state %s · jump %s · pose %s · speed %.1f m/s · last %s" % [
            PlatformerMotor.State.keys()[motor.state], PlatformerMotor.Jump.keys()[motor.jump_kind], motor.anim_state()["pose"], speed, _last_event]


func _environment() -> void:
    add_child(GothicEnvironment.create())  # the full-3D look (DEC-053)


func _build() -> void:
    var stone: Color = Color(0.22, 0.22, 0.27)
    var accent: Color = Color(0.32, 0.27, 0.3)
    # Start pad and the momentum strip (+X).
    _solid("Start pad", Vector3(0.0, -0.5, 0.0), Vector3(12.0, 1.0, 12.0), stone)
    _solid("Momentum strip", Vector3(36.0, -0.5, 0.0), Vector3(60.0, 1.0, 5.0), stone.darkened(0.1))
    _sign("MOMENTUM RUN  →\nrun straight: speed builds to 10.8 m/s\nlet go: brake · reverse: skid", Vector3(7.0, 2.6, -2.0))
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
    # Climb tower (-X, -Z): an 8 m climbable tower, a 3 m climbable step wall, a plain 8 m wall.
    _solid("Climb ground", Vector3(-20.0, -0.5, -16.0), Vector3(16.0, 1.0, 16.0), stone)
    add_child(ClimbWall.create("Climb tower", Vector3(-22.0, 4.0, -22.0), Vector3(6.0, 8.0, 3.0)))
    _solid("Tower top", Vector3(-22.0, 8.15, -22.0), Vector3(6.0, 0.3, 3.0), stone.lightened(0.15))
    add_child(ClimbWall.create("Parkour step", Vector3(-15.0, 1.5, -22.0), Vector3(4.0, 3.0, 3.0)))
    _solid("Plain wall", Vector3(-28.5, 4.0, -22.0), Vector3(3.0, 8.0, 3.0), accent.darkened(0.25))
    _sign("CLIMBING\nbone handholds climb: jump in to grab,\nWASD climb, Space leap, back+Space jump off, Ctrl let go", Vector3(-20.0, 3.0, -12.0))
    # A short run-up: the run builds speed over ~1.5 s now (DEC-051), so stand close.
    stations["climb"] = Vector3(-22.0, 1.2, -19.0)
    stations["parkour"] = Vector3(-15.0, 1.2, -18.0)
    stations["plain"] = Vector3(-28.5, 1.2, -17.0)
    # Slopes (+X, far -Z): a 25° ramp you can walk (it speeds you up downhill, slows you uphill),
    # a 45° ramp too steep to stand on (forced slide), and a 60° face that is not a floor at all
    # (the steep-face fallback: you slide down it in the slide pose, never stuck in the fall pose).
    _solid("Slope ground", Vector3(40.0, -0.5, -20.0), Vector3(24.0, 1.0, 22.0), stone)
    _ramp("Ramp 25", Vector3(40.0, 0.0, -13.0), 25.0, 8.0, stone.lightened(0.08))
    _ramp("Ramp 45", Vector3(40.0, 0.0, -20.0), 45.0, 5.0, accent)
    _ramp("Face 60", Vector3(40.0, 0.0, -27.0), 60.0, 5.0, accent.darkened(0.2))
    _sign("SLOPES\n25° walk · 45° slides you down · 60° is a face, not a floor", Vector3(32.0, 3.0, -20.0))
    stations["slope"] = Vector3(33.0, 1.2, -20.0)
    stations["ramp45_top"] = _ramp_drop_point(Vector3(40.0, 0.0, -20.0), 45.0, 5.0)
    stations["face60_top"] = _ramp_drop_point(Vector3(40.0, 0.0, -27.0), 60.0, 5.0)
    # Bonk wall (+X, +Z): a run-up into a tall wall. Jumping into it head-on without pushing into
    # it bonks you back; pushing into it wall-slides (and you can kick).
    _solid("Bonk run-up", Vector3(42.0, -0.5, 10.0), Vector3(18.0, 1.0, 6.0), stone)
    _solid("Bonk wall", Vector3(51.5, 3.0, 10.0), Vector3(1.0, 6.0, 6.0), accent)
    _sign("BONK WALL\njump into it head-on and let go: bonk", Vector3(38.0, 2.6, 7.5))
    stations["bonk"] = Vector3(36.0, 1.2, 10.0)


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


## A ramp rising toward +X from `foot` (its low edge on the ground) at `angle_deg`, `length` m
## along its surface, 5 m wide.
func _ramp(label: String, foot: Vector3, angle_deg: float, length: float, color: Color) -> StaticBody3D:
    var angle: float = deg_to_rad(angle_deg)
    var thickness: float = 0.5
    var up: Vector3 = Vector3(-sin(angle), cos(angle), 0.0)  # the surface normal
    var along: Vector3 = Vector3(cos(angle), sin(angle), 0.0)
    var center: Vector3 = foot + along * (length * 0.5) - up * (thickness * 0.5)
    var body: StaticBody3D = _solid(label, center, Vector3(length, thickness, 5.0), color)
    body.rotation.z = angle
    return body


## A spot 1.2 m above the middle of a ramp built by _ramp (tests drop the hero here).
func _ramp_drop_point(foot: Vector3, angle_deg: float, length: float) -> Vector3:
    var angle: float = deg_to_rad(angle_deg)
    var along: Vector3 = Vector3(cos(angle), sin(angle), 0.0)
    return foot + along * (length * 0.55) + Vector3(-sin(angle), cos(angle), 0.0) * 1.2


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

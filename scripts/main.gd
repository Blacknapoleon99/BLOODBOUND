extends Node3D
## Tiny procedural prototype corridor. Not the final level, card system, or boss.
## Goal: easily replaceable greybox; supports side-view and one 3D practice area.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SPAWN_POSITION: Vector3 = Vector3(-16.0, 2.0, 0.0)
const ENEMY_POSITION: Vector3 = Vector3(5.0, 0.95, 0.0)
const GATE_POSITION: Vector3 = Vector3(13.0, 1.0, 0.0)
const ARENA_SPAWN: Vector3 = Vector3(34.0, 2.0, 0.0)
const CHECKPOINT_POSITION: Vector3 = Vector3(-4.5, 1.2, 0.0)

var player: CharacterBody3D
var camera: Camera3D
var dummy: Node3D
var checkpoint: Checkpoint
var respawn_point: Vector3 = SPAWN_POSITION
var hud: Label
var enemy_alive: bool = true
var arena_visited: bool = false
var game_won: bool = false
var _message: String = ""
var _message_until: float = 0.0


func _ready() -> void:
    InputBindings.ensure_defaults()
    _build_greybox()
    player = PLAYER_SCENE.instantiate() as CharacterBody3D
    player.add_to_group(&"player")
    add_child(player)
    player.global_position = SPAWN_POSITION
    player.connect("attack_requested", Callable(self, "_on_player_attack"))

    camera = Camera3D.new()
    camera.name = "SideViewOrArenaCamera"
    camera.fov = 52.0
    camera.current = true
    add_child(camera)
    camera.global_position = player.global_position + Vector3(0.0, 4.8, 22.0)
    camera.look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)

    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "MinimalHUD"
    add_child(canvas)
    hud = Label.new()
    hud.name = "ControlsHUD"
    hud.position = Vector2(22, 20)
    hud.add_theme_font_size_override("font_size", 19)
    hud.add_theme_color_override("font_color", Color(0.98, 0.94, 0.88))
    hud.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.02))
    hud.add_theme_constant_override("shadow_offset_x", 2)
    hud.add_theme_constant_override("shadow_offset_y", 2)
    canvas.add_child(hud)
    _flash("Greybox foundation: defeat the crimson dummy, explore the 3D gate, reach EXIT.", 7.0)


func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    var in_arena: bool = bool(player.get("in_3d_mode"))
    var offset: Vector3 = Vector3(0.0, 5.8, 11.5) if in_arena else Vector3(0.0, 4.8, 22.0)
    var goal: Vector3 = player.global_position + offset
    camera.global_position = camera.global_position.lerp(goal, minf(1.0, 4.0 * delta))
    camera.look_at(player.global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)

    if player.global_position.y < -9.0:
        _respawn()

    if not in_arena and not game_won and player.global_position.x > 17.2:
        if not enemy_alive:
            game_won = true
            player.set("game_frozen", true)
            _flash("VICTORY — prototype traversal complete. Press R to restart.", 999999.0)
        else:
            _flash("Defeat the crimson dummy (press J near it while facing it).", 2.0)

    if _message_until > 0.0:
        _message_until -= delta
        if _message_until <= 0.0:
            _message = ""

    var state: String = "3D ARENA — WASD move / SPACE jump / K dodge / E return" if in_arena else "2.5D — A/D move / SPACE jump / K dodge / J attack / E near amber gate"
    var objective: String = "ENEMY: DEFEATED" if not enemy_alive else "ENEMY: ACTIVE"
    var arena_state: String = "ARENA: VISITED" if arena_visited else "ARENA: OPTIONAL"
    var checkpoint_state: String = "CHECKPOINT: SET" if checkpoint.is_active else "CHECKPOINT: —"
    hud.text = "BLOODBOUND — GREYBOX STARTER (not full game)\n" + state + "\n" + objective + "    " + arena_state + "    " + checkpoint_state + "\n" + _message


func _unhandled_input(event: InputEvent) -> void:
    if event.is_echo():
        return
    if event.is_action_pressed(&"restart") and game_won:
        get_tree().reload_current_scene()
        return
    if not event.is_action_pressed(&"interact") or game_won or not is_instance_valid(player):
        return
    if bool(player.get("in_3d_mode")):
        player.set("in_3d_mode", false)
        player.call("teleport_to", Vector3(14.5, 2.0, 0.0))
        _flash("Returned to 2.5D corridor.", 3.0)
    elif player.global_position.distance_to(GATE_POSITION) < 2.7:
        player.set("in_3d_mode", true)
        player.call("teleport_to", ARENA_SPAWN)
        arena_visited = true
        _flash("3D movement active. Press E to return.", 4.0)
    else:
        _flash("Approach the amber pillar at x = 13 to enter the 3D arena.", 2.0)


func _on_player_attack(origin: Vector3, facing_direction: float) -> void:
    if bool(player.get("in_3d_mode")):
        _flash("3D combat is planned, not implemented in this bootstrap.", 2.0)
        return
    if not enemy_alive:
        return
    var distance_x: float = ENEMY_POSITION.x - origin.x
    if absf(distance_x) < 2.0 and absf(ENEMY_POSITION.y - origin.y) < 1.7 and (distance_x * facing_direction) > 0.0:
        enemy_alive = false
        dummy.visible = false
        _flash("Dummy defeated! Head right to the pale EXIT marker.", 4.0)
    else:
        _flash("Miss! Face the red dummy and attack from nearby.", 1.0)


func _respawn() -> void:
    if bool(player.get("in_3d_mode")):
        player.call("teleport_to", ARENA_SPAWN)
        _flash("Fell from the arena — returned to its centre.", 3.5)
        return
    player.call("teleport_to", respawn_point)
    if checkpoint.is_active:
        _flash("Fell into the abyss — returned to the checkpoint.", 3.5)
    else:
        _flash("Fell into the abyss — returned to the safe start.", 3.5)


func _on_checkpoint_activated(reached: Checkpoint) -> void:
    respawn_point = reached.respawn_position
    _flash("Checkpoint reached.", 2.5)


func _flash(message: String, seconds: float) -> void:
    _message = message
    _message_until = seconds


func _build_greybox() -> void:
    var world_env: WorldEnvironment = WorldEnvironment.new()
    var env: Environment = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.021, 0.025, 0.039)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.29, 0.31, 0.46)
    env.ambient_light_energy = 0.75
    world_env.environment = env
    add_child(world_env)

    var moonlight: DirectionalLight3D = DirectionalLight3D.new()
    moonlight.rotation_degrees = Vector3(-45.0, -25.0, 0.0)
    moonlight.light_color = Color(0.59, 0.66, 1.0)
    moonlight.light_energy = 1.3
    add_child(moonlight)

    # Side-scrolling platforms, with a gap narrow enough for the starter jump.
    _make_solid("Starting causeway", Vector3(-13.0, -0.5, 0.0), Vector3(12.0, 1.0, 4.0), Color(0.18, 0.19, 0.23))
    _make_solid("Broken stone span", Vector3(-4.5, 0.0, 0.0), Vector3(3.0, 0.7, 3.7), Color(0.23, 0.23, 0.28))
    # Starts at x=-1.5, leaving a 1.5 m gap after the broken span (wider than the player capsule).
    _make_solid("Battle causeway", Vector3(4.0, -0.5, 0.0), Vector3(11.0, 1.0, 4.0), Color(0.17, 0.18, 0.21))
    _make_solid("Gate causeway", Vector3(13.7, -0.5, 0.0), Vector3(9.0, 1.0, 4.0), Color(0.20, 0.19, 0.23))
    _make_solid("Raised step", Vector3(0.0, 1.15, -0.2), Vector3(2.0, 0.3, 2.6), Color(0.31, 0.27, 0.29))

    # Far background silhouette: visual decoration only, NOT implemented boss AI.
    _make_visual("Distant Gothic silhouette (decorative only)", Vector3(5.0, 6.0, -22.0), Vector3(3.0, 12.0, 2.8), Color(0.10, 0.065, 0.09))
    _make_visual("Left tower", Vector3(-12.0, 5.0, -18.0), Vector3(3.5, 10.0, 3.0), Color(0.07, 0.085, 0.12))
    _make_visual("Distant tower", Vector3(11.0, 7.0, -26.0), Vector3(3.5, 14.0, 3.0), Color(0.055, 0.071, 0.09))

    checkpoint = Checkpoint.create(CHECKPOINT_POSITION)
    checkpoint.activated.connect(_on_checkpoint_activated)
    add_child(checkpoint)

    dummy = Node3D.new()
    dummy.name = "OneHitCrimsonPracticeDummy"
    dummy.position = ENEMY_POSITION
    add_child(dummy)
    _make_visual("Practice dummy mesh", Vector3.ZERO, Vector3(0.75, 1.9, 0.7), Color(0.76, 0.12, 0.22), dummy)

    _make_visual("Arena entry — amber", Vector3(13.0, 2.0, -0.5), Vector3(0.45, 4.0, 0.55), Color(0.95, 0.54, 0.12))
    _make_visual("Exit marker", Vector3(17.8, 2.0, -0.7), Vector3(0.6, 4.0, 0.6), Color(0.72, 0.88, 0.96))

    # Separate 3D training platform. Camera/motor are the same player nodes.
    _make_solid("Free-movement arena", Vector3(35.0, -0.5, 0.0), Vector3(14.0, 1.0, 14.0), Color(0.20, 0.17, 0.25))
    _make_visual("Arena obelisk", Vector3(38.0, 1.6, -3.0), Vector3(1.2, 3.2, 1.2), Color(0.35, 0.23, 0.39))
    _make_visual("Arena obelisk B", Vector3(32.0, 1.6, 3.0), Vector3(1.2, 3.2, 1.2), Color(0.28, 0.25, 0.38))


func _make_solid(label: String, center: Vector3, size: Vector3, color: Color) -> void:
    var block: StaticBody3D = StaticBody3D.new()
    block.name = label
    block.position = center
    var collision: CollisionShape3D = CollisionShape3D.new()
    var box_shape: BoxShape3D = BoxShape3D.new()
    box_shape.size = size
    collision.shape = box_shape
    block.add_child(collision)
    _make_visual(label + " appearance", Vector3.ZERO, size, color, block)
    add_child(block)


func _make_visual(label: String, center: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> void:
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    mesh_node.name = label
    mesh_node.position = center
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.1
    material.roughness = 0.9
    mesh_node.material_override = material
    if parent == null:
        parent = self
    parent.add_child(mesh_node)

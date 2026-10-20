extends Node3D
## Procedural greybox level: causeway → Plagued Soldier → portcullis → Pursuit Approach
## (collapsing slabs, moving platform, the Bishop hurling lances) → Hollow Bishop arena.
## The optional Reality Fracture (free 3D arena) is entered at the amber gate; see RealityFracture.
## Goal: easily replaceable greybox; level rules (checkpoints, resets, victory) live here.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SOLDIER_SCENE: PackedScene = preload("res://scenes/enemies/plagued_soldier.tscn")
const SPAWN_POSITION: Vector3 = Vector3(-16.0, 2.0, 0.0)
const ENEMY_POSITION: Vector3 = Vector3(5.0, 1.0, 0.0)
const GATE_POSITION: Vector3 = Vector3(13.0, 1.0, 0.0)
const CHECKPOINT_POSITION: Vector3 = Vector3(-4.5, 1.2, 0.0)
const PORTCULLIS_X: float = 18.6
const APPROACH_START_X: float = 18.2
const APPROACH_CHECKPOINT_POSITION: Vector3 = Vector3(20.6, 1.2, 0.0)
const PURSUIT_START_X: float = 20.0
const BOSS_ARENA_START_X: float = 58.2
const BOSS_CHECKPOINT_POSITION: Vector3 = Vector3(60.6, 1.2, 0.0)
const FIGHT_START_X: float = 60.0

var player: CharacterBody3D
var camera: Camera3D
var enemy: PlaguedSoldier
var checkpoint: Checkpoint
var boss_checkpoint: Checkpoint
var approach_checkpoint: Checkpoint
var collapsing_slabs: Array[CollapsingSlab] = []
var ferry: MovingPlatform
var boss: HollowBishop
var boss_arena: BossArena
var portcullis: StaticBody3D
var boss_bar: ProgressBar
var boss_label: Label
var fracture: RealityFracture
var respawn_point: Vector3 = SPAWN_POSITION
var hud: Label
var enemy_alive: bool = true
var arena_visited: bool = false
var game_won: bool = false
var _message: String = ""
var _message_until: float = 0.0
var _trauma: float = 0.0
var hurt_vignette: ColorRect


func _ready() -> void:
    InputBindings.ensure_defaults()
    GameSettings.load_settings()
    add_to_group(&"camera_shaker")
    _build_greybox()
    player = PLAYER_SCENE.instantiate() as CharacterBody3D
    player.add_to_group(&"player")
    add_child(player)
    player.global_position = SPAWN_POSITION
    player.connect("died", _on_player_died)

    camera = Camera3D.new()
    camera.name = "SideViewOrArenaCamera"
    camera.fov = 52.0
    camera.current = true
    add_child(camera)
    camera.global_position = player.global_position + Vector3(0.0, 4.8, 22.0)
    camera.look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
    fracture.teleported.connect(func(_to_3d: bool) -> void: _snap_camera())
    fracture.entered.connect(_on_fracture_entered)
    fracture.exited.connect(_on_fracture_exited)

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
    _build_boss_bar(canvas)
    hurt_vignette = ColorRect.new()
    hurt_vignette.name = "HurtVignette"
    hurt_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
    hurt_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hurt_vignette.material = _vignette_material()
    hurt_vignette.color = Color(0.7, 0.0, 0.02, 0.0)
    canvas.add_child(hurt_vignette)
    canvas.move_child(hurt_vignette, 0)
    player.connect("hurt", func(_info: DamageInfo) -> void: hurt_vignette.color.a = 0.55)
    var card_system: CardSystem = player.get_node("Cards") as CardSystem
    var card_ui: CardHandUI = CardHandUI.create(card_system)
    canvas.add_child(card_ui)
    var targeting: CardTargeting = CardTargeting.create(card_system, card_ui, camera, boss)
    targeting.hint.connect(func(text: String) -> void: _flash(text, 2.5))
    add_child(targeting)
    card_system.card_played.connect(_on_card_played)
    card_system.card_failed.connect(_on_card_failed)
    add_child(PauseMenu.create())
    _flash("Cross the causeway, defeat the plagued soldier, and face what waits beyond the gate.", 7.0)


func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    var in_arena: bool = bool(player.get("in_3d_mode"))
    camera.global_position = camera.global_position.lerp(_camera_goal(), minf(1.0, 4.0 * delta))
    camera.look_at(_camera_look_target(), Vector3.UP)
    _apply_shake(delta)
    hurt_vignette.color.a = move_toward(hurt_vignette.color.a, 0.0, 1.4 * delta)

    if player.global_position.y < -9.0:
        _respawn()

    if not in_arena and enemy_alive and player.global_position.x > PORTCULLIS_X - 1.6:
        _flash("The portcullis is sealed while the plagued soldier stands.", 1.0)
    if not in_arena and boss.phase == HollowBishop.Phase.DORMANT and player.global_position.x > PURSUIT_START_X:
        boss.awaken()
        _flash("THE HOLLOW BISHOP rises from the abyss — run for the cathedral!", 3.5)
    if not in_arena and not boss.fight_started and player.global_position.x > FIGHT_START_X:
        boss.min_x = boss_arena.left_x() + 4.0
        boss.max_x = boss_arena.right_x() - 4.0
        boss.begin_fight()
        _flash("The Bishop turns to face you. Strike the stigmata when its hand falls.", 3.5)
    _update_boss_bar()

    if _message_until > 0.0:
        _message_until -= delta
        if _message_until <= 0.0:
            _message = ""

    var state: String = "REALITY FRACTURE — WASD move / SPACE jump / J light / L heavy / K dodge / cards: 1-3 or click" if in_arena else "2.5D — A/D move / SPACE jump / J light / L heavy / K dodge / cards: 1-3 or click / E amber gate"
    var player_health: Health = player.get("health")
    # ASCII only: the web build ships just Godot's default font (no box-drawing glyphs).
    var hp: String = "HP %d/%d" % [player_health.current, player_health.max_health]
    var objective: String = "SOLDIER: DEFEATED" if not enemy_alive else "SOLDIER: %d HP" % enemy.health.current
    if not enemy_alive:
        objective = "BISHOP: SLAIN" if boss.phase == HollowBishop.Phase.DEFEATED else "GATE: OPEN"
    var arena_state: String = "FRACTURE: OPTIONAL"
    if fracture.state == RealityFracture.State.CLEARED:
        arena_state = "FRACTURE: SEALED"
    elif in_arena:
        arena_state = "GUARDIAN: DEFEATED — ENTER THE PORTAL" if fracture.portal_open else "GUARDIAN: %d HP" % fracture.guardian.health.current
    var checkpoint_state: String = "CHECKPOINT: SET" if checkpoint.is_active else "CHECKPOINT: —"
    hud.text = "BLOODBOUND — GREYBOX VERTICAL SLICE\n" + state + "\n" + hp + "    " + objective + "    " + arena_state + "    " + checkpoint_state + "\n" + _message


func _unhandled_input(event: InputEvent) -> void:
    if event.is_echo():
        return
    if event.is_action_pressed(&"restart") and game_won:
        get_tree().reload_current_scene()
        return
    if not event.is_action_pressed(&"interact") or game_won or not is_instance_valid(player):
        return
    if fracture.is_transitioning():
        return
    if bool(player.get("in_3d_mode")):
        if fracture.portal_open:
            _flash("Step into the burning portal to return.", 2.0)
        else:
            _flash("The fracture holds you until its guardian falls.", 2.0)
    elif player.global_position.distance_to(GATE_POSITION) < 2.7:
        if fracture.can_enter():
            fracture.enter(player)
        else:
            _flash("The fracture has sealed. Nothing stirs beyond the gate.", 2.0)
    else:
        _flash("Approach the amber pillar at x = 13 to enter the Reality Fracture.", 2.0)


func _on_enemy_defeated() -> void:
    enemy_alive = false
    _open_portcullis()
    _flash("The plagued soldier falls. The portcullis grinds open.", 4.0)


func _on_player_died() -> void:
    if bool(player.get("in_3d_mode")):
        # Revived where you stand (no stray death state), then the fracture expels you.
        player.call("revive_at", player.global_position)
        fracture.fail()
        _flash("The fracture rejects you. Its guardian waits to be challenged again.", 3.5)
        return
    player.call("revive_at", respawn_point)
    _reset_hazards()
    _flash("You were slain — restored at the last checkpoint.", 3.5)


func _on_fracture_entered() -> void:
    arena_visited = true
    _flash("REALITY FRACTURE — move freely on X/Z. Slay the guardian to open the way back.", 4.0)


func _on_fracture_exited(cleared: bool) -> void:
    if cleared:
        _flash("The fracture seals behind you. Blood and vigour restored.", 3.5)


func _camera_goal() -> Vector3:
    var offset: Vector3 = Vector3(0.0, 4.8, 22.0)
    if bool(player.get("in_3d_mode")):
        offset = Vector3(0.0, 5.8, 11.5)
    elif player.global_position.x > PORTCULLIS_X:
        offset = Vector3(0.0, 6.5, 24.0)  # pull back so the Bishop fits in frame
    return player.global_position + offset


func _camera_look_target() -> Vector3:
    var in_boss_arena: bool = not bool(player.get("in_3d_mode")) and player.global_position.x > PORTCULLIS_X
    return player.global_position + Vector3(0.0, 4.0 if in_boss_arena else 1.2, 0.0)


## Called while the fracture fade is fully black: jump the camera to its new framing.
func _snap_camera() -> void:
    camera.global_position = _camera_goal() + Vector3(0.0, 1.5, 3.0)  # slightly wide, then eases in
    camera.look_at(_camera_look_target(), Vector3.UP)


## Spell out *why* a card was refused, so a refusal never reads as "the card is broken".
func _on_card_failed(card: CardData, _slot: int, reason: StringName) -> void:
    if card == null:
        return
    var why: String = ""
    match reason:
        &"no_target":
            match card.targeting:
                CardData.Targeting.ENEMY, CardData.Targeting.BOSS_WEAK_POINT:
                    why = "no enemy or exposed stigmata within %d m" % int(card.card_range)
                CardData.Targeting.BOSS_TELEGRAPH:
                    why = "only while the Bishop's hand is winding up a strike"
                _:
                    why = "no target"
        &"out_of_range":
            why = "target is beyond %d m — move closer" % int(card.card_range)
        &"not_exposed":
            why = "the stigmata is sealed — wait for the Bishop's hand to fall onto the causeway"
        &"energy":
            why = "needs %d blood (land hits to earn more)" % card.cost
        &"cooldown":
            why = "still recovering"
        &"blocked":
            why = "you cannot act right now"
    _flash("%s: %s" % [card.display_name, why], 2.0)


func _on_card_played(card: CardData, _slot: int) -> void:
    _flash(card.display_name.to_upper() + "!", 1.5)


func _on_boss_defeated() -> void:
    game_won = true
    player.set("game_frozen", true)
    _flash("VICTORY — the Hollow Bishop is unmade. Press R to restart.", 999999.0)


func _on_sunder_impact(x: float) -> void:
    if boss_arena.break_at(x):
        _flash("The causeway shatters! Jump the gap or drop to the rubble.", 2.5)


## Death and falls reset every temporary hazard so the route is always recoverable.
func _reset_hazards() -> void:
    boss_arena.restore_all()
    for slab: CollapsingSlab in collapsing_slabs:
        slab.restore()
    boss.on_player_respawn()


func _open_portcullis() -> void:
    (portcullis.get_child(0) as CollisionShape3D).set_deferred(&"disabled", true)
    var tween: Tween = create_tween()
    tween.tween_property(portcullis, "position:y", 6.5, 1.2).set_ease(Tween.EASE_OUT)


## Red edges, clear centre: the screen "bleeds" when the player is hit.
static func _vignette_material() -> ShaderMaterial:
    var shader: Shader = Shader.new()
    shader.code = """
shader_type canvas_item;
void fragment() {
    vec2 d = UV - vec2(0.5);
    float edge = smoothstep(0.28, 0.75, length(d * vec2(1.25, 1.0)));
    COLOR = vec4(COLOR.rgb, COLOR.a * edge);
}
"""
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = shader
    return material


func _build_boss_bar(canvas: CanvasLayer) -> void:
    var box: VBoxContainer = VBoxContainer.new()
    box.name = "BossBar"
    box.anchor_left = 0.5
    box.anchor_right = 0.5
    box.anchor_top = 1.0
    box.anchor_bottom = 1.0
    box.offset_left = -240.0
    box.offset_right = 240.0
    box.offset_top = -86.0
    box.offset_bottom = -24.0
    box.visible = false
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(box)
    boss_label = Label.new()
    boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_label.add_theme_font_size_override("font_size", 18)
    boss_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.8))
    box.add_child(boss_label)
    boss_bar = ProgressBar.new()
    boss_bar.custom_minimum_size = Vector2(480, 18)
    boss_bar.show_percentage = false
    boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var fill: StyleBoxFlat = StyleBoxFlat.new()
    fill.bg_color = Color(0.62, 0.05, 0.08)
    var back: StyleBoxFlat = StyleBoxFlat.new()
    back.bg_color = Color(0.08, 0.05, 0.06, 0.85)
    back.border_color = Color(0.5, 0.42, 0.36)
    back.set_border_width_all(2)
    boss_bar.add_theme_stylebox_override("fill", fill)
    boss_bar.add_theme_stylebox_override("background", back)
    box.add_child(boss_bar)


func _update_boss_bar() -> void:
    var box: Control = boss_bar.get_parent() as Control
    box.visible = boss.is_active() or (boss.phase == HollowBishop.Phase.INTRO and boss.fight_started)
    boss_bar.max_value = boss.health.max_health
    boss_bar.value = boss.health.current
    boss_label.text = "THE HOLLOW BISHOP — " + boss.phase_title()


## Called through the "camera_shaker" group by HitFeedback.
func add_trauma(amount: float) -> void:
    _trauma = minf(1.0, _trauma + amount)


func _apply_shake(delta: float) -> void:
    _trauma = maxf(0.0, _trauma - 2.2 * delta)
    var power: float = _trauma * _trauma * 0.35 * GameSettings.camera_shake
    camera.h_offset = randf_range(-1.0, 1.0) * power
    camera.v_offset = randf_range(-1.0, 1.0) * power


func _respawn() -> void:
    if bool(player.get("in_3d_mode")):
        player.call("teleport_to", fracture.spawn_point)
        _flash("Fell from the arena — returned to its centre.", 3.5)
        return
    player.call("teleport_to", respawn_point)
    _reset_hazards()
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

    enemy = SOLDIER_SCENE.instantiate() as PlaguedSoldier
    enemy.position = ENEMY_POSITION
    enemy.defeated.connect(_on_enemy_defeated)
    add_child(enemy)

    _make_visual("Arena entry — amber", Vector3(13.0, 2.0, -0.5), Vector3(0.45, 4.0, 0.55), Color(0.95, 0.54, 0.12))

    # Portcullis: sealed until the soldier dies, so the boss is always met in order.
    portcullis = StaticBody3D.new()
    portcullis.name = "Portcullis"
    portcullis.position = Vector3(PORTCULLIS_X, 2.5, 0.0)
    var bars: CollisionShape3D = CollisionShape3D.new()
    var bars_shape: BoxShape3D = BoxShape3D.new()
    bars_shape.size = Vector3(0.4, 5.0, 4.0)
    bars.shape = bars_shape
    portcullis.add_child(bars)
    add_child(portcullis)
    _make_visual("Portcullis bars", Vector3.ZERO, Vector3(0.3, 5.0, 3.6), Color(0.32, 0.3, 0.34), portcullis)

    _build_approach()

    # The Hollow Bishop's causeway and the colossus itself, 22 m behind the play plane.
    boss_arena = BossArena.new()
    boss_arena.name = "BossArena"
    add_child(boss_arena)
    boss_arena.build(BOSS_ARENA_START_X)
    _make_solid("Cathedral door", Vector3(boss_arena.right_x() + 0.6, 3.0, 0.0), Vector3(1.2, 7.0, 4.0), Color(0.14, 0.1, 0.12))
    boss_checkpoint = Checkpoint.create(BOSS_CHECKPOINT_POSITION)
    boss_checkpoint.name = "BossCheckpoint"
    boss_checkpoint.activated.connect(_on_checkpoint_activated)
    add_child(boss_checkpoint)
    boss = HollowBishop.new()
    boss.name = "HollowBishop"
    boss.position = Vector3(32.0, 0.0, -22.0)
    # While it stalks the approach it follows the player across this span.
    boss.min_x = APPROACH_START_X + 6.0
    boss.max_x = BOSS_ARENA_START_X - 2.0
    add_child(boss)
    boss.defeated.connect(_on_boss_defeated)
    boss.sunder_impact.connect(_on_sunder_impact)

    # Reality Fracture: the optional free-movement chapel, off the main play plane.
    fracture = RealityFracture.new()
    fracture.name = "RealityFracture"
    add_child(fracture)


## The Pursuit Approach between the portcullis and the arena (x 18.2 → 58.2).
## Route: causeway → three collapsing slabs over a pit (1 m gaps) → landing → moving platform
## across a 10 m gap → arena threshold. Every jump fits the ~5.6 m running jump; falling
## respawns at the approach checkpoint and restores the slabs.
func _build_approach() -> void:
    _make_solid("Approach causeway", Vector3(22.2, -0.5, 0.0), Vector3(8.0, 1.0, 4.0), Color(0.19, 0.18, 0.22))
    approach_checkpoint = Checkpoint.create(APPROACH_CHECKPOINT_POSITION)
    approach_checkpoint.name = "ApproachCheckpoint"
    approach_checkpoint.activated.connect(_on_checkpoint_activated)
    add_child(approach_checkpoint)
    for i in 3:
        var slab: CollapsingSlab = CollapsingSlab.create("Collapsing slab %d" % i, Vector3(28.45 + 3.5 * i, -0.5, 0.0), Vector3(2.5, 1.0, 4.0))
        add_child(slab)
        collapsing_slabs.append(slab)
    _make_solid("Approach landing", Vector3(40.7, -0.5, 0.0), Vector3(6.0, 1.0, 4.0), Color(0.18, 0.17, 0.21))
    ferry = MovingPlatform.create("Bone ferry", Vector3(45.25, -0.3, 0.0), Vector3(52.15, -0.3, 0.0), Vector3(3.0, 0.6, 4.0))
    add_child(ferry)
    _make_solid("Arena threshold", Vector3(55.95, -0.5, 0.0), Vector3(4.5, 1.0, 4.0), Color(0.19, 0.17, 0.2))


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

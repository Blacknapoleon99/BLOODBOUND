class_name HollowBishop
extends Node3D
## The Hollow Bishop: a ~30 m skeletal colossus standing `depth` metres behind the play plane.
## It cannot be reached directly; it attacks *through* depth and exposes a weak point in reach.
##
## Phases (fight phases driven by HP, never by a timer):
##   DORMANT → INTRO (rises, `intro_time`) → PURSUIT (stalks the approach, single Bone Lances every
##   `pursuit_interval` s, cannot be damaged, no HP bar) → begin_fight() →
##   PROCESSION (HP > collapse_at): Hand Slam / Bone Lances
##   → COLLAPSE (HP <= collapse_at): + Sunder (breaks the causeway), Censer Sweep, Grasping Dead
##   → COVENANT (HP <= covenant_at): + Requiem Beam; faster, longer weak-point windows
##   → UNMAKING (HP <= unmaking_at): desperation — relentless, but the stigmata stays open longest
##   → DEFEATED (HP 0).
## Entering a new fight phase triggers a ROAR (`roar_time` s): the current attack is dropped, the
## Bishop shudders and starts nothing, and the level shows the phase title.
##
## Attacks (all telegraphed on the Z=0 plane before anything can hurt):
##   Hand Slam: the hand hovers at depth over a fixed x with a red floor plate (`slam_telegraph` s),
##     crashes through to Z=0 (hitbox live `impact_time` s, 2 dmg), then lies on the causeway with
##     its stigmata exposed (`weak_window` s) — the only time the Bishop can be damaged.
##   Sunder: Hand Slam with a longer telegraph that also asks the arena to break that segment.
##   Bone Lances: up to three lances thrown from depth at fixed x lanes, each with a red column.
##   Censer Sweep (CenserSweep): knee-high censer sweeps the causeway — jump it.
##   Requiem Beam (RequiemBeam): heart beam sweeps the causeway too fast to outrun — dodge through.
##   Grasping Dead: raises up to `max_minions` Husks (weak Plagued Soldiers) onto the causeway.
##
## Ritual Chains (card): while a Slam/Sunder is still aiming or hovering (before the descent),
##   `interrupt_with_chains()` cancels it — the hand is dragged down to its marked spot with no
##   hitbox (and no causeway break) and the stigmata is exposed for the card's duration.
##
## Debug/test hooks: `ai_enabled` (stop choosing attacks), `debug_attack(name, x)` (run one
## attack now), `awaken()`. Hit/phase logic is identical whether an attack came from AI or debug.

signal phase_changed(phase_name: String)
signal attack_started(attack: StringName)
signal weak_point_changed(open: bool)
signal sunder_impact(x: float)
signal chained
signal defeated

enum Phase { DORMANT, INTRO, PURSUIT, PROCESSION, COLLAPSE, COVENANT, UNMAKING, DEFEATED }

const ACTOR_ATTACKS: Array[StringName] = [&"censer", &"beam"]
const ALL_ATTACKS: Array[StringName] = [&"slam", &"sunder", &"lance", &"lance_volley", &"censer", &"beam", &"summon"]

const PHASE_TITLES: Dictionary = {
    Phase.PROCESSION: "I · THE PROCESSION",
    Phase.COLLAPSE: "II · THE COLLAPSE",
    Phase.COVENANT: "III · THE COVENANT",
    Phase.UNMAKING: "IV · THE UNMAKING",
}

## Optimal held-combo spam deals ~9 per weak-point window, so 90 HP is at least ten windows of
## pure melee across four phases; spears, Epitaph and Husk blood shorten it for good play.
@export var max_health: int = 90
@export var collapse_at: int = 65
@export var covenant_at: int = 35
@export var unmaking_at: int = 12
@export var max_minions: int = 2
@export var depth: float = -22.0
@export var min_x: float = 22.0
@export var max_x: float = 42.0
@export var engage_min_x: float = 18.6
@export var ai_enabled: bool = true
@export_group("Timing")
@export var intro_time: float = 1.5
@export var aim_time: float = 0.4
@export var slam_telegraph: float = 1.0
@export var sunder_telegraph: float = 1.3
@export var descent_time: float = 0.15
@export var impact_time: float = 0.12
@export var weak_window: float = 2.5
@export var covenant_weak_window: float = 4.0
@export var unmaking_weak_window: float = 5.0
@export var roar_time: float = 1.8
@export var summon_time: float = 1.2
@export var retract_time: float = 0.6
@export var lance_speed: float = 16.0
@export var lance_spacing: float = 0.5
@export var chain_pull_time: float = 0.3
@export var pursuit_interval: float = 3.2

var phase: Phase = Phase.DORMANT
var health: Health
var hand: BishopHand
var weak_open_seconds: float = 0.0
## True once the player has reached the arena; INTRO then leads straight into the fight.
var fight_started: bool = false
## Set by the level while an ambush holds the player: pursuit lances wait.
var pursuit_hold: bool = false

var _attack: StringName = &""
var _t: float = 0.0
var _target_x: float = 0.0
var _impact_done: bool = false
var _lance_plan: Array[float] = []
var _lance_index: int = 0
var _cooldown: float = 2.0
var _pattern_index: int = 0
var _intro_t: float = 0.0
var _arm: MeshInstance3D
var _heart_material: StandardMaterial3D
var _rest_y: float = 0.0
var _chain_from: Vector3
var _chain_window: float = 3.0
var _actor: Node3D
var _roar_left: float = 0.0
var _heart: MeshInstance3D
var _summon_spots: Array[float] = []
var _summon_markers: Array[MeshInstance3D] = []


func _ready() -> void:
    add_to_group(&"interruptible")
    add_to_group(&"silenceable")
    health = Health.new()
    health.name = "Health"
    health.max_health = max_health
    add_child(health)
    health.changed.connect(_on_health_changed)
    _build_body()
    hand = BishopHand.create(health)
    add_child(hand)
    hand.weak_point.hit_received.connect(_on_weak_point_hit)
    _rest_y = position.y
    position.y = _rest_y - 14.0  # sunk in the abyss until awakened
    visible = false  # its sunk silhouette would otherwise poke into early camera shots
    hand.global_position = _hand_rest()
    _update_arm()


# --- Public API -------------------------------------------------------------------

func phase_name() -> String:
    return Phase.keys()[phase]


func phase_title() -> String:
    return PHASE_TITLES.get(phase, "")


func is_active() -> bool:
    return phase in [Phase.PROCESSION, Phase.COLLAPSE, Phase.COVENANT, Phase.UNMAKING]


func is_roaring() -> bool:
    return _roar_left > 0.0


func minions() -> Array[Node]:
    return get_tree().get_nodes_in_group(&"bishop_minion").filter(func(m: Node) -> bool: return not m.is_queued_for_deletion() and not bool(m.call("is_dead")))


func attack_actor() -> Node3D:
    return _actor if is_instance_valid(_actor) else null


func is_attacking() -> bool:
    return _attack != &""


func current_attack() -> StringName:
    return _attack


func awaken() -> void:
    if phase == Phase.DORMANT:
        _intro_t = 0.0
        visible = true
        _set_phase(Phase.INTRO)


## Ends the pursuit and starts the HP-driven fight (awakens first if still dormant).
func begin_fight() -> void:
    fight_started = true
    if phase == Phase.DORMANT:
        awaken()
    elif phase == Phase.PURSUIT:
        _set_phase(_phase_for_health())
        _cooldown = 2.0


func set_ai_enabled(enabled: bool) -> void:
    ai_enabled = enabled


## Starts any attack in ALL_ATTACKS aimed at `x` right away (ends a roar early).
func debug_attack(attack: StringName, x: float) -> bool:
    _roar_left = 0.0
    return _start_attack(attack, x)


## Bell of Silence: a slam/sunder still in its telegraph, or a lance volley still being thrown,
## is cancelled (no weak point is opened — that is Ritual Chains' job), and no new attack starts
## for `seconds`.
func silence(seconds: float) -> void:
    if not (is_active() or phase == Phase.PURSUIT):
        return
    var cancellable: bool = can_be_interrupted() or ((_attack == &"lance" or _attack == &"lance_volley") and _lance_index < _lance_plan.size())
    cancellable = cancellable or (_attack in ACTOR_ATTACKS and attack_actor() != null and bool(_actor.call("is_telegraphing")))
    cancellable = cancellable or (_attack == &"summon" and _t < summon_time)
    if cancellable:
        _cancel_attack()
    _cooldown = maxf(_cooldown, seconds)


## True while a Slam/Sunder has not started its descent (the telegraph window).
func can_be_interrupted() -> bool:
    if not is_active() or not (_attack == &"slam" or _attack == &"sunder"):
        return false
    return _t < _slam_timeline()[1]


func interrupt_with_chains(window: float) -> bool:
    if not can_be_interrupted():
        return false
    _chain_from = hand.global_position
    _chain_window = window
    _attack = &"chained"
    _t = 0.0
    hand.show_telegraph(_target_x, false)
    chained.emit()
    return true


## Called by the level when the player respawns: drop the current attack and give breathing room.
func on_player_respawn() -> void:
    _cancel_attack()
    clear_minions()
    _cooldown = 2.0


func clear_minions() -> void:
    for minion: Node in get_tree().get_nodes_in_group(&"bishop_minion"):
        minion.queue_free()


# --- Loop ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
    match phase:
        Phase.DORMANT:
            return
        Phase.INTRO:
            _intro_t += delta
            position.y = lerpf(_rest_y - 14.0, _rest_y, clampf(_intro_t / intro_time, 0.0, 1.0))
            if _intro_t >= intro_time:
                _set_phase(_phase_for_health() if fight_started else Phase.PURSUIT)
                _cooldown = 2.0
        Phase.DEFEATED:
            position.y = move_toward(position.y, _rest_y - 40.0, 8.0 * delta)
            hand.global_position = hand.global_position.move_toward(_hand_rest(), 6.0 * delta)
            _update_arm()
            return

    if _roar_left > 0.0:
        _roar_left -= delta
        # Shudder in place; nothing new starts until the roar ends.
        position.x += randf_range(-0.08, 0.08)
        hand.global_position = hand.global_position.move_toward(_hand_rest(), 10.0 * delta)
        get_tree().call_group(&"camera_shaker", &"add_trauma", 0.6 * delta)
        _update_arm()
        _pulse_heart()
        return

    var player: Node3D = _engaged_player()
    if player != null and not is_attacking():
        position.x = move_toward(position.x, clampf(player.global_position.x, min_x, max_x), 2.5 * delta)

    if is_attacking():
        if _attack == &"slam" or _attack == &"sunder":
            _tick_slam(delta)
        elif _attack == &"chained":
            _tick_chained(delta)
        elif _attack in ACTOR_ATTACKS:
            _tick_actor(delta)
        elif _attack == &"summon":
            _tick_summon(delta)
        else:
            _tick_lances(delta)
    else:
        hand.global_position = hand.global_position.move_toward(_hand_rest(), 10.0 * delta)
        if ai_enabled and is_active() and player != null:
            _cooldown -= delta
            if _cooldown <= 0.0:
                _start_attack(_next_pattern_attack(), player.global_position.x)
        elif ai_enabled and phase == Phase.PURSUIT and player != null and not pursuit_hold:
            _cooldown -= delta
            if _cooldown <= 0.0:
                _start_attack(&"lance", player.global_position.x)
    _update_arm()
    _pulse_heart()


func _engaged_player() -> Node3D:
    var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
    if player == null or bool(player.get("in_3d_mode")) or player.global_position.x < engage_min_x:
        return null
    var player_health: Health = player.get("health") as Health
    if player_health and player_health.is_dead():
        return null
    return player


func _next_pattern_attack() -> StringName:
    var pattern: Array = [&"slam", &"lance_volley"]
    match phase:
        Phase.COLLAPSE:
            pattern = [&"summon", &"sunder", &"censer", &"lance_volley", &"slam"]
        Phase.COVENANT:
            pattern = [&"summon", &"beam", &"slam", &"censer", &"lance_volley", &"sunder"]
        Phase.UNMAKING:
            pattern = [&"beam", &"slam", &"censer", &"lance_volley", &"slam"]
    var attack: StringName = pattern[_pattern_index % pattern.size()]
    _pattern_index += 1
    if attack == &"summon" and minions().size() >= max_minions:
        attack = pattern[_pattern_index % pattern.size()]
        _pattern_index += 1
    return attack


func _start_attack(attack: StringName, x: float) -> bool:
    if is_attacking():
        return false
    var pursuit_lance: bool = phase == Phase.PURSUIT and attack == &"lance"
    if not is_active() and not pursuit_lance:
        return false
    if attack not in ALL_ATTACKS:
        return false
    if attack == &"summon" and minions().size() >= max_minions:
        return false
    _attack = attack
    _t = 0.0
    _impact_done = false
    _target_x = x
    if attack == &"lance":
        _lance_plan = [x]
    elif attack == &"lance_volley":
        _lance_plan = [x, x - 3.5, x + 3.5]
    _lance_index = 0
    if attack in ACTOR_ATTACKS:
        # Sweep from the far end toward (and past) the player.
        var left: float = min_x - 3.5
        var right: float = max_x + 3.5
        var start_x: float = right if x - left < right - x else left
        var end_x: float = left if start_x == right else right
        _actor = CenserSweep.create(self, start_x, end_x) if attack == &"censer" else RequiemBeam.create(_heart, start_x, end_x)
        add_child(_actor)
    elif attack == &"summon":
        _summon_spots = []
        for offset: float in [-4.0, 4.0]:
            _summon_spots.append(clampf(x + offset, min_x - 3.0, max_x + 3.0))
        for spot: float in _summon_spots:
            var marker: MeshInstance3D = MeshInstance3D.new()
            var mesh: CylinderMesh = CylinderMesh.new()
            mesh.top_radius = 0.8
            mesh.bottom_radius = 0.8
            mesh.height = 0.04
            marker.mesh = mesh
            marker.material_override = BishopHand._warning_material()
            marker.top_level = true
            add_child(marker)
            marker.global_position = Vector3(spot, 0.03, 0.0)
            _summon_markers.append(marker)
    attack_started.emit(attack)
    return true


func _finish_attack() -> void:
    _attack = &""
    _actor = null
    match phase:
        Phase.UNMAKING:
            _cooldown = 0.7
        Phase.COVENANT:
            _cooldown = 1.0
        Phase.COLLAPSE:
            _cooldown = 1.5
        _:
            _cooldown = 1.8
    if phase == Phase.PURSUIT:
        _cooldown = pursuit_interval - 1.9  # a lance attack itself lasts ~1.9 s


func _cancel_attack() -> void:
    hand.hitbox.deactivate()
    hand.show_telegraph(_target_x, false)
    if hand.weak_open:
        hand.set_weak(false)
        weak_point_changed.emit(false)
    for lance: Node in get_tree().get_nodes_in_group(&"boss_lance"):
        lance.queue_free()
    if attack_actor() != null:
        _actor.call("cancel")
    _actor = null
    _clear_summon_markers()
    _attack = &""


# --- Hand Slam / Sunder ---------------------------------------------------------

func _slam_timeline() -> PackedFloat32Array:
    var telegraph: float = sunder_telegraph if _attack == &"sunder" else slam_telegraph
    var weak: float = weak_window
    if phase == Phase.COVENANT:
        weak = covenant_weak_window
    elif phase == Phase.UNMAKING:
        weak = unmaking_weak_window
    var t0: float = aim_time
    var t1: float = t0 + telegraph
    var t2: float = t1 + descent_time
    var t3: float = t2 + impact_time
    var t4: float = t3 + weak
    var t5: float = t4 + retract_time
    return PackedFloat32Array([t0, t1, t2, t3, t4, t5])


func _tick_slam(delta: float) -> void:
    _t += delta
    var tl: PackedFloat32Array = _slam_timeline()
    var rest: Vector3 = _hand_rest()
    var hover: Vector3 = Vector3(_target_x, 9.0, -8.0)
    var impact: Vector3 = Vector3(_target_x, 0.55, 0.0)
    hand.show_telegraph(_target_x, _t < tl[2])
    if _t < tl[0]:
        hand.global_position = rest.lerp(hover, _t / tl[0])
    elif _t < tl[1]:
        hand.global_position = hover
    elif _t < tl[2]:
        hand.global_position = hover.lerp(impact, (_t - tl[1]) / (tl[2] - tl[1]))
    elif _t < tl[3]:
        hand.global_position = impact
        if not _impact_done:
            _impact_done = true
            hand.hitbox.activate()
            Audio.sfx(&"bishop_slam", 0.04)
            get_tree().call_group(&"camera_shaker", &"add_trauma", 0.6)
            if _attack == &"sunder":
                sunder_impact.emit(_target_x)
    elif _t < tl[4]:
        hand.global_position = impact
        if hand.hitbox.is_active():
            hand.hitbox.deactivate()
        if not hand.weak_open:
            weak_open_seconds = 0.0
            hand.set_weak(true)
            weak_point_changed.emit(true)
        weak_open_seconds += delta
    elif _t < tl[5]:
        if hand.weak_open:
            hand.set_weak(false)
            weak_point_changed.emit(false)
        hand.global_position = impact.lerp(rest, (_t - tl[4]) / (tl[5] - tl[4]))
    else:
        _finish_attack()


## Chained: pulled to the marked spot with no hitbox, stigmata exposed, then released.
func _tick_chained(delta: float) -> void:
    _t += delta
    var impact: Vector3 = Vector3(_target_x, 0.55, 0.0)
    var t_open: float = chain_pull_time
    var t_close: float = t_open + _chain_window
    var t_end: float = t_close + retract_time
    if _t < t_open:
        hand.global_position = _chain_from.lerp(impact, _t / t_open)
    elif _t < t_close:
        hand.global_position = impact
        if not hand.weak_open:
            weak_open_seconds = 0.0
            hand.set_weak(true)
            weak_point_changed.emit(true)
        weak_open_seconds += delta
    elif _t < t_end:
        if hand.weak_open:
            hand.set_weak(false)
            weak_point_changed.emit(false)
        hand.global_position = impact.lerp(_hand_rest(), (_t - t_close) / retract_time)
    else:
        _finish_attack()


# --- Censer / Beam actors and Grasping Dead -------------------------------------

func _tick_actor(delta: float) -> void:
    _t += delta
    # The arm hangs back while the actor (censer, beam) does the work.
    hand.global_position = hand.global_position.move_toward(_hand_rest(), 10.0 * delta)
    if attack_actor() == null or bool(_actor.get("done")):
        _finish_attack()


func _tick_summon(delta: float) -> void:
    _t += delta
    _heart_material.emission = Color(0.6, 1.0, 0.7) * (1.0 + sin(_t * 20.0))
    if _t >= summon_time and not _summon_spots.is_empty():
        for spot: float in _summon_spots:
            if minions().size() < max_minions:
                _spawn_husk(spot)
        _summon_spots.clear()
        _clear_summon_markers()
    if _t >= summon_time + 0.3:
        _finish_attack()


## A Husk (see EnemyFactory) clawing up from the causeway; roams the whole arena.
func _spawn_husk(x: float) -> void:
    var husk: PlaguedSoldier = EnemyFactory.husk(get_parent(), x, min_x - 3.0, max_x + 3.0)
    husk.add_to_group(&"bishop_minion")


func _clear_summon_markers() -> void:
    for marker: MeshInstance3D in _summon_markers:
        if is_instance_valid(marker):
            marker.queue_free()
    _summon_markers.clear()


# --- Bone Lances ---------------------------------------------------------------

func _tick_lances(delta: float) -> void:
    _t += delta
    # Raise the throwing hand behind the boss while the volley lasts.
    hand.global_position = hand.global_position.move_toward(global_position + Vector3(4.0, 14.0, 1.0), 20.0 * delta)
    var next_spawn: float = 0.3 + lance_spacing * _lance_index
    if _lance_index < _lance_plan.size() and _t >= next_spawn:
        var x: float = clampf(_lance_plan[_lance_index], engage_min_x + 0.5, max_x + 3.5)
        var lance: BoneLance = BoneLance.create(x, depth + 1.0, lance_speed)
        add_child(lance)
        _lance_index += 1
    var travel: float = absf(depth) / lance_speed
    if _lance_index >= _lance_plan.size() and _t >= next_spawn - lance_spacing + travel + 0.5:
        _finish_attack()


# --- Health / phases ----------------------------------------------------------

func _phase_for_health() -> Phase:
    if health.current <= 0:
        return Phase.DEFEATED
    if health.current <= unmaking_at:
        return Phase.UNMAKING
    if health.current <= covenant_at:
        return Phase.COVENANT
    if health.current <= collapse_at:
        return Phase.COLLAPSE
    return Phase.PROCESSION


func _on_health_changed(_current: int, _maximum: int) -> void:
    if phase in [Phase.DORMANT, Phase.INTRO, Phase.PURSUIT, Phase.DEFEATED]:
        return
    var next: Phase = _phase_for_health()
    if next == Phase.DEFEATED:
        _cancel_attack()
        clear_minions()
        _roar_left = 0.0
        _set_phase(Phase.DEFEATED)
        defeated.emit()
    elif next != phase:
        _cancel_attack()
        _roar_left = roar_time
        _set_phase(next)


func _on_weak_point_hit(_info: DamageInfo) -> void:
    _heart_material.emission = Color(1.0, 0.9, 0.8) * 3.0


func _set_phase(next: Phase) -> void:
    if phase == next:
        return
    phase = next
    _pattern_index = 0
    phase_changed.emit(phase_name())


# --- Visuals ------------------------------------------------------------------

func _hand_rest() -> Vector3:
    return global_position + Vector3(5.5, 4.0, 3.0)


func _build_body() -> void:
    var robe: StandardMaterial3D = _material(Color(0.09, 0.07, 0.09))
    var bone: StandardMaterial3D = _material(Color(0.66, 0.62, 0.53))
    var crimson: StandardMaterial3D = _material(Color(0.42, 0.04, 0.07))
    _add_box("Robe", Vector3(7.0, 22.0, 4.0), Vector3(0.0, -1.0, 0.0), robe)
    for i in 5:
        _add_box("Rib%d" % i, Vector3(5.2 - 0.5 * i, 0.35, 0.5), Vector3(0.0, 8.5 - 1.1 * i, 2.1), bone)
    _add_box("Spine", Vector3(0.6, 7.0, 0.5), Vector3(0.0, 6.5, 2.0), bone)
    _add_box("Shoulders", Vector3(10.0, 1.4, 3.0), Vector3(0.0, 9.6, 0.0), bone)
    _add_box("Mitre", Vector3(2.6, 4.2, 1.6), Vector3(0.0, 16.4, 0.0), crimson)
    _add_box("LeftArm", Vector3(0.9, 9.0, 0.9), Vector3(-5.2, 5.2, 0.6), bone)
    var skull: MeshInstance3D = MeshInstance3D.new()
    skull.name = "Skull"
    var skull_mesh: SphereMesh = SphereMesh.new()
    skull_mesh.radius = 2.3
    skull_mesh.height = 5.0
    skull.mesh = skull_mesh
    skull.material_override = bone
    skull.position = Vector3(0.0, 12.6, 0.3)
    add_child(skull)
    var eye_material: StandardMaterial3D = _material(Color(1.0, 0.2, 0.1))
    eye_material.emission_enabled = true
    eye_material.emission = Color(1.0, 0.15, 0.05) * 2.5
    for side: float in [-0.8, 0.8]:
        _add_box("Eye", Vector3(0.6, 0.4, 0.3), Vector3(side, 12.9, 2.5), eye_material)
    _heart_material = _material(Color(0.5, 0.04, 0.08))
    _heart_material.emission_enabled = true
    _heart_material.emission = Color(0.6, 0.03, 0.06)
    var heart: MeshInstance3D = MeshInstance3D.new()
    _heart = heart
    heart.name = "Heart"
    var heart_mesh: SphereMesh = SphereMesh.new()
    heart_mesh.radius = 0.9
    heart_mesh.height = 1.8
    heart.mesh = heart_mesh
    heart.material_override = _heart_material
    heart.position = Vector3(0.0, 6.8, 1.6)
    add_child(heart)
    _arm = MeshInstance3D.new()
    _arm.name = "SlamArm"
    _arm.top_level = true
    var arm_mesh: BoxMesh = BoxMesh.new()
    arm_mesh.size = Vector3(0.8, 0.8, 1.0)
    _arm.mesh = arm_mesh
    _arm.material_override = bone
    add_child(_arm)


func _update_arm() -> void:
    var shoulder: Vector3 = global_position + Vector3(4.8, 9.4, 0.5)
    var wrist: Vector3 = hand.global_position + Vector3(0.0, 0.3, -1.0)
    var span: Vector3 = wrist - shoulder
    if span.length() < 0.1:
        return
    var up: Vector3 = Vector3.UP if absf(span.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
    var basis_to: Basis = Basis.looking_at(span, up).scaled_local(Vector3(1.0, 1.0, span.length()))
    _arm.global_transform = Transform3D(basis_to, shoulder + span * 0.5)


func _pulse_heart() -> void:
    var target: Color = Color(1.0, 0.1, 0.15) * 2.0 if hand.weak_open else Color(0.6, 0.03, 0.06)
    _heart_material.emission = _heart_material.emission.lerp(target, 0.1)


func _add_box(label: String, box_size: Vector3, at: Vector3, material: Material) -> void:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = label
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = box_size
    node.mesh = mesh
    node.material_override = material
    node.position = at
    add_child(node)


static func _material(color: Color) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.85
    return material

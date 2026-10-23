extends CharacterBody3D
## Player motor: platforming feel, dodge, attacks and hit reactions. Damage resolution
## lives in Health/Hurtbox/Hitbox; checkpoints and respawn live in the level (main.gd).
## Z=0 in platforming mode. 3D mode unlocks Z movement with the same body.
##
## Timing semantics (all in seconds):
## - Coyote time: jump still allowed for `coyote_time` after walking off a ledge.
## - Jump buffer: a press up to `jump_buffer_time` before landing jumps on landing.
## - Variable jump: releasing jump while rising multiplies upward speed by `jump_cut_factor`.
## - Dodge: `dodge_duration` burst along facing/input; invulnerable for `dodge_invulnerable_time`
##   from the start of the dodge; usable again after `dodge_cooldown`; one dodge per airtime.
## - Light attack is a 3-step combo (AttackData.next_combo): pressing again — or simply holding
##   the button — within `combo_window` of the previous step continues the chain.
## - Melee is manual: left click / J for the light combo (hold to chain), right click / L heavy.
## - Attacks (see AttackData): no jumping, turning or new attacks until the attack ends.
##   An attack pressed while busy is buffered for `attack_buffer_time` and starts on the
##   first free frame (only the latest press is kept).
##   Only RECOVERY may be cancelled into a dodge, and only if the attack allows it.
## - Getting hit: cancels any attack, applies knockback, `hurt_stun` without control,
##   then `hurt_invulnerable_time` of invulnerability (from the moment of the hit).

signal jumped
## Full-3D moveset events (PlatformerMotor): &"skid", &"jump_<kind>", &"wall_slide",
## &"ledge_grab", &"pull_up", &"pound_start", &"pound_land" — for sound, camera and tests.
signal move_event(name: StringName)
signal blinked(from: Vector3, to: Vector3)
signal landed
signal dodge_started(direction: Vector3)
signal dodge_refused
signal attack_started(attack_id: StringName)
signal hurt(info: DamageInfo)
signal blocked(info: DamageInfo)
signal died
## Emitted after every teleport/respawn: the animator drops any action or pose it was holding.
signal teleported

@export_group("Run")
@export var move_speed: float = 8.5
@export var ground_acceleration: float = 60.0
@export var ground_deceleration: float = 70.0
@export var air_acceleration: float = 36.0
## Used while input opposes the current velocity (a turnaround), on the ground / in the air.
@export var turn_acceleration: float = 160.0
@export var air_turn_acceleration: float = 70.0

@export_group("Jump")
@export var jump_speed: float = 9.5
@export var rise_gravity: float = 22.0
@export var fall_gravity: float = 30.0
@export var max_fall_speed: float = 24.0
@export var jump_cut_factor: float = 0.45
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12

@export_group("Full 3D motor")
## Used only in full 3D (a ThirdPersonCamera assigned); the side-view game keeps the values above.
## Ground: speed changes at `accel3d`, direction ROTATES toward the stick at `turn_rate3d`
## (rad/s) instead of each axis catching up separately; a reversal brakes at `brake3d` and
## pivots; from a standstill you start at `start_speed3d` at once.
@export var accel3d: float = 70.0
@export var decel3d: float = 90.0
@export var brake3d: float = 140.0
@export var turn_rate3d: float = 20.0
@export var start_speed3d: float = 3.5
@export var air_accel3d: float = 30.0
@export var air_turn_rate3d: float = 6.0
## Jump designed by shape (apex height in metres, seconds to reach it, seconds to fall back),
## after the GDC "Building a Better Jump" method; gravity and launch speed are derived.
@export var jump_height3d: float = 2.3
@export var jump_rise_time3d: float = 0.36
@export var jump_fall_time3d: float = 0.27
## Near the apex (|vy| below this) with jump held, gravity halves: a brief hang for precision.
@export var apex_hang_speed3d: float = 1.6

@export_group("Dodge")
@export var dodge_speed: float = 17.0
@export var dodge_duration: float = 0.22
@export var dodge_invulnerable_time: float = 0.28
@export var dodge_cooldown: float = 0.4
## Full 3D: a readable dodge-roll at the platformer's pace (3.6 m over 0.36 s) instead of the
## side view's 17 m/s burst, so the roll clip plays at a believable rate (DEC-061).
@export var dodge_speed_3d: float = 10.0
@export var dodge_duration_3d: float = 0.36
@export var dodge_invulnerable_time_3d: float = 0.36
## Blood each dodge/dash costs (refused, with feedback, when you can't pay).
@export var dodge_blood_cost: float = 0.6

@export_group("Combat")
@export var light_attack: AttackData
@export var heavy_attack: AttackData
@export var hurt_invulnerable_time: float = 0.8
@export var attack_buffer_time: float = 0.15
@export var combo_window: float = 0.35
## 3D only: attacking with no movement input turns toward the nearest enemy within this range.
@export var soft_lock_range: float = 3.5
@export var health: Health
@export var hurtbox: Hurtbox
@export var melee: MeleeAttack

var in_3d_mode: bool = false
var game_frozen: bool = false
var facing_direction: float = 1.0

var _facing_3d: Vector3 = Vector3.RIGHT
var _coyote_left: float = 0.0
var _buffer_left: float = 0.0
var _jump_rising: bool = false
var _was_on_floor: bool = true  # no landing thud on spawn
var _dodge_left: float = 0.0
var _attack_held: bool = false
## Local co-op: this player's action-name prefix ("" = player 1, "p2_" = player 2) and index.
## Online play can drive a remote player's prefixed actions without touching this script.
var input_prefix: String = ""
var player_index: int = 0
## Co-op: knocked down at 0 HP until the partner revives you (see main.gd).
var is_downed: bool = false
## Full-3D: the ThirdPersonCamera whose yaw makes input camera-relative (null = world axes).
var view_camera: Node3D
## Full-3D lock-on target (set by the camera): the player faces it; cards aim at it.
var lock_target: Node3D
## The full-3D platformer moveset; drives movement whenever a third-person camera is assigned.
var motor: PlatformerMotor
## Full-3D: the camera-relative stick this frame (the motor turns the facing toward it).
var _wish_3d: Vector2 = Vector2.ZERO
var _haste_left: float = 0.0
var _haste_mult: float = 1.0
var _invulnerable_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _air_dodge_used: bool = false
var _dodge_direction: Vector3 = Vector3.RIGHT
var _stun_left: float = 0.0
var _queued_attack: AttackData
var _queued_left: float = 0.0
var _shield_category: StringName = &""
var _shield_left: float = 0.0
var _shield_visual: MeshInstance3D
var _combo_prev: AttackData
var _combo_left: float = 0.0
var _hurt_flash_left: float = 0.0
var _body_material: StandardMaterial3D
const BODY_COLOR: Color = Color(0.55, 0.6, 0.85)
## Set before adding to the tree (co-op player 2 is red).
var body_color: Color = BODY_COLOR


func _ready() -> void:
    InputBindings.ensure_defaults()
    hurtbox.hit_received.connect(_on_hit_received)
    hurtbox.hit_blocked.connect(func(info: DamageInfo) -> void: blocked.emit(info))
    health.died.connect(_on_died)
    melee.attack_finished.connect(_on_attack_finished)
    motor = PlatformerMotor.new(self)
    _build_shield_visual()
    var knight: MeshInstance3D = get_node_or_null("VisualRoot/PlaceholderKnight") as MeshInstance3D
    if knight:
        _body_material = StandardMaterial3D.new()
        _body_material.albedo_color = body_color
        knight.material_override = _body_material


## This player's name for an input action (see InputBindings.configure_players).
func act(action: StringName) -> StringName:
    return action if input_prefix == "" else StringName(input_prefix + String(action))


## Co-op down state: no control, no hurtbox, lying on the ground.
func set_downed(down: bool) -> void:
    is_downed = down
    game_frozen = down
    hurtbox.set_enabled(not down)
    velocity = Vector3.ZERO
    var visual: Node3D = get_node_or_null("VisualRoot") as Node3D
    if visual:
        visual.rotation.z = PI * 0.5 if down else 0.0
        visual.position.y = -0.55 if down else 0.0


func is_invulnerable() -> bool:
    return _invulnerable_left > 0.0


## Seconds the dodge lasts in the current mode (the 3D roll is longer and slower).
func current_dodge_duration() -> float:
    return dodge_duration_3d if _full_3d() else dodge_duration


func is_dodging() -> bool:
    return _dodge_left > 0.0


func is_stunned() -> bool:
    return _stun_left > 0.0


func stun_time_left() -> float:
    return _stun_left


func is_shielded() -> bool:
    return _shield_left > 0.0


## Grave Shield: absorb the next hit of `category` within `duration` seconds.
func raise_shield(category: StringName, duration: float) -> void:
    _shield_category = category
    _shield_left = duration
    _shield_visual.visible = true


## Hurtbox hook. Consumes the shield when it blocks.
func try_block(info: DamageInfo) -> bool:
    if _shield_left <= 0.0 or info.category != _shield_category:
        return false
    _shield_left = 0.0
    _shield_visual.visible = false
    return true


func get_facing_vector() -> Vector3:
    return _facing_3d if in_3d_mode else Vector3(facing_direction, 0.0, 0.0)


## Shadow Step / Grave Hook: teleport up to `distance` along `direction` (default: facing),
## passing through enemies but stopping short of walls. Grants `iframes` s of invulnerability.
## Unlike teleport_to it keeps the current attack/dodge cooldowns. Returns the distance moved.
## `rise` lifts the path first (Grave Hook pulls you up out of a pit onto a foe's ledge).
func blink(distance: float, iframes: float, direction: Vector3 = Vector3.ZERO, rise: float = 0.0) -> float:
    var dir: Vector3 = direction if direction.length_squared() > 0.0001 else get_facing_vector()
    dir.y = 0.0
    if not in_3d_mode:
        dir.z = 0.0
    if dir.length_squared() < 0.0001:
        return 0.0
    dir = dir.normalized()
    var start: Vector3 = global_position
    var from: Vector3 = start + Vector3(0.0, maxf(0.0, rise), 0.0)
    var allowed: float = distance
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    for height: float in [-0.5, 0.0, 0.6]:  # knee, chest and head rays
        var origin: Vector3 = from + Vector3(0.0, height, 0.0)
        var exclude: Array[RID] = [get_rid()]
        for attempt in 6:
            var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * (distance + 0.4))
            query.exclude = exclude
            query.collide_with_areas = false
            var hit: Dictionary = space.intersect_ray(query)
            if hit.is_empty():
                break
            var collider: Object = hit["collider"]
            if collider is Node and ((collider as Node).is_in_group(&"enemy") or (collider as Node).is_in_group(&"player")):
                exclude.append(hit["rid"])  # pass through bodies, not walls
                continue
            allowed = minf(allowed, maxf(0.0, origin.distance_to(hit["position"]) - 0.45))
            break
    global_position = from + dir * allowed
    if not in_3d_mode:
        position.z = 0.0
    velocity.x = 0.0
    velocity.z = 0.0
    velocity.y = maxf(velocity.y, 0.0)
    if _full_3d():
        motor.reset()  # the blink stops the run: no speed left over along the facing
    _invulnerable_left = maxf(_invulnerable_left, iframes)
    melee.cancel()
    _queued_attack = null
    blinked.emit(start, global_position)
    return allowed


## Sigil of Haste: run and attack `mult` times faster for `seconds`.
func haste(seconds: float, mult: float) -> void:
    _haste_left = seconds
    _haste_mult = mult
    melee.haste_scale = mult


func is_hasted() -> bool:
    return _haste_left > 0.0


## Moves the player instantly and clears all transient motion/combat state (respawn, mode switch).
func teleport_to(target: Vector3) -> void:
    global_position = target
    reset_physics_interpolation()  # a teleport must not smear across the screen
    velocity = Vector3.ZERO
    _coyote_left = 0.0
    _buffer_left = 0.0
    _jump_rising = false
    _dodge_left = 0.0
    _invulnerable_left = 0.0
    _stun_left = 0.0
    _queued_attack = null
    melee.cancel()
    if motor != null:
        motor.reset()
    teleported.emit()


## Respawn helper: full health plus a clean motion state.
func revive_at(target: Vector3) -> void:
    health.restore_full()
    teleport_to(target)
    _combo_prev = null
    _combo_left = 0.0
    _haste_left = 0.0
    melee.haste_scale = 1.0
    _shield_left = 0.0
    _shield_visual.visible = false


func _physics_process(delta: float) -> void:
    if game_frozen:
        velocity = Vector3.ZERO
        return

    _tick_timers(delta)
    if _haste_left > 0.0:
        _haste_left -= delta
        if _haste_left <= 0.0:
            melee.haste_scale = 1.0
    var on_floor: bool = is_on_floor()
    if on_floor:
        _coyote_left = coyote_time
        _air_dodge_used = false
        if not _was_on_floor:
            landed.emit()

    var controllable: bool = not is_stunned() and not health.is_dead()
    var input_x: float = 0.0
    var input_z: float = 0.0
    if controllable:
        input_x = Input.get_axis(act(&"move_left"), act(&"move_right"))
        input_z = Input.get_axis(act(&"move_forward"), act(&"move_back")) if in_3d_mode else 0.0
        if in_3d_mode and view_camera != null:
            # Camera-relative: W runs away from the camera, A/D strafe across its view.
            var world: Vector3 = (view_camera.call("flat_basis") as Basis) * Vector3(input_x, 0.0, input_z)
            input_x = world.x
            input_z = world.z
    if _full_3d():
        # The motor owns the facing (it turns toward the stick at a fixed rate, DEC-051); a lock-on
        # target only turns you where the motor allows strafing.
        _wish_3d = Vector2(input_x, input_z)
        if not melee.is_busy() and motor.allows_lock_facing():
            _face_lock_target()
    elif not melee.is_busy():
        _update_facing(input_x, input_z)
        _face_lock_target()

    if controllable and Input.is_action_just_pressed(act(&"jump")):
        _buffer_left = jump_buffer_time
    if controllable and Input.is_action_just_pressed(act(&"dodge")):
        _try_start_dodge(input_x, input_z, on_floor)
    if _queued_attack != null and not melee.is_busy() and not is_stunned():
        var queued: AttackData = _queued_attack
        _queued_attack = null
        if _queued_left > 0.0:
            _try_attack(queued)
    if controllable and not melee.is_busy() and _queued_attack == null and not is_dodging():
        if _attack_held and Input.is_action_pressed(act(&"attack")):
            _try_attack(light_attack)  # holding left click / J keeps the combo going
        else:
            _attack_held = false

    if is_dodging():
        velocity.x = _dodge_direction.x * (dodge_speed_3d if _full_3d() else dodge_speed)
        velocity.z = _dodge_direction.z * (dodge_speed_3d if _full_3d() else dodge_speed)
        velocity.y = 0.0
        if _full_3d():
            motor.hold_external(PlatformerMotor.State.DASH, delta)
    elif is_stunned():
        if _full_3d():
            # The motor's KNOCKBACK state carries the hit (friction, gravity, its pose).
            if motor.state != PlatformerMotor.State.KNOCKBACK:
                motor.knockback()
            motor.step(Vector2.ZERO, on_floor, delta)
        else:
            # Knockback carries; only gravity and gentle friction act.
            velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
            _apply_gravity(on_floor, delta)
    elif melee.is_busy():
        _apply_attack_motion(input_x, input_z, on_floor, delta)
        _apply_gravity(on_floor, delta)
        if _full_3d():
            motor.hold_external(PlatformerMotor.State.ATTACK, delta)
    elif _full_3d():
        motor.step(Vector2(input_x, input_z), on_floor, delta)
    else:
        _apply_run(input_x, input_z, on_floor, delta)
        _apply_jump_and_gravity(on_floor, delta)

    if not in_3d_mode:
        velocity.z = 0.0
        position.z = 0.0
    move_and_slide()
    if not in_3d_mode:
        position.z = 0.0
    _was_on_floor = on_floor  # pre-move state, so next frame sees the touchdown
    _update_reaction_visuals(delta)


func is_hurt_flashing() -> bool:
    return _hurt_flash_left > 0.0


func _enemy_body_ahead(distance: float) -> bool:
    var ahead: Vector3 = melee.facing
    for node: Node in get_tree().get_nodes_in_group(&"enemy"):
        var enemy: Node3D = node as Node3D
        if enemy == null or (enemy.has_method("is_dead") and enemy.call("is_dead")):
            continue
        var offset: Vector3 = enemy.global_position - global_position
        offset.y = 0.0
        if offset.length() < distance and offset.dot(ahead) > 0.0:
            return true
    return false


func _on_attack_finished(data: AttackData) -> void:
    _combo_prev = data if data.next_combo != null else null
    _combo_left = combo_window


## Light presses continue the chain: from the attack in progress (buffered press) or from the
## one that just ended (within combo_window).
func _resolve_light(data: AttackData) -> AttackData:
    if data != light_attack:
        return data
    if melee.is_busy() and melee.current != null and melee.current.next_combo != null:
        return melee.current.next_combo
    if not melee.is_busy() and _combo_prev != null and _combo_left > 0.0:
        return _combo_prev.next_combo
    return light_attack


func _update_reaction_visuals(delta: float) -> void:
    _hurt_flash_left = maxf(0.0, _hurt_flash_left - delta)
    var visual: Node3D = get_node_or_null("VisualRoot") as Node3D
    if visual == null:
        return
    # Lean into swings, recoil when hurt.
    var lean: float = 0.0
    if melee.is_busy() and melee.phase == MeleeAttack.Phase.ACTIVE:
        lean = -0.3 * facing_direction
    elif is_stunned():
        lean = 0.35 * facing_direction
    visual.rotation.z = lerpf(visual.rotation.z, lean, minf(1.0, 18.0 * delta))
    if _body_material:
        var t: float = _hurt_flash_left / 0.18
        _body_material.albedo_color = body_color.lerp(Color(1.0, 0.25, 0.2), t)
        _body_material.emission_enabled = t > 0.0
        _body_material.emission = Color(1.0, 0.1, 0.05) * t

func _tick_timers(delta: float) -> void:
    _coyote_left = maxf(0.0, _coyote_left - delta)
    _buffer_left = maxf(0.0, _buffer_left - delta)
    if _dodge_left > 0.0 and _dodge_left - delta <= 0.0:
        _end_dodge()
    _dodge_left = maxf(0.0, _dodge_left - delta)
    _invulnerable_left = maxf(0.0, _invulnerable_left - delta)
    _dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
    _stun_left = maxf(0.0, _stun_left - delta)
    _queued_left = maxf(0.0, _queued_left - delta)
    _combo_left = maxf(0.0, _combo_left - delta)
    if _shield_left > 0.0:
        _shield_left = maxf(0.0, _shield_left - delta)
        _shield_visual.visible = _shield_left > 0.0


func _update_facing(input_x: float, input_z: float) -> void:
    if absf(input_x) > 0.01:
        facing_direction = signf(input_x)
    var planar: Vector3 = Vector3(input_x, 0.0, input_z)
    if planar.length_squared() > 0.01:
        _facing_3d = planar.normalized()
    elif not in_3d_mode:
        _facing_3d = Vector3(facing_direction, 0.0, 0.0)


func _apply_run(input_x: float, input_z: float, on_floor: bool, delta: float) -> void:
    var target: Vector2 = Vector2(input_x, input_z).limit_length(1.0) * move_speed * (_haste_mult if _haste_left > 0.0 else 1.0)
    var rate: float = air_acceleration
    if on_floor:
        rate = ground_acceleration if target.length() > 0.01 else ground_deceleration
    # Turning around: brake hard against the old direction instead of sliding through it.
    if absf(target.x) > 0.01 and velocity.x * target.x < 0.0:
        rate = turn_acceleration if on_floor else air_turn_acceleration
    velocity.x = move_toward(velocity.x, target.x, rate * delta)
    if in_3d_mode:
        velocity.z = move_toward(velocity.z, target.y, rate * delta)


## Full 3D (a third-person camera drives the input).
func _full_3d() -> bool:
    return in_3d_mode and view_camera != null


## Full-3D ground/air movement on the XZ plane as ONE vector: the speed eases toward the
## target, the direction rotates toward the stick (sharp, readable turns), a reversal brakes
## and pivots, and a standing start gets an instant kick.
func _apply_run_3d(input_x: float, input_z: float, on_floor: bool, delta: float) -> void:
    var wish: Vector2 = Vector2(input_x, input_z).limit_length(1.0)
    var top: float = move_speed * (_haste_mult if _haste_left > 0.0 else 1.0)
    var planar: Vector2 = Vector2(velocity.x, velocity.z)
    var speed: float = planar.length()
    if wish.length() < 0.05:
        speed = move_toward(speed, 0.0, (decel3d if on_floor else air_accel3d * 0.3) * delta)
        planar = planar.normalized() * speed if speed > 0.0 else Vector2.ZERO
    else:
        var want_dir: Vector2 = wish.normalized()
        var want_speed: float = top * wish.length()
        var dir: Vector2 = planar / speed if speed > 0.3 else want_dir
        var angle: float = absf(dir.angle_to(want_dir))
        if on_floor and angle > deg_to_rad(150.0) and speed > 2.0:
            speed = move_toward(speed, 0.0, brake3d * delta)  # reversal: brake, then pivot
            if speed <= 2.0:
                dir = want_dir
        else:
            var turn: float = (turn_rate3d if on_floor else air_turn_rate3d) * delta
            dir = dir.rotated(clampf(dir.angle_to(want_dir), -turn, turn))
            if on_floor and speed < start_speed3d:
                speed = minf(start_speed3d, want_speed)  # instant first step
            speed = move_toward(speed, want_speed, (accel3d if on_floor else air_accel3d) * delta)
        planar = dir * speed
    velocity.x = planar.x
    velocity.z = planar.y


func _apply_attack_motion(input_x: float, input_z: float, on_floor: bool, delta: float) -> void:
    var data: AttackData = melee.current
    # Plant your feet when already in reach: lunging into an enemy's body only earns you its
    # contact damage (and that hit would break your combo).
    if melee.phase == MeleeAttack.Phase.ACTIVE and data.lunge_speed > 0.0 and not _enemy_body_ahead(1.3):
        var lunge: Vector3 = melee.facing * data.lunge_speed
        velocity.x = lunge.x
        if in_3d_mode:
            velocity.z = lunge.z
        return
    var target: Vector2 = Vector2(input_x, input_z).limit_length(1.0) * move_speed * data.move_multiplier
    var rate: float = ground_deceleration if on_floor else air_acceleration
    if _full_3d():
        # The 3D hero walks through a swing at its own (slower) run pace (DEC-060).
        target = Vector2(input_x, input_z).limit_length(1.0) * PlatformerMotor.RUN_SPEED * data.move_multiplier
        var planar: Vector2 = Vector2(velocity.x, velocity.z).move_toward(target, decel3d * delta)
        velocity.x = planar.x
        velocity.z = planar.y
        return
    velocity.x = move_toward(velocity.x, target.x, rate * delta)
    if in_3d_mode:
        velocity.z = move_toward(velocity.z, target.y, rate * delta)


func _apply_jump_and_gravity(on_floor: bool, delta: float) -> void:
    if _buffer_left > 0.0 and _coyote_left > 0.0:
        velocity.y = 2.0 * jump_height3d / jump_rise_time3d if _full_3d() else jump_speed
        _buffer_left = 0.0
        _coyote_left = 0.0
        _jump_rising = true
        jumped.emit()
        return

    if _jump_rising and velocity.y > 0.0 and not Input.is_action_pressed(act(&"jump")):
        velocity.y *= jump_cut_factor
        _jump_rising = false
    _apply_gravity(on_floor, delta)


func _apply_gravity(on_floor: bool, delta: float) -> void:
    if velocity.y <= 0.0:
        _jump_rising = false
    if on_floor:
        if velocity.y < 0.0:
            velocity.y = 0.0
    else:
        var g: float = rise_gravity if velocity.y > 0.0 else fall_gravity
        if _full_3d():
            var rise_g: float = 2.0 * jump_height3d / (jump_rise_time3d * jump_rise_time3d)
            var fall_g: float = 2.0 * jump_height3d / (jump_fall_time3d * jump_fall_time3d)
            g = rise_g if velocity.y > 0.0 else fall_g
            if absf(velocity.y) < apex_hang_speed3d and Input.is_action_pressed(act(&"jump")):
                g *= 0.5  # apex hang
        velocity.y = maxf(velocity.y - g * delta, -max_fall_speed * (1.5 if _full_3d() else 1.0))


func _try_start_dodge(input_x: float, input_z: float, on_floor: bool) -> void:
    if _dodge_cooldown_left > 0.0 or is_dodging():
        return
    if _full_3d() and motor.blocks_dodge():
        return
    if not on_floor and _air_dodge_used:
        return
    if melee.is_busy() and not melee.can_cancel_into_dodge():
        return
    var cards: CardSystem = get_node_or_null("Cards") as CardSystem
    if cards != null and cards.energy != null and dodge_blood_cost > 0.0:
        if not cards.energy.spend(dodge_blood_cost):
            dodge_refused.emit()  # not enough blood: no dash
            return
    if melee.is_busy():
        melee.cancel()
    var direction: Vector3 = Vector3(input_x, 0.0, input_z)
    if direction.length_squared() < 0.01:
        direction = get_facing_vector()
    _dodge_direction = direction.normalized()
    _dodge_left = current_dodge_duration()
    _invulnerable_left = maxf(_invulnerable_left, dodge_invulnerable_time_3d if _full_3d() else dodge_invulnerable_time)
    _dodge_cooldown_left = dodge_cooldown
    _jump_rising = false
    if not on_floor:
        _air_dodge_used = true
    if _full_3d():
        # The dash cancels a slide, crouch or wall slide; it is the motor's DASH state while it
        # lasts, and the hero faces the way it dashes.
        _facing_3d = _dodge_direction
        motor.begin_external(PlatformerMotor.State.DASH)
    dodge_started.emit(_dodge_direction)


## Locked on: always face the target (strafe around it), unless dodging.
func _face_lock_target() -> void:
    if lock_target == null or not is_instance_valid(lock_target) or is_dodging():
        return
    var to_target: Vector3 = lock_target.global_position - global_position
    to_target.y = 0.0
    if to_target.length_squared() > 0.01:
        _facing_3d = to_target.normalized()
        if absf(_facing_3d.x) > 0.01:
            facing_direction = signf(_facing_3d.x)


## With no stick/keys held, aim the attack at the nearest living enemy in range (3D only).
func _soft_lock_facing() -> void:
    var input: Vector2 = Input.get_vector(act(&"move_left"), act(&"move_right"), act(&"move_forward"), act(&"move_back"))
    if input.length() > 0.2:
        return
    var best: Node3D = null
    var best_distance: float = soft_lock_range
    for node: Node in get_tree().get_nodes_in_group(&"enemy"):
        var enemy: Node3D = node as Node3D
        if enemy == null or (enemy.has_method("is_dead") and enemy.call("is_dead")):
            continue
        var offset: Vector3 = enemy.global_position - global_position
        offset.y = 0.0
        if offset.length() < best_distance:
            best = enemy
            best_distance = offset.length()
    if best:
        var dir: Vector3 = best.global_position - global_position
        dir.y = 0.0
        _facing_3d = dir.normalized()
        if absf(_facing_3d.x) > 0.01:
            facing_direction = signf(_facing_3d.x)


## Drops dodge speed back to run speed so the burst does not turn into a long slide.
func _end_dodge() -> void:
    var planar: Vector2 = Vector2(velocity.x, velocity.z).limit_length(PlatformerMotor.RUN_SPEED if _full_3d() else move_speed)
    velocity.x = planar.x
    velocity.z = planar.y


func _try_attack(data: AttackData) -> void:
    if data == null or is_dodging() or health.is_dead():
        return
    if _full_3d() and motor.blocks_attacks():
        return
    data = _resolve_light(data)
    if is_stunned():
        # Held until the stun ends (same idea as the card buffer), not silently dropped.
        _queued_attack = data
        _queued_left = _stun_left + attack_buffer_time
        return
    if melee.is_busy():
        _queued_attack = data
        _queued_left = attack_buffer_time
        return
    if _full_3d() and _wish_3d.length() > 0.2 and (lock_target == null or not is_instance_valid(lock_target)):
        # Combat stays snappy: a swing goes where the stick points, not where the run has turned.
        _facing_3d = Vector3(_wish_3d.x, 0.0, _wish_3d.y).normalized()
        if absf(_facing_3d.x) > 0.01:
            facing_direction = signf(_facing_3d.x)
    if in_3d_mode:
        _soft_lock_facing()
    if melee.start(data, get_facing_vector()):
        _buffer_left = 0.0
        if _full_3d():
            # Swinging stands you up out of a crouch or slide; it is the motor's ATTACK state.
            motor.begin_external(PlatformerMotor.State.ATTACK)
        attack_started.emit(data.id)


func _on_hit_received(info: DamageInfo) -> void:
    _queued_attack = null
    melee.cancel()
    _dodge_left = 0.0
    _jump_rising = false
    velocity = info.knockback
    if not in_3d_mode:
        velocity.z = 0.0
    _stun_left = info.hitstun
    _invulnerable_left = hurt_invulnerable_time
    _hurt_flash_left = 0.18
    _combo_prev = null
    if _full_3d():
        motor.knockback()  # a hit ends any flip, slide, hang, climb or pull-up (DEC-051)
    hurt.emit(info)


func _build_shield_visual() -> void:
    _shield_visual = MeshInstance3D.new()
    _shield_visual.name = "GraveShieldWard"
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 1.1
    sphere.height = 2.2
    _shield_visual.mesh = sphere
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.55, 0.65, 0.8, 0.28)
    _shield_visual.material_override = material
    _shield_visual.visible = false
    add_child(_shield_visual)


func _on_died() -> void:
    melee.cancel()
    died.emit()


func _unhandled_input(event: InputEvent) -> void:
    if game_frozen or event.is_echo():
        return
    if event.is_action_pressed(act(&"attack")):
        # Only a press that reached the player counts as holding: clicks eaten by the HUD or
        # by card targeting must not start a combo through Input.is_action_pressed.
        _attack_held = true
        _try_attack(light_attack)
    elif event.is_action_pressed(act(&"heavy_attack")):
        _try_attack(heavy_attack)

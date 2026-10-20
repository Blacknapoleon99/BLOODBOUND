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
## - Attacks (see AttackData): no jumping, turning or new attacks until the attack ends.
##   Only RECOVERY may be cancelled into a dodge, and only if the attack allows it.
## - Getting hit: cancels any attack, applies knockback, `hurt_stun` without control,
##   then `hurt_invulnerable_time` of invulnerability (from the moment of the hit).

signal jumped
signal landed
signal dodge_started(direction: Vector3)
signal attack_started(attack_id: StringName)
signal hurt(info: DamageInfo)
signal died

@export_group("Run")
@export var move_speed: float = 7.0
@export var ground_acceleration: float = 45.0
@export var ground_deceleration: float = 55.0
@export var air_acceleration: float = 28.0

@export_group("Jump")
@export var jump_speed: float = 9.5
@export var rise_gravity: float = 22.0
@export var fall_gravity: float = 30.0
@export var max_fall_speed: float = 24.0
@export var jump_cut_factor: float = 0.45
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12

@export_group("Dodge")
@export var dodge_speed: float = 15.0
@export var dodge_duration: float = 0.22
@export var dodge_invulnerable_time: float = 0.28
@export var dodge_cooldown: float = 0.45

@export_group("Combat")
@export var light_attack: AttackData
@export var heavy_attack: AttackData
@export var hurt_invulnerable_time: float = 0.8
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
var _was_on_floor: bool = false
var _dodge_left: float = 0.0
var _invulnerable_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _air_dodge_used: bool = false
var _dodge_direction: Vector3 = Vector3.RIGHT
var _stun_left: float = 0.0


func _ready() -> void:
    InputBindings.ensure_defaults()
    hurtbox.hit_received.connect(_on_hit_received)
    health.died.connect(_on_died)


func is_invulnerable() -> bool:
    return _invulnerable_left > 0.0


func is_dodging() -> bool:
    return _dodge_left > 0.0


func is_stunned() -> bool:
    return _stun_left > 0.0


func get_facing_vector() -> Vector3:
    return _facing_3d if in_3d_mode else Vector3(facing_direction, 0.0, 0.0)


## Moves the player instantly and clears all transient motion/combat state (respawn, mode switch).
func teleport_to(target: Vector3) -> void:
    global_position = target
    velocity = Vector3.ZERO
    _coyote_left = 0.0
    _buffer_left = 0.0
    _jump_rising = false
    _dodge_left = 0.0
    _invulnerable_left = 0.0
    _stun_left = 0.0
    melee.cancel()


## Respawn helper: full health plus a clean motion state.
func revive_at(target: Vector3) -> void:
    health.restore_full()
    teleport_to(target)


func _physics_process(delta: float) -> void:
    if game_frozen:
        velocity = Vector3.ZERO
        return

    _tick_timers(delta)
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
        input_x = Input.get_axis(&"move_left", &"move_right")
        input_z = Input.get_axis(&"move_forward", &"move_back") if in_3d_mode else 0.0
    if not melee.is_busy():
        _update_facing(input_x, input_z)

    if controllable and Input.is_action_just_pressed(&"jump"):
        _buffer_left = jump_buffer_time
    if controllable and Input.is_action_just_pressed(&"dodge"):
        _try_start_dodge(input_x, input_z, on_floor)

    if is_dodging():
        velocity.x = _dodge_direction.x * dodge_speed
        velocity.z = _dodge_direction.z * dodge_speed
        velocity.y = 0.0
    elif is_stunned():
        # Knockback carries; only gravity and gentle friction act.
        velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
        _apply_gravity(on_floor, delta)
    elif melee.is_busy():
        _apply_attack_motion(input_x, input_z, on_floor, delta)
        _apply_gravity(on_floor, delta)
    else:
        _apply_run(input_x, input_z, on_floor, delta)
        _apply_jump_and_gravity(on_floor, delta)

    if not in_3d_mode:
        velocity.z = 0.0
        position.z = 0.0
    move_and_slide()
    if not in_3d_mode:
        position.z = 0.0
    _was_on_floor = is_on_floor()


func _tick_timers(delta: float) -> void:
    _coyote_left = maxf(0.0, _coyote_left - delta)
    _buffer_left = maxf(0.0, _buffer_left - delta)
    if _dodge_left > 0.0 and _dodge_left - delta <= 0.0:
        _end_dodge()
    _dodge_left = maxf(0.0, _dodge_left - delta)
    _invulnerable_left = maxf(0.0, _invulnerable_left - delta)
    _dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
    _stun_left = maxf(0.0, _stun_left - delta)


func _update_facing(input_x: float, input_z: float) -> void:
    if absf(input_x) > 0.01:
        facing_direction = signf(input_x)
    var planar: Vector3 = Vector3(input_x, 0.0, input_z)
    if planar.length_squared() > 0.01:
        _facing_3d = planar.normalized()
    elif not in_3d_mode:
        _facing_3d = Vector3(facing_direction, 0.0, 0.0)


func _apply_run(input_x: float, input_z: float, on_floor: bool, delta: float) -> void:
    var target: Vector2 = Vector2(input_x, input_z).limit_length(1.0) * move_speed
    var rate: float = air_acceleration
    if on_floor:
        rate = ground_acceleration if target.length() > 0.01 else ground_deceleration
    velocity.x = move_toward(velocity.x, target.x, rate * delta)
    if in_3d_mode:
        velocity.z = move_toward(velocity.z, target.y, rate * delta)


func _apply_attack_motion(input_x: float, input_z: float, on_floor: bool, delta: float) -> void:
    var data: AttackData = melee.current
    if melee.phase == MeleeAttack.Phase.ACTIVE and data.lunge_speed > 0.0:
        var lunge: Vector3 = melee.facing * data.lunge_speed
        velocity.x = lunge.x
        if in_3d_mode:
            velocity.z = lunge.z
        return
    var target: Vector2 = Vector2(input_x, input_z).limit_length(1.0) * move_speed * data.move_multiplier
    var rate: float = ground_deceleration if on_floor else air_acceleration
    velocity.x = move_toward(velocity.x, target.x, rate * delta)
    if in_3d_mode:
        velocity.z = move_toward(velocity.z, target.y, rate * delta)


func _apply_jump_and_gravity(on_floor: bool, delta: float) -> void:
    if _buffer_left > 0.0 and _coyote_left > 0.0:
        velocity.y = jump_speed
        _buffer_left = 0.0
        _coyote_left = 0.0
        _jump_rising = true
        jumped.emit()
        return

    if _jump_rising and velocity.y > 0.0 and not Input.is_action_pressed(&"jump"):
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
        velocity.y = maxf(velocity.y - g * delta, -max_fall_speed)


func _try_start_dodge(input_x: float, input_z: float, on_floor: bool) -> void:
    if _dodge_cooldown_left > 0.0 or is_dodging():
        return
    if not on_floor and _air_dodge_used:
        return
    if melee.is_busy():
        if not melee.can_cancel_into_dodge():
            return
        melee.cancel()
    var direction: Vector3 = Vector3(input_x, 0.0, input_z)
    if direction.length_squared() < 0.01:
        direction = get_facing_vector()
    _dodge_direction = direction.normalized()
    _dodge_left = dodge_duration
    _invulnerable_left = maxf(_invulnerable_left, dodge_invulnerable_time)
    _dodge_cooldown_left = dodge_cooldown
    _jump_rising = false
    if not on_floor:
        _air_dodge_used = true
    dodge_started.emit(_dodge_direction)


## Drops dodge speed back to run speed so the burst does not turn into a long slide.
func _end_dodge() -> void:
    var planar: Vector2 = Vector2(velocity.x, velocity.z).limit_length(move_speed)
    velocity.x = planar.x
    velocity.z = planar.y


func _try_attack(data: AttackData) -> void:
    if data == null or is_dodging() or is_stunned() or health.is_dead():
        return
    if melee.start(data, get_facing_vector()):
        _buffer_left = 0.0
        attack_started.emit(data.id)


func _on_hit_received(info: DamageInfo) -> void:
    melee.cancel()
    _dodge_left = 0.0
    _jump_rising = false
    velocity = info.knockback
    if not in_3d_mode:
        velocity.z = 0.0
    _stun_left = info.hitstun
    _invulnerable_left = hurt_invulnerable_time
    hurt.emit(info)


func _on_died() -> void:
    melee.cancel()
    died.emit()


func _unhandled_input(event: InputEvent) -> void:
    if game_frozen or event.is_echo():
        return
    if event.is_action_pressed(&"attack"):
        _try_attack(light_attack)
    elif event.is_action_pressed(&"heavy_attack"):
        _try_attack(heavy_attack)

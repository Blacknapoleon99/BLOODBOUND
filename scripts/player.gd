extends CharacterBody3D
## Player motor: platforming feel, dodge, and mode switching. Combat resolution,
## health and checkpoints live elsewhere; this node only reports intent via signals.
## Z=0 in platforming mode. 3D mode unlocks Z movement with the same body.
##
## Timing semantics (all in seconds):
## - Coyote time: jump still allowed for `coyote_time` after walking off a ledge.
## - Jump buffer: a press up to `jump_buffer_time` before landing jumps on landing.
## - Variable jump: releasing jump while rising multiplies upward speed by `jump_cut_factor`.
## - Dodge: `dodge_duration` burst along facing/input; invulnerable for `dodge_invulnerable_time`
##   from the start of the dodge; usable again after `dodge_cooldown`; one dodge per airtime.

signal attack_requested(origin: Vector3, facing_direction: float)
signal jumped
signal landed
signal dodge_started(direction: Vector3)

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

var in_3d_mode: bool = false
var game_frozen: bool = false
var facing_direction: float = 1.0

var _coyote_left: float = 0.0
var _buffer_left: float = 0.0
var _jump_rising: bool = false
var _was_on_floor: bool = false
var _dodge_left: float = 0.0
var _invulnerable_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _air_dodge_used: bool = false
var _dodge_direction: Vector3 = Vector3.RIGHT


func _ready() -> void:
    InputBindings.ensure_defaults()


func is_invulnerable() -> bool:
    return _invulnerable_left > 0.0


func is_dodging() -> bool:
    return _dodge_left > 0.0


## Moves the player instantly and clears all transient motion state (respawn, mode switch).
func teleport_to(target: Vector3) -> void:
    global_position = target
    velocity = Vector3.ZERO
    _coyote_left = 0.0
    _buffer_left = 0.0
    _jump_rising = false
    _dodge_left = 0.0
    _invulnerable_left = 0.0


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

    var input_x: float = Input.get_axis(&"move_left", &"move_right")
    var input_z: float = Input.get_axis(&"move_forward", &"move_back") if in_3d_mode else 0.0
    if absf(input_x) > 0.01:
        facing_direction = signf(input_x)

    if Input.is_action_just_pressed(&"jump"):
        _buffer_left = jump_buffer_time
    if Input.is_action_just_pressed(&"dodge"):
        _try_start_dodge(input_x, input_z, on_floor)

    if is_dodging():
        velocity.x = _dodge_direction.x * dodge_speed
        velocity.z = _dodge_direction.z * dodge_speed
        velocity.y = 0.0
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
    _dodge_left = maxf(0.0, _dodge_left - delta)
    _invulnerable_left = maxf(0.0, _invulnerable_left - delta)
    _dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)


func _apply_run(input_x: float, input_z: float, on_floor: bool, delta: float) -> void:
    var target: Vector2 = Vector2(input_x, input_z).limit_length(1.0) * move_speed
    var rate: float = air_acceleration
    if on_floor:
        rate = ground_acceleration if target.length() > 0.01 else ground_deceleration
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
    var direction: Vector3 = Vector3(input_x, 0.0, input_z)
    if direction.length_squared() < 0.01:
        direction = Vector3(facing_direction, 0.0, 0.0)
    _dodge_direction = direction.normalized()
    _dodge_left = dodge_duration
    _invulnerable_left = dodge_invulnerable_time
    _dodge_cooldown_left = dodge_cooldown
    _jump_rising = false
    if not on_floor:
        _air_dodge_used = true
    dodge_started.emit(_dodge_direction)


func _unhandled_input(event: InputEvent) -> void:
    if game_frozen:
        return
    if event.is_action_pressed(&"attack") and not event.is_echo():
        attack_requested.emit(global_position, facing_direction)

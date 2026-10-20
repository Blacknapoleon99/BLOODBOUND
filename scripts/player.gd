extends CharacterBody3D
## Prototype player motor only. Combat, input remapping and health are future systems.
## Z=0 in platforming mode. 3D mode unlocks Z movement with the same body.

signal attack_requested(origin: Vector3, facing_direction: float)

@export var move_speed: float = 7.0
@export var acceleration: float = 30.0
@export var jump_speed: float = 9.0
@export var gravity_force: float = 22.0

var in_3d_mode: bool = false
var game_frozen: bool = false
var facing_direction: float = 1.0
var _jump_was_pressed: bool = false


func _physics_process(delta: float) -> void:
    if game_frozen:
        velocity = Vector3.ZERO
        return

    var left_pressed: bool = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
    var right_pressed: bool = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
    var x_axis: float = float(int(right_pressed) - int(left_pressed))
    velocity.x = move_toward(velocity.x, x_axis * move_speed, acceleration * delta)

    if absf(x_axis) > 0.01:
        facing_direction = signf(x_axis)

    if in_3d_mode:
        var up_depth: bool = Input.is_physical_key_pressed(KEY_W)
        var down_depth: bool = Input.is_physical_key_pressed(KEY_S)
        var z_axis: float = float(int(down_depth) - int(up_depth))
        velocity.z = move_toward(velocity.z, z_axis * move_speed, acceleration * delta)
    else:
        velocity.z = 0.0
        # The corridor is a 3D scene with a rigorously locked movement plane.
        position.z = 0.0

    if not is_on_floor():
        velocity.y -= gravity_force * delta
    else:
        if velocity.y < 0.0:
            velocity.y = 0.0

    var jump_pressed: bool = Input.is_physical_key_pressed(KEY_SPACE)
    if jump_pressed and not _jump_was_pressed and is_on_floor():
        velocity.y = jump_speed
    _jump_was_pressed = jump_pressed

    move_and_slide()
    if not in_3d_mode:
        position.z = 0.0


func _unhandled_key_input(event: InputEvent) -> void:
    if game_frozen:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_J:
            attack_requested.emit(global_position, facing_direction)

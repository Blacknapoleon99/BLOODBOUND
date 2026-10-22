class_name ThirdPersonCamera
extends Node3D
## Third-person orbit camera with lock-on (full-3D phase 1, docs/superpowers/specs/
## 2026-10-22-full-3d-conversion-plan.md).
##
## - Orbits the player: mouse (captured) or right stick; pitch clamped.
## - A SpringArm3D pulls the camera in front of walls instead of clipping through them.
## - Follows the player's render-rate (interpolated) position, so motion stays smooth.
## - Lock-on (`lock_on`: Q / middle mouse / R3): picks the enemy nearest the screen centre
##   within LOCK_RANGE; `lock_next` (Tab / mouse wheel) cycles; it breaks when the target dies
##   or gets farther than LOCK_BREAK. While locked the camera swings behind the player to frame
##   the target, the player faces it (`Player.lock_target`) and cards aim at it.
## - `add_trauma` (group "camera_shaker") shakes it for hits, like the side-view camera.

const LOCK_RANGE: float = 18.0
const LOCK_BREAK: float = 24.0
const PITCH_MIN: float = deg_to_rad(-55.0)
const PITCH_MAX: float = deg_to_rad(30.0)
const MOUSE_SENSITIVITY: float = 0.0035
const STICK_SPEED: float = 3.2  # rad/s at full deflection
const FOLLOW_RATE: float = 16.0
const LOCK_TURN_RATE: float = 7.0

signal lock_changed(target: Node3D)

var player: CharacterBody3D
var camera: Camera3D
var arm: SpringArm3D
var yaw: float = 0.0
var pitch: float = deg_to_rad(-18.0)
var distance: float = 5.5
var height: float = 1.5
var lock_target: Node3D
var _marker: MeshInstance3D
var _trauma: float = 0.0
var _focus: Vector3 = Vector3.INF


static func create(target_player: CharacterBody3D) -> ThirdPersonCamera:
    var rig: ThirdPersonCamera = ThirdPersonCamera.new()
    rig.name = "ThirdPersonCamera"
    rig.player = target_player
    rig.top_level = true
    rig.add_to_group(&"camera_shaker")
    rig.arm = SpringArm3D.new()
    rig.arm.spring_length = rig.distance
    rig.arm.margin = 0.25
    rig.arm.collision_mask = 1  # world geometry
    var probe: SphereShape3D = SphereShape3D.new()
    probe.radius = 0.25
    rig.arm.shape = probe
    rig.add_child(rig.arm)
    rig.camera = Camera3D.new()
    rig.camera.fov = 65.0
    rig.camera.current = true
    rig.camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    rig.arm.add_child(rig.camera)
    rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    rig._build_marker()
    return rig


func _ready() -> void:
    arm.add_excluded_object(player.get_rid())
    yaw = player.rotation.y
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Flat (yaw-only) basis: what "forward" and "right" mean for the player's input.
func flat_basis() -> Basis:
    return Basis(Vector3.UP, yaw)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and lock_target == null:
        var motion: InputEventMouseMotion = event
        yaw -= motion.relative.x * MOUSE_SENSITIVITY
        pitch = clampf(pitch - motion.relative.y * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
    elif event.is_action_pressed(&"lock_on"):
        toggle_lock()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"lock_next") and lock_target != null:
        cycle_lock()
        get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    _validate_lock()
    var look: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
    if lock_target == null:
        yaw -= look.x * STICK_SPEED * delta
        pitch = clampf(pitch - look.y * STICK_SPEED * 0.6 * delta, PITCH_MIN, PITCH_MAX)
    else:
        # Swing behind the player so the target sits ahead of them on screen.
        var to_target: Vector3 = lock_target.global_position - player.global_position
        to_target.y = 0.0
        if to_target.length_squared() > 0.01:
            var want: float = atan2(-to_target.x, -to_target.z)
            yaw = lerp_angle(yaw, want, 1.0 - exp(-LOCK_TURN_RATE * delta))
            pitch = lerpf(pitch, deg_to_rad(-14.0), 1.0 - exp(-4.0 * delta))
    var target: Vector3 = player.get_global_transform_interpolated().origin + Vector3(0.0, height, 0.0)
    if _focus == Vector3.INF or _focus.distance_to(target) > 12.0:
        _focus = target  # first frame / teleport: cut
    _focus = _focus.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
    global_position = _focus
    rotation = Vector3(pitch, yaw, 0.0)
    arm.spring_length = distance
    # Shake (hits): a small random offset that decays.
    _trauma = maxf(0.0, _trauma - 1.6 * delta)
    var shake: float = _trauma * _trauma * GameSettings.camera_shake
    camera.h_offset = randf_range(-0.25, 0.25) * shake
    camera.v_offset = randf_range(-0.25, 0.25) * shake
    _update_marker()


func add_trauma(amount: float) -> void:
    _trauma = clampf(_trauma + amount, 0.0, 1.0)


# --- Lock-on ------------------------------------------------------------------------------------

func toggle_lock() -> void:
    if lock_target != null:
        set_lock(null)
    else:
        set_lock(_best_candidate(null))


func cycle_lock() -> void:
    var next: Node3D = _best_candidate(lock_target)
    if next != null:
        set_lock(next)


func set_lock(target: Node3D) -> void:
    lock_target = target
    player.set("lock_target", target)
    lock_changed.emit(target)


## Living enemies within LOCK_RANGE, scored by how close they are to the screen centre (and
## distance); `exclude` is skipped (for cycling).
func _best_candidate(exclude: Node3D) -> Node3D:
    var best: Node3D = null
    var best_score: float = INF
    var view_dir: Vector3 = -camera.global_basis.z
    for node: Node in get_tree().get_nodes_in_group(&"enemy"):
        var enemy: Node3D = node as Node3D
        if enemy == null or enemy == exclude or not _lockable(enemy):
            continue
        var offset: Vector3 = enemy.global_position - player.global_position
        var dist: float = offset.length()
        if dist > LOCK_RANGE:
            continue
        var to_enemy: Vector3 = (enemy.global_position - camera.global_position).normalized()
        var off_centre: float = 1.0 - view_dir.dot(to_enemy)  # 0 = dead centre
        var score: float = off_centre * 30.0 + dist * 0.2
        if score < best_score:
            best = enemy
            best_score = score
    return best


func _lockable(enemy: Node3D) -> bool:
    if not is_instance_valid(enemy) or not enemy.is_inside_tree():
        return false
    if enemy.has_method("is_dead") and enemy.call("is_dead"):
        return false
    return true


func _validate_lock() -> void:
    if lock_target == null:
        return
    if not _lockable(lock_target) or lock_target.global_position.distance_to(player.global_position) > LOCK_BREAK:
        set_lock(null)


func _build_marker() -> void:
    _marker = MeshInstance3D.new()
    var mesh: PrismMesh = PrismMesh.new()
    mesh.size = Vector3(0.28, 0.28, 0.06)
    _marker.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(1.0, 0.15, 0.1)
    material.no_depth_test = true
    _marker.material_override = material
    _marker.top_level = true
    _marker.visible = false
    add_child(_marker)


func _update_marker() -> void:
    _marker.visible = lock_target != null
    if lock_target != null:
        _marker.global_position = lock_target.get_global_transform_interpolated().origin + Vector3(0.0, 2.1, 0.0)
        _marker.rotation = Vector3(PI, yaw, 0.0)  # point down at the target

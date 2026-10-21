class_name BoneArcher
extends CharacterBody3D
## Ranged skeleton for ambushes. Keeps its distance, draws (a red aim line shows the shot for
## `aim_time` s), looses an arrow along the causeway, then recovers.
## States: IDLE → AIM → RECOVER → (AIM...) ; HITSTUN on poise break ; DEAD.
## Too close (< `retreat_distance`) and it backs away instead of aiming, unless cornered.
## Shares the combat contracts: Health/Hurtbox (team enemy), poise, silence, enemy group.

signal defeated
signal state_changed(state_name: String)

enum State { IDLE, AIM, RECOVER, HITSTUN, DEAD }

@export var aim_time: float = 0.7
@export var recover_time: float = 1.0
@export var engage_range: float = 14.0
@export var retreat_distance: float = 3.5
@export var move_speed: float = 2.4
@export var poise_max: int = 2
@export var max_health: int = 3
@export var min_x: float = -INF
@export var max_x: float = INF
@export var ai_enabled: bool = true

var state: State = State.IDLE
var facing: float = -1.0
var health: Health
var hurtbox: Hurtbox
var poise: int = 2
var arrows_fired: int = 0
var _t: float = 0.0
var _stun_left: float = 0.0
var _silenced_left: float = 0.0
var _flash_left: float = 0.0
var _aim_line: MeshInstance3D
var _body_material: StandardMaterial3D
var _visual: Node3D


func _ready() -> void:
    add_to_group(&"enemy")
    add_to_group(&"silenceable")
    poise = poise_max
    var body_shape: CollisionShape3D = CollisionShape3D.new()
    var capsule: CapsuleShape3D = CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    body_shape.shape = capsule
    add_child(body_shape)
    health = Health.new()
    health.max_health = max_health
    add_child(health)
    health.died.connect(_on_died)
    hurtbox = Hurtbox.new()
    hurtbox.team = &"enemy"
    hurtbox.health = health
    var hurt_shape: CollisionShape3D = CollisionShape3D.new()
    var hurt_capsule: CapsuleShape3D = CapsuleShape3D.new()
    hurt_capsule.radius = 0.42
    hurt_capsule.height = 1.85
    hurt_shape.shape = hurt_capsule
    hurtbox.add_child(hurt_shape)
    add_child(hurtbox)
    hurtbox.hit_received.connect(_on_hit)
    _build_visual()


func state_name() -> String:
    return State.keys()[state]


func is_dead() -> bool:
    return state == State.DEAD


func is_silenced() -> bool:
    return _silenced_left > 0.0


func silence(seconds: float) -> void:
    if state == State.DEAD:
        return
    _silenced_left = maxf(_silenced_left, seconds)
    if state == State.AIM:
        _aim_line.visible = false
        _set_state(State.RECOVER)


func _physics_process(delta: float) -> void:
    _t += delta
    _stun_left = maxf(0.0, _stun_left - delta)
    _silenced_left = maxf(0.0, _silenced_left - delta)
    _flash_left = maxf(0.0, _flash_left - delta)
    var target: Node3D = _target()
    match state:
        State.IDLE:
            velocity.x = 0.0
            if ai_enabled and target != null and _silenced_left <= 0.0:
                var dx: float = target.global_position.x - global_position.x
                facing = signf(dx) if absf(dx) > 0.01 else facing
                if absf(dx) < retreat_distance and _can_step(-facing):
                    velocity.x = -facing * move_speed
                else:
                    _set_state(State.AIM)
                    Audio.sfx(&"archer_draw")
        State.AIM:
            velocity.x = 0.0
            if target != null:
                var dx2: float = target.global_position.x - global_position.x
                if absf(dx2) > 0.01:
                    facing = signf(dx2)
            _aim_line.visible = true
            _aim_line.position = Vector3(facing * 4.0, 0.15, 0.0)
            if _t >= aim_time:
                _aim_line.visible = false
                Audio.sfx(&"arrow_release")
                get_parent().add_child(BoneArrow.create(global_position + Vector3(facing * 0.6, 0.15, 0.0), Vector3(facing, 0.0, 0.0)))
                arrows_fired += 1
                _set_state(State.RECOVER)
        State.RECOVER:
            velocity.x = 0.0
            if _t >= recover_time:
                _set_state(State.IDLE)
        State.HITSTUN:
            velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
            if _stun_left <= 0.0:
                _set_state(State.IDLE)
        State.DEAD:
            velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
    if not is_on_floor():
        velocity.y -= 26.0 * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0
    velocity.z = 0.0
    move_and_slide()
    position.z = 0.0
    if global_position.y < -9.0 and state != State.DEAD:
        health.apply_damage(health.current)  # fell into the abyss
    _update_visual()


func _target() -> Node3D:
    var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
    if player == null or bool(player.get("in_3d_mode")):
        return null
    if absf(player.global_position.x - global_position.x) > engage_range or absf(player.global_position.y - global_position.y) > 3.0:
        return null
    return player


func _can_step(dir: float) -> bool:
    var next_x: float = global_position.x + dir * 0.6
    return next_x > min_x and next_x < max_x


func _on_hit(info: DamageInfo) -> void:
    if state == State.DEAD:
        return
    _flash_left = 0.12
    poise -= info.poise_damage
    if poise > 0:
        return
    poise = poise_max
    _aim_line.visible = false
    velocity = info.knockback
    _stun_left = info.hitstun
    _set_state(State.HITSTUN)


func _on_died() -> void:
    _aim_line.visible = false
    _set_state(State.DEAD)
    hurtbox.set_enabled(false)
    set_deferred(&"collision_layer", 0)
    var tween: Tween = create_tween()
    tween.tween_property(_visual, "rotation:z", -facing * PI * 0.5, 0.35)
    tween.tween_property(_visual, "position:y", -0.7, 0.6)
    defeated.emit()


func _set_state(next: State) -> void:
    if state == next:
        return
    state = next
    _t = 0.0
    state_changed.emit(state_name())


func _build_visual() -> void:
    _visual = Node3D.new()
    add_child(_visual)
    _body_material = StandardMaterial3D.new()
    _body_material.albedo_color = Color(0.72, 0.68, 0.58)
    var body: MeshInstance3D = MeshInstance3D.new()
    var mesh: CapsuleMesh = CapsuleMesh.new()
    mesh.radius = 0.3
    mesh.height = 1.75
    body.mesh = mesh
    body.material_override = _body_material
    _visual.add_child(body)
    var bow: MeshInstance3D = MeshInstance3D.new()
    var bow_mesh: BoxMesh = BoxMesh.new()
    bow_mesh.size = Vector3(0.08, 1.2, 0.08)
    bow.mesh = bow_mesh
    var wood: StandardMaterial3D = StandardMaterial3D.new()
    wood.albedo_color = Color(0.35, 0.2, 0.1)
    bow.material_override = wood
    bow.name = "Bow"
    bow.position = Vector3(0.4, 0.15, 0.0)
    _visual.add_child(bow)
    _aim_line = MeshInstance3D.new()
    var line: BoxMesh = BoxMesh.new()
    line.size = Vector3(8.0, 0.05, 0.05)
    _aim_line.mesh = line
    _aim_line.material_override = BishopHand._warning_material()
    _aim_line.visible = false
    add_child(_aim_line)


func _update_visual() -> void:
    if state == State.DEAD:
        return
    _visual.scale.x = facing  # mirror the bow side toward the target
    var color: Color = Color(0.72, 0.68, 0.58)
    var emission: Color = Color.BLACK
    if state == State.AIM:
        emission = Color(1.0, 0.25, 0.05) * (0.4 + 0.6 * (_t / aim_time))
    if _silenced_left > 0.0:
        emission = Color(0.25, 0.3, 0.8) * 0.6
    if _flash_left > 0.0:
        color = Color.WHITE
    _body_material.albedo_color = color
    _body_material.emission_enabled = emission != Color.BLACK
    _body_material.emission = emission

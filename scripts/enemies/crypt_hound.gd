class_name CryptHound
extends CharacterBody3D
## Fast skeletal hound for ambushes. Runs you down, then telegraphs a pounce: it crouches and
## glows (`crouch_time` s), leaps in an arc toward where you stood (hitbox live in the air),
## and lands exposed for `recover_time` s, which is the punish window.
## States: RUN -> CROUCH -> POUNCE -> RECOVER -> RUN ; HITSTUN on poise break ; DEAD.
## Shares the combat contracts: Health/Hurtbox (team enemy), poise, silence, enemy group.

signal defeated
signal state_changed(state_name: String)

enum State { RUN, CROUCH, POUNCE, RECOVER, HITSTUN, DEAD }

@export var run_speed: float = 6.5
@export var pounce_range: float = 4.5
@export var crouch_time: float = 0.45
@export var recover_time: float = 0.8
@export var pounce_speed: float = 10.0
@export var pounce_lift: float = 6.0
@export var poise_max: int = 1
@export var max_health: int = 3
@export var min_x: float = -INF
@export var max_x: float = INF
@export var ai_enabled: bool = true

var state: State = State.RUN
var facing: float = -1.0
## Full 3D (EnemyFactory.full_3d): runs and pounces on X/Z within `leash_radius` of home.
var plane_locked: bool = true
var leash_radius: float = 12.0
var heading: Vector3 = Vector3(-1.0, 0.0, 0.0)
var home: Vector3
var _home_set: bool = false
var health: Health
var hurtbox: Hurtbox
var bite: Hitbox
var poise: int = 1
var pounces: int = 0
var _t: float = 0.0
var _stun_left: float = 0.0
var _silenced_left: float = 0.0
var _flash_left: float = 0.0
var _material: StandardMaterial3D
var _visual: Node3D


func _ready() -> void:
    add_to_group(&"enemy")
    add_to_group(&"silenceable")
    poise = poise_max
    var body_shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(1.1, 0.8, 0.5)
    body_shape.shape = box
    body_shape.position.y = -0.5
    add_child(body_shape)
    health = Health.new()
    health.max_health = max_health
    add_child(health)
    health.died.connect(_on_died)
    hurtbox = Hurtbox.new()
    hurtbox.team = &"enemy"
    hurtbox.health = health
    var hurt_shape: CollisionShape3D = CollisionShape3D.new()
    var hurt_box: BoxShape3D = BoxShape3D.new()
    hurt_box.size = Vector3(1.2, 0.9, 0.7)
    hurt_shape.shape = hurt_box
    hurt_shape.position.y = -0.45
    hurtbox.add_child(hurt_shape)
    add_child(hurtbox)
    hurtbox.hit_received.connect(_on_hit)
    bite = Hitbox.new()
    bite.team = &"enemy"
    bite.damage = 1
    bite.category = &"melee"
    bite.knockback = 5.0
    bite.knockback_up = 3.0
    bite.hitstun = 0.3
    bite.attack_id = &"hound_pounce"
    var bite_shape: CollisionShape3D = CollisionShape3D.new()
    var bite_box: BoxShape3D = BoxShape3D.new()
    bite_box.size = Vector3(1.3, 1.0, 1.0)
    bite_shape.shape = bite_box
    bite_shape.position.y = -0.45
    bite.add_child(bite_shape)
    add_child(bite)
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
    if state == State.CROUCH:
        _set_state(State.RUN)


func _physics_process(delta: float) -> void:
    if not _home_set:
        _home_set = true
        home = global_position
    _t += delta
    _stun_left = maxf(0.0, _stun_left - delta)
    _silenced_left = maxf(0.0, _silenced_left - delta)
    _flash_left = maxf(0.0, _flash_left - delta)
    var target: Node3D = _target()
    match state:
        State.RUN:
            _set_planar(Vector3.ZERO)
            if ai_enabled and target != null:
                var off: Vector3 = _planar_to(target)
                _face(off)
                if off.length() < pounce_range and _silenced_left <= 0.0 and is_on_floor():
                    _set_state(State.CROUCH)
                elif off.length() > 1.0 and _can_step(heading):
                    _set_planar(heading * run_speed)
        State.CROUCH:
            _set_planar(Vector3.ZERO)
            if target != null:
                _face(_planar_to(target))  # aims the leap at you until it springs
            if _t >= crouch_time:
                velocity = heading * pounce_speed + Vector3(0.0, pounce_lift, 0.0)
                bite.activate()
                pounces += 1
                Audio.sfx(&"hound_pounce")
                _set_state(State.POUNCE)
        State.POUNCE:
            if not _can_step(Vector3(velocity.x, 0.0, velocity.z)):
                _set_planar(Vector3.ZERO)
            if _t > 0.1 and is_on_floor():
                bite.deactivate()
                _set_state(State.RECOVER)
        State.RECOVER:
            _brake(30.0 * delta)
            if _t >= recover_time:
                _set_state(State.RUN)
        State.HITSTUN:
            _brake(8.0 * delta)
            if _stun_left <= 0.0:
                _set_state(State.RUN)
        State.DEAD:
            _brake(20.0 * delta)
    if not is_on_floor():
        velocity.y -= 26.0 * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0
    if plane_locked:
        velocity.z = 0.0
    move_and_slide()
    if plane_locked:
        position.z = 0.0
    if global_position.y < -9.0 and state != State.DEAD:
        health.apply_damage(health.current)
    _update_visual()


func _target() -> Node3D:
    var player: Node3D = Players.nearest(global_position) as Node3D
    if player == null or bool(player.get("in_3d_mode")) == plane_locked:
        return null
    var player_health: Health = player.get("health") as Health
    if player_health != null and player_health.is_dead():
        return null
    if _planar_to(player).length() > 16.0 or absf(player.global_position.y - global_position.y) > 3.0:
        return null
    return player


func _planar_to(target: Node3D) -> Vector3:
    var off: Vector3 = target.global_position - global_position
    off.y = 0.0
    if plane_locked:
        off.z = 0.0
    return off


func _face(dir: Vector3) -> void:
    dir.y = 0.0
    if plane_locked:
        if absf(dir.x) > 0.05:
            facing = signf(dir.x)
        heading = Vector3(facing, 0.0, 0.0)
    elif dir.length_squared() > 0.0001:
        heading = dir.normalized()
        if absf(heading.x) > 0.01:
            facing = signf(heading.x)


func _set_planar(v: Vector3) -> void:
    velocity.x = v.x
    velocity.z = 0.0 if plane_locked else v.z


func _brake(amount: float) -> void:
    var planar: Vector2 = Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, amount)
    velocity.x = planar.x
    velocity.z = planar.y


## Side view: x bounds (stepping back inside is always allowed); full 3D: the home leash.
func _can_step(dir: Vector3) -> bool:
    if plane_locked:
        var sx: float = signf(dir.x)
        var next_x: float = global_position.x + sx * 0.6
        return (next_x > min_x or sx > 0.0) and (next_x < max_x or sx < 0.0)
    if dir.length_squared() < 0.0001:
        return true
    var next: Vector3 = global_position + Vector3(dir.x, 0.0, dir.z).normalized() * 0.6 - home
    next.y = 0.0
    var now: Vector3 = global_position - home
    now.y = 0.0
    return next.length() < leash_radius or next.length() < now.length()


func _on_hit(info: DamageInfo) -> void:
    if state == State.DEAD:
        return
    _flash_left = 0.12
    poise -= info.poise_damage
    if poise > 0 or state == State.POUNCE:
        return  # mid-leap it cannot be knocked out of the air
    poise = poise_max
    bite.deactivate()
    velocity = info.knockback
    _stun_left = info.hitstun
    _set_state(State.HITSTUN)


func _on_died() -> void:
    bite.deactivate()
    _set_state(State.DEAD)
    hurtbox.set_enabled(false)
    set_deferred(&"collision_layer", 0)
    var tween: Tween = create_tween()
    tween.tween_property(_visual, "rotation:z", facing * PI, 0.35)
    tween.tween_property(_visual, "position:y", -0.6, 0.5)
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
    _material = StandardMaterial3D.new()
    _material.albedo_color = Color(0.62, 0.6, 0.55)
    var body: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(1.0, 0.45, 0.35)
    body.mesh = mesh
    body.material_override = _material
    body.position.y = -0.4
    _visual.add_child(body)
    var head: MeshInstance3D = MeshInstance3D.new()
    var head_mesh: BoxMesh = BoxMesh.new()
    head_mesh.size = Vector3(0.4, 0.32, 0.3)
    head.mesh = head_mesh
    head.material_override = _material
    head.position = Vector3(0.6, -0.2, 0.0)
    head.name = "Head"
    _visual.add_child(head)


func _update_visual() -> void:
    if state == State.DEAD:
        return
    if plane_locked:
        _visual.scale.x = facing
    else:
        _visual.scale.x = 1.0
        _visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-heading.z, heading.x), 0.3)
    _visual.scale.y = 0.75 if state == State.CROUCH else 1.0
    var color: Color = Color(0.62, 0.6, 0.55)
    var emission: Color = Color.BLACK
    if state == State.CROUCH:
        emission = Color(1.0, 0.25, 0.05) * (0.5 + 0.5 * (_t / crouch_time))
    if _silenced_left > 0.0:
        emission = Color(0.25, 0.3, 0.8) * 0.6
    if _flash_left > 0.0:
        color = Color.WHITE
    _material.albedo_color = color
    _material.emission_enabled = emission != Color.BLACK
    _material.emission = emission

class_name PlaguedSoldier
extends CharacterBody3D
## First enemy family: a shambling plagued soldier with one readable overhead slash.
##
## States: PATROL → CHASE (player within aggro range) → ATTACK (MeleeAttack phases:
## STARTUP is the telegraph, ACTIVE hits, RECOVERY is the punish window) → back to CHASE.
## Poise: every hit flashes the soldier and makes it flinch, but only breaking its poise
## (sum of DamageInfo.poise_damage >= `poise_max`; light 1, finisher/spear 2, heavy 3) cancels its
## attack and staggers it (HITSTUN + knockback). Poise refills after `poise_regen_delay` s
## without being hit — so fast combos cannot stun-lock it, but they do wear it down.
## DEAD disables hurt/contact boxes and body collision, so the corpse never blocks the route.
## Touching the soldier deals light contact damage (`contact_damage`, at most once per second).
## Leash: the soldier never moves outside [patrol_min_x - leash_margin, patrol_max_x + leash_margin],
## so it cannot follow the player off a ledge. If it is ever knocked into a pit it returns home,
## because the level's exit depends on it being killable.
## Abilities:
##   Plague Lunge (`lunge_enabled`): at 3–6 m it crouches (0.55 s telegraph, red marker) and
##     dashes ~2.5 m forward with its blade out — back off or dodge through.
##   Frenzy (`enrage_enabled`, soldiers with >= 4 HP): at half health it turns red, chases 30%
##     faster and attacks twice as often.
##   Death Burst (`burst_on_death`, Husks): 0.6 s after dying it bursts in a plague cloud
##     (StrikeZone, 1.3 m, 1 damage) — don't stand on the corpse.
## Unlocked (plane_locked = false, Reality Fracture arenas): it chases and strikes on X/Z and is
## leashed to `leash_radius` around its home instead of the X range.

signal defeated
signal state_changed(state_name: String)

enum State { IDLE, PATROL, CHASE, ATTACK, HITSTUN, DEAD }

@export var patrol_min_x: float = 1.5
@export var patrol_max_x: float = 8.0
@export var patrol_speed: float = 2.2
@export var chase_speed: float = 4.4
@export var aggro_range: float = 8.0
@export var aggro_height: float = 2.5
@export var attack_range: float = 1.7
@export var attack_cooldown: float = 0.5
@export var leash_margin: float = 0.5
@export var poise_max: int = 3
@export var poise_regen_delay: float = 1.5
## Free-movement leash (used when plane_locked is false); 0 disables it.
@export var leash_radius: float = 0.0
@export var kill_plane_y: float = -9.0
@export var plane_locked: bool = true
@export var gravity_force: float = 26.0
## Debug/test switch: when false the soldier idles in place (deterministic test setups).
@export var ai_enabled: bool = true
@export var lunge_enabled: bool = true
@export var lunge_cooldown: float = 3.5
@export var enrage_enabled: bool = true
@export var burst_on_death: bool = false
@export var slash: AttackData
@export var health: Health
@export var hurtbox: Hurtbox
@export var melee: MeleeAttack
@export var contact_hitbox: Hitbox
@export var contact_damage: int = 1
@export var visual: Node3D
@export var telegraph_marker: MeshInstance3D

var state: State = State.PATROL
var facing: Vector3 = Vector3.LEFT

var _patrol_dir: float = -1.0
var _stun_left: float = 0.0
var _cooldown_left: float = 0.0
var _body_material: StandardMaterial3D
var _base_color: Color
var _home: Vector3
var _death_tween: Tween
var poise: int = 3
var _poise_regen_left: float = 0.0
var _flash_left: float = 0.0
var _flinch_left: float = 0.0
var _silenced_left: float = 0.0
var _lunge_left: float = 1.5
var enraged: bool = false
var _calm_color: Color
static var _lunge_data: AttackData


## The Plague Lunge attack (shared by every soldier).
static func lunge_attack() -> AttackData:
    if _lunge_data == null:
        _lunge_data = AttackData.new()
        _lunge_data.id = &"soldier_lunge"
        _lunge_data.startup = 0.55
        _lunge_data.active = 0.22
        _lunge_data.recovery = 0.55
        _lunge_data.damage = 1
        _lunge_data.knockback = 6.0
        _lunge_data.hitstun = 0.3
        _lunge_data.reach_offset = 0.8
        _lunge_data.reach = 1.4
        _lunge_data.lunge_speed = 11.0
    return _lunge_data


func _ready() -> void:
    add_to_group(&"enemy")
    add_to_group(&"silenceable")
    poise = poise_max
    hurtbox.hit_received.connect(_on_hit_received)
    health.died.connect(_on_died)
    melee.phase_changed.connect(_on_attack_phase)
    melee.attack_finished.connect(_on_attack_finished)
    contact_hitbox.damage = contact_damage
    contact_hitbox.knockback = 5.0
    contact_hitbox.knockback_up = 2.5
    contact_hitbox.hitstun = 0.25
    contact_hitbox.category = &"contact"
    contact_hitbox.attack_id = &"soldier_contact"
    telegraph_marker.visible = false
    var body_mesh: MeshInstance3D = visual.get_node("Body") as MeshInstance3D
    _body_material = (body_mesh.material_override as StandardMaterial3D).duplicate()
    body_mesh.material_override = _body_material
    _base_color = _body_material.albedo_color
    _home = position
    if not ai_enabled:
        _set_state(State.IDLE)


func state_name() -> String:
    return State.keys()[state]


func set_ai_enabled(enabled: bool) -> void:
    ai_enabled = enabled
    if state == State.DEAD:
        return
    if not enabled:
        melee.cancel()
        _set_state(State.IDLE)
    elif state == State.IDLE:
        _set_state(State.PATROL)


func teleport_to(target: Vector3) -> void:
    global_position = target
    velocity = Vector3.ZERO


## Bell of Silence: no new attacks for `seconds`; an attack still winding up is cancelled.
func silence(seconds: float) -> void:
    if state == State.DEAD:
        return
    _silenced_left = maxf(_silenced_left, seconds)
    if melee.phase == MeleeAttack.Phase.STARTUP:
        melee.cancel()
        telegraph_marker.visible = false
        _set_state(State.CHASE if ai_enabled else State.IDLE)


func is_silenced() -> bool:
    return _silenced_left > 0.0


func is_dead() -> bool:
    return state == State.DEAD


## Full reset used when an encounter is retried (e.g. the player fails a Reality Fracture).
func revive_at_home() -> void:
    if _death_tween and _death_tween.is_valid():
        _death_tween.kill()
    melee.cancel()
    health.restore_full()
    if enraged:
        enraged = false
        _base_color = _calm_color
    _lunge_left = 1.5
    visual.position = Vector3.ZERO
    visual.rotation = Vector3.ZERO
    collision_layer = 1
    collision_mask = 1
    hurtbox.set_enabled(true)
    contact_hitbox.activate()
    telegraph_marker.visible = false
    _stun_left = 0.0
    _cooldown_left = 0.0
    poise = poise_max
    teleport_to(_home)
    state = State.IDLE  # force a state_changed below even if it was already IDLE
    _set_state(State.PATROL if ai_enabled else State.IDLE)


func _physics_process(delta: float) -> void:
    _stun_left = maxf(0.0, _stun_left - delta)
    _cooldown_left = maxf(0.0, _cooldown_left - delta)
    _flash_left = maxf(0.0, _flash_left - delta)
    _silenced_left = maxf(0.0, _silenced_left - delta)
    _flinch_left = maxf(0.0, _flinch_left - delta)
    _lunge_left = maxf(0.0, _lunge_left - delta)
    if poise < poise_max:
        _poise_regen_left -= delta
        if _poise_regen_left <= 0.0:
            poise = poise_max

    match state:
        State.IDLE, State.DEAD:
            velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
        State.PATROL:
            _patrol()
            if _target_in_aggro():
                _set_state(State.CHASE)
        State.CHASE:
            _chase()
        State.ATTACK:
            _attack_motion()
        State.HITSTUN:
            velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
            if _stun_left <= 0.0:
                _set_state(State.CHASE if ai_enabled else State.IDLE)

    if not is_on_floor():
        velocity.y -= gravity_force * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0
    if plane_locked:
        velocity.z = 0.0
        position.z = 0.0
    _apply_leash()
    move_and_slide()
    if plane_locked:
        position.z = 0.0
    if global_position.y < kill_plane_y and state != State.DEAD:
        teleport_to(_home)
        _set_state(State.PATROL if ai_enabled else State.IDLE)
    _update_visual()


func _apply_leash() -> void:
    if state == State.HITSTUN or state == State.DEAD:
        return
    if not plane_locked and leash_radius > 0.0:
        var out: Vector3 = global_position - _home
        out.y = 0.0
        if out.length() >= leash_radius:
            var dir: Vector3 = out.normalized()
            var outward: float = velocity.x * dir.x + velocity.z * dir.z
            if outward > 0.0:
                velocity.x -= dir.x * outward
                velocity.z -= dir.z * outward
        return
    # Predictive: fast moves (Plague Lunge) must not step past the leash within one frame.
    var x: float = global_position.x + velocity.x * get_physics_process_delta_time()
    if (x <= patrol_min_x - leash_margin and velocity.x < 0.0) or (x >= patrol_max_x + leash_margin and velocity.x > 0.0):
        velocity.x = 0.0


func _target() -> Node3D:
    var player: Node3D = Players.nearest(global_position) as Node3D
    if player == null or bool(player.get("in_3d_mode")) != (not plane_locked):
        return null
    var player_health: Health = player.get("health") as Health
    if player_health != null and player_health.is_dead():
        return null
    return player


func _target_in_aggro() -> bool:
    var target: Node3D = _target()
    if target == null:
        return false
    var offset: Vector3 = target.global_position - global_position
    return absf(offset.y) < aggro_height and Vector2(offset.x, offset.z).length() < aggro_range


func _patrol() -> void:
    if global_position.x <= patrol_min_x:
        _patrol_dir = 1.0
    elif global_position.x >= patrol_max_x:
        _patrol_dir = -1.0
    facing = Vector3(_patrol_dir, 0.0, 0.0)
    velocity.x = _patrol_dir * patrol_speed
    velocity.z = 0.0


func _chase() -> void:
    var target: Node3D = _target()
    if target == null or not _target_in_aggro():
        _set_state(State.PATROL)
        return
    var offset: Vector3 = target.global_position - global_position
    offset.y = 0.0
    var distance: float = offset.length()
    if distance > 0.01:
        facing = offset / distance
    if distance <= attack_range and _cooldown_left <= 0.0 and _silenced_left <= 0.0:
        velocity.x = 0.0
        velocity.z = 0.0
        if melee.start(slash, facing):
            _set_state(State.ATTACK)
        return
    if lunge_enabled and _lunge_left <= 0.0 and _silenced_left <= 0.0 and distance > 3.0 and distance < 6.0:
        velocity.x = 0.0
        velocity.z = 0.0
        if melee.start(lunge_attack(), facing):
            _lunge_left = lunge_cooldown
            Audio.sfx(&"soldier_lunge")
            _set_state(State.ATTACK)
        return
    var speed: float = chase_speed if distance > attack_range * 0.8 else 0.0
    if enraged:
        speed *= 1.3
    velocity.x = facing.x * speed
    velocity.z = facing.z * speed


func _attack_motion() -> void:
    if melee.phase == MeleeAttack.Phase.ACTIVE and melee.current != null:
        velocity.x = melee.facing.x * melee.current.lunge_speed
        velocity.z = melee.facing.z * melee.current.lunge_speed
    else:
        velocity.x = 0.0
        velocity.z = 0.0


func _on_attack_phase(phase: MeleeAttack.Phase) -> void:
    var telegraphing: bool = phase == MeleeAttack.Phase.STARTUP
    telegraph_marker.visible = telegraphing
    if telegraphing:
        var reach_center: Vector3 = melee.facing * (melee.current.reach_offset if melee.current else slash.reach_offset)
        telegraph_marker.position = Vector3(reach_center.x, -0.82, reach_center.z)
        telegraph_marker.basis = Basis.looking_at(melee.facing, Vector3.UP)


func _on_attack_finished(_data: AttackData) -> void:
    telegraph_marker.visible = false
    _cooldown_left = attack_cooldown * (0.5 if enraged else 1.0)
    if state == State.ATTACK:
        _set_state(State.CHASE if ai_enabled else State.IDLE)


func _on_hit_received(info: DamageInfo) -> void:
    if state == State.DEAD:
        return
    _flash_left = 0.12
    _flinch_left = 0.2
    poise -= info.poise_damage
    _poise_regen_left = poise_regen_delay
    if enrage_enabled and not enraged and health.max_health >= 4 and health.current * 2 <= health.max_health and not health.is_dead():
        enraged = true
        _calm_color = _base_color
        _base_color = Color(0.75, 0.18, 0.12)
    if poise > 0:
        # Flinch only: keep any attack going, small shove if not mid-swing.
        if state != State.ATTACK:
            velocity.x = info.knockback.x * 0.3
            velocity.z = info.knockback.z * 0.3
        return
    poise = poise_max
    melee.cancel()
    telegraph_marker.visible = false
    velocity = info.knockback
    _stun_left = info.hitstun
    if not health.is_dead():
        _set_state(State.HITSTUN)


func _on_died() -> void:
    melee.cancel()
    telegraph_marker.visible = false
    _set_state(State.DEAD)
    contact_hitbox.deactivate()
    hurtbox.set_enabled(false)
    set_deferred(&"collision_layer", 0)
    set_deferred(&"collision_mask", 1)
    _death_tween = create_tween()
    _death_tween.tween_property(visual, "rotation:x", PI * 0.5, 0.35)
    _death_tween.tween_property(visual, "position:y", -0.7, 0.8)
    if burst_on_death and is_inside_tree():
        get_tree().create_timer(0.6).timeout.connect(func() -> void: Audio.sfx(&"husk_burst"))
        get_parent().add_child(StrikeZone.create(global_position + Vector3(0.0, -0.95, 0.0), 1.3, 0.5, 0.6, 1, &"husk_burst", &"burst"))
    defeated.emit()


func _set_state(next: State) -> void:
    if state == next:
        return
    state = next
    state_changed.emit(state_name())


func _update_visual() -> void:
    if state == State.DEAD:
        return
    if absf(facing.x) > 0.01 or absf(facing.z) > 0.01:
        visual.basis = Basis.looking_at(Vector3(facing.x, 0.0, facing.z), Vector3.UP)
        if _flinch_left > 0.0:
            # Recoil: lean back away from facing for a moment.
            visual.basis = visual.basis * Basis(Vector3.RIGHT, 0.35 * (_flinch_left / 0.2))
    var color: Color = _base_color
    var emission: Color = Color.BLACK
    if melee.phase == MeleeAttack.Phase.STARTUP:
        # Pulsing wind-up glow: the readable "about to strike" cue.
        var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
        emission = Color(1.0, 0.35, 0.05) * (0.6 + 0.8 * pulse)
    elif melee.phase == MeleeAttack.Phase.ACTIVE:
        emission = Color(1.0, 0.1, 0.05) * 1.5
    elif state == State.HITSTUN:
        color = Color(0.9, 0.85, 0.8)
    if _silenced_left > 0.0:
        emission = Color(0.25, 0.3, 0.8) * 0.6
    if _flash_left > 0.0:
        color = Color(1.0, 1.0, 1.0)
        emission = Color(1.0, 0.95, 0.9) * 0.8
    _body_material.albedo_color = color
    _body_material.emission_enabled = emission != Color.BLACK
    _body_material.emission = emission

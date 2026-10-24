class_name StitchedBrute
extends CreatureEnemy
## The Stitched Brute (DEC-064): a hulking abomination sewn together from corpses, a butcher's
## cleaver fused through its right wrist, two withered extra arms twitching on its back and a
## moaning face sewn into its belly. Slow, heavy, hard to stagger (poise 6).
##   Cleave: within `slam_range` it heaves the cleaver overhead for `slam_windup` s (back arched,
##     a red box on the floor where it will land), then chops it down (2 damage, big knockback)
##     and stays bent over the stuck blade for `slam_recover` s: the punish window.
##   Charge: from `charge_min`..`charge_max` m it lowers its head and paws the ground for
##     `charge_windup` s (a red lane), then charges along it (1 damage); a wall dazes it.
## A poise break only interrupts a wind-up. Death: a heavy forward fall and a big gore burst.
## States: idle -> slam_windup -> slam -> slam_recover ; idle -> charge_windup -> charging ->
## charge_recover | stagger ; hitstun ; dead.

@export var walk_speed: float = 1.7
@export var slam_range: float = 2.7
@export var slam_windup: float = 1.0
@export var slam_recover: float = 1.25
@export var charge_min: float = 5.0
@export var charge_max: float = 11.0
@export var charge_windup: float = 0.9
@export var charge_speed: float = 9.0
@export var charge_time: float = 1.25
@export var charge_recover: float = 0.9
@export var daze_time: float = 1.3
@export var rest_time: float = 1.1

var cleaver: Hitbox
var ram: Hitbox
var moves: Array[StringName] = []
var _slam_marker: MeshInstance3D
var _lane: MeshInstance3D
var _chop: float = 0.0
var _heave: float = 0.0
var _hunch: float = 0.0
var _impact_done: bool = false


func _init() -> void:
    max_health = 14
    poise_max = 6
    shard_value = 12
    leash_radius = 12.0
    _base_color = Color(0.55, 0.52, 0.46)


func _build_body() -> void:
    _add_collider(Vector3(1.2, 2.5, 1.1), 0.25)
    _add_hurt_shape(Vector3(1.5, 2.7, 1.4), 0.3)
    cleaver = _make_hitbox(Vector3(1.7, 1.9, 1.7), Vector3(1.55, -0.1, 0.0), 2, &"brute_cleave", 9.5)
    cleaver.knockback_up = 4.5
    cleaver.hitstun = 0.5
    cleaver.poise_damage = 3
    ram = _make_hitbox(Vector3(1.6, 2.2, 1.6), Vector3(0.45, 0.2, 0.0), 1, &"brute_charge", 11.0)
    _slam_marker = _warning(Vector3(1.7, 0.05, 1.6))
    _lane = _warning(Vector3(10.0, 0.05, 1.5))
    _build_rig("stitched_brute", Vector3(1.2, 2.5, 1.0))
    if rig != null:
        gait = CreatureGait.new(rig, self)
        gait.stride = 0.5
        gait.swing_time = 0.34
        gait.lift = 0.14
        gait.lead = 0.3
        gait.add_leg(&"leg_L_up", &"leg_L_lo", &"foot_L", 0, Vector3(0.1, 0.0, 1.0), Vector3(0.04, 0.0, 0.0))
        gait.add_leg(&"leg_R_up", &"leg_R_lo", &"foot_R", 1, Vector3(-0.1, 0.0, 1.0), Vector3(-0.04, 0.0, 0.0))
        gait.on_step = _on_step


func _roam_style() -> Roam3D.Style:
    return Roam3D.Style.GUARD


func _tick(delta: float, target: Node3D) -> void:
    hitbox_ahead(cleaver, 1.55, -0.1)
    hitbox_ahead(ram, 0.45, 0.2)
    match state:
        &"idle":
            stop()
            if not ai_enabled:
                return
            if target == null:
                roam_idle(delta, walk_speed * 0.7)
                return
            var off: Vector3 = planar_to(target)
            var dist: float = off.length()
            face(off)
            if roam != null:
                engage(delta, target, slam_range * 0.75, walk_speed, walk_speed * 0.4)
            elif dist > slam_range * 0.8:
                move_dir(chase_dir(target), walk_speed)
            if _t < rest_time or _silenced_left > 0.0 or not is_on_floor():
                return
            if dist < slam_range + 0.3:
                start_move(&"slam")
            elif dist > charge_min and dist < charge_max and absf(target.global_position.y - global_position.y) < 1.2 \
                    and (roam == null or roam.safe_step(off, 3.0)) and can_step(off, 2.0):
                start_move(&"charge")
        &"slam_windup":
            stop()
            if target != null and _t < slam_windup * 0.6:
                face(planar_to(target))
            _place_marker(_slam_marker, 1.55)
            if _t >= slam_windup:
                _slam_marker.visible = false
                cleaver.activate()
                _impact_done = false
                Audio.sfx(&"heavy_swing", 0.08, 2.0)
                set_state(&"slam")
        &"slam":
            stop()
            if _t >= 0.08 and not _impact_done:
                _impact_done = true
                Audio.sfx(&"bishop_slam", 0.08)
                get_tree().call_group(&"camera_shaker", &"add_trauma", 0.45)
            if _t >= 0.2:
                cleaver.deactivate()
                set_state(&"slam_recover")
        &"slam_recover":
            stop()
            if _t >= slam_recover:
                set_state(&"idle")
        &"charge_windup":
            stop()
            if target != null and _t < charge_windup * 0.75:
                face(planar_to(target))
            _place_marker(_lane, 5.5)
            if _t >= charge_windup:
                _lane.visible = false
                ram.activate()
                _ghost_player(true)
                Audio.sfx(&"bishop_roar", 0.12, -6.0)
                set_state(&"charging")
        &"charging":
            move_dir(heading, charge_speed)
            var wall: bool = _hit_static_wall()
            var edge: bool = not can_step(heading, 0.8) or (roam != null and not roam.safe_step(heading, 1.6))
            if (wall or edge) and _t > 0.1:
                ram.deactivate()
                if wall:
                    move_dir(-heading, 2.5)
                    Audio.sfx(&"bishop_slam", 0.05, -4.0)
                    get_tree().call_group(&"camera_shaker", &"add_trauma", 0.35)
                    _stun_left = daze_time
                    set_state(&"stagger")
                else:
                    stop()
                    set_state(&"charge_recover")
            elif _t >= charge_time:
                ram.deactivate()
                set_state(&"charge_recover")
        &"charge_recover":
            _brake(18.0 * delta)
            if _t >= charge_recover:
                set_state(&"idle")


## Starts a move now (AI, tests).
func start_move(move: StringName) -> void:
    moves.append(move)
    match move:
        &"slam":
            set_state(&"slam_windup")
            Audio.sfx(&"player_effort", 0.2, -2.0)
        &"charge":
            set_state(&"charge_windup")


func set_state(next: StringName) -> void:
    if state == &"charging" and next != &"charging":
        _ghost_player(false)
    if next != &"slam_windup":
        _slam_marker.visible = false
    if next != &"charge_windup":
        _lane.visible = false
    super.set_state(next)


func _ghost_player(on: bool) -> void:
    for player: Node3D in Players.all():
        if on:
            add_collision_exception_with(player as PhysicsBody3D)
        else:
            remove_collision_exception_with(player as PhysicsBody3D)


func _hit_static_wall() -> bool:
    for i in get_slide_collision_count():
        var hit: KinematicCollision3D = get_slide_collision(i)
        if hit.get_collider() is StaticBody3D and hit.get_normal().dot(heading) < -0.5:
            return true
    return false


func _on_step(_at: Vector3) -> void:
    if speed() > 0.5 or state == &"charging":
        get_tree().call_group(&"camera_shaker", &"add_trauma", 0.04 if state != &"charging" else 0.08)


func _on_poise_break(info: DamageInfo) -> void:
    if state in [&"slam_windup", &"charge_windup"]:
        _stun_left = 0.9
        set_state(&"stagger")
    velocity.x = info.knockback.x * 0.15
    velocity.z = info.knockback.z * 0.15 if not plane_locked else 0.0


func _on_silenced() -> void:
    if state in [&"slam_windup", &"charge_windup"]:
        set_state(&"idle")


func _on_died() -> void:
    cleaver.deactivate()
    ram.deactivate()
    _ghost_player(false)
    super._on_died()


func _on_death_fx() -> void:
    _impact_done = false
    Audio.sfx(&"bishop_roar", 0.15, -2.0)


func _glow() -> Color:
    match state:
        &"slam_windup", &"charge_windup":
            return Color(1.0, 0.18, 0.04) * (0.4 + 0.6 * sin(_t * 16.0) * 0.5 + 0.3)
        &"stagger":
            return Color(0.9, 0.8, 0.2) * 0.45
    return Color.BLACK


# --- Animation --------------------------------------------------------------------------------

func _animate(delta: float) -> void:
    var heave_to: float = 0.0
    var chop_to: float = 0.0
    var hunch_to: float = 0.0
    match state:
        &"slam_windup":
            heave_to = clampf(_t / (slam_windup * 0.75), 0.0, 1.0)
        &"slam":
            chop_to = 1.0
        &"slam_recover":
            chop_to = 1.0 if _t < slam_recover * 0.6 else 0.0
        &"charge_windup", &"charging":
            hunch_to = 1.0
        &"stagger":
            hunch_to = 0.4
    _heave = move_toward(_heave, heave_to, delta * (2.5 if heave_to > _heave else 6.0))
    _chop = move_toward(_chop, chop_to, delta * (14.0 if chop_to > _chop else 1.6))
    _hunch = move_toward(_hunch, hunch_to, delta * 3.0)
    var sp: float = clampf(speed() / walk_speed, 0.0, 2.0)
    var breath: float = sin(anim_t * 1.6)
    if gait != null:
        gait.update(delta, feet_y(), is_on_floor(), 1.0 if state != &"charging" else 2.6)
    var sway: float = sin(anim_t * 3.4) * 0.07 * minf(sp, 1.0)
    var chop: float = _chop * _chop
    # Body: hunched, rocking side to side with its steps; arches back to heave the cleaver.
    rig.shift(&"pelvis", Vector3(0.0, -0.08 - 0.12 * chop - 0.1 * _hunch + breath * 0.01 - absf(sway) * 0.3, 0.0))
    rig.turn(&"pelvis", Vector3(0.05 + 0.15 * _hunch, sway * 0.6, sway))
    rig.turn(&"torso", Vector3(0.36 - 0.55 * _heave + 0.7 * chop + 0.35 * _hunch + breath * 0.025, -0.2 * _heave, -sway * 0.8))
    var ht: Vector3 = twitch(&"head", Vector3(0.25, 0.45, 0.4), 1.1, delta)
    rig.turn(&"head", Vector3(-0.1 + 0.25 * _hunch + ht.x, ht.y, 0.3 * sin(anim_t * 0.5) + ht.z))
    rig.turn(&"head_b", Vector3(0.25 + 0.1 * sin(anim_t * 1.1), 0.0, 0.55 + 0.15 * sin(anim_t * 0.8 + sway * 4.0)) + twitch(&"hb", Vector3(0.15, 0.2, 0.25), 1.6, delta))
    # Arms: the left swings with the walk; the cleaver arm drags, heaves overhead, chops down.
    var swing: float = sin(anim_t * 3.4) * 0.35 * minf(sp, 1.0)
    rig.turn(&"arm_L_up", Vector3(swing - 2.0 * _heave + 0.6 * _hunch - 0.7 * chop, 0.0, -0.12 - 0.3 * _heave))
    rig.turn(&"arm_L_lo", Vector3(-0.35 - 0.4 * _heave, 0.0, 0.0))
    rig.turn(&"hand_L", twitch(&"hand", Vector3(0.3, 0.2, 0.3), 0.8, delta))
    rig.turn(&"arm_R_up", Vector3(-swing * 0.5 - 2.75 * _heave + 0.5 * _hunch - 1.15 * chop * (1.0 - _heave), 0.0, 0.12 + 0.25 * _heave))
    rig.turn(&"arm_R_lo", Vector3(-0.25 - 0.9 * _heave + 0.15 * chop, 0.0, 0.0))
    # The extra limbs never stop moving.
    rig.turn(&"extra_a", Vector3(0.3, 0.0, 0.0) + twitch(&"xa", Vector3(0.7, 0.6, 0.7), 0.35, delta))
    rig.turn(&"extra_b", twitch(&"xb", Vector3(0.6, 0.8, 0.6), 0.3, delta) + Vector3(sin(anim_t * 7.0) * 0.12, 0.0, 0.0))
    if gait != null:
        for tag: String in ["L", "R"]:
            rig.level(StringName("foot_" + tag))


func _animate_death(delta: float) -> void:
    var k: float = clampf(death_t / 0.75, 0.0, 1.0)
    var e: float = k * k * k
    if k >= 1.0 and not _impact_done:
        _impact_done = true
        get_tree().call_group(&"camera_shaker", &"add_trauma", 0.4)
        Audio.sfx(&"bishop_slam", 0.1, -3.0)
    rig.shift(&"pelvis", Vector3(0.0, lerpf(-0.08, -0.62, e), 0.18 * e))
    rig.turn(&"pelvis", Vector3(lerpf(0.05, 1.42, e), 0.0, 0.12 * e))
    rig.turn(&"torso", Vector3(0.1, 0.0, 0.0))
    rig.turn(&"head", Vector3(-0.5 * e, 0.4, 0.5))
    rig.turn(&"arm_L_up", Vector3(-1.8 * e, 0.0, -0.6 * e))
    rig.turn(&"arm_R_up", Vector3(-1.6 * e, 0.0, 0.5 * e))
    rig.turn(&"leg_L_up", Vector3(-0.2 * e, 0.0, 0.1))
    rig.turn(&"leg_R_up", Vector3(-0.3 * e, 0.0, -0.1))
    var spasm: float = exp(-death_t * 1.5)
    rig.turn(&"extra_a", twitch(&"dxa", Vector3(0.9, 0.8, 0.9), 0.15, delta) * spasm)
    rig.turn(&"extra_b", twitch(&"dxb", Vector3(0.9, 0.8, 0.9), 0.15, delta) * spasm)

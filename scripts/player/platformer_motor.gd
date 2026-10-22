class_name PlatformerMotor
extends RefCounted
## The full-3D platformer moveset (design: docs/superpowers/specs/2026-10-22-3d-platformer-design.md).
## Owned by the player and stepped instead of the plain 3D run/jump whenever a third-person camera
## drives the player. Every move is an explicit state with entry rules, so animation and tests
## read the state instead of guessing from velocity.
##
## Moves: momentum run (speed builds 8.5 -> 11 m/s running straight), skid turn (+ side flip),
## variable jump, triple jump chain, crouch / crouch-walk / slide, long jump, backflip, wall slide
## + wall kick, ledge grab (hang, shimmy, pull up, drop) and ground pound. The dash stays the
## player's (it overrides everything while it lasts).
##
## Our own numbers, written from scratch; tuned in playtests.

enum State { GROUND, AIR, SKID, CROUCH, SLIDE, WALL_SLIDE, HANG, PULL_UP, POUND_SPIN, POUND_FALL, POUND_LAND }
enum Jump { NONE, SINGLE, DOUBLE, TRIPLE, LONG, BACKFLIP, SIDE_FLIP, WALL_KICK, FALL }

# --- Tuning -----------------------------------------------------------------------------------
const RUN_SPEED: float = 8.5
const BOOST_SPEED: float = 11.0
const BOOST_DELAY: float = 0.4  # running straight this long before speed starts building
const BOOST_RAMP: float = 0.8  # then this long to reach BOOST_SPEED
const CROUCH_SPEED: float = 2.5
const SKID_TIME: float = 0.18
const SKID_MIN_SPEED: float = 6.0
const SKID_EXIT_SPEED: float = 5.0
const SLIDE_MIN_SPEED: float = 6.0
const SLIDE_FRICTION: float = 9.0
const SLIDE_MAX_TIME: float = 0.9
const CHAIN_WINDOW: float = 0.15  # jump this soon after landing to chain the next jump
const CHAIN_MIN_SPEED: float = 5.0
const HEIGHT: Dictionary = {
    Jump.SINGLE: 2.3, Jump.DOUBLE: 2.9, Jump.TRIPLE: 3.8, Jump.LONG: 1.0,
    Jump.BACKFLIP: 3.6, Jump.SIDE_FLIP: 3.2, Jump.WALL_KICK: 2.6,
}
const LONG_GRAVITY_SCALE: float = 0.45
const LONG_MIN_SPEED: float = 14.0
const LONG_MAX_SPEED: float = 16.0
const BACKFLIP_BACK_SPEED: float = 2.5
const SIDE_FLIP_SPEED: float = 4.5
const WALL_SLIDE_SPEED: float = 3.5
const WALL_KICK_SPEED: float = 7.5
const WALL_KICK_LOCK: float = 0.22
const WALL_MIN_HEIGHT: float = 1.0  # no wall slide this close above the floor
const HANG_DROP: float = 1.25  # body centre below the ledge top while hanging
const SHIMMY_SPEED: float = 2.2
const PULL_UP_TIME: float = 0.3
const REGRAB_COOLDOWN: float = 0.35
const POUND_SPIN_TIME: float = 0.28
const POUND_FALL_SPEED: float = 26.0
const POUND_LAND_TIME: float = 0.25
const POUND_RADIUS: float = 2.0
const POUND_DAMAGE: int = 2
const STAND_HEIGHT: float = 1.7
const CROUCH_HEIGHT: float = 1.0

## The player (player.gd has no class name: its tuning and timers are read dynamically).
var player
var state: State = State.GROUND
var jump_kind: Jump = Jump.NONE
## Seconds in the current state (animation reads it for flips and spins).
var state_time: float = 0.0
var chain: int = 0  # 0 none, 1/2/3 = last jump in the triple chain
var run_time: float = 0.0
var ledge_normal: Vector3 = Vector3.ZERO
var ledge_top: float = 0.0
var wall_normal: Vector3 = Vector3.ZERO
var crouched: bool = false
var _hang_let_go: bool = false  # pushing toward the wall pulls up only after first easing off

var _chain_left: float = 0.0
var _control_lock: float = 0.0
var _regrab_left: float = 0.0
var _skid_dir: Vector2 = Vector2.ZERO
var _pull_from: Vector3
var _pull_to: Vector3
var _shape: CapsuleShape3D
var _collision: CollisionShape3D


func _init(owner_body: CharacterBody3D) -> void:
    player = owner_body
    _collision = player.get_node_or_null("BodyCollision") as CollisionShape3D
    if _collision != null and _collision.shape is CapsuleShape3D:
        _shape = (_collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D  # crouching must not shrink other players
        _collision.shape = _shape


# --- Queries ----------------------------------------------------------------------------------

func rise_gravity() -> float:
    return 2.0 * float(player.jump_height3d) / pow(float(player.jump_rise_time3d), 2.0)


func fall_gravity() -> float:
    return 2.0 * float(player.jump_height3d) / pow(float(player.jump_fall_time3d), 2.0)


## Launch speed that peaks at `height` metres under the rising gravity (scaled for the long jump).
func launch_speed(height: float, gravity_scale: float = 1.0) -> float:
    return sqrt(2.0 * rise_gravity() * gravity_scale * height)


## No sword swings while hanging, sliding on a wall, pulling up or ground-pounding.
func blocks_attacks() -> bool:
    return state in [State.HANG, State.PULL_UP, State.WALL_SLIDE, State.POUND_SPIN, State.POUND_FALL, State.POUND_LAND]


## No dash out of a hang or a pound.
func blocks_dodge() -> bool:
    return state in [State.HANG, State.PULL_UP, State.POUND_SPIN, State.POUND_FALL, State.POUND_LAND]


## The motor owns the facing in these states (wall, ledge, flips) — the stick doesn't turn you.
func locks_facing() -> bool:
    return state in [State.SKID, State.WALL_SLIDE, State.HANG, State.PULL_UP, State.POUND_SPIN, State.POUND_FALL, State.POUND_LAND] \
            or (state == State.AIR and jump_kind in [Jump.BACKFLIP, Jump.LONG, Jump.WALL_KICK])


func reset() -> void:
    if _collision != null:
        _collision.disabled = false
    _set_state(State.AIR if not player.is_on_floor() else State.GROUND)
    jump_kind = Jump.NONE
    chain = 0
    run_time = 0.0
    _control_lock = 0.0
    _set_crouched(false)


# --- Step -------------------------------------------------------------------------------------

## One physics step. `wish` is the camera-relative stick (x, z), length 0..1.
func step(wish: Vector2, on_floor: bool, delta: float) -> void:
    state_time += delta
    _chain_left = maxf(0.0, _chain_left - delta)
    _control_lock = maxf(0.0, _control_lock - delta)
    _regrab_left = maxf(0.0, _regrab_left - delta)
    var crouch_held: bool = Input.is_action_pressed(player.act(&"crouch"))
    var crouch_pressed: bool = Input.is_action_just_pressed(player.act(&"crouch"))
    var jump_wanted: bool = float(player._buffer_left) > 0.0
    match state:
        State.HANG:
            _step_hang(wish, jump_wanted, crouch_pressed, delta)
            return
        State.PULL_UP:
            _step_pull_up()
            return
        State.POUND_SPIN:
            player.velocity = Vector3.ZERO
            if state_time >= POUND_SPIN_TIME:
                _set_state(State.POUND_FALL)
            return
        State.POUND_FALL:
            player.velocity = Vector3(0.0, -POUND_FALL_SPEED, 0.0)
            if on_floor:
                _pound_impact()
            return
        State.POUND_LAND:
            player.velocity = Vector3.ZERO
            if state_time >= POUND_LAND_TIME:
                _set_state(State.GROUND)
            return

    # Landing / leaving the ground.
    if on_floor and state in [State.AIR, State.WALL_SLIDE]:
        _land(wish)
    elif not on_floor and state in [State.GROUND, State.SKID, State.CROUCH, State.SLIDE]:
        _set_state(State.AIR)
        jump_kind = Jump.FALL
        _set_crouched(false)

    if on_floor:
        _step_ground(wish, crouch_held, jump_wanted, delta)
    else:
        if crouch_pressed and state != State.WALL_SLIDE:
            _start_pound()
            return
        _step_air(wish, jump_wanted, delta)


# --- Ground -----------------------------------------------------------------------------------

func _step_ground(wish: Vector2, crouch_held: bool, jump_wanted: bool, delta: float) -> void:
    var planar: Vector2 = Vector2(player.velocity.x, player.velocity.z)
    var speed: float = planar.length()
    # Crouch / slide.
    if crouch_held and state in [State.GROUND, State.SKID]:
        _set_state(State.SLIDE if speed >= SLIDE_MIN_SPEED else State.CROUCH)
        _set_crouched(true)
    elif not crouch_held and state in [State.CROUCH, State.SLIDE] and _can_stand():
        _set_state(State.GROUND)
        _set_crouched(false)

    if jump_wanted and float(player._coyote_left) > 0.0:
        _ground_jump(wish, speed)
        return

    match state:
        State.SKID:
            speed = move_toward(speed, 0.0, (RUN_SPEED / SKID_TIME) * delta)
            planar = planar.normalized() * speed if speed > 0.01 else Vector2.ZERO
            if state_time >= SKID_TIME:
                planar = _skid_dir * SKID_EXIT_SPEED
                _face(_skid_dir)
                _set_state(State.GROUND)
        State.SLIDE:
            speed = move_toward(speed, 0.0, SLIDE_FRICTION * delta)
            var dir: Vector2 = planar.normalized() if speed > 0.01 else Vector2.ZERO
            if wish.length() > 0.2 and dir != Vector2.ZERO:
                dir = dir.rotated(clampf(dir.angle_to(wish.normalized()), -1.5 * delta, 1.5 * delta))
            planar = dir * speed
            if speed < 2.5 or state_time > SLIDE_MAX_TIME:
                _set_state(State.CROUCH)
        State.CROUCH:
            planar = planar.move_toward(wish.limit_length(1.0) * CROUCH_SPEED, 30.0 * delta)
        _:
            planar = _run(wish, planar, speed, delta)
    player.velocity.x = planar.x
    player.velocity.z = planar.y
    if player.velocity.y < 0.0:
        player.velocity.y = 0.0


## Momentum run: today's instant, vector-steered run, plus a top speed that builds while you run
## straight and a skid when you reverse at speed.
func _run(wish: Vector2, planar: Vector2, speed: float, delta: float) -> Vector2:
    if wish.length() < 0.05:
        run_time = 0.0
        speed = move_toward(speed, 0.0, float(player.decel3d) * delta)
        return planar.normalized() * speed if speed > 0.0 else Vector2.ZERO
    var want_dir: Vector2 = wish.normalized()
    var dir: Vector2 = planar / speed if speed > 0.3 else want_dir
    var angle: float = absf(dir.angle_to(want_dir))
    if angle > deg_to_rad(150.0) and speed >= SKID_MIN_SPEED:
        _skid_dir = want_dir
        run_time = 0.0
        _set_state(State.SKID)
        player.emit_signal(&"move_event", &"skid")
        return planar
    if wish.length() > 0.9 and angle < deg_to_rad(25.0) and speed >= RUN_SPEED * 0.9:
        run_time += delta
    else:
        run_time = maxf(0.0, run_time - 3.0 * delta)
    var boost: float = clampf((run_time - BOOST_DELAY) / BOOST_RAMP, 0.0, 1.0)
    var top: float = lerpf(RUN_SPEED, BOOST_SPEED, boost) * (float(player._haste_mult) if float(player._haste_left) > 0.0 else 1.0)
    var want_speed: float = top * wish.length()
    if angle > deg_to_rad(150.0) and speed > 2.0:
        speed = move_toward(speed, 0.0, float(player.brake3d) * delta)  # slow reversal: brake, pivot
        if speed <= 2.0:
            dir = want_dir
    else:
        var turn: float = float(player.turn_rate3d) * delta
        dir = dir.rotated(clampf(dir.angle_to(want_dir), -turn, turn))
        if speed < float(player.start_speed3d):
            speed = minf(float(player.start_speed3d), want_speed)
        speed = move_toward(speed, want_speed, float(player.accel3d) * delta)
    return dir * speed


func _ground_jump(wish: Vector2, speed: float) -> void:
    var kind: Jump = Jump.SINGLE
    var planar: Vector2 = Vector2(player.velocity.x, player.velocity.z)
    var facing: Vector3 = player.get_facing_vector()
    var face2: Vector2 = Vector2(facing.x, facing.z)
    var gravity_scale: float = 1.0
    match state:
        State.SKID:
            kind = Jump.SIDE_FLIP
            planar = _skid_dir * SIDE_FLIP_SPEED
            _face(_skid_dir)
        State.SLIDE:
            kind = Jump.LONG
            gravity_scale = LONG_GRAVITY_SCALE
            var dir: Vector2 = planar.normalized() if speed > 0.1 else face2
            planar = dir * clampf(speed + 3.0, LONG_MIN_SPEED, LONG_MAX_SPEED)
            _face(dir)
        State.CROUCH:
            if speed >= CHAIN_MIN_SPEED:
                kind = Jump.LONG
                gravity_scale = LONG_GRAVITY_SCALE
                var dir2: Vector2 = planar.normalized()
                planar = dir2 * clampf(speed + 3.0, LONG_MIN_SPEED, LONG_MAX_SPEED)
                _face(dir2)
            else:
                kind = Jump.BACKFLIP
                planar = -face2 * BACKFLIP_BACK_SPEED
        _:
            if _chain_left > 0.0 and speed >= CHAIN_MIN_SPEED and chain in [1, 2]:
                kind = Jump.DOUBLE if chain == 1 else Jump.TRIPLE
    _set_crouched(false)
    chain = 1 if kind == Jump.SINGLE else (2 if kind == Jump.DOUBLE else (3 if kind == Jump.TRIPLE else 0))
    _launch(kind, planar, gravity_scale)


func _launch(kind: Jump, planar: Vector2, gravity_scale: float = 1.0) -> void:
    jump_kind = kind
    player.velocity = Vector3(planar.x, launch_speed(float(HEIGHT[kind]), gravity_scale), planar.y)
    player._buffer_left = 0.0
    player._coyote_left = 0.0
    player._jump_rising = kind in [Jump.SINGLE, Jump.DOUBLE]  # only these cut short on release
    _set_state(State.AIR)
    player.emit_signal(&"jumped")
    player.emit_signal(&"move_event", StringName("jump_%s" % Jump.keys()[kind].to_lower()))


func _land(wish: Vector2) -> void:
    if jump_kind in [Jump.SINGLE, Jump.DOUBLE] and Vector2(player.velocity.x, player.velocity.z).length() >= CHAIN_MIN_SPEED - 1.0:
        _chain_left = CHAIN_WINDOW
    else:
        chain = 0
    if jump_kind == Jump.LONG:
        # Keep a little of the long jump's speed: land running, not stopped dead.
        var planar: Vector2 = Vector2(player.velocity.x, player.velocity.z).limit_length(BOOST_SPEED)
        player.velocity.x = planar.x
        player.velocity.z = planar.y
    jump_kind = Jump.NONE
    _set_state(State.GROUND)


# --- Air --------------------------------------------------------------------------------------

func _step_air(wish: Vector2, jump_wanted: bool, delta: float) -> void:
    # Ledge grab first (it can catch you out of a wall slide too).
    if _regrab_left <= 0.0 and player.velocity.y <= 0.5 and _try_ledge_grab():
        return
    if state == State.WALL_SLIDE:
        _step_wall_slide(wish, jump_wanted, delta)
        return
    if player.velocity.y < 1.0 and jump_kind != Jump.LONG and _touching_wall_into(wish):
        _set_state(State.WALL_SLIDE)
        player.emit_signal(&"move_event", &"wall_slide")
        _step_wall_slide(wish, jump_wanted, delta)
        return
    # Air control: reduced for the committed jumps.
    var planar: Vector2 = Vector2(player.velocity.x, player.velocity.z)
    if _control_lock <= 0.0:
        var committed: bool = jump_kind in [Jump.LONG, Jump.BACKFLIP, Jump.WALL_KICK]
        var accel: float = 10.0 if committed else float(player.air_accel3d)
        var turn_rate: float = 2.0 if committed else float(player.air_turn_rate3d)
        var speed: float = planar.length()
        if wish.length() > 0.05:
            var want: Vector2 = wish.normalized()
            var dir: Vector2 = planar / speed if speed > 0.3 else want
            dir = dir.rotated(clampf(dir.angle_to(want), -turn_rate * delta, turn_rate * delta))
            var cap: float = maxf(speed, RUN_SPEED * wish.length())  # never slows a fast jump
            speed = move_toward(speed, cap, accel * delta)
            planar = dir * speed
        else:
            planar = planar.move_toward(Vector2.ZERO, (2.0 if committed else float(player.air_accel3d) * 0.3) * delta)
        player.velocity.x = planar.x
        player.velocity.z = planar.y
    # Variable height: releasing early cuts the single and double jumps.
    if player._jump_rising and player.velocity.y > 0.0 and not Input.is_action_pressed(player.act(&"jump")):
        player.velocity.y *= float(player.jump_cut_factor)
        player._jump_rising = false
    _gravity(delta)


func _gravity(delta: float) -> void:
    if player.velocity.y <= 0.0:
        player._jump_rising = false
    var g: float = rise_gravity() if player.velocity.y > 0.0 else fall_gravity()
    if jump_kind == Jump.LONG:
        g *= LONG_GRAVITY_SCALE
    elif jump_kind in [Jump.SINGLE, Jump.DOUBLE, Jump.TRIPLE] and absf(player.velocity.y) < float(player.apex_hang_speed3d) \
            and Input.is_action_pressed(player.act(&"jump")):
        g *= 0.5  # apex hang
    player.velocity.y = maxf(player.velocity.y - g * delta, -float(player.max_fall_speed) * 1.5)


# --- Walls ------------------------------------------------------------------------------------

## In the air, pressing into a tall static wall.
func _touching_wall_into(wish: Vector2) -> bool:
    if not player.is_on_wall() or _near_floor(WALL_MIN_HEIGHT):
        return false
    var n: Vector3 = player.get_wall_normal()
    if absf(n.y) > 0.3:
        return false
    n.y = 0.0
    n = n.normalized()
    var into: float = wish.dot(Vector2(-n.x, -n.z))
    if into < 0.3:
        return false
    wall_normal = n
    return true


func _step_wall_slide(wish: Vector2, jump_wanted: bool, delta: float) -> void:
    _face(Vector2(-wall_normal.x, -wall_normal.z))
    if jump_wanted:
        _control_lock = WALL_KICK_LOCK
        _face(Vector2(wall_normal.x, wall_normal.z))
        chain = 0
        _launch(Jump.WALL_KICK, Vector2(wall_normal.x, wall_normal.z) * WALL_KICK_SPEED)
        return
    var away: float = wish.dot(Vector2(wall_normal.x, wall_normal.z))
    var still_on_wall: bool = player.test_move(player.global_transform, -wall_normal * 0.12)
    if away > 0.3 or not still_on_wall or _near_floor(0.3):
        _set_state(State.AIR)
        return
    player.velocity.x = -wall_normal.x * 0.5  # stay pressed to the wall
    player.velocity.z = -wall_normal.z * 0.5
    _gravity(delta)
    player.velocity.y = maxf(player.velocity.y, -WALL_SLIDE_SPEED)


func _near_floor(distance: float) -> bool:
    var from: Vector3 = player.global_position + Vector3(0.0, -STAND_HEIGHT * 0.5 + 0.05, 0.0)
    return _ray(from, from + Vector3.DOWN * distance).size() > 0


# --- Ledges -----------------------------------------------------------------------------------

## Falling past the top edge of a static wall you face: catch it.
func _try_ledge_grab() -> bool:
    var facing: Vector3 = player.get_facing_vector()
    if state == State.WALL_SLIDE:
        facing = -wall_normal
    facing.y = 0.0
    if facing.length_squared() < 0.01:
        return false
    facing = facing.normalized()
    var pos: Vector3 = player.global_position
    var chest: Vector3 = pos + Vector3(0.0, 0.3, 0.0)
    var wall_hit: Dictionary = _ray(chest, chest + facing * 0.75)
    if wall_hit.is_empty():
        return false
    var n: Vector3 = wall_hit["normal"]
    if absf(n.y) > 0.3:
        return false
    n.y = 0.0
    n = n.normalized()
    var top: Dictionary = _ledge_top_at(wall_hit["position"], n)
    if top.is_empty():
        return false
    var top_y: float = (top["position"] as Vector3).y
    if top_y < pos.y + 0.7 or top_y > pos.y + 1.4:
        return false  # hands reach the edge: the snap into the hang stays small
    ledge_normal = n
    ledge_top = top_y
    var at: Vector3 = Vector3(wall_hit["position"].x, top_y - HANG_DROP, wall_hit["position"].z) + n * 0.38
    player.global_position = at
    player.velocity = Vector3.ZERO
    _face(Vector2(-n.x, -n.z))
    jump_kind = Jump.NONE
    chain = 0
    _hang_let_go = false
    _set_state(State.HANG)
    player.emit_signal(&"move_event", &"ledge_grab")
    return true


## The walkable top just behind a wall hit at `point` (normal `n`), or {}.
func _ledge_top_at(point: Vector3, n: Vector3) -> Dictionary:
    var probe: Vector3 = point - n * 0.25
    var hit: Dictionary = _ray(Vector3(probe.x, player.global_position.y + 1.6, probe.z), Vector3(probe.x, player.global_position.y - 0.2, probe.z))
    if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
        return {}
    var above: Dictionary = _ray(Vector3(probe.x, (hit["position"] as Vector3).y + 0.05, probe.z), Vector3(probe.x, (hit["position"] as Vector3).y + 1.6, probe.z))
    return {} if not above.is_empty() else hit  # a ceiling right above: not a ledge you can climb onto


func _step_hang(wish: Vector2, jump_wanted: bool, crouch_pressed: bool, delta: float) -> void:
    player.velocity = Vector3.ZERO
    var n2: Vector2 = Vector2(ledge_normal.x, ledge_normal.z)
    var into: float = wish.dot(-n2)
    if crouch_pressed or wish.dot(n2) > 0.6:
        _drop_from_ledge()
        return
    if into < 0.3:
        _hang_let_go = true
    if (jump_wanted or (into > 0.6 and _hang_let_go)) and state_time > 0.12:
        if _start_pull_up():
            return
    var tangent: Vector3 = ledge_normal.cross(Vector3.UP).normalized()
    var along: float = wish.dot(Vector2(tangent.x, tangent.z))
    if absf(along) > 0.2:
        var step_dir: Vector3 = tangent * signf(along)
        var next: Vector3 = player.global_position + step_dir * SHIMMY_SPEED * absf(along) * delta
        var chest: Vector3 = next + Vector3(0.0, 0.3, 0.0)
        var wall_hit: Dictionary = _ray(chest, chest - ledge_normal * 0.75)
        if not wall_hit.is_empty() and not player.test_move(player.global_transform, step_dir * 0.1):
            var top: Dictionary = _ledge_top_at(wall_hit["position"], ledge_normal)
            if not top.is_empty() and absf((top["position"] as Vector3).y - ledge_top) < 0.3:
                player.global_position = next
    player._buffer_left = 0.0


func _start_pull_up() -> bool:
    var target: Vector3 = player.global_position - ledge_normal * 0.75
    target.y = ledge_top + STAND_HEIGHT * 0.5 + 0.02
    var standing: Transform3D = Transform3D(player.global_transform.basis, target)
    if player.test_move(standing, Vector3.UP * 0.05):
        return false  # no room to stand up there
    _pull_from = player.global_position
    _pull_to = target
    player._buffer_left = 0.0
    if _collision != null:
        _collision.disabled = true  # the climb passes the ledge's corner; collision resumes on top
    _set_state(State.PULL_UP)
    player.emit_signal(&"move_event", &"pull_up")
    return true


func _step_pull_up() -> void:
    player.velocity = Vector3.ZERO
    var t: float = clampf(state_time / PULL_UP_TIME, 0.0, 1.0)
    # Up first, then in over the edge.
    var up: float = smoothstep(0.0, 0.7, t)
    var over: float = smoothstep(0.45, 1.0, t)
    var p: Vector3 = _pull_from
    p.y = lerpf(_pull_from.y, _pull_to.y, up)
    p.x = lerpf(_pull_from.x, _pull_to.x, over)
    p.z = lerpf(_pull_from.z, _pull_to.z, over)
    player.global_position = p
    if t >= 1.0:
        if _collision != null:
            _collision.disabled = false
        _set_state(State.GROUND)


func _drop_from_ledge() -> void:
    _regrab_left = REGRAB_COOLDOWN
    player.global_position += ledge_normal * 0.15
    player.velocity = Vector3.ZERO
    jump_kind = Jump.FALL
    _set_state(State.AIR)


# --- Ground pound -----------------------------------------------------------------------------

func _start_pound() -> void:
    jump_kind = Jump.NONE
    chain = 0
    player._jump_rising = false
    _set_state(State.POUND_SPIN)
    player.emit_signal(&"move_event", &"pound_start")


func _pound_impact() -> void:
    _set_state(State.POUND_LAND)
    var feet: Vector3 = player.global_position + Vector3(0.0, -STAND_HEIGHT * 0.5, 0.0)
    var zone: StrikeZone = StrikeZone.create(feet, POUND_RADIUS, 0.8, 0.0, POUND_DAMAGE, &"ground_pound", &"burst")
    zone.hitbox.team = &"player"
    zone.hitbox.category = &"heavy"
    zone.hitbox.knockback = 6.0
    zone.hitbox.poise_damage = 3
    player.get_parent().add_child(zone)
    # A pound smashes a cracked floor outright (secret cellars), whatever its hit points.
    for node: Node in player.get_tree().get_nodes_in_group(&"breakable"):
        var slab: Node3D = node as Node3D
        var to: Vector3 = slab.global_position - feet
        if Vector2(to.x, to.z).length() < POUND_RADIUS + 1.0 and to.y < 0.2 and to.y > -1.6:
            var slab_health: Health = slab.get("health") as Health
            if slab_health != null and not slab_health.is_dead():
                slab_health.apply_damage(slab_health.current)
    player.get_tree().call_group(&"camera_shaker", &"add_trauma", 0.35)
    player.emit_signal(&"move_event", &"pound_land")


# --- Helpers ----------------------------------------------------------------------------------

func _set_state(next: State) -> void:
    if next != state:
        state = next
        state_time = 0.0


func _face(dir: Vector2) -> void:
    if dir.length_squared() < 0.0001:
        return
    var d: Vector3 = Vector3(dir.x, 0.0, dir.y).normalized()
    player._facing_3d = d
    if absf(d.x) > 0.01:
        player.facing_direction = signf(d.x)


func _set_crouched(on: bool) -> void:
    if on == crouched or _shape == null:
        return
    crouched = on
    _shape.height = CROUCH_HEIGHT if on else STAND_HEIGHT
    _collision.position.y = -(STAND_HEIGHT - CROUCH_HEIGHT) * 0.5 if on else 0.0


## Room to stand up from a crouch (a slide under a low ceiling stays crouched).
func _can_stand() -> bool:
    if not crouched:
        return true
    var head: Vector3 = player.global_position + Vector3(0.0, -STAND_HEIGHT * 0.5 + CROUCH_HEIGHT, 0.0)
    for offset: Vector3 in [Vector3.ZERO, Vector3(0.3, 0.0, 0.0), Vector3(-0.3, 0.0, 0.0), Vector3(0.0, 0.0, 0.3), Vector3(0.0, 0.0, -0.3)]:
        if not _ray(head + offset, head + offset + Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT + 0.05)).is_empty():
            return false
    return true


## Ray against the static world (walls, floors, moving platforms) — never enemies or players.
func _ray(from: Vector3, to: Vector3) -> Dictionary:
    var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [player.get_rid()]
    query.collide_with_areas = false
    for attempt in 4:
        var hit: Dictionary = space.intersect_ray(query)
        if hit.is_empty():
            return hit
        var collider: Object = hit["collider"]
        if collider is StaticBody3D or collider is AnimatableBody3D:
            return hit
        var excluded: Array[RID] = query.exclude
        excluded.append(hit["rid"])
        query.exclude = excluded
    return {}

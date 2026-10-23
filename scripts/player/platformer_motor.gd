class_name PlatformerMotor
extends RefCounted
## The full-3D platformer moveset (design: docs/superpowers/specs/2026-10-22-3d-platformer-design.md;
## feel: docs/superpowers/specs/2026-10-22-movement-reference-spec.md, DEC-051).
## Owned by the player and stepped instead of the plain 3D run/jump whenever a third-person camera
## drives the player. Every move is an explicit state with entry rules, so animation and tests
## read the state instead of guessing from velocity.
##
## The contract (DEC-051): the hero is always in exactly ONE state, and nothing moves the body
## without the motor being in a state that represents it. Hits are KNOCKBACK, the dash is DASH,
## swings are ATTACK (the player drives the velocity of those two and ticks them with
## hold_external). anim_state() names the one pose the animator plays.
##
## Ground motion is facing-led (Super Mario 64 style): a scalar forward speed along a facing that
## the motor turns toward the stick at a fixed rate, so the hero always faces the way it moves.
## The stick magnitude is squared; speed follows a drag-limited curve; letting go brakes (fast)
## or decelerates (slow); every landing is a short LAND state; jumps keep their facing in the air
## (limited forward/back control plus a small sideways drift) and bonk off walls hit head-on.
## Floors are classed by angle and surface tag: too steep a floor, or a face that is no floor at
## all, is a SLOPE_SLIDE (never the fall pose stuck on a slope).
##
## Moves: run, skid turn (+ side flip), brake, decelerate, land, variable jump, triple jump chain,
## crouch / crouch-walk / slide, long jump, backflip, wall slide + wall kick, bonk, ledge grab
## (hang, shimmy, pull up, drop), ground pound, slope slide, and climbing on marked walls (group
## "climbable", see ClimbWall). The dash stays the player's (DASH while it lasts).
##
## Our own code and numbers, written from the prose spec only (clean room, DEC-044).

enum State {
    GROUND, AIR, SKID, CROUCH, SLIDE, WALL_SLIDE, HANG, PULL_UP, POUND_SPIN, POUND_FALL, POUND_LAND, CLIMB, CLIMB_LEAP,
    DECEL, BRAKE, LAND, KNOCKBACK, BONK, SLOPE_SLIDE, DASH, ATTACK,
}
enum Jump { NONE, SINGLE, DOUBLE, TRIPLE, LONG, BACKFLIP, SIDE_FLIP, WALL_KICK, FALL }

# --- Tuning (a regular platformer pace for a 1.8 m hero, DEC-060; was SM64 x1.125, DEC-051) ---
# Ground run.
const RUN_SPEED: float = 6.0  # full-tilt run
const SPRINT_SPEED: float = 7.25  # after running straight at full tilt for SPRINT_DELAY
const SPRINT_DELAY: float = 0.8
const SPRINT_ACCEL: float = 1.5  # m/s² from the run up to the sprint (about 0.8 s)
const SPRINT_TURN: float = 1.5  # rad/s: turning harder than this resets the sprint build-up
const GROUND_CAP: float = 10.0  # absolute ground speed cap
const START_SPEED: float = 2.5  # instant first step
const ACCEL_BASE: float = 12.0  # drag-limited accel = ACCEL_BASE - ACCEL_DRAG * speed (m/s²)
const ACCEL_DRAG: float = 0.8  # -> 2.5 to 6.0 m/s in ~0.4 s
const ACCEL_MIN: float = 2.0  # floor for the curve (haste pushes the target past its zero)
const STICK_POWER: float = 1.5  # target = RUN_SPEED × tilt^1.5: half tilt walks at ~2.1 m/s
const OVER_SPEED_DECEL: float = 8.0  # above the stick's target speed
const TURN_RATE: float = 6.0  # rad/s (~344°/s): the facing turns toward the stick at this rate
const PIVOT_SPEED: float = 1.0  # slower than this, the facing snaps to the stick (a standing start)
const STICK_DEADZONE: float = 0.05
const DECEL_RATE: float = 8.0  # stick released below BRAKE_MIN_SPEED: glide to a stop
const BRAKE_RATE: float = 30.0  # stick released at a run: skid to a stop
const BRAKE_MIN_SPEED: float = 4.0
const SKID_ANGLE_DEG: float = 100.0  # stick this far from the facing at speed: turnaround skid
const SKID_MIN_SPEED: float = 4.0
const SKID_RATE: float = 30.0
const SKID_EXIT_SPEED: float = 2.0  # walks off the new way at this speed
const PUSH_SPEED: float = 2.0  # walking head-on into a wall clamps the speed (and plays "push")
const PUSH_HEAD_ON_DOT: float = 0.5  # facing within 60° of the wall's inward normal
const BLOCKED_RATIO: float = 0.25  # really moving less than this share of the run: blocked (push)
const STRAFE_ACCEL: float = 45.0  # locked on: vector steering (snappy, for combat)
const STRAFE_DECEL: float = 60.0
const CROUCH_SPEED: float = 2.0
const CROUCH_ACCEL: float = 20.0
const SLIDE_MIN_SPEED: float = 3.0  # crouching faster than this slides
const SLIDE_FRICTION: float = 6.0
const SLIDE_END_SPEED: float = 1.8
const SLIDE_MAX_TIME: float = 0.9
const SLIDE_TURN: float = 1.5  # rad/s the stick steers a crouch slide
# Landing and jumps.
const LAND_TIME: float = 0.13
const LAND_LONG_TIME: float = 0.2
const LAND_BONK_TIME: float = 0.3
const LAND_KEEP: float = 0.98  # speed kept per 1/30 s while landing with the stick held
const LAND_MIN_AIR: float = 0.1  # shorter airtime (a step down) lands straight into GROUND
const CHAIN_WINDOW: float = 0.25  # jump this soon after touchdown to chain the next jump
const TRIPLE_MIN_SPEED: float = 4.5  # the triple needs this forward speed at the chained jump
const JUMP_CARRY: float = 0.8  # single/double/triple keep this much forward speed
const LONG_ENTRY_SPEED: float = 3.0  # crouch + jump faster than this is a long jump
const HEIGHT: Dictionary = {
    Jump.SINGLE: 2.3, Jump.DOUBLE: 2.9, Jump.TRIPLE: 3.8, Jump.LONG: 1.0,
    Jump.BACKFLIP: 3.6, Jump.SIDE_FLIP: 3.2, Jump.WALL_KICK: 2.6,
}
const LONG_GRAVITY_SCALE: float = 0.32  # the same 1 m height, floatier: ~0.74 s of flight
const LONG_BOOST: float = 2.5  # the long jump launches this much faster than the run
const LONG_MIN_SPEED: float = 8.0
const LONG_MAX_SPEED: float = 9.0
const LONG_LAND_SPEED: float = 6.0  # a long jump lands running at most this fast
const BACKFLIP_BACK_SPEED: float = 2.0
const SIDE_FLIP_SPEED: float = 3.0
# Air steering: the facing is fixed; the stick changes forward speed and adds a drift.
const AIR_DRAG: float = 2.0
const AIR_ACCEL: float = 9.0  # × tilt × cos(stick vs facing)
const AIR_DRIFT: float = 2.4  # sideways m/s × tilt × sin(stick vs facing), never builds up
const AIR_BACK_LIMIT: float = -3.0  # pulling back can drift you backwards this fast at most
const AIR_CAP: float = 7.25  # the stick can build air speed up to the sprint
const LONG_AIR_CAP: float = 9.0
const AIR_OVER_DRAG: float = 8.0  # extra drag above the cap
const COMMITTED_AIR_SCALE: float = 0.5  # backflip / wall kick steer at half strength
const AIR_POSE_GRACE: float = 0.08  # stepping off a lip shows the fall pose only after this
# Walls.
const BONK_MIN_SPEED: float = 4.5
const BONK_HEAD_ON_DOT: float = 0.707  # facing within 45° of the wall's inward normal
const BONK_BACK_SPEED: float = 2.0
const BONK_HARD_SPEED: float = 8.5
const BONK_HARD_BACK: float = 3.5
const WALL_KICK_WINDOW: float = 0.17  # jump this soon after a bonk to kick off the wall
const WALL_SLIDE_SPEED: float = 3.5
const WALL_KICK_SPEED: float = 6.0
const WALL_KICK_LOCK: float = 0.22
const WALL_MIN_HEIGHT: float = 1.0  # no wall slide this close above the floor
# Ledges.
const HANG_DROP: float = 1.25  # body centre below the ledge top while hanging
const SHIMMY_SPEED: float = 2.2
const PULL_UP_TIME: float = 0.3  # jump: a fast climb
const PULL_UP_SLOW_TIME: float = 0.8  # stick toward the wall: a slow climb
const HANG_JUMP_GUARD: float = 0.12
const HANG_STICK_GUARD: float = 0.33  # the stick can't climb you up until this long after the grab
const REGRAB_COOLDOWN: float = 0.35
# Ground pound.
const POUND_SPIN_TIME: float = 0.28
const POUND_FALL_SPEED: float = 26.0
const POUND_LAND_TIME: float = 0.25
const POUND_RADIUS: float = 2.0
const POUND_DAMAGE: int = 2
# Climbing.
const CLIMB_UP_SPEED: float = 2.6  # climbing up is quicker than crawling across
const CLIMB_SIDE_SPEED: float = 2.0
const CLIMB_DOWN_SPEED: float = 3.0
const CLIMB_LEAP_SPEED: float = 7.5
const CLIMB_LEAP_TIME: float = 0.3  # about 2.2 m along the wall
const CLIMB_RUN_UP_SPEED: float = 6.5  # "parkour up": jumping into a climb wall keeps rising
const CLIMB_RUN_UP_TIME: float = 0.35
const CLIMB_GAP: float = 0.38  # body centre to wall while climbing
# Slopes. Floors carry a surface class in their collider's metadata "surface" (grip / default /
# slide / ice; untagged = default).
const STEEP_MIN_NORMAL_Y: float = 0.29  # steeper than ~73° is a wall, not a slope
const SLIDE_DEG: Dictionary = {&"grip": 999.0, &"default": 38.0, &"slide": 20.0, &"ice": 10.0}  # forces a slide
const SLOPE_DEG: Dictionary = {&"grip": 999.0, &"default": 15.0, &"slide": 10.0, &"ice": 5.0}  # walking speeds up / slows
const SURFACE_FRICTION: Dictionary = {&"grip": 0.92, &"default": 0.92, &"slide": 0.96, &"ice": 0.98}  # slide speed kept per 1/30 s
const SLOPE_WALK_ACCEL: float = 10.0  # × sin(slope) while walking on a slope
const SLOPE_SLIDE_ACCEL: float = 45.0  # × sin(slope) down a slide
const SLOPE_STEER: float = 1.5  # rad/s the stick steers a slope slide
const SLOPE_SLIDE_STOP: float = 1.2  # a slide on a walkable floor ends below this speed
const SLOPE_JUMP_DELAY: float = 0.17
const SLOPE_LOST_TIME: float = 0.1  # no surface for this long: freefall
const SLOPE_STICK: float = 0.5  # pressed into the surface so contact holds
const STEEP_JUMP_SCALE: float = 0.6  # a jump off a slide surface is weaker and goes downhill
# Hits.
const KNOCKBACK_FRICTION: float = 6.0  # while stunned
const KNOCKBACK_RECOVER_RATE: float = 40.5  # after the stun, on the ground, until nearly still
const KNOCKBACK_RECOVER_SPEED: float = 1.0
const STAND_HEIGHT: float = 1.7
const CROUCH_HEIGHT: float = 1.0

const _GROUNDED: Array[State] = [State.GROUND, State.SKID, State.CROUCH, State.SLIDE, State.DECEL, State.BRAKE, State.LAND]
const _AIRBORNE: Array[State] = [State.AIR, State.WALL_SLIDE, State.BONK]

## The player (player.gd has no class name: its tuning and timers are read dynamically).
var player
var state: State = State.GROUND
var jump_kind: Jump = Jump.NONE
## Seconds in the current state (animation reads it for flips and spins).
var state_time: float = 0.0
var chain: int = 0  # 0 none, 1/2/3 = last jump in the triple chain
## Scalar speed along the facing (negative = drifting backwards in the air or after a bonk).
var forward_speed: float = 0.0
## How fast the facing turned last step (rad/s, + = counter-clockwise from above), for the lean.
var turn_speed: float = 0.0
## Walking into a wall head-on this step (the "push" pose).
var pushing: bool = false
## Metres moved in position-driven states (shimmy, climb): the animator's progress for them.
var anim_travel: float = 0.0
## The jump that ended in the current LAND (the animator and the landing time read it).
var land_kind: Jump = Jump.NONE
## Seconds of running straight at full tilt (the sprint builds after SPRINT_DELAY, DEC-060).
var run_time: float = 0.0
var ledge_normal: Vector3 = Vector3.ZERO
var ledge_top: float = 0.0
var wall_normal: Vector3 = Vector3.ZERO
var crouched: bool = false
var _hang_let_go: bool = false
var _climb_boost: float = 0.0
var _leap_velocity: Vector3 = Vector3.ZERO

var _chain_left: float = 0.0
var _control_lock: float = 0.0
var _regrab_left: float = 0.0
var _bonk_kick_left: float = 0.0
var _air_time: float = 0.0
var _land_time: float = LAND_TIME
var _contact_lost: float = 0.0
var _slope_normal: Vector3 = Vector3.UP
var _shimmy_moved: bool = false
var _skid_dir: Vector2 = Vector2.ZERO
var _pull_from: Vector3
var _pull_to: Vector3
var _pull_time: float = PULL_UP_TIME
var _prev_pos: Vector3
## Planar speed the body really moved last step (platform motion removed) and the run speed
## the motor asked for: a run that doesn't move is blocked (DEC-060).
var _real_speed: float = 0.0
var _last_run_speed: float = 0.0
var _last_yaw: float = 0.0
var _shape: CapsuleShape3D
var _collision: CollisionShape3D


func _init(owner_body: CharacterBody3D) -> void:
    player = owner_body
    _collision = player.get_node_or_null("BodyCollision") as CollisionShape3D
    if _collision != null and _collision.shape is CapsuleShape3D:
        _shape = (_collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D  # crouching must not shrink other players
        _collision.shape = _shape
    _prev_pos = player.global_position if player.is_inside_tree() else player.position


# --- Queries ----------------------------------------------------------------------------------

func rise_gravity() -> float:
    return 2.0 * float(player.jump_height3d) / pow(float(player.jump_rise_time3d), 2.0)


func fall_gravity() -> float:
    return 2.0 * float(player.jump_height3d) / pow(float(player.jump_fall_time3d), 2.0)


## Launch speed that peaks at `height` metres under the rising gravity (scaled for the long jump).
func launch_speed(height: float, gravity_scale: float = 1.0) -> float:
    return sqrt(2.0 * rise_gravity() * gravity_scale * height)


## No sword swings while hanging, sliding on a wall or slope, pulling up, pounding or bonked.
func blocks_attacks() -> bool:
    return state in [State.HANG, State.PULL_UP, State.WALL_SLIDE, State.POUND_SPIN, State.POUND_FALL, State.POUND_LAND,
            State.CLIMB, State.CLIMB_LEAP, State.SLOPE_SLIDE, State.BONK, State.KNOCKBACK]


## No dash out of a hang, a pound, a slope slide or a bonk.
func blocks_dodge() -> bool:
    return state in [State.HANG, State.PULL_UP, State.POUND_SPIN, State.POUND_FALL, State.POUND_LAND, State.CLIMB,
            State.CLIMB_LEAP, State.SLOPE_SLIDE, State.BONK, State.KNOCKBACK]


## The motor owns the facing in these states (wall, ledge, flips, slides, hits).
func locks_facing() -> bool:
    return not allows_lock_facing()


## A lock-on target may turn the hero toward it only in plain running, landing, crouching and
## ordinary jumps (it strafes); never on a wall, a ledge, in a flip, slide or hit.
func allows_lock_facing() -> bool:
    if state in [State.GROUND, State.DECEL, State.BRAKE, State.LAND, State.CROUCH, State.DASH, State.ATTACK]:
        return true
    return state == State.AIR and jump_kind in [Jump.NONE, Jump.SINGLE, Jump.DOUBLE, Jump.FALL]


func reset() -> void:
    if _collision != null:
        _collision.disabled = false
    _set_state(State.AIR if not player.is_on_floor() else State.GROUND)
    jump_kind = Jump.NONE
    chain = 0
    run_time = 0.0
    _last_run_speed = 0.0
    forward_speed = 0.0
    pushing = false
    _control_lock = 0.0
    _bonk_kick_left = 0.0
    _air_time = 0.0
    _prev_pos = player.global_position
    _set_crouched(false)


## A hit (player._on_hit_received): leave whatever the motor was doing — a flip, a slide, a
## hang, a climb, a pull-up — and enter KNOCKBACK. The player has already set the knockback
## velocity; collision is always restored.
func knockback() -> void:
    match state:
        State.PULL_UP:
            player.global_position = _pull_to  # finish the climb instead of stopping inside the corner
        State.HANG:
            player.global_position += ledge_normal * 0.15
            _regrab_left = REGRAB_COOLDOWN
        State.CLIMB, State.CLIMB_LEAP, State.WALL_SLIDE:
            player.global_position += wall_normal * 0.15
            _regrab_left = REGRAB_COOLDOWN
    if _collision != null:
        _collision.disabled = false
    if _can_stand():
        _set_crouched(false)
    jump_kind = Jump.NONE
    chain = 0
    pushing = false
    _control_lock = 0.0
    player._jump_rising = false
    run_time = 0.0
    _last_run_speed = 0.0
    state = State.KNOCKBACK
    player.floor_stop_on_slope = true
    state_time = 0.0  # a second hit restarts the reaction
    player.emit_signal(&"move_event", &"knockback")


## The player drives the body in DASH and ATTACK (shared side-view code); the motor only names
## the state and ticks its time, so the pose never freezes. Call every frame of the dash/swing.
func hold_external(kind: State, delta: float) -> void:
    if state != kind:
        begin_external(kind)
    else:
        state_time += delta
    turn_speed = 0.0
    _prev_pos = player.global_position


func begin_external(kind: State) -> void:
    if _collision != null:
        _collision.disabled = false
    if _can_stand():
        _set_crouched(false)
    jump_kind = Jump.NONE
    chain = 0
    pushing = false
    _control_lock = 0.0
    run_time = 0.0
    _last_run_speed = 0.0
    state = kind
    player.floor_stop_on_slope = true
    state_time = 0.0


## The one animation state for the animator (DEC-051). Keys:
##   pose      StringName naming the pose/clip (every state maps to one; see ArtAnimator)
##   speed     locomotion speed for the loco poses (forward speed, or the push speed)
##   progress  0..1 through a position-driven move (pull-up, climb leap), or metres moved
##             (shimmy, climb), or seconds in the state (knockback)
##   rising    vertical speed > 0
func anim_state() -> Dictionary:
    var speed: float = absf(forward_speed)
    var pose: StringName = &"idle"
    var progress: float = state_time
    var planar: float = Vector2(player.velocity.x, player.velocity.z).length()
    match state:
        State.GROUND:
            if _strafing():
                speed = planar  # strafing round a target: the legs keep pace with the body, not the facing
            if pushing:
                pose = &"push"
                speed = PUSH_SPEED
            else:
                pose = &"walk" if speed > 0.05 else &"idle"
        State.DECEL:
            pose = &"walk"
        State.LAND:
            pose = &"land"
        State.BRAKE:
            pose = &"brake"
        State.SKID:
            pose = &"skid"
        State.CROUCH:
            pose = &"crouch"
        State.SLIDE:
            pose = &"slide"
        State.SLOPE_SLIDE:
            pose = &"slope_slide"
        State.WALL_SLIDE:
            pose = &"wall_slide"
        State.HANG:
            pose = &"shimmy" if _shimmy_moved else &"hang"
            progress = anim_travel
        State.PULL_UP:
            pose = &"pull_up"
            progress = clampf(state_time / _pull_time, 0.0, 1.0)
        State.CLIMB:
            pose = &"climb"
            progress = anim_travel
        State.CLIMB_LEAP:
            pose = &"climb_leap"
            progress = clampf(state_time / CLIMB_LEAP_TIME, 0.0, 1.0)
        State.POUND_SPIN:
            pose = &"pound_spin"
        State.POUND_FALL:
            pose = &"pound_fall"
        State.POUND_LAND:
            pose = &"pound_land"
        State.KNOCKBACK:
            pose = &"knockback"
        State.BONK:
            pose = &"bonk"
        State.DASH:
            # In the air the legs take the air pose, never the run cycle (DEC-060).
            pose = &"dash" if player.is_on_floor() else &"dash_air"
            speed = planar
        State.ATTACK:
            pose = &"attack" if player.is_on_floor() else &"attack_air"
            speed = planar
        State.AIR:
            match jump_kind:
                Jump.TRIPLE:
                    pose = &"triple"
                Jump.BACKFLIP:
                    pose = &"backflip"
                Jump.SIDE_FLIP:
                    pose = &"side_flip"
                Jump.LONG:
                    pose = &"long_jump"
                Jump.WALL_KICK:
                    pose = &"wall_kick"
                Jump.FALL, Jump.NONE:
                    # Stepping off a lip: keep the legs going for a moment (no flicker).
                    if state_time < AIR_POSE_GRACE:
                        pose = &"walk" if speed > 0.05 else &"idle"
                    else:
                        pose = &"fall"
                _:
                    pose = &"jump" if player.velocity.y > 0.0 else &"fall"
    return {"pose": pose, "speed": speed, "progress": progress, "rising": player.velocity.y > 0.0, "time": state_time}


# --- Step -------------------------------------------------------------------------------------

## One physics step. `wish` is the camera-relative stick (x, z), length 0..1.
func step(wish: Vector2, on_floor: bool, delta: float) -> void:
    state_time += delta
    wish = wish.limit_length(1.0)
    _chain_left = maxf(0.0, _chain_left - delta)
    _control_lock = maxf(0.0, _control_lock - delta)
    _regrab_left = maxf(0.0, _regrab_left - delta)
    _bonk_kick_left = maxf(0.0, _bonk_kick_left - delta)
    _track_motion(delta)
    var crouch_held: bool = Input.is_action_pressed(player.act(&"crouch"))
    var crouch_pressed: bool = Input.is_action_just_pressed(player.act(&"crouch"))
    var jump_wanted: bool = float(player._buffer_left) > 0.0
    match state:
        State.HANG:
            _step_hang(wish, jump_wanted, crouch_pressed, delta)
            return
        State.CLIMB:
            _step_climb(wish, jump_wanted, crouch_pressed, on_floor, delta)
            return
        State.CLIMB_LEAP:
            _step_climb_leap()
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
            if _steep_contact() == Vector3.ZERO:
                return
            _enter_slope_slide()  # a pound onto a face too steep to stand on: slide off it
        State.POUND_LAND:
            player.velocity = Vector3.ZERO
            if state_time >= POUND_LAND_TIME:
                forward_speed = 0.0
                _set_state(State.GROUND)
            return
        State.KNOCKBACK:
            if player.is_stunned() or (on_floor and Vector2(player.velocity.x, player.velocity.z).length() > KNOCKBACK_RECOVER_SPEED):
                _step_knockback(on_floor, delta)
                return
            _exit_to_free(on_floor)
        State.DASH, State.ATTACK:
            _exit_to_free(on_floor)

    # Landing / leaving the ground.
    if on_floor and state in _AIRBORNE:
        _land()
    elif not on_floor and state in _GROUNDED:
        if player.velocity.y <= 0.1 and _steep_contact() != Vector3.ZERO:
            _enter_slope_slide()
        else:
            _leave_ground()

    if state == State.SLOPE_SLIDE:
        _step_slope_slide(wish, jump_wanted, on_floor, delta)
        return
    if on_floor:
        if _floor_forces_slide():
            _enter_slope_slide()
            _step_slope_slide(wish, jump_wanted, on_floor, delta)
            return
        _step_ground(wish, crouch_held, jump_wanted, delta)
    else:
        if crouch_pressed and state == State.AIR:
            _start_pound()
            return
        _step_air(wish, jump_wanted, delta)


## Per-step bookkeeping for the animator: metres moved by position-driven moves, and the
## facing's turn rate (for the run lean).
func _track_motion(delta: float) -> void:
    var pos: Vector3 = player.global_position
    var moved: float = pos.distance_to(_prev_pos)
    _prev_pos = pos
    var real: Vector3 = player.get_real_velocity() - player.get_platform_velocity()
    _real_speed = Vector2(real.x, real.z).length()
    _shimmy_moved = state == State.HANG and moved > 0.0005
    if state in [State.HANG, State.CLIMB] and moved < 1.0:
        anim_travel += moved
    var f: Vector2 = _face2()
    var yaw: float = atan2(f.x, f.y)
    turn_speed = wrapf(yaw - _last_yaw, -PI, PI) / maxf(delta, 0.0001)
    _last_yaw = yaw


## Out of DASH / ATTACK / KNOCKBACK: back to free movement, keeping the speed along the facing.
func _exit_to_free(on_floor: bool) -> void:
    forward_speed = Vector2(player.velocity.x, player.velocity.z).dot(_face2())
    jump_kind = Jump.NONE
    if on_floor:
        forward_speed = maxf(0.0, forward_speed)
        _set_state(State.GROUND)
    else:
        jump_kind = Jump.FALL
        _air_time = LAND_MIN_AIR
        _set_state(State.AIR)


func _leave_ground() -> void:
    jump_kind = Jump.FALL
    _air_time = 0.0
    _set_crouched(false)
    _set_state(State.AIR)


# --- Ground -----------------------------------------------------------------------------------

func _step_ground(wish: Vector2, crouch_held: bool, jump_wanted: bool, delta: float) -> void:
    pushing = false
    # Crouch / slide.
    if crouch_held and state in [State.GROUND, State.SKID, State.DECEL, State.BRAKE, State.LAND]:
        var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
        _set_state(State.SLIDE if speed >= SLIDE_MIN_SPEED else State.CROUCH)
        forward_speed = speed if state == State.SLIDE else minf(forward_speed, CROUCH_SPEED)
        _set_crouched(true)
    elif not crouch_held and state in [State.CROUCH, State.SLIDE] and _can_stand():
        _set_state(State.GROUND)
        _set_crouched(false)

    if jump_wanted and float(player._coyote_left) > 0.0:
        _ground_jump()
        return

    if _strafing() and state in [State.GROUND, State.DECEL, State.BRAKE, State.LAND]:
        _strafe_ground(wish, delta)
    else:
        match state:
            State.SKID:
                _step_skid(delta)
            State.SLIDE:
                _step_slide(wish, delta)
            State.CROUCH:
                _step_crouch(wish, delta)
            State.LAND:
                _step_land(wish, delta)
            State.DECEL, State.BRAKE:
                _step_stopping(wish, delta)
            _:
                _step_run(wish, delta)
    if player.velocity.y < 0.0:
        player.velocity.y = 0.0


## GROUND: facing-led run. The facing turns toward the stick at TURN_RATE; the forward speed
## follows the drag-limited curve toward the squared stick's target; velocity = facing × speed.
func _step_run(wish: Vector2, delta: float) -> void:
    forward_speed = maxf(forward_speed, 0.0)
    var mag: float = wish.length()
    if mag < STICK_DEADZONE:
        run_time = 0.0
        if forward_speed >= BRAKE_MIN_SPEED:
            _set_state(State.BRAKE)
            player.emit_signal(&"move_event", &"brake")
            _step_stopping(wish, delta)
        elif forward_speed > 0.05:
            _set_state(State.DECEL)
            _step_stopping(wish, delta)
        else:
            forward_speed = 0.0
            _set_planar(Vector2.ZERO)
        return
    var want: Vector2 = wish / mag
    var f: Vector2 = _face2()
    var turn_step: float = absf(f.angle_to(want))
    if forward_speed < PIVOT_SPEED:
        f = want  # a standing start faces the stick at once
        _face(f)
    elif absf(f.angle_to(want)) > deg_to_rad(SKID_ANGLE_DEG) and forward_speed >= SKID_MIN_SPEED:
        _skid_dir = want
        run_time = 0.0
        _set_state(State.SKID)
        player.emit_signal(&"move_event", &"skid")
        _step_skid(delta)
        return
    else:
        f = _turn_facing(want, TURN_RATE * delta)
    var target: float = _target_speed(mag)
    # Sprint: running straight at full tilt for SPRINT_DELAY lets the speed build past the run.
    var full_tilt: bool = mag > 0.95 and absf(turn_step) < SPRINT_TURN * delta and forward_speed >= target - 0.05
    run_time = run_time + delta if full_tilt or (run_time > 0.0 and mag > 0.95 and absf(turn_step) < SPRINT_TURN * delta) else 0.0
    var sprint: bool = run_time > SPRINT_DELAY and mag > 0.95
    if forward_speed < START_SPEED and target > forward_speed:
        forward_speed = minf(START_SPEED, target)  # the instant first step
    if forward_speed < target:
        var accel: float = maxf(ACCEL_MIN, ACCEL_BASE - ACCEL_DRAG * forward_speed)
        forward_speed = minf(target, forward_speed + accel * delta)
    elif sprint and forward_speed < SPRINT_SPEED * _haste():
        forward_speed = minf(SPRINT_SPEED * _haste(), forward_speed + SPRINT_ACCEL * delta)
    elif forward_speed > target and not (sprint and forward_speed <= SPRINT_SPEED * _haste()):
        forward_speed = maxf(target, forward_speed - OVER_SPEED_DECEL * delta)
    forward_speed += _slope_gain(f) * delta
    # Walking into a wall head-on: slow to a push (glancing walls just slide you along). Anything
    # else that stops the body (a corner, a low lip, a body in the way) counts as a wall too: the
    # legs never run on the spot while the body stands still.
    var blocked: bool = _last_run_speed > 1.0 and _real_speed < _last_run_speed * BLOCKED_RATIO
    if player.is_on_wall():
        var n: Vector3 = player.get_wall_normal()
        if absf(n.y) < 0.3 and f.dot(-Vector2(n.x, n.z).normalized()) > PUSH_HEAD_ON_DOT:
            blocked = true
    if blocked:
        forward_speed = minf(forward_speed, PUSH_SPEED)
        pushing = true
        run_time = 0.0
    forward_speed = clampf(forward_speed, 0.0, GROUND_CAP)
    _last_run_speed = forward_speed
    _set_planar(f * forward_speed)


## Shaped stick: half tilt asks for about a third of the run speed (careful walking is easy).
func _target_speed(mag: float) -> float:
    return RUN_SPEED * pow(mag, STICK_POWER) * _haste()


func _haste() -> float:
    return float(player._haste_mult) if float(player._haste_left) > 0.0 else 1.0


## Walking on a slope (above its class's threshold): downhill speeds you up, uphill slows you.
func _slope_gain(f: Vector2) -> float:
    var n: Vector3 = player.get_floor_normal()
    var cls: StringName = _surface_class(_floor_collider())
    if cls == &"grip" or rad_to_deg(acos(clampf(n.y, -1.0, 1.0))) <= float(SLOPE_DEG[cls]):
        return 0.0
    return SLOPE_WALK_ACCEL * Vector2(n.x, n.z).dot(f)


## DECEL (slow, walk cycle winding down) and BRAKE (fast, skid pose). The stick resumes running
## (or skids into a turnaround when reversed at speed).
func _step_stopping(wish: Vector2, delta: float) -> void:
    if wish.length() >= STICK_DEADZONE:
        _set_state(State.GROUND)
        _step_run(wish, delta)
        return
    var rate: float = BRAKE_RATE if state == State.BRAKE else DECEL_RATE
    forward_speed = move_toward(maxf(forward_speed, 0.0), 0.0, rate * delta)
    _set_planar(_face2() * forward_speed)
    if forward_speed <= 0.0:
        _set_state(State.GROUND)


## Turnaround: brake along the old facing, then face the stick and walk off.
func _step_skid(delta: float) -> void:
    forward_speed = move_toward(forward_speed, 0.0, SKID_RATE * delta)
    _set_planar(_face2() * forward_speed)
    if forward_speed <= 0.01:
        _face(_skid_dir)
        forward_speed = SKID_EXIT_SPEED
        _set_planar(_skid_dir * forward_speed)
        _set_state(State.GROUND)


## LAND: a short landing. Stick held: keep most of the speed; released: brake.
func _step_land(wish: Vector2, delta: float) -> void:
    var mag: float = wish.length()
    var f: Vector2 = _face2()
    if mag >= STICK_DEADZONE and forward_speed >= 0.0:
        forward_speed *= pow(LAND_KEEP, delta * 30.0)
        f = _face(wish / mag) if forward_speed < PIVOT_SPEED else _turn_facing(wish / mag, TURN_RATE * delta)
    else:
        forward_speed = move_toward(forward_speed, 0.0, BRAKE_RATE * delta)
    _set_planar(f * forward_speed)
    if state_time >= _land_time:
        if mag >= STICK_DEADZONE:
            _set_state(State.GROUND)
        elif forward_speed >= BRAKE_MIN_SPEED:
            _set_state(State.BRAKE)
        elif forward_speed > 0.05:
            _set_state(State.DECEL)
        else:
            forward_speed = 0.0
            _set_state(State.GROUND)


## Crouch-walk: slow, facing-led like the run.
func _step_crouch(wish: Vector2, delta: float) -> void:
    var mag: float = wish.length()
    var f: Vector2 = _face2()
    forward_speed = maxf(forward_speed, 0.0)
    if mag >= STICK_DEADZONE:
        var want: Vector2 = wish / mag
        f = _face(want) if forward_speed < PIVOT_SPEED else _turn_facing(want, TURN_RATE * delta)
        forward_speed = move_toward(forward_speed, CROUCH_SPEED * mag * mag, CROUCH_ACCEL * delta)
    else:
        forward_speed = move_toward(forward_speed, 0.0, CROUCH_ACCEL * delta)
    _set_planar(f * forward_speed)


## Crouch slide: friction slows it, the stick steers it a little, and the hero faces the slide.
func _step_slide(wish: Vector2, delta: float) -> void:
    var planar: Vector2 = Vector2(player.velocity.x, player.velocity.z)
    var speed: float = move_toward(planar.length(), 0.0, SLIDE_FRICTION * delta)
    var dir: Vector2 = planar.normalized() if planar.length() > 0.01 else _face2()
    if wish.length() > 0.2:
        dir = dir.rotated(clampf(dir.angle_to(wish.normalized()), -SLIDE_TURN * delta, SLIDE_TURN * delta))
    _face(dir)
    forward_speed = speed
    _set_planar(dir * speed)
    if speed < SLIDE_END_SPEED or state_time > SLIDE_MAX_TIME:
        _set_state(State.CROUCH)


## Locked on: vector steering so the hero strafes around the target it keeps facing.
func _strafe_ground(wish: Vector2, delta: float) -> void:
    if state != State.GROUND:
        _set_state(State.GROUND)
    var planar: Vector2 = Vector2(player.velocity.x, player.velocity.z)
    var mag: float = wish.length()
    var target: Vector2 = (wish / mag) * _target_speed(mag) if mag >= STICK_DEADZONE else Vector2.ZERO
    planar = planar.move_toward(target, (STRAFE_ACCEL if mag >= STICK_DEADZONE else STRAFE_DECEL) * delta)
    forward_speed = maxf(0.0, planar.dot(_face2()))
    _set_planar(planar)


func _ground_jump() -> void:
    var kind: Jump = Jump.SINGLE
    var f: Vector2 = _face2()
    var planar: Vector2 = f * maxf(forward_speed, 0.0) * JUMP_CARRY
    var gravity_scale: float = 1.0
    match state:
        State.SKID:
            kind = Jump.SIDE_FLIP
            planar = _skid_dir * SIDE_FLIP_SPEED
            _face(_skid_dir)
        State.SLIDE:
            kind = Jump.LONG
            gravity_scale = LONG_GRAVITY_SCALE
            var dir: Vector2 = Vector2(player.velocity.x, player.velocity.z).normalized() if forward_speed > 0.1 else f
            planar = dir * clampf(forward_speed + LONG_BOOST, LONG_MIN_SPEED, LONG_MAX_SPEED)
            _face(dir)
        State.CROUCH:
            if forward_speed >= LONG_ENTRY_SPEED:
                kind = Jump.LONG
                gravity_scale = LONG_GRAVITY_SCALE
                planar = f * clampf(forward_speed + LONG_BOOST, LONG_MIN_SPEED, LONG_MAX_SPEED)
            else:
                kind = Jump.BACKFLIP
                planar = -f * BACKFLIP_BACK_SPEED
        _:
            if _chain_left > 0.0 and chain == 1:
                kind = Jump.DOUBLE
            elif _chain_left > 0.0 and chain == 2 and forward_speed > TRIPLE_MIN_SPEED:
                kind = Jump.TRIPLE
            if _strafing():
                planar = Vector2(player.velocity.x, player.velocity.z) * JUMP_CARRY
    _set_crouched(false)
    chain = 1 if kind == Jump.SINGLE else (2 if kind == Jump.DOUBLE else (3 if kind == Jump.TRIPLE else 0))
    _launch(kind, planar, gravity_scale)


func _launch(kind: Jump, planar: Vector2, gravity_scale: float = 1.0, height_scale: float = 1.0) -> void:
    jump_kind = kind
    player.velocity = Vector3(planar.x, launch_speed(float(HEIGHT[kind]) * height_scale, gravity_scale), planar.y)
    forward_speed = planar.dot(_face2())
    pushing = false
    _air_time = 0.0
    player._buffer_left = 0.0
    player._coyote_left = 0.0
    player._jump_rising = kind in [Jump.SINGLE, Jump.DOUBLE]  # only these cut short on release
    _set_state(State.AIR)
    player.emit_signal(&"jumped")
    player.emit_signal(&"move_event", StringName("jump_%s" % Jump.keys()[kind].to_lower()))


func _land() -> void:
    var was: Jump = jump_kind
    var bonked: bool = state == State.BONK
    if was in [Jump.SINGLE, Jump.DOUBLE] and not bonked:
        _chain_left = CHAIN_WINDOW
    else:
        chain = 0
    if _strafing():
        forward_speed = maxf(0.0, Vector2(player.velocity.x, player.velocity.z).dot(_face2()))
    if was == Jump.LONG:
        forward_speed = minf(forward_speed, LONG_LAND_SPEED)  # land running, not stopped dead
    land_kind = was
    jump_kind = Jump.NONE
    _land_time = LAND_BONK_TIME if bonked else (LAND_LONG_TIME if was == Jump.LONG else LAND_TIME)
    if bonked or was != Jump.FALL or _air_time >= LAND_MIN_AIR:
        _set_state(State.LAND)
        player.emit_signal(&"move_event", &"land")
    else:
        forward_speed = maxf(forward_speed, 0.0)
        _set_state(State.GROUND)  # a step down: no landing


# --- Air --------------------------------------------------------------------------------------

func _step_air(wish: Vector2, jump_wanted: bool, delta: float) -> void:
    _air_time += delta
    if state == State.BONK:
        _step_bonk(jump_wanted, delta)
        return
    # Ledge grab first (it can catch you out of a wall slide too); never out of a flip.
    if _regrab_left <= 0.0 and player.velocity.y <= 0.5 and jump_kind not in [Jump.TRIPLE, Jump.BACKFLIP] and _try_ledge_grab():
        return
    if _regrab_left <= 0.0 and _try_start_climb(wish):
        return
    if state == State.WALL_SLIDE:
        _step_wall_slide(wish, jump_wanted, delta)
        return
    if player.velocity.y < 1.0 and jump_kind != Jump.LONG and _touching_wall_into(wish):
        _set_state(State.WALL_SLIDE)
        player.emit_signal(&"move_event", &"wall_slide")
        _step_wall_slide(wish, jump_wanted, delta)
        return
    # Falling onto a face too steep to stand on: slide down it (never stuck in the fall pose).
    if player.velocity.y <= 0.0 and _steep_contact() != Vector3.ZERO:
        _enter_slope_slide()
        _step_slope_slide(wish, false, false, delta)
        return
    if _strafing():
        _air_strafe(wish, delta)
    else:
        if _check_bonk(wish):
            return
        _air_control(wish, delta)
    # Variable height: releasing early cuts the single and double jumps.
    if player._jump_rising and player.velocity.y > 0.0 and not Input.is_action_pressed(player.act(&"jump")):
        player.velocity.y *= float(player.jump_cut_factor)
        player._jump_rising = false
    _gravity(delta)


## Committed air control: the facing stays; the stick only trims forward speed (to a small
## backward drift at most) and adds a sideways drift that doesn't accumulate.
func _air_control(wish: Vector2, delta: float) -> void:
    var f: Vector2 = _face2()
    var side_dir: Vector2 = Vector2(-f.y, f.x)
    var mag: float = wish.length()
    var tilt: float = mag * mag
    var along: float = 0.0
    var across: float = 0.0
    if mag >= STICK_DEADZONE:
        along = (wish / mag).dot(f)
        across = (wish / mag).dot(side_dir)
    var side: float = 0.0
    if _control_lock <= 0.0:
        var committed: bool = jump_kind in [Jump.BACKFLIP, Jump.WALL_KICK]
        var cap: float = LONG_AIR_CAP if jump_kind == Jump.LONG else AIR_CAP
        forward_speed = move_toward(forward_speed, 0.0, AIR_DRAG * delta)
        if along < 0.0 or forward_speed < cap:
            forward_speed += AIR_ACCEL * tilt * along * delta * (COMMITTED_AIR_SCALE if committed else 1.0)
        if forward_speed > cap:
            forward_speed = maxf(cap, forward_speed - AIR_OVER_DRAG * delta)
        forward_speed = maxf(forward_speed, AIR_BACK_LIMIT)
        side = AIR_DRIFT * tilt * across * (COMMITTED_AIR_SCALE if committed else 1.0)
    _set_planar(f * forward_speed + side_dir * side)


## Locked on: the old vector air steering (the facing belongs to the target).
func _air_strafe(wish: Vector2, delta: float) -> void:
    var planar: Vector2 = Vector2(player.velocity.x, player.velocity.z)
    if _control_lock <= 0.0:
        var speed: float = planar.length()
        if wish.length() > STICK_DEADZONE:
            var want: Vector2 = wish.normalized()
            var dir: Vector2 = planar / speed if speed > 0.3 else want
            var rate: float = float(player.air_turn_rate3d)
            dir = dir.rotated(clampf(dir.angle_to(want), -rate * delta, rate * delta))
            speed = move_toward(speed, maxf(speed, AIR_CAP * wish.length()), float(player.air_accel3d) * delta)
            planar = dir * speed
        else:
            planar = planar.move_toward(Vector2.ZERO, AIR_DRAG * delta)
    forward_speed = planar.dot(_face2())
    _set_planar(planar)


## Head-on into a wall in the air: not pushing into it (or in a long jump) at speed, bonk back
## off it; otherwise just stop against it (a wall slide may follow).
func _check_bonk(wish: Vector2) -> bool:
    if not player.is_on_wall() or _near_floor(0.3):
        return false
    var n: Vector3 = player.get_wall_normal()
    if absf(n.y) > 0.3:
        return false
    var n2: Vector2 = Vector2(n.x, n.z).normalized()
    if _face2().dot(-n2) < BONK_HEAD_ON_DOT:
        return false  # glancing: slide along it
    var pushing_in: bool = wish.dot(-n2) > 0.3
    if forward_speed > BONK_MIN_SPEED and (jump_kind == Jump.LONG or not pushing_in):
        wall_normal = Vector3(n2.x, 0.0, n2.y)
        forward_speed = -(BONK_HARD_BACK if forward_speed > BONK_HARD_SPEED else BONK_BACK_SPEED)
        player.velocity.y = minf(player.velocity.y, 0.0)
        player._jump_rising = false
        _bonk_kick_left = WALL_KICK_WINDOW
        chain = 0
        _set_state(State.BONK)
        _set_planar(_face2() * forward_speed)
        player.emit_signal(&"move_event", &"bonk")
        return true
    forward_speed = minf(forward_speed, 0.0)
    return false


## BONK: knocked back off the wall, no control; a quick jump still kicks off it.
func _step_bonk(jump_wanted: bool, delta: float) -> void:
    if jump_wanted and _bonk_kick_left > 0.0:
        _control_lock = WALL_KICK_LOCK
        var away: Vector2 = Vector2(wall_normal.x, wall_normal.z)
        _face(away)
        chain = 0
        _launch(Jump.WALL_KICK, away * WALL_KICK_SPEED)
        return
    _set_planar(_face2() * forward_speed)
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


# --- Hits -------------------------------------------------------------------------------------

## KNOCKBACK: the hit's velocity decays (gently while stunned, then quickly to a stand).
func _step_knockback(on_floor: bool, delta: float) -> void:
    var rate: float = KNOCKBACK_FRICTION if player.is_stunned() else KNOCKBACK_RECOVER_RATE
    var planar: Vector2 = Vector2(player.velocity.x, player.velocity.z).move_toward(Vector2.ZERO, rate * delta)
    _set_planar(planar)
    if on_floor:
        if player.velocity.y < 0.0:
            player.velocity.y = 0.0
    else:
        _gravity(delta)


# --- Slopes -----------------------------------------------------------------------------------

## The normal of a face too steep to stand on that the body is touching (not a floor, not a
## sheer wall), or ZERO.
func _steep_contact() -> Vector3:
    if not player.is_on_wall() or player.is_on_floor():
        return Vector3.ZERO
    var n: Vector3 = player.get_wall_normal()
    return n if n.y > STEEP_MIN_NORMAL_Y else Vector3.ZERO


## Standing on a floor steeper than its class allows (confirmed by a ray under the body's centre,
## so a capsule rolling on a box edge is not a slope).
func _floor_forces_slide() -> bool:
    if not (state in _GROUNDED):
        return false
    var from: Vector3 = player.global_position
    var hit: Dictionary = _ray(from, from + Vector3.DOWN * (STAND_HEIGHT * 0.5 + 0.4))
    if hit.is_empty():
        return false
    var n: Vector3 = hit["normal"]
    var cls: StringName = _surface_class(hit["collider"])
    return rad_to_deg(acos(clampf(n.y, -1.0, 1.0))) > float(SLIDE_DEG[cls])


func _enter_slope_slide() -> void:
    _set_crouched(false)
    jump_kind = Jump.NONE
    chain = 0
    pushing = false
    _contact_lost = 0.0
    player._jump_rising = false
    _set_state(State.SLOPE_SLIDE)
    player.emit_signal(&"move_event", &"slope_slide")


## SLOPE_SLIDE: gravity pulls the slide down the surface; friction (by class) gives it a natural
## top speed; the stick steers it a little; it ends on a walkable floor once slow, or becomes a
## fall when the surface runs out. A jump after SLOPE_JUMP_DELAY is a weak jump downhill.
func _step_slope_slide(wish: Vector2, jump_wanted: bool, on_floor: bool, delta: float) -> void:
    var n: Vector3 = player.get_floor_normal() if on_floor else _steep_contact()
    var collider: Object = _floor_collider() if on_floor else _wall_collider()
    if n == Vector3.ZERO:
        _contact_lost += delta
        if _contact_lost > SLOPE_LOST_TIME:
            forward_speed = Vector2(player.velocity.x, player.velocity.z).dot(_face2())
            jump_kind = Jump.FALL
            _air_time = LAND_MIN_AIR
            _set_state(State.AIR)
            _gravity(delta)
            return
        n = _slope_normal
    else:
        _contact_lost = 0.0
    _slope_normal = n
    var cls: StringName = _surface_class(collider)
    var forced: bool = not on_floor or rad_to_deg(acos(clampf(n.y, -1.0, 1.0))) > float(SLIDE_DEG[cls])
    var v: Vector3 = player.velocity
    v -= n * v.dot(n)
    var down: Vector3 = Vector3.DOWN - n * Vector3.DOWN.dot(n)
    if down.length() > 0.001:
        v += down.normalized() * SLOPE_SLIDE_ACCEL * sqrt(maxf(0.0, 1.0 - n.y * n.y)) * delta
    v *= pow(float(SURFACE_FRICTION[cls]), delta * 30.0)
    var planar: Vector2 = Vector2(v.x, v.z)
    if wish.length() > 0.2 and planar.length() > 0.1:
        planar = planar.rotated(clampf(planar.angle_to(wish.normalized()), -SLOPE_STEER * delta, SLOPE_STEER * delta))
        v = Vector3(planar.x, v.y, planar.y)
        v -= n * v.dot(n)
        planar = Vector2(v.x, v.z)
    if planar.length() > 0.3:
        _turn_facing(planar.normalized(), TURN_RATE * delta)  # face the way you slide
    forward_speed = planar.length()
    if jump_wanted and state_time > SLOPE_JUMP_DELAY:
        var downhill: Vector2 = Vector2(n.x, n.z).normalized() if Vector2(n.x, n.z).length() > 0.01 else _face2()
        _face(downhill)
        chain = 0
        _launch(Jump.SINGLE, downhill * maxf(3.0, planar.length()), 1.0, STEEP_JUMP_SCALE if forced else 1.0)
        return
    if on_floor and not forced and planar.length() < SLOPE_SLIDE_STOP:
        forward_speed = 0.0
        _set_planar(Vector2.ZERO)
        _set_state(State.GROUND)
        return
    player.velocity = v - n * SLOPE_STICK


## The floor's surface class from its collider's metadata "surface" (untagged = default).
func _surface_class(collider: Object) -> StringName:
    if collider != null and collider.has_meta(&"surface"):
        var tag: StringName = StringName(str(collider.get_meta(&"surface")))
        if SLIDE_DEG.has(tag):
            return tag
    return &"default"


func _floor_collider() -> Object:
    return _collider_matching(func(n: Vector3) -> bool: return n.y >= cos(player.floor_max_angle) - 0.01)


func _wall_collider() -> Object:
    return _collider_matching(func(n: Vector3) -> bool: return n.y > STEEP_MIN_NORMAL_Y and n.y < cos(player.floor_max_angle))


func _collider_matching(test: Callable) -> Object:
    for i in player.get_slide_collision_count():
        var c: KinematicCollision3D = player.get_slide_collision(i)
        if test.call(c.get_normal()):
            return c.get_collider()
    return null


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
        if away > 0.3:
            _face(Vector2(wall_normal.x, wall_normal.z))  # push off: face away, drift from it
        forward_speed = 0.0
        jump_kind = Jump.FALL if jump_kind == Jump.NONE else jump_kind
        _set_state(State.AIR)
        return
    forward_speed = 0.5
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
    _prev_pos = at
    player.velocity = Vector3.ZERO
    forward_speed = 0.0
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
    if jump_wanted and state_time > HANG_JUMP_GUARD:
        if _start_pull_up(PULL_UP_TIME):
            return
    elif into > 0.6 and _hang_let_go and state_time > HANG_STICK_GUARD:
        if _start_pull_up(PULL_UP_SLOW_TIME):
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


func _start_pull_up(duration: float) -> bool:
    var target: Vector3 = player.global_position - ledge_normal * 0.75
    target.y = ledge_top + STAND_HEIGHT * 0.5 + 0.02
    var standing: Transform3D = Transform3D(player.global_transform.basis, target)
    if player.test_move(standing, Vector3.UP * 0.05):
        return false  # no room to stand up there
    _pull_from = player.global_position
    _pull_to = target
    _pull_time = duration
    player._buffer_left = 0.0
    if _collision != null:
        _collision.disabled = true  # the climb passes the ledge's corner; collision resumes on top (or on a hit)
    _set_state(State.PULL_UP)
    player.emit_signal(&"move_event", &"pull_up")
    return true


func _step_pull_up() -> void:
    player.velocity = Vector3.ZERO
    var t: float = clampf(state_time / _pull_time, 0.0, 1.0)
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
        forward_speed = 0.0
        _set_state(State.GROUND)


func _drop_from_ledge() -> void:
    _regrab_left = REGRAB_COOLDOWN
    player.global_position += ledge_normal * 0.15
    player.velocity = Vector3.ZERO
    forward_speed = 0.0
    jump_kind = Jump.FALL
    _air_time = LAND_MIN_AIR
    _set_state(State.AIR)


# --- Climbing ---------------------------------------------------------------------------------

## The climbable surface straight ahead of the body at `height` above its centre (toward the wall
## `into`), or {}.
func _climb_hit(at: Vector3, into: Vector3, height: float) -> Dictionary:
    var from: Vector3 = at + Vector3(0.0, height, 0.0)
    var hit: Dictionary = _ray(from, from + into * 0.9)
    if hit.is_empty() or not (hit["collider"] as Node).is_in_group(&"climbable"):
        return {}
    if absf((hit["normal"] as Vector3).y) > 0.35:
        return {}
    return hit


## In the air, pushing into (or rising against) a climbable wall: grab on.
func _try_start_climb(wish: Vector2) -> bool:
    if not player.is_on_wall():
        return false
    var n: Vector3 = player.get_wall_normal()
    n.y = 0.0
    if n.length_squared() < 0.01:
        return false
    n = n.normalized()
    var rising: bool = player.velocity.y > 0.5 and Input.is_action_pressed(player.act(&"jump"))
    if wish.dot(Vector2(-n.x, -n.z)) < 0.3 and not rising:
        return false
    var hit: Dictionary = _climb_hit(player.global_position, -n, 0.3)
    if hit.is_empty():
        return false
    _attach_climb(hit)
    # Parkour up: a jump into the wall carries on up it for a moment.
    _climb_boost = CLIMB_RUN_UP_TIME if rising else 0.0
    jump_kind = Jump.NONE
    chain = 0
    forward_speed = 0.0
    _set_state(State.CLIMB)
    player.emit_signal(&"move_event", &"climb")
    return true


func _attach_climb(hit: Dictionary) -> void:
    var n: Vector3 = hit["normal"]
    n.y = 0.0
    wall_normal = n.normalized()
    var at: Vector3 = (hit["position"] as Vector3) + wall_normal * CLIMB_GAP
    player.global_position = Vector3(at.x, player.global_position.y, at.z)
    player.velocity = Vector3.ZERO
    _face(Vector2(-wall_normal.x, -wall_normal.z))


func _step_climb(wish: Vector2, jump_wanted: bool, crouch_pressed: bool, on_floor: bool, delta: float) -> void:
    _climb_boost = maxf(0.0, _climb_boost - delta)
    # No climbable wall under the hands any more (it moved, vanished or a snap missed): let go.
    var here: Vector3 = player.global_position
    if _climb_hit(here, -wall_normal, 0.3).is_empty() and _climb_hit(here, -wall_normal, -0.3).is_empty():
        _leave_climb(Jump.FALL)
        return
    var n2: Vector2 = Vector2(wall_normal.x, wall_normal.z)
    var tangent: Vector3 = wall_normal.cross(Vector3.UP).normalized()
    var up: float = wish.dot(-n2)  # pushing toward the wall climbs up, away climbs down
    var side: float = wish.dot(Vector2(tangent.x, tangent.z))
    if crouch_pressed:
        _leave_climb(Jump.FALL)
        return
    if jump_wanted:
        player._buffer_left = 0.0
        if up < -0.5:
            # Back + jump: kick off the wall.
            _control_lock = WALL_KICK_LOCK
            _face(n2)
            _launch(Jump.WALL_KICK, n2 * WALL_KICK_SPEED)
            return
        var dir: Vector3 = Vector3.UP * (up if wish.length() > 0.2 else 1.0) + tangent * side
        if dir.length_squared() < 0.01:
            dir = Vector3.UP
        _leap_velocity = dir.normalized() * CLIMB_LEAP_SPEED
        _set_state(State.CLIMB_LEAP)
        player.emit_signal(&"move_event", &"climb_leap")
        return
    var vertical: float = up * (CLIMB_UP_SPEED if up > 0.0 else CLIMB_DOWN_SPEED)
    if _climb_boost > 0.0:
        vertical = maxf(vertical, CLIMB_RUN_UP_SPEED)
    var velocity: Vector3 = Vector3.UP * vertical + tangent * side * CLIMB_SIDE_SPEED
    var next: Vector3 = player.global_position + velocity * delta
    var hit: Dictionary = _climb_hit(next, -wall_normal, 0.3)
    if hit.is_empty():
        if velocity.y > 0.0 and _try_mantle():
            return
        # Off the edge of the climbable part: no further that way.
        var lateral_only: Vector3 = player.global_position + tangent * side * CLIMB_SIDE_SPEED * delta
        if not _climb_hit(lateral_only, -wall_normal, 0.3).is_empty():
            velocity.y = 0.0
        elif not _climb_hit(player.global_position + Vector3.UP * velocity.y * delta, -wall_normal, 0.3).is_empty():
            velocity = Vector3.UP * velocity.y
        else:
            velocity = Vector3.ZERO
    else:
        _attach_climb(hit)
    if on_floor and vertical < 0.0:
        forward_speed = 0.0
        _set_state(State.GROUND)  # climbed down to the floor
        player.velocity = Vector3.ZERO
        return
    player.velocity = velocity


func _step_climb_leap() -> void:
    player.velocity = _leap_velocity
    var next: Vector3 = player.global_position + _leap_velocity * player.get_physics_process_delta_time()
    if _climb_hit(next, -wall_normal, 0.3).is_empty() and _leap_velocity.y > 0.0 and _try_mantle():
        return
    if state_time >= CLIMB_LEAP_TIME:
        var hit: Dictionary = _climb_hit(player.global_position, -wall_normal, 0.3)
        if hit.is_empty():
            _leave_climb(Jump.FALL)
        else:
            _attach_climb(hit)
            _set_state(State.CLIMB)


## At the top of a climb wall: if there is a walkable top within reach, pull up onto it.
func _try_mantle() -> bool:
    var probe: Vector3 = player.global_position - wall_normal * (CLIMB_GAP + 0.3)
    var hit: Dictionary = _ray(Vector3(probe.x, player.global_position.y + 1.8, probe.z), Vector3(probe.x, player.global_position.y - 0.3, probe.z))
    if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
        return false
    ledge_normal = wall_normal
    ledge_top = (hit["position"] as Vector3).y
    return _start_pull_up(PULL_UP_TIME)


func _leave_climb(kind: Jump) -> void:
    _regrab_left = REGRAB_COOLDOWN
    player.global_position += wall_normal * 0.15
    player.velocity = Vector3.ZERO
    forward_speed = 0.0
    jump_kind = kind
    _air_time = LAND_MIN_AIR
    _set_state(State.AIR)


# --- Ground pound -----------------------------------------------------------------------------

func _start_pound() -> void:
    jump_kind = Jump.NONE
    chain = 0
    forward_speed = 0.0
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
        _last_run_speed = 0.0
        if next != State.GROUND:
            run_time = 0.0
    # A slope slide starts from rest: Godot's floor_stop_on_slope cancels small down-slope motion
    # of a body on a floor, so a slow start froze the slide (pose sliding, body still; DEC-060).
    player.floor_stop_on_slope = next != State.SLOPE_SLIDE


## The hero's facing on the ground plane (the motor owns it in full 3D).
func _face2() -> Vector2:
    var f: Vector3 = player._facing_3d
    var f2: Vector2 = Vector2(f.x, f.z)
    return f2.normalized() if f2.length_squared() > 0.0001 else Vector2(1.0, 0.0)


func _face(dir: Vector2) -> Vector2:
    if dir.length_squared() < 0.0001:
        return _face2()
    var d: Vector3 = Vector3(dir.x, 0.0, dir.y).normalized()
    player._facing_3d = d
    if absf(d.x) > 0.01:
        player.facing_direction = signf(d.x)
    return Vector2(d.x, d.z)


## Turns the facing toward `want` by at most `max_angle` radians; returns the new facing.
func _turn_facing(want: Vector2, max_angle: float) -> Vector2:
    var f: Vector2 = _face2()
    return _face(f.rotated(clampf(f.angle_to(want), -max_angle, max_angle)))


func _set_planar(planar: Vector2) -> void:
    player.velocity.x = planar.x
    player.velocity.z = planar.y


func _strafing() -> bool:
    var target: Variant = player.lock_target
    return target != null and is_instance_valid(target)


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

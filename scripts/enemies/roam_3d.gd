class_name Roam3D
extends RefCounted
## Full-3D enemy steering shared by every enemy type (DEC-058). Only used when an enemy is NOT
## plane-locked: the side-view game (and co-op) never creates one.
##
## Idle: the enemy roams its whole leash area: seeded random waypoints inside the leash AND on
## solid ground (a ray down at the waypoint and along the way), walked to with a limited turn
## rate, then a pause to look around. Archetype flavour via `style`:
##   PATROL  (soldiers, husks): wander, pause, look around.
##   PROWL   (hounds): quick laps round home on curved (arcing) paths, short pauses.
##   GUARD   (knights, the Gravewarden): pace a four-post guard loop, long look-arounds.
##   DRIFT   (wraiths): a figure-of-eight 3D curve round home with a height bob (no ground).
##   SKITTER (crawlers): scurries to each waypoint in short bursts, with twitchy stops.
##   KEEP    (archers): slow repositioning walks with long watchful pauses.
## Engaged: `engage_velocity` closes in (along the navigation detour when there is one), aiming
## at a slot on a ring round the target whose bearing is pushed away from other enemies (so a
## group spreads its approach angles), then holds the ring and strafes around the target.
## Ledges: `guard` stops self-driven planar motion that would carry the enemy off solid ground,
## so enemies never walk into the abyss on their own (knockback is not guarded).

enum Style { PATROL, PROWL, GUARD, DRIFT, SKITTER, KEEP }

const WALK: int = 0
const PAUSE: int = 1

var body: CharacterBody3D
var style: Style = Style.PATROL
var home: Vector3
var leash: float = 8.0
var flying: bool = false
## Current flat facing (unit); owners copy it into their own heading/facing.
var heading: Vector3 = Vector3(-1.0, 0.0, 0.0)
var turn_rate: float = 5.0
## Which way this enemy circles its target (+1/-1); flips now and then, or when blocked.
var circle_sign: float = 1.0
## Height of the ground the enemy last stood on (NAN until measured).
var floor_y: float = NAN
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _mode: int = PAUSE
var _mode_left: float = 0.4
var _pause_len: float = 0.4
var _look_from: float = 0.0
var _wp: Vector3
var _guard_index: int = 0
var _orbit: float = 0.0
var _walk_t: float = 0.0
var _clock: float = 0.0
var _floor_left: float = 0.0
var _flip_left: float = 3.0
var _last_leg: Vector3 = Vector3.ZERO


func _init(owner_body: CharacterBody3D, roam_style: Style, start_heading: Vector3) -> void:
    body = owner_body
    style = roam_style
    flying = style == Style.DRIFT
    if start_heading.length_squared() > 0.0001:
        heading = Vector3(start_heading.x, 0.0, start_heading.z).normalized()
    turn_rate = {Style.PROWL: 7.0, Style.SKITTER: 10.0, Style.GUARD: 3.5, Style.KEEP: 4.0}.get(style, 5.0)


## Seeds the roam from where the enemy stands, so a course's foes always roam the same way.
func set_home(at: Vector3, radius: float) -> void:
    home = at
    leash = maxf(0.5, radius)
    var p: Vector3i = Vector3i((at * 10.0).round())
    rng.seed = hash([p.x, p.y, p.z, int(style)])
    circle_sign = 1.0 if rng.randf() < 0.5 else -1.0
    _orbit = rng.randf() * TAU
    _guard_index = rng.randi() % 4
    _start_pause(rng.randf_range(0.2, 0.8))


# --- Ground ----------------------------------------------------------------------------------

## Re-measures the floor under the enemy a few times a second while it stands on it.
func update_floor(delta: float) -> void:
    if flying:
        return
    _floor_left -= delta
    if (_floor_left > 0.0 and not is_nan(floor_y)) or not body.is_on_floor():
        return
    _floor_left = 0.2
    var p: Vector3 = body.global_position
    var hit: Dictionary = _ray(p + Vector3(0.0, 0.2, 0.0), p + Vector3(0.0, -3.0, 0.0))
    if not hit.is_empty():
        floor_y = (hit["position"] as Vector3).y


## True if there is solid ground at `p`'s x/z, level with the floor the enemy stands on (a step
## of up to 0.7 m down or 1 m up). Unknown floor (never landed yet) counts as ground.
func ground_at(p: Vector3) -> bool:
    if flying:
        return true
    if is_nan(floor_y):
        return true
    var hit: Dictionary = _ray(Vector3(p.x, floor_y + 1.0, p.z), Vector3(p.x, floor_y - 0.7, p.z))
    return not hit.is_empty()


## True if `dist` m along flat `dir` is inside the leash and on ground (sampled twice).
func safe_step(dir: Vector3, dist: float) -> bool:
    dir.y = 0.0
    if dir.length_squared() < 0.0001:
        return true
    dir = dir.normalized()
    var p: Vector3 = body.global_position
    if not in_leash(p + dir * dist) and _flat(p + dir * dist - home).length() > _flat(p - home).length():
        return false
    return ground_at(p + dir * dist) and ground_at(p + dir * (dist * 0.5))


func in_leash(p: Vector3) -> bool:
    return _flat(p - home).length() <= leash


## Stops the planar part of a self-driven velocity that would walk the enemy off solid ground.
func guard(v: Vector3, delta: float) -> Vector3:
    if flying:
        return v
    var planar: Vector3 = Vector3(v.x, 0.0, v.z)
    var speed: float = planar.length()
    if speed < 0.05:
        return v
    var look: float = 0.45 + speed * maxf(delta, 1.0 / 60.0) * 2.0 + speed * 0.06
    if ground_at(body.global_position + planar / speed * look):
        return v
    return Vector3(0.0, v.y, 0.0)


# --- Idle roaming -----------------------------------------------------------------------------

## The planar (flying: full 3D) velocity for an idle enemy this frame; updates `heading`.
func idle_velocity(delta: float, speed: float) -> Vector3:
    _clock += delta
    update_floor(delta)
    if flying:
        return _drift(delta, speed)
    _mode_left -= delta
    if _mode == PAUSE:
        # Look around: sweep the gaze left and right of where it stopped.
        var sweep: float = sin((_pause_len - _mode_left) * (2.6 if style == Style.SKITTER else 1.6)) * (1.1 if style == Style.GUARD else 0.8)
        _turn_to(Vector3(cos(_look_from + sweep), 0.0, sin(_look_from + sweep)), delta)
        if _mode_left <= 0.0:
            if _pick_waypoint():
                _mode = WALK
                _walk_t = 0.0
                _mode_left = 8.0  # give up on a waypoint it cannot reach
            else:
                _start_pause(0.6)
        return Vector3.ZERO
    var to: Vector3 = _flat(_wp - body.global_position)
    if to.length() < 0.45 or _mode_left <= 0.0:
        _start_pause()
        return Vector3.ZERO
    var want: Vector3 = to.normalized()
    if style == Style.PROWL:
        want = want.rotated(Vector3.UP, circle_sign * clampf(to.length() * 0.15, 0.0, 0.7))  # arcs
    _turn_to(want, delta)
    _walk_t += delta
    var pace: float = speed * clampf(heading.dot(want), 0.2, 1.0)  # slows to turn, never snaps
    if style == Style.SKITTER and fmod(_walk_t, 0.75) > 0.45:
        pace *= 0.1  # bursts of scurrying
    if not safe_step(heading, 0.5 + speed * 0.15):
        _start_pause()  # an edge or the leash: stop, look, pick another way
        return Vector3.ZERO
    return heading * pace


func _drift(delta: float, speed: float) -> Vector3:
    _orbit += delta * 0.45 * circle_sign
    var r: float = clampf(leash * 0.6, 1.0, 4.0)
    var target: Vector3 = home + Vector3(cos(_orbit) * r, sin(_clock * 1.7) * 0.45, sin(_orbit * 2.0) * r * 0.6)
    var to: Vector3 = target - body.global_position
    var v: Vector3 = to.limit_length(1.0) * speed
    if Vector2(v.x, v.z).length() > 0.05:
        _turn_to(Vector3(v.x, 0.0, v.z), delta)
    return v


func _start_pause(length: float = -1.0) -> void:
    _mode = PAUSE
    if length < 0.0:
        match style:
            Style.PROWL:
                length = rng.randf_range(0.3, 0.8)
            Style.SKITTER:
                length = rng.randf_range(0.25, 0.7)
            Style.GUARD:
                length = rng.randf_range(1.0, 1.8)
            Style.KEEP:
                length = rng.randf_range(1.1, 2.2)
            _:
                length = rng.randf_range(0.8, 1.8)
    _pause_len = length
    _mode_left = length
    _look_from = atan2(heading.z, heading.x)


func _pick_waypoint() -> bool:
    var p: Vector3 = body.global_position
    for attempt in 12:
        var wp: Vector3
        var shrink: float = 1.0 - attempt * 0.07
        match style:
            Style.GUARD:
                var post: float = TAU * float(_guard_index) / 4.0 + _orbit
                var r: float = clampf(leash * 0.6, 0.6, 4.5) * shrink
                wp = home + Vector3(cos(post), 0.0, sin(post)) * r
                if attempt >= 3:
                    _guard_index += 1
            Style.PROWL:
                var step: float = circle_sign * rng.randf_range(0.9, 1.6)
                var a: float = atan2(p.z - home.z, p.x - home.x) + step
                if rng.randf() < 0.15:
                    circle_sign = -circle_sign
                wp = home + Vector3(cos(a), 0.0, sin(a)) * leash * rng.randf_range(0.45, 0.85) * shrink
            _:
                var a3: float = rng.randf() * TAU
                wp = home + Vector3(cos(a3), 0.0, sin(a3)) * leash * sqrt(rng.randf()) * shrink
        wp.y = p.y
        var span: float = _flat(wp - p).length()
        if span < 1.4 or not in_leash(wp):
            continue
        var leg: Vector3 = _flat(wp - p) / span
        if style != Style.GUARD and style != Style.PROWL and attempt < 8 and absf(leg.dot(_last_leg)) > 0.5:
            continue  # turn a new way each leg: the roam covers the area, not one line
        if not _path_on_ground(p, wp):
            continue
        _wp = wp
        _last_leg = leg
        if style == Style.GUARD:
            _guard_index += 1
        return true
    return false


func _path_on_ground(from: Vector3, to: Vector3) -> bool:
    var samples: int = maxi(2, ceili(_flat(to - from).length() / 1.2))
    for i in range(1, samples + 1):
        if not ground_at(from.lerp(to, float(i) / samples)):
            return false
    return true


# --- Engaged ---------------------------------------------------------------------------------

## Planar velocity for an enemy fighting `target`: close in toward a spread-out slot on a ring of
## `ring` m round the target (along `detour`, the navigation direction, when it bends round an
## obstacle), then hold the ring and strafe around at `strafe_speed`.
func engage_velocity(target: Node3D, ring: float, speed: float, strafe_speed: float, delta: float, detour: Vector3 = Vector3.ZERO) -> Vector3:
    _clock += delta
    update_floor(delta)
    _flip_left -= delta
    if _flip_left <= 0.0:
        _flip_left = rng.randf_range(2.5, 5.0)
        if rng.randf() < 0.35:
            circle_sign = -circle_sign
    var off: Vector3 = _flat(body.global_position - target.global_position)
    var dist: float = off.length()
    if dist < 0.01:
        off = Vector3(1.0, 0.0, 0.0) * 0.01
        dist = 0.01
    var bearing: float = atan2(off.z, off.x)
    var push: float = spread_push(target, bearing, ring)
    var tangent: Vector3 = Vector3(-sin(bearing), 0.0, cos(bearing))
    if dist > ring + 2.5:
        var slot_bearing: float = bearing + clampf(push, -1.0, 1.0)
        var slot: Vector3 = target.global_position + Vector3(cos(slot_bearing), 0.0, sin(slot_bearing)) * ring
        var dir: Vector3 = _flat(slot - body.global_position)
        var straight: Vector3 = -off
        if detour.length_squared() > 0.0001 and _flat(detour).angle_to(straight) > 0.35:
            dir = _flat(detour)  # the navigation path bends round something: follow it
        return dir.normalized() * speed
    var radial: Vector3 = -off / dist * clampf((dist - ring) * 1.5, -1.0, 1.0) * speed
    var around: Vector3 = tangent * (circle_sign * strafe_speed + push * strafe_speed)
    var v: Vector3 = radial + around
    if v.length_squared() > 0.0001 and not safe_step(v, 0.7):
        circle_sign = -circle_sign  # a ledge or the leash: circle the other way
        v = radial
    return v


## How far (radians, signed) this enemy's bearing round `target` is pushed away from the other
## enemies close round the same target, so a group spreads out instead of stacking on one line.
func spread_push(target: Node3D, bearing: float, ring: float) -> float:
    var push: float = 0.0
    var reach: float = maxf(ring * 3.0, 9.0)
    for other: Node in body.get_tree().get_nodes_in_group(&"enemy"):
        if other == body or not (other is Node3D) or (other.has_method(&"is_dead") and bool(other.call(&"is_dead"))):
            continue
        var o: Vector3 = _flat((other as Node3D).global_position - target.global_position)
        if o.length() > reach or o.length() < 0.01:
            continue
        var d: float = angle_difference(atan2(o.z, o.x), bearing)  # >0: the other is behind us
        if absf(d) < 1.1:
            var side: float = signf(d) if absf(d) > 0.001 else (1.0 if body.get_instance_id() > other.get_instance_id() else -1.0)
            push += side * (1.1 - absf(d))
    return push


# --- Helpers ---------------------------------------------------------------------------------

func _turn_to(want: Vector3, delta: float) -> void:
    want.y = 0.0
    if want.length_squared() < 0.0001:
        return
    want = want.normalized()
    var angle: float = heading.signed_angle_to(want, Vector3.UP)
    var step: float = clampf(angle, -turn_rate * delta, turn_rate * delta)
    heading = heading.rotated(Vector3.UP, step).normalized()


func _flat(v: Vector3) -> Vector3:
    return Vector3(v.x, 0.0, v.z)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
    if not body.is_inside_tree():
        return {}
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1, [body.get_rid()])
    var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
    for i in 3:
        var hit: Dictionary = space.intersect_ray(query)
        if hit.is_empty():
            return {}
        if not (hit["collider"] is CharacterBody3D):
            return hit
        var ex: Array[RID] = query.exclude
        ex.append(hit["rid"])
        query.exclude = ex  # another body (enemy, player) is not ground: look past it
    return {}

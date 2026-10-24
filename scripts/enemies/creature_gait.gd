class_name CreatureGait
extends RefCounted
## Procedural feet for the full-3D creatures (DEC-064): every leg is a two-bone chain of a
## CreatureRig that keeps its foot PLANTED on the ground while the body moves, and steps when
## the foot falls `stride` m behind where it should be (its home under the body, led along the
## velocity). Legs in different `group`s never swing together (tripod for the spider, diagonal
## pairs for a crawler, left/right for a biped). Landing spots come from one ray each step, so
## feet follow slopes and steps. Airborne, the legs dangle toward their homes.
## Nothing here moves the body or touches combat: it is presentation only.

class Leg:
    var upper: StringName
    var lower: StringName
    var end_local: Vector3
    var home: Vector3          # model space, on the ground
    var pole: Vector3          # model-space bend direction of the middle joint
    var group: int = 0
    var lift: float = 1.0
    var sole: float = 0.03     # height of the foot point above the ground
    var planted: Vector3 = Vector3.ZERO
    var from: Vector3
    var to: Vector3
    var t: float = -1.0        # >= 0 while swinging
    var pos: Vector3           # where the foot is this frame (world)
    var override_w: float = 0.0
    var override_at: Vector3   # world target used with weight override_w (reaching, rearing)

var rig: CreatureRig
var body: CharacterBody3D
var legs: Array[Leg] = []
var stride: float = 0.45
var swing_time: float = 0.2
var lift: float = 0.12
var lead: float = 0.22
var steps: int = 0
var enabled: bool = true
var _ready_feet: bool = false
## Called with the world position of every foot that lands (dust, blood, sound).
var on_step: Callable


func _init(the_rig: CreatureRig, the_body: CharacterBody3D) -> void:
    rig = the_rig
    body = the_body


## Adds a leg ending at `end` (a child part/empty of `lower`, or the lower part's own end).
func add_leg(upper: StringName, lower: StringName, end: StringName, group: int, pole: Vector3, home_offset: Vector3 = Vector3.ZERO, leg_lift: float = 1.0) -> Leg:
    if not rig.has(upper) or not rig.has(lower) or not rig.has(end):
        return null
    var leg: Leg = Leg.new()
    leg.upper = upper
    leg.lower = lower
    leg.end_local = (rig.rest[end] as Transform3D).origin
    var end_model: Vector3 = (rig.rest_root[end] as Transform3D).origin
    leg.home = Vector3(end_model.x, 0.0, end_model.z) + home_offset
    leg.sole = clampf(end_model.y, 0.0, 0.22)
    leg.pole = pole
    leg.group = group
    leg.lift = leg_lift
    legs.append(leg)
    return leg


func reset() -> void:
    _ready_feet = false


## Ground height under world point `at` (ray down), or `fallback`.
func ground_y(at: Vector3, fallback: float) -> float:
    if not body.is_inside_tree():
        return fallback
    var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.9, at + Vector3.DOWN * 1.4, 1, [body.get_rid()])
    var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
    for i in 3:
        var hit: Dictionary = space.intersect_ray(q)
        if hit.is_empty():
            return fallback
        if not (hit["collider"] is CharacterBody3D):
            return (hit["position"] as Vector3).y
        var ex: Array[RID] = q.exclude
        ex.append(hit["rid"])
        q.exclude = ex
    return fallback


## Per frame: plant/step every foot and solve its IK. `feet_y` is the world height the body's
## feet would stand at (its floor). `grounded` false: dangle. `pace` scales step speed.
func update(delta: float, feet_y: float, grounded: bool, pace: float = 1.0) -> void:
    if not enabled or legs.is_empty():
        return
    var v: Vector3 = body.velocity
    v.y = 0.0
    var xf: Transform3D = rig.model.global_transform
    var flat: Basis = rig.model.global_basis
    if not _ready_feet:
        _ready_feet = true
        for leg: Leg in legs:
            var h: Vector3 = xf * leg.home
            leg.planted = Vector3(h.x, ground_y(h, feet_y) + leg.sole, h.z)
            leg.pos = leg.planted
            leg.t = -1.0
    var swinging: Dictionary = {}
    for leg: Leg in legs:
        if leg.t >= 0.0:
            swinging[leg.group] = true
    for leg: Leg in legs:
        var home: Vector3 = xf * leg.home
        var want: Vector3 = Vector3(home.x, feet_y + leg.sole, home.z) + v * lead
        if not grounded:
            leg.t = -1.0
            leg.planted = leg.pos.lerp(want + Vector3.UP * 0.25, 1.0 - exp(-delta * 10.0))
            leg.pos = leg.planted
        elif leg.t >= 0.0:
            leg.t += delta * pace / swing_time
            var k: float = clampf(leg.t, 0.0, 1.0)
            var e: float = k * k * (3.0 - 2.0 * k)
            leg.pos = leg.from.lerp(leg.to, e) + Vector3.UP * sin(k * PI) * lift * leg.lift
            if leg.t >= 1.0:
                leg.t = -1.0
                leg.planted = leg.to
                leg.pos = leg.to
                steps += 1
                if on_step.is_valid():
                    on_step.call(leg.to)
        else:
            var off: Vector3 = leg.planted - want
            off.y = 0.0
            var other_swinging: bool = false
            for g: int in swinging:
                if g != leg.group:
                    other_swinging = true
            if off.length() > stride and not other_swinging:
                leg.from = leg.planted
                var land: Vector3 = want + v * swing_time * 0.5
                leg.to = Vector3(land.x, ground_y(land, feet_y) + leg.sole, land.z)
                if absf(leg.to.y - (feet_y + leg.sole)) > 0.9:
                    leg.to.y = feet_y + leg.sole  # no ground there (a ledge): keep the step level
                leg.t = 0.0
                swinging[leg.group] = true
            leg.pos = leg.planted
        var target: Vector3 = leg.pos
        if leg.override_w > 0.0:
            target = target.lerp(leg.override_at, clampf(leg.override_w, 0.0, 1.0))
        rig.ik(leg.upper, leg.lower, leg.end_local, target, flat * leg.pole)


## The foot nearest to swinging, or how far through the step cycle the body is (0..1, for bob).
func phase() -> float:
    var best: float = 0.0
    for leg: Leg in legs:
        if leg.t >= 0.0:
            best = maxf(best, leg.t)
    return best

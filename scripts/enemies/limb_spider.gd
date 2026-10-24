class_name LimbSpider
extends CreatureEnemy
## The Limb Spider (DEC-064): a crawling knot of human arms and legs sewn round a prone torso
## with too many mouths, an upside-down head hanging under its front. It skitters in fast
## bursts and comes in packs (EnemyFactory `limb_spider_pack`): spiders near each other take
## turns to leap, so a pack's attacks arrive one after another, never all at once.
##   Leap: from `leap_min`..`leap_max` m it rears its front limbs and gapes every mouth for
##     `leap_windup` s, then leaps at the spot you stood on (1 damage in the air) and lands
##     crouched for `land_recover` s.
##   Bite: close in, the front mouth gapes for `bite_windup` s and snaps (1 damage).
## Fragile: 2 HP, poise 1. States: idle -> leap_windup -> leap -> land ; idle -> bite_windup ->
## bite -> land ; hitstun ; dead.

@export var skitter_speed: float = 7.0
@export var roam_speed: float = 3.0
@export var leap_min: float = 2.6
@export var leap_max: float = 6.5
@export var leap_windup: float = 0.5
@export var leap_flight: float = 0.55
@export var land_recover: float = 0.6
@export var bite_range: float = 1.5
@export var bite_windup: float = 0.32

var fangs: Hitbox
var pounce: Hitbox
var leaps: int = 0
var _cool: float = 0.8
var _crouch: float = 0.0
var _gape: float = 0.0
var _leg_out: Array[Vector3] = []


func _init() -> void:
    max_health = 2
    poise_max = 1
    shard_value = 2
    leash_radius = 11.0
    _base_color = Color(0.62, 0.55, 0.5)


func _ready() -> void:
    super._ready()
    add_to_group(&"limb_spider")


func _build_body() -> void:
    _add_collider(Vector3(0.9, 0.5, 0.9), -0.65)
    _add_hurt_shape(Vector3(1.4, 0.8, 1.5), -0.6)
    fangs = _make_hitbox(Vector3(1.0, 0.8, 1.0), Vector3(0.8, -0.6, 0.0), 1, &"spider_bite", 5.0)
    pounce = _make_hitbox(Vector3(1.3, 1.0, 1.3), Vector3(0.2, -0.55, 0.0), 1, &"spider_leap", 6.5)
    _build_rig("limb_spider", Vector3(0.9, 0.5, 0.9))
    if rig != null:
        gait = CreatureGait.new(rig, self)
        gait.stride = 0.34
        gait.swing_time = 0.09
        gait.lift = 0.16
        gait.lead = 0.12
        for k in 6:
            var end: StringName = StringName("limb%d_end" % k)
            if not rig.has(end):
                continue
            var e: Vector3 = (rig.rest_root[end] as Transform3D).origin
            var out: Vector3 = Vector3(e.x, 0.0, e.z).normalized()
            _leg_out.append(out)
            gait.add_leg(StringName("limb%d_a" % k), StringName("limb%d_b" % k), end, 0 if k in [0, 3, 4] else 1, out * 0.35 + Vector3.UP, -out * 0.15)


func _roam_style() -> Roam3D.Style:
    return Roam3D.Style.SKITTER


func _tick(delta: float, target: Node3D) -> void:
    hitbox_ahead(fangs, 0.8, -0.6)
    hitbox_ahead(pounce, 0.2, -0.55)
    _cool -= delta
    match state:
        &"idle":
            stop()
            if not ai_enabled:
                return
            if target == null:
                roam_idle(delta, roam_speed)
                return
            var off: Vector3 = planar_to(target)
            var dist: float = off.length()
            face(off)
            var dy: float = target.global_position.y - global_position.y
            var can_strike: bool = _cool <= 0.0 and _silenced_left <= 0.0 and is_on_floor()
            if can_strike and dist < bite_range and absf(dy) < 1.2:
                set_state(&"bite_windup")
                Audio.sfx(&"hound_pounce", 0.2, -8.0)
            elif can_strike and dist > leap_min and dist < leap_max and dy < 1.6 and dy > -2.5 and not _pack_busy() and _landing_ok(target.global_position):
                set_state(&"leap_windup")
                Audio.sfx(&"husk_burst", 0.25, -12.0)
            elif roam != null:
                # Skitter in bursts on a zig-zag, circling at leaping distance.
                var burst: float = 1.0 if fmod(anim_t, 0.7) < 0.45 else 0.15
                engage(delta, target, leap_min + 0.8 if _cool > 0.0 else bite_range * 0.7, skitter_speed * burst, skitter_speed * 0.55 * burst)
                if dist > 2.5:
                    var v: Vector3 = Vector3(velocity.x, 0.0, velocity.z).rotated(Vector3.UP, sin(anim_t * 7.0) * 0.5)
                    velocity.x = v.x
                    velocity.z = v.z
            elif dist > bite_range * 0.8:
                move_dir(chase_dir(target), skitter_speed * (1.0 if fmod(anim_t, 0.7) < 0.45 else 0.2))
        &"leap_windup":
            stop()
            if target != null:
                face(planar_to(target))
            if _t >= leap_windup:
                if target != null:
                    _leap_at(target.global_position)
                else:
                    set_state(&"idle")
        &"leap":
            if _t > 0.12 and is_on_floor():
                pounce.deactivate()
                Audio.sfx(&"land", 0.15, -6.0)
                set_state(&"land")
            elif _t > leap_flight * 2.5:
                pounce.deactivate()
                set_state(&"land")
        &"bite_windup":
            stop()
            if target != null:
                face(planar_to(target))
            if _t >= bite_windup:
                fangs.activate()
                move_dir(heading, 3.0)
                Audio.sfx(&"hound_pounce", 0.2, -2.0)
                set_state(&"bite")
        &"bite":
            _brake(20.0 * delta)
            if _t >= 0.16:
                fangs.deactivate()
                set_state(&"land")
        &"land":
            _brake(30.0 * delta)
            if _t >= land_recover:
                _cool = rng.randf_range(0.9, 1.8)
                set_state(&"idle")


## Another spider of the pack close by is already leaping (take turns).
func _pack_busy() -> bool:
    for other: Node in get_tree().get_nodes_in_group(&"limb_spider"):
        if other == self or (other as LimbSpider).is_dead():
            continue
        var o: LimbSpider = other as LimbSpider
        if (o.state == &"leap_windup" or o.state == &"leap") and o.global_position.distance_to(global_position) < 8.0:
            return true
    return false


## Never leap at a spot over a gap (or out of the leash).
func _landing_ok(at: Vector3) -> bool:
    if roam == null:
        return plane_locked and at.x > min_x and at.x < max_x
    for k: float in [0.35, 0.7, 1.0]:
        var p: Vector3 = global_position.lerp(at, k)
        if not roam.ground_at(p):
            return false
    return roam.in_leash(at)


func _leap_at(at: Vector3) -> void:
    var g: float = 26.0
    var to: Vector3 = at - global_position
    to.y = 0.0
    if plane_locked:
        to.z = 0.0
    to = to.limit_length(leap_max + 0.5)
    var t: float = leap_flight
    velocity.x = to.x / t
    velocity.z = to.z / t
    var dy: float = clampf(at.y - global_position.y, -2.0, 1.6)
    velocity.y = (dy + 0.5 * g * t * t) / t
    pounce.activate()
    leaps += 1
    Audio.sfx(&"hound_pounce", 0.15)
    set_state(&"leap")


func _on_poise_break(info: DamageInfo) -> void:
    fangs.deactivate()
    pounce.deactivate()
    super._on_poise_break(info)


func _on_silenced() -> void:
    if state in [&"leap_windup", &"bite_windup"]:
        set_state(&"idle")


func _on_died() -> void:
    fangs.deactivate()
    pounce.deactivate()
    super._on_died()


func _on_death_fx() -> void:
    Audio.sfx(&"husk_burst", 0.2, -4.0)


func _glow() -> Color:
    if state == &"leap_windup":
        return Color(1.0, 0.1, 0.05) * (0.4 + 0.6 * _t / leap_windup)
    if state == &"bite_windup":
        return Color(1.0, 0.15, 0.05) * 0.6
    return Color.BLACK


# --- Animation --------------------------------------------------------------------------------

func _animate(delta: float) -> void:
    var crouch_to: float = 0.0
    var gape_to: float = 0.15 + 0.25 * maxf(0.0, sin(anim_t * 2.3))
    match state:
        &"leap_windup":
            crouch_to = 1.0
            gape_to = 1.0
        &"bite_windup":
            crouch_to = 0.4
            gape_to = 1.0
        &"bite":
            gape_to = 0.0
        &"land":
            crouch_to = 0.7 * (1.0 - _t / land_recover)
        &"leap":
            gape_to = 0.9
    _crouch = move_toward(_crouch, crouch_to, delta * 5.0)
    _gape = move_toward(_gape, gape_to, delta * (12.0 if gape_to < _gape else 6.0))
    var sp: float = clampf(speed() / skitter_speed, 0.0, 1.0)
    var tw: Vector3 = twitch(&"body", Vector3(0.12, 0.25, 0.12), 0.5, delta)
    rig.shift(&"body", Vector3(0.0, -0.14 * _crouch + sin(anim_t * 19.0) * 0.02 * sp + 0.03 * sin(anim_t * 1.7), 0.0))
    var airborne: bool = not is_on_floor()
    rig.turn(&"body", Vector3(0.18 * sp - 0.35 * _crouch * (1.0 if state == &"leap_windup" else 0.0) + (-0.25 if airborne else 0.0) + tw.x, tw.y, tw.z))
    rig.turn(&"head", Vector3(0.2 * sin(anim_t * 2.1), 0.0, 0.35 * sin(anim_t * 1.3)) + twitch(&"head", Vector3(0.6, 0.8, 0.7), 0.5, delta))
    for k in 4:
        var m: StringName = StringName("mouth_%d" % k)
        var own: float = 0.5 + 0.5 * sin(anim_t * (3.0 + k * 1.7) + k)
        var o: float = clampf(_gape * (0.6 + 0.6 * own) + twitch(StringName("m%d" % k), Vector3(0.4, 0, 0), 0.4, delta).x, 0.15, 1.9)
        if rig.has(m):
            (rig.p(m) as Node3D).scale = Vector3(1.0 + 0.15 * o, 1.0, 0.45 + 1.0 * o)
    if gait == null:
        return
    # Rearing: the front limbs lift off the ground and reach forward; in the air all of them do.
    var model_xf: Transform3D = rig.model.global_transform
    for i in gait.legs.size():
        var leg: CreatureGait.Leg = gait.legs[i]
        var front: bool = i < 2
        var w: float = 0.0
        if state == &"leap_windup" and front:
            w = clampf(_t / (leap_windup * 0.5), 0.0, 1.0)
        elif state == &"leap":
            w = 1.0
        leg.override_w = w
        if w > 0.0:
            var out: Vector3 = _leg_out[i] if i < _leg_out.size() else Vector3.FORWARD
            var reach: Vector3 = out * 0.9 + Vector3(0.0, 0.7 if front else 0.15, 0.55 if front else 0.2)
            leg.override_at = model_xf * (Vector3(0.0, 0.42, 0.0) + reach)
    gait.update(delta, feet_y(), not airborne, 1.0 + sp)


func _animate_death(delta: float) -> void:
    var k: float = clampf(death_t / 0.5, 0.0, 1.0)
    var e: float = k * k * (3.0 - 2.0 * k)
    rig.shift(&"body", Vector3(0.0, lerpf(0.0, -0.26, e), 0.0))
    rig.turn(&"body", Vector3(0.2 * e, 0.0, 0.5 * e))
    rig.turn(&"head", Vector3(0.6 * e, 0.0, 0.9 * e))
    var model_xf: Transform3D = rig.model.global_transform
    var spasm: float = exp(-death_t * 2.0)
    for i in mini(6, _leg_out.size()):
        var leg: CreatureGait.Leg = gait.legs[i] if gait != null and i < gait.legs.size() else null
        if leg == null:
            continue
        # Legs curl in over the body like a dead spider's.
        var curl: Vector3 = model_xf * (Vector3(0.0, 0.42 - 0.26 * e, 0.0) + _leg_out[i] * lerpf(1.0, 0.3, e) + Vector3.UP * 0.45 * e)
        curl += twitch(StringName("dl%d" % i), Vector3(0.25, 0.25, 0.25), 0.15, delta) * spasm
        var target: Vector3 = leg.pos.lerp(curl, e)
        rig.ik(leg.upper, leg.lower, leg.end_local, target, rig.model.global_basis * leg.pole)
    for m in 4:
        var mouth: StringName = StringName("mouth_%d" % m)
        if rig.has(mouth):
            (rig.p(mouth) as Node3D).scale = Vector3(1.1, 1.0, lerpf(1.0, 1.6, e))

class_name FlayedStalker
extends CreatureEnemy
## The Flayed Stalker (DEC-064): a tall skinless thing of wet muscle and sinew, jaw hanging
## open, that STALKS on all fours: it circles you at a distance, creeping, then darts in.
## Within `lunge_range` it REARS UP on its hind legs (`rise_time` s: hooked hands raised, jaw
## gaping, eyes flaring, a red rim) and LUNGES along the line it reared on (claws, 1 damage).
## Then it hunches, spent, for `recover_time` s: the punish window. Fast but fragile (3 HP,
## poise 1: any hit cancels the rear-up). It drips blood as it moves.
## States: idle (stalk/close) -> rise -> lunge -> recover -> idle ; hitstun ; dead.

@export var crawl_speed: float = 6.2
@export var stalk_speed: float = 2.2
@export var roam_speed: float = 2.0
@export var lunge_range: float = 4.4
@export var rise_time: float = 0.55
@export var lunge_speed: float = 11.0
@export var lunge_time: float = 0.32
@export var recover_time: float = 0.9
@export var stalk_ring: float = 6.0

var claws: Hitbox
var lunges: int = 0
var _stalk_left: float = 1.2
var _drip_left: float = 0.0
var _lunge_dir: Vector3 = Vector3.RIGHT
var _rise: float = 0.0
var _slash: float = 0.0


func _init() -> void:
    max_health = 3
    poise_max = 1
    shard_value = 3
    _base_color = Color(0.5, 0.08, 0.07)


func _build_body() -> void:
    _add_collider(Vector3(0.7, 1.3, 0.7), -0.35)
    _add_hurt_shape(Vector3(0.95, 1.6, 1.2), -0.2)
    claws = _make_hitbox(Vector3(1.3, 1.4, 1.3), Vector3(0.8, -0.3, 0.0), 1, &"stalker_claw", 7.0)
    claws.hitstun = 0.4
    _build_rig("flayed_stalker", Vector3(0.6, 1.2, 0.6))
    if rig != null:
        gait = CreatureGait.new(rig, self)
        gait.stride = 0.42
        gait.swing_time = 0.16
        gait.lift = 0.16
        gait.lead = 0.16
        for s: float in [1.0, -1.0]:
            var tag: String = "L" if s > 0.0 else "R"
            gait.add_leg(StringName("arm_%s_up" % tag), StringName("arm_%s_lo" % tag), StringName("hand_%s" % tag), 0 if s > 0.0 else 1,
                Vector3(1.0 * s, 0.5, -0.7), Vector3(0.1 * s, 0.0, 0.86))
            gait.add_leg(StringName("leg_%s_up" % tag), StringName("leg_%s_lo" % tag), StringName("foot_%s" % tag), 1 if s > 0.0 else 0,
                Vector3(0.25 * s, 0.0, 1.0), Vector3(0.05 * s, 0.0, -0.2))
        gait.on_step = _on_step


func _roam_style() -> Roam3D.Style:
    return Roam3D.Style.PROWL


func _tick(delta: float, target: Node3D) -> void:
    hitbox_ahead(claws, 0.8, -0.3)
    match state:
        &"idle":
            stop()
            if not ai_enabled:
                return
            if target == null:
                roam_idle(delta, roam_speed)
                _stalk_left = maxf(_stalk_left, 1.0)
                return
            var off: Vector3 = planar_to(target)
            face(off)
            _stalk_left -= delta
            var dy: float = absf(target.global_position.y - global_position.y)
            if off.length() < lunge_range and _stalk_left <= 0.0 and _silenced_left <= 0.0 and is_on_floor() and dy < 1.6:
                set_state(&"rise")
                Audio.sfx(&"beam_charge", 0.15, -10.0)
            elif roam != null:
                if _stalk_left > 0.0:
                    engage(delta, target, stalk_ring, crawl_speed * 0.8, stalk_speed)  # circles, creeping
                else:
                    engage(delta, target, lunge_range * 0.6, crawl_speed, stalk_speed * 0.5)  # darts in
            elif off.length() > lunge_range * 0.7:
                move_dir(chase_dir(target), crawl_speed if _stalk_left <= 0.0 else stalk_speed)
        &"rise":
            stop()
            if target != null and _t < rise_time * 0.8:
                face(planar_to(target))  # tracks you, then commits
            if _t >= rise_time:
                _lunge_dir = heading
                claws.activate()
                lunges += 1
                Audio.sfx(&"hound_pounce", 0.12)
                set_state(&"lunge")
        &"lunge":
            var k: float = clampf(_t / lunge_time, 0.0, 1.0)
            move_dir(_lunge_dir, lunge_speed * (1.0 - 0.6 * k))
            if roam != null and not roam.safe_step(_lunge_dir, 0.9):
                stop()
            if _t >= lunge_time:
                claws.deactivate()
                set_state(&"recover")
        &"recover":
            _brake(24.0 * delta)
            if _t >= recover_time:
                _stalk_left = rng.randf_range(1.0, 2.2)
                set_state(&"idle")


func _apply_motion(delta: float) -> void:
    super._apply_motion(delta)
    _drip_left -= delta
    if _drip_left <= 0.0 and not _dead and rig != null and is_inside_tree():
        _drip_left = rng.randf_range(0.18, 0.4) if speed() > 1.0 else rng.randf_range(0.6, 1.2)
        var at: Vector3 = (rig.p(&"chest") if rig.has(&"chest") else self).global_position
        at += Vector3(rng.randf_range(-0.15, 0.15), -0.05, rng.randf_range(-0.15, 0.15))
        Gore.drop(self, at, Vector3(velocity.x * 0.3, -0.4, velocity.z * 0.3), rng.randf_range(0.014, 0.022), Gore.tint_for(Gore.Fluid.BLOOD), 0.0, rng.randf_range(0.1, 0.2))


func _on_step(at: Vector3) -> void:
    if rng.randf() < 0.25:
        Gore.drop(self, at + Vector3.UP * 0.12, Vector3(0.0, -0.6, 0.0), 0.016, Gore.tint_for(Gore.Fluid.BLOOD), 0.0, rng.randf_range(0.12, 0.22))


func _on_poise_break(info: DamageInfo) -> void:
    claws.deactivate()
    super._on_poise_break(info)


func _on_silenced() -> void:
    if state == &"rise":
        set_state(&"idle")


func _on_died() -> void:
    claws.deactivate()
    super._on_died()


func _on_death_fx() -> void:
    Audio.sfx(&"husk_burst", 0.1, -3.0)


func _glow() -> Color:
    if state == &"rise":
        return Color(1.0, 0.12, 0.04) * (0.45 + 0.55 * _t / rise_time) * (0.75 + 0.25 * sin(_t * 40.0))
    return Color.BLACK


# --- Animation --------------------------------------------------------------------------------

func _animate(delta: float) -> void:
    var want_rise: float = 0.0
    match state:
        &"rise":
            want_rise = clampf(_t / (rise_time * 0.7), 0.0, 1.0)
        &"lunge":
            want_rise = 0.75
        &"hitstun":
            want_rise = 0.25
    _rise = move_toward(_rise, want_rise, delta * (6.0 if want_rise > _rise else 3.0))
    _slash = move_toward(_slash, 1.0 if state == &"lunge" else 0.0, delta * (9.0 if state == &"lunge" else 3.0))
    var r: float = _rise * _rise * (3.0 - 2.0 * _rise)
    var sp: float = clampf(speed() / crawl_speed, 0.0, 1.0)
    var breath: float = sin(anim_t * (2.2 + 3.0 * sp))
    var low: float = 0.06 if state == &"recover" else 0.0
    # Spine: folded onto all fours, rearing up as r -> 1, diving forward in the lunge.
    rig.shift(&"pelvis", Vector3(0.0, lerpf(-0.3, -0.1, r) - low + breath * 0.012, lerpf(-0.12, -0.12, r)))
    var tw: Vector3 = twitch(&"spine", Vector3(0.08, 0.1, 0.06), 0.9, delta)
    rig.turn(&"pelvis", Vector3(lerpf(0.78, 0.12, r) + _slash * 0.5, tw.y * 0.5, 0.0))
    rig.turn(&"spine", Vector3(lerpf(0.62, 0.02, r) + tw.x + breath * 0.03 + low, 0.0, tw.z))
    rig.turn(&"chest", Vector3(lerpf(0.38, -0.3, r) + _slash * 0.25, -tw.y, 0.0))
    var ht: Vector3 = twitch(&"head", Vector3(0.35, 0.6, 0.7), 0.7, delta)
    rig.turn(&"neck", Vector3(lerpf(-0.75, -0.15, r) + ht.x * 0.4, ht.y * 0.4, 0.0))
    rig.turn(&"head", Vector3(lerpf(-0.85, -0.35, r) + ht.x, ht.y, ht.z + 0.3 * sin(anim_t * 0.7)))
    rig.p(&"head").scale = Vector3.ONE * 1.15
    var jt: Vector3 = twitch(&"jaw", Vector3(0.3, 0.0, 0.08), 0.5, delta)
    rig.turn(&"jaw", Vector3(clampf(lerpf(0.38, 1.05, r) + jt.x + sin(anim_t * 5.0) * 0.05, 0.05, 1.2), 0.0, jt.z))
    # Limbs: planted by the gait (hands are its front feet), then raised as it rears.
    if gait != null:
        gait.update(delta, feet_y(), is_on_floor(), 1.0 + sp * 0.6)
    for s: float in [1.0, -1.0]:
        var tag: String = "L" if s > 0.0 else "R"
        var up: StringName = StringName("arm_%s_up" % tag)
        var lo: StringName = StringName("arm_%s_lo" % tag)
        var hand: StringName = StringName("hand_%s" % tag)
        var raise: Vector3 = Vector3(-2.55 + _slash * 1.7, 0.0, s * (0.45 - _slash * 0.3))
        rig.blend(up, raise, r)
        rig.blend(lo, Vector3(-0.7 + _slash * 0.4, 0.0, 0.0), r)
        var ft: Vector3 = twitch(StringName("fing_" + tag), Vector3(0.4, 0.2, 0.3), 0.6, delta)
        rig.turn(hand, Vector3(lerpf(0.5, -0.5, r) + ft.x, ft.y, ft.z))


func _animate_death(delta: float) -> void:
    var k: float = clampf(death_t / 0.45, 0.0, 1.0)
    var e: float = k * k
    var spasm: float = exp(-death_t * 1.8)
    rig.shift(&"pelvis", Vector3(0.0, lerpf(-0.44, -0.95, e), 0.0))
    rig.turn(&"pelvis", Vector3(lerpf(0.55, 1.5, e), 0.0, 0.25 * e))
    rig.turn(&"spine", Vector3(0.15, 0.0, -0.2 * e) + twitch(&"d_spine", Vector3(0.25, 0.2, 0.2), 0.25, delta) * spasm)
    rig.turn(&"chest", Vector3(0.1, 0.0, 0.1))
    rig.turn(&"neck", Vector3(-0.3, 0.5 * e, 0.0))
    rig.turn(&"head", Vector3(-0.4, 0.4 * e, 0.6 * e) + twitch(&"d_head", Vector3(0.4, 0.4, 0.4), 0.2, delta) * spasm)
    rig.turn(&"jaw", Vector3(1.2, 0.0, 0.15))
    for s: float in [1.0, -1.0]:
        var tag: String = "L" if s > 0.0 else "R"
        var limb: Vector3 = twitch(StringName("d_" + tag), Vector3(0.6, 0.4, 0.5), 0.18, delta) * spasm
        rig.turn(StringName("arm_%s_up" % tag), Vector3(-1.4, 0.0, s * 1.0 * e) + limb)
        rig.turn(StringName("arm_%s_lo" % tag), Vector3(-0.5, 0.0, 0.0) + limb * 0.5)
        rig.turn(StringName("leg_%s_up" % tag), Vector3(-0.3 * e, 0.0, s * 0.35 * e) + limb * 0.4)
        rig.turn(StringName("leg_%s_lo" % tag), Vector3(0.6 * e, 0.0, 0.0))
        rig.turn(StringName("hand_%s" % tag), Vector3(0.9, 0.0, 0.0) + limb)

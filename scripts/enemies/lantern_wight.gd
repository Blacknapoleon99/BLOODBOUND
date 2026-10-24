class_name LanternWight
extends CreatureEnemy
## The Lantern Wight (DEC-064): an impossibly tall (3.2 m), thin figure of grey tallow under a
## tattered black mantle, a crown of guttering candles fused into its skull and a cage-lantern
## hanging from its right hand (a real light). It bleeds wax and ash (Gore WAX), not blood.
## It only moves while it is NOT SEEN: whenever the active camera has it in view (inside the
## frustum, with no wall in between) it freezes mid-stride like a statue. Turn away and it
## lurches after you, chains rattling. Beside you (`swing_range`), and unseen, it hauls the
## lantern back (`swing_windup` s: the lantern flares and lights the floor round you), then
## swings it hard (2 damage); once begun, the swing finishes even if you look. Fragile once
## you face it: 7 HP, poise 3.
## States: idle (frozen / stalking) -> swing_windup -> swing -> swing_recover ; hitstun ; dead.

@export var move_speed: float = 4.4
@export var roam_speed: float = 1.3
@export var swing_range: float = 2.4
@export var swing_windup: float = 0.5
@export var swing_recover: float = 0.95
## Off only for dev captures: the wight then moves even while it is in view.
@export var freeze_when_seen: bool = true

var lantern_hit: Hitbox
var swings: int = 0
## Seen by the active camera this frame (frozen while idle).
var watched: bool = false
## Times it froze because it was seen (tests).
var freezes: int = 0
var light: OmniLight3D
var _rattle_left: float = 0.0
var _haul: float = 0.0
var _sweep: float = 0.0
var _pend: Vector2 = Vector2.ZERO
var _pend_v: Vector2 = Vector2.ZERO
var _last_hand: Vector3 = Vector3.ZERO
var _pose_seed: float = 0.0


func _init() -> void:
    max_health = 7
    poise_max = 3
    shard_value = 6
    _base_color = Color(0.7, 0.68, 0.6)


func _build_body() -> void:
    _add_collider(Vector3(0.7, 3.0, 0.7), 0.5)
    _add_hurt_shape(Vector3(0.95, 3.1, 0.95), 0.55)
    lantern_hit = _make_hitbox(Vector3(2.0, 1.8, 2.6), Vector3(1.3, 0.2, 0.0), 2, &"wight_lantern", 10.0)
    lantern_hit.knockback_up = 4.0
    lantern_hit.hitstun = 0.5
    _build_rig("lantern_wight", Vector3(0.6, 3.1, 0.6))
    light = OmniLight3D.new()
    light.name = "LanternLight"
    light.light_color = Color(1.0, 0.7, 0.38)
    light.light_energy = 1.6
    light.omni_range = 6.0
    light.omni_attenuation = 1.4
    light.shadow_enabled = false
    if rig != null and rig.has(&"lantern_light"):
        rig.p(&"lantern_light").add_child(light)
    else:
        light.position = Vector3(0.3, -0.3, 0.0)
        _visual.add_child(light)
    if rig != null:
        gait = CreatureGait.new(rig, self)
        gait.stride = 0.75
        gait.swing_time = 0.2
        gait.lift = 0.22
        gait.lead = 0.15
        gait.add_leg(&"leg_L_up", &"leg_L_lo", &"foot_L", 0, Vector3(0.0, 0.0, 1.0), Vector3(0.06, 0.0, 0.0))
        gait.add_leg(&"leg_R_up", &"leg_R_lo", &"foot_R", 1, Vector3(0.0, 0.0, 1.0), Vector3(-0.06, 0.0, 0.0))


func _roam_style() -> Roam3D.Style:
    return Roam3D.Style.GUARD


## True when the active camera can see the wight: any of head, chest or knees inside the view
## frustum with nothing solid (world layer) between them and the lens.
func is_watched() -> bool:
    var vp: Viewport = get_viewport()
    if vp == null:
        return false
    var cam: Camera3D = vp.get_camera_3d()
    if cam == null or not cam.is_inside_tree():
        return false
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    for h: float in [2.7, 1.7, 0.5]:
        var p: Vector3 = Vector3(global_position.x, feet_y() + h, global_position.z)
        if not cam.is_position_in_frustum(p) or cam.global_position.distance_to(p) > 60.0:
            continue
        var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam.global_position, p, 1, [get_rid()])
        var hit: Dictionary = space.intersect_ray(q)
        if hit.is_empty() or hit["collider"] is CharacterBody3D:
            return true
    return false


func _tick(delta: float, target: Node3D) -> void:
    hitbox_ahead(lantern_hit, 1.3, 0.2)
    var was: bool = watched
    watched = is_watched() and freeze_when_seen
    match state:
        &"idle":
            stop()
            if watched:
                if not was:
                    freezes += 1
                return  # a statue while it is seen
            if was:
                _pose_seed = rng.randf() * 100.0  # each time you look back, it stands differently
            if not ai_enabled:
                return
            if target == null:
                roam_idle(delta, roam_speed)
                return
            var off: Vector3 = planar_to(target)
            face(off)
            if off.length() < swing_range and _silenced_left <= 0.0 and is_on_floor():
                set_state(&"swing_windup")
                Audio.sfx(&"censer_swing", 0.1, -4.0)
                return
            var lurch: float = 0.35 + 0.95 * absf(sin(anim_t * 3.6))
            if roam != null:
                engage(delta, target, swing_range * 0.6, move_speed * lurch, 0.0)
            else:
                move_dir(chase_dir(target), move_speed * lurch)
            _rattle_left -= delta
            if _rattle_left <= 0.0 and off.length() < 14.0:
                _rattle_left = rng.randf_range(0.8, 1.4)
                Audio.sfx(&"card_chains", 0.2, -9.0)
        &"swing_windup":
            stop()
            if target != null and _t < swing_windup * 0.7:
                face(planar_to(target))
            if _t >= swing_windup:
                lantern_hit.activate()
                swings += 1
                Audio.sfx(&"heavy_swing", 0.1, 1.0)
                set_state(&"swing")
        &"swing":
            stop()
            if _t >= 0.2:
                lantern_hit.deactivate()
                set_state(&"swing_recover")
        &"swing_recover":
            _brake(20.0 * delta)
            if _t >= swing_recover:
                set_state(&"idle")


## Frozen statues don't drift on their own; knockback still moves them.
func is_frozen() -> bool:
    return watched and state == &"idle" and not _dead


func _on_poise_break(info: DamageInfo) -> void:
    lantern_hit.deactivate()
    super._on_poise_break(info)


func _on_silenced() -> void:
    if state == &"swing_windup":
        set_state(&"idle")


func _on_died() -> void:
    lantern_hit.deactivate()
    super._on_died()


func _on_death_fx() -> void:
    Audio.sfx(&"geyser", 0.1, -8.0)
    var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
    var embers: CPUParticles3D = CPUParticles3D.new()
    embers.name = "WightEmbers"
    embers.one_shot = true
    embers.explosiveness = 0.7
    embers.amount = 48
    embers.lifetime = 1.6
    embers.direction = Vector3.UP
    embers.spread = 70.0
    embers.initial_velocity_min = 1.0
    embers.initial_velocity_max = 3.5
    embers.gravity = Vector3(0.0, 1.2, 0.0)
    embers.damping_min = 0.5
    embers.damping_max = 1.5
    embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    embers.emission_box_extents = Vector3(0.3, 1.2, 0.3)
    embers.scale_amount_min = 0.6
    embers.scale_amount_max = 1.3
    var ramp: Gradient = Gradient.new()
    ramp.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
    ramp.set_color(1, Color(0.6, 0.1, 0.02, 0.0))
    embers.color_ramp = ramp
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2(0.06, 0.06)
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.vertex_color_use_as_albedo = true
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.billboard_keep_scale = true
    m.albedo_texture = BloodTextures.soft_dot()
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.disable_fog = true
    quad.material = m
    embers.mesh = quad
    host.add_child(embers)
    embers.global_position = global_position + Vector3(0.0, 0.6, 0.0)
    embers.emitting = true
    get_tree().create_timer(2.2, false).timeout.connect(embers.queue_free)
    _drop_lantern(host)


## The lantern falls from the dead hand, rolls a little and gutters out.
func _drop_lantern(host: Node) -> void:
    if rig == null or not rig.has(&"lantern"):
        return
    var lan: Node3D = rig.p(&"lantern")
    var xf: Transform3D = lan.global_transform
    lan.get_parent().remove_child(lan)
    host.add_child(lan)
    lan.global_transform = xf
    var floor_y: float = feet_y()
    if gait != null:
        floor_y = gait.ground_y(xf.origin, feet_y())
    var fall: float = maxf(0.0, xf.origin.y - (floor_y + 0.62))
    var t: float = sqrt(2.0 * fall / 18.0) + 0.05
    var tw: Tween = lan.create_tween()
    tw.set_parallel(true)
    tw.tween_property(lan, "global_position:y", floor_y + 0.62, t).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    tw.tween_property(lan, "rotation:z", lan.rotation.z + 1.3, t + 0.3)
    tw.tween_property(lan, "global_position:x", xf.origin.x + heading.x * 0.5, t + 0.3)
    tw.tween_property(lan, "global_position:z", xf.origin.z + heading.z * 0.5, t + 0.3)
    if light != null and light.get_parent() != null and lan.is_ancestor_of(light):
        tw.tween_property(light, "light_energy", 0.0, 2.2).set_delay(0.3)
    tw.chain().tween_interval(1.0)
    tw.chain().tween_callback(lan.queue_free)


func _glow() -> Color:
    if state == &"swing_windup":
        return Color(1.0, 0.45, 0.1) * (0.5 + 0.5 * _t / swing_windup)
    return Color.BLACK


# --- Animation --------------------------------------------------------------------------------

func _animate(delta: float) -> void:
    _flicker()
    if is_frozen():
        return  # holds whatever pose it was caught in
    var haul_to: float = 0.0
    var sweep_to: float = 0.0
    match state:
        &"swing_windup":
            haul_to = clampf(_t / (swing_windup * 0.8), 0.0, 1.0)
        &"swing":
            sweep_to = 1.0
        &"swing_recover":
            sweep_to = 1.0 - clampf(_t / swing_recover, 0.0, 1.0)
    _haul = move_toward(_haul, haul_to, delta * 3.0) if haul_to > _haul else move_toward(_haul, haul_to, delta * 10.0)
    _sweep = move_toward(_sweep, sweep_to, delta * (12.0 if sweep_to > _sweep else 1.5))
    var sp: float = clampf(speed() / move_speed, 0.0, 1.0)
    var ps: float = _pose_seed
    var lean: float = 0.2 + 0.12 * sp
    rig.shift(&"pelvis", Vector3(0.0, -0.04 - 0.04 * sp, 0.0))
    rig.turn(&"pelvis", Vector3(lean * 0.4, 0.06 * sin(anim_t * 3.6), 0.0))
    rig.turn(&"spine", Vector3(lean + 0.2 * _haul - 0.1 * _sweep, -0.4 * _haul + 0.5 * _sweep, 0.08 * sin(ps)))
    var ht: Vector3 = twitch(&"head", Vector3(0.3, 0.5, 0.6), 1.0, delta)
    rig.turn(&"head", Vector3(0.45 + 0.2 * sin(ps * 1.7) + ht.x, 0.4 * sin(ps * 2.3) + ht.y, 0.5 * sin(ps * 0.9) + ht.z))
    # Left arm: dangling, too long, fingers twitching; right arm: the lantern.
    rig.turn(&"arm_L_up", Vector3(0.15 * sin(anim_t * 3.6) - 0.3 * sp + 0.2 * sin(ps), 0.0, 0.08))
    rig.turn(&"arm_L_lo", Vector3(-0.2 - 0.15 * sin(ps * 3.1), 0.0, 0.0))
    rig.turn(&"hand_L", twitch(&"handL", Vector3(0.5, 0.3, 0.4), 0.6, delta))
    var arm_x: float = -0.25 + 1.3 * _haul - 3.0 * _sweep
    rig.turn(&"arm_R_up", Vector3(arm_x, 0.0, -0.12 - 0.45 * _haul + 0.6 * _sweep))
    rig.turn(&"arm_R_lo", Vector3(-0.3 - 0.4 * _haul, 0.0, 0.0))
    _swing_lantern(delta)
    if gait != null:
        gait.update(delta, feet_y(), is_on_floor(), 1.0)
        rig.level(&"foot_L")
        rig.level(&"foot_R")


## The cage-lantern hangs from the hand like a pendulum: it lags behind the hand's motion.
func _swing_lantern(delta: float) -> void:
    if not rig.has(&"lantern") or not rig.has(&"hand_R"):
        return
    var hand: Vector3 = rig.p(&"hand_R").global_position
    var acc: Vector3 = (hand - _last_hand) / maxf(delta, 0.001) if _last_hand != Vector3.ZERO else Vector3.ZERO
    _last_hand = hand
    var local: Vector3 = rig.model.global_basis.inverse() * acc
    var want: Vector2 = Vector2(clampf(-local.z * 0.08, -1.0, 1.0), clampf(local.x * 0.08, -1.0, 1.0))
    _pend_v += (want - _pend) * 60.0 * delta - _pend_v * 4.0 * delta
    _pend += _pend_v * delta
    rig.level(&"lantern", Basis.from_euler(Vector3(_pend.x, 0.0, _pend.y)))


func _flicker() -> void:
    if light == null:
        return
    var n: float = 0.82 + 0.18 * sin(anim_t * 23.0) * sin(anim_t * 7.3 + 1.0)
    var flare: float = 1.0 + 2.2 * _haul + 1.2 * _sweep
    light.light_energy = 1.6 * n * flare
    if rig != null:
        rig.glow(&"glass", 1.6 * n * flare)
        rig.glow(&"flame", 3.0 * (0.85 + 0.15 * sin(anim_t * 31.0)))


func _animate_death(_delta: float) -> void:
    _haul = 0.0
    _sweep = 0.0
    var k: float = clampf(death_t / 0.8, 0.0, 1.0)
    var e: float = k * k * k
    # Topples stiffly like a statue, sagging as it goes, its flames guttering out.
    rig.shift(&"pelvis", Vector3(0.0, -0.3 * e, 0.0))
    rig.turn(&"pelvis", Vector3(1.35 * e, 0.0, 0.1 * e))
    rig.turn(&"spine", Vector3(0.2 * e, 0.0, 0.0))
    rig.scale = Vector3(1.0, 1.0 - 0.12 * k, 1.0)
    rig.glow(&"flame", 3.0 * (1.0 - k))
    if light != null and rig.is_ancestor_of(light):
        light.light_energy = 1.6 * (1.0 - k)

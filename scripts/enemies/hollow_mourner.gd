class_name HollowMourner
extends CreatureEnemy
## The Hollow Mourner (DEC-064): a faceless figure in a long tattered mourning dress and a lace
## veil, hovering a hand's breadth off the ground. No blood: it bleeds dark mist (Gore ECTO).
## It drifts at a distance; every few seconds (or when you close in) it BLINKS: folds into a
## thin pale streak and reappears a couple of metres from you. Then it WAILS: its blank face
## splits open, its arms rise, and a pale ring of `wail_radius` m pulses on the floor round it
## for `wail_windup` s (filling in as the scream builds). When the ring is full, a shock bursts
## out across it (1 damage, knockback away): leave the ring, or dodge through the burst. After
## the scream it hangs limp for `wail_recover` s. A poise break (2 hits) silences the wail.
## States: idle -> blink_out -> blink_in -> wail_windup -> wail -> wail_recover -> idle ;
## hitstun ; dead.

@export var drift_speed: float = 1.2
@export var keep_ring: float = 4.6
@export var blink_every: float = 3.0
@export var blink_time: float = 0.3
@export var wail_radius: float = 3.6
@export var wail_windup: float = 1.25
@export var wail_recover: float = 1.1

var shock: Hitbox
var blinks: int = 0
var wails: int = 0
var _blink_cool: float = 1.6
var _ring: MeshInstance3D
var _fill: MeshInstance3D
var _raise: float = 0.0
var _limp: float = 0.0
var _split: float = 0.0


func _init() -> void:
    max_health = 4
    poise_max = 2
    shard_value = 4
    _base_color = Color(0.85, 0.85, 0.9)


func _build_body() -> void:
    _add_collider(Vector3(0.6, 1.9, 0.6), -0.05)
    _add_hurt_shape(Vector3(0.9, 2.15, 0.9), 0.1)
    shock = Hitbox.new()
    shock.team = &"enemy"
    shock.damage = 1
    shock.category = &"area"
    shock.knockback = 7.0
    shock.knockback_up = 3.5
    shock.hitstun = 0.45
    shock.attack_id = &"mourner_wail"
    var shape: CollisionShape3D = CollisionShape3D.new()
    var cyl: CylinderShape3D = CylinderShape3D.new()
    cyl.radius = wail_radius
    cyl.height = 2.6
    shape.shape = cyl
    shape.position.y = FEET + 1.3
    shock.add_child(shape)
    add_child(shock)
    _ring = _warning(Vector3(wail_radius, 0.0, 0.0), true)
    _fill = _warning(Vector3(wail_radius, 0.0, 0.0), true)
    var pale: StandardMaterial3D = (BishopHand._warning_material() as StandardMaterial3D).duplicate() as StandardMaterial3D
    pale.albedo_color = Color(0.75, 0.82, 1.0, 0.25)
    _ring.material_override = pale
    _build_rig("hollow_mourner", Vector3(0.6, 1.9, 0.6))


func _roam_style() -> Roam3D.Style:
    return Roam3D.Style.PATROL


func _tick(delta: float, target: Node3D) -> void:
    _blink_cool -= delta
    match state:
        &"idle":
            stop()
            if not ai_enabled:
                return
            if target == null:
                roam_idle(delta, drift_speed * 0.7)
                return
            var off: Vector3 = planar_to(target)
            face(off)
            if roam != null:
                engage(delta, target, keep_ring, drift_speed, drift_speed * 0.8)
            elif off.length() > keep_ring:
                move_dir(chase_dir(target), drift_speed)
            elif off.length() < keep_ring - 1.0:
                move_dir(-off, drift_speed)
            var close: bool = off.length() < 1.8
            if _silenced_left <= 0.0 and is_on_floor() and (_blink_cool <= 0.0 or (close and _blink_cool < blink_every - 1.0)):
                set_state(&"blink_out")
                Audio.sfx(&"dodge", 0.2, -2.0)
        &"blink_out":
            stop()
            if _t >= blink_time:
                var spot: Vector3 = _blink_spot(target)
                if spot != Vector3.INF:
                    global_position = spot
                    reset_physics_interpolation()
                    blinks += 1
                if target != null:
                    face(planar_to(target))
                set_state(&"blink_in")
        &"blink_in":
            stop()
            if target != null:
                face(planar_to(target))
            if _t >= blink_time:
                if target != null and planar_to(target).length() < wail_radius + 2.5:
                    set_state(&"wail_windup")
                    Audio.sfx(&"card_choir", 0.05, -1.0)
                    Audio.sfx(&"beam_charge", 0.05, -7.0)
                else:
                    _blink_cool = 1.0
                    set_state(&"idle")
        &"wail_windup":
            stop()
            if target != null:
                face(planar_to(target))
            _show_ring(clampf(_t / wail_windup, 0.0, 1.0))
            if _t >= wail_windup:
                _hide_ring()
                shock.activate()
                wails += 1
                _burst()
                set_state(&"wail")
        &"wail":
            stop()
            if _t >= 0.15:
                shock.deactivate()
                set_state(&"wail_recover")
        &"wail_recover":
            stop()
            if _t >= wail_recover:
                _blink_cool = blink_every * rng.randf_range(0.8, 1.2)
                set_state(&"idle")


## Where to reappear: a few metres from `target` on the same solid floor, in view of it and
## inside the leash (side view: beside it on the line). Vector3.INF if nowhere fits.
func _blink_spot(target: Node3D) -> Vector3:
    if target == null:
        return Vector3.INF
    var tp: Vector3 = target.global_position
    if plane_locked:
        for i in 6:
            var side: float = 1.0 if rng.randf() < 0.5 else -1.0
            var x: float = tp.x + side * rng.randf_range(1.8, 2.8)
            if x > min_x + 0.3 and x < max_x - 0.3:
                return Vector3(x, global_position.y + 0.05, 0.0)
        return Vector3.INF
    if roam == null or is_nan(roam.floor_y):
        return Vector3.INF
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    for i in 12:
        var a: float = rng.randf() * TAU
        var p: Vector3 = tp + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(1.9, 2.8)
        p.y = roam.floor_y
        if not roam.in_leash(p) or not roam.ground_at(p):
            continue
        var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(tp + Vector3.UP * 0.4, p + Vector3.UP * 1.2, 1, [get_rid()])
        var hit: Dictionary = space.intersect_ray(q)
        if not hit.is_empty() and not (hit["collider"] is CharacterBody3D):
            continue  # a wall between: never reappear behind or inside it
        return Vector3(p.x, roam.floor_y - FEET + 0.05, p.z)
    return Vector3.INF


func _show_ring(k: float) -> void:
    var at: Vector3 = Vector3(global_position.x, feet_y() + 0.05, global_position.z)
    _ring.visible = true
    _ring.global_position = at
    _fill.visible = true
    _fill.global_position = at + Vector3.UP * 0.01
    var s: float = maxf(0.02, k)
    _fill.scale = Vector3(s, 1.0, s)
    var m: StandardMaterial3D = _ring.material_override as StandardMaterial3D
    m.albedo_color.a = 0.18 + 0.3 * k * (0.6 + 0.4 * sin(_t * 30.0))


func _hide_ring() -> void:
    _ring.visible = false
    _fill.visible = false


## The scream's burst: a pale shock ring racing out over the floor and a puff of dark mist.
func _burst() -> void:
    Audio.sfx(&"bishop_roar", 0.25, -1.0)
    get_tree().call_group(&"camera_shaker", &"add_trauma", 0.3)
    var host: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
    var ring: MeshInstance3D = MeshInstance3D.new()
    ring.name = "MournerShock"
    var torus: TorusMesh = TorusMesh.new()
    torus.inner_radius = 0.85
    torus.outer_radius = 1.0
    torus.rings = 48
    torus.ring_segments = 6
    ring.mesh = torus
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = Color(0.78, 0.86, 1.0, 0.8)
    m.disable_fog = true
    ring.material_override = m
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    host.add_child(ring)
    ring.global_position = Vector3(global_position.x, feet_y() + 0.3, global_position.z)
    ring.scale = Vector3(0.4, 1.0, 0.4)
    var tw: Tween = ring.create_tween()
    tw.set_parallel(true)
    tw.tween_property(ring, "scale", Vector3(wail_radius, 2.0, wail_radius), 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
    tw.chain().tween_callback(ring.queue_free)
    var mist: CPUParticles3D = CPUParticles3D.new()
    mist.name = "MournerMist"
    mist.one_shot = true
    mist.explosiveness = 0.95
    mist.amount = 40
    mist.lifetime = 1.0
    mist.direction = Vector3(1.0, 0.0, 0.0)
    mist.spread = 180.0
    mist.flatness = 0.85
    mist.initial_velocity_min = 3.0
    mist.initial_velocity_max = 7.0
    mist.damping_min = 4.0
    mist.damping_max = 6.0
    mist.gravity = Vector3(0.0, 0.6, 0.0)
    mist.scale_amount_min = 0.5
    mist.scale_amount_max = 1.2
    var ramp: Gradient = Gradient.new()
    ramp.set_color(0, Color(0.15, 0.12, 0.2, 0.8))
    ramp.set_color(1, Color(0.05, 0.04, 0.07, 0.0))
    mist.color_ramp = ramp
    var quad: QuadMesh = QuadMesh.new()
    var qm: StandardMaterial3D = StandardMaterial3D.new()
    qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    qm.vertex_color_use_as_albedo = true
    qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    qm.billboard_keep_scale = true
    qm.albedo_texture = BloodTextures.soft_dot()
    qm.disable_fog = true
    quad.material = qm
    mist.mesh = quad
    host.add_child(mist)
    mist.global_position = Vector3(global_position.x, feet_y() + 0.5, global_position.z)
    mist.emitting = true
    get_tree().create_timer(1.5, false).timeout.connect(mist.queue_free)


func _on_poise_break(info: DamageInfo) -> void:
    shock.deactivate()
    _hide_ring()
    super._on_poise_break(info)


func _on_silenced() -> void:
    if state == &"wail_windup":
        _hide_ring()
        set_state(&"idle")


func set_state(next: StringName) -> void:
    if next != &"wail_windup" and _ring != null:
        _hide_ring()
    super.set_state(next)


func _on_died() -> void:
    shock.deactivate()
    _hide_ring()
    super._on_died()


func _on_death_fx() -> void:
    Audio.sfx(&"card_choir", 0.2, -6.0)


func _glow() -> Color:
    if state == &"wail_windup":
        return Color(0.7, 0.8, 1.0) * (0.3 + 0.6 * _t / wail_windup)
    if state == &"blink_out" or state == &"blink_in":
        return Color(0.7, 0.8, 1.0) * 0.8
    return Color.BLACK


# --- Animation --------------------------------------------------------------------------------

func _animate(delta: float) -> void:
    var raise_to: float = 0.0
    var limp_to: float = 0.0
    var split_to: float = 0.0
    match state:
        &"wail_windup":
            raise_to = clampf(_t / (wail_windup * 0.8), 0.0, 1.0)
            split_to = raise_to
        &"wail":
            raise_to = 1.3
            split_to = 1.4
        &"wail_recover", &"hitstun":
            limp_to = 1.0
    _raise = move_toward(_raise, raise_to, delta * (2.0 if raise_to > _raise else 3.0))
    _limp = move_toward(_limp, limp_to, delta * 2.5)
    _split = move_toward(_split, split_to, delta * (1.6 if split_to > _split else 2.5))
    var hover: float = 0.22 + 0.05 * sin(anim_t * 1.3) - 0.12 * _limp
    rig.shift(&"body", Vector3(0.0, hover, 0.0))
    rig.turn(&"body", Vector3(0.05 * sin(anim_t * 0.9) - 0.15 * _raise, 0.0, 0.04 * sin(anim_t * 0.7)))
    rig.turn(&"torso", Vector3(0.18 + 0.3 * _limp - 0.25 * _raise + 0.02 * sin(anim_t * 1.8), 0.0, 0.0))
    var ht: Vector3 = twitch(&"head", Vector3(0.3, 0.5, 0.6), 1.6, delta, 0.8)
    rig.turn(&"head", Vector3(0.12 + 0.6 * _limp - 0.55 * _raise + ht.x, ht.y, 0.7 * sin(anim_t * 0.31) + ht.z))
    var o: float = clampf(_split, 0.0, 1.4)
    if rig.has(&"split"):
        (rig.p(&"split") as Node3D).scale = Vector3(0.01 + 3.2 * o, 0.25 + 0.75 * minf(o, 1.0), 0.01 + o) if o > 0.02 else Vector3.ONE * 0.001
    rig.glow(&"glow_pale", 1.0 + 4.0 * o)
    for s: float in [1.0, -1.0]:
        var tag: String = "L" if s > 0.0 else "R"
        var sway: float = 0.08 * sin(anim_t * 0.8 + s)
        var ft: Vector3 = twitch(StringName("hand" + tag), Vector3(0.3, 0.2, 0.3), 1.2, delta)
        rig.turn(StringName("arm_%s_up" % tag), Vector3(sway - 0.5 * _raise, 0.0, s * (0.05 + 1.25 * _raise) - s * 0.1 * _limp))
        rig.turn(StringName("arm_%s_lo" % tag), Vector3(-0.25 - 0.6 * _raise + 0.15 * _limp, 0.0, 0.0))
        rig.turn(StringName("hand_%s" % tag), ft + Vector3(-0.3 * _raise, 0.0, s * 0.3 * _raise))
    # Blinking: folds into a thin pale streak and back out.
    var fold: float = 0.0
    if state == &"blink_out":
        fold = clampf(_t / blink_time, 0.0, 1.0)
    elif state == &"blink_in":
        fold = 1.0 - clampf(_t / blink_time, 0.0, 1.0)
    fold = fold * fold
    rig.scale = Vector3(1.0 - 0.94 * fold, 1.0 + 0.5 * fold, 1.0 - 0.94 * fold)
    rig.visible = fold < 0.97


func _animate_death(_delta: float) -> void:
    var k: float = clampf(death_t / 0.9, 0.0, 1.0)
    var e: float = k * (2.0 - k)
    rig.visible = true
    rig.scale = Vector3(1.0 + 0.4 * e, 1.0 - 0.86 * e, 1.0 + 0.4 * e)
    rig.shift(&"body", Vector3(0.0, 0.22 * (1.0 - e), 0.0))
    rig.turn(&"head", Vector3(0.9 * e, 0.0, 0.7 * e))
    if rig.has(&"split"):
        (rig.p(&"split") as Node3D).scale = Vector3(4.0, 1.0, 1.0) * (1.0 - k) + Vector3.ONE * 0.001
    rig.glow(&"glow_pale", 6.0 * (1.0 - k))
    rig.overlay(Color(0.6, 0.65, 0.8), 0.9 * (1.0 - k), 1.5, 0.3)

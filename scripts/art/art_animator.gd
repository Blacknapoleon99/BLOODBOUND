class_name ArtAnimator
extends Node
## Visual-only driver for a rigged ArtSwap model. It only reads gameplay state; nothing here
## changes movement, combat or timing.
##
## Fluid animation (an AnimationTree built in code):
##   locomotion  BlendSpace1D idle -> walk -> run on the body's real ground speed, with playback
##               sped up past the run clip's own speed so feet never ice-skate;
##   air         blends into "fall" while descending;
##   full        one-shot for whole-body actions (dodge, hit, jump, stand-still attacks);
##   upper       one-shot masked to spine/arms/head, so attacks, draws and casts play on the
##               upper body while the legs keep running.
## The Tripo preset clips are long (slash 6.6 s, dive 2.7 s), so each action plays only its
## busiest stretch (found once per clip from bone motion) time-scaled to the GAMEPLAY duration
## of the action: the swing lands with the hitbox and hands back as the attack ends.

## Reference ground speeds (m/s) of the locomotion clips on a 1.8 m humanoid.
const WALK_REF: float = 1.6
const RUN_REF: float = 5.5
## Seconds of source animation used for each kind of action (the busiest window of the clip).
const SOURCE_WINDOW: Dictionary = {&"attack": 0.75, &"dive": 0.7, &"hit": 0.55, &"jump": 0.6, &"cast": 0.9, &"draw": 0.0}
const FADE_IN: float = 0.06
const FADE_OUT: float = 0.12
## Bones (name suffixes) the upper-body mask lets through.
const UPPER_BONES: Array[String] = ["Spine", "Spine1", "Spine2", "Neck", "Head", "Shoulder", "Arm", "ForeArm", "Hand"]

var body: Node3D
var model: Node3D
var player: AnimationPlayer
var tree: AnimationTree
var steer_facing: bool = false
var move_clip: StringName = &"walk"
var weapon: Node
var _dead: bool = false
var _last_pos: Vector3
var _velocity: Vector3
var _speed_smoothed: float = 0.0
var _air: float = 0.0
var _state_move: bool = false
var _has_upper: bool = false
var _queued: Dictionary = {}  # an action to fire when the current one ends (draw -> swing)
var _queued_at: float = -1.0
var _clock: float = 0.0
var _loco_points: Array[float] = []
## Model height / 1.8 m: reference stride speeds scale with size (the 30 m Bishop).
var size_scale: float = 1.0
## Cached busiest-window start per Animation resource.
static var _window_cache: Dictionary = {}


static func attach(owner_body: Node3D, art: Node3D, steer: bool, moving: StringName, height: float = 1.8) -> ArtAnimator:
    var players: Array[Node] = art.find_children("*", "AnimationPlayer", true, false)
    if players.is_empty():
        return null
    var animator: ArtAnimator = ArtAnimator.new()
    animator.name = "ArtAnimator"
    animator.body = owner_body
    animator.model = art
    animator.player = players[0] as AnimationPlayer
    animator.steer_facing = steer
    animator.move_clip = moving
    animator.size_scale = maxf(0.3, height / 1.8)
    animator._last_pos = owner_body.global_position if owner_body.is_inside_tree() else owner_body.position
    for clip: StringName in animator.player.get_animation_list():
        var anim: Animation = animator.player.get_animation(clip)
        anim.loop_mode = Animation.LOOP_LINEAR if clip in [&"idle", &"walk", &"run", &"fall"] else Animation.LOOP_NONE
    art.add_child(animator)
    animator._build_tree()
    animator._connect_gameplay_signals()
    return animator


# --- Tree --------------------------------------------------------------------------------

func _build_tree() -> void:
    tree = AnimationTree.new()
    tree.name = "ArtAnimationTree"
    player.get_parent().add_child(tree)
    tree.anim_player = tree.get_path_to(player)
    tree.root_node = tree.get_path_to(player.get_node(player.root_node))
    var root: AnimationNodeBlendTree = AnimationNodeBlendTree.new()

    var loco: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
    loco.min_space = 0.0
    loco.max_space = RUN_REF * size_scale
    for entry: Array in [[&"idle", 0.0], [&"walk", WALK_REF * size_scale], [&"run", RUN_REF * size_scale]]:
        if player.has_animation(entry[0]) and (entry[0] != &"run" or move_clip == &"run"):
            var clip: AnimationNodeAnimation = AnimationNodeAnimation.new()
            clip.animation = entry[0]
            loco.add_blend_point(clip, entry[1], -1, entry[0])
            _loco_points.append(entry[1])
    if _loco_points.is_empty():  # no locomotion clips at all: hold the first clip
        var any: AnimationNodeAnimation = AnimationNodeAnimation.new()
        any.animation = player.get_animation_list()[0]
        loco.add_blend_point(any, 0.0, -1, &"hold")
        _loco_points.append(0.0)
    root.add_node(&"loco", loco)
    root.add_node(&"loco_speed", AnimationNodeTimeScale.new())
    root.connect_node(&"loco_speed", 0, &"loco")

    var fall: AnimationNodeAnimation = AnimationNodeAnimation.new()
    fall.animation = &"fall" if player.has_animation(&"fall") else _loco_anim_name(0)
    root.add_node(&"fall", fall)
    root.add_node(&"air", AnimationNodeBlend2.new())
    root.connect_node(&"air", 0, &"loco_speed")
    root.connect_node(&"air", 1, &"fall")

    for layer: StringName in [&"full", &"upper"]:
        var shot: AnimationNodeAnimation = AnimationNodeAnimation.new()
        shot.animation = player.get_animation_list()[0]
        shot.use_custom_timeline = true
        shot.loop_mode = Animation.LOOP_NONE
        root.add_node(StringName("%s_clip" % layer), shot)
        root.add_node(StringName("%s_speed" % layer), AnimationNodeTimeScale.new())
        root.connect_node(StringName("%s_speed" % layer), 0, StringName("%s_clip" % layer))
        var one: AnimationNodeOneShot = AnimationNodeOneShot.new()
        one.fadein_time = FADE_IN
        one.fadeout_time = FADE_OUT
        one.mix_mode = AnimationNodeOneShot.MIX_MODE_BLEND
        root.add_node(layer, one)
    root.connect_node(&"full", 0, &"air")
    root.connect_node(&"full", 1, &"full_speed")
    root.connect_node(&"upper", 0, &"full")
    root.connect_node(&"upper", 1, &"upper_speed")
    root.connect_node(&"output", 0, &"upper")
    _has_upper = _mask_upper_body(root.get_node(&"upper") as AnimationNodeOneShot)
    tree.tree_root = root
    tree.active = true


## Lets only spine/arm/head tracks through the upper one-shot. False if the rig has none.
func _mask_upper_body(one: AnimationNodeOneShot) -> bool:
    var paths: Array[NodePath] = []
    for clip: StringName in player.get_animation_list():
        var anim: Animation = player.get_animation(clip)
        for t in anim.get_track_count():
            var path: NodePath = anim.track_get_path(t)
            var bone: String = String(path.get_concatenated_subnames())
            for suffix: String in UPPER_BONES:
                if bone.ends_with(suffix) or bone.contains(suffix + "_") or (suffix == "Hand" and bone.contains("Hand")):
                    if not paths.has(path):
                        paths.append(path)
                    break
    if paths.is_empty():
        return false
    one.filter_enabled = true
    for path: NodePath in paths:
        one.set_filter_path(path, true)
    return true


func _loco_anim_name(i: int) -> StringName:
    var loco: AnimationNodeBlendSpace1D = (tree.tree_root as AnimationNodeBlendTree).get_node(&"loco") if tree and tree.tree_root else null
    if loco != null and i < loco.get_blend_point_count():
        return (loco.get_blend_point_node(i) as AnimationNodeAnimation).animation
    return player.get_animation_list()[0]


# --- Actions -------------------------------------------------------------------------------

## Plays `clip` as an action lasting `duration` seconds of game time (0 = the clip's natural
## pace over its window). `upper` keeps the legs on locomotion. Missing clips are ignored.
func act(clip: StringName, duration: float, kind: StringName, upper: bool) -> bool:
    if _dead or not player.has_animation(clip):
        return false
    var anim: Animation = player.get_animation(clip)
    var window: float = float(SOURCE_WINDOW.get(kind, 0.75))
    if window <= 0.0 or window > anim.length:
        window = anim.length
    var start: float = clampf(_busiest_start(anim, window), 0.0, maxf(0.0, anim.length - window))
    if kind == &"hit":
        start = 0.0  # reactions read best from their first frame
    var layer: StringName = &"upper" if upper and _has_upper else &"full"
    var root: AnimationNodeBlendTree = tree.tree_root as AnimationNodeBlendTree
    var shot: AnimationNodeAnimation = root.get_node(StringName("%s_clip" % layer)) as AnimationNodeAnimation
    shot.animation = clip
    shot.start_offset = start
    shot.timeline_length = window
    shot.stretch_time_scale = false
    var scale: float = window / duration if duration > 0.01 else 1.0
    tree.set("parameters/%s_speed/scale" % layer, clampf(scale, 0.4, 4.0))
    tree.set("parameters/%s/request" % layer, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
    return true


## Compatibility for ArtWeapon (sheathe) and simple callers: a natural-pace action.
func play_once(clip: StringName, speed: float = 1.0) -> bool:
    var kind: StringName = &"draw" if clip == &"draw" or clip == &"sheathe" else &"attack"
    var length: float = player.get_animation(clip).length if player.has_animation(clip) else 0.0
    return act(clip, length / maxf(speed, 0.01), kind, true)


## Start of the `window`-second stretch with the most bone rotation (cached per clip).
static func _busiest_start(anim: Animation, window: float) -> float:
    var key: String = "%d:%.2f" % [anim.get_instance_id(), window]
    if _window_cache.has(key):
        return _window_cache[key]
    var step: float = 1.0 / 30.0
    var samples: int = int(anim.length / step) + 1
    var activity: PackedFloat32Array = PackedFloat32Array()
    activity.resize(samples)
    for t in anim.get_track_count():
        if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
            continue
        var bone: String = String(anim.track_get_path(t).get_concatenated_subnames())
        if bone.begins_with("Cloth"):
            continue
        var prev: Quaternion = anim.rotation_track_interpolate(t, 0.0)
        for i in range(1, samples):
            var q: Quaternion = anim.rotation_track_interpolate(t, i * step)
            activity[i] += prev.angle_to(q)
            prev = q
    var span: int = maxi(1, int(window / step))
    var best: float = -1.0
    var best_i: int = 0
    var running: float = 0.0
    for i in samples:
        running += activity[i]
        if i >= span:
            running -= activity[i - span]
        if i >= span - 1 and running > best:
            best = running
            best_i = i - span + 1
    var start: float = best_i * step
    _window_cache[key] = start
    return start


# --- Gameplay hooks ---------------------------------------------------------------------------

func _connect_gameplay_signals() -> void:
    var melee: Object = body.get("melee") as Object
    if melee != null and melee.has_signal(&"attack_started"):
        _hook(melee, &"attack_started", _on_melee_attack)
    else:
        _hook(body, &"attack_started", _on_named_attack)  # the Bishop's attack names
    _hook(body, &"phase_changed", func(_phase: Variant = null) -> void: act(&"angry_01", 1.2, &"cast", false))
    _hook(body, &"dodge_started", _on_dodge)
    _hook(body, &"jumped", func() -> void: act(&"jump", 0.45, &"jump", false))
    _hook(body, &"hurt", func(_info: Variant = null) -> void: act(&"hit_to_body_01", 0.35, &"hit", true))
    _hook(body, &"died", _on_died)
    _hook(body, &"defeated", _on_died)
    _hook(body, &"state_changed", _on_state)


func _hook(source: Object, sig: StringName, callable: Callable) -> void:
    if source != null and source.has_signal(sig):
        source.connect(sig, callable)


## Melee (player and Plagued Soldier): the swing spans the attack's real startup+active+recovery.
func _on_melee_attack(data: Variant = null) -> void:
    var attack: AttackData = data as AttackData
    var melee: MeleeAttack = body.get("melee") as MeleeAttack
    var duration: float = 0.5
    var clip: StringName = _attack_clip()
    if attack != null:
        var speed: float = maxf(0.1, melee.speed_scale * melee.haste_scale) if melee else 1.0
        duration = (attack.startup + attack.active + attack.recovery) / speed
        if String(attack.id).contains("heavy") and player.has_animation(&"chop"):
            clip = &"chop"
    if weapon != null:
        weapon.call(&"note_attack")
        if not weapon.get(&"drawn"):
            if player.has_animation(&"draw"):
                var draw_time: float = 0.14
                weapon.call(&"begin_draw", draw_time * 0.6)
                act(&"draw", draw_time, &"draw", true)
                _queue(clip, maxf(0.15, duration - draw_time), draw_time)
                return
            weapon.call(&"begin_draw", 0.0)
    act(clip, duration, &"attack", _moving())


func _on_named_attack(id: Variant = null) -> void:
    var s: String = str(id).to_lower()
    var clip: StringName = _attack_clip()
    var kind: StringName = &"attack"
    if (s.contains("heavy") or s.contains("slam") or s.contains("sunder")) and player.has_animation(&"chop"):
        clip = &"chop"
    elif (s.contains("beam") or s.contains("rain") or s.contains("geyser") or s.contains("summon")) and player.has_animation(&"cast_a_spell"):
        clip = &"cast_a_spell"
        kind = &"cast"
    act(clip, 1.1, kind, false)


func _on_dodge(_dir: Variant = null) -> void:
    var duration: float = float(body.get("dodge_invulnerable_time")) if "dodge_invulnerable_time" in body else 0.35
    act(&"dive", maxf(0.3, duration + 0.06), &"dive", false)


func _queue(clip: StringName, duration: float, after: float) -> void:
    _queued = {"clip": clip, "duration": duration}
    _queued_at = _clock + after


## Enemy states (PlaguedSoldier/BoneArcher/CryptHound enums, CodeEnemy names): the attack clip
## starts on the wind-up so the swing reads as the telegraph; a charge runs.
func _on_state(state_name: String) -> void:
    var s: String = state_name.to_lower()
    _state_move = s.contains("charging")
    if s.contains("dead"):
        _on_died()
    elif s.contains("charge_windup"):
        act(&"angry_01", 0.8, &"cast", false)
    elif s.contains("hitstun") or s.contains("stagger"):
        act(&"hit_to_body_01", 0.4, &"hit", false)
    elif s.contains("aim"):
        act(&"shoot", 0.9, &"attack", true)
    elif s.contains("windup") or s.contains("crouch"):
        act(_attack_clip(), 0.9, &"attack", false)
    elif s.contains("attack") and body.get("melee") == null:
        act(_attack_clip(), 0.8, &"attack", false)


func _attack_clip() -> StringName:
    for clip: StringName in [&"slash", &"chop", &"attack"]:
        if player.has_animation(clip):
            return clip
    return &"slash"


func _on_died() -> void:
    if _dead:
        return
    _dead = true
    # Death is final: drop the tree and let the AnimationPlayer hold the defeat clip.
    tree.active = false
    if player.has_animation(&"defeat"):
        player.play(&"defeat", 0.15)


func _moving() -> bool:
    return Vector2(_velocity.x, _velocity.z).length() > 1.0


# --- Per frame --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
    if body == null or not is_instance_valid(body) or _dead:
        return
    _clock += delta
    var character: CharacterBody3D = body as CharacterBody3D
    if character != null:
        _velocity = character.velocity
    else:
        _velocity = (body.global_position - _last_pos) / maxf(delta, 0.0001)
        _last_pos = body.global_position
    # Facing: frame-rate independent ease toward the gameplay facing (no snapping).
    if steer_facing and body.has_method(&"get_facing_vector"):
        var f: Vector3 = body.call(&"get_facing_vector")
        if f.length_squared() > 0.0001:
            model.rotation.y = lerp_angle(model.rotation.y, atan2(f.x, f.z), 1.0 - exp(-20.0 * delta))
    if not _queued.is_empty() and _clock >= _queued_at:
        var next: Dictionary = _queued
        _queued = {}
        act(next["clip"], next["duration"], &"attack", _moving())
    # Locomotion: smoothed ground speed drives the blend; faster than the run clip speeds it up.
    var ground: float = Vector2(_velocity.x, _velocity.z).length()
    if _state_move:
        ground = maxf(ground, RUN_REF * size_scale)
    _speed_smoothed = lerpf(_speed_smoothed, ground, 1.0 - exp(-10.0 * delta))
    var top: float = _loco_points.max()
    tree.set("parameters/loco/blend_position", minf(_speed_smoothed, top) if top > 0.0 else 0.0)
    var over: float = _speed_smoothed / top if top > 0.0 else 1.0
    tree.set("parameters/loco_speed/scale", clampf(over, 1.0, 1.8) if _loco_points.size() > 1 else clampf(over, 0.25, 1.8))
    # Air: ease into the fall clip while descending.
    var falling: bool = character != null and not character.is_on_floor() and _velocity.y < -1.0
    _air = move_toward(_air, 1.0 if falling else 0.0, 6.0 * delta)
    tree.set("parameters/air/blend_amount", _air)

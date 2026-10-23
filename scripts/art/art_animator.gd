class_name ArtAnimator
extends Node
## Visual-only driver for a rigged ArtSwap model. It only reads gameplay state; nothing here
## changes movement, combat or timing.
##
## Fluid animation (an AnimationTree built in code):
##   locomotion  BlendSpace1D idle -> walk -> run on the body's real ground speed, with playback
##               sped up past the run clip's own speed so feet never ice-skate;
##   air         blends into "fall" while descending;
##   base        blends into a held/scrubbed "hold" clip for poses that are not locomotion or
##               air (the 3D hero's hang, climb, pull-up, slides, skids, knockback);
##   full        one-shot for whole-body actions (dodge, hit, jump, stand-still attacks);
##   upper       one-shot masked to spine/arms/head, so attacks, draws and casts play on the
##               upper body while the legs keep running.
## The full-3D hero (a PlatformerMotor) is driven ONLY by motor.anim_state() (DEC-051): every
## motor state names a pose, HERO_POSES maps it to locomotion, the air pose, or a held clip
## scrubbed by the move's own progress. Nothing guesses from raw velocity or is_on_floor(), so the
## pose can never disagree with the move. Other bodies keep the velocity-driven path.
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
## The 3D hero's poses (PlatformerMotor.anim_state "pose") -> [layer, clip, mode, value].
## layer: &"loco" (idle/walk/run blend on the motor's speed), &"air" (the fall loop), or &"hold"
## (one clip held or scrubbed). Hold modes: &"frame" (fixed fraction of the clip), &"travel"
## (metres moved, one cycle per HOLD_STRIDE), &"span" (the jump clip's takeoff by 0..1
## progress), &"peak" (the end of that takeoff), &"time" (seconds in the state).
## Placeholders until real clips (the rig has no hang/climb/slide clips): a real clip replaces a
## row here without touching the motor.
const HERO_POSES: Dictionary = {
    &"idle": [&"loco"], &"walk": [&"loco"], &"push": [&"loco"], &"land": [&"loco"], &"crouch": [&"loco"],
    &"attack": [&"loco"], &"dash": [&"loco"],
    &"jump": [&"air"], &"fall": [&"air"], &"attack_air": [&"air"], &"dash_air": [&"air"], &"triple": [&"air"], &"backflip": [&"air"], &"side_flip": [&"air"],
    &"long_jump": [&"air"], &"wall_kick": [&"air"], &"pound_spin": [&"air"], &"pound_fall": [&"air"], &"bonk": [&"air"],
    &"brake": [&"hold", &"idle", &"frame", 0.0], &"skid": [&"hold", &"idle", &"frame", 0.0],
    &"slide": [&"hold", &"idle", &"frame", 0.0], &"slope_slide": [&"hold", &"idle", &"frame", 0.0],
    &"pound_land": [&"hold", &"idle", &"frame", 0.0], &"wall_slide": [&"hold", &"fall", &"frame", 0.0],
    &"hang": [&"hold", &"jump", &"peak"], &"pull_up": [&"hold", &"jump", &"span"], &"climb_leap": [&"hold", &"jump", &"span"],
    &"shimmy": [&"hold", &"walk", &"travel"], &"climb": [&"hold", &"walk", &"travel"],
    &"knockback": [&"hold", &"hit_to_body_01", &"time"],
}
## The hero's full moveset (DEC-059): Kimodo text-to-motion clips retargeted onto the hero
## (assets/models/player/hero_kimodo_anims.res, built by tools/kimodo). Used instead of the
## placeholder rows above whenever the model has every clip named here.
## Rows: [&"loco"] | [&"air"] | [&"hold", clip, mode, ...] with modes (seconds of the clip):
##   &"play" from, to, rate     plays from `from` at `rate` x the state's time, holding at `to`;
##   &"loop" from, to, rate     the same, wrapping inside [from, to];
##   &"stride" from, to, metres one [from, to] cycle per `metres` moved (hands keep pace);
##   &"progress" from, to       the move's own 0..1 progress (pull-up, climb leap);
##   &"at" t                    one held frame.
const HERO_MOVESET: Dictionary = {
    &"idle": [&"loco"], &"walk": [&"loco"], &"push": [&"loco"], &"attack": [&"loco"], &"dash": [&"loco"],
    &"fall": [&"air"], &"attack_air": [&"air"], &"dash_air": [&"air"],
    &"crouch": [&"hold", &"crouch", &"loop", 0.3, 3.0, 1.0],
    &"land": [&"hold", &"land_hard", &"play", 0.1, 0.4, 1.2],
    &"jump": [&"hold", &"air_jump", &"play", 0.43, 0.95, 1.4],
    &"triple": [&"hold", &"front_flip", &"play", 0.4, 1.7, 1.9],
    &"backflip": [&"hold", &"backflip", &"play", 0.35, 1.6, 1.8],
    &"side_flip": [&"hold", &"side_flip", &"play", 0.55, 1.9, 1.9],
    &"long_jump": [&"hold", &"long_jump", &"play", 0.5, 1.25, 1.0],
    &"wall_kick": [&"hold", &"wall_kick", &"play", 0.1, 1.2, 1.6],
    &"pound_spin": [&"hold", &"front_flip", &"play", 0.75, 1.35, 2.1],
    &"pound_fall": [&"hold", &"air_jump", &"at", 0.75],
    &"pound_land": [&"hold", &"ground_pound", &"play", 0.4, 0.62, 1.0],
    &"bonk": [&"hold", &"knockback", &"play", 0.25, 1.3, 1.5],
    &"brake": [&"hold", &"skid", &"play", 0.3, 1.2, 1.4],
    &"skid": [&"hold", &"skid", &"play", 0.3, 1.2, 1.4],
    &"slide": [&"hold", &"slide", &"loop", 0.3, 2.0, 1.0],
    &"slope_slide": [&"hold", &"slide", &"loop", 0.3, 2.0, 1.0],
    &"wall_slide": [&"hold", &"wall_slide", &"play", 0.3, 1.0, 1.0],
    &"hang": [&"hold", &"ledge_hang", &"loop", 0.0, 3.3, 1.0],
    &"shimmy": [&"hold", &"shimmy", &"stride", 0.0, 3.3, 2.0],
    &"pull_up": [&"hold", &"pull_up", &"progress", 0.2, 2.2],
    &"climb": [&"hold", &"climb", &"stride", 0.0, 3.3, 3.0],
    &"climb_leap": [&"hold", &"air_jump", &"progress", 0.43, 0.95],
    &"knockback": [&"hold", &"knockback", &"play", 0.0, 1.5, 1.2],
}
## Poses whose clip turns the whole body over (the procedural flip is skipped for them).
const CLIP_FLIPS: Array[StringName] = [&"triple", &"backflip", &"side_flip", &"pound_spin"]
## Each step of the hero's combo swings its own whole clip (DEC-059).
const ATTACK_CLIPS: Dictionary = {
    &"player_light": &"slash_1", &"player_light_2": &"slash_2", &"player_light_finisher": &"slash_3",
    &"player_heavy": &"heavy_overhead",
}
## Attack playback (clips with "strike"/"motion_start"/"motion_end" metadata): the wind-up plays
## over the attack's STARTUP, the clip's contact (the sword hand's fastest frame, +-
## STRIKE_HALF seconds) over ACTIVE, and the follow-through over RECOVERY plus a visual-only
## FOLLOW_TAIL that any next action interrupts. No segment plays faster than MAX_SWING_RATE: a
## wind-up too long for a fast startup starts part-way in instead of being squeezed.
const STRIKE_HALF: float = 0.06
const FOLLOW_TAIL: float = 0.25
const MAX_SWING_RATE: float = 4.0
const ATTACK_FADE_OUT: float = 0.18
## Boost sprint over the run (m/s at which it starts and is fully in): PlatformerMotor's 6 m/s
## run to its 7.25 m/s sprint (DEC-060).
const SPRINT_FROM: float = 6.3
const SPRINT_FULL: float = 7.2
## A whole-body action left behind by the motor state that started it fades out this fast.
const ABANDON_FADE: float = 0.08
## Clips that loop on their own (locomotion and stance).
const LOOP_CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"fall", &"combat_idle", &"sprint"]
## Seconds both held-clip slots cross-fade when the held clip changes.
const HOLD_SWAP: float = 0.1
## Metres of shimmy/climb per walk-clip cycle (hands and feet keep pace with the body).
const HOLD_STRIDE: float = 1.4
## Locomotion playback may speed up this far past the run clip (feet planted at any speed).
const LOCO_MAX_RATE: float = 3.0

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
var _airtime: float = 0.0
## The model's rest transform from ArtSwap (scale and feet offset); poses are built on it.
var _base_scale: Vector3 = Vector3.ONE
var _base_origin: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _squash: float = 1.0
var _state_move: bool = false
var _has_upper: bool = false
var _queued: Dictionary = {}  # an action to fire when the current one ends (draw -> swing)
var _queued_at: float = -1.0
var _clock: float = 0.0
var _loco_points: Array[float] = []
## Model height / 1.8 m: reference stride speeds scale with size (the 30 m Bishop).
var size_scale: float = 1.0
## The 3D hero: the pose being played (from PlatformerMotor.anim_state) and the held clip's
## position in seconds (tests and debugging read these).
var pose: StringName = &""
var hold_time: float = 0.0
var _hold: float = 0.0
var _hold_clip: StringName = &""
var _lean_pitch: float = 0.0
var _lean_roll: float = 0.0
## The moveset table in use (HERO_MOVESET when the model has its clips, else HERO_POSES).
var poses: Dictionary = HERO_POSES
var real_moveset: bool = false
## Held-clip slots A/B (cross-faded when the clip changes) and the active one.
var _slot: int = 0
var _slot_clip: Array[StringName] = [&"", &""]
var _ab: float = 0.0
var _stance: float = 0.0
var _boost: float = 0.0
var _sprint_ref: float = 4.4
## The attack being played by plan (see attack_plan) and its game time; tests read
## action_src_time (seconds into the clip) to check the contact lands in ACTIVE.
var _plan: Dictionary = {}
var _plan_t: float = 0.0
var action_src_time: float = -1.0
## The 3D hero: the motor state (PlatformerMotor.State) that owns the whole-body one-shot now
## playing (a standing swing: ATTACK; the dash roll: DASH), or -1.
var full_owner: int = -1
## Cached busiest-window start per Animation resource.
static var _window_cache: Dictionary = {}
## Cached [start, length] spans found from the hips' height (see _hips_span).
static var _span_cache: Dictionary = {}


static func attach(owner_body: Node3D, art: Node3D, steer: bool, moving: StringName, height: float = 1.8, extra: AnimationLibrary = null) -> ArtAnimator:
    var players: Array[Node] = art.find_children("*", "AnimationPlayer", true, false)
    if players.is_empty():
        return null
    if extra != null:  # retargeted clips (the hero's moveset) join the model's own library
        var own: AnimationLibrary = (players[0] as AnimationPlayer).get_animation_library(&"")
        for clip: StringName in extra.get_animation_list():
            if not own.has_animation(clip):
                own.add_animation(clip, extra.get_animation(clip))
    var animator: ArtAnimator = ArtAnimator.new()
    animator.name = "ArtAnimator"
    animator.body = owner_body
    animator.model = art
    animator.player = players[0] as AnimationPlayer
    animator.steer_facing = steer
    animator.move_clip = moving
    animator.size_scale = maxf(0.3, height / 1.8)
    animator._base_scale = art.scale
    animator._base_origin = art.position
    animator._yaw = art.rotation.y
    animator._last_pos = owner_body.global_position if owner_body.is_inside_tree() else owner_body.position
    for clip: StringName in animator.player.get_animation_list():
        var anim: Animation = animator.player.get_animation(clip)
        anim.loop_mode = Animation.LOOP_LINEAR if clip in LOOP_CLIPS else Animation.LOOP_NONE
    animator.real_moveset = animator._has_moveset()
    animator.poses = HERO_MOVESET if animator.real_moveset else HERO_POSES
    if animator.player.has_animation(&"sprint"):
        animator._sprint_ref = float(animator.player.get_animation(&"sprint").get_meta(&"treadmill_speed", 2.45)) * height
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
    # Combat stance over standing still (sword drawn), and the boost sprint over the run.
    var ground: StringName = &"loco_speed"
    for extra: Array in [[&"stance", &"combat_idle"], [&"boost", &"sprint"]]:
        if not player.has_animation(extra[1]):
            continue
        var clip_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
        clip_node.animation = extra[1]
        root.add_node(StringName("%s_clip" % extra[0]), clip_node)
        root.add_node(StringName("%s_speed" % extra[0]), AnimationNodeTimeScale.new())
        root.connect_node(StringName("%s_speed" % extra[0]), 0, StringName("%s_clip" % extra[0]))
        root.add_node(extra[0], AnimationNodeBlend2.new())
        root.connect_node(extra[0], 0, ground)
        root.connect_node(extra[0], 1, StringName("%s_speed" % extra[0]))
        ground = extra[0]

    var fall: AnimationNodeAnimation = AnimationNodeAnimation.new()
    fall.animation = &"fall" if player.has_animation(&"fall") else _loco_anim_name(0)
    if player.has_animation(&"fall"):
        # Loop only the airborne stretch: the clip ends collapsing onto the ground, which looped
        # in mid-air read as the character dropping dead or getting stuck.
        var span: Array = _hips_span(player.get_animation(&"fall"), &"fall")
        if not span.is_empty():
            fall.use_custom_timeline = true
            fall.start_offset = span[0]
            fall.timeline_length = span[1]
            fall.stretch_time_scale = false
            fall.loop_mode = Animation.LOOP_LINEAR
    root.add_node(&"fall", fall)
    root.add_node(&"air", AnimationNodeBlend2.new())
    root.connect_node(&"air", 0, ground)
    root.connect_node(&"air", 1, &"fall")
    # Held / scrubbed poses: two slots (A/B, cross-faded when the held clip changes), each a clip
    # frozen (time scale 0) and placed by a seek every frame.
    for slot: String in ["hold_a", "hold_b"]:
        var hold: AnimationNodeAnimation = AnimationNodeAnimation.new()
        hold.animation = player.get_animation_list()[0]
        root.add_node(StringName(slot + "_clip"), hold)
        root.add_node(StringName(slot + "_scale"), AnimationNodeTimeScale.new())
        root.connect_node(StringName(slot + "_scale"), 0, StringName(slot + "_clip"))
        root.add_node(StringName(slot + "_seek"), AnimationNodeTimeSeek.new())
        root.connect_node(StringName(slot + "_seek"), 0, StringName(slot + "_scale"))
    root.add_node(&"hold_ab", AnimationNodeBlend2.new())
    root.connect_node(&"hold_ab", 0, &"hold_a_seek")
    root.connect_node(&"hold_ab", 1, &"hold_b_seek")
    root.add_node(&"base", AnimationNodeBlend2.new())
    root.connect_node(&"base", 0, &"air")
    root.connect_node(&"base", 1, &"hold_ab")

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
    root.connect_node(&"full", 0, &"base")
    root.connect_node(&"full", 1, &"full_speed")
    root.connect_node(&"upper", 0, &"full")
    root.connect_node(&"upper", 1, &"upper_speed")
    root.connect_node(&"output", 0, &"upper")
    _has_upper = _mask_upper_body(root.get_node(&"upper") as AnimationNodeOneShot)
    tree.tree_root = root
    tree.active = true
    tree.set("parameters/hold_a_scale/scale", 0.0)
    tree.set("parameters/hold_b_scale/scale", 0.0)
    tree.set("parameters/hold_ab/blend_amount", 0.0)
    tree.set("parameters/base/blend_amount", 0.0)


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
    if kind == &"roll":  # the whole roll: from the dip to back on the feet
        start = 0.1
        window = anim.length - 0.02 - start  # through to back on the feet
    if kind == &"jump" or kind == &"dive":
        # The takeoff of one hop / the leap of the dive, never the landing or lying on the floor:
        # the air pose and locomotion take over from there, driven by the real jump.
        var span: Array = _hips_span(anim, kind)
        if not span.is_empty():
            start = span[0]
            window = span[1]
    var layer: StringName = &"upper" if upper and _has_upper else &"full"
    var root: AnimationNodeBlendTree = tree.tree_root as AnimationNodeBlendTree
    if not _plan.is_empty() and _plan["layer"] == layer:
        _plan = {}  # a new action on the same layer interrupts the swing
        action_src_time = -1.0
    if layer == &"full":
        full_owner = -1
    (root.get_node(layer) as AnimationNodeOneShot).fadeout_time = FADE_OUT
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


## The whole swing of `clip` laid onto an attack's phases (game seconds already divided by the
## weapon speed): {"clip", "start", "end", "contact", "segments": [[game seconds, src from,
## src to] x3]} for startup / active / recovery+tail. Empty if the clip has no strike metadata.
func attack_plan(clip: StringName, startup: float, active: float, recovery: float) -> Dictionary:
    if not player.has_animation(clip):
        return {}
    var anim: Animation = player.get_animation(clip)
    if not anim.has_meta(&"strike"):
        return {}
    var c: float = float(anim.get_meta(&"strike"))
    var hit_from: float = maxf(0.0, c - STRIKE_HALF)
    var hit_to: float = minf(anim.length, c + STRIKE_HALF)
    var start: float = minf(float(anim.get_meta(&"motion_start", 0.0)), hit_from)
    start = maxf(start, hit_from - maxf(startup, 0.01) * MAX_SWING_RATE)  # start part-way in if needed
    var follow: float = recovery + FOLLOW_TAIL
    var end: float = clampf(float(anim.get_meta(&"motion_end", anim.length)) + 0.1, hit_to, anim.length)
    end = minf(end, hit_to + follow * MAX_SWING_RATE)
    return {"clip": clip, "start": start, "end": end, "contact": c,
        "segments": [[maxf(startup, 0.001), start, hit_from], [maxf(active, 0.001), hit_from, hit_to], [follow, hit_to, end]]}


## Seconds into the clip that `plan` shows `t` game seconds after the attack started.
static func plan_time(plan: Dictionary, t: float) -> float:
    var left: float = t
    for seg: Array in plan["segments"]:
        if left <= seg[0]:
            return lerpf(seg[1], seg[2], left / seg[0])
        left -= seg[0]
    return float(plan["end"])


## Plays an attack plan on the full or upper layer; _physics_process steps each segment's rate.
func act_plan(plan: Dictionary, upper: bool) -> void:
    var layer: StringName = &"upper" if upper and _has_upper else &"full"
    var root: AnimationNodeBlendTree = tree.tree_root as AnimationNodeBlendTree
    var shot: AnimationNodeAnimation = root.get_node(StringName("%s_clip" % layer)) as AnimationNodeAnimation
    shot.animation = plan["clip"]
    shot.start_offset = plan["start"]
    shot.timeline_length = float(plan["end"]) - float(plan["start"])
    shot.stretch_time_scale = false
    var one: AnimationNodeOneShot = root.get_node(layer) as AnimationNodeOneShot
    one.fadeout_time = ATTACK_FADE_OUT
    _plan = plan.duplicate()
    _plan["layer"] = layer
    _plan_t = 0.0
    if layer == &"full":
        full_owner = PlatformerMotor.State.ATTACK if _hero_motor() != null else -1
    action_src_time = float(plan["start"])
    _step_plan(0.0)
    tree.set("parameters/%s/request" % layer, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _step_plan(delta: float) -> void:
    if _plan.is_empty():
        return
    _plan_t += delta
    action_src_time = plan_time(_plan, _plan_t)
    var left: float = _plan_t
    var rate: float = 1.0
    for seg: Array in _plan["segments"]:
        rate = (float(seg[2]) - float(seg[1])) / float(seg[0])
        if left < seg[0]:
            break
        left -= seg[0]
    tree.set("parameters/%s_speed/scale" % _plan["layer"], clampf(rate, 0.05, MAX_SWING_RATE))
    if _plan_t > _plan_length():
        _plan = {}
        action_src_time = -1.0


func _plan_length() -> float:
    var total: float = 0.0
    for seg: Array in _plan["segments"]:
        total += float(seg[0])
    return total


## True when the model carries every clip the hero moveset (and its combo) needs.
func _has_moveset() -> bool:
    for row: Array in HERO_MOVESET.values():
        if row.size() > 1 and not player.has_animation(row[1]):
            return false
    for clip: StringName in ATTACK_CLIPS.values():
        if not player.has_animation(clip):
            return false
    return true


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


## [start, length] of a phase of `anim` read from the hips' height (cached), or [] if the rig
## has no hips track:
## - &"fall": from the start until the hips drop below 90% of their height (the clip collapsing
##   onto the ground);
## - &"jump": one hop's takeoff, from the first low point to the next high point;
## - &"dive": from the high point before the lowest point to halfway down (the leap, not the
##   faceplant).
static func _hips_span(anim: Animation, phase: StringName) -> Array:
    var key: String = "%d:%s" % [anim.get_instance_id(), phase]
    if _span_cache.has(key):
        return _span_cache[key]
    var track: int = -1
    for t in anim.get_track_count():
        if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and String(anim.track_get_path(t)).ends_with("Hips"):
            track = t
            break
    var span: Array = []
    if track >= 0:
        var step: float = 1.0 / 30.0
        var ys: PackedFloat32Array = PackedFloat32Array()
        var n: int = int(anim.length / step) + 1
        for i in n:
            ys.append(anim.position_track_interpolate(track, i * step).y)
        match phase:
            &"fall":
                var end: int = n - 1
                for i in n:
                    if ys[i] < ys[0] * 0.9:
                        end = i
                        break
                if end > 6:
                    span = [0.0, (end - 3) * step]
            &"jump":
                var low: int = 0
                while low + 1 < n and ys[low + 1] >= ys[low]:  # skip a first rise
                    low += 1
                while low + 1 < n and ys[low + 1] <= ys[low]:  # down into the crouch
                    low += 1
                var high: int = low
                while high + 1 < n and ys[high + 1] >= ys[high]:  # up to the peak of the hop
                    high += 1
                if high > low:
                    var from: int = maxi(0, low - 3)
                    span = [from * step, (high - from) * step]
            &"dive":
                var lowest: int = 0
                for i in n:
                    if ys[i] < ys[lowest]:
                        lowest = i
                var peak: int = lowest
                while peak > 0 and ys[peak - 1] >= ys[peak]:
                    peak -= 1
                var halfway: int = peak
                while halfway < lowest and ys[halfway] > (ys[peak] + ys[lowest]) * 0.5:
                    halfway += 1
                if halfway > peak:
                    var from2: int = maxi(0, peak - 6)
                    span = [from2 * step, (halfway - from2) * step]
    _span_cache[key] = span
    return span


# --- Gameplay hooks ---------------------------------------------------------------------------

func _connect_gameplay_signals() -> void:
    var melee: Object = body.get("melee") as Object
    if melee != null and melee.has_signal(&"attack_started"):
        _hook(melee, &"attack_started", _on_melee_attack)
    else:
        _hook(body, &"attack_started", _on_named_attack)  # the Bishop's attack names
    _hook(body, &"phase_changed", func(_phase: Variant = null) -> void: act(&"angry_01", 1.2, &"cast", false))
    _hook(body, &"dodge_started", _on_dodge)
    _hook(body, &"jumped", _on_jumped)
    _hook(body, &"hurt", func(_info: Variant = null) -> void: act(&"hit_to_body_01", 0.35, &"hit", true))
    _hook(body, &"died", _on_died)
    _hook(body, &"defeated", _on_died)
    _hook(body, &"state_changed", _on_state)


## The takeoff clip, only for plain jumps: flips, long jumps and wall kicks are procedural poses
## and a full-body takeoff would fight them.
func _on_jumped() -> void:
    var motor: PlatformerMotor = _hero_motor()
    if motor != null and (real_moveset or motor.jump_kind not in [PlatformerMotor.Jump.SINGLE, PlatformerMotor.Jump.DOUBLE]):
        return  # the real moveset's jump row plays the takeoff from the motor state
    act(&"jump", 0.22, &"jump", false)  # the takeoff only


func _hook(source: Object, sig: StringName, callable: Callable) -> void:
    if source != null and source.has_signal(sig):
        source.connect(sig, callable)


## Melee (player and Plagued Soldier): the swing spans the attack's real startup+active+recovery.
func _on_melee_attack(data: Variant = null) -> void:
    var attack: AttackData = data as AttackData
    var melee: MeleeAttack = body.get("melee") as MeleeAttack
    var duration: float = 0.5
    var clip: StringName = _attack_clip()
    if attack != null and ATTACK_CLIPS.has(attack.id) and player.has_animation(ATTACK_CLIPS[attack.id]):
        # The hero's moveset: the whole swing, its contact on the attack's ACTIVE window.
        var rate: float = maxf(0.1, melee.speed_scale * melee.haste_scale) if melee else 1.0
        var plan: Dictionary = attack_plan(ATTACK_CLIPS[attack.id], attack.startup / rate, attack.active / rate, attack.recovery / rate)
        if not plan.is_empty():
            if weapon != null:
                weapon.call(&"note_attack")
                if not weapon.get(&"drawn"):
                    weapon.call(&"begin_draw", 0.0)  # the wind-up itself brings the sword round
            act_plan(plan, _moving() or not _grounded())
            return
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
    if real_moveset and player.has_animation(&"roll"):
        act(&"roll", maxf(0.3, duration + 0.14), &"roll", false)  # a whole forward roll
        if _hero_motor() != null:
            full_owner = PlatformerMotor.State.DASH
        return
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
    if Vector2(_velocity.x, _velocity.z).length() > 1.0:
        return true
    # The 3D hero swinging with the stick held walks through the swing: upper body only, so the
    # legs keep walking instead of standing in the swing while the body moves (DEC-060).
    var wish: Variant = body.get("_wish_3d") if _hero_motor() != null else null
    return wish is Vector2 and (wish as Vector2).length() > 0.2


func _grounded() -> bool:
    var character: CharacterBody3D = body as CharacterBody3D
    return character == null or character.is_on_floor()


# --- Procedural moveset poses (placeholder until real clips) ----------------------------------

## The 3D hero's motor, or null (side view, enemies, the Bishop).
func _hero_motor() -> PlatformerMotor:
    if body == null or body.get("view_camera") == null:
        return null
    return body.get("motor") as PlatformerMotor


## Builds the model's transform from the facing yaw plus the PlatformerMotor state: the triple
## jump and ground pound flip forward, the backflip flips back, the side flip rolls, the long jump
## dives forward, the skid, brake and slides lean back, the crouch squashes, a landing dips, the
## run leans into its speed and rolls into turns. Rotations pivot at the body's centre (the
## player's origin), squash at the feet.
func _apply_pose(delta: float) -> void:
    var pitch: float = 0.0  # + leans/flips forward
    var roll: float = 0.0
    var squash: float = 1.0
    var lean_pitch: float = 0.0
    var lean_roll: float = 0.0
    var motor: PlatformerMotor = _hero_motor()
    if motor != null and real_moveset:
        # Real clips carry the flips, slides, hangs and climbs; only the run lean, the long
        # jump's dive and a small landing give stay procedural.
        var t2: float = motor.state_time
        match motor.state:
            PlatformerMotor.State.AIR:
                if motor.jump_kind == PlatformerMotor.Jump.LONG:
                    pitch = deg_to_rad(45.0) * smoothstep(0.0, 0.15, t2)
            PlatformerMotor.State.GROUND, PlatformerMotor.State.DECEL:
                var run: float = maxf(0.0, motor.forward_speed)
                lean_pitch = deg_to_rad(8.0) * clampf(run / PlatformerMotor.RUN_SPEED, 0.0, 1.5)
                lean_roll = clampf(-motor.turn_speed * run * 0.02, -deg_to_rad(25.0), deg_to_rad(25.0))
            PlatformerMotor.State.LAND:
                squash = lerpf(0.93, 1.0, smoothstep(0.0, 0.13, t2))
    elif motor != null:
        var t: float = motor.state_time
        match motor.state:
            PlatformerMotor.State.AIR:
                match motor.jump_kind:
                    PlatformerMotor.Jump.TRIPLE:
                        pitch = TAU * smoothstep(0.0, 0.55, t)
                    PlatformerMotor.Jump.BACKFLIP:
                        pitch = -TAU * smoothstep(0.0, 0.6, t)
                    PlatformerMotor.Jump.SIDE_FLIP:
                        roll = TAU * smoothstep(0.0, 0.5, t)
                    PlatformerMotor.Jump.LONG:
                        pitch = deg_to_rad(55.0) * smoothstep(0.0, 0.12, t)
                    PlatformerMotor.Jump.WALL_KICK:
                        pitch = -deg_to_rad(15.0) * (1.0 - smoothstep(0.0, 0.3, t))
            PlatformerMotor.State.GROUND, PlatformerMotor.State.DECEL:
                # Run lean (speed) and turn roll (turn rate x speed), eased below.
                var speed: float = maxf(0.0, motor.forward_speed)
                lean_pitch = deg_to_rad(10.0) * clampf(speed / PlatformerMotor.RUN_SPEED, 0.0, 1.5)
                lean_roll = clampf(-motor.turn_speed * speed * 0.02, -deg_to_rad(30.0), deg_to_rad(30.0))
            PlatformerMotor.State.LAND:
                squash = lerpf(0.82, 1.0, smoothstep(0.0, 0.13, t))
            PlatformerMotor.State.SKID, PlatformerMotor.State.BRAKE:
                pitch = -deg_to_rad(22.0)
            PlatformerMotor.State.SLIDE:
                pitch = -deg_to_rad(35.0)
                squash = 0.75
            PlatformerMotor.State.SLOPE_SLIDE:
                pitch = -deg_to_rad(30.0)
                squash = 0.85
            PlatformerMotor.State.CROUCH:
                squash = 0.68
            PlatformerMotor.State.WALL_SLIDE:
                pitch = -deg_to_rad(12.0)
            PlatformerMotor.State.HANG, PlatformerMotor.State.PULL_UP:
                pitch = deg_to_rad(8.0)
            PlatformerMotor.State.CLIMB:
                # Hand over hand: a sway that follows how far you have climbed (motor progress).
                pitch = deg_to_rad(6.0)
                roll = sin(motor.anim_travel / HOLD_STRIDE * TAU) * deg_to_rad(7.0)
            PlatformerMotor.State.CLIMB_LEAP:
                pitch = deg_to_rad(10.0)
                squash = 1.05
            PlatformerMotor.State.POUND_SPIN:
                pitch = TAU * smoothstep(0.0, PlatformerMotor.POUND_SPIN_TIME, t)
                squash = 0.85
            PlatformerMotor.State.POUND_FALL:
                squash = 0.8
            PlatformerMotor.State.POUND_LAND:
                squash = lerpf(0.6, 1.0, smoothstep(0.0, PlatformerMotor.POUND_LAND_TIME, t))
            PlatformerMotor.State.KNOCKBACK:
                pitch = -deg_to_rad(10.0)
            PlatformerMotor.State.BONK:
                pitch = -deg_to_rad(20.0)
    # The run lean eases (~170 deg/s) and is zero outside running.
    var ease_step: float = deg_to_rad(170.0) * delta
    _lean_pitch = move_toward(_lean_pitch, lean_pitch, ease_step)
    _lean_roll = move_toward(_lean_roll, lean_roll, ease_step)
    pitch += _lean_pitch
    roll += _lean_roll
    _squash = lerpf(_squash, squash, 1.0 - exp(-18.0 * delta))
    var turn: Basis = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
    var pivot: Vector3 = Vector3.ZERO  # the body's centre in the visual root's space
    var origin: Vector3 = pivot + turn * (_base_origin - pivot)
    model.transform = Transform3D(turn * Basis.from_scale(Vector3(_base_scale.x, _base_scale.y * _squash, _base_scale.z)), origin)


func character_velocity() -> Vector3:
    var character: CharacterBody3D = body as CharacterBody3D
    return character.velocity if character != null else Vector3.ZERO


## The 3D hero: one pose from the motor picks the layer (locomotion / air / held clip), the
## locomotion speed and the held clip's position. No velocity or floor guessing.
func _drive_hero(motor: PlatformerMotor, delta: float) -> void:
    _settle_actions(motor)
    var a: Dictionary = motor.anim_state()
    pose = a["pose"]
    var row: Array = poses.get(pose, [&"loco"])
    var layer: StringName = row[0]
    var speed: float = float(a["speed"]) if layer == &"loco" else 0.0
    _speed_smoothed = lerpf(_speed_smoothed, speed, 1.0 - exp(-20.0 * delta))
    var top: float = _loco_points.max()
    tree.set("parameters/loco/blend_position", minf(_speed_smoothed, top) if top > 0.0 else 0.0)
    var over: float = _speed_smoothed / top if top > 0.0 else 1.0
    tree.set("parameters/loco_speed/scale", clampf(over, 1.0, LOCO_MAX_RATE) if _loco_points.size() > 1 else clampf(over, 0.25, LOCO_MAX_RATE))
    _drive_stance(_speed_smoothed, delta)
    if layer == &"hold":
        if real_moveset:
            _set_slot(row, float(a["progress"]), float(a["time"]))
        else:
            _set_hold(row, float(a["progress"]))
    _air = move_toward(_air, 1.0 if layer == &"air" else 0.0, (7.0 if layer == &"air" else 10.0) * delta)
    _hold = move_toward(_hold, 1.0 if layer == &"hold" else 0.0, 12.0 * delta)
    _ab = move_toward(_ab, float(_slot), delta / HOLD_SWAP)
    tree.set("parameters/hold_ab/blend_amount", _ab)
    tree.set("parameters/air/blend_amount", _air)
    tree.set("parameters/base/blend_amount", _hold)


## A whole-body one-shot belongs to the motor state that started it (a standing swing to ATTACK,
## the roll to DASH). Once the motor has left that state and the hero moves, leaves the ground or
## does anything but stand, the one-shot fades out at once: legs frozen in a swing's
## follow-through while the body runs off was the "stuck in an animation and sliding" bug
## (DEC-060). Standing still, the follow-through tail plays out; a roll may finish running out of
## the dash.
func _settle_actions(motor: PlatformerMotor) -> void:
    if full_owner < 0:
        return
    if not bool(tree.get("parameters/full/active")):
        if int(tree.get("parameters/full/request")) == AnimationNodeOneShot.ONE_SHOT_REQUEST_NONE:
            full_owner = -1  # finished (a request still pending has not started yet)
        return
    if motor.state == full_owner:
        return
    var keep: bool = motor.state in [PlatformerMotor.State.GROUND, PlatformerMotor.State.LAND]             and absf(motor.forward_speed) < 0.5 and Vector2(_velocity.x, _velocity.z).length() < 0.5
    if full_owner == PlatformerMotor.State.DASH:
        # The roll reads as motion: it may finish while the dash runs or brakes out on the ground,
        # but a jump, a fall, a swing or a hit takes over at once.
        keep = motor.state in [PlatformerMotor.State.GROUND, PlatformerMotor.State.DECEL, PlatformerMotor.State.BRAKE,
                PlatformerMotor.State.LAND] and _grounded()
    if keep:
        return
    var root: AnimationNodeBlendTree = tree.tree_root as AnimationNodeBlendTree
    (root.get_node(&"full") as AnimationNodeOneShot).fadeout_time = ABANDON_FADE
    tree.set("parameters/full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
    if not _plan.is_empty() and _plan["layer"] == &"full":
        _plan = {}
        action_src_time = -1.0
    full_owner = -1


## Combat stance (sword drawn, standing) and boost sprint (top speed) over the locomotion.
func _drive_stance(speed: float, delta: float) -> void:
    var drawn: bool = weapon != null and bool(weapon.get(&"drawn"))
    _stance = move_toward(_stance, 1.0 if drawn and speed < 0.4 else 0.0, 5.0 * delta)
    _boost = move_toward(_boost, smoothstep(SPRINT_FROM * size_scale, SPRINT_FULL * size_scale, speed), 4.0 * delta)
    if player.has_animation(&"combat_idle"):
        tree.set("parameters/stance/blend_amount", _stance)
    if player.has_animation(&"sprint"):
        tree.set("parameters/boost/blend_amount", _boost)
        tree.set("parameters/boost_speed/scale", clampf(speed / maxf(_sprint_ref, 0.1), 0.5, LOCO_MAX_RATE))


## Places a real-moveset held clip in the A/B slots (see HERO_MOVESET): a new clip goes into the
## other slot and the two cross-fade, so changing poses never pops.
func _set_slot(row: Array, progress: float, time: float) -> void:
    var clip: StringName = row[1]
    if clip != _slot_clip[_slot]:
        _slot = 1 - _slot
        _slot_clip[_slot] = clip
        var node: StringName = &"hold_b_clip" if _slot == 1 else &"hold_a_clip"
        ((tree.tree_root as AnimationNodeBlendTree).get_node(node) as AnimationNodeAnimation).animation = clip
    _hold_clip = clip
    var length: float = player.get_animation(clip).length
    hold_time = clampf(pose_clip_time(row, progress, time), 0.0, length)
    tree.set("parameters/%s/seek_request" % ("hold_b_seek" if _slot == 1 else "hold_a_seek"), hold_time)


## Seconds into the row's clip for a pose `time` seconds old with move `progress` (HERO_MOVESET).
static func pose_clip_time(row: Array, progress: float, time: float) -> float:
    match row[2]:
        &"play":
            return minf(float(row[3]) + time * float(row[5]), float(row[4]))
        &"loop":
            return float(row[3]) + fposmod(time * float(row[5]), float(row[4]) - float(row[3]))
        &"stride":
            return float(row[3]) + fposmod(progress / float(row[5]), 1.0) * (float(row[4]) - float(row[3]))
        &"progress":
            return lerpf(float(row[3]), float(row[4]), clampf(progress, 0.0, 1.0))
        &"at":
            return float(row[3])
    return 0.0


## Places the held clip for a placeholder pose (HERO_POSES, models without the moveset).
func _set_hold(row: Array, progress: float) -> void:
    var clip: StringName = row[1]
    if not player.has_animation(clip):
        clip = _loco_anim_name(0)
    var anim: Animation = player.get_animation(clip)
    if clip != _hold_clip:
        _hold_clip = clip
        ((tree.tree_root as AnimationNodeBlendTree).get_node(&"hold_a_clip") as AnimationNodeAnimation).animation = clip
    var mode: StringName = row[2] if row.size() > 2 else &"frame"
    var t: float = 0.0
    match mode:
        &"frame":
            t = anim.length * (float(row[3]) if row.size() > 3 else 0.0)
        &"travel":
            t = fposmod(progress / HOLD_STRIDE, 1.0) * anim.length
        &"time":
            t = minf(progress, anim.length)
        &"span", &"peak":
            var span: Array = _hips_span(anim, &"jump")
            var start: float = float(span[0]) if not span.is_empty() else 0.0
            var length: float = float(span[1]) if not span.is_empty() else anim.length
            t = start + length * (1.0 if mode == &"peak" else clampf(progress, 0.0, 1.0))
    hold_time = clampf(t, 0.0, anim.length)
    tree.set("parameters/hold_a_seek/seek_request", hold_time)


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
    # Facing: frame-rate independent ease toward the gameplay facing (no snapping), then the
    # moveset's procedural pose (flips, spins, crouch, leans) on top.
    if steer_facing and body.has_method(&"get_facing_vector"):
        var f: Vector3 = body.call(&"get_facing_vector")
        if f.length_squared() > 0.0001:
            var turn_rate: float = 28.0 if body.get("view_camera") != null else 20.0
            _yaw = lerp_angle(_yaw, atan2(f.x, f.z), 1.0 - exp(-turn_rate * delta))
        _apply_pose(delta)
    _step_plan(delta)
    if not _queued.is_empty() and _clock >= _queued_at:
        var next: Dictionary = _queued
        _queued = {}
        act(next["clip"], next["duration"], &"attack", _moving())
    var motor: PlatformerMotor = _hero_motor()
    if motor != null:
        _drive_hero(motor, delta)
        return
    pose = &""
    if _hold > 0.0:  # left the 3D hero path (the Bishop hand-off): drop any held pose
        _hold = 0.0
        tree.set("parameters/base/blend_amount", 0.0)
    # Locomotion: smoothed ground speed drives the blend; faster than the run clip speeds it up.
    var ground: float = Vector2(_velocity.x, _velocity.z).length()
    if _state_move:
        ground = maxf(ground, RUN_REF * size_scale)
    _speed_smoothed = lerpf(_speed_smoothed, ground, 1.0 - exp(-10.0 * delta))
    var top: float = _loco_points.max()
    tree.set("parameters/loco/blend_position", minf(_speed_smoothed, top) if top > 0.0 else 0.0)
    var over: float = _speed_smoothed / top if top > 0.0 else 1.0
    tree.set("parameters/loco_speed/scale", clampf(over, 1.0, 1.8) if _loco_points.size() > 1 else clampf(over, 0.25, 1.8))
    _drive_stance(_speed_smoothed, delta)
    # Air: the air pose whenever really airborne (rising or falling); a short grace keeps steps
    # and slope lips from flickering it; landing eases straight back into locomotion.
    var grounded: bool = character == null or character.is_on_floor()
    _airtime = 0.0 if grounded else _airtime + delta
    var airborne: bool = _airtime > 0.08
    _air = move_toward(_air, 1.0 if airborne else 0.0, (7.0 if airborne else 10.0) * delta)
    tree.set("parameters/air/blend_amount", _air)

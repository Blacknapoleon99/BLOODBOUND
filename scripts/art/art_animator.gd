class_name ArtAnimator
extends Node
## Visual-only driver for a rigged ArtSwap model: picks the model's animation from the body's
## motion and gameplay signals, and (for the player) turns the model to face its direction.
## It only reads gameplay state; nothing here changes movement, combat or timing.

## Locomotion clips loop; everything else plays once and then hands back to locomotion.
const LOOPING: Array[StringName] = [&"idle", &"walk", &"run", &"fall"]

var body: Node3D
var model: Node3D
var player: AnimationPlayer
## Turn `model` toward the body's facing (players); enemies turn their own visual node.
var steer_facing: bool = false
## Clip used while moving on the ground ("run" for the player, "walk" for enemies).
var move_clip: StringName = &"walk"
var _one_shot: StringName = &""
## Locomotion clip forced by the current enemy state (the Gravewarden's charge runs).
var _state_move: StringName = &""
var _dead: bool = false
var _last_pos: Vector3
var _velocity: Vector3


static func attach(owner_body: Node3D, art: Node3D, steer: bool, moving: StringName) -> ArtAnimator:
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
    animator._last_pos = owner_body.global_position if owner_body.is_inside_tree() else owner_body.position
    for clip: StringName in animator.player.get_animation_list():
        var anim: Animation = animator.player.get_animation(clip)
        anim.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(clip) else Animation.LOOP_NONE
    animator.player.animation_finished.connect(animator._on_finished)
    art.add_child(animator)
    animator._connect_gameplay_signals()
    return animator


func _connect_gameplay_signals() -> void:
    _hook(body, &"attack_started", _on_attack)
    _hook(body, &"phase_changed", func(_phase: Variant = null) -> void: play_once(&"angry_01"))
    _hook(body, &"dodge_started", func(_dir: Variant = null) -> void: play_once(&"dive"))
    _hook(body, &"jumped", func() -> void: play_once(&"jump"))
    _hook(body, &"hurt", func(_info: Variant = null) -> void: play_once(&"hit_to_body_01"))
    _hook(body, &"died", _on_died)
    _hook(body, &"defeated", _on_died)
    _hook(body, &"state_changed", _on_state)
    var melee: Object = body.get("melee") as Object
    if melee != null and not body.has_signal(&"attack_started"):
        _hook(melee, &"attack_started", func(_data: Variant = null) -> void: play_once(&"slash"))


## Player attack ids (light/heavy) and Hollow Bishop attack names map onto the model's clips.
func _on_attack(id: Variant = null) -> void:
    var s: String = str(id).to_lower()
    if (s.contains("heavy") or s.contains("slam") or s.contains("sunder")) and player.has_animation(&"chop"):
        play_once(&"chop")
    elif (s.contains("beam") or s.contains("barrage") or s.contains("rain") or s.contains("geyser")             or s.contains("summon") or s.contains("requiem")) and player.has_animation(&"cast_a_spell"):
        play_once(&"cast_a_spell")
    else:
        play_once(attack_clip())


func _hook(source: Object, sig: StringName, callable: Callable) -> void:
    if source != null and source.has_signal(sig):
        source.connect(sig, callable)


## Plays `clip` once if the model has it (missing clips are ignored: the greybox timing rules).
func play_once(clip: StringName) -> void:
    if _dead or not player.has_animation(clip):
        return
    _one_shot = clip
    player.play(clip, 0.08)


## Enemy state names (PlaguedSoldier/BoneArcher/CryptHound enums, CodeEnemy set_state names).
## The attack clip starts on the wind-up, so the swing reads as the telegraph; the strike
## state that follows (bash, quake) only starts it if it is not already playing; a charge runs.
func _on_state(state_name: String) -> void:
    var s: String = state_name.to_lower()
    _state_move = &"run" if s.contains("charging") and player.has_animation(&"run") else &""
    if s.contains("charge_windup") and player.has_animation(&"angry_01"):
        play_once(&"angry_01")  # a roar before the charge
        return
    if s.contains("dead"):
        _on_died()
    elif s.contains("hitstun") or s.contains("stagger"):
        play_once(&"hit_to_body_01")
    elif s.contains("aim"):
        play_once(&"shoot")
    elif s.contains("windup") or s.contains("attack") or s.contains("pounce"):
        play_once(attack_clip())
    elif (s.contains("bash") or s.contains("quake")) and _one_shot == &"":
        play_once(attack_clip())


func attack_clip() -> StringName:
    for clip: StringName in [&"slash", &"chop", &"attack"]:
        if player.has_animation(clip):
            return clip
    return &"slash"


func _on_died() -> void:
    if _dead:
        return
    _dead = false
    play_once(&"defeat")
    _dead = true


func _on_finished(clip: StringName) -> void:
    if clip == _one_shot and not _dead:
        _one_shot = &""


func _physics_process(_delta: float) -> void:
    if body == null or not is_instance_valid(body):
        return
    var character: CharacterBody3D = body as CharacterBody3D
    if character != null:
        _velocity = character.velocity
    else:
        _velocity = (body.global_position - _last_pos) / maxf(_delta, 0.0001)
        _last_pos = body.global_position
    if steer_facing and body.has_method(&"get_facing_vector"):
        var f: Vector3 = body.call(&"get_facing_vector")
        if f.length_squared() > 0.0001:
            var target: float = atan2(f.x, f.z)
            model.rotation.y = lerp_angle(model.rotation.y, target, 0.35)
    if _dead or _one_shot != &"":
        return
    var clip: StringName = &"idle"
    if character != null and not character.is_on_floor() and player.has_animation(&"fall") and _velocity.y < -1.0:
        clip = &"fall"
    elif _state_move != &"":
        clip = _state_move
    elif Vector2(_velocity.x, _velocity.z).length() > 0.6 and player.has_animation(move_clip):
        clip = move_clip
    if player.current_animation != clip and player.has_animation(clip):
        player.play(clip, 0.15)

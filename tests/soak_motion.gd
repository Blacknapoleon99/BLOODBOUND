extends SceneTree
## Movement soak (DEC-060): drives the REAL full-3D hero with seeded random input for minutes
## (move in every direction, analog tilt, jump taps/holds, crouch, dash, light/heavy swings,
## lock-on, cards, camera turns) in the movement playground and across the rooms of a real 3D
## run, with random teleports onto ledges, climb walls, slopes, moving/orbiting platforms,
## enemies and edges, and random hits mid-action. Every physics frame it checks the motor and
## the animator for the "stuck in a pose and sliding" family of bugs and logs each anomaly with
## the last second of history.
##
## Run (headless, faster than real time):
##   godot --headless --path . --fixed-fps 60 -s res://tests/soak_motion.gd -- --seed=1 --seconds=300
## Options: --seed=N (default 1), --seconds=S simulated seconds in total (default 240),
##          --verbose (print every anomaly's history, not only the first of each kind).
## Exit code 0 = no anomalies.

const HZ: float = 60.0
const MOVE_KEYS: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D]
const DIRS: Array = [[KEY_W], [KEY_S], [KEY_A], [KEY_D], [KEY_W, KEY_A], [KEY_W, KEY_D], [KEY_S, KEY_A], [KEY_S, KEY_D]]
const ALL_KEYS: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_CTRL, KEY_SHIFT, KEY_J, KEY_L]
## Longest each transient motor state may last (seconds, game time) before it counts as stuck.
const MAX_TIME: Dictionary = {
    &"LAND": 0.4, &"SKID": 0.6, &"BRAKE": 0.6, &"DECEL": 1.5, &"PULL_UP": 0.9, &"POUND_SPIN": 0.35,
    &"POUND_LAND": 0.35, &"CLIMB_LEAP": 0.4, &"SLIDE": 1.0, &"DASH": 0.45, &"ATTACK": 1.6, &"KNOCKBACK": 3.0,
    &"BONK": 4.0, &"POUND_FALL": 6.0,
}
## States where the body may legitimately move with the stick released.
const COASTING: Array[StringName] = [&"DECEL", &"BRAKE", &"SKID", &"SLIDE", &"SLOPE_SLIDE", &"KNOCKBACK", &"DASH", &"ATTACK", &"LAND"]

var seed_value: int = 1
var total_seconds: float = 240.0
var verbose: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var p: CharacterBody3D
var motor: PlatformerMotor
var animator: ArtAnimator
var scene_kind: String = ""
var spots: Array[Dictionary] = []  # {"pos", "tag"} teleport targets in the current scene

var held: Dictionary = {}  # Key -> true
var analog: float = 0.0  # analog forward tilt (0 = off)
var input_text: String = ""
var sim_time: float = 0.0
var history: Array[Dictionary] = []
var anomalies: Array[Dictionary] = []
var counts: Dictionary = {}
var state_frames: Dictionary = {}  # motor state -> frames seen (coverage)
var frames: int = 0
var _timers: Dictionary = {}  # detector -> seconds the condition has held
var _prev_pos: Vector3
var _prev_floor: Node3D
var _prev_floor_pos: Vector3
var _prev_hold_time: float = -1.0
var _prev_plan_t: float = 0.0
var _oneshot_age: Dictionary = {&"full": 0.0, &"upper": 0.0}
var _death_pending: bool = false
var _last_report: Dictionary = {}  # kind -> sim time last logged (rate limit)


func _initialize() -> void:
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--seed="):
            seed_value = int(arg.get_slice("=", 1))
        elif arg.begins_with("--seconds="):
            total_seconds = float(arg.get_slice("=", 1))
        elif arg == "--verbose":
            verbose = true
    rng.seed = seed_value
    _run.call_deferred()


func _run() -> void:
    GameSettings.persistence_enabled = false
    GameSettings.reset_defaults()
    Profile.reset()
    print("SOAK seed=%d seconds=%.0f" % [seed_value, total_seconds])
    var chunk: float = clampf(total_seconds / 4.0, 20.0, 90.0)
    var budget: float = total_seconds
    var round_i: int = 0
    while budget > 0.0:
        var length: float = minf(chunk, budget)
        if round_i % 2 == 0:
            await _enter_playground()
        else:
            await _enter_run(seed_value * 100 + round_i)
        await _soak(length)
        budget -= length
        round_i += 1
    _release_all()
    print("SOAK frames=%d simulated=%.1f s anomalies=%d" % [frames, sim_time, anomalies.size()])
    for kind: String in counts:
        print("  %-18s %d" % [kind, counts[kind]])
    var cover: Array[String] = []
    for st: StringName in state_frames:
        cover.append("%s %d" % [st, state_frames[st]])
    print("SOAK coverage (frames per motor state): " + ", ".join(cover))
    quit(1 if anomalies.size() > 0 else 0)


# --- Scenes -----------------------------------------------------------------------------

func _enter_playground() -> void:
    _release_all()
    Lane.full_3d = false
    change_scene_to_file("res://scenes/playground_3d.tscn")
    await _frames(15)
    scene_kind = "playground"
    var room: Node3D = current_scene
    _bind(room.get("player"))
    spots.clear()
    var stations: Dictionary = room.get("stations")
    for key: String in stations:
        spots.append({"pos": stations[key], "tag": "station:" + key})
    for node: Node in room.find_children("*", "StaticBody3D", true, false):
        _add_top_spots(node as StaticBody3D, "pg")
    _collect_movers(room)


func _enter_run(run_seed: int) -> void:
    _release_all()
    LevelLayout.classic = false
    RunState.coop = false
    RunState.full_3d = true
    RunState.new_run(run_seed)
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(15)
    scene_kind = "run%d" % run_seed
    var main: Node3D = current_scene
    _bind(main.get("player"))
    spots.clear()
    var opening: Node = main.get("opening")
    var rooms: Array = main.get("sections")
    for room: LevelSection in rooms:
        spots.append({"pos": room.checkpoint.global_position + Vector3(0.0, 0.3, 1.5), "tag": "entry:" + String(room.id)})
        for i in room.platforms.size():
            var r: Rect2 = room.platforms[i]
            var zr: Vector2 = room.platform_z[i]
            var top: float = r.position.y
            var cx: float = room.gx(r.get_center().x)
            # The middle and the edges (stepping off mid-action).
            spots.append({"pos": Vector3(cx, top + 1.0, (zr.x + zr.y) * 0.5), "tag": "%s plat%d" % [room.id, i]})
            spots.append({"pos": Vector3(room.gx(r.end.x) - 0.4, top + 1.0, (zr.x + zr.y) * 0.5), "tag": "%s edge%d" % [room.id, i]})
        for wall: ClimbWall in room.climb_walls:
            var at: Vector3 = wall.global_position
            spots.append({"pos": Vector3(at.x, room.platforms[0].position.y + 1.2, at.z) + Vector3(0.0, 0.0, 0.0), "tag": "%s climb" % room.id})
    if opening != null:
        for node: Node in opening.find_children("*", "StaticBody3D", true, false):
            _add_top_spots(node as StaticBody3D, "open")
    _collect_movers(main)


func _bind(player: CharacterBody3D) -> void:
    p = player
    motor = p.get("motor")
    animator = p.find_child("ArtAnimator", true, false) as ArtAnimator
    _prev_pos = p.global_position
    _prev_floor = null
    history.clear()
    _timers.clear()


## A spot on top of a static box (its collision shape's top), plus one near its edge.
func _add_top_spots(body: StaticBody3D, tag: String) -> void:
    if body == null:
        return
    for child: Node in body.get_children():
        var cs: CollisionShape3D = child as CollisionShape3D
        if cs == null or not (cs.shape is BoxShape3D):
            continue
        var size: Vector3 = (cs.shape as BoxShape3D).size
        if size.x < 1.5 or size.z < 1.5 or size.y > 30.0:
            continue
        var top: Vector3 = cs.global_position + Vector3(0.0, size.y * 0.5 + 1.0, 0.0)
        spots.append({"pos": top, "tag": "%s %s" % [tag, body.name]})
        spots.append({"pos": top + Vector3(size.x * 0.5 - 0.4, 0.0, 0.0), "tag": "%s %s edge" % [tag, body.name]})


func _collect_movers(scene: Node) -> void:
    for node: Node in scene.find_children("*", "AnimatableBody3D", true, false):
        spots.append({"mover": node, "tag": "mover " + String(node.name)})


# --- Soak loop --------------------------------------------------------------------------

func _soak(length: float) -> void:
    var end_at: float = sim_time + length
    var next_teleport: float = sim_time + rng.randf_range(1.0, 4.0)
    while sim_time < end_at:
        if not is_instance_valid(p) or p.get("view_camera") == null:
            # The run handed off to the side view (or the scene changed): start a fresh run.
            await _enter_run(seed_value * 100 + frames)
            continue
        if sim_time >= next_teleport:
            _random_teleport()
            next_teleport = sim_time + rng.randf_range(2.5, 9.0)
        await _segment()


## One random input segment (0.06-1.0 s): what is held, what is tapped, maybe a hit.
func _segment() -> void:
    var duration: float = rng.randf_range(0.06, 1.0)
    var want: Dictionary = {}
    var roll: float = rng.randf()
    analog = 0.0
    if roll < 0.2:
        pass  # stick released
    elif roll < 0.3:
        analog = rng.randf_range(0.25, 1.0)
    else:
        for k: Key in DIRS[rng.randi() % DIRS.size()]:
            want[k] = true
    if rng.randf() < 0.18:
        want[KEY_SPACE] = true  # held jump
    if rng.randf() < 0.1:
        want[KEY_CTRL] = true  # held crouch
    if rng.randf() < 0.05:
        want[KEY_J] = true  # held light (chains the combo)
    _apply_held(want)
    var taps: Array[Key] = []
    for entry: Array in [[KEY_SPACE, 0.25], [KEY_CTRL, 0.08], [KEY_SHIFT, 0.2], [KEY_J, 0.18], [KEY_L, 0.06], [KEY_Q, 0.05], [KEY_TAB, 0.02], [KEY_1, 0.03], [KEY_2, 0.02], [KEY_3, 0.02]]:
        if rng.randf() < float(entry[1]) and not want.has(entry[0]):
            taps.append(entry[0])
    var look: StringName = &""
    if rng.randf() < 0.12:
        look = [&"look_left", &"look_right"][rng.randi() % 2]
        Input.action_press(look, rng.randf_range(0.3, 1.0))
    var hit_at: int = rng.randi_range(0, maxi(1, int(duration * HZ))) if rng.randf() < 0.05 else -1
    var tap_at: int = rng.randi_range(0, maxi(1, int(duration * HZ) / 2))
    input_text = _describe(want, taps)
    var n: int = maxi(1, int(duration * HZ))
    for i in n:
        if analog > 0.0:
            Input.action_press(&"move_forward", analog)
        if i == tap_at:
            for k: Key in taps:
                _key(k, true)
        elif i == tap_at + 2:
            for k: Key in taps:
                _key(k, false)
        if i == hit_at:
            if rng.randf() < 0.15:
                _synthetic_death()
            else:
                _synthetic_hit()
        await physics_frame
        _monitor()
        if not is_instance_valid(p):
            break
    for k: Key in taps:
        _key(k, false)
    if look != &"":
        Input.action_release(look)
    if analog > 0.0:
        Input.action_release(&"move_forward")
        analog = 0.0


func _apply_held(want: Dictionary) -> void:
    for k: Key in ALL_KEYS:
        var on: bool = want.has(k)
        if bool(held.get(k, false)) != on:
            _key(k, on)
            held[k] = on


func _release_all() -> void:
    for k: Key in ALL_KEYS:
        _key(k, false)
    held.clear()
    for a: StringName in [&"move_forward", &"look_left", &"look_right"]:
        if InputMap.has_action(a):
            Input.action_release(a)
    analog = 0.0


func _describe(want: Dictionary, taps: Array[Key]) -> String:
    var s: String = ""
    for k: Key in want:
        s += OS.get_keycode_string(k) + " "
    if analog > 0.0:
        s += "fwd%.2f " % analog
    for k: Key in taps:
        s += "+" + OS.get_keycode_string(k) + " "
    return s.strip_edges()


func _random_teleport() -> void:
    if spots.is_empty():
        return
    var spot: Dictionary = spots[rng.randi() % spots.size()]
    var at: Vector3
    if spot.has("mover"):
        var mover: Node3D = spot["mover"] as Node3D
        if not is_instance_valid(mover):
            return
        at = mover.global_position + Vector3(0.0, 1.4, 0.0)
    elif rng.randf() < 0.12:
        # Onto an enemy's head (landing on a moving body).
        var foes: Array[Node] = get_nodes_in_group(&"enemy")
        if foes.is_empty():
            return
        var foe: Node3D = foes[rng.randi() % foes.size()] as Node3D
        if foe == null:
            return
        at = foe.global_position + Vector3(0.0, 2.6, 0.0)
        spot = {"tag": "enemy " + String(foe.name)}
    else:
        at = spot["pos"]
    # Never into solid geometry (a spot over a sealed cellar niche is inside its slab): the game
    # itself never puts the hero there, so it would only measure the harness.
    if _blocked_at(at):
        return
    # Teleports land mid-action as often as not (respawn / teleport mid-swing or dash).
    p.call("teleport_to", at)
    (p.get("health") as Health).restore_full()
    _prev_pos = p.global_position
    _prev_floor = null
    _record_event("teleport " + String(spot["tag"]))


func _blocked_at(at: Vector3) -> bool:
    var cs: CollisionShape3D = p.get_node("BodyCollision") as CollisionShape3D
    var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
    query.shape = cs.shape
    query.transform = Transform3D(Basis.IDENTITY, at + cs.position)
    query.exclude = [p.get_rid()]
    query.collide_with_areas = false
    return not p.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _synthetic_hit() -> void:
    var hurtbox: Hurtbox = p.get("hurtbox") as Hurtbox
    var info: DamageInfo = DamageInfo.new()
    var dir: Vector2 = Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(2.0, 7.0)
    info.knockback = Vector3(dir.x, rng.randf_range(0.0, 4.0), dir.y)
    info.hitstun = rng.randf_range(0.1, 0.45)
    hurtbox.hit_received.emit(info)
    _record_event("hit")


## A real death (lethal damage, mid-action as often as not): main.gd revives the hero at the
## checkpoint; afterwards the animator must be running again (the frozen-after-death bug).
func _synthetic_death() -> void:
    var health: Health = p.get("health") as Health
    health.apply_damage(health.current)
    _record_event("death")
    _death_pending = true


func _record_event(text: String) -> void:
    if not history.is_empty():
        history[history.size() - 1]["event"] = String(history[history.size() - 1].get("event", "")) + text + " "


# --- Monitor ----------------------------------------------------------------------------

func _monitor() -> void:
    frames += 1
    if paused:
        _unpause()
        return
    if not is_instance_valid(p) or p.get("view_camera") == null or motor == null:
        return
    var dt: float = (1.0 / HZ) * Engine.time_scale
    sim_time += 1.0 / HZ
    var hp: Health = p.get("health") as Health
    if _death_pending:
        if hp.is_dead():
            sim_time += 1.0 / HZ  # dead: waiting for main.gd's respawn (time still runs)
            return
        _death_pending = false
    elif frames % 30 == 0:
        hp.restore_full()
    # 0. Alive but the animator switched off (death froze the model for the rest of the run).
    if animator != null:
        _flag(not hp.is_dead() and (not animator.tree.active or bool(animator.get("_dead"))), "animator_dead_after_respawn", 0.5, (1.0 / HZ))
    var a: Dictionary = motor.anim_state()
    var state: StringName = StringName(PlatformerMotor.State.keys()[motor.state])
    var on_floor: bool = p.is_on_floor()
    # Real motion relative to whatever the hero stands on (a moving platform carries you).
    var pos: Vector3 = p.global_position
    var floor_body: Node3D = _floor_body()
    var carried: Vector3 = Vector3.ZERO
    if floor_body != null and floor_body == _prev_floor:
        carried = floor_body.global_position - _prev_floor_pos
    var rel: Vector3 = (pos - _prev_pos) - carried
    var teleported: bool = (pos - _prev_pos).length() > 3.0
    var rel_speed: float = Vector2(rel.x, rel.z).length() / maxf(dt, 0.0001) if not teleported else 0.0
    _prev_pos = pos
    _prev_floor = floor_body
    _prev_floor_pos = floor_body.global_position if floor_body != null else Vector3.ZERO
    var moving_input: bool = analog > 0.0 or MOVE_KEYS.any(func(k: Key) -> bool: return bool(held.get(k, false)))
    var row: Array = animator.poses.get(animator.pose, [&"loco"]) if animator != null else [&"loco"]
    var full_on: bool = animator != null and bool(animator.tree.get("parameters/full/active"))
    var upper_on: bool = animator != null and bool(animator.tree.get("parameters/upper/active"))
    var full_clip: StringName = _oneshot_clip(&"full")
    var base_w: float = float(animator.tree.get("parameters/base/blend_amount")) if animator != null else 0.0
    var air_w: float = float(animator.tree.get("parameters/air/blend_amount")) if animator != null else 0.0
    var hold_time: float = float(animator.hold_time) if animator != null else 0.0
    var collision: CollisionShape3D = p.get_node("BodyCollision") as CollisionShape3D
    var rec: Dictionary = {
        "t": snappedf(sim_time, 0.01), "state": state, "jump": PlatformerMotor.Jump.keys()[motor.jump_kind],
        "st": snappedf(motor.state_time, 0.01), "pose": a["pose"], "apose": animator.pose if animator else &"",
        "full": String(full_clip) if full_on else "", "upper": upper_on, "base": snappedf(base_w, 0.01), "air": snappedf(air_w, 0.01),
        "hold": snappedf(hold_time, 0.01), "v": Vector3(p.velocity).snapped(Vector3.ONE * 0.1), "rel": snappedf(rel_speed, 0.1),
        "floor": on_floor, "on": String(floor_body.name) if floor_body != null else "", "in": input_text,
        "melee": (p.get("melee") as MeleeAttack).is_busy(), "dodge": bool(p.call("is_dodging")), "stun": bool(p.call("is_stunned")),
        "ts": snappedf(Engine.time_scale, 0.01), "pos": pos.snapped(Vector3.ONE * 0.01), "touch": _touching(),
    }
    history.append(rec)
    state_frames[state] = int(state_frames.get(state, 0)) + 1
    if history.size() > 75:
        history.pop_front()
    if teleported:
        _timers.clear()
        return

    # 1. Collision off outside a pull-up.
    _flag(collision.disabled and motor.state != PlatformerMotor.State.PULL_UP, "collision_off", 0.0, dt)
    # 2. A transient state outlasting its longest legitimate time.
    var limit: float = float(MAX_TIME.get(state, -1.0))
    if limit > 0.0 and motor.state_time > limit:
        _report("overstay_" + String(state), "%s for %.2f s (max %.2f)" % [state, motor.state_time, limit])
    # 3. The animator plays a different pose from the motor's, or the wrong layer.
    if animator != null:
        _flag(animator.pose != a["pose"], "pose_mismatch", 0.25, dt)
        var layer: StringName = row[0]
        var wrong_layer: bool = (layer == &"loco" and (base_w > 0.5 or air_w > 0.5)) or (layer == &"hold" and base_w < 0.5) or (layer == &"air" and (air_w < 0.5 or base_w > 0.5))
        _flag(wrong_layer, "layer_mismatch", 0.25, dt)
    # 4. A whole-body one-shot left over from an action the motor has left, while the body moves
    #    or does something else: the legs are stuck in the swing/roll and the hero slides.
    var stale: bool = false
    if full_on:
        var owner_state: int = _clip_state(full_clip)
        var busy_moving: bool = rel_speed > 1.0 or not on_floor or not (motor.state in [PlatformerMotor.State.GROUND, PlatformerMotor.State.LAND, PlatformerMotor.State.DECEL])
        if owner_state == PlatformerMotor.State.DASH:
            # A roll may run out of the dash on the ground; anything else must take over.
            busy_moving = not on_floor or not (motor.state in [PlatformerMotor.State.GROUND, PlatformerMotor.State.LAND, PlatformerMotor.State.DECEL, PlatformerMotor.State.BRAKE])
        stale = owner_state >= 0 and motor.state != owner_state and busy_moving
    _flag(stale, "stale_oneshot", 0.2, dt)
    # 5. A one-shot that never ends.
    var plan_t: float = float(animator.get("_plan_t")) if animator != null else 0.0
    var refired: bool = plan_t < _prev_plan_t  # a new swing refires the one-shot (held combo)
    _prev_plan_t = plan_t
    for layer2: StringName in [&"full", &"upper"]:
        var on: bool = full_on if layer2 == &"full" else upper_on
        _oneshot_age[layer2] = float(_oneshot_age[layer2]) + dt if on and not refired else 0.0
        if float(_oneshot_age[layer2]) > 2.5:
            _report("oneshot_stuck_" + String(layer2), "%s one-shot active %.1f s" % [layer2, _oneshot_age[layer2]])
            _oneshot_age[layer2] = -1000.0
    # 6. Sliding on the floor in a frozen held pose (the clip stopped, the body moves).
    var frozen: bool = animator != null and row[0] == &"hold" and base_w > 0.5 and absf(hold_time - _prev_hold_time) < 0.0001 \
            and row.size() > 2 and row[2] in [&"play", &"at"]
    _prev_hold_time = hold_time
    _flag(on_floor and rel_speed > 1.0 and frozen and not (state in [&"KNOCKBACK", &"SLIDE", &"SLOPE_SLIDE", &"SKID", &"BRAKE"]), "frozen_slide", 0.25, dt)
    # 6b. A slide (crouch or slope) that doesn't move: the slide pose held on a body standing still.
    _flag(state in [&"SLOPE_SLIDE", &"SLIDE"] and rel_speed < 0.2 and not teleported, "stuck_slide", 0.5, dt)
    # 7. Drifting with the stick released in a state that should stand still (incl. a moving
    #    platform or an enemy under you).
    var drift: bool = on_floor and not moving_input and rel_speed > 0.4 and not (state in COASTING) \
            and not bool(p.call("is_stunned")) and not bool(p.call("is_dodging"))
    _flag(drift, "drift_no_input", 0.5, dt)
    # 8. Locomotion legs out of step with the body: running while standing still, idling while
    #    the body moves (ice-skating), or running in mid-air.
    if animator != null and row[0] == &"loco" and not full_on:
        var shown: float = float(animator.get("_speed_smoothed"))
        _flag(on_floor and state == &"GROUND" and shown > 2.5 and rel_speed < 0.3, "legs_run_standing", 0.3, dt)
        _flag(on_floor and rel_speed > 1.5 and shown < rel_speed * 0.5 and not (state in [&"DASH", &"KNOCKBACK"]), "legs_idle_moving", 0.25, dt)
        _flag(not on_floor and not (state in [&"GROUND", &"DECEL", &"BRAKE", &"LAND"]) and air_w < 0.5 and base_w < 0.5 and shown > 1.0, "legs_run_in_air", 0.25, dt)
    else:
        _timers.erase("legs_idle_moving")


func _flag(cond: bool, kind: String, grace: float, dt: float) -> void:
    if not cond:
        _timers[kind] = 0.0
        return
    var t: float = float(_timers.get(kind, 0.0)) + dt
    _timers[kind] = t
    if t > grace and t - dt <= grace:
        _report(kind, "held %.2f s" % t)


func _report(kind: String, detail: String) -> void:
    counts[kind] = int(counts.get(kind, 0)) + 1
    var entry: Dictionary = {"kind": kind, "detail": detail, "t": sim_time, "scene": scene_kind, "history": history.duplicate(true)}
    anomalies.append(entry)
    var first: bool = int(counts[kind]) == 1
    printerr("ANOMALY %s [%s t=%.2f] %s" % [kind, scene_kind, sim_time, detail])
    if first or verbose:
        for h: Dictionary in history.slice(maxi(0, history.size() - 60)):
            print("    t=%s %s/%s st=%s pose=%s apose=%s full=%s up=%s base=%s air=%s hold=%s v=%s rel=%s floor=%s on=%s melee=%s dodge=%s stun=%s ts=%s in=[%s] %s" % [
                h["t"], h["state"], h["jump"], h["st"], h["pose"], h["apose"], h["full"], h["upper"], h["base"], h["air"], h["hold"],
                h["v"], h["rel"], h["floor"], h["on"], h["melee"], h["dodge"], h["stun"], h["ts"], h["in"], h.get("event", "")])
            print("        pos=%s touch=%s" % [h["pos"], h["touch"]])


## The motor state that owns a whole-body one-shot clip (-1 = any / not tracked).
func _clip_state(clip: StringName) -> int:
    if clip in ArtAnimator.ATTACK_CLIPS.values() or clip in [&"slash", &"chop"]:
        return PlatformerMotor.State.ATTACK
    if clip in [&"roll", &"dive"]:
        return PlatformerMotor.State.DASH
    if clip == &"hit_to_body_01":
        return PlatformerMotor.State.KNOCKBACK
    return -1


func _oneshot_clip(layer: StringName) -> StringName:
    if animator == null:
        return &""
    var root_node: AnimationNodeBlendTree = animator.tree.tree_root as AnimationNodeBlendTree
    var shot: AnimationNodeAnimation = root_node.get_node(StringName("%s_clip" % layer)) as AnimationNodeAnimation
    return shot.animation if shot != null else &""


## What the body touched last move (collider name and normal), for the anomaly history.
func _touching() -> String:
    var parts: Array[String] = []
    for i in p.get_slide_collision_count():
        var c: KinematicCollision3D = p.get_slide_collision(i)
        var col: Node = c.get_collider() as Node
        parts.append("%s%s" % [col.name if col != null else "?", c.get_normal().snapped(Vector3.ONE * 0.01)])
    return ",".join(parts)


func _floor_body() -> Node3D:
    for i in p.get_slide_collision_count():
        var c: KinematicCollision3D = p.get_slide_collision(i)
        if c.get_normal().y > 0.6:
            return c.get_collider() as Node3D
    return null


func _unpause() -> void:
    for node: Node in current_scene.find_children("*", "CardOfferOverlay", true, false):
        var overlay: CardOfferOverlay = node as CardOfferOverlay
        if overlay.is_open():
            overlay.skip_button.pressed.emit()
            return
    paused = false


func _key(code: Key, pressed: bool) -> void:
    var ev: InputEventKey = InputEventKey.new()
    ev.keycode = code
    ev.physical_keycode = code
    ev.pressed = pressed
    Input.parse_input_event(ev)


func _frames(n: int) -> void:
    for i in n:
        await process_frame

extends SceneTree
## Automated M0 gameplay smoke test. Drives the real main scene through Godot's
## input pipeline (Input.parse_input_event), so the player script and main.gd
## receive the same key events a human would produce.
##
## Run headless:  godot --headless --path . -s res://tests/gameplay_smoke.gd
## Run visible:   godot --path . -s res://tests/gameplay_smoke.gd   (also saves screenshots)
## Exit code 0 = all checks passed, 1 = at least one failure.

const PHYSICS_HZ: float = 60.0
const SHOT_DIR: String = "res://docs/screenshots/"
const CARD_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3]

var _failures: int = 0
var _checks: int = 0
var _max_abs_z_in_2d: float = 0.0
var _main: Node3D
var _player: CharacterBody3D
var _enemy: PlaguedSoldier


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    await _seconds(1.0)

    _check(_player.is_on_floor(), "player lands on the starting causeway")
    _check(absf(_player.global_position.z) < 0.001, "player starts on Z=0 plane")
    await _shot("01_boot")
    _m4_data_and_deck_checks()

    # The soldier patrols on its own from boot; park it for deterministic movement tests.
    var ex0: float = _enemy.global_position.x
    await _seconds(1.0)
    _check(_enemy.state_name() == "PATROL" and absf(_enemy.global_position.x - ex0) > 0.8, "soldier patrols on its own (state=%s, dx=%.2f)" % [_enemy.state_name(), _enemy.global_position.x - ex0])
    _enemy.set_ai_enabled(false)
    _enemy.teleport_to(Vector3(9.0, 1.0, 0.0))

    # The portcullis to the Bishop's arena stays shut while the soldier lives.
    _player.call("teleport_to", Vector3(16.0, 1.0, 0.0))
    await _seconds(0.3)
    await _hold(KEY_D, 1.0)
    _check(_player.global_position.x < 18.3, "portcullis blocks the way while the soldier lives (x=%.2f)" % _player.global_position.x)
    _player.call("teleport_to", Vector3(-16.0, 2.0, 0.0))
    await _seconds(0.8)

    # --- Horizontal movement -------------------------------------------------
    var x0: float = _player.global_position.x
    await _hold(KEY_D, 0.5)
    var x1: float = _player.global_position.x
    _check(x1 > x0 + 1.5, "D moves right (dx=%.2f)" % (x1 - x0))
    # Reversing from full speed needs ~0.47 s of deceleration before moving left.
    await _hold(KEY_A, 0.9)
    await _seconds(0.3)
    var x2: float = _player.global_position.x
    _check(x2 < x1 - 1.0, "A moves left (dx=%.2f)" % (x2 - x1))
    _check(_player.get("facing_direction") == -1.0, "facing flips to left after moving left")

    # --- Jump ----------------------------------------------------------------
    var full_rise: float = await _jump_peak(0.5)
    _check(full_rise > 1.8, "held Space gives a full jump (rise=%.2f)" % full_rise)
    _check(_player.is_on_floor(), "player lands again after jump")
    var short_rise: float = await _jump_peak(0.03)
    _check(short_rise < full_rise * 0.6 and short_rise > 0.3, "tapped Space gives a short jump (rise=%.2f vs %.2f)" % [short_rise, full_rise])

    # Holding Space must not auto-bunnyhop on every landing.
    _key(KEY_SPACE, true)
    var takeoffs: int = 0
    var was_floor: bool = true
    for i in int(2.5 * PHYSICS_HZ):
        await physics_frame
        var on_floor: bool = _player.is_on_floor()
        if was_floor and not on_floor:
            takeoffs += 1
        was_floor = on_floor
    _key(KEY_SPACE, false)
    await _seconds(0.2)
    _check(takeoffs == 1, "holding Space jumps once, no auto-bunnyhop (takeoffs=%d)" % takeoffs)

    # --- Gap death / respawn (teleport over the first gap, then let it fall) --
    _player.global_position = Vector3(-6.5, 0.0, 0.0)
    _player.velocity = Vector3.ZERO
    await _seconds(2.0)
    var spawn: Vector3 = _main.get_script().get_script_constant_map()["SPAWN_POSITION"]
    _check(_player.global_position.distance_to(spawn) < 2.5, "falling into the gap respawns at the safe start (pos=%s)" % _player.global_position)
    await _seconds(0.8)

    # --- Real traversal from spawn to the dummy, jumping gaps/obstacles -------
    var checkpoint: Node = _main.get("checkpoint")
    _check(not bool(checkpoint.get("is_active")), "checkpoint starts inactive")
    var reached: bool = await _run_right_until(3.2, 8.0)
    _check(reached, "traversed gaps and raised step to the dummy (x=%.2f)" % _player.global_position.x)
    _check(bool(checkpoint.get("is_active")), "passing the broken span activates the checkpoint")

    # Fall into the second gap: must return to the checkpoint, not the start.
    _player.call("teleport_to", Vector3(-2.25, 0.0, 0.0))
    await _seconds(2.0)
    var cp_pos: Vector3 = checkpoint.get("respawn_position")
    _check(_player.global_position.distance_to(cp_pos) < 1.5, "falling after the checkpoint respawns at it (pos=%s)" % _player.global_position)

    # --- M1 movement-feel measurements ---------------------------------------
    await _m1_coyote_checks(spawn)
    await _m1_buffer_checks()
    await _m1_dodge_checks()

    _player.call("teleport_to", cp_pos)
    await _seconds(0.6)
    reached = await _run_right_until(3.2, 6.0)
    _check(reached, "route from checkpoint to the battle causeway is traversable (x=%.2f)" % _player.global_position.x)

    # --- M2 combat -------------------------------------------------------------
    await _m2_attack_phase_checks()
    await _m2_enemy_attack_checks()
    await _m2_player_death_check(cp_pos)
    await _m2_contact_damage_check()
    await _m2_leash_check()
    await _m2_player_hits_enemy_checks()

    # --- M5 Reality Fracture: cross into 3D and back ---------------------------
    reached = await _run_right_until(12.6, 6.0)
    _check(reached, "walked to the amber gate (x=%.2f)" % _player.global_position.x)
    await _seconds(0.3)
    await _m5_fracture_checks()

    # --- M3 Hollow Bishop → victory / restart ----------------------------------
    await _m3_boss_checks()
    _check(bool(_main.get("game_won")), "defeating the Bishop wins the run")
    _check(bool(_player.get("game_frozen")), "player is frozen on victory")
    await _shot("08_victory")
    _tap(KEY_R)
    await _frames(10)
    _bind()
    await _seconds(0.5)
    _check(bool(_main.get("enemy_alive")) and not bool(_main.get("game_won")), "R restarts with fresh state")
    _check(_player.global_position.distance_to(spawn) < 2.5, "restart places player at spawn")

    _check(_max_abs_z_in_2d < 0.001, "no Z drift during 2.5D play (max |z|=%.4f)" % _max_abs_z_in_2d)

    print("SMOKE RESULT: %d/%d checks passed" % [_checks - _failures, _checks])
    quit(1 if _failures > 0 else 0)


## Jumps from standing, holding Space for `hold` seconds; returns the peak rise.
func _jump_peak(hold: float) -> float:
    var start_y: float = _player.global_position.y
    _key(KEY_SPACE, true)
    var peak: float = start_y
    var released: bool = false
    for frame in range(1, int(1.6 * PHYSICS_HZ)):
        await physics_frame
        if not released and frame >= maxi(1, int(hold * PHYSICS_HZ)):
            _key(KEY_SPACE, false)
            released = true
        peak = maxf(peak, _player.global_position.y)
        if frame > 10 and _player.is_on_floor():
            break
    _key(KEY_SPACE, false)
    await _seconds(0.2)
    return peak - start_y


## Walks off the starting ledge (x=-7) and presses jump `frames_after` frames after leaving the floor.
func _coyote_attempt(spawn: Vector3, frames_after: int) -> bool:
    _player.call("teleport_to", spawn)
    await _seconds(0.6)
    _key(KEY_D, true)
    var left_floor: bool = false
    for i in int(3.0 * PHYSICS_HZ):
        await physics_frame
        if not _player.is_on_floor() and _player.global_position.x > -7.4:
            left_floor = true
            break
    if not left_floor:
        _key(KEY_D, false)
        return false
    for i in frames_after:
        await physics_frame
    _key(KEY_SPACE, true)
    await physics_frame
    await physics_frame
    var jumped: bool = _player.velocity.y > 5.0
    _key(KEY_SPACE, false)
    _key(KEY_D, false)
    await _seconds(2.0)
    return jumped


func _m1_coyote_checks(spawn: Vector3) -> void:
    _check(await _coyote_attempt(spawn, 3), "coyote time: jump 3 frames (50 ms) after leaving a ledge works")
    _check(not await _coyote_attempt(spawn, 12), "coyote time expires: jump 12 frames (200 ms) after leaving a ledge is ignored")


## One standing jump (Space held 15 frames). If `repress_at` > 0, Space is pressed again
## on that frame (counted from the first press). Returns {landed, rejumped}.
func _jump_cycle(repress_at: int) -> Dictionary:
    _key(KEY_SPACE, true)
    var landed: int = -1
    var rejumped: bool = false
    for frame in range(1, int(2.5 * PHYSICS_HZ)):
        await physics_frame
        if frame == 15:
            _key(KEY_SPACE, false)
        if frame == repress_at:
            _key(KEY_SPACE, true)
        if frame == repress_at + 1:
            _key(KEY_SPACE, false)
        if landed < 0 and frame > 5 and _player.is_on_floor():
            landed = frame
            if repress_at <= 0:
                break
        elif landed > 0 and _player.velocity.y > 5.0:
            rejumped = true
        if landed > 0 and frame > landed + 20:
            break
    _key(KEY_SPACE, false)
    await _seconds(1.2)
    return {"landed": landed, "rejumped": rejumped}


func _m1_buffer_checks() -> void:
    _player.call("teleport_to", Vector3(-16.0, 2.0, 0.0))
    await _seconds(0.6)
    var landing: int = (await _jump_cycle(-1))["landed"]
    _check(landing > 0, "reference jump lands (frame %d)" % landing)
    var early_ok: Dictionary = await _jump_cycle(landing - 5)
    _check(early_ok["rejumped"], "jump buffer: press 5 frames (83 ms) before landing jumps on landing")
    var too_early: Dictionary = await _jump_cycle(landing - 14)
    _check(not too_early["rejumped"], "jump buffer expires: press 14 frames (233 ms) before landing is ignored")


func _m1_dodge_checks() -> void:
    _player.call("teleport_to", Vector3(-16.0, 2.0, 0.0))
    await _seconds(0.6)
    _player.set("facing_direction", 1.0)
    var x0: float = _player.global_position.x
    _tap(KEY_K)
    await physics_frame
    await physics_frame
    _check(bool(_player.call("is_invulnerable")), "dodge grants invulnerability immediately")
    await _seconds(0.25)
    var dx: float = _player.global_position.x - x0
    _check(dx > 2.8, "dodge bursts along facing without input (dx=%.2f)" % dx)
    await _seconds(0.1)
    _check(not bool(_player.call("is_invulnerable")), "invulnerability ends after ~0.28 s")
    var total: float = _player.global_position.x - x0
    _check(total < 4.8, "dodge ends at run speed instead of sliding on (total dx=%.2f)" % total)
    # Pressed inside cooldown (0.45 s from dodge start): must be ignored.
    _tap(KEY_K)
    await physics_frame
    await physics_frame
    _check(not bool(_player.call("is_dodging")), "dodge is ignored while on cooldown")
    await _seconds(0.5)
    _tap(KEY_K)
    await physics_frame
    await physics_frame
    _check(bool(_player.call("is_dodging")), "dodge is available again after cooldown")
    await _seconds(0.6)


func _bind() -> void:
    _main = current_scene as Node3D
    _player = _main.get("player") as CharacterBody3D
    _enemy = _main.get("enemy") as PlaguedSoldier


func _melee() -> MeleeAttack:
    return _player.get("melee") as MeleeAttack


func _player_hp() -> int:
    return (_player.get("health") as Health).current


func _wait_until(cond: Callable, timeout: float) -> bool:
    for i in int(timeout * PHYSICS_HZ):
        await physics_frame
        if cond.call():
            return true
    return false


func _place(player_x: float, enemy_x: float, ai: bool) -> void:
    _enemy.set_ai_enabled(false)
    _player.call("teleport_to", Vector3(player_x, 1.0, 0.0))
    _player.set("facing_direction", 1.0)
    _enemy.teleport_to(Vector3(enemy_x, 1.0, 0.0))
    await _seconds(0.4)
    _enemy.set_ai_enabled(ai)


## Physics frames a phase of `seconds` lasts (phases end on the first tick at/after their time).
func _frames_for(seconds: float) -> int:
    return ceili(seconds * PHYSICS_HZ - 0.001)


func _newest_fx_color() -> Color:
    var fx: Array[Node] = root.get_tree().get_nodes_in_group(&"hit_fx")
    if fx.is_empty():
        return Color(0, 0, 0, 0)
    return fx[fx.size() - 1].get_meta(&"spray_color")


## Light attack timeline with the enemy out of reach: hitbox only live in ACTIVE.
func _m2_attack_phase_checks() -> void:
    await _place(3.2, 11.0, false)
    var hp_start: int = _player_hp()
    _check(hp_start == 5, "player enters combat tests at full HP (hp=%d)" % hp_start)
    var melee: MeleeAttack = _melee()
    var hitbox: Hitbox = melee.hitbox
    var counts: Dictionary = {MeleeAttack.Phase.STARTUP: 0, MeleeAttack.Phase.ACTIVE: 0, MeleeAttack.Phase.RECOVERY: 0}
    var hitbox_wrong: int = 0
    _tap(KEY_J)
    for i in 50:
        await physics_frame
        if melee.phase != MeleeAttack.Phase.IDLE:
            counts[melee.phase] += 1
            if hitbox.is_active() != (melee.phase == MeleeAttack.Phase.ACTIVE):
                hitbox_wrong += 1
    var light: AttackData = _player.get("light_attack")
    var expected: Array[int] = [_frames_for(light.startup), _frames_for(light.active), _frames_for(light.recovery)]
    var got: Array[int] = [counts[MeleeAttack.Phase.STARTUP], counts[MeleeAttack.Phase.ACTIVE], counts[MeleeAttack.Phase.RECOVERY]]
    _check(got == expected, "light attack phases match AttackData exactly: %s frames (expected %s)" % [got, expected])
    _check(hitbox_wrong == 0, "hitbox is live only during ACTIVE (%d wrong frames)" % hitbox_wrong)
    _check(melee.phase == MeleeAttack.Phase.IDLE, "attack returns to idle")
    _check(_enemy.health.current == 3, "whiff out of reach deals no damage")

    # Heavy attack has a longer, committed wind-up.
    var heavy_startup: int = 0
    _tap(KEY_L)
    for i in 60:
        await physics_frame
        if melee.phase == MeleeAttack.Phase.STARTUP:
            heavy_startup += 1
    var heavy: AttackData = _player.get("heavy_attack")
    _check(heavy_startup == _frames_for(heavy.startup) and heavy_startup > expected[0] * 2, "heavy startup is %d frames, matching data and over twice the light wind-up" % heavy_startup)

    # Cancel rules: dodge cancels light RECOVERY, but not STARTUP.
    _player.call("teleport_to", Vector3(3.2, 1.0, 0.0))
    await _seconds(0.6)
    _tap(KEY_J)
    await physics_frame
    await physics_frame
    _tap(KEY_K)
    await physics_frame
    await physics_frame
    _check(not bool(_player.call("is_dodging")) and melee.is_busy(), "dodge cannot cancel attack STARTUP")
    await _wait_until(func() -> bool: return melee.phase == MeleeAttack.Phase.RECOVERY, 1.0)
    _tap(KEY_K)
    await physics_frame
    await physics_frame
    _check(bool(_player.call("is_dodging")) and not melee.is_busy(), "dodge cancels light attack RECOVERY")
    await _seconds(0.8)
    # Attack buffer: a press during the last frames of an attack fires when it ends.
    var started: Array[StringName] = []
    var on_start: Callable = func(id: StringName) -> void: started.append(id)
    _player.connect("attack_started", on_start)
    _tap(KEY_J)
    await _wait_until(func() -> bool: return melee.phase == MeleeAttack.Phase.RECOVERY, 1.0)
    await _seconds(0.12)
    _tap(KEY_L)
    await _seconds(0.9)
    _check(started == [&"player_light", &"player_heavy"], "attack pressed during recovery is buffered and fires (%s)" % [started])
    await _wait_until(func() -> bool: return not melee.is_busy(), 2.0)
    await _seconds(0.2)
    started.clear()
    _tap(KEY_J)
    await physics_frame
    await physics_frame
    _tap(KEY_L)
    await _seconds(1.2)
    _player.disconnect("attack_started", on_start)
    _check(started == [&"player_light"], "a press far outside the buffer window is dropped (%s)" % [started])
    await _seconds(0.8)
    _check(_player_hp() == hp_start, "no unintended damage during attack/dodge tests (hp=%d)" % _player_hp())


## Soldier AI: telegraph → strike that really damages, then a dodge with i-frames through it.
func _m2_enemy_attack_checks() -> void:
    await _place(3.2, 5.5, true)
    var em: MeleeAttack = _enemy.melee
    var states_seen: Array[String] = []
    _enemy.state_changed.connect(func(n: String) -> void: states_seen.append(n))
    var hp0: int = _player_hp()
    var startup_frame: int = -1
    var active_frame: int = -1
    var marker_shown: bool = false
    var frame: int = 0
    var hit_x_before: float = 0.0
    while frame < int(4.0 * PHYSICS_HZ):
        await physics_frame
        frame += 1
        if startup_frame < 0 and em.phase == MeleeAttack.Phase.STARTUP:
            startup_frame = frame
        if em.phase == MeleeAttack.Phase.STARTUP and _enemy.telegraph_marker.visible:
            marker_shown = true
        if active_frame < 0 and em.phase == MeleeAttack.Phase.ACTIVE:
            active_frame = frame
            hit_x_before = _player.global_position.x
        if _player_hp() < hp0:
            break
    _check("CHASE" in states_seen and "ATTACK" in states_seen, "soldier aggroes and attacks (states %s)" % [states_seen])
    _check(startup_frame > 0 and active_frame - startup_frame >= 30, "telegraph precedes the strike by %d frames (>= 30)" % (active_frame - startup_frame))
    _check(marker_shown, "telegraph shows the red danger marker")
    _check(_player_hp() == hp0 - 1, "soldier slash damages the player (%d → %d)" % [hp0, _player_hp()])
    await physics_frame
    _check(bool(_player.call("is_invulnerable")) and bool(_player.call("is_stunned")), "player gets hitstun and post-hit invulnerability")
    await _seconds(0.3)
    _check(_player.global_position.x < hit_x_before - 0.5, "player is knocked away from the soldier (dx=%.2f)" % (_player.global_position.x - hit_x_before))
    var c: Color = _newest_fx_color()
    _check(c.r > 0.4 and c.g < 0.1, "hit spawns a blood spray (color=%s)" % c)
    await _shot("02_soldier_hit")

    # Dodge into the next strike: i-frames must absorb it.
    var started: bool = await _wait_until(func() -> bool: return em.phase == MeleeAttack.Phase.STARTUP, 5.0)
    _check(started, "soldier winds up again")
    var hp1: int = _player_hp()
    await _seconds(0.45)
    _player.set("facing_direction", signf(_enemy.global_position.x - _player.global_position.x))
    _tap(KEY_K)
    await _wait_until(func() -> bool: return em.phase == MeleeAttack.Phase.RECOVERY, 1.0)
    _check(_player_hp() == hp1, "dodge i-frames absorb the telegraphed strike (hp %d → %d)" % [hp1, _player_hp()])
    _enemy.set_ai_enabled(false)
    await _seconds(1.2)


## Lethal damage from the soldier respawns the player at the checkpoint with full health.
func _m2_player_death_check(cp_pos: Vector3) -> void:
    var health: Health = _player.get("health")
    await _place(3.2, 4.6, false)
    health.apply_damage(health.current - 1)  # debug setup: one hit from death
    _enemy.set_ai_enabled(true)
    var revived: bool = await _wait_until(func() -> bool: return health.current == health.max_health and _player.global_position.distance_to(cp_pos) < 1.0, 4.0)
    _enemy.set_ai_enabled(false)
    _check(revived, "dying to the soldier revives at the checkpoint with full HP (hp=%d pos=%s)" % [health.current, _player.global_position])
    await _seconds(0.5)


func _m2_contact_damage_check() -> void:
    await _place(3.2, 5.0, false)
    await _seconds(0.9)
    var hp0: int = _player_hp()
    await _hold(KEY_D, 0.6)
    _check(_player_hp() == hp0 - 1, "walking into the soldier deals contact damage (%d → %d)" % [hp0, _player_hp()])
    await _seconds(1.0)


## Player stands beyond the soldier's patrol zone, inside aggro range: it must chase, then
## stop at its leash (patrol_max_x + leash_margin) instead of following. On the left side the
## raised step already blocks it; this side is open floor, so only the leash can stop it.
func _m2_leash_check() -> void:
    await _place(13.0, 7.5, true)
    var highest_x: float = _enemy.global_position.x
    var chased: bool = false
    for i in int(3.0 * PHYSICS_HZ):
        await physics_frame
        highest_x = maxf(highest_x, _enemy.global_position.x)
        chased = chased or _enemy.state_name() == "CHASE"
    _enemy.set_ai_enabled(false)
    var limit: float = _enemy.patrol_max_x + _enemy.leash_margin
    _check(chased, "soldier chases a player beyond its patrol zone")
    _check(highest_x <= limit + 0.1 and highest_x > limit - 0.3, "soldier stops at its leash (max x=%.2f, leash=%.2f)" % [highest_x, limit])
    await _seconds(0.5)


func _m2_player_hits_enemy_checks() -> void:
    await _place(3.2, 4.3, false)
    _player.set("facing_direction", -1.0)
    _tap(KEY_J)
    await _seconds(0.6)
    _check(_enemy.health.current == 3, "attacking while facing away misses")

    _player.set("facing_direction", 1.0)
    var ex: float = _enemy.global_position.x
    var stunned: bool = false
    _tap(KEY_J)
    for i in 30:
        await physics_frame
        stunned = stunned or _enemy.state_name() == "HITSTUN"
    _check(_enemy.health.current == 2, "light attack deals 1 damage (hp=%d)" % _enemy.health.current)
    _check(stunned, "hit soldier enters HITSTUN")
    _check(_enemy.global_position.x > ex + 0.3, "hit soldier is knocked back (dx=%.2f)" % (_enemy.global_position.x - ex))
    var c: Color = _newest_fx_color()
    _check(c.r > 0.4 and c.g < 0.1, "default spray is blood red")

    GameSettings.reduced_gore = true
    await _place(3.2, 4.3, false)
    _tap(KEY_J)
    await _seconds(0.5)
    c = _newest_fx_color()
    GameSettings.reduced_gore = false
    _check(_enemy.health.current == 1, "second light hit lands (hp=%d)" % _enemy.health.current)
    _check(c.r < 0.3 and absf(c.r - c.b) < 0.1, "reduced-gore spray is ash grey (color=%s)" % c)

    await _place(3.2, 4.4, false)
    _tap(KEY_L)
    await _seconds(1.0)
    _check(_enemy.health.current == 0 and _enemy.state_name() == "DEAD", "heavy attack deals 2 damage and kills (hp=%d, state=%s)" % [_enemy.health.current, _enemy.state_name()])
    _check(not bool(_main.get("enemy_alive")), "level registers the soldier as defeated")
    _check(_enemy.collision_layer == 0 and not _enemy.hurtbox.monitorable, "corpse no longer blocks or takes hits")
    await _shot("03_soldier_dead")


func _check(ok: bool, label: String) -> void:
    _checks += 1
    if ok:
        print("PASS  ", label)
    else:
        _failures += 1
        printerr("FAIL  ", label)


func _key(code: Key, pressed: bool) -> void:
    var ev: InputEventKey = InputEventKey.new()
    ev.keycode = code
    ev.physical_keycode = code
    ev.pressed = pressed
    Input.parse_input_event(ev)


func _tap(code: Key) -> void:
    _key(code, true)
    # Release on the next physics tick so edge-triggered jump logic sees the press.
    (func() -> void:
        await physics_frame
        await physics_frame
        _key(code, false)).call()


func _hold(code: Key, seconds: float) -> void:
    _key(code, true)
    await _seconds(seconds)
    _key(code, false)


func _seconds(seconds: float) -> void:
    for i in int(seconds * PHYSICS_HZ):
        await physics_frame
        _track_z()


func _frames(n: int) -> void:
    for i in n:
        await process_frame


func _track_z() -> void:
    if is_instance_valid(_player) and not bool(_player.get("in_3d_mode")):
        _max_abs_z_in_2d = maxf(_max_abs_z_in_2d, absf(_player.global_position.z))


## Holds D, jumping at known gap edges or when blocked by a wall, until x >= target.
func _run_right_until(target_x: float, timeout: float) -> bool:
    _key(KEY_D, true)
    var jump_frames_left: int = 0
    var ok: bool = false
    for i in int(timeout * PHYSICS_HZ):
        await physics_frame
        _track_z()
        var x: float = _player.global_position.x
        if x >= target_x:
            ok = true
            break
        var near_gap: bool = not _floor_ahead(0.8)
        if jump_frames_left > 0:
            jump_frames_left -= 1
            if jump_frames_left == 0:
                _key(KEY_SPACE, false)
        elif _player.is_on_floor() and (near_gap or _player.is_on_wall()):
            _key(KEY_SPACE, true)
            jump_frames_left = 24
    _key(KEY_D, false)
    _key(KEY_SPACE, false)
    return ok


## True if there is walkable ground within 1.2 m below a point `dist` ahead of the player.
## (Short on purpose: a rubble ledge 1 m down does not count, so the run jumps the full gap.)
func _floor_ahead(dist: float) -> bool:
    var from: Vector3 = _player.global_position + Vector3(dist, 0.0, 0.0)
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -1.2, 0.0))
    query.exclude = [_player.get_rid()]
    return not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _heal() -> void:
    (_player.get("health") as Health).restore_full()


func _boss_idle(boss: HollowBishop) -> void:
    await _wait_until(func() -> bool: return not boss.is_attacking(), 8.0)


func _first_lance() -> BoneLance:
    var lances: Array[Node] = root.get_tree().get_nodes_in_group(&"boss_lance")
    return lances[0] as BoneLance if not lances.is_empty() else null


func _cards() -> CardSystem:
    return _player.get_node("Cards") as CardSystem


func _energy() -> BloodEnergy:
    return _player.get_node("BloodEnergy") as BloodEnergy


func _slot_of(id: StringName) -> int:
    var hand: Array[CardData] = _cards().deck.hand
    for i in hand.size():
        if hand[i] != null and hand[i].id == id:
            return i
    return -1


func _hand_ids() -> Array[StringName]:
    var ids: Array[StringName] = []
    for card: CardData in _cards().deck.hand:
        ids.append(card.id if card else &"")
    return ids


func _m4_data_and_deck_checks() -> void:
    var spear: CardData = load("res://resources/cards/blood_spear.tres")
    var shield: CardData = load("res://resources/cards/grave_shield.tres")
    var chains: CardData = load("res://resources/cards/ritual_chains.tres")
    _check([spear.cost, shield.cost, chains.cost] == [2, 2, 3], "card costs come from CardData resources (2/2/3)")
    _check(spear.targeting == CardData.Targeting.BOSS_WEAK_POINT and shield.targeting == CardData.Targeting.SELF and chains.targeting == CardData.Targeting.BOSS_TELEGRAPH,
        "card targeting rules come from data")
    var ids: Array[String] = []
    for id: StringName in _hand_ids():
        ids.append(String(id))
    ids.sort()  # StringName sorts by pointer; compare as Strings
    _check(ids == ["blood_spear", "grave_shield", "ritual_chains"], "starting hand holds the three starter cards (%s)" % [ids])

    var pool: Array[CardData] = []
    for i in 10:
        var card: CardData = CardData.new()
        card.id = StringName("test_%d" % i)
        pool.append(card)
    var sequences: Array = []
    for seed_value: int in [42, 42, 7]:
        var deck: CardDeck = CardDeck.new()
        deck.setup(pool, seed_value, 3)
        var order: Array[StringName] = []
        for card: CardData in deck.hand:
            order.append(card.id)
        for i in 12:
            deck.play_slot(i % 3)
            order.append(deck.hand[i % 3].id)  # the card drawn into the freed slot
        sequences.append(order)
        if seed_value == 7:
            _check(deck.total_cards() == 10, "draw/discard/reshuffle conserves all 10 cards")
    _check(sequences[0] == sequences[1], "same seed deals the identical sequence")
    _check(sequences[0] != sequences[2], "a different seed deals a different sequence")
    var first_ten: Dictionary = {}
    for i in 10:
        first_ten[sequences[0][i]] = true
    _check(first_ten.size() == 10, "every card is dealt once before any repeats")


func _m4_card_checks(boss: HollowBishop) -> void:
    var cards: CardSystem = _cards()
    var energy: BloodEnergy = _energy()
    var ui: CardHandUI = _main.find_child("CardHand", true, false) as CardHandUI
    energy.regen_per_second = 0.0  # exact energy accounting for these checks
    var spear_slot: int = _slot_of(&"blood_spear")
    var shield_slot: int = _slot_of(&"grave_shield")
    var chains_slot: int = _slot_of(&"ritual_chains")
    var hand_before: Array[StringName] = _hand_ids()
    _check(ui != null and ui.slots.size() == 3, "card hand UI shows three slots")

    # Invalid plays spend nothing and apply nothing.
    _heal()
    _player.call("teleport_to", Vector3(24.2, 1.0, 0.0))
    await _seconds(0.5)
    energy.set_amount(6.0)
    var spear_card: CardData = cards.deck.card_in_slot(spear_slot)
    _check(cards.play_slot(spear_slot) == &"no_target" and energy.current == 6.0 and cards.cooldown_left(spear_card) == 0.0
        and root.get_tree().get_nodes_in_group(&"blood_spear").is_empty(), "Blood Spear with no exposed weak point is refused, nothing spent")
    _check(cards.play_slot(chains_slot) == &"no_target" and energy.current == 6.0, "Ritual Chains with nothing to interrupt is refused, nothing spent")
    energy.set_amount(1.0)
    _check(cards.play_slot(shield_slot) == &"energy" and energy.current == 1.0 and not bool(_player.call("is_shielded")),
        "unaffordable Grave Shield is refused, no shield, nothing spent")
    await _frames(2)
    _check(ui.slots[shield_slot].modulate.a < 0.9 and "NEED BLOOD" in ui._status_labels[shield_slot].text, "UI dims the unaffordable card and flashes NEED BLOOD")

    # Grave Shield through the real key binding; absorbs one heavy slam.
    energy.set_amount(6.0)
    _tap(CARD_KEYS[shield_slot])
    await _frames(3)
    _check(bool(_player.call("is_shielded")) and energy.current == 4.0, "key %d plays Grave Shield: shield up, 2 blood spent" % (shield_slot + 1))
    _check(cards.play_slot(shield_slot) == &"cooldown" and energy.current == 4.0, "replaying during cooldown is refused, nothing spent")
    await _frames(2)
    _check("COOLING" in ui._status_labels[shield_slot].text, "UI flashes COOLING on a refused replay")
    await _seconds(0.9)  # let the failure flash end
    _check(ui.slots[shield_slot].modulate.a < 0.9 and "s" in ui._status_labels[shield_slot].text, "UI shows the cooldown timer")
    boss.debug_attack(&"slam", 24.2)
    await _boss_idle(boss)
    _check(_player_hp() == 5 and not bool(_player.call("is_shielded")), "Grave Shield absorbs the slam and is consumed (hp=%d)" % _player_hp())
    _player.call("raise_shield", &"heavy", 3.0)
    boss.debug_attack(&"lance", 24.2)
    await _boss_idle(boss)
    _check(_player_hp() == 4, "the heavy-only ward does not stop a lance (projectile) (hp=%d)" % _player_hp())

    # Ritual Chains interrupts the telegraph: the player beneath takes nothing.
    _heal()
    _player.call("teleport_to", Vector3(24.2, 1.0, 0.0))
    _player.set("facing_direction", 1.0)
    await _seconds(1.0)
    energy.set_amount(6.0)
    var boss_hp0: int = boss.health.current
    boss.debug_attack(&"slam", 24.2)
    await _seconds(0.8)
    _check(boss.can_be_interrupted(), "hovering slam is interruptible")
    _tap(CARD_KEYS[chains_slot])
    await _frames(3)
    _check(boss.current_attack() == &"chained" and energy.current == 3.0, "key %d plays Ritual Chains: slam bound, 3 blood spent" % (chains_slot + 1))
    var slam_live: bool = false
    for i in 60:
        await physics_frame
        slam_live = slam_live or boss.hand.hitbox.is_active()
        if boss.hand.weak_open:
            break
    _check(not slam_live and _player_hp() == 5, "chained hand never becomes a hitbox; player beneath unhurt")
    _check(boss.hand.weak_open, "chains drag the hand down with the stigmata exposed")
    await _shot("07_chained")
    _tap(KEY_J)
    await _seconds(0.5)
    _check(boss.health.current == boss_hp0 - 1 and energy.current == 4.0, "melee hit on the stigmata damages the Bishop and earns 1 blood (energy=%.1f)" % energy.current)

    # Blood Spear: range check, then a real projectile into the exposed stigmata.
    _player.call("teleport_to", Vector3(44.0, 1.0, 0.0))
    await _seconds(0.2)
    _check(cards.play_slot(spear_slot) == &"out_of_range" and energy.current == 4.0, "Blood Spear beyond its 14 m range is refused, nothing spent")
    _player.call("teleport_to", Vector3(33.0, 1.0, 0.0))
    await _seconds(0.2)
    var boss_hp1: int = boss.health.current
    _check(cards.play_slot(spear_slot) == &"ok" and energy.current == 2.0, "Blood Spear at an exposed stigmata in range is played, 2 blood spent")
    _check(root.get_tree().get_nodes_in_group(&"blood_spear").size() == 1, "Blood Spear launches a projectile")
    await _seconds(0.6)
    _check(boss.health.current == boss_hp1 - 2, "the spear flies to the stigmata and deals 2 (%d → %d)" % [boss_hp1, boss.health.current])
    _check(root.get_tree().get_nodes_in_group(&"blood_spear").is_empty(), "spent spear is cleaned up")
    await _boss_idle(boss)
    _check(not boss.can_be_interrupted(), "nothing is interruptible once the Bishop is idle")
    _check(_hand_ids() == hand_before, "played cards return to the same slots (%s)" % [_hand_ids()])
    energy.regen_per_second = 0.25


func _m5_fracture_checks() -> void:
    var fracture: RealityFracture = _main.get("fracture")
    var guardian: PlaguedSoldier = fracture.guardian
    var energy: BloodEnergy = _energy()
    var cards: CardSystem = _cards()
    var cam: Camera3D = _main.get("camera")
    guardian.set_ai_enabled(false)
    energy.regen_per_second = 0.0
    var entry_x: float = _player.global_position.x
    var shield_slot: int = _slot_of(&"grave_shield")
    var shield_card: CardData = cards.deck.card_in_slot(shield_slot)
    energy.set_amount(4.0)
    _check(cards.play_slot(shield_slot) == &"ok", "Grave Shield played before crossing (puts it on cooldown)")
    var hp_before: int = _player_hp()

    # Transition in: fade covers the teleport, input frozen, then free X/Z control.
    _tap(KEY_E)
    await _frames(6)
    _check(fracture.is_transitioning() and bool(_player.get("game_frozen")), "E at the gate starts the fracture transition with input frozen")
    var max_alpha: float = 0.0
    for i in 120:
        await process_frame
        max_alpha = maxf(max_alpha, fracture.fade.color.a)
        if fracture.state == RealityFracture.State.ACTIVE:
            break
    _check(max_alpha >= 0.99 and fracture.fade.color.a < 0.01, "screen fades fully to black over the teleport, then back (max alpha=%.2f)" % max_alpha)
    _check(fracture.state == RealityFracture.State.ACTIVE and bool(_player.get("in_3d_mode")) and not bool(_player.get("game_frozen")), "transition completes into the fracture with control restored")
    _check(_player_hp() == hp_before and is_equal_approx(energy.current, 2.0) and cards.cooldown_left(shield_card) > 4.5,
        "HP, blood energy and card cooldowns carry into 3D (hp=%d, blood=%.1f, cd=%.1f)" % [_player_hp(), energy.current, cards.cooldown_left(shield_card)])
    _check(bool(_main.get("arena_visited")), "fracture flagged as visited")
    await _seconds(1.5)
    _check(_player.is_on_floor(), "player stands on the chapel floor")
    var arena_offset: Vector3 = cam.global_position - _player.global_position
    _check(absf(arena_offset.z - 11.5) < 1.0 and absf(arena_offset.y - 5.8) < 1.0, "camera eases into the closer 3D framing (offset=%s)" % arena_offset)
    await _shot("04_fracture")

    # Free X/Z locomotion (same checks as the M0 arena).
    var z0: float = _player.global_position.z
    await _hold(KEY_W, 0.5)
    var z1: float = _player.global_position.z
    _check(z1 < z0 - 1.5, "W moves into depth in the fracture (dz=%.2f)" % (z1 - z0))
    await _hold(KEY_S, 0.8)
    var z2: float = _player.global_position.z
    _check(z2 > z1 + 2.0, "S moves toward the camera (dz=%.2f)" % (z2 - z1))
    await _hold(KEY_D, 0.4)
    _check(absf(_player.global_position.z - fracture.center.z) > 0.2, "depth position persists while strafing")
    await _seconds(0.5)
    var z_before_dodge: float = _player.global_position.z
    _key(KEY_W, true)
    await physics_frame
    _tap(KEY_K)
    await _seconds(0.25)
    _key(KEY_W, false)
    _check(_player.global_position.z < z_before_dodge - 2.8, "dodge follows input direction in 3D (dz=%.2f)" % (_player.global_position.z - z_before_dodge))
    await _seconds(0.5)
    _tap(KEY_E)
    await _seconds(0.8)
    _check(bool(_player.get("in_3d_mode")) and not fracture.portal_open, "E cannot leave while the guardian lives; portal sealed")

    # The guardian fights in depth: chases on X/Z, telegraphs, hits, knocks back along X/Z.
    _heal()
    _player.call("teleport_to", fracture.center + Vector3(-2.0, 1.0, 2.0))
    guardian.revive_at_home()
    await _seconds(0.4)
    var home_z: float = guardian.global_position.z
    var states_seen: Array[String] = []
    var on_state: Callable = func(n: String) -> void: states_seen.append(n)
    guardian.state_changed.connect(on_state)
    guardian.set_ai_enabled(true)
    var hp0: int = _player_hp()
    var max_dz: float = 0.0
    var hit_pos: Vector3 = Vector3.ZERO
    for i in int(5.0 * PHYSICS_HZ):
        await physics_frame
        max_dz = maxf(max_dz, absf(guardian.global_position.z - home_z))
        if _player_hp() < hp0:
            hit_pos = _player.global_position
            break
    await _seconds(0.3)
    var pushed: Vector3 = _player.global_position - hit_pos
    guardian.set_ai_enabled(false)
    guardian.state_changed.disconnect(on_state)
    _check("CHASE" in states_seen and "ATTACK" in states_seen, "guardian aggroes and attacks in 3D (%s)" % [states_seen])
    _check(max_dz > 0.8, "guardian chases across depth (max dz=%.2f)" % max_dz)
    _check(_player_hp() == hp0 - 1, "guardian's slash damages the player (%d → %d)" % [hp0, _player_hp()])
    _check(absf(pushed.z) > 0.2 and absf(pushed.x) > 0.2, "3D knockback pushes the player along X and Z (%s)" % pushed)
    await _seconds(1.0)

    # Dying inside expels the player to the entry spot, healed, and resets the guardian.
    var player_health: Health = _player.get("health")
    guardian.health.apply_damage(2)  # debug setup: wounded guardian, so the reset is observable
    player_health.apply_damage(player_health.current - 1)  # debug setup: one hit from death
    _player.call("teleport_to", guardian.global_position + Vector3(-1.3, 0.0, 0.0))
    guardian.set_ai_enabled(true)
    var expelled: bool = await _wait_until(func() -> bool: return fracture.state == RealityFracture.State.IDLE and not bool(_player.get("game_frozen")), 6.0)
    _check(expelled and not bool(_player.get("in_3d_mode")), "dying in the fracture expels the player back to 2.5D")
    _check(absf(_player.global_position.x - entry_x) < 0.3 and absf(_player.global_position.z) < 0.001, "expelled to the exact entry spot (x=%.2f vs %.2f, z=%.3f)" % [_player.global_position.x, entry_x, _player.global_position.z])
    _check(player_health.current == player_health.max_health, "expelled player is healed")
    _check(guardian.health.current == guardian.health.max_health and not fracture.portal_open and fracture.can_enter(), "guardian resets to full HP and the fracture can be retried")

    # Re-enter, and win with soft lock-on.
    _tap(KEY_E)
    var back_in: bool = await _wait_until(func() -> bool: return fracture.state == RealityFracture.State.ACTIVE, 2.0)
    _check(back_in, "the fracture can be re-entered after a failure")
    guardian.set_ai_enabled(false)
    _player.call("teleport_to", fracture.center + Vector3(0.0, 1.0, 0.0))
    guardian.teleport_to(fracture.center + Vector3(0.3, 1.0, -1.2))
    await _seconds(0.5)
    _key(KEY_D, true)
    await physics_frame
    await physics_frame
    _key(KEY_D, false)
    await _seconds(0.3)
    _tap(KEY_J)
    await _seconds(0.5)
    var facing: Vector3 = _player.call("get_facing_vector")
    _check(guardian.health.current == 2 and facing.z < -0.5, "soft lock-on turns an undirected attack onto the guardian (hp=%d, facing=%s)" % [guardian.health.current, facing])
    _tap(KEY_L)
    await _seconds(1.0)
    _check(guardian.is_dead() and fracture.portal_open, "heavy hit slays the guardian and the return portal opens")
    await _shot("05_fracture_cleared")

    # Walk into the portal: back to the entry spot, rewarded, fracture sealed.
    player_health.apply_damage(2)
    energy.set_amount(1.0)
    _player.call("teleport_to", fracture.portal.global_position + Vector3(2.0, -0.4, -2.0))
    await _seconds(0.4)
    _key(KEY_A, true)
    _key(KEY_S, true)
    await _wait_until(func() -> bool: return fracture.is_transitioning(), 2.0)
    _key(KEY_A, false)
    _key(KEY_S, false)
    var home: bool = await _wait_until(func() -> bool: return fracture.state == RealityFracture.State.CLEARED and not bool(_player.get("game_frozen")), 3.0)
    _check(home and not bool(_player.get("in_3d_mode")), "walking into the open portal returns to 2.5D")
    _check(absf(_player.global_position.x - entry_x) < 0.3 and absf(_player.global_position.z) < 0.001, "returned to the exact entry spot (x=%.2f)" % _player.global_position.x)
    _check(player_health.current == player_health.max_health and is_equal_approx(energy.current, 4.0), "clearing the fracture heals fully and grants 3 blood (blood=%.1f)" % energy.current)
    await _seconds(1.5)
    var side_offset: Vector3 = cam.global_position - _player.global_position
    _check(absf(side_offset.z - 22.0) < 1.0, "camera returns to side-view framing (offset=%s)" % side_offset)
    _tap(KEY_E)
    await _seconds(0.6)
    _check(not bool(_player.get("in_3d_mode")) and not fracture.can_enter(), "a cleared fracture stays sealed")
    energy.regen_per_second = 0.25


func _m3_boss_checks() -> void:
    var boss: HollowBishop = _main.get("boss")
    var arena: BossArena = _main.get("boss_arena")
    _check(boss.phase_name() == "DORMANT", "Bishop lies dormant before the arena")
    _heal()
    var reached: bool = await _run_right_until(21.5, 5.0)
    _check(reached, "open portcullis leads into the Bishop's arena (x=%.2f)" % _player.global_position.x)
    _check(bool((_main.get("boss_checkpoint") as Checkpoint).is_active), "arena checkpoint activates")
    _check(boss.phase_name() == "INTRO", "entering the arena awakens the Bishop (phase=%s)" % boss.phase_name())
    boss.set_ai_enabled(false)
    await _seconds(1.8)
    _check(boss.phase_name() == "PROCESSION", "Bishop rises into phase I (phase=%s)" % boss.phase_name())
    var bar: ProgressBar = _main.get("boss_bar")
    _check(bar.get_parent().visible and bar.value == 12 and bar.max_value == 12, "boss HP bar shows 12/12")
    await _boss_idle(boss)
    _check(boss.global_position.z < -20.0 and boss.global_position.y > -1.0, "Bishop stands far behind the play plane (z=%.1f)" % boss.global_position.z)
    await _shot("05_bishop_awake")

    # Hand Slam on a standing player: long telegraph, travels from depth, real damage.
    _heal()
    _player.call("teleport_to", Vector3(24.2, 1.0, 0.0))
    await _seconds(0.5)
    var hp0: int = _player_hp()
    boss.debug_attack(&"slam", 24.2)
    var marker_lead: int = 0
    var min_hand_z: float = 0.0
    var impact_z: float = 99.0
    var plate_x: float = 0.0
    for i in 400:
        await physics_frame
        if not boss.is_attacking():
            break
        min_hand_z = minf(min_hand_z, boss.hand.global_position.z)
        if impact_z == 99.0:
            if boss.hand.marker.visible:
                marker_lead += 1
                plate_x = boss.hand.marker.global_position.x
            if boss.hand.hitbox.is_active():
                impact_z = boss.hand.global_position.z
    _check(marker_lead >= 80, "slam telegraph plate shows %d frames before impact (>= 80)" % marker_lead)
    _check(absf(plate_x - 24.2) < 0.01, "telegraph plate marks the strike x (%.2f)" % plate_x)
    _check(min_hand_z < -7.5 and absf(impact_z) < 0.05, "hand travels from depth (z=%.1f) to the play plane (z=%.2f)" % [min_hand_z, impact_z])
    _check(_player_hp() == hp0 - 2, "slam deals 2 damage to a player who stays (%d → %d)" % [hp0, _player_hp()])

    # Same slam, but the player steps out of the plate during the telegraph.
    _heal()
    _player.call("teleport_to", Vector3(24.2, 1.0, 0.0))
    await _seconds(1.0)
    boss.debug_attack(&"slam", 24.2)
    await _seconds(0.5)
    await _hold(KEY_D, 0.7)
    await _boss_idle(boss)
    _check(_player_hp() == 5, "stepping off the telegraphed plate avoids the slam (hp=%d)" % _player_hp())

    # Weak point: only the exposed stigmata on the fallen hand takes damage.
    _heal()
    _player.call("teleport_to", Vector3(28.0, 1.0, 0.0))
    await _seconds(0.5)
    var boss_hp: int = boss.health.current
    boss.debug_attack(&"slam", 25.5)
    _check(not boss.hand.weak_open, "stigmata is closed while the hand is raised")
    var opened: bool = await _wait_until(func() -> bool: return boss.hand.weak_open, 3.0)
    _check(opened, "stigmata opens once the hand lies on the causeway")
    await _shot("06_weak_point")
    _player.set("facing_direction", -1.0)
    _tap(KEY_J)
    await _seconds(0.45)
    _check(boss.health.current == boss_hp - 1, "light hit on the stigmata damages the Bishop (%d → %d)" % [boss_hp, boss.health.current])
    _tap(KEY_L)
    await _seconds(0.9)
    _check(boss.health.current == boss_hp - 3, "heavy hit deals 2 more (hp=%d)" % boss.health.current)
    await _wait_until(func() -> bool: return not boss.hand.weak_open, 4.0)
    var phase1_window: float = boss.weak_open_seconds
    _check(absf(phase1_window - boss.weak_window) < 0.05, "phase I weak window lasts %.2f s" % phase1_window)
    _player.set("facing_direction", -1.0)
    _tap(KEY_J)
    await _seconds(0.4)
    _check(boss.health.current == boss_hp - 3, "closed stigmata ignores hits (hp=%d)" % boss.health.current)
    await _boss_idle(boss)

    # Bone Lance: thrown from depth along a telegraphed lane; hits only on the plane.
    _heal()
    _player.call("teleport_to", Vector3(30.2, 1.0, 0.0))
    await _seconds(0.5)
    hp0 = _player_hp()
    boss.debug_attack(&"lance", 30.2)
    await _wait_until(func() -> bool: return _first_lance() != null, 1.0)
    var lance: BoneLance = _first_lance()
    _check(lance != null and lance.shaft_z() < -15.0 and lance.column.visible and absf(lance.global_position.x - 30.2) < 0.01,
        "lance starts deep behind the plane with a lane telegraph at x=30.2")
    var z_at_hit: float = 99.0
    for i in 180:
        await physics_frame
        if _player_hp() < hp0:
            z_at_hit = lance.shaft_z() if is_instance_valid(lance) else 99.0
            break
    _check(_player_hp() == hp0 - 1 and absf(z_at_hit) < 2.0, "lance hits a player standing in its lane on the plane (hp %d → %d, z=%.2f)" % [hp0, _player_hp(), z_at_hit])
    await _boss_idle(boss)

    _heal()
    _player.call("teleport_to", Vector3(30.2, 1.0, 0.0))
    await _seconds(1.0)
    boss.debug_attack(&"lance", 30.2)
    await _wait_until(func() -> bool: var l: BoneLance = _first_lance(); return l != null and l.shaft_z() > -5.0, 3.0)
    _key(KEY_SPACE, true)
    await _seconds(0.45)
    _key(KEY_SPACE, false)
    await _boss_idle(boss)
    _check(_player_hp() == 5, "jumping over the lance avoids it (hp=%d)" % _player_hp())

    _player.call("teleport_to", Vector3(30.2, 1.0, 0.0))
    await _seconds(0.6)
    boss.debug_attack(&"lance", 30.2)
    await _wait_until(func() -> bool: var l: BoneLance = _first_lance(); return l != null and l.shaft_z() > -3.0, 3.0)
    _tap(KEY_K)
    await _boss_idle(boss)
    _check(_player_hp() == 5, "dodging out of the lane avoids the lance (hp=%d)" % _player_hp())

    # AI on its own: chooses both attack types in phase I.
    _heal()
    _player.call("teleport_to", Vector3(30.2, 1.0, 0.0))
    var seen: Dictionary = {}
    var record: Callable = func(attack: StringName) -> void: seen[attack] = true
    boss.attack_started.connect(record)
    boss.set_ai_enabled(true)
    await _seconds(10.0)
    boss.set_ai_enabled(false)
    boss.attack_started.disconnect(record)
    _check(seen.has(&"slam") and seen.has(&"lance_volley"), "Bishop AI alternates Hand Slam and Bone Lances (%s)" % [seen.keys()])
    await _boss_idle(boss)
    await _seconds(1.0)

    # --- M4 Bloodbound Cards in the real boss fight -------------------------------
    await _m4_card_checks(boss)

    # Phase II: Sunder breaks the causeway; the route stays recoverable.
    boss.health.apply_damage(boss.health.current - boss.collapse_at)  # debug: jump to the phase threshold
    await _frames(2)
    _check(boss.phase_name() == "COLLAPSE" and "II" in (_main.get("boss_label") as Label).text, "HP %d enters phase II, shown on the bar" % boss.health.current)
    _heal()
    _player.call("teleport_to", Vector3(21.0, 1.0, 0.0))
    await _seconds(0.5)
    boss.debug_attack(&"sunder", 28.2)
    await _wait_until(func() -> bool: return arena.segments[2].is_broken, 4.0)
    _check(arena.segments[2].is_broken and arena.rubble[2].visible, "Sunder breaks the struck segment and exposes a rubble ledge")
    _check(not arena.can_break(1) and not arena.can_break(3) and not arena.can_break(0), "neighbours of a gap and the entry segment cannot break")
    await _boss_idle(boss)
    await _shot("07_causeway_broken")
    _player.call("teleport_to", Vector3(21.0, 1.0, 0.0))
    await _seconds(0.4)
    reached = await _run_right_until(33.0, 5.0)
    _check(reached and arena.segments[2].is_broken, "player jumps the broken segment (x=%.2f)" % _player.global_position.x)
    _player.call("teleport_to", Vector3(28.2, 0.5, 0.0))
    await _seconds(0.8)
    _check(_player.is_on_floor() and _player.global_position.y < 0.0, "rubble ledge catches a player who drops in (y=%.2f)" % _player.global_position.y)
    reached = await _run_right_until(31.5, 3.0)
    _check(reached, "player climbs out of the gap from the rubble (x=%.2f)" % _player.global_position.x)
    _player.call("teleport_to", Vector3(26.9, -2.0, 0.0))
    var cp: Vector3 = (_main.get("boss_checkpoint") as Checkpoint).respawn_position
    var reset: bool = await _wait_until(func() -> bool: return _player.global_position.distance_to(cp) < 1.0, 3.0)
    await _seconds(0.1)
    _check(reset and not arena.segments[2].is_broken, "falling respawns at the arena checkpoint and reknits the causeway")

    # Phase III: longer weak window; finish the Bishop through the stigmata.
    boss.health.apply_damage(boss.health.current - boss.covenant_at)  # debug: jump to the phase threshold
    _check(boss.phase_name() == "COVENANT", "HP %d enters phase III" % boss.health.current)
    _heal()
    _player.call("teleport_to", Vector3(28.0, 1.0, 0.0))
    await _seconds(0.5)
    boss.debug_attack(&"slam", 25.5)
    await _wait_until(func() -> bool: return boss.hand.weak_open, 3.0)
    await _wait_until(func() -> bool: return not boss.hand.weak_open, 6.0)
    _check(boss.weak_open_seconds > phase1_window + 1.0, "phase III weak window is longer (%.2f s vs %.2f s)" % [boss.weak_open_seconds, phase1_window])
    await _boss_idle(boss)
    _heal()
    boss.debug_attack(&"slam", 25.5)
    await _wait_until(func() -> bool: return boss.hand.weak_open, 3.0)
    _player.set("facing_direction", -1.0)
    _tap(KEY_L)
    await _seconds(0.9)
    _tap(KEY_J)
    await _seconds(0.5)
    _check(boss.health.current == 0 and boss.phase_name() == "DEFEATED", "final stigmata hits defeat the Bishop (hp=%d, phase=%s)" % [boss.health.current, boss.phase_name()])
    await _seconds(1.0)
    _check(not boss.is_attacking() and _first_lance() == null, "defeated Bishop stops attacking")


func _shot(name: String) -> void:
    if DisplayServer.get_name() == "headless":
        return
    await _frames(2)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
    var img: Image = root.get_viewport().get_texture().get_image()
    img.save_png(SHOT_DIR + name + ".png")

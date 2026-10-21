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
    # Never touch the player's real settings file; start from defaults.
    GameSettings.persistence_enabled = false
    _test_defaults()
    await _m6_menu_checks()
    _bind()
    await _seconds(1.0)

    _check(_player.is_on_floor(), "player lands on the starting causeway")
    _check(absf(_player.global_position.z) < 0.001, "player starts on Z=0 plane")
    await _shot("01_boot")
    _m4_data_and_deck_checks()

    # The soldier patrols on its own from boot; park it for deterministic movement tests.
    var ex0: float = _enemy.global_position.x
    var max_dx: float = 0.0
    for i in int(1.0 * PHYSICS_HZ):  # it may turn at a patrol bound, so track the furthest point
        await physics_frame
        max_dx = maxf(max_dx, absf(_enemy.global_position.x - ex0))
    _check(_enemy.state_name() == "PATROL" and max_dx > 0.8, "soldier patrols on its own (state=%s, max dx=%.2f)" % [_enemy.state_name(), max_dx])
    _enemy.set_ai_enabled(false)
    _enemy.teleport_to(Vector3(9.0, 1.0, 0.0))

    # The portcullis to the Bishop's arena stays shut while the soldier lives.
    _player.call("teleport_to", Vector3(16.0, 1.0, 0.0))
    await _seconds(0.3)
    await _hold(KEY_D, 1.0)
    _check(_player.global_position.x < 18.3, "portcullis blocks the way while the soldier lives (x=%.2f)" % _player.global_position.x)
    _player.call("teleport_to", Vector3(-16.0, 2.0, 0.0))
    await _seconds(0.8)
    await _m6_pause_checks()

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
    await _fix_combat_feel_checks()
    await _fix_spear_hits_enemies()
    await _fix_mouse_cards_vs_soldier()

    # --- M5 Reality Fracture: cross into 3D and back ---------------------------
    reached = await _run_right_until(12.6, 6.0)
    _check(reached, "walked to the amber gate (x=%.2f)" % _player.global_position.x)
    await _seconds(0.3)
    await _m5_fracture_checks()

    # --- M3 Hollow Bishop → victory / restart ----------------------------------
    var spoils_before: int = Profile.pending_spoils
    await _m3_boss_checks()
    _check(bool(_main.get("game_won")), "defeating the Bishop wins the run")
    _check(Audio.current_music == &"" and int(Audio.played.get(&"victory", 0)) > 0, "victory stops the music and plays the victory chord")
    _check(bool(_player.get("game_frozen")), "player is frozen on victory")
    var chest: LootChest = _main.get("loot_chest")
    _check(chest != null and chest.player_in_reach(_player), "the Bishop drops a reliquary within reach")
    var stash_before: int = Profile.stash.size()
    _tap(KEY_E)
    await _frames(4)
    var loot_overlay: CardOfferOverlay = _main.get("offer_overlay")
    _check(loot_overlay.is_open() and loot_overlay.offer_view.offers.size() == 3 and loot_overlay.offer_view.offers.all(func(c: Resource) -> bool: return c is ItemData), "E opens the reliquary: pick 1 of 3 items")
    var looted: ItemData = loot_overlay.offer_view.offers[0]
    _tap(KEY_1)
    await _frames(4)
    _check(Profile.stash.size() == stash_before + 1 and Profile.stash.has(looted.id) and chest.used, "the picked item (%s) goes into the stash" % looted.display_name)
    Profile.pending_spoils += 1  # keep the spoils check below meaningful (the chest spent the victory spoil)
    await _shot("08_victory")
    _check(Profile.pending_spoils == spoils_before + 1, "victory earns spoils for the Armory (%d -> %d)" % [spoils_before, Profile.pending_spoils])
    _tap(KEY_R)
    await _frames(10)
    _check(current_scene.scene_file_path == "res://scenes/armory.tscn", "R after victory opens the Armory")
    _tap(KEY_ENTER)  # Continue is focused
    await _frames(10)
    _check(current_scene.scene_file_path == "res://scenes/draft.tscn", "the Armory continues into a fresh draft")
    await _draft_three()
    _bind()
    await _seconds(0.5)
    _check(bool(_main.get("enemy_alive")) and not bool(_main.get("game_won")), "R restarts with fresh state")
    _check(_player.global_position.distance_to(spawn) < 2.5, "restart places player at spawn")
    _tap(KEY_ESCAPE)
    await _frames(3)
    var pause_menu: PauseMenu = _main.find_child("PauseMenu", true, false) as PauseMenu
    pause_menu.menu_button.pressed.emit()
    await _frames(10)
    _check(current_scene.scene_file_path == "res://scenes/main_menu.tscn" and not paused, "pause → Main menu returns to the title screen, unpaused")
    await _m7_altar_and_new_card_checks()
    await _m9_archer_and_ambush_checks()
    await _m11_relic_checks()
    await _m12_enemy_ability_checks()
    await _m13_hazard_checks()
    await _m14_equipment_checks()
    await _m15_new_card_checks()
    await _m16_map_checks()
    await _m17_new_enemy_checks()
    await _m10_audio_checks()  # last: checks that every sound was heard somewhere in the suite

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
    # Pressed inside cooldown (0.4 s from dodge start): must be ignored.
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


## Settings for scripted checks: game defaults.
func _test_defaults() -> void:
    GameSettings.reset_defaults()
    Ambush.enabled = false  # scripted checks walk the level freely; ambushes have their own checks
    SpikeTrap.enabled = false  # likewise for the traps (see _m13_hazard_checks)
    Profile.reset()  # starter gear only (no stats): equipment has its own checks
    LevelLayout.classic = true  # the original short layout; the full map has its own checks
    PendulumBlade.enabled = false


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
    _check(_enemy.health.current == _enemy.health.max_health, "whiff out of reach deals no damage")

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
    var hp_max: int = _enemy.health.max_health
    await _place(3.2, 4.3, false)
    _player.set("facing_direction", -1.0)
    _tap(KEY_J)
    await _seconds(0.6)
    _check(_enemy.health.current == hp_max, "attacking while facing away misses")

    # A single light hit flinches (flash) but does not stagger: poise absorbs it.
    _player.set("facing_direction", 1.0)
    var flashed: bool = false
    var stunned: bool = false
    _tap(KEY_J)
    for i in 30:
        await physics_frame
        flashed = flashed or float(_enemy.get("_flash_left")) > 0.0
        stunned = stunned or _enemy.state_name() == "HITSTUN"
    _check(_enemy.health.current == hp_max - 1, "light attack deals 1 damage (hp=%d)" % _enemy.health.current)
    _check(flashed and not stunned and _enemy.poise == _enemy.poise_max - 1, "a light hit flashes the soldier but only chips its poise (poise=%d)" % _enemy.poise)
    var c: Color = _newest_fx_color()
    _check(c.r > 0.4 and c.g < 0.1, "default spray is blood red")

    GameSettings.reduced_gore = true
    await _place(3.2, 4.3, false)
    _tap(KEY_J)
    await _seconds(0.5)
    c = _newest_fx_color()
    GameSettings.reduced_gore = false
    _check(_enemy.health.current == hp_max - 2, "second light hit lands (hp=%d)" % _enemy.health.current)
    _check(c.r < 0.3 and absf(c.r - c.b) < 0.1, "reduced-gore spray is ash grey (color=%s)" % c)

    # Heavy breaks the (already chipped) poise: stagger + knockback.
    await _place(3.2, 4.4, false)
    var ex: float = _enemy.global_position.x
    stunned = false
    _tap(KEY_L)
    for i in 60:
        await physics_frame
        stunned = stunned or _enemy.state_name() == "HITSTUN"
    _check(_enemy.health.current == hp_max - 4, "heavy attack deals 2 damage (hp=%d)" % _enemy.health.current)
    _check(stunned and _enemy.global_position.x > ex + 0.3, "heavy breaks poise: the soldier staggers and is knocked back (dx=%.2f)" % (_enemy.global_position.x - ex))

    # Finish it by holding J: the combo chains until it drops.
    await _place(3.2, 4.3, false)
    _key(KEY_J, true)
    await _wait_until(func() -> bool: return _enemy.is_dead(), 3.0)
    _key(KEY_J, false)
    await _seconds(0.6)
    _check(_enemy.health.current == 0 and _enemy.state_name() == "DEAD", "holding J chains the combo and kills the soldier (hp=%d, state=%s)" % [_enemy.health.current, _enemy.state_name()])
    _check(not bool(_main.get("enemy_alive")), "level registers the soldier as defeated")
    _check(_enemy.collision_layer == 0 and not _enemy.hurtbox.monitorable, "corpse no longer blocks or takes hits")
    await _shot("03_soldier_dead")


## Playtest request: faster melee, an auto-attack, and hit reactions on both sides.
func _fix_combat_feel_checks() -> void:
    var energy: BloodEnergy = _energy()
    var melee: MeleeAttack = _melee()
    energy.regen_per_second = 0.0
    _enemy.revive_at_home()
    await _place(3.2, 4.3, false)
    energy.set_amount(0.0)
    var ids: Array[StringName] = []
    var on_start: Callable = func(id: StringName) -> void: ids.append(id)
    _player.connect("attack_started", on_start)
    var hp0: int = _enemy.health.current
    _key(KEY_J, true)
    await _seconds(1.2)
    var blood_after_1_2s: float = energy.current
    await _seconds(0.4)
    _key(KEY_J, false)
    var chain_ok: bool = ids.size() >= 4 and ids.slice(0, 3) == [&"player_light", &"player_light_2", &"player_light_finisher"]
    _check(chain_ok, "holding J chains light → light → finisher and keeps going (%d attacks: %s)" % [ids.size(), ids.slice(0, 4)])
    _check(blood_after_1_2s >= 1.5, "a held combo earns blood quickly (%.1f blood in 1.2 s)" % blood_after_1_2s)
    _check(_enemy.health.current < hp0, "the combo damages the soldier (%d → %d)" % [hp0, _enemy.health.current])
    await _seconds(0.3)
    ids.clear()
    await _seconds(0.6)
    _check(ids.is_empty() and not melee.is_busy(), "releasing J stops the combo")
    _player.disconnect("attack_started", on_start)

    # Melee is manual: left click swings, nothing swings on its own.
    _enemy.revive_at_home()
    await _place(3.2, 1.9, false)
    _check(InputMap.action_get_events(&"attack").any(func(e: InputEvent) -> bool: return e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT), "left click is bound to the light attack")
    _check(InputMap.action_get_events(&"heavy_attack").any(func(e: InputEvent) -> bool: return e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT), "right click is bound to the heavy attack")
    hp0 = _enemy.health.current
    await _seconds(1.0)
    _check(_enemy.health.current == hp0 and not melee.is_busy(), "no auto-attack: an enemy in reach is not hit without input")
    var click: InputEventMouseButton = InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    _player.call("_unhandled_input", click)  # headless drops OS mouse input; deliver it directly
    await physics_frame
    _check(melee.is_busy() and melee.current == _player.get("light_attack"), "a left click starts the light attack")
    await _seconds(0.8)

    # Poise vs telegraph, then hit reactions on the player.
    _enemy.revive_at_home()
    await _place(3.2, 4.6, true)
    _heal()
    var winding: bool = await _wait_until(func() -> bool: return _enemy.melee.phase == MeleeAttack.Phase.STARTUP, 4.0)
    _player.set("facing_direction", 1.0)
    _tap(KEY_J)
    await _seconds(0.15)
    _check(winding and _enemy.state_name() == "ATTACK", "a single quick hit does not interrupt the soldier's wind-up (poise)")
    var player_hp: int = _player_hp()
    var hit: bool = await _wait_until(func() -> bool: return _player_hp() < player_hp, 3.0)
    var vignette: ColorRect = _main.get("hurt_vignette")
    _check(hit and bool(_player.call("is_hurt_flashing")) and vignette.color.a > 0.3, "getting hit flashes the player red and pulses the screen edges (a=%.2f)" % vignette.color.a)
    _enemy.set_ai_enabled(false)
    _enemy.health.apply_damage(_enemy.health.current)
    await _seconds(0.6)
    energy.regen_per_second = 0.25


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
    _check(spear.targeting == CardData.Targeting.ENEMY and shield.targeting == CardData.Targeting.SELF and chains.targeting == CardData.Targeting.BOSS_TELEGRAPH,
        "card targeting rules come from data")
    var ids: Array[String] = []
    for id: StringName in _hand_ids():
        ids.append(String(id))
    ids.sort()  # StringName sorts by pointer; compare as Strings
    _check(ids == ["blood_spear", "grave_shield", "ritual_chains"], "starting hand holds the three starter cards (%s)" % [ids])

    _check(CardPool.ALL.size() >= 8, "the card pool holds %d cards" % CardPool.ALL.size())
    RunState.new_run(99)
    var offer_a: Array = RunState.next_offer().map(func(c: CardData) -> StringName: return c.id)
    RunState.new_run(99)
    var offer_b: Array = RunState.next_offer().map(func(c: CardData) -> StringName: return c.id)
    RunState.end_run()
    _check(offer_a == offer_b and offer_a.size() == 3, "the same run seed makes the same offers (%s)" % [offer_a])

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
    _player.call("teleport_to", Vector3(_bx(24.2), 1.0, 0.0))
    await _seconds(0.5)
    energy.set_amount(6.0)
    var spear_card: CardData = cards.deck.card_in_slot(spear_slot)
    _check(cards.play_slot(spear_slot) == &"no_target" and energy.current == 6.0 and cards.cooldown_left(spear_card) == 0.0
        and root.get_tree().get_nodes_in_group(&"blood_spear").is_empty(), "Blood Spear with no enemy or exposed weak point is refused, nothing spent")
    _check("Blood Spear: no enemy or exposed stigmata" in str(_main.get("_message")), "the HUD explains why the spear was refused (%s)" % _main.get("_message"))
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
    boss.debug_attack(&"slam", _bx(24.2))
    await _boss_idle(boss)
    _check(_player_hp() == 5 and not bool(_player.call("is_shielded")), "Grave Shield absorbs the slam and is consumed (hp=%d)" % _player_hp())
    _player.call("raise_shield", &"heavy", 3.0)
    boss.debug_attack(&"lance", _bx(24.2))
    await _boss_idle(boss)
    _check(_player_hp() == 4, "the heavy-only ward does not stop a lance (projectile) (hp=%d)" % _player_hp())

    # Ritual Chains interrupts the telegraph: the player beneath takes nothing.
    _heal()
    _player.call("teleport_to", Vector3(_bx(24.2), 1.0, 0.0))
    _player.set("facing_direction", 1.0)
    await _seconds(1.0)
    energy.set_amount(6.0)
    var boss_hp0: int = boss.health.current
    boss.debug_attack(&"slam", _bx(24.2))
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
    var blood_after_hit: float = 3.0 + energy.per_hit
    _check(boss.health.current == boss_hp0 - 1 and is_equal_approx(energy.current, blood_after_hit), "melee hit on the stigmata damages the Bishop and earns %.1f blood (energy=%.1f)" % [energy.per_hit, energy.current])

    # Blood Spear: range check, then a real projectile into the exposed stigmata.
    _player.call("teleport_to", Vector3(_bx(44.0), 1.0, 0.0))
    await _seconds(0.2)
    _check(cards.play_slot(spear_slot) == &"out_of_range" and is_equal_approx(energy.current, blood_after_hit), "Blood Spear beyond its 14 m range is refused, nothing spent")
    _player.call("teleport_to", Vector3(_bx(33.0), 1.0, 0.0))
    await _seconds(0.2)
    var boss_hp1: int = boss.health.current
    _check(cards.play_slot(spear_slot) == &"ok" and is_equal_approx(energy.current, blood_after_hit - 2.0), "Blood Spear at an exposed stigmata in range is played, 2 blood spent")
    _check(root.get_tree().get_nodes_in_group(&"blood_spear").size() == 1, "Blood Spear launches a projectile")
    await _seconds(0.6)
    _check(boss.health.current == boss_hp1 - spear_card.damage, "the spear flies to the stigmata and deals %d (%d → %d)" % [spear_card.damage, boss_hp1, boss.health.current])
    _check(root.get_tree().get_nodes_in_group(&"blood_spear").is_empty(), "spent spear is cleaned up")
    await _boss_idle(boss)
    _check(not boss.can_be_interrupted(), "nothing is interruptible once the Bishop is idle")
    _check(_hand_ids() == hand_before, "played cards return to the same slots (%s)" % [_hand_ids()])
    await _fix_stun_buffer_checks(boss)
    await _fix_mouse_cards_vs_bishop(boss)
    energy.regen_per_second = 0.25


func _m5_fracture_checks() -> void:
    var fracture: RealityFracture = _main.get("fracture")
    var guardian: PlaguedSoldier = fracture.guardian
    var energy: BloodEnergy = _energy()
    var cards: CardSystem = _cards()
    var cam: Camera3D = _main.get("camera")
    guardian.set_ai_enabled(false)
    # Park it off the locomotion lane: where its patrol left it depends on how long earlier tests ran.
    guardian.teleport_to(fracture.center + Vector3(5.0, 1.0, 4.0))
    energy.regen_per_second = 0.0
    var entry_x: float = _player.global_position.x
    var shield_slot: int = _slot_of(&"grave_shield")
    var shield_card: CardData = cards.deck.card_in_slot(shield_slot)
    await _wait_until(func() -> bool: return cards.cooldown_left(shield_card) == 0.0, 7.0)  # an earlier check may have used it
    energy.set_amount(4.0)
    _check(cards.play_slot(shield_slot) == &"ok", "Grave Shield played before crossing (puts it on cooldown)")
    var hp_before: int = _player_hp()

    # Transition in: fade covers the teleport, input frozen, then free X/Z control.
    _tap(KEY_E)
    await _frames(6)
    _check(fracture.is_transitioning() and bool(_player.get("game_frozen")), "E at the gate starts the fracture transition with input frozen")
    var max_alpha: float = 0.0
    var deadline: int = Time.get_ticks_msec() + 3000  # time-based: frame rate differs headless vs. visible
    while Time.get_ticks_msec() < deadline:
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
    _check(guardian.health.current == guardian.health.max_health - 1 and facing.z < -0.5, "soft lock-on turns an undirected attack onto the guardian (hp=%d, facing=%s)" % [guardian.health.current, facing])
    _key(KEY_J, true)
    await _wait_until(func() -> bool: return guardian.is_dead(), 4.0)
    _key(KEY_J, false)
    await _seconds(0.5)
    _check(guardian.is_dead() and fracture.portal_open, "a held combo slays the guardian and the return portal opens")
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
    var overlay: CardOfferOverlay = _main.get("offer_overlay")
    _check(overlay.is_open() and paused and overlay.offer_view.offers.size() == 3, "clearing the fracture offers a relic (pick 1 of 3, game paused)")
    overlay.skip_button.pressed.emit()
    await _frames(3)
    _check(not overlay.is_open() and not paused, "taking nothing resumes play")
    await _seconds(1.5)
    var side_offset: Vector3 = cam.global_position - _player.global_position
    _check(absf(side_offset.z - 22.0) < 1.0, "camera returns to side-view framing (offset=%s)" % side_offset)
    _tap(KEY_E)
    await _seconds(0.6)
    _check(not bool(_player.get("in_3d_mode")) and not fracture.can_enter(), "a cleared fracture stays sealed")
    energy.regen_per_second = 0.25


## Arena x in the original M3 layout → x in the current layout (the arena moved when the
## Pursuit Approach was inserted; tests stay valid if it moves again).
func _bx(x: float) -> float:
    return x + ((_main.get("boss_arena") as BossArena).left_x() - 18.2)


func _m6_menu_checks() -> void:
    change_scene_to_file("res://scenes/main_menu.tscn")
    await _frames(10)
    var menu: Control = current_scene as Control
    var start: Button = menu.get("start_button")
    var settings_button: Button = menu.get("settings_button")
    var quit: Button = menu.get("quit_button")
    _check(start != null and start.has_focus() and settings_button != null and quit.visible, "title screen shows Start (focused) / Settings / Quit")
    await _shot("00_title")
    settings_button.pressed.emit()
    await _frames(2)
    var panel: SettingsPanel = menu.get("settings")
    _check(panel.visible, "Settings opens from the title screen")
    panel.save_path = "user://test_settings.cfg"
    panel.gore_toggle.button_pressed = true
    panel.shake_slider.value = 0.5
    panel.hitstop_toggle.button_pressed = false
    panel.music_slider.value = 0.3
    panel.sfx_slider.value = 0.5
    var music_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))
    _check(is_equal_approx(GameSettings.music_volume, 0.3) and absf(music_db - linear_to_db(0.3)) < 0.01, "the Music slider sets the Music bus volume (%.1f dB)" % music_db)
    _check(GameSettings.reduced_gore and is_equal_approx(GameSettings.camera_shake, 0.5) and not GameSettings.hitstop_enabled, "settings controls change gore / shake / hit-stop immediately")
    _test_defaults()
    GameSettings.load_settings("user://test_settings.cfg")
    _check(GameSettings.reduced_gore and is_equal_approx(GameSettings.camera_shake, 0.5) and not GameSettings.hitstop_enabled
        and is_equal_approx(GameSettings.music_volume, 0.3) and is_equal_approx(GameSettings.sfx_volume, 0.5), "settings (incl. volumes) persist through save and reload")
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
    _test_defaults()
    _tap(KEY_ESCAPE)
    await _frames(3)
    _check(not panel.visible and (menu.get("_menu") as Control).visible, "Esc closes Settings back to the title menu")
    start.grab_focus()
    _tap(KEY_ENTER)
    await _frames(12)
    _check(current_scene.scene_file_path == "res://scenes/armory.tscn", "Enter on Start opens the Armory")
    _tap(KEY_ENTER)  # Continue is focused
    await _frames(12)
    _check(current_scene.scene_file_path == "res://scenes/draft.tscn" and RunState.active, "Continue in the Armory opens the card draft for a new run")
    var picked: Array[StringName] = await _draft_three()
    _check(current_scene.scene_file_path == "res://scenes/main.tscn", "finishing the draft loads the level")
    _bind()
    var hand: Array[String] = []
    for id: StringName in _hand_ids():
        hand.append(String(id))
    hand.sort()
    var want: Array[String] = []
    for id: StringName in picked:
        want.append(String(id))
    want.sort()
    _check(hand == want, "the drafted cards are the starting hand (%s)" % [hand])
    # The rest of the suite runs on the default deck for deterministic checks.
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)


## Picks one card in each of the three draft rounds (a different offer position each round).
func _draft_three() -> Array[StringName]:
    var picked: Array[StringName] = []
    for round in RunState.DRAFT_ROUNDS:
        var view: CardOfferView = current_scene.find_child("Offers", true, false) as CardOfferView
        if view == null or view.offers.size() != RunState.OFFER_SIZE:
            _check(false, "draft round %d offers %d cards" % [round + 1, RunState.OFFER_SIZE])
            return picked
        var ids: Array = view.offers.map(func(c: CardData) -> StringName: return c.id)
        if round == 0:
            _check(ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "each draft offer shows 3 different cards (%s)" % [ids])
        _check(not picked.has(ids[round % 3]) or round == 0, "draft offers skip cards already picked")
        picked.append(ids[round % 3])
        _tap(CARD_KEYS[round % 3])
        await _frames(6)
    await _frames(10)
    return picked


func _m6_pause_checks() -> void:
    var pause_menu: PauseMenu = _main.find_child("PauseMenu", true, false) as PauseMenu
    _tap(KEY_ESCAPE)
    await _frames(3)
    _check(paused and pause_menu.is_open() and pause_menu.resume_button.has_focus(), "Esc pauses the game and opens the pause menu")
    var px: float = _player.global_position.x
    _key(KEY_D, true)
    await _frames(20)
    _key(KEY_D, false)
    _check(absf(_player.global_position.x - px) < 0.001, "nothing moves while paused")
    pause_menu.settings_button.pressed.emit()
    await _frames(2)
    _check(pause_menu.settings.visible, "Settings opens from the pause menu")
    _tap(KEY_ESCAPE)
    await _frames(3)
    _check(not pause_menu.settings.visible and pause_menu.is_open() and paused, "Esc in Settings returns to the pause menu")
    await _shot("01_paused")
    _tap(KEY_ESCAPE)
    await _frames(3)
    _check(not paused and not pause_menu.is_open(), "Esc again resumes")


## Portcullis → Pursuit Approach → arena threshold. Returns when standing at the threshold.
func _m6_approach_checks(boss: HollowBishop) -> bool:
    var reached: bool = await _run_right_until(22.0, 5.0)
    _check(reached, "open portcullis leads onto the Pursuit Approach (x=%.2f)" % _player.global_position.x)
    _check(bool((_main.get("approach_checkpoint") as Checkpoint).is_active), "approach checkpoint activates")
    _check(boss.phase_name() == "INTRO", "stepping onto the approach awakens the Bishop (phase=%s)" % boss.phase_name())
    await _seconds(1.8)
    var bar: ProgressBar = _main.get("boss_bar")
    _check(boss.phase_name() == "PURSUIT" and not bar.get_parent().visible, "the Bishop stalks the approach (PURSUIT, no HP bar yet)")
    var thrown: bool = await _wait_until(func() -> bool: return _first_lance() != null, 5.0)
    var lance_dx: float = absf(_first_lance().global_position.x - _player.global_position.x) if thrown else 99.0
    _check(thrown and lance_dx < 1.0, "during the pursuit it hurls a telegraphed lance at the player's lane (dx=%.2f)" % lance_dx)
    await _shot("05_pursuit")
    boss.set_ai_enabled(false)
    await _boss_idle(boss)
    _heal()

    var slabs: Array[CollapsingSlab] = _main.get("collapsing_slabs")
    reached = await _run_right_until(38.5, 5.0)
    _check(reached, "player runs across the collapsing slabs (x=%.2f)" % _player.global_position.x)
    await _seconds(0.5)
    var collapsed: int = slabs.filter(func(slab: CollapsingSlab) -> bool: return slab.is_collapsed).size()
    _check(collapsed > 0, "slabs crumble behind the player (%d collapsed)" % collapsed)
    await _seconds(4.0)
    _check(slabs.all(func(slab: CollapsingSlab) -> bool: return not slab.is_collapsed), "crumbled slabs return after a few seconds")
    var cp: Vector3 = (_main.get("approach_checkpoint") as Checkpoint).respawn_position
    _player.call("teleport_to", Vector3(28.45, 1.0, 0.0))
    var dropped: bool = await _wait_until(func() -> bool: return _player.global_position.distance_to(cp) < 1.0, 4.0)
    _check(dropped and slabs.all(func(slab: CollapsingSlab) -> bool: return not slab.is_collapsed), "standing still drops the player; respawn at the approach checkpoint restores the slabs")

    var ferry: MovingPlatform = _main.get("ferry")
    _player.call("teleport_to", Vector3(42.8, 1.0, 0.0))
    await _seconds(0.4)
    await _wait_until(func() -> bool: return ferry.progress() < 0.02, 9.0)
    _key(KEY_D, true)
    await _wait_until(func() -> bool: return _player.global_position.x >= 45.0, 1.5)
    _key(KEY_D, false)
    var carried: bool = await _wait_until(func() -> bool: return ferry.progress() > 0.98, 6.0)
    await _seconds(0.2)
    _check(carried and _player.is_on_floor() and _player.global_position.x > 50.5, "the bone ferry carries the player over the 10 m gap (x=%.2f)" % _player.global_position.x)
    reached = await _run_right_until(55.5, 3.0)
    _check(reached, "player steps off onto the arena threshold")
    return reached


## Playtest fix: Blood Spear must damage ordinary enemies, not only the Bishop's stigmata.
func _fix_spear_hits_enemies() -> void:
    var energy: BloodEnergy = _energy()
    var cards: CardSystem = _cards()
    var spear: CardData = cards.deck.card_in_slot(_slot_of(&"blood_spear"))
    energy.regen_per_second = 0.0
    _enemy.set_ai_enabled(false)
    _enemy.revive_at_home()
    await _place(3.2, 5.6, false)
    energy.set_amount(6.0)
    var hp0: int = _enemy.health.current
    _tap(CARD_KEYS[_slot_of(&"blood_spear")])
    await _frames(3)
    _check(is_equal_approx(energy.current, 4.0) and root.get_tree().get_nodes_in_group(&"blood_spear").size() == 1, "Blood Spear fires at a living Plagued Soldier (2 blood spent)")
    await _seconds(0.6)
    _check(_enemy.health.current == maxi(0, hp0 - spear.damage), "the spear damages the soldier (%d → %d)" % [hp0, _enemy.health.current])
    var numbers: Array[Node] = root.get_tree().get_nodes_in_group(&"damage_number")
    _check(not numbers.is_empty() and (numbers[numbers.size() - 1] as Label3D).text == str(spear.damage), "a floating damage number shows the hit")
    if not _enemy.is_dead():
        _enemy.health.apply_damage(_enemy.health.current)
    await _seconds(0.5)
    energy.regen_per_second = 0.25


## Playtest fix: abilities pressed while recoiling from a hit fire when the stun ends,
## instead of being silently dropped.
func _fix_stun_buffer_checks(boss: HollowBishop) -> void:
    var energy: BloodEnergy = _energy()
    var cards: CardSystem = _cards()
    energy.regen_per_second = 0.0
    _heal()
    _player.call("teleport_to", Vector3(_bx(24.2), 1.0, 0.0))
    _player.set("facing_direction", 1.0)
    await _seconds(1.0)
    var hp0: int = boss.health.current
    boss.debug_attack(&"slam", _bx(24.2))
    var player_hp: int = _player_hp()
    await _wait_until(func() -> bool: return _player_hp() < player_hp, 3.0)
    _check(bool(_player.call("is_stunned")), "the slam leaves the player in hitstun")
    _tap(KEY_J)
    await _seconds(1.0)
    _check(boss.health.current == hp0 - 1, "J pressed during hitstun lands once the stun ends (%d → %d)" % [hp0, boss.health.current])
    await _boss_idle(boss)

    _heal()
    _player.call("teleport_to", Vector3(_bx(24.2), 1.0, 0.0))
    await _seconds(1.0)
    energy.set_amount(6.0)
    var spear: CardData = cards.deck.card_in_slot(_slot_of(&"blood_spear"))
    var failures: Array[StringName] = []
    var on_fail: Callable = func(_c: CardData, _s: int, reason: StringName) -> void: failures.append(reason)
    cards.card_failed.connect(on_fail)
    hp0 = boss.health.current
    boss.debug_attack(&"slam", _bx(24.2))
    player_hp = _player_hp()
    await _wait_until(func() -> bool: return _player_hp() < player_hp, 3.0)
    _tap(CARD_KEYS[_slot_of(&"blood_spear")])
    await _seconds(1.2)
    cards.card_failed.disconnect(on_fail)
    _check(failures.is_empty() and boss.health.current == hp0 - spear.damage,
        "Blood Spear pressed during hitstun fires when the stun ends (hp %d → %d, failures %s)" % [hp0, boss.health.current, failures])
    await _boss_idle(boss)
    energy.regen_per_second = 0.25


## Playtest fix: the Bishop must not melt. Optimal melee spam inside one weak-point window may
## take at most a fifth of its health (so the fight lasts at least five windows), but must
## still feel rewarding (at least 3 damage).
func _fix_tuning_checks(boss: HollowBishop) -> void:
    _heal()
    _player.call("teleport_to", Vector3(_bx(27.6), 1.0, 0.0))
    await _seconds(0.6)
    boss.debug_attack(&"slam", _bx(25.5))
    await _wait_until(func() -> bool: return boss.hand.weak_open, 3.0)
    var hp0: int = boss.health.current
    var melee: MeleeAttack = _melee()
    while boss.hand.weak_open:
        _player.set("facing_direction", -1.0)
        if not melee.is_busy():
            _tap(KEY_J)
        await physics_frame
    var dealt: int = hp0 - boss.health.current
    _check(dealt >= 3, "a weak-point window rewards melee (%d damage)" % dealt)
    _check(dealt * 5 <= boss.max_health, "optimal melee spam takes at most 1/5 of the Bishop per window (%d of %d)" % [dealt, boss.max_health])
    await _boss_idle(boss)


## Mouse click. With a window it goes through the real input pipeline (GUI picking included).
## Godot's headless display server drops mouse input, so headless runs route the same click to
## the card slot under the cursor or to CardTargeting directly (same logic, no OS input path).
func _click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
    if DisplayServer.get_name() == "headless":
        var ui: CardHandUI = _main.find_child("CardHand", true, false) as CardHandUI
        for i in ui.slots.size():
            if button == MOUSE_BUTTON_LEFT and ui.slots[i].get_global_rect().has_point(at):
                ui.slot_clicked.emit(i)
                await process_frame
                return
        var ev: InputEventMouseButton = InputEventMouseButton.new()
        ev.button_index = button
        ev.pressed = true
        ev.position = at
        _targeting()._unhandled_input(ev)
        await process_frame
        return
    var motion: InputEventMouseMotion = InputEventMouseMotion.new()
    motion.position = at
    motion.global_position = at
    Input.parse_input_event(motion)
    await process_frame
    for pressed: bool in [true, false]:
        var ev: InputEventMouseButton = InputEventMouseButton.new()
        ev.button_index = button
        ev.pressed = pressed
        ev.position = at
        ev.global_position = at
        Input.parse_input_event(ev)
        await process_frame


func _click_slot(slot: int) -> void:
    var ui: CardHandUI = _main.find_child("CardHand", true, false) as CardHandUI
    await _click(ui.slots[slot].get_global_rect().get_center())


func _screen_of(world: Vector3) -> Vector2:
    return (_main.get("camera") as Camera3D).unproject_position(world)


func _targeting() -> CardTargeting:
    return _main.find_child("CardTargeting", true, false) as CardTargeting


## Playtest fix: cards and targets can be used with the mouse (the playtester clicked them).
func _fix_mouse_cards_vs_soldier() -> void:
    var energy: BloodEnergy = _energy()
    var spear_slot: int = _slot_of(&"blood_spear")
    var spear: CardData = _cards().deck.card_in_slot(spear_slot)
    energy.regen_per_second = 0.0
    _enemy.revive_at_home()
    await _place(3.2, 7.0, false)
    energy.set_amount(6.0)
    await _frames(5)

    await _click_slot(spear_slot)
    _check(_targeting() != null and _targeting().armed_slot == spear_slot, "clicking the Blood Spear card arms it for targeting")
    await _click(Vector2(1240, 40))  # empty night sky
    await _frames(3)
    _check(is_equal_approx(energy.current, 6.0) and root.get_tree().get_nodes_in_group(&"blood_spear").is_empty(), "clicking empty space fires nothing and spends nothing")
    _check(_targeting().armed_slot == spear_slot and "target" in str(_main.get("_message")).to_lower(), "a miss-click keeps the card armed and says so (%s)" % _main.get("_message"))
    await _click(Vector2(640, 360), MOUSE_BUTTON_RIGHT)
    _check(_targeting().armed_slot == -1, "right-click cancels targeting")

    var hp0: int = _enemy.health.current
    await _click_slot(spear_slot)
    await _click(_screen_of(_enemy.global_position))
    await _frames(3)
    _check(is_equal_approx(energy.current, 4.0) and _targeting().armed_slot == -1, "clicking the soldier fires the armed spear at it (2 blood spent)")
    await _seconds(0.6)
    _check(_enemy.health.current == maxi(0, hp0 - spear.damage), "the clicked target takes the spear (%d → %d)" % [hp0, _enemy.health.current])

    var shield_slot: int = _slot_of(&"grave_shield")
    await _seconds(0.4)
    await _click_slot(shield_slot)
    await _frames(3)
    _check(bool(_player.call("is_shielded")) and _targeting().armed_slot == -1, "clicking Grave Shield plays it immediately (no target needed)")
    if not _enemy.is_dead():
        _enemy.health.apply_damage(_enemy.health.current)
    await _seconds(0.5)
    energy.regen_per_second = 0.25


func _fix_mouse_cards_vs_bishop(boss: HollowBishop) -> void:
    var energy: BloodEnergy = _energy()
    var spear_slot: int = _slot_of(&"blood_spear")
    var spear: CardData = _cards().deck.card_in_slot(spear_slot)
    energy.regen_per_second = 0.0
    _heal()
    _player.call("teleport_to", Vector3(_bx(30.0), 1.0, 0.0))
    await _seconds(2.0)  # let the spear cooldown from the previous checks expire
    energy.set_amount(6.0)
    var heart: Vector3 = boss.global_position + Vector3(0.0, 6.8, 1.6)
    await _click_slot(spear_slot)
    await _click(_screen_of(heart))
    await _frames(3)
    _check(is_equal_approx(energy.current, 6.0) and "stigmata" in str(_main.get("_message")), "clicking the Bishop's body refuses and points to the stigmata (%s)" % _main.get("_message"))
    await _click(Vector2(640, 360), MOUSE_BUTTON_RIGHT)

    boss.debug_attack(&"slam", _bx(25.5))
    await _wait_until(func() -> bool: return boss.hand.weak_open, 3.0)
    var hp0: int = boss.health.current
    await _click_slot(spear_slot)
    await _click(_screen_of(boss.hand.global_position + Vector3(0.0, 0.5, 0.4)))
    await _seconds(0.6)
    _check(boss.health.current == hp0 - spear.damage, "clicking the exposed stigmata spears it (%d → %d)" % [hp0, boss.health.current])
    await _boss_idle(boss)
    energy.regen_per_second = 0.25


## Deals `id` into hand slot 0 (test setup: the card pool is random in real runs).
func _deal(id: StringName) -> int:
    _cards().deck.hand[0] = CardPool.by_id(id)
    return 0


func _m7_altar_and_new_card_checks() -> void:
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    await _seconds(0.6)
    var cards: CardSystem = _cards()
    var energy: BloodEnergy = _energy()
    var health: Health = _player.get("health")
    energy.regen_per_second = 0.0
    _enemy.set_ai_enabled(false)

    # Blood Altar: E opens a pick-1-of-3 overlay; the chosen card joins the deck and cycles in.
    var overlay: CardOfferOverlay = _main.get("offer_overlay")
    var altar: BloodAltar = (_main.get("altars") as Array)[0]
    _player.call("teleport_to", altar.global_position + Vector3(0.0, 1.0, 0.0))
    await _seconds(0.4)
    _tap(KEY_E)
    await _frames(4)
    _check(overlay.is_open() and paused and overlay.offer_view.offers.size() == 3, "E at a Blood Altar offers 3 cards and pauses the game")
    var chosen: CardData = overlay.offer_view.offers[0]
    _tap(KEY_1)
    await _frames(4)
    _check(not overlay.is_open() and not paused and altar.used and cards.deck.total_cards() == 4, "picking adds %s to the deck (%d cards) and spends the altar" % [chosen.display_name, cards.deck.total_cards()])
    _tap(KEY_E)
    await _frames(4)
    _check(not overlay.is_open(), "a spent altar offers nothing more")
    energy.set_amount(6.0)
    var shield_slot: int = _slot_of(&"grave_shield")
    cards.play_slot(shield_slot)
    _check(_hand_ids().has(chosen.id), "the new card cycles into the hand when a card is played (%s)" % [_hand_ids()])
    await _seconds(0.5)

    # Hemorrhage Pact: 1 HP for 4 blood, never lethal.
    var slot: int = _deal(&"hemorrhage_pact")
    health.apply_damage(health.current - 1)
    energy.set_amount(0.0)
    _check(cards.play_slot(slot) == &"too_weak" and health.current == 1, "Hemorrhage Pact is refused at 1 HP")
    health.restore_full()
    _check(cards.play_slot(slot) == &"ok" and health.current == 4 and is_equal_approx(energy.current, 4.0), "Hemorrhage Pact trades 1 HP for 4 blood (hp=%d, blood=%.1f)" % [health.current, energy.current])

    # Transfusion: heals 2, refused at full health.
    slot = _deal(&"transfusion")
    health.restore_full()
    energy.set_amount(6.0)
    _check(cards.play_slot(slot) == &"full_health", "Transfusion is refused at full health")
    health.apply_damage(3)
    _check(cards.play_slot(slot) == &"ok" and health.current == 4, "Transfusion heals 2 HP (hp=%d)" % health.current)
    health.restore_full()

    # Epitaph: delayed spike under the target, 4 damage, breaks poise.
    _enemy.revive_at_home()
    await _place(3.2, 6.0, false)
    slot = _deal(&"epitaph")
    energy.set_amount(6.0)
    var hp0: int = _enemy.health.current
    _check(cards.play_slot(slot) == &"ok" and not root.get_tree().get_nodes_in_group(&"epitaph_spike").is_empty() and _enemy.health.current == hp0, "Epitaph marks the ground under the soldier (no damage yet)")
    var staggered: bool = false
    for i in 60:
        await physics_frame
        staggered = staggered or _enemy.state_name() == "HITSTUN"
    _check(_enemy.health.current == hp0 - 4 and staggered, "the spike erupts for 4 and staggers it (%d → %d)" % [hp0, _enemy.health.current])

    # Ashen Choir: a phantom that shoots shards at the nearest enemy for a while.
    _enemy.revive_at_home()
    await _place(3.2, 6.0, false)
    slot = _deal(&"ashen_choir")
    energy.set_amount(6.0)
    hp0 = _enemy.health.current
    _check(cards.play_slot(slot) == &"ok", "Ashen Choir summons a phantom")
    await _seconds(2.6)
    var phantoms: Array[Node] = root.get_tree().get_nodes_in_group(&"ashen_phantom")
    var fired: int = (phantoms[0] as AshenPhantom).shards_fired if not phantoms.is_empty() else 0
    _check(fired >= 2 and _enemy.health.current < hp0, "the phantom fires shards that hurt the soldier (%d shards, hp %d → %d)" % [fired, hp0, _enemy.health.current])
    await _seconds(4.0)
    _check(root.get_tree().get_nodes_in_group(&"ashen_phantom").is_empty(), "the phantom fades after its duration")

    # Bell of Silence: cancels a soldier wind-up and stops new attacks.
    _enemy.revive_at_home()
    await _place(3.2, 4.6, true)
    _heal()
    await _wait_until(func() -> bool: return _enemy.melee.phase == MeleeAttack.Phase.STARTUP, 4.0)
    slot = _deal(&"bell_of_silence")
    energy.set_amount(6.0)
    _check(cards.play_slot(slot) == &"ok" and _enemy.melee.phase == MeleeAttack.Phase.IDLE and _enemy.is_silenced(), "Bell of Silence cancels the soldier's wind-up")
    var attacked: bool = false
    for i in int(3.0 * PHYSICS_HZ):
        await physics_frame
        attacked = attacked or _enemy.state_name() == "ATTACK"
    _check(not attacked, "silenced soldier does not attack for the duration")
    _enemy.set_ai_enabled(false)
    energy.regen_per_second = 0.25


## Step 3: the bigger Bishop's new attacks (debug-triggered so each answer can be checked).
func _m8_new_attack_checks(boss: HollowBishop) -> void:
    var energy: BloodEnergy = _energy()
    # Censer Sweep: knee-high, so standing gets hit and a well-timed jump clears it.
    _heal()
    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    await _seconds(0.6)
    var hp0: int = _player_hp()
    _check(boss.debug_attack(&"censer", _bx(30.2)), "Censer Sweep starts")
    var censer: CenserSweep = boss.attack_actor() as CenserSweep
    _check(censer != null and censer.is_telegraphing(), "the censer telegraphs (red band along the causeway) before sweeping")
    await _seconds(0.9)
    await _shot("11_censer")
    await _boss_idle(boss)
    _check(_player_hp() == hp0 - 1, "standing in the censer's path costs 1 HP (%d → %d)" % [hp0, _player_hp()])
    await _seconds(1.0)
    _heal()
    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    await _seconds(0.6)
    boss.debug_attack(&"censer", _bx(30.2))
    censer = boss.attack_actor() as CenserSweep
    await _wait_until(func() -> bool: return censer == null or not is_instance_valid(censer) or (not censer.is_telegraphing() and absf(censer.censer_position().x - _player.global_position.x) < 5.0), 4.0)
    _key(KEY_SPACE, true)
    await _seconds(0.5)
    _key(KEY_SPACE, false)
    await _boss_idle(boss)
    _check(_player_hp() == 5, "jumping over the censer avoids it (hp=%d)" % _player_hp())

    # Requiem Beam: too fast to outrun; standing costs 2, dodging through costs nothing.
    await _seconds(0.8)
    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    await _seconds(0.4)
    hp0 = _player_hp()
    _check(boss.debug_attack(&"beam", _bx(30.2)), "Requiem Beam starts")
    await _seconds(1.5)
    await _shot("12_requiem_beam")
    await _boss_idle(boss)
    _check(_player_hp() == hp0 - 2, "standing in the beam's sweep costs 2 HP (%d → %d)" % [hp0, _player_hp()])
    await _seconds(1.0)
    _heal()
    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    await _seconds(0.6)
    boss.debug_attack(&"beam", _bx(30.2))
    var beam: RequiemBeam = boss.attack_actor() as RequiemBeam
    _player.set("facing_direction", signf(beam.from_x - _player.global_position.x))  # dodge *through* it, toward the beam
    await _wait_until(func() -> bool: return beam == null or not is_instance_valid(beam) or (not beam.is_telegraphing() and absf(beam.beam_x() - _player.global_position.x) < 2.2), 4.0)
    _tap(KEY_K)
    await _boss_idle(boss)
    _check(_player_hp() == 5, "dodging through the beam avoids it (hp=%d)" % _player_hp())

    # Bell of Silence (or any silence) cancels a censer still in its telegraph.
    await _seconds(0.8)
    boss.debug_attack(&"censer", _bx(30.2))
    await _seconds(0.3)
    boss.silence(4.0)
    await _frames(3)
    _check(not boss.is_attacking() and root.get_tree().get_nodes_in_group(&"boss_censer").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).is_empty(), "silence cancels a censer still winding up")

    # Grasping Dead: two Husks rise; never more than two; they die to the combo and give blood.
    _heal()
    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    await _seconds(0.4)
    _check(boss.debug_attack(&"summon", _bx(30.2)), "Grasping Dead starts (red marks where they will rise)")
    await _boss_idle(boss)
    var husks: Array[Node] = boss.minions()
    var on_plane: bool = husks.all(func(h: Node) -> bool: return absf((h as Node3D).global_position.z) < 0.01 and (h as Node3D).global_position.y > 0.0)
    _check(husks.size() == 2 and on_plane, "two Husks rise onto the causeway (%d)" % husks.size())
    await _shot("13_husks")
    if boss.debug_attack(&"summon", _bx(30.2)):
        await _boss_idle(boss)
    _check(boss.minions().size() <= boss.max_minions, "never more than %d Husks at a time (%d)" % [boss.max_minions, boss.minions().size()])
    _check(not boss.debug_attack(&"summon", _bx(30.2)) or boss.minions().size() < boss.max_minions, "a full graveyard refuses another summon")
    energy.regen_per_second = 0.0
    energy.set_amount(0.0)
    for i in int(10.0 * PHYSICS_HZ):
        await physics_frame
        if _player_hp() < 3:
            _heal()
        if boss.minions().is_empty():
            break
        _swing_if_near(boss.minions())
    _key(KEY_J, false)
    _check(boss.minions().is_empty() and energy.current >= 1.0, "the Husks fall to the combo and feed blood (%.1f blood)" % energy.current)
    energy.regen_per_second = 0.25
    boss.clear_minions()
    await _seconds(1.6)
    _heal()


## Step 4: Bone Archers and ambush rooms between the set-pieces (fresh level, ambushes on).
func _m9_archer_and_ambush_checks() -> void:
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    await _seconds(0.6)
    _enemy.set_ai_enabled(false)
    var health: Health = _player.get("health")

    # Bone Archer on its own: telegraphs, looses an arrow; jump it, or take 1 if you stand.
    var archer: BoneArcher = EnemyFactory.archer(_main, -10.0, -18.0, -7.5)
    _player.call("teleport_to", Vector3(-16.0, 1.0, 0.0))
    _heal()
    var aimed: bool = await _wait_until(func() -> bool: return archer.state_name() == "AIM", 3.0)
    _check(aimed, "the Bone Archer draws (red aim line) when the player is in range")
    var hp0: int = _player_hp()
    var close: bool = await _wait_until(func() -> bool:
        for n: Node in root.get_tree().get_nodes_in_group(&"bone_arrow"):
            if absf((n as Node3D).global_position.x - _player.global_position.x) < 4.2:
                return true
        return false, 3.0)
    _key(KEY_SPACE, true)
    await _seconds(0.45)
    _key(KEY_SPACE, false)
    await _seconds(0.6)
    _check(close and _player_hp() == hp0 and archer.arrows_fired >= 1, "jumping over the arrow avoids it (hp=%d, arrows=%d)" % [_player_hp(), archer.arrows_fired])
    hp0 = _player_hp()
    await _wait_until(func() -> bool: return _player_hp() < hp0, 5.0)
    _check(_player_hp() == hp0 - 1, "standing in the arrow's path costs 1 HP (%d → %d)" % [hp0, _player_hp()])
    archer.queue_free()
    for n: Node in root.get_tree().get_nodes_in_group(&"bone_arrow"):
        n.queue_free()
    await _seconds(0.3)

    # Gate ossuary: walls rise, foes spawn, the gate and altar wait, killing all drops the walls.
    Ambush.enabled = true
    var ambushes: Array = _main.get("ambushes")
    var e1: Ambush = ambushes[0]
    _heal()
    _player.call("teleport_to", Vector3(9.6, 1.0, 0.0))
    await _seconds(0.4)
    await _hold(KEY_D, 0.3)
    await _frames(3)
    _check(e1.is_active() and e1.wall_collision_enabled() and e1.alive_count() == 3, "entering the gate ossuary raises bone walls and spawns 2 Husks + an archer (%d foes)" % e1.alive_count())
    await _seconds(0.8)
    await _shot("14_ambush")
    _player.call("teleport_to", Vector3(12.9, 1.0, 0.0))
    await _seconds(0.2)
    _tap(KEY_E)
    await _frames(3)
    var fracture: RealityFracture = _main.get("fracture")
    _check(not fracture.is_transitioning() and "bone walls" in str(_main.get("_message")), "the fracture gate waits while the ambush holds")
    _player.call("teleport_to", Vector3(10.0, 1.0, 0.0))
    await _hold(KEY_A, 1.2)
    _check(_player.global_position.x > 9.3, "the bone wall keeps the player in (x=%.2f)" % _player.global_position.x)
    for i in int(25.0 * PHYSICS_HZ):
        await physics_frame
        if _player_hp() < 3:
            _heal()
        if e1.alive_count() == 0:
            break
        _chase_nearest(e1)
        _swing_if_near(e1.enemies)
    _key(KEY_A, false)
    _key(KEY_D, false)
    _key(KEY_J, false)
    await _frames(5)
    _check(e1.state == Ambush.State.CLEARED and not e1.wall_collision_enabled(), "slaying every foe drops the walls (state=%s)" % Ambush.State.keys()[e1.state])

    # Landing ambush: dying mid-fight resets it for a retry.
    var e2: Ambush = ambushes[1]
    _heal()
    _player.call("teleport_to", Vector3(38.2, 1.0, 0.0))
    await _seconds(0.4)
    await _hold(KEY_D, 0.25)
    await _frames(3)
    _check(e2.is_active() and e2.alive_count() == 4, "the landing ambush springs (%d foes)" % e2.alive_count())
    health.apply_damage(health.current)  # debug: lethal
    await _frames(6)
    var leftover: int = root.get_tree().get_nodes_in_group(&"ambush_enemy").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion() and not bool(n.call("is_dead"))).size()
    _check(e2.state == Ambush.State.ARMED and not e2.wall_collision_enabled() and leftover == 0, "dying mid-ambush clears it and re-arms it (state=%s, leftover=%d)" % [Ambush.State.keys()[e2.state], leftover])
    Ambush.enabled = false


## Bot melee for scripted fights: face the nearest living foe and hold J while one is in reach.
func _swing_if_near(foes: Array) -> void:
    var best: Node3D = null
    for f: Variant in foes:
        var e: Node3D = f as Node3D
        if e == null or not is_instance_valid(e) or bool(e.call("is_dead")):
            continue
        if best == null or absf(e.global_position.x - _player.global_position.x) < absf(best.global_position.x - _player.global_position.x):
            best = e
    var near: bool = best != null and absf(best.global_position.x - _player.global_position.x) < 1.9 and absf(best.global_position.y - _player.global_position.y) < 1.8
    if near and not (_player.get("melee") as MeleeAttack).is_busy():
        _player.set("facing_direction", signf(best.global_position.x - _player.global_position.x))
    if near != Input.is_action_pressed(&"attack"):
        _key(KEY_J, near)


## Walk toward the nearest living foe of an ambush (the caller does the swinging).
func _chase_nearest(ambush: Ambush) -> void:
    var best: Node3D = null
    ambush.alive_count()  # prunes freed corpses
    for e: Node3D in ambush.enemies:
        if not bool(e.call("is_dead")):
            if best == null or absf(e.global_position.x - _player.global_position.x) < absf(best.global_position.x - _player.global_position.x):
                best = e
    if best == null:
        return
    var dx: float = best.global_position.x - _player.global_position.x
    _key(KEY_D, dx > 1.2)
    _key(KEY_A, dx < -1.2)


const SOUND_IDS: Array[StringName] = [
    &"slash", &"slash_finisher", &"heavy_swing", &"hit_flesh", &"hit_weak", &"player_hurt", &"dodge",
    &"jump", &"land", &"death", &"card_spear", &"card_shield", &"card_chains", &"card_bell", &"card_epitaph",
    &"card_pact", &"card_choir", &"card_transfusion", &"card_refused", &"bishop_roar", &"bishop_slam",
    &"lance_whistle", &"censer_swing", &"beam_charge", &"beam_fire", &"summon", &"archer_draw",
    &"arrow_release", &"walls_rise", &"altar", &"ui_click", &"victory",
    &"bone_rain", &"geyser", &"hound_pounce", &"husk_burst", &"soldier_lunge", &"equip",
    &"card_step", &"card_hook", &"card_bridge", &"card_nova", &"card_haste", &"loot_drop",
    &"player_fall", &"player_death", &"player_effort",
]
const VOICE_LINES: Array[StringName] = [
    &"vo_awaken", &"vo_fight", &"vo_phase2", &"vo_phase3", &"vo_phase4", &"vo_slam", &"vo_beam",
    &"vo_summon", &"vo_rain", &"vo_geyser", &"vo_taunt", &"vo_death",
]


## Sound & music: every generated file loads, the level plays its drone, and every sound id
## was actually triggered by gameplay at some point during this run of the suite.
func _m10_audio_checks() -> void:
    var empty: Array[StringName] = []
    for id: StringName in SOUND_IDS + [&"music_level", &"music_boss"]:
        var stream: AudioStream = load("res://assets/audio/%s.wav" % id) if ResourceLoader.exists("res://assets/audio/%s.wav" % id) else null
        if stream == null or stream.get_length() <= 0.0:
            empty.append(id)
    _check(empty.is_empty(), "all %d generated sounds and both music loops load (missing: %s)" % [SOUND_IDS.size(), empty])
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    _check(Audio.current_music == &"music_level", "the level plays its ambient drone (%s)" % Audio.current_music)
    var music: AudioStreamWAV = load("res://assets/audio/music_level.wav")
    _check(music.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.loop_end > music.mix_rate * 10, "level music loops (%d frames)" % music.loop_end)
    var silent: Array[StringName] = []
    for id: StringName in SOUND_IDS:
        if int(Audio.played.get(id, 0)) == 0:
            silent.append(id)
    _check(silent.is_empty(), "every sound was triggered by gameplay during this run (never played: %s)" % [silent])
    var missing_vo: Array[StringName] = []
    for id: StringName in VOICE_LINES:
        if not ResourceLoader.exists("res://assets/audio/%s.wav" % id):
            missing_vo.append(id)
    _check(missing_vo.is_empty(), "all %d Bishop voice lines exist (missing: %s)" % [VOICE_LINES.size(), missing_vo])
    var spoken: Array = VOICE_LINES.filter(func(id: StringName) -> bool: return int(Audio.voiced.get(id, 0)) > 0)
    _check(spoken.has(&"vo_awaken") and spoken.has(&"vo_fight") and spoken.has(&"vo_phase2") and spoken.has(&"vo_phase3") and spoken.has(&"vo_phase4") and spoken.has(&"vo_death"), "the Bishop speaks at awakening, fight start, each phase and death (%s)" % [spoken])
    _check(spoken.size() >= 8, "the Bishop also calls out its attacks (%d different lines spoken)" % spoken.size())
    var hurt_takes: Array = Audio._takes(&"player_hurt")
    _check(hurt_takes.size() == 4, "the knight has 4 different hurt cries, picked at random (%d)" % hurt_takes.size())


## Relics & card upgrades: offers mix cards/relics/upgrades, every relic does what it says,
## upgrades replace the deck card, and relics follow the run into a reloaded level.
func _m11_relic_checks() -> void:
    var ids: Dictionary = {}
    for relic: RelicData in RelicPool.ALL:
        ids[relic.id] = true
    _check(RelicPool.ALL.size() == 8 and ids.size() == 8, "8 distinct relics in the pool")
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    await _seconds(0.3)
    var cards: CardSystem = _cards()
    var energy: BloodEnergy = _energy()
    var health: Health = _player.get("health")
    var melee: MeleeAttack = _melee()
    energy.regen_per_second = 0.0
    _enemy.set_ai_enabled(false)

    var altar_offer: Array = _main.call("_altar_offer")
    _check(altar_offer.size() == 3 and altar_offer[0] is CardData and altar_offer[1] is CardData and altar_offer[2] is RelicData, "a Blood Altar offers 2 cards and 1 relic")
    var fracture_offer: Array = _main.call("_fracture_offer")
    var relic_count: int = fracture_offer.filter(func(c: Resource) -> bool: return c is RelicData).size()
    var upgrades: Array = fracture_offer.filter(func(c: Resource) -> bool: return c is CardData and c.upgrade_source != null)
    _check(fracture_offer.size() == 3 and relic_count == 2 and upgrades.size() == 1, "the fracture offers 2 relics and 1 card upgrade")
    _check(CardOfferView.describe(altar_offer[2]).begins_with("RELIC:") and CardOfferView.describe(upgrades[0]).begins_with("UPGRADE:"), "offer buttons label relics and upgrades")

    # Upgrade: the tempered copy replaces the original everywhere in the deck.
    var upgrade: CardData = upgrades[0]
    var base: CardData = upgrade.upgrade_source
    var before_total: int = cards.deck.total_cards()
    _main.call("_on_offer_resolved", upgrade)
    var all: Array[CardData] = cards.deck.all_cards()
    _check(all.has(upgrade) and not all.has(base) and cards.deck.total_cards() == before_total, "an upgrade replaces %s with %s in the deck" % [base.display_name, upgrade.display_name])
    _check(upgrade.cost == maxi(0, base.cost - 1) and upgrade.cooldown < base.cooldown and upgrade.upgraded and not base.upgraded, "upgrades cost 1 less (%d -> %d) and cool down faster (%.2f -> %.2f)" % [base.cost, upgrade.cost, base.cooldown, upgrade.cooldown])
    var again: Array = _main.call("_fracture_offer")
    _check(again.all(func(c: Resource) -> bool: return not (c is CardData and c.upgrade_source == upgrade)), "an upgraded card is never offered for upgrade again")

    # Stat relics apply at once.
    _main.call("_on_offer_resolved", RelicPool.by_id(&"bone_ward"))
    _check(health.max_health == 6 and health.current == 6, "Bone Ward: +1 max HP (%d/%d)" % [health.current, health.max_health])
    energy.set_amount(1.0)
    _main.call("_on_offer_resolved", RelicPool.by_id(&"vessel_of_plenty"))
    _check(is_equal_approx(energy.maximum, 8.0) and is_equal_approx(energy.current, 3.0), "Vessel of Plenty: max blood 8 and 2 blood now (%.1f/%.1f)" % [energy.current, energy.maximum])
    _main.call("_on_offer_resolved", RelicPool.by_id(&"wraith_step"))
    _check(is_equal_approx(float(_player.get("dodge_invulnerable_time")), 0.40) and is_equal_approx(float(_player.get("dodge_cooldown")), 0.25), "Wraith Step: dodge i-frames 0.40 s, cooldown 0.25 s")
    _main.call("_on_offer_resolved", RelicPool.by_id(&"executioners_seal"))
    var heavy: AttackData = _player.get("heavy_attack")
    melee.start(heavy, Vector3.RIGHT)
    _check(melee.hitbox.damage == heavy.damage + 1, "Executioner's Seal: heavy strike deals %d (base %d)" % [melee.hitbox.damage, heavy.damage])
    await _seconds(1.2)
    melee.start(_player.get("light_attack"), Vector3.RIGHT)
    _check(melee.hitbox.damage == (_player.get("light_attack") as AttackData).damage, "Executioner's Seal leaves the opening jabs alone")
    await _seconds(0.8)

    # Rule relics.
    _main.call("_on_offer_resolved", RelicPool.by_id(&"penitents_rosary"))
    _main.call("_on_offer_resolved", RelicPool.by_id(&"thorned_reliquary"))
    _player.call("teleport_to", _enemy.global_position + Vector3(-4.0, 0.5, 0.0))
    await _seconds(0.4)
    energy.set_amount(8.0)
    var spear_slot: int = _deal(&"blood_spear")
    var spear_card: CardData = cards.deck.card_in_slot(spear_slot)
    _check(cards.play_slot(spear_slot) == &"ok", "Blood Spear plays with relics held")
    _check(absf(cards.cooldown_left(spear_card) - spear_card.cooldown * 0.75) < 0.05, "Penitent's Rosary: cooldown %.2f s instead of %.2f s" % [cards.cooldown_left(spear_card), spear_card.cooldown])
    var spear: BloodSpearProjectile = null
    for node: Node in _main.get_children():
        if node is BloodSpearProjectile:
            spear = node
    _check(spear != null and spear.hitbox.damage == spear_card.damage + 1, "Thorned Reliquary: the spear carries %d damage (base %d)" % [spear.hitbox.damage if spear else -1, spear_card.damage])
    await _seconds(1.0)

    _main.call("_on_offer_resolved", RelicPool.by_id(&"leech_fang"))
    energy.set_amount(0.0)
    _enemy.health.apply_damage(_enemy.health.current)
    await _frames(2)
    _check(energy.current >= 0.99, "Leech Fang: slaying a foe feeds 1 blood (blood=%.1f)" % energy.current)
    _main.call("_on_offer_resolved", RelicPool.by_id(&"gravebloom"))
    health.apply_damage(2)
    var hp_before: int = health.current
    _main.set("kills", 3)
    _main.call("on_combatant_died", _enemy)
    _check(health.current == hp_before + 1, "Gravebloom: the 4th kill heals 1 HP (%d -> %d)" % [hp_before, health.current])
    _main.call("on_combatant_died", _enemy)
    _check(health.current == hp_before + 1, "Gravebloom heals only on every 4th kill")
    _check(_relic_offer_is_empty(), "with all 8 relics held, altars fall back to 3 cards")
    await _frames(2)
    var hud_text: String = (_main.get("hud") as Label).text
    _check(hud_text.contains("RELICS:") and hud_text.contains("Gravebloom"), "the HUD lists held relics")

    # Relics and upgrades follow the run into a fresh level load.
    RunState.new_run(31)
    RunState.deck.assign(CardSystem.DEFAULT_CARDS.duplicate())
    var tempered: CardData = RunState.deck[0].upgraded_copy()
    RunState.replace_card(RunState.deck[0], tempered)
    RunState.relics.append(RelicPool.by_id(&"bone_ward"))
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    health = _player.get("health")
    _check(health.max_health == 6 and _cards().deck.all_cards().has(tempered), "a run's relics and upgrades carry into the level (max HP %d)" % health.max_health)
    RunState.end_run()


func _relic_offer_is_empty() -> bool:
    var offer: Array = _main.call("_altar_offer")
    return offer.size() == 3 and offer.all(func(c: Resource) -> bool: return c is CardData)


## Bone Rain and Marrow Geyser: telegraphed rings, real damage if you stay, none if you move.
func _barrage_checks(boss: HollowBishop) -> void:
    _heal()
    var x: float = _bx(28.0)
    _player.call("teleport_to", Vector3(x, 1.0, 0.0))
    await _seconds(0.5)
    var hp0: int = _player_hp()
    _check(boss.debug_attack(&"bone_rain", x), "Bone Rain starts")
    await _frames(3)
    var rings: Array[Node] = root.get_tree().get_nodes_in_group(&"strike_zone")
    _check(rings.size() >= 4 and rings.all(func(z: Node) -> bool: return not (z as StrikeZone).landed), "Bone Rain marks %d rings before anything falls" % rings.size())
    await _seconds(0.6)
    var wave2: Array[Node] = root.get_tree().get_nodes_in_group(&"strike_zone")
    _check(wave2.size() > rings.size(), "a second, offset wave is marked (%d rings)" % wave2.size())
    await _boss_idle(boss)
    _check(_player_hp() < hp0, "standing on a ring gets you hit by the bones (hp %d -> %d)" % [hp0, _player_hp()])
    await _seconds(0.6)

    _heal()
    _player.call("teleport_to", Vector3(_bx(22.5), 1.0, 0.0))
    await _seconds(0.5)
    hp0 = _player_hp()
    _check(boss.debug_attack(&"marrow_geyser", _bx(22.5)), "Marrow Geyser starts")
    _key(KEY_D, true)
    await _boss_idle(boss)
    _key(KEY_D, false)
    _check(_player_hp() == hp0, "running keeps ahead of the Marrow Geyser (hp %d)" % _player_hp())
    await _seconds(0.8)
    hp0 = _player_hp()
    boss.debug_attack(&"marrow_geyser", _player.global_position.x)
    await _boss_idle(boss)
    _check(_player_hp() < hp0, "standing still, the geyser finds you (hp %d -> %d)" % [hp0, _player_hp()])
    await _seconds(0.8)
    boss.debug_attack(&"bone_rain", _player.global_position.x)
    await _frames(3)
    boss.silence(1.0)
    await _frames(3)
    var left: Array = root.get_tree().get_nodes_in_group(&"strike_zone").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
    _check(not boss.is_attacking() and left.is_empty(), "Bell of Silence cancels a barrage still being marked")
    _heal()
    await _seconds(1.2)


## Unique abilities of the small enemies: lunge + frenzy, Husk death burst, archer lob + hop,
## Crypt Hound pounce.
func _m12_enemy_ability_checks() -> void:
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    await _seconds(0.3)

    # Plague Lunge from mid range.
    await _place(3.0, 7.5, true)
    var lunged: bool = await _wait_until(func() -> bool: return _enemy.melee.current != null and _enemy.melee.current.id == &"soldier_lunge", 2.0)
    _check(lunged, "the soldier lunges from mid range (Plague Lunge)")
    await _seconds(1.5)
    _heal()
    _enemy.set_ai_enabled(false)
    _enemy.health.apply_damage(_enemy.health.current - _enemy.health.max_health / 2)
    _enemy.hurtbox.hit_received.emit(DamageInfo.new())
    _check(_enemy.enraged, "below half HP the soldier enters a Frenzy")
    _enemy.revive_at_home()
    _check(not _enemy.enraged, "reviving clears the Frenzy")

    # Husk death burst.
    var husk: PlaguedSoldier = EnemyFactory.husk(_main, -12.0, -18.0, -7.5)
    husk.set_ai_enabled(false)
    # Leave the revived soldier's contact range first (its knockback would carry us out of the burst).
    _player.call("teleport_to", Vector3(-16.0, 1.0, 0.0))
    await _seconds(1.0)
    _player.call("teleport_to", Vector3(-13.4, 1.0, 0.0))  # out of the Husk's contact reach, inside the burst
    await _seconds(0.3)
    _heal()
    var hp0: int = _player_hp()
    husk.health.apply_damage(husk.health.current)
    await _frames(3)
    var cloud: bool = root.get_tree().get_nodes_in_group(&"strike_zone").size() > 0
    var lowest: int = hp0
    for i in int(0.9 * PHYSICS_HZ):
        await physics_frame
        lowest = mini(lowest, _player_hp())
    _check(cloud and lowest < hp0, "a slain Husk bursts in a plague cloud (hp %d -> %d, now %d)" % [hp0, lowest, _player_hp()])
    await _seconds(1.0)

    # Bone Archer: every third shot is a lobbed Grave Arrow onto the player's spot.
    _heal()
    var archer: BoneArcher = EnemyFactory.archer(_main, -9.0, -18.0, -7.5)
    archer.arrows_fired = 2
    _player.call("teleport_to", Vector3(-15.0, 1.0, 0.0))
    var lobbed: bool = await _wait_until(func() -> bool: return archer.lobs_fired >= 1, 3.0)
    var marks: Array = root.get_tree().get_nodes_in_group(&"strike_zone").filter(func(n: Node) -> bool: return absf((n as Node3D).global_position.x - _player.global_position.x) < 1.0)
    _check(lobbed and not marks.is_empty(), "the archer's third shot lobs a Grave Arrow onto the player's spot")
    _key(KEY_A, true)
    await _seconds(0.3)
    _key(KEY_A, false)
    await _seconds(1.0)
    _heal()
    _player.call("teleport_to", Vector3(archer.global_position.x + 1.5, 1.0, 0.0))  # room to hop left
    var hopped: bool = await _wait_until(func() -> bool: return archer.velocity.y > 3.0, 2.5)
    _check(hopped, "crowded, the archer Bone-Hops away")
    archer.health.apply_damage(archer.health.current)
    await _seconds(0.5)

    # Crypt Hound: runs in, crouches (telegraph), pounces, lands exposed.
    _heal()
    _player.call("teleport_to", Vector3(-16.0, 1.0, 0.0))
    var hound: CryptHound = EnemyFactory.hound(_main, -8.5, -18.0, -7.5)
    var crouched: bool = await _wait_until(func() -> bool: return hound.state_name() == "CROUCH", 3.0)
    _check(crouched and absf(hound.global_position.x - _player.global_position.x) < hound.pounce_range + 0.3, "the Crypt Hound runs in and crouches to pounce")
    hp0 = _player_hp()
    var landed: bool = await _wait_until(func() -> bool: return hound.state_name() == "RECOVER", 2.0)
    _check(landed and hound.pounces == 1 and _player_hp() < hp0, "its pounce lands on a player who stands still (hp %d -> %d)" % [hp0, _player_hp()])
    _heal()
    await _seconds(0.3)
    var hit: bool = false
    for i in 8:
        if hound.is_dead():
            break
        _player.set("facing_direction", signf(hound.global_position.x - _player.global_position.x))
        _tap(KEY_J)
        await _seconds(0.3)
    _check(hound.is_dead(), "the hound dies to the combo during its recovery")
    _check(_main.get("ambushes")[0].spawns.any(func(d: Dictionary) -> bool: return d["type"] == &"hound"), "Crypt Hounds join the ambushes")
    await _seconds(0.5)


## Level hazards: cycling spike traps and the pendulum blade hurt a player who ignores them,
## and can be passed by timing; respawning resets them.
func _m13_hazard_checks() -> void:
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    _enemy.set_ai_enabled(false)
    var traps: Array = _main.get("traps")
    var spikes: Array = traps.filter(func(t: Node) -> bool: return t is SpikeTrap)
    var blades: Array = traps.filter(func(t: Node) -> bool: return t is PendulumBlade)
    _check(spikes.size() == 3 and blades.size() == 1, "the level has 3 spike traps and a pendulum blade")
    var trap: SpikeTrap = spikes[0]
    _check(trap.state == SpikeTrap.State.DOWN, "disabled traps stay down")
    SpikeTrap.enabled = true
    PendulumBlade.enabled = true
    trap.reset()
    var seen: Dictionary = {}
    for i in int(trap.cycle_time() * PHYSICS_HZ) + 5:
        await physics_frame
        seen[trap.state] = true
    _check(seen.size() == 3, "a spike trap cycles down -> warning -> up")
    _heal()
    _player.call("teleport_to", Vector3(trap.global_position.x, 1.0, 0.0))
    var hp0: int = _player_hp()
    await _wait_until(func() -> bool: return _player_hp() < hp0, trap.cycle_time() + 0.5)
    _check(_player_hp() < hp0, "standing on the strip, the spikes hurt (hp %d -> %d)" % [hp0, _player_hp()])
    # Timed crossing: wait for the spikes to drop, then run across.
    _heal()
    _player.call("teleport_to", Vector3(trap.global_position.x - 2.5, 1.0, 0.0))
    await _seconds(1.0)
    await _wait_until(func() -> bool: return trap.state == SpikeTrap.State.UP, trap.cycle_time())
    await _wait_until(func() -> bool: return trap.state == SpikeTrap.State.DOWN, trap.cycle_time())
    hp0 = _player_hp()
    await _hold(KEY_D, 0.7)
    _check(_player_hp() == hp0 and _player.global_position.x > trap.global_position.x + 1.0, "running across while the spikes are down is safe")

    var blade: PendulumBlade = blades[0]
    _heal()
    _player.call("teleport_to", Vector3(blade.global_position.x, 1.0, 0.0))
    hp0 = _player_hp()
    await _wait_until(func() -> bool: return _player_hp() < hp0, blade.period + 0.3)
    _check(_player_hp() < hp0, "the pendulum blade cuts a player standing in its path (hp %d -> %d)" % [hp0, _player_hp()])
    var low_y: float = 99.0
    for i in int(blade.period * PHYSICS_HZ):
        await physics_frame
        low_y = minf(low_y, blade.blade_position().y)
    _check(low_y > 0.4 and low_y < 1.4, "the blade sweeps at waist height (lowest y=%.2f), so it can be jumped" % low_y)
    _player.call("revive_at", _player.global_position)
    _main.call("_reset_hazards")
    _check(trap.state == SpikeTrap.State.DOWN, "respawning resets the traps")
    SpikeTrap.enabled = false
    PendulumBlade.enabled = false
    await _seconds(0.3)


## Attributes, items and the Armory: spoils, equipping, stat preview, effect in the level,
## attack speed, and persistence.
func _m14_equipment_checks() -> void:
    var ids: Dictionary = {}
    for item: ItemData in ItemPool.ALL:
        ids[item.id] = true
    _check(ItemPool.ALL.size() == 13 and ids.size() == 13, "13 distinct items exist")
    var starters_plain: bool = ItemPool.STARTERS.all(func(id: StringName) -> bool: return ItemPool.by_id(id).stat_line() == "No bonuses")
    _check(starters_plain, "starter gear has no bonuses")
    for slot: int in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.CHARM]:
        _check(ItemPool.ALL.filter(func(i: ItemData) -> bool: return i.slot == slot).size() >= 3, "at least 3 %s items" % ItemData.slot_name(slot))

    # Base numbers used by the Armory preview match the real player.
    Profile.reset()
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    var health: Health = _player.get("health")
    var energy: BloodEnergy = _energy()
    var light: AttackData = _player.get("light_attack")
    var heavy: AttackData = _player.get("heavy_attack")
    var base_ok: bool = health.max_health == Equipment.BASE_HP and light.damage == Equipment.BASE_LIGHT and heavy.damage == Equipment.BASE_HEAVY
    base_ok = base_ok and light.next_combo.next_combo.damage == Equipment.BASE_FINISHER and is_equal_approx(float(_player.get("move_speed")), Equipment.BASE_SPEED)
    base_ok = base_ok and is_equal_approx(float(_player.get("dodge_cooldown")), Equipment.BASE_DODGE_COOLDOWN) and is_equal_approx(energy.per_hit, Equipment.BASE_BLOOD_PER_HIT) and is_equal_approx(energy.maximum, Equipment.BASE_MAX_BLOOD)
    _check(base_ok, "the Armory base stats match the player")

    # The Armory: spoils, equipping, preview.
    change_scene_to_file("res://scenes/armory.tscn")
    await _frames(10)
    var armory: Control = current_scene
    var offer: Array = armory.get("spoil_offer")
    _check((armory.get("spoils_box") as Control).visible and offer.size() == 3 and offer.all(func(i: ItemData) -> bool: return not Profile.stash.has(i.id)), "a new profile has spoils waiting: 3 items not yet owned")
    var claimed: ItemData = offer[1]
    _tap(KEY_2)
    await _frames(4)
    _check(Profile.stash.has(claimed.id) and Profile.equipped[claimed.slot] == claimed.id and Profile.pending_spoils == 0, "claiming spoils adds and equips %s" % claimed.display_name)
    _check(not (armory.get("spoils_box") as Control).visible, "no more spoils, the offer hides")
    for id: StringName in [&"gravecleaver", &"ossuary_plate", &"censer_locket"]:
        Profile.add_item(id)
    armory.call("refresh")
    await _frames(2)
    var buttons: Dictionary = armory.get("item_buttons")
    (buttons[&"gravecleaver"] as Button).pressed.emit()
    await _frames(2)
    buttons = armory.get("item_buttons")
    (buttons[&"ossuary_plate"] as Button).pressed.emit()
    await _frames(2)
    buttons = armory.get("item_buttons")
    (buttons[&"censer_locket"] as Button).pressed.emit()
    await _frames(2)
    _check(Profile.item_in(ItemData.Slot.WEAPON).id == &"gravecleaver" and Profile.item_in(ItemData.Slot.ARMOR).id == &"ossuary_plate" and Profile.item_in(ItemData.Slot.CHARM).id == &"censer_locket", "clicking stash items equips one per slot")
    var stats: String = (armory.get("stats_label") as Label).text
    var attrs: String = (armory.get("attributes_label") as Label).text
    _check(attrs.contains("Vigor 2") and attrs.contains("Might 2") and attrs.contains("Agility -2") and attrs.contains("Devotion 2"), "attributes add up across the three slots (%s)" % attrs.replace("\n", " "))
    _check(stats.contains("Health 7") and stats.contains("heavy 6") and stats.contains("x0.85"), "the stat preview shows the result (%s)" % stats.replace("\n", " | "))
    Profile.save("user://test_profile.cfg")

    # The gear works in the level.
    (armory.get("continue_button") as Button).pressed.emit()
    await _frames(10)
    _check(current_scene.scene_file_path == "res://scenes/draft.tscn", "Continue goes to the draft")
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    health = _player.get("health")
    energy = _energy()
    var melee: MeleeAttack = _melee()
    _check(health.max_health == 7 and health.current == 7, "Vigor 2: 7 max HP in the level")
    _check(absf(float(_player.get("move_speed")) - Equipment.BASE_SPEED * 0.92) < 0.01, "Agility -2: run speed %.2f" % float(_player.get("move_speed")))
    _check(is_equal_approx(energy.per_hit, 0.7) and is_equal_approx(energy.maximum, 7.0), "Devotion 2: %.1f blood per hit, max %.0f" % [energy.per_hit, energy.maximum])
    await _seconds(0.3)
    melee.start(_player.get("heavy_attack"), Vector3.RIGHT)
    _check(melee.hitbox.damage == 6, "Might 2 + Gravecleaver: heavy strike deals 6 (%d)" % melee.hitbox.damage)
    var heavy_frames: int = 0
    while melee.is_busy() and heavy_frames < 300:
        await physics_frame
        heavy_frames += 1
    var heavy_data: AttackData = _player.get("heavy_attack")
    var expected: int = _frames_for((heavy_data.startup + heavy_data.active + heavy_data.recovery) / 0.85)
    _check(absf(heavy_frames - expected) <= 3, "Gravecleaver swings at x0.85 speed (%d frames, expected ~%d)" % [heavy_frames, expected])
    await _seconds(0.5)

    # Persistence: the saved profile comes back.
    Profile.reset()
    Profile.load_from("user://test_profile.cfg")
    _check(Profile.stash.has(&"gravecleaver") and Profile.item_in(ItemData.Slot.WEAPON).id == &"gravecleaver" and Profile.item_in(ItemData.Slot.CHARM).id == &"censer_locket", "the profile (stash + equipped) persists through save and load")
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_profile.cfg"))
    Profile.reset()
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()


## Utility and ability cards: Shadow Step (teleport dash), Grave Hook, Ossuary Bridge,
## Blood Nova, Sigil of Haste.
func _m15_new_card_checks() -> void:
    _check(CardPool.ALL.size() == 13, "13 cards in the pool (%d)" % CardPool.ALL.size())
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()
    await _seconds(0.4)
    var cards: CardSystem = _cards()
    var energy: BloodEnergy = _energy()
    energy.regen_per_second = 0.0
    var melee: MeleeAttack = _melee()

    # Shadow Step: 4.5 m along facing, through an enemy, invulnerable.
    await _place(-1.0, 1.5, false)
    energy.set_amount(6.0)
    var x0: float = _player.global_position.x
    _check(cards.play_slot(_deal(&"shadow_step")) == &"ok", "Shadow Step plays")
    var moved: float = _player.global_position.x - x0
    _check(absf(moved - 4.5) < 0.2 and bool(_player.call("is_invulnerable")), "it teleports 4.5 m ahead through the soldier, untouchable (dx=%.2f)" % moved)
    await _seconds(3.0)
    # ...but never through a wall: the sealed portcullis stops it.
    _player.call("teleport_to", Vector3(16.6, 1.0, 0.0))
    _player.set("facing_direction", 1.0)
    await _seconds(0.3)
    energy.set_amount(6.0)
    cards.play_slot(_deal(&"shadow_step"))
    _check(_player.global_position.x < 18.4 and _player.global_position.x > 16.6, "Shadow Step stops at walls (x=%.2f, portcullis at 18.6)" % _player.global_position.x)
    await _seconds(3.0)

    # Grave Hook: yank to an enemy 7 m away and strike it.
    await _place(-1.0, 6.0, false)
    energy.set_amount(6.0)
    var hp0: int = _enemy.health.current
    var hook_x0: float = _player.global_position.x
    _check(cards.play_slot(_deal(&"grave_hook")) == &"ok", "Grave Hook plays on an enemy 7 m away")
    var gap: float = absf(_enemy.global_position.x - _player.global_position.x)
    _check(gap < 1.6 and _enemy.health.current == hp0 - 1, "it pulls you to the soldier and strikes it (gap %.2f, hp %d -> %d)" % [gap, hp0, _enemy.health.current])
    await _seconds(1.0)
    # From down in the gap (x -3..-1.5), the hook hauls you up onto the soldier's ledge.
    await _seconds(3.2)  # Grave Hook cooldown (4 s)
    _enemy.revive_at_home()
    _enemy.set_ai_enabled(false)
    _enemy.teleport_to(Vector3(2.5, 1.0, 0.0))
    _player.call("teleport_to", Vector3(-2.25, -1.2, 0.0))
    await _frames(2)
    energy.set_amount(6.0)
    _check(cards.play_slot(_deal(&"grave_hook")) == &"ok", "Grave Hook plays from inside a pit")
    await _seconds(0.4)
    _check(_player.global_position.y > 0.5 and _player.global_position.x > -1.0, "it pulls you up out of the pit onto the ledge (%.2f, %.2f)" % [_player.global_position.x, _player.global_position.y])
    await _seconds(1.0)

    # Blood Nova: area damage around you.
    _enemy.revive_at_home()
    await _place(3.0, 4.6, false)
    energy.set_amount(6.0)
    hp0 = _enemy.health.current
    _check(cards.play_slot(_deal(&"blood_nova")) == &"ok", "Blood Nova plays")
    await _seconds(0.3)
    _check(_enemy.health.current == hp0 - 2, "it hits an enemy within 3 m for 2 (hp %d -> %d)" % [hp0, _enemy.health.current])
    await _seconds(1.0)

    # Ossuary Bridge: a temporary platform ahead at foot level, then it crumbles.
    _enemy.revive_at_home()
    _player.call("teleport_to", Vector3(-16.0, 1.0, 0.0))
    _player.set("facing_direction", 1.0)
    await _seconds(0.4)
    energy.set_amount(6.0)
    _check(cards.play_slot(_deal(&"ossuary_bridge")) == &"ok", "Ossuary Bridge plays")
    await _frames(3)
    var bridges: Array[Node] = root.get_tree().get_nodes_in_group(&"bone_bridge")
    var bridge: Node3D = bridges[0] as Node3D if not bridges.is_empty() else null
    _check(bridge != null and bridge.global_position.x > _player.global_position.x and absf(bridge.global_position.y + 0.2) < 0.15, "a bone slab grows ahead at foot level")
    # Stand on it in mid-air: lift it above the floor and drop the player onto it.
    if bridge != null:
        bridge.global_position.y = 2.0
        _player.call("teleport_to", Vector3(bridge.global_position.x, 3.5, 0.0))
        await _seconds(0.6)
        _check(_player.is_on_floor() and _player.global_position.y > 2.5, "the slab is solid ground (y=%.2f)" % _player.global_position.y)
    await _seconds(5.0)
    _check(root.get_tree().get_nodes_in_group(&"bone_bridge").is_empty(), "the slab crumbles after 5 s")

    # Sigil of Haste: faster run and swings for 5 s.
    energy.set_amount(6.0)
    _check(cards.play_slot(_deal(&"haste_sigil")) == &"ok" and bool(_player.call("is_hasted")) and is_equal_approx(melee.haste_scale, 1.3), "Sigil of Haste speeds you up")
    var hx0: float = _player.global_position.x
    await _hold(KEY_D, 0.5)
    var hasted_dx: float = _player.global_position.x - hx0
    await _seconds(5.0)
    _check(not bool(_player.call("is_hasted")) and is_equal_approx(melee.haste_scale, 1.0), "haste wears off after 5 s")
    hx0 = _player.global_position.x
    await _hold(KEY_D, 0.5)
    var normal_dx: float = _player.global_position.x - hx0
    _check(hasted_dx > normal_dx * 1.15, "hasted you cover more ground (%.2f vs %.2f m)" % [hasted_dx, normal_dx])
    energy.regen_per_second = 0.25


## The first map: seeded room order and its rules, every room provably completable, and the
## full map building and joining up (opening -> 8 rooms -> approach -> arena).
func _m16_map_checks() -> void:
    # Layout rules.
    var plan_a: Array[Script] = LevelLayout.plan(1234)
    LevelLayout.classic = false
    plan_a = LevelLayout.plan(1234)
    var plan_b: Array[Script] = LevelLayout.plan(1234)
    _check(plan_a.size() == 8 and plan_a == plan_b, "a seed always deals the same 8-room map")
    var varied: bool = false
    for seed_value: int in [1, 2, 3, 4, 5, 6]:
        varied = varied or LevelLayout.plan(seed_value) != plan_a
    _check(varied, "different seeds deal different maps")
    var rules_ok: bool = true
    for seed_value: int in range(40):
        var plan: Array[Script] = LevelLayout.plan(seed_value)
        var act1: Array = plan.slice(0, 3)
        var act2: Array = plan.slice(4, 7)
        rules_ok = rules_ok and act1.all(func(r: Script) -> bool: return LevelLayout.ACT1.has(r))
        rules_ok = rules_ok and act2.all(func(r: Script) -> bool: return LevelLayout.ACT2.has(r))
        rules_ok = rules_ok and plan[3] == LevelLayout.ELITE and plan[7] == LevelLayout.MERCHANT
        var unique: Dictionary = {}
        for r: Script in plan:
            unique[r] = true
        rules_ok = rules_ok and unique.size() == 8
    _check(rules_ok, "40 seeds: Act I rooms first, elite 4th, Act II rooms, merchant last, never a repeat")
    LevelLayout.classic = true

    # Reachability: the validator itself, then every room.
    var probe: LevelSection = LevelSection.new()
    _check(LevelSection.can_jump(Rect2(0, 0, 4, 0), Rect2(7, 0, 4, 0)) and not LevelSection.can_jump(Rect2(0, 0, 4, 0), Rect2(13, 0, 4, 0)), "validator: a 3 m gap is jumpable, a 9 m gap is not")
    _check(LevelSection.can_jump(Rect2(0, 0, 4, 0), Rect2(5, 1.4, 4, 0)) and not LevelSection.can_jump(Rect2(0, 0, 4, 0), Rect2(5, 2.2, 4, 0)), "validator: a 1.4 m step is climbable, 2.2 m is not")
    probe.free()
    var holder: Node3D = Node3D.new()
    root.add_child(holder)
    var all_rooms: Array[Script] = []
    all_rooms.append_array(LevelLayout.ACT1)
    all_rooms.append_array(LevelLayout.ACT2)
    all_rooms.append(LevelLayout.ELITE)
    all_rooms.append(LevelLayout.MERCHANT)
    var broken: Array[String] = []
    for script: Script in all_rooms:
        var room: LevelSection = script.new() as LevelSection
        holder.add_child(room)
        room.build(1000.0)
        if not room.is_completable():
            broken.append(room.title)
    _check(broken.is_empty(), "all %d rooms are completable with running and jumping alone (failing: %s)" % [all_rooms.size(), broken])
    holder.queue_free()
    await _frames(2)

    # The full map in the level.
    LevelLayout.classic = false
    RunState.new_run(77)
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(12)
    _bind()
    var sections: Array = _main.get("sections")
    var offset: float = float(_main.get("map_offset"))
    var total: float = 0.0
    var joined: bool = true
    var x: float = 18.2
    for room: LevelSection in sections:
        joined = joined and is_equal_approx(room.origin_x, x)
        x += room.width
        total += room.width
    _check(sections.size() == 8 and is_equal_approx(offset, total) and joined, "the full map builds 8 rooms end to end (%.0f m of rooms)" % total)
    var arena: BossArena = _main.get("boss_arena")
    _check(is_equal_approx(arena.left_x(), 58.2 + offset), "the Bishop's approach and arena follow the last room (arena at x=%.1f)" % arena.left_x())
    # Drop into every room's checkpoint: solid ground, the HUD names the room, respawn moves there.
    var landed_all: bool = true
    for i in sections.size():
        var room: LevelSection = sections[i]
        _player.call("teleport_to", room.checkpoint.global_position + Vector3(0.0, 0.3, 0.0))
        await _seconds(0.5)
        landed_all = landed_all and _player.is_on_floor() and absf(_player.global_position.y - 0.85) < 0.2
        if i == 0:
            await _frames(2)
            var hud_text: String = (_main.get("hud") as Label).text
            _check(hud_text.contains("ROOM 1/8"), "the HUD names the current room")
            _check(_main.get("respawn_point") == room.checkpoint.respawn_position, "entering a room sets its checkpoint")
    _check(landed_all, "every room's entry checkpoint stands on solid ground")
    LevelLayout.classic = true
    RunState.end_run()
    change_scene_to_file("res://scenes/main.tscn")
    await _frames(10)
    _bind()


## Shielded Knight, Flying Wraith, Bone Crawler; Bone Shards; ambush waves.
func _m17_new_enemy_checks() -> void:
    await _seconds(0.3)
    _enemy.set_ai_enabled(false)
    var shards0: int = RunState.shards

    # Shielded Knight: frontal hits clang off, a heavy breaks the guard, hits from behind land.
    var knight: ShieldedKnight = EnemyFactory.spawn(&"knight", _main, -10.0, -18.0, -7.5) as ShieldedKnight
    knight.set_ai_enabled(false)
    _player.call("teleport_to", Vector3(-11.4, 1.0, 0.0))
    await _seconds(0.4)
    knight.facing = -1.0
    _player.set("facing_direction", 1.0)
    var hp0: int = knight.health.current
    _tap(KEY_J)
    await _seconds(0.5)
    _check(knight.health.current == hp0 and knight.blocks >= 1, "the Shielded Knight blocks a frontal jab (blocks=%d)" % knight.blocks)
    _tap(KEY_L)
    await _seconds(0.9)
    _check(knight.health.current < hp0 and (knight.state == &"stagger" or knight.state == &"hitstun"), "a heavy strike breaks its guard (hp %d -> %d, %s)" % [hp0, knight.health.current, knight.state])
    await _seconds(1.6)
    knight.facing = 1.0  # turned away: hit it in the back
    hp0 = knight.health.current
    _tap(KEY_J)
    await _seconds(0.5)
    _check(knight.health.current < hp0, "hits from behind land")
    knight.facing = -1.0
    knight.set_ai_enabled(true)
    _heal()
    var php: int = _player_hp()
    var bashed: bool = await _wait_until(func() -> bool: return knight.state == &"bash", 3.0)
    await _seconds(0.4)
    _check(bashed and _player_hp() < php, "it winds up and Shield Bashes (hp %d -> %d)" % [php, _player_hp()])
    knight.health.apply_damage(knight.health.current)
    await _frames(3)
    _check(RunState.shards == shards0 + knight.shard_value, "a slain knight drops %d Bone Shards (%d)" % [knight.shard_value, RunState.shards])
    await _seconds(1.0)

    # Flying Wraith: hovers above, telegraphs and dives.
    _heal()
    _player.call("teleport_to", Vector3(-12.0, 1.0, 0.0))
    var wraith: FlyingWraith = EnemyFactory.spawn(&"wraith", _main, -16.0, -19.0, -7.0) as FlyingWraith
    await _seconds(1.5)
    _check(wraith.global_position.y > _player.global_position.y + 1.5, "the wraith hovers above the player (dy=%.1f)" % (wraith.global_position.y - _player.global_position.y))
    php = _player_hp()
    var dove: bool = await _wait_until(func() -> bool: return wraith.dives >= 1, 4.0)
    await _seconds(0.8)
    _check(dove and _player_hp() < php, "it locks a red line on you and dives (hp %d -> %d)" % [php, _player_hp()])
    wraith.health.apply_damage(wraith.health.current)
    await _seconds(1.0)

    # Bone Crawler: runs in, fuses, bursts.
    _heal()
    _player.call("teleport_to", Vector3(-16.0, 1.0, 0.0))
    var crawler: BoneCrawler = EnemyFactory.spawn(&"crawler", _main, -9.0, -18.0, -7.5) as BoneCrawler
    php = _player_hp()
    var fused: bool = await _wait_until(func() -> bool: return crawler.state == &"fuse", 3.0)
    await _seconds(1.2)
    _check(fused and crawler.burst_spawned and crawler.is_dead() and _player_hp() < php, "the Bone Crawler runs in, fuses and bursts (hp %d -> %d)" % [php, _player_hp()])
    await _seconds(1.0)
    var crawler2: BoneCrawler = EnemyFactory.spawn(&"crawler", _main, -9.0, -18.0, -7.5) as BoneCrawler
    crawler2.set_ai_enabled(false)
    await _seconds(0.3)
    crawler2.health.apply_damage(1)
    await _frames(2)
    _check(crawler2.burst_spawned, "killed early, a crawler still bursts where it falls")
    await _seconds(1.0)

    # Ambush waves: the next wave rises when the first is dead.
    var waves: Ambush = Ambush.create("Ambush: test waves", -14.0, -18.5, -7.5, [{"type": &"husk", "x": -10.0}, {"type": &"crawler", "x": -9.0, "wave": 1}])
    _main.add_child(waves)
    Ambush.enabled = true
    _player.call("teleport_to", Vector3(-13.0, 1.0, 0.0))
    await _seconds(0.3)
    _check(waves.is_active() and waves.alive_count() == 1, "wave 1 of an ambush spawns")
    for e: Node3D in waves.enemies:
        (e.get("health") as Health).apply_damage(99)
    await _seconds(0.3)
    _check(waves.is_active() and waves.wave == 1 and waves.alive_count() == 1, "when it falls, wave 2 rises")
    for e: Node3D in waves.enemies:
        if not bool(e.call("is_dead")):
            (e.get("health") as Health).apply_damage(99)
    await _seconds(0.3)
    _check(waves.state == Ambush.State.CLEARED, "the last wave cleared drops the walls")
    Ambush.enabled = false
    _heal()
    await _seconds(1.5)


func _m3_boss_checks() -> void:
    var boss: HollowBishop = _main.get("boss")
    var arena: BossArena = _main.get("boss_arena")
    _check(boss.phase_name() == "DORMANT", "Bishop lies dormant before the approach")
    _heal()
    var reached: bool = await _m6_approach_checks(boss)
    reached = await _run_right_until(_bx(21.5), 5.0)
    _check(reached, "the approach leads into the Bishop's arena (x=%.2f)" % _player.global_position.x)
    _check(bool((_main.get("boss_checkpoint") as Checkpoint).is_active), "arena checkpoint activates")
    _check(boss.fight_started and boss.phase_name() == "PROCESSION", "reaching the arena turns the pursuit into the fight (phase=%s)" % boss.phase_name())
    _check(Audio.current_music == &"music_boss", "the boss track starts with the fight (%s)" % Audio.current_music)
    boss.set_ai_enabled(false)
    await _seconds(1.8)
    _check(boss.phase_name() == "PROCESSION", "Bishop rises into phase I (phase=%s)" % boss.phase_name())
    var bar: ProgressBar = _main.get("boss_bar")
    _check(bar.get_parent().visible and bar.value == boss.max_health and bar.max_value == boss.max_health, "boss HP bar shows %d/%d" % [bar.value, bar.max_value])
    await _boss_idle(boss)
    _check(boss.global_position.z < -20.0 and boss.global_position.y > -1.0, "Bishop stands far behind the play plane (z=%.1f)" % boss.global_position.z)
    await _shot("05_bishop_awake")
    await _barrage_checks(boss)

    # Hand Slam on a standing player: long telegraph, travels from depth, real damage.
    _heal()
    _player.call("teleport_to", Vector3(_bx(24.2), 1.0, 0.0))
    await _seconds(0.5)
    var hp0: int = _player_hp()
    boss.debug_attack(&"slam", _bx(24.2))
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
    _check(marker_lead >= 60, "slam telegraph plate shows %d frames before impact (>= 60, fairness floor)" % marker_lead)
    _check(absf(plate_x - _bx(24.2)) < 0.01, "telegraph plate marks the strike x (%.2f)" % plate_x)
    _check(min_hand_z < -7.5 and absf(impact_z) < 0.05, "hand travels from depth (z=%.1f) to the play plane (z=%.2f)" % [min_hand_z, impact_z])
    _check(_player_hp() == hp0 - 2, "slam deals 2 damage to a player who stays (%d → %d)" % [hp0, _player_hp()])

    # Same slam, but the player steps out of the plate during the telegraph.
    _heal()
    _player.call("teleport_to", Vector3(_bx(24.2), 1.0, 0.0))
    await _seconds(1.0)
    boss.debug_attack(&"slam", _bx(24.2))
    await _seconds(0.5)
    await _hold(KEY_D, 0.7)
    await _boss_idle(boss)
    _check(_player_hp() == 5, "stepping off the telegraphed plate avoids the slam (hp=%d)" % _player_hp())

    # Weak point: only the exposed stigmata on the fallen hand takes damage.
    _heal()
    _player.call("teleport_to", Vector3(_bx(28.0), 1.0, 0.0))
    await _seconds(0.5)
    var boss_hp: int = boss.health.current
    boss.debug_attack(&"slam", _bx(25.5))
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

    await _fix_tuning_checks(boss)

    # Bone Lance: thrown from depth along a telegraphed lane; hits only on the plane.
    _heal()
    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    await _seconds(0.5)
    hp0 = _player_hp()
    boss.debug_attack(&"lance", _bx(30.2))
    await _wait_until(func() -> bool: return _first_lance() != null, 1.0)
    var lance: BoneLance = _first_lance()
    _check(lance != null and lance.shaft_z() < -15.0 and lance.column.visible and absf(lance.global_position.x - _bx(30.2)) < 0.01,
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
    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    await _seconds(1.0)
    boss.debug_attack(&"lance", _bx(30.2))
    await _wait_until(func() -> bool: var l: BoneLance = _first_lance(); return l != null and l.shaft_z() > -5.0, 3.0)
    _key(KEY_SPACE, true)
    await _seconds(0.45)
    _key(KEY_SPACE, false)
    await _boss_idle(boss)
    _check(_player_hp() == 5, "jumping over the lance avoids it (hp=%d)" % _player_hp())

    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    await _seconds(0.6)
    boss.debug_attack(&"lance", _bx(30.2))
    await _wait_until(func() -> bool: var l: BoneLance = _first_lance(); return l != null and l.shaft_z() > -3.0, 3.0)
    _tap(KEY_K)
    await _boss_idle(boss)
    _check(_player_hp() == 5, "dodging out of the lane avoids the lance (hp=%d)" % _player_hp())

    # AI on its own: chooses both attack types in phase I.
    _heal()
    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    var seen: Dictionary = {}
    var record: Callable = func(attack: StringName) -> void: seen[attack] = true
    boss.attack_started.connect(record)
    boss.set_ai_enabled(true)
    await _seconds(10.0)
    boss.set_ai_enabled(false)
    boss.attack_started.disconnect(record)
    _check(seen.has(&"slam") and seen.has(&"lance_volley"), "Bishop AI alternates Hand Slam and Bone Lances (%s)" % [seen.keys()])
    await _boss_idle(boss)
    await _m8_new_attack_checks(boss)
    await _boss_idle(boss)
    await _seconds(1.0)

    # --- M4 Bloodbound Cards in the real boss fight -------------------------------
    await _m4_card_checks(boss)

    # Phase II: Sunder breaks the causeway; the route stays recoverable.
    boss.health.apply_damage(boss.health.current - boss.collapse_at)  # debug: jump to the phase threshold
    await _frames(2)
    _check(boss.phase_name() == "COLLAPSE" and "II" in (_main.get("boss_label") as Label).text, "HP %d enters phase II, shown on the bar" % boss.health.current)
    var banner: Label = _main.get("phase_banner")
    _check(boss.is_roaring() and banner.visible and "II" in banner.text, "entering phase II makes the Bishop roar and shows the phase banner (%s)" % banner.text.replace("\n", " / "))
    await _seconds(boss.roar_time + 0.2)
    _check(not boss.is_roaring(), "the roar ends after %.1f s" % boss.roar_time)
    _heal()
    _player.call("teleport_to", Vector3(_bx(21.0), 1.0, 0.0))
    await _seconds(0.5)
    boss.debug_attack(&"sunder", _bx(28.2))
    await _wait_until(func() -> bool: return arena.segments[2].is_broken, 4.0)
    _check(arena.segments[2].is_broken and arena.rubble[2].visible, "Sunder breaks the struck segment and exposes a rubble ledge")
    _check(not arena.can_break(1) and not arena.can_break(3) and not arena.can_break(0), "neighbours of a gap and the entry segment cannot break")
    await _boss_idle(boss)
    await _shot("07_causeway_broken")
    _player.call("teleport_to", Vector3(_bx(21.0), 1.0, 0.0))
    await _seconds(0.4)
    reached = await _run_right_until(_bx(33.0), 5.0)
    _check(reached and arena.segments[2].is_broken, "player jumps the broken segment (x=%.2f)" % _player.global_position.x)
    _player.call("teleport_to", Vector3(_bx(28.2), 0.5, 0.0))
    await _seconds(0.8)
    _check(_player.is_on_floor() and _player.global_position.y < 0.0, "rubble ledge catches a player who drops in (y=%.2f)" % _player.global_position.y)
    reached = await _run_right_until(_bx(31.5), 3.0)
    _check(reached, "player climbs out of the gap from the rubble (x=%.2f)" % _player.global_position.x)
    _player.call("teleport_to", Vector3(_bx(26.9), -2.0, 0.0))
    var cp: Vector3 = (_main.get("boss_checkpoint") as Checkpoint).respawn_position
    var reset: bool = await _wait_until(func() -> bool: return _player.global_position.distance_to(cp) < 1.0, 3.0)
    await _seconds(0.1)
    _check(reset and not arena.segments[2].is_broken, "falling respawns at the arena checkpoint and reknits the causeway")

    # Phase III: longer weak window; finish the Bishop through the stigmata.
    boss.health.apply_damage(boss.health.current - boss.covenant_at)  # debug: jump to the phase threshold
    _check(boss.phase_name() == "COVENANT", "HP %d enters phase III" % boss.health.current)
    _heal()
    _player.call("teleport_to", Vector3(_bx(28.0), 1.0, 0.0))
    await _seconds(0.5)
    boss.debug_attack(&"slam", _bx(25.5))
    await _wait_until(func() -> bool: return boss.hand.weak_open, 3.0)
    await _wait_until(func() -> bool: return not boss.hand.weak_open, 6.0)
    _check(boss.weak_open_seconds > phase1_window + 1.0, "phase III weak window is longer (%.2f s vs %.2f s)" % [boss.weak_open_seconds, phase1_window])
    await _boss_idle(boss)

    # Phase III AI: raises the dead and fires the Requiem Beam.
    _heal()
    _player.call("teleport_to", Vector3(_bx(30.2), 1.0, 0.0))
    var seen3: Dictionary = {}
    var record3: Callable = func(attack: StringName) -> void: seen3[attack] = true
    boss.attack_started.connect(record3)
    boss.set_ai_enabled(true)
    var overlapped: bool = false
    var secondaries0: int = boss.secondary_attacks_started
    for i in int(14.0 * PHYSICS_HZ):
        await physics_frame
        if _player_hp() < 3:
            _heal()
        overlapped = overlapped or (boss.is_attacking() and boss.secondary_actor() != null)
        if seen3.has(&"beam") and seen3.has(&"summon") and overlapped:
            break
    boss.set_ai_enabled(false)
    boss.attack_started.disconnect(record3)
    _check(seen3.has(&"summon") and seen3.has(&"beam"), "phase III AI raises the dead and fires the Requiem Beam (%s)" % [seen3.keys()])
    _check(overlapped and boss.secondary_attacks_started > secondaries0, "from phase III the Bishop runs a second ability alongside its main attack (%d)" % (boss.secondary_attacks_started - secondaries0))
    _check(not boss.start_secondary(&"censer", _bx(30.0)) or boss.attack_actor() == null or boss.attack_actor() is not RequiemBeam, "never a censer on top of the beam")
    await _boss_idle(boss)
    boss.clear_minions()
    await _seconds(0.3)

    # Phase IV: the Unmaking — longest weak-point window.
    var cov_window: float = boss.weak_open_seconds
    boss.health.apply_damage(boss.health.current - boss.unmaking_at)  # debug: jump to the phase threshold
    await _frames(2)
    _check(boss.phase_name() == "UNMAKING" and boss.is_roaring() and "IV" in (_main.get("phase_banner") as Label).text, "HP %d enters phase IV, the Unmaking (roar + banner)" % boss.health.current)
    _heal()
    _player.call("teleport_to", Vector3(_bx(28.0), 1.0, 0.0))
    await _seconds(0.5)
    boss.debug_attack(&"slam", _bx(25.5))
    await _wait_until(func() -> bool: return boss.hand.weak_open, 3.0)
    await _wait_until(func() -> bool: return not boss.hand.weak_open, 7.0)
    _check(boss.weak_open_seconds > cov_window + 0.5, "phase IV weak window is the longest (%.2f s vs %.2f s)" % [boss.weak_open_seconds, cov_window])
    await _boss_idle(boss)
    boss.debug_attack(&"summon", _bx(30.0))
    await _wait_until(func() -> bool: return boss.minions().size() >= 1, 3.0)
    await _boss_idle(boss)
    _heal()
    boss.health.apply_damage(boss.health.current - 3)  # debug: skip to the last 3 HP (tuning is checked separately)
    boss.debug_attack(&"slam", _bx(25.5))
    await _wait_until(func() -> bool: return boss.hand.weak_open, 3.0)
    _player.set("facing_direction", -1.0)
    _tap(KEY_L)
    await _seconds(0.9)
    for i in 6:  # the faster Unmaking may crowd the window: keep jabbing while it is open
        if boss.health.current == 0:
            break
        _player.set("facing_direction", -1.0)
        _tap(KEY_J)
        await _seconds(0.35)
    await _seconds(0.2)
    _check(boss.health.current == 0 and boss.phase_name() == "DEFEATED", "final stigmata hits defeat the Bishop (hp=%d, phase=%s)" % [boss.health.current, boss.phase_name()])
    await _frames(3)
    _check(root.get_tree().get_nodes_in_group(&"bishop_minion").filter(func(m: Node) -> bool: return not m.is_queued_for_deletion()).is_empty(), "the Bishop's Husks crumble when it falls")
    await _seconds(1.0)
    _check(not boss.is_attacking() and _first_lance() == null, "defeated Bishop stops attacking")


func _shot(name: String) -> void:
    if DisplayServer.get_name() == "headless":
        return
    await _frames(2)
    print("PERF %-22s fps=%3d  process_ms=%5.2f  physics_ms=%5.2f  draw_calls=%4d  objects=%5d  static_mem_mb=%.1f" % [name,
        Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
        Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
        Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_COUNT),
        Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
    var img: Image = root.get_viewport().get_texture().get_image()
    img.save_png(SHOT_DIR + name + ".png")

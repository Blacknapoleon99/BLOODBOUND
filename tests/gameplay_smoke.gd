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

var _failures: int = 0
var _checks: int = 0
var _max_abs_z_in_2d: float = 0.0
var _main: Node3D
var _player: CharacterBody3D


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
	var ground_y: float = _player.global_position.y
	_tap(KEY_SPACE)
	var peak: float = ground_y
	for i in int(1.2 * PHYSICS_HZ):
		await physics_frame
		peak = maxf(peak, _player.global_position.y)
	_check(peak > ground_y + 1.2, "Space jumps (peak rise=%.2f)" % (peak - ground_y))
	_check(_player.is_on_floor(), "player lands again after jump")

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
	var reached: bool = await _run_right_until(3.2, 8.0)
	_check(reached, "traversed gaps and raised step to the dummy (x=%.2f)" % _player.global_position.x)
	await _shot("02_at_dummy")

	# --- Melee ---------------------------------------------------------------
	_check(bool(_main.get("enemy_alive")), "dummy is alive before attacking")
	_tap(KEY_J)
	await _frames(3)
	_check(not bool(_main.get("enemy_alive")), "J attack defeats the dummy when facing it in range")

	# --- Walk to the amber gate and enter the 3D arena -----------------------
	reached = await _run_right_until(12.6, 6.0)
	_check(reached, "walked to the amber gate (x=%.2f)" % _player.global_position.x)
	await _seconds(0.3)
	_tap(KEY_E)
	await _frames(3)
	_check(bool(_player.get("in_3d_mode")), "E near the gate enters 3D mode")
	_check(bool(_main.get("arena_visited")), "arena flagged as visited")
	await _seconds(1.5)
	_check(_player.is_on_floor(), "player stands on the arena floor")
	var cam: Camera3D = _main.get("camera")
	var arena_offset: Vector3 = cam.global_position - _player.global_position
	_check(absf(arena_offset.z - 11.5) < 1.0 and absf(arena_offset.y - 5.8) < 1.0, "camera moves to closer arena framing (offset=%s)" % arena_offset)
	await _shot("03_arena")

	var z0: float = _player.global_position.z
	await _hold(KEY_W, 0.5)
	var z1: float = _player.global_position.z
	_check(z1 < z0 - 1.5, "W moves into depth in arena (dz=%.2f)" % (z1 - z0))
	await _hold(KEY_S, 0.8)
	var z2: float = _player.global_position.z
	_check(z2 > z1 + 2.0, "S moves toward camera in arena (dz=%.2f)" % (z2 - z1))
	await _hold(KEY_D, 0.4)
	_check(absf(_player.global_position.z) > 0.2, "depth position persists while strafing in arena")

	# --- Return to 2.5D ------------------------------------------------------
	_tap(KEY_E)
	await _frames(3)
	_check(not bool(_player.get("in_3d_mode")), "E in arena returns to 2.5D mode")
	_check(absf(_player.global_position.z) < 0.001, "return restores Z=0 plane lock")
	await _seconds(1.5)
	var side_offset: Vector3 = cam.global_position - _player.global_position
	_check(absf(side_offset.z - 22.0) < 1.0, "camera returns to side-view framing (offset=%s)" % side_offset)

	# --- Exit / victory / restart -------------------------------------------
	reached = await _run_right_until(17.3, 4.0)
	await _frames(3)
	_check(bool(_main.get("game_won")), "reaching EXIT after defeating the dummy wins")
	_check(bool(_player.get("game_frozen")), "player is frozen on victory")
	await _shot("04_victory")
	_tap(KEY_R)
	await _frames(10)
	_bind()
	await _seconds(0.5)
	_check(bool(_main.get("enemy_alive")) and not bool(_main.get("game_won")), "R restarts with fresh state")
	_check(_player.global_position.distance_to(spawn) < 2.5, "restart places player at spawn")

	_check(_max_abs_z_in_2d < 0.001, "no Z drift during 2.5D play (max |z|=%.4f)" % _max_abs_z_in_2d)

	print("SMOKE RESULT: %d/%d checks passed" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)


func _bind() -> void:
	_main = current_scene as Node3D
	_player = _main.get("player") as CharacterBody3D


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
	var jump_held: bool = false
	var ok: bool = false
	for i in int(timeout * PHYSICS_HZ):
		await physics_frame
		_track_z()
		var x: float = _player.global_position.x
		if x >= target_x:
			ok = true
			break
		var near_gap: bool = (x > -7.9 and x < -7.4) or (x > -3.4 and x < -3.0)
		var want_jump: bool = _player.is_on_floor() and (near_gap or _player.is_on_wall())
		if want_jump and not jump_held:
			_key(KEY_SPACE, true)
			jump_held = true
		elif jump_held:
			_key(KEY_SPACE, false)
			jump_held = false
	_key(KEY_D, false)
	_key(KEY_SPACE, false)
	return ok


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _frames(2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + name + ".png")

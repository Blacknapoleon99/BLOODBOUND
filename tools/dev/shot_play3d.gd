extends SceneTree
## Dev capture (visible window only): the 3D run through the gameplay camera, with a few
## seconds of scripted input. Writes play3d_*.png to the folder given after "--" (default user://).

var _out: String = "user://"


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, down: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out.path_join("play3d_%s.png" % name))
	var p: Node3D = current_scene.get("player") as Node3D
	var motor: Object = p.get("motor") if p != null else null
	print("%-10s pos=%s state=%s" % [name, p.global_position if p else Vector3.ZERO, motor.call("anim_state") if motor else "?"])


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	GameSettings.persistence_enabled = false
	LevelLayout.classic = false
	RunState.full_3d = true
	RunState.new_run(77)
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(1.5)
	await _shot("0_start")
	_key(KEY_D, true)
	await _wait(1.2)
	await _shot("1_run")
	_key(KEY_SPACE, true)
	await _wait(0.25)
	await _shot("2_jump")
	_key(KEY_SPACE, false)
	await _wait(0.8)
	_key(KEY_D, false)
	await _wait(0.4)
	await _shot("3_land")
	_key(KEY_A, true)
	await _wait(2.5)
	await _shot("4_back")
	_key(KEY_A, false)
	RunState.full_3d = false
	RunState.end_run()
	quit()

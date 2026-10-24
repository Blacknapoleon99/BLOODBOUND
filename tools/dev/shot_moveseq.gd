extends SceneTree
## Dev capture (visible window only): frame sequences of the 3D hero's basic moves in the
## movement playground, through the gameplay camera. Every 0.1 s writes seq_<move>_<nn>.png
## to the folder given after "--" (default user://) and prints the motor state, the pose, the
## body speed and the animator's playing clip, so mismatches can be read off side by side.

var _out: String = "user://"
var _p: CharacterBody3D
var _frame: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, down: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _capture(move: String, seconds: float) -> void:
	var steps: int = int(round(seconds / 0.1))
	for i in steps:
		for f in 6:
			await physics_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_viewport().get_texture().get_image()
		img.resize(640, 360)
		img.save_png(_out.path_join("seq_%s_%02d.png" % [move, i]))
		var motor: PlatformerMotor = _p.get("motor")
		var a: Dictionary = motor.anim_state()
		var speed: float = Vector2(_p.velocity.x, _p.velocity.z).length()
		var anim: AnimationPlayer = _p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		print("%s_%02d state=%-11s pose=%-12s spd=%5.2f vy=%5.2f floor=%s clip=%s" % [move, i,
			PlatformerMotor.State.keys()[motor.state], a["pose"], speed, _p.velocity.y, _p.is_on_floor(),
			anim.current_animation if anim else "-"])


func _reset() -> void:
	_p.call("teleport_to", Vector3(0.0, 1.2, 0.0))
	for i in 30:
		await physics_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	GameSettings.persistence_enabled = false
	change_scene_to_file("res://scenes/playground_3d.tscn")
	for i in 60:
		await physics_frame
	_p = current_scene.get("player")
	var which: String = args[1] if args.size() > 1 else "all"
	if which in ["all", "run"]:
		await _reset()
		_key(KEY_D, true)
		await _capture("run", 1.2)
		_key(KEY_D, false)
		await _capture("stop", 0.6)
	if which in ["all", "turn"]:
		await _reset()
		_key(KEY_W, true)
		await _capture("turn", 0.8)
		_key(KEY_W, false)
		_key(KEY_S, true)
		await _capture("turn_rev", 1.0)
		_key(KEY_S, false)
	if which in ["all", "jump"]:
		await _reset()
		_key(KEY_W, true)
		for i in 40:
			await physics_frame
		_key(KEY_SPACE, true)
		await _capture("jump", 1.1)
		_key(KEY_SPACE, false)
		_key(KEY_W, false)
		await _capture("jump_end", 0.4)
	if which in ["all", "attack"]:
		await _reset()
		_key(KEY_W, true)
		for i in 30:
			await physics_frame
		_key(KEY_J, true)
		await _capture("attack", 0.8)
		_key(KEY_J, false)
		_key(KEY_W, false)
		await _capture("attack_end", 0.5)
	quit()

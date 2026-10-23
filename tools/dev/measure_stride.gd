extends SceneTree
## Measures the real ground speed of the hero's locomotion clips (walk, run, sprint): the planted
## foot's speed relative to the hips while it is the lower foot, in metres per second for a hero
## scaled to 1.8 m. ArtAnimator's WALK_REF / RUN_REF should match these, or the feet skate.
## Run: godot --headless --path . -s res://tools/dev/measure_stride.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = (load("res://assets/models/player/bone_revenant.glb") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var extra: AnimationLibrary = load("res://assets/models/player/hero_kimodo_anims.res") as AnimationLibrary
	if extra != null and not ap.has_animation_library(&"kimodo"):
		ap.add_animation_library(&"kimodo", extra)
	var lt: int = _bone(skel, "LeftToeBase")
	var rt: int = _bone(skel, "RightToeBase")
	var hips: int = _bone(skel, "Hips")
	var head: int = _bone(skel, "HeadTop_End")
	skel.reset_bone_poses()
	var height: float = skel.get_bone_global_rest(head).origin.y - skel.get_bone_global_rest(lt).origin.y
	var scale: float = 1.8 / height
	print("model height %.3f -> scale %.3f" % [height, scale])
	for clip: String in ["walk", "run", "kimodo/sprint", "kimodo/walk", "kimodo/run", "sprint"]:
		if not ap.has_animation(clip):
			continue
		var anim: Animation = ap.get_animation(clip)
		ap.play(clip)
		var speeds: Array[float] = []
		var prev: Dictionary = {}
		var dt: float = 1.0 / 120.0
		var t: float = 0.0
		while t < anim.length:
			ap.seek(t, true)
			ap.advance(0.0)
			skel.force_update_all_bone_transforms()
			var h: Vector3 = skel.get_bone_global_pose(hips).origin
			var l: Vector3 = skel.get_bone_global_pose(lt).origin - h
			var r: Vector3 = skel.get_bone_global_pose(rt).origin - h
			var low: Vector3 = l if l.y < r.y else r
			var key: String = "l" if l.y < r.y else "r"
			if prev.has(key):
				var d: Vector3 = (low - prev[key]) / dt
				speeds.append(Vector2(d.x, d.z).length() * scale)
			prev = {key: low}
			t += dt
		speeds.sort()
		var med: float = speeds[speeds.size() / 2] if not speeds.is_empty() else 0.0
		print("%s: length %.2f s, planted-foot speed median %.2f m/s (p25 %.2f, p75 %.2f)" % [clip, anim.length, med,
			speeds[speeds.size() / 4], speeds[speeds.size() * 3 / 4]])
	quit()


func _bone(skel: Skeleton3D, suffix: String) -> int:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).ends_with(suffix):
			return i
	return -1

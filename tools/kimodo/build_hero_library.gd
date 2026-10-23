extends SceneTree
## Builds the hero's Kimodo AnimationLibrary from tools/kimodo/kimodo_to_hero.py output (DEC-059).
##   godot --headless --path . -s res://tools/kimodo/build_hero_library.gd -- <clips.json> <out.res>
## Track paths are taken from the hero's own imported clips, so the library plays on the same
## AnimationPlayer. Each Animation carries metadata from the retarget: "strike" (seconds, the sword
## hand's fastest frame = the swing's contact), "motion_start", "motion_end", "treadmill_speed".

const HERO: String = "res://assets/models/player/bone_revenant.glb"


func _init() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2:
        push_error("usage: -- <clips.json> <out.res>")
        quit(1)
        return
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    var hero: Node = (load(HERO) as PackedScene).instantiate()
    var player: AnimationPlayer = hero.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
    var skeleton: Skeleton3D = hero.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
    # Path prefix of the skeleton as the hero's own clips address it ("<path>:<bone>").
    var sample: Animation = player.get_animation(&"idle")
    var prefix: String = ""
    for t in sample.get_track_count():
        var p: NodePath = sample.track_get_path(t)
        if p.get_subname_count() > 0:
            prefix = String(p.get_concatenated_names())
            break
    var lib: AnimationLibrary = AnimationLibrary.new()
    var fps: float = float(data["fps"])
    for clip: Dictionary in data["clips"]:
        var anim: Animation = Animation.new()
        var frames: int = int(clip["meta"]["frames"])
        anim.length = (frames - 1) / fps
        anim.loop_mode = Animation.LOOP_LINEAR if clip["loop"] else Animation.LOOP_NONE
        for key: String in clip["meta"]:
            if key != "source_frames":
                anim.set_meta(StringName(key), clip["meta"][key])
        var tracks: Dictionary = clip["tracks"]
        for gltf_name: String in tracks:
            var bone: String = _bone(skeleton, gltf_name)
            if bone == "":
                push_warning("no bone for %s" % gltf_name)
                continue
            var path: NodePath = NodePath("%s:%s" % [prefix, bone])
            var tr: Dictionary = tracks[gltf_name]
            if tr.has("pos"):
                var pi: int = anim.add_track(Animation.TYPE_POSITION_3D)
                anim.track_set_path(pi, path)
                var pos: Array = tr["pos"]
                for f in frames:
                    var v: Array = pos[f]
                    anim.position_track_insert_key(pi, f / fps, Vector3(v[0], v[1], v[2]))
            var ri: int = anim.add_track(Animation.TYPE_ROTATION_3D)
            anim.track_set_path(ri, path)
            var rot: Array = tr["rot"]
            for f in frames:
                var q: Array = rot[f]
                anim.rotation_track_insert_key(ri, f / fps, Quaternion(q[0], q[1], q[2], q[3]).normalized())
        anim.optimize()  # drop keys that interpolation reproduces (Godot defaults)
        lib.add_animation(StringName(clip["name"]), anim)
    var err: Error = ResourceSaver.save(lib, args[1], ResourceSaver.FLAG_COMPRESS)
    print("saved %s: %d clips (%s), prefix %s" % [args[1], lib.get_animation_list().size(), error_string(err), prefix])
    hero.free()
    quit(0 if err == OK else 1)


## The skeleton's name for a glTF joint ("mixamorig:Hips" may be imported as "mixamorig_Hips").
func _bone(skeleton: Skeleton3D, gltf_name: String) -> String:
    for candidate: String in [gltf_name, gltf_name.replace(":", "_"), gltf_name.replace(":", "")]:
        if skeleton.find_bone(candidate) != -1:
            return candidate
    return ""

class_name ArtCloth
extends RefCounted
## Real-time cloth for rigged ArtSwap models: a SpringBoneSimulator3D on the bone chains added in
## Blender down each cloth panel ("<Prefix>0".."<Prefix>2"), with capsule colliders on the hips
## and thighs so the panels swing and trail but don't pass through the legs. Visual only.

## Chain roots in the model's skeleton (see assets/source/player/bone_revenant.blend).
const CHAINS: Array[String] = ["ClothFrontL", "ClothFrontR", "ClothBackL", "ClothBackR"]
const CHAIN_LENGTH: int = 3
## Tuned for knee-length rag panels: firm enough to hang, drag so they settle, gravity to pull them down.
const STIFFNESS: float = 4.5
const DRAG: float = 0.8
const GRAVITY: float = 1.5
const RADIUS: float = 0.012
const TIP_LENGTH: float = 0.06
## Colliders: bone suffix -> [radius, height] in skeleton units (the model is 1 unit tall).
const COLLIDERS: Dictionary = {
    "LeftUpLeg": [0.045, 0.26], "RightUpLeg": [0.045, 0.26], "Hips": [0.075, 0.16],
    "LeftLeg": [0.035, 0.24], "RightLeg": [0.035, 0.24],
}


## Returns the simulator, or null when the model has no cloth chains.
static func attach(art: Node3D) -> SpringBoneSimulator3D:
    var skeletons: Array[Node] = art.find_children("*", "Skeleton3D", true, false)
    if skeletons.is_empty():
        return null
    var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
    var chains: Array[String] = []
    for prefix: String in CHAINS:
        if skeleton.find_bone(prefix + "0") != -1 and skeleton.find_bone(prefix + str(CHAIN_LENGTH - 1)) != -1:
            chains.append(prefix)
    if chains.is_empty():
        return null
    var sim: SpringBoneSimulator3D = SpringBoneSimulator3D.new()
    sim.name = "ArtCloth"
    skeleton.add_child(sim)
    sim.setting_count = chains.size()
    for i in chains.size():
        sim.set_root_bone_name(i, chains[i] + "0")
        sim.set_end_bone_name(i, chains[i] + str(CHAIN_LENGTH - 1))
        sim.set_extend_end_bone(i, true)
        sim.set_end_bone_length(i, TIP_LENGTH)
        sim.set_stiffness(i, STIFFNESS)
        sim.set_drag(i, DRAG)
        sim.set_gravity(i, GRAVITY)
        sim.set_radius(i, RADIUS)
        sim.set_enable_all_child_collisions(i, true)
    for suffix: String in COLLIDERS:
        var bone: String = _bone_ending(skeleton, suffix)
        if bone == "":
            continue
        var capsule: SpringBoneCollisionCapsule3D = SpringBoneCollisionCapsule3D.new()
        capsule.name = "Collide" + suffix
        capsule.bone_name = bone
        capsule.radius = COLLIDERS[suffix][0]
        capsule.height = COLLIDERS[suffix][1]
        # Capsules run along the node's Y; centre them halfway down the bone (bones point along +Y).
        capsule.position_offset = Vector3(0.0, COLLIDERS[suffix][1] * 0.5, 0.0)
        sim.add_child(capsule)
    return sim


static func _bone_ending(skeleton: Skeleton3D, suffix: String) -> String:
    for i in skeleton.get_bone_count():
        var bone_name: String = skeleton.get_bone_name(i)
        if bone_name.ends_with(suffix) and not bone_name.begins_with("Cloth"):
            return bone_name
    return ""

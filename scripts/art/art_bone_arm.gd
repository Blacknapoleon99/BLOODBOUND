class_name ArtBoneArm
extends Node3D
## Visual-only arm for the Hollow Bishop model. The slam hand flies ~28 m from the shoulder to
## the play plane, more than three times the model's own arm (8 m). Stretching the model's arm
## that far tears the robe it is skinned with (tested: the Tripo auto-rig weights the sleeve to
## the body), so the model's right arm is folded away (a SkeletonModifier3D scales it to
## nothing) and a long skeletal arm grows from the model's real shoulder: a humerus to a raised
## elbow, then twin forearm bones (radius + ulna) to the slam hand's wrist. Replaces the greybox
## "SlamArm" box. In the planned full-3D version the Bishop slams within its natural reach and
## uses its own arm.

const SHOULDER_BONE: String = "RightArm"
const BONE_COLOR: Color = Color(0.6, 0.56, 0.48)  # matched to the model's bone texture

var bishop: Node3D
var hand: Node3D
var skeleton: Skeleton3D
var _shoulder_bone: int = -1
var _humerus: MeshInstance3D
var _radius: MeshInstance3D
var _ulna: MeshInstance3D
var _elbow: MeshInstance3D
var _knob: MeshInstance3D


static func attach(owner_bishop: Node3D, art: Node3D) -> ArtBoneArm:
    var skeletons: Array[Node] = art.find_children("*", "Skeleton3D", true, false)
    var owner_hand: Node3D = owner_bishop.get("hand") as Node3D
    if skeletons.is_empty() or owner_hand == null:
        return null
    var arm: ArtBoneArm = ArtBoneArm.new()
    arm.name = "ArtBoneArm"
    arm.top_level = true
    arm.bishop = owner_bishop
    arm.hand = owner_hand
    arm.skeleton = skeletons[0] as Skeleton3D
    for i in arm.skeleton.get_bone_count():
        if arm.skeleton.get_bone_name(i).ends_with(SHOULDER_BONE):
            arm._shoulder_bone = i
            break
    if arm._shoulder_bone == -1:
        return null
    var fold: FoldArm = FoldArm.new()
    fold.name = "FoldArm"
    fold.bone = arm._shoulder_bone
    arm.skeleton.add_child(fold)
    var greybox: Node3D = owner_bishop.get("_arm") as Node3D
    if greybox != null:
        greybox.visible = false
    arm._build()
    owner_bishop.add_child(arm)
    return arm


func _build() -> void:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = BONE_COLOR
    material.roughness = 0.85
    _humerus = _bone_mesh(0.9, 0.5, material)
    _radius = _bone_mesh(0.38, 0.28, material)
    _ulna = _bone_mesh(0.32, 0.24, material)
    _elbow = _joint_mesh(0.85, material)
    _knob = _joint_mesh(0.95, material)


func _bone_mesh(thick: float, thin: float, material: Material) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = thin
    mesh.bottom_radius = thick
    mesh.height = 1.0
    mesh.radial_segments = 10
    node.mesh = mesh
    node.material_override = material
    add_child(node)
    return node


func _joint_mesh(radius: float, material: Material) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    node.mesh = mesh
    node.material_override = material
    add_child(node)
    return node


func _process(_delta: float) -> void:
    if not is_instance_valid(bishop) or not is_instance_valid(hand) or not bishop.visible:
        visible = false
        return
    visible = true
    var shoulder: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(_shoulder_bone)).origin
    var wrist: Vector3 = hand.get_global_transform_interpolated().origin + Vector3(0.0, 0.3, -1.0)
    var span: Vector3 = wrist - shoulder
    var reach: float = span.length()
    if reach < 0.5:
        return
    # A raised elbow: the bend grows as the hand comes closer (a slack arm bends more).
    var bend: float = clampf(18.0 - reach * 0.35, 2.0, 9.0)
    var elbow: Vector3 = shoulder.lerp(wrist, 0.42) + Vector3.UP * bend
    _place(_humerus, shoulder, elbow, Vector3.ZERO)
    var side: Vector3 = span.cross(Vector3.UP).normalized() * 0.35
    _place(_radius, elbow, wrist, side)
    _place(_ulna, elbow, wrist, -side)
    _elbow.global_position = elbow
    _knob.global_position = shoulder


## Stretches a unit cylinder between `a` and `b` (offset sideways by `shift`).
func _place(node: MeshInstance3D, a: Vector3, b: Vector3, shift: Vector3) -> void:
    var span: Vector3 = b - a
    var length: float = span.length()
    if length < 0.01:
        return
    var up: Vector3 = span / length
    var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
    var basis_to: Basis = Basis(side, up, side.cross(up)).scaled_local(Vector3(1.0, length, 1.0))
    node.global_transform = Transform3D(basis_to, (a + b) * 0.5 + shift)


## Folds the model's own right arm away (scale ~0 on the shoulder bone after animation).
class FoldArm extends SkeletonModifier3D:
    var bone: int = -1

    func _process_modification_with_delta(_delta: float) -> void:
        var skel: Skeleton3D = get_skeleton()
        if skel != null and bone >= 0:
            skel.set_bone_pose_scale(bone, Vector3.ONE * 0.001)

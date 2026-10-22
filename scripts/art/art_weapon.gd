class_name ArtWeapon
extends Node
## Visual-only sword for a rigged ArtSwap player: lives in a back socket while exploring, moves to
## the right-hand socket on the first attack, and sheathes again after a quiet spell. Hit timing
## and hitboxes stay in gameplay code; this only reads `attack_started` and nearby enemies.

const SHEATHE_AFTER: float = 4.0  # seconds with no attack...
const QUIET_RADIUS: float = 8.0   # ...and no living enemy this close to this weapon's player

## The sword GLB has its origin on the grip, blade along +Y, 1.1 m long. Placements are given in
## the model's own skeleton space (Tripo: 1 unit tall, feet at 0, facing +Z, the character's right
## hand on -X, T-pose rest) and converted to bone-local fits from the rest pose, so they do not
## depend on Mixamo bone axes.
const HAND_BONE_SUFFIX: String = "RightHand"
const SHEATH_BONE_SUFFIX: String = "Spine2"
const SWORD_LENGTH_M: float = 1.1
## Scabbard on the back: grip over the right shoulder, blade down toward the left hip.
const SHEATH_GRIP: Vector3 = Vector3(-0.07, 0.80, -0.09)
const SHEATH_BLADE_DIR: Vector3 = Vector3(0.45, -0.89, 0.0)
const SHEATH_FLAT_NORMAL: Vector3 = Vector3(0.0, 0.0, -1.0)
## In the fist (T-pose rest: fingers along -X, thumb forward +Z): blade out along the thumb side.
const HAND_GRIP_OFFSET: Vector3 = Vector3(-0.035, -0.005, 0.0)
const HAND_BLADE_DIR: Vector3 = Vector3(0.0, 0.0, 1.0)
const HAND_FLAT_NORMAL: Vector3 = Vector3(0.0, 1.0, 0.0)

var hand_fit: Transform3D
var sheath_fit: Transform3D

var body: Node3D
var sword: Node3D
var hand_socket: BoneAttachment3D
var sheath_socket: BoneAttachment3D
var drawn: bool = false
var _quiet: float = 0.0


## Adds sockets to the first Skeleton3D under `art` and parents a sword instance to the sheath.
static func attach(owner_body: Node3D, art: Node3D, sword_scene: PackedScene, scale: float) -> ArtWeapon:
    var skeletons: Array[Node] = art.find_children("*", "Skeleton3D", true, false)
    if skeletons.is_empty() or sword_scene == null:
        return null
    var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
    var weapon: ArtWeapon = ArtWeapon.new()
    weapon.name = "ArtWeapon"
    weapon.body = owner_body
    weapon.hand_socket = _socket(skeleton, "WeaponHand", HAND_BONE_SUFFIX)
    weapon.sheath_socket = _socket(skeleton, "WeaponSheath", SHEATH_BONE_SUFFIX)
    if weapon.hand_socket == null or weapon.sheath_socket == null:
        return null
    # Skeleton space is the 1-unit model; the ArtSwap fit scales it by `scale` metres.
    var units: float = 1.0 / maxf(scale, 0.001)
    var hand_rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone(weapon.hand_socket.bone_name))
    var sheath_rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone(weapon.sheath_socket.bone_name))
    weapon.hand_fit = hand_rest.affine_inverse() * _placement(hand_rest.origin + HAND_GRIP_OFFSET, HAND_BLADE_DIR, HAND_FLAT_NORMAL, units)
    weapon.sheath_fit = sheath_rest.affine_inverse() * _placement(SHEATH_GRIP, SHEATH_BLADE_DIR, SHEATH_FLAT_NORMAL, units)
    weapon.sword = sword_scene.instantiate() as Node3D
    weapon.sword.name = "Sword"
    weapon.sheath_socket.add_child(weapon.sword)
    weapon.sword.transform = weapon.sheath_fit
    art.add_child(weapon)
    if owner_body.has_signal(&"attack_started"):
        owner_body.connect(&"attack_started", weapon._on_attack)
    return weapon


## A sword transform in skeleton space: grip at `grip`, blade (+Y) along `blade`, flat facing `flat`.
static func _placement(grip: Vector3, blade: Vector3, flat: Vector3, units: float) -> Transform3D:
    var y: Vector3 = blade.normalized()
    var x: Vector3 = y.cross(flat).normalized()
    var z: Vector3 = x.cross(y).normalized()
    return Transform3D(Basis(x, y, z).scaled(Vector3.ONE * SWORD_LENGTH_M / 1.1 * units), grip)


static func _socket(skeleton: Skeleton3D, socket_name: String, suffix: String) -> BoneAttachment3D:
    for i in skeleton.get_bone_count():
        if skeleton.get_bone_name(i).ends_with(suffix):
            var socket: BoneAttachment3D = BoneAttachment3D.new()
            socket.name = socket_name
            socket.bone_name = skeleton.get_bone_name(i)
            skeleton.add_child(socket)
            return socket
    return null


func _on_attack(_id: Variant = null) -> void:
    _quiet = 0.0
    if not drawn:
        _move_to(hand_socket, hand_fit)
        drawn = true


func _move_to(socket: BoneAttachment3D, fit: Transform3D) -> void:
    sword.reparent(socket, false)
    sword.transform = fit


func _process(delta: float) -> void:
    if not drawn or body == null or not is_instance_valid(body):
        return
    if _enemy_near():
        _quiet = 0.0
        return
    _quiet += delta
    if _quiet >= SHEATHE_AFTER:
        _move_to(sheath_socket, sheath_fit)
        drawn = false


## Living members of the gameplay "enemy" group within QUIET_RADIUS of this weapon's own player.
func _enemy_near() -> bool:
    for enemy: Node in get_tree().get_nodes_in_group(&"enemy"):
        var e: Node3D = enemy as Node3D
        if e == null or (e.has_method(&"is_dead") and e.call(&"is_dead")):
            continue
        if e.global_position.distance_to(body.global_position) <= QUIET_RADIUS:
            return true
    return false

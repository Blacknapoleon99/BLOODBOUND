class_name AshenPhantom
extends Node3D
## Ashen Choir: a phantom that hovers at the player's shoulder and, every `interval` seconds,
## hurls a blood shard (a small Blood Spear projectile) at the nearest valid enemy in range.
## Uses CardSystem's own target rules, so it never shoots sealed weak points or distant foes.

var cards: CardSystem
var follow: Node3D
var card: CardData
var interval: float = 0.8
var lifetime: float = 6.0
var shards_fired: int = 0
var _until_shot: float = 0.3
var _shard: CardData
var _t: float = 0.0


static func create(card_system: CardSystem, player: Node3D, source: CardData) -> AshenPhantom:
    var phantom: AshenPhantom = AshenPhantom.new()
    phantom.name = "AshenPhantom"
    phantom.add_to_group(&"ashen_phantom")
    phantom.top_level = true
    phantom.cards = card_system
    phantom.follow = player
    phantom.card = source
    phantom.interval = source.amount if source.amount > 0.0 else 0.8
    phantom.lifetime = source.duration
    phantom._shard = CardData.new()
    phantom._shard.id = &"ashen_shard"
    phantom._shard.damage = source.damage
    var body: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 0.28
    mesh.height = 0.7
    body.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.75, 0.75, 0.85, 0.55)
    material.emission_enabled = true
    material.emission = Color(0.5, 0.5, 0.7)
    body.material_override = material
    phantom.add_child(body)
    return phantom


func _physics_process(delta: float) -> void:
    _t += delta
    if not is_instance_valid(follow) or _t >= lifetime:
        queue_free()
        return
    var side: float = -float(follow.get("facing_direction")) if follow.get("facing_direction") != null else -1.0
    global_position = follow.global_position + Vector3(0.8 * side, 1.5 + 0.15 * sin(_t * 4.0), 0.0)
    _until_shot -= delta
    if _until_shot > 0.0:
        return
    _until_shot = interval
    var found: Dictionary = cards.find_enemy_target(card.card_range, global_position)
    if found["reason"] != &"ok":
        return
    var aim: Vector3 = cards.aim_point(found["target"])
    get_tree().current_scene.add_child(BloodSpearProjectile.create(global_position, aim, _shard, 1))
    shards_fired += 1

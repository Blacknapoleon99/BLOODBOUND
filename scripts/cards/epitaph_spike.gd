class_name EpitaphSpike
extends Node3D
## Epitaph: a red ring marks the ground under the target; after `delay` a bone spike erupts
## through it (real Hitbox, team player) and then crumbles. A target that steps out of the
## ring in time is missed — the delay is the counterplay, for enemies too.

const RADIUS: float = 1.0

var delay: float = 0.6
var hitbox: Hitbox
var _ring: MeshInstance3D
var _spike: MeshInstance3D
var _t: float = 0.0
var _erupted: bool = false


static func create(at: Vector3, card: CardData) -> EpitaphSpike:
    var spike: EpitaphSpike = EpitaphSpike.new()
    spike.name = "EpitaphSpike"
    spike.add_to_group(&"epitaph_spike")
    spike.top_level = true
    spike.position = at
    spike.delay = card.duration
    spike._ring = MeshInstance3D.new()
    var ring_mesh: CylinderMesh = CylinderMesh.new()
    ring_mesh.top_radius = RADIUS
    ring_mesh.bottom_radius = RADIUS
    ring_mesh.height = 0.04
    spike._ring.mesh = ring_mesh
    spike._ring.material_override = BishopHand._warning_material()
    spike._ring.position = Vector3(0.0, -0.8, 0.0)
    spike.add_child(spike._ring)
    spike._spike = MeshInstance3D.new()
    var spike_mesh: CylinderMesh = CylinderMesh.new()
    spike_mesh.top_radius = 0.02
    spike_mesh.bottom_radius = 0.45
    spike_mesh.height = 2.6
    spike._spike.mesh = spike_mesh
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.85, 0.8, 0.7)
    spike._spike.material_override = bone
    spike._spike.position = Vector3(0.0, -2.2, 0.0)
    spike._spike.visible = false
    spike.add_child(spike._spike)
    spike.hitbox = Hitbox.new()
    spike.hitbox.team = &"player"
    spike.hitbox.damage = card.damage
    spike.hitbox.category = &"card"
    spike.hitbox.knockback = 2.0
    spike.hitbox.knockback_up = 6.0
    spike.hitbox.hitstun = 0.6
    spike.hitbox.poise_damage = 3
    spike.hitbox.attack_id = card.id
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(RADIUS * 2.0, 2.6, RADIUS * 2.0)
    shape.shape = box
    spike.hitbox.add_child(shape)
    spike.add_child(spike.hitbox)
    return spike


func _physics_process(delta: float) -> void:
    _t += delta
    if not _erupted and _t >= delay:
        _erupted = true
        _ring.visible = false
        _spike.visible = true
        hitbox.activate()
        get_tree().call_group(&"camera_shaker", &"add_trauma", 0.25)
    if _erupted:
        var rise: float = clampf((_t - delay) / 0.1, 0.0, 1.0)
        _spike.position.y = lerpf(-2.2, 0.3, rise)
        if _t >= delay + 0.15 and hitbox.is_active():
            hitbox.deactivate()
        if _t >= delay + 0.8:
            queue_free()

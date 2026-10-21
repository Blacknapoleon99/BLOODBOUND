class_name StrikeZone
extends Node3D
## A telegraphed area strike on the play plane: a pulsing red ring marks the spot for `delay`
## seconds, then the strike lands (hitbox live for `active_time`), shows its visual and fades.
## Used by the Bishop's Bone Rain / Marrow Geyser, the archer's lobbed arrow and the Husk's
## death burst. Answer: be somewhere else when it lands (or dodge through it).

var delay: float = 0.8
var active_time: float = 0.15
var hitbox: Hitbox
var landed: bool = false
var done: bool = false
var _t: float = 0.0
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _strike: MeshInstance3D
var _strike_material: StandardMaterial3D
var _style: StringName = &"spike"


## `style`: &"spike" (rises from the ground), &"bone" (falls from above), &"burst" (flat blast).
static func create(at: Vector3, radius: float, height: float, wait: float, damage: int, id: StringName, style: StringName = &"spike") -> StrikeZone:
    var zone: StrikeZone = StrikeZone.new()
    zone.name = "StrikeZone"
    zone.add_to_group(&"strike_zone")
    zone.top_level = true
    zone.delay = wait
    zone._style = style
    zone.position = Vector3(at.x, at.y, 0.0)
    zone._ring = MeshInstance3D.new()
    var disc: CylinderMesh = CylinderMesh.new()
    disc.top_radius = radius
    disc.bottom_radius = radius
    disc.height = 0.04
    zone._ring.mesh = disc
    zone._ring_material = BishopHand._warning_material()
    zone._ring.material_override = zone._ring_material
    zone._ring.position.y = 0.04
    zone.add_child(zone._ring)
    zone._strike = MeshInstance3D.new()
    var column: CylinderMesh = CylinderMesh.new()
    column.top_radius = radius * (0.25 if style == &"spike" else 0.6)
    column.bottom_radius = radius * (0.9 if style != &"burst" else 1.0)
    column.height = height if style != &"burst" else 0.5
    zone._strike.mesh = column
    zone._strike_material = StandardMaterial3D.new()
    zone._strike_material.albedo_color = Color(0.85, 0.8, 0.68) if style != &"burst" else Color(0.45, 0.75, 0.3, 0.8)
    zone._strike_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    zone._strike.material_override = zone._strike_material
    zone._strike.position.y = column.height * 0.5
    zone._strike.visible = false
    zone.add_child(zone._strike)
    zone.hitbox = Hitbox.new()
    zone.hitbox.team = &"enemy"
    zone.hitbox.damage = damage
    zone.hitbox.category = &"area"
    zone.hitbox.knockback = 3.0
    zone.hitbox.knockback_up = 6.0 if style == &"spike" else 2.5
    zone.hitbox.hitstun = 0.3
    zone.hitbox.attack_id = id
    var shape: CollisionShape3D = CollisionShape3D.new()
    var cylinder: CylinderShape3D = CylinderShape3D.new()
    cylinder.radius = radius
    cylinder.height = maxf(height, 1.6)
    shape.shape = cylinder
    shape.position.y = cylinder.height * 0.5
    zone.hitbox.add_child(shape)
    zone.add_child(zone.hitbox)
    return zone


func is_telegraphing() -> bool:
    return not landed and not done


func cancel() -> void:
    hitbox.deactivate()
    done = true
    queue_free()


func _physics_process(delta: float) -> void:
    if done:
        return
    _t += delta
    if not landed:
        _ring_material.albedo_color.a = 0.25 + 0.45 * (_t / delay) * (0.6 + 0.4 * sin(_t * 28.0))
        if _style == &"bone" and _t > delay - 0.25:
            # The bone is visible falling for the last quarter second.
            _strike.visible = true
            _strike.position.y = lerpf(9.0, (_strike.mesh as CylinderMesh).height * 0.5, (_t - (delay - 0.25)) / 0.25)
        if _t >= delay:
            landed = true
            _ring.visible = false
            _strike.visible = true
            _strike.position.y = (_strike.mesh as CylinderMesh).height * 0.5
            hitbox.activate()
            get_tree().call_group(&"camera_shaker", &"add_trauma", 0.12)
        return
    if _t >= delay + active_time and hitbox.is_active():
        hitbox.deactivate()
    _strike_material.albedo_color.a = clampf(1.0 - (_t - delay - active_time) / 0.35, 0.0, 1.0)
    if _t >= delay + active_time + 0.35:
        done = true
        queue_free()

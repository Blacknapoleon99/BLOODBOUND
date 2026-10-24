class_name GoreGib
extends MeshInstance3D
## A short-lived chunk thrown by death gore: a lump of flesh or a bone shard. Flies ballistically
## (hand-simulated with world rays, so it is not a physics body and never pushes or blocks the
## player), tumbles, bleeds a thin trail while airborne, leaves a splat on its first hard
## impacts, bounces a little, settles, then shrinks away after its life.

const GRAVITY: float = 22.0
const WORLD_MASK: int = 1
const MAX_SPLATS: int = 2

var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
var life: float = 4.0
## Fluid this chunk drips / splats (alpha 0 = clean, e.g. dry bone).
var fluid: Color = Color(0, 0, 0, 0)
var half_extent: float = 0.06

var _resting: bool = false
var _splats: int = 0
var _drip_left: float = 0.0
var _query: PhysicsRayQueryParameters3D


func _ready() -> void:
    add_to_group(&"gore_gibs")
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _query = PhysicsRayQueryParameters3D.new()
    _query.collision_mask = WORLD_MASK
    _query.collide_with_areas = false


## Starts the shrink-and-free early (Gore's gib cap evicting the oldest chunk).
func expire() -> void:
    if life > 0.0:
        life = 0.0
        _vanish()


func _physics_process(delta: float) -> void:
    if life <= 0.0:
        return
    life -= delta
    if life <= 0.0:
        _vanish()
        return
    if _resting:
        return
    velocity.y -= GRAVITY * delta
    rotation += spin * delta
    var from: Vector3 = global_position
    var to: Vector3 = from + velocity * delta
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    _query.from = from
    _query.to = to + velocity.normalized() * half_extent
    var hit: Dictionary = space.intersect_ray(_query) if space != null else {}
    if not hit.is_empty() and not (hit.get(&"collider") is CharacterBody3D or hit.get(&"collider") is RigidBody3D):
        var n: Vector3 = hit[&"normal"]
        var speed: float = velocity.length()
        if fluid.a > 0.0 and _splats < MAX_SPLATS and speed > 2.0:
            _splats += 1
            Gore.splat(self, hit[&"position"], n, clampf(0.25 + speed * 0.05, 0.25, 0.7), fluid, velocity)
        global_position = (hit[&"position"] as Vector3) + n * half_extent
        velocity = velocity.bounce(n) * 0.32
        velocity -= n * velocity.dot(n) * 0.2
        spin *= 0.5
        if velocity.length() < 1.2 and n.y > 0.6:
            _resting = true
            velocity = Vector3.ZERO
    else:
        global_position = to
        if fluid.a > 0.0:
            _drip_left -= delta
            if _drip_left <= 0.0:
                _drip_left = 0.05
                Gore.drop(self, global_position, velocity * 0.25, 0.015, fluid, 0.0, 0.14 if randf() < 0.1 else 0.0)


func _vanish() -> void:
    set_physics_process(false)
    var tween: Tween = create_tween()
    tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.5).set_ease(Tween.EASE_IN)
    tween.tween_callback(queue_free)

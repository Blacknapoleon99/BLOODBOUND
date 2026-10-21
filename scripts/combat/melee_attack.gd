class_name MeleeAttack
extends Node
## Phase machine for one attacker: IDLE → STARTUP → ACTIVE → RECOVERY → IDLE.
## Owns exactly one Hitbox, which it places along the given facing and enables only in ACTIVE.

signal phase_changed(phase: Phase)
signal attack_started(data: AttackData)
signal attack_finished(data: AttackData)

enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }

@export var hitbox: Hitbox

var phase: Phase = Phase.IDLE
var current: AttackData
var facing: Vector3 = Vector3.RIGHT
var _phase_left: float = 0.0


func is_busy() -> bool:
    return phase != Phase.IDLE


func phase_name() -> String:
    return Phase.keys()[phase]


func can_cancel_into_dodge() -> bool:
    return phase == Phase.RECOVERY and current != null and current.dodge_cancel_recovery


## Extra damage per AttackData.id (relics such as Executioner's Seal, Might from equipment).
var bonus_damage: Dictionary = {}
## Weapon attack speed: every phase lasts duration / speed_scale.
var speed_scale: float = 1.0
## Temporary multiplier on top (Sigil of Haste).
var haste_scale: float = 1.0


func start(data: AttackData, attack_facing: Vector3) -> bool:
    if is_busy() or data == null:
        return false
    current = data
    facing = _flat(attack_facing)
    hitbox.configure_from(data)
    hitbox.damage += int(bonus_damage.get(data.id, 0))
    _place_hitbox()
    attack_started.emit(data)
    _enter(Phase.STARTUP, data.startup)
    return true


## Aborts the attack immediately (hit reactions, dodge-cancel). Safe when idle.
func cancel() -> void:
    if not is_busy():
        return
    hitbox.deactivate()
    var finished_data: AttackData = current
    _enter(Phase.IDLE, 0.0)
    attack_finished.emit(finished_data)


func _physics_process(delta: float) -> void:
    if phase == Phase.IDLE:
        return
    _phase_left -= delta
    # Epsilon: 6 × (1/60) leaves ~1e-17 of a 0.1 s phase, which would add a whole frame.
    if _phase_left > 0.0001:
        return
    match phase:
        Phase.STARTUP:
            hitbox.activate()
            _enter(Phase.ACTIVE, current.active)
        Phase.ACTIVE:
            hitbox.deactivate()
            _enter(Phase.RECOVERY, current.recovery)
        Phase.RECOVERY:
            var finished_data: AttackData = current
            _enter(Phase.IDLE, 0.0)
            attack_finished.emit(finished_data)


func _enter(next: Phase, duration: float) -> void:
    phase = next
    _phase_left = duration / maxf(0.1, speed_scale * haste_scale)
    phase_changed.emit(next)


func _place_hitbox() -> void:
    var shape_node: CollisionShape3D = hitbox.get_child(0) as CollisionShape3D
    var box: BoxShape3D = shape_node.shape as BoxShape3D
    box.size = Vector3(current.width, current.height, current.reach)
    var center: Vector3 = facing * current.reach_offset + Vector3.UP * current.height_offset
    hitbox.transform = Transform3D(Basis.looking_at(facing, Vector3.UP), center)


static func _flat(v: Vector3) -> Vector3:
    var flat: Vector3 = Vector3(v.x, 0.0, v.z)
    return flat.normalized() if flat.length_squared() > 0.0001 else Vector3.RIGHT

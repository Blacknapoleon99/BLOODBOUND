class_name Hitbox
extends Area3D
## Delivers damage to overlapping enemy Hurtboxes while active. Each target is hit at most
## once per activation, unless `rehit_interval` > 0 (used for continuous contact damage).

signal hit_landed(target: Hurtbox, info: DamageInfo)

@export var team: StringName = &"neutral"
@export var rehit_interval: float = 0.0
@export var start_active: bool = false

## Template values for delivered hits (copied per target).
var damage: int = 1
var category: StringName = &"melee"
var knockback: float = 4.0
var knockback_up: float = 2.0
var hitstun: float = 0.25
var poise_damage: int = 1
var attack_id: StringName = &""

var _active: bool = false
var _hit_times: Dictionary = {}  # Hurtbox instance id -> time of last hit
var _clock: float = 0.0


func _ready() -> void:
    collision_layer = 0
    collision_mask = Hurtbox.COMBAT_LAYER
    monitoring = true
    monitorable = false
    _active = start_active


func is_active() -> bool:
    return _active


func activate() -> void:
    _active = true
    _hit_times.clear()


func deactivate() -> void:
    _active = false


func configure_from(data: AttackData) -> void:
    damage = data.damage
    category = data.category
    knockback = data.knockback
    knockback_up = data.knockback_up
    hitstun = data.hitstun
    poise_damage = data.poise_damage
    attack_id = data.id


func _physics_process(delta: float) -> void:
    _clock += delta
    if not _active:
        return
    for area: Area3D in get_overlapping_areas():
        var target: Hurtbox = area as Hurtbox
        if target == null or target.team == team:
            continue
        var key: int = target.get_instance_id()
        if _hit_times.has(key):
            if rehit_interval <= 0.0 or _clock - float(_hit_times[key]) < rehit_interval:
                continue
        var info: DamageInfo = _build_info(target)
        if target.receive(info):
            _hit_times[key] = _clock
            hit_landed.emit(target, info)


func _build_info(target: Hurtbox) -> DamageInfo:
    var source: Node3D = get_parent() as Node3D
    while source != null and not (source is CharacterBody3D):
        source = source.get_parent() as Node3D
    var origin: Vector3 = source.global_position if source else global_position
    var away: Vector3 = target.global_position - origin
    away.y = 0.0
    if away.length_squared() < 0.0001:
        away = -global_basis.z
        away.y = 0.0
    away = away.normalized()
    var info: DamageInfo = DamageInfo.new()
    info.amount = damage
    info.category = category
    info.hitstun = hitstun
    info.poise_damage = poise_damage
    info.knockback = away * knockback + Vector3.UP * knockback_up
    info.source = source
    info.hit_position = target.global_position.lerp(origin, 0.3) + Vector3.UP * 0.3
    info.attack_id = attack_id
    return info

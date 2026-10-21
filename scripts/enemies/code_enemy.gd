class_name CodeEnemy
extends CharacterBody3D
## Shared plumbing for enemies built entirely in code (Shielded Knight, Flying Wraith, Bone
## Crawler, Gravewarden): Health + Hurtbox (team enemy), poise, silence, hit flash, a simple
## state clock, death collapse, and the "enemy"/"silenceable" groups. Subclasses override
## `_tick(delta, target)`, `_on_poise_break(info)` and `_build_visual()`.

signal defeated
signal state_changed(state_name: String)

@export var max_health: int = 3
@export var poise_max: int = 2
@export var min_x: float = -INF
@export var max_x: float = INF
@export var ai_enabled: bool = true
## Bone Shards dropped on death (see main.gd on_combatant_died).
@export var shard_value: int = 2

var health: Health
var hurtbox: Hurtbox
var poise: int = 2
var facing: float = -1.0
var state: StringName = &"idle"
var _t: float = 0.0
var _stun_left: float = 0.0
var _silenced_left: float = 0.0
var _flash_left: float = 0.0
var _visual: Node3D
var _material: StandardMaterial3D
var _base_color: Color = Color(0.7, 0.68, 0.6)
var _dead: bool = false


func _ready() -> void:
    add_to_group(&"enemy")
    add_to_group(&"silenceable")
    poise = poise_max
    health = Health.new()
    health.max_health = max_health
    add_child(health)
    health.died.connect(_on_died)
    hurtbox = Hurtbox.new()
    hurtbox.team = &"enemy"
    hurtbox.health = health
    add_child(hurtbox)
    hurtbox.hit_received.connect(_on_hit)
    _material = StandardMaterial3D.new()
    _material.albedo_color = _base_color
    _visual = Node3D.new()
    add_child(_visual)
    _build_body()


## Override: add collision shape(s), hurtbox shape (to `hurtbox`), meshes (to `_visual`).
func _build_body() -> void:
    pass


func state_name() -> String:
    return String(state).to_upper()


func is_dead() -> bool:
    return _dead


func is_silenced() -> bool:
    return _silenced_left > 0.0


func silence(seconds: float) -> void:
    if not _dead:
        _silenced_left = maxf(_silenced_left, seconds)
        _on_silenced()


func set_ai_enabled(enabled: bool) -> void:
    ai_enabled = enabled


func _physics_process(delta: float) -> void:
    _t += delta
    _stun_left = maxf(0.0, _stun_left - delta)
    _silenced_left = maxf(0.0, _silenced_left - delta)
    _flash_left = maxf(0.0, _flash_left - delta)
    if _dead:
        velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
    elif state == &"stagger" or state == &"hitstun":
        velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
        if _stun_left <= 0.0:
            set_state(&"idle")
    else:
        _tick(delta, _target())
    _apply_motion(delta)
    _update_look()


## Override for AI. Called every physics frame while alive and not stunned.
func _tick(_delta: float, _target_node: Node3D) -> void:
    pass


## Default motion: gravity, plane lock, x bounds, abyss death.
func _apply_motion(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= 26.0 * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0
    velocity.z = 0.0
    var next_x: float = global_position.x + velocity.x * delta
    if (next_x < min_x and velocity.x < 0.0) or (next_x > max_x and velocity.x > 0.0):
        velocity.x = 0.0
    move_and_slide()
    position.z = 0.0
    if global_position.y < -9.0 and not _dead:
        health.apply_damage(health.current)


func _target() -> Node3D:
    var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
    if player == null or bool(player.get("in_3d_mode")):
        return null
    var player_health: Health = player.get("health") as Health
    if player_health != null and player_health.is_dead():
        return null
    if absf(player.global_position.x - global_position.x) > 16.0 or absf(player.global_position.y - global_position.y) > 6.0:
        return null
    return player


func set_state(next: StringName) -> void:
    if state == next:
        return
    state = next
    _t = 0.0
    state_changed.emit(state_name())


func _on_hit(info: DamageInfo) -> void:
    if _dead:
        return
    _flash_left = 0.12
    poise -= info.poise_damage
    if poise > 0:
        return
    poise = poise_max
    _on_poise_break(info)


## Override to cancel attacks; default: knockback + hitstun.
func _on_poise_break(info: DamageInfo) -> void:
    velocity = info.knockback
    _stun_left = info.hitstun
    set_state(&"hitstun")


## Override to drop a wind-up when silenced.
func _on_silenced() -> void:
    pass


func _on_died() -> void:
    _dead = true
    set_state(&"dead")
    hurtbox.set_enabled(false)
    set_deferred(&"collision_layer", 0)
    var tween: Tween = create_tween()
    tween.tween_property(_visual, "rotation:z", -facing * PI * 0.5, 0.35)
    tween.tween_property(_visual, "position:y", -0.6, 0.5)
    defeated.emit()


## Override for state colours; default flash + silence tint.
func _glow() -> Color:
    return Color.BLACK


func _update_look() -> void:
    if _dead:
        return
    _visual.scale.x = facing
    var emission: Color = _glow()
    if _silenced_left > 0.0:
        emission = Color(0.25, 0.3, 0.8) * 0.6
    _material.albedo_color = Color.WHITE if _flash_left > 0.0 else _base_color
    _material.emission_enabled = emission != Color.BLACK
    _material.emission = emission


# --- Builders for subclasses ---------------------------------------------------------

func _add_collider(size: Vector3, center_y: float) -> void:
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    shape.position.y = center_y
    add_child(shape)


func _add_hurt_shape(size: Vector3, center_y: float) -> void:
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    shape.position.y = center_y
    hurtbox.add_child(shape)


func _add_mesh(size: Vector3, at: Vector3, material: Material = null, label: String = "Part") -> MeshInstance3D:
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    mesh_node.name = label
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.material_override = material if material != null else _material
    mesh_node.position = at
    _visual.add_child(mesh_node)
    return mesh_node


func _make_hitbox(size: Vector3, center: Vector3, damage: int, id: StringName, knockback: float = 6.0) -> Hitbox:
    var hitbox: Hitbox = Hitbox.new()
    hitbox.team = &"enemy"
    hitbox.damage = damage
    hitbox.category = &"melee"
    hitbox.knockback = knockback
    hitbox.knockback_up = 3.0
    hitbox.hitstun = 0.35
    hitbox.attack_id = id
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    shape.position = center
    hitbox.add_child(shape)
    add_child(hitbox)
    return hitbox

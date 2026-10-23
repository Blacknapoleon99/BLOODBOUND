class_name CodeEnemy
extends CharacterBody3D
## Shared plumbing for enemies built entirely in code (Shielded Knight, Flying Wraith, Bone
## Crawler, Gravewarden): Health + Hurtbox (team enemy), poise, silence, hit flash, a simple
## state clock, death collapse, and the "enemy"/"silenceable" groups. Subclasses override
## `_tick(delta, target)`, `_on_poise_break(info)` and `_build_visual()`.
##
## Two modes. `plane_locked` (the side-view game): movement on X only, kept in
## [min_x, max_x], facing is a sign. Full 3D (`plane_locked = false`, set by EnemyFactory when
## `EnemyFactory.full_3d`): movement on X/Z, kept within `leash_radius` of home, `heading` is a
## facing vector, and a NavigationAgent3D routes the chase around obstacles when the level has
## a navigation mesh. Subclasses use the helpers (planar_to / face / move_dir / chase_dir /
## stop / heading) so the same AI runs in both.
##
## Full 3D also gets a `roam` (Roam3D, DEC-058): idle enemies wander their whole leash area on
## solid ground (`roam_idle`), engaged ones close in on spread-out angles and circle the target
## (`engage`), and `_apply_motion` never lets self-driven motion carry them off a ledge.

signal defeated
signal state_changed(state_name: String)

@export var max_health: int = 3
@export var poise_max: int = 2
@export var min_x: float = -INF
@export var max_x: float = INF
@export var ai_enabled: bool = true
## Bone Shards dropped on death (see main.gd on_combatant_died).
@export var shard_value: int = 2
@export var plane_locked: bool = true
@export var leash_radius: float = 12.0

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
## Facing as a flat unit vector (full 3D); in the side view it is (facing, 0, 0).
var heading: Vector3 = Vector3(-1.0, 0.0, 0.0)
## Leash centre. Setting it (e.g. an arena ring's centre) before the first physics frame keeps it.
var home: Vector3:
    set(value):
        home = value
        _home_set = true
        if roam != null:
            roam.set_home(value, leash_radius)
## Full-3D steering (null in the side view).
var roam: Roam3D
var nav: NavigationAgent3D
var _nav_refresh: float = 0.0


func _ready() -> void:
    if not plane_locked:
        nav = NavigationAgent3D.new()
        nav.radius = 0.5
        nav.path_desired_distance = 0.6
        nav.target_desired_distance = 0.8
        add_child(nav)
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


var _home_set: bool = false


## Override: the Roam3D style for this archetype.
func _roam_style() -> Roam3D.Style:
    return Roam3D.Style.PATROL


func _physics_process(delta: float) -> void:
    if not plane_locked and roam == null:
        roam = Roam3D.new(self, _roam_style(), heading)
        if _home_set:
            roam.set_home(home, leash_radius)
    if not _home_set:
        home = global_position
    elif roam != null and roam.leash != maxf(0.5, leash_radius):
        roam.set_home(home, leash_radius)  # the leash was changed after spawning
    _t += delta
    _stun_left = maxf(0.0, _stun_left - delta)
    _silenced_left = maxf(0.0, _silenced_left - delta)
    _flash_left = maxf(0.0, _flash_left - delta)
    if _dead:
        _brake(20.0 * delta)
    elif state == &"stagger" or state == &"hitstun":
        _brake(8.0 * delta)
        if _stun_left <= 0.0:
            set_state(&"idle")
    else:
        _tick(delta, _target())
    _apply_motion(delta)
    _update_look()


## Override for AI. Called every physics frame while alive and not stunned.
func _tick(_delta: float, _target_node: Node3D) -> void:
    pass


## Default motion: gravity, then the side-view x bounds or the full-3D leash, abyss death.
func _apply_motion(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= 26.0 * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0
    _apply_bounds(delta)
    if roam != null and not _dead and state != &"stagger" and state != &"hitstun":
        roam.update_floor(delta)
        velocity = roam.guard(velocity, delta)  # never walk off the platform on its own
    move_and_slide()
    if plane_locked:
        position.z = 0.0
    if global_position.y < -9.0 and not _dead:
        health.apply_damage(health.current)


func _apply_bounds(delta: float) -> void:
    if plane_locked:
        velocity.z = 0.0
        var next_x: float = global_position.x + velocity.x * delta
        if (next_x < min_x and velocity.x < 0.0) or (next_x > max_x and velocity.x > 0.0):
            velocity.x = 0.0
        return
    var out: Vector3 = global_position - home
    out.y = 0.0
    if out.length() >= leash_radius:
        var dir: Vector3 = out.normalized()
        var outward: float = velocity.x * dir.x + velocity.z * dir.z
        if outward > 0.0:
            velocity.x -= dir.x * outward
            velocity.z -= dir.z * outward


func _target() -> Node3D:
    var player: Node3D = Players.nearest(global_position) as Node3D
    if player == null or bool(player.get("in_3d_mode")) == plane_locked:
        return null  # the side-view enemy ignores a 3D player and vice versa
    var player_health: Health = player.get("health") as Health
    if player_health != null and player_health.is_dead():
        return null
    if absf(player.global_position.y - global_position.y) > 6.0:
        return null
    if plane_locked and absf(player.global_position.x - global_position.x) > 16.0:
        return null
    if not plane_locked and planar_to(player).length() > 20.0:
        return null
    return player


# --- Movement helpers (same AI in the side view and in full 3D) -------------------------------

## Flat offset to `target` (z dropped in the side view).
func planar_to(target: Node3D) -> Vector3:
    var off: Vector3 = target.global_position - global_position
    off.y = 0.0
    if plane_locked:
        off.z = 0.0
    return off


## Turn to face `dir` (flat). The side view keeps a sign on X.
func face(dir: Vector3) -> void:
    dir.y = 0.0
    if plane_locked:
        if absf(dir.x) > 0.01:
            facing = signf(dir.x)
        heading = Vector3(facing, 0.0, 0.0)
    elif dir.length_squared() > 0.0001:
        heading = dir.normalized()
        if absf(heading.x) > 0.01:
            facing = signf(heading.x)


func move_dir(dir: Vector3, speed: float) -> void:
    dir.y = 0.0
    if plane_locked:
        dir.z = 0.0
    dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.ZERO
    velocity.x = dir.x * speed
    velocity.z = dir.z * speed


func stop() -> void:
    velocity.x = 0.0
    velocity.z = 0.0


func _brake(amount: float) -> void:
    var planar: Vector2 = Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, amount)
    velocity.x = planar.x
    velocity.z = planar.y


## Which way to walk to reach `target`: along the navigation path in full 3D when the level
## has a navigation mesh, otherwise straight at it.
func chase_dir(target: Node3D) -> Vector3:
    var direct: Vector3 = planar_to(target)
    if nav == null or plane_locked:
        return direct
    _nav_refresh -= get_physics_process_delta_time()
    if _nav_refresh <= 0.0:
        _nav_refresh = 0.25
        nav.target_position = target.global_position
    if NavigationServer3D.map_get_iteration_id(nav.get_navigation_map()) == 0 or nav.is_navigation_finished():
        return direct
    var next: Vector3 = nav.get_next_path_position() - global_position
    next.y = 0.0
    return next if next.length_squared() > 0.01 else direct


## Full 3D, no target: roam the leash area at `speed` (turning, pausing, looking around).
func roam_idle(delta: float, speed: float) -> void:
    if roam == null:
        stop()
        return
    var v: Vector3 = roam.idle_velocity(delta, speed)
    velocity.x = v.x
    velocity.z = v.z
    if roam.flying:
        velocity.y = v.y
    face(roam.heading)


## Full 3D, fighting `target`: close in (navigation detour, spread angle), then hold a ring of
## `ring` m and strafe round it. Faces the target. Side view: walks straight at it as before.
func engage(delta: float, target: Node3D, ring: float, speed: float, strafe_speed: float) -> void:
    if roam == null:
        move_dir(chase_dir(target), speed)
        return
    var v: Vector3 = roam.engage_velocity(target, ring, speed, strafe_speed, delta, chase_dir(target))
    velocity.x = v.x
    velocity.z = v.z
    face(planar_to(target))
    roam.heading = heading


## True if one step along `dir` stays inside this enemy's bounds/leash.
func can_step(dir: Vector3, step: float = 0.6) -> bool:
    if plane_locked:
        var next_x: float = global_position.x + signf(dir.x) * step
        return (next_x > min_x or dir.x > 0.0) and (next_x < max_x or dir.x < 0.0)
    var next: Vector3 = global_position + Vector3(dir.x, 0.0, dir.z).normalized() * step - home
    next.y = 0.0
    return next.length() < leash_radius or next.length() < (global_position - home).length()


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
    tween.tween_property(_visual, "rotation:z", (-facing if plane_locked else -1.0) * PI * 0.5, 0.35)
    tween.tween_property(_visual, "position:y", -0.6, 0.5)
    defeated.emit()


## Override for state colours; default flash + silence tint.
func _glow() -> Color:
    return Color.BLACK


func _update_look() -> void:
    if _dead:
        return
    if plane_locked:
        _visual.scale.x = facing
    else:
        # The visual's forward is +X (the side view mirrors it); in 3D it turns instead.
        _visual.scale.x = 1.0
        _visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-heading.z, heading.x), 0.3)
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

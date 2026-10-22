class_name Ambush
extends Node3D
## An ambush room on the 2.5D path. Crossing `trigger_x` raises bone walls at `left_x` and
## `right_x` and spawns its enemies; the walls drop when every enemy is dead.
## If the player dies (or falls) while it is active, `reset()` clears it and re-arms it, so a
## failed fight can always be retried and never softlocks the route.
## `Ambush.enabled = false` (static) keeps every ambush dormant — used by scripted tests.

signal started(ambush: Ambush)
signal cleared(ambush: Ambush)

enum State { ARMED, ACTIVE, CLEARED }

static var enabled: bool = true

var trigger_x: float
var left_x: float
var right_x: float
## [{"type": &"husk"|&"archer"|&"hound"|&"knight"|&"wraith"|&"crawler", "x": float, "wave": int}]
## Waves: wave 0 spawns when the walls rise; each next wave when the previous one is dead.
var spawns: Array[Dictionary] = []
var state: State = State.ARMED
var enemies: Array[Node3D] = []
var _walls: Array[StaticBody3D] = []
var wave: int = 0
## Built for the 3D run: triggers for a free-moving (3D) player and spreads its spawns in depth.
## Side-view ambushes ignore a 3D player (a Reality Fracture visit) and vice versa.
var three_d: bool = false
## Spawn indices already killed: a retry after a death does not bring them back.
var _killed: Dictionary = {}
## Open 3D courses (DEC-052): a 3D ambush is an ARENA RING, not two walls across a hall. A ring of
## bone walls (radius `ring_radius` round `ring_center`, world x/z) rises when a player steps
## inside it; foes spawn spread round the ring. Built from left/right by default (the centre
## between them, half the span as radius); a room can place it anywhere with `set_ring`.
var ring: bool = false
var ring_center: Vector2 = Vector2.ZERO
var ring_radius: float = 0.0
## Ring foes' leash round the ring's centre (> 0: set it to the arena floor's inscribed radius
## so nobody chases off the floor; default: the ring's radius).
var spawn_leash: float = -1.0


static func create(label: String, trigger: float, left: float, right: float, spawn_list: Array[Dictionary]) -> Ambush:
    var ambush: Ambush = Ambush.new()
    ambush.name = label
    ambush.trigger_x = trigger
    ambush.left_x = left
    ambush.right_x = right
    ambush.spawns = spawn_list
    ambush.three_d = Lane.full_3d
    if Lane.full_3d:
        ambush.set_ring(Vector2((left + right) * 0.5, 0.0), (right - left) * 0.5)
    return ambush


## Makes this a 3D arena ring at world `center` (x, z) with `radius` (before it enters the tree).
func set_ring(center: Vector2, radius: float) -> void:
    ring = true
    ring_center = center
    ring_radius = radius
    left_x = center.x - radius
    right_x = center.x + radius


func _ready() -> void:
    if ring and three_d:
        var count: int = maxi(12, int(TAU * ring_radius / 2.4))
        for i in count:
            _walls.append(_make_ring_wall(TAU * i / count, TAU * ring_radius / count + 0.4))
        return
    for x: float in [left_x, right_x]:
        _walls.append(_make_wall(x))


## True if `p` (world) stands inside the ring (planar), with `margin` metres to spare.
func inside_ring(p: Vector3, margin: float = 0.0) -> bool:
    return Vector2(p.x - ring_center.x, p.z - ring_center.y).length() < ring_radius - margin


func is_active() -> bool:
    return state == State.ACTIVE


func alive_count() -> int:
    _prune()
    return enemies.filter(func(e: Node3D) -> bool: return not bool(e.call("is_dead"))).size()


## Dead enemies free themselves after a moment; drop those references before touching them.
func _prune() -> void:
    enemies = enemies.filter(func(e: Variant) -> bool: return is_instance_valid(e))


func _physics_process(_delta: float) -> void:
    match state:
        State.ARMED:
            for player: Node3D in Players.standing():
                if enabled and bool(player.get("in_3d_mode")) == three_d and player.global_position.x > trigger_x \
                        and player.global_position.x < right_x and absf(player.global_position.y - global_position.y) < 4.0:
                    _start()
                    break
        State.ACTIVE:
            if alive_count() == 0 and _spawn_wave(wave + 1) > 0:
                wave += 1
            elif alive_count() == 0:
                state = State.CLEARED
                _set_walls(false)
                cleared.emit(self)


func _start() -> void:
    state = State.ACTIVE
    _set_walls(true)
    enemies.clear()
    wave = 0
    _spawn_wave(0)
    started.emit(self)


## Spawns every spawn of wave `n`; returns how many.
func _spawn_wave(n: int) -> int:
    var count: int = 0
    for index in spawns.size():
        var spawn: Dictionary = spawns[index]
        if int(spawn.get("wave", 0)) != n or _killed.has(index):
            continue
        var x: float = float(spawn["x"])
        var z: float = [0.0, -2.5, 2.5][index % 3] if three_d else 0.0
        var leash: float = spawn_leash if spawn_leash > 0.0 else ring_radius
        if ring and three_d:  # spread round the arena, never on top of whoever just walked in
            var angle: float = 0.7 + index * 2.39996
            var dist: float = minf(ring_radius * 0.55, leash * 0.6)
            x = ring_center.x + cos(angle) * dist
            z = ring_center.y + sin(angle) * dist
        var enemy: Node3D = EnemyFactory.spawn(spawn["type"], get_parent(), x, left_x + 0.8, right_x - 0.8, global_position.y + 1.0, z)
        if ring and three_d and "leash_radius" in enemy:
            # Leashed round the arena's centre: they chase anywhere on its floor, never off it.
            enemy.set("leash_radius", leash)
            var centre: Vector3 = Vector3(ring_center.x, enemy.global_position.y, ring_center.y)
            if "home" in enemy:
                enemy.set("home", centre)
            if "_home" in enemy:
                enemy.set("_home", centre)
        enemy.add_to_group(&"ambush_enemy")
        enemy.connect("defeated", func() -> void: _killed[index] = true)
        enemies.append(enemy)
        count += 1
    return count


## Player died / fell during the fight: remove its enemies, drop the walls, arm it again.
func reset() -> void:
    if state != State.ACTIVE:
        return
    _prune()
    for enemy: Node3D in enemies:
        enemy.queue_free()
    enemies.clear()
    _set_walls(false)
    state = State.ARMED


func _make_wall(x: float) -> StaticBody3D:
    var wall: StaticBody3D = StaticBody3D.new()
    wall.name = "Bone wall"
    wall.position = Vector3(x, 3.0, 0.0)
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(0.6, 6.0, Lane.DEPTH_3D if three_d else 4.0)
    shape.shape = box
    shape.disabled = true
    wall.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(0.6, 6.0, Lane.DEPTH_3D if three_d else 3.0)
    mesh_node.mesh = mesh
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.7, 0.66, 0.56)
    bone.emission_enabled = true
    bone.emission = Color(0.6, 0.05, 0.05) * 0.6
    mesh_node.material_override = bone
    wall.add_child(mesh_node)
    wall.visible = false
    add_child(wall)
    return wall


## One bone segment of a 3D arena ring, tangent to the circle at `angle`.
func _make_ring_wall(angle: float, length: float) -> StaticBody3D:
    var wall: StaticBody3D = StaticBody3D.new()
    wall.name = "Bone ring wall"
    wall.position = Vector3(ring_center.x + cos(angle) * ring_radius, 3.0, ring_center.y + sin(angle) * ring_radius)
    wall.rotation.y = -angle - PI * 0.5
    var size: Vector3 = Vector3(length, 6.0, 0.6)
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    shape.disabled = true
    wall.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.7, 0.66, 0.56)
    bone.emission_enabled = true
    bone.emission = Color(0.6, 0.05, 0.05) * 0.6
    mesh_node.material_override = bone
    wall.add_child(mesh_node)
    wall.visible = false
    add_child(wall)
    return wall


func wall_count() -> int:
    return _walls.size()


func _set_walls(up: bool) -> void:
    for wall: StaticBody3D in _walls:
        (wall.get_child(0) as CollisionShape3D).set_deferred(&"disabled", not up)
        wall.visible = up


func wall_collision_enabled() -> bool:
    return not _walls.is_empty() and not (_walls[0].get_child(0) as CollisionShape3D).disabled

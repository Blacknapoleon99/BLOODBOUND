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
## [{"type": &"husk"|&"archer", "x": float}]
var spawns: Array[Dictionary] = []
var state: State = State.ARMED
var enemies: Array[Node3D] = []
var _walls: Array[StaticBody3D] = []


static func create(label: String, trigger: float, left: float, right: float, spawn_list: Array[Dictionary]) -> Ambush:
    var ambush: Ambush = Ambush.new()
    ambush.name = label
    ambush.trigger_x = trigger
    ambush.left_x = left
    ambush.right_x = right
    ambush.spawns = spawn_list
    return ambush


func _ready() -> void:
    for x: float in [left_x, right_x]:
        _walls.append(_make_wall(x))


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
            var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
            if enabled and player != null and not bool(player.get("in_3d_mode")) \
                    and player.global_position.x > trigger_x and player.global_position.x < right_x \
                    and absf(player.global_position.y - global_position.y) < 4.0:
                _start()
        State.ACTIVE:
            if alive_count() == 0:
                state = State.CLEARED
                _set_walls(false)
                cleared.emit(self)


func _start() -> void:
    state = State.ACTIVE
    _set_walls(true)
    enemies.clear()
    for spawn: Dictionary in spawns:
        var x: float = float(spawn["x"])
        var enemy: Node3D
        if spawn["type"] == &"archer":
            enemy = EnemyFactory.archer(get_parent(), x, left_x + 0.8, right_x - 0.8)
        else:
            enemy = EnemyFactory.husk(get_parent(), x, left_x + 0.8, right_x - 0.8)
        enemy.add_to_group(&"ambush_enemy")
        enemies.append(enemy)
    started.emit(self)


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
    box.size = Vector3(0.6, 6.0, 4.0)
    shape.shape = box
    shape.disabled = true
    wall.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(0.6, 6.0, 3.0)
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


func _set_walls(up: bool) -> void:
    for wall: StaticBody3D in _walls:
        (wall.get_child(0) as CollisionShape3D).set_deferred(&"disabled", not up)
        wall.visible = up


func wall_collision_enabled() -> bool:
    return not _walls.is_empty() and not (_walls[0].get_child(0) as CollisionShape3D).disabled

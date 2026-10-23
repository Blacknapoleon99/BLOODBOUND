class_name SpikeTrap
extends Node3D
## A strip of bone spikes in the causeway floor that cycles: down (`down_time`) -> warning glow
## (`warn_time`) -> up and lethal-ish (`up_time`, 1 damage + a toss upward) -> down. Time your run
## or jump over the strip. `phase_offset` desynchronises neighbouring traps.
## `SpikeTrap.enabled = false` keeps every trap down (scripted tests that walk the level).

static var enabled: bool = true

enum State { DOWN, WARN, UP }

var down_time: float = 1.5
var warn_time: float = 0.5
var up_time: float = 0.7
var phase_offset: float = 0.0
var width: float = 2.0
## Strip depth (z). Side view: the 2.6 m plate; full 3D: the hall, or the ledge it sits on.
var depth: float = 2.6
var state: State = State.DOWN
var hitbox: Hitbox
var _t: float = 0.0
var _spikes: Node3D
var _plate_material: StandardMaterial3D
var _spike_material: StandardMaterial3D


static func create(label: String, center_x: float, floor_y: float, strip_width: float, offset: float = 0.0, z: float = 0.0, strip_depth: float = -1.0) -> SpikeTrap:
    var trap: SpikeTrap = SpikeTrap.new()
    trap.name = label
    trap.add_to_group(&"spike_trap")
    trap.position = Vector3(center_x, floor_y, z)
    if strip_depth > 0.0:
        trap.depth = strip_depth
    elif Lane.full_3d:
        trap.depth = Lane.depth() - 0.4
    trap.width = strip_width
    trap.phase_offset = offset
    trap._t = offset
    trap._build()
    return trap


func cycle_time() -> float:
    return down_time + warn_time + up_time


func _build() -> void:
    _plate_material = GothicMaterials.standard("rust_iron", Color(0.55, 0.42, 0.38), 0.8)  # a rusted grate (DEC-054)
    _spike_material = GothicMaterials.standard("rust_iron", Color(0.95, 0.88, 0.8), 0.6, false)
    # Modelled grate tiles and octagonal rusted spikes (DEC-057), one MultiMesh each; the
    # scripted materials still drive the warning pulse.
    var tile: ArrayMesh = GothicProps.mesh("spike_plate_tile", {&"iron": _plate_material})
    if tile != null:
        var nx: int = maxi(1, roundi(width))
        var nz: int = maxi(1, roundi(depth))
        var tiles: Array[Transform3D] = []
        for i in nx:
            for j in nz:
                var at: Vector3 = Vector3(-width * 0.5 + (i + 0.5) * width / nx, 0.0, -depth * 0.5 + (j + 0.5) * depth / nz)
                tiles.append(Transform3D(Basis.from_scale(Vector3(width / nx, 1.0, depth / nz)), at))
        add_child(_multi(tile, tiles, "Plate"))
    else:
        var plate: MeshInstance3D = MeshInstance3D.new()
        var plate_mesh: BoxMesh = BoxMesh.new()
        plate_mesh.size = Vector3(width, 0.04, depth)
        plate.mesh = plate_mesh
        plate.material_override = _plate_material
        plate.position.y = 0.02
        add_child(plate)
    _spikes = Node3D.new()
    _spikes.name = "Spikes"
    add_child(_spikes)
    var count: int = maxi(2, int(width / 0.45))
    var rows: int = 1 if depth <= 2.6 else int(depth / 0.9)  # a bed of spikes across a 3D hall
    var spike_mesh: ArrayMesh = GothicProps.mesh("spike", {&"iron": _spike_material})
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = hash(name)
    var spikes: Array[Transform3D] = []
    for r in rows:
        var z: float = 0.0 if rows == 1 else -depth * 0.5 + (r + 0.5) * depth / rows
        for i in count:
            var x: float = -width * 0.5 + (i + 0.5) * width / count
            if spike_mesh != null:
                var tilt: Basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06))
                spikes.append(Transform3D(tilt.scaled(Vector3.ONE * rng.randf_range(0.92, 1.08)), Vector3(x, 0.0, z)))
                continue
            var spike: MeshInstance3D = MeshInstance3D.new()
            var cone: CylinderMesh = CylinderMesh.new()
            cone.top_radius = 0.0
            cone.bottom_radius = 0.14
            cone.height = 0.9
            spike.mesh = cone
            spike.material_override = _spike_material
            spike.position = Vector3(x, 0.45, z)
            _spikes.add_child(spike)
    if spike_mesh != null:
        _spikes.add_child(_multi(spike_mesh, spikes, "Spike bed"))
    _spikes.position.y = -0.95  # retracted into the floor
    hitbox = Hitbox.new()
    hitbox.team = &"enemy"
    hitbox.damage = 1
    hitbox.category = &"hazard"
    hitbox.knockback = 2.0
    hitbox.knockback_up = 8.0
    hitbox.hitstun = 0.3
    hitbox.attack_id = &"spike_trap"
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(width - 0.2, 0.9, 2.0 if depth <= 2.6 else depth - 0.4)
    shape.shape = box
    shape.position.y = 0.45
    hitbox.add_child(shape)
    add_child(hitbox)


static func _multi(m: Mesh, xfs: Array[Transform3D], label: String) -> MultiMeshInstance3D:
    var multi: MultiMesh = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = m
    multi.instance_count = xfs.size()
    for k in xfs.size():
        multi.set_instance_transform(k, xfs[k])
    var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = multi
    return node


## Starts the cycle over (used when the player respawns).
func reset() -> void:
    _t = phase_offset
    _set_state(State.DOWN)


func _physics_process(delta: float) -> void:
    if not enabled:
        if state != State.DOWN:
            _set_state(State.DOWN)
        return
    _t = fmod(_t + delta, cycle_time())
    var next: State = State.DOWN
    if _t >= down_time + warn_time:
        next = State.UP
    elif _t >= down_time:
        next = State.WARN
    if next != state:
        _set_state(next)
    if state == State.WARN:
        _plate_material.emission_enabled = true
        _plate_material.emission = Color(1.0, 0.2, 0.05) * (0.5 + 0.5 * sin(_t * 30.0))


func _set_state(next: State) -> void:
    state = next
    match state:
        State.DOWN:
            hitbox.deactivate()
            _spikes.position.y = -0.95
            _plate_material.emission_enabled = false
        State.WARN:
            _spikes.position.y = -0.75  # tips peek out
        State.UP:
            _spikes.position.y = 0.0
            _plate_material.emission_enabled = false
            hitbox.activate()

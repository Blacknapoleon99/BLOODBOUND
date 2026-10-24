class_name BloodDroplets
extends MultiMeshInstance3D
## Every flying blood droplet in the scene, drawn as one MultiMesh (stretched along its velocity)
## and simulated by hand: gravity, a little drag and one ray per droplet per physics tick against
## world geometry. A droplet that lands with a splat size leaves a Gore splat where it hit.
## Presentation only: rays never touch hurtboxes, characters or gameplay state.
## One instance per scene, created lazily by Gore (group "gore_droplets").

const CAPACITY: int = 768
const GRAVITY: float = 21.0
const DRAG: float = 0.7
const WORLD_MASK: int = 1
const DROP_SHADE: float = 0.55

var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _radius: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _delay: PackedFloat32Array = PackedFloat32Array()
var _splat: PackedFloat32Array = PackedFloat32Array()
var _color: PackedColorArray = PackedColorArray()
var _active: int = 0
var _query: PhysicsRayQueryParameters3D


static func create() -> BloodDroplets:
    var node: BloodDroplets = BloodDroplets.new()
    node.name = "GoreDroplets"
    return node


func _init() -> void:
    add_to_group(&"gore_droplets")
    top_level = true
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    custom_aabb = AABB(Vector3(-5000.0, -5000.0, -5000.0), Vector3(10000.0, 10000.0, 10000.0))
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 6
    mesh.rings = 3
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.albedo_color = Color.WHITE
    mat.roughness = 0.08
    mat.metallic_specular = 0.8
    mesh.material = mat
    multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    multimesh.mesh = mesh
    multimesh.instance_count = CAPACITY
    multimesh.visible_instance_count = 0
    _pos.resize(CAPACITY)
    _vel.resize(CAPACITY)
    _radius.resize(CAPACITY)
    _life.resize(CAPACITY)
    _delay.resize(CAPACITY)
    _splat.resize(CAPACITY)
    _color.resize(CAPACITY)
    _query = PhysicsRayQueryParameters3D.new()
    _query.collision_mask = WORLD_MASK
    _query.collide_with_areas = false
    _query.hit_from_inside = false


## Live droplets (including ones still waiting on their delay).
func active_count() -> int:
    return _active


## Launches one droplet. `splat_size` > 0 leaves a splat of that diameter where it lands.
## `delay` holds it back (unseen) so a spurt reads as a pulsing stream. Returns false when full.
func add(at: Vector3, velocity: Vector3, radius: float, color: Color, life: float, delay: float = 0.0, splat_size: float = 0.0) -> bool:
    if _active >= CAPACITY:
        return false
    var i: int = _active
    _pos[i] = at
    _vel[i] = velocity
    _radius[i] = radius
    # Airborne drops are lit like glossy beads (and often right by the hero's lights), so they
    # are drawn darker than the splat they leave, which keeps the full tint.
    _color[i] = Color(color.r * DROP_SHADE, color.g * DROP_SHADE, color.b * DROP_SHADE, color.a)
    _life[i] = life
    _delay[i] = delay
    _splat[i] = splat_size
    _active += 1
    return true


func _physics_process(delta: float) -> void:
    if _active == 0:
        if multimesh.visible_instance_count != 0:
            multimesh.visible_instance_count = 0
        return
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var i: int = _active - 1
    while i >= 0:
        if _delay[i] > 0.0:
            _delay[i] -= delta
            i -= 1
            continue
        var v: Vector3 = _vel[i]
        v.y -= GRAVITY * delta
        v *= maxf(0.0, 1.0 - DRAG * delta)
        _vel[i] = v
        var from: Vector3 = _pos[i]
        var to: Vector3 = from + v * delta
        var landed: bool = false
        if space != null:
            _query.from = from
            _query.to = to + v.normalized() * _radius[i]
            var hit: Dictionary = space.intersect_ray(_query)
            if not hit.is_empty() and not _is_character(hit.get(&"collider")):
                landed = true
                if _splat[i] > 0.0:
                    Gore.splat(self, hit[&"position"], hit[&"normal"], _splat[i], _undarken(_color[i]), v)
        _pos[i] = to
        _life[i] -= delta
        if landed or _life[i] <= 0.0:
            _remove(i)
        i -= 1
    _write_instances()


func _undarken(c: Color) -> Color:
    return Color(c.r / DROP_SHADE, c.g / DROP_SHADE, c.b / DROP_SHADE, c.a)


func _is_character(collider: Variant) -> bool:
    return collider is CharacterBody3D or collider is RigidBody3D


func _remove(i: int) -> void:
    var last: int = _active - 1
    if i != last:
        _pos[i] = _pos[last]
        _vel[i] = _vel[last]
        _radius[i] = _radius[last]
        _color[i] = _color[last]
        _life[i] = _life[last]
        _delay[i] = _delay[last]
        _splat[i] = _splat[last]
    _active = last


func _write_instances() -> void:
    var hidden: Transform3D = Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0.0, -10000.0, 0.0))
    for i in _active:
        if _delay[i] > 0.0:
            multimesh.set_instance_transform(i, hidden)
            continue
        var v: Vector3 = _vel[i]
        var speed: float = v.length()
        var r: float = _radius[i]
        var basis: Basis = Basis()
        if speed > 0.01:
            var dir: Vector3 = v / speed
            if dir.dot(Vector3.UP) < -0.999:
                basis = Basis(Vector3.RIGHT, PI)
            else:
                basis = Basis(Quaternion(Vector3.UP, dir))
        var stretch: float = clampf(1.0 + speed * 0.3, 1.0, 4.5)
        basis = basis * Basis.from_scale(Vector3(r * 2.0, r * 2.0 * stretch, r * 2.0))
        multimesh.set_instance_transform(i, Transform3D(basis, _pos[i]))
        multimesh.set_instance_color(i, _color[i])
    multimesh.visible_instance_count = _active

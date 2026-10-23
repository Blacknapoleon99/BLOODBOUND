class_name BackdropFlock
extends RefCounted
## Crows and bats for the background world (DEC-055): one MultiMesh per flock (one draw call),
## wings flapped in `backdrop_flock.gdshader`, bodies steered round a centre on the CPU.

const SHADER: Shader = preload("res://assets/shaders/backdrop/backdrop_flock.gdshader")

static var _mesh: ArrayMesh
static var _materials: Dictionary = {}


## A bat silhouette: a small body and two jagged wings along X (forward is -Z), `span` = 1 m.
static func _bat_mesh() -> ArrayMesh:
    if _mesh != null:
        return _mesh
    var model: Array = BackdropKit.model("bd_bat")
    if not model.is_empty():
        # The modelled bat (DEC-057): furred body, ears, scalloped wings. Its head points +Z;
        # flip it to face -Z (and keep the winding).
        var mv: PackedVector3Array = (model[0] as PackedVector3Array).duplicate()
        var mn: PackedVector3Array = (model[1] as PackedVector3Array).duplicate()
        for i in mv.size():
            mv[i] = Vector3(mv[i].x, mv[i].y, -mv[i].z)
            mn[i] = Vector3(mn[i].x, mn[i].y, -mn[i].z)
        var mi: PackedInt32Array = (model[3] as PackedInt32Array).duplicate()
        for t in range(0, mi.size() - 2, 3):
            var swap: int = mi[t + 1]
            mi[t + 1] = mi[t + 2]
            mi[t + 2] = swap
        var marrays: Array = []
        marrays.resize(Mesh.ARRAY_MAX)
        marrays[Mesh.ARRAY_VERTEX] = mv
        marrays[Mesh.ARRAY_NORMAL] = mn
        marrays[Mesh.ARRAY_INDEX] = mi
        _mesh = ArrayMesh.new()
        _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, marrays)
        return _mesh
    var v: PackedVector3Array = PackedVector3Array()
    # Body.
    v.append_array(PackedVector3Array([Vector3(0, 0, -0.18), Vector3(0.05, 0, 0.12), Vector3(-0.05, 0, 0.12)]))
    for s in [-1.0, 1.0]:
        # Wing: three scalloped panels from the body out to the tip.
        var root_f: Vector3 = Vector3(s * 0.04, 0, -0.08)
        var root_b: Vector3 = Vector3(s * 0.04, 0, 0.1)
        var mid: Vector3 = Vector3(s * 0.28, 0.02, -0.12)
        var tip: Vector3 = Vector3(s * 0.5, 0.0, -0.02)
        var notch1: Vector3 = Vector3(s * 0.2, 0, 0.12)
        var notch2: Vector3 = Vector3(s * 0.38, 0, 0.1)
        v.append_array(PackedVector3Array([root_f, mid, root_b]))
        v.append_array(PackedVector3Array([root_b, mid, notch1]))
        v.append_array(PackedVector3Array([notch1, mid, notch2]))
        v.append_array(PackedVector3Array([notch2, mid, tip]))
    var n: PackedVector3Array = PackedVector3Array()
    for i in v.size():
        n.append(Vector3.UP)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = v
    arrays[Mesh.ARRAY_NORMAL] = n
    _mesh = ArrayMesh.new()
    _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return _mesh


static func _material(act: int) -> ShaderMaterial:
    var key: int = mini(act, 2)
    if not _materials.has(key):
        var m: ShaderMaterial = ShaderMaterial.new()
        m.shader = SHADER
        m.set_shader_parameter("haze_color", BackdropKit.theme(act)["haze"])
        _materials[key] = m
    return _materials[key]


static func all_materials() -> Array:
    return _materials.values()


## A flock of `count` birds `span` metres across.
static func create(count: int, span: float, act: int) -> MultiMeshInstance3D:
    var mm: MultiMesh = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_custom_data = true
    mm.mesh = _bat_mesh()
    mm.instance_count = count
    var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = _material(act)
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mmi.custom_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 1000, 4000))
    mmi.set_meta(&"span", span)
    return mmi


## Gives every bird its own orbit radius, speed, height and flap phase.
static func scatter(mmi: MultiMeshInstance3D, rng: RandomNumberGenerator) -> void:
    var params: Array = []
    for i in mmi.multimesh.instance_count:
        var ph: float = rng.randf()
        params.append([rng.randf_range(0.55, 1.35), rng.randf_range(0.35, 0.7) * (1.0 if rng.randf() < 0.8 else -1.0), rng.randf_range(-4.0, 4.0), ph * TAU, rng.randf_range(0.8, 1.25)])
        mmi.multimesh.set_instance_custom_data(i, Color(ph, 0, 0, 0))
    mmi.set_meta(&"params", params)
    circle(mmi, Vector3.ZERO, 10.0, 0.0)


## Places every bird on its orbit round `center` at time `t`.
static func circle(mmi: MultiMeshInstance3D, center: Vector3, radius: float, t: float) -> void:
    var params: Array = mmi.get_meta(&"params", [])
    var span: float = mmi.get_meta(&"span", 1.0)
    for i in params.size():
        var p: Array = params[i]
        var speed: float = p[1]
        var a: float = t * speed * (12.0 / maxf(radius * p[0], 4.0)) + p[3]
        var r: float = radius * p[0]
        var pos: Vector3 = center + Vector3(cos(a) * r, p[2] + sin(t * 0.8 + p[3]) * 2.0, sin(a) * r)
        var fwd: Vector3 = Vector3(-sin(a), 0.0, cos(a)) * signf(speed)
        var basis: Basis = Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3.BACK, 0.35 * signf(speed))
        mmi.multimesh.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * span * p[4]), pos))

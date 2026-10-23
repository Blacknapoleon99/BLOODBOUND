class_name BackdropKit
extends RefCounted
## Procedural low-poly building blocks for the background world (DEC-055): gothic towers and
## spires, pointed arches, flying buttresses, floating rock islands, dead trees, chains, gibbet
## cages, bone ribs, a colossal cathedral and mountain rings. Pieces are merged (`Merge`) into
## ONE single-surface ArrayMesh per object, so a whole island or the whole cathedral is a single
## draw call. Vertex colours carry the look: rgb tints the stone, alpha < 0.5 marks glowing
## parts (windows, the rose window, cage lanterns) for `backdrop_stone.gdshader`.
##
## Decor only: nothing here has collision. A few Kenney Castle Kit pieces (CC0, copied into
## assets/models/backdrop/kenney_castle/) are merged in as ruined towers when they're imported;
## everything else is generated here.

const STONE_SHADER: Shader = preload("res://assets/shaders/backdrop/backdrop_stone.gdshader")
const KENNEY_DIR: String = "res://assets/models/backdrop/kenney_castle/"

## Tints (vertex colour rgb multiplies the material's stone colour).
const C_STONE: Color = Color(1.0, 1.0, 1.0, 1.0)
const C_DARK: Color = Color(0.7, 0.68, 0.72, 1.0)
const C_LIGHT: Color = Color(1.35, 1.3, 1.3, 1.0)
const C_BONE: Color = Color(3.6, 3.2, 2.6, 1.0)
const C_IRON: Color = Color(0.55, 0.5, 0.5, 1.0)
const C_WOOD: Color = Color(0.85, 0.7, 0.6, 1.0)
## Glow (alpha 0): rgb scales the material's glow colour.
const C_GLOW: Color = Color(1.0, 1.0, 1.0, 0.0)
const C_GLOW_DIM: Color = Color(0.45, 0.45, 0.45, 0.0)

static var _prims: Dictionary = {}
static var _rocks: Dictionary = {}
static var _kenney: Dictionary = {}
static var _materials: Dictionary = {}


## Act themes: stone, glow, haze, rim. Act 0/1 = the bleeding cathedral (blood red), act 2 =
## the drowned belfries (violet-crimson, colder stone).
static func theme(act: int) -> Dictionary:
    if act >= 2:
        return {
            "stone": Color(0.085, 0.09, 0.115),
            "glow": Color(0.9, 0.05, 0.4),
            "band": Color(0.3, 0.07, 0.24),
            "haze": Color(0.085, 0.06, 0.11),
            "rim": Color(0.42, 0.16, 0.36),
            "sea_top": Color(0.2, 0.06, 0.16),
            "sea_deep": Color(0.035, 0.02, 0.05),
            "ember": Color(1.0, 0.25, 0.45),
        }
    return {
        "stone": Color(0.105, 0.092, 0.1),
        "glow": Color(1.0, 0.07, 0.035),
        "band": Color(0.42, 0.075, 0.05),
        "haze": Color(0.115, 0.055, 0.065),
        "rim": Color(0.55, 0.15, 0.12),
        "sea_top": Color(0.3, 0.07, 0.06),
        "sea_deep": Color(0.05, 0.018, 0.022),
        "ember": Color(1.0, 0.36, 0.08),
    }


## The shared stone material for an act and band (`far` = horizon: longer haze, stronger glow).
## Materials are shared so every room of an act batches the same state.
static func stone_material(act: int, far: bool) -> ShaderMaterial:
    var key: String = "%d_%s" % [mini(act, 2), far]
    if _materials.has(key):
        return _materials[key]
    var t: Dictionary = theme(act)
    var m: ShaderMaterial = ShaderMaterial.new()
    m.shader = STONE_SHADER
    m.set_shader_parameter("stone_color", t["stone"])
    m.set_shader_parameter("glow_color", t["glow"])
    m.set_shader_parameter("haze_color", t["haze"])
    m.set_shader_parameter("rim_color", t["rim"])
    m.set_shader_parameter("glow_energy", 4.0 if far else 3.0)
    m.set_shader_parameter("haze_start", 120.0 if far else 30.0)
    m.set_shader_parameter("haze_end", 1500.0 if far else 420.0)
    m.set_shader_parameter("haze_max", 0.8 if far else 0.62)
    m.set_shader_parameter("rim_strength", 0.75 if far else 0.35)
    _materials[key] = m
    return m


## Every shared material built so far (the horizon syncs their haze to the scene's fog).
static func all_materials() -> Array:
    return _materials.values()


# --- Merging ---------------------------------------------------------------------------

## Accumulates transformed primitives into one vertex-coloured triangle list.
class Merge:
    var verts: PackedVector3Array = PackedVector3Array()
    var normals: PackedVector3Array = PackedVector3Array()
    var colors: PackedColorArray = PackedColorArray()
    var indices: PackedInt32Array = PackedInt32Array()

    func is_empty() -> bool:
        return verts.is_empty()

    func add_arrays(v: PackedVector3Array, n: PackedVector3Array, idx: PackedInt32Array, xf: Transform3D, color: Color) -> void:
        var base: int = verts.size()
        var nb: Basis = xf.basis.inverse().transposed()
        var has_n: bool = n.size() == v.size()
        for i in v.size():
            verts.append(xf * v[i])
            normals.append((nb * n[i]).normalized() if has_n else Vector3.UP)
            colors.append(color)
        if idx.is_empty():
            for i in v.size():
                indices.append(base + i)
        else:
            for i in idx:
                indices.append(base + i)

    func add_mesh(mesh: Mesh, xf: Transform3D, color: Color) -> void:
        for s in mesh.get_surface_count():
            var arr: Array = mesh.surface_get_arrays(s)
            var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
            var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
            var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
            add_arrays(v, n, idx, xf, color)

    func commit() -> ArrayMesh:
        var arrays: Array = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = verts
        arrays[Mesh.ARRAY_NORMAL] = normals
        arrays[Mesh.ARRAY_COLOR] = colors
        arrays[Mesh.ARRAY_INDEX] = indices
        var mesh: ArrayMesh = ArrayMesh.new()
        if not verts.is_empty():
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        return mesh


## A MeshInstance3D for merged decor: no shadows, no collision, the act's shared material.
static func instance(m: Merge, act: int, far: bool, label: String) -> MeshInstance3D:
    var mi: MeshInstance3D = MeshInstance3D.new()
    mi.name = label
    mi.mesh = m.commit()
    mi.material_override = stone_material(act, far)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
    return mi


# --- Primitives ------------------------------------------------------------------------

static func _box() -> BoxMesh:
    if not _prims.has("box"):
        var b: BoxMesh = BoxMesh.new()
        b.size = Vector3.ONE
        _prims["box"] = b
    return _prims["box"]


## Unit-height cylinder (bottom radius 1, top radius `top`), `sides` facets.
static func _cyl(sides: int, top: float) -> CylinderMesh:
    var key: String = "cyl_%d_%.2f" % [sides, top]
    if not _prims.has(key):
        var c: CylinderMesh = CylinderMesh.new()
        c.height = 1.0
        c.bottom_radius = 1.0
        c.top_radius = top
        c.radial_segments = sides
        c.rings = 0
        c.cap_top = top > 0.0
        _prims[key] = c
    return _prims[key]


static func _sphere(segs: int) -> SphereMesh:
    var key: String = "sph_%d" % segs
    if not _prims.has(key):
        var s: SphereMesh = SphereMesh.new()
        s.radius = 1.0
        s.height = 2.0
        s.radial_segments = segs
        s.rings = maxi(3, segs / 2)
        _prims[key] = s
    return _prims[key]


static func _torus(sides: int, thickness: float) -> TorusMesh:
    var key: String = "tor_%d_%.2f" % [sides, thickness]
    if not _prims.has(key):
        var t: TorusMesh = TorusMesh.new()
        t.inner_radius = 1.0 - thickness
        t.outer_radius = 1.0
        t.rings = sides
        t.ring_segments = 4
        _prims[key] = t
    return _prims[key]


static func _prism() -> PrismMesh:
    if not _prims.has("prism"):
        var p: PrismMesh = PrismMesh.new()
        p.size = Vector3.ONE
        _prims["prism"] = p
    return _prims["prism"]


## A right-handed basis whose Y axis points along `dir`.
static func basis_y(dir: Vector3) -> Basis:
    var y: Vector3 = dir.normalized()
    var ref: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.UP)) > 0.95 else Vector3.UP
    var x: Vector3 = y.cross(ref).normalized()
    var z: Vector3 = x.cross(y)
    return Basis(x, y, z)


static func box(m: Merge, center: Vector3, size: Vector3, color: Color, rot: Basis = Basis.IDENTITY) -> void:
    m.add_mesh(_box(), Transform3D(rot * Basis.from_scale(size), center), color)


## A tapered beam (cylinder) from `a` to `b`, radius r0 at a and r1 at b.
static func beam(m: Merge, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, color: Color) -> void:
    var d: Vector3 = b - a
    var length: float = d.length()
    if length < 0.001:
        return
    var bs: Basis = basis_y(d)
    var top: float = snappedf(clampf(r1 / maxf(r0, 0.001), 0.0, 1.0), 0.05)
    var xf: Transform3D = Transform3D(Basis(bs.x * r0, bs.y * length, bs.z * r0), (a + b) * 0.5)
    m.add_mesh(_cyl(sides, top), xf, color)


## An upright spire/column standing on `base`.
static func column(m: Merge, base: Vector3, height: float, radius: float, top: float, sides: int, color: Color) -> void:
    beam(m, base, base + Vector3.UP * height, radius, radius * top, sides, color)


static func ball(m: Merge, center: Vector3, radius: Vector3, color: Color, segs: int = 8) -> void:
    m.add_mesh(_sphere(segs), Transform3D(Basis.from_scale(radius), center), color)


## A gable/roof prism: ridge along local X of `rot`, `size` = (length, height, width).
static func roof(m: Merge, center: Vector3, size: Vector3, color: Color, rot: Basis = Basis.IDENTITY) -> void:
    # PrismMesh: triangle in XY extruded along Z; turn it so the ridge runs along X.
    var turn: Basis = Basis(Vector3.UP, PI * 0.5)
    m.add_mesh(_prism(), Transform3D(rot * turn * Basis.from_scale(Vector3(size.z, size.y, size.x)), center), color)


# --- Gothic pieces ---------------------------------------------------------------------

## A pointed (equilateral) gothic arch in the plane of `xf`'s local XY, feet at x = ±span/2,
## apex at y = 0.866 span. `keep` < 1 breaks the right half off (a ruined arch).
static func pointed_arch(m: Merge, xf: Transform3D, span: float, thick: float, color: Color, segs: int = 5, keep: float = 1.0) -> void:
    var r: float = span
    for side in [-1.0, 1.0]:
        var c: Vector2 = Vector2(-side * span * 0.5, 0.0)
        var a0: float = 0.0 if side > 0.0 else PI
        var a1: float = PI / 3.0 if side > 0.0 else PI * 2.0 / 3.0
        var n: int = segs if side < 0.0 else int(round(segs * keep))
        for i in n:
            var t0: float = lerpf(a0, a1, float(i) / segs)
            var t1: float = lerpf(a0, a1, float(i + 1) / segs)
            var p0: Vector2 = c + Vector2(cos(t0), sin(t0)) * r
            var p1: Vector2 = c + Vector2(cos(t1), sin(t1)) * r
            beam(m, xf * Vector3(p0.x, p0.y, 0.0), xf * Vector3(p1.x, p1.y, 0.0), thick, thick, 4, color)


## A lancet window (glowing slit with a pointed head) on a wall facing `normal`.
static func lancet(m: Merge, center: Vector3, normal: Vector3, w: float, h: float, color: Color = C_GLOW) -> void:
    var rot: Basis = Basis.looking_at(-normal, Vector3.UP)
    box(m, center, Vector3(w, h, w * 0.3) * Vector3(1, 1, 1), color, rot)
    beam(m, center + Vector3.UP * h * 0.5, center + Vector3.UP * (h * 0.5 + w * 0.9), w * 0.62, 0.0, 4, color)


## A square gothic tower with corner pinnacles, a lit belfry and a spire. `broken` snaps the
## spire and bites the parapet.
static func gothic_tower(m: Merge, base: Vector3, w: float, h: float, spire: float, broken: bool, rng: RandomNumberGenerator) -> void:
    box(m, base + Vector3(0, h * 0.5, 0), Vector3(w, h, w), C_STONE)
    # Buttressed corners.
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var corner: Vector3 = base + Vector3(sx * w * 0.5, 0.0, sz * w * 0.5)
            box(m, corner + Vector3(0, h * 0.47, 0), Vector3(w * 0.16, h * 0.94, w * 0.16), C_DARK)
            column(m, corner + Vector3(0, h * 0.94, 0), w * 0.42, w * 0.09, 0.0, 4, C_DARK)
    # String courses.
    for f in [0.33, 0.66]:
        box(m, base + Vector3(0, h * f, 0), Vector3(w * 1.08, w * 0.05, w * 1.08), C_LIGHT)
    # Belfry lancets on all four faces.
    for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
        var face: Vector3 = base + dir * (w * 0.5 + 0.02 * w) + Vector3.UP * h * 0.8
        for k in [-1.0, 1.0]:
            var side: Vector3 = dir.cross(Vector3.UP) * k * w * 0.18
            lancet(m, face + side, dir, w * 0.1, h * 0.12, C_GLOW if rng.randf() < 0.75 else C_GLOW_DIM)
        lancet(m, base + dir * (w * 0.51) + Vector3.UP * h * 0.45, dir, w * 0.08, h * 0.1, C_GLOW_DIM)
    if broken:
        # Jagged stump of a spire and a few loose blocks.
        column(m, base + Vector3(0, h, 0), spire * 0.3, w * 0.42, 0.55, 8, C_DARK)
        for i in 4:
            var off: Vector3 = Vector3(rng.randf_range(-0.3, 0.3) * w, h + spire * rng.randf_range(0.2, 0.35), rng.randf_range(-0.3, 0.3) * w)
            box(m, base + off, Vector3.ONE * w * rng.randf_range(0.12, 0.22), C_DARK, Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf())))
    else:
        column(m, base + Vector3(0, h, 0), spire, w * 0.45, 0.0, 8, C_DARK)
        beam(m, base + Vector3(0, h + spire, 0), base + Vector3(0, h + spire * 1.08, 0), w * 0.03, w * 0.03, 4, C_IRON)


## A flying buttress: a pier with a pinnacle, and a strut leaning toward `to` (the wall it props).
static func flying_buttress(m: Merge, pier_base: Vector3, pier_h: float, to: Vector3, w: float, broken: bool) -> void:
    box(m, pier_base + Vector3(0, pier_h * 0.5, 0), Vector3(w, pier_h, w), C_STONE)
    column(m, pier_base + Vector3(0, pier_h, 0), w * 2.2, w * 0.45, 0.0, 4, C_DARK)
    var top: Vector3 = pier_base + Vector3(0, pier_h * 0.86, 0)
    var mid: Vector3 = top.lerp(to, 0.5) + Vector3.UP * w * 0.9
    beam(m, top, mid, w * 0.32, w * 0.28, 4, C_DARK)
    if not broken:
        beam(m, mid, to, w * 0.28, w * 0.26, 4, C_DARK)
    else:
        box(m, mid + (to - mid) * 0.18, Vector3.ONE * w * 0.45, C_DARK, Basis.from_euler(Vector3(0.4, 0.7, 0.2)))
    beam(m, top + Vector3.DOWN * w * 1.2, mid.lerp(to, 0.4) + Vector3.DOWN * w * 2.2, w * 0.2, w * 0.2, 4, C_DARK)


## The colossal cathedral: west front faces -X (toward the player), nave runs along +X.
## Local metres at `scale` 1: ~330 m long, ~250 m to the crossing spire's tip.
static func cathedral(m: Merge, xf: Transform3D, rng: RandomNumberGenerator) -> void:
    var sub: Merge = Merge.new()
    var nave_w: float = 70.0
    # Nave + aisles + roof.
    box(sub, Vector3(180, 55, 0), Vector3(240, 110, nave_w), C_STONE)
    roof(sub, Vector3(180, 132, 0), Vector3(240, 44, nave_w + 6), C_DARK)
    for s in [-1.0, 1.0]:
        box(sub, Vector3(180, 30, s * 50), Vector3(240, 60, 30), C_DARK)
    # Clerestory windows and flying buttresses.
    for i in 9:
        var x: float = 80.0 + i * 25.0
        for s in [-1.0, 1.0]:
            lancet(sub, Vector3(x, 82, s * (nave_w * 0.5 + 0.4)), Vector3(0, 0, s), 5.0, 22.0, C_GLOW if rng.randf() < 0.8 else C_GLOW_DIM)
            lancet(sub, Vector3(x, 36, s * 65.5), Vector3(0, 0, s), 4.0, 16.0, C_GLOW_DIM)
            flying_buttress(sub, Vector3(x, 0, s * 92), 88.0, Vector3(x, 100, s * nave_w * 0.5), 7.0, rng.randf() < 0.25)
    # West front: facade block, gable, portal, rose window.
    box(sub, Vector3(10, 75, 0), Vector3(20, 150, 84), C_STONE)
    roof(sub, Vector3(10, 168, 0), Vector3(20, 36, 84), C_STONE)
    column(sub, Vector3(10, 186, 0), 26.0, 3.0, 0.0, 4, C_DARK)
    lancet(sub, Vector3(-0.6, 24, 0), Vector3.LEFT, 14.0, 34.0, C_GLOW)
    pointed_arch(sub, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-1.5, 30, 0)), 22.0, 2.2, C_LIGHT, 5)
    var rose_c: Vector3 = Vector3(-0.8, 100, 0)
    var face_x: Basis = Basis(Vector3.BACK, PI * 0.5)
    sub.add_mesh(_cyl(24, 1.0), Transform3D(face_x * Basis.from_scale(Vector3(24, 1.2, 24)), rose_c), C_GLOW)
    sub.add_mesh(_torus(24, 0.12), Transform3D(face_x * Basis.from_scale(Vector3(26, 2, 26)), rose_c + Vector3(-1.2, 0, 0)), C_LIGHT)
    sub.add_mesh(_torus(16, 0.3), Transform3D(face_x * Basis.from_scale(Vector3(7, 2, 7)), rose_c + Vector3(-1.2, 0, 0)), C_LIGHT)
    for k in 12:
        var a: float = TAU * k / 12.0
        var dir: Vector3 = Vector3(0, cos(a), sin(a))
        beam(sub, rose_c + Vector3(-1.4, 0, 0) + dir * 6.5, rose_c + Vector3(-1.4, 0, 0) + dir * 24.5, 0.9, 0.7, 4, C_LIGHT)
        ball(sub, rose_c + Vector3(-1.6, 0, 0) + dir * 15.0, Vector3(1.4, 2.6, 2.6), C_LIGHT, 6)
    # Twin west towers: the north spire stands, the south one is snapped.
    gothic_tower(sub, Vector3(15, 0, -62), 34.0, 215.0, 120.0, false, rng)
    gothic_tower(sub, Vector3(15, 0, 62), 34.0, 200.0, 110.0, true, rng)
    # Crossing tower and its great spire; transepts.
    box(sub, Vector3(215, 70, 0), Vector3(50, 140, 150), C_STONE)
    roof(sub, Vector3(215, 160, 0), Vector3(50, 40, 150), C_DARK, Basis(Vector3.UP, PI * 0.5))
    gothic_tower(sub, Vector3(215, 120, 0), 46.0, 95.0, 150.0, false, rng)
    for s in [-1.0, 1.0]:
        sub.add_mesh(_cyl(24, 1.0), Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(14, 1.0, 14)), Vector3(215, 92, s * 75.6)), C_GLOW)
    # Apse.
    column(sub, Vector3(300, 0, 0), 110.0, 36.0, 1.0, 10, C_STONE)
    column(sub, Vector3(300, 110, 0), 40.0, 38.0, 0.0, 10, C_DARK)
    # The rock the cathedral was torn up on, and the chains that hold it over the abyss.
    rock(sub, Transform3D(Basis.from_scale(Vector3(230, 150, 150)), Vector3(170, -4, 0)), 7, C_DARK)
    for k in 4:
        var a: float = TAU * (k + 0.5) / 4.0
        var top: Vector3 = Vector3(170 + cos(a) * 170, -60, sin(a) * 120)
        chain(sub, top, 160.0, 6.0, C_IRON)
    m.add_arrays(sub.verts, sub.normals, sub.indices, xf, C_STONE)
    _recolor_tail(m, sub)


## add_arrays() paints one colour; restore the sub-merge's own colours on the appended tail.
static func _recolor_tail(m: Merge, sub: Merge) -> void:
    var start: int = m.colors.size() - sub.colors.size()
    for i in sub.colors.size():
        m.colors[start + i] = sub.colors[i]


## Appends `sub` (already built in local space) under transform `xf`, keeping its colours.
static func append(m: Merge, sub: Merge, xf: Transform3D) -> void:
    m.add_arrays(sub.verts, sub.normals, sub.indices, xf, C_STONE)
    _recolor_tail(m, sub)


# --- Natural pieces --------------------------------------------------------------------

## A floating rock island (flat-ish top at local y ≈ 0.16, a long ragged root below to y ≈ -1.9),
## unit radius; `variant` picks one of a few cached shapes.
static func rock(m: Merge, xf: Transform3D, variant: int, color: Color) -> void:
    var data: Array = _rock_tris(variant % 8)
    m.add_arrays(data[0], data[1], PackedInt32Array(), xf, color)


static func _rock_tris(variant: int) -> Array:
    if _rocks.has(variant):
        return _rocks[variant]
    var noise: FastNoiseLite = FastNoiseLite.new()
    noise.seed = 1337 + variant * 101
    noise.frequency = 0.9
    var rings: int = 7
    var segs: int = 11
    var grid: Array = []
    for i in rings + 1:
        var row: Array = []
        var theta: float = PI * i / rings
        for j in segs:
            var phi: float = TAU * j / segs
            var p: Vector3 = Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
            var n: float = noise.get_noise_3dv(p * 1.7)
            var r: float = 1.0 + n * 0.32
            var y: float = p.y
            if y >= 0.0:
                y = 0.1 + y * 0.12 + n * 0.05
            else:
                r *= 1.0 + y * 0.62
                y = y * 1.9 + n * 0.25
            row.append(Vector3(p.x * r, y, p.z * r))
        grid.append(row)
    var v: PackedVector3Array = PackedVector3Array()
    var nn: PackedVector3Array = PackedVector3Array()
    for i in rings:
        for j in segs:
            var a: Vector3 = grid[i][j]
            var b: Vector3 = grid[i][(j + 1) % segs]
            var c: Vector3 = grid[i + 1][j]
            var d: Vector3 = grid[i + 1][(j + 1) % segs]
            for tri: Array in [[a, b, c], [b, d, c]]:
                var p0: Vector3 = tri[0]
                var p1: Vector3 = tri[1]
                var p2: Vector3 = tri[2]
                var fn: Vector3 = (p1 - p0).cross(p2 - p0)
                if fn.length_squared() < 0.0000001:
                    continue
                fn = fn.normalized()
                var centroid: Vector3 = (p0 + p1 + p2) / 3.0
                if fn.dot(centroid - Vector3(0, -0.4, 0)) < 0.0:
                    fn = -fn
                    var tmp: Vector3 = p1
                    p1 = p2
                    p2 = tmp
                v.append_array(PackedVector3Array([p0, p1, p2]))
                nn.append_array(PackedVector3Array([fn, fn, fn]))
    _rocks[variant] = [v, nn]
    return _rocks[variant]


## A dead, crooked tree: a trunk splitting into bare branches (`depth` levels).
static func dead_tree(m: Merge, base: Vector3, height: float, rng: RandomNumberGenerator, color: Color = C_WOOD) -> void:
    _branch(m, base, Vector3(rng.randf_range(-0.15, 0.15), 1.0, rng.randf_range(-0.15, 0.15)).normalized(), height, height * 0.06, 3, rng, color)


static func _branch(m: Merge, from: Vector3, dir: Vector3, length: float, radius: float, depth: int, rng: RandomNumberGenerator, color: Color) -> void:
    var to: Vector3 = from + dir * length
    beam(m, from, to, radius, radius * 0.6, 5, color)
    if depth <= 0:
        return
    var count: int = rng.randi_range(2, 3)
    for i in count:
        var side: Vector3 = Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)).normalized()
        var nd: Vector3 = (dir + side * rng.randf_range(0.6, 1.3) + Vector3.DOWN * rng.randf_range(0.0, 0.25)).normalized()
        _branch(m, to, nd, length * rng.randf_range(0.5, 0.7), radius * 0.6, depth - 1, rng, color)


## A hanging chain of `length` metres going straight down from `top`.
static func chain(m: Merge, top: Vector3, length: float, link: float, color: Color = C_IRON) -> void:
    var pitch: float = link * 1.25
    var count: int = maxi(1, int(length / pitch))
    for i in count:
        var c: Vector3 = top + Vector3.DOWN * (pitch * (i + 0.5))
        var rot: Basis = Basis(Vector3.UP, PI * 0.5 * (i % 2)) * Basis(Vector3.RIGHT, PI * 0.5)
        m.add_mesh(_torus(6, 0.32), Transform3D(rot * Basis.from_scale(Vector3(link * 0.5, link * 0.5, link * 0.85)), c), color)


## A gibbet cage hanging from `hang` (its hook), `size` ≈ height, with a slumped corpse inside
## and a dim lantern. Points down from `hang`.
static func cage(m: Merge, hang: Vector3, size: float, rng: RandomNumberGenerator) -> void:
    var r: float = size * 0.3
    var top: Vector3 = hang + Vector3.DOWN * size * 0.25
    var bottom: Vector3 = top + Vector3.DOWN * size
    beam(m, hang, top + Vector3.UP * r * 0.3, size * 0.025, size * 0.025, 4, C_IRON)
    column(m, top, r * 0.6, r * 1.05, 0.0, 8, C_IRON)
    for k in 8:
        var a: float = TAU * k / 8.0
        var off: Vector3 = Vector3(cos(a), 0.0, sin(a)) * r
        beam(m, bottom + off * 0.8, top + off, size * 0.018, size * 0.018, 3, C_IRON)
    for y in [0.0, 0.5, 1.0]:
        m.add_mesh(_torus(10, 0.1), Transform3D(Basis.from_scale(Vector3(r, size * 0.05, r) * (0.8 + 0.2 * y)), bottom.lerp(top, y)), C_IRON)
    # The prisoner: hunched bones.
    var hip: Vector3 = bottom + Vector3.UP * size * 0.2
    var neck: Vector3 = hip + Vector3(rng.randf_range(-0.1, 0.1), 0.45, 0.08) * size
    beam(m, hip, neck, size * 0.05, size * 0.04, 4, C_BONE)
    ball(m, neck + Vector3(0.04, 0.08, 0.05) * size, Vector3.ONE * size * 0.09, C_BONE, 6)
    for s in [-1.0, 1.0]:
        beam(m, neck, neck + Vector3(s * 0.32, -0.38, 0.1) * size, size * 0.025, size * 0.02, 3, C_BONE)
        beam(m, hip, hip + Vector3(s * 0.15, -0.2, 0.25) * size, size * 0.03, size * 0.02, 3, C_BONE)
    ball(m, bottom + Vector3.UP * size * 0.05, Vector3(r * 0.25, size * 0.05, r * 0.25), C_GLOW_DIM, 6)


## One giant curved rib (or arch of bone) from `root`, curling up and over toward `dir`.
static func rib(m: Merge, root: Vector3, dir: Vector3, span: float, rise: float, thick: float) -> void:
    var segs: int = 7
    var prev: Vector3 = root
    for i in segs:
        var t: float = float(i + 1) / segs
        var p: Vector3 = root + dir * (span * (1.0 - cos(t * PI * 0.62))) + Vector3.UP * (rise * sin(t * PI * 0.8))
        beam(m, prev, p, thick * (1.0 - 0.55 * (t - 1.0 / segs)), thick * (1.0 - 0.55 * t), 5, C_BONE)
        prev = p


## A colossal carcass lying in the abyss: a spine along local X with ribs rising on both sides
## and a horned skull at the head.
static func ribcage(m: Merge, xf: Transform3D, length: float, rng: RandomNumberGenerator) -> void:
    var sub: Merge = Merge.new()
    var ribs: int = 9
    for i in ribs + 3:
        var x: float = length * float(i) / (ribs + 2)
        ball(sub, Vector3(x, 0, 0), Vector3(length * 0.035, length * 0.045, length * 0.04), C_BONE, 6)
        beam(sub, Vector3(x, 0, 0), Vector3(x, length * 0.09, 0), length * 0.012, 0.0, 4, C_BONE)
    for i in ribs:
        var x: float = length * (0.15 + 0.6 * float(i) / ribs)
        var span: float = length * (0.16 + 0.1 * sin(PI * float(i) / ribs))
        for s in [-1.0, 1.0]:
            if rng.randf() < 0.12:
                continue  # a broken rib
            rib(sub, Vector3(x, 0, 0), Vector3(0, 0, s), span, span * 1.25, length * 0.016)
    var head: Vector3 = Vector3(length * 1.03, length * 0.02, 0)
    ball(sub, head, Vector3(length * 0.09, length * 0.07, length * 0.075), C_BONE, 8)
    box(sub, head + Vector3(length * 0.08, -length * 0.03, 0), Vector3(length * 0.11, length * 0.04, length * 0.07), C_BONE)
    for s in [-1.0, 1.0]:
        ball(sub, head + Vector3(length * 0.05, length * 0.01, s * length * 0.035), Vector3.ONE * length * 0.016, C_GLOW, 6)
        rib(sub, head + Vector3(0, length * 0.04, s * length * 0.04), Vector3(-0.5, 0, s * 0.8).normalized(), length * 0.12, length * 0.15, length * 0.012)
    append(m, sub, xf)


## A ring of jagged mountain/cliff silhouettes around the origin (one mesh), base far below.
static func mountain_ring(radius: float, min_h: float, max_h: float, base_y: float, seed_value: int, color: Color) -> Merge:
    var m: Merge = Merge.new()
    var noise: FastNoiseLite = FastNoiseLite.new()
    noise.seed = seed_value
    noise.frequency = 2.2
    var segs: int = 120
    var tops: Array[Vector3] = []
    for i in segs:
        var a: float = TAU * i / segs
        var dir: Vector3 = Vector3(cos(a), 0.0, sin(a))
        var n: float = noise.get_noise_2d(cos(a), sin(a))
        var spike: float = 1.0 - absf(noise.get_noise_2d(cos(a) * 3.0 + 9.0, sin(a) * 3.0))
        var h: float = lerpf(min_h, max_h, clampf(n * 0.5 + 0.5, 0.0, 1.0) * 0.6 + spike * spike * 0.4)
        var r: float = radius * (1.0 + noise.get_noise_2d(cos(a) * 5.0, sin(a) * 5.0 + 3.0) * 0.08)
        tops.append(dir * r + Vector3.UP * h)
    var v: PackedVector3Array = PackedVector3Array()
    var nn: PackedVector3Array = PackedVector3Array()
    for i in segs:
        var a: Vector3 = tops[i]
        var b: Vector3 = tops[(i + 1) % segs]
        var a0: Vector3 = Vector3(a.x * 1.02, base_y, a.z * 1.02)
        var b0: Vector3 = Vector3(b.x * 1.02, base_y, b.z * 1.02)
        var inward: Vector3 = -((a + b) * 0.5 * Vector3(1, 0, 1)).normalized()
        for tri: Array in [[a0, b0, a], [b0, b, a]]:
            v.append_array(PackedVector3Array(tri))
            var fn: Vector3 = (inward + Vector3.UP * 0.25).normalized()
            nn.append_array(PackedVector3Array([fn, fn, fn]))
    m.add_arrays(v, nn, PackedInt32Array(), Transform3D.IDENTITY, color)
    return m


# --- Kenney Castle Kit (CC0) -----------------------------------------------------------

## [mesh, transform-to-scene-root, aabb] for a Kenney piece, or [] if it isn't available.
static func kenney(piece: String) -> Array:
    if _kenney.has(piece):
        return _kenney[piece]
    var path: String = KENNEY_DIR + piece + ".glb"
    var result: Array = []
    if ResourceLoader.exists(path):
        var scene: PackedScene = load(path) as PackedScene
        if scene != null:
            var root: Node = scene.instantiate()
            for node: Node in root.find_children("*", "MeshInstance3D", true, false):
                var mi: MeshInstance3D = node as MeshInstance3D
                var xf: Transform3D = mi.transform
                var p: Node = mi.get_parent()
                while p != null and p != root and p is Node3D:
                    xf = (p as Node3D).transform * xf
                    p = p.get_parent()
                result = [mi.mesh, xf, xf * mi.mesh.get_aabb()]
                break
            root.free()
    _kenney[piece] = result
    return result


## A ruined Kenney hexagon tower (base, `floors` mid sections, a top or a broken stump) of
## width ≈ `scale` metres. Falls back to a procedural tower when the kit isn't imported.
static func kenney_tower(m: Merge, base: Vector3, scale: float, floors: int, broken: bool, rng: RandomNumberGenerator) -> void:
    var parts: Array[String] = ["tower-hexagon-base"]
    for i in floors:
        parts.append("tower-hexagon-mid")
    if not broken:
        parts.append("tower-hexagon-top")
        parts.append("tower-hexagon-roof")
    var y: float = 0.0
    var yaw: Basis = Basis(Vector3.UP, rng.randf() * TAU)
    for part: String in parts:
        var k: Array = kenney(part)
        if k.is_empty():
            gothic_tower(m, base, scale * 0.8, scale * (floors + 1.5), scale * 1.6, broken, rng)
            return
        var aabb: AABB = k[2]
        var xf: Transform3D = Transform3D(yaw * Basis.from_scale(Vector3.ONE * scale), base + Vector3.UP * (y - aabb.position.y) * scale) * (k[1] as Transform3D)
        m.add_mesh(k[0], xf, C_STONE)
        y += aabb.size.y
    var top: Vector3 = base + Vector3.UP * y * scale
    if broken:
        for i in 3:
            box(m, top + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.3, 0.3)) * scale, Vector3.ONE * scale * rng.randf_range(0.15, 0.3), C_DARK, Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf())))
    # Lit arrow slits so the tower reads at night.
    for i in floors:
        var a: float = rng.randf() * TAU
        var dir: Vector3 = Vector3(cos(a), 0, sin(a))
        lancet(m, base + Vector3.UP * (scale * (1.2 + i)) + dir * scale * 0.47, dir, scale * 0.07, scale * 0.28, C_GLOW if rng.randf() < 0.6 else C_GLOW_DIM)

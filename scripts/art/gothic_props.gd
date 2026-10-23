class_name GothicProps
extends RefCounted
## Modelled gothic props and hazard visuals (DEC-057). The meshes are original, built headless
## in Blender by tools/blender/build_props.py and exported to assets/models/props/<name>.glb as
## geometry + UVs only; each surface's material NAME is a role (stone, iron, bone, wood, wax,
## flame, glow, cloth, gold, dark, glass, blade, ...). This library maps roles to textured PBR
## materials (Poly Haven CC0 scans + the procedural bone/cloth/wax sets in
## assets/textures/gothic/), object-space triplanar so instanced, scaled and moving props never
## swim. Works in the Compatibility and Forward+ renderers.
##
## A script that animates a material (a telegraph glow, a fade) passes it in `roles`, e.g.
## `GothicProps.mesh("spike_plate_tile", {&"iron": _plate_material})`, so its existing code keeps
## driving the look. Every call has a fallback: when a GLB is missing `mesh()` returns null and
## callers keep their primitive.

const DIR: String = "res://assets/models/props/"

static var _raw: Dictionary = {}       # name -> ArrayMesh as imported (role-named surfaces)
static var _cooked: Dictionary = {}    # name -> ArrayMesh with the shared role materials
static var _materials: Dictionary = {} # role -> Material


static func available(asset: String) -> bool:
    return raw(asset) != null


## The imported mesh (one object per GLB), or null when the asset isn't there.
static func raw(asset: String) -> ArrayMesh:
    if _raw.has(asset):
        return _raw[asset]
    var result: ArrayMesh = null
    var path: String = DIR + asset + ".glb"
    if ResourceLoader.exists(path):
        var scene: PackedScene = load(path) as PackedScene
        if scene != null:
            var root: Node = scene.instantiate()
            for node: Node in root.find_children("*", "MeshInstance3D", true, false):
                var mi: MeshInstance3D = node as MeshInstance3D
                if mi.mesh is ArrayMesh:
                    result = mi.mesh as ArrayMesh
                    break
            root.free()
    _raw[asset] = result
    return result


## The role of surface `i` of an imported mesh.
static func role_of(m: Mesh, i: int) -> StringName:
    var mat: Material = m.surface_get_material(i)
    if mat == null:
        return &"stone"
    var n: String = mat.resource_name
    var dot: int = n.find(".")
    return StringName(n.substr(0, dot) if dot > 0 else n)


## A mesh for `asset` with every surface given its role's material, `roles` overriding some
## (role -> Material). Without overrides the result is shared and cached.
static func mesh(asset: String, roles: Dictionary = {}) -> ArrayMesh:
    if roles.is_empty() and _cooked.has(asset):
        return _cooked[asset]
    var src: ArrayMesh = raw(asset)
    if src == null:
        return null
    var out: ArrayMesh = src.duplicate() as ArrayMesh
    for i in out.get_surface_count():
        var role: StringName = role_of(src, i)
        out.surface_set_material(i, roles[role] if roles.has(role) else material(role))
    if roles.is_empty():
        _cooked[asset] = out
    return out


## A new mesh holding only the surfaces whose role is (or, `invert`, isn't) in `keep`, with
## materials applied. Used to split candle flames (no shadows) from their wax.
static func subset(asset: String, keep: Array, invert: bool = false, roles: Dictionary = {}) -> ArrayMesh:
    var src: ArrayMesh = raw(asset)
    if src == null:
        return null
    var out: ArrayMesh = ArrayMesh.new()
    for i in src.get_surface_count():
        var role: StringName = role_of(src, i)
        if (role in keep) == invert:
            continue
        out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(i))
        out.surface_set_material(out.get_surface_count() - 1, roles[role] if roles.has(role) else material(role))
    return out


## A copy of `asset` stretched along `axis` (0 x, 1 y, 2 z) to `length`, nine-slice style:
## vertices within `keep` metres of either end move rigidly with that end, the middle stretches.
## The source spans `src_min..src_max` on that axis. Detail at the ends (bevels, hubs, caps)
## keeps its size, so one modelled metre serves any span.
static func stretched(asset: String, axis: int, src_min: float, src_max: float, new_min: float, new_max: float, keep: float, roles: Dictionary = {}) -> ArrayMesh:
    var src: ArrayMesh = raw(asset)
    if src == null:
        return null
    var out: ArrayMesh = ArrayMesh.new()
    var lo_end: float = src_min + keep
    var hi_end: float = src_max - keep
    for i in src.get_surface_count():
        var arrays: Array = src.surface_get_arrays(i)
        var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        for k in verts.size():
            var v: Vector3 = verts[k]
            var c: float = v[axis]
            var n: float
            if c <= lo_end:
                n = new_min + (c - src_min)
            elif c >= hi_end:
                n = new_max - (src_max - c)
            else:
                var t: float = (c - lo_end) / maxf(hi_end - lo_end, 0.0001)
                n = lerpf(new_min + keep, new_max - keep, t)
            v[axis] = n
            verts[k] = v
        arrays[Mesh.ARRAY_VERTEX] = verts
        out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        var role: StringName = role_of(src, i)
        out.surface_set_material(out.get_surface_count() - 1, roles[role] if roles.has(role) else material(role))
    return out


## A MeshInstance3D of `asset` (null when it isn't available).
static func instance(asset: String, roles: Dictionary = {}, label: String = "") -> MeshInstance3D:
    var m: ArrayMesh = mesh(asset, roles)
    if m == null:
        return null
    var mi: MeshInstance3D = MeshInstance3D.new()
    mi.name = label if label != "" else asset
    mi.mesh = m
    return mi


## The shared material for a role.
static func material(role: StringName) -> Material:
    if _materials.has(role):
        return _materials[role]
    var m: Material
    match role:
        &"stone":
            m = GothicMaterials.standard("masonry", Color(0.66, 0.62, 0.62), 1.1, false)
        &"stone_dark":
            m = GothicMaterials.standard("masonry", Color(0.3, 0.28, 0.3), 1.1, false)
        &"stone_pale":
            m = GothicMaterials.standard("cracked", Color(0.82, 0.76, 0.68), 0.8, false)
        &"rock":
            m = GothicMaterials.standard("rubble", Color(0.55, 0.52, 0.52), 1.6, false)
        &"iron", &"blade":
            var iron: StandardMaterial3D = GothicMaterials.standard("rust_iron", Color(0.62, 0.52, 0.48), 0.45, false)
            if role == &"blade":
                iron.albedo_color = Color(0.95, 0.9, 0.88)
            m = iron
        &"gold":
            var gold: StandardMaterial3D = GothicMaterials.standard("rust_iron", Color(1.0, 0.74, 0.36), 0.35, false)
            gold.metallic = 1.0
            gold.metallic_texture = null
            gold.roughness = 0.6
            m = gold
        &"bone":
            m = GothicMaterials.standard("bone", Color(0.92, 0.86, 0.76), 0.3, false)
        &"wood":
            m = GothicMaterials.standard("wood", Color(0.72, 0.6, 0.52), 0.9, false)
        &"wax":
            var wax: StandardMaterial3D = GothicMaterials.standard("wax", Color(0.8, 0.72, 0.56), 0.25, false)
            wax.emission_enabled = true
            wax.emission = Color(0.42, 0.2, 0.06) * 0.12  # lit from within by the flame
            m = wax
        &"cloth":
            var cloth: StandardMaterial3D = GothicMaterials.standard("cloth", Color(0.5, 0.08, 0.09), 0.5, false)
            cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
            m = cloth
        &"flame":
            var fire: StandardMaterial3D = StandardMaterial3D.new()
            fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            fire.albedo_color = Color(1.0, 0.66, 0.26)
            fire.emission_enabled = true
            fire.emission = Color(1.0, 0.45, 0.12)
            fire.emission_energy_multiplier = 3.0
            m = fire
        &"glow":
            var glow: StandardMaterial3D = StandardMaterial3D.new()
            glow.albedo_color = Color(0.45, 0.02, 0.03)
            glow.roughness = 0.15
            glow.emission_enabled = true
            glow.emission = Color(1.0, 0.1, 0.06)
            glow.emission_energy_multiplier = 1.8
            m = glow
        &"glass":
            var glass: StandardMaterial3D = StandardMaterial3D.new()
            glass.albedo_color = Color(0.12, 0.2, 0.18)
            glass.roughness = 0.12
            glass.metallic = 0.4
            glass.emission_enabled = true
            glass.emission = Color(0.2, 0.5, 0.35) * 0.25
            m = glass
        &"blood":
            var blood: StandardMaterial3D = StandardMaterial3D.new()
            blood.albedo_color = Color(0.22, 0.0, 0.01)
            blood.roughness = 0.08
            blood.metallic = 0.2
            m = blood
        _:  # &"dark" and anything unknown: a deep cavity
            var dark: StandardMaterial3D = StandardMaterial3D.new()
            dark.albedo_color = Color(0.03, 0.02, 0.02)
            dark.roughness = 1.0
            m = dark
    _materials[role] = m
    return m

class_name GothicKit
extends RefCounted
## Modular gothic architecture for level geometry (DEC-056). Every collision box keeps its
## BoxShape3D exactly as before; only its LOOK is rebuilt from modelled kit pieces
## (assets/models/kit/gothic_kit.glb, made by tools/blender/build_gothic_kit.py):
## - walkable blocks: flagstone cells on top, a coping ring with a moulded cornice lip and a
##   corbel table round the edge, mitred corners, masonry courses (or a blind pointed arcade on
##   tall faces) down the sides, dressed quoins on the vertical corners, a rough underside slab;
## - walls: the same plus shallow buttresses; pillars: capital, clustered shaft, annulets and a
##   broken-off foot; climb walls: pale masonry with carved corbel-and-bone handholds;
## - movers: a riveted iron grate; collapsing / secret slabs: shattered stone over a glowing core;
##   gates: an iron portcullis.
## A box of ANY size is 9-sliced (corners fixed, edges and cells tiled and stretched to whole
## counts). Pieces are collected per room in a `Batch` and drawn as one MultiMeshInstance3D per
## (piece, material): a room costs a few dozen draw calls however many blocks it has. Seeded by
## position, so every build (and screenshot) matches. Textures: the CC0 Poly Haven scans,
## world-space triplanar (scripts/art/shaders/gothic_kit.gdshader).
##
## Footing contract (checked per piece, see `Batch.violations`): nothing rises more than
## TOP_TOLERANCE above a block's top; nothing reaches more than SIDE_TOLERANCE past its sides or
## bottom (cornice lips, buttresses). Handholds are exempt (they stick out to be grabbed).

const KIT_PATH: String = "res://assets/models/kit/gothic_kit.glb"
const SHADER_PATH: String = "res://scripts/art/shaders/gothic_kit.gdshader"
const TEX: String = "res://assets/textures/gothic/"
const TOP_TOLERANCE: float = 0.03
const SIDE_TOLERANCE: float = 0.16
## Authored sizes of the single-mesh pieces (scaled to the collision box).
const NOMINAL: Dictionary = {
    "grate": Vector3(3.0, 0.6, 3.0),
    "cracked": Vector3(2.6, 1.0, 2.6),
    "portcullis": Vector3(0.3, 5.0, 3.6),
}

## Pieces that cast shadows (the rest are covered by these).
const SHADOW_PIECES: Array[String] = ["base", "ashlar_a", "ashlar_b", "ashlar_c", "arcade", "pillar_capital",
    "pillar_shaft", "pillar_broken", "buttress"]

## Off: every block falls back to its textured box (GothicMaterials).
static var enabled: bool = true
static var _meshes: Dictionary = {}
static var _loaded: bool = false
static var _materials: Dictionary = {}
static var _textures: Dictionary = {}


## True when the kit GLB is imported and the kit is on.
static func available() -> bool:
    _load()
    return enabled and not _meshes.is_empty()


static func mesh(piece: String) -> Mesh:
    _load()
    return _meshes.get(piece) as Mesh


static func _load() -> void:
    if _loaded:
        return
    _loaded = true
    if not ResourceLoader.exists(KIT_PATH):
        push_warning("GothicKit: %s missing; level blocks stay boxes" % KIT_PATH)
        return
    var scene: PackedScene = load(KIT_PATH) as PackedScene
    if scene == null:
        return
    var root: Node = scene.instantiate()
    for node: Node in root.find_children("*", "MeshInstance3D", true, false):
        var mi: MeshInstance3D = node as MeshInstance3D
        if mi.mesh != null:
            _meshes[String(mi.name)] = mi.mesh
    root.free()


# --- Single pieces (movers, slabs, gates) ----------------------------------------------------

## One kit piece scaled to `size` (movers, collapsing / secret slabs, portcullis bars), with
## the material for `kind` in object space so it never swims as the body moves. Falls back to a
## textured box.
static func single(piece: String, size: Vector3, kind: StringName) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = "Kit " + piece
    var m: Mesh = mesh(piece) if enabled else null
    if m == null:
        var box: BoxMesh = BoxMesh.new()
        box.size = size
        node.mesh = box
        node.material_override = GothicMaterials.block(&"iron" if kind == &"bars" else kind)
        return node
    var nominal: Vector3 = NOMINAL.get(piece, Vector3.ONE)
    node.mesh = m
    node.scale = size / nominal
    node.material_override = material(kind, Color(0, 0, 0, 0), true, nominal.y * 0.5)
    return node


# --- Materials ----------------------------------------------------------------------------------

## The shared kit material for `kind` (the GothicMaterials kinds, plus floor_pale and bars),
## tinted toward a room palette. `single`: object-space mapping, top taken from `top_local`.
static func material(kind: StringName, room_tint: Color = Color(0, 0, 0, 0), single_mesh: bool = false, top_local: float = 0.0) -> ShaderMaterial:
    var key: String = "%s|%s|%s|%.3f" % [kind, room_tint.to_html(), single_mesh, top_local]
    if _materials.has(key):
        return _materials[key]
    var m: ShaderMaterial = ShaderMaterial.new()
    m.shader = load(SHADER_PATH)
    m.set_shader_parameter(&"use_custom", not single_mesh)
    m.set_shader_parameter(&"local_space", single_mesh)
    m.set_shader_parameter(&"top_local", top_local)
    _configure(m, kind, GothicMaterials._room_tint(room_tint))
    _materials[key] = m
    return m


static func _tex(set_name: String, map: String) -> Texture2D:
    var path: String = TEX + set_name + "_" + map + ".jpg"
    if not _textures.has(path):
        _textures[path] = load(path) if ResourceLoader.exists(path) else null
    return _textures[path]


static func _sets(m: ShaderMaterial, top_set: String, side_set: String) -> void:
    m.set_shader_parameter(&"top_albedo", _tex(top_set, "diff"))
    m.set_shader_parameter(&"top_normal", _tex(top_set, "nor"))
    m.set_shader_parameter(&"top_arm", _tex(top_set, "arm"))
    m.set_shader_parameter(&"side_albedo", _tex(side_set, "diff"))
    m.set_shader_parameter(&"side_normal", _tex(side_set, "nor"))
    m.set_shader_parameter(&"side_arm", _tex(side_set, "arm"))


static func _configure(m: ShaderMaterial, kind: StringName, tint: Color) -> void:
    match kind:
        &"floor_cobble":
            _sets(m, "cobble", "masonry")
            m.set_shader_parameter(&"top_scale", 2.8)
            m.set_shader_parameter(&"roughness_bias", -0.28)
            m.set_shader_parameter(&"top_tint", Color(0.62, 0.62, 0.66) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.5, 0.48, 0.5) * tint)
            m.set_shader_parameter(&"moss", 0.45)
        &"floor_blood":
            _sets(m, "flagstone", "masonry")
            m.set_shader_parameter(&"top_tint", Color(0.72, 0.66, 0.64) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.5, 0.44, 0.44) * tint)
            m.set_shader_parameter(&"blood", 1.0)
            m.set_shader_parameter(&"moss", 0.15)
        &"floor_pale":  # breakable causeway slabs: a shade lighter than the solid ends
            _sets(m, "flagstone", "masonry")
            m.set_shader_parameter(&"top_tint", Color(0.92, 0.88, 0.82) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.62, 0.58, 0.56) * tint)
            m.set_shader_parameter(&"moss", 0.1)
        &"pillar":
            _sets(m, "flagstone", "masonry")
            m.set_shader_parameter(&"top_tint", Color(0.7, 0.68, 0.68) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.54, 0.52, 0.54) * tint)
            m.set_shader_parameter(&"side_scale", 5.0)
            m.set_shader_parameter(&"side_fade", 9.0)
            m.set_shader_parameter(&"moss", 0.5)
        &"wall":
            _sets(m, "masonry", "masonry")
            m.set_shader_parameter(&"top_tint", Color(0.5, 0.48, 0.5) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.64, 0.61, 0.62) * tint)
            m.set_shader_parameter(&"side_fade", 10.0)
            m.set_shader_parameter(&"side_dark", 0.3)
            m.set_shader_parameter(&"moss", 0.55)
        &"ossuary":
            _sets(m, "flagstone", "cracked")
            m.set_shader_parameter(&"top_tint", Color(0.95, 0.86, 0.7) * tint)
            m.set_shader_parameter(&"side_tint", Color(1.0, 0.9, 0.74))
            m.set_shader_parameter(&"side_scale", 1.6)
            m.set_shader_parameter(&"moss", 0.1)
            m.set_shader_parameter(&"blood", 0.4)
        &"climb":
            _sets(m, "climb", "climb")
            m.set_shader_parameter(&"top_tint", Color(0.8, 0.74, 0.66) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.82, 0.74, 0.64))
            m.set_shader_parameter(&"side_scale", 4.5)
            m.set_shader_parameter(&"side_fade", 14.0)
            m.set_shader_parameter(&"side_dark", 0.45)
            m.set_shader_parameter(&"moss", 0.25)
            m.set_shader_parameter(&"bone_color", Color(0.9, 0.84, 0.7))
        &"iron", &"bars":
            _sets(m, "rust_iron", "rust_iron")
            m.set_shader_parameter(&"top_scale", 1.2)
            m.set_shader_parameter(&"side_scale", 1.0)
            m.set_shader_parameter(&"top_tint", Color(0.75, 0.62, 0.55))
            m.set_shader_parameter(&"side_tint", Color(0.62, 0.5, 0.44))
            m.set_shader_parameter(&"top_band", 0.12)
            m.set_shader_parameter(&"side_fade", 1.6 if kind == &"iron" else 9.0)
            m.set_shader_parameter(&"side_dark", 0.4)
            m.set_shader_parameter(&"cavity_dark", 0.4)
            m.set_shader_parameter(&"moss", 0.0)
            m.set_shader_parameter(&"variation", 0.1)
            m.set_shader_parameter(&"metal", 1.0)
            m.set_shader_parameter(&"emission_color", Color(1.0, 0.32, 0.08))
            m.set_shader_parameter(&"emission_glow", 0.9 if kind == &"iron" else 0.25)
        &"cracked":
            _sets(m, "cracked", "cracked")
            m.set_shader_parameter(&"top_scale", 1.6)
            m.set_shader_parameter(&"side_scale", 1.6)
            m.set_shader_parameter(&"top_tint", Color(0.66, 0.56, 0.52) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.55, 0.46, 0.44) * tint)
            m.set_shader_parameter(&"side_fade", 1.4)
            m.set_shader_parameter(&"side_dark", 0.35)
            m.set_shader_parameter(&"emission_color", Color(0.75, 0.1, 0.04))
            m.set_shader_parameter(&"emission_glow", 2.4)
            m.set_shader_parameter(&"moss", 0.0)
        &"breakable":
            _sets(m, "cracked", "cracked")
            m.set_shader_parameter(&"top_scale", 1.4)
            m.set_shader_parameter(&"side_scale", 1.4)
            m.set_shader_parameter(&"top_tint", Color(0.7, 0.6, 0.56))
            m.set_shader_parameter(&"side_tint", Color(0.58, 0.48, 0.46))
            m.set_shader_parameter(&"side_fade", 1.4)
            m.set_shader_parameter(&"emission_color", Color(0.95, 0.12, 0.05))
            m.set_shader_parameter(&"emission_glow", 2.4)
            m.set_shader_parameter(&"moss", 0.0)
        _:  # &"floor"
            _sets(m, "flagstone", "masonry")
            m.set_shader_parameter(&"top_tint", Color(0.76, 0.73, 0.66) * tint)
            m.set_shader_parameter(&"side_tint", Color(0.6, 0.57, 0.58) * tint)


# --- Batches ------------------------------------------------------------------------------------

## Collects kit pieces for many boxes (one room, one gate) and draws them as MultiMeshes.
class Batch:
    ## World offset of the node the batch is committed under (for the per-instance top height).
    var offset: Vector3 = Vector3.ZERO
    ## Room palette (gentle hue tint).
    var tint: Color = Color(0, 0, 0, 0)
    ## Footing-contract breaches ("label: piece ..."), filled while boxes are added.
    var violations: PackedStringArray = PackedStringArray()
    var instance_total: int = 0
    var boxes: Array[Dictionary] = []
    var _parts: Dictionary = {}  # "piece|kind" -> {piece, kind, xf: Array[Transform3D], custom: Array[Color]}
    var _box: AABB
    var _label: String = ""
    var _check: bool = true

    ## Covers the box (local centre, size) of material `kind` with kit pieces.
    func add_box(center: Vector3, size: Vector3, kind: StringName, label: String = "") -> void:
        boxes.append({"pos": center, "size": size, "kind": kind, "label": label})
        if not GothicKit.available():
            return
        _box = AABB(center - size * 0.5, size)
        _label = label
        GothicKit._assemble(self, center, size, kind)

    ## Carved handholds on the four faces of a climb box (same rows/columns ClimbWall used).
    func add_handholds(center: Vector3, size: Vector3, kind: StringName = &"climb") -> void:
        if not GothicKit.available():
            return
        _check = false
        for xf: Transform3D in GothicKit.handhold_transforms(size):
            put("handhold", kind, Transform3D(xf.basis, xf.origin + center), center.y + size.y * 0.5, 0.5)
        _check = true

    func put(piece: String, kind: StringName, xf: Transform3D, top_y: float, seed: float) -> void:
        # Blood-soaked floors share the floor batch: the blood is per instance (custom.b).
        var blood: float = 1.0 if kind == &"floor_blood" else 0.0
        if kind == &"floor_blood":
            kind = &"floor"
        var key: String = piece + "|" + String(kind)
        if not _parts.has(key):
            _parts[key] = {"piece": piece, "kind": kind, "xf": [] as Array[Transform3D], "custom": []}
        var part: Dictionary = _parts[key]
        (part["xf"] as Array[Transform3D]).append(xf)
        (part["custom"] as Array).append(Color(top_y + offset.y, seed, blood, 0.0))
        instance_total += 1
        if _check:
            var m: Mesh = GothicKit.mesh(piece)
            if m != null:
                var bb: AABB = xf * m.get_aabb()
                var lo: Vector3 = _box.position - Vector3.ONE * GothicKit.SIDE_TOLERANCE
                var hi: Vector3 = _box.end + Vector3(GothicKit.SIDE_TOLERANCE, GothicKit.TOP_TOLERANCE, GothicKit.SIDE_TOLERANCE)
                if bb.position.x < lo.x or bb.position.y < lo.y or bb.position.z < lo.z \
                        or bb.end.x > hi.x or bb.end.y > hi.y or bb.end.z > hi.z:
                    violations.append("%s: %s %s outside %s" % [_label, piece, bb, _box])

    ## Builds the MultiMeshes under `parent` (or textured boxes when the kit is unavailable).
    func commit(parent: Node3D, node_name: String = "Gothic kit") -> Node3D:
        var root: Node3D = Node3D.new()
        root.name = node_name
        if not GothicKit.available():
            for b: Dictionary in boxes:
                var mi: MeshInstance3D = MeshInstance3D.new()
                var box: BoxMesh = BoxMesh.new()
                box.size = b["size"]
                mi.mesh = box
                mi.position = b["pos"]
                mi.material_override = GothicMaterials.block(b["kind"], tint)
                root.add_child(mi)
            parent.add_child(root)
            return root
        for key: String in _parts:
            var part: Dictionary = _parts[key]
            var xfs: Array[Transform3D] = part["xf"]
            var custom: Array = part["custom"]
            var mm: MultiMesh = MultiMesh.new()
            mm.transform_format = MultiMesh.TRANSFORM_3D
            mm.use_custom_data = true
            mm.mesh = GothicKit.mesh(part["piece"])
            mm.instance_count = xfs.size()
            for i in xfs.size():
                mm.set_instance_transform(i, xfs[i])
                mm.set_instance_custom_data(i, custom[i])
            var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
            node.name = key.replace("|", " ")
            node.multimesh = mm
            node.material_override = GothicKit.material(part["kind"], tint)
            # Only the silhouette pieces cast shadows (the underside slab covers each block's
            # footprint): trims, paving and handholds would multiply draw calls per shadow split.
            if not GothicKit.SHADOW_PIECES.has(String(part["piece"])):
                node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            root.add_child(node)
        parent.add_child(root)
        return root


# --- Assembly -----------------------------------------------------------------------------------

## Rotation by `quarter` x 90 degrees about Y, then a scale in the piece's own axes.
static func _xf(quarter: int, local_scale: Vector3, pos: Vector3) -> Transform3D:
    return Transform3D(Basis(Vector3.UP, quarter * PI * 0.5) * Basis.from_scale(local_scale), pos)


## Local x/z scale for a piece turned by `quarter` that must span world extents ex (X), ez (Z).
static func _span(quarter: int, ex: float, ey: float, ez: float) -> Vector3:
    return Vector3(ex, ey, ez) if posmod(quarter, 2) == 0 else Vector3(ez, ey, ex)


static func _assemble(b: Batch, c: Vector3, s: Vector3, kind: StringName) -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = hash(Vector3i(roundi(c.x * 8.0), roundi(c.y * 8.0), roundi(c.z * 8.0))) ^ hash(kind)
    var seed: float = rng.randf()
    if kind == &"pillar":
        _pillar(b, c, s, kind, rng, seed)
    else:
        _masonry(b, c, s, kind, rng, seed)


static func _masonry(b: Batch, c: Vector3, s: Vector3, kind: StringName, rng: RandomNumberGenerator, seed: float) -> void:
    var top: float = c.y + s.y * 0.5
    var bottom: float = c.y - s.y * 0.5
    var w: float = s.x
    var d: float = s.z
    var h: float = s.y
    var m: float = minf(w, d)
    var cw: float = minf(0.5, m * 0.5) if m < 1.6 else 0.5  # coping ring width
    var hc: float = minf(0.6, h)                             # coping height
    var syc: float = hc / 0.6
    var k: float = cw / 0.5
    var hx: float = w * 0.5
    var hz: float = d * 0.5
    # Corners (outer faces at +x/+z in the piece's frame).
    var corners: Array = [[1.0, 1.0, 0], [1.0, -1.0, 1], [-1.0, -1.0, 2], [-1.0, 1.0, -1]]
    for cn: Array in corners:
        b.put("corner", kind, _xf(cn[2], Vector3(k, syc, k), Vector3(c.x + cn[0] * hx, top, c.z + cn[1] * hz)), top, seed)
    # Coping edges: [quarter, along X?, side sign].
    for e: Array in [[0, true, 1.0], [2, true, -1.0], [1, false, 1.0], [-1, false, -1.0]]:
        var along_x: bool = e[1]
        var inner: float = (w if along_x else d) - 2.0 * cw
        if inner < 0.02:
            continue
        var n: int = maxi(1, roundi(inner))
        var seg: float = inner / n
        for i in n:
            var t: float = -inner * 0.5 + seg * (i + 0.5)
            var pos: Vector3 = Vector3(c.x + t, top, c.z + e[2] * hz) if along_x else Vector3(c.x + e[2] * hx, top, c.z + t)
            var piece: String = "edge_b" if rng.randf() < 0.14 else "edge"
            b.put(piece, kind, _xf(e[0], Vector3(seg, syc, k), pos), top, seed)
    # Flagstone cells over the interior.
    var iw: float = w - 2.0 * cw
    var idp: float = d - 2.0 * cw
    if iw > 0.02 and idp > 0.02:
        var nx: int = maxi(1, roundi(iw / 2.0))  # 2 x 2 m paving cells
        var nz: int = maxi(1, roundi(idp / 2.0))
        var cx: float = iw / nx
        var cz: float = idp / nz
        var sy: float = minf(1.0, h / 0.22)
        for i in nx:
            for j in nz:
                var r: float = rng.randf()
                var piece: String = "top_a" if r < 0.42 else ("top_b" if r < 0.84 else "top_c")
                var q: int = rng.randi_range(0, 3)
                var pos: Vector3 = Vector3(c.x - iw * 0.5 + cx * (i + 0.5), top, c.z - idp * 0.5 + cz * (j + 0.5))
                b.put(piece, kind, _xf(q, _span(q, cx / 2.0, sy, cz / 2.0), pos), top, seed)
    # Sides below the coping.
    var ys: float = top - hc
    var hs: float = ys - bottom
    if hs > 0.05:
        var qx: float = minf(0.3, hx)
        var qz: float = minf(0.3, hz)
        var nq: int = maxi(1, roundi(hs))
        var qh: float = hs / nq
        for cn: Array in corners:
            for j in nq:
                var pos: Vector3 = Vector3(c.x + cn[0] * hx, ys - qh * j, c.z + cn[1] * hz)
                b.put("quoin", kind, _xf(cn[2], _span(cn[2], qx / 0.3, qh, qz / 0.3), pos), top, seed)
        for e: Array in [[0, true, 1.0], [2, true, -1.0], [1, false, 1.0], [-1, false, -1.0]]:
            var along_x: bool = e[1]
            var length: float = (w - 2.0 * qx) if along_x else (d - 2.0 * qz)
            if length < 0.05:
                continue
            var depth_scale: float = minf(1.0, ((hz if along_x else hx)) / 0.3)
            var arcade: bool = hs >= 3.0 and length >= 1.4 and kind != &"climb" and kind != &"ossuary"
            var ha: float = 0.0
            if arcade:
                ha = 3.0 if hs - 3.0 >= 0.6 else hs
            var np: int = maxi(1, roundi(length / 2.0))
            var pw: float = length / np
            var h_ash: float = hs - ha
            var ny: int = maxi(1, roundi(h_ash)) if h_ash > 0.05 else 0
            var rh: float = h_ash / ny if ny > 0 else 0.0
            for i in np:
                var t: float = -length * 0.5 + pw * (i + 0.5)
                var base: Vector3 = Vector3(c.x + t, 0.0, c.z + e[2] * hz) if along_x else Vector3(c.x + e[2] * hx, 0.0, c.z + t)
                if arcade:
                    b.put("arcade", kind, _xf(e[0], Vector3(pw / 2.0, ha / 3.0, depth_scale), Vector3(base.x, ys, base.z)), top, seed)
                for j in ny:
                    var r: float = rng.randf()
                    var piece: String = "ashlar_a" if r < 0.45 else ("ashlar_b" if r < 0.88 else "ashlar_c")
                    b.put(piece, kind, _xf(e[0], Vector3(pw / 2.0, rh, depth_scale), Vector3(base.x, ys - ha - rh * j, base.z)), top, seed)
            # Shallow buttresses along long wall faces.
            if kind == &"wall" and length >= 3.5 and hs >= 1.5:
                var count: int = int(length / 2.6)
                for i in count:
                    var t: float = -length * 0.5 + length * (i + 1) / (count + 1)
                    var pos: Vector3 = Vector3(c.x + t, ys, c.z + e[2] * hz) if along_x else Vector3(c.x + e[2] * hx, ys, c.z + t)
                    b.put("buttress", kind, _xf(e[0], Vector3(1.0, hs, 1.0), pos), top, seed)
    # Rough underside slab (also casts the block's full shadow).
    if h >= 0.4:
        b.put("base", kind, _xf(0, Vector3(w, 1.0, d), Vector3(c.x, bottom + 0.2, c.z)), top, seed)


static func _pillar(b: Batch, c: Vector3, s: Vector3, kind: StringName, rng: RandomNumberGenerator, seed: float) -> void:
    var top: float = c.y + s.y * 0.5
    var bottom: float = c.y - s.y * 0.5
    var hcap: float = minf(clampf(minf(s.x, s.z) * 0.45, 0.6, 1.2), s.y)
    var q: int = rng.randi_range(0, 3)
    b.put("pillar_capital", kind, _xf(q, _span(q, s.x, hcap, s.z), Vector3(c.x, top, c.z)), top, seed)
    var rem: float = s.y - hcap
    if rem <= 0.05:
        return
    var hb: float = minf(1.2, rem * 0.35) if rem > 1.5 else 0.0
    var hshaft: float = rem - hb
    var n: int = maxi(1, roundi(hshaft / 1.5))
    var seg: float = hshaft / n
    var y0: float = top - hcap
    for j in n:
        b.put("pillar_shaft", kind, _xf(0, Vector3(s.x, seg, s.z), Vector3(c.x, y0 - seg * j, c.z)), top, seed)
        if j > 0 and j % 2 == 1:
            b.put("pillar_band", kind, _xf(0, Vector3(s.x, 1.0, s.z), Vector3(c.x, y0 - seg * j, c.z)), top, seed)
    if hb > 0.0:
        q = rng.randi_range(0, 3)
        b.put("pillar_broken", kind, _xf(q, _span(q, s.x, hb, s.z), Vector3(c.x, bottom + hb, c.z)), top, seed)


## Handhold placements (local to the climb box's centre): staggered rows on all four faces,
## the same grid ClimbWall's bone studs used, so every climb route reads exactly as before.
static func handhold_transforms(size: Vector3) -> Array[Transform3D]:
    var out: Array[Transform3D] = []
    var rows: int = maxi(1, int(size.y / 0.6))
    for face: int in 4:
        var normal: Vector3 = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT][face]
        var quarter: int = [2, 0, -1, 1][face]
        var span: float = size.x if face < 2 else size.z
        var depth: float = size.z if face < 2 else size.x
        var columns: int = maxi(1, int(span / 0.9))
        var along: Vector3 = Vector3.RIGHT if face < 2 else Vector3.BACK
        for r in rows:
            for col in columns:
                var offset: float = (col + (0.25 if r % 2 == 0 else 0.75)) * span / columns - span * 0.5
                if absf(offset) > span * 0.5 - 0.25:
                    continue
                var at: Vector3 = along * offset + Vector3.UP * (-size.y * 0.5 + (r + 0.5) * size.y / rows) + normal * (depth * 0.5 + 0.02)
                out.append(_xf(quarter, Vector3.ONE, at))
    return out

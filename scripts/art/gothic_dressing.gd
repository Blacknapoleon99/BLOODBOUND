class_name GothicDressing
extends RefCounted
## Decor pass over a built open-course room (DEC-054). Visual only: no collision, nothing on a
## physics layer, never moves a platform, so the course validator and every route are untouched.
## - Crumbled undersides: a broken rock chunk hangs under every floating walkable block, so the
##   course reads as pieces of a ruined cathedral adrift in the void. Its depth is capped so it
##   never hangs into the headroom of anything below (another platform, a lift's path).
## - Props on some platform corners: skull piles, candle clusters, broken columns with a fallen
##   drum, bent iron fence stubs. Kept clear of the checkpoint, pickups, traps, altars, chests,
##   levers, the exit arch and any wall standing on the platform. One MultiMesh per prop part.
## Deterministic per room (seeded from its id), so screenshots and runs match.

const HEADROOM: float = 2.6     # clear space kept above any lower platform
const KEEP_CLEAR: float = 1.7   # props stay this far (x/z) from gameplay objects
const PROP_CHANCE: float = 0.5

## Modelled props (assets/models/props/, DEC-057); the old procedural parts remain the
## fallback when a model is missing.
const MODELS: Array[String] = ["skull_pile_a", "skull_pile_b", "candles_a", "candles_b", "candelabra", "column_tall",
        "column_short", "column_drum", "gravestone_a", "gravestone_b", "sarcophagus", "fence_section", "fence_bent", "iron_cage"]
const FLAMED: Array[String] = ["candles_a", "candles_b", "candelabra"]
const MAX_LIGHTS: int = 4  # candle lights per room

static var _meshes: Dictionary = {}


static func dress(room: LevelSection) -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = hash(String(room.id)) ^ 0x5eed
    var blocks: Array[Dictionary] = room.dress_blocks
    var rubble: Node3D = Node3D.new()
    rubble.name = "Rubble undersides"
    room.add_child(rubble)
    var parts: Dictionary = {}  # part name -> Array[Transform3D]
    var clear: Array[Vector3] = _keep_clear(room)
    for i in blocks.size():
        var b: Dictionary = blocks[i]
        if not bool(b["walkable"]):
            continue
        _hang_rubble(rubble, b, i, blocks, rng, room._palette)
        if rng.randf() < PROP_CHANCE:
            _place_props(b, i, blocks, clear, rng, parts)
    var lights: int = 0
    for part: String in parts:
        var list: Array = parts[part]
        if list.is_empty():
            continue
        if part == "light":
            for xf: Transform3D in list:
                if lights >= MAX_LIGHTS:
                    break
                room.add_child(GothicEnvironment.torch_light(xf.origin, 1.4, 4.5))
                lights += 1
            continue
        if part in MODELS and GothicProps.available(part):
            # Modelled prop (DEC-057): its flames go in a second, shadowless MultiMesh.
            room.add_child(_multi(GothicProps.subset(part, [&"flame"], true), list, "Props: " + part, true))
            if part in FLAMED:
                room.add_child(_multi(GothicProps.subset(part, [&"flame"]), list, "Props: " + part + " flames", false))
            continue
        room.add_child(_multi(_mesh(part), list, "Props: " + part, part != "flame"))


# --- Rubble -------------------------------------------------------------------------------

static func _hang_rubble(parent: Node3D, b: Dictionary, index: int, blocks: Array[Dictionary], rng: RandomNumberGenerator, tint: Color) -> void:
    var pos: Vector3 = b["pos"]
    var size: Vector3 = b["size"]
    var bottom: float = pos.y - size.y * 0.5
    var span: float = minf(size.x, size.z)
    var depth: float = clampf(span * 0.55 + 0.8, 1.0, 4.5)
    if b["kind"] == &"pillar":
        depth = clampf(span * 1.2, 1.0, 3.0)
    for j in blocks.size():
        if j == index:
            continue
        var o: Dictionary = blocks[j]
        var op: Vector3 = o["pos"]
        var os: Vector3 = o["size"]
        var o_top: float = op.y + os.y * 0.5
        var o_bottom: float = op.y - os.y * 0.5
        if o_bottom >= bottom - 0.01:
            continue  # wholly above this block's underside
        if absf(op.x - pos.x) * 2.0 < os.x + size.x * 0.9 and absf(op.z - pos.z) * 2.0 < os.z + size.z * 0.9:
            if o_top > bottom + 0.01:
                return  # a wall or climb wall runs down through here: no rubble
            depth = minf(depth, bottom - o_top - HEADROOM)
    if depth < 0.6:
        return
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = "Rubble"
    node.mesh = _rubble_mesh(size.x * 0.5, size.z * 0.5, depth, rng)
    node.material_override = GothicMaterials.block(&"rubble", tint)
    node.position = Vector3(pos.x, bottom + 0.02, pos.z)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # it only hangs in the void
    parent.add_child(node)


## A faceted, roughly conical rock chunk: its top ring matches (just inside) the block's
## footprint, it tapers to a crooked point `depth` below. Flat-shaded triangles.
static func _rubble_mesh(hx: float, hz: float, depth: float, rng: RandomNumberGenerator) -> ArrayMesh:
    var segs: int = 18
    var rings: int = 9
    var pts: Array = []
    var tip: Vector3 = Vector3(rng.randf_range(-0.25, 0.25) * hx, -depth, rng.randf_range(-0.25, 0.25) * hz)
    var strata_phase: float = rng.randf() * TAU
    for r in rings:
        var t: float = float(r) / rings
        # Strata (DEC-057): alternate ledges and undercuts so the chunk reads as layered rock.
        var ledge: float = 1.0 + (0.09 if r % 2 == 1 else -0.05) * (1.0 - t) * (0.6 + 0.4 * sin(strata_phase + r))
        var shrink: float = pow(1.0 - t, 0.8) * (0.97 if r == 0 else ledge)
        var ring: Array = []
        for k in segs:
            var a: float = TAU * (k + (0.0 if r == 0 else rng.randf_range(-0.3, 0.3))) / segs
            var c: float = cos(a)
            var s: float = sin(a)
            var rx: float = signf(c) * pow(absf(c), 0.45)
            var rz: float = signf(s) * pow(absf(s), 0.45)
            var jitter: float = 1.0 if r == 0 else rng.randf_range(0.7, 1.22)
            var y: float = 0.0 if r == 0 else -depth * t + rng.randf_range(-0.3, 0.3) * depth / rings
            var centre: Vector3 = tip * t
            ring.append(Vector3(centre.x + rx * hx * shrink * jitter, y, centre.z + rz * hz * shrink * jitter))
        pts.append(ring)
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var core: Vector3 = Vector3(0.0, -depth * 0.35, 0.0)
    for r in rings:
        var upper: Array = pts[r]
        for k in segs:
            var k2: int = (k + 1) % segs
            if r < rings - 1:
                var lower: Array = pts[r + 1]
                _tri(st, upper[k], upper[k2], lower[k2], core)
                _tri(st, upper[k], lower[k2], lower[k], core)
            else:
                _tri(st, upper[k], upper[k2], tip, core)
    # Stalactite drips of rock hanging off the lower rings.
    for k in rng.randi_range(2, 4):
        var ring: Array = pts[rng.randi_range(2, rings - 2)]
        var j: int = rng.randi() % segs
        var root_a: Vector3 = ring[j]
        var root_b: Vector3 = ring[(j + 1) % segs]
        var root_c: Vector3 = (root_a + root_b) * 0.5 * 0.82
        var drip: Vector3 = (root_a + root_b) * 0.5 * 0.9 + Vector3(0.0, -rng.randf_range(0.4, 1.1) * minf(depth, 2.5) * 0.45, 0.0)
        drip.y = maxf(drip.y, -depth * 0.97)  # never below the headroom-capped tip
        var mid: Vector3 = (root_a + root_b + root_c + drip) * 0.25
        _tri(st, root_a, root_b, drip, mid)
        _tri(st, root_b, root_c, drip, mid)
        _tri(st, root_c, root_a, drip, mid)
    # Cap the top (hidden under the block, but closes the mesh for shadows/AO).
    var top_ring: Array = pts[0]
    for k in segs:
        _tri(st, Vector3.ZERO, top_ring[(k + 1) % segs], top_ring[k], Vector3(0.0, -1.0, 0.0))
    return st.commit()


## One flat-shaded triangle facing away from `inside` (Godot front faces wind clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
    var n: Vector3 = (b - a).cross(c - a)
    if n.length_squared() < 1e-10:
        return
    n = n.normalized()
    var centroid: Vector3 = (a + b + c) / 3.0
    if n.dot(centroid - inside) < 0.0:
        n = -n
        var swap: Vector3 = b
        b = c
        c = swap
    # Counter-clockwise about the outward normal -> emit reversed for clockwise front faces.
    st.set_normal(n)
    st.add_vertex(a)
    st.set_normal(n)
    st.add_vertex(c)
    st.set_normal(n)
    st.add_vertex(b)


# --- Props --------------------------------------------------------------------------------

static func _keep_clear(room: LevelSection) -> Array[Vector3]:
    var out: Array[Vector3] = []
    var groups: Array = [room.pickups, room.traps, room.altars, room.caches, room.shortcuts, room.slabs, room.secrets, room.enemies, room.climb_walls]
    for g: Array in groups:
        for n: Variant in g:
            if n is Node3D and is_instance_valid(n):
                out.append((n as Node3D).position)
    if room.checkpoint:
        out.append(room.checkpoint.position)
    out.append(Vector3(room.gx(2.4), 0.0, 0.0))  # spawn
    out.append(Vector3(room.gx(room.width - 1.0), 0.0, -3.7))  # exit arch
    out.append(Vector3(room.gx(room.width - 1.0), 0.0, 3.7))
    for c: Node in room.get_children():
        if c is Label3D or c is Ambush:
            out.append((c as Node3D).position)
    return out


static func _place_props(b: Dictionary, index: int, blocks: Array[Dictionary], clear: Array[Vector3], rng: RandomNumberGenerator, parts: Dictionary) -> void:
    var pos: Vector3 = b["pos"]
    var size: Vector3 = b["size"]
    if size.x < 3.0 or size.z < 3.0:
        return
    var top: float = pos.y + size.y * 0.5
    var corners: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
    corners.shuffle()
    for corner: Vector2 in corners:
        var inset: float = 0.6
        var at: Vector3 = Vector3(pos.x + corner.x * (size.x * 0.5 - inset), top, pos.z + corner.y * (size.z * 0.5 - inset))
        if not _free(at, index, blocks, clear):
            continue
        if _modelled():
            _place_model(at, corner, size, rng, parts)
            return
        var roll: float = rng.randf()
        if roll < 0.32:
            _skull_pile(at, rng, parts)
        elif roll < 0.66:
            _candles(at, rng, parts)
        elif roll < 0.85 and size.x >= 4.0 and size.z >= 4.0:
            _column(at, corner, rng, parts)
        else:
            _fence(at, corner, size, rng, parts)
        return


static func _free(at: Vector3, index: int, blocks: Array[Dictionary], clear: Array[Vector3]) -> bool:
    for p: Vector3 in clear:
        if Vector2(p.x - at.x, p.z - at.z).length() < KEEP_CLEAR and absf(p.y - at.y) < 3.0:
            return false
    for j in blocks.size():
        if j == index:
            continue
        var o: Dictionary = blocks[j]
        var op: Vector3 = o["pos"]
        var os: Vector3 = o["size"] * 0.5 + Vector3(0.6, 0.0, 0.6)
        var probe: Vector3 = at + Vector3(0.0, 0.5, 0.0)
        if absf(probe.x - op.x) < os.x and absf(probe.z - op.z) < os.z and probe.y > op.y - os.y - 0.1 and probe.y < op.y + os.y + 1.5:
            return false  # something stands on or hangs just over this corner
    return true


static func _add(parts: Dictionary, part: String, xf: Transform3D) -> void:
    if not parts.has(part):
        parts[part] = []
    (parts[part] as Array).append(xf)


static func _multi(m: Mesh, list: Array, label: String, shadows: bool) -> MultiMeshInstance3D:
    var multi: MultiMesh = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = m
    multi.instance_count = list.size()
    for k in list.size():
        multi.set_instance_transform(k, list[k])
    var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = multi
    if not shadows:
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return node


static func _modelled() -> bool:
    return GothicProps.available("skull_pile_a")


## The modelled corner props (DEC-057).
static func _place_model(at: Vector3, corner: Vector2, size: Vector3, rng: RandomNumberGenerator, parts: Dictionary) -> void:
    var inward: Vector3 = Vector3(-corner.x, 0.0, -corner.y).normalized()
    var face: float = atan2(inward.x, inward.z)
    var roll: float = rng.randf()
    if roll < 0.24:
        var s: float = rng.randf_range(0.9, 1.2)
        _add(parts, "skull_pile_a" if rng.randf() < 0.5 else "skull_pile_b", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), at))
    elif roll < 0.48:
        _add(parts, "candles_a" if rng.randf() < 0.5 else "candles_b", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at))
        if rng.randf() < 0.6:
            _add(parts, "light", Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.7, 0.0)))
    elif roll < 0.58:
        _add(parts, "candelabra", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at))
        _add(parts, "light", Transform3D(Basis.IDENTITY, at + Vector3(0.0, 1.5, 0.0)))
    elif roll < 0.74 and size.x >= 4.0 and size.z >= 4.0:
        if rng.randf() < 0.2 and size.x >= 5.0 and size.z >= 5.0:
            # A sarcophagus along the platform edge, a little in from the corner.
            var along: Basis = Basis(Vector3.UP, face + PI * 0.5 + rng.randf_range(-0.15, 0.15))
            _add(parts, "sarcophagus", Transform3D(along, at + inward * 0.7))
            return
        var tall: bool = rng.randf() < 0.55
        _add(parts, "column_tall" if tall else "column_short", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.03, 0.03)), at))
        var lying: Basis = Basis(Vector3.UP, face + rng.randf_range(0.8, 2.2))
        _add(parts, "column_drum", Transform3D(lying.scaled(Vector3(rng.randf_range(0.6, 0.9), 1.0, 1.0)), at + inward * 1.1))
    elif roll < 0.86:
        # A few headstones, leaning, stepping in from the corner.
        for k in rng.randi_range(1, 3):
            var off: Vector3 = Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3)) + inward * (k * 0.55)
            var lean: Basis = Basis(Vector3.UP, face + rng.randf_range(-0.35, 0.35)) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.08)) * Basis(Vector3.FORWARD, rng.randf_range(-0.08, 0.08))
            _add(parts, "gravestone_a" if rng.randf() < 0.65 else "gravestone_b", Transform3D(lean.scaled(Vector3.ONE * rng.randf_range(0.85, 1.1)), at + off + Vector3.DOWN * 0.03))
    else:
        # A run of wrought-iron railing along the longer outer edge.
        var along_x: bool = size.x >= size.z
        var dir: Vector3 = Vector3(-corner.x, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, -corner.y)
        var start: Vector3 = at + (Vector3(0.0, 0.0, corner.y * 0.3) if along_x else Vector3(corner.x * 0.3, 0.0, 0.0))
        var room_len: float = (size.x if along_x else size.z) - 1.6
        var sections: int = clampi(rng.randi_range(1, 3), 1, maxi(1, int(room_len / 1.2)))
        var yaw: float = atan2(-dir.z, dir.x)  # local +X along `dir`
        for k in sections:
            var bent: bool = rng.randf() < 0.35
            _add(parts, "fence_bent" if bent else "fence_section", Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.03, 0.03)), start + dir * (k * 1.2)))


static func _skull_pile(at: Vector3, rng: RandomNumberGenerator, parts: Dictionary) -> void:
    var count: int = rng.randi_range(4, 8)
    for k in count:
        var off: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.42)
        var lift: float = 0.0 if off.length() > 0.22 or k < 3 else rng.randf_range(0.1, 0.17)
        var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.25))
        var s: float = rng.randf_range(0.85, 1.15)
        _add(parts, "skull", Transform3D(basis.scaled(Vector3.ONE * s), at + Vector3(off.x, lift, off.y)))
    for k in rng.randi_range(2, 4):
        var off2: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.2, 0.55)
        var basis2: Basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5)
        _add(parts, "bone", Transform3D(basis2, at + Vector3(off2.x, 0.03, off2.y)))


static func _candles(at: Vector3, rng: RandomNumberGenerator, parts: Dictionary) -> void:
    for k in rng.randi_range(3, 6):
        var off: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.38)
        var h: float = rng.randf_range(0.12, 0.5)
        var r: float = rng.randf_range(0.8, 1.3)
        var base: Vector3 = at + Vector3(off.x, 0.0, off.y)
        _add(parts, "candle", Transform3D(Basis.from_scale(Vector3(r, h, r)), base + Vector3(0.0, h * 0.5, 0.0)))
        _add(parts, "flame", Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.85, 1.2)), base + Vector3(0.0, h + 0.055, 0.0)))
    _add(parts, "wax", Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.0)), at + Vector3(0.0, 0.01, 0.0)))


static func _column(at: Vector3, corner: Vector2, rng: RandomNumberGenerator, parts: Dictionary) -> void:
    var h: float = rng.randf_range(0.7, 2.2)
    _add(parts, "plinth", Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.12, 0.0)))
    var tilt: Basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05))
    _add(parts, "column", Transform3D(tilt.scaled(Vector3(1.0, h, 1.0)), at + Vector3(0.0, 0.24 + h * 0.5, 0.0)))
    # A fallen drum beside it, lying toward the platform's inside.
    var inward: Vector3 = Vector3(-corner.x, 0.0, -corner.y).normalized()
    var lying: Basis = Basis(Vector3.UP, atan2(inward.x, inward.z) + rng.randf_range(0.8, 2.2)) * Basis(Vector3.RIGHT, PI * 0.5)
    _add(parts, "column", Transform3D(lying.scaled(Vector3(1.0, 0.55, 1.0)), at + inward * 1.0 + Vector3(0.0, 0.34, 0.0)))


static func _fence(at: Vector3, corner: Vector2, size: Vector3, rng: RandomNumberGenerator, parts: Dictionary) -> void:
    # Along the longer outer edge from the corner: a stretch of bent spear-topped railing.
    var along_x: bool = size.x >= size.z
    var dir: Vector3 = Vector3(-corner.x, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, -corner.y)
    var start: Vector3 = at + (Vector3(0.0, 0.0, corner.y * 0.3) if along_x else Vector3(corner.x * 0.3, 0.0, 0.0))
    var length: float = rng.randf_range(1.2, minf(2.4, (size.x if along_x else size.z) - 1.6))
    var posts: int = int(length / 0.24)
    for k in posts:
        if rng.randf() < 0.12:
            continue  # a missing bar
        var h: float = rng.randf_range(0.7, 0.95) * (1.0 - 0.35 * float(k) / posts)
        var bend: Basis = Basis(Vector3.RIGHT if not along_x else Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
        var base: Vector3 = start + dir * (k * 0.24)
        _add(parts, "post", Transform3D(bend.scaled(Vector3(1.0, h, 1.0)), base + bend * Vector3(0.0, h * 0.5, 0.0)))
        _add(parts, "tip", Transform3D(bend, base + bend * Vector3(0.0, h + 0.07, 0.0)))
    var rail_len: float = posts * 0.24
    var rail_basis: Basis = Basis(Vector3.UP, 0.0 if along_x else PI * 0.5).scaled(Vector3(rail_len, 1.0, 1.0))
    _add(parts, "rail", Transform3D(rail_basis, start + dir * (rail_len * 0.5 - 0.12) + Vector3(0.0, 0.18, 0.0)))
    _add(parts, "rail", Transform3D(rail_basis, start + dir * (rail_len * 0.5 - 0.12) + Vector3(0.0, 0.5, 0.0)))


# --- Exit arch ----------------------------------------------------------------------------

## The goal over every exit pad: a carved pointed (gothic) arch spanning z -3.7..3.7, with stepped
## plinths, capitals, a skull keystone and a blood-red glowing inner moulding plus a red light,
## so the exit reads from anywhere on the course. Local origin at the pad top (y = 0), arch
## plane at x = 0. Visual only.
static func exit_arch() -> Node3D:
    var arch: Node3D = Node3D.new()
    var model: MeshInstance3D = GothicProps.instance("exit_arch", {}, "Exit arch")
    if model != null:
        # Modelled arch (DEC-057): clustered piers on stepped plinths, leaf capitals, a
        # three-order archivolt with crockets and a finial, a skull keystone, a blood moulding.
        arch.add_child(model)
        var lamp: OmniLight3D = GothicEnvironment.torch_light(Vector3(-0.6, 3.2, 0.0), 2.6, 7.5)
        lamp.light_color = Color(1.0, 0.16, 0.08)
        arch.add_child(lamp)
        return arch
    var stone: ShaderMaterial = GothicMaterials.block(&"column")
    var glow: StandardMaterial3D = StandardMaterial3D.new()
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.albedo_color = Color(0.9, 0.1, 0.05)
    glow.emission_enabled = true
    glow.emission = Color(1.0, 0.12, 0.05)
    glow.emission_energy_multiplier = 2.2
    const HALF: float = 3.7
    const SPRING: float = 4.6  # height where the arch springs from the piers
    const R: float = 4.7       # arc radius (centres 1.0 m past the axis: a pointed arch)
    for side: float in [-1.0, 1.0]:
        var z: float = side * HALF
        _arch_box(arch, Vector3(0.0, 0.3, z), Vector3(1.3, 0.6, 1.3), Basis.IDENTITY, stone)
        _arch_box(arch, Vector3(0.0, 0.75, z), Vector3(1.05, 0.3, 1.05), Basis.IDENTITY, stone)
        _arch_box(arch, Vector3(0.0, 2.6, z), Vector3(0.8, 3.4, 0.8), Basis.IDENTITY, stone)
        _arch_box(arch, Vector3(0.0, 4.4, z), Vector3(1.1, 0.4, 1.1), Basis.IDENTITY, stone)
        # Inner glowing groove down the pier's inside face.
        _arch_box(arch, Vector3(0.0, 2.6, z - side * 0.41), Vector3(0.22, 3.2, 0.04), Basis.IDENTITY, glow)
        # Arc: from the springing point up to the apex, centre on the far side of the axis.
        var centre: Vector2 = Vector2(-side * (R - HALF), SPRING)  # (z, y)
        var apex_angle: float = acos((R - HALF) / R)  # where the arc crosses the axis (z = 0)
        var segs: int = 7
        var prev: Vector2 = Vector2(z, SPRING)
        for k in range(1, segs + 1):
            var t: float = float(k) / segs
            var ang: float = lerpf(0.0, apex_angle, t)
            var pt: Vector2 = centre + Vector2(side * R * cos(ang), R * sin(ang))
            _arch_segment(arch, prev, pt, 0.75, 0.8, stone, Vector3.ZERO)
            # The glowing inner moulding, a little inside the stone.
            var inner_prev: Vector2 = centre + (prev - centre).normalized() * (R - 0.42)
            var inner_pt: Vector2 = centre + (pt - centre).normalized() * (R - 0.42)
            _arch_segment(arch, inner_prev, inner_pt, 0.08, 0.24, glow, Vector3.ZERO)
            prev = pt
    # Skull keystone at the apex.
    var apex_y: float = SPRING + sqrt(R * R - (R - HALF) * (R - HALF))
    var skull: MeshInstance3D = MeshInstance3D.new()
    skull.name = "Keystone skull"
    skull.mesh = _mesh("skull")
    skull.scale = Vector3.ONE * 3.2
    skull.rotation.y = -PI * 0.5  # faces the oncoming player (-X)
    skull.position = Vector3(-0.35, apex_y - 0.55, 0.0)
    arch.add_child(skull)
    var light: OmniLight3D = GothicEnvironment.torch_light(Vector3(-0.6, 3.2, 0.0), 2.6, 7.5)
    light.light_color = Color(1.0, 0.16, 0.08)
    arch.add_child(light)
    return arch


static func _arch_box(parent: Node3D, at: Vector3, size: Vector3, basis: Basis, mat: Material) -> void:
    var node: MeshInstance3D = MeshInstance3D.new()
    var box: BoxMesh = BoxMesh.new()
    box.size = size
    node.mesh = box
    node.material_override = mat
    node.transform = Transform3D(basis, at)
    parent.add_child(node)


## One voussoir from `a` to `b` (points in the arch plane: x = z, y = y), `thick` radially.
static func _arch_segment(parent: Node3D, a: Vector2, b: Vector2, thick: float, depth: float, mat: Material, offset: Vector3) -> void:
    var d: Vector2 = b - a
    var mid: Vector2 = (a + b) * 0.5
    var ang: float = atan2(d.y, d.x)  # angle of the chord in the z/y plane
    var basis: Basis = Basis(Vector3.RIGHT, -ang)  # box's Z axis along the chord
    _arch_box(parent, Vector3(0.0, mid.y, mid.x) + offset, Vector3(depth, thick, d.length() + 0.12), basis, mat)


# --- Prop meshes --------------------------------------------------------------------------

static func _mesh(part: String) -> Mesh:
    if _meshes.has(part):
        return _meshes[part]
    var m: Mesh
    match part:
        "skull":
            m = _skull_mesh()
        "bone":
            var c: CapsuleMesh = CapsuleMesh.new()
            c.radius = 0.03
            c.height = 0.42
            c.radial_segments = 6
            c.rings = 2
            c.material = _bone()
            m = c
        "candle":
            var c: CylinderMesh = CylinderMesh.new()
            c.top_radius = 0.045
            c.bottom_radius = 0.05
            c.height = 1.0
            c.radial_segments = 8
            c.rings = 1
            var wax: StandardMaterial3D = StandardMaterial3D.new()
            wax.albedo_color = Color(0.6, 0.54, 0.42)
            wax.roughness = 0.45
            wax.emission_enabled = true
            wax.emission = Color(0.35, 0.18, 0.05) * 0.25  # lit from the flame above
            c.material = wax
            m = c
        "wax":
            var c: CylinderMesh = CylinderMesh.new()
            c.top_radius = 0.38
            c.bottom_radius = 0.42
            c.height = 0.02
            c.radial_segments = 12
            c.rings = 1
            var puddle: StandardMaterial3D = StandardMaterial3D.new()
            puddle.albedo_color = Color(0.32, 0.27, 0.2)
            puddle.roughness = 0.35
            c.material = puddle
            m = c
        "flame":
            var s: SphereMesh = SphereMesh.new()
            s.radius = 0.035
            s.height = 0.13
            s.radial_segments = 6
            s.rings = 4
            var fire: StandardMaterial3D = StandardMaterial3D.new()
            fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            fire.albedo_color = Color(1.0, 0.62, 0.22)
            fire.emission_enabled = true
            fire.emission = Color(1.0, 0.45, 0.12)
            fire.emission_energy_multiplier = 3.0
            s.material = fire
            m = s
        "plinth":
            var b: BoxMesh = BoxMesh.new()
            b.size = Vector3(1.0, 0.24, 1.0)
            b.material = GothicMaterials.block(&"column")
            m = b
        "column":
            var c: CylinderMesh = CylinderMesh.new()
            c.top_radius = 0.36
            c.bottom_radius = 0.4
            c.height = 1.0
            c.radial_segments = 10
            c.rings = 1
            c.material = GothicMaterials.block(&"column")
            m = c
        "post":
            var c: CylinderMesh = CylinderMesh.new()
            c.top_radius = 0.022
            c.bottom_radius = 0.026
            c.height = 1.0
            c.radial_segments = 6
            c.rings = 1
            c.material = GothicMaterials.block(&"rust")
            m = c
        "tip":
            var c: CylinderMesh = CylinderMesh.new()
            c.top_radius = 0.0
            c.bottom_radius = 0.05
            c.height = 0.15
            c.radial_segments = 4
            c.rings = 1
            c.material = GothicMaterials.block(&"rust")
            m = c
        _:  # "rail"
            var b: BoxMesh = BoxMesh.new()
            b.size = Vector3(1.0, 0.04, 0.035)
            b.material = GothicMaterials.block(&"rust")
            m = b
    _meshes[part] = m
    return m


static func _bone() -> StandardMaterial3D:
    var bone: StandardMaterial3D = StandardMaterial3D.new()
    bone.albedo_color = Color(0.5, 0.45, 0.36)
    bone.roughness = 0.75
    return bone


## A low-poly skull (about 0.24 m long): cranium, face, jaw; dark eye sockets and nose as a
## second surface.
static func _skull_mesh() -> ArrayMesh:
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.5
    sphere.height = 1.0
    sphere.radial_segments = 12
    sphere.rings = 6
    var box: BoxMesh = BoxMesh.new()
    box.size = Vector3.ONE
    var mesh: ArrayMesh = ArrayMesh.new()
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(0.19, 0.17, 0.23)), Vector3(0.0, 0.115, -0.01)))
    st.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(0.15, 0.12, 0.12)), Vector3(0.0, 0.075, 0.075)))
    st.append_from(box, 0, Transform3D(Basis.from_scale(Vector3(0.1, 0.035, 0.08)), Vector3(0.0, 0.02, 0.095)))
    st.append_from(box, 0, Transform3D(Basis.from_scale(Vector3(0.09, 0.02, 0.02)), Vector3(0.0, 0.042, 0.13)))  # teeth
    st.commit(mesh)
    mesh.surface_set_material(0, _bone())
    var holes: SurfaceTool = SurfaceTool.new()
    holes.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side: float in [-1.0, 1.0]:
        holes.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(0.052, 0.046, 0.04)), Vector3(side * 0.04, 0.09, 0.125)))
    holes.append_from(sphere, 0, Transform3D(Basis.from_scale(Vector3(0.022, 0.03, 0.02)), Vector3(0.0, 0.058, 0.138)))
    holes.commit(mesh)
    var dark: StandardMaterial3D = StandardMaterial3D.new()
    dark.albedo_color = Color(0.04, 0.025, 0.02)
    dark.roughness = 1.0
    mesh.surface_set_material(1, dark)
    return mesh

class_name Backdrop3D
extends Node3D
## The background world around one open 3D course (DEC-055): decor only, no collision, never
## inside the play space. Rooms float in a void; this fills it, gothic-SM64 style, in bands:
##
##   NEAR  (10-40 m past the course edge, tops below the course): broken clustered pillars
##         rising out of the abyss, loose masonry, and gibbet cages swinging on long chains.
##   MID   (60-200 m out to the sides, |z| >= 60 so it never sits on the chain of rooms):
##         drifting rock islands with ruined towers, dead trees and hanging cages; one big
##         feature per room (a titan's ribcage, a broken flying buttress, a ruined arcade);
##         a flock of bats circling.
##   FAR   the horizon (`BackdropHorizon`, one per scene, follows the camera): the colossal
##         cathedral with its red rose window, mountain rings, broken spires, the blood sea.
##
## Theme follows the room's act (`BackdropKit.theme`), and the room id seeds the layout, so a
## room always looks the same. Every mesh is merged per object (one draw call each), casts no
## shadow, and the whole room's decor is hidden when the camera is far from it.

## The camera must be within this many metres (along X) of the room's centre for its decor to
## show; the horizon covers everything further away.
const SHOW_RANGE: float = 300.0
const NEAR_GAP: float = 10.0
const MID_MIN: float = 60.0

var act: int = 1
var seed_value: int = 0
## Course bounds in world space: x0..x1, z0..z1, and its highest walkable top.
var bounds_x: Vector2 = Vector2.ZERO
var bounds_z: Vector2 = Vector2.ZERO
var top_y: float = 0.0
## Animated parts: [node, kind, base transform, phase, amplitude].
var _movers: Array[Dictionary] = []
var _flock: MultiMeshInstance3D
var _flock_center: Vector3 = Vector3.ZERO
var _flock_radius: float = 20.0
var _time: float = 0.0


## Spawns the backdrop for a built open course (one line from LevelSection.build). Also
## makes sure the scene has a horizon.
static func attach(section: LevelSection) -> Backdrop3D:
    var zmin: float = -Lane.half()
    var zmax: float = Lane.half()
    var ytop: float = 0.0
    for i in section.platform_z.size():
        zmin = minf(zmin, section.platform_z[i].x)
        zmax = maxf(zmax, section.platform_z[i].y)
        ytop = maxf(ytop, section.platforms[i].position.y)
    var b: Backdrop3D = spawn(section, Vector2(section.origin_x, section.origin_x + section.width), Vector2(zmin, zmax), ytop, section.act, hash(String(section.id)), section.get_parent() if section.get_parent() != null else section)
    return b


## Spawns a backdrop around any play area (world bounds) under `parent`.
## `horizon_parent` receives the scene's single `BackdropHorizon` if it has none yet.
static func spawn(parent: Node, x_range: Vector2, z_range: Vector2, highest: float, act_value: int, seed_in: int, horizon_parent: Node) -> Backdrop3D:
    var b: Backdrop3D = Backdrop3D.new()
    b.name = "Backdrop"
    b.act = act_value
    b.seed_value = seed_in
    b.bounds_x = x_range
    b.bounds_z = z_range
    b.top_y = highest
    b.add_to_group(&"backdrop_room")
    b.set_process(not headless())
    parent.add_child(b)
    b._build()
    BackdropHorizon.ensure(horizon_parent, act_value)
    return b


## Headless runs (tests, CI) build the decor but don't animate it: nothing is drawn, and the
## suite's frame timing stays what it was without a backdrop.
static func headless() -> bool:
    return DisplayServer.get_name() == "headless"


func center() -> Vector3:
    return Vector3((bounds_x.x + bounds_x.y) * 0.5, 0.0, (bounds_z.x + bounds_z.y) * 0.5)


func _build() -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = seed_value
    _build_near(rng)
    _build_gibbets(rng)
    _build_islands(rng)
    _build_feature(rng)
    _build_flock(rng)


# --- NEAR band ---------------------------------------------------------------------------

func _build_near(rng: RandomNumberGenerator) -> void:
    var m: BackdropKit.Merge = BackdropKit.Merge.new()
    var width: float = bounds_x.y - bounds_x.x
    var count: int = int(width / 15.0) + 2
    for side in [-1.0, 1.0]:
        var edge: float = (bounds_z.y if side > 0.0 else bounds_z.x) + side * NEAR_GAP
        for i in count:
            var x: float = lerpf(bounds_x.x - 6.0, bounds_x.y + 6.0, (i + rng.randf_range(0.1, 0.9)) / count)
            var z: float = edge + side * rng.randf_range(0.0, 26.0)
            var top: float = rng.randf_range(-22.0, -6.0)
            _pillar(m, Vector3(x, top, z), rng.randf_range(1.3, 2.6), rng)
            if rng.randf() < 0.55:
                var y: float = rng.randf_range(-22.0, -5.0)
                BackdropKit.box(m, Vector3(x + rng.randf_range(-6, 6), y, z + side * rng.randf_range(2, 10)), Vector3.ONE * rng.randf_range(0.8, 2.2), BackdropKit.C_DARK, Basis.from_euler(Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU))
        # One tall ruin per side well back from the edge: a broken wall with a lit lancet.
        var rx: float = lerpf(bounds_x.x, bounds_x.y, rng.randf_range(0.2, 0.8))
        var rz: float = edge + side * rng.randf_range(22.0, 34.0)
        _ruin_wall(m, Vector3(rx, -30.0, rz), rng.randf_range(32.0, 46.0), side, rng)
    add_child(BackdropKit.instance(m, act, false, "Near ruins"))


## A clustered gothic pillar rising from deep in the abyss to a broken top at `top`.
func _pillar(m: BackdropKit.Merge, top: Vector3, r: float, rng: RandomNumberGenerator) -> void:
    var base: Vector3 = Vector3(top.x, -150.0, top.z)
    if not BackdropKit.model("bd_pillar_top").is_empty():
        # Modelled broken crown (DEC-057): capital and snapped drum, its tip at `top`.
        var crown: Vector3 = top + Vector3.DOWN * r * 3.0
        BackdropKit.column(m, base, crown.y - base.y, r, 1.0, 12, BackdropKit.C_STONE)
        for k in 4:
            var a: float = TAU * k / 4.0 + PI * 0.25
            BackdropKit.column(m, base + Vector3(cos(a), 0, sin(a)) * r * 0.95, crown.y - base.y, r * 0.38, 1.0, 8, BackdropKit.C_DARK)
        BackdropKit.add_model(m, "bd_pillar_top", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * r), crown))
        return
    BackdropKit.column(m, base, top.y - base.y, r, 1.0, 8, BackdropKit.C_STONE)
    for k in 4:
        var a: float = TAU * k / 4.0 + PI * 0.25
        var off: Vector3 = Vector3(cos(a), 0, sin(a)) * r * 0.95
        BackdropKit.column(m, base + off, top.y - base.y - rng.randf_range(0.0, 2.0), r * 0.38, 1.0, 6, BackdropKit.C_DARK)
    # A capital ring a little below the break, and a jagged chunk on top.
    BackdropKit.box(m, top + Vector3.DOWN * 2.5, Vector3(r * 2.6, 0.6, r * 2.6), BackdropKit.C_LIGHT)
    BackdropKit.box(m, top + Vector3(rng.randf_range(-0.4, 0.4), 0.3, rng.randf_range(-0.4, 0.4)) * r, Vector3(r * 1.5, r * 0.9, r * 1.2), BackdropKit.C_STONE, Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf(), rng.randf_range(-0.4, 0.4))))


## A ragged slab of cathedral wall standing up out of the abyss with a glowing lancet.
func _ruin_wall(m: BackdropKit.Merge, base: Vector3, h: float, side: float, rng: RandomNumberGenerator) -> void:
    var w: float = rng.randf_range(9.0, 14.0)
    var yaw: Basis = Basis(Vector3.UP, rng.randf_range(-0.35, 0.35))
    # Modelled ruin (DEC-057): ragged courses, a glowing lancet, buttresses (faces both ways).
    if BackdropKit.add_model(m, "bd_ruin_wall", Transform3D(yaw * Basis.from_scale(Vector3(w, h, 2.2)), base)):
        return
    BackdropKit.box(m, base + Vector3.UP * h * 0.5, Vector3(w, h, 2.2), BackdropKit.C_STONE, yaw)
    # Ragged top: steps of broken masonry.
    for i in 4:
        var off: float = (i - 1.5) * w * 0.25
        BackdropKit.box(m, base + yaw * Vector3(off, h + rng.randf_range(-2.0, 3.5), 0), Vector3(w * 0.24, 4.0, 2.2), BackdropKit.C_STONE, yaw)
    for s in [-1.0, 1.0]:
        BackdropKit.box(m, base + yaw * Vector3(s * w * 0.5, h * 0.45, 0), Vector3(1.6, h * 0.9, 3.4), BackdropKit.C_DARK, yaw)
    var face: Vector3 = yaw * Vector3(0, 0, -side)
    BackdropKit.lancet(m, base + Vector3.UP * h * 0.72 + face * 1.15, face, 1.8, 6.5, BackdropKit.C_GLOW)
    BackdropKit.pointed_arch(m, Transform3D(yaw, base + Vector3.UP * (h * 0.72 + 3.0) + face * 1.2), 3.6, 0.35, BackdropKit.C_LIGHT, 4)


## Gibbet cages hanging on long chains just outside the course, swinging slowly.
func _build_gibbets(rng: RandomNumberGenerator) -> void:
    var width: float = bounds_x.y - bounds_x.x
    var count: int = 2 if width > 35.0 else 1
    for i in count:
        var side: float = -1.0 if (i + seed_value) % 2 == 0 else 1.0
        var edge: float = (bounds_z.y if side > 0.0 else bounds_z.x) + side * rng.randf_range(12.0, 18.0)
        var pivot_pos: Vector3 = Vector3(lerpf(bounds_x.x, bounds_x.y, (i + 0.5) / count + rng.randf_range(-0.15, 0.15)), top_y + 40.0, edge)
        var length: float = pivot_pos.y - rng.randf_range(-4.0, 2.0)
        var m: BackdropKit.Merge = BackdropKit.Merge.new()
        BackdropKit.chain(m, Vector3.ZERO, length, 0.55)
        BackdropKit.cage(m, Vector3.DOWN * length, 2.6, rng)
        var pivot: Node3D = Node3D.new()
        pivot.name = "Gibbet %d" % i
        pivot.position = pivot_pos
        add_child(pivot)
        pivot.add_child(BackdropKit.instance(m, act, false, "Chain and cage"))
        _movers.append({"node": pivot, "kind": &"swing", "base": pivot.transform, "phase": rng.randf() * TAU, "amp": rng.randf_range(0.012, 0.025)})


# --- MID band ----------------------------------------------------------------------------

func _build_islands(rng: RandomNumberGenerator) -> void:
    var c: Vector3 = center()
    var count: int = 3 + (1 if bounds_x.y - bounds_x.x > 50.0 else 0)
    for i in count:
        var side: float = -1.0 if i % 2 == 0 else 1.0
        var edge: float = bounds_z.y if side > 0.0 else bounds_z.x
        var z: float = side * maxf(MID_MIN + 12.0, absf(edge) + rng.randf_range(55.0, 150.0))
        var x: float = c.x + rng.randf_range(-0.6, 0.6) * (bounds_x.y - bounds_x.x) + rng.randf_range(-20.0, 20.0)
        var y: float = top_y + rng.randf_range(-10.0, 32.0)
        var size: float = rng.randf_range(10.0, 20.0) * (1.0 + absf(z) / 400.0)
        var m: BackdropKit.Merge = BackdropKit.Merge.new()
        _island(m, size, rng)
        var node: MeshInstance3D = BackdropKit.instance(m, act, false, "Floating island %d" % i)
        node.position = Vector3(x, y, z)
        node.rotation.y = rng.randf() * TAU
        add_child(node)
        _movers.append({"node": node, "kind": &"drift", "base": node.transform, "phase": rng.randf() * TAU, "amp": rng.randf_range(1.0, 2.5)})
        if i == 0:
            _flock_center = Vector3(x, y + size * 1.6, z)
            _flock_radius = size * 1.4


## One island in local space: rock, a ruin on top, dead trees, chains and a cage underneath.
func _island(m: BackdropKit.Merge, size: float, rng: RandomNumberGenerator) -> void:
    BackdropKit.rock(m, Transform3D(Basis.from_scale(Vector3(size, size * 1.1, size * rng.randf_range(0.75, 1.0))), Vector3.ZERO), rng.randi() % 8, BackdropKit.C_STONE)
    var top: float = size * 0.13
    var kind: int = rng.randi() % 3
    if kind == 0:
        BackdropKit.kenney_tower(m, Vector3(rng.randf_range(-0.2, 0.2) * size, top - 0.5, 0), size * 0.42, rng.randi_range(1, 3), rng.randf() < 0.6, rng)
    elif kind == 1:
        BackdropKit.gothic_tower(m, Vector3(rng.randf_range(-0.2, 0.2) * size, top - 0.5, 0), size * 0.32, size * rng.randf_range(1.1, 1.8), size * 0.9, rng.randf() < 0.5, rng)
    else:
        # A roofless chapel: two rows of pointed arches on pillars.
        var span: float = size * 0.3
        for s in [-1.0, 1.0]:
            for k in 3:
                var p: Vector3 = Vector3((k - 1) * span, top, s * size * 0.22)
                BackdropKit.column(m, p, size * 0.5, size * 0.035, 1.0, 6, BackdropKit.C_STONE)
            for k in 2:
                var keep: float = 1.0 if rng.randf() < 0.6 else 0.4
                BackdropKit.pointed_arch(m, Transform3D(Basis.IDENTITY, Vector3((k - 0.5) * span, top + size * 0.5, s * size * 0.22)), span, size * 0.03, BackdropKit.C_STONE, 4, keep)
        BackdropKit.lancet(m, Vector3(-span * 1.6, top + size * 0.3, 0), Vector3.LEFT, size * 0.05, size * 0.25, BackdropKit.C_GLOW)
        BackdropKit.box(m, Vector3(-span * 1.55, top + size * 0.3, 0), Vector3(size * 0.06, size * 0.6, size * 0.4), BackdropKit.C_STONE)
    for t in rng.randi_range(1, 3):
        var a: float = rng.randf() * TAU
        BackdropKit.dead_tree(m, Vector3(cos(a), 0, sin(a)) * size * rng.randf_range(0.45, 0.7) + Vector3.UP * (top - 0.3), size * rng.randf_range(0.25, 0.45), rng)
    # Chains hanging from the root, one ending in a cage.
    for k in 2:
        var a: float = rng.randf() * TAU
        var hang: Vector3 = Vector3(cos(a), 0, sin(a)) * size * 0.45 + Vector3.DOWN * size * 0.4
        var length: float = size * rng.randf_range(0.6, 1.3)
        BackdropKit.chain(m, hang, length, size * 0.04)
        if k == 0:
            BackdropKit.cage(m, hang + Vector3.DOWN * length, size * 0.2, rng)


## One big feature per room, out on a side: a titan's ribcage in the abyss, a colossal broken
## flying buttress, or a ruined arcade marching off into the dark.
func _build_feature(rng: RandomNumberGenerator) -> void:
    var c: Vector3 = center()
    var side: float = 1.0 if seed_value % 2 == 0 else -1.0
    var edge: float = bounds_z.y if side > 0.0 else bounds_z.x
    var z: float = side * maxf(MID_MIN + 40.0, absf(edge) + rng.randf_range(90.0, 140.0))
    var m: BackdropKit.Merge = BackdropKit.Merge.new()
    var pick: int = (seed_value / 7) % 3
    if act >= 2 and pick == 2:
        pick = 0  # act 2 leans on bone
    var label: String = ""
    if pick == 0:
        var length: float = rng.randf_range(110.0, 150.0)
        var yaw: Basis = Basis(Vector3.UP, rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0))
        BackdropKit.ribcage(m, Transform3D(yaw, Vector3(c.x - length * 0.4, top_y - 26.0, z)), length, rng)
        label = "Titan ribcage"
    elif pick == 1:
        var to: Vector3 = Vector3(c.x + rng.randf_range(-30, 30), top_y + 70.0, z + side * 50.0)
        BackdropKit.flying_buttress(m, Vector3(to.x + rng.randf_range(-10, 10), -140.0, z - side * 10.0), 190.0, to, 9.0, true)
        BackdropKit.flying_buttress(m, Vector3(to.x + 40.0, -140.0, z + side * 6.0), 170.0, to + Vector3(40, -10, 0), 8.0, rng.randf() < 0.5)
        BackdropKit.gothic_tower(m, Vector3(to.x - 50.0, -120.0, z + side * 40.0), 18.0, 150.0, 60.0, true, rng)
        label = "Broken buttresses"
    else:
        var dir: Vector3 = Vector3(1, 0, side * rng.randf_range(0.2, 0.5)).normalized()
        var start: Vector3 = Vector3(c.x - 70.0, -120.0, z)
        for k in 7:
            var p: Vector3 = start + dir * (k * 24.0)
            var h: float = 120.0 + top_y + rng.randf_range(-8.0, 6.0) - k * 2.0
            BackdropKit.column(m, p, h, 3.2, 1.0, 8, BackdropKit.C_STONE)
            BackdropKit.box(m, p + Vector3.UP * h, Vector3(9, 2.5, 9), BackdropKit.C_LIGHT)
            if k < 6 and rng.randf() < 0.8:
                var mid: Vector3 = p + dir * 12.0 + Vector3.UP * h
                var yaw: Basis = Basis(Vector3.UP, atan2(-dir.z, dir.x))
                BackdropKit.pointed_arch(m, Transform3D(yaw, mid), 24.0, 1.6, BackdropKit.C_STONE, 5, 1.0 if rng.randf() < 0.6 else 0.5)
        label = "Ruined arcade"
    var node: MeshInstance3D = BackdropKit.instance(m, act, false, label)
    add_child(node)


func _build_flock(rng: RandomNumberGenerator) -> void:
    _flock = BackdropFlock.create(14, 1.6, act)
    _flock.name = "Bat flock"
    add_child(_flock)
    BackdropFlock.scatter(_flock, rng)


# --- Life --------------------------------------------------------------------------------

func _process(delta: float) -> void:
    var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
    if cam != null:
        var near: bool = absf(cam.global_position.x - center().x) < SHOW_RANGE
        if visible != near:
            visible = near
    if not visible:
        return
    _time += delta
    for mv: Dictionary in _movers:
        var node: Node3D = mv["node"]
        var base: Transform3D = mv["base"]
        var ph: float = mv["phase"]
        var amp: float = mv["amp"]
        if mv["kind"] == &"swing":
            var a: float = sin(_time * 0.7 + ph) * amp * 4.0
            var b: float = sin(_time * 0.45 + ph * 1.7) * amp * 2.5
            node.transform = Transform3D(Basis.from_euler(Vector3(a, 0.0, b)), base.origin)
        else:
            var t: Transform3D = base
            t.origin += Vector3(sin(_time * 0.11 + ph) * amp * 0.6, sin(_time * 0.23 + ph) * amp, cos(_time * 0.09 + ph) * amp * 0.6)
            t.basis = Basis(Vector3.UP, sin(_time * 0.05 + ph) * 0.08) * base.basis
            node.transform = t
    if _flock != null:
        BackdropFlock.circle(_flock, _flock_center, _flock_radius, _time)

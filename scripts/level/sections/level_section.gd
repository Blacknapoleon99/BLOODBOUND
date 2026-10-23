class_name LevelSection
extends Node3D
## One handmade room of the first map (see docs/superpowers/specs/2026-10-21-first-map-design.md).
##
## Contract: the room spans x = origin_x .. origin_x + width. Its entry (left) and exit (right)
## floors have their top at y = 0, so rooms join seamlessly in any order. Subclasses describe
## the room in `_design()` with the helpers below, all in LOCAL x (0 = left edge); helpers
## convert to world space, so every node lives in world coordinates (the section node itself
## stays at the origin).
##
## Every walkable surface is also recorded in `platforms` (Rect2: x = left, y = top height,
## width = width) and its depth in `platform_z` (z from, z to), so `is_completable()` can prove
## the exit is reachable from the entry with the player's real jump limits — no room can ship
## unwinnable.
##
## Full 3D (`Lane.full_3d`, the 3D run): each room is an OPEN COURSE (DEC-052) described in
## `_course()`: a wide, wall-less area (about 40-60 m long, 30-40 m across, up to ~15 m of
## height) floating in the void, with several genuinely different routes from the entry pad to
## the exit pad (ground, high, climb...), optional side areas, secrets and loose Bone Shards.
## The course helpers (`pads`, `plat`, `pillar`, `wall3`, `climb`, `kick_shaft`, `lift`, `orbit`,
## `crumble`, `cellar`, `shard`, `spike_bed`, `blade`, `foe`, `arena`, `lever`, `hint`) take
## local x and world z (the section sits at z = 0). Every platform carries a route tag
## (`route()`), and the validator proves: the exit is reachable with BASIC jumps alone; each
## declared route reaches it on its own (advanced moves allowed: climbing, wall kicks, triple
## and long jumps); the common pads alone never do (no single corridor); every reward can be
## reached. Rooms keep joining along X: the entry pad spans local x 0..10 and the exit pad the
## last 8 m, both 8 m deep round z = 0 with their tops at y = 0.

var id: StringName = &"section"
var title: String = "Section"
var act: int = 1
var difficulty: int = 1
var width: float = 40.0
var origin_x: float = 0.0
var platforms: Array[Rect2] = []
## Depth of each platform (x = z from, y = z to), parallel to `platforms`.
var platform_z: Array[Vector2] = []
## Pairs of platform indices joined by a moving platform (ride from one end to the other).
var links: Array[Vector2i] = []
var checkpoint: Checkpoint
var altars: Array[BloodAltar] = []
var ambushes: Array[Ambush] = []
var traps: Array[Node3D] = []
var slabs: Array[CollapsingSlab] = []
var enemies: Array[Node3D] = []
var secrets: Array[BreakableFloor] = []
var caches: Array[LootChest] = []
var shortcuts: Array[LeverShortcut] = []
var _palette: Color = Color(0.18, 0.18, 0.22)
var _ledges: int = 0
## Depth of a 3D ledge, and how far left/right of the hall's centre it sits.
const LEDGE_DEPTH_3D: float = 4.5
const LEDGE_SWAY_3D: float = 2.5
## --- Open 3D courses (DEC-052) ---
## Route tag of each platform (parallel to `platforms`); &"" = common (the entry/exit pads).
var platform_route: Array[StringName] = []
## Declared routes, in the order `route()` first named them.
var routes: Array[StringName] = []
## Directed links an ADVANCED move makes (a climb up a ClimbWall, a wall-kick shaft).
var adv_links: Array[Vector2i] = []
var pickups: Array[ShardPickup] = []
var climb_walls: Array[ClimbWall] = []
var _route: StringName = &""
var _climbs: Array[Dictionary] = []
## Every solid block's box (world centre `pos`, `size`, material `kind`, `walkable` top), for the
## decor pass (GothicDressing, DEC-054): crumbled undersides and props. Visual data only.
var dress_blocks: Array[Dictionary] = []


## Builds the room with its left edge at `at_x` (world). Call after adding it to the level.
func build(at_x: float) -> void:
    origin_x = at_x
    name = "Section: " + title
    if Lane.full_3d:
        _course()
        _finish_course()
        Backdrop3D.attach(self)  # background world around the course (DEC-055)
    else:
        _design()
    checkpoint = Checkpoint.create(Vector3(gx(2.4), 1.2, 0.0), Vector3(2.0, 3.0, Lane.depth(3.0)))
    checkpoint.name = "Checkpoint: " + title
    add_child(checkpoint)
    if not Lane.full_3d:
        _backdrop()  # full 3D: no walls at all — the course floats in the void
    else:
        GothicDressing.dress(self)  # decor only: rubble undersides and props (DEC-054)


## Override: lay out the room with the helpers (the side view).
func _design() -> void:
    pass


## Override: the room as an open 3D course (the 3D run). Defaults to the side-view design.
func _course() -> void:
    _design()


func gx(local_x: float) -> float:
    return origin_x + local_x


# --- Geometry helpers ---------------------------------------------------------------

## Solid ground from x0 to x1 with its top at `top`, reaching down to `bottom` (a step block or
## a thick floor). Records the walkable top.
func ground(x0: float, x1: float, top: float = 0.0, bottom: float = -1.0, label: String = "Ground") -> void:
    _block(label, x0, x1, bottom, top, _palette, 0.0, -1.0, &"floor")
    _platform(Rect2(x0, top, x1 - x0, 0.0))


## A thin floating ledge (0.4 m thick) — something to jump onto over a pit. In 3D it is
## LEDGE_DEPTH_3D deep and alternates left/right of the hall's centre.
func ledge(x0: float, x1: float, top: float, label: String = "Ledge") -> void:
    if not Lane.full_3d:
        _block(label, x0, x1, top - 0.4, top, _palette.lightened(0.12), 0.0, -1.0, &"floor")
        _platform(Rect2(x0, top, x1 - x0, 0.0))
        return
    var z: float = LEDGE_SWAY_3D * (1.0 if _ledges % 2 == 0 else -1.0)
    _ledges += 1
    _block(label, x0, x1, top - 0.4, top, _palette.lightened(0.12), z, LEDGE_DEPTH_3D, &"floor")
    _platform(Rect2(x0, top, x1 - x0, 0.0), Vector2(z - LEDGE_DEPTH_3D * 0.5, z + LEDGE_DEPTH_3D * 0.5))


## Records a walkable surface (depth defaults to the whole hall). Returns its index.
func _platform(rect: Rect2, z_range: Vector2 = Vector2.INF) -> int:
    platforms.append(rect)
    platform_z.append(Vector2(-Lane.half(), Lane.half()) if z_range == Vector2.INF else z_range)
    platform_route.append(_route)
    return platforms.size() - 1


## Depth range of the walkable surface under local `x` at height `top` (the whole hall if none).
func z_range_at(x: float, top: float) -> Vector2:
    for i in platforms.size():
        var r: Rect2 = platforms[i]
        if absf(r.position.y - top) < 0.05 and x >= r.position.x and x <= r.end.x:
            return platform_z[i]
    return Vector2(-Lane.half(), Lane.half())


## Solid, non-walkable scenery that blocks movement (ceilings, pillars).
func block(x0: float, x1: float, y0: float, y1: float, label: String = "Wall") -> void:
    _block(label, x0, x1, y0, y1, _palette.darkened(0.25), 0.0, -1.0, &"wall")


func slab(center_x: float, top: float = 0.0, slab_width: float = 2.5) -> CollapsingSlab:
    var s: CollapsingSlab = CollapsingSlab.create("Collapsing slab", Vector3(gx(center_x), top - 0.5, 0.0), Vector3(slab_width, 1.0, Lane.depth()))
    s.collapse_delay = 0.55
    add_child(s)
    slabs.append(s)
    _platform(Rect2(center_x - slab_width * 0.5, top, slab_width, 0.0))
    return s


## A platform shuttling between local x `a` and `b` (centres) at top height `top`.
func mover(a: float, b: float, top: float = 0.0, platform_width: float = 3.0, travel: float = 2.2) -> MovingPlatform:
    var p: MovingPlatform = MovingPlatform.create("Moving platform", Vector3(gx(a), top - 0.3, 0.0), Vector3(gx(b), top - 0.3, 0.0), Vector3(platform_width, 0.6, Lane.depth()))
    p.travel_time = travel
    p.pause_time = 0.6
    add_child(p)
    _platform(Rect2(a - platform_width * 0.5, top, platform_width, 0.0))
    _platform(Rect2(b - platform_width * 0.5, top, platform_width, 0.0))
    links.append(Vector2i(platforms.size() - 2, platforms.size() - 1))
    return p


func spikes(center_x: float, strip_width: float = 2.0, offset: float = 0.0, top: float = 0.0) -> SpikeTrap:
    var trap: SpikeTrap
    if Lane.full_3d:
        var zr: Vector2 = z_range_at(center_x, top)  # on a ledge: as deep as the ledge
        trap = SpikeTrap.create("Spike trap", gx(center_x), top, strip_width, offset, (zr.x + zr.y) * 0.5, zr.y - zr.x - 0.4)
    else:
        trap = SpikeTrap.create("Spike trap", gx(center_x), top, strip_width, offset)
    add_child(trap)
    traps.append(trap)
    return trap


func pendulum(x: float, floor_top: float = 0.0, offset: float = 0.0) -> PendulumBlade:
    var blade_node: PendulumBlade = PendulumBlade.create("Pendulum blade", Vector3(gx(x), floor_top + 5.9, 0.0), 5.0, offset)
    add_child(blade_node)
    traps.append(blade_node)
    return blade_node


## A roaming enemy that stays dead once killed. `lo`/`hi` bound its movement (local x).
func enemy(type: StringName, x: float, lo: float, hi: float, floor_top: float = 0.0) -> Node3D:
    var zr: Vector2 = z_range_at(x, floor_top) if Lane.full_3d else Vector2.ZERO
    var e: Node3D = EnemyFactory.spawn(type, self, gx(x), gx(lo), gx(hi), floor_top + 1.0, (zr.x + zr.y) * 0.5)
    enemies.append(e)
    return e


## Bone walls at local `left`/`right` close when the player passes `trigger`; `spawns` are
## {"type", "x" (local), "wave" (optional)}.
func ambush(label: String, trigger: float, left: float, right: float, spawns: Array, floor_top: float = 0.0) -> Ambush:
    var world_spawns: Array[Dictionary] = []
    for spawn: Dictionary in spawns:
        var copy: Dictionary = spawn.duplicate()
        copy["x"] = gx(float(spawn["x"]))
        world_spawns.append(copy)
    var a: Ambush = Ambush.create(label, gx(trigger), gx(left), gx(right), world_spawns)
    a.position.y = floor_top
    add_child(a)
    ambushes.append(a)
    return a


## A secret under the floor: a 2 m cracked slab at local [hole_x, hole_x + 2] (top 0; leave that
## span out of your ground() calls) over a niche 1.5 m down holding a reliquary of `kind`
## (&"shards", &"card", &"relics"). Break it, drop in, claim it, hop back out (1.5 m).
func secret_cellar(hole_x: float, kind: StringName, shards: int = 25) -> LootChest:
    var crack: BreakableFloor = BreakableFloor.create(Vector3(gx(hole_x + 1.0), -0.5, 0.0), Vector3(2.0, 1.0, Lane.depth()))
    add_child(crack)
    secrets.append(crack)
    _platform(Rect2(hole_x, 0.0, 2.0, 0.0))
    ground(hole_x, hole_x + 2.0, -1.5, -3.0, "Secret niche")
    block(hole_x - 1.0, hole_x, -3.0, -1.0, "Niche wall")  # sealed sides: no slipping under the floor
    block(hole_x + 2.0, hole_x + 3.0, -3.0, -1.0, "Niche wall")
    var chest: LootChest = LootChest.create(Vector3(gx(hole_x + 1.0), -1.5, -1.0))
    chest.kind = kind
    chest.shards = shards
    add_child(chest)
    caches.append(chest)
    return chest


## A lever at local `lever_x` (standing height `lever_top`) that, once pulled, makes a bone
## bridge solid over local [x0, x1] at height `top`.
func shortcut(lever_x: float, lever_top: float, x0: float, x1: float, top: float = 0.0) -> LeverShortcut:
    var zr: Vector2 = z_range_at(lever_x, lever_top) if Lane.full_3d else Vector2.ZERO
    var s: LeverShortcut = LeverShortcut.create(Vector3(gx(lever_x), lever_top, (zr.x + zr.y) * 0.5), gx(x0), gx(x1), top)
    add_child(s)
    shortcuts.append(s)
    return s


func altar(x: float, floor_top: float = 0.0, z: float = 0.0) -> BloodAltar:
    var a: BloodAltar = BloodAltar.create("Blood Altar", Vector3(gx(x), floor_top, z))
    add_child(a)
    altars.append(a)
    return a


# --- Open 3D course kit (DEC-052; local x, world z) ---------------------------------------

const PAD_DEPTH: float = 8.0  # entry/exit pads: 8 m deep round z = 0


## Tags every platform made from now on with `tag` (&"" = common). Declares the route, except
## &"side": optional areas (secrets, perches) that lead nowhere.
func route(tag: StringName) -> void:
    _route = tag
    if tag != &"" and tag != &"side" and not routes.has(tag):
        routes.append(tag)


## The entry pad (local x 0..entry_len) and the exit pad (the last exit_len m): common to every
## route. The checkpoint stands on the entry pad.
func pads(entry_len: float = 10.0, exit_len: float = 8.0) -> void:
    var keep: StringName = _route
    _route = &""
    plat(entry_len * 0.5, 0.0, entry_len, PAD_DEPTH, 0.0, "Entry pad", 1.5)
    plat(width - exit_len * 0.5, 0.0, exit_len, PAD_DEPTH, 0.0, "Exit pad", 1.5)
    _exit_arch()
    _route = keep


## A flat walkable box centred at (local x, z), `w` along X, `d` along Z, top at `top`.
func plat(cx: float, cz: float, w: float, d: float, top: float, label: String = "Platform", thick: float = 1.0) -> int:
    var tint: Color = _palette.lightened(0.1) if _route == &"" else _palette.lightened(0.03 + 0.04 * (routes.find(_route) % 3))
    _block(label, cx - w * 0.5, cx + w * 0.5, top - thick, top, tint, cz, d, _floor_kind(label, cx, cz, top))
    return _platform(Rect2(cx - w * 0.5, top, w, 0.0), Vector2(cz - d * 0.5, cz + d * 0.5))


## A column rising out of the void with a walkable top (stepping stones, perches).
func pillar(cx: float, cz: float, size: float, top: float, label: String = "Pillar", depth: float = 8.0) -> int:
    _block(label, cx - size * 0.5, cx + size * 0.5, top - depth, top, _palette.darkened(0.08), cz, size, &"pillar")
    return _platform(Rect2(cx - size * 0.5, top, size, 0.0), Vector2(cz - size * 0.5, cz + size * 0.5))


## Solid, non-walkable scenery at (local x, z): a wall-kick wall, a tunnel roof, cover.
func wall3(cx: float, cz: float, w: float, d: float, y0: float, y1: float, label: String = "Wall") -> void:
    _block(label, cx - w * 0.5, cx + w * 0.5, y0, y1, _palette.darkened(0.25), cz, d, &"wall")


## A climbable block (bone handholds) from `bottom` to `top`; its top is walkable. Climbing it
## is an ADVANCED link from any platform at its foot (within 2.5 m, at a height it spans).
func climb(cx: float, cz: float, w: float, d: float, bottom: float, top: float, label: String = "Climb wall") -> int:
    var wall: ClimbWall = ClimbWall.create(label, Vector3(gx(cx), (bottom + top) * 0.5, cz), Vector3(w, top - bottom, d), _palette.lightened(0.08))
    add_child(wall)
    climb_walls.append(wall)
    dress_blocks.append({"pos": wall.position, "size": Vector3(w, top - bottom, d), "kind": &"climb", "walkable": false})
    var index: int = _platform(Rect2(cx - w * 0.5, top, w, 0.0), Vector2(cz - d * 0.5, cz + d * 0.5))
    _climbs.append({"x0": cx - w * 0.5, "x1": cx + w * 0.5, "z0": cz - d * 0.5, "z1": cz + d * 0.5, "bottom": bottom, "top": top, "index": index})
    return index


## A wall-kick shaft standing on platform `base` (index): two plain walls with a 3 m gap,
## `height` tall, and a landing beside their top. `along_x`: the walls run along X (the shaft
## opens along X) and the landing sits 4 m on in +X; otherwise they run along Z and the landing
## sits 4 m on in +Z. Kicking up is an ADVANCED link from `base` to the landing (its index).
func kick_shaft(cx: float, cz: float, base: int, height: float, along_x: bool = true, label: String = "Kick shaft") -> int:
    var floor_top: float = platforms[base].position.y
    var keep: StringName = _route
    for side: float in [-1.0, 1.0]:
        if along_x:
            wall3(cx, cz + side * 1.8, 5.0, 0.6, floor_top, floor_top + height, label + " wall")
        else:
            wall3(cx + side * 1.8, cz, 0.6, 5.0, floor_top, floor_top + height, label + " wall")
    var landing: int
    if along_x:
        landing = plat(cx + 4.0, cz, 3.0, 4.2, floor_top + height, label + " top", 0.5)
    else:
        landing = plat(cx, cz + 4.0, 4.2, 3.0, floor_top + height, label + " top", 0.5)
    _route = keep
    adv_links.append(Vector2i(base, landing))
    return landing


## A platform shuttling between local points `a` and `b` (x, top, z): across a gap, up a shaft.
func lift(a: Vector3, b: Vector3, w: float = 3.0, d: float = 3.0, travel: float = 2.6) -> MovingPlatform:
    var p: MovingPlatform = MovingPlatform.create("Moving platform", Vector3(gx(a.x), a.y - 0.3, a.z), Vector3(gx(b.x), b.y - 0.3, b.z), Vector3(w, 0.6, d))
    p.travel_time = travel
    p.pause_time = 0.8
    add_child(p)
    for end: Vector3 in [a, b]:  # rubble must not hang into a lift's path
        dress_blocks.append({"pos": Vector3(gx(end.x), end.y - 0.3, end.z), "size": Vector3(w, 0.6, d), "kind": &"iron", "walkable": false})
    var i: int = _platform(Rect2(a.x - w * 0.5, a.y, w, 0.0), Vector2(a.z - d * 0.5, a.z + d * 0.5))
    var j: int = _platform(Rect2(b.x - w * 0.5, b.y, w, 0.0), Vector2(b.z - d * 0.5, b.z + d * 0.5))
    links.append(Vector2i(i, j))
    return p


## A platform circling (local cx, cz) at height `top`. Riding it reaches every point of its
## orbit (8 samples are recorded and linked in a ring).
func orbit(cx: float, cz: float, top: float, radius: float, period: float = 9.0, angle0: float = 0.0, size: float = 3.0) -> OrbitingPlatform:
    var p: OrbitingPlatform = OrbitingPlatform.create("Orbiting platform", Vector3(gx(cx), top - 0.3, cz), radius, period, angle0, Vector3(size, 0.6, size))
    add_child(p)
    dress_blocks.append({"pos": Vector3(gx(cx), top - 0.3, cz), "size": Vector3(radius * 2.0 + size, 0.6, radius * 2.0 + size), "kind": &"iron", "walkable": false})
    var first: int = platforms.size()
    for k in 8:
        var a: float = TAU * k / 8.0
        var px: float = cx + cos(a) * radius
        var pz: float = cz + sin(a) * radius
        _platform(Rect2(px - size * 0.5, top, size, 0.0), Vector2(pz - size * 0.5, pz + size * 0.5))
    for k in 8:
        links.append(Vector2i(first + k, first + (k + 1) % 8))
    return p


## A crumbling slab at (local x, z): stand still and it drops (restored on respawn).
func crumble(cx: float, cz: float, top: float, w: float = 2.6, d: float = 2.6) -> CollapsingSlab:
    var s: CollapsingSlab = CollapsingSlab.create("Collapsing slab", Vector3(gx(cx), top - 0.5, cz), Vector3(w, 1.0, d))
    s.collapse_delay = 0.55
    add_child(s)
    slabs.append(s)
    _platform(Rect2(cx - w * 0.5, top, w, 0.0), Vector2(cz - d * 0.5, cz + d * 0.5))
    return s


## A ground-pound cellar: a 6x6 dais (top `top`) round a cracked 2x2 slab over a sealed niche
## 1.5 m down holding a reliquary of `kind`. Pound it (or strike it) to break in; hop back out.
func cellar(cx: float, cz: float, top: float, kind: StringName, shards: int = 25) -> LootChest:
    var tint: Color = _palette.lightened(0.06)
    _block("Cellar dais", cx - 3.0, cx - 1.0, top - 3.0, top, tint, cz, 6.0, &"ossuary")
    _block("Cellar dais", cx + 1.0, cx + 3.0, top - 3.0, top, tint, cz, 6.0, &"ossuary")
    _block("Cellar dais", cx - 1.0, cx + 1.0, top - 3.0, top, tint, cz - 2.0, 2.0, &"ossuary")
    _block("Cellar dais", cx - 1.0, cx + 1.0, top - 3.0, top, tint, cz + 2.0, 2.0, &"ossuary")
    _platform(Rect2(cx - 3.0, top, 6.0, 0.0), Vector2(cz - 3.0, cz + 3.0))
    var crack: BreakableFloor = BreakableFloor.create(Vector3(gx(cx), top - 0.5, cz), Vector3(2.0, 1.0, 2.0))
    add_child(crack)
    secrets.append(crack)
    _block("Secret niche", cx - 1.0, cx + 1.0, top - 3.0, top - 1.5, _palette.darkened(0.2), cz, 2.0, &"wall")
    _platform(Rect2(cx - 1.0, top - 1.5, 2.0, 0.0), Vector2(cz - 1.0, cz + 1.0))
    var chest: LootChest = LootChest.create(Vector3(gx(cx), top - 1.5, cz - 0.4))
    chest.kind = kind
    chest.shards = shards
    add_child(chest)
    caches.append(chest)
    return chest


## A loose Bone Shard floating 1 m over (local x, z) at standing height `top`.
func shard(x: float, z: float, top: float, amount: int = 3) -> ShardPickup:
    var pickup: ShardPickup = ShardPickup.create(Vector3(gx(x), top + 1.0, z), amount)
    add_child(pickup)
    pickups.append(pickup)
    return pickup


## A spike strip `w` x `d` on the floor at (local x, z), height `top`.
func spike_bed(cx: float, cz: float, w: float, d: float, top: float = 0.0, offset: float = 0.0) -> SpikeTrap:
    var trap: SpikeTrap = SpikeTrap.create("Spike trap", gx(cx), top, w, offset, cz, d)
    add_child(trap)
    traps.append(trap)
    return trap


## A pendulum swinging over (local x, z) at floor height `top`, its blade `span` wide. It swings
## along X (across a walkway running along X its blade spans the walkway's depth) unless
## `along_z` (it swings along Z, for walkways running along Z).
func blade(cx: float, cz: float, top: float = 0.0, offset: float = 0.0, span: float = 4.0, along_z: bool = false) -> PendulumBlade:
    var b: PendulumBlade = PendulumBlade.create("Pendulum blade", Vector3(gx(cx), top + 5.9, cz), 5.0, offset, span)
    if along_z:
        b.rotation.y = PI * 0.5
    add_child(b)
    traps.append(b)
    return b


## An enemy standing on the platform under (local x, z) at `top`, leashed so it never walks
## off that platform's edges.
func foe(type: StringName, x: float, z: float, top: float = 0.0) -> Node3D:
    var leash: float = 6.0
    var i: int = platform_under(x, z, top)
    if i >= 0:
        var r: Rect2 = platforms[i]
        var zr: Vector2 = platform_z[i]
        leash = minf(minf(x - r.position.x, r.end.x - x), minf(z - zr.x, zr.y - z)) - 0.7
    var e: Node3D = EnemyFactory.spawn(type, self, gx(x), gx(x - 6.0), gx(x + 6.0), top + 1.0, z)
    if "leash_radius" in e:
        e.set("leash_radius", 10.0 if type == &"wraith" else clampf(leash, 0.8, 12.0))  # wraiths fly
    enemies.append(e)
    return e


## A 3D arena: a ring of bone walls (radius `radius` round local x, z) rises when you step in;
## `spawns` are {"type", "wave" (optional)} spread round the ring. `leash`: how far from the
## centre its foes may chase (the floor's inscribed radius, so nobody runs off the floor).
func arena(label: String, cx: float, cz: float, radius: float, spawns: Array, top: float = 0.0, leash: float = -1.0) -> Ambush:
    var world_spawns: Array[Dictionary] = []
    for spawn: Dictionary in spawns:
        var copy: Dictionary = spawn.duplicate()
        copy["x"] = gx(cx)
        world_spawns.append(copy)
    var a: Ambush = Ambush.create(label, gx(cx - radius), gx(cx - radius), gx(cx + radius), world_spawns)
    a.set_ring(Vector2(gx(cx), cz), radius)
    a.spawn_leash = leash
    a.position.y = top
    add_child(a)
    ambushes.append(a)
    return a


## A lever at (local x, z) that makes a bone bridge solid over local x0..x1 at depth `z` (and
## height `top`). The bridge is a reward (a way back, a shortcut), never part of a route.
func lever(lx: float, lz: float, ltop: float, x0: float, x1: float, z: float, top: float, depth: float = 2.4) -> LeverShortcut:
    var s: LeverShortcut = LeverShortcut.create(Vector3(gx(lx), ltop, lz), gx(x0), gx(x1), top, z, depth)
    add_child(s)
    shortcuts.append(s)
    return s


## A carved hint floating over (local x, z) at standing height `top` (tutorial, route markers).
func hint(text: String, x: float, z: float, top: float) -> Label3D:
    var label: Label3D = Label3D.new()
    label.name = "Sign"
    label.text = text
    label.position = Vector3(gx(x), top + 2.6, z)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 48
    label.pixel_size = 0.006
    label.modulate = Color(0.95, 0.88, 0.8)
    label.outline_size = 10
    # Read from a distance; hidden up close so a sign never fills the screen.
    label.visibility_range_begin = 6.0
    label.visibility_range_begin_margin = 1.0
    label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
    add_child(label)
    return label


## Index of the platform whose top is at `top` (± 0.05) and covers local (x, z); -1 if none.
func platform_under(x: float, z: float, top: float) -> int:
    for i in platforms.size():
        var r: Rect2 = platforms[i]
        var zr: Vector2 = platform_z[i]
        if absf(r.position.y - top) < 0.05 and x >= r.position.x and x <= r.end.x and z >= zr.x and z <= zr.y:
            return i
    return -1


## A glowing archway over the exit pad: the goal reads from anywhere on the course (decor only).
func _exit_arch() -> void:
    var arch: Node3D = GothicDressing.exit_arch()  # carved pointed arch, blood-lit inside (DEC-054)
    arch.name = "Exit arch"
    arch.position = Vector3(gx(width - 1.0), 0.0, 0.0)
    add_child(arch)


## After `_course()`: climbs become advanced links from the platforms at their feet.
func _finish_course() -> void:
    for c: Dictionary in _climbs:
        for i in platforms.size():
            if i == int(c["index"]):
                continue
            var r: Rect2 = platforms[i]
            var zr: Vector2 = platform_z[i]
            var t: float = r.position.y
            if t < float(c["bottom"]) - 0.3 or t > float(c["top"]) - 0.5:
                continue
            var gap_x: float = maxf(0.0, maxf(float(c["x0"]) - r.end.x, r.position.x - float(c["x1"])))
            var gap_z: float = maxf(0.0, maxf(float(c["z0"]) - zr.y, zr.x - float(c["z1"])))
            if Vector2(gap_x, gap_z).length() <= 2.5:
                adv_links.append(Vector2i(i, int(c["index"])))


# --- Reachability ---------------------------------------------------------------------

## Player jump numbers, from scenes/player.tscn defaults (checked by the smoke test).
const RUN_SPEED: float = 8.5
const JUMP_SPEED: float = 9.5
const RISE_GRAVITY: float = 22.0
const FALL_GRAVITY: float = 30.0
const SAFETY: float = 0.75  # only count on 75% of the theoretical reach
## The full-3D jump (player.gd jump_height3d / jump_fall_time3d; the rise to the apex, apex hang
## included, measured at 0.43 s).
const APEX_3D: float = 2.3
const RISE_TIME_3D: float = 0.43
const FALL_TIME_3D: float = 0.27
## Advanced moves the route check allows (PlatformerMotor: triple jump apex 3.8 m and 3.4 m
## measured, backflip 3.6 m, a ledge grab off a single jump; long jump about 9 m).
const ADV_RISE: float = 3.0
const ADV_UP_REACH: float = 3.5
const LONG_REACH: float = 7.0


static func jump_apex() -> float:
    return APEX_3D if Lane.full_3d else JUMP_SPEED * JUMP_SPEED / (2.0 * RISE_GRAVITY)


## Horizontal distance a running jump covers when landing `dy` higher (negative = lower).
static func jump_reach(dy: float) -> float:
    var apex: float = jump_apex()
    if dy > apex * SAFETY:
        return -1.0
    var t_up: float = JUMP_SPEED / RISE_GRAVITY
    var t_down: float = sqrt(2.0 * maxf(0.0, apex - dy) / FALL_GRAVITY)
    if Lane.full_3d:
        t_up = RISE_TIME_3D
        t_down = FALL_TIME_3D * sqrt(maxf(0.0, apex - dy) / apex)
    return minf(9.0, RUN_SPEED * (t_up + t_down) * SAFETY)


## Can a running jump get from `from` to `to`? Depth ranges (`from_z`, `to_z`: z from, z to)
## count in full 3D: the gap is the planar distance between the two surfaces.
static func can_jump(from: Rect2, to: Rect2, from_z: Vector2 = Vector2(-2.0, 2.0), to_z: Vector2 = Vector2(-2.0, 2.0)) -> bool:
    var dy: float = to.position.y - from.position.y
    var reach: float = jump_reach(dy)
    if reach < 0.0:
        return false
    var gap: float = _gap(from, to, from_z, to_z)
    if gap > 0.0:
        return gap <= reach
    # Overlapping: walking/dropping is fine when level or lower; going UP onto a surface
    # directly overhead needs room beside it to jump past its edge.
    if dy <= 0.05:
        return true
    return from.position.x < to.position.x - 0.8 or from.end.x > to.end.x + 0.8 \
            or from_z.x < to_z.x - 0.8 or from_z.y > to_z.y + 0.8


## Advanced jumps for route checks: the triple jump / backflip / ledge grab (up to 3 m up, 3.5 m across)
## and the long jump (up to 7 m across, level or down), on top of every basic jump.
static func can_jump_adv(from: Rect2, to: Rect2, from_z: Vector2, to_z: Vector2) -> bool:
    if can_jump(from, to, from_z, to_z):
        return true
    var dy: float = to.position.y - from.position.y
    var gap: float = _gap(from, to, from_z, to_z)
    return (dy <= ADV_RISE and gap <= ADV_UP_REACH) or (dy <= 0.3 and gap <= LONG_REACH)


## Planar gap between two surfaces (0 when they overlap in plan).
static func _gap(from: Rect2, to: Rect2, from_z: Vector2, to_z: Vector2) -> float:
    var gap_x: float = maxf(0.0, maxf(to.position.x - from.end.x, from.position.x - to.end.x))
    var gap_z: float = maxf(0.0, maxf(to_z.x - from_z.y, from_z.x - to_z.y))
    return Vector2(gap_x, gap_z).length()


## True if the exit floor is reachable from the entry floor with running and BASIC jumps.
func is_completable() -> bool:
    return _reaches_exit(false, func(_i: int) -> bool: return true)


## Platforms reachable from the entry. `advanced` adds climbs, wall kicks, triple and long
## jumps; `allowed(i)` filters which platforms may be used.
func reachable(advanced: bool, allowed: Callable) -> Dictionary:
    var start: int = _platform_at(0.5)
    var seen: Dictionary = {}
    if start < 0 or not allowed.call(start):
        return seen
    seen[start] = true
    var queue: Array[int] = [start]
    while not queue.is_empty():
        var i: int = queue.pop_front()
        for j in platforms.size():
            if seen.has(j) or not allowed.call(j):
                continue
            var ok: bool = links.has(Vector2i(i, j)) or links.has(Vector2i(j, i)) \
                    or can_jump(platforms[i], platforms[j], platform_z[i], platform_z[j])
            if not ok and advanced:
                ok = adv_links.has(Vector2i(i, j)) or can_jump_adv(platforms[i], platforms[j], platform_z[i], platform_z[j])
            if ok:
                seen[j] = true
                queue.append(j)
    return seen


func _reaches_exit(advanced: bool, allowed: Callable) -> bool:
    var goal: int = _platform_at(width - 0.5)
    return goal >= 0 and reachable(advanced, allowed).has(goal)


## The declared routes that reach the exit on their own (their platforms plus the common pads),
## advanced moves allowed.
func working_routes() -> Array[StringName]:
    var ok: Array[StringName] = []
    for tag: StringName in routes:
        if _reaches_exit(true, func(i: int) -> bool: return platform_route[i] == &"" or platform_route[i] == tag):
            ok.append(tag)
    return ok


## The routes that reach the exit with BASIC jumps alone.
func basic_routes() -> Array[StringName]:
    var ok: Array[StringName] = []
    for tag: StringName in routes:
        if _reaches_exit(false, func(i: int) -> bool: return platform_route[i] == &"" or platform_route[i] == tag):
            ok.append(tag)
    return ok


## True if the common pads alone already join entry and exit (a single corridor: not allowed).
func is_corridor() -> bool:
    return _reaches_exit(true, func(i: int) -> bool: return platform_route[i] == &"")


## Loose shards and reliquaries not standing over a platform reachable from the entry (advanced
## moves allowed), as local positions. Empty = every reward can be reached.
func unreachable_rewards() -> Array[Vector3]:
    var seen: Dictionary = reachable(true, func(_i: int) -> bool: return true)
    var spots: Array[Vector3] = []
    for p: ShardPickup in pickups:
        spots.append(p.position - Vector3(origin_x, 1.0, 0.0))
    for c: LootChest in caches:
        spots.append(c.position - Vector3(origin_x, 0.0, 0.0))
    var bad: Array[Vector3] = []
    for spot: Vector3 in spots:
        var found: bool = false
        for i: int in seen:
            var r: Rect2 = platforms[i]
            var zr: Vector2 = platform_z[i]
            if absf(r.position.y - spot.y) < 0.6 and spot.x >= r.position.x - 0.3 and spot.x <= r.end.x + 0.3 \
                    and spot.z >= zr.x - 0.3 and spot.z <= zr.y + 0.3:
                found = true
                break
        if not found:
            bad.append(spot)
    return bad


## Planar extent of the course's platforms: Rect2(x0, z0, w, d) in local x / world z.
func footprint() -> Rect2:
    var box: Rect2 = Rect2(platforms[0].position.x, platform_z[0].x, 0.0, 0.0)
    for i in platforms.size():
        box = box.expand(Vector2(platforms[i].position.x, platform_z[i].x)).expand(Vector2(platforms[i].end.x, platform_z[i].y))
    return box


## Lowest and highest walkable tops.
func height_range() -> Vector2:
    var lo: float = INF
    var hi: float = -INF
    for r: Rect2 in platforms:
        lo = minf(lo, r.position.y)
        hi = maxf(hi, r.position.y)
    return Vector2(lo, hi)


func _platform_at(local_x: float) -> int:
    for i in platforms.size():
        var r: Rect2 = platforms[i]
        if absf(r.position.y) < 0.01 and local_x >= r.position.x and local_x <= r.end.x \
                and platform_z[i].x <= 0.0 and platform_z[i].y >= 0.0:
            return i
    return -1


# --- Internals ------------------------------------------------------------------------

## The look of a walkable `plat` (DEC-054): pads and routes get different stone, some blood.
func _floor_kind(label: String, cx: float, cz: float, top: float) -> StringName:
    if label == "Exit pad":
        return &"floor_blood"
    if _route == &"":
        return &"floor"
    var roll: float = fposmod(sin(cx * 12.9898 + cz * 78.233 + top * 37.719 + origin_x) * 43758.5453, 1.0)
    if roll < 0.2:
        return &"floor_blood"
    return &"floor_cobble" if routes.find(_route) % 3 == 1 else &"floor"


func _block(label: String, x0: float, x1: float, y0: float, y1: float, color: Color, z: float = 0.0, z_depth: float = -1.0, kind: StringName = &"wall") -> void:
    var body: StaticBody3D = StaticBody3D.new()
    body.name = label
    body.position = Vector3(gx((x0 + x1) * 0.5), (y0 + y1) * 0.5, z)
    var size: Vector3 = Vector3(x1 - x0, y1 - y0, z_depth if z_depth > 0.0 else Lane.depth())
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    var mesh_node: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    mesh_node.material_override = GothicMaterials.block(kind, _palette)
    body.add_child(mesh_node)
    add_child(body)
    dress_blocks.append({"pos": body.position, "size": size, "kind": kind, "walkable": kind != &"wall", "color": color})


## Dark back wall and a few pillars so each room reads as a place (decor only).
func _backdrop() -> void:
    var wall: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(width, 16.0, 0.5)
    wall.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = _palette.darkened(0.6)
    wall.material_override = material
    wall.position = Vector3(gx(width * 0.5), 4.0, -6.0)
    add_child(wall)
    var count: int = int(width / 9.0)
    for i in count:
        var pillar_mesh: MeshInstance3D = MeshInstance3D.new()
        var pm: BoxMesh = BoxMesh.new()
        pm.size = Vector3(1.2, 14.0, 1.2)
        pillar_mesh.mesh = pm
        pillar_mesh.material_override = material
        pillar_mesh.position = Vector3(gx(4.5 + i * 9.0), 3.0, -5.0)
        add_child(pillar_mesh)

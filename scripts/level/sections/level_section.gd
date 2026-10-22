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
## Full 3D (`Lane.full_3d`, the 3D run): the same designs become walled halls `Lane.DEPTH_3D`
## deep. Floors, slabs, movers, hazards and ambush walls span the hall; floating ledges are
## narrower and zig-zag left/right in depth so every climb is aimed; enemies and spikes on a
## ledge sit on its actual depth; the reachability check uses the 3D jump over planar gaps.

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


## Builds the room with its left edge at `at_x` (world). Call after adding it to the level.
func build(at_x: float) -> void:
    origin_x = at_x
    name = "Section: " + title
    _design()
    checkpoint = Checkpoint.create(Vector3(gx(2.4), 1.2, 0.0), Vector3(2.0, 3.0, Lane.depth(3.0)))
    checkpoint.name = "Checkpoint: " + title
    add_child(checkpoint)
    if Lane.full_3d:
        _hall_walls()
    else:
        _backdrop()


## Override: lay out the room with the helpers.
func _design() -> void:
    pass


func gx(local_x: float) -> float:
    return origin_x + local_x


# --- Geometry helpers ---------------------------------------------------------------

## Solid ground from x0 to x1 with its top at `top`, reaching down to `bottom` (a step block or
## a thick floor). Records the walkable top.
func ground(x0: float, x1: float, top: float = 0.0, bottom: float = -1.0, label: String = "Ground") -> void:
    _block(label, x0, x1, bottom, top, _palette)
    _platform(Rect2(x0, top, x1 - x0, 0.0))


## A thin floating ledge (0.4 m thick) — something to jump onto over a pit. In 3D it is
## LEDGE_DEPTH_3D deep and alternates left/right of the hall's centre.
func ledge(x0: float, x1: float, top: float, label: String = "Ledge") -> void:
    if not Lane.full_3d:
        _block(label, x0, x1, top - 0.4, top, _palette.lightened(0.12))
        _platform(Rect2(x0, top, x1 - x0, 0.0))
        return
    var z: float = LEDGE_SWAY_3D * (1.0 if _ledges % 2 == 0 else -1.0)
    _ledges += 1
    _block(label, x0, x1, top - 0.4, top, _palette.lightened(0.12), z, LEDGE_DEPTH_3D)
    _platform(Rect2(x0, top, x1 - x0, 0.0), Vector2(z - LEDGE_DEPTH_3D * 0.5, z + LEDGE_DEPTH_3D * 0.5))


## Records a walkable surface (depth defaults to the whole hall).
func _platform(rect: Rect2, z_range: Vector2 = Vector2.INF) -> void:
    platforms.append(rect)
    platform_z.append(Vector2(-Lane.half(), Lane.half()) if z_range == Vector2.INF else z_range)


## Depth range of the walkable surface under local `x` at height `top` (the whole hall if none).
func z_range_at(x: float, top: float) -> Vector2:
    for i in platforms.size():
        var r: Rect2 = platforms[i]
        if absf(r.position.y - top) < 0.05 and x >= r.position.x and x <= r.end.x:
            return platform_z[i]
    return Vector2(-Lane.half(), Lane.half())


## Solid, non-walkable scenery that blocks movement (ceilings, pillars).
func block(x0: float, x1: float, y0: float, y1: float, label: String = "Wall") -> void:
    _block(label, x0, x1, y0, y1, _palette.darkened(0.25))


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
    var blade: PendulumBlade = PendulumBlade.create("Pendulum blade", Vector3(gx(x), floor_top + 5.9, 0.0), 5.0, offset)
    add_child(blade)
    traps.append(blade)
    return blade


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


func altar(x: float, floor_top: float = 0.0) -> BloodAltar:
    var a: BloodAltar = BloodAltar.create("Blood Altar", Vector3(gx(x), floor_top, 0.0))
    add_child(a)
    altars.append(a)
    return a


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
    var gap_x: float = maxf(0.0, maxf(to.position.x - from.end.x, from.position.x - to.end.x))
    var gap_z: float = maxf(0.0, maxf(to_z.x - from_z.y, from_z.x - to_z.y))
    var gap: float = Vector2(gap_x, gap_z).length()
    if gap > 0.0:
        return gap <= reach
    # Overlapping: walking/dropping is fine when level or lower; going UP onto a surface
    # directly overhead needs room beside it to jump past its edge.
    if dy <= 0.05:
        return true
    return from.position.x < to.position.x - 0.8 or from.end.x > to.end.x + 0.8 \
            or from_z.x < to_z.x - 0.8 or from_z.y > to_z.y + 0.8


## True if the exit floor is reachable from the entry floor.
func is_completable() -> bool:
    var start: int = _platform_at(0.5)
    var goal: int = _platform_at(width - 0.5)
    if start < 0 or goal < 0:
        return false
    var seen: Dictionary = {start: true}
    var queue: Array[int] = [start]
    while not queue.is_empty():
        var i: int = queue.pop_front()
        if i == goal:
            return true
        for j in platforms.size():
            if seen.has(j):
                continue
            var linked: bool = links.has(Vector2i(i, j)) or links.has(Vector2i(j, i))
            if linked or can_jump(platforms[i], platforms[j], platform_z[i], platform_z[j]):
                seen[j] = true
                queue.append(j)
    return false


func _platform_at(local_x: float) -> int:
    for i in platforms.size():
        var r: Rect2 = platforms[i]
        if absf(r.position.y) < 0.01 and local_x >= r.position.x and local_x <= r.end.x:
            return i
    return -1


# --- Internals ------------------------------------------------------------------------

func _block(label: String, x0: float, x1: float, y0: float, y1: float, color: Color, z: float = 0.0, z_depth: float = -1.0) -> void:
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
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    mesh_node.material_override = material
    body.add_child(mesh_node)
    add_child(body)


## Full 3D: tall walls down both sides of the hall (you fall into pits, never off the side).
func _hall_walls() -> void:
    var wall_color: Color = _palette.darkened(0.45)
    for side: float in [-1.0, 1.0]:
        _block("Hall wall", 0.0, width, -14.0, 12.0, wall_color, side * (Lane.half() + 0.3), 0.6)
    # Buttresses break up the long walls (decor that also gives the camera something to frame).
    for i in int(width / 8.0):
        for side: float in [-1.0, 1.0]:
            _block("Buttress", 3.6 + i * 8.0, 4.4 + i * 8.0, -14.0, 12.0, wall_color.lightened(0.06), side * (Lane.half() + 0.1), 0.4)


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
        var pillar: MeshInstance3D = MeshInstance3D.new()
        var pm: BoxMesh = BoxMesh.new()
        pm.size = Vector3(1.2, 14.0, 1.2)
        pillar.mesh = pm
        pillar.material_override = material
        pillar.position = Vector3(gx(4.5 + i * 9.0), 3.0, -5.0)
        add_child(pillar)

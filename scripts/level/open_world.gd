class_name OpenWorld
extends RefCounted
## The 3D run's open world (DEC-063): one connected place instead of a line of rooms.
##
## Layout (seeded by the run seed, so a seed always rebuilds the same world):
##   HUB      the opening causeway and its practice stations (OpeningGrounds) at the centre.
##   INNER    every Act I room and the Pale Merchant on a ring ~70 m round the hub, pads at
##            0-4 m.
##   OUTER    every Act II room and the Gravewarden's Hall on a ring ~125 m out, between the
##            inner rooms, pads at 2-8 m. The Gravewarden takes the outer place nearest the
##            cathedral (east).
##   CATHEDRAL the forecourt beyond the easternmost room, then the gate and the Pursuit
##            Approach main.gd builds (the side-view hand-off to the Bishop, unchanged).
## Rooms keep at least VOID_GAP of open void between them (their whole planar extent).
##
## Links: walkable bridges built with the course kit in one extra section, THE WILDS (`wilds`,
## origin 0, so its local coordinates are world ones). Every bridge lands on a room's CORE
## platforms (reachable from its entry pad and back with basic jumps), so no bridge strands
## you. BASIC links (every jump within the basic validator's reach, both ways): the hub to every
## inner room, the inner ring round, each outer room to its two nearest inner rooms, outer
## neighbours that lie close, and the two rooms nearest the forecourt to it. Styles: causeways,
## stepping stones, crumbling spans, a ferry across a long gap, a hoist when the climb is steep.
## Long bridges between rooms rest on a wild crag with a roaming creature. ADVANCED links
## (optional, never needed): a long-jump gap or a climb wall. The bridge east of the portcullis
## leaves the hub through it, so it waits for the plagued soldier (`gated`); none other does.
##
## The validator (`reach`, `world_nodes`) extends LevelSection's platform graph across the whole
## world: every room is reachable from the hub and back with basic jumps alone (gated pieces
## left out), and the forecourt too.

const HUB: int = 0
const FORECOURT: int = -1
const HUB_CENTRE: Vector2 = Vector2(0.0, -3.0)
## Planar half depth assumed for a room while laying the world out (courses span ±20.5 m).
const ROOM_HALF_DEPTH: float = 21.0
const VOID_GAP: float = 14.0
const INNER_RADIUS: float = 70.0
const OUTER_RADIUS: float = 126.0
## A bridge's jumps: rise at most STEP_MAX per hop, gaps at most GAP_MAX (validator: ~2.6 m
## reach at a 1 m rise), END_GAP off a port or landing.
const STEP_MAX: float = 0.9
const END_GAP: float = 0.9
const PORT_MARGIN: float = 1.7
const PIECE_W: float = 2.9
const LANDING: float = 4.4
const ISLAND: float = 7.5
const LONG_GAP: float = 3.8
const FORECOURT_SIZE: float = 14.0
## Deep along Z, so bridges from rooms north or south of the cathedral line meet it square on.
## The gate (main.gd, 26 m) covers the approach's 10 m with 8 m to spare each side: going round
## it would take a 6 m+ leap through the air.
const FORECOURT_DEPTH: float = 30.0
## Optional bridges (outer neighbours, the second way to the forecourt) are left out past this.
const MAX_BRIDGE: float = 85.0
const CLEARANCE: float = 2.6
## Planar distance from the camera beyond which a room is hidden / its foes sleep (main.gd).
const SHOW_RANGE: float = 170.0
const AI_RANGE: float = 70.0
## The cathedral gate opens when the Gravewarden is slain and this many room standards
## (checkpoints) are lit.
const GATE_STANDARDS: int = 6
## Creatures of the wilds (the new horror types fall back to a husk until EnemyFactory has them).
const WILD_TYPES: Array[StringName] = [&"flayed_stalker", &"stitched_brute", &"limb_spider", &"hollow_mourner",
    &"lantern_wight", &"husk", &"hound", &"knight", &"crawler", &"wraith", &"archer"]
const STYLES: Array[StringName] = [&"causeway", &"causeway", &"stones", &"crumble"]

var hub: LevelSection
var rooms: Array[LevelSection] = []
var wilds: LevelSection
## Every built bridge: {"a": node id, "b": node id, "kind": &"basic"|&"long"|&"climb",
## "style": StringName, "pieces": Array[int] (wilds platforms), "gated": bool, "length": float}.
## Node ids: HUB (0), k + 1 for rooms[k], FORECOURT (-1).
var links: Array[Dictionary] = []
## Wilds platform indices behind the portcullis (the plagued soldier's bridge).
var gated: Dictionary = {}
var forecourt: int = -1
## World x where the Pursuit Approach starts (main.gd's APPROACH_START_X + map_offset).
var approach_x: float = 0.0
## World extent of everything (rooms, hub, bridges, forecourt): Rect2(x, z, w, d).
var bounds: Rect2
var wild_foes: Array[Node3D] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _obstacles: Array[Dictionary] = []  # {"box": AABB, "owner": Variant}
var _room_boxes: Array[Dictionary] = []  # {"box": AABB, "owner": LevelSection}
var _cores: Dictionary = {}  # LevelSection -> Array[int]
var _wild_boxes: Array[AABB] = []


# --- Building -------------------------------------------------------------------------------

## Builds the whole world under `level`: every room in `scripts` round `hub_section` (already
## built at the origin), the bridges, the forecourt and the backdrops. `solids`: the level's own
## blocks round the hub (causeway, portcullis) as {"box": AABB, "owner": Variant}.
static func create(level: Node3D, hub_section: LevelSection, scripts: Array[Script], run_seed: int, solids: Array[Dictionary]) -> OpenWorld:
    var world: OpenWorld = OpenWorld.new()
    world.hub = hub_section
    world._rng.seed = run_seed * 7907 + 3
    var made: Array[LevelSection] = []
    var widths: Array[float] = []
    for script: Script in scripts:
        var room: LevelSection = script.new() as LevelSection
        room.open_world = true
        made.append(room)
        widths.append(room.width)
    var places: Array[Vector3] = plan_places(scripts, widths, run_seed, hub_section.world_rect())
    for k in made.size():
        level.add_child(made[k])
        made[k].build(places[k].x, places[k].y, places[k].z)
        world.rooms.append(made[k])
    world.wilds = LevelSection.new()
    world.wilds.id = &"wilds"
    world.wilds.title = "The Wilds"
    world.wilds.act = 1
    world.wilds.open_world = true
    world.wilds._palette = Color(0.2, 0.18, 0.2)
    world.wilds.name = "Open world: the wilds"
    level.add_child(world.wilds)
    world._collect_obstacles(solids)
    world._build_forecourt()
    world._build_links()
    world.wilds._finish_course()  # climb walls become advanced links
    GothicDressing.dress(world.wilds)  # rubble under the bridges, props on landings
    world.wilds._commit_kit()
    world._compute_bounds()
    world._attach_backdrops(level, run_seed)
    return world


## Seeded world places (x = left edge, y = pad height, z = centre line) for rooms of `widths`.
static func plan_places(scripts: Array[Script], widths: Array[float], run_seed: int, hub_rect: Rect2) -> Array[Vector3]:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = run_seed * 104729 + 7
    var n: int = scripts.size()
    var inner: Array[int] = []
    var outer: Array[int] = []
    for k in n:
        if LevelLayout.ACT1.has(scripts[k]) or scripts[k] == LevelLayout.MERCHANT:
            inner.append(k)
        else:
            outer.append(k)
    _shuffle(inner, rng)
    _shuffle(outer, rng)
    var centres: Array[Vector2] = []
    var heights: Array[float] = []
    centres.resize(n)
    heights.resize(n)
    var base: float = rng.randf() * TAU
    for slot in inner.size():
        var a: float = base + TAU * slot / inner.size() + rng.randf_range(-0.12, 0.12)
        centres[inner[slot]] = HUB_CENTRE + Vector2(cos(a), sin(a)) * (INNER_RADIUS + rng.randf_range(-4.0, 8.0))
        heights[inner[slot]] = snappedf(rng.randf_range(0.0, 4.0), 0.5)
    for slot in outer.size():
        var a: float = base + TAU * (slot + 0.5) / outer.size() + rng.randf_range(-0.12, 0.12)
        centres[outer[slot]] = HUB_CENTRE + Vector2(cos(a), sin(a)) * (OUTER_RADIUS + rng.randf_range(-6.0, 10.0))
        heights[outer[slot]] = snappedf(rng.randf_range(2.0, 8.0), 0.5)
    # The Gravewarden guards the cathedral road: the outer place furthest east.
    var elite: int = scripts.find(LevelLayout.ELITE)
    if elite >= 0 and outer.has(elite):
        var east: int = elite
        for k: int in outer:
            if centres[k].x > centres[east].x:
                east = k
        var c: Vector2 = centres[east]
        centres[east] = centres[elite]
        centres[elite] = c
        var h: float = heights[east]
        heights[east] = heights[elite]
        heights[elite] = h
    # Push overlapping rooms apart (outward from the hub) until VOID_GAP of void lies between.
    var rect: Callable = func(k: int) -> Rect2:
        return Rect2(centres[k].x - widths[k] * 0.5, centres[k].y - ROOM_HALF_DEPTH, widths[k], ROOM_HALF_DEPTH * 2.0).grow(VOID_GAP * 0.5)
    var hub_box: Rect2 = hub_rect.grow(VOID_GAP * 0.5)
    for iteration in 400:
        var moved: bool = false
        for i in n:
            if (rect.call(i) as Rect2).intersects(hub_box):
                centres[i] += (centres[i] - HUB_CENTRE).normalized() * 2.0
                moved = true
            for j in range(i + 1, n):
                if (rect.call(i) as Rect2).intersects(rect.call(j) as Rect2):
                    var far: int = j if centres[j].distance_to(HUB_CENTRE) >= centres[i].distance_to(HUB_CENTRE) else i
                    centres[far] += (centres[far] - HUB_CENTRE).normalized() * 2.0
                    moved = true
        if not moved:
            break
    var out: Array[Vector3] = []
    for k in n:
        out.append(Vector3(snappedf(centres[k].x - widths[k] * 0.5, 0.1), heights[k], snappedf(centres[k].y, 0.1)))
    return out


static func _shuffle(list: Array[int], rng: RandomNumberGenerator) -> void:
    for i in range(list.size() - 1, 0, -1):
        var j: int = rng.randi_range(0, i)
        var t: int = list[i]
        list[i] = list[j]
        list[j] = t


func _collect_obstacles(solids: Array[Dictionary]) -> void:
    _obstacles.append_array(solids)
    for sec: LevelSection in [hub] + rooms:
        for b: Dictionary in sec.dress_blocks:
            var size: Vector3 = b["size"]
            var box: AABB = AABB((b["pos"] as Vector3) - size * 0.5, size)
            if bool(b["walkable"]):
                box.size.y += CLEARANCE
            _obstacles.append({"box": box, "owner": sec})
        for a: Ambush in sec.ambushes:
            if a.ring:
                var r: float = a.ring_radius + 0.6
                _obstacles.append({"box": AABB(Vector3(a.ring_center.x - r, a.position.y - 1.0, a.ring_center.y - r), Vector3(r * 2.0, 7.5, r * 2.0)), "owner": a})
        if sec != hub:
            var wr: Rect2 = sec.world_rect().grow(2.0)
            _room_boxes.append({"box": AABB(Vector3(wr.position.x, -60.0, wr.position.y), Vector3(wr.size.x, 140.0, wr.size.y)), "owner": sec})
    var hr: Rect2 = hub.world_rect().grow(2.0)
    _room_boxes.append({"box": AABB(Vector3(hr.position.x, -60.0, hr.position.y), Vector3(hr.size.x, 140.0, hr.size.y)), "owner": hub})


## The cathedral forecourt beyond the easternmost room; the gate (main.gd) stands at its far
## edge and the Pursuit Approach begins 1 m on.
func _build_forecourt() -> void:
    var east: float = hub.world_rect().end.x
    for room: LevelSection in rooms:
        east = maxf(east, room.world_rect().end.x)
    var x0: float = snappedf(east + 34.0, 0.1)
    forecourt = wilds.plat(x0 + FORECOURT_SIZE * 0.5, 0.0, FORECOURT_SIZE, FORECOURT_DEPTH, 0.0, "Cathedral forecourt", 2.0)
    approach_x = x0 + FORECOURT_SIZE + 1.0
    wilds.hint("THE CATHEDRAL GATE\nslay the Gravewarden, light %d room standards" % GATE_STANDARDS, x0 + FORECOURT_SIZE - 3.0, 0.0, 0.0)
    var fr: Rect2 = Rect2(x0, -FORECOURT_DEPTH * 0.5, FORECOURT_SIZE, FORECOURT_DEPTH)
    _obstacles.append({"box": AABB(Vector3(fr.position.x, -2.0, fr.position.y), Vector3(fr.size.x, 2.0 + CLEARANCE, fr.size.y)), "owner": FORECOURT})
    # The approach, the arena and the Bishop beyond the gate: no bridge goes there.
    _room_boxes.append({"box": AABB(Vector3(approach_x - 1.5, -60.0, -26.0), Vector3(120.0, 140.0, 52.0)), "owner": null})


func _build_links() -> void:
    var n: int = rooms.size()
    var inner: Array[int] = []
    var outer: Array[int] = []
    for k in n:
        (inner if rooms[k].act <= 1 and rooms[k].id != &"gravewarden_hall" else outer).append(k)
    var centre: Callable = func(k: int) -> Vector2:
        return rooms[k].world_rect().get_center()
    var wanted: Array[Vector2i] = []
    # Hub to every inner room.
    for k: int in inner:
        wanted.append(Vector2i(HUB, k + 1))
    # The inner ring round (by angle about the hub).
    var by_angle: Callable = func(a: int, b: int) -> bool:
        return (centre.call(a) - HUB_CENTRE).angle() < (centre.call(b) - HUB_CENTRE).angle()
    inner.sort_custom(by_angle)
    outer.sort_custom(by_angle)
    for i in inner.size():
        wanted.append(Vector2i(inner[i] + 1, inner[(i + 1) % inner.size()] + 1))
    # Each outer room to its two nearest inner rooms.
    for k: int in outer:
        var near: Array[int] = inner.duplicate()
        near.sort_custom(func(a: int, b: int) -> bool: return (centre.call(a) as Vector2).distance_to(centre.call(k)) < (centre.call(b) as Vector2).distance_to(centre.call(k)))
        for m in mini(2, near.size()):
            wanted.append(Vector2i(near[m] + 1, k + 1))
    # Outer neighbours that lie close (optional: only if the bridge stays short).
    var optional: Dictionary = {}
    for i in outer.size():
        var a: int = outer[i]
        var b: int = outer[(i + 1) % outer.size()]
        if a != b and _rect_gap(rooms[a].world_rect(), rooms[b].world_rect()) < 60.0:
            optional[wanted.size()] = true
            wanted.append(Vector2i(a + 1, b + 1))
    # The two rooms nearest the forecourt.
    var fr: Rect2 = _port_rect(wilds, forecourt)
    var by_fore: Array[int] = []
    for k in n:
        by_fore.append(k)
    by_fore.sort_custom(func(a: int, b: int) -> bool: return _rect_gap(rooms[a].world_rect(), fr) < _rect_gap(rooms[b].world_rect(), fr))
    for m in mini(2, by_fore.size()):
        if m > 0:
            optional[wanted.size()] = true
        wanted.append(Vector2i(by_fore[m] + 1, FORECOURT))
    var done: Dictionary = {}
    # The cathedral road first: its bridges get the clearest paths.
    var order: Array[int] = []
    for w in wanted.size():
        if wanted[w].y == FORECOURT:
            order.append(w)
    for w in wanted.size():
        if wanted[w].y != FORECOURT:
            order.append(w)
    for w: int in order:
        var pair: Vector2i = wanted[w]
        var key: Vector2i = Vector2i(mini(pair.x, pair.y), maxi(pair.x, pair.y))
        if done.has(key):
            continue
        done[key] = true
        _try_link(pair.x, pair.y, &"basic", MAX_BRIDGE if optional.has(w) else INF)
    # The cathedral must be reachable: if neither forecourt bridge stood, try every room.
    for k: int in by_fore:
        if _degree(FORECOURT) > 0:
            break
        _try_link(k + 1, FORECOURT, &"basic")
    # The plagued soldier's bridge: east out of the portcullis to the nearest inner room.
    _try_gated_link(inner)
    # Every room gets at least two links (no dead ends): a room short of them links to its
    # nearest other rooms (or the hub) until it has two.
    var tried: Dictionary = {}
    for cap: float in [MAX_BRIDGE * 1.3, INF]:
        for k in n:
            _ensure_two_links(k, done, tried, cap, centre)
    # Optional advanced shortcuts (a long-jump gap, a climb wall) between near rooms, linked or
    # not: never needed, always quicker for whoever has the moves.
    var extra: Array[Vector2i] = []
    for i in n:
        for j in range(i + 1, n):
            if _rect_gap(rooms[i].world_rect(), rooms[j].world_rect()) < 80.0:
                extra.append(Vector2i(i + 1, j + 1))
    extra.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _rect_gap(rooms[a.x - 1].world_rect(), rooms[a.y - 1].world_rect()) < _rect_gap(rooms[b.x - 1].world_rect(), rooms[b.y - 1].world_rect()))
    var made: int = 0
    for pair: Vector2i in extra:
        if made >= 3:
            break
        if _try_link(pair.x, pair.y, &"long" if made % 2 == 0 else &"climb") or _try_link(pair.x, pair.y, &"climb" if made % 2 == 0 else &"long"):
            made += 1


## Links room `k` to its nearest other rooms (or the hub) until it has two links (no dead ends);
## bridges up to `cap` long.
func _ensure_two_links(k: int, done: Dictionary, tried: Dictionary, cap: float, centre: Callable) -> void:
    var n: int = rooms.size()
    var others: Array[int] = [HUB]
    for m in n:
        if m != k:
            others.append(m + 1)
    var here: Vector2 = centre.call(k)
    var where: Callable = func(node: int) -> Vector2:
        return HUB_CENTRE if node == HUB else centre.call(node - 1)
    others.sort_custom(func(a: int, b: int) -> bool: return (where.call(a) as Vector2).distance_to(here) < (where.call(b) as Vector2).distance_to(here))
    for m: int in others:
        if _degree(k + 1) >= 2:
            return
        if _linked(m, k + 1) or tried.has([m, k, cap]):
            continue
        tried[[m, k, cap]] = true
        done[Vector2i(mini(m, k + 1), maxi(m, k + 1))] = true
        _try_link(m, k + 1, &"basic", cap)


func _linked(a: int, b: int) -> bool:
    for l: Dictionary in links:
        if (int(l["a"]) == a and int(l["b"]) == b) or (int(l["a"]) == b and int(l["b"]) == a):
            return true
    return false


func _degree(node: int) -> int:
    var d: int = 0
    for l: Dictionary in links:
        if int(l["a"]) == node or int(l["b"]) == node:
            d += 1
    return d


# --- Ports and paths ----------------------------------------------------------------------

func _section(node: int) -> LevelSection:
    if node == HUB:
        return hub
    if node == FORECOURT:
        return wilds
    return rooms[node - 1]


## Planar rect (world x, z) of platform `i` of `sec`.
static func _port_rect(sec: LevelSection, i: int) -> Rect2:
    var r: Rect2 = sec.platforms[i]
    var z: Vector2 = sec.platform_z[i]
    return Rect2(r.position.x + sec.origin_x, z.x, r.size.x, z.y - z.x)


## Where a bridge may land on `node`: its core platforms that hold still and are at least 2.4 m
## across ({"sec", "i", "rect", "top"}).
func _ports(node: int, exclude_gate: bool = true) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    if node == FORECOURT:
        out.append({"sec": wilds, "i": forecourt, "rect": _port_rect(wilds, forecourt), "top": wilds.platforms[forecourt].position.y})
        return out
    var sec: LevelSection = _section(node)
    if not _cores.has(sec):
        _cores[sec] = sec.core_platforms()
    for i: int in _cores[sec]:
        if not sec.platform_static[i]:
            continue
        var rect: Rect2 = _port_rect(sec, i)
        if rect.size.x < 2.4 or rect.size.y < 2.4:
            continue
        if exclude_gate and sec == hub and _is_gate_causeway(rect):
            continue  # the portcullis bridge only (see _try_gated_link)
        out.append({"sec": sec, "i": i, "rect": rect, "top": sec.platforms[i].position.y})
    return out


## The hub's gate causeway (x 9.2..18.2): behind the plagued soldier, before the portcullis.
static func _is_gate_causeway(rect: Rect2) -> bool:
    return absf(rect.position.x - 9.2) < 0.2 and absf(rect.end.x - 18.2) < 0.2


static func _rect_gap(a: Rect2, b: Rect2) -> float:
    var dx: float = maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
    var dz: float = maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
    return Vector2(dx, dz).length()


## Candidate polylines (world x/z points) from port rect `ra` to port rect `rb`: straight along X
## or Z (with a landing midway once long), or an L (a landing at the corner).
static func _paths(ra: Rect2, rb: Rect2) -> Array:
    var out: Array = []
    var ca: Vector2 = ra.get_center()
    var cb: Vector2 = rb.get_center()
    var m: float = PORT_MARGIN
    var lo: float = maxf(ra.position.y, rb.position.y) + m
    var hi: float = minf(ra.end.y, rb.end.y) - m
    if hi >= lo:
        var z: float = clampf((ca.y + cb.y) * 0.5, lo, hi)
        if rb.position.x > ra.end.x:
            out.append(_straight(Vector2(ra.end.x, z), Vector2(rb.position.x, z)))
        elif ra.position.x > rb.end.x:
            out.append(_straight(Vector2(ra.position.x, z), Vector2(rb.end.x, z)))
    lo = maxf(ra.position.x, rb.position.x) + m
    hi = minf(ra.end.x, rb.end.x) - m
    if hi >= lo:
        var x: float = clampf((ca.x + cb.x) * 0.5, lo, hi)
        if rb.position.y > ra.end.y:
            out.append(_straight(Vector2(x, ra.end.y), Vector2(x, rb.position.y)))
        elif ra.position.y > rb.end.y:
            out.append(_straight(Vector2(x, ra.position.y), Vector2(x, rb.end.y)))
    # L: along X out of A, then along Z into B.
    var z1: float = clampf(cb.y, ra.position.y + m, ra.end.y - m)
    var x1: float = clampf(ca.x, rb.position.x + m, rb.end.x - m)
    if (z1 < rb.position.y - LANDING or z1 > rb.end.y + LANDING) and (x1 > ra.end.x + LANDING or x1 < ra.position.x - LANDING):
        var sx: float = ra.end.x if x1 > ra.end.x else ra.position.x
        var ez: float = rb.position.y if z1 < rb.position.y else rb.end.y
        out.append([Vector2(sx, z1), Vector2(x1, z1), Vector2(x1, ez)])
    # L: along Z out of A, then along X into B.
    var x2: float = clampf(cb.x, ra.position.x + m, ra.end.x - m)
    var z2: float = clampf(ca.y, rb.position.y + m, rb.end.y - m)
    if (x2 < rb.position.x - LANDING or x2 > rb.end.x + LANDING) and (z2 > ra.end.y + LANDING or z2 < ra.position.y - LANDING):
        var sz: float = ra.end.y if z2 > ra.end.y else ra.position.y
        var ex: float = rb.position.x if x2 < rb.position.x else rb.end.x
        out.append([Vector2(x2, sz), Vector2(x2, z2), Vector2(ex, z2)])
    return out


static func _straight(a: Vector2, b: Vector2) -> Array:
    if a.distance_to(b) >= 18.0:
        return [a, (a + b) * 0.5, b]  # a landing midway
    return [a, b]


# --- Planning a bridge ----------------------------------------------------------------------

## Tries to join `a` and `b` with a bridge of `kind` no longer than `max_len`; true if one was
## built.
func _try_link(a: int, b: int, kind: StringName, max_len: float = INF) -> bool:
    var pa: Array[Dictionary] = _ports(a)
    var pb: Array[Dictionary] = _ports(b)
    var combos: Array = []
    for p: Dictionary in pa:
        for q: Dictionary in pb:
            var dy: float = float(q["top"]) - float(p["top"])
            if kind == &"climb" and absf(dy) < 2.6:
                continue
            var d: float = _rect_gap(p["rect"], q["rect"])
            if d < 6.0:
                continue
            combos.append([d + absf(dy) * 1.5 - minf((p["rect"] as Rect2).get_area() + (q["rect"] as Rect2).get_area(), 120.0) * 0.02, p, q])
    combos.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
    var style: StringName = STYLES[_rng.randi() % STYLES.size()]
    for k in mini(30, combos.size()):
        var p: Dictionary = combos[k][1]
        var q: Dictionary = combos[k][2]
        if kind == &"climb" and float(q["top"]) < float(p["top"]):
            var t: Dictionary = p  # climb UP: start from the lower port
            p = q
            q = t
        for pts: Array in _paths(p["rect"], q["rect"]):
            for hoist: bool in [false, true]:
                var plan: Dictionary = _plan(pts, p, q, kind, style, hoist, a != HUB and b != HUB)
                if plan.is_empty() or float(plan["length"]) > max_len or not _clear(plan, p["sec"], q["sec"], []):
                    continue
                _build(plan, a, b, kind, style, false)
                return true
    return false


## The bridge east out of the portcullis (the hub's gate causeway): only once the plagued
## soldier falls.
func _try_gated_link(inner: Array[int]) -> void:
    var gate: Dictionary = {}
    for p: Dictionary in _ports(HUB, false):
        if _is_gate_causeway(p["rect"]):
            gate = p
    if gate.is_empty():
        return
    var targets: Array[int] = inner.duplicate()
    targets.sort_custom(func(x: int, y: int) -> bool: return _rect_gap(gate["rect"], rooms[x].world_rect()) < _rect_gap(gate["rect"], rooms[y].world_rect()))
    for k: int in targets:
        var qs: Array[Dictionary] = _ports(k + 1)
        qs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return _rect_gap(gate["rect"], x["rect"]) < _rect_gap(gate["rect"], y["rect"]))
        for q: Dictionary in qs.slice(0, 12):
            for pts: Array in _paths(gate["rect"], q["rect"]):
                if (pts[0] as Vector2).x < 18.0:
                    continue  # must leave through the portcullis (east face)
                for hoist: bool in [false, true]:
                    var plan: Dictionary = _plan(pts, gate, q, &"basic", &"causeway", hoist, false)
                    if plan.is_empty() or not _clear(plan, hub, q["sec"], [&"portcullis"]):
                        continue
                    _build(plan, HUB, k + 1, &"basic", &"causeway", true)
                    return


## Lays a bridge along `pts` from port `p` to port `q`: the elements (pieces, landing, lifts,
## climb wall), their tops, and each hop checked against the validator both ways. Empty if the
## path can't be made with this kind / hoist choice.
func _plan(pts: Array, p: Dictionary, q: Dictionary, kind: StringName, style: StringName, hoist: bool, wild: bool) -> Dictionary:
    var y0: float = p["top"]
    var y1: float = q["top"]
    var dy: float = y1 - y0
    var elements: Array[Dictionary] = []  # {"type", "rect": Rect2 (x, z, w, d), "top", "top2"}
    var hops: Array[StringName] = []  # the move INTO each element, then into q
    var length: float = 0.0
    for i in pts.size() - 1:
        length += (pts[i] as Vector2).distance_to(pts[i + 1])
    var has_mid: bool = pts.size() == 3
    if hoist and not has_mid:
        return {}
    var mid_size: float = ISLAND if (wild and has_mid and length >= 26.0 and not hoist) else LANDING
    var legs: Array = []
    if has_mid:
        legs.append([pts[0], pts[1], 0.0, mid_size * 0.5])
        legs.append([pts[1], pts[2], mid_size * 0.5, 0.0])
    else:
        legs.append([pts[0], pts[1], 0.0, 0.0])
    for li in legs.size():
        var leg: Array = legs[li]
        var a: Vector2 = leg[0]
        var b: Vector2 = leg[1]
        var dir: Vector2 = (b - a).normalized()
        var start: float = float(leg[2])
        var stop: float = a.distance_to(b) - float(leg[3])
        var first_gap: float = END_GAP
        var last_gap: float = END_GAP
        if kind == &"long" and li == 0:
            first_gap = LONG_GAP
        if kind == &"climb" and li == legs.size() - 1:
            last_gap = 0.0
        var climb_len: float = 1.6 if (kind == &"climb" and li == legs.size() - 1) else 0.0
        var lo: float = start + first_gap
        var hi: float = stop - last_gap - climb_len - (END_GAP if climb_len > 0.0 else 0.0)
        var leg_style: StringName = style
        var ferry: Vector2 = Vector2.INF
        if style == &"crumble" and not wild:
            leg_style = &"causeway"
        if style == &"causeway" and hi - lo >= 24.0 and _rng.randf() < 0.45:
            var c: float = (lo + hi) * 0.5
            ferry = Vector2(c - 5.5, c + 5.5)
        var spans: Array[Vector2] = []
        if ferry == Vector2.INF:
            spans.append(Vector2(lo, hi))
        else:
            spans.append(Vector2(lo, ferry.x))
            spans.append(Vector2(ferry.y, hi))
        for si in spans.size():
            var span: Vector2 = spans[si]
            var first_hop: StringName = &"jump"
            if si == 0 and li == 0 and kind == &"long":
                first_hop = &"long"
            if si == 1:
                # The ferry: a platform riding the gap, its ends flush with the spans.
                var fa: float = ferry.x + 0.3 + 1.5
                var fb: float = ferry.y - 0.3 - 1.5
                elements.append({"type": &"ferry_a", "rect": _seg_rect(a, dir, fa - 1.5, fa + 1.5, 3.0), "top": 0.0})
                hops.append(&"jump")
                elements.append({"type": &"ferry_b", "rect": _seg_rect(a, dir, fb - 1.5, fb + 1.5, 3.0), "top": 0.0})
                hops.append(&"ride")
                first_hop = &"jump"
            var pieces: Array[Vector2] = _fill(span.x, span.y, leg_style)  # none: one hop over (checked below)
            for pi in pieces.size():
                var seg: Vector2 = pieces[pi]
                var t: StringName = &"piece"
                if leg_style == &"stones":
                    t = &"stone"
                elif leg_style == &"crumble" and (pi % 2 == 1):
                    t = &"crumble"
                elements.append({"type": t, "rect": _seg_rect(a, dir, seg.x, seg.y, PIECE_W if t != &"stone" else minf(seg.y - seg.x, 2.9)), "top": 0.0})
                hops.append(first_hop if pi == 0 else &"jump")
            if pieces.is_empty() and first_hop == &"long":
                return {}
        if climb_len > 0.0:
            elements.append({"type": &"wall", "rect": _seg_rect(a, dir, stop - climb_len, stop, 3.2), "top": 0.0})
            hops.append(&"climb")
        if has_mid and li == 0:
            var c: Vector2 = pts[1]
            var size: float = 3.4 if hoist else mid_size  # a hoist rides a 3.4 m grate in the landing's place
            elements.append({"type": &"hoist" if hoist else (&"island" if mid_size == ISLAND else &"landing"), "rect": Rect2(c.x - size * 0.5, c.y - size * 0.5, size, size), "top": 0.0, "top2": 0.0})
            hops.append(&"jump")
            if hoist:
                hops.append(&"ride")  # placeholder for the ride inside the hoist (see below)
    hops.append(&"walk" if kind == &"climb" else &"jump")  # into q (off a climb wall's top: a step)
    # Tops: jump hops share the rise (at most STEP_MAX each); a hoist rides the rest, a climb
    # wall climbs all of it; long jumps and ferries stay level.
    var jumps: int = 0
    for h: StringName in hops:
        if h == &"jump":
            jumps += 1
    var step: float = 0.0
    var ride: float = 0.0
    var climb_rise: float = 0.0
    if kind == &"climb":
        climb_rise = dy
        if dy < 2.6 or dy > 9.0:
            return {}
    elif hoist:
        step = signf(dy) * minf(absf(dy) / maxf(jumps, 1), STEP_MAX * 0.6)
        ride = dy - step * jumps
        if absf(ride) < 1.5:
            return {}  # no need for a hoist
    else:
        step = dy / maxf(jumps, 1)
        if absf(step) > STEP_MAX:
            return {}
    var y: float = y0
    var hop: int = 0
    for e: Dictionary in elements:
        var h: StringName = hops[hop]
        if h == &"jump":
            y += step
        elif h == &"climb":
            e["top"] = y + climb_rise  # the wall's walkable top meets q
            e["bottom"] = y - 1.0
            hop += 1
            continue
        e["top"] = snappedf(y, 0.05)
        hop += 1
        if e["type"] == &"hoist":
            y += ride
            e["top2"] = snappedf(y, 0.05)
            hop += 1  # the ride
    var plan: Dictionary = {"elements": elements, "p": p, "q": q, "length": length}
    if not _hops_ok(plan, kind):
        return {}
    return plan


## Splits [lo, hi] (metres along a leg) into pieces of the style's length with jumpable gaps.
func _fill(lo: float, hi: float, style: StringName) -> Array[Vector2]:
    var out: Array[Vector2] = []
    var room: float = hi - lo
    if room <= 0.0:
        return out
    var piece: float = {&"causeway": 6.0, &"stones": 2.6, &"crumble": 3.4}.get(style, 5.0)
    var gap: float = {&"causeway": 0.9, &"stones": 1.3, &"crumble": 1.0}.get(style, 1.0)
    if room < 1.8:
        return out
    var count: int = maxi(1, roundi((room + gap) / (piece + gap)))
    var piece_len: float = (room - (count - 1) * gap) / count
    while piece_len < 1.8 and count > 1:
        count -= 1
        piece_len = (room - (count - 1) * gap) / count
    var x: float = lo
    for k in count:
        out.append(Vector2(x, x + piece_len))
        x += piece_len + gap
    return out


## Rect (x, z, w, d) of the stretch [s0, s1] along a leg from `a` in axis direction `dir`,
## `width` across.
static func _seg_rect(a: Vector2, dir: Vector2, s0: float, s1: float, width: float) -> Rect2:
    var p0: Vector2 = a + dir * s0
    var p1: Vector2 = a + dir * s1
    var lo: Vector2 = Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y))
    var hi: Vector2 = Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y))
    if absf(dir.x) > 0.5:
        return Rect2(lo.x, lo.y - width * 0.5, hi.x - lo.x, width)
    return Rect2(lo.x - width * 0.5, lo.y, width, hi.y - lo.y)


## Every jump of the plan works with the validator both ways (a long-jump gap needs the long
## jump, by design); every element has room.
func _hops_ok(plan: Dictionary, kind: StringName) -> bool:
    var seq: Array[Dictionary] = []
    var p: Dictionary = plan["p"]
    var q: Dictionary = plan["q"]
    seq.append({"rect": p["rect"], "top": p["top"]})
    for e: Dictionary in plan["elements"]:
        var r: Rect2 = e["rect"]
        if r.size.x < 1.5 or r.size.y < 1.5:
            return false
        seq.append(e)
    seq.append({"rect": q["rect"], "top": q["top"]})
    for k in seq.size() - 1:
        var a: Dictionary = seq[k]
        var b: Dictionary = seq[k + 1]
        var t: StringName = b.get("type", &"port")
        var ta: float = float(a.get("top2", a["top"])) if a.get("type", &"") == &"hoist" else float(a["top"])
        if t == &"ferry_b" or t == &"wall" or (a.get("type", &"") == &"wall"):
            continue  # a ride, a climb up, the step off the wall's top onto the port
        var ra: Rect2 = Rect2((a["rect"] as Rect2).position.x, ta, (a["rect"] as Rect2).size.x, 0.0)
        var za: Vector2 = Vector2((a["rect"] as Rect2).position.y, (a["rect"] as Rect2).end.y)
        var rb: Rect2 = Rect2((b["rect"] as Rect2).position.x, float(b["top"]), (b["rect"] as Rect2).size.x, 0.0)
        var zb: Vector2 = Vector2((b["rect"] as Rect2).position.y, (b["rect"] as Rect2).end.y)
        if kind == &"long" and k == 0:
            if LevelSection.can_jump(ra, rb, za, zb) or not LevelSection.can_jump_adv(ra, rb, za, zb) or not LevelSection.can_jump_adv(rb, ra, zb, za):
                return false
            continue
        if not LevelSection.can_jump(ra, rb, za, zb) or not LevelSection.can_jump(rb, ra, zb, za):
            return false
    return true


## True if no element of `plan` (with head room) hits a solid, a fight ring or another room's
## air space; `ignore` lists obstacle owners to skip (the portcullis for the soldier's bridge).
func _clear(plan: Dictionary, sec_a: LevelSection, sec_b: LevelSection, ignore: Array) -> bool:
    var boxes: Array[AABB] = _element_boxes(plan)
    var whole: AABB = boxes[0]
    for b: AABB in boxes:
        whole = whole.merge(b)
    for rb: Dictionary in _room_boxes:
        if rb["owner"] == sec_a or rb["owner"] == sec_b:
            continue
        if (rb["box"] as AABB).intersects(whole):
            for b: AABB in boxes:
                if (rb["box"] as AABB).intersects(b):
                    return false
    var near: Array[AABB] = []
    for o: Dictionary in _obstacles:
        if ignore.has(o["owner"]):
            continue
        if typeof(o["owner"]) == TYPE_OBJECT and o["owner"] is Ambush:
            var ring: Ambush = o["owner"]
            var lands_inside: bool = false
            for port: Dictionary in [plan["p"], plan["q"]]:
                var c: Vector2 = (port["rect"] as Rect2).get_center()
                if ring.inside_ring(Vector3(c.x, 0.0, c.y)):
                    lands_inside = true
            if lands_inside:
                continue  # a bridge onto an arena's own floor: its walls seal the fight
        if (o["box"] as AABB).intersects(whole):
            near.append(o["box"])
    for b: AABB in boxes:
        for o: AABB in near:
            if o.intersects(b):
                return false
    for w: AABB in _wild_boxes:
        if w.intersects(whole):
            for b: AABB in boxes:
                if w.intersects(b):
                    return false
    return true


## The solid volume (plus head room) of every element, a little wider than drawn.
static func _element_boxes(plan: Dictionary) -> Array[AABB]:
    var out: Array[AABB] = []
    for e: Dictionary in plan["elements"]:
        # A climb wall stands flush against its port: test its core, not a margin round it.
        var r: Rect2 = (e["rect"] as Rect2).grow(-0.35 if e["type"] == &"wall" else 0.3)
        var top: float = e["top"]
        var bottom: float = top - (7.0 if e["type"] == &"stone" else 1.6)
        var head: float = top + CLEARANCE
        if e["type"] == &"hoist":
            head = maxf(top, float(e["top2"])) + CLEARANCE
            bottom = minf(top, float(e["top2"])) - 1.0
        elif e["type"] == &"wall":
            bottom = float(e["bottom"])
        out.append(AABB(Vector3(r.position.x, bottom, r.position.y), Vector3(r.size.x, head - bottom, r.size.y)))
    # A ferry sweeps the gap between its two ends.
    for k in plan["elements"].size():
        var e: Dictionary = plan["elements"][k]
        if e["type"] == &"ferry_a":
            var f: Dictionary = plan["elements"][k + 1]
            var r: Rect2 = (e["rect"] as Rect2).merge(f["rect"]).grow(0.3)
            out.append(AABB(Vector3(r.position.x, float(e["top"]) - 1.0, r.position.y), Vector3(r.size.x, 1.0 + CLEARANCE, r.size.y)))
    return out


# --- Building a planned bridge --------------------------------------------------------------

func _build(plan: Dictionary, a: int, b: int, kind: StringName, style: StringName, behind_gate: bool) -> void:
    var w: LevelSection = wilds
    var first: int = w.platforms.size()
    var islands: Array[Dictionary] = []
    var elements: Array = plan["elements"]
    for k in elements.size():
        var e: Dictionary = elements[k]
        var r: Rect2 = e["rect"]
        var c: Vector2 = r.get_center()
        var top: float = e["top"]
        match e["type"]:
            &"piece":
                w.plat(c.x, c.y, r.size.x, r.size.y, top, "Bone causeway", 1.0)
            &"stone":
                w.plat(c.x, c.y, r.size.x, r.size.y, top, "Stepping stone", 6.0)
            &"crumble":
                w.crumble(c.x, c.y, top, r.size.x, r.size.y)
            &"landing":
                w.plat(c.x, c.y, r.size.x, r.size.y, top, "Bridge landing", 1.5)
            &"island":
                w.plat(c.x, c.y, r.size.x, r.size.y, top, "Wild crag", 4.0)
                islands.append(e)
            &"hoist":
                var lift: MovingPlatform = w.lift(Vector3(c.x, top, c.y), Vector3(c.x, float(e["top2"]), c.y), r.size.x, r.size.y, 1.4 + absf(float(e["top2"]) - top) * 0.35)
                lift.name = "Bone hoist"
            &"ferry_a":
                var f: Dictionary = elements[k + 1]
                var fc: Vector2 = (f["rect"] as Rect2).get_center()
                var ferry: MovingPlatform = w.lift(Vector3(c.x, top, c.y), Vector3(fc.x, float(f["top"]), fc.y), 3.0, 3.0, 2.6)
                ferry.name = "Bone ferry"
            &"wall":
                w.climb(c.x, c.y, r.size.x, r.size.y, float(e["bottom"]), top, "Bone climb")
        _wild_boxes.append(AABB(Vector3(r.position.x - 0.5, top - 8.0, r.position.y - 0.5), Vector3(r.size.x + 1.0, 8.0 + CLEARANCE + 0.5, r.size.y + 1.0)))
    var pieces: Array[int] = []
    for i in range(first, w.platforms.size()):
        pieces.append(i)
        if behind_gate:
            gated[i] = true
    # Signs for the advanced links.
    if kind == &"long" and not elements.is_empty():
        var e0: Rect2 = elements[0]["rect"]
        w.hint("LONG JUMP\nrun, Ctrl, Space", e0.get_center().x, e0.get_center().y, float(elements[0]["top"]))
    elif kind == &"climb":
        for e: Dictionary in elements:
            if e["type"] == &"wall":
                var wr: Rect2 = e["rect"]
                w.hint("CLIMB", wr.get_center().x, wr.get_center().y, float(e["bottom"]) + 1.0)
    # The wilds: a creature on most crags, and a Bone Shard.
    for e: Dictionary in islands:
        var c: Vector2 = (e["rect"] as Rect2).get_center()
        var top: float = e["top"]
        if _rng.randf() < 0.8:
            var type: StringName = WILD_TYPES[_rng.randi() % WILD_TYPES.size()]
            var foe: Node3D = w.foe(type, c.x + 1.2, c.y - 1.2, top)
            wild_foes.append(foe)
        w.shard(c.x - 2.0, c.y + 2.0, top, 3)
    links.append({"a": a, "b": b, "kind": kind, "style": style, "pieces": pieces, "gated": behind_gate, "length": plan["length"]})


func _compute_bounds() -> void:
    var box: Rect2 = hub.world_rect()
    for room: LevelSection in rooms:
        box = box.merge(room.world_rect())
    box = box.merge(wilds.world_rect())
    bounds = box


## Backdrops (DEC-055) for the open world: near-only decor round every room and the hub, kept
## clear of every other room and bridge, plus one full backdrop round the whole world.
func _attach_backdrops(level: Node3D, run_seed: int) -> void:
    var keep: Array[AABB] = []
    for sec: LevelSection in [hub] + rooms:
        var r: Rect2 = sec.world_rect().grow(3.0)
        keep.append(AABB(Vector3(r.position.x, sec.origin_y - 6.0, r.position.y), Vector3(r.size.x, 36.0, r.size.y)))
    for i in wilds.platforms.size():
        var r: Rect2 = _port_rect(wilds, i).grow(2.5)
        var top: float = wilds.platforms[i].position.y
        keep.append(AABB(Vector3(r.position.x, top - 6.0, r.position.y), Vector3(r.size.x, 12.0, r.size.y)))
    keep.append(AABB(Vector3(approach_x - 20.0, -6.0, -30.0), Vector3(140.0, 40.0, 60.0)))
    Backdrop3D.keep_out = keep
    for sec: LevelSection in [hub] + rooms:
        sec.backdrop = Backdrop3D.attach(sec, true)
        sec.backdrop.managed = true
    Backdrop3D.keep_out = []
    var top: float = 0.0
    for room: LevelSection in rooms:
        top = maxf(top, room.height_range().y)
    var span: Rect2 = bounds.merge(Rect2(approach_x, -8.0, 90.0, 16.0))
    Backdrop3D.spawn(level, Vector2(span.position.x, span.end.x), Vector2(span.position.y, span.end.y), top, 1, run_seed ^ 0x77, level)


# --- The world graph (validator) -------------------------------------------------------------

## Every walkable surface of the world as {"sec": LevelSection, "i": int, "r": Rect2 (world x,
## world top, width), "z": Vector2 (world z range)}. With `gate_open`, the Pursuit Approach's
## first causeway is appended last (sec null), so the cathedral counts as reachable.
func world_nodes(gate_open: bool = false) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for sec: LevelSection in [hub] + rooms + [wilds]:
        for i in sec.platforms.size():
            var r: Rect2 = sec.platforms[i]
            out.append({"sec": sec, "i": i, "r": Rect2(r.position.x + sec.origin_x, r.position.y, r.size.x, 0.0), "z": sec.platform_z[i]})
    if gate_open:
        out.append({"sec": null, "i": -1, "r": Rect2(approach_x, 0.0, 8.0, 0.0), "z": Vector2(-Lane.DEPTH_3D * 0.5, Lane.DEPTH_3D * 0.5)})
    return out


## Adjacency over `nodes` (indices): basic jumps and rides; `advanced` adds climbs, kick shafts,
## ledge grabs and long jumps. `skip_gated` leaves the portcullis bridge out.
func adjacency(nodes: Array[Dictionary], advanced: bool, skip_gated: bool) -> Array[PackedInt32Array]:
    var adj: Array[PackedInt32Array] = []
    var index: Dictionary = {}  # [sec, i] -> node
    for n in nodes.size():
        adj.append(PackedInt32Array())
        index[[nodes[n]["sec"], nodes[n]["i"]]] = n
    var dead: Dictionary = {}
    if skip_gated:
        for i: int in gated:
            dead[index[[wilds, i]]] = true
    # Rides and the sections' own advanced links.
    for sec: LevelSection in [hub] + rooms + [wilds]:
        for l: Vector2i in sec.links:
            var a: int = index[[sec, l.x]]
            var b: int = index[[sec, l.y]]
            adj[a].append(b)
            adj[b].append(a)
        if advanced:
            for l: Vector2i in sec.adv_links:
                adj[index[[sec, l.x]]].append(index[[sec, l.y]])
    # Jumps between any two surfaces whose planar gap is within a long jump (grid buckets).
    var cell: float = 8.0
    var grid: Dictionary = {}
    for n in nodes.size():
        var r: Rect2 = nodes[n]["r"]
        var z: Vector2 = nodes[n]["z"]
        for cx in range(floori((r.position.x - 5.0) / cell), floori((r.end.x + 5.0) / cell) + 1):
            for cz in range(floori((z.x - 5.0) / cell), floori((z.y + 5.0) / cell) + 1):
                var key: Vector2i = Vector2i(cx, cz)
                if not grid.has(key):
                    grid[key] = []
                (grid[key] as Array).append(n)
    var tested: Dictionary = {}
    for key: Vector2i in grid:
        var list: Array = grid[key]
        for a: int in list:
            for b: int in list:
                if a == b or tested.has(Vector2i(a, b)):
                    continue
                tested[Vector2i(a, b)] = true
                var ra: Rect2 = nodes[a]["r"]
                var rb: Rect2 = nodes[b]["r"]
                var za: Vector2 = nodes[a]["z"]
                var zb: Vector2 = nodes[b]["z"]
                if LevelSection._gap(ra, rb, za, zb) > 5.0 or rb.position.y - ra.position.y > 3.2:
                    continue
                if LevelSection.can_jump(ra, rb, za, zb) or (advanced and LevelSection.can_jump_adv(ra, rb, za, zb)):
                    adj[a].append(b)
    if not dead.is_empty():
        for n in nodes.size():
            if dead.has(n):
                adj[n] = PackedInt32Array()
                continue
            var keep: PackedInt32Array = PackedInt32Array()
            for m: int in adj[n]:
                if not dead.has(m):
                    keep.append(m)
            adj[n] = keep
    return adj


## Nodes reachable from `start` over `adj` (`reverse`: nodes that can reach `start`).
static func reach(adj: Array[PackedInt32Array], start: int, reverse: bool = false) -> Dictionary:
    if not reverse:
        return LevelSection._bfs(start, adj)
    var back: Array[PackedInt32Array] = []
    for n in adj.size():
        back.append(PackedInt32Array())
    for n in adj.size():
        for m: int in adj[n]:
            back[m].append(n)
    return LevelSection._bfs(start, back)


## Node index of platform `i` of `sec` in `nodes`.
static func node_of(nodes: Array[Dictionary], sec: LevelSection, i: int) -> int:
    for n in nodes.size():
        if nodes[n]["sec"] == sec and int(nodes[n]["i"]) == i:
            return n
    return -1


## The room graph's independent loops (links - nodes + 1 for a connected graph): > 0 means you
## can go round, not just back and forth.
func loop_count() -> int:
    var nodes: Dictionary = {}
    for l: Dictionary in links:
        nodes[l["a"]] = true
        nodes[l["b"]] = true
    return links.size() - nodes.size() + 1


## The room (or hub) whose planar extent holds `p` within `margin`, at a height near its pads
## and courses; null in the wilds.
func room_at(p: Vector3, margin: float = 0.0) -> LevelSection:
    for sec: LevelSection in rooms:
        var r: Rect2 = sec.world_rect().grow(margin)
        if r.has_point(Vector2(p.x, p.z)) and p.y > sec.origin_y - 4.0 and p.y < sec.origin_y + 16.0:
            return sec
    return null

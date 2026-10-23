"""BLOODBOUND gothic props + hazard visuals (DEC-057), built headless and original.

  "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b \
      --python tools/blender/build_props.py -- <repo_root> [asset names...] [--sheet out.png]

Writes assets/models/props/<name>.glb. Coordinates are Godot metres (see gothic_common.G):
origin at the ground contact unless noted, front = +Z. Material slot names are roles mapped
to PBR materials in scripts/art/gothic_props.gd.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix
import gothic_common as C
from gothic_common import box, cyl, sphere, ico, torus, tube, lathe, prism_profile, organic, join, boolean, finish, export, set_role

OUT = "assets/models/props/"
BUILT = {}


def asset(fn):
    BUILT[fn.__name__] = fn
    return fn


# --- Bones -------------------------------------------------------------------------------

def skull_obj(seed=0, voxel=0.0055, ratio=0.35, jaw=True, tris=None):
    """A human skull ~0.24 m long, facing +Z, resting on y=0. `tris` = triangle budget."""
    r = random.Random(seed)
    parts = [
        sphere(0.1, (0, 0.122, -0.016), (0.9, 0.92, 1.1), "bone", 20, 12),           # cranium
        sphere(0.066, (0, 0.094, 0.052), (1.08, 0.82, 0.8), "bone", 16, 8),          # brow
        sphere(0.05, (0, 0.06, 0.07), (1.0, 0.9, 0.85), "bone", 12, 6),              # mid face
        sphere(0.022, (-0.06, 0.068, 0.066), (1.0, 0.75, 1.3), "bone", 10, 6),       # cheekbones
        sphere(0.022, (0.06, 0.068, 0.066), (1.0, 0.75, 1.3), "bone", 10, 6),
        tube([(-0.075, 0.07, 0.0), (-0.07, 0.066, 0.045)], 0.009, 6, "bone"),       # zygomatic arches
        tube([(0.075, 0.07, 0.0), (0.07, 0.066, 0.045)], 0.009, 6, "bone"),
        sphere(0.034, (0, 0.04, 0.088), (1.1, 0.7, 0.75), "bone", 12, 6),            # maxilla
    ]
    if jaw:
        parts.append(tube([(-0.056, 0.07, 0.0), (-0.052, 0.024, 0.03), (-0.03, 0.012, 0.085), (0, 0.009, 0.1),
                           (0.03, 0.012, 0.085), (0.052, 0.024, 0.03), (0.056, 0.07, 0.0)],
                          [0.01, 0.014, 0.015, 0.017, 0.015, 0.014, 0.01], 8, "bone"))
    sk = organic(parts, voxel=voxel, smooth=3, smooth_factor=0.5, name="skull", role="bone")
    # Eye sockets (squarish, deep), nasal cavity, temple hollows: dark cutters (material
    # transferred so the holes read black in any light).
    for sx in (-1, 1):
        boolean(sk, sphere(0.024, (sx * 0.034, 0.092, 0.112), (1.05, 0.85, 1.25), "dark", 12, 8))
        boolean(sk, sphere(0.03, (sx * 0.088, 0.1, 0.01), (0.5, 1.0, 1.0), "bone", 10, 6), transfer=False)
    boolean(sk, prism_profile([(-0.012, 0.0), (0.012, 0.0), (0.0, 0.03)], 0.06, "dark", loc=(0, 0.054, 0.12)))
    # Upper teeth (and lower ones on a jaw).
    teeth = []
    for k in range(8):
        a = (k - 3.5) / 3.5 * 0.9
        teeth.append(box((0.009, 0.014, 0.008), (math.sin(a) * 0.034, 0.03, 0.084 + math.cos(a) * 0.022), (0, a, 0), "bone"))
        if jaw:
            teeth.append(box((0.008, 0.012, 0.007), (math.sin(a) * 0.03, 0.017, 0.082 + math.cos(a) * 0.02), (0, a, 0), "bone"))
    sk = join([sk] + teeth, "skull")
    budget = tris if tris else int(1600 * ratio / 0.35)
    C.decimate_to(sk, budget)
    C.jitter(sk, 0.0015, seed, 30.0)
    return sk


def bone_obj(length=0.42, seed=0, role="bone", voxel=0.006):
    r = random.Random(seed)
    h = length * 0.5
    bend = r.uniform(-0.01, 0.01)
    parts = [tube([(-h + 0.03, 0, 0), (0, bend, 0), (h - 0.03, 0, 0)], [0.017, 0.014, 0.017], 10, role)]
    for sx in (-1, 1):
        parts.append(sphere(0.026, (sx * (h - 0.02), 0.0, 0.016), (1, 1, 1), role, 10, 6))
        parts.append(sphere(0.024, (sx * (h - 0.025), 0.0, -0.016), (1, 1, 1), role, 10, 6))
    b = organic(parts, voxel=voxel, smooth=2, name="bone", role=role)
    C.decimate_to(b, 260)
    return b


@asset
def skull():
    return skull_obj(1, tris=1400)


@asset
def bone():
    return bone_obj()


def _pile(seed, n_skulls, n_bones, spread=0.42):
    r = random.Random(seed)
    objs = []
    placed = []
    for k in range(n_skulls):
        for _ in range(20):
            a = r.uniform(0, math.tau)
            d = r.uniform(0.0, spread) if k > 0 else 0.0
            p = (math.cos(a) * d, 0.0, math.sin(a) * d)
            if all((p[0] - q[0]) ** 2 + (p[2] - q[2]) ** 2 > 0.17 ** 2 for q in placed):
                break
        lift = 0.0
        if k >= 3 and r.random() < 0.6 and placed:
            q = placed[r.randrange(len(placed))]
            p = ((p[0] + q[0]) * 0.5, 0.0, (p[2] + q[2]) * 0.5)
            lift = 0.12
        placed.append(p)
        sk = skull_obj(seed * 31 + k, jaw=r.random() < 0.6, tris=700)
        s = r.uniform(0.85, 1.12)
        C.place(sk, (p[0], lift, p[2]), (r.uniform(-0.35, 0.2), r.uniform(0, math.tau), r.uniform(-0.25, 0.25)), (s, s, s))
        objs.append(sk)
    for k in range(n_bones):
        b = bone_obj(r.uniform(0.3, 0.46), seed * 17 + k)
        a = r.uniform(0, math.tau)
        d = r.uniform(0.15, spread + 0.12)
        C.place(b, (math.cos(a) * d, 0.02 + 0.02 * (k % 2), math.sin(a) * d), (0, r.uniform(0, math.tau), r.uniform(-0.12, 0.12)))
        objs.append(b)
    return join(objs, "pile")


@asset
def skull_pile_a():
    return _pile(3, 6, 5)


@asset
def skull_pile_b():
    return _pile(8, 4, 6, 0.36)


# --- Candles -------------------------------------------------------------------------------

def candle_obj(h, rad, seed, puddle=True):
    """A melted candle: body, sagging rim, drips down the side, a wick; flame separate."""
    r = random.Random(seed)
    parts = [cyl(rad, rad * 0.96, h, 16, (0, 0, 0), role="wax")]
    # A melted lip and drips.
    parts.append(torus(rad * 0.9, rad * 0.22, (0, h - rad * 0.12, 0), role="wax", seg=16, mseg=6))
    for k in range(r.randint(3, 6)):
        a = r.uniform(0, math.tau)
        L = r.uniform(0.25, 0.85) * h
        pts = []
        rads = []
        for i in range(5):
            t = i / 4
            y = h - rad * 0.1 - L * t
            wob = r.uniform(-0.15, 0.15) * rad
            pts.append((math.cos(a + wob) * rad * 1.0, y, math.sin(a + wob) * rad * 1.0))
            rads.append(rad * (0.22 - 0.06 * t) * (1.3 if i == 4 else 1.0))
        parts.append(tube(pts, rads, 6, "wax"))
    if puddle:
        parts.append(cyl(rad * 1.9, rad * 1.5, 0.015, 16, (0, 0, 0), role="wax"))
    w = organic(parts, voxel=max(0.004, rad * 0.09), smooth=2, smooth_factor=0.5, name="candle", role="wax")
    # Hollow the top a little (a melted cup).
    cup = sphere(rad * 0.75, (0, h + rad * 0.32, 0), (1, 0.6, 1), "wax", 12, 6)
    boolean(w, cup, transfer=False)
    C.decimate_to(w, int(260 + 900 * h))
    wick = cyl(0.004, 0.003, 0.035, 5, (0, h - rad * 0.2, 0), role="dark")
    flame = lathe([(0.0, 0.0), (rad * 0.32, 0.012), (rad * 0.42, 0.03), (rad * 0.28, 0.06), (rad * 0.1, 0.09), (0.0, 0.115)], 8, "flame", (0, h + 0.012, 0))
    return [join([w, wick, flame], "candle")]


def _cluster(seed, n, base_skull=False):
    r = random.Random(seed)
    objs = []
    for k in range(n):
        a = r.uniform(0, math.tau)
        d = 0.0 if k == 0 else r.uniform(0.1, 0.36)
        h = r.uniform(0.14, 0.52) if k > 0 else 0.55
        rad = r.uniform(0.035, 0.055)
        for o in candle_obj(h, rad, seed * 13 + k):
            C.place(o, (math.cos(a) * d, 0.0, math.sin(a) * d), (r.uniform(-0.05, 0.05), 0, r.uniform(-0.05, 0.05)))
            objs.append(o)
    # Wax pool joining them.
    pool = organic([cyl(0.38, 0.3, 0.02, 20, (0, 0, 0), role="wax"),
                    cyl(0.22, 0.1, 0.03, 12, (0.12, 0, -0.05), role="wax")], voxel=0.01, smooth=3, name="pool", role="wax")
    C.decimate_to(pool, 500)
    C.jitter(pool, 0.01, seed, 4.0)
    objs.append(pool)
    if base_skull:
        sk = skull_obj(seed + 99, ratio=0.35)
        C.place(sk, (0.24, 0, 0.18), (0, 0.6, 0))
        objs.append(sk)
        for o in candle_obj(0.12, 0.03, seed + 7, puddle=False):
            C.place(o, (0.24, 0.215, 0.17), (0, 0, 0))
            objs.append(o)
    return join(objs, "candles")


@asset
def candles_a():
    return _cluster(5, 5)


@asset
def candles_b():
    return _cluster(11, 4, base_skull=True)


@asset
def candelabra():
    """A wrought-iron floor candelabrum (~1.5 m) with five dripping candles."""
    objs = [lathe([(0.0, 0.0), (0.22, 0.0), (0.2, 0.03), (0.06, 0.06), (0.035, 0.1), (0.03, 1.15), (0.05, 1.18), (0.05, 1.22), (0.0, 1.24)], 12, "iron")]
    for k in range(3):  # splayed feet
        a = math.tau * k / 3
        objs.append(tube([(0, 0.08, 0), (math.cos(a) * 0.18, 0.04, math.sin(a) * 0.18), (math.cos(a) * 0.3, 0.0, math.sin(a) * 0.3)], [0.02, 0.018, 0.024], 6, "iron"))
    objs.append(torus(0.06, 0.012, (0, 0.6, 0), role="iron", seg=10, mseg=5))
    tips = [(0, 1.24, 0)]
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        dx, dz = math.cos(a), math.sin(a)
        pts = [(0, 1.0, 0), (dx * 0.18, 1.02, dz * 0.18), (dx * 0.3, 1.1, dz * 0.3), (dx * 0.32, 1.2, dz * 0.32)]
        objs.append(tube(pts, [0.016, 0.015, 0.014, 0.014], 6, "iron"))
        objs.append(lathe([(0.0, 0.0), (0.05, 0.0), (0.06, 0.03), (0.045, 0.04), (0.0, 0.04)], 10, "iron", (dx * 0.32, 1.2, dz * 0.32)))
        tips.append((dx * 0.32, 1.24, dz * 0.32))
        # scroll curl under each arm
        objs.append(torus(0.04, 0.008, (dx * 0.16, 0.95, dz * 0.16), (math.pi / 2, -a, 0), "iron", 10, 4))
    for i, t in enumerate(tips):
        for o in candle_obj(0.16 + 0.08 * (i % 3), 0.032, 70 + i, puddle=False):
            C.place(o, t)
            objs.append(o)
    return join(objs, "candelabra")


# --- Stone --------------------------------------------------------------------------------

def _break_top(ob, y, seed, size=1.0, role="stone"):
    """Snap the top of a column/shaft off along a jagged surface at height y."""
    cutter = ico(1.0, 3, (0, y + size * 1.0, 0), (size * 1.6, size, size * 1.6), role)
    C.displace(cutter, size * 0.55, 0.35 * size, 'CLOUDS', 2)
    C.place(cutter, (0, y + size * 1.0, 0), (random.Random(seed).uniform(-0.3, 0.3), 0, random.Random(seed + 1).uniform(-0.3, 0.3)), (size * 1.6, size, size * 1.6))
    boolean(ob, cutter, transfer=False)
    return ob


def clustered_shaft(h, r=0.3, segs=8):
    parts = [cyl(r, r, h, segs, (0, 0, 0), role="stone")]
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        parts.append(cyl(r * 0.36, r * 0.36, h, 10, (math.cos(a) * r * 0.92, 0, math.sin(a) * r * 0.92), role="stone"))
    for k in range(4):
        a = math.tau * k / 4
        parts.append(cyl(r * 0.18, r * 0.18, h, 8, (math.cos(a) * r * 1.0, 0, math.sin(a) * r * 1.0), role="stone"))
    return parts


def column_base(r=0.3):
    return [
        cyl(r * 1.75, r * 1.75, 0.16, 8, (0, 0, 0), role="stone", bevel=0.02),
        cyl(r * 1.55, r * 1.45, 0.14, 8, (0, 0.16, 0), role="stone", bevel=0.015),
        torus(r * 1.3, 0.06, (0, 0.33, 0), role="stone", seg=16, mseg=6),
        cyl(r * 1.3, r * 1.2, 0.1, 16, (0, 0.3, 0), role="stone"),
    ]


def _column(h, seed, broken=True):
    r = random.Random(seed)
    shaft = join(clustered_shaft(h, 0.3), "shaft")
    C.place(shaft, (0, 0.38, 0))
    if broken:
        _break_top(shaft, 0.38 + h * r.uniform(0.82, 0.95), seed, 0.6)
    parts = column_base(0.3) + [shaft]
    ob = join(parts, "column")
    C.jitter(ob, 0.012, seed, 2.5)
    return ob


@asset
def column_tall():
    return _column(2.0, 1)


@asset
def column_short():
    return _column(0.9, 2)


@asset
def column_drum():
    """A fallen drum of a clustered column, both ends broken; lies along X, base at y=0."""
    shaft = join(clustered_shaft(1.1, 0.3), "drum")
    _break_top(shaft, 0.95, 4, 0.55)
    C.place(shaft, (-0.55, 0.36, 0), (0, 0, -math.pi / 2))
    C.jitter(shaft, 0.012, 9, 2.5)
    return shaft


@asset
def gravestone_a():
    """Pointed-arch headstone with a carved cross, chipped, on a slab."""
    w, h, t = 0.62, 0.95, 0.13
    ys = h - 0.866 * w
    prof = [(-w / 2, 0.0), (w / 2, 0.0)]
    for i in range(7):  # right arc up to the apex (centre at -w/2)
        x = w / 2 - (w / 2) * i / 6
        prof.append((x, ys + math.sqrt(max(0.0, w * w - (x + w / 2) ** 2))))
    for i in range(1, 7):  # left arc down
        x = -(w / 2) * i / 6
        prof.append((x, ys + math.sqrt(max(0.0, w * w - (x - w / 2) ** 2))))
    stone = prism_profile(prof, t, "stone", bevel=0.012)
    C.apply(stone)
    # Carved cross (recessed) and an inscription band.
    boolean(stone, box((0.06, 0.42, 0.04), (0, 0.55, t / 2), (0, 0, 0), "stone_dark"))
    boolean(stone, box((0.26, 0.06, 0.04), (0, 0.66, t / 2), (0, 0, 0), "stone_dark"))
    boolean(stone, box((0.4, 0.035, 0.03), (0, 0.24, t / 2), (0, 0, 0), "stone_dark"))
    boolean(stone, box((0.3, 0.025, 0.03), (0, 0.18, t / 2), (0, 0, 0), "stone_dark"))
    chip = ico(0.18, 2, (w / 2, h * 0.75, 0.02), (1, 1, 1), "stone")
    C.jitter(chip, 0.05, 3, 6.0)
    boolean(stone, chip, transfer=False)
    C.place(stone, (0, 0.1, 0))
    slab = box((0.9, 0.12, 0.42), (0, 0.05, 0.08), (0, 0, 0), "stone", bevel=0.02)
    ob = join([stone, slab], "gravestone")
    C.jitter(ob, 0.008, 5, 4.0)
    return ob


@asset
def gravestone_b():
    """A ringed (celtic-style) stone cross on a stepped base."""
    parts = [
        box((0.5, 0.16, 0.36), (0, 0.08, 0), role="stone", bevel=0.02),
        box((0.34, 0.12, 0.26), (0, 0.22, 0), role="stone", bevel=0.015),
        box((0.14, 1.05, 0.12), (0, 0.8, 0), role="stone", bevel=0.012),
        box((0.62, 0.14, 0.12), (0, 1.0, 0), role="stone", bevel=0.012),
        torus(0.2, 0.035, (0, 1.0, 0), (math.pi / 2, 0, 0), "stone", 20, 6),
    ]
    ob = join(parts, "cross")
    chip = ico(0.12, 2, (0.31, 1.05, 0.04), (1, 1, 1), "stone")
    C.jitter(chip, 0.04, 4, 6.0)
    boolean(ob, chip, transfer=False)
    C.jitter(ob, 0.006, 6, 5.0)
    return ob


@asset
def sarcophagus():
    """A stone sarcophagus with panelled sides; its gabled lid is shoved ajar."""
    L, W, H = 2.0, 0.85, 0.7
    body = join([box((L, H - 0.1, W), (0, (H - 0.1) / 2 + 0.1, 0), role="stone", bevel=0.02),
                 box((L + 0.12, 0.12, W + 0.12), (0, 0.06, 0), role="stone", bevel=0.02),
                 box((L + 0.06, 0.06, W + 0.06), (0, H - 0.03, 0), role="stone", bevel=0.015)], "body")
    for i in range(4):
        x = -L / 2 + L * (i + 0.5) / 4
        boolean(body, box((L / 4 - 0.12, H - 0.36, 0.06), (x, H * 0.5 + 0.02, W / 2), role="stone_dark"))
        boolean(body, box((0.08, 0.2, 0.06), (x, H * 0.5 + 0.02, -W / 2), role="stone_dark"))
    boolean(body, box((L - 0.2, 0.4, W - 0.2), (0, H, 0), role="dark"))  # hollow
    lid = join([box((L + 0.04, 0.09, W + 0.04), (0, 0.045, 0), role="stone", bevel=0.015),
                prism_profile([(-W / 2, 0), (W / 2, 0), (0, 0.16)], L, "stone", loc=(0, 0.09, 0), rot=(0, math.pi / 2, 0), bevel=0.01),
                box((0.08, 0.05, 0.5), (0.4, 0.27, 0), role="stone"), box((0.3, 0.05, 0.08), (0.4, 0.27, 0), role="stone")], "lid")
    C.place(lid, (0.25, H, 0.12), (0, 0.12, 0.03))
    ob = join([body, lid], "sarcophagus")
    C.jitter(ob, 0.008, 7, 3.0)
    return ob


# --- Iron ---------------------------------------------------------------------------------

def spear_tip(at, role="iron"):
    x, y, z = at
    return [lathe([(0.0, 0.0), (0.022, 0.0), (0.03, 0.02), (0.02, 0.035), (0.045, 0.06), (0.035, 0.1), (0.0, 0.2)], 4, role, (x, y, z), phase=math.pi / 4)]


def fence_obj(length, seed, bent=False):
    r = random.Random(seed)
    objs = []
    # End post with a ball-and-spike cap.
    objs.append(box((0.07, 1.15, 0.07), (0, 0.575, 0), role="iron", bevel=0.008))
    objs.append(sphere(0.055, (0, 1.2, 0), role="iron", segs=10, rings=6))
    objs += spear_tip((0, 1.24, 0))
    n = int(length / 0.16)
    for k in range(1, n):
        if bent and r.random() < 0.15:
            continue
        x = k * length / n
        h = 0.95 if k % 2 else 1.02
        lean = r.uniform(-0.1, 0.1) if bent else 0.0
        top = (x + lean * h, h, lean * 0.4)
        objs.append(tube([(x, 0.0, 0), (x + lean * h * 0.5, h * 0.5, lean * 0.2), top], 0.012, 6, "iron"))
        objs += spear_tip(top)
    for y in (0.12, 0.78):
        objs.append(box((length, 0.035, 0.03), (length / 2, y, 0), role="iron"))
    # Scrolls between the rails.
    for k in range(1, n, 2):
        x = (k + 0.5) * length / n
        objs.append(torus(0.04, 0.007, (x, 0.72, 0), (math.pi / 2, 0, 0), "iron", 10, 4))
        objs.append(torus(0.04, 0.007, (x, 0.18, 0), (math.pi / 2, 0, 0), "iron", 10, 4))
    ob = join(objs, "fence")
    if bent:
        # Sag the far end down and outward.
        for v in ob.data.vertices:
            g = Vector((v.co.x, v.co.z, -v.co.y))
            t = max(0.0, g.x / length)
            v.co.z -= 0.12 * t * t * max(0.0, g.y)
            v.co.y -= 0.18 * t * t * max(0.0, g.y)
    return ob


@asset
def fence_section():
    """1.2 m of wrought-iron railing from x=0 (post) to x=1.2 (next post goes there)."""
    return fence_obj(1.2, 1)


@asset
def fence_bent():
    return fence_obj(1.2, 2, bent=True)


@asset
def iron_cage():
    """A gibbet cage (~1.6 m) with a hook on top; origin at the hook, hangs down -Y."""
    objs = [torus(0.05, 0.012, (0, -0.05, 0), (math.pi / 2, 0, 0), "iron", 10, 5)]
    objs.append(tube([(0, -0.1, 0), (0, -0.28, 0)], 0.018, 6, "iron"))
    top, bot, r = -0.3, -1.75, 0.42
    objs.append(lathe([(0.0, 0.0), (r * 0.6, -0.05), (r * 0.95, -0.18), (r, -0.25)], 16, "iron", (0, top, 0)))
    for y, rr in ((top - 0.25, r), (top - 0.8, r * 1.04), (bot + 0.15, r * 0.95)):
        objs.append(torus(rr, 0.016, (0, y, 0), role="iron", seg=20, mseg=5))
    for k in range(10):
        a = math.tau * k / 10
        objs.append(tube([(math.cos(a) * r * 0.95, top - 0.2, math.sin(a) * r * 0.95), (math.cos(a) * r * 1.04, top - 0.8, math.sin(a) * r * 1.04),
                          (math.cos(a) * r * 0.8, bot + 0.05, math.sin(a) * r * 0.8)], 0.012, 5, "iron"))
    objs.append(cyl(r * 0.8, r * 0.82, 0.04, 16, (0, bot, 0), role="iron"))
    # The prisoner's remains.
    sk = skull_obj(55, ratio=0.35)
    C.place(sk, (0.08, bot + 0.28, 0.05), (0.6, 0.4, 0.3), (1.2, 1.2, 1.2))
    objs.append(sk)
    for k in range(3):
        b = bone_obj(0.36, 60 + k)
        C.place(b, (0.0, bot + 0.07 + 0.03 * k, -0.05 + 0.08 * k), (0, k * 1.2, 0.2))
        objs.append(b)
    return join(objs, "cage")


# --- Hazards ------------------------------------------------------------------------------

@asset
def spike():
    """One rusted iron spike for the spike trap: 0.9 m tall, base at y=0, octagonal collar."""
    prof = [(0.0, 0.0), (0.135, 0.0), (0.135, 0.05), (0.11, 0.07), (0.1, 0.1), (0.075, 0.12), (0.07, 0.3), (0.045, 0.6), (0.02, 0.82), (0.0, 0.9)]
    s = lathe(prof, 8, "iron", phase=math.pi / 8)
    # A barb ring.
    b = lathe([(0.0, 0.0), (0.085, 0.0), (0.06, 0.08), (0.0, 0.08)], 4, "iron", (0, 0.3, 0), phase=0.0)
    ob = join([s, b], "spike")
    for v in ob.data.vertices:  # a slight crook
        v.co.x += 0.015 * (v.co.z / 0.9) ** 2
    C.jitter(ob, 0.004, 1, 12.0)
    return ob


@asset
def spike_plate_tile():
    """1 m x 1 m rusted grate tile (top at y=0.04): bevelled frame, slots, rivets."""
    plate = box((1.0, 0.04, 1.0), (0, 0.02, 0), role="iron", bevel=0.01)
    for i in range(4):
        z = -0.33 + 0.22 * i
        boolean(plate, box((0.72, 0.03, 0.06), (0, 0.04, z), role="dark"))
    objs = [plate, box((1.0, 0.025, 0.05), (0, 0.05, -0.475), role="iron", bevel=0.006),
            box((1.0, 0.025, 0.05), (0, 0.05, 0.475), role="iron", bevel=0.006),
            box((0.05, 0.025, 0.9), (-0.475, 0.05, 0), role="iron", bevel=0.006),
            box((0.05, 0.025, 0.9), (0.475, 0.05, 0), role="iron", bevel=0.006)]
    for sx in (-1, 1):
        for sz in (-1, 1):
            for k in (0.3, 0.0):
                objs.append(sphere(0.016, (sx * 0.475, 0.062, sz * (0.475 - k * 0.0) if k == 0 else sz * 0.2), (1, 0.6, 1), "iron", 8, 4))
    return join(objs, "plate")


def crescent(width=1.6, height=0.62, thick=0.1, role="blade"):
    """A crescent blade in the XY plane (tips up), sharpened on its lower (outer) edge."""
    n = 18
    outer = []
    inner = []
    for i in range(n + 1):
        t = i / n
        x = (t - 0.5) * width
        u = (2 * t - 1)
        yo = -height * 0.6 * (1 - u * u) + height * 0.4 * u * u      # outer (low) arc
        yi = -height * 0.08 * (1 - u * u) + height * 0.42 * u * u     # inner arc
        outer.append((x, yo))
        inner.append((x, yi))
    import bmesh
    bm = bmesh.new()
    # Three rows: sharpened edge (z=0), outer shoulder (+-thick/2), inner spine (+-thick/2).
    edge = [bm.verts.new(C.G(x, y, 0.0)) for x, y in outer]
    sh_f = [bm.verts.new(C.G(x, y + (yi - y) * 0.35, thick * 0.5)) for (x, y), (_, yi) in zip(outer, inner)]
    sh_b = [bm.verts.new(C.G(x, y + (yi - y) * 0.35, -thick * 0.5)) for (x, y), (_, yi) in zip(outer, inner)]
    in_f = [bm.verts.new(C.G(x, yi, thick * 0.5)) for x, yi in inner]
    in_b = [bm.verts.new(C.G(x, yi, -thick * 0.5)) for x, yi in inner]
    for i in range(n):
        j = i + 1
        bm.faces.new((edge[i], edge[j], sh_f[j], sh_f[i]))
        bm.faces.new((edge[j], edge[i], sh_b[i], sh_b[j]))
        bm.faces.new((sh_f[i], sh_f[j], in_f[j], in_f[i]))
        bm.faces.new((sh_b[j], sh_b[i], in_b[i], in_b[j]))
        bm.faces.new((in_f[i], in_f[j], in_b[j], in_b[i]))
    for idx in (0, n):
        bm.faces.new((edge[idx], sh_f[idx], in_f[idx], in_b[idx], sh_b[idx]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = C.from_bm(bm, "crescent", role)
    # The sharpened band reads as a separate, brighter material.
    ob.data.materials.append(C.mat("iron"))
    for p in ob.data.polygons:
        c = p.center
        g = Vector((c.x, c.z, -c.y))
        p.material_index = 1 if abs(g.z) > thick * 0.3 and True else 0
    return ob


@asset
def pendulum_crescent():
    """One crescent blade (1.6 m wide, ~0.6 m tall), its hub at y=+0.2; centred at origin."""
    blade = crescent()
    hub = join([box((0.28, 0.3, 0.16), (0, 0.18, 0), role="iron", bevel=0.02),
                sphere(0.03, (0.08, 0.26, 0.085), role="iron", segs=8, rings=4), sphere(0.03, (-0.08, 0.26, 0.085), role="iron", segs=8, rings=4),
                sphere(0.03, (0.08, 0.26, -0.085), role="iron", segs=8, rings=4), sphere(0.03, (-0.08, 0.26, -0.085), role="iron", segs=8, rings=4)], "hub")
    ob = join([blade, hub], "crescent")
    # Notches bitten out of the edge.
    for x in (-0.42, 0.25):
        boolean(ob, sphere(0.05, (x, -0.33 + abs(x) * 0.25, 0), (1, 1, 1), "blade", 8, 6), transfer=False)
    return ob


@asset
def pendulum_spine():
    """The iron spine joining several crescents (1 m along Z, stretched in Godot), y=+0.32."""
    objs = [cyl(0.07, 0.07, 1.0, 10, (0, 0.32, -0.5), (math.pi / 2, 0, 0), "iron")]
    for z in (-0.5, 0.5):
        objs.append(cyl(0.1, 0.1, 0.06, 10, (0, 0.32, z - 0.03), (math.pi / 2, 0, 0), "iron", bevel=0.01))
    return join(objs, "spine")


@asset
def pendulum_arm():
    """The pendulum's arm, 1 m long from the pivot (y=0) down to y=-1; Godot stretches its
    middle. A pivot hub with a bolt at the top and a clamp collar at the bottom."""
    objs = [box((0.17, 0.8, 0.1), (0, -0.5, 0), role="iron", bevel=0.015),
            box((0.07, 0.8, 0.2), (0, -0.5, 0), role="iron", bevel=0.01),
            cyl(0.13, 0.13, 0.12, 14, (0, 0, -0.06), (math.pi / 2, 0, 0), "iron", bevel=0.015),
            cyl(0.05, 0.05, 0.2, 8, (0, 0, -0.1), (math.pi / 2, 0, 0), "iron"),
            box((0.2, 0.12, 0.18), (0, -0.92, 0), role="iron", bevel=0.02),
            box((0.24, 0.04, 0.2), (0, -0.85, 0), role="iron", bevel=0.01)]
    return join(objs, "arm")


@asset
def lever_base():
    """Carved stone plinth for the shortcut lever (0.7 m), slot on top; origin at the ground."""
    objs = [box((0.75, 0.14, 0.75), (0, 0.07, 0), role="stone", bevel=0.02),
            box((0.6, 0.38, 0.6), (0, 0.33, 0), role="stone", bevel=0.02),
            box((0.66, 0.08, 0.66), (0, 0.56, 0), role="stone", bevel=0.015)]
    base = join(objs, "lever_base")
    for (x, z, ry) in ((0, 0.3, 0), (0, -0.3, 0), (0.3, 0, math.pi / 2), (-0.3, 0, math.pi / 2)):
        boolean(base, prism_profile([(-0.12, 0.0), (0.12, 0.0), (0.12, 0.14), (0.0, 0.24), (-0.12, 0.14)], 0.05, "stone_dark", loc=(x, 0.2, z), rot=(0, ry, 0)))
    boolean(base, box((0.42, 0.1, 0.1), (0, 0.6, 0), role="dark"))
    # Iron axle brackets.
    objs = [base, box((0.06, 0.12, 0.16), (-0.2, 0.62, 0), role="iron", bevel=0.01), box((0.06, 0.12, 0.16), (0.2, 0.62, 0), role="iron", bevel=0.01),
            cyl(0.03, 0.03, 0.46, 8, (-0.23, 0.62, 0), (0, 0, -math.pi / 2), "iron")]
    sk = skull_obj(77, ratio=0.35)
    C.place(sk, (0, 0.6, 0.3), (0, 0, 0), (0.9, 0.9, 0.9))
    objs.append(sk)
    ob = join(objs, "lever_base")
    C.jitter(ob, 0.004, 8, 6.0)
    return ob


@asset
def lever_handle():
    """The lever arm: pivot at the origin, 1.1 m iron bar with a bone-wrapped grip and pommel."""
    objs = [cyl(0.035, 0.03, 0.9, 8, (0, 0, 0), role="iron", bevel=0.005),
            cyl(0.05, 0.05, 0.08, 10, (0, -0.04, 0), role="iron"),
            cyl(0.045, 0.045, 0.22, 10, (0, 0.82, 0), role="bone"),
            sphere(0.06, (0, 1.08, 0), role="gold", segs=10, rings=6)]
    for k in range(4):
        objs.append(torus(0.047, 0.008, (0, 0.85 + k * 0.05, 0), role="iron", seg=10, mseg=4))
    return join(objs, "handle")


@asset
def bridge_plank():
    """One weathered plank, 0.3 m (x) x 1 m (z, stretched to the bridge depth), top at y=0."""
    r = random.Random(3)
    p = box((0.28, 0.08, 1.0), (0, -0.04, 0), role="wood", bevel=0.012)
    C.apply(p)
    for v in p.data.vertices:
        v.co.z += 0.008 * math.sin(v.co.y * 9.0)
    # Nail heads.
    objs = [p]
    for z in (-0.42, 0.42):
        for x in (-0.07, 0.07):
            objs.append(sphere(0.012, (x, 0.0, z), (1, 0.5, 1), "iron", 6, 3))
    return join(objs, "plank")


@asset
def bridge_rail():
    """Iron stringer for the bridge, 1 m along X (stretched), with rivet bosses; top at y=0."""
    objs = [box((1.0, 0.16, 0.08), (0, -0.08, 0), role="iron", bevel=0.01)]
    for k in range(5):
        objs.append(sphere(0.018, (-0.4 + 0.2 * k, -0.05, 0.045), (1, 1, 0.5), "iron", 6, 3))
    return join(objs, "rail")


@asset
def blood_altar():
    """A carved stone altar with a blood basin (glow) and candles; origin at the ground."""
    objs = [box((1.5, 0.18, 1.1), (0, 0.09, 0), role="stone", bevel=0.025),
            box((1.25, 0.14, 0.9), (0, 0.25, 0), role="stone", bevel=0.02),
            lathe([(0.0, 0.32), (0.4, 0.32), (0.38, 0.38), (0.3, 0.42), (0.26, 0.85), (0.32, 0.9), (0.42, 0.95), (0.0, 0.95)], 8, "stone", phase=math.pi / 8)]
    # Gothic arcade on the pedestal.
    ped = join(objs, "ped")
    for k in range(8):
        a = math.tau * k / 8
        boolean(ped, prism_profile([(-0.06, 0.0), (0.06, 0.0), (0.06, 0.2), (0.0, 0.28), (-0.06, 0.2)], 0.12, "stone_dark",
                                   loc=(math.cos(a) * 0.29, 0.5, math.sin(a) * 0.29), rot=(0, -a + math.pi / 2, 0)))
    bowl = lathe([(0.0, 0.0), (0.18, 0.0), (0.42, 0.1), (0.6, 0.2), (0.62, 0.27), (0.56, 0.27), (0.4, 0.17), (0.0, 0.12)], 24, "stone", (0, 0.95, 0))
    blood = cyl(0.5, 0.5, 0.01, 24, (0, 1.17, 0), role="glow")
    objs = [ped, bowl, blood]
    for k in range(4):  # drips over the rim
        a = math.tau * k / 4 + 0.3
        objs.append(tube([(math.cos(a) * 0.6, 1.22, math.sin(a) * 0.6), (math.cos(a) * 0.62, 1.15, math.sin(a) * 0.62), (math.cos(a) * 0.5, 1.03, math.sin(a) * 0.5)], [0.02, 0.016, 0.012], 6, "glow"))
    for sx in (-1, 1):
        sk = skull_obj(80 + sx, ratio=0.35)
        C.place(sk, (sx * 0.5, 0.32, 0.32), (0, -sx * 0.4, 0))
        objs.append(sk)
        for o in candle_obj(0.22, 0.035, 90 + sx, puddle=True):
            C.place(o, (sx * 0.52, 0.32, -0.28))
            objs.append(o)
    ob = join(objs, "altar")
    return ob


@asset
def chest_body():
    """Reliquary chest body 1.2 x 0.62 x 0.8 (origin at the ground): planks, iron bands,
    corner brackets, feet and a lock plate whose keyhole glows (role glow)."""
    W, H, D = 1.2, 0.62, 0.8
    body = box((W, H - 0.06, D), (0, (H - 0.06) / 2 + 0.06, 0), role="wood", bevel=0.015)
    for k in range(1, 4):
        boolean(body, box((W + 0.02, 0.012, D + 0.02), (0, 0.06 + k * (H - 0.06) / 4, 0), role="wood"), transfer=False)
    boolean(body, box((W - 0.12, 0.2, D - 0.12), (0, H, 0), role="glow"))  # hollow, glowing inside
    objs = [body]
    for x in (-0.38, 0.0, 0.38):
        objs.append(box((0.07, H - 0.04, D + 0.03), (x, (H - 0.06) / 2 + 0.07, 0), role="iron", bevel=0.006))
    for sx in (-1, 1):
        for sz in (-1, 1):
            objs.append(box((0.1, 0.1, 0.1), (sx * (W / 2 - 0.04), 0.04, sz * (D / 2 - 0.04)), role="iron", bevel=0.01))
            objs.append(box((0.03, H - 0.1, 0.13), (sx * (W / 2 + 0.005), H / 2 + 0.03, sz * (D / 2 - 0.05)), role="iron", bevel=0.005))
    objs.append(box((0.2, 0.24, 0.03), (0, H - 0.15, D / 2 + 0.015), role="gold", bevel=0.008))
    objs.append(box((0.03, 0.08, 0.02), (0, H - 0.17, D / 2 + 0.03), role="glow"))
    objs.append(sphere(0.022, (0, H - 0.12, D / 2 + 0.03), (1, 1, 0.5), "glow", 8, 4))
    for sx in (-1, 1):  # handles
        objs.append(torus(0.07, 0.012, (sx * (W / 2 + 0.03), H * 0.62, 0), (0, 0, math.pi / 2), "iron", 12, 4))
    return join(objs, "chest_body")


@asset
def chest_lid():
    """The chest's barrel lid. Origin at the hinge line (x=+0.6, bottom of the lid), so
    rotating about Z opens it like the old script expects."""
    W, D = 1.24, 0.84
    prof = []
    for i in range(9):
        a = math.pi * i / 8
        prof.append((math.cos(a) * D / 2, math.sin(a) * 0.2 + 0.04))
    prof = [(D / 2, 0.0)] + prof + [(-D / 2, 0.0)]
    lid = prism_profile(prof, W, "wood", loc=(-W / 2, 0, 0), rot=(0, math.pi / 2, 0), bevel=0.01)
    objs = [lid]
    for x in (-0.38, 0.0, 0.38):
        band = []
        for i in range(9):
            a = math.pi * i / 8
            band.append((x - W / 2, math.sin(a) * 0.205 + 0.045, math.cos(a) * (D / 2 + 0.008)))
        objs.append(tube(band, 0.022, 4, "iron"))
    objs.append(box((0.16, 0.1, 0.03), (-W / 2, 0.02, D / 2 + 0.02), role="gold", bevel=0.006))
    # A gem on top.
    objs.append(sphere(0.05, (-W / 2, 0.25, 0), (1, 0.7, 1), "glow", 8, 6))
    return join(objs, "chest_lid")  # spans x -1.24..0: the hinge is the origin


@asset
def bone_shard():
    """A carved, splintered bone shard (~0.6 m tall) centred on the origin, glowing runes."""
    parts = [tube([(0, -0.3, 0), (0.01, -0.1, 0), (0.0, 0.1, 0), (-0.02, 0.28, 0)], [0.02, 0.07, 0.065, 0.015], 8, "bone"),
             sphere(0.07, (0.0, -0.06, 0), (1.2, 1.4, 0.7), "bone", 10, 6)]
    s = organic(parts, voxel=0.008, smooth=2, name="shard", role="bone")
    C.jitter(s, 0.012, 3, 9.0)
    # Splinter cuts.
    for k, (y, a) in enumerate(((0.22, 0.8), (-0.24, -0.7))):
        boolean(s, box((0.2, 0.06, 0.2), (0.07 if k == 0 else -0.07, y, 0), (0, 0, a), "bone"), transfer=False)
    C.decimate_to(s, 900)
    # Carved rune grooves that glow.
    for y in (-0.12, 0.0, 0.12):
        boolean(s, box((0.012, 0.07, 0.2), (0.0, y, 0.0), (0, 0, 0.6 if y else -0.5), "glow"))
    return s


@asset
def checkpoint_banner():
    """A wayside shrine-standard: stone foot, iron pole (2.5 m), crossbar, skull finial;
    origin at the GROUND. The banner itself is `checkpoint_cloth`."""
    objs = [box((0.6, 0.18, 0.6), (0, 0.09, 0), role="stone", bevel=0.02),
            box((0.4, 0.2, 0.4), (0, 0.27, 0), role="stone", bevel=0.02),
            cyl(0.035, 0.03, 2.4, 8, (0, 0.3, 0), role="iron"),
            cyl(0.025, 0.025, 0.8, 8, (-0.4, 2.45, 0), (0, 0, -math.pi / 2), "iron"),
            sphere(0.04, (-0.42, 2.45, 0), role="iron", segs=8, rings=4), sphere(0.04, (0.42, 2.45, 0), role="iron", segs=8, rings=4)]
    objs += spear_tip((0, 2.68, 0))
    sk = skull_obj(66, ratio=0.4)
    C.place(sk, (0, 2.5, 0.0), (0, 0, 0), (0.9, 0.9, 0.9))
    objs.append(sk)
    for k in range(5):
        objs.append(torus(0.035, 0.008, (-0.36 + k * 0.18, 2.45, 0), (0, 0, math.pi / 2), "iron", 8, 4))
    ob = join(objs, "checkpoint")
    C.jitter(ob, 0.003, 2, 8.0)
    return ob


@asset
def checkpoint_cloth():
    """The tattered banner hanging from the crossbar (top edge at y=2.43, ground origin)."""
    import bmesh
    bm = bmesh.new()
    cols, rows = 10, 16
    w, h = 0.72, 1.45
    r = random.Random(4)
    cuts = [r.uniform(0.0, 0.35) for _ in range(cols + 1)]
    grid = []
    for j in range(rows + 1):
        row = []
        for i in range(cols + 1):
            u = i / cols
            v = j / rows
            x = (u - 0.5) * w
            y = 2.43 - v * h
            # Swallow-tail bottom and torn edge.
            tail = abs(u - 0.5) * 0.5
            limit = 1.0 - cuts[i] * 0.4 - (0.25 - tail) * 0.6
            y = 2.43 - min(v, limit) * h
            z = 0.04 * math.sin(u * 7.0 + v * 2.0) + 0.03 * math.sin(v * 9.0)
            row.append(bm.verts.new(C.G(x, y, z)))
        grid.append(row)
    for j in range(rows):
        for i in range(cols):
            if r.random() < 0.025 and j > 4:
                continue  # holes
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
    ob = C.from_bm(bm, "cloth", "cloth")
    sol = ob.modifiers.new("solid", 'SOLIDIFY')
    sol.thickness = 0.012
    C.apply(ob)
    return ob


@asset
def exit_arch():
    """The exit gate: a pointed arch in the YZ plane (x=0) spanning z -3.7..3.7, clustered
    piers on stepped plinths, foliate capitals, a three-order archivolt, crockets, a finial,
    a skull keystone and a glowing blood moulding (role glow). Origin at the pad top."""
    HALF, SPRING, R = 3.7, 4.6, 4.7
    objs = []
    for side in (-1, 1):
        z = side * HALF
        objs.append(box((1.5, 0.35, 1.5), (0, 0.175, z), role="stone", bevel=0.03))
        objs.append(box((1.25, 0.35, 1.25), (0, 0.52, z), role="stone", bevel=0.03))
        shaft = join(clustered_shaft(3.55, 0.36), "pier")
        C.place(shaft, (0, 0.7, z))
        objs.append(shaft)
        objs.append(lathe([(0.0, 0.0), (0.62, 0.0), (0.66, 0.08), (0.58, 0.14), (0.0, 0.14)], 8, "stone", (0, 0.68, z), phase=math.pi / 8))
        # Capital: a flared block with leaf knobs.
        objs.append(lathe([(0.0, 0.0), (0.42, 0.0), (0.5, 0.18), (0.68, 0.32), (0.72, 0.4), (0.0, 0.4)], 8, "stone", (0, 4.2, z), phase=math.pi / 8))
        for k in range(8):
            a = math.tau * k / 8 + math.pi / 8
            objs.append(sphere(0.09, (math.cos(a) * 0.55, 4.42, z + math.sin(a) * 0.55), (1, 0.7, 1), "stone", 8, 5))
        objs.append(box((1.3, 0.12, 1.3), (0, 4.66, z), role="stone", bevel=0.02))
    # Archivolt: several orders stepping inward, each a swept profile along the pointed arc.
    apex = SPRING + math.sqrt(R * R - (R - HALF) ** 2)

    def arc_pts(radius_off, steps=12):
        pts = []
        for side in (-1, 1):
            centre = (-side * (R - HALF), SPRING)
            a0 = 0.0
            a1 = math.acos((R - HALF) / R)
            seq = range(steps + 1) if side == -1 else range(steps, -1, -1)
            for i in seq:
                ang = a0 + (a1 - a0) * i / steps
                rr = R + radius_off
                zz = centre[0] + side * rr * math.cos(ang)
                yy = centre[1] + rr * math.sin(ang)
                pts.append((zz, yy))
        # remove duplicate apex
        out = []
        for p in pts:
            if not out or (abs(out[-1][0] - p[0]) + abs(out[-1][1] - p[1])) > 1e-4:
                out.append(p)
        return out

    for off, thick, depth, role in ((0.15, 0.42, 1.25, "stone"), (-0.3, 0.3, 0.95, "stone"), (-0.62, 0.22, 0.7, "stone")):
        pts = arc_pts(off)
        ob = tube([(0, y, z) for z, y in pts], thick, 6, role)
        sc = ob
        # flatten the tube into a moulding: squash along x to `depth`
        for v in sc.data.vertices:
            v.co.x *= depth / (thick * 2)
        objs.append(sc)
    glow = tube([(0, y, z) for z, y in arc_pts(-0.86)], 0.07, 6, "glow")
    objs.append(glow)
    for side in (-1, 1):
        objs.append(box((0.1, 3.5, 0.12), (0, 2.6, side * (HALF - 0.47)), role="glow"))
    # Crockets along the outer order and a finial.
    pts = arc_pts(0.62, 8)
    for i, (z, y) in enumerate(pts):
        if i % 2 == 0 or abs(z) > HALF - 0.3:
            continue
        objs.append(sphere(0.16, (0, y + 0.05, z), (0.8, 1.3, 0.8), "stone", 8, 5))
    objs.append(lathe([(0.0, 0.0), (0.3, 0.0), (0.22, 0.3), (0.32, 0.45), (0.12, 0.7), (0.2, 0.85), (0.0, 1.3)], 8, "stone", (0, apex + 0.4, 0), phase=math.pi / 8))
    # Gables of the piers: little pinnacles.
    for side in (-1, 1):
        objs.append(lathe([(0.0, 0.0), (0.32, 0.0), (0.32, 0.5), (0.0, 1.6)], 4, "stone", (0, 4.72, side * HALF), phase=math.pi / 4))
    sk = skull_obj(99, voxel=0.0055, ratio=0.5)
    C.place(sk, (-0.35, apex - 0.62, 0), (0, -math.pi / 2, 0), (3.4, 3.4, 3.4))
    objs.append(sk)
    ob = join(objs, "exit_arch")
    C.jitter(ob, 0.015, 3, 1.5)
    return ob


# --- Ambush wall ------------------------------------------------------------------------

@asset
def bone_wall_module():
    """2 m of ossuary barricade (x -1..1, y 0..6, z +-0.3): a rough stone core packed with
    skulls and long bones, ribs arching out of it and red-lit cracks. Centred at y=3 in Godot
    (the wall body sits at y=3), so the origin is the module centre."""
    r = random.Random(12)
    # Lumpy mortar/stone core (rough courses), slightly thinner than the 0.6 m collision.
    core = box((2.0, 6.0, 0.36), (0, 0, 0), role="stone", bevel=0.05)
    C.displace(core, 0.12, 0.35, 'CLOUDS', 2, subdiv=4)
    C.decimate_to(core, 2500)
    objs = [core]
    sk_proto = skull_obj(200, jaw=False, tris=260)
    long_bone = bone_obj(0.44, 301)
    C.decimate_to(long_bone, 80)

    def dup(proto):
        s = proto.copy()
        s.data = proto.data.copy()
        bpy.context.scene.collection.objects.link(s)
        return s
    for side in (-1, 1):
        yaw = 0.0 if side > 0 else math.pi
        for row in range(7):
            y = -2.75 + row * 0.86
            # A course of stacked long bones (ends out) under each row of skulls.
            for k in range(6):
                b = dup(long_bone)
                C.place(b, (-0.85 + k * 0.34 + r.uniform(-0.03, 0.03), y - 0.12 + (k % 2) * 0.05, side * 0.15),
                        (0, math.pi / 2 + r.uniform(-0.15, 0.15), r.uniform(-0.1, 0.1)), (1.0, 2.6, 2.6))
                objs.append(b)
            for k in range(3):
                x = -0.62 + k * 0.62 + (0.2 if row % 2 else -0.05) + r.uniform(-0.05, 0.05)
                if abs(x) > 0.85:
                    continue
                s = dup(sk_proto)
                sc = r.uniform(2.3, 2.7)
                C.place(s, (x, y + 0.05, side * 0.13), (r.uniform(-0.15, 0.15), yaw + r.uniform(-0.25, 0.25), r.uniform(-0.15, 0.15)), (sc, sc, sc))
                objs.append(s)
    bpy.data.objects.remove(sk_proto, do_unlink=True)
    bpy.data.objects.remove(long_bone, do_unlink=True)
    # Great ribs curling out of both faces, and a crown of spikes of bone on top.
    for side in (-1, 1):
        for x in (-0.55, 0.5):
            pts = [(x, 2.9, side * 0.15), (x + 0.08, 2.3, side * 0.62), (x + 0.12, 1.2, side * 0.82), (x + 0.06, 0.1, side * 0.6), (x, -0.5, side * 0.3)]
            objs.append(tube(pts, [0.07, 0.085, 0.08, 0.06, 0.03], 8, "bone"))
    for k in range(5):
        x = -0.8 + k * 0.4
        h = r.uniform(0.35, 0.8)
        objs.append(cyl(0.07, 0.0, h, 6, (x, 2.95, r.uniform(-0.08, 0.08)), (r.uniform(-0.25, 0.25), 0, r.uniform(-0.25, 0.25)), "bone"))
    # Glowing cracks through the mortar.
    for k in range(5):
        x = r.uniform(-0.8, 0.8)
        y0 = -2.8 + k * 1.2
        pts = [(x, y0, 0.0), (x + r.uniform(-0.15, 0.15), y0 + 0.35, 0.0), (x + r.uniform(-0.2, 0.2), y0 + 0.7, 0.0)]
        for side in (-1, 1):
            objs.append(tube([(p[0], p[1], side * 0.2) for p in pts], 0.03, 4, "glow"))
    return join(objs, "bone_wall")


# --- Merchant -----------------------------------------------------------------------------

@asset
def merchant_stall():
    """The Pale Merchant's stall (origin at the ground, counter centre at z = -1.0): counter
    with plank front, four posts, a sagging torn canopy, shelves of wares, a hanging lantern."""
    r = random.Random(21)
    objs = []
    # Counter: top + front planks + legs.
    objs.append(box((2.5, 0.08, 1.05), (0, 0.9, -1.0), role="wood", bevel=0.012))
    for k in range(8):
        objs.append(box((0.3, 0.8, 0.05), (-1.05 + k * 0.3, 0.45, -0.5), (0, 0, r.uniform(-0.02, 0.02)), role="wood", bevel=0.008))
    for sx in (-1, 1):
        objs.append(box((0.08, 0.86, 1.0), (sx * 1.2, 0.43, -1.0), role="wood", bevel=0.01))
    objs.append(box((2.5, 0.06, 0.06), (0, 0.15, -0.5), role="iron"))
    # Posts and canopy frame.
    for sx in (-1, 1):
        for z in (-0.4, -2.4):
            objs.append(box((0.12, 2.75, 0.12), (sx * 1.3, 1.375, z), (0, 0, r.uniform(-0.03, 0.03)), role="wood", bevel=0.015))
        objs.append(box((0.1, 0.1, 2.2), (sx * 1.3, 2.7, -1.4), role="wood", bevel=0.01))
    objs.append(box((2.7, 0.1, 0.1), (0, 2.75, -0.4), role="wood", bevel=0.01))
    objs.append(box((2.7, 0.1, 0.1), (0, 2.95, -2.4), role="wood", bevel=0.01))
    # Canopy cloth (sagging, torn hem hanging over the front).
    import bmesh
    bm = bmesh.new()
    cols, rows = 14, 10
    grid = []
    for j in range(rows + 1):
        row = []
        for i in range(cols + 1):
            u, v = i / cols, j / rows
            x = (u - 0.5) * 2.8
            z = -2.45 + v * 2.15
            y = 3.0 - v * 0.25 - 0.18 * math.sin(math.pi * u) * math.sin(math.pi * v)
            row.append(bm.verts.new(C.G(x, y, z)))
        grid.append(row)
    # Hem hanging down from the front edge.
    hem = [grid[-1]]
    for j in range(1, 4):
        row = []
        for i in range(cols + 1):
            u = i / cols
            x = (u - 0.5) * 2.8
            drop = j * 0.11 * (1.0 if (i % 3) else 1.4) - (0.0 if i % 2 else 0.05)
            row.append(bm.verts.new(C.G(x, 2.75 - drop, -0.28 + 0.03 * j)))
        hem.append(row)
    for g in (grid, hem):
        for j in range(len(g) - 1):
            for i in range(cols):
                if g is hem and j == len(g) - 2 and i % 3 == 1:
                    continue
                bm.faces.new((g[j][i], g[j][i + 1], g[j + 1][i + 1], g[j + 1][i]))
    canopy = C.from_bm(bm, "canopy", "cloth")
    sol = canopy.modifiers.new("solid", 'SOLIDIFY')
    sol.thickness = 0.015
    C.apply(canopy)
    objs.append(canopy)
    # Back shelves with wares.
    for y in (1.2, 1.75):
        objs.append(box((2.3, 0.05, 0.35), (0, y, -2.25), role="wood", bevel=0.006))
    wares = []
    for k in range(9):  # jars and bottles
        x = -1.0 + k * 0.25 + r.uniform(-0.04, 0.04)
        y = 1.225 if k % 2 == 0 else 1.775
        h = r.uniform(0.18, 0.32)
        if k % 3 == 0:
            wares.append(lathe([(0.0, 0.0), (0.07, 0.0), (0.08, h * 0.5), (0.03, h * 0.75), (0.025, h), (0.0, h)], 10, "glass", (x, y, -2.25)))
        else:
            wares.append(lathe([(0.0, 0.0), (0.09, 0.0), (0.1, h * 0.7), (0.07, h * 0.85), (0.075, h), (0.0, h)], 10, "stone_pale", (x, y, -2.25)))
    for k in range(3):  # books
        wares.append(box((0.08, 0.26, 0.2), (0.6 + k * 0.09, 1.355, -2.25), (0, 0, 0.05 * k), role="cloth", bevel=0.01))
    # Counter wares: skulls, a ledger, coins, a candle.
    for k, x in enumerate((-0.85, 0.75)):
        sk = skull_obj(400 + k, ratio=0.35)
        C.place(sk, (x, 0.94, -0.9), (0, 0.4 - k, 0))
        wares.append(sk)
    wares.append(box((0.4, 0.06, 0.3), (-0.2, 0.97, -0.95), (0, 0.2, 0), role="cloth", bevel=0.01))
    wares.append(box((0.38, 0.015, 0.28), (-0.2, 1.0, -0.95), (0, 0.2, 0), role="stone_pale"))
    for k in range(6):
        wares.append(cyl(0.025, 0.025, 0.008 * (k % 3 + 1), 8, (0.3 + 0.04 * k, 0.94, -0.75 - 0.02 * k), role="gold"))
    for o in candle_obj(0.2, 0.035, 410):
        C.place(o, (0.35, 0.94, -1.25))
        wares.append(o)
    # Hanging lantern.
    lan = [tube([(0.0, 2.7, -1.0), (0.0, 2.35, -1.0)], 0.01, 4, "iron"),
           lathe([(0.0, 0.0), (0.1, 0.0), (0.1, 0.02), (0.08, 0.02), (0.08, 0.22), (0.12, 0.24), (0.0, 0.34)], 6, "iron", (0, 2.0, -1.0)),
           cyl(0.075, 0.075, 0.2, 6, (0, 2.02, -1.0), role="glow")]
    return join(objs + wares + lan, "merchant_stall")


@asset
def merchant_figure():
    """The Pale Merchant: a tall hooded figure in a ragged robe with a pale bone mask and
    long hands on the counter. Origin at the ground, faces +Z."""
    import bmesh
    robe = lathe([(0.0, 0.0), (0.48, 0.0), (0.44, 0.3), (0.36, 0.9), (0.3, 1.35), (0.28, 1.55), (0.22, 1.7), (0.0, 1.72)], 14, "cloth")
    C.jitter(robe, 0.03, 2, 3.0)
    hood = sphere(0.25, (0, 1.8, -0.02), (1.0, 1.15, 1.1), "cloth", 14, 8)
    boolean(hood, sphere(0.2, (0, 1.78, 0.14), (0.8, 1.0, 0.8), "dark", 12, 8))
    mask = sphere(0.13, (0, 1.78, 0.1), (0.8, 1.05, 0.55), "bone", 12, 8)
    for sx in (-1, 1):
        boolean(mask, sphere(0.025, (sx * 0.04, 1.81, 0.16), (1, 0.7, 1), "glow", 8, 6))
    shoulders = sphere(0.3, (0, 1.42, 0), (1.25, 0.55, 0.9), "cloth", 14, 8)
    arms = []
    for sx in (-1, 1):
        arms.append(tube([(sx * 0.33, 1.42, 0.0), (sx * 0.38, 1.15, 0.2), (sx * 0.3, 0.98, 0.5)], [0.1, 0.09, 0.11], 8, "cloth"))
        arms.append(tube([(sx * 0.3, 0.97, 0.56), (sx * 0.3, 0.95, 0.7), (sx * 0.32, 0.93, 0.78)], [0.025, 0.02, 0.012], 6, "bone"))
        for f in range(3):
            arms.append(tube([(sx * 0.3 + (f - 1) * 0.025, 0.95, 0.7), (sx * 0.3 + (f - 1) * 0.03, 0.93, 0.8), (sx * 0.3 + (f - 1) * 0.03, 0.91, 0.84)], 0.008, 4, "bone"))
    return join([robe, hood, mask, shoulders] + arms, "merchant_figure")


def main():
    args = C.init(sys.argv)
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        args = args[:i] + args[i + 2:]
    names = args or list(BUILT.keys())
    C.reset()
    done = []
    total = 0
    for name in names:
        C.clear_scene() if sheet is None else None
        ob = BUILT[name]()
        ob = C.finish(ob, name)
        total += export(ob, OUT + name + ".glb")
        if sheet:
            # keep it, hide everything else from the next build via a collection
            done.append(ob)
    print("TOTAL tris", total)
    if sheet:
        C.contact_sheet(done, sheet)


main()

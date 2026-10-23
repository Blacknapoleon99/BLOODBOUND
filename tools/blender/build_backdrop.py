"""BLOODBOUND background-world models (DEC-057), built headless and original.

  "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b \
      --python tools/blender/build_backdrop.py -- <repo_root> [names...] [--sheet out.png]

Writes assets/models/backdrop/gothic/<name>.glb. Godot metres (see gothic_common.G). Roles
become vertex colours in BackdropKit (stone, stone_dark, stone_pale, rock, glow, glow_dim,
iron, bone, wood), drawn by backdrop_stone.gdshader with triplanar stone detail.
Unit pieces are scaled by BackdropKit (towers: w = 1; rocks: radius 1; trees: height 1).
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Vector, noise
import gothic_common as C
from gothic_common import box, cyl, sphere, ico, torus, tube, lathe, prism_profile, organic, join, boolean, finish, export

OUT = "assets/models/backdrop/gothic/"
BUILT = {}


def asset(fn):
    BUILT[fn.__name__] = fn
    return fn


# --- Gothic vocabulary (all sizes in metres of the piece being built) -----------------------

def arch_outline(w, h_spring, apex_extra=None, steps=6):
    """Points (x, y) of a pointed (equilateral) arch opening of width w, springing at h_spring."""
    pts = [(-w / 2, 0.0)]
    for i in range(steps + 1):
        x = -w / 2 + (w / 2) * i / steps
        pts.append((x, h_spring + math.sqrt(max(0.0, w * w - (x - w / 2) ** 2))))
    for i in range(1, steps + 1):
        x = (w / 2) * i / steps
        pts.append((x, h_spring + math.sqrt(max(0.0, w * w - (x + w / 2) ** 2))))
    pts.append((w / 2, 0.0))
    return pts


def lancet(center, w, h, face_yaw, role="glow", depth=0.3, frame=True, mullion=True):
    """A pointed window: glowing pane + stone frame + mullion. `center` = bottom middle;
    face_yaw rotates the window's +Z normal around Y (0 = faces +Z)."""
    cx, cy, cz = center
    spring = max(0.0, h - 0.866 * w)
    prof = arch_outline(w, spring)
    pane = prism_profile(prof, depth, role, loc=(cx, cy, cz), rot=(0, face_yaw, 0))
    objs = [pane]
    if frame:
        t = w * 0.09
        fr = [(x, y) for x, y in arch_outline(w + t * 2, spring)]
        pts = []
        for x, y in fr:
            px = x
            pts.append((px, y))
        # moulding: tube along the outline (local) -> world
        ca, sa = math.cos(face_yaw), math.sin(face_yaw)
        world = [(cx + x * ca, cy + y, cz - x * sa) for x, y in pts]
        objs.append(tube([(wx + sa * depth * 0.5, wy, wz + ca * depth * 0.5) for wx, wy, wz in world], t, 4, "stone_pale", caps=True))
    if mullion and w > 0:
        ca, sa = math.cos(face_yaw), math.sin(face_yaw)
        objs.append(box((w * 0.07, h * 0.92, depth * 1.4), (cx, cy + h * 0.46, cz), (0, face_yaw, 0), "stone_pale"))
        # tracery: a small circle in the head
        objs.append(torus(w * 0.2, w * 0.035, (cx + sa * depth * 0.4, cy + spring + w * 0.45, cz + ca * depth * 0.4), (math.pi / 2, face_yaw, 0), "stone_pale", 10, 4))
    return objs


def pinnacle(base, w, h, role="stone_dark", crockets=True):
    """Square shaft with gablets, a pyramidal spirelet with crockets and a finial."""
    x, y, z = base
    shaft_h = h * 0.4
    objs = [box((w, shaft_h, w), (x, y + shaft_h / 2, z), role="stone"),
            cyl(w * 0.75, 0.0, h * 0.6, 4, (x, y + shaft_h, z), (0, math.pi / 4, 0), role)]
    for k in range(4):  # gablets
        a = math.tau * k / 4
        objs.append(prism_profile([(-w / 2, 0), (w / 2, 0), (0, w * 0.6)], w * 0.12, "stone",
                                  loc=(x + math.sin(a) * w * 0.5, y + shaft_h, z + math.cos(a) * w * 0.5), rot=(0, a, 0)))
    if crockets:
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            for j in range(1, 4):
                t = j / 4
                r = w * 0.75 * (1 - t) * 0.72
                objs.append(sphere(w * 0.09, (x + math.cos(a) * r, y + shaft_h + h * 0.6 * t, z + math.sin(a) * r), role=role, segs=5, rings=3))
    objs.append(sphere(w * 0.12, (x, y + h, z), role=role, segs=6, rings=4))
    return objs


def spire(base, w, h, sides=8, role="stone_dark", lucarnes=True, crockets=True):
    """An octagonal spire with crockets up its arrises, lucarnes at its foot and a finial."""
    x, y, z = base
    r = w * 0.5 / math.cos(math.pi / sides)
    objs = [cyl(r, 0.0, h, sides, (x, y, z), (0, math.pi / sides, 0), role)]
    if crockets:
        for k in range(sides):
            a = math.tau * k / sides
            for j in range(1, 9):
                t = j / 9
                rr = r * (1 - t) * 1.02
                objs.append(cyl(w * 0.035, 0.0, w * 0.09, 4, (x + math.cos(a) * rr, y + h * t, z + math.sin(a) * rr), (0.0, 0.0, 0.0), role))
    if lucarnes:
        for k in range(4):
            a = math.tau * k / 4
            px, pz = x + math.sin(a) * w * 0.36, z + math.cos(a) * w * 0.36
            objs += lancet((px + math.sin(a) * w * 0.05, y + h * 0.08, pz + math.cos(a) * w * 0.05), w * 0.12, w * 0.3, a, "glow", w * 0.06, frame=False, mullion=False)
            objs.append(prism_profile([(-w * 0.1, 0), (w * 0.1, 0), (0, w * 0.18)], w * 0.12, "stone", loc=(px, y + h * 0.08 + w * 0.3, pz), rot=(0, a, 0)))
    objs.append(torus(w * 0.06, w * 0.012, (x, y + h + w * 0.08, z), (math.pi / 2, 0, 0), "iron", 10, 4))
    objs.append(cyl(w * 0.012, w * 0.012, w * 0.25, 4, (x, y + h, z), role="iron"))
    return objs


def flyer(pier_top, wall_pt, thick, role="stone_dark"):
    """A flying buttress: an arched strut from a pier top to the wall, with a straight coping."""
    (px, py, pz), (wx, wy, wz) = pier_top, wall_pt
    pts_arch = []
    pts_top = []
    for i in range(9):
        t = i / 8
        x = px + (wx - px) * t
        z = pz + (wz - pz) * t
        y_top = py + (wy - py) * t
        sag = math.sin(math.pi * t) * thick * 2.2
        pts_top.append((x, y_top, z))
        pts_arch.append((x, y_top - thick * 2.6 + sag * 0.5 - (1 - t) * thick * 1.2, z))
    return [tube(pts_top, thick * 0.55, 4, role), tube(pts_arch, thick * 0.45, 4, role)]


def gothic_tower_obj(w, h, spire_h, broken=False, seed=1):
    """A full gothic tower at absolute size: buttressed shaft, string courses, lancets, belfry,
    corner pinnacles and a crocketed spire (or a snapped stump)."""
    r = random.Random(seed)
    objs = [box((w, h, w), (0, h / 2, 0), role="stone")]
    for sx in (-1, 1):
        for sz in (-1, 1):
            # stepped corner buttresses
            for k, (bw, bh) in enumerate(((0.24, 0.55), (0.19, 0.8), (0.14, 0.97))):
                objs.append(box((w * bw, h * bh, w * bw), (sx * w * 0.5, h * bh / 2, sz * w * 0.5), role="stone_dark"))
            objs += pinnacle((sx * w * 0.5, h, sz * w * 0.5), w * 0.16, w * 0.75)
    for f in (0.3, 0.6, 0.97):
        objs.append(box((w * 1.06, w * 0.04, w * 1.06), (0, h * f, 0), role="stone_pale"))
    for k in range(4):  # parapet battlements
        a = math.tau * k / 4
        for j in range(5):
            o = (j - 2) * w * 0.2
            px, pz = math.sin(a) * w * 0.5 + math.cos(a) * o, math.cos(a) * w * 0.5 - math.sin(a) * o
            objs.append(box((w * 0.1, w * 0.1, w * 0.06), (px, h + w * 0.05, pz), (0, a, 0), "stone"))
    for k in range(4):
        a = math.tau * k / 4
        fx, fz = math.sin(a) * w * 0.5, math.cos(a) * w * 0.5
        for side in (-1, 1):  # belfry pair
            ox = math.cos(a) * side * w * 0.17
            oz = -math.sin(a) * side * w * 0.17
            objs += lancet((fx + ox, h * 0.7, fz + oz), w * 0.2, h * 0.2, a, "glow" if r.random() < 0.75 else "glow_dim", w * 0.05)
        objs += lancet((fx, h * 0.4, fz), w * 0.12, h * 0.12, a, "glow_dim", w * 0.04, mullion=False)
    if broken:
        # A snapped spire: the lower third of the octagon with a jagged, slanted break.
        stump = cyl(w * 0.45, w * 0.3, spire_h * 0.35, 8, (0, h, 0), (0, math.pi / 8, 0), "stone_dark")
        C.bake_transform(stump)
        top_y = h + spire_h * 0.35
        for v in stump.data.vertices:
            if v.co.z > top_y - 0.001:
                v.co.z = top_y - spire_h * (0.08 + 0.16 * r.random()) - v.co.x * 0.25
        objs.append(stump)
        for k in range(4):
            objs.append(box((w * 0.18,) * 3, (r.uniform(-0.3, 0.3) * w, h + w * 0.1, r.uniform(-0.3, 0.3) * w),
                            (r.random(), r.random(), r.random()), "stone_dark"))
    else:
        objs += spire((0, h, 0), w * 0.9, spire_h)
    return objs


# --- Unit kit pieces for BackdropKit ---------------------------------------------------------

@asset
def bd_tower():
    """Unit gothic tower (w = 1, shaft h = 4, spire 3): BackdropKit scales by w."""
    return C.decimate_to(join(gothic_tower_obj(1.0, 4.0, 3.0, False, 3), "tower"), 2600)


@asset
def bd_tower_broken():
    return C.decimate_to(join(gothic_tower_obj(1.0, 4.0, 3.0, True, 4), "tower_broken"), 2400)


@asset
def bd_tower_squat():
    """A stubbier tower (h = 2.4) with a short spire, for islands."""
    return C.decimate_to(join(gothic_tower_obj(1.0, 2.4, 1.8, False, 5), "tower_squat"), 2600)


def _rock(seed, strata=True):
    r = random.Random(seed)
    ob = ico(1.0, 4, role="rock")
    me = ob.data
    off = Vector((seed * 3.7, seed * 1.3, seed * 2.1))
    for v in me.vertices:
        g = Vector((v.co.x, v.co.z, -v.co.y))  # Godot space unit sphere
        n = noise.noise(g * 1.7 + off)
        n2 = noise.noise(g * 5.0 + off * 2.0)
        rad = 1.0 + n * 0.3 + n2 * 0.06
        y = g.y
        if y >= 0.0:
            y = 0.1 + y * 0.12 + n * 0.05 + n2 * 0.02
        else:
            rad *= 1.0 + y * 0.62
            y = y * 1.9 + n * 0.25
            if strata:
                band = (y * 5.0 + n * 0.6) % 1.0
                rad *= 1.0 + 0.07 * (band ** 3) - 0.03
        x, z = g.x * rad, g.z * rad
        v.co = Vector((x, -z, y))
    C.jitter(ob, 0.025, seed, 6.0)
    C.decimate_to(ob, 1400)
    # Lighter role on the walkable-looking top, dark rock below.
    ob.data.materials.append(C.mat("rock_top"))
    for p in ob.data.polygons:
        if p.normal.z > 0.6 and p.center.z > 0.0:
            p.material_index = 1
    return ob


@asset
def bd_rock_0():
    return _rock(1)


@asset
def bd_rock_1():
    return _rock(2)


@asset
def bd_rock_2():
    return _rock(3)


@asset
def bd_rock_3():
    return _rock(4)


def _tree(seed):
    """Gnarled dead tree, height ~1, base at 0, via a skin-modified branch skeleton."""
    r = random.Random(seed)
    bm = bmesh.new()
    verts = []
    radii = []

    def grow(p, d, length, rad, depth, parent):
        steps = 3
        prev = parent
        cur = Vector(p)
        for s in range(steps):
            d = (d + Vector((r.uniform(-0.25, 0.25), r.uniform(-0.05, 0.1), r.uniform(-0.25, 0.25)))).normalized()
            cur = cur + d * (length / steps)
            v = bm.verts.new(C.G(cur.x, cur.y, cur.z))
            verts.append(v)
            radii.append(rad * (1 - 0.25 * (s + 1) / steps))
            bm.edges.new((prev, v))
            prev = v
        if depth <= 0:
            return
        for i in range(r.randint(2, 3) if depth > 1 else r.randint(2, 4)):
            side = Vector((r.uniform(-1, 1), 0.0, r.uniform(-1, 1))).normalized()
            nd = (d * 0.7 + side * r.uniform(0.7, 1.4) + Vector((0, r.uniform(-0.15, 0.35), 0))).normalized()
            grow(cur, nd, length * r.uniform(0.62, 0.82), rad * 0.6, depth - 1, prev)

    root = bm.verts.new(C.G(0, -0.05, 0))
    verts.append(root)
    radii.append(0.07)
    # roots
    for k in range(4):
        a = math.tau * k / 4 + r.uniform(-0.3, 0.3)
        v = bm.verts.new(C.G(math.cos(a) * 0.14, -0.02, math.sin(a) * 0.14))
        verts.append(v)
        radii.append(0.025)
        bm.edges.new((root, v))
    grow(Vector((0, -0.05, 0)), Vector((r.uniform(-0.15, 0.15), 1.0, r.uniform(-0.15, 0.15))).normalized(), 0.36, 0.05, 4, root)
    me = bpy.data.meshes.new("tree")
    bm.to_mesh(me)
    bm.free()
    ob = C._link("tree", me)
    ob.data.materials.append(C.mat("wood"))
    sk = ob.modifiers.new("skin", 'SKIN')
    # Skin vertex radii
    layer = ob.data.skin_vertices[0].data if ob.data.skin_vertices else None
    if layer is None:
        # the modifier creates the layer lazily: evaluate once
        bpy.context.view_layer.update()
        layer = ob.data.skin_vertices[0].data
    for i, sv in enumerate(layer):
        rr = radii[i] if i < len(radii) else 0.01
        sv.radius = (rr, rr)
    layer[0].use_root = True
    sub = ob.modifiers.new("sub", 'SUBSURF')
    sub.levels = 1
    C.apply(ob)
    C.jitter(ob, 0.008, seed, 14.0)
    C.decimate_to(ob, 1000)
    return ob


@asset
def bd_tree_0():
    return _tree(11)


@asset
def bd_tree_1():
    return _tree(12)


@asset
def bd_tree_2():
    return _tree(13)


@asset
def bd_pillar_top():
    """The broken crown of a clustered abyss pillar (r = 1): capital, a jagged snapped drum.
    Origin at the top of the shaft (the capital's base)."""
    objs = [cyl(1.0, 1.0, 0.8, 12, (0, -0.8, 0), role="stone")]
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        objs.append(cyl(0.38, 0.38, 0.8, 8, (math.cos(a) * 0.95, -0.8, math.sin(a) * 0.95), role="stone_dark"))
    objs.append(lathe([(0.0, 0.0), (1.3, 0.0), (1.55, 0.35), (1.8, 0.55), (1.8, 0.75), (0.0, 0.75)], 8, "stone_pale", (0, 0, 0), phase=math.pi / 8))
    for k in range(8):
        a = math.tau * k / 8 + math.pi / 8
        objs.append(sphere(0.3, (math.cos(a) * 1.45, 0.4, math.sin(a) * 1.45), (1, 0.8, 1), "stone_pale", 6, 4))
    drum = cyl(0.95, 0.95, 2.2, 12, (0, 0.75, 0), role="stone")
    cut = ico(1.0, 3, (0.3, 2.6, 0.0), (1.6, 1.1, 1.6), "stone", (0.4, 0.0, 0.3))
    C.jitter(cut, 0.35, 7, 1.5)
    boolean(drum, cut, transfer=False)
    objs.append(drum)
    ob = join(objs, "pillar_top")
    C.jitter(ob, 0.04, 3, 1.2)
    return ob


@asset
def bd_ruin_wall():
    """A ruined slab of cathedral wall, unit width (x -0.5..0.5), height 1, depth 1 (z): ragged
    courses broken off at uneven heights, a tall lancet glowing from within, side buttresses,
    string courses and loose blocks. Scaled by the kit (w, h, 2.2 m)."""
    r = random.Random(17)
    objs = []
    strips = 9
    for k in range(strips):
        x0 = -0.5 + k / strips
        top = 1.0 - 0.32 * abs(math.sin(k * 1.7 + 0.4)) - (0.25 if k in (6, 7) else 0.0) - r.uniform(0.0, 0.06)
        if k in (3, 4, 5):
            top = max(top, 0.95)  # the lancet's head stays standing
        strip = box((1.0 / strips + 0.002, top, 1.0), (x0 + 0.5 / strips, top / 2, 0), role="stone")
        objs.append(strip)
        # broken course blocks on top
        if r.random() < 0.7:
            objs.append(box((0.08, 0.05, 0.9), (x0 + 0.05, top + 0.02, r.uniform(-0.05, 0.05)), (r.uniform(-0.3, 0.3), 0, r.uniform(-0.4, 0.4)), "stone_dark"))
    wall = join(objs, "ruin_wall")
    win = prism_profile(arch_outline(0.22, 0.32), 1.4, "glow_dim", loc=(0.0, 0.36, 0))
    boolean(wall, win)
    objs = [wall]
    objs.append(prism_profile(arch_outline(0.22, 0.32), 0.12, "glow", loc=(0.0, 0.36, 0)))
    objs.append(box((0.025, 0.45, 1.05), (0.0, 0.58, 0), role="stone_pale"))
    objs.append(torus(0.05, 0.012, (0.0, 0.36 + 0.32 + 0.12, 0.51), (math.pi / 2, 0, 0), "stone_pale", 12, 4))
    objs.append(torus(0.05, 0.012, (0.0, 0.36 + 0.32 + 0.12, -0.51), (math.pi / 2, 0, 0), "stone_pale", 12, 4))
    for x in (-0.55, 0.53):
        objs.append(box((0.1, 0.62, 1.3), (x, 0.31, 0), role="stone_dark"))
        objs.append(prism_profile([(-0.65, 0.0), (0.65, 0.0), (0.0, 0.18)], 0.1, "stone_dark", loc=(x, 0.62, 0), rot=(0, math.pi / 2, 0)))
    for y in (0.22, 0.6):
        objs.append(box((1.02, 0.02, 1.04), (0, y, 0), role="stone_pale"))
    for k in range(4):
        objs.append(box((0.08, 0.06, 0.12), (r.uniform(-0.45, 0.45), r.uniform(0.0, 0.05), r.uniform(-0.8, 0.8)), (r.random(), r.random(), r.random()), "stone_dark"))
    return join(objs, "ruin_wall")


@asset
def bd_ribcage():
    """A colossal carcass, unit length along +X: vertebrae, ribs curling up on both sides,
    a horned skull at the head (glowing eye sockets)."""
    r = random.Random(7)
    objs = []
    for i in range(12):
        x = i / 11.0
        objs.append(sphere(0.035, (x, 0, 0), (1, 1.25, 1.1), "bone", 8, 5))
        objs.append(cyl(0.012, 0.0, 0.1, 5, (x, 0.02, 0), role="bone"))
        for s in (-1, 1):
            objs.append(cyl(0.008, 0.002, 0.05, 4, (x, 0.0, 0.02 * s), (0, 0, 0), "bone"))
    objs.append(tube([(i / 11.0, -0.005, 0) for i in range(12)], 0.016, 6, "bone"))
    for i in range(9):
        x = 0.15 + 0.6 * i / 9
        span = 0.16 + 0.1 * math.sin(math.pi * i / 9)
        for s in (-1, 1):
            if r.random() < 0.12:
                continue
            pts = []
            rads = []
            for k in range(9):
                t = k / 8
                pts.append((x - 0.03 * t, span * 1.25 * math.sin(t * math.pi * 0.8), s * span * (1 - math.cos(t * math.pi * 0.62)) * 1.2))
                rads.append(0.016 * (1 - 0.6 * t))
            objs.append(tube(pts, rads, 6, "bone"))
    head = (1.03, 0.02, 0)
    skull = organic([sphere(0.09, head, (1, 0.78, 0.85), "bone", 14, 8),
                     box((0.11, 0.04, 0.07), (1.11, -0.01, 0), role="bone"),
                     tube([(1.02, 0.03, -0.06), (1.12, -0.02, -0.04), (1.15, -0.03, 0.0), (1.12, -0.02, 0.04), (1.02, 0.03, 0.06)], 0.012, 6, "bone")],
                    voxel=0.006, smooth=3, name="head", role="bone")
    C.decimate_to(skull, 1500)
    for s in (-1, 1):
        boolean(skull, sphere(0.02, (1.08, 0.03, 0.035 * s), role="glow", segs=8, rings=6))
    objs.append(skull)
    for s in (-1, 1):
        objs.append(tube([(1.0, 0.06, 0.04 * s), (0.95, 0.13, 0.09 * s), (0.88, 0.16, 0.16 * s), (0.85, 0.12, 0.2 * s)], [0.014, 0.011, 0.007, 0.002], 6, "bone"))
    return join(objs, "ribcage")


@asset
def bd_pinnacle():
    """A unit pinnacle (base w = 1, height 4) for buttress piers."""
    return join(pinnacle((0, 0, 0), 1.0, 4.0), "pinnacle")


@asset
def bd_bat():
    """A bat silhouette (wingspan ~1, wings spread along X), body along Z."""
    body = organic([sphere(0.07, (0, 0, 0), (0.8, 0.7, 1.5), "stone_dark", 10, 6), sphere(0.05, (0, 0.02, 0.11), (1, 1, 1), "stone_dark", 8, 5)],
                   voxel=0.01, smooth=2, name="bat_body", role="stone_dark")
    C.decimate_to(body, 120)
    objs = [body]
    for s in (-1, 1):
        prof = [(0.0, 0.05), (0.18 * s, 0.1), (0.35 * s, 0.14), (0.5 * s, 0.08), (0.42 * s, -0.02), (0.34 * s, 0.03), (0.26 * s, -0.04), (0.17 * s, 0.01), (0.08 * s, -0.06), (0.0, -0.06)]
        if s < 0:
            prof = list(reversed(prof))
        wing = prism_profile(prof, 0.01, "stone_dark", rot=(-math.pi / 2, 0, 0))
        objs.append(wing)
    for s in (-1, 1):
        objs.append(cyl(0.012, 0.0, 0.05, 4, (0.025 * s, 0.03, 0.14), role="stone_dark"))
    return join(objs, "bat")


# --- The cathedral ---------------------------------------------------------------------------

@asset
def bd_cathedral():
    """The colossal cathedral (~330 m): west front faces -X, nave along +X (same layout and
    scale as the old procedural one, so BackdropHorizon's placement is unchanged)."""
    r = random.Random(77)
    objs = []
    NW = 70.0
    # Nave walls with bays, clerestory, roof.
    objs.append(box((240, 110, NW), (140, 55, 0), role="stone"))
    objs.append(prism_profile([(-NW / 2 - 3, 0), (NW / 2 + 3, 0), (0, 44)], 240, "stone_dark", loc=(140, 110, 0), rot=(0, math.pi / 2, 0)))
    objs.append(box((242, 4, NW + 8), (140, 111, 0), role="stone_pale"))
    for s in (-1, 1):
        objs.append(box((240, 60, 30), (140, 30, s * 50), role="stone_dark"))
        objs.append(prism_profile([(0, 0), (30, 0), (0, 14)], 240, "stone_dark", loc=(140, 60, s * 35), rot=(0, math.pi / 2 if s > 0 else -math.pi / 2, 0)))
    for i in range(9):
        x = 40 + i * 25.0
        for s in (-1, 1):
            yaw = 0.0 if s > 0 else math.pi
            objs += lancet((x, 66, s * (NW / 2 + 0.3)), 9.0, 34.0, yaw, "glow" if r.random() < 0.8 else "glow_dim", 1.4)
            objs += lancet((x, 14, s * 65.3), 7.0, 26.0, yaw, "glow_dim", 1.2)
            # wall shafts between bays
            objs.append(box((3.0, 108, 2.4), (x + 12.5, 54, s * (NW / 2 + 1.0)), role="stone_pale"))
            # Buttress pier, pinnacle, double flyers.
            objs.append(box((8, 92, 10), (x + 12.5, 46, s * 92), role="stone"))
            objs.append(box((10, 8, 12), (x + 12.5, 4, s * 92), role="stone_dark"))
            objs += pinnacle((x + 12.5, 92, s * 92), 7.0, 30.0)
            if r.random() < 0.85:
                objs += flyer((x + 12.5, 86, s * 87), (x + 12.5, 100, s * (NW / 2 + 1)), 3.2)
                objs += flyer((x + 12.5, 60, s * 87), (x + 12.5, 70, s * (NW / 2 + 1)), 2.6)
            else:
                objs.append(box((6, 6, 6), (x + 12.5, 88, s * 78), (0.4, 0.7, 0.2), "stone_dark"))
    # West front.
    objs.append(box((20, 150, 84), (10, 75, 0), role="stone"))
    objs.append(prism_profile([(-42, 0), (42, 0), (0, 36)], 20, "stone", loc=(10, 150, 0), rot=(0, math.pi / 2, 0)))
    objs.append(box((22, 3, 86), (10, 150, 0), role="stone_pale"))
    objs += pinnacle((10, 186, 0), 5.0, 26.0)
    # Gallery of kings: a row of small blind arches.
    for k in range(13):
        z = -36 + k * 6.0
        objs += lancet((-0.4, 126, z), 3.2, 12.0, -math.pi / 2, "stone_dark", 0.8, frame=False, mullion=False)
    # Three portals, deep orders, glowing doors.
    for z, w, h in ((0, 22, 46), (-30, 11, 28), (30, 11, 28)):
        objs += lancet((-0.6, 4, z), w, h, -math.pi / 2, "glow", 1.6, frame=False, mullion=False)
        for o in range(4):
            ww = w + 3.0 * (o + 1)
            prof = arch_outline(ww, max(0.0, h - 0.866 * w) + 0.5 * o)
            objs.append(tube([(-1.0 - o * 1.2, 4 + y, z + x) for x, y in prof], 0.9, 4, "stone_pale"))
        objs.append(prism_profile([(-w / 2 - 5, 0), (w / 2 + 5, 0), (0, w * 0.9)], 2.0, "stone", loc=(-3, 4 + h + 4, z), rot=(0, -math.pi / 2, 0)))
    # Rose window: glowing disc, stone ring, spokes, petals.
    rc = (-0.8, 100.0, 0.0)
    objs.append(cyl(24, 24, 1.2, 32, rc, (0, 0, math.pi / 2), "glow"))
    objs.append(torus(25.5, 1.6, (rc[0] - 1.0, rc[1], rc[2]), (0, 0, math.pi / 2), "stone_pale", 40, 6))
    objs.append(torus(7.0, 1.2, (rc[0] - 1.0, rc[1], rc[2]), (0, 0, math.pi / 2), "stone_pale", 24, 6))
    for k in range(16):
        a = math.tau * k / 16
        d = Vector((0, math.cos(a), math.sin(a)))
        p0 = Vector(rc) + Vector((-1.2, 0, 0)) + d * 7.0
        p1 = Vector(rc) + Vector((-1.2, 0, 0)) + d * 24.5
        objs.append(tube([tuple(p0), tuple(p1)], 0.55, 4, "stone_pale"))
        q = Vector(rc) + Vector((-1.4, 0, 0)) + d * 15.5
        a2 = a + math.pi / 16
        d2 = Vector((0, math.cos(a2), math.sin(a2)))
        objs.append(torus(3.2, 0.45, tuple(Vector(rc) + Vector((-1.4, 0, 0)) + d2 * 17.5), (0, 0, math.pi / 2), "stone_pale", 12, 4))
    # Twin west towers (north intact, south snapped).
    for z, h, sp, broken in ((-62, 215, 120, False), (62, 200, 110, True)):
        tw = gothic_tower_obj(34.0, h, sp, broken, 31 if broken else 30)
        t = join(tw, "west_tower")
        C.place(t, (15, 0, z))
        objs.append(t)
    # Transepts with rose windows.
    objs.append(box((50, 140, 150), (215, 70, 0), role="stone"))
    objs.append(prism_profile([(-25, 0), (25, 0), (0, 40)], 150, "stone_dark", loc=(215, 140, 0)))
    for s in (-1, 1):
        objs.append(cyl(14, 14, 1.2, 28, (215, 92, s * 75.6), (math.pi / 2, 0, 0), "glow"))
        objs.append(torus(15.5, 1.2, (215, 92, s * 76.4), (math.pi / 2, 0, 0), "stone_pale", 32, 5))
        for k in range(8):
            a = math.tau * k / 8
            objs.append(tube([(215 + math.cos(a) * 4, 92 + math.sin(a) * 4, s * 76.5), (215 + math.cos(a) * 14.5, 92 + math.sin(a) * 14.5, s * 76.5)], 0.5, 4, "stone_pale"))
        objs += lancet((215, 10, s * 75.4), 16.0, 40.0, 0.0 if s > 0 else math.pi, "glow", 1.5, frame=False, mullion=False)
        for x in (190.5, 239.5):
            objs.append(box((7, 150, 7), (x, 75, s * 72), role="stone_dark"))
            objs += pinnacle((x, 150, s * 72), 7.0, 32.0)
    # Crossing tower with the great spire.
    ct = join(gothic_tower_obj(46.0, 95.0, 150.0, False, 40), "crossing")
    C.place(ct, (215, 120, 0))
    objs.append(ct)
    # Apse with radiating chapels and tall lancets.
    objs.append(cyl(36, 36, 110, 10, (300, 0, 0), (0, math.pi / 10, 0), "stone"))
    objs.append(cyl(38, 0, 40, 10, (300, 110, 0), (0, math.pi / 10, 0), "stone_dark"))
    for k in range(10):
        a = -math.pi / 2 + math.pi * k / 9
        ax, az = 300 + math.cos(a) * 36.5, math.sin(a) * 36.5
        objs += lancet((ax, 30, az), 6.0, 60.0, math.atan2(math.cos(a), math.sin(a)), "glow" if r.random() < 0.8 else "glow_dim", 1.2, frame=False)
        objs.append(box((4, 112, 4), (300 + math.cos(a + math.pi / 10) * 37, 56, math.sin(a + math.pi / 10) * 37), role="stone_dark"))
        objs += pinnacle((300 + math.cos(a + math.pi / 10) * 37, 112, math.sin(a + math.pi / 10) * 37), 4.0, 20.0, crockets=False)
    for k in range(5):
        a = -math.pi / 2 + math.pi * (k + 0.5) / 5
        cx, cz = 300 + math.cos(a) * 44, math.sin(a) * 44
        objs.append(cyl(12, 12, 45, 8, (cx, 0, cz), role="stone_dark"))
        objs.append(cyl(13, 0, 16, 8, (cx, 45, cz), role="stone_dark"))
    ob = join(objs, "cathedral")
    return ob


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
        if sheet is None:
            C.clear_scene()
        ob = BUILT[name]()
        ob = C.finish(ob, name, smooth=name.startswith(("bd_tree", "bd_ribcage", "bd_bat")))
        total += export(ob, OUT + name + ".glb")
        done.append(ob)
    print("TOTAL tris", total)
    if sheet:
        C.contact_sheet(done, sheet)


main()

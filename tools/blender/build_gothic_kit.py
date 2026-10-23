"""BLOODBOUND gothic level kit (DEC-056): procedural, original, CC0-free-of-sources modelling.

Run headless (never touches a live Blender session):
    blender.exe -b --factory-startup --python tools/blender/build_gothic_kit.py -- assets/models/kit/gothic_kit.glb

Every piece is authored in GODOT coordinates (Y up, +Z = the piece's outward face) and converted
to Blender's Z-up frame only when the final mesh is written, so the glTF exporter's Y-up
conversion lands each piece back exactly as authored here.

Vertex colour channels (COLOR_0, read by scripts/art/shaders/gothic_kit.gdshader):
    r = cavity / exposure (1 = open face, low = mortar joints and recesses)
    g = glow mask (crack cores, iron rims, rivets)
    b = bone mask (carved bone handholds)

Pieces (unit sizes; GothicKit scales and tiles them to any box):
    top_a/b/c        2 x 0.22 x 2 m random-ashlar paving cells, top at y = 0, mortar bed between
                     slabs; top_c is worn (a sunk, broken slab and a tilted one)
    edge, edge_b     1 m coping strip (z -0.5..0), moulded cornice lip overhanging +0.1 below the
                     top, corbel table under it; edge_b has a broken chunk out of the lip
    corner           0.5 x 0.5 outer corner, mitred moulding (outer faces at x = 0 and z = 0)
    ashlar_a/b/c     2 x 1 m masonry panel (two courses), face at z = 0, top at y = 0
    arcade           2 x 3 m blind pointed arch panel (colonnettes, hood moulding, sill)
    quoin            0.3 x 1 x 0.3 vertical corner stones (outer corner at x = 0, z = 0)
    buttress         0.5 x 1 m shallow buttress strip with a sloped weathering top
    base             1 x 0.2 x 1 rough underside slab (top at y = 0)
    pillar_capital   1 x 1 x 1 m capital (abacus top at y = 0)
    pillar_shaft     1 x 1 x 1 m clustered shaft segment (y -1..0)
    pillar_band      annulet ring (y -0.1..0.1)
    pillar_broken    jagged broken shaft end (y -1..0)
    handhold         carved corbel with a bone grip, back at z = 0, sticking out +z
    grate            3 x 0.6 x 3 m riveted iron grate platform (centred)
    cracked          2.6 x 1 x 2.6 m shattered slab over a glowing core (centred)
    portcullis       0.3 x 5 x 3.6 m iron portcullis (centred)
"""

import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Matrix, Vector

# --------------------------------------------------------------------------------------------
# Mesh builder: plain python lists, so pieces can be assembled from many small bmeshes.
# --------------------------------------------------------------------------------------------


# Vertex alpha: 1 = walkable paving (gets the TOP texture set when it faces up near the top),
# 0 = dressed trim (coping, abacus): keeps the side stone even on top. Set per piece in main().
TRIM_ALPHA = [1.0]


class Builder:
    def __init__(self):
        self.verts = []
        self.faces = []
        self.fcol = []      # per face (r, g, b)
        self.fsmooth = []

    def add_bm(self, bm, col=(1.0, 0.0, 0.0), smooth=False, colfn=None):
        base = len(self.verts)
        bm.normal_update()
        bm.verts.ensure_lookup_table()
        index = {}
        for i, v in enumerate(bm.verts):
            index[v] = base + i
            self.verts.append(v.co.copy())
        for f in bm.faces:
            self.faces.append([index[v] for v in f.verts])
            c = colfn(f) if colfn else col
            self.fcol.append(tuple(c) + (TRIM_ALPHA[0],) if len(c) == 3 else tuple(c))
            self.fsmooth.append(smooth)

    def add_poly(self, pts, faces, col=(1.0, 0.0, 0.0), smooth=False):
        base = len(self.verts)
        self.verts.extend([Vector(p) for p in pts])
        for f in faces:
            self.faces.append([base + i for i in f])
            self.fcol.append(tuple(col) + (TRIM_ALPHA[0],) if len(col) == 3 else tuple(col))
            self.fsmooth.append(smooth)


def _bevel(bm, amount, segments=1):
    if amount <= 0.0:
        return
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=amount, offset_type='OFFSET',
                    segments=segments, profile=0.5, affect='EDGES', clamp_overlap=True)


def _fill_boundaries(bm):
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)


def _chip(bm, rng, size, depth_range=(0.03, 0.08), keep_top=True):
    """Knocks a corner off a box-like stone with a random plane (filled), for a hand-cut look."""
    sx, sy, sz = size
    corner = Vector((rng.choice((-1, 1)) * sx * 0.5,
                     (-1 if keep_top and rng.random() < 0.7 else rng.choice((-1, 1))) * sy * 0.5,
                     rng.choice((-1, 1)) * sz * 0.5))
    d = Vector((corner.x / max(sx, 1e-3) + rng.uniform(-0.3, 0.3),
                corner.y / max(sy, 1e-3) + rng.uniform(-0.3, 0.3),
                corner.z / max(sz, 1e-3) + rng.uniform(-0.3, 0.3))).normalized()
    depth = rng.uniform(*depth_range)
    # The plane passes `depth` inside the corner along its direction.
    co = corner - d * depth
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=d, clear_outer=True)
    _fill_boundaries(bm)


def stone(B, c, s, bev=0.03, seg=1, col=(1.0, 0.0, 0.0), rng=None, jit=0.0, chips=0,
          chip_depth=(0.03, 0.08), top_cap=None, colfn=None, smooth=False):
    """A bevelled, optionally chipped and jittered box stone centred at c with size s.
    top_cap: the highest y (in the stone's local frame) any vertex may reach after jitter."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
    _bevel(bm, min(bev, min(s) * 0.45), seg)
    if rng is not None:
        for _ in range(chips):
            _chip(bm, rng, s, chip_depth)
        if jit > 0.0:
            for v in bm.verts:
                v.co += Vector((rng.uniform(-jit, jit), rng.uniform(-jit, jit), rng.uniform(-jit, jit)))
    cap = s[1] * 0.5 if top_cap is None else top_cap
    for v in bm.verts:
        if v.co.y > cap:
            v.co.y = cap
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(c))
    B.add_bm(bm, col, smooth, colfn)
    bm.free()


def prism(B, poly, z0, z1, col=(1.0, 0.0, 0.0), axis='z', offset=(0.0, 0.0, 0.0), bev=0.0):
    """Extrudes a 2D polygon (counter-clockwise, in the plane normal to `axis`) between z0..z1."""
    bm = bmesh.new()
    n = len(poly)
    lo, hi = [], []
    for (a, b) in poly:
        if axis == 'z':
            lo.append(bm.verts.new((a, b, z0)))
            hi.append(bm.verts.new((a, b, z1)))
        elif axis == 'x':   # poly is (z, y)
            lo.append(bm.verts.new((z0, b, a)))
            hi.append(bm.verts.new((z1, b, a)))
        else:               # 'y': poly is (x, z)
            lo.append(bm.verts.new((a, z0, b)))
            hi.append(bm.verts.new((a, z1, b)))
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _bevel(bm, bev)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(offset))
    B.add_bm(bm, col)
    bm.free()


def sweep(B, profile, path, col=(1.0, 0.0, 0.0), closed=False, caps=True, smooth=False):
    """Sweeps a closed 2D profile [(out, y)] along a horizontal polyline path [(x, z)] with
    mitred joints; `out` is measured to the path's left in plan (+Z for a path running +X),
    the outward side of the kit's edge pieces. Used for cornices round a corner."""
    bm = bmesh.new()
    rings = []
    m = len(path)
    for i in range(m):
        p = Vector((path[i][0], 0.0, path[i][1]))
        if closed or 0 < i < m - 1:
            a = Vector((path[i - 1][0], 0.0, path[i - 1][1]))
            b = Vector((path[(i + 1) % m][0], 0.0, path[(i + 1) % m][1]))
            d0 = (p - a).normalized()
            d1 = (b - p).normalized()
            n0 = Vector((-d0.z, 0.0, d0.x))
            n1 = Vector((-d1.z, 0.0, d1.x))
            n = (n0 + n1).normalized()
            k = 1.0 / max(0.2, n.dot(n0))
        else:
            d = (Vector((path[1][0], 0.0, path[1][1])) - p) if i == 0 else (p - Vector((path[i - 1][0], 0.0, path[i - 1][1])))
            d.normalize()
            n = Vector((-d.z, 0.0, d.x))
            k = 1.0
        ring = []
        for (o, y) in profile:
            q = p + n * (o * k)
            ring.append(bm.verts.new((q.x, y, q.z)))
        rings.append(ring)
    pn = len(profile)
    segs = m if closed else m - 1
    for i in range(segs):
        r0 = rings[i]
        r1 = rings[(i + 1) % m]
        for j in range(pn):
            k2 = (j + 1) % pn
            bm.faces.new((r0[j], r0[k2], r1[k2], r1[j]))
    if caps and not closed:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    B.add_bm(bm, col, smooth)
    bm.free()


def lathe(B, profile, sides, center=(0.0, 0.0, 0.0), col=(1.0, 0.0, 0.0), smooth=True, phase=0.0,
          cap_top=False, cap_bottom=False, scale_xz=(1.0, 1.0)):
    """Revolves [(radius, y)] (bottom to top) round a vertical axis through `center`."""
    bm = bmesh.new()
    rings = []
    for (r, y) in profile:
        ring = []
        for k in range(sides):
            a = phase + 2.0 * math.pi * k / sides
            ring.append(bm.verts.new((center[0] + math.cos(a) * r * scale_xz[0], center[1] + y,
                                      center[2] + math.sin(a) * r * scale_xz[1])))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2]))
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    B.add_bm(bm, col, smooth)
    bm.free()


def hlathe(B, profile, sides, center, col=(1.0, 0.0, 0.0), smooth=True):
    """Revolves [(radius, x)] round a horizontal X axis through `center` (bones, bars)."""
    bm = bmesh.new()
    rings = []
    for (r, x) in profile:
        ring = []
        for k in range(sides):
            a = 2.0 * math.pi * k / sides
            ring.append(bm.verts.new((center[0] + x, center[1] + math.cos(a) * r, center[2] + math.sin(a) * r)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    B.add_bm(bm, col, smooth)
    bm.free()


MORTAR = (0.32, 0.0, 0.0)
RECESS = (0.55, 0.0, 0.0)
OPEN = (1.0, 0.0, 0.0)

# --------------------------------------------------------------------------------------------
# Pieces
# --------------------------------------------------------------------------------------------


def _split(rng, rect, out, max_side=0.95):
    x0, z0, x1, z1 = rect
    w, d = x1 - x0, z1 - z0
    if (w <= max_side and d <= max_side) or (w < 0.8 and d < 0.8):
        out.append(rect)
        return
    if w >= d:
        t = x0 + w * rng.uniform(0.36, 0.64)
        _split(rng, (x0, z0, t, z1), out, max_side)
        _split(rng, (t, z0, x1, z1), out, max_side)
    else:
        t = z0 + d * rng.uniform(0.36, 0.64)
        _split(rng, (x0, z0, x1, t), out, max_side)
        _split(rng, (x0, t, x1, z1), out, max_side)


def paving(B, seed, worn=False):
    """A 2 x 2 m paving cell (top at y = 0) of irregular random-ashlar slabs over a mortar bed.
    worn: one slab sunk and broken, one tilted."""
    rng = random.Random(seed)
    stone(B, (0.0, -0.13, 0.0), (2.0, 0.18, 2.0), bev=0.0, col=MORTAR)
    rects = []
    _split(rng, (-1.0, -1.0, 1.0, 1.0), rects)
    gap = 0.016
    broken = rng.randrange(len(rects)) if worn else -1
    tilted = (broken + 1 + rng.randrange(len(rects) - 1)) % len(rects) if worn else -1
    for k, (x0, z0, x1, z1) in enumerate(rects):
        w = x1 - x0 - gap * 2.0
        d = z1 - z0 - gap * 2.0
        cx, cz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
        h = 0.16
        if k == broken:
            # cracked into pieces and sunk a little
            for (fx0, fz0, fx1, fz1) in ((0.0, 0.0, 0.55, 0.5), (0.55, 0.0, 1.0, 0.62), (0.0, 0.5, 0.48, 1.0), (0.48, 0.62, 1.0, 1.0)):
                pw = (fx1 - fx0) * w - 0.03
                pd = (fz1 - fz0) * d - 0.03
                px = x0 + gap + (fx0 + fx1) * 0.5 * w
                pz = z0 + gap + (fz0 + fz1) * 0.5 * d
                drop = rng.uniform(0.04, 0.09)
                stone(B, (px, -h * 0.5 - drop, pz), (pw, h, pd), bev=0.025, seg=1, rng=rng, jit=0.012,
                      chips=1, chip_depth=(0.03, 0.07), top_cap=h * 0.5)
            continue
        drop = rng.uniform(0.0, 0.02)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * w, v.co.y * h, v.co.z * d))
        _bevel(bm, min(0.03, min(w, d) * 0.3), 1)
        for _ in range(rng.choice((0, 0, 0, 1))):
            _chip(bm, rng, (w, h, d), (0.02, 0.06))
        for v in bm.verts:
            v.co += Vector((rng.uniform(-0.004, 0.004), rng.uniform(-0.004, 0.004), rng.uniform(-0.004, 0.004)))
        if k == tilted:
            ax = rng.choice((-1.0, 1.0))
            for v in bm.verts:
                v.co.y -= (v.co.x * ax / max(w, 0.1) + 0.5) * 0.05
        for v in bm.verts:
            v.co.y = min(v.co.y, h * 0.5)
        bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((cx, -h * 0.5 - drop, cz)))
        B.add_bm(bm)
        bm.free()


def build_top_a(B):
    paving(B, 11)


def build_top_b(B):
    paving(B, 12)


def build_top_c(B):
    paving(B, 14, worn=True)


# Cornice profile [(outward offset from the face plane, y)], closed, below the coping slab.
CORNICE = [(-0.2, -0.2), (0.02, -0.2), (0.075, -0.215), (0.1, -0.25), (0.095, -0.29),
           (0.065, -0.315), (0.035, -0.33), (0.02, -0.37), (0.0, -0.4), (-0.2, -0.4)]


def build_edge(B, broken=False):
    rng = random.Random(21 if not broken else 22)
    # Coping: two stones along the strip, slightly proud of the face (0.02), top at y = 0.
    for i, (x0, x1) in enumerate(((-0.5, -0.02), (-0.02, 0.5))):
        x0g, x1g = x0 + 0.008, x1 - 0.008
        stone(B, ((x0g + x1g) * 0.5, -0.1, -0.24), (x1g - x0g, 0.2, 0.52), bev=0.035, seg=1,
              rng=rng, jit=0.005, chips=1 if (broken and i == 1) else rng.choice((0, 1)),
              chip_depth=(0.12, 0.2) if (broken and i == 1) else (0.02, 0.06), top_cap=0.1)
    # Moulded cornice lip (overhangs +0.1 below the top) and a frieze band under it.
    if broken:
        sweep(B, CORNICE, [(-0.5, 0.0), (0.12, 0.0)])
        # the broken stub: a short, rough lip end
        stone(B, (0.3, -0.33, 0.02), (0.36, 0.12, 0.1), bev=0.02, rng=rng, jit=0.02, chips=2)
    else:
        sweep(B, CORNICE, [(-0.5, 0.0), (0.5, 0.0)])
    stone(B, (0.0, -0.5, -0.15), (1.0, 0.2, 0.3), bev=0.02, col=RECESS)
    # Corbel table: little carved blocks under the lip.
    for k in range(3):
        x = -0.333 + k * 0.333
        stone(B, (x, -0.47, 0.035), (0.12, 0.14, 0.07), bev=0.02, seg=1, rng=rng, jit=0.004)


def build_corner(B):
    rng = random.Random(31)
    stone(B, (-0.24, -0.1, -0.24), (0.52, 0.2, 0.52), bev=0.035, seg=1, rng=rng, jit=0.005, top_cap=0.1)
    sweep(B, CORNICE, [(-0.5, 0.0), (0.0, 0.0), (0.0, -0.5)])
    stone(B, (-0.15, -0.5, -0.25), (0.3, 0.2, 0.5), bev=0.02, col=RECESS)
    stone(B, (-0.35, -0.5, -0.15), (0.3, 0.2, 0.3), bev=0.02, col=RECESS)
    stone(B, (0.0, -0.47, 0.0), (0.12, 0.14, 0.12), bev=0.02)
    for x in (-0.3,):
        stone(B, (x, -0.46, 0.035), (0.11, 0.12, 0.07), bev=0.02)
        stone(B, (0.035, -0.46, x), (0.07, 0.12, 0.11), bev=0.02)


def build_ashlar(B, seed, courses, missing=-1):
    """2 x 1 m panel of two masonry courses. courses = [[widths...], [widths...]] (sum 2.0)."""
    rng = random.Random(seed)
    stone(B, (0.0, -0.5, -0.17), (2.0, 1.0, 0.26), bev=0.0, col=MORTAR)
    gap = 0.012
    k = 0
    for row, widths in enumerate(courses):
        y1 = -row * 0.5
        y0 = y1 - 0.5
        x = -1.0
        for w in widths:
            k += 1
            if k == missing:
                # a stone fallen out: dark socket with a broken stub at the back
                stone(B, (x + w * 0.5, (y0 + y1) * 0.5, -0.1), (w - 0.05, 0.45, 0.1), bev=0.01,
                      rng=rng, jit=0.02, col=(0.25, 0.0, 0.0))
                x += w
                continue
            proud = rng.uniform(-0.01, 0.025)
            d = 0.2
            stone(B, (x + w * 0.5, (y0 + y1) * 0.5, -d * 0.5 + proud), (w - gap * 2.0, 0.5 - gap * 2.0, d),
                  bev=0.03, seg=1, rng=rng, jit=0.006, chips=rng.choice((0, 0, 1, 1)), chip_depth=(0.025, 0.07))
            x += w


def pointed_arch(a, r, y_s, steps=10):
    """Points of a two-centred pointed arch of half-span a, radius r, springing at y_s, from the
    left springer over the apex to the right springer."""
    cx = r - a
    pts = []
    rise = math.sqrt(max(0.0, r * r - cx * cx))
    a_start = math.pi
    a_end = math.atan2(rise, -cx)
    for i in range(steps + 1):
        t = a_start + (a_end - a_start) * i / steps
        pts.append((cx + math.cos(t) * r, y_s + math.sin(t) * r))
    right = [(-px, py) for (px, py) in reversed(pts[:-1])]
    return pts + right, rise


def build_arcade(B):
    """2 m wide, 3 m tall blind pointed arch (y -3..0), face at z = 0."""
    rng = random.Random(41)
    # Recessed back wall: small ashlar inside the arch.
    stone(B, (0.0, -1.5, -0.2), (1.6, 3.0, 0.12), bev=0.0, col=MORTAR)
    for row in range(6):
        y1 = -0.4 - row * 0.43
        off = 0.0 if row % 2 == 0 else 0.2
        x = -0.8 - off
        while x < 0.8:
            w = 0.4
            xa, xb = max(x, -0.8), min(x + w, 0.8)
            if xb - xa > 0.08:
                stone(B, ((xa + xb) * 0.5, y1 - 0.21, -0.17), (xb - xa - 0.02, 0.41, 0.1), bev=0.0,
                      rng=rng, jit=0.004, col=RECESS)
            x += w
    # Piers either side (flush with the face).
    for sx in (-1.0, 1.0):
        for row in range(6):
            y1 = -row * 0.5
            stone(B, (sx * 0.9, y1 - 0.25, -0.12), (0.2 - 0.02, 0.48, 0.24), bev=0.025, seg=2, rng=rng, jit=0.005)
    # Sill.
    stone(B, (0.0, -2.88, -0.08), (1.62, 0.22, 0.2), bev=0.03, seg=2, rng=rng, jit=0.004)
    # Colonnettes with capitals and bases.
    y_s = -1.25
    for sx in (-0.7, 0.7):
        lathe(B, [(0.065, -2.77), (0.065, y_s - 0.12)], 10, center=(sx, 0.0, -0.06))
        lathe(B, [(0.06, y_s - 0.12), (0.1, y_s - 0.02), (0.1, y_s)], 8, center=(sx, 0.0, -0.06), smooth=False, cap_top=True)
        lathe(B, [(0.1, -2.77), (0.09, -2.7), (0.065, -2.68)], 8, center=(sx, 0.0, -0.06), smooth=False)
    # Arch: intrados half-span 0.62, radius 1.0; voussoir ring swept along it.
    curve, rise = pointed_arch(0.62, 1.0, y_s, 12)
    # Spandrels (flush wall above the arch, each side of the apex).
    ext, _ = pointed_arch(0.8, 1.15, y_s, 12)
    half = len(ext) // 2
    left = ext[:half + 1]
    poly = [(-0.8, y_s)] + left[1:] + [(0.0, 0.0), (-0.8, 0.0)]
    # ensure counter-clockwise for prism()
    area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    if area < 0:
        poly = list(reversed(poly))
    prism(B, poly, -0.2, -0.01)
    rpoly = [(-x, y) for (x, y) in poly]
    rpoly = list(reversed(rpoly))
    prism(B, rpoly, -0.2, -0.01)
    # The arch ring: voussoirs between intrados and extrados, slightly proud of the spandrel.
    for i in range(len(curve) - 1):
        (x0, y0), (x1, y1) = curve[i], curve[i + 1]
        (ex0, ey0), (ex1, ey1) = ext[i], ext[i + 1]
        g = 0.006
        pts = [(x0, y0), (x1, y1), (ex1, ey1), (ex0, ey0)]
        cxp = sum(p[0] for p in pts) / 4.0
        cyp = sum(p[1] for p in pts) / 4.0
        pts = [(cxp + (px - cxp) * (1 - g * 6), cyp + (py - cyp) * (1 - g * 6)) for (px, py) in pts]
        area = sum(pts[k][0] * pts[(k + 1) % 4][1] - pts[(k + 1) % 4][0] * pts[k][1] for k in range(4))
        if area < 0:
            pts = list(reversed(pts))
        prism(B, pts, -0.18, 0.015)
    # Hood moulding: a rounded label over the extrados, with carved stops.
    hood_out, _ = pointed_arch(0.88, 1.2, y_s + 0.02, 14)
    for i in range(len(hood_out) - 1):
        (x0, y0), (x1, y1) = hood_out[i], hood_out[i + 1]
        mx, my = (x0 + x1) * 0.5, (y0 + y1) * 0.5
        ln = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * (ln + 0.02), v.co.y * 0.07, v.co.z * 0.07))
        _bevel(bm, 0.02)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(ang, 3, 'Z'))
        bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((mx, my, 0.03)))
        B.add_bm(bm)
        bm.free()
    for sx in (-1.0, 1.0):
        stone(B, (sx * 0.87, y_s + 0.0, 0.04), (0.11, 0.14, 0.1), bev=0.03, seg=2)
    # Top course over the spandrels.
    stone(B, (0.0, -0.06, -0.1), (2.0, 0.12, 0.22), bev=0.02, rng=rng, jit=0.003)


def build_quoin(B):
    rng = random.Random(51)
    stone(B, (-0.15, -0.5, -0.15), (0.26, 1.0, 0.26), bev=0.0, col=MORTAR)
    for row in range(2):
        y1 = -row * 0.5
        long_x = row % 2 == 0
        sx = 0.3 if long_x else 0.22
        sz = 0.22 if long_x else 0.3
        stone(B, (-sx * 0.5 + 0.015, y1 - 0.25, -sz * 0.5 + 0.015), (sx, 0.48, sz), bev=0.035, seg=1,
              rng=rng, jit=0.005, chips=1, chip_depth=(0.02, 0.05))


def build_buttress(B):
    """0.5 m wide strip, y -1..0, protruding +0.12 from the face, weathered (sloped) top."""
    rng = random.Random(61)
    for row in range(2):
        y1 = -row * 0.5
        stone(B, (0.0, y1 - 0.25, 0.0), (0.5, 0.48, 0.24), bev=0.03, seg=2, rng=rng, jit=0.005)
    # weathering: a sloped stone at the top
    poly = [(-0.12, -0.18), (0.13, -0.18), (0.13, -0.1), (-0.12, 0.0)]  # (z, y) in prism axis 'x'
    prism(B, poly, -0.26, 0.26, axis='x')


def build_base(B):
    rng = random.Random(71)
    stone(B, (0.0, -0.1, 0.0), (1.0, 0.2, 1.0), bev=0.04, seg=1, col=(0.6, 0.0, 0.0))  # no jitter: it is stretched to whole floors


# Clustered pier: a core plus colonnettes, all inside the unit square.
SHAFT = [((0.0, 0.0), 0.33, 8), ((0.3, 0.3), 0.13, 10), ((-0.3, 0.3), 0.13, 10), ((0.3, -0.3), 0.13, 10),
         ((-0.3, -0.3), 0.13, 10), ((0.38, 0.0), 0.09, 8), ((-0.38, 0.0), 0.09, 8), ((0.0, 0.38), 0.09, 8),
         ((0.0, -0.38), 0.09, 8)]


def build_pillar_shaft(B, y0=-1.0, y1=0.0):
    for (cx, cz), r, n in SHAFT:
        lathe(B, [(r, y0), (r, y1)], n, center=(cx, 0.0, cz), phase=math.pi / n)


def build_pillar_band(B):
    lathe(B, [(0.43, -0.1), (0.47, -0.06), (0.47, 0.02), (0.44, 0.06), (0.4, 0.1)], 8, phase=math.pi / 8,
          smooth=False, cap_top=True, cap_bottom=True)


def build_pillar_capital(B):
    rng = random.Random(81)
    # Abacus: the walkable top (y -0.2..0), full square.
    stone(B, (0.0, -0.1, 0.0), (1.0, 0.2, 1.0), bev=0.04, seg=2, rng=rng, jit=0.004, top_cap=0.1)
    # Bell: octagonal, flaring up to the abacus.
    lathe(B, [(0.36, -0.82), (0.38, -0.7), (0.42, -0.45), (0.47, -0.28), (0.49, -0.2)], 8,
          phase=math.pi / 8, smooth=False)
    # Astragal (necking) ring and a carved leaf band.
    lathe(B, [(0.36, -0.9), (0.41, -0.86), (0.41, -0.8), (0.36, -0.76)], 8, phase=math.pi / 8, smooth=False)
    for k in range(8):
        a = math.pi / 8 + k * math.pi / 4
        stone(B, (math.cos(a) * 0.42, -0.42, math.sin(a) * 0.42), (0.09, 0.16, 0.09), bev=0.03, seg=2,
              rng=rng, jit=0.01)
    # Corner crockets under the abacus corners.
    for sx in (-1, 1):
        for sz in (-1, 1):
            stone(B, (sx * 0.4, -0.27, sz * 0.4), (0.13, 0.13, 0.13), bev=0.04, seg=2, rng=rng, jit=0.01)
    build_pillar_shaft(B, -1.0, -0.86)


def build_pillar_broken(B):
    rng = random.Random(91)
    bm_all = Builder()
    for (cx, cz), r, n in SHAFT:
        bm = bmesh.new()
        ring_lo, ring_hi = [], []
        for k in range(n):
            a = math.pi / n + 2.0 * math.pi * k / n
            ring_lo.append(bm.verts.new((cx + math.cos(a) * r, -1.0, cz + math.sin(a) * r)))
            ring_hi.append(bm.verts.new((cx + math.cos(a) * r, 0.0, cz + math.sin(a) * r)))
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((ring_lo[k], ring_hi[k], ring_hi[k2], ring_lo[k2]))
        bm.faces.new(list(reversed(ring_lo)))
        # Subdivide vertically so the break can be jagged.
        bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.y - e.verts[1].co.y) > 0.5],
                                  cuts=4, use_grid_fill=False)
        for _ in range(2):
            no = Vector((rng.uniform(-0.6, 0.6), -1.0, rng.uniform(-0.6, 0.6))).normalized()
            co = Vector((cx, rng.uniform(-0.75, -0.35), cz))
            bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), dist=1e-5,
                                   plane_co=co, plane_no=no, clear_outer=True)
            _fill_boundaries(bm)
        # rough the broken face
        for v in bm.verts:
            if v.co.y < -0.2:
                v.co += Vector((rng.uniform(-0.015, 0.015), rng.uniform(-0.04, 0.04), rng.uniform(-0.015, 0.015)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        B.add_bm(bm, col=(0.8, 0.0, 0.0))
        bm.free()


def build_handhold(B):
    """A carved stone corbel (back on the wall face at z = 0) holding a bone grip."""
    rng = random.Random(101)
    poly = [(0.0, -0.09), (0.04, -0.09), (0.15, 0.0), (0.15, 0.05), (0.0, 0.05)]  # (z, y)
    prism(B, poly, -0.19, 0.19, axis='x')
    BONE = (1.0, 0.0, 1.0)
    hlathe(B, [(0.045, -0.2), (0.056, -0.17), (0.03, -0.1), (0.03, 0.1), (0.056, 0.17), (0.045, 0.2)], 6,
           center=(0.0, 0.085, 0.1), col=BONE)
    # Knuckle knobs at the bone ends.
    for sx in (-1, 1):
        stone(B, (sx * 0.2, 0.085, 0.1), (0.06, 0.08, 0.07), bev=0.02, seg=1, col=BONE, rng=rng, jit=0.004)


def build_grate(B):
    """3 x 0.6 x 3 m riveted iron platform: angle-iron frame, grate bars, corner plates."""
    IRON = (1.0, 0.0, 0.0)
    RIM = (1.0, 0.7, 0.0)
    H = 0.3
    for sx in (-1, 1):
        # frame along Z (x = +-1.5) and along X (z = +-1.5)
        stone(B, (sx * 1.47, H - 0.03, 0.0), (0.06, 0.06, 3.0), bev=0.012, col=RIM)
        stone(B, (0.0, H - 0.03, sx * 1.47), (3.0, 0.06, 0.06), bev=0.012, col=RIM)
        stone(B, (sx * 1.38, H - 0.04, 0.0), (0.18, 0.08, 2.9), bev=0.01)
        stone(B, (0.0, H - 0.04, sx * 1.38), (2.9, 0.08, 0.18), bev=0.01)
        stone(B, (sx * 1.475, 0.0, 0.0), (0.05, 0.6, 3.0), bev=0.01)
        stone(B, (0.0, 0.0, sx * 1.475), (3.0, 0.6, 0.05), bev=0.01)
        # lower flange
        stone(B, (sx * 1.42, -H + 0.03, 0.0), (0.14, 0.06, 2.9), bev=0.01)
        stone(B, (0.0, -H + 0.03, sx * 1.42), (2.9, 0.06, 0.14), bev=0.01)
    # rivets on the outer webs: two rows
    for t in [i * 0.3 - 1.35 for i in range(10)]:
        for y in (0.15, -0.15):
            for sx in (-1, 1):
                stone(B, (sx * 1.505, y, t), (0.02, 0.045, 0.045), bev=0.01, col=RIM)
                stone(B, (t, y, sx * 1.505), (0.045, 0.045, 0.02), bev=0.01, col=RIM)
    # grate bars (top at H)
    for i in range(1, 12):
        p = -1.29 + i * 0.215
        stone(B, (p, H - 0.06, 0.0), (0.045, 0.12, 2.6), bev=0.008)
        stone(B, (0.0, H - 0.09, p), (2.6, 0.06, 0.04), bev=0.006)
    # two cross beams under the grate
    for sx in (-1, 1):
        stone(B, (sx * 0.5, -0.05, 0.0), (0.12, 0.5, 2.85), bev=0.01)
    # corner plates with bolts
    for sx in (-1, 1):
        for sz in (-1, 1):
            stone(B, (sx * 1.3, H - 0.005, sz * 1.3), (0.34, 0.03, 0.34), bev=0.01)
            for bx in (-1, 1):
                for bz in (-1, 1):
                    stone(B, (sx * 1.3 + bx * 0.11, H + 0.0, sz * 1.3 + bz * 0.11), (0.04, 0.03, 0.04),
                          bev=0.01, col=RIM, top_cap=0.0)
    # central quatrefoil boss
    lathe(B, [(0.3, H - 0.04), (0.3, H - 0.005), (0.24, H)], 8, phase=math.pi / 8, smooth=False, cap_top=True)


def build_cracked(B):
    """2.6 x 1 x 2.6 slab broken into shards over a core that glows through the cracks."""
    rng = random.Random(111)
    S = 1.3
    # Jittered 3 x 3 grid of shard corners.
    g = []
    for i in range(4):
        row = []
        for j in range(4):
            x = -S + i * (2 * S / 3)
            z = -S + j * (2 * S / 3)
            if 0 < i < 3:
                x += rng.uniform(-0.22, 0.22)
            if 0 < j < 3:
                z += rng.uniform(-0.22, 0.22)
            row.append((x, z))
        g.append(row)
    for i in range(3):
        for j in range(3):
            quad = [g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1]]
            # split some quads into two triangles-ish shards
            shards = [quad]
            if rng.random() < 0.5:
                shards = [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]
            for sh in shards:
                cx = sum(p[0] for p in sh) / len(sh)
                cz = sum(p[1] for p in sh) / len(sh)
                inset = 0.055
                pts = [(cx + (p[0] - cx) * (1 - inset / max(0.2, math.hypot(p[0] - cx, p[1] - cz))),
                        cz + (p[1] - cz) * (1 - inset / max(0.2, math.hypot(p[0] - cx, p[1] - cz)))) for p in sh]
                # keep the outer boundary flush with the box
                pts = [(max(-S, min(S, px)), max(-S, min(S, pz))) for (px, pz) in pts]
                area = sum(pts[k][0] * pts[(k + 1) % len(pts)][1] - pts[(k + 1) % len(pts)][0] * pts[k][1] for k in range(len(pts)))
                if area < 0:
                    pts = list(reversed(pts))
                top = 0.5 - rng.uniform(0.0, 0.035)
                bm_b = Builder()
                prism(bm_b, pts, top - 0.4, top, axis='y')
                for v in bm_b.verts:
                    v.x += rng.uniform(-0.004, 0.004)
                # tilt the shard a touch
                tx, tz = rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02)
                for v in bm_b.verts:
                    v.y += (v.x - cx) * tx + (v.z - cz) * tz
                    v.y = min(v.y, 0.5)
                base = len(B.verts)
                B.verts.extend(bm_b.verts)
                for f in bm_b.faces:
                    B.faces.append([base + k for k in f])
                    B.fcol.append((1.0, 0.0, 0.0, 1.0))
                    B.fsmooth.append(False)
    # Core: rough block under the shards; its top glows (seen through the cracks).
    def core_col(f):
        return (0.2, 1.0, 0.0) if f.normal.y > 0.5 else (0.75, 0.0, 0.0)
    # its top sits just under the shards (0.41 m), so the glow shows down every crack
    stone(B, (0.0, -0.045, 0.0), (2.5, 0.91, 2.5), bev=0.04, rng=rng, jit=0.008, colfn=core_col)
    # Side stones on the core so the faces read as masonry.
    for sx in (-1, 1):
        for k in range(3):
            t = -0.86 + k * 0.86
            stone(B, (sx * 1.23, -0.2, t), (0.12, 0.55, 0.8), bev=0.03, rng=rng, jit=0.01, chips=1)
            stone(B, (t, -0.2, sx * 1.23), (0.8, 0.55, 0.12), bev=0.03, rng=rng, jit=0.01, chips=1)


def build_portcullis(B):
    """0.3 x 5 x 3.6 m iron portcullis (centred): pointed bars, riveted bands."""
    RIM = (1.0, 0.25, 0.0)
    n = 11
    for i in range(n):
        z = -1.65 + i * 3.3 / (n - 1)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * 0.07, v.co.y * 4.6 + 0.2, v.co.z * 0.07))
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.pi / 4, 3, 'Y'))
        bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0.0, 0.0, z)))
        B.add_bm(bm)
        bm.free()
        # pointed tip at the bottom
        B.add_poly([(0.0, -2.5, z), (0.05, -2.1, z), (0.0, -2.1, z + 0.05), (-0.05, -2.1, z), (0.0, -2.1, z - 0.05)],
                   [[0, 2, 1], [0, 3, 2], [0, 4, 3], [0, 1, 4]], col=RIM)
    for y in (-1.6, -0.3, 1.0, 2.2):
        for sx in (-1, 1):
            stone(B, (sx * 0.075, y, 0.0), (0.04, 0.14, 3.6), bev=0.01)
            for i in range(n):
                z = -1.65 + i * 3.3 / (n - 1)
                stone(B, (sx * 0.1, y, z), (0.02, 0.04, 0.04), bev=0.008, col=RIM)


# --------------------------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------------------------

PIECES = {
    "top_a": build_top_a,
    "top_b": build_top_b,
    "top_c": build_top_c,
    "edge": lambda B: build_edge(B, False),
    "edge_b": lambda B: build_edge(B, True),
    "corner": build_corner,
    "ashlar_a": lambda B: build_ashlar(B, 201, [[0.62, 0.78, 0.6], [0.3, 0.7, 0.55, 0.45]]),
    "ashlar_b": lambda B: build_ashlar(B, 202, [[0.45, 0.85, 0.7], [0.75, 0.6, 0.65]]),
    "ashlar_c": lambda B: build_ashlar(B, 203, [[0.7, 0.5, 0.8], [0.35, 0.65, 0.6, 0.4]], missing=2),
    "arcade": build_arcade,
    "quoin": build_quoin,
    "buttress": build_buttress,
    "base": build_base,
    "pillar_capital": build_pillar_capital,
    "pillar_shaft": build_pillar_shaft,
    "pillar_band": build_pillar_band,
    "pillar_broken": build_pillar_broken,
    "handhold": build_handhold,
    "grate": build_grate,
    "cracked": build_cracked,
    "portcullis": build_portcullis,
}

TRIM_PIECES = {"edge", "edge_b", "corner", "pillar_capital", "quoin", "buttress", "arcade",
               "ashlar_a", "ashlar_b", "ashlar_c", "base", "handhold"}

G2B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Godot (x, y, z) -> Blender (x, -z, y)


def make_object(name, B):
    mesh = bpy.data.meshes.new(name)
    verts = [tuple(G2B @ Vector(v)) for v in B.verts]
    mesh.from_pydata(verts, [], B.faces)
    mesh.validate(clean_customdata=False)
    mesh.update()
    for i, p in enumerate(mesh.polygons):
        p.use_smooth = B.fsmooth[i] if i < len(B.fsmooth) else False
    col = mesh.color_attributes.new(name="Col", type='FLOAT_COLOR', domain='CORNER')
    for i, p in enumerate(mesh.polygons):
        c = B.fcol[i] if i < len(B.fcol) else (1.0, 0.0, 0.0, 1.0)
        for li in p.loop_indices:
            col.data[li].color = (c[0], c[1], c[2], c[3] if len(c) > 3 else 1.0)
    mesh.color_attributes.active_color = col
    try:
        mesh.color_attributes.render_color_index = 0
    except Exception:
        pass
    # Box-projected UVs (metres), in case a non-triplanar material is ever used.
    uv = mesh.uv_layers.new(name="UVMap")
    for p in mesh.polygons:
        n = p.normal
        for li in p.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            if abs(n.z) >= abs(n.x) and abs(n.z) >= abs(n.y):
                uv.data[li].uv = (co.x * 0.5, co.y * 0.5)
            elif abs(n.x) >= abs(n.y):
                uv.data[li].uv = (co.y * 0.5, co.z * 0.5)
            else:
                uv.data[li].uv = (co.x * 0.5, co.z * 0.5)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj, len(mesh.polygons)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "assets/models/kit/gothic_kit.glb"
    out = os.path.abspath(out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    total = 0
    for name, fn in PIECES.items():
        B = Builder()
        TRIM_ALPHA[0] = 0.0 if name in TRIM_PIECES else 1.0
        fn(B)
        obj, faces = make_object(name, B)
        tris = sum(len(f) - 2 for f in B.faces)
        total += tris
        print("KIT %-16s %6d tris" % (name, tris))
    kwargs = dict(filepath=out, export_format='GLB', use_selection=False, export_apply=False,
                  export_yup=True, export_normals=True, export_materials='NONE')
    for key, value in (("export_vertex_color", 'ACTIVE'), ("export_all_vertex_colors", True),
                       ("export_colors", True)):
        try:
            bpy.ops.export_scene.gltf(**kwargs, **{key: value})
            break
        except TypeError:
            continue
    else:
        bpy.ops.export_scene.gltf(**kwargs)
    print("KIT total %d tris -> %s" % (total, out))


main()

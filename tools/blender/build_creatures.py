"""BLOODBOUND full-3D creatures (DEC-064): five original enemies built headless in Blender as
rigid-part puppets that Godot animates procedurally (scripts/enemies/creature_rig.gd).

  blender.exe -b --python tools/blender/build_creatures.py -- <repo_root> [names...] [--sheet out.png]
  python tools/blender/build_creatures.py -- <repo_root> [names...]     (pip install bpy)

Writes assets/models/enemies/<name>.glb. Coordinates are Godot metres (see gothic_common.G):
origin at the feet, front = +Z. Each GLB is a NODE HIERARCHY of parts (pelvis, spine, chest,
head, jaw, arm_L_up, ...): every part's origin sits on its joint, so rotating the node in
Godot bends the creature at that joint. Empties named *_end mark chain ends (IK targets) and
light sockets. Material slot names are roles (muscle, sinew, bone, teeth, flesh, skin, skin_b,
seam, stitch, iron, blade, blood, lips, dark, glow, glow_pale, porcelain, dress, lace, wax,
cloth_black, flame, glass, apron) mapped to materials by scripts/enemies/creature_materials.gd.
Vertex colour carries a cavity/curvature shade (darker in grooves, stitches and sockets).

Only original procedural geometry: primitives, swept tubes, lathes, voxel-remeshed unions,
booleans and vertex displacement (muscle striations). No third-party meshes.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
from mathutils import Vector, Matrix, noise
import gothic_common as C
from gothic_common import G, box, cyl, sphere, tube, organic, join, boolean, mat

OUT = "assets/models/enemies/"
BUILT = {}
TAU = math.tau


def asset(fn):
    BUILT[fn.__name__] = fn
    return fn


# --- small vector helpers (Godot space tuples) -----------------------------------------------

def L(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def A(a, b):
    return tuple(a[i] + b[i] for i in range(3))


def S(a, k):
    return tuple(a[i] * k for i in range(3))


def MX(p, s):
    """Mirror x by side s (+1 left / -1 right)."""
    return (p[0] * s, p[1], p[2])


def H(i, seed=0):
    """Deterministic hash in [0, 1)."""
    x = math.sin(i * 12.9898 + seed * 78.233) * 43758.5453
    return x - math.floor(x)


# --- rig ---------------------------------------------------------------------------------------

class Rig:
    def __init__(self, name):
        self.name = name
        self.parts = []   # dicts: name, parent, pivot, ob, rot
        self.ends = []    # (name, parent, pos)

    def part(self, name, parent, pivot, objs, tris=None, local=False, rot=(0, 0, 0)):
        ob = join([o for o in objs if o is not None], name)
        if tris:
            C.decimate_to(ob, tris)
        self.parts.append(dict(name=name, parent=parent, pivot=pivot, ob=ob, local=local, rot=rot))
        return ob

    def end(self, name, parent, pos):
        self.ends.append((name, parent, pos))

    def export(self):
        by = {}
        for p in self.parts:
            ob = p["ob"]
            ob.data.validate()
            C.shade(ob, True, 70.0)
            C.box_uv(ob)
            cavity_colors(ob)
            if not p["local"]:
                ob.data.transform(Matrix.Translation(-G(p["pivot"])))
            ob.location = G(p["pivot"])
            by[p["name"]] = p
        for p in self.parts:
            ob = p["ob"]
            if p["local"]:
                C.place(ob, (0, 0, 0), p["rot"])
            if p["parent"]:
                par = by[p["parent"]]
                ob.parent = par["ob"]
                ob.matrix_parent_inverse = Matrix.Identity(4)
                ob.location = G(p["pivot"]) - G(par["pivot"])
                if par["local"] and any(par["rot"]):
                    raise ValueError("children of rotated parts are not supported")
            else:
                ob.location = G(p["pivot"])
        empties = []
        for name, parent, pos in self.ends:
            e = bpy.data.objects.new(name, None)
            bpy.context.scene.collection.objects.link(e)
            par = by[parent]
            e.parent = par["ob"]
            e.matrix_parent_inverse = Matrix.Identity(4)
            e.location = G(pos) - G(par["pivot"])
            empties.append(e)
        path = os.path.join(C.ROOT, OUT + self.name + ".glb")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        bpy.ops.object.select_all(action='DESELECT')
        for p in self.parts:
            p["ob"].select_set(True)
        for e in empties:
            e.select_set(True)
        bpy.context.view_layer.objects.active = self.parts[0]["ob"]
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                                  export_apply=True, export_yup=True, export_materials='EXPORT',
                                  export_normals=True, export_texcoords=True, export_cameras=False,
                                  export_lights=False, export_vertex_color='ACTIVE',
                                  export_all_vertex_colors=False)
        tris = sum(sum(len(f.vertices) - 2 for f in p["ob"].data.polygons) for p in self.parts)
        print("EXPORT %s  parts=%d  tris=%d" % (OUT + self.name + ".glb", len(self.parts), tris))
        return [p["ob"] for p in self.parts]


# --- surface helpers ---------------------------------------------------------------------------

def cavity_colors(ob, strength=2.2, seed=0):
    """Vertex colour = curvature shade (concave darker) with a little mottling."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    vals = [0.0] * len(bm.verts)
    for v in bm.verts:
        if not v.link_edges:
            continue
        avg = Vector()
        el = 0.0
        for e in v.link_edges:
            avg += e.other_vert(v).co
            el += e.calc_length()
        avg /= len(v.link_edges)
        el /= len(v.link_edges)
        vals[v.index] = (avg - v.co).dot(v.normal) / max(el, 1e-6)
    for it in range(2):
        new = list(vals)
        for v in bm.verts:
            s = vals[v.index]
            n = 1
            for e in v.link_edges:
                s += vals[e.other_vert(v).index]
                n += 1
            new[v.index] = s / n
        vals = new
    bm.free()
    # Living (or once-living) surfaces get a mottled hue: yellowed, bruised, blood-flushed.
    organic_roles = {"skin", "skin_b", "muscle", "flesh", "sinew", "porcelain", "wax", "lips"}
    soft = [False] * len(me.vertices)
    for poly in me.polygons:
        mname = me.materials[poly.material_index].name.split(".")[0] if me.materials else ""
        if mname in organic_roles:
            for vi in poly.vertices:
                soft[vi] = True
    attr = me.color_attributes.new("Color", 'FLOAT_COLOR', 'POINT')
    for i, v in enumerate(me.vertices):
        n = noise.noise(v.co * 7.0 + Vector((seed, seed * 2, 0)))
        shade = max(0.22, min(1.0, 0.92 - vals[i] * strength + 0.08 * n))
        col = Vector((shade, shade, shade))
        if soft[i]:
            n1 = noise.noise(v.co * 2.6 + Vector((3.1, seed, 1.7)))
            n2 = noise.noise(v.co * 4.1 + Vector((7.3, 2.2, seed)))
            tint = Vector((1.0, 1.0, 1.0))
            tint = tint.lerp(Vector((1.0, 0.88, 0.62)), max(0.0, n1) * 0.7)
            tint = tint.lerp(Vector((0.72, 0.6, 0.92)), max(0.0, n2) * 0.6)
            tint = tint.lerp(Vector((1.0, 0.62, 0.6)), max(0.0, -n1) * 0.55)
            col = Vector((col.x * tint.x, col.y * tint.y, col.z * tint.z))
        attr.data[i].color = (min(col.x, 1.0), min(col.y, 1.0), min(col.z, 1.0), 1.0)
    me.color_attributes.active_color = attr
    try:
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
    except Exception:
        pass


def striate(ob, a, b, freq=10, amp=0.005, reach=0.25, seed=0):
    """Muscle fibre bundles: longitudinal grooves around the a->b axis."""
    Av = G(a)
    Bv = G(b)
    d = Bv - Av
    ln = d.length
    d.normalize()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    n1 = d.cross(ref).normalized()
    n2 = d.cross(n1)
    for v in ob.data.vertices:
        p = v.co
        t = (p - Av).dot(d)
        if t < 0.0 or t > ln:
            continue
        q = Av + d * t
        r = p - q
        rl = r.length
        if rl > reach or rl < 1e-5:
            continue
        ang = math.atan2(r.dot(n2), r.dot(n1))
        w = math.sin(math.pi * t / ln) ** 0.5
        warp = noise.noise(p * 9.0 + Vector((seed, 0, 0))) * 1.6
        g = abs(math.cos(ang * freq * 0.5 + warp))
        v.co = p + r / rl * amp * w * (g ** 0.6 - 0.75)


def project(ob, p):
    """Closest point (Blender coords) and normal on `ob`'s surface to Godot point p."""
    ok, loc, nrm, idx = ob.closest_point_on_mesh(G(p))
    return loc, nrm


def seam(body, pts, step=0.05, ridge=0.011, stitch_len=0.07, stitch_r=0.0048, staples=0, seed=0, drips=0.0):
    """A sewn seam over `body`'s surface along Godot points `pts`: a raw ridge + crossing
    stitches (and a few iron staples). Returns objects to join."""
    r = random.Random(seed)
    path = []
    for i in range(len(pts) - 1):
        seg = Vector(pts[i + 1]) - Vector(pts[i])
        n = max(1, int(seg.length / (step * 0.5)))
        for k in range(n):
            path.append(L(pts[i], pts[i + 1], k / n))
    path.append(pts[-1])
    surf = [project(body, p) for p in path]
    objs = []
    # Ridge: Blender-space points converted back to Godot space for tube().
    gp = []
    for loc, nrm in surf:
        q = loc + nrm * 0.003
        gp.append((q.x, q.z, -q.y))
    objs.append(tube(gp, ridge, 6, "seam", name="seam"))
    acc = 0.0
    for i in range(1, len(surf)):
        acc += (surf[i][0] - surf[i - 1][0]).length
        if acc < step:
            continue
        acc = 0.0
        loc, nrm = surf[i]
        t = (surf[i][0] - surf[i - 1][0]).normalized()
        side = t.cross(nrm).normalized()
        half = stitch_len * r.uniform(0.4, 0.6)
        tilt = t * r.uniform(-0.012, 0.012)
        a = loc + side * half + nrm * 0.004 + tilt
        b = loc - side * half + nrm * 0.004 - tilt
        m = (a + b) * 0.5 + nrm * 0.008
        role = "stitch"
        rad = stitch_r
        if staples and r.random() < staples:
            role = "iron"
            rad = stitch_r * 1.2
        objs.append(tube([(a.x, a.z, -a.y), (m.x, m.z, -m.y), (b.x, b.z, -b.y)], rad, 4, role, name="stitch"))
        if drips and r.random() < drips:
            ln = r.uniform(0.03, 0.12)
            q0 = loc + nrm * 0.004
            g0 = (q0.x, q0.z, -q0.y)
            objs.append(tube([g0, (g0[0], g0[1] - ln * 0.6, g0[2] + 0.004), (g0[0], g0[1] - ln, g0[2] + 0.006)],
                             [0.006, 0.005, 0.008], 5, "blood", name="drip"))
    return objs


def shell(rf, yf, segs, rings, role, name="shell", close_top=True, zf=None):
    """Open-bottomed surface of revolution: radius rf(t, a), height yf(t, a), t 0 top -> 1
    bottom, angle a (0 = front +Z). For dresses, veils, mantles, tatters."""
    bm = bmesh.new()
    grid = []
    for i in range(rings + 1):
        t = i / rings
        row = []
        for k in range(segs):
            a = TAU * k / segs
            rr = rf(t, a)
            z_off = zf(t, a) if zf else 0.0
            row.append(bm.verts.new(G(rr * math.sin(a), yf(t, a), rr * math.cos(a) + z_off)))
        grid.append(row)
    for i in range(rings):
        for k in range(segs):
            bm.faces.new((grid[i][k], grid[i][(k + 1) % segs], grid[i + 1][(k + 1) % segs], grid[i + 1][k]))
    if close_top:
        top = bm.verts.new(G(0, yf(0.0, 0.0) + 0.01, zf(0.0, 0.0) if zf else 0.0))
        for k in range(segs):
            bm.faces.new((grid[0][(k + 1) % segs], grid[0][k], top))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return C.from_bm(bm, name, role)


def mlimb(a, b, ra, rb, bulge=1.3, at=0.4, role="muscle", segs=12):
    """A limb segment a->b with a muscle belly."""
    pts = [a, L(a, b, 0.12), L(a, b, at), L(a, b, 0.78), b]
    rad = [ra * 0.92, ra, max(ra, rb) * bulge, (ra + rb) * 0.5, rb]
    return tube(pts, rad, segs, role)


def cone_tooth(base, tip, r, role="teeth"):
    return tube([base, L(base, tip, 0.6), tip], [r, r * 0.6, 0.0008], 5, role, name="tooth")


def claw(p0, dirv, length, r, curl=(0, -1, 0), role="bone"):
    p1 = A(p0, S(dirv, length * 0.5))
    p2 = A(A(p0, S(dirv, length)), S(curl, length * 0.35))
    return tube([p0, p1, p2], [r, r * 0.65, 0.0008], 5, role, name="claw")


def finger(knuckle, segs, radii, role="sinew", claw_len=0.0, claw_r=0.0, claw_dir=None, claw_curl=(0, -1, 0)):
    pts = [knuckle]
    for s in segs:
        pts.append(A(pts[-1], s))
    objs = [tube(pts, radii, 6, role, name="finger")]
    if claw_len > 0:
        d = claw_dir or tuple((Vector(pts[-1]) - Vector(pts[-2])).normalized())
        objs.append(claw(pts[-1], d, claw_len, claw_r, claw_curl))
    return objs


def eye(p, r, role="glow"):
    return sphere(r, p, (1, 1, 1), role, 10, 6)


# =============================================================================================
# 1. FLAYED STALKER
# =============================================================================================

@asset
def flayed_stalker():
    """Tall (2.3 m upright), skinless and sinewy; hangs-open jaw, long hooked fingers. Rest is
    upright; the game folds it onto all fours."""
    R = Rig("flayed_stalker")
    # Pelvis -------------------------------------------------------------------------------
    pb = organic([sphere(0.075, (0.1, 1.205, -0.0), (0.45, 0.8, 1.0), "bone"),
                  sphere(0.075, (-0.1, 1.205, -0.0), (0.45, 0.8, 1.0), "bone"),
                  sphere(0.04, (0, 1.13, -0.085), (1, 1.4, 0.6), "bone")], voxel=0.01, name="pelvis_b", role="bone")
    pm = organic([sphere(0.11, (0.085, 1.07, -0.05), (1, 1.05, 0.95), "muscle"),
                  sphere(0.11, (-0.085, 1.07, -0.05), (1, 1.05, 0.95), "muscle"),
                  sphere(0.1, (0, 1.13, 0.03), (1.25, 0.75, 0.75), "muscle")], voxel=0.01, name="pelvis_m", role="muscle")
    R.part("pelvis", None, (0, 1.15, 0), [pb, pm], tris=1400)
    # Abdomen ------------------------------------------------------------------------------
    ab = organic([tube([(0, 1.17, 0.03), (0, 1.36, 0.055), (0, 1.56, 0.05)], [0.075, 0.062, 0.08], 12, "muscle"),
                  tube([(0.07, 1.16, 0.0), (0.072, 1.36, 0.015), (0.09, 1.56, 0.0)], [0.042, 0.036, 0.048], 10, "muscle"),
                  tube([(-0.07, 1.16, 0.0), (-0.072, 1.36, 0.015), (-0.09, 1.56, 0.0)], [0.042, 0.036, 0.048], 10, "muscle"),
                  tube([(0, 1.17, -0.05), (0, 1.56, -0.05)], 0.05, 10, "muscle")], voxel=0.008, name="abdomen", role="muscle")
    striate(ab, (0, 1.17, 0.03), (0, 1.56, 0.05), freq=8, amp=0.006)
    verts = [sphere(0.022, (0, 1.19 + i * 0.065, -0.09), (1.3, 0.75, 1.0), "bone", 10, 6) for i in range(6)]
    R.part("spine", "pelvis", (0, 1.2, 0), [ab] + verts, tris=1700)
    # Chest: exposed ribcage over a dark wet interior ------------------------------------------
    ribs = []
    for i in range(7):
        y = 1.84 - i * 0.048
        w = 0.135 + 0.025 * math.sin(i / 6 * math.pi)
        for s in (1, -1):
            ribs.append(tube([(s * 0.025, y, -0.085), (s * w, y - 0.02, -0.04), (s * w * 1.02, y - 0.055, 0.04),
                              (s * w * 0.6, y - 0.09, 0.1), (s * 0.03, y - 0.1, 0.115)],
                             [0.012, 0.011, 0.0105, 0.009, 0.008], 6, "bone", name="rib"))
    ribs.append(tube([(0, 1.83, 0.12), (0, 1.62, 0.11)], [0.016, 0.012], 6, "bone"))
    ribs.append(tube([(0, 1.55, -0.085), (0, 1.92, -0.06)], 0.02, 8, "bone"))
    for s in (1, -1):
        ribs.append(tube([(s * 0.03, 1.885, 0.09), (s * 0.13, 1.895, 0.06), (s * 0.23, 1.89, 0.02)], 0.011, 6, "bone"))
    inner = [sphere(0.12, (0, 1.68, -0.005), (1.0, 1.25, 0.75), "dark", 14, 8),
             sphere(0.075, (0.055, 1.69, 0.03), (0.8, 1.4, 0.75), "flesh", 12, 8),
             sphere(0.075, (-0.055, 1.69, 0.03), (0.8, 1.4, 0.75), "flesh", 12, 8),
             sphere(0.05, (0.02, 1.62, 0.06), (1, 1.1, 0.8), "flesh", 10, 6)]
    cm = []
    for s in (1, -1):
        cm += [sphere(0.085, (s * 0.09, 1.79, 0.075), (1.15, 0.65, 0.45), "muscle"),
               sphere(0.068, (s * 0.235, 1.84, 0.0), (0.9, 1.15, 0.95), "muscle"),
               tube([(s * 0.21, 1.88, -0.03), (s * 0.1, 1.93, -0.045), (0, 1.96, -0.045)], [0.04, 0.045, 0.04], 10, "muscle"),
               tube([(s * 0.14, 1.58, -0.07), (s * 0.19, 1.72, -0.07), (s * 0.21, 1.83, -0.04)], [0.03, 0.045, 0.035], 10, "muscle")]
    chest_m = organic(cm, voxel=0.008, name="chest_m", role="muscle")
    R.part("chest", "spine", (0, 1.55, 0), [chest_m] + ribs + inner, tris=4200)
    # Neck: cords and a bare windpipe ------------------------------------------------------------
    nk = [tube([(0, 1.9, -0.045), (0, 2.0, -0.04), (0, 2.1, -0.02)], [0.04, 0.035, 0.04], 10, "muscle"),
          tube([(0, 1.9, 0.045), (0, 2.0, 0.055), (0, 2.07, 0.06)], 0.017, 8, "flesh")]
    for s in (1, -1):
        nk.append(tube([(s * 0.05, 1.89, 0.07), (s * 0.04, 2.0, 0.045), (s * 0.05, 2.1, 0.0)], [0.013, 0.011, 0.013], 6, "sinew"))
    for i in range(4):
        nk.append(sphere(0.018, (0, 1.92 + i * 0.05, -0.075), (1.2, 0.7, 1.0), "bone", 8, 5))
    R.part("neck", "chest", (0, 1.92, 0.0), nk, tris=900)
    # Head: muscle-wrapped skull, torn scalp, lidless pin eyes, no lips ---------------------------
    cr = organic([sphere(0.092, (0, 2.2, 0.0), (0.84, 1.04, 1.15), "muscle"),
                  sphere(0.055, (0.062, 2.18, 0.015), (0.55, 1.0, 1.15), "muscle"),
                  sphere(0.055, (-0.062, 2.18, 0.015), (0.55, 1.0, 1.15), "muscle"),
                  sphere(0.05, (0, 2.125, 0.085), (1.0, 0.85, 1.0), "muscle"),
                  sphere(0.055, (0, 2.205, 0.07), (1.15, 0.55, 0.7), "muscle")], voxel=0.0065, name="cranium", role="muscle")
    for s in (1, -1):
        boolean(cr, sphere(0.024, (s * 0.034, 2.17, 0.108), (1.0, 0.85, 1.0), "dark", 12, 8))
    boolean(cr, sphere(0.018, (0, 2.135, 0.135), (0.8, 1.2, 1.0), "dark", 10, 6))
    cap = organic([sphere(0.09, (0, 2.225, -0.012), (0.82, 1.0, 1.1), "bone")], voxel=0.008, name="cap", role="bone")
    hd = [cr, cap, eye((0.034, 2.168, 0.108), 0.0105), eye((-0.034, 2.168, 0.108), 0.0105)]
    gum = []
    for k in range(11):
        a = (k - 5) / 5 * 1.05
        base = (math.sin(a) * 0.045, 2.098, 0.07 + math.cos(a) * 0.05)
        hd.append(cone_tooth(base, A(base, (0, -0.04 - 0.012 * (k % 2), 0.004)), 0.0065))
        gum.append(A(base, (0, 0.006, 0)))
    hd.append(tube(gum, 0.011, 6, "flesh"))
    for s in (1, -1):
        hd.append(tube([(s * 0.07, 2.19, 0.02), (s * 0.075, 2.14, 0.035), (s * 0.068, 2.1, 0.02)], 0.012, 6, "sinew"))
    R.part("head", "neck", (0, 2.08, 0.03), hd, tris=3600)
    # Jaw: long, hanging; tongue lolls out; strands of sinew ---------------------------------------
    mand = [(0.064, 2.11, -0.005), (0.06, 2.04, 0.02), (0.042, 1.985, 0.1), (0, 1.97, 0.155),
            (-0.042, 1.985, 0.1), (-0.06, 2.04, 0.02), (-0.064, 2.11, -0.005)]
    jw = [tube(mand, [0.012, 0.015, 0.015, 0.017, 0.015, 0.015, 0.012], 8, "bone")]
    for k in range(10):
        a = (k - 4.5) / 4.5 * 1.0
        base = (math.sin(a) * 0.04, 1.995, 0.065 + math.cos(a) * 0.075)
        jw.append(cone_tooth(base, A(base, (0, 0.035 + 0.01 * (k % 2), 0.0)), 0.006))
    for s in (1, -1):
        jw.append(tube([(s * 0.072, 2.155, 0.025), (s * 0.068, 2.09, 0.035), (s * 0.058, 2.03, 0.04)], [0.017, 0.02, 0.016], 8, "muscle"))
    jw.append(tube([(0, 2.01, 0.03), (0, 1.99, 0.11), (0, 1.94, 0.18), (0.01, 1.87, 0.2), (0.0, 1.82, 0.19)],
                   [0.024, 0.021, 0.016, 0.011, 0.005], 8, "flesh"))
    for k, (x, ln) in enumerate([(0.03, 0.12), (-0.025, 0.18), (0.0, 0.09)]):
        jw.append(tube([(x, 1.98, 0.12), (x * 1.2, 1.98 - ln * 0.5, 0.125), (x, 1.98 - ln, 0.12)], [0.004, 0.003, 0.0015], 4, "sinew"))
    R.part("jaw", "head", (0, 2.105, 0.0), jw, tris=1800)
    # Arms ---------------------------------------------------------------------------------------
    for s, tag in ((1, "L"), (-1, "R")):
        sh, el, wr = (s * 0.25, 1.86, 0.0), (s * 0.3, 1.32, 0.03), (s * 0.32, 0.78, 0.08)
        up = organic([mlimb(sh, el, 0.05, 0.036, 1.35, 0.35), sphere(0.05, A(sh, (s * 0.01, -0.03, 0)), (0.9, 1.2, 0.9), "muscle")],
                     voxel=0.0075, name="uparm", role="muscle")
        striate(up, sh, el, freq=10, amp=0.005)
        R.part("arm_%s_up" % tag, "chest", sh, [up, sphere(0.024, A(el, (0, 0.01, -0.03)), (1, 1.2, 1), "bone", 10, 6)], tris=1300)
        fo = organic([mlimb(el, wr, 0.04, 0.024, 1.3, 0.28)], voxel=0.007, name="forearm", role="muscle")
        striate(fo, el, wr, freq=9, amp=0.0045)
        lo = [fo, tube([A(el, (0, 0, -0.03)), L(A(el, (0, 0, -0.03)), A(wr, (0, 0, -0.02)), 0.5), A(wr, (0, 0, -0.02))], [0.016, 0.01, 0.012], 6, "bone")]
        for k in range(3):
            o = (s * (k - 1) * 0.014, 0, 0.022)
            lo.append(tube([A(L(el, wr, 0.45), o), A(L(el, wr, 0.8), o), A(wr, S(o, 0.6))], [0.006, 0.005, 0.004], 5, "sinew"))
        R.part("arm_%s_lo" % tag, "arm_%s_up" % tag, el, lo, tris=1300)
        hand = [organic([sphere(0.034, A(wr, (0, -0.045, 0.012)), (1.0, 1.35, 0.55), "muscle")], voxel=0.006, name="palm", role="muscle")]
        for k in range(4):
            dx = s * (-0.027 + 0.018 * k)
            kn = A(wr, (dx, -0.085, 0.014))
            ln = 1.0 + 0.18 * (1.5 - abs(k - 1.5))
            hand += finger(kn, [(dx * 0.2, -0.085 * ln, 0.008), (dx * 0.25, -0.08 * ln, 0.03), (dx * 0.1, -0.05 * ln, 0.05)],
                           [0.0105, 0.0095, 0.008, 0.0065], "sinew", 0.055, 0.0065, None, (0, -0.4, 0.6))
        hand += finger(A(wr, (s * 0.03, -0.05, 0.03)), [(s * 0.02, -0.05, 0.03), (s * 0.01, -0.05, 0.03)], [0.01, 0.008, 0.007], "sinew", 0.04, 0.006)
        R.part("hand_%s" % tag, "arm_%s_lo" % tag, wr, hand, tris=1500)
    # Legs ---------------------------------------------------------------------------------------
    for s, tag in ((1, "L"), (-1, "R")):
        hp, kn, an = (s * 0.115, 1.1, 0.0), (s * 0.135, 0.6, 0.07), (s * 0.14, 0.12, -0.02)
        th = organic([mlimb(hp, kn, 0.07, 0.045, 1.25, 0.35)], voxel=0.008, name="thigh", role="muscle")
        striate(th, hp, kn, freq=11, amp=0.006)
        R.part("leg_%s_up" % tag, "pelvis", hp, [th, sphere(0.03, A(kn, (0, 0.0, 0.04)), (1, 1.15, 0.8), "bone", 10, 6)], tris=1400)
        calf = organic([mlimb(A(kn, (0, -0.03, -0.03)), A(an, (0, 0.06, -0.03)), 0.045, 0.02, 1.35, 0.3)], voxel=0.007, name="calf", role="muscle")
        striate(calf, A(kn, (0, -0.03, -0.03)), A(an, (0, 0.06, -0.03)), freq=9, amp=0.005)
        sh = [calf, tube([A(kn, (0, -0.02, 0.025)), L(kn, an, 0.5), A(an, (0, 0, 0.015))], [0.021, 0.017, 0.02], 8, "bone"),
              tube([A(an, (0, 0.18, -0.045)), A(an, (0, 0.0, -0.05))], [0.009, 0.011], 5, "sinew")]
        R.part("leg_%s_lo" % tag, "leg_%s_up" % tag, kn, sh, tris=1300)
        ft = [organic([tube([A(an, (0, 0.0, -0.04)), A(an, (0, -0.07, 0.05)), A(an, (0, -0.1, 0.13))], [0.03, 0.035, 0.03], 10, "muscle")],
                      voxel=0.007, name="foot", role="muscle")]
        for k in range(4):
            dx = s * (-0.03 + 0.02 * k)
            ft += finger(A(an, (dx, -0.1, 0.13)), [(dx * 0.3, -0.005, 0.06), (dx * 0.3, -0.008, 0.05)], [0.011, 0.009, 0.007], "sinew",
                         0.04, 0.007, (0, -0.4, 1.0), (0, -1, 0))
        R.part("foot_%s" % tag, "leg_%s_lo" % tag, an, ft, tris=1200)
    return R


# =============================================================================================
# 2. STITCHED BRUTE
# =============================================================================================

@asset
def stitched_brute():
    """A 2.7 m hunched abomination of sewn corpses: a cleaver fused into the right forearm, two
    extra withered arms, a moaning face sewn into the belly, a stitched-shut head."""
    R = Rig("stitched_brute")
    # Pelvis + butcher's apron -------------------------------------------------------------------
    hips = organic([sphere(0.3, (0, 1.08, -0.02), (1.25, 0.75, 0.9), "skin"),
                    sphere(0.17, (0.2, 0.98, -0.12), (1, 1, 1), "skin"), sphere(0.17, (-0.2, 0.98, -0.12), (1, 1, 1), "skin")],
                   voxel=0.018, name="hips", role="skin")
    apron = shell(lambda t, a: 0.36 + 0.06 * t, lambda t, a: 1.2 - t * 0.62 - (0.12 * H(int(a * 9), 3) if t > 0.99 else 0.0),
                  20, 6, "apron", close_top=False)
    # keep only the front half of the apron
    bm = bmesh.new()
    bm.from_mesh(apron.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y > -0.12], context='FACES')
    bm.to_mesh(apron.data)
    bm.free()
    R.part("pelvis", None, (0, 1.1, 0), [hips, apron] + seam(hips, [(0.33, 1.15, 0.12), (0.12, 1.0, 0.25), (-0.15, 1.02, 0.24)], seed=1), tris=2600)
    # Torso: bloated belly, huge hunched chest, hump with a second corpse fused in ------------------
    body = organic([sphere(0.36, (0, 1.38, 0.13), (1.12, 1.0, 1.0), "skin"),
                    sphere(0.42, (0, 1.86, 0.0), (1.32, 0.85, 0.95), "skin"),
                    sphere(0.3, (0.05, 2.1, -0.22), (1.25, 0.9, 0.9), "skin"),
                    sphere(0.21, (0.58, 2.06, 0.0), (1, 1, 1), "skin"), sphere(0.21, (-0.58, 2.06, 0.0), (1, 1, 1), "skin"),
                    tube([(0, 2.05, 0.12), (0, 2.18, 0.26)], [0.17, 0.13], 12, "skin"),
                    sphere(0.3, (0, 1.14, 0.24), (1.2, 0.42, 0.9), "skin"),
                    sphere(0.2, (0.3, 1.62, 0.3), (1.0, 0.5, 0.8), "skin")],
                   voxel=0.02, name="torso", role="skin")
    C.jitter(body, 0.035, 4, 2.2)
    C.jitter(body, 0.008, 5, 9.0)
    patches = [organic([sphere(0.2, (0.24, 1.92, 0.3), (1.0, 1.0, 0.42), "skin_b")], voxel=0.015, name="patch", role="skin_b"),
               organic([sphere(0.26, (-0.3, 1.45, 0.22), (0.9, 1.1, 0.5), "skin_b")], voxel=0.015, name="patch", role="skin_b"),
               organic([sphere(0.22, (-0.1, 2.15, -0.42), (1.2, 0.8, 0.5), "skin_b")], voxel=0.015, name="patch", role="skin_b")]
    # The belly face: a peeled human face sewn on, mouth agape.
    face = organic([sphere(0.13, (0.08, 1.42, 0.47), (0.85, 1.15, 0.35), "skin_b"),
                    sphere(0.035, (0.08, 1.4, 0.505), (0.7, 0.6, 0.8), "skin_b")], voxel=0.008, name="bellyface", role="skin_b")
    for s in (1, -1):
        boolean(face, sphere(0.02, (0.08 + s * 0.042, 1.47, 0.52), (1.2, 0.7, 1.0), "dark", 10, 6))
    boolean(face, sphere(0.032, (0.08, 1.34, 0.52), (1.0, 1.4, 1.0), "dark", 10, 6))
    face = join([face, eye((0.122, 1.468, 0.51), 0.009), eye((0.038, 1.468, 0.51), 0.009)], "bellyface")
    sewn = []
    for i, (c, rad, sq) in enumerate([((0.24, 1.92, 0.3), 0.19, 0.42), ((-0.3, 1.45, 0.22), 0.22, 0.5), ((0.08, 1.42, 0.47), 0.14, 0.35)]):
        ring = [A(c, (math.cos(TAU * k / 14) * rad * (0.95 if i != 2 else 0.85), math.sin(TAU * k / 14) * rad * (1.0 if i != 2 else 1.15), 0.05))
                for k in range(15)]
        sewn += seam(body, ring, staples=0.12, seed=10 + i, ridge=0.016, drips=0.15)
    sewn += seam(body, [(0, 2.05, 0.38), (0.0, 1.75, 0.46), (0.02, 1.5, 0.5), (0.05, 1.2, 0.43)], staples=0.2, seed=20, ridge=0.018, drips=0.3)  # Y-incision
    sewn += seam(body, [(0.45, 2.15, 0.18), (0.22, 1.98, 0.36), (0.0, 2.05, 0.38)], seed=21)
    sewn += seam(body, [(-0.45, 2.15, 0.18), (-0.22, 1.98, 0.36), (0.0, 2.05, 0.38)], seed=22)
    sewn += seam(body, [(0.5, 1.8, -0.25), (0.2, 2.0, -0.42), (-0.25, 2.2, -0.35)], seed=23)
    # The second corpse: ribs and a spine bursting from the hump.
    extra = []
    for i in range(4):
        y = 2.28 - i * 0.07
        extra.append(tube([(0.15, y, -0.38), (0.28, y - 0.03, -0.46), (0.33, y - 0.08, -0.4)], 0.014, 6, "bone"))
    extra.append(tube([(0.1, 2.36, -0.36), (0.12, 2.1, -0.44)], 0.022, 6, "bone"))
    extra.append(sphere(0.07, (0.24, 2.18, -0.44), (1, 1.2, 0.6), "flesh", 10, 6))
    R.part("torso", "pelvis", (0, 1.25, 0), [body, face] + patches + sewn + extra, tris=9000)
    # Head: swollen, sunk forward on the hump, sewn shut; one ember eye; a hook through the cheek;
    # a huge underslung jaw of mismatched teeth -------------------------------------------------------
    hd = organic([sphere(0.19, (0, 2.36, 0.38), (0.95, 1.0, 1.0), "skin"),
                  sphere(0.15, (0, 2.22, 0.45), (1.2, 0.75, 1.0), "skin"),
                  sphere(0.08, (0, 2.42, 0.53), (1.6, 0.45, 0.6), "skin"),
                  sphere(0.06, (0.13, 2.33, 0.47), (0.8, 1.0, 0.9), "skin")], voxel=0.011, name="head", role="skin")
    C.jitter(hd, 0.012, 13, 4.0)
    boolean(hd, sphere(0.038, (0.07, 2.37, 0.55), (1, 0.8, 1), "dark", 10, 6))
    boolean(hd, sphere(0.09, (0, 2.19, 0.58), (1.25, 0.55, 0.7), "dark", 12, 8))
    hparts = [hd, eye((0.07, 2.37, 0.545), 0.02)]
    for k in range(9):
        x = (k - 4) * 0.026
        tip_y = 2.23 + (0.03 if k % 3 else 0.05)
        hparts.append(cone_tooth((x, 2.15, 0.6 - abs(x) * 0.5), (x * 1.05, tip_y, 0.61 - abs(x) * 0.5), 0.011 + 0.004 * (k % 2)))
    hparts += seam(hd, [(-0.12, 2.39, 0.5), (-0.03, 2.36, 0.56)], step=0.025, stitch_len=0.05, seed=31, ridge=0.013)
    hparts += seam(hd, [(-0.1, 2.24, 0.55), (0.0, 2.27, 0.6), (0.1, 2.24, 0.55)], step=0.025, stitch_len=0.09, seed=32, ridge=0.006)
    hparts += seam(hd, [(0.0, 2.55, 0.4), (0.0, 2.5, 0.2), (0.02, 2.36, 0.12)], seed=33, ridge=0.016, drips=0.3)
    hparts.append(tube([(0.17, 2.17, 0.43), (0.2, 2.26, 0.5), (0.15, 2.33, 0.56), (0.1, 2.3, 0.59)], 0.011, 6, "iron"))
    R.part("head", "torso", (0, 2.22, 0.3), hparts, tris=3400)
    # A second head grafted onto the left shoulder: dead, eyes sewn, jaw slack.
    hb = organic([sphere(0.13, (0.42, 2.38, 0.12), (0.9, 1.05, 1.0), "skin_b"),
                  sphere(0.08, (0.42, 2.27, 0.2), (1.0, 0.8, 0.9), "skin_b"),
                  tube([(0.4, 2.2, 0.05), (0.41, 2.29, 0.1)], [0.08, 0.07], 8, "skin_b")], voxel=0.01, name="head_b", role="skin_b")
    boolean(hb, sphere(0.05, (0.42, 2.22, 0.27), (0.9, 1.4, 0.8), "dark", 10, 6))
    hbp = [hb] + seam(hb, [(0.36, 2.41, 0.23), (0.48, 2.41, 0.23)], step=0.02, stitch_len=0.035, seed=34, ridge=0.006)
    hbp += seam(hb, [(0.3, 2.22, 0.06), (0.42, 2.18, 0.16), (0.54, 2.22, 0.06)], seed=35, drips=0.4)
    R.part("head_b", "torso", (0.41, 2.2, 0.06), hbp, tris=1800)
    # Left arm: massive, sewn at the shoulder, a huge clawed hand ---------------------------------------
    sh, el, wr = (0.64, 2.07, 0.0), (0.84, 1.48, 0.12), (0.88, 0.92, 0.28)
    up = organic([mlimb(sh, el, 0.2, 0.15, 1.28, 0.38, "skin"), sphere(0.22, A(sh, (0.03, -0.02, 0)), (1, 0.9, 0.95), "skin"),
                  sphere(0.11, L(sh, el, 0.45), (0.9, 1.4, 0.9), "skin")], voxel=0.016, name="uparm", role="skin")
    C.jitter(up, 0.025, 5, 2.6)
    R.part("arm_L_up", "torso", sh, [up] + seam(up, [(0.5, 2.06, 0.18), (0.72, 1.96, 0.2), (0.88, 2.0, 0.02)], seed=40, ridge=0.016, drips=0.25), tris=2400)
    fo = organic([mlimb(el, wr, 0.17, 0.12, 1.22, 0.25, "skin_b")], voxel=0.014, name="forearm", role="skin_b")
    C.jitter(fo, 0.02, 15, 3.0)
    R.part("arm_L_lo", "arm_L_up", el, [fo] + seam(fo, [(0.94, 1.38, 0.12), (1.0, 1.18, 0.2), (0.97, 1.0, 0.32)], seed=41, drips=0.3), tris=2000)
    hand = [organic([sphere(0.14, A(wr, (0.0, -0.11, 0.02)), (0.75, 1.15, 1.0), "skin_b")], voxel=0.012, name="palm", role="skin_b")]
    for k in range(4):
        dz = -0.09 + 0.058 * k
        kn = A(wr, (0.02, -0.24, dz))
        hand += finger(kn, [(0.01, -0.11, dz * 0.2), (-0.01, -0.09, 0.03), (-0.04, -0.05, 0.04)], [0.042, 0.037, 0.031, 0.024], "skin_b",
                       0.07, 0.02, None, (-1, -0.5, 0))
    hand += finger(A(wr, (-0.08, -0.14, 0.1)), [(-0.05, -0.06, 0.06), (-0.04, -0.06, 0.03)], [0.04, 0.033, 0.026], "skin_b", 0.05, 0.018)
    R.part("hand_L", "arm_L_lo", wr, hand, tris=1800)
    # Right arm: the cleaver fused through the wrist stump ---------------------------------------------
    sh, el, wr = (-0.62, 2.07, 0.0), (-0.8, 1.5, 0.12), (-0.84, 1.02, 0.24)
    up = organic([mlimb(sh, el, 0.15, 0.12, 1.2, 0.35, "skin_b"), sphere(0.17, A(sh, (-0.02, -0.02, 0)), (1, 0.9, 0.95), "skin_b")],
                 voxel=0.016, name="uparm", role="skin_b")
    C.jitter(up, 0.022, 6, 2.6)
    R.part("arm_R_up", "torso", sh, [up] + seam(up, [(-0.55, 2.03, 0.15), (-0.72, 1.98, 0.16), (-0.82, 2.03, 0.02)], seed=42), tris=2000)
    fo = organic([mlimb(el, wr, 0.14, 0.1, 1.15, 0.3, "skin"), sphere(0.1, A(wr, (0, 0.0, 0.0)), (1, 0.7, 1), "flesh")],
                 voxel=0.014, name="forearm", role="skin")
    blade = box((0.04, 0.82, 0.38), (-0.85, 0.6, 0.36), (0.12, 0, 0), "blade", bevel=0.008)
    boolean(blade, cyl(0.035, 0.035, 0.2, 12, (-0.95, 0.83, 0.42), (0, 0, math.pi * 0.5), "dark"), transfer=False)
    spine = box((0.055, 0.84, 0.05), (-0.85, 0.6, 0.18), (0.12, 0, 0), "iron", bevel=0.01)
    gore = join([box((0.046, 0.46, 0.13), (-0.85, 0.5, 0.47), (0.12, 0, 0), "blood"),
                 box((0.046, 0.22, 0.2), (-0.85, 0.82, 0.38), (0.12, 0, 0), "blood"),
                 organic([sphere(0.05, (-0.83, 0.98, 0.3), (0.6, 2.0, 1.4), "blood")], voxel=0.01, name="smear", role="blood")], "smear")
    bands = [C.torus(0.105 - 0.008 * i, 0.016, (-0.84, 1.12 + i * 0.12, 0.22), (0.15, 0, 0), "iron", 14, 6) for i in range(3)]
    spikes = [tube([(-0.84 + 0.11 * math.cos(a), 1.16, 0.22 + 0.11 * math.sin(a)), (-0.84 + 0.15 * math.cos(a), 1.18, 0.22 + 0.15 * math.sin(a))],
                   [0.012, 0.001], 5, "iron") for a in (0.3, 1.8, 3.6, 5.0)]
    R.part("arm_R_lo", "arm_R_up", el, [fo, blade, spine, gore] + bands + spikes, tris=3000)
    R.end("cleaver_end", "arm_R_lo", (-0.85, 0.2, 0.42))
    # Extra limbs: a withered arm from the ribs, a clawing arm from the hump ------------------------------
    p0 = (-0.4, 1.72, 0.3)
    ea = [tube([p0, (-0.5, 1.5, 0.46), (-0.48, 1.27, 0.55)], [0.055, 0.04, 0.032], 8, "skin_b")]
    for k in range(4):
        ea += finger(A((-0.48, 1.27, 0.55), ((k - 1.5) * 0.015, -0.02, 0.0)), [((k - 1.5) * 0.01, -0.06, 0.02), (0.0, -0.05, 0.03)],
                     [0.011, 0.009, 0.007], "skin_b", 0.025, 0.006)
    ea.append(sphere(0.07, p0, (1, 1, 1), "flesh", 10, 6))
    R.part("extra_a", "torso", p0, ea, tris=900)
    p1 = (0.26, 2.27, -0.36)
    eb = [tube([p1, (0.36, 2.55, -0.5), (0.28, 2.78, -0.44)], [0.06, 0.045, 0.035], 8, "skin")]
    for k in range(4):
        a = (k - 1.5) * 0.5
        eb += finger((0.28, 2.79, -0.44), [(math.sin(a) * 0.05, 0.06, math.cos(a) * 0.03), (math.sin(a) * 0.03, 0.04, 0.02)],
                     [0.012, 0.01, 0.008], "skin", 0.03, 0.007, None, (0, 0, 1))
    eb.append(sphere(0.07, p1, (1, 1, 1), "flesh", 10, 6))
    R.part("extra_b", "torso", p1, eb, tris=900)
    # Legs ------------------------------------------------------------------------------------------
    for s, tag in ((1, "L"), (-1, "R")):
        hp, kn, an = (s * 0.3, 1.03, 0.0), (s * 0.36, 0.57, 0.1), (s * 0.36, 0.1, 0.0)
        th = organic([mlimb(hp, kn, 0.2 if s > 0 else 0.16, 0.15 if s > 0 else 0.12, 1.15, 0.35, "skin")], voxel=0.016, name="thigh", role="skin")
        C.jitter(th, 0.02, 7 + s, 3.0)
        R.part("leg_%s_up" % tag, "pelvis", hp, [th] + seam(th, [A(hp, (0, -0.08, 0.17)), A(L(hp, kn, 0.5), (s * 0.05, 0, 0.17)), A(kn, (0, 0.06, 0.13))], seed=50 + s), tris=1800)
        sn = organic([mlimb(kn, an, 0.14, 0.1, 1.15, 0.3, "skin_b" if s > 0 else "skin")], voxel=0.014, name="shin", role="skin_b" if s > 0 else "skin")
        R.part("leg_%s_lo" % tag, "leg_%s_up" % tag, kn, [sn], tris=1400)
        ft = organic([sphere(0.13, A(an, (0, -0.05, 0.08)), (0.85, 0.5, 1.3), "skin_b" if s > 0 else "skin")] +
                     [sphere(0.045, A(an, (s * (k - 1) * 0.06, -0.07, 0.24)), (1, 0.8, 1.2), "skin") for k in range(3)],
                     voxel=0.012, name="foot", role="skin_b" if s > 0 else "skin")
        R.part("foot_%s" % tag, "leg_%s_lo" % tag, an, [ft], tris=900)
    return R


# =============================================================================================
# 3. LIMB SPIDER
# =============================================================================================

def mouth(rad, teeth=12, depth=0.06, tongue=False):
    """A lipped mouth ring built at the origin facing +Y (local): lips, inward teeth, a dark throat."""
    objs = [C.torus(rad, rad * 0.32, (0, 0, 0), (0, 0, 0), "lips", 18, 8, (1.0, 1.0, 0.62)),
            sphere(rad * 0.95, (0, -depth * 0.4, 0), (1.0, 0.8, 0.62), "dark", 12, 6)]
    for k in range(teeth):
        a = TAU * k / teeth
        base = (math.cos(a) * rad * 0.95, 0.01, math.sin(a) * rad * 0.62)
        tip = (math.cos(a) * rad * 0.35, -0.012 - 0.01 * (k % 2), math.sin(a) * rad * 0.22)
        objs.append(cone_tooth(base, tip, rad * 0.12))
    if tongue:
        objs.append(tube([(0, -0.02, 0), (0.0, 0.03, rad * 0.4), (0.02, 0.04, rad * 1.1)], [rad * 0.3, rad * 0.25, rad * 0.1], 8, "flesh"))
    return objs


@asset
def limb_spider():
    """A crawling knot of human arms and legs round a prone torso with too many mouths; an
    upside-down head hangs under its front. Six limbs, each upper+lower (+ *_end) for IK."""
    R = Rig("limb_spider")
    BY = 0.42
    core = organic([sphere(0.3, (0, BY, 0.02), (0.85, 0.52, 1.3), "skin"),
                    sphere(0.2, (0, BY + 0.04, 0.3), (1.35, 0.65, 0.8), "skin"),
                    sphere(0.2, (0, BY, -0.32), (1.15, 0.7, 0.9), "skin"),
                    sphere(0.09, (0.12, BY + 0.12, 0.22), (1.2, 0.5, 1.1), "skin"),
                    sphere(0.09, (-0.12, BY + 0.12, 0.22), (1.2, 0.5, 1.1), "skin")] +
                   [sphere(0.1, (s * 0.27, BY + 0.01, z), (1, 1, 1), "skin") for s in (1, -1) for z in (0.3, 0.0, -0.32)],
                   voxel=0.012, name="core", role="skin")
    C.jitter(core, 0.012, 9, 6.0)
    raw = [organic([sphere(0.1, (s * 0.3, BY + 0.01, z), (0.55, 1.0, 1.0), "flesh")], voxel=0.01, name="raw", role="flesh")
           for s in (1, -1) for z in (0.3, 0.0, -0.32)]
    raw.append(organic([sphere(0.12, (0.05, BY + 0.1, -0.05), (1.3, 0.35, 1.6), "flesh")], voxel=0.01, name="raw", role="flesh"))
    spine_b = [sphere(0.03, (0, BY + 0.155 - 0.025 * abs(i - 5) / 5, -0.36 + i * 0.07), (1.2, 0.8, 1.0), "bone", 8, 5) for i in range(11)]
    sewn = seam(core, [(0.17, BY + 0.12, 0.36), (0.22, BY + 0.1, 0.0), (0.16, BY + 0.11, -0.36)], seed=60, ridge=0.014, drips=0.4)
    sewn += seam(core, [(-0.2, BY + 0.11, 0.3), (-0.12, BY + 0.14, 0.05), (-0.22, BY + 0.1, -0.2)], seed=61, ridge=0.014, drips=0.4)
    R.part("body", None, (0, BY, 0), [core] + raw + spine_b + sewn, tris=6500)
    # Mouths: front (where the neck should be), two on the back, one on the flank.
    R.part("mouth_0", "body", (0, BY + 0.07, 0.5), mouth(0.1, 14, tongue=True), local=True, rot=(math.pi * 0.4, 0, 0), tris=1400)
    R.part("mouth_1", "body", (0.08, BY + 0.15, 0.1), mouth(0.08, 12), local=True, rot=(0, 0.4, 0.15), tris=1000)
    R.part("mouth_2", "body", (-0.1, BY + 0.15, -0.2), mouth(0.07, 10), local=True, rot=(0.2, -0.6, -0.18), tris=900)
    R.part("mouth_3", "body", (-0.28, BY + 0.03, 0.14), mouth(0.055, 8), local=True, rot=(0, 0, math.pi * 0.6), tris=700)
    # The head hangs upside down under its front, crown scraping the ground, eyes rolled up.
    hd = organic([sphere(0.11, (0, 0.17, 0.5), (0.88, 1.12, 1.0), "skin"),
                  sphere(0.065, (0, 0.25, 0.54), (1.1, 0.8, 0.9), "skin"),
                  tube([(0, 0.3, 0.47), (0, BY - 0.04, 0.44)], [0.055, 0.065], 8, "skin")], voxel=0.009, name="head", role="skin")
    for s in (1, -1):
        boolean(hd, sphere(0.024, (s * 0.038, 0.2, 0.595), (1, 0.8, 1), "dark", 10, 6))
    boolean(hd, sphere(0.038, (0, 0.285, 0.6), (1.2, 0.8, 1.0), "dark", 10, 6))
    R.part("head", "body", (0, BY - 0.06, 0.44), [hd, eye((0.038, 0.2, 0.588), 0.013), eye((-0.038, 0.2, 0.588), 0.013)], tris=1600)
    # Limbs: k = 0,1 front arms; 2,3 human legs; 4,5 rear arms.
    sockets = [((0.28, BY + 0.02, 0.3), 0.6, "arm"), ((-0.28, BY + 0.02, 0.3), math.pi - 0.6, "arm"),
               ((0.3, BY, 0.0), -0.1, "leg"), ((-0.3, BY, 0.0), math.pi + 0.1, "leg"),
               ((0.26, BY + 0.01, -0.32), -0.75, "arm"), ((-0.26, BY + 0.01, -0.32), math.pi + 0.75, "arm")]
    roles = ["skin", "skin_b", "muscle", "skin", "muscle", "skin_b"]
    for k, (sk, ang, kind) in enumerate(sockets):
        out = (math.cos(ang), 0.0, math.sin(ang))
        rl = roles[k]
        a_len, b_len = (0.48, 0.7) if kind == "arm" else (0.55, 0.78)
        knee = A(sk, A(S(out, a_len * 0.9), (0, a_len * 0.42, 0)))
        # The foot lands about 1 m out, on the ground (y = 0.02).
        horiz = math.sqrt(max(0.01, b_len ** 2 - (knee[1] - 0.03) ** 2))
        foot = A((knee[0], 0.03, knee[2]), S(out, horiz))
        if kind == "arm":
            up = organic([mlimb(sk, knee, 0.058, 0.045, 1.3, 0.35, rl)], voxel=0.009, name="up", role=rl)
            lo = organic([mlimb(knee, A(foot, (0, 0.05, 0)), 0.045, 0.034, 1.25, 0.3, rl)], voxel=0.008, name="lo", role=rl)
            if rl == "muscle":
                striate(up, sk, knee, freq=10, amp=0.005)
                striate(lo, knee, foot, freq=9, amp=0.0045)
            sd = Vector((out[0], 0, out[2]))
            lob = [lo, sphere(0.028, knee, (1, 1, 1), "bone", 8, 5),
                   organic([sphere(0.04, A(foot, (0, 0.03, 0)), (1.2, 0.45, 1.0), "skin")], voxel=0.007, name="palm", role="skin")]
            for f in range(5):
                fa = ang + (f - 2) * 0.38
                fd = (math.cos(fa), 0.0, math.sin(fa))
                kn = A(foot, A(S(fd, 0.035), (0, 0.03, 0)))
                lob += finger(kn, [A(S(fd, 0.06), (0, 0.02, 0)), A(S(fd, 0.05), (0, -0.03, 0)), A(S(fd, 0.02), (0, -0.035, 0))],
                              [0.011, 0.0095, 0.008, 0.006], "skin")
        else:
            ankle = A(foot, (-out[0] * 0.06, 0.09, -out[2] * 0.06))
            up = organic([mlimb(sk, knee, 0.088, 0.06, 1.25, 0.35, rl)], voxel=0.01, name="up", role=rl)
            lo = organic([mlimb(knee, ankle, 0.062, 0.042, 1.3, 0.25, rl)], voxel=0.009, name="lo", role=rl)
            if rl == "muscle":
                striate(up, sk, knee, freq=11, amp=0.006)
                striate(lo, knee, ankle, freq=9, amp=0.005)
            lob = [lo, sphere(0.036, knee, (1, 1, 1), "bone", 8, 5),
                   organic([sphere(0.045, ankle, (1, 1, 1), rl),
                            tube([ankle, A(foot, (out[0] * 0.02, 0.02, out[2] * 0.02)), A(foot, (out[0] * 0.09, 0.0, out[2] * 0.09))],
                                 [0.04, 0.035, 0.028], 10, rl)], voxel=0.008, name="foot", role=rl)]
            for t in range(4):
                ta = ang + (t - 1.5) * 0.28
                td = (math.cos(ta), 0.0, math.sin(ta))
                lob += finger(A(foot, A(S(out, 0.085), S(td, 0.01))), [A(S(td, 0.04), (0, -0.004, 0)), A(S(td, 0.025), (0, -0.01, 0))],
                              [0.012, 0.01, 0.008], rl)
        up_parts = [up, organic([sphere(0.065, sk, (1, 1, 1), "flesh")], voxel=0.01, name="root", role="flesh")]
        up_parts += seam(up, [A(sk, (0, 0.05, 0)), L(sk, knee, 0.3)], step=0.03, stitch_len=0.05, seed=70 + k, drips=0.4)
        lob.append(organic([sphere(0.05, knee, (1, 1, 1), "flesh")], voxel=0.009, name="kneeflesh", role="flesh"))
        R.part("limb%d_a" % k, "body", sk, up_parts, tris=1100)
        R.part("limb%d_b" % k, "limb%d_a" % k, knee, lob, tris=1300 if kind == "arm" else 1000)
        R.end("limb%d_end" % k, "limb%d_b" % k, foot)
    return R


# =============================================================================================
# 4. HOLLOW MOURNER
# =============================================================================================

@asset
def hollow_mourner():
    """A faceless figure in a long tattered mourning dress and a lace veil, its hem hanging just
    above the ground. A vertical 'split' part (hidden at scale 0) opens in the face to wail."""
    R = Rig("hollow_mourner")

    def hem(a, k_seed, depth):
        k = int(round(a / TAU * 40)) % 40
        return depth * (H(k, k_seed) ** 1.5) * (1.0 if k % 2 == 0 else 0.35)

    skirt = shell(lambda t, a: (0.14 + 0.4 * t ** 1.35) * (1.0 + 0.1 * t * math.sin(a * 13 + t * 3)),
                  lambda t, a: 1.22 - 1.1 * t - (hem(a, 7, 0.32) if t > 0.99 else 0.0) - (0.05 * math.cos(a) * t),
                  40, 10, "dress", close_top=True, zf=lambda t, a: -0.05 * t)
    under = shell(lambda t, a: (0.13 + 0.3 * t) * (1.0 + 0.05 * math.sin(a * 9)),
                  lambda t, a: 1.15 - 0.95 * t - (hem(a, 9, 0.2) if t > 0.99 else 0.0),
                  28, 6, "lace", close_top=False)
    R.part("body", None, (0, 1.15, 0), [skirt, under], tris=3000)
    bod = C.lathe([(0.0, 1.2), (0.15, 1.21), (0.17, 1.33), (0.15, 1.46), (0.19, 1.58), (0.2, 1.64), (0.12, 1.69), (0.06, 1.72), (0.045, 1.8), (0.0, 1.8)],
                  18, "dress")
    collar = shell(lambda t, a: 0.055 + 0.13 * t, lambda t, a: 1.79 - 0.13 * t - (0.03 * (int(round(a / TAU * 24)) % 2) if t > 0.99 else 0.0),
                   24, 3, "lace", close_top=False)
    R.part("torso", "body", (0, 1.2, 0), [bod, collar], tris=1600)
    hd = organic([sphere(0.098, (0, 1.9, 0.02), (0.8, 1.16, 0.95), "porcelain"),
                  sphere(0.05, (0, 1.82, 0.06), (1.0, 0.9, 0.9), "porcelain")], voxel=0.006, name="head", role="porcelain")
    # Shallow hollows where eyes and a mouth should be.
    for v in hd.data.vertices:
        p = Vector((v.co.x, v.co.z, -v.co.y))
        for c, r in (((0.032, 1.915, 0.1), 0.026), ((-0.032, 1.915, 0.1), 0.026), ((0.0, 1.83, 0.1), 0.022)):
            d = (p - Vector(c)).length
            if d < r * 1.8:
                v.co -= v.normal * 0.007 * (1.0 - d / (r * 1.8)) ** 2
    def veil_r(t, a):
        if t < 0.2:
            return 0.112 * math.sin(t / 0.2 * math.pi * 0.5) + 0.004
        u = (t - 0.2) / 0.8
        return 0.116 + 0.02 * u + 0.17 * u * u * (0.5 - 0.5 * math.cos(a))

    def veil_y(t, a):
        if t < 0.2:
            return 1.905 + 0.14 * math.cos(t / 0.2 * math.pi * 0.5)
        u = (t - 0.2) / 0.8
        return 1.905 - u * (0.0 + 1.05 * (0.5 - 0.5 * math.cos(a)) ** 0.9) - (hem(a, 11, 0.16) if t > 0.99 else 0.0)

    veil = shell(veil_r, veil_y, 36, 14, "lace", close_top=True, zf=lambda t, a: 0.02 - 0.04 * t)
    R.part("head", "torso", (0, 1.78, 0.02), [hd, veil], tris=2800)
    split = [sphere(0.06, (0, 0, 0), (0.1, 1.0, 0.08), "glow_pale", 10, 8)]
    R.part("split", "head", (0, 1.87, 0.104), split, local=True)
    for s, tag in ((1, "L"), (-1, "R")):
        sh, el, wr = (s * 0.19, 1.63, 0.0), (s * 0.23, 1.3, 0.05), (s * 0.21, 0.98, 0.13)
        R.part("arm_%s_up" % tag, "torso", sh, [tube([sh, L(sh, el, 0.5), el], [0.04, 0.034, 0.033], 10, "dress")], tris=400)
        sleeve = shell(lambda t, a: 0.035 + 0.06 * t ** 1.3, lambda t, a: -0.34 * t - (hem(a, 13 + s, 0.12) if t > 0.99 else 0.0), 14, 5, "dress", close_top=False)
        # bend the sleeve along elbow->wrist
        d = Vector(wr) - Vector(el)
        rot = Vector((0, -1, 0)).rotation_difference(d.normalized())
        for v in sleeve.data.vertices:
            p = Vector((v.co.x, v.co.z, -v.co.y))
            q = rot @ p + Vector(el)
            v.co = G(q.x, q.y, q.z)
        R.part("arm_%s_lo" % tag, "arm_%s_up" % tag, el, [sleeve, tube([el, wr], [0.028, 0.022], 8, "dress")], tris=700)
        hand = [organic([sphere(0.03, A(wr, (0, -0.04, 0.01)), (0.7, 1.3, 0.9), "porcelain")], voxel=0.005, name="palm", role="porcelain")]
        for k in range(6):
            dz = -0.022 + 0.009 * k
            hand += finger(A(wr, (s * 0.004, -0.07, dz)), [(0.0, -0.06, dz * 0.4), (s * -0.005, -0.055, 0.012), (s * -0.008, -0.045, 0.02),
                                                           (s * -0.006, -0.03, 0.022)], [0.0065, 0.006, 0.0052, 0.0042, 0.002], "porcelain")
        R.part("hand_%s" % tag, "arm_%s_lo" % tag, wr, hand, tris=1100)
    return R


# =============================================================================================
# 5. LANTERN WIGHT
# =============================================================================================

@asset
def lantern_wight():
    """An impossibly tall (3.2 m), thin figure of grey tallow under a tattered black mantle,
    a crown of guttering candles fused into its skull, a cage-lantern hung from its right hand."""
    R = Rig("lantern_wight")
    pv = organic([sphere(0.12, (0, 1.55, 0), (1.2, 0.8, 0.8), "wax")], voxel=0.01, name="pelvis", role="wax")
    loin = shell(lambda t, a: 0.14 + 0.08 * t, lambda t, a: 1.62 - 0.5 * t - (0.2 * H(int(a * 4), 2) if t > 0.99 else 0.0), 16, 4, "cloth_black", close_top=False)
    R.part("pelvis", None, (0, 1.55, 0), [pv, loin], tris=1200)
    torso = organic([tube([(0, 1.6, 0.0), (0, 2.1, 0.02), (0, 2.5, 0.07)], [0.085, 0.07, 0.11], 12, "wax"),
                     tube([(0.27, 2.58, 0.05), (0, 2.6, 0.08), (-0.27, 2.58, 0.05)], [0.055, 0.075, 0.055], 10, "wax"),
                     tube([(0, 2.58, 0.07), (0, 2.76, 0.13)], [0.05, 0.04], 8, "wax")] +
                    [tube([(s * 0.02, 2.38 - i * 0.07, -0.07), (s * 0.1, 2.36 - i * 0.075, 0.0), (s * 0.04, 2.32 - i * 0.08, 0.1)], 0.012, 6, "wax")
                     for s in (1, -1) for i in range(5)], voxel=0.008, name="torso", role="wax")
    drips = []
    for i in range(14):
        x = (H(i, 1) - 0.5) * 0.4
        y0 = 2.45 + H(i, 2) * 0.15
        ln = 0.1 + H(i, 3) * 0.35
        z = 0.1 if i % 2 == 0 else -0.06
        drips.append(tube([(x, y0, z), (x * 1.02, y0 - ln * 0.6, z * 1.05), (x, y0 - ln, z)], [0.014, 0.012, 0.016], 6, "wax"))
    drips = [organic(drips, voxel=0.007, name="drips", role="wax")]
    mantle = shell(lambda t, a: 0.12 + 0.2 * t ** 0.7,
                   lambda t, a: 2.74 - t * (0.75 + 0.55 * (0.5 - 0.5 * math.cos(a))) - (0.3 * H(int(a * 6), 5) ** 2 if t > 0.99 else 0.0),
                   30, 8, "cloth_black", close_top=False, zf=lambda t, a: 0.05)
    # Open the mantle at the front below the shoulders so the ribbed tallow chest shows.
    bm = bmesh.new()
    bm.from_mesh(mantle.data)
    cut = []
    for f in bm.faces:
        c = f.calc_center_median()
        gy, gz, gx = c.z, -c.y, c.x
        if gy < 2.56 and gz > -0.02 and abs(gx) < 0.2 + (2.56 - gy) * 0.15:
            cut.append(f)
    bmesh.ops.delete(bm, geom=cut, context='FACES')
    bm.to_mesh(mantle.data)
    bm.free()
    R.part("spine", "pelvis", (0, 1.62, 0), [torso, mantle] + drips, tris=5000)
    hd = organic([sphere(0.1, (0, 3.0, 0.13), (0.85, 1.2, 1.05), "wax"),
                  sphere(0.075, (0, 2.84, 0.19), (0.8, 1.6, 0.8), "wax"),
                  sphere(0.035, (0.05, 2.9, 0.22), (0.7, 0.8, 0.7), "wax"), sphere(0.035, (-0.05, 2.9, 0.22), (0.7, 0.8, 0.7), "wax")] +
                 [tube([(x, 2.92, 0.24), (x * 1.1, 2.8, 0.255), (x, 2.68 - abs(x) * 2.0, 0.24)], [0.013, 0.011, 0.016], 6, "wax") for x in (-0.05, -0.012, 0.03, 0.06)],
                 voxel=0.006, name="head", role="wax")
    for s in (1, -1):
        boolean(hd, sphere(0.034, (s * 0.038, 2.94, 0.235), (1.0, 1.45, 1.0), "dark", 10, 6))
    boolean(hd, sphere(0.024, (0, 2.77, 0.25), (1.2, 3.2, 1.2), "dark", 8, 6))
    hp = [hd, eye((0.038, 2.925, 0.222), 0.012), eye((-0.038, 2.925, 0.222), 0.012)]
    for k in range(5):
        a = (k - 2) * 0.55
        base = (math.sin(a) * 0.065, 3.1 - abs(k - 2) * 0.03, 0.13 + math.cos(a) * 0.02 - 0.02)
        h = 0.1 + 0.1 * H(k, 8)
        tilt = (0.25 * (H(k, 9) - 0.5), 0.0, a * 0.35)
        c = cyl(0.022, 0.019, h, 8, base, tilt, "wax")
        hp.append(c)
        top = (base[0] - math.sin(tilt[2]) * h, base[1] + h * math.cos(tilt[2]), base[2])
        hp.append(sphere(0.024, A(top, (0, 0.03, 0)), (0.7, 1.9, 0.7), "flame", 8, 5))
    R.part("head", "spine", (0, 2.75, 0.12), hp, tris=2400)
    R.end("crown_end", "head", (0, 3.08, 0.14))
    for s, tag in ((1, "L"), (-1, "R")):
        sh, el, wr = (s * 0.27, 2.58, 0.05), (s * 0.32, 1.86, 0.1), (s * 0.34, 1.12, 0.16)
        up = organic([mlimb(sh, el, 0.042, 0.032, 1.15, 0.35, "wax"), sphere(0.035, el, (1, 1, 1), "wax")], voxel=0.007, name="up", role="wax")
        R.part("arm_%s_up" % tag, "spine", sh, [up], tris=900)
        lo = organic([mlimb(el, wr, 0.032, 0.022, 1.1, 0.3, "wax")], voxel=0.006, name="lo", role="wax")
        ld = [tube([L(el, wr, t0), A(L(el, wr, t0), (0.0, -0.05, 0.022)), A(L(el, wr, t0), (0.0, -0.09, 0.03))], [0.012, 0.01, 0.015], 6, "wax")
              for t0 in (0.15, 0.5, 0.8)]
        R.part("arm_%s_lo" % tag, "arm_%s_up" % tag, el, [lo] + ld, tris=900)
        hand = [organic([sphere(0.03, A(wr, (0, -0.045, 0.01)), (0.7, 1.4, 1.0), "wax")], voxel=0.005, name="palm", role="wax")]
        for k in range(4):
            dz = -0.02 + 0.013 * k
            hand += finger(A(wr, (0, -0.08, dz)), [(0, -0.08, dz * 0.3), (s * -0.004, -0.07, 0.015), (s * -0.004, -0.05, 0.02)],
                           [0.007, 0.006, 0.005, 0.0035], "wax", 0.02, 0.004)
        R.part("hand_%s" % tag, "arm_%s_lo" % tag, wr, hand, tris=900)
    # The cage-lantern hangs on a chain from the right hand.
    grip = (-0.34, 1.02, 0.18)
    lan = []
    for i in range(5):
        lan.append(C.torus(0.016, 0.004, (grip[0], grip[1] - 0.03 - i * 0.045, grip[2]), (0, 0, math.pi * 0.5 if i % 2 else 0.0), "iron", 8, 4, (1, 1, 1.6)))
    c = (grip[0], grip[1] - 0.45, grip[2])  # cage centre
    lan.append(C.lathe([(0.0, 0.0), (0.13, 0.0), (0.12, 0.03), (0.06, 0.08), (0.02, 0.12), (0.0, 0.13)], 10, "iron", A(c, (0, 0.17, 0))))
    lan.append(C.lathe([(0.0, -0.03), (0.08, -0.03), (0.13, 0.0), (0.0, 0.0)], 10, "iron", A(c, (0, -0.19, 0))))
    lan.append(C.torus(0.025, 0.006, A(c, (0, 0.31, 0)), (0, 0, math.pi * 0.5), "iron", 10, 4))
    for k in range(8):
        a = TAU * k / 8
        p0 = A(c, (math.cos(a) * 0.12, -0.19, math.sin(a) * 0.12))
        p1 = A(c, (math.cos(a) * 0.14, 0.0, math.sin(a) * 0.14))
        p2 = A(c, (math.cos(a) * 0.12, 0.17, math.sin(a) * 0.12))
        lan.append(tube([p0, p1, p2], 0.008, 5, "iron"))
    for y in (-0.08, 0.08):
        lan.append(C.torus(0.135, 0.006, A(c, (0, y, 0)), (0, 0, 0), "iron", 16, 4))
    lan.append(cyl(0.085, 0.085, 0.3, 12, A(c, (0, -0.16, 0)), role="glass"))
    lan.append(cyl(0.02, 0.02, 0.07, 8, A(c, (0, -0.16, 0)), role="wax"))
    lan.append(sphere(0.03, A(c, (0, -0.04, 0)), (0.8, 1.7, 0.8), "flame", 8, 6))
    for k in range(3):
        lan.append(sphere(0.03, A(c, ((k - 1) * 0.06, -0.215, 0.02 * k)), (0.7, 1.0, 0.7), "bone", 8, 5))  # finger bones in the cage
    R.part("lantern", "hand_R", grip, lan, tris=3200)
    R.end("lantern_light", "lantern", A(c, (0, -0.03, 0)))
    for s, tag in ((1, "L"), (-1, "R")):
        hp_, kn, an = (s * 0.1, 1.5, 0.0), (s * 0.12, 0.8, 0.1), (s * 0.12, 0.1, 0.0)
        R.part("leg_%s_up" % tag, "pelvis", hp_, [organic([mlimb(hp_, kn, 0.06, 0.042, 1.15, 0.3, "wax"), sphere(0.04, kn, (1, 1, 1), "wax")],
                                                         voxel=0.008, name="th", role="wax")], tris=900)
        lg = [organic([mlimb(kn, an, 0.042, 0.03, 1.1, 0.3, "wax")] +
                      [tube([L(kn, an, t0), A(L(kn, an, t0), (s * 0.02, -0.07, 0.03)), A(L(kn, an, t0), (s * 0.02, -0.12, 0.035))], [0.014, 0.012, 0.018], 6, "wax")
                       for t0 in (0.1, 0.45, 0.7)], voxel=0.007, name="sh", role="wax")]
        R.part("leg_%s_lo" % tag, "leg_%s_up" % tag, kn, lg, tris=900)
        R.part("foot_%s" % tag, "leg_%s_lo" % tag, an, [organic([tube([A(an, (0, 0.0, -0.04)), A(an, (0, -0.07, 0.06)), A(an, (0, -0.09, 0.2))],
                                                                       [0.03, 0.03, 0.02], 8, "wax")], voxel=0.007, name="ft", role="wax")], tris=600)
    return R


def main():
    args = C.init(sys.argv)
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        args = args[:i] + args[i + 2:]
    names = args or list(BUILT.keys())
    C.reset()
    for name in names:
        C.clear_scene()
        rig = BUILT[name]()
        rig.export()


main()

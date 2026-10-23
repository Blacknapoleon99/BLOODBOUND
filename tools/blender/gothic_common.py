"""Shared helpers for BLOODBOUND's headless Blender asset builders (DEC-057).

Run builders with:
  blender.exe -b --python tools/blender/build_props.py -- <repo_root> [asset ...]

Conventions
- All modelling helpers take GODOT coordinates (x right, y up, z toward the camera/front) and
  convert to Blender's Z-up internally (`G`). The glTF exporter turns Blender Z-up back into
  Y-up, so a point G(x, y, z) lands at (x, y, z) in Godot.
- Every asset is one joined object whose MATERIAL SLOT NAMES are roles (stone, iron, bone,
  wood, wax, flame, glow, cloth, gold, dark, blood, ...). Godot maps roles to its PBR material
  library (scripts/art/gothic_props.gd), so the GLBs carry geometry + UVs only and stay tiny.
- Organic pieces (skulls, bones, wax, rock, trees) are unions of primitives -> voxel remesh ->
  smooth -> decimate. Hard-surface pieces get real bevels. Everything gets box-projected UVs.
- Only original procedural geometry: no third-party meshes are used by these builders.
"""
import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, Matrix, Euler, noise

ROOT = None


def init(argv):
    global ROOT
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    ROOT = args[0] if args else os.getcwd()
    return args[1:]


def G(x, y=None, z=None):
    """Godot (x, y up, z front) -> Blender (x, -z, y)."""
    if y is None:
        x, y, z = x
    return Vector((x, -z, y))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


ROLE_COLORS = {
    "stone": (0.32, 0.3, 0.3), "stone_dark": (0.16, 0.15, 0.16), "stone_pale": (0.55, 0.52, 0.48),
    "iron": (0.22, 0.17, 0.14), "bone": (0.78, 0.7, 0.55), "wood": (0.3, 0.2, 0.13),
    "wax": (0.85, 0.78, 0.6), "flame": (1.0, 0.55, 0.15), "glow": (1.0, 0.08, 0.04),
    "cloth": (0.35, 0.05, 0.06), "gold": (0.7, 0.5, 0.2), "dark": (0.02, 0.02, 0.02),
    "blood": (0.35, 0.0, 0.01), "rock": (0.25, 0.23, 0.23), "glass": (0.1, 0.2, 0.25),
}


def mat(role):
    m = bpy.data.materials.get(role)
    if m is None:
        m = bpy.data.materials.new(role)
        c = ROLE_COLORS.get(role, (0.5, 0.5, 0.5))
        m.diffuse_color = (c[0], c[1], c[2], 1.0)
    return m


def _link(name, me):
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def from_bm(bm, name, role):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = _link(name, me)
    ob.data.materials.append(mat(role))
    return ob


def place(ob, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """loc/scale in Godot axes; rot = Godot euler (x, y, z) radians applied Y*X*Z like Godot's YXZ."""
    ob.location = G(loc)
    # Godot euler YXZ: R = Ry * Rx * Rz. Godot axes -> Blender: X->X, Y->Z, Z->-Y.
    rx = Matrix.Rotation(rot[0], 4, 'X')
    ry = Matrix.Rotation(rot[1], 4, 'Z')
    rz = Matrix.Rotation(-rot[2], 4, 'Y')
    r = ry @ rx @ rz
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = r.to_quaternion()
    ob.scale = (scale[0], scale[2], scale[1])
    return ob


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), role="stone", bevel=0.0, segs=2, name="box"):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[2], v.co.z * size[1]))
    ob = place(from_bm(bm, name, role), loc, rot)
    if bevel > 0:
        add_bevel(ob, bevel, segs)
    return ob


def cyl(r_bottom, r_top, h, segs=16, loc=(0, 0, 0), rot=(0, 0, 0), role="stone", bevel=0.0, bsegs=2, caps=True, name="cyl"):
    """Upright cylinder/cone in Godot space, base at loc.y (origin at its base)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=segs, radius1=r_bottom, radius2=max(r_top, 0.0), depth=h)
    for v in bm.verts:
        v.co.z += h * 0.5
    ob = place(from_bm(bm, name, role), loc, rot)
    if bevel > 0:
        add_bevel(ob, bevel, bsegs)
    return ob


def sphere(radius, loc=(0, 0, 0), scale=(1, 1, 1), role="stone", segs=16, rings=8, rot=(0, 0, 0), name="sphere"):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    return place(from_bm(bm, name, role), loc, rot, scale)


def ico(radius, subdiv=2, loc=(0, 0, 0), scale=(1, 1, 1), role="rock", rot=(0, 0, 0), name="ico"):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    return place(from_bm(bm, name, role), loc, rot, scale)


def torus(major, minor, loc=(0, 0, 0), rot=(0, 0, 0), role="iron", seg=12, mseg=6, scale=(1, 1, 1), name="torus"):
    """Ring in the Godot XZ plane (axis = Godot Y) before rotation."""
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = math.tau * i / seg
        ring = []
        for j in range(mseg):
            b = math.tau * j / mseg
            r = major + minor * math.cos(b)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b))))
        verts.append(ring)
    for i in range(seg):
        for j in range(mseg):
            a = verts[i][j]; b = verts[(i + 1) % seg][j]; c = verts[(i + 1) % seg][(j + 1) % mseg]; d = verts[i][(j + 1) % mseg]
            bm.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return place(from_bm(bm, name, role), loc, rot, scale)


def tube(points, radii, segs=8, role="iron", caps=True, name="tube"):
    """A swept tube along Godot-space points with per-point radius (bones, branches, bars)."""
    pts = [G(p) for p in points]
    bm = bmesh.new()
    rings = []
    prev_n = None
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - pts[0])
        elif i == len(pts) - 1:
            t = (pts[-1] - pts[-2])
        else:
            t = (pts[i + 1] - pts[i - 1])
        t.normalize()
        if prev_n is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            n = t.cross(ref).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n)
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        ring = []
        for k in range(segs):
            a = math.tau * k / segs
            ring.append(bm.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * r))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bm(bm, name, role)


def prism_profile(profile, depth, role="stone", name="prism", loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, bsegs=2):
    """Extrude a 2D profile [(x, y), ...] (Godot XY plane) along Godot Z, centred on z = 0."""
    bm = bmesh.new()
    front = [bm.verts.new(G(x, y, depth * 0.5)) for x, y in profile]
    back = [bm.verts.new(G(x, y, -depth * 0.5)) for x, y in profile]
    n = len(profile)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = place(from_bm(bm, name, role), loc, rot)
    if bevel > 0:
        add_bevel(ob, bevel, bsegs)
    return ob


def lathe(profile, segs=24, role="stone", loc=(0, 0, 0), rot=(0, 0, 0), name="lathe", phase=0.0):
    """Revolve [(radius, y), ...] (bottom to top) around Godot Y. r=0 points close the ends."""
    bm = bmesh.new()
    rings = []
    for r, y in profile:
        if r <= 1e-5:
            rings.append([bm.verts.new((0, 0, y))])
            continue
        ring = []
        for k in range(segs):
            a = math.tau * k / segs + phase
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), y)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        if len(A) == 1 and len(B) == 1:
            continue
        if len(A) == 1:
            for k in range(segs):
                bm.faces.new((A[0], B[k], B[(k + 1) % segs]))
        elif len(B) == 1:
            for k in range(segs):
                bm.faces.new((A[k], B[0], A[(k + 1) % segs]))
        else:
            for k in range(segs):
                bm.faces.new((A[k], A[(k + 1) % segs], B[(k + 1) % segs], B[k]))
    if len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    if len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return place(from_bm(bm, name, role), loc, rot)


# --- Modifiers ------------------------------------------------------------------------

def add_bevel(ob, width, segs=2, angle=40.0):
    md = ob.modifiers.new("bevel", 'BEVEL')
    md.width = width
    md.segments = segs
    md.limit_method = 'ANGLE'
    md.angle_limit = math.radians(angle)
    md.harden_normals = False
    return md


def apply(ob):
    """Bake every modifier (and the object transform) into the mesh data."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return ob


def bake_transform(ob):
    apply(ob)
    ob.data.transform(ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)
    return ob


def join(objs, name="asset"):
    objs = [o for o in objs if o is not None]
    for o in objs:
        bake_transform(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def boolean(target, cutter, op='DIFFERENCE', transfer=True):
    md = target.modifiers.new("bool", 'BOOLEAN')
    md.operation = op
    md.object = cutter
    md.solver = 'EXACT'
    md.use_self = True
    md.use_hole_tolerant = True
    try:
        md.material_mode = 'TRANSFER' if transfer else 'INDEX'
    except Exception:
        pass
    apply(target)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return target


def organic(objs, voxel=0.01, smooth=4, smooth_factor=0.6, ratio=1.0, name="organic", role=None, adaptivity=0.0):
    """Union of primitives -> voxel remesh -> smooth -> optional decimate. Single material."""
    ob = join(objs, name)
    md = ob.modifiers.new("remesh", 'REMESH')
    md.mode = 'VOXEL'
    md.voxel_size = voxel
    md.adaptivity = adaptivity
    md.use_smooth_shade = True
    if smooth > 0:
        sm = ob.modifiers.new("smooth", 'SMOOTH')
        sm.iterations = smooth
        sm.factor = smooth_factor
    if ratio < 1.0:
        dc = ob.modifiers.new("decimate", 'DECIMATE')
        dc.ratio = ratio
    apply(ob)
    if role is not None:
        ob.data.materials.clear()
        ob.data.materials.append(mat(role))
    return ob


def displace(ob, strength, size, kind='CLOUDS', depth=2, coords='LOCAL', subdiv=0, seed_offset=(0, 0, 0)):
    if subdiv > 0:
        s = ob.modifiers.new("sub", 'SUBSURF')
        s.levels = subdiv
        s.render_levels = subdiv
        s.subdivision_type = 'SIMPLE'
    tex = bpy.data.textures.new("disp_" + ob.name, kind)
    if kind in ('CLOUDS',):
        tex.noise_scale = size
        tex.noise_depth = depth
    elif kind == 'VORONOI':
        tex.noise_scale = size
    elif kind == 'MUSGRAVE':
        tex.noise_scale = size
    md = ob.modifiers.new("disp", 'DISPLACE')
    md.texture = tex
    md.strength = strength
    md.mid_level = 0.5
    md.texture_coords = 'LOCAL' if coords == 'LOCAL' else 'GLOBAL'
    apply(ob)
    return ob


def decimate_to(ob, target):
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris > target:
        decimate(ob, target / tris)
    return ob


def decimate(ob, ratio):
    dc = ob.modifiers.new("decimate", 'DECIMATE')
    dc.ratio = ratio
    apply(ob)
    return ob


def jitter(ob, amount, seed=0, scale=3.0):
    """Noise-push vertices (weathering) in Godot units."""
    for v in ob.data.vertices:
        p = v.co * scale + Vector((seed * 7.1, seed * 3.3, seed * 1.7))
        v.co += noise.noise_vector(p) * amount
    return ob


def shade(ob, smooth=True, angle=35.0):
    for p in ob.data.polygons:
        p.use_smooth = smooth
    if smooth:
        try:
            md = ob.modifiers.new("autosmooth", 'NODES')
            ob.modifiers.remove(md)
        except Exception:
            pass
        try:
            ob.data.set_sharp_from_angle(angle=math.radians(angle))
        except Exception:
            pass
    return ob


def set_role(ob, role):
    ob.data.materials.clear()
    ob.data.materials.append(mat(role))
    for p in ob.data.polygons:
        p.material_index = 0
    return ob


def box_uv(ob, scale=1.0):
    """Box-project UVs in object space (1 unit = 1 m / scale)."""
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                u, v = co.y, co.z
            elif ax == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            uv[li].uv = (u * scale, v * scale)


def finish(ob, name, smooth=True, angle=35.0):
    bake_transform(ob)
    ob.data.validate()
    ob.name = name
    shade(ob, smooth, angle)
    box_uv(ob)
    return ob


def export(ob, rel_path):
    path = os.path.join(ROOT, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    kwargs = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                  export_yup=True, export_materials='EXPORT', export_normals=True,
                  export_texcoords=True, export_cameras=False, export_lights=False)
    try:
        bpy.ops.export_scene.gltf(**kwargs, export_vertex_color='NONE')
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("EXPORT %s  tris=%d  dims=%s" % (rel_path, tris, tuple(round(d, 2) for d in ob.dimensions)))
    return tris


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def contact_sheet(objs, out_png, cols=5, res=(1800, 1100)):
    """Workbench preview of finished assets, each normalised into a grid cell (shape check)."""
    scene = bpy.context.scene
    cell = 2.4
    for i, ob in enumerate(objs):
        d = max(ob.dimensions) or 1.0
        s = 2.0 / d
        ob.scale = (s, s, s)
        # centre the bounds
        bb = [Vector(c) for c in ob.bound_box]
        mn = Vector((min(b.x for b in bb), min(b.y for b in bb), min(b.z for b in bb)))
        mx = Vector((max(b.x for b in bb), max(b.y for b in bb), max(b.z for b in bb)))
        c = (mn + mx) * 0.5
        col, row = i % cols, i // cols
        ob.location = Vector((col * cell, 0, -row * cell)) - Vector((c.x * s, c.y * s, c.z * s))
    rows = (len(objs) + cols - 1) // cols
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = max(cols, rows * res[0] / res[1]) * cell * 1.02
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cx = (cols - 1) * cell * 0.5
    cz = -(rows - 1) * cell * 0.5
    # three-quarter view from the front (-Y in Blender = Godot +Z front), a little above
    direction = Vector((0.55, -1.0, 0.45)).normalized()
    cam.location = Vector((cx, 0, cz)) + direction * 60
    cam.rotation_euler = (-direction).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = cam
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.show_cavity = True
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    print("SHEET", out_png)

"""Bone Revenant build: Tripo GLB -> decimate -> cloth bone chains (whole thin shells only) ->
Sheath bone -> draw/sheathe clips -> export. Run inside Blender after exec(bb_process.py)."""
import bpy, bmesh, os
from mathutils import Vector

ROOT = r"D:\BLOODBOUND\.claude\worktrees\exciting-kapitsa-f1c50d"
TOP, BOT, N = 0.535, 0.30, 3
PANELS = {  # name: x range, side test on shell centre y, z top limit
    "ClothFrontL": ((0.00, 0.09), lambda y: y <= -0.04, TOP),
    "ClothFrontR": ((-0.11, -0.01), lambda y: y <= -0.04, TOP),
    "ClothBackL":  ((0.00, 0.13), lambda y: y >= 0.04, 0.52),
    "ClothBackR":  ((-0.12, -0.01), lambda y: y >= 0.045, 0.52),
}


def shells(mesh):
    bm = bmesh.new(); bm.from_mesh(mesh.data); bm.verts.ensure_lookup_table()
    mw = mesh.matrix_world; seen = set(); out = []
    for v in bm.verts:
        if v.index in seen: continue
        st = [v]; ids = []; seen.add(v.index)
        while st:
            a = st.pop(); ids.append(a.index)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b.index not in seen: seen.add(b.index); st.append(b)
        pts = [mw @ bm.verts[i].co for i in ids]
        mn = Vector([min(p[k] for p in pts) for k in range(3)]); mx = Vector([max(p[k] for p in pts) for k in range(3)])
        out.append((ids, mn, mx, sum(pts, Vector()) / len(pts)))
    bm.free()
    return out


def panel_shells(mesh):
    """Thin hanging sheets (cloth), assigned whole to one panel; armour and limbs are never split."""
    picked = {k: [] for k in PANELS}
    for ids, mn, mx, c in shells(mesh):
        depth = mx.y - mn.y; height = mx.z - mn.z; width = mx.x - mn.x
        if depth > 0.035 or width > 0.11 or height < 0.03: continue        # not a thin sheet
        if mn.z < BOT - 0.04 or mx.z > TOP + 0.03: continue                # outside belt..knee band
        for name, ((x0, x1), side, top) in PANELS.items():
            if x0 <= c.x <= x1 and side(c.y) and mx.z <= top + 0.03:
                picked[name] += ids; break
    return picked


def add_cloth(arm, mesh):
    mw = mesh.matrix_world
    regions = panel_shells(mesh)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.scene.objects: o.select_set(o == arm)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    for name, idx in regions.items():
        if not idx: continue
        pts = [mw @ mesh.data.vertices[i].co for i in idx]
        cx = sum(p.x for p in pts) / len(pts); cy = sum(p.y for p in pts) / len(pts)
        prev = eb["mixamorig:Hips"]
        for k in range(N):
            b = eb.new(f"{name}{k}")
            b.head = Vector((cx, cy, TOP - (TOP - BOT) * k / N)); b.tail = Vector((cx, cy, TOP - (TOP - BOT) * (k + 1) / N))
            b.parent = prev; b.use_connect = k > 0; prev = b
    s = eb.new("Sheath"); s.head = Vector((-0.07, 0.09, 0.80)); s.tail = s.head + Vector((0.45, 0.0, -0.89)).normalized() * 0.08
    s.parent = eb["mixamorig:Spine2"]; s.use_deform = False
    bpy.ops.object.mode_set(mode='OBJECT')
    vg = mesh.vertex_groups
    hipg = vg.get("mixamorig:Hips") or vg.new(name="mixamorig:Hips")
    for name, idx in regions.items():
        for k in range(N):
            vg.get(f"{name}{k}") or vg.new(name=f"{name}{k}")
        for i in idx:
            z = (mw @ mesh.data.vertices[i].co).z
            t = max(0.0, min(1.0, (TOP - z) / (TOP - BOT)))
            free = min(1.0, t / 0.25)
            f = t * N - 0.5; k0 = max(0, min(N - 1, int(f))); k1 = min(N - 1, k0 + 1); a = max(0.0, min(1.0, f - k0))
            for g in list(mesh.data.vertices[i].groups): vg[g.group].remove([i])
            hipg.add([i], 1.0 - free, 'REPLACE')
            vg[f"{name}{k0}"].add([i], free * (1 - a), 'ADD')
            if k1 != k0: vg[f"{name}{k1}"].add([i], free * a, 'ADD')
    return {k: len(v) for k, v in regions.items()}


def add_draw_clips(arm):
    sc = bpy.context.scene
    for pb in arm.pose.bones: pb.matrix_basis.identity()
    arm.animation_data.action = bpy.data.actions["idle"]; sc.frame_set(0)
    idle_pose = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones}
    arm.animation_data.action = None
    tgt = bpy.data.objects.get("BB_GripTarget") or bpy.data.objects.new("BB_GripTarget", None)
    pole = bpy.data.objects.get("BB_ElbowPole") or bpy.data.objects.new("BB_ElbowPole", None)
    for o in (tgt, pole):
        if o.name not in sc.objects: sc.collection.objects.link(o)
    tgt.location = Vector((-0.06, 0.10, 0.86)); pole.location = Vector((-0.30, 0.05, 1.05))
    fore = arm.pose.bones["mixamorig:RightForeArm"]
    for c in list(fore.constraints): fore.constraints.remove(c)
    ik = fore.constraints.new('IK'); ik.target = tgt; ik.pole_target = pole; ik.chain_count = 2
    for n, m in idle_pose.items(): arm.pose.bones[n].matrix_basis = m
    bpy.context.view_layer.update()
    reach = {n: arm.convert_space(pose_bone=arm.pose.bones[n], matrix=arm.pose.bones[n].matrix, from_space='POSE', to_space='LOCAL')
             for n in ("mixamorig:RightArm", "mixamorig:RightForeArm")}
    fore.constraints.remove(ik)
    for name, keys in (("draw", [(0, {}), (4, reach), (8, {})]), ("sheathe", [(0, {}), (5, reach), (10, {})])):
        a = bpy.data.actions.get(name)
        if a: bpy.data.actions.remove(a)
        a = bpy.data.actions.new(name); a.use_fake_user = True
        arm.animation_data.action = a
        for frame, pose in keys:
            for n, m in idle_pose.items():
                pb = arm.pose.bones[n]; pb.matrix_basis = pose.get(n, m); pb.rotation_mode = 'QUATERNION'
                pb.keyframe_insert("rotation_quaternion", frame=frame); pb.keyframe_insert("location", frame=frame)
        arm.animation_data.action = None
    for pb in arm.pose.bones: pb.matrix_basis.identity()


def build_hero():
    process("tripo_revenant_anim.glb", r"player\bone_revenant.glb", ratio=0.9, tex=2048)
    sc = bpy.context.scene
    arm = next(o for o in sc.objects if o.type == 'ARMATURE'); mesh = next(o for o in sc.objects if o.type == 'MESH')
    arm.name = "RevenantRig"; mesh.name = "RevenantBody"
    arm.animation_data.action = None
    counts = add_cloth(arm, mesh)
    add_draw_clips(arm)
    for o in sc.objects: o.select_set(o in (arm, mesh))
    bpy.context.view_layer.objects.active = arm
    out = os.path.join(ROOT, r"assets\models\player\bone_revenant.glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, use_active_scene=True, export_yup=True,
        export_animations=True, export_skins=True, export_animation_mode='ACTIONS', export_image_format='JPEG', export_jpeg_quality=85)
    os.makedirs(os.path.join(ROOT, r"assets\source\player"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, r"assets\source\player\bone_revenant.blend"), copy=True)
    print("cloth verts per panel", counts, "clips", sorted(a.name for a in bpy.data.actions), os.path.getsize(out) // 1024, "KB")

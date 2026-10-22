import bpy, os, shutil
from mathutils import Vector

INCOMING = r"D:\BLOODBOUND\.claude\worktrees\exciting-kapitsa-f1c50d\assets\incoming\tripo"
MODELS = r"D:\BLOODBOUND\.claude\worktrees\exciting-kapitsa-f1c50d\assets\models"


def process(download_name, out_rel, ratio=0.5, tex=1024):
    """Tripo GLB (Downloads) -> incoming copy -> decimated, textures capped, rig/clips kept -> models/."""
    src = os.path.join(os.path.expanduser("~"), "Downloads", download_name)
    dst = os.path.join(INCOMING, download_name)
    shutil.copy(src, dst)
    sc = bpy.data.scenes.get("BB_proc") or bpy.data.scenes.new("BB_proc")
    bpy.context.window.scene = sc
    for o in list(sc.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):  # stale clips would make imported names collide (idle.001)
        bpy.data.actions.remove(a)
    before_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=dst)
    objs = list(sc.objects)
    for a in list(bpy.data.actions):  # gameplay-facing clip names: "defeat_02" -> "defeat"
        base = a.name.split(".")[0].split(":")[-1]
        for canon in ("defeat", "idle", "walk", "run", "slash", "jump", "fall", "dive", "chop", "shoot"):
            if base.startswith(canon + "_") and not any(b.name == canon for b in bpy.data.actions):
                base = canon
        a.name = base
    meshes = [o for o in objs if o.type == 'MESH']
    for m in meshes:
        if ratio < 0.999:
            d = m.modifiers.new("dec", "DECIMATE"); d.ratio = ratio
            bpy.context.view_layer.objects.active = m
            for o in objs: o.select_set(o == m)
            while m.modifiers[0].name != "dec":
                bpy.ops.object.modifier_move_up(modifier="dec")
            bpy.ops.object.modifier_apply(modifier="dec")
        for s in m.material_slots:
            if s.material and s.material.use_nodes:
                for n in s.material.node_tree.nodes:
                    if n.type == 'TEX_IMAGE' and n.image and n.image.size[0] > tex:
                        n.image.scale(tex, tex)
    for o in objs: o.select_set(True)
    out = os.path.join(MODELS, out_rel)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, use_active_scene=True,
        export_yup=True, export_animations=True, export_skins=True, export_animation_mode='ACTIONS',
        export_image_format='JPEG', export_jpeg_quality=85)
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    new_actions = [a.name for a in bpy.data.actions if a not in before_actions]
    print(out_rel, os.path.getsize(out) // 1024, "KB tris", sum(len(f.vertices) - 2 for m in meshes for f in m.data.polygons),
          "actions", new_actions, "bounds", [round(min(p[i] for p in pts), 2) for i in range(3)], [round(max(p[i] for p in pts), 2) for i in range(3)])

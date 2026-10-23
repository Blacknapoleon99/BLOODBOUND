"""Renders a contact sheet of the gothic kit GLB (workbench, headless) for a quick shape check.
    blender.exe -b --factory-startup --python tools/blender/preview_gothic_kit.py -- <kit.glb> <out.png>
"""
import bpy
import math
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
glb, out = argv[0], argv[1]
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=glb)
objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
objs.sort(key=lambda o: o.name)
x = 0.0
row_y = 0.0
col = 0
for o in objs:
    dims = o.dimensions
    o.location = Vector((x + dims.x * 0.5, row_y, 0.0))
    o.location.z -= min((o.matrix_world @ Vector(c)).z for c in o.bound_box) - o.location.z
    x += dims.x + 0.8
    col += 1
    if x > 14.0:
        x = 0.0
        row_y -= 6.0
        col = 0
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'VERTEX'
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = 'BOTH'
scene.display.shading.show_shadows = True
scene.render.resolution_x = 1800
scene.render.resolution_y = 1100
cam_data = bpy.data.cameras.new("cam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 19.0
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = Vector((7.5, row_y * 0.5 - 18.0, 14.0))
cam.rotation_euler = (math.radians(58), 0.0, math.radians(0))
scene.camera = cam
scene.render.filepath = out
bpy.ops.render.render(write_still=True)

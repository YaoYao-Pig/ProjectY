"""给新增城堡建立独立预览，不改旧资源的展示布局。"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

root = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
scene = bpy.data.scenes["MapLP_CastleStudio"]
assert bpy.context.scene == scene
assert "MapLP_CastleDisplay" not in bpy.data.collections
display = bpy.data.collections.new("MapLP_CastleDisplay")
rig = bpy.data.collections.new("MapLP_CastleRig")
scene.collection.children.link(display)
scene.collection.children.link(rig)
for name in ("Building_Castle", "CityPlot7"):
    obj = bpy.data.objects[name].copy()
    obj.name = "CastleDisplay_" + name
    display.objects.link(obj)
    if name == "CityPlot7":
        obj.scale.z = 0.22
for name in ("PreviewFloor", "Preview_Key", "Preview_Fill"):
    obj = bpy.data.objects[name].copy()
    obj.name = "Castle_" + name
    rig.objects.link(obj)
    if name == "PreviewFloor":
        obj.location.z = 0.07
scene.world = bpy.data.worlds["MapLP_PreviewWorld"]
data = bpy.data.cameras.new("Castle_PreviewCamera")
camera = bpy.data.objects.new("Castle_PreviewCamera", data)
rig.objects.link(camera)
camera.location = (7, -10, 8.5)
camera.rotation_euler = (Vector((0, 0, 1.25))-camera.location).to_track_quat("-Z", "Y").to_euler()
data.type = "ORTHO"
data.ortho_scale = 7.1
scene.camera = camera
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1200
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(root / "Previews/Castle_Blender.png")
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
masters = bpy.data.collections["MapLP_CastleMasters"]
masters.hide_render = True
masters.hide_viewport = True

# 顶点逐个落在真实七格并集内，不把包围盒尺寸当作占地证明。
centers = [(0, 0), (math.sqrt(3), 0), (-math.sqrt(3), 0)]
centers += [(signx*math.sqrt(3)/2, signy*1.5) for signx in (-1, 1) for signy in (-1, 1)]
def in_hex(x, y, center):
    dx, dy = abs(x-center[0]), abs(y-center[1])
    return dx <= math.sqrt(3)/2+1e-6 and dy <= 1-dx/math.sqrt(3)+1e-6
castle = bpy.data.objects["Building_Castle"]
assert all(any(in_hex(v.co.x, v.co.y, c) for c in centers) for v in castle.data.vertices)
for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        area.spaces.active.region_3d.view_perspective = "CAMERA"
bpy.context.view_layer.update()
print(json.dumps({"preview": scene.render.filepath, "footprint_radius": 1,
                  "all_vertices_inside_seven_hex_union": True}))

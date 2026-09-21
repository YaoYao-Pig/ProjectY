import bpy
import json
import math
from mathutils import Vector
from pathlib import Path

root = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
(root / "Previews").mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes["MapLP_Studio"]
assert bpy.context.scene == scene
assert "MapLP_Display" not in bpy.data.collections
display = bpy.data.collections.new("MapLP_Display")
rig = bpy.data.collections.new("MapLP_PreviewRig")
scene.collection.children.link(display)
scene.collection.children.link(rig)


def duplicate(master, location, scale=(1, 1, 1)):
    obj = bpy.data.objects[master].copy()
    obj.name = "Display_" + master
    display.objects.link(obj)
    obj.location = location
    obj.scale = scale
    return obj


# 展示对象引用源网格；源对象留在原点，避免把展示排版写进 FBX。
for master, x in [("Building_House", -4.6), ("Building_Workshop", -2.25), ("Building_TownHall", 2.4)]:
    duplicate(master, (x, 0.7, 0))
for x in (-4.6, -2.25):
    duplicate("Hex_City", (x, 0.7, 0), (1, 1, 0.28))
duplicate("CityPlot7", (2.4, 0.7, 0), (1, 1, 0.28))
for i, master in enumerate(["Hex_Grass", "Hex_Rock", "Hex_Shore", "Hex_Riverbed", "Hex_City", "Hex_Water"]):
    x = -5.7 + i * 2.28
    duplicate(master, (x, -3.8, 0), (1, 1, 0.28 if master != "Hex_Water" else 1))
    if master == "Hex_Rock":
        duplicate("Mountain_Cluster", (x, -3.8, 0))
    if master == "Hex_Water":
        duplicate("Hex_Riverbed", (x, -3.8, -0.06), (1, 1, 0.22))

floor_mesh = bpy.data.meshes.new("PreviewFloor_Mesh")
floor_mesh.from_pydata([(-100, -100, -0.31), (100, -100, -0.31), (100, 100, -0.31), (-100, 100, -0.31)], [], [(0, 1, 2, 3)])
floor_obj = bpy.data.objects.new("PreviewFloor", floor_mesh)
rig.objects.link(floor_obj)
floor_mat = bpy.data.materials.new("M_PreviewFloor")
floor_mat.use_nodes = True
floor_mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.70, 0.67, 0.60, 1)
floor_mat.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 1
floor_mesh.materials.append(floor_mat)


def area_light(name, location, energy, size):
    light = bpy.data.lights.new(name, "AREA")
    light.energy = energy
    light.shape = "DISK"
    light.size = size
    obj = bpy.data.objects.new(name, light)
    rig.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0, 0, 0)) - obj.location).to_track_quat("-Z", "Y").to_euler()


area_light("Preview_Key", (-5, -7, 11), 1500, 7)
area_light("Preview_Fill", (6, 2, 9), 900, 8)
world = bpy.data.worlds.new("MapLP_PreviewWorld")
world.use_nodes = True
world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.68, 0.72, 0.78, 1)
world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.7
scene.world = world
camera_data = bpy.data.cameras.new("MapLP_PreviewCamera")
camera = bpy.data.objects.new("MapLP_PreviewCamera", camera_data)
rig.objects.link(camera)
camera.location = (8.5, -14.5, 14)
target = Vector((0.0, -0.9, 0.5))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 17.7
camera_data.lens = 45
scene.camera = camera
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1600
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.render.filepath = str(root / "Previews/MapLowPoly_Overview.png")
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
masters = bpy.data.collections["MapLP_AssetMasters"]
masters.hide_render = True
masters.hide_viewport = True

# 让 Blender 打开后直接看到可检查的预览布局，不改变原有 Scene 的视角。
for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        area.spaces.active.region_3d.view_perspective = "CAMERA"
        area.spaces.active.shading.type = "MATERIAL"
bpy.context.view_layer.update()
print(json.dumps({"preview": scene.render.filepath, "display_objects": len(display.objects),
                  "master_objects": len(masters.objects), "engine": scene.render.engine}))

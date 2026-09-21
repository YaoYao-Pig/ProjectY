"""导出新增六个模型，并保存独立源文件和同风格对照预览。"""
import bpy
import json
import runpy
from pathlib import Path
from mathutils import Vector

root = Path('D:/Program/Unity/Project Y/Art/MapLowPoly')
scene = bpy.data.scenes['MapLP_EcosystemStudio']
bpy.context.window.scene = scene
masters = bpy.data.collections['MapLP_EcosystemMasters']
export = runpy.run_path(str(root/'Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
report = json.loads((root/'Integration/ecosystem-models.json').read_text())
for item in report:
    item['export'] = export(item['name'], str(root/'Staging'/ (item['name']+'.fbx')))
    obj = bpy.data.objects[item['name']]
    item['bounds_blender'] = [list(Vector(axis)) for axis in obj.bound_box]
palette = {material.name: material['palette_srgb'] for item in report
           for material in bpy.data.objects[item['name']].data.materials}
(root/'Integration/ecosystem-models.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
(root/'Integration/ecosystem-palette.json').write_text(json.dumps(palette, indent=2), encoding='utf-8')

display = bpy.data.collections.new('MapLP_EcosystemDisplay')
scene.collection.children.link(display)
def copy(name, position, scale=1):
    obj = bpy.data.objects[name].copy()
    obj.name = 'EcosystemDisplay_'+name
    display.objects.link(obj)
    obj.location = position
    obj.scale = (scale,)*3
    return obj
copy('Hex_Forest', (-3.4, 0, 0)); copy('Tree_Broadleaf', (-3.4, 0, 0))
copy('Hex_Forest', (-1.7, .15, 0)); copy('Tree_Conifer', (-1.7, .15, 0))
copy('Hex_Snow', (0, .3, 0)); copy('Tree_SnowPine', (0, .3, 0))
copy('Hex_Rock', (1.7, .45, 0)); copy('Building_Dungeon', (1.7, .45, 0))
copy('Hex_Grass', (3.4, .6, 0)); copy('Building_House', (3.4, .6, 0))
masters.hide_render = True
masters.hide_viewport = True
source = bpy.data.scenes['MapLP_CastleStudio']
scene.world = source.world.copy()
for name in ['Castle_Preview_Key', 'Castle_Preview_Fill']:
    light = bpy.data.objects[name].copy(); light.data = light.data.copy()
    light.name = name.replace('Castle', 'Ecosystem'); display.objects.link(light)
camera_data = bpy.data.cameras.new('EcosystemCamera')
camera = bpy.data.objects.new('EcosystemCamera', camera_data)
scene.collection.objects.link(camera)
camera.location = (7, -12, 8)
camera.rotation_euler = (Vector((0, 0, .5))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type = 'ORTHO'; camera_data.ortho_scale = 11.5
scene.camera = camera
scene.render.engine = 'CYCLES'; scene.cycles.samples = 32
scene.render.resolution_x = 1440; scene.render.resolution_y = 800; scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(root/'Previews/ecosystem-kit.png')
scene.view_settings.view_transform = 'AgX'
bpy.data.libraries.write(str(root/'Source/Ecosystem.blend'), {scene}, path_remap='RELATIVE', fake_user=True, compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps({'models': len(report), 'source': str(root/'Source/Ecosystem.blend'), 'preview': scene.render.filepath}))

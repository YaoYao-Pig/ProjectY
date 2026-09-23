"""导出偏远地点模型，保存独立可编辑场景并渲染与普通民居的尺度对照。"""
import bpy
import json
import runpy
from pathlib import Path
from mathutils import Vector

root = Path('D:/Program/Unity/Project Y/Art/MapLowPoly')
scene = bpy.data.scenes['MapLP_RemoteSitesStudio']
bpy.context.window.scene = scene
masters = bpy.data.collections['MapLP_RemoteSitesMasters']
export = runpy.run_path(str(root/'Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
report = json.loads((root/'Integration/remote-sites-models.json').read_text())
for item in report:
    item['export'] = export(item['name'], str(root/'Staging'/(item['name']+'.fbx')))
    item['bounds_blender'] = [list(v) for v in bpy.data.objects[item['name']].bound_box]
(root/'Integration/remote-sites-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

display = bpy.data.collections.new('MapLP_RemoteSitesDisplay')
scene.collection.children.link(display)
def copy(name, position):
    obj=bpy.data.objects[name].copy()
    obj.name='RemoteDisplay_'+name
    display.objects.link(obj)
    obj.location=position
    return obj
for name,x in [('Building_DungeonEntrance',-2.8),('Building_SecludedCottage',0),('Building_House',2.8)]:
    copy('Hex_Grass',(x,0,0))
    copy(name,(x,0,0))
masters.hide_render=True
masters.hide_viewport=True
source=bpy.data.scenes['MapLP_EcosystemStudio']
scene.world=source.world.copy()
for obj in source.objects:
    if obj.type=='LIGHT':
        lamp=obj.copy();lamp.data=obj.data.copy();lamp.name='RemoteSites_'+obj.name
        display.objects.link(lamp)
camera_data=bpy.data.cameras.new('RemoteSitesCamera')
camera=bpy.data.objects.new('RemoteSitesCamera',camera_data)
scene.collection.objects.link(camera)
camera.location=(5,-11,7)
camera.rotation_euler=(Vector((0,0,.30))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO';camera_data.ortho_scale=9.6
scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1440;scene.render.resolution_y=760;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(root/'Previews/remote-sites-kit.png')
scene.view_settings.view_transform='AgX'
bpy.data.libraries.write(str(root/'Source/RemoteSites.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps({'source':str(root/'Source/RemoteSites.blend'),'preview':scene.render.filepath,'models':len(report)}))

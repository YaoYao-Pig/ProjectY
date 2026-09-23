"""地牢陈设批量导出、独立来源保存与同尺度概览；不会清空其他源场景。"""
import bpy
import json
import runpy
from pathlib import Path
from mathutils import Vector

root=Path('D:/Program/Unity/Project Y/Art/MapLowPoly')
scene=bpy.data.scenes['MapLP_DungeonStudio'];bpy.context.window.scene=scene
export=runpy.run_path(str(root/'Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
report=json.loads((root/'Integration/dungeon-interiors-models.json').read_text())
for item in report: item['export']=export(item['name'],str(root/'Staging'/(item['name']+'.fbx')))
(root/'Integration/dungeon-interiors-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
display=bpy.data.collections.new('MapLP_DungeonDisplay');scene.collection.children.link(display)
for i,item in enumerate(report):
    obj=bpy.data.objects[item['name']].copy();obj.name='DungeonDisplay_'+item['name'];display.objects.link(obj)
    obj.location=((i%4-1.5)*4.5,(i//4-.5)*5,0)
masters=bpy.data.collections['MapLP_DungeonMasters'];masters.hide_viewport=True;masters.hide_render=True
scene.world=bpy.data.scenes['MapLP_RemoteSitesStudio'].world.copy()
for name,location,energy,size in [('Dungeon_Key',(-7,-8,12),1800,9),('Dungeon_Fill',(8,3,9),900,8)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);display.objects.link(obj);obj.location=location
    obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Dungeon_KitCamera');camera=bpy.data.objects.new('Dungeon_KitCamera',data)
scene.collection.objects.link(camera);camera.location=(7,-17,15)
camera.rotation_euler=(Vector((0,0,.7))-camera.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=20
scene.camera=camera;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1600;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(root/'Previews/dungeon-interiors-kit.png')
scene.view_settings.view_transform='AgX'
bpy.data.libraries.write(str(root/'Source/DungeonInteriors.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps(dict(source=str(root/'Source/DungeonInteriors.blend'),preview=scene.render.filepath,models=len(report))))

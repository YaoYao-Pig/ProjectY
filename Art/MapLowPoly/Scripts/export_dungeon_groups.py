"""多格设施导出与展示；只处理本套新建物件，输出独立 Blender 来源。"""
import bpy
import json
import runpy
from pathlib import Path
from mathutils import Vector

root=Path('D:/Program/Unity/Project Y/Art/MapLowPoly')
scene=bpy.data.scenes['MapLP_DungeonGroupsStudio'];bpy.context.window.scene=scene
export=runpy.run_path(str(root/'Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
report=json.loads((root/'Integration/dungeon-groups-models.json').read_text())
for item in report:
    obj=bpy.data.objects[item['name']]
    bpy.context.view_layer.update()
    item['dimensions_blender_xyz']=list(obj.dimensions)
    item['export']=export(item['name'],str(root/'Staging'/(item['name']+'.fbx')))
(root/'Integration/dungeon-groups-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
display=bpy.data.collections.new('MapLP_DungeonGroupsDisplay');scene.collection.children.link(display)
for i,item in enumerate(report):
    obj=bpy.data.objects[item['name']].copy();obj.name='DungeonGroupsDisplay_'+item['name'];display.objects.link(obj)
    obj.location=((i%4-1.5)*9,(i//4-.5)*9,0)
masters=bpy.data.collections['MapLP_DungeonGroupsMasters'];masters.hide_viewport=True;masters.hide_render=True
scene.world=bpy.data.scenes['MapLP_DungeonStudio'].world.copy()
for name,location,energy,size in [('Groups_Key',(-10,-14,20),3200,14),('Groups_Fill',(12,5,14),2200,12)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);display.objects.link(obj);obj.location=location
    obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Dungeon_GroupsCamera');camera=bpy.data.objects.new('Dungeon_GroupsCamera',data)
scene.collection.objects.link(camera);camera.location=(8,-28,23)
camera.rotation_euler=(Vector((0,0,.7))-camera.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=40
scene.camera=camera;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=1800;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(root/'Previews/dungeon-groups-kit.png')
scene.view_settings.view_transform='AgX'
bpy.data.libraries.write(str(root/'Source/DungeonGroups.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps(dict(source=str(root/'Source/DungeonGroups.blend'),preview=scene.render.filepath,models=len(report))))

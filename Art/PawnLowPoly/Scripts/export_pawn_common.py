"""导出公共棋子部件并检查三种共有装配；保留装备局部挂点原点。"""
import bpy
import json
import runpy
from pathlib import Path
from mathutils import Vector

root=Path('D:/Program/Unity/Project Y/Art/PawnLowPoly')
for name in ['Source','Staging','Previews']: (root/name).mkdir(exist_ok=True)
scene=bpy.data.scenes['PawnLP_Studio'];bpy.context.window.scene=scene
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
report=json.loads((root/'Integration/pawn-models.json').read_text())
for item in report:item['export']=export(item['name'],str(root/'Staging'/(item['name']+'.fbx')))
(root/'Integration/pawn-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
display=bpy.data.collections.new('PawnLP_Display');scene.collection.children.link(display)
sockets={'body':(0,0,0),'base':(0,0,0),'mainHand':(.50,-.28,.98),'offHand':(-.50,-.28,.98),'head':(0,0,1.59),'chest':(0,0,1.05),'back':(0,.20,1.13)}
loadouts=[['Human','Base','ArmorPlate','Helmet','Sword','Shield','Cape'],['Human','Base','ArmorLeather','Hood','Bow','Quiver'],['Human','Base','ArmorRobe','MageHat','Staff','Cape']]
for i,names in enumerate(loadouts):
    for name in names:
        source=bpy.data.objects['Pawn_'+name];obj=source.copy();obj.name='PawnDisplay_'+str(i)+'_'+name;display.objects.link(obj)
        x,y,z=sockets[source['attachment_slot']];obj.location=((i-1)*2.6+x,y,z)
masters=bpy.data.collections['PawnLP_Masters'];masters.hide_render=True;masters.hide_viewport=True
scene.world=bpy.data.scenes['MapLP_DungeonGroupsStudio'].world.copy()
for name,location,energy,size in [('Pawn_Key',(-4,-6,8),550,5),('Pawn_Fill',(5,2,6),350,4)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);display.objects.link(obj);obj.location=location
    obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Pawn_Camera');camera=bpy.data.objects.new('Pawn_Camera',data);display.objects.link(camera)
camera.location=(3,-10,6);camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO';data.ortho_scale=8.6;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.view_settings.view_transform='AgX'
scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(root/'Previews/pawn-common-kit.png')
bpy.data.libraries.write(str(root/'Source/PawnCommon.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps(dict(models=len(report),source=str(root/'Source/PawnCommon.blend'),preview=scene.render.filepath)))

"""独立摆台展示六种轮廓，不移动导出主网格。"""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
root=Path('D:/Program/Unity/Project Y/Art/TownExpansionLowPoly')
scene=bpy.data.scenes.get('TownExpansion_Preview') or bpy.data.scenes.new('TownExpansion_Preview')
bpy.context.window.scene=scene
for obj in list(scene.objects):
    assert obj.name.startswith('TownExPreview_'),'展示场景包含其他作品，停止重建'
    bpy.data.objects.remove(obj,do_unlink=True)
kit=json.loads((root/'Integration/kit-design.json').read_text(encoding='utf-8'))
for i,item in enumerate(kit):
    x=(i%3-1)*20;y=(i//3)*18
    for name in [item['shell'],item['cover']]:
        obj=bpy.data.objects.new('TownExPreview_'+name,bpy.data.objects[name].data);scene.collection.objects.link(obj);obj.location=(x,y,0)
camera_data=bpy.data.cameras.new('TownExPreview_Camera');camera=bpy.data.objects.new('TownExPreview_Camera',camera_data);scene.collection.objects.link(camera)
camera.location=(37,-64,53);camera.rotation_euler=(Vector((0,9,3))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=78;scene.camera=camera
sun_data=bpy.data.lights.new('TownExPreview_Sun','SUN');sun=bpy.data.objects.new('TownExPreview_Sun',sun_data);scene.collection.objects.link(sun)
sun.rotation_euler=(.55,-.4,-.6);sun_data.energy=2.1;sun_data.angle=.12
world=bpy.data.worlds.new('TownExPreview_World');world.use_nodes=True;scene.world=world
node=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');node.inputs['Color'].default_value=(.22,.28,.35,1);node.inputs['Strength'].default_value=.65
try:scene.render.engine='CYCLES'
except TypeError:raise RuntimeError('展示渲染需要 Cycles')
scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
formats=[i.identifier for i in scene.render.image_settings.bl_rna.properties['file_format'].enum_items];assert 'PNG' in formats
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(root/'Previews/six-buildings.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.color_type='MATERIAL'
bpy.ops.render.render(write_still=True)
print(scene.render.filepath)

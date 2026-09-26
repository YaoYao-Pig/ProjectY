import bpy,json,runpy
from pathlib import Path
from mathutils import Vector
root=Path('D:/Program/Unity/Project Y/Art/EquipmentDemo')
scene=bpy.data.scenes['EquipmentMelee_Source'];bpy.context.window.scene=scene
def allowed(owner,prop,value):
    assert value in [e.identifier for e in owner.bl_rna.properties[prop].enum_items];setattr(owner,prop,value)
props=bpy.ops.export_scene.fbx.get_rna_type().properties
for key,value in {'apply_scale_options':'FBX_SCALE_UNITS','axis_forward':'-Z','axis_up':'Y','mesh_smooth_type':'OFF','path_mode':'RELATIVE'}.items():
    assert value in [e.identifier for e in props[key].enum_items]
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
report=json.loads((root/'Integration/melee-models.json').read_text())
for row in report:row['export']=export(row['name'],str(root/'Staging'/(row['name']+'.fbx')))
(root/'Integration/melee-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assert 'EquipmentMelee_Preview' not in bpy.data.scenes
preview=bpy.data.scenes.new('EquipmentMelee_Preview');bpy.context.window.scene=preview
display=bpy.data.collections.new('EquipmentMelee_Display');preview.collection.children.link(display)
for i,row in enumerate(report):
    o=bpy.data.objects[row['name']].copy();display.objects.link(o);o.name='MeleeDisplay_'+row['name'];o.location=(-2.65+i*.95,0,.5)
    if i==6:o.location=(2.15,.09,1.0)
preview.render.engine=scene.render.engine
world=bpy.data.worlds.new('EquipmentMelee_World');world.use_nodes=True
background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');background.inputs['Color'].default_value=(.08,.105,.12,1);background.inputs['Strength'].default_value=.65;preview.world=world
assert 'AREA' in [x.identifier for x in bpy.types.Light.bl_rna.properties['type'].enum_items]
for name,pos,power in [('Key',(-3,-5,7),1000),('Fill',(4,0,5),750)]:
    d=bpy.data.lights.new('Melee_'+name,'AREA');d.energy=power;d.size=5;o=bpy.data.objects.new('Melee_'+name,d);display.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Melee_Camera');camera=bpy.data.objects.new('Melee_Camera',d);display.objects.link(camera)
camera.location=(3,-10,4);camera.rotation_euler=(Vector((-.2,0,1.25))-camera.location).to_track_quat('-Z','Y').to_euler();allowed(d,'type','ORTHO');d.ortho_scale=6.8;preview.camera=camera
preview.render.resolution_x=1800;preview.render.resolution_y=1000;preview.render.resolution_percentage=100
allowed(preview.render.image_settings,'file_format','PNG');preview.render.filepath=str(root/'Previews/melee-kit.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        r=area.spaces.active.region_3d;r.view_distance=7;r.view_location=Vector((0,0,1.25));r.view_rotation=camera.rotation_euler.to_quaternion();allowed(r,'view_perspective','ORTHO');allowed(area.spaces.active.shading,'color_type','MATERIAL')
bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(root/'Source/EquipmentMeleePreview.blend'),{preview},path_remap='RELATIVE',fake_user=True,compress=True)
print(json.dumps({'models':len(report),'preview':preview.render.filepath}))

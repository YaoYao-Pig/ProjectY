import bpy,json,math,runpy
from pathlib import Path
from mathutils import Vector
root=Path('D:/Program/Unity/Project Y/Art/EquipmentDemo')
scene=bpy.data.scenes['EquipmentDemo_Source'];bpy.context.window.scene=scene
def allowed(owner,prop,value):
    choices=[entry.identifier for entry in owner.bl_rna.properties[prop].enum_items]
    assert value in choices,(prop,value,choices);setattr(owner,prop,value)
# Check the project's existing FBX preset against this Blender version before using it.
props=bpy.ops.export_scene.fbx.get_rna_type().properties
for key,value in {'apply_scale_options':'FBX_SCALE_UNITS','axis_forward':'-Z','axis_up':'Y','mesh_smooth_type':'OFF','path_mode':'RELATIVE'}.items():
    assert value in [item.identifier for item in props[key].enum_items]
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
report=json.loads((root/'Integration/models.json').read_text())
for row in report:
    obj=bpy.data.objects[row['name']];row['dimensions_blender_xyz']=list(obj.dimensions)
    row['export']=export(row['name'],str(root/'Staging'/(row['name']+'.fbx')))
(root/'Integration/models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(root/'Source/EquipmentDemo.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
assert 'EquipmentDemo_Preview' not in bpy.data.scenes
preview=bpy.data.scenes.new('EquipmentDemo_Preview');bpy.context.window.scene=preview
display=bpy.data.collections.new('EquipmentDemo_Display');preview.collection.children.link(display)
def show(name,location,rotation=0):
    obj=bpy.data.objects['Equip_'+name].copy();obj.name='EquipmentDisplay_'+name;display.objects.link(obj)
    obj.location=location;obj.rotation_euler.z=rotation;return obj
show('Staff',(-2.05,0,.80));show('Staff',(-1.10,0,.80))
show('RuneScatter',(-1.10,0,1.85));show('RunePrecision',(-1.10,0,1.23))
show('Rifle',(.35,0,1.06),math.pi/2);show('Magazine',(.57,0,1.10),math.pi/2)
show('Chest',(.15,.60,0));show('Ammunition',(1.20,-.25,0));show('Magazine',(1.75,-.25,.28))
show('RuneScatter',(-.20,-.55,.10));show('RunePrecision',(.50,-.55,.20))
preview.render.engine=scene.render.engine
world=bpy.data.worlds.new('EquipmentDemo_World');world.use_nodes=True
background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');background.inputs['Color'].default_value=(.08,.105,.12,1);background.inputs['Strength'].default_value=.65
preview.world=world
light_types=[x.identifier for x in bpy.types.Light.bl_rna.properties['type'].enum_items];assert 'AREA' in light_types
for name,position,power,size in [('Key',(-4,-5,7),800,5),('Fill',(5,0,5),600,4)]:
    data=bpy.data.lights.new('Equipment_'+name,'AREA');data.energy=power;data.size=size
    obj=bpy.data.objects.new('Equipment_'+name,data);display.objects.link(obj);obj.location=position
    obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Equipment_Camera');camera=bpy.data.objects.new('Equipment_Camera',data);display.objects.link(camera)
camera.location=(3.8,-7.5,4.2);camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler()
allowed(data,'type','ORTHO');data.ortho_scale=5.4;preview.camera=camera
preview.render.resolution_x=1600;preview.render.resolution_y=1000;preview.render.resolution_percentage=100
allowed(preview.render.image_settings,'file_format','PNG');preview.render.filepath=str(root/'Previews/equipment-kit.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        region=area.spaces.active.region_3d;region.view_distance=5.8;region.view_location=Vector((0,0,1))
        region.view_rotation=camera.rotation_euler.to_quaternion();allowed(region,'view_perspective','ORTHO')
        allowed(area.spaces.active.shading,'color_type','MATERIAL')
bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(root/'Source/EquipmentPreview.blend'),{preview},path_remap='RELATIVE',fake_user=True,compress=True)
print(json.dumps({'fbx_files':len(report),'preview':preview.render.filepath,'source':str(root/'Source/EquipmentDemo.blend')}))

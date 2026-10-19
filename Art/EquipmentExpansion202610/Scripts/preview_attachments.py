"""One labeled orthographic contact sheet; transforms affect display copies only."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path('D:/Program/Unity/Project Y/Art/EquipmentExpansion202610')
manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
assert 'EquipmentExpansion202610_Preview' not in bpy.data.scenes
source=bpy.data.scenes['EquipmentExpansion202610_Source']
scene=bpy.data.scenes.new('EquipmentExpansion202610_Preview')
bpy.context.window.scene=scene
display=bpy.data.collections.new('EquipmentExpansion202610_Display');scene.collection.children.link(display)
def allowed(owner,key,value):
    assert value in [entry.identifier for entry in owner.bl_rna.properties[key].enum_items],(key,value)
    setattr(owner,key,value)
def flat_material(name,color):
    material=bpy.data.materials.new(name);material.use_nodes=True
    node=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    inputs={s.identifier:s for s in node.inputs}
    inputs['Base Color'].default_value=(*color,1)
    inputs['Roughness'].default_value=.9
    material.diffuse_color=(*color,1)
    return material
label_mat=flat_material('Expansion_Label',(.74,.82,.85))
card_mat=flat_material('Expansion_Card',(.027,.041,.050))
def text(body,x,z,size,material):
    curve=bpy.data.curves.new('Label_'+body,'FONT');curve.body=body;curve.size=size
    allowed(curve,'align_x','CENTER');curve.extrude=0
    obj=bpy.data.objects.new('Label_'+body,curve);display.objects.link(obj)
    obj.location=(x,-.10,z);obj.rotation_euler=(math.pi/2,0,0);curve.materials.append(material)
def card(x,z):
    mesh=bpy.data.meshes.new('CardMesh');mesh.from_pydata([(x-.49,.42,z-.46),(x+.49,.42,z-.46),(x+.49,.42,z+.43),(x-.49,.42,z+.43)],[],[(0,1,2,3)])
    obj=bpy.data.objects.new('Card',mesh);display.objects.link(obj);mesh.materials.append(card_mat)
for i,row in enumerate(manifest['assets']):
    x=(i%6-2.5)*1.07;z=4.2-(i//6)*.98
    master=bpy.data.objects[row['model']]
    obj=master.copy();obj.name='Display_'+row['model'];display.objects.link(obj)
    size=.55/max(master.dimensions);obj.scale=(size,size,size)
    obj.rotation_euler=(math.radians(9),0,math.pi if row['slotKind'] in ('thruster','catalyst') else 0)
    rotation=obj.rotation_euler.to_matrix()
    center=sum((Vector(c) for c in master.bound_box),Vector())/8
    obj.location=Vector((x,0,z+.045))-rotation@(center*size)
    card(x,z)
    text(str(row['id'])+'  '+row['slotKind'].upper(),x,z-.315,.051,label_mat)
    text(row['model'].replace('Equip_',''),x,z-.395,.050,label_mat)
text('PROJECT Y / MODULAR ATTACHMENTS',0,5.05,.13,label_mat)
text('30 ORIGINAL LOW-POLY MASTERS / OCTOBER 2026',0,4.84,.062,label_mat)
scene.render.engine=source.render.engine
world=bpy.data.worlds.new('EquipmentExpansion202610_World');world.use_nodes=True
background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
background.inputs['Color'].default_value=(.045,.065,.075,1);background.inputs['Strength'].default_value=.5
scene.world=world
assert 'AREA' in [e.identifier for e in bpy.types.Light.bl_rna.properties['type'].enum_items]
for name,position,energy,size in [('Key',(-3,-4,7),1100,5),('Fill',(4,-2,4),800,4),('Rim',(0,3,6),1000,3)]:
    data=bpy.data.lights.new('Expansion_'+name,'AREA');data.energy=energy;data.size=size
    obj=bpy.data.objects.new('Expansion_'+name,data);display.objects.link(obj);obj.location=position
    obj.rotation_euler=(Vector((0,0,2.5))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Expansion_Camera');camera=bpy.data.objects.new('Expansion_Camera',data);display.objects.link(camera)
camera.location=(0,-18,2.5);camera.rotation_euler=(Vector((0,0,2.5))-camera.location).to_track_quat('-Z','Y').to_euler()
allowed(data,'type','ORTHO');data.ortho_scale=6.6;scene.camera=camera
scene.render.resolution_x=2400;scene.render.resolution_y=2100;scene.render.resolution_percentage=100
allowed(scene.render.image_settings,'file_format','PNG')
scene.render.filepath=str(ROOT/'Previews/attachments-contact-sheet.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        region=area.spaces.active.region_3d;region.view_distance=7;region.view_location=Vector((0,0,2.5));region.view_rotation=camera.rotation_euler.to_quaternion()
        allowed(region,'view_perspective','ORTHO');allowed(area.spaces.active.shading,'color_type','MATERIAL')
        area.spaces.active.overlay.show_overlays=False
bpy.data.libraries.write(str(ROOT/'Source/EquipmentAttachmentsPreview.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print('Contact sheet ready at',scene.render.filepath,'render engine',scene.render.engine)

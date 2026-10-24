"""Create a contact sheet from display copies. Never move the export masters."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path('D:/Program/Unity/Project Y/Art/ProfessionArsenal20261025')
rows=json.loads((ROOT/'Integration/models.json').read_text(encoding='utf-8'))
NAME='ProfessionArsenal20261025_Preview'
assert NAME not in bpy.data.scenes,'Explicit preview update required'
scene=bpy.data.scenes.new(NAME);bpy.context.window.scene=scene
display=bpy.data.collections.new(NAME+'_Display');scene.collection.children.link(display)
def allowed(owner,key,value):
    assert value in [e.identifier for e in owner.bl_rna.properties[key].enum_items],(key,value)
    setattr(owner,key,value)
def material(name,color):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    inputs={s.identifier:s for s in node.inputs};inputs['Base Color'].default_value=(*color,1)
    inputs['Roughness'].default_value=.9;mat.diffuse_color=(*color,1);return mat
label=material('ProfessionArsenal_Label',(.66,.70,.64))
card=material('ProfessionArsenal_Card',(.027,.040,.042))
accent=material('ProfessionArsenal_Accent',(.35,.23,.095))
def text(body,x,z,size,mat=label):
    data=bpy.data.curves.new('ProfessionLabel_'+body,'FONT');data.body=body;data.size=size;allowed(data,'align_x','CENTER')
    obj=bpy.data.objects.new('ProfessionLabel_'+body,data);display.objects.link(obj);obj.location=(x,-.30,z);obj.rotation_euler=(math.pi/2,0,0);data.materials.append(mat)
cardw=1.42;cardh=1.96;gap=.13
for i,row in enumerate(rows):
    x=(i%4-1.5)*(cardw+gap);z=(2-i//4)*(cardh+gap)
    master=bpy.data.objects[row['modelKey']];obj=master.copy();obj.name='Display_'+master.name;display.objects.link(obj)
    transform=Matrix.Rotation(math.radians(8),3,'X')@Matrix.Rotation(math.radians(-7),3,'Z')
    corners=[transform@Vector(c) for c in master.bound_box]
    mins=Vector(tuple(min(c[k] for c in corners) for k in range(3)));maxs=Vector(tuple(max(c[k] for c in corners) for k in range(3)));dims=maxs-mins
    size=min((cardw-.26)/max(dims.x,.01),(cardh-.45)/max(dims.z,.01))
    obj.rotation_euler=transform.to_euler();obj.scale=(size,size,size);obj.location=Vector((x,0,z+.08))-(mins+maxs)*.5*size
    verts=[(x-cardw/2,.48,z-cardh/2),(x+cardw/2,.48,z-cardh/2),(x+cardw/2,.48,z+cardh/2),(x-cardw/2,.48,z+cardh/2)]
    mesh=bpy.data.meshes.new('ProfessionCard');mesh.from_pydata(verts,[],[(0,1,2,3)]);obj=bpy.data.objects.new('ProfessionCard',mesh);display.objects.link(obj);mesh.materials.append(card)
    text(str(row['id'])+' / '+row['profession'].upper(),x,z-cardh/2+.18,.055,accent)
    text(row['modelKey'].replace('Profession_',''),x,z-cardh/2+.075,.056)
title_z=2*(cardh+gap)+cardh/2+.38
text('PROJECT Y / PROFESSION ARSENAL',0,title_z,.14)
text('SIX PROFESSIONS   /   TWELVE ORIGINAL WEAPONS   /   OCTOBER 2026',0,title_z-.22,.058,accent)
center=(title_z-cardh/2)/2
world=bpy.data.worlds.new(NAME+'_World');world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.035,.050,.052,1);bg.inputs['Strength'].default_value=.5;scene.world=world
assert 'AREA' in [e.identifier for e in bpy.types.Light.bl_rna.properties['type'].enum_items]
for tag,pos,energy,size in [('Key',(-3,-4,title_z+1),950,5),('Fill',(4,-2,center),650,4),('Rim',(0,3,title_z),800,4)]:
    data=bpy.data.lights.new(NAME+tag,'AREA');data.energy=energy;data.size=size
    obj=bpy.data.objects.new(NAME+tag,data);display.objects.link(obj);obj.location=pos;obj.rotation_euler=(Vector((0,0,center))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new(NAME+'_Camera');camera=bpy.data.objects.new(NAME+'_Camera',data);display.objects.link(camera)
camera.location=(0,-20,center);camera.rotation_euler=(Vector((0,0,center))-camera.location).to_track_quat('-Z','Y').to_euler();allowed(data,'type','ORTHO')
scene.render.resolution_x=2200;scene.render.resolution_y=2200;scene.render.resolution_percentage=100
data.ortho_scale=max(4*(cardw+gap),title_z+cardh/2+.30)
scene.camera=camera;allowed(scene.render.image_settings,'file_format','PNG')
scene.render.filepath=str(ROOT/'Previews/weapons-contact-sheet.png')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.color_type='MATERIAL'
bpy.data.libraries.write(str(ROOT/'Source/ProfessionWeaponsPreview.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
print('PROFESSION_PREVIEW_READY',scene.render.filepath)

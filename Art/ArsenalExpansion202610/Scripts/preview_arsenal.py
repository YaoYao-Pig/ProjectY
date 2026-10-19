"""Produce separate readable weapon and accessory sheets from display copies only."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path('D:/Program/Unity/Project Y/Art/ArsenalExpansion202610')
design=json.loads((ROOT/'design.json').read_text(encoding='utf-8'))
def allowed(owner,key,value):
    assert value in [e.identifier for e in owner.bl_rna.properties[key].enum_items],(key,value)
    setattr(owner,key,value)
def material(name,color):
    if name in bpy.data.materials:return bpy.data.materials[name]
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    inputs={s.identifier:s for s in node.inputs};inputs['Base Color'].default_value=(*color,1)
    inputs['Roughness'].default_value=.9;mat.diffuse_color=(*color,1);return mat
label=material('Arsenal_Label',(.74,.82,.85));cardmat=material('Arsenal_Card',(.027,.041,.05))

def make(kind):
    weapon=kind=='weapons';rows=design[kind];name='ArsenalExpansion202610_'+kind.title()+'Preview'
    assert name not in bpy.data.scenes,'Preview exists; update specific meshes without rebuilding it'
    scene=bpy.data.scenes.new(name);bpy.context.window.scene=scene
    display=bpy.data.collections.new(name+'_Display');scene.collection.children.link(display)
    cardw=1.12;cardh=1.70 if weapon else 1.0;gap=.10
    def text(body,x,z,size):
        data=bpy.data.curves.new('ArsenalLabel_'+body,'FONT');data.body=body;data.size=size;allowed(data,'align_x','CENTER')
        obj=bpy.data.objects.new('ArsenalLabel_'+body,data);display.objects.link(obj);obj.location=(x,-.16,z);obj.rotation_euler=(math.pi/2,0,0);data.materials.append(label)
    for i,row in enumerate(rows):
        x=(i%5-2)*(cardw+gap);z=(3-i//5)*(cardh+gap)
        master=bpy.data.objects[row['model']];obj=master.copy();obj.name='Display_'+row['model'];display.objects.link(obj)
        transform=Matrix.Rotation(math.radians(7),3,'X')
        if weapon and row['class']=='gun':transform=transform@Matrix.Rotation(math.pi/2,3,'Z')
        elif not weapon and row['slotKind'] in ('thruster','catalyst'):transform=transform@Matrix.Rotation(math.pi,3,'Z')
        elif not weapon and row['slotKind']=='rail':transform=transform@Matrix(((0,0,1),(-1,0,0),(0,-1,0)))
        corners=[transform@Vector(c) for c in master.bound_box]
        mins=Vector(tuple(min(c[k] for c in corners) for k in range(3)));maxs=Vector(tuple(max(c[k] for c in corners) for k in range(3)))
        dims=maxs-mins
        size=min((cardw-.18)/max(dims.x,.01),(cardh-.35)/max(dims.z,.01))
        if not weapon:size=min(size,.65/max(master.dimensions))
        obj.rotation_euler=transform.to_euler();obj.scale=(size,size,size)
        obj.location=Vector((x,0,z+.08))-(mins+maxs)*.5*size
        verts=[(x-cardw/2,.45,z-cardh/2),(x+cardw/2,.45,z-cardh/2),(x+cardw/2,.45,z+cardh/2),(x-cardw/2,.45,z+cardh/2)]
        mesh=bpy.data.meshes.new('ArsenalCard');mesh.from_pydata(verts,[],[(0,1,2,3)])
        card=bpy.data.objects.new('ArsenalCard',mesh);display.objects.link(card);mesh.materials.append(cardmat)
        cat=(row['class'] if row['class']!='melee' else {3:'sword',4:'greatsword',5:'colossal',7:'tool'}[row['categoryId']]) if weapon else row['slotKind']
        text(str(row['id'])+' / '+cat.upper(),x,z-cardh/2+.15,.047)
        text(row['model'].replace('Arsenal_',''),x,z-cardh/2+.065,.050 if len(row['model'])<26 else .044)
    title_z=3*(cardh+gap)+cardh/2+.30
    text('PROJECT Y / '+('TWENTY NEW WEAPONS' if weapon else 'TWENTY UTILITY ATTACHMENTS'),0,title_z,.12)
    text('ORIGINAL LOW-POLY MASTERS / OCTOBER 2026',0,title_z-.19,.055)
    center=(title_z-cardh/2)/2
    world=bpy.data.worlds.new(name+'_World');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.045,.065,.075,1);bg.inputs['Strength'].default_value=.5;scene.world=world
    assert 'AREA' in [e.identifier for e in bpy.types.Light.bl_rna.properties['type'].enum_items]
    for tag,pos,energy,size in [('Key',(-3,-4,title_z+1),1300,5),('Fill',(4,-2,center),1000,4),('Rim',(0,3,title_z),1000,4)]:
        data=bpy.data.lights.new(name+tag,'AREA');data.energy=energy;data.size=size
        obj=bpy.data.objects.new(name+tag,data);display.objects.link(obj);obj.location=pos;obj.rotation_euler=(Vector((0,0,center))-obj.location).to_track_quat('-Z','Y').to_euler()
    data=bpy.data.cameras.new(name+'_Camera');camera=bpy.data.objects.new(name+'_Camera',data);display.objects.link(camera)
    camera.location=(0,-20,center);camera.rotation_euler=(Vector((0,0,center))-camera.location).to_track_quat('-Z','Y').to_euler();allowed(data,'type','ORTHO')
    scene.render.resolution_x=2200;scene.render.resolution_y=2900 if weapon else 1850;scene.render.resolution_percentage=100
    # Orthographic scale spans the wider image axis; preserve a fixed margin on both axes.
    width=5*(cardw+gap);height=title_z+cardh/2+.30
    data.ortho_scale=max(width,height*scene.render.resolution_x/scene.render.resolution_y) if scene.render.resolution_x>=scene.render.resolution_y else max(height,width*scene.render.resolution_y/scene.render.resolution_x)
    scene.camera=camera;allowed(scene.render.image_settings,'file_format','PNG')
    scene.render.filepath=str(ROOT/'Previews'/(kind+'-contact-sheet.png'))
    bpy.data.libraries.write(str(ROOT/'Source'/(kind.title()+'Preview.blend')),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
    print('PREVIEW_READY',kind,scene.render.filepath,'scale',data.ortho_scale)
    return scene
print('Preview helpers ready; call make(weapons/attachments).')

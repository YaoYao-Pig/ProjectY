"""Stage the twelve inspected masters and render one contact sheet from display copies."""
import bpy,json,math,runpy
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path('D:/Program/Unity/Project Y/Art/SocketExpansion202610')
source=bpy.data.scenes['SocketExpansion202610_Source'];bpy.context.window.scene=source
manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
props=bpy.ops.export_scene.fbx.get_rna_type().properties
for key,value in {'apply_scale_options':'FBX_SCALE_UNITS','axis_forward':'-Z','axis_up':'Y','mesh_smooth_type':'OFF','path_mode':'RELATIVE'}.items():
    assert value in [x.identifier for x in props[key].enum_items]
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
for row in manifest['models']:
    row['export']=export(row['model'],str(ROOT/'Staging'/(row['model']+'.fbx')))
manifest['status']='exported'
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')

def allowed(owner,key,value):
    assert value in [e.identifier for e in owner.bl_rna.properties[key].enum_items];setattr(owner,key,value)
assert 'SocketExpansion202610_Preview' not in bpy.data.scenes
scene=bpy.data.scenes.new('SocketExpansion202610_Preview');bpy.context.window.scene=scene
display=bpy.data.collections.new('SocketExpansion202610_Display');scene.collection.children.link(display)
def material(name,color):
    m=bpy.data.materials.new(name);m.use_nodes=True
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    inputs={s.identifier:s for s in n.inputs};inputs['Base Color'].default_value=(*color,1);inputs['Roughness'].default_value=.9
    m.diffuse_color=(*color,1);return m
ink=material('SocketExpansion_PreviewInk',(.025,.037,.046));paper=material('SocketExpansion_PreviewType',(.74,.82,.85))
def text(body,x,z,size):
    curve=bpy.data.curves.new('SocketLabel_'+body,'FONT');curve.body=body;curve.size=size;allowed(curve,'align_x','CENTER')
    obj=bpy.data.objects.new('SocketLabel_'+body,curve);display.objects.link(obj);obj.location=(x,-.22,z);obj.rotation_euler=(math.pi/2,0,0);curve.materials.append(paper)
for i,row in enumerate(manifest['models']):
    x=(i%4-1.5)*1.1;z=(2-i//4)*1.04
    original=bpy.data.objects[row['model']];obj=original.copy();obj.name='Display_'+row['model'];display.objects.link(obj)
    rotation=Matrix.Rotation(math.radians(9),3,'X')
    if row['slotKind']=='stock':rotation=rotation@Matrix.Rotation(math.pi/2,3,'Z')
    elif row['slotKind']=='muzzle':rotation=rotation@Matrix.Rotation(math.radians(53),3,'Z')
    corners=[rotation@Vector(c) for c in original.bound_box]
    minimum=Vector(tuple(min(c[j] for c in corners)for j in range(3)));maximum=Vector(tuple(max(c[j] for c in corners)for j in range(3)))
    size=maximum-minimum;scale=min(.70/max(size.x,.01),.65/max(size.z,.01))
    obj.rotation_euler=rotation.to_euler();obj.scale=(scale,scale,scale);obj.location=Vector((x,0,z+.09))-(minimum+maximum)*.5*scale
    mesh=bpy.data.meshes.new('SocketCard');mesh.from_pydata([(x-.51,.45,z-.46),(x+.51,.45,z-.46),(x+.51,.45,z+.49),(x-.51,.45,z+.49)],[],[(0,1,2,3)])
    card=bpy.data.objects.new('SocketCard',mesh);display.objects.link(card);mesh.materials.append(ink)
    text(str(row['id'])+' / '+row['slotKind'].upper(),x,z-.30,.052)
    text(row['label'],x,z-.385,.046)
text('PROJECT Y / WEAPON ATTACHMENTS',0,2.98,.115)
text('12 COMPACT SOCKET MODULES / PURE-COLOR LOW-POLY',0,2.78,.052)
world=bpy.data.worlds.new('SocketExpansion_PreviewWorld');world.use_nodes=True
background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');background.inputs['Color'].default_value=(.045,.065,.075,1);background.inputs['Strength'].default_value=.5;scene.world=world
assert 'AREA' in [e.identifier for e in bpy.types.Light.bl_rna.properties['type'].enum_items]
for tag,position,energy in [('Key',(-3,-4,6),750),('Fill',(4,-2,3),550),('Rim',(0,3,5),600)]:
    data=bpy.data.lights.new('SocketPreview_'+tag,'AREA');data.energy=energy;data.size=4
    obj=bpy.data.objects.new('SocketPreview_'+tag,data);display.objects.link(obj);obj.location=position;obj.rotation_euler=(Vector((0,0,1.2))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('SocketPreviewCamera');camera=bpy.data.objects.new('SocketPreviewCamera',data);display.objects.link(camera)
camera.location=(0,-16,1.25);camera.rotation_euler=(Vector((0,0,1.25))-camera.location).to_track_quat('-Z','Y').to_euler()
allowed(data,'type','ORTHO');data.ortho_scale=4.5;scene.camera=camera
scene.render.engine=source.render.engine;scene.render.resolution_x=2000;scene.render.resolution_y=1700;scene.render.resolution_percentage=100
allowed(scene.render.image_settings,'file_format','PNG');scene.render.filepath=str(ROOT/'Previews/contact-sheet.png')
bpy.data.libraries.write(str(ROOT/'Source/WeaponAttachmentsPreview.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps({'models':len(manifest['models']),'triangles':sum(r['triangles']for r in manifest['models']),
                  'fbxBytes':sum(r['export']['bytes']for r in manifest['models']),'preview':scene.render.filepath}))

import bpy, math
from pathlib import Path
from mathutils import Vector, Quaternion
root=Path('D:/Program/Unity/Project Y/Art/Dice')
scene=bpy.data.scenes.new('Dice_Showcase')
bpy.context.window.scene=scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(root/'Preview.png')
world=bpy.data.worlds.new('Dice_StudioWorld');world.use_nodes=True;scene.world=world
background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
background.inputs['Color'].default_value=(.09,.12,.21,1);background.inputs['Strength'].default_value=.45
source=bpy.data.scenes['Dice_Source']
layout=[('D20',(0,-.45,.85),1.45,20),('D12',(-2.2,.15,.68),1.1,12),('D10',(2.1,.05,.8),1.15,8),
        ('D4',(-3.4,2.05,.56),.95,4),('D6',(-1.3,2.6,.65),1.1,6),('D8',(1.05,2.65,.7),1.1,8),('D100',(3.3,1.9,.78),1.1,90)]
for name,pos,scale,value in layout:
    original=source.objects[name]
    pivot=bpy.data.objects.new(name+'_Display',None);scene.collection.objects.link(pivot)
    axis=source.objects[f'{name}_Face_{value}_Axis'].location.normalized()
    # Slight tilt toward the viewer makes the showcased reading legible.
    target=Vector((0,-.3,1)).normalized()
    rotation=axis.rotation_difference(target)
    pivot.rotation_mode='QUATERNION';pivot.rotation_quaternion=rotation
    pivot.location=pos;pivot.scale=(scale,)*3
    for child in original.children:
        if child.type!='MESH' or child.name.endswith('_Collider'):continue
        obj=child.copy();obj.data=child.data;scene.collection.objects.link(obj);obj.parent=pivot
    # Put each silhouette on the floor, respecting its exact rotated vertices.
    lowest=min((pivot.rotation_quaternion @ (child.matrix_basis @ v.co)*scale).z for child in pivot.children for v in child.data.vertices)
    pivot.location.z=-lowest+.04

def mat(name,color,metal=0,rough=.4):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
floor_mesh=bpy.data.meshes.new('StudioFloor');floor_mesh.from_pydata([(-200,-200,0),(200,-200,0),(200,200,0),(-200,200,0)],[],[(0,1,2,3)])
floor=bpy.data.objects.new('StudioFloor',floor_mesh);scene.collection.objects.link(floor);floor_mesh.materials.append(mat('Dice_StudioSlate',(.009,.014,.025),.25,.32))
for name,loc,color,power,size in [('WarmKey',(-4,-4,8),(1,.74,.4),1500,5),('CoolRim',(4,4,6),(.22,.52,1),1900,4),('TopSoft',(0,1,8),(1,.92,.75),950,3),('Front',(-1,-5,3),(.5,.7,1),450,4)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,1,0))-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Dice_ShowcaseCamera');camera=bpy.data.objects.new('Dice_ShowcaseCamera',data);scene.collection.objects.link(camera)
camera.location=(0,-10.2,9.5);camera.rotation_euler=(Vector((0,1,.3))-camera.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=10.3;scene.camera=camera
bpy.ops.render.render(write_still=True)
print(str(root/'Preview.png'))

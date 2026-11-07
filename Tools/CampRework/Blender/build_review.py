"""Keep editable origin-centred assets and a separate presentation scene in the source blend."""
import bpy,math
from pathlib import Path
from mathutils import Vector
root=Path('D:/Program/Unity/Project Y/Art/CampPresentation')
art=bpy.data.scenes['CampPresentation_Art']
assert 'CampPresentation_Review' not in bpy.data.scenes,'Inspect the existing task review before replacing it.'
review=bpy.data.scenes.new('CampPresentation_Review');bpy.context.window.scene=review
originals=bpy.data.collections.new('Editable assets at origin');review.collection.children.link(originals);originals.hide_render=True
for collection in art.collection.children:originals.children.link(collection)
display=bpy.data.collections.new('Display copies');review.collection.children.link(display)
families=['Workbench','Forge','Warehouse','Medical']
for row,family in enumerate(families):
    for level in range(3):
        source=bpy.data.objects[f'Camp_{family}_L{level}'];obj=source.copy();obj.name=f'Review_{family}_{level}';display.objects.link(obj)
        obj.location=(level*5.2,row*4.6,0);obj.hide_render=False;obj.hide_set(False)
for i,name in enumerate(['Camp_Firepit','Camp_BackdropTree','Camp_Clearing']):
    source=bpy.data.objects[name];obj=source.copy();obj.name='Review_'+name;display.objects.link(obj);obj.location=(i*5.2,18.4,0)
    obj.scale=(.2,.2,.2) if name=='Camp_Clearing' else (.65,.65,.65) if name=='Camp_BackdropTree' else (1,1,1)
    obj.hide_render=False;obj.hide_set(False)
for collection in art.collection.children:
    for obj in collection.objects:obj.hide_set(True)
camera_data=bpy.data.cameras.new('CampReviewCamera')
assert 'ORTHO' in [i.identifier for i in camera_data.bl_rna.properties['type'].enum_items]
camera_data.type='ORTHO';camera_data.ortho_scale=26
camera=bpy.data.objects.new('CampReviewCamera',camera_data);review.collection.objects.link(camera)
camera.location=(20,-17,26);camera.rotation_euler=(Vector((5.2,8.5,.6))-camera.location).to_track_quat('-Z','Y').to_euler();review.camera=camera
light_types=[i.identifier for i in bpy.types.BlendDataLights.bl_rna.functions['new'].parameters['type'].enum_items]
assert 'AREA' in light_types
for name,position,power,size in [('Key',(0,-5,20),2600,12),('Fill',(15,12,15),1800,10)]:
    data=bpy.data.lights.new('CampReview'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    light=bpy.data.objects.new('CampReview'+name,data);review.collection.objects.link(light);light.location=position;light.rotation_euler=(Vector((5,8,0))-light.location).to_track_quat('-Z','Y').to_euler()
review.render.resolution_x=1600;review.render.resolution_y=1200;review.render.resolution_percentage=100
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        space=area.spaces.active;space.region_3d.view_distance=29;space.region_3d.view_location=Vector((5.2,8.5,1))
        space.region_3d.view_rotation=(Vector((18,-16,24))-Vector((5.2,8.5,1))).to_track_quat('Z','Y');space.shading.type='MATERIAL'
bpy.data.libraries.write(str(root/'Source'/'CampPresentation.blend'),{review},fake_user=True)
print('Source blend now opens to the review scene with 15 display copies and hidden editable asset collections.')

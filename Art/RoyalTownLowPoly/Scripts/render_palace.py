"""独立预览场景检查宫殿剪影、侧翼和窗拱；不改导出原件。"""
import bpy
from mathutils import Vector
scene=bpy.data.scenes.new('RoyalTown_Preview');bpy.context.window.scene=scene
obj=bpy.data.objects['Royal_Palace'].copy();scene.collection.objects.link(obj)
camera=bpy.data.cameras.new('RoyalPreviewCamera');host=bpy.data.objects.new('RoyalPreviewCamera',camera);scene.collection.objects.link(host)
host.location=(57,-72,49);host.rotation_euler=(Vector((0,0,13))-host.location).to_track_quat('-Z','Y').to_euler();camera.type='ORTHO';camera.ortho_scale=66;scene.camera=host
sun=bpy.data.lights.new('RoyalPreviewSun','SUN');sun.energy=3;lamp=bpy.data.objects.new('RoyalPreviewSun',sun);scene.collection.objects.link(lamp);lamp.rotation_euler=(.5,-.5,-.4)
world=bpy.data.worlds.new('RoyalPreviewWorld');world.use_nodes=True;next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs['Color'].default_value=(.24,.31,.37,1);scene.world=world
scene.render.resolution_x=1500;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath='D:/Program/Unity/Project Y/Art/RoyalTownLowPoly/Previews/palace-blender.png'
scene.render.film_transparent=False
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.render.render(write_still=True)
print(scene.render.filepath)

"""Seven-tile seam and legacy-house scale comparison, isolated review scene."""
import bpy,runpy,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y');BASE=ROOT/'Art/AssetExpansion202610/Terrain'
H=runpy.run_path(str(BASE.parent/'shared_pipeline.py'))
scene=H['setup_review']('TerrainContext');bpy.context.window.scene=scene
source=ROOT/'Art/MapLowPoly/Source/MapLowPoly.blend'
with bpy.data.libraries.load(str(source),link=False) as (data_from,data_to):
    assert 'Building_House' in data_from.objects
    data_to.objects=['Building_House']
house=data_to.objects[0]
entries=[('AE_Hex_Mushroom_Mycelium',0,0,None),('AE_Hex_Mushroom_Sporebed',1,0,'AE_Mushroom_RedParasol'),('AE_Hex_Mushroom_OldGrowth',0,1,'AE_Mushroom_BrownCanopy'),('AE_Hex_Swamp_Moss',-1,1,'AE_Swamp_RootWillow'),('AE_Hex_DarkForest_Loam',-1,0,'AE_DarkForest_AncientOak'),('AE_Hex_Lava_Crust',0,-1,'AE_Lava_BasaltOrgan'),('AE_Hex_Volcano_Ash',1,-1,'AE_Volcano_BrokenCrater')]
copies=[];scale=.16
for i,(name,q,r,decor) in enumerate(entries):
    x=math.sqrt(3)*(q+r*.5);y=r*1.5
    for obj_source,z in [(bpy.data.objects[name],0)]+([(bpy.data.objects[decor],0)] if decor else [(house,0)]):
        obj=obj_source.copy();obj.data=obj_source.data;obj.location=(x*scale,y*scale,z);obj.scale=(scale,)*3;obj.rotation_euler=(0,0,0);obj.hide_render=False
        scene.collection.objects.link(obj);copies.append(obj)
scene.render.resolution_x=1400;scene.render.resolution_y=1100
scene.camera.data.ortho_scale=1.12
target=Vector((0,0,.1));scene.camera.location=(2.6,-4,3.1)
scene.camera.rotation_euler=(target-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(BASE/'Previews/seven_hex_legacy_house_context.png')
bpy.ops.render.render(write_still=True,scene=scene.name)
bpy.data.libraries.write(str(BASE/'Source/TerrainContext.blend'),{scene},fake_user=True,compress=True)
print(json.dumps({'source_reference':str(source),'legacy_object':house.name,'new_tile_count':7,'common_scale':scale,'seam_pitch_x':math.sqrt(3),'seam_pitch_y':1.5,'image':scene.render.filepath}))

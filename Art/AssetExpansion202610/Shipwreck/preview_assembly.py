import bpy,runpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y/Art/AssetExpansion202610')
P=runpy.run_path(str(ROOT/'shared_pipeline.py'))
old=bpy.context.window.scene
scene=P['setup_review']('ShipwreckAssembly');bpy.context.window.scene=scene
for o in list(scene.objects):
    if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
placements=[('SW_Hull_CogWreck',(0,0,0),0),('SW_Deck_Cog',(0,0,0),0),
 ('SW_SternCastle',(0,12,0),0),('SW_Mast_BrokenSquare',(0,-1,0),0),
 ('SW_Hatch_Collapsed',(-2.5,-6,0),0),('SW_Capstan',(0,-12,0),0),
 ('SW_Cargo_SaltCrates',(3.3,5,0),0),('SW_Cargo_WetBarrels',(-3.4,7,0),0),
 ('SW_Rope_Coil',(-1.8,-11,0),0),('SW_Bell_BrokenFrame',(-2.5,8.8,0),0),
 ('SW_Drift_Planks',(-3.2,-2,0),.3),('SW_Boat_BrokenDinghy',(9,4,-1.15),-.3)]
for name,pos,rot in placements:
    source=bpy.data.objects[name];o=source.copy();o.data=source.data;scene.collection.objects.link(o)
    o.name='SW_Assembly_'+name;o.location=Vector(pos)/34;o.scale=(1/34,)*3;o.rotation_euler.z=rot
mesh=bpy.data.meshes.new('SW_Assembly_Water');mesh.from_pydata([(-3,-3,-1.15/34),(3,-3,-1.15/34),(3,3,-1.15/34),(-3,3,-1.15/34)],[],[(0,1,2,3)])
builder=runpy.run_path(str(ROOT/'Shipwreck/build_shipwreck.py'))
mat=builder['G']['ensure_material']('SWWater');mesh.materials.append(mat);o=bpy.data.objects.new('SW_Assembly_Water',mesh);scene.collection.objects.link(o)
scene.render.resolution_x=1400;scene.render.resolution_y=1100
scene.camera.data.ortho_scale=1.45
for name,position in [('assembled',(2.6,-4,3.4)),('assembled_top',(0,0,4)),('assembled_side',(4,0,1.8))]:
    scene.camera.location=position;scene.camera.rotation_euler=(-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(ROOT/'Shipwreck/Previews'/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.data.libraries.write(str(ROOT/'Shipwreck/Source/ShipwreckAssembly.blend'),{scene},compress=True,fake_user=True)
bpy.context.window.scene=old
print('Shipwreck assembly: hero, top, side saved; source preserved')

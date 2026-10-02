"""Apply the two specific issues found during four-view visual review."""
import bpy,bmesh,json,runpy
from pathlib import Path
BASE=Path('D:/Program/Unity/Project Y/Art/AssetExpansion202610/Terrain')
G=runpy.run_path(str(BASE/'Scripts/terrain_geometry.py'))
rows=json.loads((BASE/'manifest.json').read_text(encoding='utf8'))
scene=bpy.data.scenes['AE202610_Terrain'];bpy.context.window.scene=scene
for i,row in enumerate(rows[:15]):
    obj=bpy.data.objects[row['name']];mesh=obj.data
    # The existing palette has exactly top/accent/side; infer top from the outer planar band.
    keys=[m.name for m in mesh.materials]
    spec={
      'Swamp':[('Peat','PeatLight'),('Moss','MossDeep'),('Silt','PeatLight')],
      'DarkForest':[('Loam','LoamLight'),('Peat','Loam'),('Blight','LoamLight')],
      'Lava':[('Basalt','BasaltLight'),('Cinder','LavaDark'),('BasaltDark','Cinder')],
      'Volcano':[('Ash','AshLight'),('Tuff','Ash'),('Tuff','Sulphur')],
      'Mushroom':[('Mycelium','MyceliumLight'),('MyceliumLight','StemShadow'),('MyceliumDark','Mycelium')]}
    variant=i%3;top,accent=spec[row['biome']][variant]
    for p in mesh.polygons:
        if all(abs(mesh.vertices[j].co.z)<1e-8 for j in p.vertices):
            center=p.center;key=accent if G['soil_patch'](center.x,center.y,variant) else top
            p.material_index=keys.index('AE_Terrain_'+key)
    row['design_zh']='精确半径1尖顶六边形，表面为连续偏置沉积斑块，避免放射花纹；边界无倒角、无高差。'
obj=bpy.data.objects['AE_Lava_MagmaRift'];old=obj.data
v,f,c=G['magma_rift_geometry']();mesh=bpy.data.meshes.new('AE_Lava_MagmaRift_Mesh')
mesh.from_pydata(v,[],f);keys=list(dict.fromkeys(c))
for key in keys:mesh.materials.append(bpy.data.materials['AE_Terrain_'+key])
for p,key in zip(mesh.polygons,c):p.material_index=keys.index(key)
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
uv=mesh.uv_layers.new(name='UVMap')
for p in mesh.polygons:
    axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=axis]
    for li in p.loop_indices:
        co=mesh.vertices[mesh.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]],co[axes[1]])
obj.data=mesh;bpy.data.meshes.remove(old)
for row in rows:
    if row['name']=='AE_Lava_MagmaRift':row['design_zh']='厚熔岩床被四块断裂岩板包围，错缝露出分支火脉；平贴地表，无悬空的橙色管线。'
H=runpy.run_path(str(BASE.parent/'shared_pipeline.py'))
H['finish_batch']('Terrain',scene,[bpy.data.objects[r['name']] for r in rows],rows)
runpy.run_path(str(BASE/'Scripts/verify_terrain.py'))
print('Revised 15 soil patterns and 1 magma rift; complete manifest/source updated')

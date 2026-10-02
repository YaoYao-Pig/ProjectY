"""Replace collinear bottom ngons with a stable explicit triangle fan."""
import bpy,bmesh,json,runpy
from pathlib import Path
BASE=Path('D:/Program/Unity/Project Y/Art/AssetExpansion202610/Terrain')
rows=json.loads((BASE/'manifest.json').read_text(encoding='utf8'))
scene=bpy.data.scenes['AE202610_Terrain'];bpy.context.window.scene=scene
for row in rows:
    if row['category']!='hex_tile':continue
    obj=bpy.data.objects[row['name']];old=obj.data
    vertices=[tuple(v.co) for v in old.vertices];vertices.append((0,0,-1));center=len(vertices)-1
    faces=[];mats=[]
    for p in old.polygons:
        if len(p.vertices)==18 and all(abs(old.vertices[i].co.z+1)<1e-7 for i in p.vertices):
            ids=list(p.vertices)
            for i in range(18):faces.append((center,ids[i],ids[(i+1)%18]));mats.append(p.material_index)
        else:faces.append(tuple(p.vertices));mats.append(p.material_index)
    mesh=bpy.data.meshes.new(row['name']+'_StableCaps');mesh.from_pydata(vertices,[],faces)
    for mat in old.materials:mesh.materials.append(mat)
    for p,mi in zip(mesh.polygons,mats):p.material_index=mi
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
    uv=mesh.uv_layers.new(name='UVMap')
    for p in mesh.polygons:
        axis=max(range(3),key=lambda i:abs(p.normal[i]));axes=[i for i in range(3) if i!=axis]
        for li in p.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]],co[axes[1]])
    obj.data=mesh;bpy.data.meshes.remove(old)
H=runpy.run_path(str(BASE.parent/'shared_pipeline.py'))
H['finish_batch']('Terrain',scene,[bpy.data.objects[r['name']] for r in rows],rows)
runpy.run_path(str(BASE/'Scripts/verify_terrain.py'))

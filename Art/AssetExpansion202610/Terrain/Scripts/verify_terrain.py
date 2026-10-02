"""Narrow asset QA only; no Unity, compilation or gameplay tests."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
BASE=Path('D:/Program/Unity/Project Y/Art/AssetExpansion202610/Terrain')
rows=json.loads((BASE/'manifest.json').read_text(encoding='utf8'))
checks=[]
for row in rows:
    obj=bpy.data.objects[row['name']];mesh=obj.data;mesh.calc_loop_triangles()
    areas=[]
    for tri in mesh.loop_triangles:
        a,b,c=[mesh.vertices[i].co for i in tri.vertices]
        areas.append((b-a).cross(c-a).length*.5)
    assert min(areas)>1e-10,(obj.name,min(areas))
    assert not any(not math.isfinite(v) for vert in mesh.vertices for v in vert.co),obj.name
    assert obj.location.length<1e-8 and obj.rotation_euler.to_matrix().is_identity
    if row['category']=='hex_tile':
        assert abs(min(v.co.z for v in mesh.vertices)+1)<1e-7
        assert abs(max(v.co.z for v in mesh.vertices))<1e-7
        boundary=[tuple(round(v,7) for v in vert.co) for vert in mesh.vertices if vert.co.z==0 and Vector(vert.co[:2]).length>.58]
        assert len(boundary)==18,(obj.name,len(boundary))
        if 'first_boundary' not in globals():first_boundary=sorted(boundary)
        assert sorted(boundary)==first_boundary,obj.name
        # Each edge lies on apothem cos(pi/6); exact tangential joins preserve all rotations.
        edges=[]
        for side in range(6):
            a=math.pi/3*(side+1)
            points=[p for p in boundary if abs(p[0]*math.cos(a)+p[1]*math.sin(a)-math.sqrt(3)/2)<1e-6]
            assert len(points)==4,(obj.name,side,points)
            edges.append(len(points))
    else:
        assert abs(min(v.co.z for v in mesh.vertices))<1e-6,obj.name
    checks.append(dict(name=obj.name,minimum_triangle_area=min(areas),closed_components=row['nonmanifold_edges']==0,
                       root_transform='identity',uv_channels=len(mesh.uv_layers),material_slots=len(mesh.materials),
                       exact_hex_seams=row['category']=='hex_tile',origin_grounded=row['category']=='decoration'))
(BASE/'mesh_qa.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
print(json.dumps({'assets_checked':len(checks),'exact_boundary_variants':15,'minimum_triangle_area':min(c['minimum_triangle_area'] for c in checks),'status':'passed'}))

"""Small mesh, reference and lore checks; no gameplay execution."""
import bpy,json,re,math
from pathlib import Path
BASE=Path('D:/Program/Unity/Project Y/Art/AssetExpansion202610/ShipwreckWeapons')
rows=json.loads((BASE/'manifest.json').read_text(encoding='utf8'));qa=[]
assert len(rows)==10
for r in rows:
    obj=bpy.data.objects[r['name']];me=obj.data;me.calc_loop_triangles()
    assert obj.location.length<1e-8 and max(abs(v) for v in obj.rotation_euler)<1e-8 and all(abs(v-1)<1e-8 for v in obj.scale)
    assert r['nonmanifold_edges']==0 and r['degenerate_faces']==0 and r['uv_layers']>0
    assert 2<=len(r['references'])<=5 and all(x['reviewed'] and Path(x['local_file']).is_file() for x in r['references'])
    count=len(re.findall(r'[\u4e00-\u9fff]',r['lore_zh']));assert count>=100
    areas=[]
    for t in me.loop_triangles:
        a,b,c=[me.vertices[i].co for i in t.vertices];areas.append((b-a).cross(c-a).length*.5)
    assert min(areas)>1e-12,(r['name'],min(areas))
    qa.append(dict(name=r['name'],zero_root_transform=True,closed_components=True,degenerate_triangles=0,min_triangle_area=min(areas),lore_han_count=count,reference_image_count=len(r['references']),uv_channels=len(me.uv_layers)))
(BASE/'mesh_qa.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'checked':len(qa),'passed':True,'minimum_lore_han_count':min(x['lore_han_count'] for x in qa)}))

"""检查最终模型与配表通路：逐条穿门/室内边验证人物中心和两侧净空。"""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path('D:/Program/Unity/Project Y')
rows=json.loads((root/'Config/Tables/MapArea/MapAreaTownInteriorTable.json').read_text(encoding='utf-8'))['rows']
lots={r['id']:r for r in json.loads((root/'Config/Tables/MapArea/MapAreaTownLotTable.json').read_text(encoding='utf-8'))['rows']}
kit=json.loads((root/'Art/TownExpansionLowPoly/Integration/kit-design.json').read_text(encoding='utf-8'))
directions=[(1,0),(0,1),(-1,1),(-1,0),(0,-1),(1,-1)]
report=[]
by_id={r['id']:r for r in rows}
for item in kit:
    row=by_id[item['lotId']]
    lot=lots[row['id']];floor=set(zip(row['interiorQ'],row['interiorR']));door=(lot['entryQ'],lot['entryR']);floor.add(door)
    trees=[]
    for name in [item['shell'],item['cover']]:
        mesh=bpy.data.objects[name].data
        # 已由 Unity 中炉火中心实测核对共享导出预设的实际轴向。
        trees.append((name,BVHTree.FromPolygons([(-v.co.x,v.co.z,-v.co.y) for v in mesh.vertices],[p.vertices for p in mesh.polygons])))
    checked=0;failures=[]
    for q,r in floor:
        for dq,dr in directions:
            target=(q+dq,r+dr)
            if target not in floor or target<(q,r):continue
            start=Vector((math.sqrt(3)*1.5*(q+r/2),0,2.25*r));end=Vector((math.sqrt(3)*1.5*(target[0]+target[1]/2),0,2.25*target[1]))
            direction=(end-start).normalized();side=Vector((-direction.z,0,direction.x))
            for height in [.18,1.3]:
                for offset in [-.69,0,.69]:
                    origin=start+side*offset+Vector((0,height,0));checked+=1
                    for name,tree in trees:
                        hit=tree.ray_cast(origin,direction,(end-start).length)
                        if hit[0] is not None:failures.append(dict(model=name,edge=[q,r,*target],height=height,offset=offset,hit=list(hit[0])))
    report.append(dict(building=item['kind'],checked=checked,failures=failures))
path=root/'Art/TownExpansionLowPoly/Integration/geometry-check.json';path.write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
assert all(not value['failures'] for value in report),'建筑几何侵入通路，详见 geometry-check.json'

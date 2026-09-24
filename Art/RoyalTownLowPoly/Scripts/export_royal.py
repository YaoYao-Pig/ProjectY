"""王城静态 FBX 暂存导出，输出每个根网格的尺寸/材质/面数。"""
import bpy
import json
import runpy
from pathlib import Path
root=Path('D:/Program/Unity/Project Y');out=root/'Art/RoyalTownLowPoly'
bpy.context.window.scene=bpy.data.scenes['RoyalTown_Source']
export=runpy.run_path(str(root/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
report=[]
for obj in bpy.data.collections['RoyalTown_Masters'].objects:
    obj.data.calc_loop_triangles()
    result=export(obj.name,str(out/'Exports'/f'{obj.name}.fbx'))
    result.update(name=obj.name,triangles=len(obj.data.loop_triangles),dimensions=list(obj.dimensions),materials=[m.name for m in obj.data.materials])
    report.append(result)
(out/'Integration/models.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps([dict(name=r['name'],triangles=r['triangles'],bytes=r['bytes']) for r in report]))

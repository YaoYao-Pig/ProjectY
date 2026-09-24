"""只导出本次 13 个根网格，保留选择和旧资产。"""
import bpy,json,runpy
from pathlib import Path
root=Path('D:/Program/Unity/Project Y');out=root/'Art/TownInteriorLowPoly'
bpy.context.window.scene=bpy.data.scenes['WalkTown_Source']
export=runpy.run_path(str(root/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
report=[]
for row in json.loads((out/'Integration/models.json').read_text(encoding='utf-8')):
    obj=bpy.data.objects[row['name']];assert obj.name in bpy.data.collections['WalkTown_Masters'].objects
    result=export(obj.name,str(out/'Staging'/(obj.name+'.fbx')),overwrite=True);report.append(dict(name=obj.name,bytes=result['bytes']))
print(json.dumps(report))

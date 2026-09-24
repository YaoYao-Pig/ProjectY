"""为已创建的王城源定向补充拱券挡墙，不重建宫殿。"""
import bpy,runpy,ast,math,json
from pathlib import Path
from mathutils import Vector
root=Path('D:/Program/Unity/Project Y');out=root/'Art/RoyalTownLowPoly'
bpy.context.window.scene=bpy.data.scenes['RoyalTown_Source']
h=runpy.run_path(str(root/'Art/MapLowPoly/Scripts/mesh_helpers.py'));Mesh=h['MeshBuilder']
scope={'Mesh':Mesh,'math':math,'Vector':Vector}
tree=ast.parse((out/'Scripts/build_royal.py').read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),'royal_helpers','exec'),scope)
b=Mesh();b.box((0,-1.25,1.6),(9,.45,3.2),'RoyalStone')
for x in [-3,0,3]:
    scope['arch'](b,x,-1.53,.18,2.1,1.4,.25,.24,True)
    for px in [x-1.48,x+1.48]:b.box((px,-1.52,1.6),(.22,.45,3.2),'RoyalIvory')
for z in [.12,3.08]:b.box((0,-1.5,z),(9,.65,.24),'RoyalIvory')
b.vertices=[(x/9,y,z) for x,y,z in b.vertices]
h['PALETTE'].update({k[8:]:v['palette_srgb'].lstrip('#') for k,v in bpy.data.materials.items() if k.startswith('M_MapLP_') and 'palette_srgb' in v})
obj=b.finish('Royal_Retaining',bpy.data.collections['RoyalTown_Masters'])
export=runpy.run_path(str(root/'Art/MapLowPoly/Scripts/export_map_static_fbx.py'))['export_map_static_fbx']
result=export(obj.name,str(out/'Exports/Royal_Retaining.fbx'));obj.data.calc_loop_triangles()
result.update(name=obj.name,triangles=len(obj.data.loop_triangles),dimensions=list(obj.dimensions),materials=[m.name for m in obj.data.materials])
report=json.loads((out/'Integration/models.json').read_text(encoding='utf-8'));report.append(result)
(out/'Integration/models.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.data.libraries.write(str(out/'Source/RoyalTown.blend'),{bpy.context.scene},fake_user=True,compress=True)
print(result)

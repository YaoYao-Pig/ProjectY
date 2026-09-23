"""增量制作双手战士姿态与双手剑；通过 Blender MCP 执行。"""
import bpy, json, math, runpy, ast
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y/Art/PawnLowPoly')
scene=bpy.data.scenes['PawnLP_Studio'];bpy.context.window.scene=scene
masters=bpy.data.collections['PawnLP_Masters']
assert 'Pawn_HumanWarrior' not in bpy.data.objects, '请定向编辑已有战士'
MeshBuilder=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py')['MeshBuilder']
# 复用制作原语，不重新执行公共模型的初始化脚本。
tree=ast.parse((ROOT/'Scripts/build_pawn_common.py').read_text(encoding='utf-8'))
for fn in tree.body:
    if isinstance(fn,ast.FunctionDef) and fn.name in ['prism','beam']:
        exec(compile(ast.Module(body=[fn],type_ignores=[]),'pawn_primitives','exec'))
m=MeshBuilder()
for x in [-.17,.17]:
    m.box((x,-.045,.235),(.25,.43,.22),'Timber');beam(m,(x,0,.34),(x,0,.82),.105,'Window')
prism(m,0,0,.76,.31,.175,.57,'Window',8,1.05)
m.box((0,-.005,1.31),(.18,.17,.16),'PlasterShade')
prism(m,0,0,1.36,.245,.205,.42,'PlasterShade',8,.86)
m.box((0,-.215,1.565),(.10,.085,.13),'PlasterShade')
for x in [-.093,.093]:m.box((x,-.203,1.615),(.048,.022,.035),'Timber')
for side,z in [(-1,.94),(1,1.11)]:
    beam(m,(side*.29,0,1.25),(side*.32,-.24,1.04),.105,'Window')
    beam(m,(side*.32,-.24,1.04),(0,-.42,z),.088,'PlasterShade')
    prism(m,0,-.42,z-.065,.10,.10,.13,'PlasterShade',6)
body=m.finish('Pawn_HumanWarrior',masters);body['attachment_slot']='body'
m=MeshBuilder()
prism(m,0,0,-.09,.042,.042,.32,'Timber',6)
m.box((0,0,.25),(.46,.09,.075),'Stone')
m.part([(-.10,-.04,.29),(.10,-.04,.29),(.10,.04,.29),(-.10,.04,.29),(-.07,-.03,1.19),(.07,-.03,1.19),(.07,.03,1.19),(-.07,.03,1.19),(0,0,1.4)],
 [(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,8),(5,6,8),(6,7,8),(7,4,8)],'RockLight')
# 主手插槽保持公共契约，剑柄移到此姿势的双手中心。
m.vertices=[(x-.50,y-.14,z-.04) for x,y,z in m.vertices]
sword=m.finish('Pawn_Greatsword',masters);sword['attachment_slot']='mainHand'
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
report=json.loads((ROOT/'Integration/pawn-models.json').read_text())
bpy.context.view_layer.update()
for obj in [body,sword]:
    assert all(p.area>1e-9 and not p.use_smooth for p in obj.data.polygons)
    report.append(dict(name=obj.name,slot=obj['attachment_slot'],dimensions_blender_xyz=list(obj.dimensions),triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),materials=[m.name for m in obj.data.materials],export=export(obj.name,str(ROOT/'Staging'/(obj.name+'.fbx')))))
(ROOT/'Integration/pawn-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
display=bpy.data.collections['PawnLP_Display']
sockets={'body':(0,0,0),'base':(0,0,0),'mainHand':(.50,-.28,.98),'head':(0,0,1.59),'chest':(0,0,1.05),'back':(0,.20,1.13)}
for obj in list(display.objects):
    if obj.name.startswith('PawnDisplay_'):obj.location.x-=1.3
for name in ['HumanWarrior','Base','ArmorPlate','Helmet','Greatsword','Cape']:
    src=bpy.data.objects['Pawn_'+name];obj=src.copy();obj.name='PawnDisplay_3_'+name;display.objects.link(obj)
    x,y,z=sockets[src['attachment_slot']];obj.location=(3.9+x,y,z)
scene.camera.data.ortho_scale=11.5
scene.render.filepath=str(ROOT/'Previews/pawn-squad-kit.png')
bpy.data.libraries.write(str(ROOT/'Source/PawnCommon.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps(dict(models=len(report),preview=scene.render.filepath)))

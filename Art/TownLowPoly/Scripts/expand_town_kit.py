"""保留原民居与工坊，补充更鲜明的奇幻铁匠铺和三类露天摊位。经 Blender MCP 执行。"""
import bpy, math, json, runpy, ast
from pathlib import Path
from mathutils import Vector
ROOT=Path('D:/Program/Unity/Project Y/Art/TownLowPoly')
scene=bpy.data.scenes['TownLP_Studio'];bpy.context.window.scene=scene
masters=bpy.data.collections['TownLP_Masters'];masters.hide_viewport=False
helpers=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py')
helpers['PALETTE'].update(ForgeGlow='ed963e',Iron='394047',Cloth='527e86',Herb='779755')
MeshBuilder=helpers['MeshBuilder']
tree=ast.parse((ROOT/'Scripts/build_town_kit.py').read_text(encoding='utf-8'))
pawn=ast.parse(Path('D:/Program/Unity/Project Y/Art/PawnLowPoly/Scripts/build_pawn_common.py').read_text(encoding='utf-8'))
for parsed,names in [(pawn,['prism','beam']),(tree,['barrel','sign'])]:
    for fn in parsed.body:
        if isinstance(fn,ast.FunctionDef) and fn.name in names:exec(compile(ast.Module(body=[fn],type_ignores=[]),'town_helpers','exec'))
objects=[]
def finish(m,name):
    assert name not in bpy.data.objects,'已存在资源，请定向修改'
    obj=m.finish(name,masters);objects.append(obj)
def blade(m,x,y,z,h=.9):
    # 抽象宽刃与护手，以轮廓表达武器货物。
    prism(m,x,y,z,.045,.04,.22,'Timber',6)
    m.box((x,y,z+.24),(.34,.08,.07),'Iron')
    prism(m,x,y,z+.28,.105,.045,h,'RockLight',4,.08)

m=MeshBuilder()
# 一边是低矮石屋，一边是敞开的锻造棚；巨大的八角炉与偏置烟道打破民居剪影。
m.box((0,0,.12),(5.15,3.8,.24),'Stone')
m.box((-1.42,.28,1.23),(2.35,2.92,2.25),'Rock')
m.ridge_roof(1.37,1.63,2.5,3.28)
# 屋顶平移到偏置石屋上，仅修改刚加入的六个顶点。
for i in range(len(m.vertices)-6,len(m.vertices)):
    x,y,z=m.vertices[i];m.vertices[i]=(x-1.42,y+.28,z)
m.box((-1.3,-1.2,.92),(1.0,.09,1.6),'Timber')
m.box((-2.15,-1.24,1.5),(.40,.10,.70),'Window')
for x in [-.05,2.3]:
    m.box((x,-1.53,1.26),(.18,.18,2.48),'Timber')
    m.beam((x,-1.53,1.8),(x+(.42 if x<0 else -.42),-1.53,2.46),.14,.14)
m.box((1.15,-.0,2.59),(2.7,3.55,.17),'TimberLight')
# 厚铁束圈、大火口与侧边烟道；火口朝街，使用实体深色洞面与暖色炉芯。
prism(m,1.18,.35,.24,.91,.84,1.56,'RockDark',8,.84)
m.box((1.18,-.49,1.04),(1.02,.10,.88),'Iron')
m.box((1.18,-.55,.91),(.72,.025,.46),'ForgeGlow')
for x in [.90,1.18,1.46]:m.box((x,-.575,.91),(.055,.035,.48),'Iron')
prism(m,1.25,.48,1.75,.67,.64,1.22,'Rock',8,.60)
prism(m,1.25,.48,2.92,.36,.38,1.65,'RockDark',8,1.06)
for z in [3.1,4.25]:prism(m,1.25,.48,z,.43,.44,.14,'Iron',8)
prism(m,1.25,.48,4.57,.52,.52,.23,'Stone',8,1.08)
# 铁砧、淬火桶、悬挂巨锤与武器架，集中在开放棚内并避开正门。
prism(m,.13,-1.11,.24,.37,.33,.56,'Timber',8,.92)
m.box((.13,-1.11,.92),(.78,.36,.18),'Iron');prism(m,.13,-1.11,.77,.20,.15,.14,'Iron',6)
m.part([(.52,-1.29,.84),(.52,-.93,.84),(.92,-1.11,.90),(.52,-1.29,1),(.52,-.93,1),(.92,-1.11,.94)],[(0,2,1),(3,4,5),(0,3,5,2),(1,2,5,4),(0,1,4,3)],'Iron')
barrel(m,2.04,-1.13,.24,.9);prism(m,2.04,-1.13,.88,.22,.22,.025,'Water',8)
m.box((-2.45,-1.45,.87),(.12,.12,1.35),'Timber');m.box((-1.73,-1.45,.87),(.12,.12,1.35),'Timber')
m.box((-2.09,-1.45,1.12),(.86,.10,.10),'Timber')
for x in [-2.37,-2.10,-1.82]:blade(m,x,-1.51,.29,.80)
sign(m,-.37,-1.85,2.82,'hammer')
finish(m,'Town_ArcaneSmithy')

for kind in ['Cloth','Herbs','Arms']:
    m=MeshBuilder()
    for x in [-1.03,1.03]:
        for y in [-.53,.53]:m.box((x,y,1.02),(.11,.11,2.04),'Timber')
    m.box((0,0,.73),(2.13,1.24,.16),'TimberLight')
    if kind!='Arms':
        # 斜坡棚布和垂边；药草摊为一片绿棚，布匹摊蓝白分条。
        for i in range(5):
            x=-1.15+i*.46; key=('Cloth' if i%2==0 else 'Plaster') if kind=='Cloth' else 'Herb'
            m.part([(x,-.84,1.99),(x+.46,-.84,1.99),(x+.46,.79,2.22),(x,.79,2.22),
                    (x,-.84,1.87),(x+.46,-.84,1.87),(x+.46,.79,2.12),(x,.79,2.12)],
                   [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],key)
    if kind=='Cloth':
        for x,key in [(-.65,'Cloth'),(0,'Roof'),(.65,'Plaster')]:
            m.box((x,0,.89),(.50,.80,.17),key);m.box((x,-.5,.69),(.5,.07,.5),key)
        for x in [-.66,-.2,.28,.70]:prism(m,x,.35,1.00,.15,.15,.30,'Plaster',8)
    elif kind=='Herbs':
        for x in [-.7,0,.7]:
            prism(m,x,0,.81,.22,.22,.35,'RoofShade',8,.65)
            for dx,dy in [(-.12,0),(.1,-.1),(0,.13)]:prism(m,x+dx,dy,1.13,.13,.12,.28,'Herb',5,.12)
        for x in [-.55,0,.55]:
            m.beam((x,.55,2.12),(x,.55,1.74),.035,.035,'Timber')
            prism(m,x,.55,1.46,.18,.14,.28,'Grass',5,.1)
    else:
        m.box((0,.57,1.28),(2.2,.10,.13),'Timber')
        for x in [-.78,-.35,.1,.55]:blade(m,x,.50,.89,.85)
        for x in [-.5,.5]:
            prism(m,x,-.18,.82,.28,.25,.14,'Iron',8,.88)
            m.box((x,-.48,.78),(.43,.10,.50),'Iron')
        m.box((0,.62,2.0),(2.4,.36,.12),'TimberLight')
    finish(m,'Town_Stall'+kind)

glow=bpy.data.materials['M_MapLP_ForgeGlow'];node=glow.node_tree.nodes.get('Principled BSDF')
assert 'Emission Color' in node.inputs and 'Emission Strength' in node.inputs
node.inputs['Emission Color'].default_value=glow.diffuse_color;node.inputs['Emission Strength'].default_value=.7
export=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/export_map_static_fbx.py')['export_map_static_fbx']
bpy.context.view_layer.update();report=json.loads((ROOT/'Integration/town-models.json').read_text())
for obj in objects:
    assert all(p.area>1e-9 and not p.use_smooth for p in obj.data.polygons)
    report.append(dict(name=obj.name,dimensions_blender_xyz=list(obj.dimensions),triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),materials=[m.name for m in obj.data.materials],export=export(obj.name,str(ROOT/'Staging'/(obj.name+'.fbx')))))
(ROOT/'Integration/town-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
display=bpy.data.collections['TownLP_Display']
for i,source in enumerate(objects):
    obj=source.copy();display.objects.link(obj);obj.location=((i-1.5)*7,18,0)
masters.hide_render=True;masters.hide_viewport=True
scene.camera.location=(18,-28,29);scene.camera.rotation_euler=(Vector((0,8,1))-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.camera.data.ortho_scale=37
scene.render.filepath=str(ROOT/'Previews/town-kit.png')
bpy.data.libraries.write(str(ROOT/'Source/TownKit.blend'),{scene},path_remap='RELATIVE',fake_user=True,compress=True)
bpy.ops.render.render(write_still=True)
print(json.dumps(dict(models=len(report),added=[o.name for o in objects],preview=scene.render.filepath)))

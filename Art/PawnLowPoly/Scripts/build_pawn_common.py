"""战棋棋子的公共身体与模块化部件；通过 Blender MCP 执行，挂点是装备的局部原点。"""
import bpy
import math
import json
import runpy
from pathlib import Path
from mathutils import Vector

ROOT=Path('D:/Program/Unity/Project Y/Art/PawnLowPoly')
MeshBuilder=runpy.run_path('D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py')['MeshBuilder']
assert 'PawnLP_Studio' not in bpy.data.scenes, '已有棋子源作品，须定向编辑'
scene=bpy.data.scenes.new('PawnLP_Studio');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
masters=bpy.data.collections.new('PawnLP_Masters');scene.collection.children.link(masters)
objects=[]
def finish(m,name,slot):
    obj=m.finish('Pawn_'+name,masters);obj['attachment_slot']=slot;objects.append(obj)
def prism(m,x,y,z,rx,ry,height,material,sides=8,top=1):
    verts=[(x+math.cos(i*math.pi*2/sides)*rx*s,y+math.sin(i*math.pi*2/sides)*ry*s,z+h)
           for s,h in [(1,0),(top,height)] for i in range(sides)]
    faces=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]+[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    m.part(verts,faces,material)
def beam(m,start,end,width,material):
    a,b=Vector(start),Vector(end);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)))
    if u.length<.01:u=axis.cross(Vector((0,1,0)))
    u.normalize();v=axis.cross(u)
    verts=[tuple(c+width*(math.cos(i*math.pi/3)*u+math.sin(i*math.pi/3)*v)) for c in [a,b] for i in range(6)]
    m.part(verts,[tuple(reversed(range(6))),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)],material)

# 稍夸张的头、手、靴保持俯视可读；身体不与护甲或武器合网格。
m=MeshBuilder()
for x in [-.17,.17]:
    m.box((x,-.045,.235),(.25,.43,.22),'Timber')
    beam(m,(x,0,.34),(x,0,.82),.105,'Window')
prism(m,0,0,.76,.31,.175,.57,'Window',8,1.05)
m.box((0,-.005,1.31),(.18,.17,.16),'PlasterShade')
prism(m,0,0,1.36,.245,.205,.42,'PlasterShade',8,.86)
m.box((0,-.215,1.565),(.10,.085,.13),'PlasterShade')
for x in [-.093,.093]:m.box((x,-.203,1.615),(.048,.022,.035),'Timber')
for side in [-1,1]:
    beam(m,(side*.29,0,1.25),(side*.44,-.06,1.07),.105,'Window')
    beam(m,(side*.44,-.06,1.07),(side*.50,-.28,.98),.088,'PlasterShade')
    prism(m,side*.50,-.28,.90,.10,.10,.17,'PlasterShade',6)
finish(m,'Human','body')
m=MeshBuilder();prism(m,0,0,0,.69,.69,.10,'RockDark',20,.95)
prism(m,0,0,.10,.64,.64,.035,'TimberLight',20)
finish(m,'Base','base')

# 护甲均以胸部挂点为原点；肩部和腰缘是完整部件的一部分。
m=MeshBuilder();prism(m,0,0,-.27,.335,.215,.61,'RockLight',8,.97)
m.box((0,-.23,.04),(.40,.07,.32),'Stone')
for x in [-.34,.34]:prism(m,x,0,.16,.18,.22,.18,'Rock',6,.83)
m.box((0,-.015,-.245),(.67,.45,.12),'Timber');finish(m,'ArmorPlate','chest')
m=MeshBuilder();prism(m,0,0,-.27,.335,.21,.57,'TimberLight',8,.98)
m.box((0,-.225,.025),(.12,.055,.59),'Timber')
for x in [-.34,.34]:prism(m,x,0,.17,.15,.20,.12,'Timber',6)
finish(m,'ArmorLeather','chest')
m=MeshBuilder();prism(m,0,0,-.83,.38,.30,1.16,'Window',8,.88)
m.box((0,-.21,-.15),(.71,.07,.12),'TimberLight')
for x in [-.34,.34]:prism(m,x,0,.14,.18,.21,.17,'Window',6,.90)
finish(m,'ArmorRobe','chest')

# 头部挂点统一；头饰保留脸部可见区域，避免用一整块金属遮掉五官。
m=MeshBuilder();prism(m,0,0,.045,.27,.23,.21,'RockLight',8,.48)
for x in [-.22,.22]:m.box((x,.015,-.045),(.10,.30,.28),'Rock')
m.box((0,.17,-.005),(.39,.1,.28),'Rock');m.box((0,-.232,.035),(.05,.055,.23),'Stone')
finish(m,'Helmet','head')
m=MeshBuilder();prism(m,0,.05,.055,.28,.26,.20,'Timber',8,.65)
for x in [-.23,.23]:m.box((x,.055,-.035),(.095,.32,.29),'Timber')
m.box((0,.22,-.055),(.42,.10,.34),'Timber');finish(m,'Hood','head')
m=MeshBuilder();prism(m,0,0,.065,.39,.34,.065,'Window',10)
prism(m,0,.015,.13,.25,.22,.44,'Window',8,.06)
prism(m,0,0,.13,.255,.225,.075,'TimberLight',8)
finish(m,'MageHat','head')

# 手持件的原点都在手心。武器尖端朝上，明确为静态棋子姿态。
m=MeshBuilder();prism(m,0,0,-.10,.035,.035,.27,'Timber',6)
m.box((0,0,.18),(.32,.075,.055),'Stone')
m.part([(-.085,-.035,.21),(.085,-.035,.21),(.085,.035,.21),(-.085,.035,.21),(-.065,-.025,.89),(.065,-.025,.89),(.065,.025,.89),(-.065,.025,.89),(0,0,1.05)],
 [(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,8),(5,6,8),(6,7,8),(7,4,8)],'RockLight')
finish(m,'Sword','mainHand')
m=MeshBuilder();beam(m,(0,0,-.68),(0,0,1.08),.037,'TimberLight')
prism(m,0,0,1.07,.14,.14,.24,'WaterDeep',6,.1);prism(m,0,0,.99,.13,.13,.08,'Stone',6)
finish(m,'Staff','mainHand')
m=MeshBuilder()
points=[(.03,0,-.60),(.20,0,-.38),(.26,0,-.15),(.26,0,.15),(.20,0,.38),(.03,0,.60)]
for a,b in zip(points,points[1:]):beam(m,a,b,.035,'TimberLight')
beam(m,points[0],points[-1],.008,'Plaster');m.box((.265,0,0),(.07,.08,.19),'Timber')
m.vertices=[(x-.265,y,z) for x,y,z in m.vertices]
finish(m,'Bow','mainHand')
m=MeshBuilder();outline=[(-.31,.41),(.31,.41),(.34,.13),(.20,-.24),(0,-.43),(-.20,-.24),(-.34,.13)]
vertices=[(x,y,z) for y in [-.15,-.06] for x,z in outline]
faces=[tuple(reversed(range(7))),tuple(range(7,14))]+[(i,(i+1)%7,(i+1)%7+7,i+7) for i in range(7)]
m.part(vertices,faces,'RoofShade');m.box((0,-.165,.025),(.08,.035,.59),'Stone')
finish(m,'Shield','offHand')

# 背部附件独立，可被实际装备状态替换，身体与手持件无需重做。
m=MeshBuilder();m.part([(-.23,0,.23),(.23,0,.23),(-.39,.16,-.93),(.39,.16,-.93),(-.23,.055,.23),(.23,.055,.23),(-.39,.22,-.93),(.39,.22,-.93)],
 [(0,1,3,2),(6,7,5,4),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],'RoofShade')
finish(m,'Cape','back')
m=MeshBuilder();prism(m,.15,.10,-.52,.13,.13,.77,'Timber',8)
for x in [.06,.15,.24]:beam(m,(x,.10,-.40),(x,.10,.52),.018,'TimberLight');m.box((x,.10,.47),(.07,.04,.14),'Plaster')
finish(m,'Quiver','back')

bpy.context.view_layer.update()
report=[]
for obj in objects:
    assert all(p.area>1e-9 and not p.use_smooth for p in obj.data.polygons)
    report.append(dict(name=obj.name,slot=obj['attachment_slot'],dimensions_blender_xyz=list(obj.dimensions),triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),materials=[m.name for m in obj.data.materials]))
(ROOT/'Integration').mkdir(exist_ok=True)
(ROOT/'Integration/pawn-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(dict(models=len(report),body_height=1.78,sockets_unity=dict(mainHand=[-.50,.98,.28],offHand=[.50,.98,.28],head=[0,1.59,0],chest=[0,1.05,0],back=[0,1.13,-.20]))))

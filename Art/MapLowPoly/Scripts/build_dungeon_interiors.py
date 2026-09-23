"""通过 Blender MCP 制作地牢内部陈设；每件是落地原点、纯色硬边的独立网格。"""
import bpy
import json
import math
import runpy
from pathlib import Path

ROOT=Path('D:/Program/Unity/Project Y/Art/MapLowPoly')
MeshBuilder=runpy.run_path(str(ROOT/'Scripts/mesh_helpers.py'))['MeshBuilder']
assert 'MapLP_DungeonStudio' not in bpy.data.scenes, '已存在地牢作品，须定向修改，禁止覆盖'
scene=bpy.data.scenes.new('MapLP_DungeonStudio')
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
bpy.context.window.scene=scene
masters=bpy.data.collections.new('MapLP_DungeonMasters');scene.collection.children.link(masters)
objects=[]

def frustum(mesh,x,y,z,bottom,top,height,material,sides=8):
    ring=[(math.cos(2*math.pi*i/sides),math.sin(2*math.pi*i/sides)) for i in range(sides)]
    vertices=[(x+a*radius,y+b*radius,z+dz) for radius,dz in ((bottom,0),(top,height)) for a,b in ring]
    faces=[tuple(reversed(range(sides))),tuple(range(sides,sides*2))]
    faces.extend((i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides))
    mesh.part(vertices,faces,material)

def finish(mesh,name,radius):
    obj=mesh.finish('Dungeon_'+name,masters);obj['footprint_radius']=radius
    # 木箱包边也计入最低点，统一把完整网格落到地面。
    bottom=min(v.co.z for v in obj.data.vertices)
    for vertex in obj.data.vertices: vertex.co.z-=bottom
    objects.append(obj)

# 完整柱：宽柱础、八角柱身、两层柱头，不制作细砖缝。
m=MeshBuilder();m.box((0,0,.12),(1.18,1.10,.24),'RockDark')
frustum(m,0,0,.24,.53,.43,2.20,'Stone')
m.box((0,0,2.52),(1.04,1.04,.16),'Rock');m.box((0,0,2.70),(1.22,1.10,.20),'RockLight')
finish(m,'Pillar',0)

# 断柱顶部参差但每个面封闭，碎石保留在单格内。
m=MeshBuilder();m.box((0,0,.10),(1.15,1.10,.20),'RockDark')
frustum(m,0,0,.20,.45,.37,.74,'Stone')
m.box((-.16,.08,1.06),(.42,.48,.38),'Rock');m.box((.32,-.28,.20),(.42,.34,.4),'RockDark')
finish(m,'BrokenPillar',0)

# 祭台是完整七格占地物件，层级和几何标志承担识别，不靠贴图。
m=MeshBuilder();m.box((0,0,.10),(2.65,1.95,.20),'RockDark');m.box((0,0,.28),(2.25,1.55,.16),'Rock')
m.box((0,0,.63),(1.70,1.12,.54),'Stone');m.box((0,0,.96),(2.10,1.42,.14),'RockLight')
m.box((0,0,1.11),(.72,.56,.18),'RoofShade');finish(m,'Altar',1)

# 石棺具有收脚棺身和压顶，闭合结构不暗示当前未实现的开箱玩法。
m=MeshBuilder();m.box((0,0,.12),(1.55,2.70,.24),'RockDark');m.box((0,0,.58),(1.30,2.38,.68),'Stone')
m.box((0,0,.96),(1.48,2.57,.14),'RockLight');m.box((0,0,1.10),(.78,1.78,.10),'Rock')
finish(m,'Sarcophagus',1)

def crate(mesh,center,size):
    x,y,z=center;w,d,h=size
    mesh.box(center,size,'TimberLight')
    for dx in (-w*.39,w*.39): mesh.box((x+dx,y-d*.5-.015,z),(.10,.05,h+.04),'Timber')
    for dz in (-h*.39,h*.39): mesh.box((x,y-d*.5-.02,z+dz),(w+.03,.06,.09),'Timber')
m=MeshBuilder();crate(m,(-.23,0,.34),(.70,.88,.68));crate(m,(.35,.13,.25),(.48,.61,.5));crate(m,(-.23,.10,.94),(.60,.61,.52))
finish(m,'CrateStack',0)

# 火焰用少量橙色块面表达，没有点光源、粒子或额外运行时脚本。
m=MeshBuilder();frustum(m,0,0,0,.48,.40,.20,'RockDark');frustum(m,0,0,.20,.18,.14,.86,'Stone')
frustum(m,0,0,1.06,.22,.46,.20,'Timber');frustum(m,0,0,1.26,.37,.10,.45,'Roof')
frustum(m,-.08,0,1.53,.14,.025,.32,'Plaster');finish(m,'Brazier',0)

# 侧室废拱本身为不可通行的装饰占地，不把小门洞当作主通道入口。
m=MeshBuilder()
for x in (-1.25,1.25):
    m.box((x,0,.15),(.64,1.04,.30),'RockDark');m.box((x,0,1.04),(.50,.80,1.48),'Stone')
for i in range(7):
    a,b=i*math.pi/7,(i+1)*math.pi/7
    vertices=[(radius*math.cos(angle),y,1.78+radius*math.sin(angle))
              for y in (-.40,.40) for radius,angle in ((.99,a),(1.52,a),(1.52,b),(.99,b))]
    m.part(vertices,[(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'RockLight' if i%2 else 'Rock')
finish(m,'RuinedArch',1)

m=MeshBuilder();m.box((0,0,.77),(2.70,.70,.16),'TimberLight')
for x in (-.88,.88):
    m.box((x,0,.36),(.24,.58,.72),'Timber');m.box((x,0,.10),(.52,.73,.20),'Timber')
finish(m,'Bench',1)

bpy.context.view_layer.update()
report=[]
for obj in objects:
    assert all(not face.use_smooth and face.area>1e-9 for face in obj.data.polygons)
    assert min(v.co.z for v in obj.data.vertices)>=-1e-6
    report.append(dict(name=obj.name,dimensions_blender_xyz=list(obj.dimensions),footprint_radius=obj['footprint_radius'],
        triangles=sum(len(face.vertices)-2 for face in obj.data.polygons),materials=[m.name for m in obj.data.materials]))
(ROOT/'Integration/dungeon-interiors-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))

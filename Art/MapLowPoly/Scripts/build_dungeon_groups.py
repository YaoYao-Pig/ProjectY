"""通过 Blender MCP 制作多格地牢设施，成组轮廓与实际配置占地保持一致。"""
import bpy
import math
import json
import runpy
from pathlib import Path
from mathutils import Vector

ROOT=Path('D:/Program/Unity/Project Y/Art/MapLowPoly')
MeshBuilder=runpy.run_path(str(ROOT/'Scripts/mesh_helpers.py'))['MeshBuilder']
assert 'MapLP_DungeonGroupsStudio' not in bpy.data.scenes, '已有源作品，须定向编辑'
scene=bpy.data.scenes.new('MapLP_DungeonGroupsStudio');bpy.context.window.scene=scene
scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
masters=bpy.data.collections.new('MapLP_DungeonGroupsMasters');scene.collection.children.link(masters)
objects=[]
def finish(mesh,name):
    obj=mesh.finish('Dungeon_'+name,masters)
    # 宽设施为 19 格六边形占地保留边缘余量，长设施保留其完整跨度。
    if name not in ('SupplyCache','BrokenColonnade'):
        for v in obj.data.vertices: v.co.x*=.8;v.co.y*=.8
    bottom=min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices: v.co.z-=bottom
    objects.append(obj)
def stone(mesh,x,y,z,rx,ry,height,material='Rock',sides=7):
    ring=[(math.cos(2*math.pi*i/sides+.2),math.sin(2*math.pi*i/sides+.2)) for i in range(sides)]
    verts=[(x+a*rx*scale+.12*dz,y+b*ry*scale,z+dz) for scale,dz in [(1,0),(.78,height*.75),(.36,height)] for a,b in ring]
    faces=[tuple(reversed(range(sides))),tuple(range(sides*2,sides*3))]
    for level in range(2):
        for i in range(sides): faces.append((level*sides+i,level*sides+(i+1)%sides,(level+1)*sides+(i+1)%sides,(level+1)*sides+i))
    mesh.part(verts,faces,material)
def beam(mesh,start,end,radius,material='Timber'):
    a,b=Vector(start),Vector(end);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)))
    if u.length<.01: u=axis.cross(Vector((0,1,0)))
    u.normalize();v=axis.cross(u)
    verts=[tuple(center+radius*scale*(math.cos(i*math.pi/3)*u+math.sin(i*math.pi/3)*v)) for center,scale in [(a,1),(b,.6)] for i in range(6)]
    faces=[tuple(reversed(range(6))),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
    mesh.part(verts,faces,material)
def crate(mesh,x,y,z,w,d,h):
    mesh.box((x,y,z+h*.5),(w,d,h),'TimberLight')
    for dx in [-w*.38,w*.38]: mesh.box((x+dx,y-d*.5-.025,z+h*.5),(.13,.08,h),'Timber')
    for dz in [.13,h-.13]: mesh.box((x,y-d*.5-.04,z+dz),(w,.09,.16),'Timber')

# 坍塌处是连续的大体量石堆，低台与小碎石连成一片，远景也可读。
m=MeshBuilder();stone(m,0,0,0,3.15,2.7,.32,'RockDark')
for x,y,s,h in [(-1.6,-.4,1.25,2.3),(.2,.6,1.6,3.15),(1.8,-.4,1.05,1.5),(-.1,-1.8,.8,1),(-2,1.1,.65,1.2)]:
    stone(m,x,y,.16,s,s*.8,h,'RockLight' if x<0 else 'Rock')
finish(m,'RubbleMound')

# 13 格窄长货垛：完整组合而非重复单格模型。
m=MeshBuilder();m.box((0,0,.1),(7.5,1.48,.2),'Timber')
for x,y,z,w,d,h in [(-2.75,0,.2,1.45,1.30,1.2),(-1.2,0,.2,1.4,1.25,1.6),(-1.4,0,1.8,1.05,1,1),(.5,0,.2,1.65,1.35,.9),(2.35,0,.2,1.7,1.3,1.4)]:crate(m,x,y,z,w,d,h)
finish(m,'SupplyCache')

# 多层祭台带宽台阶、四角矮柱和明显的中央祭石，占 19 格。
m=MeshBuilder();m.box((0,0,.18),(5.8,5.1,.36),'RockDark');m.box((0,.28,.46),(4.9,4.35,.20),'Rock')
m.box((0,.55,.68),(4.0,3.75,.24),'Stone');m.box((0,.65,1.17),(2.45,1.55,.74),'RockLight')
m.box((0,.65,1.64),(2.9,1.9,.2),'RoofShade')
for x in [-2.3,2.3]:
    for y in [-1.65,1.65]: stone(m,x,y,.5,.36,.36,1.4,'Stone',6)
for i in range(3):m.box((0,-2.35-i*.32,.36-i*.08),(2.6,.65,.16),'RockLight')
finish(m,'RitualDais')

# 家族墓地共享石基，三口棺、石碑和低栏形成有用途的设施。
m=MeshBuilder();m.box((0,0,.13),(6.3,5.6,.26),'RockDark')
for x in [-2.05,0,2.05]:
    m.box((x,-.25,.64),(1.55,3.15,1.02),'Stone');m.box((x,-.25,1.24),(1.8,3.4,.18),'RockLight')
    m.box((x,2.1,1.10),(1.25,.42,1.94),'Rock');m.box((x,1.85,1.30),(.75,.12,.95),'RoofShade')
finish(m,'TombCluster')

# 根系和岩石同属一个占地组，避免细线状根须或透明贴图。
m=MeshBuilder();stone(m,0,0,0,3.1,2.9,.36,'Earth')
for x,y,h in [(-.85,.2,3.5),(1,.8,2.6),(.4,-.8,2.3)]:
    stone(m,x,y,.2,.57,.53,h,'Timber',6)
    for angle in [0,2.1,4.2]:
        end=(x+math.cos(angle)*1.75,y+math.sin(angle)*1.55,.25)
        beam(m,(x,y,.65),end,.3)
beam(m,(-.8,.2,2.1),(-2.2,-.4,2.75),.22)
stone(m,-1.5,-1.15,.16,1,.7,1.15,'Rock');stone(m,1.7,-.5,.15,.6,.8,.85,'Shore')
finish(m,'RootThicket')

# 书架与断墙形成 L 形陈设，外轮廓和色块承担识别。
m=MeshBuilder();m.box((0,0,.08),(6.2,5.4,.16),'RockDark')
for x in [-2.2,0,2.2]:
    m.box((x,1.7,1.45),(1.9,.7,2.9),'Timber')
    for z in [.35,1.2,2.05]:
        m.box((x,1.13,z),(2,.55,.16),'TimberLight')
        for j in range(5):m.box((x-.70+j*.34,1.4,z+.4),(.26,.47,.62+(.08 if j%2 else 0)),['RoofShade','Window','TimberLight'][j%3])
m.box((-2.55,-.65,.75),(.45,3.2,1.5),'Rock')
crate(m,.8,-1.3,.16,1.5,1.3,.85);finish(m,'BookArchive')

# 餐桌与两侧长凳共享长条铺地，不占用通道来补空旷感。
m=MeshBuilder();m.box((0,0,.06),(6.6,4.4,.12),'Earth')
m.box((0,0,1.08),(5.8,1.7,.25),'TimberLight')
for x in [-2,2]:
    m.box((x,0,.51),(.38,1.45,1.02),'Timber')
for y in [-1.55,1.55]:
    m.box((0,y,.63),(5.7,.66,.18),'TimberLight')
    for x in [-2.1,2.1]:m.box((x,y,.3),(.35,.6,.6),'Timber')
for x in [-1.4,1.15]:stone(m,x,0,1.20,.38,.28,.22,'Stone',6)
finish(m,'DiningSet')

# 13 格连柱廊的长基座上有完整柱、断柱和上梁，跨度大而轮廓不重复。
m=MeshBuilder();m.box((0,0,.15),(7.4,1.5,.30),'RockDark')
for x,h in [(-2.9,3.1),(0,3.1),(2.9,1.45)]:
    m.box((x,0,.48),(1.1,1.1,.36),'Rock');stone(m,x,0,.66,.39,.39,h-.66,'Stone',8)
    m.box((x,0,h+.11),(1.12,1.1,.22),'RockLight')
m.box((-1.45,0,3.45),(4.05,1.2,.42),'Rock');finish(m,'BrokenColonnade')

bpy.context.view_layer.update()
report=[]
for obj in objects:
    assert all(not p.use_smooth and p.area>1e-9 for p in obj.data.polygons)
    assert obj.data.uv_layers and min(v.co.z for v in obj.data.vertices)>=-1e-6
    report.append(dict(name=obj.name,dimensions_blender_xyz=list(obj.dimensions),triangles=sum(len(p.vertices)-2 for p in obj.data.polygons),materials=[m.name for m in obj.data.materials]))
(ROOT/'Integration/dungeon-groups-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))

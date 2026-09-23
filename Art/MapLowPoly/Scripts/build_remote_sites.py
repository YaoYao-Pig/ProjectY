"""经 Blender MCP 制作偏远地点：独立石拱地牢入口与低矮隐居房屋。"""
import bpy
import json
import math
import runpy
from pathlib import Path

ROOT = Path('D:/Program/Unity/Project Y/Art/MapLowPoly')
helpers = runpy.run_path(str(ROOT / 'Scripts/mesh_helpers.py'))
MeshBuilder = helpers['MeshBuilder']
assert 'MapLP_RemoteSitesStudio' not in bpy.data.scenes, '场景已存在，请检查后定向修改，不能重复创建'
scene = bpy.data.scenes.new('MapLP_RemoteSitesStudio')
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
bpy.context.window.scene = scene
masters = bpy.data.collections.new('MapLP_RemoteSitesMasters')
scene.collection.children.link(masters)
objects = []

def finish(mesh, name, usage):
    obj = mesh.finish(name, masters)
    obj['usage_zh'] = usage
    obj['suggested_footprint_radius'] = 0
    objects.append(obj)
    return obj

# 地牢不是房屋：粗石拱门、后退的暗洞、下行台阶与一侧破损石柱。
mesh = MeshBuilder()
for x in (-.49, .49):
    mesh.box((x, .03, .37), (.27, .58, .74), 'Rock')
    mesh.box((x, -.05, .10), (.31, .69, .20), 'RockDark')
for i in range(7):
    a, b = i * math.pi / 7, (i + 1) * math.pi / 7
    vertices = [(radius * math.cos(angle), y, .72 + radius * math.sin(angle))
                for y in (-.28, .33) for radius, angle in [( .36, a), (.65, a), (.65, b), (.36, b)]]
    mesh.part(vertices, [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],
              'RockLight' if i in (1,3,6) else 'Rock')
# 门洞有真实空隙，最内侧暗面只表现洞内深度，不制作室内关卡。
outline = [(-.36, .02), (.36, .02)] + [(.36*math.cos(i*math.pi/7), .72+.36*math.sin(i*math.pi/7)) for i in range(8)]
count = len(outline)
# 暗洞背板带厚度和封闭侧面，Unity 单面材质下也有明确向外法线。
faces = [tuple(reversed(range(count))), tuple(range(count, count*2))]
faces.extend((i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count))
mesh.part([(x,y,z) for y in (.32,.36) for x,z in outline], faces, 'Timber')
mesh.box((0,.0,.025), (.68,.62,.05), 'Timber')
for i in range(3):
    mesh.box((0, -.68+i*.19, .025*(3-i)), (.68, .22, .05*(3-i)), 'RockDark' if i%2 else 'Rock')
mesh.box((.51, .35, .71), (.24, .29, 1.42), 'RockDark')
mesh.box((.51, .36, 1.48), (.29, .31, .24), 'Rock')
mesh.box((-.51, .39, .25), (.27, .27, .50), 'RockDark')
mesh.box((-.62, -.30, .11), (.21, .21, .22), 'RockDark')
finish(mesh, 'Building_DungeonEntrance', '独立地牢：石拱入口、下行台阶、破损侧柱；无民居屋顶')

# 隐居矮屋：低墙、宽而低的屋顶、石基、深门洞。总高 1.05 米，明显低于民居。
mesh = MeshBuilder()
mesh.box((0,0,.075), (1.12,.98,.15), 'RockDark')
mesh.box((0,0,.385), (1.04,.88,.53), 'PlasterShade')
mesh.box((0,0,.65), (1.10,.94,.08), 'Timber')
a,b,eave,peak=.62,.56,.67,1.05
mesh.part([(-a,-b,eave),(a,-b,eave),(a,b,eave),(-a,b,eave),(0,-b,peak),(0,b,peak)],
          [(0,1,4),(2,3,5),(0,4,5,3),(1,2,5,4),(3,2,1,0)],
          ['PlasterShade','PlasterShade','Timber','TimberLight','Timber'])
mesh.box((-.12,-.454,.325), (.26,.035,.41), 'Timber')
mesh.box((.30,-.455,.43), (.16,.034,.13), 'Window')
mesh.box((.30,-.48,.345), (.20,.08,.035), 'TimberLight')
for x in (-.505,.505): mesh.box((x,-.453,.39), (.05,.045,.51), 'Timber')
mesh.box((-.12,-.54,.045), (.37,.19,.09), 'Rock')
finish(mesh, 'Building_SecludedCottage', '隐居群落矮屋：低墙、宽木屋顶与石基，单格完整建筑')

bpy.context.view_layer.update()
report = []
for obj in objects:
    assert all(not f.use_smooth and f.area > 1e-9 for f in obj.data.polygons)
    # 尖顶单位六边形内的所有顶点；屋檐和碎石也不得越格。
    for v in obj.data.vertices:
        x,y,z = v.co
        assert abs(x) <= math.sqrt(3)/2+1e-6 and abs(y)+abs(x)/math.sqrt(3) <= 1+1e-6, (obj.name, list(v.co))
        assert z >= -1e-6
    report.append({'name':obj.name,'dimensions_blender_xyz':list(obj.dimensions),
                   'triangles':sum(len(f.vertices)-2 for f in obj.data.polygons),
                   'materials':[m.name for m in obj.data.materials]})
(ROOT/'Integration/remote-sites-models.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))

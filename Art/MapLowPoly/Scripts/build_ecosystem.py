"""通过 Blender MCP 制作森林、雪地与地牢；保留原有资源场景。"""
import bpy
import json
import math
import runpy
from pathlib import Path

ROOT = Path('D:/Program/Unity/Project Y/Art/MapLowPoly')
helpers = runpy.run_path(str(ROOT / 'Scripts/mesh_helpers.py'))
helpers['PALETTE'].update(Forest='567747', ForestSide='425b3b', Leaf='557c43', LeafLight='709454',
                          Pine='3f6b57', PineLight='557c66', Snow='d7e4e6', SnowSide='a2b7ba', SnowCap='e8efea')
MeshBuilder = helpers['MeshBuilder']
assert 'MapLP_EcosystemStudio' not in bpy.data.scenes
scene = bpy.data.scenes.new('MapLP_EcosystemStudio')
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
bpy.context.window.scene = scene
masters = bpy.data.collections.new('MapLP_EcosystemMasters')
scene.collection.children.link(masters)
objects = []


def rings(mesh, center, layers, sides, materials, offset=0):
    """少边环面连接；冠层轻微偏心，避免所有树像同一根圆锥。"""
    x, y = center
    vertices = [(x + dx + radius * math.cos(offset + i * math.tau / sides),
                 y + dy + radius * math.sin(offset + i * math.tau / sides), z)
                for radius, z, dx, dy in layers for i in range(sides)]
    faces = [tuple(reversed(range(sides)))]
    colors = [materials[0]]
    for level in range(len(layers)-1):
        for i in range(sides):
            a, b = level*sides+i, level*sides+(i+1)%sides
            faces.append((a, b, b+sides, a+sides))
            colors.append(materials[(i+level) % len(materials)])
    faces.append(tuple(range((len(layers)-1)*sides, len(layers)*sides)))
    colors.append(materials[-1])
    mesh.part(vertices, faces, colors)


def finish(mesh, name, usage):
    obj = mesh.finish(name, masters)
    obj['usage_zh'] = usage
    obj['suggested_footprint_radius'] = 0
    objects.append(obj)
    return obj


for name, top, side in [('Hex_Forest', 'Forest', 'ForestSide'), ('Hex_Snow', 'Snow', 'SnowSide')]:
    mesh = MeshBuilder()
    mesh.hex_prism(1, -1, 0, top, side)
    finish(mesh, name, '精确六边形底块；颜色过渡由地貌配置控制')

mesh = MeshBuilder()
rings(mesh, (0, 0), [(.11, 0, 0, 0), (.075, 1.35, .025, 0)], 5, ['Timber'])
rings(mesh, (0, 0), [(.28, .85, 0, 0), (.64, 1.26, -.04, 0),
                     (.53, 1.72, .015, .035), (.08, 2, .06, .02)], 7, ['Leaf', 'LeafLight', 'Leaf'], .2)
finish(mesh, 'Tree_Broadleaf', '阔叶树：短树干与不对称块面树冠')

for snow in (False, True):
    mesh = MeshBuilder()
    rings(mesh, (0, 0), [(.095, 0, 0, 0), (.055, 1.9, 0, 0)], 5, ['Timber'])
    for level, (radius, base, top) in enumerate([(.66, .43, 1.54), (.53, .99, 2.02), (.37, 1.62, 2.5)]):
        rings(mesh, (0, 0), [(radius*.81, base, 0, 0), (radius, base+.09, 0, 0),
                            (.018, top, .02, -.015)], 7, ['Pine', 'PineLight'], level*.21)
        if snow:
            # 冠层上方覆盖积雪，底部保留深绿色裙边，远景仍可辨认树种。
            rings(mesh, (0, 0), [(radius*.88, base+.23, 0, 0),
                                (.019, top+.012, .02, -.015)], 7, ['Snow', 'SnowCap'], level*.21)
    tree = finish(mesh, 'Tree_SnowPine' if snow else 'Tree_Conifer', '覆雪松树' if snow else '常绿针叶树')
    if snow:
        for vertex in tree.data.vertices: vertex.co.z *= 2.5/2.512

# 地牢以破损石塔与黑色拱门识别；无室内、碰撞与玩法含义。
mesh = MeshBuilder()
rings(mesh, (0, .07), [(.58, 0, 0, 0), (.61, .20, 0, 0), (.51, 1.26, 0, 0)], 8,
      ['RockDark', 'Rock', 'RockDark'], math.pi/8)
for i in range(7):
    angle = i*math.tau/8
    mesh.box((.44*math.cos(angle), .07+.44*math.sin(angle), 1.30+(i%3)*.05),
             (.22, .22, .30+(i%3)*.05), 'RockLight' if i%2 else 'Rock')
# 暗色门洞覆盖塔的前立面，石拱框给出入口方向。
mesh.box((0, -.518, .43), (.44, .05, .70), 'Timber')
for i in range(6):
    angle = (i+.5)*math.pi/6
    mesh.box((.29*math.cos(angle), -.535, .76+.29*math.sin(angle)), (.14, .12, .18), 'RockLight')
for x in (-.29, .29): mesh.box((x, -.535, .42), (.15, .12, .68), 'RockLight')
mesh.box((0, -.64, .08), (.68, .32, .16), 'Rock')
mesh.box((.50, -.15, .14), (.24, .29, .28), 'RockDark')
dungeon = finish(mesh, 'Building_Dungeon', '地牢遗址：破损石塔、暗色拱门与少量碎石')
max_z = max(vertex.co.z for vertex in dungeon.data.vertices)
for vertex in dungeon.data.vertices: vertex.co.z *= 1.6/max_z

bpy.context.view_layer.update()
report = []
for obj in objects:
    assert all(not face.use_smooth and face.area > 1e-9 for face in obj.data.polygons)
    report.append({'name': obj.name, 'dimensions_blender_xyz': list(obj.dimensions),
                   'triangles': sum(len(face.vertices)-2 for face in obj.data.polygons),
                   'materials': [material.name for material in obj.data.materials]})
(ROOT/'Integration/ecosystem-models.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))

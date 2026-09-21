"""通过 Blender MCP 制作同系列城堡；不修改已有三种建筑或展示场景。"""
import bpy
import json
import math
import runpy
from pathlib import Path

ROOT = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
helpers = runpy.run_path(str(ROOT / "Scripts/mesh_helpers.py"))
MeshBuilder = helpers["MeshBuilder"]
assert "Building_Castle" not in bpy.data.objects
assert "MapLP_CastleStudio" not in bpy.data.scenes
scene = bpy.data.scenes.new("MapLP_CastleStudio")
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1
bpy.context.window.scene = scene
masters = bpy.data.collections.new("MapLP_CastleMasters")
scene.collection.children.link(masters)
mesh = MeshBuilder()


def octagon(x, y, radius, bottom, top, material):
    """八边形塔身保留硬边；不用大量圆柱分段。"""
    ring = [(x + radius * math.cos(math.pi / 8 + i * math.pi / 4),
             y + radius * math.sin(math.pi / 8 + i * math.pi / 4)) for i in range(8)]
    vertices = [(a, b, bottom) for a, b in ring] + [(a, b, top) for a, b in ring]
    faces = [tuple(reversed(range(8))), tuple(range(8, 16))]
    faces += [(i, (i+1)%8, (i+1)%8+8, i+8) for i in range(8)]
    mesh.part(vertices, faces, material)


def rotated_box(center, size, angle, material):
    start = len(mesh.vertices)
    mesh.box((0, 0, 0), size, material)
    c, s = math.cos(angle), math.sin(angle)
    cx, cy, cz = center
    mesh.vertices[start:] = [(cx+c*x-s*y, cy+s*x+c*y, cz+z) for x, y, z in mesh.vertices[start:]]


def facade_polygon(points_xz, y, thickness, material):
    count = len(points_xz)
    vertices = [(x, y-thickness/2, z) for x, z in points_xz]
    vertices += [(x, y+thickness/2, z) for x, z in points_xz]
    faces = [tuple(reversed(range(count))), tuple(range(count, count*2))]
    faces += [(i, (i+1)%count, (i+1)%count+count, i+count) for i in range(count)]
    mesh.part(vertices, faces, material)


# 一块完整石质地基；四角塔、墙与主堡都在同一模型内。
mesh.box((0, 0, 0.07), (3.35, 3.20, 0.14), "RockDark")
mesh.box((0, 0, 0.155), (3.22, 3.08, 0.07), "Stone")
mesh.box((0, 0, 0.20), (2.35, 2.15, 0.04), "City")

# 城墙高低层次留出中央主堡剪影，垛口用少量大块表现。
for y in (-1.15, 1.15):
    mesh.box((0, y, 0.84), (2.48, 0.23, 1.32), "Stone")
    mesh.box((0, y, 1.45), (2.48, 0.30, 0.15), "RockLight")
    for x in (-0.92, -0.46, 0, 0.46, 0.92):
        mesh.box((x, y, 1.63), (0.24, 0.30, 0.24), "Stone")
for x in (-1.23, 1.23):
    mesh.box((x, 0, 0.84), (0.23, 2.30, 1.32), "Stone")
    mesh.box((x, 0, 1.45), (0.30, 2.30, 0.15), "RockLight")
    for y in (-0.73, -0.24, 0.24, 0.73):
        mesh.box((x, y, 1.63), (0.30, 0.25, 0.24), "Stone")

# 前方低塔、后方高塔，八边形腰线与开放垛口形成中世纪要塞轮廓。
for x in (-1.23, 1.23):
    for y in (-1.15, 1.15):
        height = 1.98 if y < 0 else 2.38
        octagon(x, y, 0.43, 0.14, 0.31, "RockDark")
        octagon(x, y, 0.36, 0.28, height, "Stone")
        octagon(x, y, 0.40, height-0.17, height-0.02, "RockLight")
        octagon(x, y, 0.385, height-0.02, height+0.05, "RockDark")
        for i in range(8):
            angle = i*math.pi/4
            rotated_box((x+0.325*math.cos(angle), y+0.325*math.sin(angle), height+0.15),
                        (0.16, 0.20, 0.26), angle, "Stone")
        # 狭长箭窗放在平面中央，避免与八边形转角相交。
        mesh.box((x, y-0.337, height-0.65), (0.055, 0.014, 0.30), "Window")
        mesh.box((x+0.337, y, height-0.65), (0.014, 0.055, 0.30), "Window")

# 主堡高于城墙，红褐色双坡顶与已有城镇建筑保持同一系列。
mesh.box((0, 0.25, 1.29), (1.38, 1.35, 2.20), "PlasterShade")
mesh.box((0, 0.25, 0.41), (1.46, 1.43, 0.27), "Stone")
mesh.box((0, 0.25, 2.31), (1.47, 1.44, 0.17), "Stone")
mesh.ridge_roof(0.81, 0.79, 2.39, 3.25, y_offset=0.25)
for x in (-0.44, 0, 0.44):
    mesh.box((x, -0.439, 1.91), (0.18, 0.035, 0.36), "Stone")
    mesh.box((x, -0.462, 1.91), (0.095, 0.014, 0.265), "Window")
for y in (0.0, 0.50):
    mesh.box((0.705, y, 1.96), (0.033, 0.18, 0.37), "Stone")
    mesh.box((0.728, y, 1.96), (0.014, 0.09, 0.27), "Window")

# 拱门外框和闭合木门采用几何轮廓；只表示外观，不引入通行逻辑。
radius, spring = 0.31, 0.85
door = [(-radius, 0.19), (radius, 0.19), (radius, spring)]
door += [(radius*math.cos(i*math.pi/8), spring+radius*math.sin(i*math.pi/8)) for i in range(1, 9)]
facade_polygon(door, -1.282, 0.026, "Timber")
for i in range(8):
    a, b = i*math.pi/8, (i+1)*math.pi/8
    points = [(0.31*math.cos(a), spring+0.31*math.sin(a)),
              (0.43*math.cos(a), spring+0.43*math.sin(a)),
              (0.43*math.cos(b), spring+0.43*math.sin(b)),
              (0.31*math.cos(b), spring+0.31*math.sin(b))]
    facade_polygon(points, -1.30, 0.095, "RockLight")
for x in (-0.37, 0.37):
    mesh.box((x, -1.30, 0.52), (0.12, 0.095, 0.66), "RockLight")
for x in (-0.19, 0, 0.19):
    mesh.box((x, -1.312, 0.56), (0.021, 0.022, 0.71), "TimberLight")
for z in (0.37, 0.76):
    mesh.box((0, -1.322, z), (0.59, 0.018, 0.04), "TimberLight")
mesh.box((0, -1.47, 0.16), (0.81, 0.41, 0.10), "Stone")
mesh.box((0, -1.69, 0.07), (0.91, 0.25, 0.14), "RockLight")

# 一面简洁旗帜提高远景识别度，不增加新材质或细碎装饰。
mesh.box((0, 0.34, 3.46), (0.028, 0.028, 0.48), "Timber")
facade_polygon([(0.01, 3.65), (0.39, 3.65), (0.31, 3.51), (0.39, 3.37), (0.01, 3.37)],
               0.34, 0.016, "Roof")
castle = mesh.finish("Building_Castle", masters)
castle["suggested_footprint_radius"] = 1
castle["usage_zh"] = "中世纪城堡：四角塔、垛口城墙、拱门、主堡与旗帜"
bpy.context.view_layer.update()
assert all(not face.use_smooth and face.area > 1e-9 for face in castle.data.polygons)
print(json.dumps({"name": castle.name, "dimensions_blender_xyz": list(castle.dimensions),
                  "triangles": sum(len(face.vertices)-2 for face in castle.data.polygons),
                  "materials": [mat.name for mat in castle.data.materials]}))

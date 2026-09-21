import bpy
import json
import math
import runpy

helpers = runpy.run_path("D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py")
MeshBuilder = helpers["MeshBuilder"]
masters = helpers["master_collection"]()

# 七个标准格共边抵消后，按外边界生成整体网格；顶面三角形共享同一高度与材质。
edges = {}
for q, r in [(0, 0), (1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]:
    cx, cy = math.sqrt(3) * (q + r / 2), -1.5 * r
    ring = [(round(cx + math.cos(math.radians(30 + 60 * i)), 6),
             round(cy + math.sin(math.radians(30 + 60 * i)), 6)) for i in range(6)]
    for i, start in enumerate(ring):
        end = ring[(i + 1) % 6]
        key = tuple(sorted((start, end)))
        if key in edges:
            del edges[key]
        else:
            edges[key] = (start, end)
following = {start: end for start, end in edges.values()}
assert len(following) == len(edges)
start = min(following)
ring = [start]
cursor = following[start]
while cursor != start:
    assert cursor not in ring
    ring.append(cursor)
    cursor = following[cursor]
assert len(ring) == len(edges)
count = len(ring)
vertices = [(x, y, -1) for x, y in ring] + [(x, y, 0) for x, y in ring]
vertices.extend([(0, 0, -1), (0, 0, 0)])
faces, materials = [], []
for i in range(count):
    nxt = (i + 1) % count
    faces.extend([(count * 2, nxt, i), (count * 2 + 1, count + i, count + nxt),
                  (i, nxt, count + nxt, count + i)])
    materials.extend(["Earth", "City", "Earth"])
builder = MeshBuilder()
builder.part(vertices, faces, materials)
plot = builder.finish("CityPlot7", masters)
plot["footprint_radius"] = 1
plot["footprint_hexes"] = 7

# 同步首次建模时发现的民居外凸窗框尺寸，后续重建脚本已包含相同约束。
house = bpy.data.objects["Building_House"]
depth = max(vertex.co.y for vertex in house.data.vertices) - min(vertex.co.y for vertex in house.data.vertices)
for vertex in house.data.vertices:
    vertex.co.y *= 0.676 / depth
house.data.update()
bpy.context.view_layer.update()
print(json.dumps({"city_plot": plot.name, "boundary_segments": count,
                  "dimensions_xyz_blender": list(plot.dimensions),
                  "house_dimensions_xyz_blender": list(house.dimensions)}))

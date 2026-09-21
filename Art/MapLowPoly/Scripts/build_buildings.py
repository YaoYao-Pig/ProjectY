import bpy
import json
import runpy

helpers = runpy.run_path("D:/Program/Unity/Project Y/Art/MapLowPoly/Scripts/mesh_helpers.py")
MeshBuilder = helpers["MeshBuilder"]
masters = helpers["master_collection"]()
assert bpy.context.scene.name == "MapLP_Studio"


def front_window(mesh, x, y, z, width, height):
    # 深色窗面与单根窗棂，在俯视镜头中保留清楚的大形。
    mesh.box((x, y, z), (width + 0.038, 0.035, height + 0.038), "TimberLight")
    mesh.box((x, y - 0.021, z), (width, 0.016, height), "Window")
    mesh.box((x, y - 0.032, z), (0.016, 0.014, height), "Timber")


def side_window(mesh, x, y, z, width, height):
    mesh.box((x, y, z), (0.035, width + 0.038, height + 0.038), "TimberLight")
    mesh.box((x + 0.021, y, z), (0.016, width, height), "Window")
    mesh.box((x + 0.032, y, z), (0.014, 0.016, height), "Timber")


def front_door(mesh, y, bottom, width, height):
    mesh.box((0, y, bottom + height / 2), (width + 0.055, 0.04, height + 0.028), "TimberLight")
    mesh.box((0, y - 0.024, bottom + height / 2), (width, 0.018, height), "Timber")
    mesh.box((width * 0.28, y - 0.040, bottom + height * 0.46), (0.028, 0.022, 0.03), "Stone")


# 民居：高而窄的双坡屋顶、少量窗棂和可见的门，保持单格小尺度。
house = MeshBuilder()
house.box((0, 0, 0.04), (0.95, 0.63, 0.08), "Stone")
house.box((0, 0, 0.585), (0.87, 0.54, 1.03), "Plaster")
house.ridge_roof(0.52, 0.338, 1.10, 1.75)
for x in (-0.421, 0.421):
    house.box((x, -0.28, 0.60), (0.042, 0.03, 1.00), "TimberLight")
house.box((0, -0.29, 1.06), (0.90, 0.035, 0.052), "Timber")
house.beam((-0.474, -0.341, 1.115), (0, -0.341, 1.708), 0.035, 0.026)
house.beam((0, -0.341, 1.708), (0.474, -0.341, 1.115), 0.035, 0.026)
front_door(house, -0.281, 0.08, 0.21, 0.53)
front_window(house, -0.266, -0.286, 0.74, 0.105, 0.18)
front_window(house, 0.266, -0.286, 0.74, 0.105, 0.18)
front_window(house, 0, -0.340, 1.32, 0.10, 0.14)
side_window(house, 0.443, 0.01, 0.70, 0.17, 0.22)
# 门窗等凸出细节也纳入单格占地，整体进深保持在配置目标内。
house_depth = max(vertex[1] for vertex in house.vertices) - min(vertex[1] for vertex in house.vertices)
house.vertices = [(x, y * 0.676 / house_depth, z) for x, y, z in house.vertices]
house.finish("Building_House", masters)

# 工坊：较低坡度的大屋面、宽双扇门与方形烟囱，远景可与民居区分。
workshop = MeshBuilder()
workshop.box((0, 0, 0.045), (0.98, 0.63, 0.09), "Stone")
workshop.box((0, 0.008, 0.79), (0.91, 0.55, 1.42), "PlasterShade")
workshop.ridge_roof(0.52, 0.338, 1.50, 1.90)
for x in (-0.44, 0.44):
    workshop.box((x, -0.283, 0.79), (0.047, 0.032, 1.40), "Timber")
workshop.box((0, -0.286, 1.46), (0.93, 0.04, 0.055), "Timber")
front_door(workshop, -0.282, 0.09, 0.50, 0.72)
workshop.box((0, -0.321, 0.45), (0.022, 0.021, 0.72), "TimberLight")
workshop.box((0, -0.324, 0.31), (0.49, 0.018, 0.037), "TimberLight")
workshop.box((0, -0.324, 0.66), (0.49, 0.018, 0.037), "TimberLight")
front_window(workshop, 0, -0.281, 1.14, 0.32, 0.18)
side_window(workshop, 0.465, 0.01, 1.05, 0.22, 0.23)
workshop.box((0.265, 0.115, 1.795), (0.155, 0.18, 0.61), "RockDark")
workshop.box((0.265, 0.115, 2.08), (0.20, 0.225, 0.07), "Stone")
workshop.box((0.265, 0.115, 2.118), (0.11, 0.13, 0.012), "Timber")
workshop.finish("Building_Workshop", masters)

# 集会厅：七格建筑采用完整基座和宽阔主体，不拆成独立六边形房块。
hall = MeshBuilder()
hall.box((0, 0, 0.045), (3.00, 1.94, 0.09), "Stone")
hall.box((0, 0.025, 0.94), (2.77, 1.55, 1.72), "Plaster")
hall.ridge_roof(1.52, 0.95, 1.80, 2.80)
hall.box((0, -0.769, 0.25), (2.80, 0.05, 0.20), "PlasterShade")
hall.box((0, -0.775, 1.745), (2.84, 0.052, 0.082), "Timber")
for x in (-1.337, -0.67, 0.67, 1.337):
    hall.box((x, -0.764, 0.96), (0.065, 0.045, 1.56), "TimberLight")
for x in (-1.01, -0.675, 0.675, 1.01):
    front_window(hall, x, -0.779, 1.08, 0.19, 0.40)
for y in (-0.38, 0.37):
    side_window(hall, 1.39, y, 1.00, 0.24, 0.42)
front_door(hall, -0.779, 0.09, 0.43, 0.89)
hall.box((0, -0.822, 0.54), (0.025, 0.025, 0.86), "TimberLight")
hall.beam((-1.454, -0.952, 1.824), (0, -0.952, 2.770), 0.05, 0.035)
hall.beam((0, -0.952, 2.770), (1.454, -0.952, 1.824), 0.05, 0.035)
hall.box((0, -0.967, 2.18), (0.23, 0.025, 0.24), "Timber")
hall.box((0, -0.985, 2.18), (0.13, 0.02, 0.14), "PlasterShade")
for x in (-0.37, 0.37):
    hall.box((x, -0.919, 0.66), (0.072, 0.082, 1.14), "Timber")
hall.ridge_roof(0.49, 0.162, 1.22, 1.51, y_offset=-0.815)
hall.box((0, -0.92, 0.092), (0.83, 0.136, 0.055), "Stone")
hall.finish("Building_TownHall", masters)
bpy.context.view_layer.update()
print(json.dumps({obj.name: {"dimensions_xyz_blender": list(obj.dimensions),
                            "triangles": sum(len(face.vertices) - 2 for face in obj.data.polygons)}
                  for obj in masters.objects if obj.name.startswith("Building_")}))

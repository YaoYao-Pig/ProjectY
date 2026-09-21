import bpy
import json
import math
from pathlib import Path

root = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
masters = bpy.data.collections["MapLP_AssetMasters"]
epsilon = 2e-6
grass = bpy.data.objects["Hex_Grass"]
top = [vertex.co.copy() for vertex in grass.data.vertices if abs(vertex.co.z) < epsilon]
assert len(top) == 6
adjacency = []
for q, r in [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]:
    dx, dy = math.sqrt(3) * (q + r / 2), -1.5 * r
    distances = [min(math.hypot(vertex.x - (other.x + dx), vertex.y - (other.y + dy)) for other in top)
                 for vertex in top]
    matched = [distance for distance in distances if distance < epsilon]
    assert len(matched) == 2, (q, r, distances)
    adjacency.append({"q": q, "r": r, "matched_edge_endpoints": 2,
                      "max_endpoint_error_metres": max(matched)})

reference = sorted((round(vertex.x, 6), round(vertex.y, 6)) for vertex in top)
for name in ("Hex_Grass", "Hex_Rock", "Hex_Shore", "Hex_Riverbed", "Hex_City", "Hex_Water"):
    obj = bpy.data.objects[name]
    ring = sorted((round(vertex.co.x, 6), round(vertex.co.y, 6)) for vertex in obj.data.vertices if abs(vertex.co.z) < epsilon)
    assert ring == reference, name
    assert all(face.normal.z > 0.99 for face in obj.data.polygons if all(abs(obj.data.vertices[i].co.z) < epsilon for i in face.vertices))

plot = bpy.data.objects["CityPlot7"]
top_faces = [face for face in plot.data.polygons if face.normal.z > 0.99]
area = sum(face.area for face in top_faces)
expected_area = 7 * 3 * math.sqrt(3) / 2
assert abs(area - expected_area) < 2e-5
assert len(top_faces) == 18
with bpy.data.libraries.load(str(root / "Source/MapLowPoly.blend"), link=False) as (file_data, unused):
    source_scenes = list(file_data.scenes)
    source_objects = list(file_data.objects)
assert source_scenes == ["MapLP_Studio"], source_scenes
assert not {"Cube", "Light", "Camera"}.intersection(source_objects)
assert {obj.name for obj in masters.objects}.issubset(set(source_objects))
assert {"Cube", "Light", "Camera"} == {obj.name for obj in bpy.data.scenes["Scene"].objects}
result = {"same_height_adjacency": adjacency,
          "all_six_top_boundaries_identical": True,
          "city_plot7_area": area, "expected_seven_hex_area": expected_area,
          "city_plot7_top_triangles": len(top_faces),
          "source_scenes": source_scenes, "source_object_count": len(source_objects),
          "source_excludes_original_scene_objects": True, "original_scene_preserved": True}
(root / "verification.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
manifest_path = root / "asset_manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["checks"]["hex_neighbour_edges_match"] = True
manifest["checks"]["city_plot7_area_matches_union"] = True
manifest["checks"]["source_contains_only_own_scene"] = True
manifest["verification_report"] = "verification.json"
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result))

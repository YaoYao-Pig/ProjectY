import bpy
import json
import runpy
from pathlib import Path

ROOT = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
helpers = runpy.run_path(str(ROOT / "Scripts/mesh_helpers.py"))
MeshBuilder = helpers["MeshBuilder"]
assert "MapLP_Studio" not in bpy.data.scenes, "已有本套场景，请先检查而不是重复生成"
scene = bpy.data.scenes.new("MapLP_Studio")
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
bpy.context.window.scene = scene
masters = bpy.data.collections.new("MapLP_AssetMasters")
scene.collection.children.link(masters)

# 五类地块仅改变材质，不改变六边形边界，保证相邻格无缝拼接。
for name, top, side in [
    ("Hex_Grass", "Grass", "GrassSide"),
    ("Hex_Rock", "Rock", "RockDark"),
    ("Hex_Shore", "Shore", "Earth"),
    ("Hex_Riverbed", "Riverbed", "Earth"),
    ("Hex_City", "City", "Earth"),
]:
    mesh = MeshBuilder()
    mesh.hex_prism(1.0, -1.0, 0.0, top, side)
    mesh.finish(name, masters)

# 独立水面不绑定湖泊或河流玩法，顶面高度由地图水位控制。
water = MeshBuilder()
water.hex_prism(1.0, -0.035, 0.0, "Water", "WaterDeep")
water.finish("Hex_Water", masters)

# 山峰作为可拆装饰：底部留在单格内，地块本体依旧保持一致拼接边界。
mountain = MeshBuilder()
mountain.part([(-0.65, -0.30, 0), (-0.10, -0.68, 0), (0.62, -0.38, 0),
               (0.66, 0.27, 0), (0.12, 0.67, 0), (-0.60, 0.42, 0),
               (-0.21, -0.03, 1.32), (0.34, 0.16, 0.83), (-0.42, 0.25, 0.62)],
              [(5, 4, 3, 2, 1, 0), (0, 1, 6), (1, 2, 6), (2, 7, 6),
               (2, 3, 7), (3, 4, 7), (4, 6, 7), (4, 8, 6), (4, 5, 8),
               (5, 0, 8), (0, 6, 8)],
              ["RockDark", "RockDark", "Rock", "RockLight", "Rock", "RockDark",
               "RockLight", "Rock", "RockDark", "RockDark", "Rock"])
mountain.finish("Mountain_Cluster", masters)
scene["source_original_scene"] = "Scene"
print(json.dumps({"scene": scene.name, "created": [obj.name for obj in masters.objects],
                  "original_scene_objects": [obj.name for obj in bpy.data.scenes["Scene"].objects]}))

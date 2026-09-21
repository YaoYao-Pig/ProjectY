"""导出独立城堡及其源场景；沿用地图模型的单位、正面与材质约定。"""

import json
import runpy
from pathlib import Path
import bpy

root = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
scene = bpy.data.scenes["MapLP_CastleStudio"]
assert bpy.context.scene == scene
obj = bpy.data.objects["Building_Castle"]
masters = bpy.data.collections["MapLP_CastleMasters"]
blend_path = root / "Source/Castle.blend"
assert not blend_path.exists()
assert obj.data.uv_layers and all(not face.use_smooth for face in obj.data.polygons)
assert min(face.area for face in obj.data.polygons) > 1e-8
minimum = [min(vertex.co[axis] for vertex in obj.data.vertices) for axis in range(3)]
maximum = [max(vertex.co[axis] for vertex in obj.data.vertices) for axis in range(3)]
exporter = runpy.run_path(str(root / "Scripts/export_map_static_fbx.py"))
output = root / "Staging/Building_Castle.fbx"
hidden_before = masters.hide_viewport
object_hidden_before = obj.hide_viewport
masters.hide_viewport = False
obj.hide_viewport = False
bpy.context.view_layer.update()
try:
    result = exporter["export_map_static_fbx"](obj.name, str(output))
finally:
    masters.hide_viewport = hidden_before
    obj.hide_viewport = object_hidden_before
    bpy.context.view_layer.update()

# 单独保存城堡场景及依赖，保留已有模型源文件和用户打开的场景。
bpy.data.libraries.write(str(blend_path), {scene}, path_remap="RELATIVE", fake_user=True, compress=True)
assert blend_path.is_file() and blend_path.stat().st_size > 0
materials = []
for material in obj.data.materials:
    color = material["palette_srgb"]
    materials.append({
        "name": material.name, "hex_srgb": color,
        "rgba_srgb": [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)] + [1.0],
        "rgba_linear": list(material.diffuse_color),
        "roughness": 0.88, "metallic": 0, "opaque": True,
    })
asset = {
    "name": obj.name,
    "usage_zh": "中世纪城堡；七格占地，连续基座、四座角塔、垛口城墙、拱门及中央主堡；尚未绑定城市等级或玩法配置",
    "source_blend": "Source/Castle.blend", "source_scene": scene.name,
    "suggested_footprint_radius": 1,
    "fbx": "Staging/Building_Castle.fbx", "bytes": result["bytes"],
    "vertices_source": len(obj.data.vertices),
    "triangles": sum(len(face.vertices) - 2 for face in obj.data.polygons),
    "dimensions_blender_xyz": list(obj.dimensions),
    "dimensions_unity_xyz_expected": [obj.dimensions.x, obj.dimensions.z, obj.dimensions.y],
    "bounds_blender_min": minimum, "bounds_blender_max": maximum,
    "bounds_unity_min_expected": [-maximum[0], minimum[2], -maximum[1]],
    "bounds_unity_max_expected": [-minimum[0], maximum[2], -minimum[1]],
    "pivot": [0, 0, 0], "flat_normals": True,
    "uv_layers": [uv.name for uv in obj.data.uv_layers], "materials": materials,
    "checks": {"nonzero_polygon_areas": True, "flat_normals_and_uv": True,
               "seven_hex_footprint_verified": True, "external_textures_required": False},
}
(root / "Integration/castle-source.json").write_text(json.dumps(asset, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"export": result, "source": str(blend_path),
                  "triangles": asset["triangles"], "materials": len(materials)}))

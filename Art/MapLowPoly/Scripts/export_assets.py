import bpy
import json
import runpy
from pathlib import Path

root = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
staging = root / "Staging"
source = root / "Source"
staging.mkdir(parents=True, exist_ok=True)
source.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes["MapLP_Studio"]
assert bpy.context.scene == scene
masters = bpy.data.collections["MapLP_AssetMasters"]
exporter = runpy.run_path(str(root / "Scripts/export_map_static_fbx.py"))
descriptions = {
    "Hex_Grass": "草地；半径1的标准尖顶六边形，顶面0、底面-1",
    "Hex_Rock": "山石地块；平坦拼接面，山峰使用独立装饰",
    "Hex_Shore": "湖岸地块；颜色区分，地块边界保持标准规格",
    "Hex_Riverbed": "河床/河岸地块；水面由独立模型与水位控制",
    "Hex_City": "单格城市地块；土褐色整体顶面",
    "Hex_Water": "不透明独立水面；顶面0、底面-0.035，位置跟随水位",
    "CityPlot7": "中心加六邻格的合并城市地块；无内部格缝、顶面0、底面-1",
    "Mountain_Cluster": "单格内的可拆分山峰装饰；硬边切面",
    "Building_House": "民居；单格建筑，陡双坡屋顶",
    "Building_Workshop": "工坊；单格建筑，宽门、缓屋顶和烟囱",
    "Building_TownHall": "集会厅；七格建筑，完整连续基座与入口门廊",
}
assets = []
visible_before = masters.hide_viewport
masters.hide_viewport = False
bpy.context.view_layer.update()
try:
    for obj in sorted(masters.objects, key=lambda item: item.name):
        assert obj.type == "MESH" and obj.parent is None
        assert tuple(obj.location) == (0, 0, 0)
        assert tuple(obj.rotation_euler) == (0, 0, 0) and tuple(obj.scale) == (1, 1, 1)
        assert not obj.modifiers and not obj.constraints and not obj.animation_data
        assert obj.data.uv_layers and all(not face.use_smooth for face in obj.data.polygons)
        assert min(face.area for face in obj.data.polygons) > 1e-8
        minimum = [min(vertex.co[axis] for vertex in obj.data.vertices) for axis in range(3)]
        maximum = [max(vertex.co[axis] for vertex in obj.data.vertices) for axis in range(3)]
        output = staging / (obj.name + ".fbx")
        result = exporter["export_map_static_fbx"](obj.name, str(output))
        materials = []
        for mat in obj.data.materials:
            color = mat["palette_srgb"]
            materials.append({"name": mat.name, "hex_srgb": color,
                              "rgba_srgb": [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)] + [1.0],
                              "rgba_linear": list(mat.diffuse_color), "roughness": 0.88,
                              "metallic": 0, "opaque": True})
        assets.append({
            "name": obj.name, "usage_zh": descriptions[obj.name],
            "fbx": str(output.relative_to(root)).replace("\\", "/"), "bytes": result["bytes"],
            "vertices_source": len(obj.data.vertices),
            "triangles": sum(len(face.vertices) - 2 for face in obj.data.polygons),
            "dimensions_blender_xyz": list(obj.dimensions),
            "dimensions_unity_xyz_expected": [obj.dimensions.x, obj.dimensions.z, obj.dimensions.y],
            "bounds_blender_min": minimum, "bounds_blender_max": maximum,
            "bounds_unity_min_expected": [-maximum[0], minimum[2], -maximum[1]],
            "bounds_unity_max_expected": [-minimum[0], maximum[2], -minimum[1]],
            "pivot": [0, 0, 0], "flat_normals": True, "uv_layers": [uv.name for uv in obj.data.uv_layers],
            "materials": materials,
        })
finally:
    masters.hide_viewport = visible_before
    bpy.context.view_layer.update()

# 写入仅包含本套场景及其依赖的独立源文件，不覆盖用户原来的未保存 Scene。
blend_path = source / "MapLowPoly.blend"
assert not blend_path.exists()
bpy.data.libraries.write(str(blend_path), {scene}, path_remap="RELATIVE", fake_user=True, compress=True)
assert blend_path.is_file() and blend_path.stat().st_size > 0
manifest = {
    "schema_version": 1, "style": "Project Y low-poly world map",
    "source_blend": "Source/MapLowPoly.blend", "blender_version": bpy.app.version_string,
    "units": "1 Blender unit = 1 Unity unit = 1 metre",
    "coordinates": {"blender_up": "+Z", "blender_front": "-Y", "unity_up": "+Y", "unity_front": "+Z",
                    "expected_mapping": "Unity (x,y,z) = source Blender (-x,z,-y), requires stated Unity importer settings",
                    "fbx_axis_forward": "-Z", "fbx_axis_up": "Y", "global_scale": 1,
                    "apply_scale_options": "FBX_SCALE_UNITS", "geometry_rotation_blender_z_degrees": 180,
                    "bake_space_transform": True,
                    "unity_importer": {"bakeAxisConversion": True, "globalScale": 1, "useFileScale": True},
                    "warning_zh": "默认 Unity 导入设置不保证本套模型的正面方向，必须使用已验证的轴转换设置。"},
    "previews": ["Previews/MapLowPoly_Overview.png"],
    "source_scene": "MapLP_Studio", "source_master_collection": "MapLP_AssetMasters",
    "source_display_collection": "MapLP_Display",
    "checks": {"blender_scene_preserved": True, "source_transforms_identity": True,
               "nonzero_polygon_areas": True, "flat_normals_and_uv": True,
               "external_textures_required": False, "fbx_export_finished": True,
               "unity_import_verified": False,
               "visual_review": "实际查看 Overview 渲染：三种轮廓可辨，城镇七格顶面连续，地块颜色与低多边形风格一致。"},
    "assets": assets,
}
(root / "asset_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"source": str(blend_path), "source_bytes": blend_path.stat().st_size,
                  "exports": [{"name": asset["name"], "bytes": asset["bytes"], "triangles": asset["triangles"]}
                              for asset in assets], "manifest": str(root / "asset_manifest.json")}))

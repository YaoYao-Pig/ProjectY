import bpy
import json
import runpy
import hashlib
from pathlib import Path

root = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
manifest_path = root / "asset_manifest.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
exporter = runpy.run_path(str(root / "Scripts/export_map_static_fbx.py"))
source_blend = root / manifest["source_blend"]
blend_hash = hashlib.sha256(source_blend.read_bytes()).hexdigest()
exports = []

# Unity 已实测通过单模型探针后，才统一覆盖本套正式暂存文件。
for asset in manifest["assets"]:
    obj = bpy.data.objects[asset["name"]]
    coordinates_before = [tuple(vertex.co) for vertex in obj.data.vertices]
    result = exporter["export_map_static_fbx"](obj.name, str(root / asset["fbx"]), overwrite=True)
    assert obj.name == asset["name"]
    assert coordinates_before == [tuple(vertex.co) for vertex in obj.data.vertices]
    asset["bytes"] = result["bytes"]
    minimum, maximum = asset["bounds_blender_min"], asset["bounds_blender_max"]
    asset["bounds_unity_min_expected"] = [-maximum[0], minimum[2], -maximum[1]]
    asset["bounds_unity_max_expected"] = [-minimum[0], maximum[2], -minimum[1]]
    exports.append(result)

assert hashlib.sha256(source_blend.read_bytes()).hexdigest() == blend_hash
manifest["coordinates"].update({
    "expected_mapping": "Unity (x,y,z) = source Blender (-x,z,-y), requires stated Unity importer settings",
    "geometry_rotation_blender_z_degrees": 180,
    "bake_space_transform": True,
    "unity_importer": {"bakeAxisConversion": True, "globalScale": 1, "useFileScale": True},
    "warning_zh": "默认 Unity 导入设置不保证本套模型的正面方向，必须使用已验证的轴转换设置。",
})
manifest["checks"]["unity_axis_probe_verified"] = True
manifest["checks"]["source_preserved_after_axis_export"] = True
manifest["checks"]["unity_import_verified"] = False
manifest["export_script"] = "Scripts/export_map_static_fbx.py"
manifest["axis_probe_evidence"] = {
    "probe": "Probe/Building_House.fbx",
    "confirmed_by": "Unity importer check performed by root agent",
    "root_rotation": [0, 0, 0], "root_scale": [1, 1, 1],
    "house_bounds_center_z": 0.01932776,
    "house_dimensions_xyz": [1.04, 1.75, 0.676],
    "front": "+Z", "bakeAxisConversion": True,
}
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
(root / "axis_export_report.json").write_text(json.dumps({"source_blend_sha256": blend_hash, "exports": exports}, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"export_count": len(exports), "source_blend_unchanged": True,
                  "source_meshes_unchanged": True, "exports": exports}))

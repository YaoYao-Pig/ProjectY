import bpy
import json
from pathlib import Path

# 本步骤只导出轴向探针；源模型和已交付 FBX 均保持不变。
root = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
output = root / "Probe/Building_House.fbx"
output.parent.mkdir(parents=True, exist_ok=True)
assert not output.exists(), "禁止覆盖现存探针，先检查上次结果"
assert bpy.context.mode == "OBJECT"
source = bpy.data.objects["Building_House"]
assert tuple(source.rotation_euler) == (0, 0, 0)
assert tuple(source.scale) == (1, 1, 1)
original_selected = list(bpy.context.selected_objects)
original_active = bpy.context.view_layer.objects.active
probe_collection = bpy.data.collections.new("MapLP_AxisProbe")
bpy.context.scene.collection.children.link(probe_collection)
probe = source.copy()
probe.data = source.data.copy()
probe.name = "Building_House_Probe"
probe_collection.objects.link(probe)

# Unity 实测先前 -Y 门面落在 -Z，因此在导出副本上绕 Z 转 180 度。
# bake_space_transform 只用于这组无骨骼、无动画的静态网格。
for vertex in probe.data.vertices:
    vertex.co.x = -vertex.co.x
    vertex.co.y = -vertex.co.y
probe.data.update()
bpy.context.view_layer.update()
try:
    for obj in original_selected:
        obj.select_set(False)
    probe.select_set(True)
    bpy.context.view_layer.objects.active = probe
    result = bpy.ops.export_scene.fbx(
        filepath=str(output), check_existing=False,
        use_selection=True, object_types={"MESH", "EMPTY"},
        global_scale=1.0, apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z", axis_up="Y",
        use_space_transform=True, bake_space_transform=True,
        use_mesh_modifiers=True, use_triangles=True,
        mesh_smooth_type="OFF", add_leaf_bones=False,
        bake_anim=False, path_mode="RELATIVE", embed_textures=False,
    )
    assert result == {"FINISHED"} and output.stat().st_size > 0
    report = {"fbx": str(output), "bytes": output.stat().st_size,
              "source_object": source.name, "probe_object": probe.name,
              "geometry_rotation_blender_z_degrees": 180,
              "axis_forward": "-Z", "axis_up": "Y", "bake_space_transform": True,
              "use_space_transform": True, "global_scale": 1,
              "apply_unit_scale": True, "apply_scale_options": "FBX_SCALE_UNITS",
              "source_y_bounds": [min(v.co.y for v in source.data.vertices), max(v.co.y for v in source.data.vertices)],
              "probe_y_bounds": [min(v.co.y for v in probe.data.vertices), max(v.co.y for v in probe.data.vertices)],
              "expected_unity_front": "+Z", "unity_verified": False}
    (output.parent / "axis_probe.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report))
finally:
    # 探针对象只服务本次导出，不把技术性旋转混入可编辑源模型或展示布局。
    probe_mesh = probe.data
    bpy.data.objects.remove(probe, do_unlink=True)
    bpy.data.meshes.remove(probe_mesh)
    bpy.data.collections.remove(probe_collection)
    for obj in original_selected:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = original_active

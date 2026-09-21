import bpy
import json
from pathlib import Path

# 第二次只测试空间轴烘焙，不额外旋转源网格。
root = Path("D:/Program/Unity/Project Y/Art/MapLowPoly")
output = root / "Probe/House_BakedOnly.fbx"
assert not output.exists()
source = bpy.data.objects["Building_House"]
selected_before = list(bpy.context.selected_objects)
active_before = bpy.context.view_layer.objects.active
collection = bpy.data.collections.new("MapLP_BakedOnlyProbe")
bpy.context.scene.collection.children.link(collection)
probe = source.copy()
probe.data = source.data.copy()
probe.name = "House_BakedOnly"
collection.objects.link(probe)
bpy.context.view_layer.update()
try:
    for obj in selected_before:
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
              "geometry_rotation_blender_z_degrees": 0,
              "axis_forward": "-Z", "axis_up": "Y", "bake_space_transform": True,
              "use_space_transform": True, "global_scale": 1,
              "apply_unit_scale": True, "apply_scale_options": "FBX_SCALE_UNITS",
              "source_y_bounds": [min(v.co.y for v in source.data.vertices), max(v.co.y for v in source.data.vertices)],
              "expected_unity_front": "+Z", "unity_verified": False}
    (output.parent / "axis_probe_baked_only.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report))
finally:
    mesh = probe.data
    bpy.data.objects.remove(probe, do_unlink=True)
    bpy.data.meshes.remove(mesh)
    bpy.data.collections.remove(collection)
    for obj in selected_before:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = active_before

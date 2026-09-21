"""本套静态地图资源的导出预设；必须配合 Unity bakeAxisConversion=true 使用。"""

from pathlib import Path
import bpy


def export_map_static_fbx(source_name, output_path, *, overwrite=False):
    """只旋转导出副本，保留源对象与网格名称、变换、展示布局。"""
    output = Path(output_path)
    assert output.is_absolute() and output.suffix.lower() == ".fbx"
    assert output.parent.is_dir()
    if output.exists() and not overwrite:
        raise FileExistsError(output)
    assert bpy.context.mode == "OBJECT"
    assert abs(bpy.context.scene.unit_settings.scale_length - 1) < 1e-6
    source = bpy.data.objects[source_name]
    assert source.type == "MESH" and source.parent is None
    assert not source.modifiers and not source.constraints and not source.animation_data
    assert tuple(source.location) == (0, 0, 0)
    assert tuple(source.rotation_euler) == (0, 0, 0) and tuple(source.scale) == (1, 1, 1)
    source_mesh = source.data
    object_name, mesh_name = source.name, source_mesh.name
    assert "__MapLP_Source_" + object_name not in bpy.data.objects
    assert "__MapLP_Source_" + mesh_name not in bpy.data.meshes
    selected_before = list(bpy.context.selected_objects)
    active_before = bpy.context.view_layer.objects.active
    collection = bpy.data.collections.new("MapLP_ExportOnly")
    bpy.context.scene.collection.children.link(collection)
    export_obj = export_mesh = None
    try:
        # 临时让出稳定名称，导出文件内部不留下 Probe 或 .001 后缀。
        source.name = "__MapLP_Source_" + object_name
        source_mesh.name = "__MapLP_Source_" + mesh_name
        export_obj = source.copy()
        export_mesh = source_mesh.copy()
        export_obj.data = export_mesh
        export_obj.name = object_name
        export_mesh.name = mesh_name
        collection.objects.link(export_obj)
        export_obj["front_axis_blender"] = "+Y"
        export_obj["source_front_axis_blender"] = "-Y"
        for vertex in export_mesh.vertices:
            vertex.co.x = -vertex.co.x
            vertex.co.y = -vertex.co.y
        export_mesh.update()
        bpy.context.view_layer.update()
        for obj in selected_before:
            obj.select_set(False)
        export_obj.select_set(True)
        bpy.context.view_layer.objects.active = export_obj
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
        assert result == {"FINISHED"} and output.is_file() and output.stat().st_size > 0
        return {"path": str(output), "bytes": output.stat().st_size,
                "object": object_name, "mesh": mesh_name,
                "geometry_rotation_blender_z_degrees": 180,
                "bake_space_transform": True, "unity_bakeAxisConversion_required": True}
    finally:
        if export_obj is not None:
            bpy.data.objects.remove(export_obj, do_unlink=True)
        if export_mesh is not None:
            bpy.data.meshes.remove(export_mesh)
        bpy.data.collections.remove(collection)
        source.name, source_mesh.name = object_name, mesh_name
        for obj in selected_before:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = active_before


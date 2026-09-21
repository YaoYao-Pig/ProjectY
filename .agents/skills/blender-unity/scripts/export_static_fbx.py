"""Run inside Blender; export explicitly named static objects and restore selection."""

from pathlib import Path
import bpy


def export_static_fbx(object_names, output_path, *, overwrite=False):
    """Export meshes/empties only; caller owns geometry, transforms and unit choices."""
    if not object_names or len(set(object_names)) != len(object_names):
        raise ValueError("Provide a nonempty list of unique object names")
    if bpy.context.mode != "OBJECT":
        raise ValueError("Switch to Object Mode before exporting")
    output = Path(output_path)
    if not output.is_absolute() or output.suffix.lower() != ".fbx":
        raise ValueError("output_path must be an absolute .fbx path")
    if output.exists() and not overwrite:
        raise FileExistsError(output)
    if not output.parent.is_dir():
        raise FileNotFoundError(output.parent)
    if abs(bpy.context.scene.unit_settings.scale_length - 1.0) > 1e-6:
        raise ValueError("This static preset expects 1 Blender unit = 1 metre")

    objects = [bpy.context.view_layer.objects[name] for name in object_names]
    if not any(obj.type == "MESH" for obj in objects):
        raise ValueError("At least one mesh is required")
    for obj in objects:
        if obj.type not in {"MESH", "EMPTY"}:
            raise ValueError(f"Unsupported static export object: {obj.name}: {obj.type}")
        if obj.hide_select or not obj.visible_get():
            raise ValueError(f"Export object must be visible and selectable: {obj.name}")
        if obj.animation_data or any(mod.type == "ARMATURE" for mod in obj.modifiers):
            raise ValueError(f"Use a rig/animation-specific export for {obj.name}")
        if obj.matrix_world.determinant() <= 0:
            raise ValueError(f"Resolve mirrored or zero-scale transforms on {obj.name}")
    original_selected = list(bpy.context.selected_objects)
    original_active = bpy.context.view_layer.objects.active
    try:
        for obj in original_selected:
            obj.select_set(False)
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = next(obj for obj in objects if obj.type == "MESH")
        result = bpy.ops.export_scene.fbx(
            filepath=str(output), check_existing=False,
            use_selection=True, object_types={"MESH", "EMPTY"},
            global_scale=1.0, apply_unit_scale=True,
            apply_scale_options="FBX_SCALE_UNITS",
            axis_forward="-Z", axis_up="Y",
            use_space_transform=True, bake_space_transform=False,
            use_mesh_modifiers=True, use_triangles=True,
            mesh_smooth_type="OFF", add_leaf_bones=False,
            bake_anim=False, path_mode="RELATIVE", embed_textures=False,
        )
        if result != {"FINISHED"} or not output.is_file() or output.stat().st_size == 0:
            raise RuntimeError(f"FBX export did not finish: {result}")
        return {"path": str(output), "bytes": output.stat().st_size,
                "objects": [obj.name for obj in objects],
                "source_dimensions": {obj.name: list(obj.dimensions) for obj in objects},
                "blender_version": bpy.app.version_string}
    finally:
        for obj in objects:
            obj.select_set(False)
        for obj in original_selected:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = original_active

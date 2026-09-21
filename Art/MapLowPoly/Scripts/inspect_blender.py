import bpy
import json

# 先核实当前文件与节点接口，避免改动用户已有作品。
print(json.dumps({
    "file": bpy.data.filepath,
    "scenes": [scene.name for scene in bpy.data.scenes],
    "mode": bpy.context.mode,
    "engines": [item.identifier for item in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items],
    "version": bpy.app.version_string,
    "scene_units": bpy.context.scene.unit_settings.scale_length,
}))

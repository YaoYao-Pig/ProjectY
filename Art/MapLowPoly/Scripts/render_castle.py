"""单独渲染城堡；超时后先查输出，不重复建模。"""
import bpy
import json

assert bpy.context.scene.name == "MapLP_CastleStudio"
result = bpy.ops.render.render(write_still=True)
print(json.dumps({"result": sorted(result), "image": bpy.context.scene.render.filepath}))

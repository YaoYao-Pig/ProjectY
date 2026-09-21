import bpy
import json

# 单独执行渲染，便于超时后检查结果，避免重新创建资源。
assert bpy.context.scene.name == "MapLP_Studio"
result = bpy.ops.render.render(write_still=True)
print(json.dumps({"render_result": sorted(result), "path": bpy.context.scene.render.filepath}))

# 大地图地貌贴图与自然细节

五张原始贴图由内置 ImageGen 生成，保留完整输出并复制到 `Assets/GameFramework/Resources/MapGround/`：草地 Grass、林地 Forest、岩地 Rock、湿土卵石岸 Shore、积雪 Snow。源提示词、默认生成路径与项目资产路径见 [texture-prompts.json](texture-prompts.json)。

贴图为低对比手绘地表色，不烘焙固定水岸、六边形边框或植被阴影。Shader 使用跨格世界坐标、三角随机平铺、宏观斑块与地貌过渡弱化重复；不宣称原图边缘像素严格周期相等。植物由单独的程序化网格与动画 Shader 表现，地表图片不随风整体滑动。

导入合同为 512×512、RGBA32、sRGB、Repeat、Trilinear、mipmap、无 Read/Write，设置随各 PNG 的 `.meta` 保存。[import_map_ground.cs](../../Tools/Rendering/import_map_ground.cs) 原生 Editor 片段可重新应用并核对实际导入结果；C# 材质创建时也会校验，避免错误的数组层格式进入运行。

Lua 检查入口为 [map_groundcover.lua](../../Tools/Tests/map_groundcover.lua) 与 [map_render_snapshot.lua](../../Tools/Tests/map_render_snapshot.lua)。[导出脚本](../../Tools/Rendering/export_map_ground_preview.lua) 使用真实配置与散布实现生成 288 格六区美术展示夹具；它不是生产随机地图。输出为 [map-ground-layout.json](../../Docs/Previews/Rendering/map-ground-layout.json)。

[preview_map_ground.cs](../../Tools/Rendering/preview_map_ground.cs) 是 Edit Mode 原生预览片段：创建临时场景、复用实际渲染批次和真实 FBX，检查纹理数组、自然细节、重建/释放并捕捉 36 帧动画。只用临时材质时间，不保存用户场景或进入 Play；此文件的存在不代表已完成原生验收。

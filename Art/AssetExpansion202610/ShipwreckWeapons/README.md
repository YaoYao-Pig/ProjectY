# 雾礁号遗物 · 10 把武器

这一组为沉船扩充制作了正好 10 把具有独立轮廓的武器：潮痕短弯刀、齿浪登船刀、沉钟战锤、断链船锚斧、捕潮鱼叉、牡蛎剖心匕首、绞索重弩、海蛇反曲弓、守灯人法杖、盐雾短铳。使用原有项目的硬边低多边形与纯色哑光风格，共 10,400 三角面、16 种共享材质。

- `Source/ShipwreckWeapons.blend`：可编辑模型，独立 Scene，不包含或覆盖原用户场景。
- `Staging/`：10 个独立 FBX；主代理统一导入 `Assets/DynamicAsset/AssetExpansion202610/ShipwreckWeapons/`。
- `manifest.json` / `materials.json`：实际尺寸、三角面数、UV、导出参数及线性色/sRGB 调色板。
- `catalog.json` / `lore.md`：逐武器的原创中文背景，最短 182 汉字；故事特征对应三道潮痕、船钟空腔、断链、贝壳护手、绞盘与灯塔铜笼等可见造型。
- `References/reference_index.json`：14 张已搜索并亲看的游戏参考，记录来源页、原图 URL、归档路径和借鉴点；每把武器映射 2 张，不把参考图用作发行贴图。
- `Previews/overview.png`、`review_sheet_1.png`、`review_sheet_2.png`：总览与四视图联系表。各武器有独立正、侧、背、斜俯视图，船钟另有左端腔体检查，共 41 张单体图。
- `review.json` / `review.md`：逐项真实目视意见与修正记录；`mesh_qa.json` 为最小网格、资料完整性检查。
- `Scripts/build_shipwreck_weapons.py`：初次制作入口；只复用旧武器文件内的造型函数，从不调用旧批次 `build()`。最终弓弦及骨背修正已经写回此入口。

模型采用米制，主握持中心为本地原点、源对象零位移零旋转单位缩放。Blender +Z 向上、-Y 为展示正面；弓在 XZ 平面、朝 -X，弩和短铳朝 -Y。静态 FBX 沿用项目已核实的轴转换，Unity importer 必须开启 `bakeAxisConversion`。武器没有新增游戏属性、掉落、动作、握点配表或改装插槽；双手持握与角色体型的动态适配在接入时另行验证。

文学意象参照 William Morris 的中古奇幻小说 [The Water of the Wondrous Isles](https://www.gutenberg.org/cache/epub/8778/pg8778-images.html)，第一部第二十章与第二部第一章的魔法舟离岸、渡水与陌生岛屿。雾礁号及十件遗物的故事为本批次原创，不是对小说角色或情节的复刻。

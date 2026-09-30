# UIScrollList

关键词：无限滚动、虚拟列表、ScrollRect、CellTemplate、多模板、可变尺寸、对象池、列表刷新。

## 文档目录

正文：职责 / 接入与契约 / 生命周期 / 验证；关键入口：控制器 / 布局 / 使用文档。

## 正文

- `UI.UIScrollList` 继承 UIWidgetCtrl，经父控制器 `AddWidget(UIScrollList, reference)` 接入。它管理有限数据的可见项及分模板复用池；使用已有 ScrollRect，不新增 C# 组件、不修改业务 Prefab、不要求注册 Cell 的 PanelConfig。支持纵向单列、横向单行，非循环/网格列表。
- 绑定与控制器生命周期沿用 [UI](UI.md)。列表引用必须绑定 `ScrollRect`；content 是 viewport 的直接子节点，只启用一个滚动轴。模板引用必须绑定自身根 RectTransform 为 `Root`，且根物体预先禁用、尺寸为正。禁止其他布局组件驱动 Content/Cell 根尺寸位置。
- 父 Bind 中仅调用一次 Configure；templates 为名称到 LuaReference 的表，onBind 必填。多模板必填 getTemplate(index)；默认按模板宽高布局，可用 getSize(index,key,viewportWidth,viewportHeight) 返回每项宽高。尺寸预先计算，不自动测量绑定后的文本。
- 索引从 1 开始。SetItemCount 重建且默认回到开头；Reload 重建且默认保留像素偏移；RefreshItem 只更新已实例化项内容；ScrollTo(index,alignment) 立即定位，alignment 范围 0–1。数据排序、模板、尺寸变化必须重建。
- 滚动只查询缓存布局并处理可见项；元数据构建 O(N)，可见区用二分定位。overscan 默认 100 UI 单位；GetVisibleRange 包含预留区。视口变化自动重建并夹紧原像素偏移。
- Cell 暴露 reference/view/root/templateKey/index；离屏复用后可能代表另一项。onCreate 一实例一次，onBind 覆盖复用状态；onRecycle 时 index 已清空，旧索引由第二参数提供。回调禁止重入列表修改/生命周期或关闭父面板。
- 模板/数据归调用方，克隆实例归列表；Hide 移除滚动监听并回池，Show 复用，Dispose 释放所有实例及回调。各模板池按最大并发保留；不要把 Cell 作为稳定的数据身份缓存。
- 完整 Prefab 结构、Lua 示例、配置及限制见 [使用说明](../../Docs/UIScrollList.md)。

验证：`python -X utf8 Tools/Tests/run_lua.py Tools/Tests/ui_scroll_list.lua`，仅布局和控制器定向测试；Unity 边界使用替身，真实 Prefab、拖拽惯性和显示仍需单独验收。

## 关键入口

- [UIScrollList.lua](../../Lua/UI/UIScrollList.lua)：Configure / SetItemCount / Reload / RefreshItem / ScrollTo / 生命周期。
- [UIScrollListLayout.lua](../../Lua/UI/UIScrollListLayout.lua)：Build / Visible / ClampOffset，不依赖 Unity。
- [ui_scroll_list.lua](../../Tools/Tests/ui_scroll_list.lua)：可变尺寸、复用、横纵滚动、数据变动和资源释放定向检查。

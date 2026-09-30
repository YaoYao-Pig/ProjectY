# UIScrollList 使用说明

`require('UI.UIScrollList')` 是继承 `UIWidgetCtrl` 的 Lua UI 组件，使用 Unity `ScrollRect` 处理拖拽、惯性和滚动条。数据有起止，只实例化视口和预留区域内的 Cell；离屏实例按 CellTemplate 分池复用。支持纵向单列、横向单行，以及同一列表中的不同模板和不同宽高。

## Prefab 与绑定

推荐结构：

```text
Panel（LuaReference）
├─ ItemList（LuaReference、ScrollRect）
│  └─ Viewport（RectTransform、RectMask2D、可接收射线的 Graphic）
│     └─ Content（RectTransform）
└─ Templates
   ├─ ShortCell（禁用、RectTransform、LuaReference）
   └─ TallCell（禁用、RectTransform、LuaReference）
```

绑定如下；名称区分大小写：

| LuaReference | Key | Component |
| --- | --- | --- |
| Panel | `ItemList` | ItemList 的 LuaReference |
| Panel | `ShortTemplate` / `TallTemplate` | 两个 CellTemplate 的 LuaReference |
| ItemList | `ScrollRect` | ItemList 的 ScrollRect |
| 各 CellTemplate | `Root` | **该 LuaReference 所在物体本身**的 RectTransform |
| 各 CellTemplate | `Title` / `Button` 等 | 展示、交互需要的组件 |

- `ScrollRect.viewport`、`content` 必须显式设置，Content 必须是 Viewport 的直接子物体；只能启用 `vertical`、`horizontal` 中一个轴。通常选 `Clamped` 或 `Elastic` movementType。
- Content 的尺寸、锚点、pivot、位置由列表管理。不要在 Content 上使用 LayoutGroup、ContentSizeFitter，或让其他脚本驱动它的尺寸/位置。Content 只承载列表实例及可选的禁用模板。
- 模板也可使用独立 Prefab 引用，或放在 Content 下；根物体必须预先禁用。默认尺寸取 Configure 时模板根 RectTransform 的实际宽高，必须大于零；推荐固定尺寸，避免模板根拉伸导致尺寸依赖父节点。
- Cell 根的尺寸、位置、锚点、pivot 由列表管理，不应另挂驱动根尺寸的 ContentSizeFitter/布局逻辑。Cell 内部可以正常布局。
- 各 Cell 从左上角对齐，保留各自宽高；交叉轴不会自动拉伸，过宽/过高的 Cell 会被 Viewport 裁剪。需要铺满交叉轴时通过 `getSize` 返回对应尺寸。
- 绑定遵循项目 [UI 契约](../ForAI/Framework/UI.md)：业务代码使用 `self.view.Key` 和 `cell.view.Key`，不需要 GetComponent 或节点搜索。

这是可复用的 Lua 控制器，无需新增 C# MonoBehaviour，也不要求在 PanelConfig 注册 Cell。现有业务 Prefab 需按上述契约接入，本次未修改它们。

## 接入 Panel

在父 Panel/Widget 的 `Bind` 中创建并配置列表；`AddWidget` 接收类而非配置名称，会自动管理它的 Show/Hide/Update/Dispose。

```lua
local UIScrollList = require('UI.UIScrollList')

function Panel:Bind()
    self.rows = {}
    self.list = self:AddWidget(UIScrollList, self.view.ItemList)
    self.list:Configure({
        templates = {
            Short = self.view.ShortTemplate,
            Tall = self.view.TallTemplate,
        },
        spacing = 8,
        overscan = 100,
        padding = { left = 12, right = 12, top = 12, bottom = 12 },
        getTemplate = function(index)
            return self.rows[index].expanded and 'Tall' or 'Short'
        end,
        onCreate = function(cell)
            -- 每个实际实例仅执行一次。监听归列表 lifetime 管理。
            self.list:Listen(cell.view.Button, function()
                -- 从 cell.index 读取当前项，不捕获首次绑定的 index。
                local row = self.rows[cell.index]
                self:SelectRow(row) -- 业务自己的方法
            end)
        end,
        onBind = function(cell, index)
            -- 每次复用必须完整覆盖视觉状态，包括文字、图片、选中态等。
            cell.view.Title.text = self.rows[index].title
            cell.view.Button.interactable = self.rows[index].enabled
        end,
    })
end

function Panel:OnShow(args)
    self.rows = args.rows
    self.list:SetItemCount(#self.rows)
end
```

父控制器在 `OnShow` 后自动 Show 子组件，隐藏和释放也由框架完成。不要再次手动 Show/Dispose 已交给 AddWidget 的列表。尚未显示时可以 SetItemCount、Reload、ScrollTo；元数据和位置会更新，但不会创建 Cell。

## 同模板内不同尺寸

不传 `getSize` 时，每项使用选中模板的尺寸。传入它后，必须返回两个有限正数 `width, height`，单位是 RectTransform 的本地 UI 单位：

```lua
getSize = function(index, templateKey, viewportWidth, viewportHeight)
    local row = self.rows[index]
    -- 例如纵向列表铺满视口宽度（扣除左右 padding），高度来自业务计算。
    return math.max(1, viewportWidth - 24), row.height
end,
```

尺寸在构建布局前计算。列表不会实例化所有 Cell 去测量文本，也不会根据 onBind 后的 Cell 根尺寸反推布局；文本换行等自适应高度应预先计算，再通过 getSize 返回。视口宽高变化会自动重新查询模板和尺寸，保留并夹紧当前像素偏移。

## 接口

所有数据项索引从 **1** 开始；滚动顺序为从上到下或从左到右。

| 方法 | 行为 |
| --- | --- |
| `Configure(options)` | 仅一次，父 Bind 中、首次 Show 前调用 |
| `SetItemCount(count, keepPosition)` | 重建模板/尺寸元数据并刷新；默认回到开头，true 保留像素偏移；count=0 清空 |
| `Reload(keepPosition)` | 项数不变，重新查询模板/尺寸并绑定；默认保留像素偏移，false 回到开头 |
| `RefreshItem(index)` | 只重新绑定当前已实例化的该项；离屏项下次进入时读取最新数据；不重新计算模板/尺寸 |
| `ScrollTo(index, alignment)` | 立即跳转；0=项起始对齐视口起始，0.5=居中，1=项末尾对齐视口末尾；默认 0，受内容边界限制 |
| `GetVisibleCell(index)` | 获取当前借用的 Cell，离屏返回 nil；Cell 之后可能代表其他项，不要长期缓存其数据索引 |
| `GetVisibleRange()` | 返回已实例化范围，**包含 overscan**；空范围满足 first > last |

增删/重排数据后调用 SetItemCount；只改变模板或尺寸时调用 Reload；仅文字/颜色等变化可调用 RefreshItem。保留位置是保留**像素偏移**，不按数据 ID 跟踪滚动锚点；插入前部数据时业务可用 ScrollTo 定位。

## 配置与 Cell 生命周期

| 配置 | 说明 |
| --- | --- |
| `templates` | 必填，非空的 `模板名称 → LuaReference` 表 |
| `getTemplate(index)` | 多模板时必填；返回 templates 中的名称，单模板时可省略 |
| `getSize(index, templateKey, viewportWidth, viewportHeight)` | 可选，覆盖每项宽高 |
| `onBind(cell, index)` | 必填，每次项进入可见范围或刷新时调用 |
| `onCreate(cell)` | 可选，每个实例创建一次；适合设置长期事件监听 |
| `onRecycle(cell, oldIndex)` | 可选，离屏、重建、隐藏时调用；调用时物体已禁用，cell.index 已清空；用 oldIndex 或自己缓存的数据清理订阅 |
| `onDestroy(cell)` | 可选，Dispose 时每个实例调用一次，实际销毁前释放额外资源；列表 Listen 注册的监听此前已解绑 |
| `spacing` | 项间距，默认 0，无末尾额外间距 |
| `padding` | left/right/top/bottom，未填写项默认 0 |
| `overscan` | 视口前后各保留的 UI 距离，默认 100 |

Cell 提供 `reference`、只读绑定代理 `view`、`root`、`templateKey`、当前 `index`，可自行增加状态字段。模板和数据归调用方，实例归列表；列表隐藏时解除滚动监听并回收可见项，重开复用池，Dispose 销毁所有自建实例。池保留每种模板出现过的最大并发实例数量。

回调中不要调用列表的数据/定位/生命周期方法，也不要关闭其父面板，避免重入。onBind 应完整重置复用状态；异步图片等回调应核对当前项/版本，onRecycle 取消该项请求与订阅。尺寸/模板查询应无副作用，不能依赖实例已创建。

布局重建为 O(N) 时间/存储，日常滚动用二分查找定位范围，再只处理可见项；不在滚动时遍历全部数据。它是有限数据虚拟列表，不提供循环首尾连接、网格排列或网络分页加载；业务追加数据后使用 SetItemCount 更新。

## 最小验证

```text
python -X utf8 Tools/Tests/run_lua.py Tools/Tests/ui_scroll_list.lua
```

测试覆盖混合尺寸、横纵布局、间距/padding、二分可见范围、10000 项的有限实例复用、刷新/跳转、缩减与清空、视口变化、监听释放、回调失败清理。它使用真实 Lua 控制器与 Unity 边界替身，不代替 Unity 中的真实 Prefab、拖拽/惯性、遮罩和视觉验收。

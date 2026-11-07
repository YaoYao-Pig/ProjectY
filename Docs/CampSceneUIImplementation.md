# 远征营地场景与 UI 交付记录

日期：2026-10-27。对应[确认后的设计](CampSceneUIDesign.md)。已修改项目资源与运行代码，尚未进入 Play。

## 装备入库与建筑铭牌迭代

- 仓库现支持背包中的武器、防具和独立弹匣。枪内弹匣随枪保存；装备按原实例移动，保留耐久、词缀、配件、事迹与器灵。取出后再进行穿戴/改装。
- 角色/远征存档升级到31/32，旧网格兼容；新档校验装备引用与背包位置互斥，不能复制同一实例。
- 建筑标签采用可缩放的矢量皮革铭牌，新增切角铜边、缝线、铆钉和底部指向，提供普通/悬停/按下状态。
- 本轮集中请求一次 C# 编译；装备仓储、原堆叠仓储、独立堆/装备成长回归及真实 UI 装备拖拽/存档检查通过，Console 无错误。仍未进入 Play。

![普通铭牌](../Art/CampPresentation/Previews/camp-tag-0.png)
![悬停铭牌](../Art/CampPresentation/Previews/camp-tag-1.png)
![按下铭牌](../Art/CampPresentation/Previews/camp-tag-2.png)

![装备入库](../Art/CampPresentation/Previews/camp-warehouse-equipment.png)

## 已完成

- 营地入口由长列表改为固定相机的 3D 场景；工作台、熔炉、仓库、医务所均可点击打开叠层界面。
- 制作、锻造采用左侧列表与右侧真实模型/详情；制作页整合工位订单、等待和领取。锻造保留装备实例、配件与已有成长操作。
- 仓库采用左右双网格，整堆双向拖拽、指定落点、旋转、同类合并、失败回退；装备独立占格，同时保留 80/160/320 件容量。
- 仓储包含稳定堆、装备引用与持久位置；旧数量仓储按真实物品占格迁移，当前版本见上方迭代记录。
- 场景通过 Additive 加载，营地透明 RT 与主世界单独模糊合成；队员使用外观副本，不搬动世界角色，不加入战斗或导航控制。
- 四类设施各有 0/1/2 级外观，另有炊具篝火、根部与枝叶更细的背景树、不规则营地地面，共 15 件 FBX；源 `.blend` 保留。
- UI 复用项目 GuildMatte 切图，标题用思源宋体，数据/按钮用黑体；修正浅纸面的文字对比、配方选中态、材料卡和网格尺寸。所有新正式文案均接入语言表及原生绑定。

## 原生资源预览

以下来自真实 Unity 资源、实际控制器和配置数据的 Edit Mode 隔离宿主。主世界底景是中性测试背景，不是正在运行的远征。

![升级营地](../Art/CampPresentation/Previews/camp-level-2.png)

![制作与订单](../Art/CampPresentation/Previews/camp-production.png)

![双网格仓库](../Art/CampPresentation/Previews/camp-warehouse.png)

## 实际验证

- 主动请求一次项目 C# 编译；新类型加载成功，Console 无错误。存在与本次无关的 HudModeTransition 成员遮蔽警告。
- 营地规则检查通过，文案来源检查通过。
- 真实已编译 Data 检查通过：准确来源堆、独立仓储堆、显式合并、非法落点不变、旋转、容量、过期版本、白名单、保存往返及旧仓储安置。
- 生产检查通过：未完成/满包/不支持产物不改变订单；混合产物完整发放；重复领取不复制装备。
- 原生 UI 检查通过：建筑入口、建设、配方制作、等待、领取、锻造、两侧实际拖拽与指定坐标、升级外观、关闭和缓存重开、暂停释放、临时角色存档往返。
- Blender 与 Unity 已检查模型存在、导出、原生导入及视觉效果。Editor 原主场景保留，测试没有读取或覆盖玩家档案。
- 1280×720 与 1024×768 原生排版已检查；四个建筑中心射线均命中正确入口。15 件模型均为零根旋转、单位缩放、独立 URP 材质；6 个 LuaReference 入口和 10 个固定文案绑定检查通过。

## 尚未覆盖

- Play 中的异步 Additive 加载/快速连续开关、真实主世界后处理背景、正式游戏鼠标与 Esc 时序。
- 长时间运行的 RT/相机资源监测、性能采样及其余显示比例；未做 Player 构建或全量游戏回归。
- 队员当前复用既有外观与 idle 表现，没有新增专用坐姿、锤击或整理物资动画。

## 文件与维护

- [独立营地场景](../Assets/DynamicAsset/CampPresentation/Scenes/CampPresentation.unity)、[Camp Prefab](../Assets/DynamicAsset/UI/Prefabs/Camp/CampPanel.prefab)、[15 件模型](../Assets/DynamicAsset/CampPresentation/Models/)。
- [Blender 源文件](../Art/CampPresentation/Source/CampPresentation.blend)、[资源清单](../Art/CampPresentation/Integration/kit-manifest.json)。Art 沿项目规则不纳入 Git，导出模型与制作脚本位于 Assets/Tools。
- [重建与验证流程](../Tools/CampRework/README.md)、[当前业务契约](../ForAI/Business/Camp.md)。

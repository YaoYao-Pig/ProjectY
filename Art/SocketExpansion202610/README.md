# 分类槽位与配件扩充

已接入游戏：12件独立低多边形配件及模型图标，覆盖30把非staff武器、73个新挂点。Unity Prefab与四槽工坊已同步，172个真实C#装卸组合和原生第四槽交互通过；本轮未进入Play。

配件均为物理技能组件，使用对应分类槽位；命中率修正以百分点计，附加伤害是继续参与武器/技能倍率的基础值。完整武器组合、旧ID保留与四槽UI契约见[装备模块](../../ForAI/Business/Equipment.md)。

| ID | 名称 | 部位 | 实际作用 | 取舍／条件 |
| --- | --- | --- | --- | --- |
| 730 | 缠革稳握柄 | 握柄 `grip` | 命中＋10 | 伤害－5% |
| 731 | 护手织带 | 握柄 `grip` | 伤害命中后，自身护卫提升至至少2点，至自身下回合开始 | 不叠加，不降低已有更高护卫；与稳握柄择一 |
| 732 | 破势配重 | 柄尾 `pommel` | 伤害＋15% | 命中－5 |
| 733 | 汲血配重 | 柄尾 `pommel` | 伤害命中后恢复自身4生命，不消耗目标流血 | 目标受击后必须仍存活且流血 |
| 734 | 远猎弓臂 | 弓臂 `bowlimb` | 射程＋1格 | 伤害－10% |
| 735 | 强力弓臂 | 弓臂 `bowlimb` | 伤害＋20% | 命中－8 |
| 736 | 校准弓弦 | 弓弦 `bowstring` | 命中＋12 | 伤害－10% |
| 737 | 潮线弓弦 | 弓弦 `bowstring` | 伤害命中后40%施加3回合潮湿，扑灭燃烧并阻止点燃 | 概率触发；会移除希望保留的燃烧 |
| 738 | 破甲枪口 | 枪口 `muzzle` | 命中后追加1基础伤害；该伤害扣血时令身体甲、头盔、盾牌各损失12耐久 | 会损伤可能拾取的装备 |
| 739 | 分流枪口 | 枪口 `muzzle` | 总目标上限至少2人，默认追加主目标1格内合法目标 | 伤害－20%、命中－5；目标上限不相加 |
| 740 | 测距枪托 | 枪托 `stock` | 射程＋1格、命中＋6 | 伤害－10% |
| 741 | 复进枪托 | 枪托 `stock` | 物理技能冷却－1回合，最低0 | 伤害－5%；无CD基础射击不会额外获益 |

所有12件进入旅途杂货商店模板1独立补货；731、734、737、738进入现有加权掉落池5。数值源为[EquipmentRuneTable](../../Config/Tables/Equipment/EquipmentRuneTable.json)，触发动作源为[CombatEffectTable](../../Config/Tables/Adventure/CombatEffectTable.json)：731→1350、733→1358、737→1362、738→1359；未新增Buff类别。

## 制作与接入文件

- [模型源](Source/WeaponAttachments.blend)、[预览场景源](Source/WeaponAttachmentsPreview.blend)、[模型manifest](manifest.json)、[FBX暂存目录](Staging/)、[配件总览](Previews/contact-sheet.png)、[实际Unity装配预览](Previews/unity-installed.png)。导入后的米制包围盒记录在[资源验收](Integration/unity-import.json)。
- [建模脚本](Scripts/build_socket_attachments.py)、[导出与预览脚本](Scripts/export_preview.py)；模型单位为米，沿用项目FBX轴向转换及纯色材质约定，具体接触面/朝向见manifest。
- [新增挂点放置脚本](Scripts/place_sockets.py)、[实际Unity武器根局部bounds](Integration/weapon-bounds.json)。脚本只修改201–273，保留旧39条挂点，依据[Socket源表](../../Config/Tables/Equipment/EquipmentSocketTable.json)安排每侧最多两个标签。
- Unity目标目录为 `Assets/DynamicAsset/SocketExpansion202610`，每件对应 `Models/Socket_ID.fbx`、`Prefabs/Socket_ID.prefab`、`Icons/Item_ID.png`；绑定与图标须经正式编辑器工具保存，不能用手改YAML或运行时查找替代。
- [规则定向检查](../../Tools/Tests/weapon_socket_expansion.lua)覆盖原挂点身份、分类组合、物理组件结算、40%潮湿边界与获取引用。[原生装配检查](../../Tools/Tests/weapon_socket_expansion_integration.lua)及[模型验收片段](Integration/validate_unity.cs)覆盖30武器与172个兼容装卸组合；[四槽原生UI检查](../../Tools/Tests/workbench_four_slots_editmode.cs)覆盖真实第四按钮安装/卸下、4→2→3→4切换、引线显隐与标签间距。上述检查通过，主动集中编译一次，不操作玩家存档。

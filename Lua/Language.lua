-- Add literal fields inside this block. Export copies trailing comments into LuaTxt.desc.
-- LuaTxt takes priority; unexported new fields still work through these defaults.
local defaults = {
-- @localization-begin
    ProfessionNeedMaterial = "需要材料：%s ×%d", -- 职业技能材料不足；物品名称、数量
    ProfessionNeedsResonance = "目标需要持有余音。", -- 安可前置
    ProfessionEncoreUsed = "目标本轮已经受益于安可。", -- 安可每轮限制
    ProfessionMissingStatus = "自身没有可转移的所选状态。", -- 转祸状态选择无效
    ProfessionTransferImmune = "目标免疫或阻止此状态，无法转移。", -- 转祸免疫预校验
    ProfessionCannotSwap = "双方需要能够移动，且完整占位可以合法互换。", -- 护卫换位失败
    ProfessionChooseOtherAlly = "请选择另一名存活友军。", -- 承誓对象限制
    ProfessionNoLanding = "没有合法的落点。", -- 技能位移落点无效
    ProfessionSelectLanding = "选择目标后，请选择退步或救援落点。", -- 二阶段技能落点选择
    ProfessionNoLandingAction = "此技能不需要额外选择落点。", -- 错误的位移施放命令
    ProfessionOutsideRange = "目标超出技能距离。", -- 职业地格技能距离限制
    ProfessionInvalidTrapCell = "请在可见、无人占据的相邻地面放置绊索。", -- 绊索地格限制
    ProfessionInvalidSalvage = "请选择已记录实际材料投入的己方工事。", -- 应急拆料拒绝旧记录和非己方工事
    ProfessionOccupiedConstruction = "工事上仍有单位，不能拆除。", -- 应急拆料占位限制
    ProfessionNoRefundSpace = "背包没有空间存放返还木料。", -- 应急拆料返还事务预校验
    ProfessionEquipmentRequired = "当前装备不满足技能要求，请检查可用近战武器、弓或盾牌。", -- 职业技能装备限制
    ProfessionInterpose = "%s 为 %s 承受了这次攻击。", -- 承誓日志；护卫者、被保护者
    ProfessionSkillMove = "%s 完成技能位移。", -- 技能位移日志；单位名
    ProfessionTrapTriggered = "%s 触发绊索，剩余移动中止。", -- 绊索日志；单位名
    ProfessionSkillUsed = "%s 使用了 %s。", -- 职业地格技能日志；单位名、技能名
    ProfessionTripwireName = "绊索", -- 战场公开机关标识
    ProfessionDuelEnded = "礼式决斗已分出胜负。", -- 礼式决斗认输阈值结算日志
    StartOriginCaption = "选择身世，查看同行者与随身物资，再启程。", -- 新游戏身世页说明
    StartOriginCount = "开场身世 · %d 种", -- 身世列表标题
    StartOriginParty = "领队：%s\n同行：%s", -- 开场队伍；首位为领队，其余为同行者
    StartOriginSeparator = "、", -- 同行者分隔符
    StartOriginKit = "起始装备与补给", -- 身世开场物品区标题
    StartOriginCreate = "以「%s」启程", -- 按选中身世创建世界
    StartOriginEquipped = "自动装备", -- 开场主武器已在对应队员身上
    StartOriginCoins = "起始金币", -- 开场金币预览
    StartOriginInvalid = "请选择有效的开场。", -- Lua/C# 开场编号无效提示
    StartOriginUnknown = "未知开场：%s", -- Lua 格式；%s 为不存在的开场编号
    MissionObjective = "任务目标", -- 任务详情分段标题
    MissionPublisher = "委托人：%s  ·  地点：%s", -- 任务详情发布者与交付地点
    MissionRewards = "报酬预览", -- 任务详情显示预期报酬，实际变动由结算展示
    MissionRewardCoins = "金币", -- 金币奖励名称
    MissionRewardExperience = "经验", -- 经验奖励名称
    MissionRewardRecruit = "加入队伍", -- 招募奖励类型
    MissionRewardRelation = "好感变化", -- 好感奖励类型
    MissionRewardReputation = "声望变化", -- 声望奖励类型
    MissionRewardEachMember = "每位队员", -- 经验奖励数量按每位队员展示
    MissionRewardToInventory = "共享背包", -- 物品奖励去向
    MissionRewardShared = "队伍共用", -- 金币奖励去向
    MissionRewardItemGlyph = "物", -- 无插图物品的占位图标
    MissionSettlementTitle = "任务完成", -- 任务结算标题
    MissionSettlementReceived = "已获得以下奖励", -- 成功发奖后的结算说明
    MissionSettlementEmpty = "任务已完成，本次没有额外物品或经验奖励。", -- 无物质奖励的任务结算
    MissionSettlementNext = "下一份结算（%d）", -- 连续任务结算数量
    MissionSettlementSaved = "奖励已发放，确认后继续冒险", -- 结算确认不重复发奖
    MissionClaimHint = "目标已达成，领取后报酬才会到账。", -- 待领取任务提示
    MissionClaimedHint = "这份任务的报酬已领取。", -- 已领奖提示
    MissionStages = "任务进度", -- 阶段列表标题
    MissionAcceptHint = "接取后开始记录任务进度。", -- 可接任务提示
    Confirm = "确认", -- 通用确认按钮
    Cancel = "取消", -- 通用取消按钮
    RewardReceived = "已获得奖励", -- 领取奖励后的提示
    BattleEnemyTurn = "其他队伍正在行动…", -- 战斗 HUD
    BattleMainSpent = "本回合主要行动已使用", -- 战斗 HUD
    BattleNoAP = "行动点不足", -- 战斗 HUD
    BattleNoTarget = "没有可用目标：检查距离与视线", -- 战斗 HUD
    BattleActing = "行动中", -- 战斗 HUD
    BattleSpeed = "先攻 %d", -- 战斗 HUD
    BattleDown = "倒地", -- 战斗 HUD
    BattleHP = "生命 %d / %d", -- 战斗 HUD
    BattleRound = "第 %d 轮 / %d", -- 战斗 HUD
    BattleAP = "行动点  %d / %d AP", -- 战斗 HUD
    BattleResources = "护甲 %d  ·  格挡 %d\n移动 %s  ·  主要 %s", -- 战斗 HUD
    BattleSpent = "已用", -- 战斗 HUD
    BattleReady = "可用", -- 战斗 HUD
    BattleSkills = "技能", -- 战斗 HUD
    BattleItems = "物品", -- 战斗 HUD
    BattleEndTurn = "结束回合  ↵", -- 战斗 HUD
    BattleAdvanceAI = "推进 AI 回合", -- 战斗 HUD
    BattleMove = "移动  [Esc]", -- 战斗 HUD
    BattleFocus = "定位战场  [F]", -- 战斗 HUD
    BattleAutoOn = "AI 自动行动：开", -- 战斗 HUD
    BattleAutoOff = "AI 自动行动：关", -- 战斗 HUD
    BattleHideLog = "收起战斗记录", -- 战斗 HUD
    BattleShowLog = "展开战斗记录", -- 战斗 HUD
    BattleMoveHint = "点击绿色地格移动；数字键 1—4 选择本页技能。", -- 战斗 HUD
    BattleTargetHint = "点击高亮角色施放技能。", -- 战斗 HUD
    BattleSelfHint = "点击当前角色施放技能。", -- 战斗 HUD
    BattleSkillCost = "%d AP  ·  %s  ·  射程 %d", -- 战斗 HUD
    BattleMain = "主要行动", -- 战斗 HUD
    BattleSecondary = "次要行动", -- 战斗 HUD
    BattleItemHint = "物品槽位\n当前仅展示配置图标，尚未接入背包与物品使用。", -- 战斗 HUD
    GrowthTitle = "同行者 · 旅人手记", -- 角色养成 UI
    GrowthNoTraits = "尚未留下印记", -- 角色养成 UI
    GrowthTraitHint = "冒险中的选择会带来特质，也可能改变已有特质。", -- 角色养成 UI
    GrowthJourneyHint = "经历会改变特质、唤醒潜力，也会打开新的道路。", -- 角色养成 UI
    GrowthChooseNode = "选择被动节点", -- 角色养成 UI
    GrowthLearned = "已研习 · ", -- 角色养成 UI
    GrowthInnate = "固有／装备 · ", -- 角色养成 UI
    GrowthStudy = "学习 · ", -- 角色养成 UI
    GrowthLearnAvailable = "选择一项研习 · 等级 ", -- 角色养成 UI
    GrowthKnownSkills = "已掌握的主动技能", -- 角色养成 UI
    GrowthLockedTree = "  ·  未解锁", -- 角色养成 UI
    GrowthAdjacent = "任一相邻", -- 角色养成 UI
    GrowthPrerequisites = "全部前置", -- 角色养成 UI
    DiceRequirement = "要求：%s", -- 检定要求，%s 为数值
    DiceTens = "十位", -- 骰子十位标签
    DiceUnits = "个位", -- 骰子个位标签
    DiceTenths = "十分位", -- 骰子小数第一位
    DiceHundredths = "百分位", -- 骰子小数第二位
    DiceSuccess = "检定成功", -- 检定结果
    DiceFailure = "检定失败", -- 检定结果
    BattleLogExpandedTitle = "战斗记录 · {0} 条", -- C# 格式，{0} 为记录条数
    BattleLogCollapsedTitle = "战斗记录 · 点击展开", -- 战斗日志标题
    InventorySearching = "搜索中…", -- 搜刮物品状态
    InventoryUnsearched = "未搜索", -- 搜刮物品状态
    InventoryDragLabel = "{0}  /  R 旋转", -- C# 格式，{0} 为拖动物品名
    SkillTooltipTitle = "技能说明", -- 技能浮窗
    SkillSynergyActive = "生效中", -- 技能协同状态
    SkillSynergyDiscovered = "已发现", -- 技能协同状态
    SkillTooltipScrollHint = "滚轮翻阅 · 点击下划线术语查看释义", -- 技能浮窗底部提示
    SkillTooltipTermHint = "点击下划线术语查看释义", -- 技能浮窗底部提示
    UILoadingSystemStage = "准备出发", -- Lua/UI/LoadingSystem.lua:28
    UICampSections = "等待生产", -- Lua/UI/Panel/CampCtr.lua:5
    UICampSections2 = "仓库存取", -- Lua/UI/Panel/CampCtr.lua:5
    UICampSections3 = "生产与领取", -- Lua/UI/Panel/CampCtr.lua:5
    UICampSections4 = "建设设施", -- Lua/UI/Panel/CampCtr.lua:5
    UICampHintText = "材料优先使用仓库；金币、材料或空间不足时，交易不改变资源。", -- Lua/UI/Panel/CampCtr.lua:38
    UICampCaptionText = "第 %d 天 %02d:%02d  |  %d 金币  |  仓库 %d/%d  |  生产订单 %d", -- Lua/UI/Panel/CampCtr.lua:19
    UICampTitleText = "远征营地", -- Lua/UI/Panel/CampCtr.lua:18
    UICharacterGrowthNextTreeTextText = "被动天赋", -- Lua/UI/Panel/CharacterGrowthCtr.lua:32
    UICharacterGrowthPreviousTreeTextText = "职业技能", -- Lua/UI/Panel/CharacterGrowthCtr.lua:32
    UICharacterGrowthAtlasTextText = "技能图鉴", -- Lua/UI/Panel/CharacterGrowthCtr.lua:32
    UICharacterGrowthHistoryTabTextText = "旅途经历", -- Lua/UI/Panel/CharacterGrowthCtr.lua:31
    UICharacterGrowthSkillsTabTextText = "职业与天赋", -- Lua/UI/Panel/CharacterGrowthCtr.lua:31
    UICharacterGrowthOverviewTabTextText = "属性加点", -- Lua/UI/Panel/CharacterGrowthCtr.lua:31
    UICharacterGrowthHistory = "每段经历记录发生日期、地点与同行者。", -- Lua/UI/Panel/CharacterGrowthCtr.lua:74
    UICharacterGrowthSkills = "拖动查看分支，点击技能预览释放；点击职业徽记进入职业树与兼职选择。", -- 职业技能树操作提示
    GrowthProfessionOverview = "职业之路", -- 已加入职业树标题
    GrowthProfessionTreeTitle = "职业之路 · %d 个职业", -- 职业树概况；%d=已加入职业数
    GrowthChooseProfession = "选择兼职职业", -- 兼职网格标题
    GrowthAddProfession = "添加兼职", -- 打开未加入职业的网格
    GrowthChooseNewProfession = "选择新职业", -- 添加兼职节点说明
    GrowthAvailableProfession = "尚未加入", -- 兼职网格节点状态
    GrowthCurrentProfession = "当前研习", -- 当前职业徽记状态
    GrowthJoinedProfession = "已加入", -- 已加入但未在研习的职业状态
    GrowthBackProfessionTree = "‹ 返回职业树", -- 从兼职网格返回职业树
    GrowthBackSkillTree = "‹ 返回技能树", -- 从职业树返回当前技能树
    GrowthStudyingProfession = "当前研习：%s", -- 职业树根说明；%s=职业名称
    GrowthJoinProfession = "加入并研习", -- 确认加入选中的兼职职业
    GrowthJoinProfessionDetail = "%s\n\n加入后开放该职业的技能目录与被动树。已学能力永久保留，加入不消耗学习机会，也不赠送初始技能。", -- 兼职说明；%s=职业配置说明
    GrowthProfessionGridDetail = "选择一枚职业徽记查看介绍，再点击“加入并研习”。", -- 网格尚未选中职业的说明
    GrowthProfessionTreeDetail = "点击已加入的职业进入它的技能树。\n\n不同职业共用角色等级与成长资源，已学能力保留。通过“添加兼职”加入新的职业。", -- 已加入职业树说明
    GrowthAllProfessionsJoined = "已加入全部职业，可从职业树切换当前研习职业。", -- 所有职业均已加入时的说明
    GrowthProfessionTreeHint = "点击职业徽记切换研习并打开技能树；“添加兼职”可选择新职业。", -- 职业树操作提示
    GrowthProfessionGridHint = "点选职业查看介绍，确认加入后开始研习；已有技能和天赋保留。", -- 兼职网格操作提示
    GrowthCourseAvailable = "可学习", -- 职业树节点：可消耗学习机会
    GrowthCourseLocked = "条件不足", -- 职业树节点：学习条件未满足
    GrowthCourseNoOpportunity = "机会不足", -- 职业树节点：条件满足但没有学习机会
    GrowthCourseOtherProfession = "其他职业", -- 职业树节点：跨职业的前置技能
    UICharacterGrowthSkills2 = "被动天赋消耗天赋点；右侧目录切换天赋树，选中节点后投入。", -- Lua/UI/Panel/CharacterGrowthCtr.lua:73
    UICharacterGrowthOverview = "属性点用于 + 加点；旅途印记中可查看特质、关系和荣誉。", -- Lua/UI/Panel/CharacterGrowthCtr.lua:72
    UICharacterGrowthSummaryText = "属性点 %s  /  天赋点 %s  /  学习机会 %s  /  潜力 %s", -- Lua/UI/Panel/CharacterGrowthCtr.lua:65；%s1=growth.AttributePoints，%s2=growth.TalentPoints，%s3=growth.PendingCount，%s4=growth.LockedPotential
    UICharacterGrowthHeroExperienceText = "已到达本阶段的顶点", -- Lua/UI/Panel/CharacterGrowthCtr.lua:63
    UICharacterGrowthHeroExperienceText2 = "经验 %s / %s", -- Lua/UI/Panel/CharacterGrowthCtr.lua:63；%s1=growth.Experience，%s2=nextLevel.experience
    UICharacterGrowthHeroHealthText = "生命  %s / %s", -- Lua/UI/Panel/CharacterGrowthCtr.lua:62；%s1=actor.HP，%s2=actor.MaxHP
    UICharacterGrowthHeroLevelText = "旅人  ·  等级 %s", -- Lua/UI/Panel/CharacterGrowthCtr.lua:61；%s1=growth.Level
    UICharacterGrowthBody = "尚未解锁 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:146
    UICharacterGrowthBody2 = "已开放 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:146
    UICharacterGrowthTitle = "当前 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:145
    UICharacterGrowthSkillTitleText = "天赋树目录 · %s 点可用", -- Lua/UI/Panel/CharacterGrowthCtr.lua:143；%s1=actor.Growth.TalentPoints
    UICharacterGrowthTalentDetailText = "可以投入", -- Lua/UI/Panel/CharacterGrowthCtr.lua:142
    UICharacterGrowthTalentNameText = "星火成途", -- Lua/UI/Panel/CharacterGrowthCtr.lua:141
    UICharacterGrowthInvestTextText = "投入 %s 天赋点", -- Lua/UI/Panel/CharacterGrowthCtr.lua:140；%s1=node.pointCost
    UICharacterGrowthInvestTextText2 = "无可选课程", -- Lua/UI/Panel/CharacterGrowthCtr.lua:195
    UICharacterGrowthTalentDetailText2 = "可切换研习职业，查看其他职业的课程。", -- Lua/UI/Panel/CharacterGrowthCtr.lua:194
    UICharacterGrowthTalentNameText2 = "当前职业暂无课程", -- Lua/UI/Panel/CharacterGrowthCtr.lua:194
    UICharacterGrowthInvestTextText3 = "暂不可学习", -- Lua/UI/Panel/CharacterGrowthCtr.lua:192
    UICharacterGrowthInvestTextText4 = "已经掌握", -- Lua/UI/Panel/CharacterGrowthCtr.lua:192
    UICharacterGrowthInvestTextText5 = "学习 · 消耗 1 次机会", -- Lua/UI/Panel/CharacterGrowthCtr.lua:192
    UICharacterGrowthTalentDetailText3 = "%s · %s\n\n%s%s", -- 职业技能详情；%s1=技能种类，%s2=学习状态，%s3=技能说明，%s4=触媒条件
    UICharacterGrowthKind = "主动技能", -- Lua/UI/Panel/CharacterGrowthCtr.lua:189
    UICharacterGrowthKind2 = "战前准备技能", -- Lua/UI/Panel/CharacterGrowthCtr.lua:189
    UICharacterGrowthBody3 = "主动技能 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:171
    UICharacterGrowthBody4 = "战前准备 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:171
    UICharacterGrowthTitle2 = "未满足 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:170
    UICharacterGrowthTitle3 = "可学习 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:170
    UICharacterGrowthTitle4 = "已掌握 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:170
    UICharacterGrowthBody5 = "%s 转职不赠送新技能。", -- Lua/UI/Panel/CharacterGrowthCtr.lua:162；%s1=profession.description
    UICharacterGrowthTitle5 = "转入职业 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:161
    UICharacterGrowthTitle6 = "正在研习 · ", -- Lua/UI/Panel/CharacterGrowthCtr.lua:161
    UICharacterGrowthInvestTextText6 = "在左侧选择职业", -- Lua/UI/Panel/CharacterGrowthCtr.lua:158
    UICharacterGrowthTalentDetailText4 = "转职后开放对应课程和天赋树。\n\n已掌握的技能与天赋保留，可自由组合。\n\n转职不消耗学习机会，也不赠送新技能。", -- Lua/UI/Panel/CharacterGrowthCtr.lua:157
    UICharacterGrowthTalentNameText3 = "选择研习职业", -- Lua/UI/Panel/CharacterGrowthCtr.lua:157
    UICharacterGrowthBody6 = "探索期间免费转职；已学能力永久保留，装备仍由属性与触媒要求决定。", -- Lua/UI/Panel/CharacterGrowthCtr.lua:155
    UICharacterGrowthTitle7 = "切换研习职业", -- Lua/UI/Panel/CharacterGrowthCtr.lua:154
    UICharacterGrowthTitle8 = "返回当前职业技能", -- Lua/UI/Panel/CharacterGrowthCtr.lua:154
    UICharacterGrowthTreeTitleText = "%s · 学习机会 %s", -- Lua/UI/Panel/CharacterGrowthCtr.lua:153；%s1=current.name，%s2=growth.PendingCount
    UICharacterGrowthHistorySummaryText = "留下 %s 段经历  ·  %s / %s", -- Lua/UI/Panel/CharacterGrowthCtr.lua:210；%s1=#all，%s2=self.historyPage，%s3=pages
    UIDialogueHintText = "滚动回看  ·  选择回应或让同行者接话", -- Lua/UI/Panel/DialogueCtr.lua:68
    UIDialogueTitle = "查看商品", -- Lua/UI/Panel/DialogueCtr.lua:62
    UIDialogueTitle2 = "<b>让 %s 接话</b>  <size=70%%>%s</size>", -- Lua/UI/Panel/DialogueCtr.lua:45；%s1=Rich.Escape(entry.name)，%s2=Rich.Escape(entry.cue)
    UIDialogueCaptionText = "%s  /  小队交谈", -- Lua/UI/Panel/DialogueCtr.lua:20；%s1=story.rules.factions:Get(npc.factionId).name
    UIEquipmentWorkbenchMessage = "点击挂点选择组件，点击库存弹匣选择弹种并装填；拖动旋转，滚轮缩放。维修可在背包选中装备后进行。", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:37
    UIEquipmentWorkbenchMessage2 = "已应用，装备与战斗参数已同步。", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:53
    UIEquipmentWorkbenchEffectsEffects1 = "每次耗弹 %s", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:190；%s1=skill.shots*skill.ammoPerShot
    UIEquipmentWorkbenchEffectsEffects12 = "奥术触媒已就绪", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:188
    UIEquipmentWorkbenchEffectsEffects13 = "射程 %d · 目标 %d · 冷却 %d 回合", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:185
    UIEquipmentWorkbenchEffectsEffects14 = "命中 %d%%  ·  伤害 ×%.2f", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:184
    UIEquipmentWorkbenchLinesLines1 = "装备技能", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:175
    UIEquipmentWorkbenchLinesLines12 = "备用弹药 %s", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:174；%s1=data:CountItem(loaded.AmmoItemId)
    UIEquipmentWorkbenchLinesLines13 = "弹匣", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:174
    UIEquipmentWorkbenchLinesLines14 = "已安装组件", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:172
    UIEquipmentWorkbenchR = "尚未获得 · 商店补货 / 搜刮", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:161
    UIEquipmentWorkbenchR2 = "已安装", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:161
    UIEquipmentWorkbenchR3 = "点击安装", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:161
    UIEquipmentWorkbenchR4 = "%s/%s 发", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:155；%s1=mag.Rounds，%s2=mag.Capacity
    UIEquipmentWorkbenchR5 = "弹匣 #%s", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:155；%s1=mag.Id
    UIEquipmentWorkbenchSocketTitleText = "此武器没有改装槽", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:150
    UIEquipmentWorkbenchSocketTitleText2 = "%s · 可安装组件", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:150；%s1=slot.name
    UIEquipmentWorkbenchRequirementsText = "已装备削弱：伤害 -%d%% · 命中 -%d", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:147
    UIEquipmentWorkbenchRequirementsText2 = "属性不足，无法装备", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:144
    UIEquipmentWorkbenchRequirementsText3 = "已满足要求", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:144
    UIEquipmentWorkbenchRequirementsText4 = "无属性限制", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:143
    UIEquipmentWorkbenchRequirementsText5 = "装备要求", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:143
    UIEquipmentWorkbenchR6 = "共享库存", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:132
    UIEquipmentWorkbenchR7 = "已装入武器", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:122
    UIEquipmentWorkbenchR8 = "备用", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:122
    UIEquipmentWorkbenchR9 = "%s/%s 发 · %s", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:122；%s1=mag.Rounds，%s2=mag.Capacity，%s3=data:MagazineWeapon(mag.Id)==0 and LuaLanguage.UIEquipmentWorkbenchR8 or LuaLanguage.UIEquipmentWorkbenchR7
    UIEquipmentWorkbenchR10 = " · 已装备", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:111
    UIEquipmentWorkbenchR11 = " · 背包", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:111
    UIEquipmentWorkbenchCategoryTextText = "全部武器", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:107
    UIEquipmentWorkbenchEquipTextText = "装备给 %s", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:91；%s1=self.stats:Template(actor).name
    UIEquipmentWorkbenchSubtitleText = "持有者：%s", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:90；%s1=self.stats:Template(self.system:Actor(weapon.OwnerActorId)).name
    UIEquipmentWorkbenchSubtitleText2 = "共享背包 · 未装备", -- Lua/UI/Panel/EquipmentWorkbenchCtr.lua:90
    UIGMSkillNameText = "请输入有效技能 ID（例如 201：驯服）", -- Lua/UI/Panel/GMCtr.lua:24
    UIGMTargetText = "%s  ·  等级 %s", -- Lua/UI/Panel/GMCtr.lua:22；%s1=self.gm.growth.stats:Template(actor).name，%s2=actor.Growth.Level
    UIGMResultText = "已获得「%s」", -- Lua/UI/Panel/GMCtr.lua:36；%s1=self.gm:Skill(id).name
    UIGMResultText2 = "升级完成：等级 %s", -- Lua/UI/Panel/GMCtr.lua:36；%s1=actor.Growth.Level
    UIGMResultText3 = "当前动作尚未结束，请稍后再试", -- Lua/UI/Panel/GMCtr.lua:34
    UIGMResultText4 = "请输入有效的整数技能 ID", -- Lua/UI/Panel/GMCtr.lua:31
    UIGMNpcCountText = "找到 %s 位 NPC", -- Lua/UI/Panel/GMCtr.lua:46；%s1=#rows
    UIGMNpcCountText2 = "没有匹配的 NPC", -- Lua/UI/Panel/GMCtr.lua:46
    UIGMResultText5 = "已到达「%s」附近。关闭 GM 后按 E 交谈。", -- Lua/UI/Panel/GMCtr.lua:59；%s1=self.gm.npcs.story.rules.npcs:Get(id).name
    GMWorldMapUnavailable = "请先创建或载入远征，再开启全图视野。", -- GM 开全图：尚未绑定世界地图时的失败原因
    GMRevealWorldSuccess = "已开启全图视野：大地图持续全亮，远处敌人可见。", -- GM 开全图：命令与面板的成功反馈
    UIGMRevealWorldText = "开全图", -- GM 面板开全图按钮
    UIGMRevealWorldHint = "大地图持续全亮，远处敌人可见。重新开局或读档后需再次开启。", -- GM 面板开全图作用范围与生命周期说明
    UIGMKillTargetText = "秒杀", -- GM 面板秒杀按钮；点击后选择场景中的一个目标
    UIGMKillTargetHint = "点选一个敌人或动物。\nEsc／右键取消。", -- GM 面板秒杀使用说明
    GMKillPickHint = "秒杀：点选一个敌人或动物 · Esc／右键取消", -- 场景点选秒杀目标时的提示
    GMKillRequiresScene = "请先进入战斗或小地图，再选择秒杀目标。", -- GM 秒杀：当前阶段没有可点选目标
    GMKillDialogueOpen = "请先结束当前对话，再选择秒杀目标。", -- GM 秒杀：对话期间禁止操作
    GMKillInvalidTarget = "请选择当前场景中的敌人或动物。", -- GM 秒杀：空白、无效 ID 或场景外目标
    GMKillProtectedTarget = "秒杀仅适用于敌人和野生动物，不能选择队友、盟友或已驯服动物。", -- GM 秒杀：拒绝不在范围内的单位
    GMKillAlreadyDefeated = "这个目标已经倒地。", -- GM 秒杀：重复操作不再触发伤亡或奖励
    GMKillBattleEnded = "战斗已经结束，请等待结算。", -- GM 秒杀：结束的战斗不再接收目标
    GMKillSuccess = "已秒杀「%s」。", -- GM 秒杀成功；%s=目标名称
    GMKillSource = "GM 秒杀", -- GM 致死伤害日志的来源及动作名称
    GMDiceOpen = "投骰子", -- GM 面板打开骰子组合页
    GMDiceTitle = "骰子组合", -- GM 骰子组合页标题
    GMDiceHelp = "可混合选择，合计 1～6 颗。\nD10 为 0～9；D100 为百分比十位骰（00、10…90）。", -- GM 骰子选择数量与特殊面值说明
    GMDiceSelectedCount = "已选 %d / %d 颗", -- GM 骰子数量；%d1=已选数量，%d2=最大数量
    GMDiceBack = "返回 GM", -- GM 骰子组合页返回按钮
    GMDiceClear = "清空组合", -- GM 骰子组合页清空按钮
    GMDiceThrow = "开始投掷", -- GM 骰子组合页投掷按钮
    GMDiceAdd = "+", -- GM 骰子数量增加按钮
    GMDiceRemove = "−", -- GM 骰子数量减少按钮
    GMDiceD4Label = "D4 · 1～4", -- GM 四面骰选择标签
    GMDiceD6Label = "D6 · 1～6", -- GM 六面骰选择标签
    GMDiceD8Label = "D8 · 1～8", -- GM 八面骰选择标签
    GMDiceD10Label = "D10 · 0～9", -- GM 十面骰选择标签
    GMDiceD12Label = "D12 · 1～12", -- GM 十二面骰选择标签
    GMDiceD20Label = "D20 · 1～20", -- GM 二十面骰选择标签
    GMDiceD100Label = "D100 · 00～90", -- GM 百分比十位骰选择标签
    GMDiceInvalidCombination = "骰子组合无效，请使用支持的骰子和非负整数数量。", -- GM 投骰子参数校验失败
    GMDiceCountRequired = "请选择 1～%d 颗骰子。", -- GM 骰子数量范围；%d=最大数量
    GMDiceRollBusy = "请先完成当前投掷，再投下一组骰子。", -- GM 拒绝在演出进行时重复提交
    GMDiceRollTitle = "GM · 自由投骰", -- GM 投掷演出标题
    GMDiceCombination = "组合：%s", -- GM 投掷演出说明；%s=数量与骰型组合
    GMDiceRollResult = "%s\n合计：%d", -- GM 自由投骰结果；%s=逐颗点数，%d=面值总和
    UIInventoryMessage = "已取消移动，物品保留原位", -- Lua/UI/Panel/InventoryCtr.lua:14
    UIInventoryMessage2 = "拖动收纳  ·  拖动时 R 旋转 / 右键取消  ·  拖到装备槽穿戴", -- Lua/UI/Panel/InventoryCtr.lua:50
    UIInventoryMessage3 = "已保存收纳与装备变更", -- Lua/UI/Panel/InventoryCtr.lua:58
    UIInventoryRepairTextText = "维修装备", -- Lua/UI/Panel/InventoryCtr.lua:90
    UIInventoryRepairTextText2 = "维修 · 铁件%d / 金币%d", -- Lua/UI/Panel/InventoryCtr.lua:90
    UIInventoryItemDetailText = "点击物品查看属性与品质\n\n拖动整理 · R 旋转\n装备后释放背包空间", -- Lua/UI/Panel/InventoryCtr.lua:83
    UIInventoryItemDetailText2 = "物品详情", -- Lua/UI/Panel/InventoryCtr.lua:83
    UIInventoryItemDetailText3 = "可在武器工坊中使用", -- Lua/UI/Panel/InventoryCtr.lua:82
    UIInventoryItemDetailText4 = "拖动至装备槽即可穿戴", -- Lua/UI/Panel/InventoryCtr.lua:82
    UIInventoryItemDetailText5 = "已穿戴 · %s", -- Lua/UI/Panel/InventoryCtr.lua:82；%s1=Model.slotNames[selected.slot]
    UIInventoryItemDetailText6 = "%d × %d 格 · 数量 %d", -- Lua/UI/Panel/InventoryCtr.lua:81
    UIInventoryItemNameText = "选择一件物品", -- Lua/UI/Panel/InventoryCtr.lua:80
    UIInventoryCapacityText = "%d × %d  /  已用 %d 格 · 剩余 %d 格", -- Lua/UI/Panel/InventoryCtr.lua:79
    UIInventoryActorStatsText = "生命 %d / %d\n", -- Lua/UI/Panel/InventoryCtr.lua:77
    UILootMessage = "已切换容器，可以整理位置或双向存取", -- Lua/UI/Panel/LootCtr.lua:21
    UILootText = "全部战利品 · 选择容器以整理或存入", -- Lua/UI/Panel/LootCtr.lua:40
    UILootMessage2 = "左右背包可双向拖拽，右侧也能整理位置。", -- Lua/UI/Panel/LootCtr.lua:31
    UILootMessage3 = "汇总中可领取；选择一个容器后可整理或存入物品。", -- Lua/UI/Panel/LootCtr.lua:31
    UILootCapacityText = "%d × %d  ·  已用 %d 格 / 剩余 %d 格", -- Lua/UI/Panel/LootCtr.lua:52
    UILootEmptyText = "这里没有可搜刮的物品", -- Lua/UI/Panel/LootCtr.lua:61
    UILootEmptyText2 = "空容器\n可从左侧背包拖入物品", -- Lua/UI/Panel/LootCtr.lua:61
    UILootSearchStatusText = "搜索完成  ·  剩余 %d 件  ·  可双向存取", -- Lua/UI/Panel/LootCtr.lua:60
    UILootSearchStatusText2 = "剩余 %d 件  ·  %d 件等待揭示  ·  滚轮浏览", -- Lua/UI/Panel/LootCtr.lua:60
    UILootItemDetailText = "选择已搜索的物品查看属性。\n\n拖入左侧背包即可领取。", -- Lua/UI/Panel/LootCtr.lua:70
    UILootItemNameText = "选择物品查看详情", -- Lua/UI/Panel/LootCtr.lua:69
    UILootReason = "已整理背包", -- Lua/UI/Panel/LootCtr.lua:88
    UILootReason2 = "已收入背包：%s", -- Lua/UI/Panel/LootCtr.lua:85；%s1=reason
    UIMainHudRestartTextText = "营地", -- Lua/UI/Panel/MainHudCtr.lua:37
    UIMainHudGrowthTextText = "养成", -- 主 HUD 常驻养成入口
    UIFactionEntry = "势力", -- 主 HUD 势力关系入口
    UIFactionTitle = "势力关系", -- 势力关系树标题
    UIFactionSubtitle = "选择势力，查看它与世界各方的关系", -- 势力关系树说明
    UIFactionPlayer = "我的小队", -- 势力关系树玩家节点
    UIFactionPlayerDescription = "小队与各方的关系会随声望和旅途中的选择改变。", -- 玩家根节点说明
    UIFactionRoot = "当前查看的势力", -- 关系树根节点标识
    UIFactionHome = "回到我的小队", -- 关系树重置根节点按钮
    UIFactionClose = "关闭  Esc", -- 势力关系树关闭按钮
    UIFactionAllied = "同盟", -- 直接外交关系
    UIFactionNeutral = "中立", -- 直接外交关系
    UIFactionHostile = "敌对", -- 直接外交关系
    UIFactionGroupCount = "%s · %d", -- 关系分枝标题：关系、数量
    UIFactionRelationValue = "%s    %+d", -- 势力节点：关系、当前关系值
    UIFactionEmpty = "暂无此类关系", -- 空关系分枝提示
    UIFactionUnknownName = "？？？", -- 从未进入视野的势力名称占位
    UIFactionUnknownHint = "尚未进入视野", -- 未发现势力不显示关系，也不可切换视角
    UIFactionUnknownTitle = "未发现势力", -- 关系树未知区域的预览标题
    UIFactionUnknownCount = "未发现势力 · %d", -- 未知势力区域标题与数量
    UIFactionHelp = "首次进入视野后揭示势力 · 点击已发现势力切换视角 · 滚动查看分枝 · 同盟关系不传递", -- 关系树底部操作提示
    UIMainHudSkillHintText = "生活技能 · 悬停查看说明", -- Lua/UI/Panel/MainHudCtr.lua:140
    UIMainHudSkillHintText2 = "点击场景中的目标释放技能 · Esc 取消", -- Lua/UI/Panel/MainHudCtr.lua:140
    UIMainHudSkillEmptyText = "点击左侧队员卡片进行选择", -- Lua/UI/Panel/MainHudCtr.lua:137
    UIMainHudSkillEmptyText2 = "尚未掌握生活技能，可在升级研习时学习。", -- Lua/UI/Panel/MainHudCtr.lua:137
    UIMainHudSkillActorText = "选择一位队员，查看拥有的技能", -- Lua/UI/Panel/MainHudCtr.lua:136
    UIMainHudSkillActorText2 = "%s · 技能", -- Lua/UI/Panel/MainHudCtr.lua:136；%s1=self.adventure.battle.stats:Template(actor).name
    UIMainHudNavigationTitleText = "附 近 与 目 的 地", -- Lua/UI/Panel/MainHudCtr.lua:86
    UIMainHudNavigationTitleText2 = "这 一 程，去 哪 里", -- Lua/UI/Panel/MainHudCtr.lua:86
    UIMainHudCoinsText = "%s  金币", -- Lua/UI/Panel/MainHudCtr.lua:85；%s1=model.coins
    UIMainHudTimeSpeedTextText = "速度 %s×", -- Lua/UI/Panel/MainHudCtr.lua:81；%s1=model.timeControl.speed
    UIMainHudClockDayText = "第 %s 天", -- Lua/UI/Panel/MainHudCtr.lua:156；%s1=minutes//1440+1
    UIMissionJournalCategories = "招募", -- Lua/UI/Panel/MissionJournalCtr.lua:5
    UIMissionJournalCategories2 = "支线", -- Lua/UI/Panel/MissionJournalCtr.lua:5
    UIMissionJournalCategories3 = "主线", -- Lua/UI/Panel/MissionJournalCtr.lua:5
    UIMissionJournalCategories4 = "基础", -- Lua/UI/Panel/MissionJournalCtr.lua:5
    UIMissionJournalCategories5 = "城镇委托", -- Lua/UI/Panel/MissionJournalCtr.lua:5
    UIMissionJournalFailed = "已失败", -- Lua/UI/Panel/MissionJournalCtr.lua:6
    UIMissionJournalCompleted = "已完成", -- Lua/UI/Panel/MissionJournalCtr.lua:6
    UIMissionJournalReady = "待交付", -- Lua/UI/Panel/MissionJournalCtr.lua:6
    UIMissionJournalActive = "进行中", -- Lua/UI/Panel/MissionJournalCtr.lua:6
    UIMissionJournalInactive = "可接取", -- Lua/UI/Panel/MissionJournalCtr.lua:6
    UIMissionJournalDescriptionDefaultText = "此分类下还没有可接取或已接取的任务。", -- Lua/UI/Panel/MissionJournalCtr.lua:95
    UIMissionJournalDetailTitleDefaultText = "暂无任务", -- Lua/UI/Panel/MissionJournalCtr.lua:95
    UIMissionJournalBody = "尚未激活任务阶段。", -- Lua/UI/Panel/MissionJournalCtr.lua:93
    UIMissionJournalBody2 = "这段旅程已经完成。", -- Lua/UI/Panel/MissionJournalCtr.lua:93
    UIMissionJournalBody3 = "靠近商队正在交战的位置后加入。", -- Lua/UI/Panel/MissionJournalCtr.lua:81
    UIMissionJournalTitle = "加入战斗，保护商队", -- Lua/UI/Panel/MissionJournalCtr.lua:81
    UIMissionJournalBody4 = "返回大地图后沿可行道路追上商队；到达附近再选择随行或参战。", -- Lua/UI/Panel/MissionJournalCtr.lua:76
    UIMissionJournalTitle2 = "赶往护送商队", -- Lua/UI/Panel/MissionJournalCtr.lua:76
    UIMissionJournalBody5 = "在大地图靠近商队后随行，遇袭时一同作战。", -- Lua/UI/Panel/MissionJournalCtr.lua:74
    UIMissionJournalBody6 = "小队正与商队一起移动，遇袭会进入战斗。", -- Lua/UI/Panel/MissionJournalCtr.lua:74
    UIMissionJournalBody7 = "商队在城外等待；出城后可随行。", -- Lua/UI/Panel/MissionJournalCtr.lua:74
    UIMissionJournalTitle3 = "随商队同行", -- Lua/UI/Panel/MissionJournalCtr.lua:73
    UIMissionJournalTitle4 = "离开商队，独立行动", -- Lua/UI/Panel/MissionJournalCtr.lua:73
    UIMissionJournalTitle5 = "领取任务奖励", -- Lua/UI/Panel/MissionJournalCtr.lua:63
    UIMissionJournalTitle6 = "交付委托并领取报酬", -- Lua/UI/Panel/MissionJournalCtr.lua:63
    UIMissionJournalTitle7 = "接取任务", -- Lua/UI/Panel/MissionJournalCtr.lua:63
    UIMissionJournalBody8 = "%s\n好感 %s · %s声望 %s\n%s · %s", -- Lua/UI/Panel/MissionJournalCtr.lua:54；%s1=Rich.Escape(npc.description)，%s2=story.data:GetValue('relation:'..npc.id)，%s3=Rich.Escape(story.rules.factions:Get(npc.factionId).name)，%s4=story.data:GetValue('reputation:'..npc.factionId)，%s5=Rich.Escape(location)，%s6=Rich.Escape(activity)
    UIMissionJournalTitle8 = " · 已入队", -- Lua/UI/Panel/MissionJournalCtr.lua:54
    UIMissionJournalActivity = "传奇路遇 · 接近后交谈", -- Lua/UI/Panel/MissionJournalCtr.lua:52
    UIMissionJournalLocation = "本地图没有该 NPC 的出生地点", -- Lua/UI/Panel/MissionJournalCtr.lua:51
    UIMissionJournalLocation2 = "大地图游荡", -- Lua/UI/Panel/MissionJournalCtr.lua:51
    UIMissionJournalDescriptionDefaultText2 = "关系、所属阵营与当前日程", -- Lua/UI/Panel/MissionJournalCtr.lua:48
    UIMissionJournalDetailTitleDefaultText2 = "同行者与城镇居民", -- Lua/UI/Panel/MissionJournalCtr.lua:48
    UIMissionJournalCompanionsTextText = "同行者", -- Lua/UI/Panel/MissionJournalCtr.lua:31
    UIMissionJournalCompanionsTextText2 = "返回任务", -- Lua/UI/Panel/MissionJournalCtr.lua:31
    UIMissionJournalCaptionText = "第 %d 天 · %02d:%02d", -- Lua/UI/Panel/MissionJournalCtr.lua:27
    UIMissionJournalTitleText = "任务手记", -- Lua/UI/Panel/MissionJournalCtr.lua:25
    UIMissionJournalTitleText2 = "居民委托", -- Lua/UI/Panel/MissionJournalCtr.lua:25
    UIShopHintText = "商品直接收入共享背包；售罄后需等待补货。", -- Lua/UI/Panel/ShopCtr.lua:30
    UIShopBody = "点击购买 1 件", -- Lua/UI/Panel/ShopCtr.lua:24
    UIShopBody2 = "%d 金币 / 件  ·  剩余 %d  ·  占格 %d × %d\n%s", -- Lua/UI/Panel/ShopCtr.lua:23
    UIShopBody3 = "商人正在等待补货，请下次再来。", -- Lua/UI/Panel/ShopCtr.lua:23
    UIShopName = "本期没有商品", -- Lua/UI/Panel/ShopCtr.lua:19
    UIShopCaptionText = "%s  |  持有 %d 金币  |  下次补货：第 %d 天", -- Lua/UI/Panel/ShopCtr.lua:17
    UIShopTitleText = "%s · 商品", -- Lua/UI/Panel/ShopCtr.lua:16；%s1=snapshot.name
    UISkillAtlasCloseTextText = "关闭  Esc", -- Lua/UI/Panel/SkillAtlasCtr.lua:35
    UISkillAtlasCloseTextText2 = "返回角色手记", -- Lua/UI/Panel/SkillAtlasCtr.lua:35
    UISkillAtlasText = "%s 项技艺", -- Lua/UI/Panel/SkillAtlasCtr.lua:63；%s1=#self.atlas:Nodes(row.id)
    UISkillAtlasLabel = "关联 · %s", -- Lua/UI/Panel/SkillAtlasCtr.lua:90；%s1=self.atlas.categories:Get(row.categoryId).name
    UISkillAtlasTreeTitleText = "%s / %s · 图鉴", -- Lua/UI/Panel/SkillAtlasCtr.lua:77；%s1=self.atlas.disciplines:Get(category.disciplineId).name，%s2=category.name
    UISkillAtlasPrerequisiteTitleText = "前置：任意掌握", -- Lua/UI/Panel/SkillAtlasCtr.lua:108
    UISkillAtlasPrerequisiteTitleText2 = "前置：全部掌握", -- Lua/UI/Panel/SkillAtlasCtr.lua:108
    UISkillAtlasPrerequisiteTitleText3 = "无前置技能", -- Lua/UI/Panel/SkillAtlasCtr.lua:108
    UISkillAtlasSearchSummaryText = "%s 项匹配结果", -- Lua/UI/Panel/SkillAtlasCtr.lua:125；%s1=#rows
    UIStartMenuHintText = "请输入 0–4294967295 的整数种子，或点击“随机种子”。", -- Lua/UI/Panel/StartMenuCtr.lua:37
    UIStartMenuCaptionText = "保存时间为本地时间；载入成功后，F5 更新所选存档。", -- Lua/UI/Panel/StartMenuCtr.lua:55
    UIStartMenuTitleText = "选择存档", -- Lua/UI/Panel/StartMenuCtr.lua:55
    UIStartMenuCaptionText2 = "新世界使用独立存档，不覆盖其他旅程。", -- Lua/UI/Panel/StartMenuCtr.lua:51
    UIStartMenuTitleText2 = "创建新世界", -- Lua/UI/Panel/StartMenuCtr.lua:51
    UIStartMenuCaptionText3 = "开始新的旅程，或继续已经保存的世界。", -- Lua/UI/Panel/StartMenuCtr.lua:49
    UIStartMenuTitleText3 = "远征", -- Lua/UI/Panel/StartMenuCtr.lua:49
    UIStartMenuBody = "种子 %s  ·  %s\n%s", -- Lua/UI/Panel/StartMenuCtr.lua:78；%s1=tostring(saved.Seed)，%s2=size，%s3=saved.PartySummary
    UIStartMenuSize = "旧档未记录世界", -- Lua/UI/Panel/StartMenuCtr.lua:77
    UIStartMenuSize2 = "按原配方规模", -- Lua/UI/Panel/StartMenuCtr.lua:77
    UIStartMenuSize3 = "%s 格", -- Lua/UI/Panel/StartMenuCtr.lua:77；%s1=saved.TargetCells
    UIStartMenuTitle = "远征 · ", -- Lua/UI/Panel/StartMenuCtr.lua:76
    UIStartMenuTitle2 = "旧版存档 · ", -- Lua/UI/Panel/StartMenuCtr.lua:76
    UIStartMenuEmptyText = "还没有存档\n从“开始游戏”创建第一段旅程", -- Lua/UI/Panel/StartMenuCtr.lua:71
    UIStartMenuEmptyText2 = "无法读取存档列表", -- Lua/UI/Panel/StartMenuCtr.lua:67
    CampaignWorldName = "世界名称", -- 创建世界页的名称输入标签
    CampaignWorldNamePlaceholder = "输入世界名称（可选）", -- 创建世界页的名称输入提示，留空沿用默认存档标题
    CampaignNamedSave = "%s · %s", -- 具名存档标题；%s1=玩家输入的世界名称，%s2=本地保存时间
    CampaignUnnamedSave = "远征 · %s", -- 无名称存档标题；%s=本地保存时间
    CampaignLegacySave = "旧版存档 · %s", -- 无名称旧版存档标题；%s=本地保存时间
    CampaignInvalidSize = "请选择有效的世界大小。", -- 创建世界的规模校验提示
    CampaignSelectSave = "请先选择存档。", -- 加载世界时未指定存档的提示
    CampaignFinishEvent = "请先结束当前事件或战斗。", -- 创建或加载世界前的会话状态校验
    CampaignCloseParty = "请先结束队伍交互。", -- 创建或加载世界前的队伍交互校验
    CampaignCloseCamp = "请先关闭营地面板。", -- 创建或加载世界前的营地校验
    CampaignCloseShop = "请先关闭商店。", -- 创建或加载世界前的商店校验
    CampaignCloseDialogue = "请先结束对话。", -- 创建或加载世界前的对话校验
    CampaignCloseLoot = "请先关闭战利品窗口。", -- 创建或加载世界前的战利品校验
    CampaignInitialSaveFailed = "世界已创建，但初始存档未保存：%s", -- 初始保存失败提示；%s=保存错误
    CampaignLoadingBusy = "世界正在加载，请稍候。", -- 重复开始加载时的提示
    CampaignLoadingLoadTitle = "加载世界", -- 读档 loading 标题
    CampaignLoadingRead = "读取远征存档", -- 读档 loading 阶段
    CampaignLoadingValidate = "校验队伍与物品", -- 读档 loading 阶段
    CampaignLoadingWorldState = "校验世界探索记录", -- 读档 loading 阶段
    CampaignLoadingAreas = "恢复已探索区域", -- 读档 loading 阶段
    CampaignLoadingSnapshot = "准备地图显示数据", -- 创建和加载世界的 loading 阶段
    CampaignLoadingResources = "准备地图资源", -- 创建和加载世界的 loading 阶段
    CampaignLoadingRender = "构建地图显示", -- 创建和加载世界的 loading 阶段
    CampaignLoadingCreate = "建立队伍并保存新远征", -- 创建世界的提交阶段
    CampaignLoadingRestore = "恢复远征与队伍", -- 加载世界的提交阶段
    CampaignLoadingReady = "世界已就绪", -- loading 完成阶段
    CampaignLoadingAssetMismatch = "地图资源绑定不一致：{0}", -- C# 地图候选构建失败提示；{0}=地图资源 ID
    UIStoryEventRewardsRewards1 = "可能唤醒潜力", -- Lua/UI/Panel/StoryEventCtr.lua:31
    UIStoryEventRewardsRewards12 = "开启新的天赋道路", -- Lua/UI/Panel/StoryEventCtr.lua:30
    UIStoryEventRewardsRewards13 = "经验 +%s", -- Lua/UI/Panel/StoryEventCtr.lua:29；%s1=row.experience
    UIStoryEventRewardsRewards14 = "用时 %s 分钟", -- Lua/UI/Panel/StoryEventCtr.lua:26；%s1=row.timeMinutes
    UIStoryEventRewardsRewards15 = "消耗 %s 金币", -- Lua/UI/Panel/StoryEventCtr.lua:25；%s1=row.costCoins
    UIStoryEventContinueTextText = "返回旅途", -- Lua/UI/Panel/StoryEventCtr.lua:19
    UIStoryEventContinueTextText2 = "继续探索", -- Lua/UI/Panel/StoryEventCtr.lua:19
    UIWorldPartyHintText = "关闭后时间保持暂停；按空格继续，1 / 2 / 3 调整流速。", -- Lua/UI/Panel/WorldPartyCtr.lua:25
    UIWorldPartyCaptionText = "%s  |  持有 %s 金币", -- Lua/UI/Panel/WorldPartyCtr.lua:17；%s1=snapshot.caption，%s2=snapshot.coins
    UISkillTipPresenterBreadcrumb = "术语释义 · 第 %s 层", -- Lua/UI/SkillTipPresenter.lua:32；%s1=#self.stack
    UIBattleHUDContentHintText = "剩余移动 %s，可分段；贴身移动会被借机攻击，使用技能后结束移动。", -- Lua/UI/Widget/BattleHUDContent.lua:94；%s1=model.moveRemaining
    UIBattleHUDContentHintText2 = "部署：可先移动，也可直接准备；使用技能或道具后跳过剩余移动。", -- Lua/UI/Widget/BattleHUDContent.lua:93
    UIBattleHUDContentHintText3 = "移动阶段已结束；选择可用技能、道具或结束回合。", -- Lua/UI/Widget/BattleHUDContent.lua:92
    UIBattleHUDContentMoveTextText = "%s%s · 余 %s", -- Lua/UI/Widget/BattleHUDContent.lua:79；%s1=self.demo.IsBattleMoveSelected and '• ' or ''，%s2=L.BattleMove，%s3=model.moveRemaining
    UIBattleHUDContentMoveTextText2 = "移动已结束", -- Lua/UI/Widget/BattleHUDContent.lua:78
    UIBattleHUDContentMoveTextText3 = "取消选择 [Esc]", -- Lua/UI/Widget/BattleHUDContent.lua:78
    UIBattleHUDContentEndTurnTextText = "结束部署", -- Lua/UI/Widget/BattleHUDContent.lua:76
    UIBattleHUDContentEndTurnTextText2 = "确认释放 %s/%s", -- Lua/UI/Widget/BattleHUDContent.lua:75；%s1=selection.Count(self.demo)，%s2=selection.Limit(self.demo)
    UIBattleHUDContentSkillTitleText = "职业准备技能", -- Lua/UI/Widget/BattleHUDContent.lua:73
    UIBattleHUDContentRoundText = "战前部署", -- Lua/UI/Widget/BattleHUDContent.lua:72
    UICharacterSkillStateText = "暂不可用", -- Lua/UI/Widget/CharacterSkill.lua:12
    UICharacterSkillStateText2 = "点击使用", -- Lua/UI/Widget/CharacterSkill.lua:12
    UICharacterSkillStateText3 = "请选择目标", -- Lua/UI/Widget/CharacterSkill.lua:12
    UIHudHealthHealthTextText = "骑%s/%s 人%s/%s", -- Lua/UI/Widget/HudHealth.lua:18；%s1=row.hp，%s2=row.maxHP，%s3=row.riderHP，%s4=row.riderMaxHP
    UISkillCriticalChance = "命中后暴击率", -- 技能详情：每发命中后独立判定的暴击概率
    UISkillCriticalMultiplier = "暴击伤害倍率", -- 技能详情：即时伤害的暴击倍率
    DiceCritical = "暴击", -- 战斗暴击检定名称及成功标签
    DiceNormalHit = "普通命中", -- 战斗暴击检定失败标签
    UISkillTipAny = "任意角色", -- Lua/Game/Presentation/SkillTipModel.lua:3
    UISkillTipCell = "地格", -- Lua/Game/Presentation/SkillTipModel.lua:3
    UISkillTipSelf = "自身", -- Lua/Game/Presentation/SkillTipModel.lua:3
    UISkillTipAlly = "友方角色", -- Lua/Game/Presentation/SkillTipModel.lua:3
    UISkillTipEnemy = "敌方角色", -- Lua/Game/Presentation/SkillTipModel.lua:3
    UISkillTipBreadcrumb = "技能详情  ·  协同效应已发现 %s / %s", -- Lua/Game/Presentation/SkillTipModel.lua:48；%s1=discovered，%s2=#result.synergies
    UISkillTipBody = "%s\n\n<color=#A6B8BB>点击道具立即对自己使用。</color>", -- Lua/Game/Presentation/SkillTipModel.lua:41；%s1=result.body
    UISkillTipBody2 = "%s\n<color=#A6B8BB>选择 1–%s 个不同目标后确认释放。</color>", -- Lua/Game/Presentation/SkillTipModel.lua:38；%s1=result.body，%s2=skill.maxTargets
    UISkillTipBody3 = "%s\n\n<color=#A6B8BB>相关规则</color>  %s", -- Lua/Game/Presentation/SkillTipModel.lua:37；%s1=result.body，%s2=self.catalog:Rich(table.concat(mechanics,'  ·  '))
    UISkillTipMechanicsMechanics1 = "转施", -- Lua/Game/Presentation/SkillTipModel.lua:36
    UISkillTipMechanicsMechanics12 = "抛射", -- Lua/Game/Presentation/SkillTipModel.lua:35
    UISkillTipMechanicsMechanics13 = "直射", -- Lua/Game/Presentation/SkillTipModel.lua:35
    UISkillTipMechanicsMechanics14 = "追踪", -- Lua/Game/Presentation/SkillTipModel.lua:34
    UISkillTipMechanicsMechanics15 = "高打低", -- Lua/Game/Presentation/SkillTipModel.lua:33
    UISkillTipText = "扩散半径", -- Lua/Game/Presentation/SkillTipModel.lua:31
    UISkillTipText2 = "%s 发", -- Lua/Game/Presentation/SkillTipModel.lua:30；%s1=skill.shots*skill.ammoPerShot
    UISkillTipText3 = "弹药消耗", -- Lua/Game/Presentation/SkillTipModel.lua:30
    UISkillTipText4 = "%s 次", -- Lua/Game/Presentation/SkillTipModel.lua:29；%s1=skill.shots
    UISkillTipText5 = "连续次数", -- Lua/Game/Presentation/SkillTipModel.lua:29
    UISkillTipText6 = "%s 个", -- Lua/Game/Presentation/SkillTipModel.lua:28；%s1=skill.maxTargets
    UISkillTipText7 = "目标上限", -- Lua/Game/Presentation/SkillTipModel.lua:28
    UISkillTipText8 = "  ·  剩余 %s", -- Lua/Game/Presentation/SkillTipModel.lua:27；%s1=row.cooldown
    UISkillTipText9 = "%s 回合%s", -- Lua/Game/Presentation/SkillTipModel.lua:27；%s1=skill.cooldownTurns，%s2=row.cooldown>0 and (string.format(LuaLanguage.UISkillTipText8, (row.cooldown))) or ''
    UISkillTipText10 = "冷却", -- Lua/Game/Presentation/SkillTipModel.lua:27
    UISkillTipText11 = "技能命中", -- Lua/Game/Presentation/SkillTipModel.lua:26
    UISkillTipText12 = "伤害倍率", -- Lua/Game/Presentation/SkillTipModel.lua:25
    UISkillTipText13 = "目标", -- Lua/Game/Presentation/SkillTipModel.lua:22
    UISkillTipText14 = "固定距离", -- Lua/Game/Presentation/SkillTipModel.lua:21
    UISkillTipText15 = "射程规则", -- Lua/Game/Presentation/SkillTipModel.lua:21
    UISkillTipText16 = "最小距离", -- Lua/Game/Presentation/SkillTipModel.lua:20
    UISkillTipText17 = "射程", -- Lua/Game/Presentation/SkillTipModel.lua:19
    UISkillTipText18 = "行动类型", -- Lua/Game/Presentation/SkillTipModel.lua:18
    UISkillTipText19 = "行动点", -- Lua/Game/Presentation/SkillTipModel.lua:17
    UISkillTipBreadcrumb2 = "技能详情", -- Lua/Game/Presentation/SkillTipModel.lua:13
    UIMainHudBody = "选择要继续的远征存档；显示保存时间、种子与队伍摘要", -- Lua/Game/Adventure/MainHudModel.lua:102
    UIMainHudTitle = "加载游戏", -- Lua/Game/Adventure/MainHudModel.lua:102
    UIMainHudBody2 = "%s · 保存探索、敌群、战利品和剧情", -- Lua/Game/Adventure/MainHudModel.lua:101；%s1=adventure.characterSaves.Status
    UIMainHudTitle2 = "保存远征 [F5]", -- Lua/Game/Adventure/MainHudModel.lua:101
    UIMainHudBody3 = "携带火炬可照亮小队周围；亮度只在局部探索生效", -- Lua/Game/Adventure/MainHudModel.lua:100
    UIMainHudBody4 = "查询技能效果与前置；学习与加点请打开角色养成", -- Lua/Game/Adventure/MainHudModel.lua:98
    UIMainHudTitle3 = "技能图鉴 · 浏览", -- Lua/Game/Adventure/MainHudModel.lua:98
    UIMainHudBody5 = "创建新世界：输入或随机种子，选择世界大小；已有存档保留", -- Lua/Game/Adventure/MainHudModel.lua:96
    UIMainHudTitle4 = "开始菜单", -- Lua/Game/Adventure/MainHudModel.lua:96
    UIMainHudCaption = "继续探索  [Esc]", -- Lua/Game/Adventure/MainHudModel.lua:76
    UIMainHudBody6 = "到达服务点附近后按 E", -- Lua/Game/Adventure/MainHudModel.lua:70
    UIMainHudTitle5 = "前往 · %s", -- Lua/Game/Adventure/MainHudModel.lua:70；%s1=site.name
    UIMainHudBody7 = "走近后选择工具或徒手处理", -- Lua/Game/Adventure/MainHudModel.lua:67
    UIMainHudTitle6 = "处理 · %s", -- Lua/Game/Adventure/MainHudModel.lua:67；%s1=obstacle.name
    UIMainHudBody8 = "耐久 %s/%s · 选择伤害技能攻击；锁定容器须先清除守卫", -- Lua/Game/Adventure/MainHudModel.lua:63；%s1=loot.durability，%s2=loot.maxDurability
    UIMainHudBody9 = "靠近后整理容器、存入或取出物品", -- Lua/Game/Adventure/MainHudModel.lua:63
    UIMainHudTitle7 = "容器 · ", -- Lua/Game/Adventure/MainHudModel.lua:62
    UIMainHudTitle8 = "搜刮 · ", -- Lua/Game/Adventure/MainHudModel.lua:62
    UIMainHudTitle9 = "存放 · ", -- Lua/Game/Adventure/MainHudModel.lua:62
    UIMainHudBody10 = "从全图视角回到同行者身边", -- Lua/Game/Adventure/MainHudModel.lua:60
    UIMainHudTitle10 = "定位小队并跟随", -- Lua/Game/Adventure/MainHudModel.lua:60
    UIMainHudTitle11 = "最近结果", -- Lua/Game/Adventure/MainHudModel.lua:59
    UIMainHudSubtitle = "左键走格子 · E 交互 · 空格停止", -- Lua/Game/Adventure/MainHudModel.lua:57
    UIMainHudBody11 = "旅途中的抉择", -- Lua/Game/Adventure/MainHudModel.lua:50
    UIMainHudBody12 = "服务台按 E 交互", -- Lua/Game/Adventure/MainHudModel.lua:50
    UIMainHudBody13 = "装备、材料与守卫宝库", -- Lua/Game/Adventure/MainHudModel.lua:50
    UIMainHudBody14 = "野生动物 · 驯服坐骑 · 哥布林", -- Lua/Game/Adventure/MainHudModel.lua:50
    UIMainHudBody15 = "重返战场 · 领取遗留战利品", -- Lua/Game/Adventure/MainHudModel.lua:50
    UIMainHudBody16 = "数字键 %s · 同步调整行进与游戏时间", -- Lua/Game/Adventure/MainHudModel.lua:36；%s1=key
    UIMainHudTitle12 = "%s%s 倍时间", -- Lua/Game/Adventure/MainHudModel.lua:36；%s1=travel.speed==speed and '● ' or ''，%s2=speed
    UIMainHudBody17 = "空格切换 · 同时控制小队、商队与敌人", -- Lua/Game/Adventure/MainHudModel.lua:35
    UIMainHudTitle13 = "Ⅱ 暂停时间", -- Lua/Game/Adventure/MainHudModel.lua:35
    UIMainHudTitle14 = "▶ 继续时间", -- Lua/Game/Adventure/MainHudModel.lua:35
    UIMainHudBody18 = "小队原地待命 · 时间继续流逝", -- Lua/Game/Adventure/MainHudModel.lua:33
    UIMainHudBody19 = "时间已暂停", -- Lua/Game/Adventure/MainHudModel.lua:33
    UIMainHudBody20 = "行进中", -- Lua/Game/Adventure/MainHudModel.lua:32
    UIMainHudBody21 = "已暂停", -- Lua/Game/Adventure/MainHudModel.lua:32
    UIMainHudBody22 = "%s · %s · 预计 %.0f 分钟", -- Lua/Game/Adventure/MainHudModel.lua:32
    UIMainHudTitle15 = "小队待命", -- Lua/Game/Adventure/MainHudModel.lua:31
    UIMainHudSubtitle2 = "种子 %s · 左键前往 · 空格暂停/继续 · 1 / 2 / 3 调速", -- Lua/Game/Adventure/MainHudModel.lua:30；%s1=data.Seed
    UIMainHudTitle16 = "边境远征 · 大地图", -- Lua/Game/Adventure/MainHudModel.lua:30
    UIMainHudEffectBody = "坐骑：%s\n%s", -- Lua/Game/Adventure/MainHudModel.lua:12；%s1=stats:Template(mount).name，%s2=effect.body
    UIMainHudEffectName = "%s · 坐骑", -- Lua/Game/Adventure/MainHudModel.lua:12；%s1=effect.name
    UIMainHudSubtitle3 = "选择目的地，开始这一程。", -- Lua/Game/Adventure/MainHudModel.lua:5
    UIMainHudTitle17 = "边境远征", -- Lua/Game/Adventure/MainHudModel.lua:5
    UIInteractionPromptText = "处理", -- Lua/Game/Adventure/InteractionPrompt.lua:35
    UIInteractionPromptText2 = "搜刮", -- Lua/Game/Adventure/InteractionPrompt.lua:31
    UIInteractionPromptText3 = "存放", -- Lua/Game/Adventure/InteractionPrompt.lua:31
    UIInteractionPromptText4 = "交谈", -- Lua/Game/Adventure/InteractionPrompt.lua:27
    UIInteractionPromptText5 = "交易", -- Lua/Game/Adventure/InteractionPrompt.lua:27
    UIInteractionPromptText6 = "交互", -- Lua/Game/Adventure/InteractionPrompt.lua:21
    UIInteractionPromptBody = "靠近目标后按 E", -- Lua/Game/Adventure/InteractionPrompt.lua:16
    UIInteractionPromptText7 = "附近没有可交互的目标", -- Lua/Game/Adventure/InteractionPrompt.lua:42
    UIBattleHUDAmmo = "未装弹匣", -- Lua/Game/Battle/BattleHUDModel.lua:22
    UIBattleHUDAmmo2 = "弹匣 %s/%s", -- Lua/Game/Battle/BattleHUDModel.lua:22；%s1=magazine.Rounds，%s2=magazine.Capacity
    UIInventoryOffhand = "副手", -- Lua/Game/Equipment/InventoryModel.lua:5
    UIInventoryWeapon = "主手", -- Lua/Game/Equipment/InventoryModel.lua:5
    UIInventoryFeet = "鞋子", -- Lua/Game/Equipment/InventoryModel.lua:5
    UIInventoryLegs = "裤子", -- Lua/Game/Equipment/InventoryModel.lua:5
    UIInventoryRightRing = "右戒指", -- Lua/Game/Equipment/InventoryModel.lua:5
    UIInventoryLeftRing = "左戒指", -- Lua/Game/Equipment/InventoryModel.lua:5
    UIInventoryBody = "身体甲", -- Lua/Game/Equipment/InventoryModel.lua:5
    UIInventoryHead = "头部", -- Lua/Game/Equipment/InventoryModel.lua:5
    UIInventoryText = "拖到空格另放一堆，拖到同类物品上合并", -- Lua/Game/Equipment/InventoryModel.lua:43
    UIInventoryText2 = "弹药 %d / %d", -- Lua/Game/Equipment/InventoryModel.lua:39
    UIInventoryText3 = "双手武器 · 需要空副手", -- Lua/Game/Equipment/InventoryModel.lua:36
    UIInventoryText4 = "单手武器 · 可装备主手或副手", -- Lua/Game/Equipment/InventoryModel.lua:36
    UIInventoryText5 = "背包空间不足，无法放回原装备", -- Lua/Game/Equipment/InventoryModel.lua:80
    UIInventoryText6 = "物品与装备槽不兼容", -- Lua/Game/Equipment/InventoryModel.lua:77
    UIInventoryText7 = "无效装备槽", -- Lua/Game/Equipment/InventoryModel.lua:70
    UIInventoryText8 = "背包空间不足，无法卸下装备", -- Lua/Game/Equipment/InventoryModel.lua:67
    UIInventoryText9 = "物品尚未穿戴", -- Lua/Game/Equipment/InventoryModel.lua:65
    UIInventoryText10 = "位置被占用或超出背包范围", -- Lua/Game/Equipment/InventoryModel.lua:62
    UIInventoryText11 = "物品不在当前背包或角色身上", -- Lua/Game/Equipment/InventoryModel.lua:55
    UIInventoryText12 = "无效队员", -- Lua/Game/Equipment/InventoryModel.lua:52
    UIInventoryText13 = "只能在探索期间整理背包", -- Lua/Game/Equipment/InventoryModel.lua:51
    UIEquipmentPresentationLinesLines1 = "无额外属性修正", -- Lua/Game/Equipment/EquipmentPresentation.lua:24
    UIEquipmentPresentationLinesLines12 = " 个百分点", -- Lua/Game/Equipment/EquipmentPresentation.lua:22
    UIEquipmentPresentationLinesLines13 = "命中", -- Lua/Game/Equipment/EquipmentPresentation.lua:22
    UIEquipmentPresentationLinesLines14 = "伤害", -- Lua/Game/Equipment/EquipmentPresentation.lua:21
    UIEquipmentPresentationLines = "品质效果", -- Lua/Game/Equipment/EquipmentPresentation.lua:20
    UIEquipmentPresentationLinesLines15 = "已损毁 · 维修后可用", -- Lua/Game/Equipment/EquipmentPresentation.lua:33
    UIEquipmentPresentationLinesLines16 = "原始耐久上限 %s · 已有永久损伤", -- Lua/Game/Equipment/EquipmentPresentation.lua:32；%s1=condition.BaseMaximum
    UIEquipmentPresentationLinesLines17 = "效能 %d%%", -- Lua/Game/Equipment/EquipmentPresentation.lua:31
    UIEquipmentPresentationLines2 = "耐久", -- Lua/Game/Equipment/EquipmentPresentation.lua:30
    UIEquipmentPresentationLines3 = "装备状态", -- Lua/Game/Equipment/EquipmentPresentation.lua:30
    UIEquipmentPresentationLinesLines18 = "当前值 / 需求 · 不含装备加成", -- Lua/Game/Equipment/EquipmentPresentation.lua:43
    UIEquipmentPresentationLinesLines19 = "已计入品质与当前耐久", -- Lua/Game/Equipment/EquipmentPresentation.lua:65
    UIEquipmentPresentationLinesLines110 = "当前无有效属性加成", -- Lua/Game/Equipment/EquipmentPresentation.lua:64
    UIEquipmentPresentationLines4 = "装备属性", -- Lua/Game/Equipment/EquipmentPresentation.lua:54
    UIEquipmentPresentationRing = "戒指", -- Lua/Game/Equipment/EquipmentPresentation.lua:74
    UIEquipmentPresentationOffhand = "盾牌", -- Lua/Game/Equipment/EquipmentPresentation.lua:74
    UIEquipmentPresentationFeet = "足部护具", -- Lua/Game/Equipment/EquipmentPresentation.lua:74
    UIEquipmentPresentationLegs = "腿部护具", -- Lua/Game/Equipment/EquipmentPresentation.lua:74
    UIEquipmentPresentationBody = "身体护甲", -- Lua/Game/Equipment/EquipmentPresentation.lua:74
    UIEquipmentPresentationHead = "头部护具", -- Lua/Game/Equipment/EquipmentPresentation.lua:74
    UIEquipmentPresentationCategory = "双手", -- Lua/Game/Equipment/EquipmentPresentation.lua:72
    UIEquipmentPresentationCategory2 = "单手", -- Lua/Game/Equipment/EquipmentPresentation.lua:72
    UIEquipmentPresentationLinesLines111 = "在武器改装界面选择对应挂点安装", -- Lua/Game/Equipment/EquipmentPresentation.lua:101
    UIEquipmentPresentationLinesLines112 = "需要专精：%s", -- Lua/Game/Equipment/EquipmentPresentation.lua:100；%s1=rules.passives:Get(rules.talents:Get(row.requiredTalentId).passiveId).name
    UIEquipmentPresentationLinesLines113 = "伤害命中后", -- Lua/Game/Equipment/EquipmentPresentation.lua:97
    UIEquipmentPresentationTarget = "自身：", -- Lua/Game/Equipment/EquipmentPresentation.lua:96
    UIEquipmentPresentationLinesLines114 = "仅影响允许转施的自身法术；可选择自己、队友或敌人，保留原行动消耗。", -- Lua/Game/Equipment/EquipmentPresentation.lua:91
    UIEquipmentPresentationLinesLines115 = "%s 格内任意角色", -- Lua/Game/Equipment/EquipmentPresentation.lua:90；%s1=row.transferRange
    UIEquipmentPresentationLinesLines116 = "%s 格内 · 目标上限至少 %s 人", -- Lua/Game/Equipment/EquipmentPresentation.lua:88；%s1=row.splashRadius，%s2=row.maxTargets
    UIEquipmentPresentationLinesLines117 = "扩散", -- Lua/Game/Equipment/EquipmentPresentation.lua:88
    UIEquipmentPresentationLinesLines118 = "%+d 回合", -- Lua/Game/Equipment/EquipmentPresentation.lua:87
    UIEquipmentPresentationLinesLines119 = " 格", -- Lua/Game/Equipment/EquipmentPresentation.lua:85
    UIEquipmentPresentationLinesLines120 = "技能伤害", -- Lua/Game/Equipment/EquipmentPresentation.lua:84
    UIEquipmentPresentationLines5 = "改装效果", -- Lua/Game/Equipment/EquipmentPresentation.lua:83
    UIEquipmentPresentationStock = "步枪 · 枪托组件", -- Lua/Game/Equipment/EquipmentPresentation.lua:82
    UIEquipmentPresentationMuzzle = "步枪 · 枪口组件", -- Lua/Game/Equipment/EquipmentPresentation.lua:82
    UIEquipmentPresentationBowstring = "弓 · 弓弦组件", -- Lua/Game/Equipment/EquipmentPresentation.lua:82
    UIEquipmentPresentationBowlimb = "弓 · 弓臂组件", -- Lua/Game/Equipment/EquipmentPresentation.lua:82
    UIEquipmentPresentationPommel = "近战武器 · 柄尾配重", -- Lua/Game/Equipment/EquipmentPresentation.lua:82
    UIEquipmentPresentationGrip = "近战武器 · 握柄组件", -- Lua/Game/Equipment/EquipmentPresentation.lua:82
    UIEquipmentPresentationEdge = "近战武器 · 刃部组件", -- Lua/Game/Equipment/EquipmentPresentation.lua:81
    UIEquipmentPresentationRail = "步枪/弓 · 导轨", -- Lua/Game/Equipment/EquipmentPresentation.lua:81
    UIEquipmentPresentationCatalyst = "单手剑 · 奥术触媒", -- Lua/Game/Equipment/EquipmentPresentation.lua:81
    UIEquipmentPresentationThruster = "巨剑 · 剑脊机械组件", -- Lua/Game/Equipment/EquipmentPresentation.lua:81
    UIEquipmentPresentationShaft = "法杖 · 杖身", -- Lua/Game/Equipment/EquipmentPresentation.lua:81
    UIEquipmentPresentationHead2 = "法杖 · 杖头", -- Lua/Game/Equipment/EquipmentPresentation.lua:81
    UICampText = "请先结束当前交互", -- Lua/Game/Camp/CampModel.lua:15
    UICampText2 = "请先结束队伍交互", -- Lua/Game/Camp/CampModel.lua:14
    UICampText3 = "请先返回地图营地", -- Lua/Game/Camp/CampModel.lua:13
    UICampText4 = "营地已经打开", -- Lua/Game/Camp/CampModel.lua:20
    UICampText5 = "营地状态已变化，请重新选择", -- Lua/Game/Camp/CampModel.lua:27
    UICampText6 = "请先打开营地", -- Lua/Game/Camp/CampModel.lua:26
    UICampText7 = "%s 升至 %s 级", -- Lua/Game/Camp/CampModel.lua:41；%s1=self.rules.facilities:Get(facilityId).name，%s2=upgrade.level
    UICampText8 = "营地建设", -- Lua/Game/Camp/CampModel.lua:41
    UICampText9 = "%s · %s 分钟后可领取", -- Lua/Game/Camp/CampModel.lua:52；%s1=row.name，%s2=row.minutes
    UICampText10 = "开始生产", -- Lua/Game/Camp/CampModel.lua:52
    UICampText11 = "领取营地产物", -- Lua/Game/Camp/CampModel.lua:62
    UICampText12 = "该设施没有待领取订单", -- Lua/Game/Camp/CampModel.lua:56
    UICampText13 = "营地仓库只接收材料、弹药、药品与组件", -- Lua/Game/Camp/CampModel.lua:66
    UICampText14 = "营地仓库只保存堆叠物品", -- Lua/Game/Camp/CampModel.lua:72
    UICampText15 = "推进营地生产、世界时钟与商人补货周期。等待不直接恢复伤势或发放物品。", -- Lua/Game/Camp/CampModel.lua:127
    UICampText16 = "等待 %s 小时", -- Lua/Game/Camp/CampModel.lua:127；%s1=duration//60
    UICampText17 = "探索、搜刮或向商人购买材料后，可在这里安全存放。", -- Lua/Game/Camp/CampModel.lua:125
    UICampText18 = "尚无可转移物资", -- Lua/Game/Camp/CampModel.lua:125
    UICampText19 = "\n背包空间不足，物品留在仓库", -- Lua/Game/Camp/CampModel.lua:122
    UICampText20 = "仓库 %s  |  背包 %s%s", -- Lua/Game/Camp/CampModel.lua:122；%s1=stored，%s2=bag，%s3=not fits and LuaLanguage.UICampText19 or ''
    UICampText21 = "取出 %s ×%s", -- Lua/Game/Camp/CampModel.lua:122；%s1=item.name，%s2=amount
    UICampText22 = "\n仓库已满，请先升级或取出", -- Lua/Game/Camp/CampModel.lua:118
    UICampText23 = "背包 %s  |  仓库 %s%s", -- Lua/Game/Camp/CampModel.lua:118；%s1=bag，%s2=stored，%s3=free==0 and LuaLanguage.UICampText22 or ''
    UICampText24 = "存入 %s ×%s", -- Lua/Game/Camp/CampModel.lua:118；%s1=item.name，%s2=amount
    UICampText25 = "材料先从仓库扣除，再从背包补足。每次转移最多 10 件，药品和组件每次 1 件。", -- Lua/Game/Camp/CampModel.lua:111
    UICampText26 = "营地仓库 · %s / %s", -- Lua/Game/Camp/CampModel.lua:111；%s1=data.StoredTotal，%s2=capacity
    UICampText27 = "点击安排生产 · 每个设施保留一个订单", -- Lua/Game/Camp/CampModel.lua:107
    UICampText28 = "产出 %s  |  %s 分钟\n投入 %s\n%s", -- Lua/Game/Camp/CampModel.lua:106；%s1=rules:ItemsText(recipe.outputIds,recipe.outputCounts)，%s2=recipe.minutes，%s3=rules:CostText(recipe)，%s4=ok and LuaLanguage.UICampText27 or reason
    UICampText29 = "%s · %s %s 级", -- Lua/Game/Camp/CampModel.lua:105；%s1=recipe.name，%s2=facility.name，%s3=recipe.requiredLevel
    UICampText30 = "剩余 %s 分钟", -- Lua/Game/Camp/CampModel.lua:100；%s1=math.ceil(job.ReadyAt-minutes)
    UICampText31 = "背包空间不足，产物保留在设施中", -- Lua/Game/Camp/CampModel.lua:100
    UICampText32 = "生产已完成，点击收入背包", -- Lua/Game/Camp/CampModel.lua:100
    UICampText33 = "生产中 · ", -- Lua/Game/Camp/CampModel.lua:99
    UICampText34 = "领取 · ", -- Lua/Game/Camp/CampModel.lua:99
    UICampText35 = "%s · %s 级", -- Lua/Game/Camp/CampModel.lua:94；%s1=facility.name，%s2=level
    UICampDetail = "点击建设，费用一次性扣除", -- Lua/Game/Camp/CampModel.lua:93
    UICampDetail2 = "建设至 %s 级：%s", -- Lua/Game/Camp/CampModel.lua:92；%s1=upgrade.level，%s2=rules:CostText(upgrade)
    UILootDisplayName = "未搜索的物品", -- Lua/Game/Loot/LootModel.lua:32
    UILootDetail = "来自：%s", -- Lua/Game/Loot/LootModel.lua:30；%s1=source.Name
    UILootDetail2 = "正在搜索，揭示后可以拖入背包", -- Lua/Game/Loot/LootModel.lua:26
    UIShopText = "对话已变化，请重新选择", -- Lua/Game/Shop/ShopModel.lua:16
    UIShopText2 = "这位居民不出售商品", -- Lua/Game/Shop/ShopModel.lua:14
    UIShopText3 = "商人不存在", -- Lua/Game/Shop/ShopModel.lua:12
    UIShopText4 = "当前不能开启商店", -- Lua/Game/Shop/ShopModel.lua:7
    UIShopText5 = "%s ×%s（花费 %s 金币）", -- Lua/Game/Shop/ShopModel.lua:54；%s1=item.name，%s2=count，%s3=entry.Price*count
    UIShopText6 = "购买商品", -- Lua/Game/Shop/ShopModel.lua:54
    UIShopText7 = "商品不在当前商店中", -- Lua/Game/Shop/ShopModel.lua:49
    UIShopText8 = "商店已到补货时间，请重新打开", -- Lua/Game/Shop/ShopModel.lua:46
    UIShopText9 = "商品列表已变化，请重新选择", -- Lua/Game/Shop/ShopModel.lua:42
    UIShopText10 = "商店已关闭", -- Lua/Game/Shop/ShopModel.lua:39
    UIShopName2 = "%s · 随机词缀", -- Lua/Game/Shop/ShopModel.lua:68；%s1=name
    UIShopReason = "背包空间不足", -- Lua/Game/Shop/ShopModel.lua:66
    UIShopReason2 = "金币不足", -- Lua/Game/Shop/ShopModel.lua:65
    UIShopReason3 = "已售罄", -- Lua/Game/Shop/ShopModel.lua:65
    UISkillAtlasText2 = "可在角色养成 → 职业技能中学习", -- Lua/Game/Progression/SkillAtlas.lua:94
    UISkillAtlasText3 = "特定途径获取", -- Lua/Game/Progression/SkillAtlas.lua:92
    UISkillAtlasText4 = "装备授予", -- Lua/Game/Progression/SkillAtlas.lua:90
    UISkillAtlasText5 = "骑乘能力", -- Lua/Game/Progression/SkillAtlas.lua:89
    UISkillAtlasText6 = "通用动作", -- Lua/Game/Progression/SkillAtlas.lua:88
    UISkillAtlasText7 = "固有技能", -- Lua/Game/Progression/SkillAtlas.lua:87
    UISkillAtlasText8 = "已掌握", -- Lua/Game/Progression/SkillAtlas.lua:86
    UISkillAtlasText9 = "触媒就绪", -- Lua/Game/Progression/SkillAtlas.lua:99
    UISkillAtlasText10 = "施放条件：%s", -- Lua/Game/Progression/SkillAtlas.lua:99；%s1=allowed and LuaLanguage.UISkillAtlasText9 or reason
    UISkillAtlasLinesLines1 = "获取：角色固有、装备或骑乘能力", -- Lua/Game/Progression/SkillAtlas.lua:133
    UISkillAtlasLinesLines12 = "获取：消耗背包中的对应道具，不能研习", -- Lua/Game/Progression/SkillAtlas.lua:132
    UISkillAtlasLinesLines13 = "获取：战斗中的通用动作", -- Lua/Game/Progression/SkillAtlas.lua:131
    UISkillAtlasLinesLines14 = "获取：角色养成 → 职业与天赋 → 职业技能，转入对应职业后选学；消耗 1 次学习机会", -- Lua/Game/Progression/SkillAtlas.lua:130
    UISkillAtlasRequirements = "角色等级 %s", -- Lua/Game/Progression/SkillAtlas.lua:124；%s1=course.minLevel
    UISkillAtlasLinesLines15 = "探索时每次消耗 %s 回合，可清理战后遗留工事", -- Lua/Game/Progression/SkillAtlas.lua:119；%s1=construction.workRounds
    UISkillAtlasLinesLines16 = "占地：1 格 · 保留至本次远征结束", -- Lua/Game/Progression/SkillAtlas.lua:118
    UISkillAtlasLinesLines17 = "工具：角色须装备铲子；仅可挖掘未铺装的泥土、草地", -- Lua/Game/Progression/SkillAtlas.lua:117
    UISkillAtlasLinesLines18 = "结构耐久：%s + 巧匠 ×%s", -- Lua/Game/Progression/SkillAtlas.lua:116；%s1=construction.maxHP，%s2=construction.hpPerCrafting
    UISkillAtlasLinesLines19 = "材料：无", -- Lua/Game/Progression/SkillAtlas.lua:115
    UISkillAtlasLinesLines110 = "材料：%s", -- Lua/Game/Progression/SkillAtlas.lua:115；%s1=table.concat(material,'、')
    UISkillAtlasLines = "行动点 %s    距离 %s 格    冷却 %s 回合", -- Lua/Game/Progression/SkillAtlas.lua:107；%s1=skill.cost，%s2=skill.range，%s3=skill.cooldownTurns
    UISkillAtlasKind = "道具动作", -- Lua/Game/Progression/SkillAtlas.lua:105
    UISkillAtlasKind2 = "准备技能", -- Lua/Game/Progression/SkillAtlas.lua:105
    UISkillAtlasContextsContexts1 = "探索", -- Lua/Game/Progression/SkillAtlas.lua:104
    UISkillAtlasContextsContexts12 = "战斗", -- Lua/Game/Progression/SkillAtlas.lua:104
    UIAdventureJournalPanelJournalHeading = "旅途见闻", -- Assets/DynamicAsset/UI/Prefabs/Adventure/AdventureJournalPanel.prefab / Journal/Heading
    UIAdventureJournalPanelJournalGrowthLabel = "同行者  [C]", -- Assets/DynamicAsset/UI/Prefabs/Adventure/AdventureJournalPanel.prefab / Journal/Growth/Label
    UICharacterGrowthPanelPageHeroCollection = "边 境 远 征  /  同 行 者", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Hero/Collection
    UICharacterGrowthPanelPageHeroTitle = "艾岚", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Hero/Title
    UICharacterGrowthPanelPageHeroRole = "剑士", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Hero/Role
    UICharacterGrowthPanelPageHeroHeroLevel = "旅人 · 等级 1", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Hero/HeroLevel
    UICharacterGrowthPanelPageHeroHeroHealth = "生命  46 / 46", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Hero/HeroHealth
    UICharacterGrowthPanelPageHeroHeroExperience = "距下一次成长", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Hero/HeroExperience
    UICharacterGrowthPanelPageHeroOrbitHint = "拖动旋转 · 滚轮缩放", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Hero/OrbitHint
    UICharacterGrowthPanelPageBookTitle = "旅 人 手 记", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/BookTitle
    UICharacterGrowthPanelPageBookSubtitle = "来历、选择，以及尚未走过的路。", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/BookSubtitle
    UICharacterGrowthPanelPageCloseLabel = "关闭  ×", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Close/Label
    UICharacterGrowthPanelPageOverviewTabLabel = "总 览", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/OverviewTab/Label
    UICharacterGrowthPanelPageSkillsTabLabel = "天 赋 与 技 能", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/SkillsTab/Label
    UICharacterGrowthPanelPageHistoryTabLabel = "经 历", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/HistoryTab/Label
    UICharacterGrowthPanelPageOverviewAttributesHeading = "属 性", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Overview/AttributesHeading
    UICharacterGrowthPanelPageOverviewAttributeNote = "选择 + 为属性投入一点", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Overview/AttributeNote
    UICharacterGrowthPanelPageOverviewTraitsHeading = "旅 途 印 记", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Overview/TraitsHeading
    UICharacterGrowthPanelPageOverviewTraitsNote = "每段经历，都会留下痕迹。", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Overview/TraitsNote
    UICharacterGrowthPanelPageOverviewTraitDetail = "选择一枚印记，回顾它的来由。", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Overview/TraitDetail
    UICharacterGrowthPanelPageSkillsTalentName = "选择一项天赋", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Skills/TalentName
    UICharacterGrowthPanelPageSkillsInvestLabel = "投入天赋点", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Skills/Invest/Label
    UICharacterGrowthPanelPageHistoryPreviousHistoryLabel = "上一页", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/History/PreviousHistory/Label
    UICharacterGrowthPanelPageHistoryNextHistoryLabel = "下一页", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/History/NextHistory/Label
    UICharacterGrowthPanelPageAtlasLabel = "技艺图谱", -- Assets/DynamicAsset/UI/Prefabs/Adventure/CharacterGrowthPanel.prefab / Page/Atlas/Label
    UIJournalAttributeWidgetTitle = "体力", -- Assets/DynamicAsset/UI/Prefabs/Adventure/JournalAttributeWidget.prefab / Title
    UIStartMenuPanelPageCaption = "选择一段旅程", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/Caption
    UIStartMenuPanelPageHomePageStartLabel = "开始游戏", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/HomePage/Start/Label
    UIStartMenuPanelPageHomePageHomeHint = "每次新游戏创建独立存档\nF5 保存当前旅程", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/HomePage/HomeHint
    UIStartMenuPanelPageNewPageSeedLabel = "世界种子", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/NewPage/SeedLabel
    UIStartMenuPanelPageNewPageRandomSeedLabel = "随机种子", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/NewPage/RandomSeed/Label
    UIStartMenuPanelPageNewPageSeedHint = "输入 0–4294967295 的整数；相同种子和规模可重现世界布局。", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/NewPage/SeedHint
    UIStartMenuPanelPageNewPageSizeLabel = "地图规模", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/NewPage/SizeLabel
    UIStartMenuPanelPageNewPageWorldSizeCaption = "标准 · 10,000 格", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/NewPage/WorldSize/Caption
    UIStartMenuPanelPageNewPageSizeHint = "较大的世界需要更长的生成与保存时间。", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/NewPage/SizeHint
    UIStartMenuPanelPageNewPageCreateLabel = "创建世界并开始", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/NewPage/Create/Label
    UIStartMenuPanelPageBackLabel = "返回首页", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/Back/Label
    UIStartMenuPanelPageResumeLabel = "返回游戏", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StartMenuPanel.prefab / Page/Resume/Label
    UIStoryChoiceWidgetTitle = "做出选择", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StoryChoiceWidget.prefab / Title
    UIStoryChoiceWidgetBody = "条件与后果", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StoryChoiceWidget.prefab / Body
    UIStoryEventPanelPageTitle = "旅途中的一页", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StoryEventPanel.prefab / Page/Title
    UIStoryEventPanelPageDescription = "有人向你伸出手。", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StoryEventPanel.prefab / Page/Description
    UIStoryEventPanelPageContinueLabel = "继续旅程", -- Assets/DynamicAsset/UI/Prefabs/Adventure/StoryEventPanel.prefab / Page/Continue/Label
    UITraitTagWidgetTitle = "◆ 印记", -- Assets/DynamicAsset/UI/Prefabs/Adventure/TraitTagWidget.prefab / Title
    UIBattleHUDPanelSafeAreaCombatLogLogCloseLabel = "收起", -- Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab / SafeArea/CombatLog/LogClose/Label
    UIBattleHUDPanelSafeAreaSkillTipBackLabel = "‹ 返回", -- Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab / SafeArea/SkillTip/Back/Label
    UIBattleHUDPanelSafeAreaSkillTipScrollViewportContentStatsTitle = "技能参数", -- Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab / SafeArea/SkillTip/Scroll/Viewport/Content/StatsTitle
    UIBattleHUDPanelSafeAreaSkillTipScrollViewportContentSynergyTitle = "协同效应", -- Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab / SafeArea/SkillTip/Scroll/Viewport/Content/SynergyTitle
    UIBattleHUDPanelSafeAreaSkillTipScrollViewportContentSynergiesSynergyTemplateUndiscoveredMaskUnknown = "尚未发现", -- Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab / SafeArea/SkillTip/Scroll/Viewport/Content/Synergies/SynergyTemplate/UndiscoveredMask/Unknown
    UIBattleHUDPanelSafeAreaSkillTipScrollViewportContentSynergiesSynergyTemplateUndiscoveredMaskUnlockHint = "首次成功装配对应符文组合后解锁", -- Assets/DynamicAsset/UI/Prefabs/Battle/BattleHUDPanel.prefab / SafeArea/SkillTip/Scroll/Viewport/Content/Synergies/SynergyTemplate/UndiscoveredMask/UnlockHint
    UIStatusEffectWidgetGlyph = "效", -- Assets/DynamicAsset/UI/Prefabs/Battle/StatusEffectWidget.prefab / Glyph
    UICampPanelPageCloseLabel = "关闭", -- Assets/DynamicAsset/UI/Prefabs/Camp/CampPanel.prefab / Page/Close/Label
    UILoadingPanelContentTitle = "创建世界", -- Assets/DynamicAsset/UI/Prefabs/Common/LoadingPanel.prefab / Content/Title
    UILoadingPanelContentTipCategory = "旅途建议", -- Assets/DynamicAsset/UI/Prefabs/Common/LoadingPanel.prefab / Content/TipCategory
    UILoadingPanelContentTip = "世界正在展开。", -- Assets/DynamicAsset/UI/Prefabs/Common/LoadingPanel.prefab / Content/Tip
    UITabButtonWidgetLabel = "分类", -- Assets/DynamicAsset/UI/Prefabs/Common/TabButtonWidget.prefab / Label
    UIEquipmentWorkbenchPanelSafeAreaHeading = "旅 人 工 坊  /  FIELD WORKBENCH", -- Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentWorkbenchPanel.prefab / SafeArea/Heading
    UIEquipmentWorkbenchPanelSafeAreaCloseLabel = "关闭 [I / Esc]", -- Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentWorkbenchPanel.prefab / SafeArea/Close/Label
    UIEquipmentWorkbenchPanelSafeAreaInventoryInventoryTitle = "共 享 背 包", -- Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentWorkbenchPanel.prefab / SafeArea/Inventory/InventoryTitle
    UIEquipmentWorkbenchPanelSafeAreaPreviewOrbitHint = "拖动旋转  ·  滚轮缩放  ·  点击挂点", -- Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentWorkbenchPanel.prefab / SafeArea/Preview/OrbitHint
    UIEquipmentWorkbenchPanelSafeAreaDetailsScrollViewportContentRemoveLabel = "卸下选中挂点组件", -- Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentWorkbenchPanel.prefab / SafeArea/Details/Scroll/Viewport/Content/Remove/Label
    UIEquipmentWorkbenchPanelSafeAreaDetailsScrollViewportContentFillLabel = "装填所选弹匣", -- Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentWorkbenchPanel.prefab / SafeArea/Details/Scroll/Viewport/Content/Fill/Label
    UIEquipmentWorkbenchPanelSafeAreaDetailsScrollViewportContentStatsTitle = "装备详情与技能", -- Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentWorkbenchPanel.prefab / SafeArea/Details/Scroll/Viewport/Content/StatsTitle
    UIEquipmentWorkbenchPanelSafeAreaFooterUnequipLabel = "卸下角色武器", -- Assets/DynamicAsset/UI/Prefabs/Equipment/EquipmentWorkbenchPanel.prefab / SafeArea/Footer/Unequip/Label
    UIInventoryPanelFrameHeading = "远 征 行 囊", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Heading
    UIInventoryPanelFrameSubtitle = "INVENTORY  /  装备与空间管理", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Subtitle
    UIInventoryPanelFrameCloseLabel = "关闭  [ I / Esc ]", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Close/Label
    UIInventoryPanelFrameEquipmentCharacterPreviewSlotoffhandEmpty = "单手 / 盾牌", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Equipment/CharacterPreview/Slot_offhand/Empty
    UIInventoryPanelFrameEquipmentCharacterPreviewSlotheadEmpty = "空槽", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Equipment/CharacterPreview/Slot_head/Empty
    UIInventoryPanelFrameEquipmentCharacterPreviewOrbitHint = "拖动角色旋转  ·  滚轮缩放", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Equipment/CharacterPreview/OrbitHint
    UIInventoryPanelFrameDetailsDetailHeading = "装备详情  ·  滚轮查看", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Details/DetailHeading
    UIInventoryPanelFrameDetailsEquipLabel = "穿戴装备", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Details/Equip/Label
    UIInventoryPanelFrameDetailsUnequipLabel = "卸下装备", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Details/Unequip/Label
    UIInventoryPanelFrameDetailsRotateLabel = "旋转 90°", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Details/Rotate/Label
    UIInventoryPanelFrameWorkbenchLabel = "武器改装工坊  →", -- Assets/DynamicAsset/UI/Prefabs/Equipment/InventoryPanel.prefab / Frame/Workbench/Label
    UILootPanelFrameTitle = "搜刮战利品", -- Assets/DynamicAsset/UI/Prefabs/Equipment/LootPanel.prefab / Frame/Title
    UILootPanelFrameLootLootTitle = "战 利 品", -- Assets/DynamicAsset/UI/Prefabs/Equipment/LootPanel.prefab / Frame/Loot/LootTitle
    UILootPanelFrameHint = "左右双向拖拽  ·  R 旋转  ·  右键取消  ·  战斗汇总先选择容器再存入", -- Assets/DynamicAsset/UI/Prefabs/Equipment/LootPanel.prefab / Frame/Hint
    UIGMPanelFrameTitle = "GM · 角色与 NPC", -- Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab / Frame/Title
    UIGMPanelFrameDescription = "槽位按队伍顺序从 1 开始 · F8 打开/关闭 · Esc 关闭", -- Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab / Frame/Description
    UIGMPanelFrameSlotLabel = "角色槽位", -- Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab / Frame/SlotLabel
    UIGMPanelFrameLevelUpText = "升 1 级", -- Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab / Frame/LevelUp/Text
    UIGMPanelFrameSkillLabel = "技能 ID", -- Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab / Frame/SkillLabel
    UIGMPanelFrameGrantSkillText = "获取技能", -- Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab / Frame/GrantSkill/Text
    UIGMPanelFrameNpcTitle = "查找 NPC · 名称 / ID", -- Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab / Frame/NpcTitle
    UIGMPanelFrameNpcHint = "留空显示全部叙事 NPC。点击条目传送，关闭 GM 后按 E 交谈。", -- Assets/DynamicAsset/UI/Prefabs/GM/GMPanel.prefab / Frame/NpcHint
    UICharacterSkillWidgetContexts = "生活 + 战斗", -- Assets/DynamicAsset/UI/Prefabs/MainHud/CharacterSkillWidget.prefab / Contexts
    UIHudHealthWidgetDamageAnchorDamageNumberTemplateCritical = "暴击!", -- Assets/DynamicAsset/UI/Prefabs/MainHud/HudHealthWidget.prefab / DamageAnchor/DamageNumberTemplate/Critical
    UIMainHudPanelExplorationSafeNavigationNavigationTitle = "目的地", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Exploration/Safe/Navigation/NavigationTitle
    UIMainHudPanelExplorationSafeJournalJournalTitle = "旅 途 见 闻", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Exploration/Safe/Journal/JournalTitle
    UIMainHudPanelExplorationSafeInteractionInteractLabel = "交互  E", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Exploration/Safe/Interaction/Interact/Label
    UIMainHudPanelExplorationSafeCharacterSkillsSkillActor = "选择队员 · 生活技能", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Exploration/Safe/CharacterSkills/SkillActor
    UIMainHudPanelExplorationSafeCharacterSkillsCancelSkillLabel = "取消  Esc", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Exploration/Safe/CharacterSkills/CancelSkill/Label
    UIMainHudPanelExplorationSafeCharacterSkillsSkillEmpty = "点击下方队员卡片进行选择", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Exploration/Safe/CharacterSkills/SkillEmpty
    UIMainHudPanelCommonEntryRailMenuToggleMenuToggleText = "菜单", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/EntryRail/MenuToggle/MenuToggleText
    UIMainHudPanelCommonEntryRailMissionsMissionsText = "任务", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/EntryRail/Missions/MissionsText
    UIMainHudPanelCommonEntryRailInventoryLabel = "背包", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/EntryRail/Inventory/Label
    UIMainHudPanelCommonEntryRailNavigationToggleLabel = "地图", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/EntryRail/NavigationToggle/Label
    UIMainHudPanelCommonMenuMenuTitle = "旅途菜单", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/Menu/MenuTitle
    UIMainHudPanelCommonMenuGrowthLabel = "手记 C", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/Menu/Growth/Label
    UIMainHudPanelCommonMenuFocusLabel = "全图  F", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/Menu/Focus/Label
    UIMainHudPanelCommonMenuEnvironmentLabel = "画面", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/Menu/Environment/Label
    UIMainHudPanelCommonMenuLeaveLabel = "返回大地图", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/Menu/Leave/Label
    UIMainHudPanelCommonMenuStopLabel = "停止  Space", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/Menu/Stop/Label
    UIMainHudPanelCommonMenuCameraModeLabel = "切换视角  V", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/Menu/CameraMode/Label
    UIMainHudPanelCommonMenuRestartLabel = "新的远征", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/Menu/Restart/Label
    UIMainHudPanelCommonWorldControlsTimeControlsTimeStartLabel = "开始", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/WorldControls/TimeControls/TimeStart/Label
    UIMainHudPanelCommonWorldControlsTimeControlsTimePauseLabel = "暂停", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/WorldControls/TimeControls/TimePause/Label
    UIMainHudPanelCommonWorldControlsTimeControlsTimeSpeedLabel = "速度 1×", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/WorldControls/TimeControls/TimeSpeed/Label
    UIMainHudPanelCommonWorldControlsFollowLabel = "回到小队", -- Assets/DynamicAsset/UI/Prefabs/MainHud/MainHudPanel.prefab / Common/WorldControls/Follow/Label
    UIDiceRollPanelTitle = "命运的回响", -- Assets/DynamicAsset/UI/Prefabs/Presentation/DiceRollPanel.prefab / Title
    UIDiceRollPanelDetail = "掷出你的命运", -- Assets/DynamicAsset/UI/Prefabs/Presentation/DiceRollPanel.prefab / Detail
    UIDiceRollPanelContinueCaption = "继续", -- Assets/DynamicAsset/UI/Prefabs/Presentation/DiceRollPanel.prefab / Continue/Caption
    UIDiceRollPanelRevealCaption = "快速揭晓", -- Assets/DynamicAsset/UI/Prefabs/Presentation/DiceRollPanel.prefab / Reveal/Caption
    UISkillAtlasPanelPageTitle = "技 艺 图 谱", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/Title
    UISkillAtlasPanelPageSubtitle = "武艺与百工 · 自由研习，各有所长", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/Subtitle
    UISkillAtlasPanelPageDomain1Label = "领域", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/Domain1/Label
    UISkillAtlasPanelPageTreeTitle = "营造 / 筑障", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/TreeTitle
    UISkillAtlasPanelPageSearchPlaceholder = "搜索全部技艺…", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/Search/Placeholder
    UISkillAtlasPanelPageSearchButtonLabel = "搜索", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/SearchButton/Label
    UISkillAtlasPanelPageClearSearchLabel = "清空", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/ClearSearch/Label
    UISkillAtlasPanelPageGraphScrollViewportEmpty = "此分类尚未收录技能", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/GraphScroll/Viewport/Empty
    UISkillAtlasPanelPageLegend = "■ 已掌握 / 当前可用    □ 满足研习条件    ▧ 条件不足或特定途径", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/Legend
    UISkillAtlasPanelPageHint = "点击技能查看效果与前置 · 图谱用于浏览，不直接学习", -- Assets/DynamicAsset/UI/Prefabs/Progression/SkillAtlasPanel.prefab / Page/Hint
    CampaignPreparing = "正在准备远征…", -- 远征初始化界面
    CampaignRetrySize = "选择规模重新开始", -- 远征初始化失败后的重试
    CampaignSizeSmall = "短途边境 · 2500 格", -- 新世界规模按钮
    CampaignSizeMedium = "标准远征 · 10000 格", -- 新世界规模按钮
    CampaignSizeLarge = "广袤世界 · 30000 格", -- 新世界规模按钮
    CampaignSizeHuge = "十万格大陆 · 100000 格", -- 新世界规模按钮
    LootHoverDurability = " · 耐久 {0}/{1}", -- C# 格式；{0} 当前耐久，{1} 最大耐久
    LootHoverSearch = "\n靠近后 E 搜刮 / 存放", -- 世界容器悬停提示
    LootHoverAttack = "\n选择攻击技能后点击容器", -- 世界容器悬停提示
    EnvironmentClock = "画面 · {0}:{1}", -- C# 格式；{0} 小时，{1} 分钟
    EnvironmentClockHint = "游戏时钟与 NPC 日程同步 · 参数由配置控制", -- 环境预览面板
    WorldPartyHoverVisit = "\n点击前往", -- 大地图据点悬停提示
    WorldPartyHoverFollow = "\n点击追赶", -- 大地图队伍悬停提示
    WorldPartyHoverTrade = " · 可交易 / 攻击", -- 商队悬停提示
    DiceTamingTitle = "驯服 %s", -- %s 为动物名称
    DiceEffectTrigger = "%s触发", -- %s 为效果名称
    DemoStatsTemplate = "LEVEL  %d     /     COINS  %d", -- UI 示例；等级与金币
    DemoClaimReward = "CLAIM REWARD", -- UI 示例领取按钮
    DemoLevelUp = "LEVEL UP", -- UI 示例升级按钮
    DemoOpenModal = "OPEN MODAL", -- UI 示例打开窗口按钮
    DemoModalTitle = "A LUA-CONTROLLED MODAL", -- UI 示例窗口标题
    DemoModalDescription = "This panel blocks input to lower windows.\nClose it with the button or Escape.\nIts Lua listeners are released on close.", -- UI 示例窗口正文
    DemoClose = "CLOSE", -- UI 示例关闭按钮
    LootSourcePlaceholder = "Option A", -- 容器选择器的编辑态占位；运行时替换为容器名称
    BodyOpen = "身体健康", -- 身体健康与创伤界面
    BodyTitle = "身体健康", -- 身体健康与创伤界面
    BodyBack = "返回装备", -- 身体健康与创伤界面
    BodySelectHint = "点击身体部位查看伤势 · 左右以角色自身为准", -- 身体健康与创伤界面
    BodyTreat = "治疗此部位", -- 身体健康与创伤界面
    BodyMovement = "移动力", -- 身体健康与创伤界面
    BodyPenalty = "%s -%d%%", -- 身体健康与创伤界面
    BodyNoInjury = "无创伤", -- 身体健康与创伤界面
    BodyHealthyDescription = "此部位健康，无需治疗。", -- 身体健康与创伤界面
    BodyInvalidTreatment = "请选择有效的队员、身体部位和医疗物资。", -- 身体健康与创伤界面
    BodyPermanentDescription = "此部位已永久致残，医疗物资无法修复。", -- 身体健康与创伤界面
    BodyMissingSupplies = "背包中的医疗物资不足。", -- 身体健康与创伤界面
    BodyExplorationOnly = "只能在探索期间治疗创伤。", -- 身体健康与创伤界面
    BodyTreated = "治疗完成，已消耗医疗物资；生命值和其他部位伤势不变。", -- 身体健康与创伤界面
    BodyInjuryLog = "%s · %s受到%s，伤势：%s（健康度 %d/100）", -- 身体健康与创伤界面
    BodyNoPenalty = "无属性惩罚", -- 身体健康与创伤界面
    BodyScheduledRecovery = "约 %d 游戏小时后自然恢复 %d 点损伤", -- 身体健康中的已登记自然恢复
    BodyDetail = "健康度  %d / 100\n<color=%s>%s</color> · %s\n\n%s\n\n属性影响\n%s", -- 身体健康与创伤界面
    BodyUntreatable = "永久致残 · 无法修复", -- 身体健康与创伤界面
    BodyNoTreatment = "部位健康 · 无需治疗", -- 身体健康与创伤界面
    BodyTreatmentButton = "使用%s ×%d（持有 %d）\n健康度恢复至 %d / 100", -- 身体健康与创伤界面
    BodyTreatmentNote = "治疗只修复选中部位，不恢复生命。\n普通回血与营地休整不消除创伤。\n各部位惩罚叠加，移动至少保留1格。", -- 身体健康与创伤界面
    BodyLegend = "<color=#F3F3F0>■</color> 健康   <color=#E8C653>■</color> 轻伤\n<color=#D95750>■</color> 重伤   <color=#7A8795>□</color> 黑色：永久致残", -- 身体健康与创伤界面
    BodyNoTraumaDescription = "血量损失与创伤独立记录。普通回血不会清除已有创伤。", -- 身体详情：血量与创伤的区别
    BodyDetailV2 = "部位血量  %d / %d\n总生命  %d / %d\n<color=%s>%s</color> · %s\n\n%s\n\n属性影响\n%s", -- 身体详情：部位血量/上限、总血量/上限、色号、阶段、创伤、说明、影响列表
    BodyAttributePercent = "%s  <color=%s>%+g%%</color>", -- 属性影响行：属性名、色号、百分比数值
    BodyAttributeAmount = "%s  <color=%s>%+g</color>", -- 属性影响行：属性名、色号、属性点数
    BodyDiseaseHeading = "疾病", -- 身体健康右下角疾病标题
    BodyDiseaseTreat = "使用药物治疗", -- 疾病治疗按钮默认文案
    BodyNoDisease = "暂无疾病", -- 角色没有疾病时显示
    BodyMissingMedicine = "背包中的治疗药品不足。", -- 疾病治疗物资不足提示
    BodyDiseaseCured = "疾病已治愈，已消耗治疗药品。", -- 疾病治疗成功提示
    BodyDiseaseMedicine = "使用%s ×%d（持有 %d）", -- 疾病治疗按钮：药名、消耗数量、持有数量
    BodyMedicineDescription = "用于身体健康界面治疗%s。\n%s", -- 背包药物说明：疾病名、疾病描述
    BodyNoRecoverableHealth = "可恢复的部位血量已满。", -- 治疗道具无法恢复已致残部位时的提示
    BodyTreatmentButtonV2 = "使用%s ×%d（持有 %d）\n创伤程度降低 %d", -- 清创按钮：物资名、消耗、持有、降低的创伤程度
    BodyTreatmentNoteV2 = "普通治疗恢复部位血量；医疗物资清除创伤。\n空血部位再次被命中后永久致残。", -- 健康界面滚动详情治疗规则说明
    BodyInjuryLogV2 = "%s · %s受到%s，伤势：%s（部位血量 %d/%d）", -- 创伤日志：角色名、部位、类型、阶段、部位血量及上限
    BodyDiseaseEntry = "%s\n%s", -- 疾病列表条目：疾病名、逐行属性影响
    BodySaveLegacy = "旧版身体健康记录无效", -- 身体存档校验失败时的玩家提示
    BodySaveLegacyPart = "旧版部位创伤记录无效", -- 身体存档校验失败时的玩家提示
    BodySaveMissing = "缺少完整的六个身体部位记录", -- 身体存档校验失败时的玩家提示
    BodySaveState = "部位血量、创伤或恢复计划无效", -- 身体存档校验失败时的玩家提示
    BodySaveCapacity = "部位血量上限与身体分配不一致", -- 身体存档校验失败时的玩家提示
    BodySaveTotals = "部位血量之和与角色总生命不一致", -- 身体存档校验失败时的玩家提示
    CampInsufficientCoins = "金币不足", -- 营地材料和金币交易余额不足
    CampInsufficientMaterials = "材料不足（先用仓库，再用背包）", -- 营地权威交易材料不足
    CampFacilityLevelChanged = "设施等级已变化", -- 营地建设提交时等级变化
    CampFacilityLevelInsufficient = "设施等级不足", -- 营地生产设施等级不足
    CampFacilityBusy = "该设施仍有订单，请先领取产物", -- 营地设施存在尚未领取的生产订单
    CampProductionPending = "生产尚未完成", -- 营地产物尚未到领取时间
    CampItemCountLimit = "物品数量已达上限", -- 营地产物或仓库取出将超过库存数量上限
    CampInvalidDeposit = "无效存入数量", -- 营地仓库存入参数无效
    CampBackpackInsufficient = "背包物品数量不足", -- 营地存入时随身物品不足
    CampWarehouseFull = "营地仓库已满，请升级或取出物品", -- 营地仓库存入超过容量
    CampInvalidWithdrawal = "无效取出物品或数量", -- 营地仓库取出参数无效
    CampWarehouseInsufficient = "仓库物品数量不足", -- 营地仓库取出数量不足
    CampWithdrawBackpackFull = "背包空间不足，物品仍保留在仓库中", -- 营地取出物品的整组容量不足
    CampInvalidWait = "无效等待时长", -- 营地等待时长不受支持
    CampTimeLimit = "游戏时间已达上限", -- 营地生产或等待超过世界时钟上限
    CampMissingMaterial = "缺少 %s", -- 营地配方预览：物品名称
    CampMaxLevel = "已达到最高等级", -- 营地设施已无后续升级
    CampRequiredFacilityLevel = "需要 %s %s 级", -- 营地生产要求：设施名称、所需等级
    CampItemQuantity = "%s ×%s", -- 营地材料或产物条目：物品名称、数量
    CampItemSeparator = "、", -- 营地材料或产物列表分隔符
    CampCostCoins = "%s 金币", -- 营地仅金币费用：金币数
    CampCostMaterialsCoins = "%s  +  %s 金币", -- 营地完整费用：材料列表、金币数
    BattleSelectionInvalidTarget = "请选择射程内的合法目标", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionFull = "已选满目标；再次点击已选目标可取消", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionNoLanding = "该目标附近没有合法落点，请选择其他目标", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionInvalidLanding = "请选择高亮的合法落点，或按 Esc 取消", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionHit = "命中 {0:0.#}%", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionIntercept = "{0} · 误击 {1:0.#}%", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionFriendlyRisk = "{0} · 有友军风险", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionLandingHint = "目标：{0}。点击高亮地格确认落点并施放，Esc 取消", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionLandingTargetHint = "先选择目标，再点击合法落点；选择期间不消耗行动或材料", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionCountRisk = "已选 {0}/{1} · {2}", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionTargetHint = "已选 {0}/{1} · 点击目标切换 · Enter 确认 · Esc 取消", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionBlockers = "{0}\n弹道经过 {1} 处遮挡", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionMultipleHelp = "{0}\n点击切换选择；可选 1 至 {1} 个不同敌人。Enter 确认，Esc 取消。", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionChooseLanding = "点击地格选落点", -- 职业扩展文本；保持现有占位参数格式
    BattleSelectionTrapHelp = "公开的一次性绊索：首个地面单位进入时中止移动，速度降低 2，持续 2 回合。友军与敌人都会触发。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionExploreFacility = "请靠近提供此服务的设施入口。", -- 职业探索技能找不到距离内设施时的提示
    ProfessionExploreDaily = "今天已经进行过这项活动，请明天再来。", -- 职业探索每日次数提示
    ProfessionExploreNoRumor = "酒馆暂时没有附近尚未记录的地点消息。", -- 真实传闻地点已耗尽或附近没有地点
    ProfessionExploreNotDeployed = "这位队员没有参与当前区域的探索。", -- 职业探索技能施术者不在探索队形
    ProfessionExploreNoPlant = "附近没有可见且尚未采过的炼金植物。", -- 炼金萃取需要真实可见未采植物
    ProfessionExploreBagFull = "背包空间不足，请先腾出材料的位置。", -- 炼金萃取物品容量检查失败
    ProfessionExploreCareTarget = "请选择附近存活且参与探索的队员。", -- 诊护目标不合法或超出范围
    ProfessionExploreNoRecovery = "这位队员没有可通过诊护加速的定时伤势。", -- 永久伤或无定时恢复的伤势不接受加速
    ProfessionExploreCareMaterial = "诊护需要一份急救包。", -- 诊护缺少急救包
    ProfessionExploreNoCurse = "当前持有的武器没有尚未净化的诅咒。", -- 识咒目标必须为当前装备的真实诅咒武器实例
    ProfessionExploreCleanseMaterial = "已经辨识诅咒；净化需要一份净化药剂。", -- 识咒第二阶段缺少净化药剂
    ProfessionExploreNoTrack = "附近没有最近观察到的有效动物足迹。", -- 循迹附近没有未过期的真实观测记录
    ProfessionExploreExtracted = "从附近的植物中萃取了 %s × %d。", -- Lua格式：材料名称、数量
    ProfessionExploreRumor = "在%s听闻了真实地点「%s」的消息，地图坐标为（%d，%d）。", -- Lua格式：消息来源酒馆、真实地点名、地图q、地图r
    ProfessionExploreCared = "完成对%s的诊护，现有定时伤势的恢复期限最多提前了 %d 分钟。", -- Lua格式：目标角色名、最大提前分钟数；永久伤不会恢复
    ProfessionExploreCleansed = "消耗了一份净化药剂，「%s」的这件武器已解除诅咒；再次装备不会重新触发。", -- Lua格式：武器配置名称；净化按实例保存
    ProfessionExploreTrackMoved = "辨认出%s的足迹：从区域坐标（%d，%d）走向（%d，%d），这是 %d 分钟前的真实观测。", -- Lua格式：动物名称、前次q/r、最近q/r、经过分钟；不是实时隐藏位置
    ProfessionExploreTrackStill = "辨认出%s的停留痕迹：观测始于（%d，%d），最近位置为（%d，%d），距今 %d 分钟。", -- Lua格式：动物名称、初次q/r、最近q/r、经过分钟
    ProfessionAlreadyBoundAnimal = "已经拥有一只动物同伴。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionRequired = "需要一只存活、独立随行并已进入本场战斗的动物同伴。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionDisabled = "动物同伴当前无法接受指令。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionTooFar = "动物同伴超出指令距离。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionNoSpace = "附近没有能容纳动物的空格，本场无法部署同伴。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionInvalidTarget = "请选择符合指令距离和阵营要求的存活目标。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionCommandSpent = "动物同伴本轮已用完此类指令，或正在执行救援。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionTooLarge = "目标体型过大或正在骑乘，动物无法衔拖。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionNoLanding = "没有可到达且能容纳目标的合法落点。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionChooseCell = "请在目标附近选择高亮的落点。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionNotRideable = "这只动物不能骑乘。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionFollowing = "动物已改为独立随行，生命与亲密度保持不变。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionMounted = "已骑乘同一只动物。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionCompanionDefeated = "动物同伴「%s」倒地。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelGroundOnly = "请在公会地面层的空地发起单挑。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelNoSpace = "公会附近没有足够的空地进行单挑。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelUnavailable = "目前无法发起礼式决斗。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelNoMount = "单挑需要先下马；可在生活技能中切换动物随行模式。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelLowHealth = "生命过低，先疗伤再参加单挑。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelDeposit = "金币不足以支付单挑的约定保证金。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelDaily = "今天已在这座城镇参加过单挑。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelStarted = "礼式决斗开始。任一方生命降到四分之一时认输；同伴不参战，胜者取回保证金并获得奖励。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelWon = "赢得公会单挑，保证金退还并获得约定奖励；伤势保留。", -- 职业扩展文本；保持现有占位参数格式
    ProfessionDuelLost = "公会单挑结束，保证金支付给对手；伤势保留，双方均未被处决。", -- 职业扩展文本；保持现有占位参数格式
    AmmoIncompatible = "弹药口径与弹匣不兼容", -- 工坊装填：目标弹药不属于弹匣口径
    AmmoMagazineFull = "弹匣已满", -- 工坊补充当前弹种时没有空余容量
    AmmoUnavailable = "背包中没有所选弹药", -- 工坊装填时没有可消费的弹药
    AmmoCountLimit = "退回余弹将超过物品数量上限", -- 换弹种时退回旧弹药超过库存数量上限
    AmmoReturnBackpackFull = "背包放不下退回的余弹，装填已取消", -- 换弹种容量检查失败，两种弹药与弹匣均保持不变
    AmmoSelectMagazine = "请选择随身携带的弹匣", -- 工坊要求队员或背包中的弹匣
    EquipmentAmmoStats = "肉伤 ×%.2f · 甲伤 ×%.2f · 穿甲 %+g 个百分点", -- 弹药说明：肉伤倍率、甲伤倍率、穿甲百分点修正
    EquipmentMagazineSummary = "%s · %d/%d 发", -- 弹匣说明：实际弹药名、余弹、容量
    EquipmentWeaponArmor = "直接伤生命 %g%% · 甲伤 ×%.2f", -- 武器属性：基础穿甲百分比、甲伤倍率
    EquipmentArmorRule = "每次命中按穿甲比例分成肉体伤害和护甲伤害，穿甲不是概率；正数肉伤最低1点。破甲后的剩余伤害溢出生命，护甲耐久归零后不会掉落。", -- 装备详情中的承伤与战利品规则
    WorkbenchMagazineName = "%s #%d", -- 工坊弹匣标题：弹匣物品名、实例编号
    WorkbenchMagazineSelect = "%s · %s · 点击选择装填", -- 工坊弹匣条目：弹种余弹说明、备用或已装入状态
    WorkbenchAmmoTitle = "装填弹匣 #%d · 选择弹种", -- 工坊弹种选项标题：弹匣实例编号
    WorkbenchAmmoInstructions = "选择弹种后点击装填按钮；换种时余弹退回背包。点击挂点返回装配。", -- 工坊装填操作说明
    WorkbenchAmmoStock = "%s · 库存 %d 发", -- 工坊弹种条目：弹药属性说明、库存数量
    WorkbenchAmmoTarget = "装填目标：%s #%d · 当前 %s", -- 工坊装填目标：弹匣名称、实例编号、当前弹种余弹说明
    WorkbenchAmmoSelected = "待装弹药：%s · 库存 %d 发", -- 工坊当前选择：弹药名称、库存数量
    BattleAmmoSummary = "%s · %d/%d", -- 战斗HUD弹药：实际弹种名称、余弹、容量
    BattleArmorResult = " · %s耐久 %g→%g（甲伤 %g；吸收 %g；穿透 %g；溢出 %g）", -- 战斗实际护甲结算：部位名、原耐久、剩余耐久、甲伤、吸收、穿透、溢出
    BattleArmorBroken = " · 护甲已打烂，无法掉落", -- 战斗中护甲耐久归零的战利品提示
    BattleArmorPreserved = " · 本次未损伤护甲", -- 保甲攻击的实际结算提示
    EffectTriggered = "触发", -- 附加效果检定成功
    EffectNotTriggered = "未触发", -- 附加效果检定失败
    BattleCheckGreater = " · 掷值 > %g 成功（成功率 %g%%）", -- 附加效果高点数检定：门槛、成功率
    BattleCheckRoll = " · 掷出 %g/100", -- 已结算的1至100掷值
    DiceRequirementGreater = "掷值大于 %g 成功 · 成功率 %g%%", -- 骰子展示：高点数成功门槛、成功率
    EffectTooltipBody = "%s\n\n来源  %s\n层数  %d\n持续  %s", -- 状态说明：效果、来源名、层数、剩余时间
    EffectRemainingTurns = "剩余 %d 回合", -- 状态剩余回合
    EffectRemainingMinutes = "剩余 %d 分钟", -- 状态剩余游戏分钟
    EffectIndefinite = "持续生效", -- 无期限状态
    EffectMinuteTimer = "%dm", -- 状态图标的分钟倒计时
-- @localization-end
}
return require('Config.LanguageProxy').Create(defaults)

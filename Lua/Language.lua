-- Add literal fields inside this block. Export copies trailing comments into LuaTxt.desc.
-- LuaTxt takes priority; unexported new fields still work through these defaults.
local defaults = {
-- @localization-begin
    Confirm = "确认", -- 通用确认按钮
    Cancel = "取消", -- 通用取消按钮
    RewardReceived = "已获得奖励", -- 领取奖励后的提示
    BattleEnemyTurn = "敌方正在行动…", -- 战斗 HUD
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
    BattleAdvanceAI = "推进敌方回合", -- 战斗 HUD
    BattleMove = "移动  [Esc]", -- 战斗 HUD
    BattleFocus = "定位战场  [F]", -- 战斗 HUD
    BattleAutoOn = "敌方自动行动：开", -- 战斗 HUD
    BattleAutoOff = "敌方自动行动：关", -- 战斗 HUD
    BattleHideLog = "收起战斗记录", -- 战斗 HUD
    BattleShowLog = "展开战斗记录", -- 战斗 HUD
    BattleMoveHint = "点击绿色地格移动；数字键 1—8 选择技能。", -- 战斗 HUD
    BattleTargetHint = "点击高亮角色施放技能。", -- 战斗 HUD
    BattleSelfHint = "点击当前角色施放技能。", -- 战斗 HUD
    BattleSkillCost = "%d AP  ·  %s  ·  射程 %d", -- 战斗 HUD
    BattleMain = "主要行动", -- 战斗 HUD
    BattleSecondary = "次要行动", -- 战斗 HUD
    BattleItemHint = "物品槽位\n当前仅展示配置图标，尚未接入背包与物品使用。", -- 战斗 HUD
-- @localization-end
}
return require('Config.LanguageProxy').Create(defaults)

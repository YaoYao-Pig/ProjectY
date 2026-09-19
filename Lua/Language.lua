-- Add literal fields inside this block. Export copies trailing comments into LuaTxt.desc.
-- LuaTxt takes priority; unexported new fields still work through these defaults.
local defaults = {
-- @localization-begin
    Confirm = "确认", -- 通用确认按钮
    Cancel = "取消", -- 通用取消按钮
    RewardReceived = "已获得奖励", -- 领取奖励后的提示
-- @localization-end
}
return require('Config.LanguageProxy').Create(defaults)

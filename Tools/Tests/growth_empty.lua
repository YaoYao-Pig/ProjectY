-- 旧只读战斗夹具的零养成状态；真实可变状态由 growth_integration.lua 验证。
return function()
    return {TalentCount=0,SkillCount=0,GetAttribute=function() return 0 end}
end

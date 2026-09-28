-- 技能的使用场景是独立标签；同一技能可以同时用于生活与战斗。
return function(skill,context)
    for _,value in ipairs(skill.contexts) do if value==context then return true end end
    return false
end

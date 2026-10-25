-- Read-only combat geometry rules. Natural terrain and construction use the same final cell heights.
local LuaLanguage=require('Language')
local Height={};Height.__index=Height
function Height.New(config)
    local rule=config:GetTable('HeightAdvantageTable'):Get(1)
    assert(rule.heightPerLevel>0 and rule.maxLevels>=1 and math.tointeger(rule.maxLevels),'Invalid height advantage levels')
    assert(rule.hitPerLevel>=0 and rule.rangePerLevel>=0 and math.tointeger(rule.rangePerLevel),'Invalid height advantage bonuses')
    return setmetatable({rule=rule},Height)
end
function Height:Levels(origin,target)
    if not origin.height or not target.height or (origin.layer or 0)~=(target.layer or 0) then return 0 end
    return math.min(self.rule.maxLevels,math.max(0,math.floor((origin.height-target.height+.00001)/self.rule.heightPerLevel)))
end
function Height:RangeBonus(origin,target,skill)
    if skill.target~='enemy' or skill.range<=1 or skill.fixedRange then return 0 end
    return self:Levels(origin,target)*self.rule.rangePerLevel
end
function Height:HitChance(origin,target,skill)
    local bonus=skill.target=='enemy' and skill.proficiency~='bow' and self:Levels(origin,target)*self.rule.hitPerLevel or 0
    return math.min(100,skill.hitChance+bonus)
end
function Height:AdvantageSources(origin,target,skill)
    if skill.target=='enemy' and skill.proficiency=='bow' and self:Levels(origin,target)>0 then return {'high_ground'} end
end
function Height:Description(skill)
    if skill.target~='enemy' then return '' end
    local rule=self.rule
    local text=skill.proficiency=='bow' and string.format(LuaLanguage.HeightAdvantageBow,rule.heightPerLevel) or
        string.format(LuaLanguage.HeightAdvantageHit,rule.heightPerLevel,rule.hitPerLevel,rule.hitPerLevel*rule.maxLevels)
    if skill.range>1 and not skill.fixedRange then text=string.format(LuaLanguage.HeightAdvantageRange,text,rule.rangePerLevel,rule.rangePerLevel*rule.maxLevels) end
    return string.format(LuaLanguage.HeightAdvantageTarget,text)
end
return Height

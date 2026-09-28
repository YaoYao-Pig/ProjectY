-- 独立开发命令入口；不复制角色、经验、技能或当前队伍状态。
local Class=require('Core.Class')
local System=require('Core.LuaSystem')
local GM=Class('GMSystem',System)
local function integer(value) return type(value)=='number' and value%1==0 end
function GM:OnInit(context)
    System.OnInit(self,context)
    self.data=context.services.Adventure
    self.growth=context.systems:Get('Growth')
    self.skills=context.systems:Get('Config'):GetTable('CombatSkillTable')
    self.commands={level_up=self.LevelUp,grant_skill=self.GrantSkill}
end
function GM:Slot(slot)
    if not integer(slot) or slot<1 or slot>self.data.PartyCount then return nil,'槽位必须是 1～'..self.data.PartyCount..' 的有效队员槽位' end
    return self.data:GetPartyAt(slot-1)
end
function GM:Skill(id)
    if not integer(id) or id<1 then return nil end
    return self.skills:Find(id)
end
function GM:Execute(command,slot,value)
    local action=self.commands[command]
    if not action then return false,'未知 GM 命令：'..tostring(command) end
    local actor,reason=self:Slot(slot);if not actor then return false,reason end
    return action(self,actor,value)
end
function GM:LevelUp(actor)
    local growth,rules=actor.Growth,self.growth.rules
    if growth.Level>=rules.maxLevel then return false,'角色已达到配置等级上限 '..rules.maxLevel end
    local nextLevel=rules.levels:Get(growth.Level+1)
    local needed=nextLevel.experience-growth.Experience
    assert(needed>0,'Actor has unprocessed level-up experience')
    self.growth:AddExperience(actor,needed,'GM 调试')
    return true,self.growth.stats:Template(actor).name..' 已升至 '..growth.Level..' 级'
end
function GM:GrantSkill(actor,id)
    local skill=self:Skill(id)
    if not skill then return false,'无效技能 ID：'..tostring(id) end
    if not actor.Growth:GrantSkill(id) then return false,'角色已掌握「'..skill.name..'」' end
    self.growth.chronicle:Record('growth',actor,'GM 授予技能','学会「'..skill.name..'」（ID '..id..'）。','GM 调试',false)
    self.growth:PrepareOffers(actor)
    return true,self.growth.stats:Template(actor).name..' 已获得「'..skill.name..'」'
end
function GM:OnShutdown() self.data=nil;self.growth=nil;self.skills=nil;self.commands=nil end
return GM

-- 技能栏的查询和命令适配器；UI 只保存当前角色与技能选择，玩法状态归原系统。
local Supports=require('Game.Battle.SkillContext')
local Skills={};Skills.__index=Skills
function Skills.New(adventure)
    local self=setmetatable({adventure=adventure,handlers={},skills=adventure.config:GetTable('CombatSkillTable'),
        effects=adventure.config:GetTable('CombatEffectTable')},Skills)
    self:Register('tame',{
        CanUse=function(actor,id) return adventure.areas:CanTame(actor.Id,id) end,
        Use=function(actor,id) return adventure.areas:Tame(actor.Id,id) end,
        Targets=function()
            local state=adventure.data.Areas.Active;local area=adventure.areas:ActiveLayout()
            local visible,targets={},{}
            for i=0,state.VisibleCount-1 do visible[state:GetVisibleAt(i)]=true end
            for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
                for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j)
                    if actor.Team==0 and actor.HP>0 and actor.AnimalOwnerId==0 and visible[area:Find(actor.Q,actor.R).index] then targets[#targets+1]=actor.Id end
                end
            end
            return targets
        end})
    return self
end
function Skills:Register(effectKind,handler)
    assert(not self.handlers[effectKind] and handler.CanUse and handler.Use and handler.Targets,'Invalid or duplicate life skill handler')
    self.handlers[effectKind]=handler
end
function Skills:Actor(id)
    for i=0,self.adventure.data.PartyCount-1 do local actor=self.adventure.data:GetPartyAt(i);if actor.Id==id then return actor end end
end
function Skills:Handler(skill)
    assert(#skill.effectIds==1,'Life skill handlers require one effect instruction')
    return assert(self.handlers[self.effects:Get(skill.effectIds[1]).kind],'Life skill has no registered effect handler')
end
function Skills:Context() return self.adventure.data.Phase=='battle' and 'battle' or 'life' end
function Skills:CanUse(actorId,skillId,targetId)
    local actor=self:Actor(actorId)
    if not actor or actor.HP<=0 then return false,'请选择存活的队员' end
    local skill=self.skills:Find(skillId);if not skill then return false,'未知技能' end
    local owns=false
    for _,id in ipairs(self.adventure.battle:SkillIds(actor)) do if id==skillId then owns=true;break end end
    if not owns then return false,'角色没有这个技能' end
    local context=self:Context()
    if not Supports(skill,context) then return false,'此技能不能在当前场景使用' end
    if context=='battle' then
        local battle=self.adventure.battle
        if battle.data.ActiveId~=actorId then return false,'请等待此角色的回合' end
        if skill.target=='cell' then
            local cell=battle.board.area and battle.board.area.cells[targetId] or battle.board.cells[targetId]
            if not cell then return false,'请选择技能落点' end
            return battle:CanUseSkillAt(skillId,cell.q,cell.r)
        end
        return battle:CanUseSkill(skillId,targetId)
    end
    if self.adventure.data.Phase~='area' then return false,'进入小地图后使用' end
    return self:Handler(skill).CanUse(actor,targetId)
end
function Skills:Use(actorId,skillId,targetId)
    local ok,reason=self:CanUse(actorId,skillId,targetId);if not ok then return false,reason end
    if self:Context()=='battle' then
        return self.adventure:BattleCommand(self.skills:Get(skillId).target=='cell' and 'skill_cell' or 'skill',skillId,targetId)
    end
    return self:Handler(self.skills:Get(skillId)).Use(self:Actor(actorId),targetId)
end
function Skills:Rows(actorId,context)
    local actor=self:Actor(actorId);if not actor then return {} end
    local rows={}
    for _,id in ipairs(self.adventure.battle:SkillIds(actor)) do
        local skill=self.skills:Get(id)
        if Supports(skill,context) then
            local targets={}
            if context=='life' and self.adventure.data.Phase=='area' then targets=self:Handler(skill).Targets(actor)
            elseif context=='battle' then
                if skill.target=='cell' then for _,cell in ipairs(self.adventure.battle:SkillCells(id)) do targets[#targets+1]=cell.index end
                else for _,unit in ipairs(self.adventure.battle:Units()) do targets[#targets+1]=unit.Id end end
            end
            local available,reason=false,'附近没有可用目标'
            if self.adventure.data.Phase=='map' then reason='进入小地图后使用' end
            if actor.HP<=0 then reason='角色已倒地' end
            for _,targetId in ipairs(targets) do
                local ok,why=self:CanUse(actorId,id,targetId)
                if ok then available=true;reason='';break end
                reason=why
            end
            local labels={};for _,tag in ipairs(skill.contexts) do labels[#labels+1]=tag=='life' and '生活' or '战斗' end
            rows[#rows+1]={id=id,name=skill.name,description=skill.description,contexts=table.concat(labels,' + '),
                target=skill.target=='self' and 'self' or skill.target=='cell' and 'cell' or 'unit',available=available,reason=reason}
        end
    end
    return rows
end
return Skills

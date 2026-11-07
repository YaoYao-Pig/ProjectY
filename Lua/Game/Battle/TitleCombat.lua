local Life=require('Game.Battle.ActorLife')
-- Title definitions are read-only; kill evidence and per-turn limits belong to C# battle state.
local Combat={};Combat.__index=Combat
local function state()return CS.ProjectY.Data.TitleCombatState end
local healEffect={kind='heal',duration='instant'}
function Combat.New(battle)return setmetatable({battle=battle,stats=battle.stats},Combat)end
function Combat:Begin()state().BeginBattle(self.battle.data)end
function Combat:BeginTurn(actor)state().BeginTurn(actor)end
function Combat:Finish()
    for i=0,self.battle.data.UnitCount-1 do state().End(self.battle.data:GetUnitAt(i))end
end
function Combat:Damage(source,target,amount,skill,periodic,attackHit)
    if amount<=0 then return amount end
    local bonus=0
    if source and source~=target and source.HP>0 and source.HP*100<source.MaxHP*30 and skill and attackHit and not periodic then
        bonus=self.stats.titles:Effect(source,'low_health_damage_percent')
    end
    local incoming=self.stats.titles:Effect(target,'damage_taken_percent')
    amount=math.floor(amount*(100+bonus)/100*(100+incoming)/100+0.000000001)
    assert(amount<=1000000,'Title damage exceeds effect bounds')
    return amount
end
function Combat:Heal(actor,percent,title)
    if percent<=0 or actor.HP<=0 or not Life.Alive(actor) then return end
    local amount=math.max(1,math.floor(actor.MaxHP*percent/100))
    self.battle.gameEffects:Execute(healEffect,actor,amount,actor.Id,self.stats:Template(actor).name,title.name,actor,false,{titleEffect=true},false)
end
function Combat:Defeated(source,target,sourceId)
    local battle=self.battle
    if battle.data.Phase~='combat' or battle.data.Winner~='' or Life.Alive(target) then return end
    local attacker=source or (sourceId and battle:FindUnit(sourceId))
    if not attacker or battle:FindUnit(attacker.Id)~=attacker or battle:FindUnit(target.Id)~=target
        or target.AnimalOwnerId~=0 or not battle:IsHostile(attacker,target) then return end
    if not state().RecordKill(battle.data,target.Id)then return end
    -- Called only by actual damage execution, never by public defeated/GM notifications.
    if self.onKill then self.onKill(attacker,target)end
    if attacker.HP<=0 or not Life.Alive(attacker) then return end
    local titles=self.stats.titles
    local heal=titles:Effect(attacker,'kill_heal_percent');local morale=titles:Effect(attacker,'kill_morale')
    if heal<=0 and morale<=0 or not state().TryKillBenefit(attacker,2)then return end
    local title=assert(titles:Equipped(attacker),'Title effect requires an equipped title')
    self:Heal(attacker,heal,title)
    if morale>0 then battle.morale:Change(battle,attacker,morale,title.name)end
end
function Combat:EndTurn(actor)
    if self.battle.data.Phase~='combat' or self.battle.data.Winner~='' or actor.HP<=0 or not Life.Alive(actor) then return end
    local titles=self.stats.titles;local percent=titles:Effect(actor,'turn_heal_percent')
    if percent>0 then self:Heal(actor,percent,assert(titles:Equipped(actor),'Title effect requires an equipped title'))end
end
return Combat

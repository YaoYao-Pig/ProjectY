local Life=require('Game.Battle.ActorLife')
local Hex=require('Game.Map.HexGrid')
local L=require('Language')
local Rules={};Rules.__index=Rules
local function state()return CS.ProjectY.Data.MoraleState end
function Rules.New(config,stats)
    local self=setmetatable({stats=stats,rule=config:GetTable('MoraleRuleTable'):Get(1),
        stages=config:GetTable('MoraleStageTable'),events=config:GetTable('MoraleEventTable'),byStage={},byEvent={}},Rules)
    local previous=-1
    for stage=-3,1 do
        local row=self.stages:Get(stage+4)
        assert(row.stage==stage and row.minimumPercent>previous and row.minimumPercent<=100,'Invalid morale stage thresholds')
        self.byStage[stage]=row;previous=row.minimumPercent
    end
    assert(self.byStage[-3].minimumPercent==0 and self.rule.minimumChance<=self.rule.maximumChance,'Invalid morale bounds')
    for _,row in ipairs(self.events:All())do assert(not self.byEvent[row.kind],'Duplicate morale event');self.byEvent[row.kind]=row end
    for _,kind in ipairs({'wound','ally_defeated','ally_fleeing','enemy_defeated','kill','outnumbered','rally'})do assert(self.byEvent[kind],'Missing morale event: '..kind)end
    return self
end
function Rules:Maximum(actor)
    local title=self.stats.titles:Equipped(actor)
    local maximum=self.rule.maximum:Evaluate({courage=self.stats:Get(actor,'courage')})+(title and title.moraleMaximum or 0)
    return math.max(1,math.min(1000000,math.floor(maximum)))
end
function Rules:Stage(current,maximum)
    local percent=current*100/maximum
    for stage=1,-3,-1 do if percent>=self.byStage[stage].minimumPercent then return stage end end
    error('Morale thresholds do not cover zero')
end
function Rules:Row(actor)return self.byStage[state().Active(actor) and state().Stage(actor) or 0]end
function Rules:Fleeing(actor)return state().Active(actor) and state().Stage(actor)==-3 end
function Rules:Attribute(actor,name,value)
    if not state().Active(actor)then return value end
    if name=='defense' then return math.max(0,math.floor(value*self:Row(actor).defenseScale))end
    return value
end
function Rules:Skill(actor,skill)
    local title=self.stats.titles:Equipped(actor)
    if title then skill.damageScale=skill.damageScale*(1+title.damagePercent/100)end
    if state().Active(actor)then
        local row=self:Row(actor);skill.hitChance=math.max(0,math.min(100,skill.hitChance*row.hitScale))
    end
    return skill
end
function Rules:Projection(actor)
    local maximum=self:Maximum(actor)
    if state().Active(actor)then return state().Current(actor),state().Maximum(actor),self:Row(actor).name end
    return math.floor(maximum*self.rule.initialPercent/100),maximum,self.byStage[0].name
end
function Rules:Begin(battle)
    state().BeginBattle(battle.data)
    for _,actor in ipairs(battle:Units())do
        CS.ProjectY.Data.DeathDoorState.BeginBattle(actor)
        local maximum=self:Maximum(actor);local current=math.floor(maximum*self.rule.initialPercent/100)
        state().Begin(actor,maximum,current,self:Stage(current,maximum))
    end
end
function Rules:End(battle)
    for i=0,battle.data.UnitCount-1 do state().End(battle.data:GetUnitAt(i))end
end
function Rules:Neighbors(battle,actor)
    local allies,enemies=0,0
    for _,other in ipairs(battle:Units())do
        if other~=actor and Life.Alive(other) and self.stats.animals:Distance(actor,other,battle.board)<=self.rule.supportRadius then
            if battle:IsHostile(actor,other)then enemies=enemies+1
            elseif battle:IsAllied(actor,other)and not self:Fleeing(other)then allies=allies+1 end
        end
    end
    return allies,enemies
end
function Rules:Change(battle,actor,delta,reason)
    if not Life.Alive(actor) or not state().Active(actor)then return end
    local before,oldStage=state().Current(actor),state().Stage(actor)
    local maximum=self:Maximum(actor);local current=math.max(0,math.min(maximum,before+delta))
    local stage=self:Stage(current,maximum)
    state().Set(actor,maximum,current,stage)
    if before~=current or stage~=oldStage then
        battle:Emit('morale_changed',string.format(L.MoraleChanged,self.stats:Template(actor).name,reason,current,maximum,self.byStage[stage].name),actor.Id,actor.Id,current-before,actor)
    end
    -- A downward crossing broadcasts once. Already fleeing allies cannot recursively rebroadcast.
    if stage==-3 and oldStage~=-3 then
        for _,other in ipairs(battle:Units())do
            if other~=actor and Life.Alive(other) and battle:IsAllied(actor,other)
                and self.stats.animals:Distance(actor,other,battle.board)<=self.rule.witnessRadius then
                self:Check(battle,other,'ally_fleeing')
            end
        end
    end
end
function Rules:Check(battle,actor,kind)
    if not Life.Alive(actor) or not state().Active(actor)then return false end
    local event=assert(self.byEvent[kind]);local allies,enemies=self:Neighbors(battle,actor)
    local chance=math.max(self.rule.minimumChance,math.min(self.rule.maximumChance,
        self.stats:Get(actor,'courage')+self:Row(actor).checkBonus+allies*self.rule.allyBonus-enemies*self.rule.enemyPenalty-event.difficulty))
    local roll=battle.data:RollPercent()+1;local passed=roll<=chance
    battle:Emit('morale_check',string.format(L.MoraleCheck,self.stats:Template(actor).name,event.name,roll,chance,passed and L.MoralePassed or L.MoraleFailed),actor.Id,actor.Id,0,actor)
    if event.change>0 and passed or event.change<0 and not passed then self:Change(battle,actor,event.change,event.name)end
    return passed
end
function Rules:OnEvent(battle,event)
    if event.kind=='battle_started'then self:Begin(battle);return end
    if battle.data.Phase~='combat' or battle.data.Winner~=''then return end
    local target=event.target
    if event.kind=='damage' and target and Life.Alive(target) and event.amount>0 and event.impact then
        local hit=event.impact
        if hit.hpBefore and hit.hpAfter and hit.hpBefore-hit.hpAfter>=hit.maxHP*self.rule.woundPercent/100 then self:Check(battle,target,'wound')end
    elseif event.kind=='defeated' and target and not Life.Alive(target) and state().RecordDefeat(battle.data,target.Id)then
        local source=event.sourceId and battle:FindUnit(event.sourceId)
        for _,actor in ipairs(battle:Units())do
            if Life.Alive(actor) then
                if actor==source and battle:IsHostile(actor,target)then self:Check(battle,actor,'kill')
                elseif self.stats.animals:Distance(actor,target,battle.board)<=self.rule.witnessRadius then
                    if battle:IsAllied(actor,target)then self:Check(battle,actor,'ally_defeated')
                    elseif battle:IsHostile(actor,target)then self:Check(battle,actor,'enemy_defeated')end
                end
            end
        end
    end
end
function Rules:BeginTurn(battle,actor)
    if not state().Active(actor)then return end
    local maximum=self:Maximum(actor)
    if maximum~=state().Maximum(actor)then self:Change(battle,actor,0,L.MoraleCapacityChanged)end
    if self:Fleeing(actor)then
        local nearest=math.huge
        for _,other in ipairs(battle:Units())do if Life.Alive(other) and battle:IsHostile(actor,other)then
            nearest=math.min(nearest,self.stats.animals:Distance(actor,other,battle.board))
        end end
        if nearest>self.rule.rallyDistance and self:Check(battle,actor,'rally')then
            local floor=math.ceil(maximum*self.byStage[-1].minimumPercent/100)
            if state().Current(actor)<floor then self:Change(battle,actor,floor-state().Current(actor),self.byEvent.rally.name)end
        end
    else
        local allies,enemies=self:Neighbors(battle,actor)
        if enemies>allies+1 then self:Check(battle,actor,'outnumbered')end
    end
end
function Rules:FleeDestination(battle,actor,cells)
    local enemies={}
    for _,other in ipairs(battle:Units())do if Life.Alive(other) and battle:IsHostile(actor,other)then enemies[#enemies+1]=other end end
    local function distance(q,r)
        local nearest=math.huge
        for _,other in ipairs(enemies)do nearest=math.min(nearest,Hex.Distance(q,r,other.Q,other.R))end
        return nearest
    end
    local best,bestScore=nil,distance(actor.Q,actor.R)
    for _,cell in ipairs(cells)do
        local score=distance(cell.q,cell.r)
        if score>bestScore or best and score==bestScore and (cell.q<best.q or cell.q==best.q and cell.r<best.r)then best,bestScore=cell,score end
    end
    return best
end
function Rules:Flee(battle,actor)
    assert(actor==battle:Active() and self:Fleeing(actor),'Only the active fleeing actor may retreat')
    local best=self:FleeDestination(battle,actor,battle:Reachable())
    if best then battle:TryMove(best.q,best.r,true)end
    if battle.data.Winner=='' and battle.data.ActiveId==actor.Id and Life.Alive(actor) then battle:EndTurn()end
end
return Rules

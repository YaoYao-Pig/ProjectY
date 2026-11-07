local Life=require('Game.Battle.ActorLife')
local L=require('Language')
local Model={};Model.__index=Model
local function state()return CS.ProjectY.Data.TitleState end
function Model.New(adventure)
    return setmetatable({adventure=adventure,rules=adventure.battle.stats.titles},Model)
end
function Model:Actor(id)
    for i=0,self.adventure.data.PartyCount-1 do
        local actor=self.adventure.data:GetPartyAt(i);if actor.Id==id then return actor end
    end
end
function Model:Start()
    assert(not self.unsubscribe,'Title events already subscribed')
    local combat=self.adventure.battle.titleCombat
    assert(not combat.onKill,'Title kill callback already attached')
    combat.onKill=function(source,target)self:RewardKill(source,target)end
    self.unsubscribe=self.adventure.battle.Changed:Subscribe(function(event)self:OnBattleEvent(event)end)
end
function Model:Dispose()
    if self.unsubscribe then self.unsubscribe();self.unsubscribe=nil end
    self.adventure.battle.titleCombat.onKill=nil
end
function Model:RewardKill(source,target)
    local actor=self:Actor(source.Id)
    if actor~=source or actor.Team~=1 or not self.adventure.battle:IsHostile(1,target) then return end
    local legend=self.adventure.parties.legends.byUnit[target.TemplateId]
    local amount=legend and self.rules.forge.policy.legendReward or self.rules.forge.policy.killReward
    CS.ProjectY.Data.ReputationState.AwardKill(self.adventure.data,target.Id,amount)
end
function Model:Evaluate(actor)
    for _,row in ipairs(self.rules.definitions:All())do
        if not state().Owns(actor,row.id) and self.rules:Eligible(actor,row,self.adventure.data.PartyBonds)then
            state().Award(actor,row.id)
            local site=self.adventure.sites[self.adventure.data.SiteId]
            self.adventure.growth.chronicle:Record('honor',actor,L.TitleAwardHistory,
                string.format(L.TitleAwardDescription,row.name),site and site.name or L.TitleJourney)
        end
    end
end
function Model:Increment(actor,kind,id)
    state().Increment(actor,kind..':0')
    if id>0 then state().Increment(actor,kind..':'..id)end
end
function Model:OnBattleEvent(event)
    local battle=self.adventure.battle
    if event.kind=='battle_started' then
        CS.ProjectY.Data.ReputationState.BeginBattle(self.adventure.data)
        for i=0,self.adventure.data.PartyCount-1 do state().BeginBattle(self.adventure.data:GetPartyAt(i))end
    elseif event.kind=='defeated' and battle.data.Phase=='combat' then
        local actor=event.sourceId and self:Actor(event.sourceId);local target=event.target
        if actor and actor.Team==1 and target and not Life.Alive(target) and target.AnimalOwnerId==0 and battle:IsHostile(actor,target)
            and state().RecordKill(actor,target.Id)then
            self:Increment(actor,'kill',target.TemplateId)
            local legend=self.adventure.parties.legends.byUnit[target.TemplateId]
            if legend then self:Increment(actor,'legend',legend.id)end
            self:Evaluate(actor)
        end
    elseif event.kind=='heal' and event.sourceId then
        local actor=self:Actor(event.sourceId);if actor then self:Evaluate(actor)end
    end
end
function Model:Complete(kind,id,definitionId)
    assert(kind=='mission' or kind=='quest' or kind=='town','Unknown title completion source')
    for i=0,self.adventure.data.PartyCount-1 do
        local actor=self.adventure.data:GetPartyAt(i)
        if state().RecordSettlement(actor,kind,id)then
            self:Increment(actor,kind,definitionId or id)
            -- Mission totals include commissioned town jobs, never intermediate quest steps.
            if kind=='town' then state().Increment(actor,'mission:0')end
            self:Evaluate(actor)
        end
    end
    local amount=self:CompletionReward(kind)
    if amount>0 and CS.ProjectY.Data.ReputationState.AwardSettlement(self.adventure.data,kind,id,amount)then return amount end
    return 0
end
function Model:CompletionReward(kind)
    local policy=self.rules.forge.policy
    return kind=='mission' and policy.missionReward or kind=='town' and policy.townReward or 0
end
function Model:ForgeRows()return self.rules.forge:Rows()end
function Model:Quote(name,ranks)return self.rules.forge:Quote(name,ranks)end
function Model:Craft(actorId,name,ranks)
    local data=self.adventure.data
    if data.Phase~='map' and data.Phase~='area' then return false,L.TitleExploreOnly end
    local actor=self:Actor(actorId);if not actor then return false,L.TitleInvalidActor end
    local quote=self:Quote(name,ranks)
    if not quote.valid then return false,quote.reason end
    local id=state().Craft(data,actor,quote.name,quote.serialized,quote.cost)
    if id==0 then return false,L.TitleForgeInsufficient end
    return true,'',id
end
function Model:Equip(actorId,titleId)
    local data=self.adventure.data
    if data.Phase~='map' and data.Phase~='area' then return false,L.TitleExploreOnly end
    local actor=self:Actor(actorId);if not actor then return false,L.TitleInvalidActor end
    if type(titleId)~='number' or not math.tointeger(titleId) then return false,L.TitleNotOwned end
    if titleId~=0 and not state().Owns(actor,titleId)then return false,L.TitleNotOwned end
    if titleId>0 and not self.rules.definitions:Find(titleId)then return false,L.TitleNotOwned end
    state().Equip(actor,titleId)
    actor:SetMaxHP(self.adventure.battle.stats:MaximumHP(actor))
    self.adventure.battle.stats.spellcasting:Sync(actor)
    return true
end
return Model

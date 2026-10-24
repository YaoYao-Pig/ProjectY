-- Special-event orchestration. Durable identity/outcomes live in NarrativeData flags;
-- the combatant, wounds and equipment remain owned by the saved area encounter.
local Hex=require('Game.Map.HexGrid')
local Events={};Events.__index=Events
function Events.New(adventure)
    local self=setmetatable({adventure=adventure,byEvent={},byArea={},byNpc={},byChoice={}},Events)
    for _,row in ipairs(adventure.config:GetTable('SpecialEventTable'):All()) do
        assert(not self.byEvent[row.eventId] and not self.byArea[row.areaId] and not self.byNpc[row.npcId],'Duplicate special event identity')
        assert(row.key:match('^[%a_][%w_]*$'),'Invalid special event fact key')
        local encounter=adventure.config:GetTable('CombatEncounterTable'):Get(row.encounterId)
        assert(encounter.enemyIds[row.allyIndex]==row.allyUnitId,'Special event ally slot does not match encounter')
        assert(row.townRadius>=0 and row.initialHealthPercent>=1 and row.initialHealthPercent<=100,'Invalid special event entry or initial health')
        assert(#row.initialInjuryPartIds==#row.initialInjuryTypeIds and #row.initialInjuryPartIds==#row.initialInjuryDamage and
            #row.initialInjuryPartIds==#row.injuryRecoveryMinutes,'Special event injury arrays differ')
        self.byEvent[row.eventId]=row;self.byArea[row.areaId]=row;self.byNpc[row.npcId]=row
        for _,id in ipairs({row.enterChoiceId,row.battleChoiceId,row.leaveChoiceId}) do
            assert(not self.byChoice[id],'Special event choices must have one owner');self.byChoice[id]=row
        end
    end
    return self
end
function Events:Value(row,suffix) return self.adventure.data.Narrative:GetValue('flag:'..row.key..'_'..suffix) end
function Events:Set(row,suffix,value) self.adventure.data.Narrative:SetValue('flag:'..row.key..'_'..suffix,value) end
function Events:CanTrigger(eventId,cell)
    local row=self.byEvent[eventId];if not row then return true end
    if self:Value(row,'site')~=0 then return false end
    if row.townRadius==0 then return true end
    local definitions=self.adventure.config:GetTable('MapAreaTable')
    local townType=self.adventure.config:GetEnum('MapArea','E_MapAreaType').Town
    for _,site in ipairs(self.adventure.sites) do
        if site.areaConfigId and definitions:Get(site.areaConfigId).areaType==townType and
            Hex.Distance(cell.q,cell.r,site.q,site.r)<=row.townRadius then return true end
    end
    return false
end
function Events:Discovered(site)
    local row=self.byEvent[site.eventId];if not row then return end
    local previous=self:Value(row,'site')
    assert(previous==0 or previous==site.id,'Special event already has a world location')
    self:Set(row,'site',site.id)
end
function Events:CanEnter(site)
    local row=self.byEvent[site.eventId]
    if row and self:Value(row,'failed')==1 then return false,row.failureText end
    return true
end
function Events:Decorate(area)
    local row=self.byArea[area.configId];if not row then return end
    local plan=assert(area.encounterPlans[1],'Special event needs its configured encounter')
    assert(plan.encounterId==row.encounterId and #area.encounterPlans==1,'Special event encounter layout differs')
    plan.actorIds={[row.allyIndex]=10000+row.npcId};plan.teams={[row.allyIndex]=4}
    plan.initialHealthPercents={[row.allyIndex]=row.initialHealthPercent}
    local injuries={}
    for i,id in ipairs(row.initialInjuryPartIds) do
        local part=self.adventure.config:GetTable('BodyPartTable'):Get(id)
        self.adventure.config:GetTable('InjuryTypeTable'):Get(row.initialInjuryTypeIds[i])
        assert(row.initialInjuryDamage[i]>0 and row.initialInjuryDamage[i]<100,'Initial injury must be recoverable')
        injuries[#injuries+1]={part=part.index,kind=row.initialInjuryTypeIds[i],damage=row.initialInjuryDamage[i]}
    end
    plan.injuries={[row.allyIndex]=injuries}
end
function Events:FindAlly(row,state)
    for i=0,state.EncounterCount-1 do local group=state:GetEncounterAt(i)
        for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j)
            if actor.Id==10000+row.npcId then
                assert(actor.TemplateId==row.allyUnitId,'Special event actor identity differs')
                return actor,group
            end
        end
    end
end
function Events:BeforeExplore()
    local adventure=self.adventure
    local row=self.byArea[adventure.areas:ActiveLayout().configId];if not row then return false end
    -- A completed trial never starts another fight, including after loading/re-entry.
    if self:Value(row,'outcome')~=0 then return true end
    assert(adventure.events:BeginArea(row.sceneEventId,row.key..':decision',adventure.areas:ActiveLayout().name))
    return true
end
function Events:Choose(choice,resultText)
    local row=self.byChoice[choice.id];if not row then return false end
    local adventure=self.adventure;local data=adventure.data
    if choice.id==row.enterChoiceId then
        local site=assert(adventure.sites[data.SiteId]);self:Discovered(site)
        local cell=adventure.map:GetCell(site.q,site.r);local region=adventure.map:GetRegion(cell.regionId)
        local source={regionId=region.instanceId,regionConfigId=region.configId,regionType=region.regionType,
            q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights,encounterId=row.encounterId}
        assert(adventure.areas:EnterEventBattlefield(site,data.Seed,source,row.areaId,function(area)self:Decorate(area)end))
        adventure.equipment:InitializeLoot(adventure.areas)
        self:BeforeExplore()
    elseif choice.id==row.battleChoiceId then
        assert(adventure.areas:ActiveLayout().configId==row.areaId and self:Value(row,'outcome')==0,'Special encounter is no longer available')
        local actor,group=self:FindAlly(row,data.Areas.Active);assert(actor and actor.HP>0,'Special encounter ally is missing')
        data:Complete(resultText or adventure.events:Text(choice.result));data:ReturnToMap()
        local relations={[1]={[2]='hostile',[4]='allied'},[2]={[1]='hostile',[4]='hostile'},[4]={[1]='allied',[2]='hostile'}}
        local context={relations=relations,primary=2}
        if row.allyParticipates then
            context.aiProfiles={[actor.Id]={selfPreservation=true,retreatHealthRatio=0.5}};context.protectedActorId=actor.Id
        else context.excludedActorIds={[actor.Id]=true} end
        adventure.areas:StartBattle(adventure.battle,group,context)
        if not row.allyParticipates then
            assert(not adventure.battle.board:Find(actor.Q,actor.R),'A sheltered companion must remain outside the battle window')
        end
        adventure.battle.data:AddLog(row.objective)
    else
        data:Complete(resultText or adventure.events:Text(choice.result))
    end
    return true
end
function Events:ShouldLeave(choiceId)
    local row=self.byChoice[choiceId];return row and choiceId==row.leaveChoiceId
end
function Events:CanChoose(choiceId)
    local row=self.byChoice[choiceId];if not row then return true end
    if choiceId==row.enterChoiceId or choiceId==row.battleChoiceId then
        if #self.adventure.events:LivingParty()==0 then return false,'请先到营地救治至少一名队员。' end
        if self:Value(row,'outcome')~=0 then return false,'这次遭遇已经结束。' end
    end
    return true
end
function Events:Settle(result)
    local adventure=self.adventure
    if adventure.data.AreaEncounterId==0 then return end
    local row=self.byArea[adventure.areas:ActiveLayout().configId];if not row then return end
    assert(self:Value(row,'outcome')==0,'Special event result already settled')
    local actor=assert(self:FindAlly(row,adventure.data.Areas.Active),'Special encounter ally is missing')
    local survived=result=='victory' and actor.HP>0
    if result~='victory' then
        if row.killAllyOnFailure then
            assert(not actor.MountedAnimal,'Event execution requires an unmounted combatant')
            actor:Damage(actor.HP)
        end
        self:Set(row,'failed',1)
    end
    self:Set(row,'outcome',survived and 1 or 2)
    local message=survived and row.successText or result=='victory' and row.deathText or row.failureText
    adventure.growth.chronicle:Record('event',nil,adventure.events.events:Get(row.eventId).name,message,
        adventure.areas:ActiveLayout().name,true,row.eventId,row.battleChoiceId)
    return message
end
function Events:PrepareRecruit(npcId)
    local row=assert(self.byNpc[npcId],'Event NPC has no special-event definition')
    if self:Value(row,'outcome')~=1 then return nil,'需要成功救下这位同行者，才能邀请他入队。' end
    local site=self:Value(row,'site');local state=self.adventure.data.Areas:Find(site)
    assert(state,'Rescued companion has no saved area')
    local actor,group=self:FindAlly(row,state)
    if not actor or actor.HP<=0 then return nil,'这位同行者已不在现场，无法招募。' end
    return {npcId=npcId,actorId=actor.Id,actor=actor,group=group,existing=true}
end
return Events

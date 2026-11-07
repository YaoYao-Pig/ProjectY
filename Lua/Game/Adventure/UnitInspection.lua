local L=require('Language')
local Life=require('Game.Battle.ActorLife')
local Inspection={};Inspection.__index=Inspection
local action={id=0,action='secondary',cost=1,contexts={'preparation','battle'},cooldownTurns=0,
    skillGroup='support',catalystKind='none',ammoPerShot=0,effectIds={}}
local priority={'scouting','speed','defense'}
local resources={'health','actionPoints','guard','casting'}
local resourceFields={health=true,actionPoints=true,guard=true,casting=true}
function Inspection.New(adventure)
    local self=setmetatable({adventure=adventure,stats=adventure.battle.stats,
        targets=require('Game.Adventure.UnitInspectionTargets').New(adventure),attributes={}},Inspection)
    local byCode={}
    for _,row in ipairs(adventure.config:GetTable('GrowthAttributeTable'):All())do byCode[row.code]=row end
    for _,code in ipairs(priority)do self.attributes[#self.attributes+1]=assert(byCode[code],'Inspection attribute is not registered');byCode[code]=nil end
    local remaining={};for _,row in pairs(byCode)do remaining[#remaining+1]=row end
    table.sort(remaining,function(a,b)return a.id<b.id end)
    for _,row in ipairs(remaining)do self.attributes[#self.attributes+1]=row end
    return self
end
function Inspection:Data()return CS.ProjectY.Data.UnitInspections.Get(self.adventure.data)end
function Inspection:Encounter(actor)
    local key,owned=self.targets:Identity(actor)
    if owned then return end
    local data=self:Data();local record=data:Find(key)
    if record then
        local complete=true
        for _,field in ipairs(resources)do if not record:HasField(field)then complete=false;break end end
        if complete then return end
    end
    data:Reveal(key,resources)
end
function Inspection:Targets()
    local rows=self.targets:Rows()
    for _,row in ipairs(rows)do self:Encounter(row.actor)end
    return rows
end
function Inspection:EncounterVisible()
    for _,row in ipairs(self.targets:Rows(false))do self:Encounter(row.actor)end
end
function Inspection:CaptureUse(actor,skillId)
    local key,owned=self.targets:Identity(actor)
    if owned or not self.targets:Find(key)then return end
    return {key=key,field='skill:'..skillId}
end
function Inspection:CommitUse(observation)
    if observation then
        self:Data():Reveal(observation.key,{'health','actionPoints','guard','casting',observation.field})
    end
end
function Inspection:Observers()
    local adventure=self.adventure;local rows={}
    local battle=adventure.battle
    local active=adventure.data.Phase=='battle' and battle.data.ActiveId or nil
    for i=0,adventure.data.PartyCount-1 do
        local actor=adventure.data:GetPartyAt(i)
        if Life.Alive(actor) and (not active or actor.Id==active and actor.Team==1)then
            rows[#rows+1]={id=actor.Id,name=self.targets:Name(actor)}
        end
    end
    return rows
end
function Inspection:Observer(id)
    for i=0,self.adventure.data.PartyCount-1 do
        local actor=self.adventure.data:GetPartyAt(i)
        if actor.Id==id and Life.Alive(actor) then return actor end
    end
end
function Inspection:Known(actor,field)
    local key,owned=self.targets:Identity(actor)
    if owned then return true end
    if not key then return false end
    local record=self:Data():Find(key)
    return record~=nil and record:HasField(field)
end
function Inspection:CanObserve(target,observerId)
    if not target then return false,L.InspectionTargetUnavailable end
    if target.owned then return false,L.InspectionOwned end
    local record=self:Data():Find(target.key)
    if record and record.Observed then return false,L.InspectionAlreadyObserved end
    local adventure=self.adventure;local phase=adventure.data.Phase
    if phase~='map' and phase~='area' and phase~='battle'then return false,L.InspectionUnavailable end
    local observer=self:Observer(observerId)
    if not observer then return false,L.InspectionObserverRequired end
    if phase=='battle'then
        local battle=adventure.battle
        if (battle.data.Phase~='deployment' and battle.data.Phase~='combat') or battle.data.Winner~=''
            or observer.Team~=1 or battle.data.ActiveId~=observer.Id then return false,L.InspectionPlayerTurn end
        local allowed,reason=battle:ActionBudget(action)
        if not allowed then return false,reason end
    end
    return true,nil,observer
end
function Inspection:Fields(actor)
    local attributes={{field='health',label='InspectionHealth'}}
    for _,row in ipairs(self.attributes)do attributes[#attributes+1]={field='attribute:'..row.code,attribute=row}end
    attributes[#attributes+1]={field='actionPoints',label='InspectionActionPoints'}
    attributes[#attributes+1]={field='guard',label='InspectionGuard'}
    attributes[#attributes+1]={field='casting',label='InspectionCasting'}
    local traits={}
    for i=0,actor.TraitCount-1 do
        local row=self.stats.traits:Get(actor:GetTraitAt(i))
        traits[#traits+1]={field='trait:'..row.id,trait=row}
    end
    table.sort(traits,function(a,b)return a.trait.id<b.trait.id end)
    local ordered={}
    for i=1,math.max(#attributes,#traits)do
        if attributes[i]then ordered[#ordered+1]=attributes[i]end
        if traits[i]then ordered[#ordered+1]=traits[i]end
    end
    return ordered
end
function Inspection:Value(actor,item)
    if item.attribute then return tostring(self.stats:Get(actor,item.attribute.code))end
    if item.field=='health'then return string.format(L.InspectionFraction,actor.HP,actor.MaxHP)end
    if item.field=='actionPoints'then return string.format(L.InspectionFraction,actor.AP,self.stats:Template(actor).actionPoints)end
    if item.field=='guard'then return tostring(actor.Guard)end
    assert(item.field=='casting','Unknown inspection field')
    local casting=CS.ProjectY.Data.SpellcastingState
    return string.format(L.InspectionFraction,casting.Current(actor),casting.Maximum(actor))
end
function Inspection:Build(key,observerId)
    local target=self.targets:Find(key)
    if not target then return nil,L.InspectionTargetUnavailable end
    self:Encounter(target.actor)
    local record=self:Data():Find(key)
    local observer=self:Observer(observerId)
    local result={name=target.name,key=key,owned=target.owned,attributes={},traits={},skills={},revealedCount=0,
        observerId=observer and observer.Id or 0,observerName=observer and self.stats:Template(observer).name or '',
        cost=self.adventure.data.Phase=='battle' and L.InspectionBattleCost or L.InspectionLifeCost}
    local fields=self:Fields(target.actor);result.totalCount=#fields
    for _,item in ipairs(fields)do
        local known=target.owned or record~=nil and record:HasField(item.field)
        if known then result.revealedCount=result.revealedCount+1 end
        if item.trait then
            result.traits[#result.traits+1]={field=item.field,known=known,
                title=known and item.trait.name or L.InspectionUnknown,body=known and item.trait.description or L.InspectionUnknown}
        else
            result.attributes[#result.attributes+1]={field=item.field,known=known,
                name=known and (item.attribute and item.attribute.name or L[item.label])or L.InspectionUnknown,
                value=known and self:Value(target.actor,item)or L.InspectionUnknown}
        end
    end
    local ids,seen={},{}
    for _,id in ipairs(self.adventure.battle:SkillIds(target.actor))do ids[#ids+1]=id;seen[id]=true end
    if record then
        for i=0,record.FieldCount-1 do
            local id=tonumber(record:GetFieldAt(i):match('^skill:(%d+)$'))
            if id and not seen[id]then ids[#ids+1]=id;seen[id]=true end
        end
    end
    table.sort(ids)
    for _,id in ipairs(ids)do
        local known=target.owned or record~=nil and record:HasField('skill:'..id)
        local skill=self.adventure.config:GetTable('CombatSkillTable'):Get(id)
        if skill.skillKind~='item'then
            result.skills[#result.skills+1]={known=known,title=known and skill.name or L.InspectionUnknown,
                body=known and skill.description or L.InspectionUnknown}
        end
    end
    result.canObserve,result.reason=self:CanObserve(target,observerId)
    result.reason=result.reason or ''
    result.result=target.owned and L.InspectionOwnedResult or record and record.Observed and
        string.format(L.InspectionResult,record.ObserverRoll,result.revealedCount,result.totalCount)or L.InspectionUnobserved
    return result
end
function Inspection:Observe(key,observerId)
    local target=self.targets:Find(key)
    local allowed,reason,observer=self:CanObserve(target,observerId)
    if not allowed then return false,reason end
    self:Encounter(target.actor)
    local fields={}
    for _,item in ipairs(self:Fields(target.actor))do
        if not resourceFields[item.field]then fields[#fields+1]=item end
    end
    local ownScouting=math.floor(self.stats:Get(observer,'scouting'))
    local targetScouting=math.floor(self.stats:Get(target.actor,'scouting'))
    local data=self:Data()
    local ownRoll,targetRoll=data:Roll(20),data:Roll(20)
    local margin=ownRoll+ownScouting-targetRoll-targetScouting
    local tier=margin<=0 and 0 or margin>=20 and 5 or math.floor(margin/5)+1
    local count=math.ceil(#fields*tier/5)
    local revealed={};for i=1,count do revealed[i]=fields[i].field end
    data:Record(key,observer.Id,ownRoll,targetRoll,margin,revealed)
    if self.adventure.data.Phase=='battle'then
        observer:SpendAction('secondary',action.cost)
        self.adventure.battle.Changed:Emit({kind='unit_observed',sourceId=observer.Id,targetId=target.actor.Id})
    else
        self.adventure.narrative:AdvanceMinutes(5)
    end
    return true,string.format(L.InspectionResult,ownRoll,count+#resources,#fields+#resources)
end
return Inspection

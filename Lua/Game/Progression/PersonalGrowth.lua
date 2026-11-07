local L=require('Language')
local Life=require('Game.Battle.ActorLife')
local Model={};Model.__index=Model
local function state()return CS.ProjectY.Data.PeopleState end
function Model.New(adventure)
    return setmetatable({adventure=adventure,rules=require('Game.Progression.PersonalGrowthRules').New(adventure.config),
        stats=adventure.battle.stats,chronicle=adventure.growth.chronicle},Model)
end
function Model:Record(actorId)
    return state().Get(self.adventure.data):FindActor(actorId)
end
function Model:Actor(actorId)return self.adventure.growth:Actor(actorId)end
function Model:RecordEvent(actor,kind,eventId)
    local record=self:Record(actor.Id)
    if not record or not record.Joined or record.Actor~=actor or record.Stage>=2 then return false end
    assert(type(eventId)=='string' and #eventId>0,'Personal growth events require a stable receipt')
    return state().RecordGrowthEvent(self.adventure.data,actor.Id,kind,eventId)
end
function Model:RecordBattleVictory(actor,eventId)return self:RecordEvent(actor,'battle',eventId)end
function Model:RecordRescue(actor,eventId)return self:RecordEvent(actor,'rescue',eventId)end
function Model:RecordLearnedSkill(actor,skillId)
    self.rules.skills:Get(skillId)
    assert(actor.Growth:HasSkill(skillId),'Learning must succeed before recording personal growth')
    return self:RecordEvent(actor,'learn',tostring(skillId))
end
function Model:Summary(actorId)
    local record=self:Record(actorId)
    if not record or not record.Joined then return nil end
    local history={}
    for completed=1,record.Stage do
        local choice=self.rules.choices:Get(completed==1 and record.Branch1 or record.Branch2)
        history[#history+1]=string.format(L.PeopleGrowthHistoryEntry,choice.title,choice.history)
    end
    local stage=self.rules:Current(record)
    if not stage then return {title=L.PeopleGrowthCompleted,body=table.concat(history,'\n\n'),progress='',completed=true}end
    history[#history+1]=stage.description
    return {title=stage.title,body=table.concat(history,'\n\n'),progress=self.rules:Progress(record,stage),completed=false,
        available=self.rules:Eligible(record,stage),stage=stage.stage}
end
function Model:Choices(actorId)
    local actor=self:Actor(actorId);local record=self:Record(actorId)
    if not actor or not record or not record.Joined then return {}end
    local stage=self.rules:Current(record);if not stage then return {}end
    local available=self.rules:Eligible(record,stage)
    local reason=available and '' or L.PeopleGrowthNotReady
    if not Life.Alive(actor)then available=false;reason=L.PeopleGrowthActorUnavailable end
    local progress=self.rules:Progress(record,stage);local rows={}
    for _,choice in ipairs(self.rules.byStage[stage.id])do
        local reward=self.rules:Reward(actor,record,choice,self.stats)
        rows[#rows+1]={id=choice.id,choiceId=choice.id,stageId=stage.id,profileId=record.ProfileId,stage=stage.stage,
            title=choice.title,body=string.format(L.PeopleGrowthChoiceBody,choice.description,progress,reward),
            available=available,reason=reason,progress=progress,reward=reward}
    end
    return rows
end
function Model:Choose(actorId,choiceId)
    local data=self.adventure.data
    if data.Phase~='map' and data.Phase~='area' then return false,L.PeopleGrowthExploreOnly end
    local actor=self:Actor(actorId);local record=self:Record(actorId)
    if not actor or not record or not record.Joined or record.Actor~=actor or not Life.Alive(actor)then return false,L.PeopleGrowthActorUnavailable end
    local stage=self.rules:Current(record)
    if not stage then return false,L.PeopleGrowthCompleted end
    if type(choiceId)~='number' or not math.tointeger(choiceId)then return false,L.PeopleGrowthInvalidChoice end
    local choice=self.rules.choices:Find(choiceId)
    if not choice or choice.stageId~=stage.id then return false,L.PeopleGrowthInvalidChoice end
    if not self.rules:Eligible(record,stage)then return false,L.PeopleGrowthNotReady end
    assert(actor.Growth.Initialized,'Personal growth actor has no initialized growth')
    local previous
    if choice.replacePreviousTrait then
        previous=self.rules.choices:Get(record.Branch1)
        assert(previous.stageId==self.rules.byProfile[record.ProfileId][1].id,'Invalid previous personal growth choice')
        assert(actor:HasTrait(previous.traitId),'Previous personal growth trait is missing')
    end
    assert(not actor:HasTrait(choice.traitId),'Unclaimed personal growth trait is already granted')
    local skillId=choice.skillIds[1]
    local known=skillId and self.rules:KnowsSkill(actor,skillId,self.stats)
    local reward=self.rules:Reward(actor,record,choice,self.stats)
    if not state().ChooseGrowth(data,actorId,record.Stage,choiceId)then return false,L.PeopleGrowthInvalidChoice end
    if previous then actor:RemoveTrait(previous.traitId)end
    actor:AddTrait(choice.traitId)
    if skillId and not known then actor.Growth:GrantSkill(skillId)end
    actor:SetMaxHP(self.stats:MaximumHP(actor))
    local site=self.adventure.sites[data.SiteId]
    self.chronicle:Record('growth',actor,stage.title,string.format(L.PeopleGrowthMemory,choice.history,reward),
        site and site.name or L.PeopleGrowthJourney,false,stage.id,choice.id)
    return true,string.format(L.PeopleGrowthMemory,choice.history,reward)
end
function Model:ValidateSaved(prepared)
    local people=state().Prepared(prepared)
    for i=0,people.Count-1 do
        local record=people:GetAt(i)
        if record.Joined then self.rules:ValidateRecord(record,self.stats)end
    end
end
return Model

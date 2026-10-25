local L=require('Language')
local Hex=require('Game.Map.HexGrid')
local Dice=require('Game.Presentation.DiceChecks')
local Speech={};Speech.__index=Speech
local function state() return CS.ProjectY.Data.AnimalSpeechState end
local function bound(actor) return CS.ProjectY.Data.AnimalCompanionState.Bound(actor) end
local castBase,tameBase,companionBase,approachBase=100000000,200000000,300000000,1000
function Speech.New(story)
    local adventure=story.adventure
    local self=setmetatable({story=story,adventure=adventure,rules=require('Game.Animals.AnimalSpeechRules').New(adventure.config)},Speech)
    self.rule=self.rules.rule;self.skill=adventure.config:GetTable('CombatSkillTable'):Get(self.rule.skillId)
    self.animals=adventure.battle.stats.animals
    adventure.characterSkills:Register('animal_speech',{
        CanUse=function(actor,id)return self:CanOpen(actor,id)end,
        Use=function(actor,id)
            if adventure.data.Phase=='map' then return self:OpenCompanions(actor)end
            return self:Open(actor,assert(self:FindTarget(id)),'area',true)
        end,
        Targets=function(actor)return self:Targets(actor)end,
        MapTargets=function(actor)return #self:Companions()>0 and {actor.Id} or {}end})
    return self
end
function Speech:Active() return state().Target(self.story.data)~=nil end
function Speech:Companions()
    local result={}
    for i=0,self.adventure.data.PartyCount-1 do local owner=self.adventure.data:GetPartyAt(i)
        if bound(owner) and bound(owner).HP>0 then result[#result+1]=owner end
    end
    return result
end
function Speech:OpenCompanions(actor)
    local owners=self:Companions()
    if #owners==0 then return false,L.AnimalSpeechNoCompanion end
    return self:Open(actor,bound(owners[1]),'companion',#owners==1)
end
function Speech:Knows(actor,id)
    for _,skill in ipairs(self.adventure.battle:SkillIds(actor))do if skill==id then return true end end
    return false
end
function Speech:CanCast(actor)
    if not actor or actor.HP<=0 or actor.Team~=1 then return false,L.AnimalSpeechLivingCaster end
    if not self:Knows(actor,self.rule.skillId)then return false,L.AnimalSpeechNotLearned end
    return self.adventure.battle.stats.equipment:CheckSkillEquipment(actor,self.skill,self.adventure.battle.stats)
end
function Speech:FindTarget(id)
    for i=0,self.adventure.data.PartyCount-1 do
        local owner=self.adventure.data:GetPartyAt(i);local animal=bound(owner)
        if animal and (id==owner.Id or id==animal.Id)then return animal end
    end
    if self.adventure.data.Phase=='battle' then return self.adventure.battle:FindUnit(id) end
    if self.adventure.data.Phase=='area' then return self.adventure.areas:FindAnimal(id) end
end
function Speech:ValidTarget(target)
    if not target or target.HP<=0 or not self.animals.byUnit[target.TemplateId] then return false,L.AnimalSpeechTarget end
    return true
end
function Speech:Targets(actor)
    local result={};local area,stateData=self.adventure.areas:ActiveLayout(),self.adventure.data.Areas.Active
    local visible={};for i=0,stateData.VisibleCount-1 do visible[stateData:GetVisibleAt(i)]=true end
    for i=0,stateData.EncounterCount-1 do local group=stateData:GetEncounterAt(i)
        for j=0,group.EnemyCount-1 do local animal=group:GetEnemyAt(j)
            if animal.AnimalOwnerId==0 and self:ValidTarget(animal) and visible[area:Find(animal.Q,animal.R).index]then result[#result+1]=animal.Id end
        end
    end
    for i=0,self.adventure.data.PartyCount-1 do local owner=self.adventure.data:GetPartyAt(i)
        if bound(owner) and bound(owner).HP>0 then result[#result+1]=owner.Id end
    end
    return result
end
function Speech:CanOpen(actor,id)
    if self.story.data.DialogueOpen then return false,L.AnimalSpeechBusy end
    local ok,reason=self:CanCast(actor);if not ok then return false,reason end
    if self.adventure.data.Phase=='map' then
        return id==actor.Id and #self:Companions()>0,L.AnimalSpeechNoCompanion
    end
    local target=self:FindTarget(id);ok,reason=self:ValidTarget(target);if not ok then return false,reason end
    if target.AnimalOwnerId>0 then return true end
    if self.adventure.data.Phase~='area' then return false,L.AnimalSpeechTarget end
    local area,data=self.adventure.areas:ActiveLayout(),self.adventure.data.Areas.Active
    local origin
    for i=0,data.MemberCount-1 do if data:GetMemberIdAt(i)==actor.Id then origin=area.cells[data:GetMemberCellAt(i)];break end end
    if not origin then return false,L.AnimalSpeechNotDeployed end
    local targetCell=area:Find(target.Q,target.R)
    if origin.layer~=targetCell.layer or not area:CanSee(origin,targetCell) then return false,L.AnimalSpeechUnreachable end
    local distance=math.huge
    for _,cell in ipairs(assert(self.animals:Cells(target,area)))do distance=math.min(distance,Hex.Distance(origin.q,origin.r,cell.q,cell.r))end
    if distance>self.skill.range then return false,L.AnimalSpeechUnreachable end
    return true
end
function Speech:Open(actor,target,context,understood,partyId)
    local story=self.story
    if story.data.DialogueOpen then return false,L.AnimalSpeechBusy end
    local ok,reason=self:ValidTarget(target);if not ok then return false,reason end
    if target.AnimalOwnerId>0 then context='companion' end
    local legend=self.adventure.parties.legends.byUnit[target.TemplateId]
    local npcId=legend and legend.npcId or self.rule.npcId
    local definition=assert(story.dialogue:Definition(npcId),'Animal dialogue definition is missing')
    if self.adventure.data.Phase=='area' then self.adventure.areas:Stop() end
    self.adventure.travel.data:SetPaused(true)
    story.data:BeginDialogue(definition.id,npcId,partyId or target.Id,actor.Id)
    state().Bind(story.data,target,partyId or 0,context,understood)
    story.dialogue:Enter(definition.entryNodeId)
    return true
end
function Speech:OpenWorld(party)
    local ok,reason=self.adventure.parties.legends:CanTalk(party);if not ok then return false,reason end
    assert(party.MemberCount==1,'Legendary animal must have one authoritative actor')
    return self:Open(assert(self.adventure.events:LivingParty()[1]),party:GetMemberAt(0),'world',false,party.Id)
end
function Speech:CanContinue()
    local data=self.story.data;local target=state().Target(data)
    local ok,reason=self:ValidTarget(target);if not ok then return false,reason end
    local context=state().Context(data);local phase=self.adventure.data.Phase
    if context=='world' then return self.adventure.parties.legends:CanTalk(assert(self.adventure.parties.data:Find(state().PartyId(data)))) end
    if context=='companion' then
        for i=0,self.adventure.data.PartyCount-1 do if bound(self.adventure.data:GetPartyAt(i))==target then return phase=='area' or phase=='map',L.AnimalSpeechTarget end end
    elseif context=='battle' then
        local battle=self.adventure.battle
        if phase=='battle' and battle.data.Winner=='' and battle:FindUnit(target.Id)==target and battle.data.ActiveId==data.DialogueActorId then return true end
    elseif context=='area' and phase=='area' and self.adventure.areas:FindAnimal(target.Id)==target then return true end
    return false,L.AnimalSpeechTarget
end
function Speech:HasStory()
    return state().Understood(self.story.data) and state().Context(self.story.data)~='battle'
end
function Speech:Opening()
    local target=state().Target(self.story.data)
    if state().Context(self.story.data)=='companion' and not state().Understood(self.story.data)then return L.AnimalSpeechSelectCompanion end
    return string.format(state().Understood(self.story.data) and L.AnimalSpeechBattleOpening or L.AnimalSpeechUntranslated,self.adventure.battle.stats:Template(target).name)
end
function Speech:IsHostile()
    local data=self.story.data;local partyId=state().PartyId(data)
    if state().Context(data)=='world' then
        return self.adventure.factions:Relation(0,assert(self.adventure.parties.data:Find(partyId)).FactionId)=='hostile'
    end
    local target=state().Target(data)
    if state().Context(data)=='battle' then return self.adventure.battle:IsHostile(assert(self.adventure.characterSkills:Actor(data.DialogueActorId)),target) end
    return target.AnimalOwnerId==0 and target.Team==2
end
function Speech:CanDiscuss()
    local target=state().Target(self.story.data)
    if target.AnimalOwnerId~=0 then return false,L.AnimalSpeechAlreadyCompanion end
    if state().Pending(target)then
        local modifier=state().Modifier(target)
        return false,modifier>0 and L.AnimalSpeechPendingAdvantage or string.format(L.AnimalSpeechPending,modifier)
    end
    if target.TameRetryTurns>0 then return false,string.format(L.AnimalSpeechRetry,target.TameRetryTurns)end
    local actor=self.adventure.characterSkills:Actor(self.story.data.DialogueActorId)
    if not actor or actor.HP<=0 then return false,L.AnimalSpeechLivingCaster end
    return true
end
function Speech:CanTame(actor)
    local target=state().Target(self.story.data)
    local ok,reason=self.animals:CanTame(actor,target);if not ok then return false,reason end
    if not self:Knows(actor,self.animals.rule.tameSkillId)then return false,L.AnimalSpeechTameNotLearned end
    if state().Context(self.story.data)=='world' then
        if self:IsHostile()then return false,L.AnimalSpeechHostileTaming end
        return true
    end
    if state().Context(self.story.data)=='area' then return self.adventure.areas:CanTame(actor.Id,target.Id) end
    return false,L.AnimalSpeechHostileTaming
end
function Speech:Choices()
    local rows={};local data=self.story.data;local target=state().Target(data)
    local function add(id,text,available,reason)rows[#rows+1]={id=id,text=text,available=available~=false,reason=reason or ''}end
    if state().Context(data)=='companion' and not state().Understood(data)then
        for _,owner in ipairs(self:Companions())do
            add(-companionBase-owner.Id,string.format(L.AnimalSpeechTalkCompanion,self.adventure.battle.stats:Template(bound(owner)).name))
        end
        add(-4,L.AnimalSpeechLeave);return rows
    end
    if not state().Understood(data)then
        for i=0,self.adventure.data.PartyCount-1 do local actor=self.adventure.data:GetPartyAt(i)
            local ok,reason=self:CanCast(actor)
            add(-castBase-actor.Id,string.format(L.AnimalSpeechCastBy,self.adventure.battle.stats:Template(actor).name),ok,reason)
        end
        add(-1,L.AnimalSpeechObserve);add(-2,L.AnimalSpeechGesture)
    elseif target.AnimalOwnerId==0 then
        local ok,reason=self:CanDiscuss()
        for _,row in ipairs(self.rules.approaches:All())do
            add(-approachBase-row.id,row.name,ok,ok and row.description or reason)
        end
        if state().Context(data)~='battle' and not self:IsHostile()then
            for i=0,self.adventure.data.PartyCount-1 do local actor=self.adventure.data:GetPartyAt(i)
                local can,why=self:CanTame(actor)
                local chance,values=self.animals:TameChance(actor,target,self.adventure.battle.stats,false)
                local text=#values.advantageSources>0 and L.AnimalSpeechTameAdvantageBy or L.AnimalSpeechTameBy
                add(-tameBase-actor.Id,string.format(text,self.adventure.battle.stats:Template(actor).name,chance),can,why)
            end
        end
    end
    if state().Context(data)=='world' and not state().Understood(data)then add(-3,L.AnimalSpeechAttack)end
    add(-4,L.AnimalSpeechLeave)
    return rows
end
function Speech:Choose(id,version)
    local story,data=self.story,self.story.data
    if version~=data.DialogueVersion then return false,L.AnimalSpeechStale end
    local continuing,why=self:CanContinue();if not continuing then return false,why end
    local selected
    for _,row in ipairs(self:Choices())do if row.id==id then selected=row;break end end
    if not selected or not selected.available then return false,selected and selected.reason or L.AnimalSpeechStale end
    if id==-4 then return story.dialogue:Close()end
    if id==-3 then return story.dialogue:Close('attack')end
    local target=state().Target(data)
    story.data:AddDialogueLine(story.rules.settings.playerSpeaker,selected.text,true)
    if id<=-companionBase then
        local actor=assert(self.adventure.characterSkills:Actor(data.DialogueActorId))
        local ok,reason=self:CanCast(actor);if not ok then return false,reason end
        local owner=assert(self.adventure.characterSkills:Actor(-id-companionBase))
        local companion=assert(bound(owner))
        data:CloseDialogue();return self:Open(actor,companion,'companion',true)
    end
    if id<=-tameBase then return self:Tame(assert(self.adventure.characterSkills:Actor(-id-tameBase)))end
    if id<=-castBase then
        local actor=assert(self.adventure.characterSkills:Actor(-id-castBase))
        state().Understand(data,actor.Id);story.dialogue:Enter(data.DialogueNodeId);return true
    end
    if id<-approachBase then
        local approach=self.rules.approaches:Get(-id-approachBase)
        local actor=assert(self.adventure.characterSkills:Actor(data.DialogueActorId))
        local chance=self.rules:Chance(actor,self.adventure.battle.stats,approach,self:IsHostile(),self.adventure.parties.legends.byUnit[target.TemplateId]~=nil)
        local roll=target:RollAnimalPercent();local success=roll<math.floor(chance*100)
        local modifier=success and approach.successModifier or approach.failureModifier
        state().Resolve(target,modifier)
        story.data:AddDialogueLine(self.adventure.battle.stats:Template(target).name,success and approach.successText or approach.failureText,false)
        story.data:AddDialogueLine(L.AnimalSpeechNarrator,modifier>0 and L.AnimalSpeechResultAdvantage or string.format(L.AnimalSpeechResult,modifier),false)
        state().Touch(data)
        self.adventure.events.CheckResolved:Emit(Dice.Percent(string.format(L.AnimalSpeechCheckTitle,self.adventure.battle.stats:Template(target).name),roll/100,chance,success,'exclusive',100))
        return true
    end
    story.data:AddDialogueLine(L.AnimalSpeechNarrator,id==-1 and L.AnimalSpeechObservation or L.AnimalSpeechGestureResult,false)
    state().Touch(data);return true
end
function Speech:Tame(actor)
    local data=self.story.data;local target=state().Target(data)
    if state().Context(data)=='area' then
        local success,reason=self.adventure.areas:Tame(actor.Id,target.Id)
        if success then self.story.dialogue:Close()else state().Touch(data)end
        return success,reason
    end
    local success,chance,roll,_,result=self.animals:Tame(actor,target,self.adventure.battle.stats,false)
    local title=string.format(L.DiceTamingTitle,self.adventure.battle.stats:Template(target).name)
    self.adventure.events.CheckResolved:Emit(result and Dice.Resolved(title,result) or Dice.Percent(title,roll,math.floor(chance*100)/100,success,'exclusive',100))
    if success then
        self:OnTamed(target)
        data:CloseDialogue()
        self.adventure.parties.data:Close()
        self.adventure.travel.data:SetPaused(true)
        return true
    end
    data:AddDialogueLine(L.AnimalSpeechNarrator,string.format(L.AnimalSpeechTameFailed,chance,target.TameRetryTurns),false)
    state().Touch(data);return true
end
function Speech:OnTamed(target)
    local legend=self.adventure.parties.legends.byUnit[target.TemplateId]
    if not legend then return end
    local parties=self.adventure.parties.data
    for i=0,parties.Count-1 do local party=parties:GetAt(i)
        if party.DefinitionId==legend.id then
            assert(party.MemberCount==1 and party:GetMemberAt(0)==target,'Tamed legend is not its world identity')
            state().RetireParty(parties,party)
            if legend.defeatedFlag~='' then self.story.data:SetValue('flag:'..legend.defeatedFlag,1)end
            self.story:Refresh();return
        end
    end
    error('Tamed legendary animal has no world party')
end
return Speech

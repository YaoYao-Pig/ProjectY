local L=require('Language')
local PeopleDialogue={};PeopleDialogue.__index=PeopleDialogue
local leaveId=-900000
local function session()return CS.ProjectY.Data.PeopleDialogueSession end
function PeopleDialogue.New(adventure)return setmetatable({adventure=adventure},PeopleDialogue)end
function PeopleDialogue:Active()
    local data=self.adventure.data.Narrative
    return data.DialogueOpen and session().Key(data)~=''
end
function PeopleDialogue:Person()
    assert(self:Active(),'No active person dialogue')
    return assert(self.adventure.people:Find(session().Key(self.adventure.data.Narrative)),'Dialogue person is missing')
end
function PeopleDialogue:CanContinue()
    if not self:Active()then return false,L.PeopleDialogueUnavailable end
    return self.adventure.people:CanTalk(self:Person())
end
function PeopleDialogue:Begin(person,localNpcId)
    local adventure=self.adventure;local data=adventure.data.Narrative
    if data.DialogueOpen then return false,L.PeopleDialogueBusy end
    local ok,reason=adventure.people:CanTalk(person)
    if not ok then return false,reason end
    local actor=adventure.events:LivingParty()[1]
    if not actor then return false,L.PeopleDialogueLivingActor end
    person:Meet()
    local description=adventure.people:Describe(person)
    if adventure.data.Phase=='map' then
        adventure.travel.data:SetPaused(true)
        if not person.Joined and person.OriginKind=='world' then
            localNpcId=adventure.parties.data.ContactId
            assert(localNpcId>0,'World person dialogue requires a validated contact')
        end
    elseif adventure.data.Phase=='area' then adventure.areas:Stop()end
    session().Begin(data,person.Key,actor.Id,localNpcId or 0)
    data:AddDialogueLine(description.name,description.opening,false)
    return true
end
function PeopleDialogue:OpenResident(definition,localId)
    local adventure=self.adventure
    if adventure.data.Narrative.DialogueOpen then return false,L.PeopleDialogueBusy end
    if adventure.data.Phase~='area'then return false,L.PeopleDialogueUnavailable end
    local state=adventure.data.Areas.Active
    assert(state.InteractionKind==2 and state.InteractionId==localId,'Person dialogue requires a validated nearby resident interaction')
    local person=adventure.people:EnsureResident(definition,state.SiteId)
    return self:Begin(person,localId)
end
function PeopleDialogue:OpenTarget(key)
    local adventure=self.adventure
    if adventure.data.Narrative.DialogueOpen then return false,L.PeopleDialogueBusy end
    local ok,reason=adventure.people:CanOpen(key)
    if not ok then return false,reason end
    local target=assert(adventure.inspection.targets:Find(key),'Validated person target is missing')
    local person=adventure.people:EnsureTarget(target)
    local localId=0
    if person.OriginKind=='resident' and not person.Joined then
        local definition=assert(adventure.people:ResidentDefinition(person),'Resident dialogue requires the active resident definition')
        ok,reason=adventure.areas:Interact(2,definition.id)
        if not ok then return false,reason end
        localId=definition.id
    end
    return self:Begin(person,localId)
end
function PeopleDialogue:Title()return self.adventure.people:Describe(self:Person()).name end
function PeopleDialogue:Caption()return self.adventure.people:Describe(self:Person()).caption end
function PeopleDialogue:Choices()
    local ok,reason=self:CanContinue();local rows={}
    if ok then
        for _,row in ipairs(self.adventure.people:Options(self:Person()))do
            assert(row.id~=leaveId,'Person option uses the reserved close id')
            rows[#rows+1]=row
        end
    end
    rows[#rows+1]={id=leaveId,text=L.PeopleDialogueLeave,available=true,reason=ok and '' or reason}
    return rows
end
function PeopleDialogue:Choose(id,version)
    local adventure=self.adventure;local data=adventure.data.Narrative
    if not self:Active() or version~=data.DialogueVersion then return false,L.PeopleDialogueStale end
    local selected
    for _,row in ipairs(self:Choices())do if row.id==id then selected=row;break end end
    if not selected then return false,L.PeopleDialogueStale end
    if not selected.available then return false,selected.reason end
    if id==leaveId then return self:Close()end
    local person=self:Person()
    local ok,response,action=adventure.people:Act(person,id)
    if not ok then return false,response end
    if action=='commissions'then return self:Close(true)end
    assert(action==nil,'Unknown person dialogue action')
    assert(type(response)=='string' and response~='','Person action requires a localized response')
    data:AddDialogueLine(adventure.narrative.rules.settings.playerSpeaker,selected.text,true)
    data:AddDialogueLine(adventure.people:Describe(person).name,response,false)
    session().Touch(data)
    return true
end
function PeopleDialogue:Close(keepInteraction)
    local adventure=self.adventure
    if not self:Active()then return true end
    local localId=adventure.data.Narrative.DialogueLocalNpcId
    adventure.data.Narrative:CloseDialogue()
    if adventure.data.Phase=='area'then
        if localId>0 and not keepInteraction then adventure.areas:CloseInteraction()end
        adventure.narrative.npcs:SyncPresence()
    end
    return true
end
return PeopleDialogue

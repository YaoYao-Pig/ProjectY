local Actions = require('Game.Narrative.NarrativeActions')
local Dialogue = {}; Dialogue.__index = Dialogue
function Dialogue.New(story) return setmetatable({story=story},Dialogue) end
function Dialogue:Definition(npcId)
    local story=self.story
    for _,id in ipairs(story.rules.npcs:Get(npcId).dialogueIds) do
        local row=story.rules.dialogues:Get(id)
        if story.conditions:Check(row.conditionId,{}) then return row end
    end
end
function Dialogue:OpenWorld(party)
    local story=self.story;local parties=story.adventure.parties
    if story.data.DialogueOpen then return false,'请先结束当前对话' end
    local legend=assert(parties.legends:Find(party.DefinitionId),'World dialogue requires a configured identity')
    local ok,reason=parties.legends:CanTalk(party);if not ok then return false,reason end
    assert(parties.data.IsOpen and parties.data.ContactId==party.Id,'World dialogue must follow a validated contact')
    local definition=self:Definition(legend.npcId)
    if not definition then return false,'此时没有可进行的对话' end
    local actor=assert(story.adventure.events:LivingParty()[1])
    story.adventure.travel.data:SetPaused(true)
    story.data:BeginDialogue(definition.id,legend.npcId,party.Id,actor.Id);self:Enter(definition.entryNodeId)
    return true
end
function Dialogue:Enter(id)
    local story = self.story; local row = story.rules.nodes:Get(id)
    assert(row.dialogueId == story.data.DialogueId,'Node outside current dialogue')
    story.data:EnterDialogueNode(id)
    local speaker = row.speaker == 'npc' and story.rules.npcs:Get(story.data.DialogueNpcId).name
        or row.speaker == 'player' and story.rules.settings.playerSpeaker or '旁白'
    story.data:AddDialogueLine(speaker,row.text,false)
    self:AutoInterjections(id)
end
function Dialogue:Participants(row)
    local story, result = self.story, {}
    for i=0,story.adventure.data.PartyCount-1 do
        local actor = story.adventure.data:GetPartyAt(i)
        if actor.HP > 0 and story.conditions:Check(row.conditionId,{actor=actor}) then result[#result+1] = actor end
    end
    return result
end
function Dialogue:Speak(row, actor)
    local story = self.story
    local name = story.npcs:ActorName(actor) or story.adventure.battle.stats:Template(actor).name
    story.data:AddCompanionLine(row.id,actor.Id,name,row.cue,row.text)
end
function Dialogue:AutoInterjections(nodeId)
    local story = self.story
    for _, row in ipairs(story.rules.interjectionsByNode[nodeId] or {}) do
        if row.mode == 'auto' and not story.data:HasDialogueInterjection(row.id) then
            local actors = self:Participants(row)
            for _, actor in ipairs(actors) do self:Speak(row,actor) end
            if #actors > 0 then story.data:CompleteDialogueInterjection(row.id) end
        end
    end
end
function Dialogue:Interjections()
    local story, result = self.story, {}
    assert(story.data.DialogueOpen,'No dialogue to display')
    for _, row in ipairs(story.rules.interjectionsByNode[story.data.DialogueNodeId] or {}) do
        if row.mode == 'optional' and not story.data:HasDialogueInterjection(row.id) then
            for _, actor in ipairs(self:Participants(row)) do
                result[#result+1] = {id=row.id,actorId=actor.Id,name=story.npcs:ActorName(actor) or story.adventure.battle.stats:Template(actor).name,cue=row.cue}
            end
        end
    end
    return result
end
function Dialogue:Interject(id,actorId,version)
    local story = self.story
    if not story.data.DialogueOpen or version ~= story.data.DialogueVersion then return false,'对话已推进，请选择当前选项' end
    local row = story.rules.interjections:Find(id)
    if not row or row.nodeId ~= story.data.DialogueNodeId or row.mode ~= 'optional' or story.data:HasDialogueInterjection(id) then
        return false,'这段发言当前不可用'
    end
    local ok,reason = self:CanContinue(); if not ok then return false,reason end
    for _, actor in ipairs(self:Participants(row)) do
        if actor.Id == actorId then
            self:Speak(row,actor); story.data:CompleteDialogueInterjection(id)
            if row.nextNodeId ~= 0 then self:Enter(row.nextNodeId) end
            return true
        end
    end
    return false,'这位队员当前不满足发言条件'
end
function Dialogue:CanContinue()
    local story = self.story
    if story.rules.npcs:Get(story.data.DialogueNpcId).locationKind == 'world_party' then
        local party = assert(story.adventure.parties.data:Find(story.data.DialogueLocalNpcId))
        return story.adventure.parties.legends:CanTalk(party)
    end
    return true
end
function Dialogue:Open(npcId,localId)
    local story = self.story; local data = story.adventure.data
    if data.Phase ~= 'area' or story.data.DialogueOpen then return false,'当前不能开启对话' end
    assert(story.rules.npcs:Get(npcId).locationKind=='town','Town dialogue requires a town NPC')
    local definition=self:Definition(npcId)
    if not definition then return false,'此时没有可进行的对话' end
    local state = data.Areas.Active
    assert(state.InteractionKind == 2 and state.InteractionId == localId,'Dialogue must follow a validated nearby NPC interaction')
    local actorId = state:GetMemberIdAt(0)
    state:Stop(); story.data:BeginDialogue(definition.id,npcId,localId,actorId); self:Enter(definition.entryNodeId)
    return true
end
function Dialogue:Choices()
    local story = self.story
    assert(story.data.DialogueOpen,'No dialogue to display')
    local rows = {}
    for _, id in ipairs(story.rules.nodes:Get(story.data.DialogueNodeId).choiceIds) do
        local row = story.rules.choices:Get(id)
        local ok,reason = story.conditions:Check(row.conditionId,{})
        local visible = ok or not row.hideWhenLocked
        if ok then local plan; plan,reason = Actions.Prepare(story,row.actionIds); ok = plan ~= nil end
        if visible then rows[#rows+1] = {id=id,text=row.text,available=ok,reason=reason or ''} end
    end
    return rows
end
function Dialogue:Choose(id,version)
    local story = self.story
    if not story.data.DialogueOpen or version ~= story.data.DialogueVersion then return false,'对话已推进，请选择当前选项' end
    local belongs = false
    for _, choiceId in ipairs(story.rules.nodes:Get(story.data.DialogueNodeId).choiceIds) do if choiceId == id then belongs = true; break end end
    if not belongs then return false,'选项不属于当前对话节点' end
    local continuing,why = self:CanContinue(); if not continuing then return false,why end
    local row = story.rules.choices:Get(id)
    local ok,reason = story.conditions:Check(row.conditionId,{})
    if not ok then return false,reason end
    local plan; plan,reason = Actions.Prepare(story,row.actionIds); if not plan then return false,reason end
    Actions.Apply(story,plan)
    story.data:AddDialogueLine(story.rules.settings.playerSpeaker,row.text,true)
    story:Refresh()
    if row.nextNodeId == 0 then return self:Close(row.worldAction) else self:Enter(row.nextNodeId) end
    return true
end
function Dialogue:Close(action)
    local story = self.story
    if not story.data.DialogueOpen then return true end
    local world=story.rules.npcs:Get(story.data.DialogueNpcId).locationKind=='world_party'
    local partyId=story.data.DialogueLocalNpcId
    story.data:CloseDialogue()
    if world then return story.adventure.parties.legends:Finish(partyId,action or 'none') end
    if story.adventure.data.Phase == 'area' then story.adventure.areas:CloseInteraction(); story.npcs:SyncPresence() end
    return true
end
return Dialogue

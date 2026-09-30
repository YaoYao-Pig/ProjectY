local Actions = require('Game.Narrative.NarrativeActions')
local Dialogue = {}; Dialogue.__index = Dialogue
function Dialogue.New(story) return setmetatable({story=story},Dialogue) end
function Dialogue:Enter(id)
    local story = self.story; local row = story.rules.nodes:Get(id)
    assert(row.dialogueId == story.data.DialogueId,'Node outside current dialogue')
    story.data:EnterDialogueNode(id)
    local speaker = row.speaker == 'npc' and story.rules.npcs:Get(story.data.DialogueNpcId).name
        or row.speaker == 'player' and story.rules.settings.playerSpeaker or '旁白'
    story.data:AddDialogueLine(speaker,row.text,false)
end
function Dialogue:Open(npcId,localId)
    local story = self.story; local data = story.adventure.data
    if data.Phase ~= 'area' or story.data.DialogueOpen then return false,'当前不能开启对话' end
    local npc = story.rules.npcs:Get(npcId)
    local definition
    for _, id in ipairs(npc.dialogueIds) do local row=story.rules.dialogues:Get(id); if story.conditions:Check(row.conditionId,{}) then definition=row;break end end
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
    local row = story.rules.choices:Get(id)
    local ok,reason = story.conditions:Check(row.conditionId,{})
    if not ok then return false,reason end
    local plan; plan,reason = Actions.Prepare(story,row.actionIds); if not plan then return false,reason end
    Actions.Apply(story,plan)
    story.data:AddDialogueLine(story.rules.settings.playerSpeaker,row.text,true)
    story:Refresh()
    if row.nextNodeId == 0 then self:Close() else self:Enter(row.nextNodeId) end
    return true
end
function Dialogue:Close()
    local story = self.story
    story.data:CloseDialogue()
    if story.adventure.data.Phase == 'area' then story.adventure.areas:CloseInteraction(); story.npcs:SyncPresence() end
    return true
end
return Dialogue

-- Traverse only the currently available dialogue branches. Dialogue content remains the source of task ownership.
local Actions=require('Game.Narrative.NarrativeActions')
local Markers={}
function Markers.Story(story,npcId)
    local npc=story.rules.npcs:Get(npcId);local dialogue
    for _,id in ipairs(npc.dialogueIds) do local row=story.rules.dialogues:Get(id)
        if story.conditions:Check(row.conditionId,{}) then dialogue=row;break end
    end
    if not dialogue then return 0 end
    local pending,seen,result={dialogue.entryNodeId},{},0
    while #pending>0 do
        local id=table.remove(pending)
        if not seen[id] then
            seen[id]=true
            for _,choiceId in ipairs(story.rules.nodes:Get(id).choiceIds) do local choice=story.rules.choices:Get(choiceId)
                if story.conditions:Check(choice.conditionId,{}) and Actions.Prepare(story,choice.actionIds) then
                    for _,actionId in ipairs(choice.actionIds) do local action=story.rules.actions:Get(actionId)
                        if action.kind=='claim_mission' and story.data:Status('mission',action.targetId)=='ready' then return 2 end
                        if action.kind=='accept_mission' and story:CanAccept(action.targetId) then result=1 end
                    end
                    if choice.nextNodeId~=0 then pending[#pending+1]=choice.nextNodeId end
                end
            end
        end
    end
    return result
end
return Markers

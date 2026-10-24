local Language = require('Language')
local Rewards = {}

-- Presentation rows are snapshots, never a source for granting rewards.
function Rewards.Row(story, action, amount, recipients)
    amount = amount == nil and action.value or amount
    if action.kind == 'recruit_npc' then amount = 1 end
    if amount == 0 then return nil end
    if action.kind == 'add_coins' then
        return {kind='coins',name=Language.MissionRewardCoins,amount=amount}
    elseif action.kind == 'grant_experience' then
        return {kind='experience',name=Language.MissionRewardExperience,amount=amount,perMember=true,recipients=recipients}
    elseif action.kind == 'grant_item' then
        local item = story.rules.config:GetTable('EquipmentItemTable'):Get(action.targetId)
        return {kind='item',name=item.name,amount=amount,itemId=action.targetId,iconPath=item.iconPath}
    elseif action.kind == 'recruit_npc' then
        return {kind='recruit',name=story.rules.npcs:Get(action.targetId).name,amount=1,targetId=action.targetId}
    elseif action.kind == 'add_relation' then
        return {kind='relation',name=story.rules.npcs:Get(action.targetId).name,amount=amount,targetId=action.targetId}
    elseif action.kind == 'add_reputation' then
        return {kind='reputation',name=story.rules.factions:Get(action.targetId).name,amount=amount,targetId=action.targetId}
    end
end

local function sameRecipients(left,right)
    if left == nil or right == nil then return left == right end
    if #left ~= #right then return false end
    for i,actor in ipairs(left) do if actor.id ~= right[i].id then return false end end
    return true
end

function Rewards.Append(rows,row)
    if not row then return end
    for index,current in ipairs(rows) do
        if current.kind == row.kind and current.itemId == row.itemId and current.targetId == row.targetId
            and sameRecipients(current.recipients,row.recipients) then
            current.amount = current.amount + row.amount
            if current.amount == 0 then table.remove(rows,index) end
            return
        end
    end
    local copy = {}
    for key,value in pairs(row) do copy[key] = value end
    rows[#rows+1] = copy
end

function Rewards.Preview(story,actionIds)
    local rows = {}
    for _,id in ipairs(actionIds) do
        local action = story.rules.actions:Get(id)
        if action.kind == 'claim_mission' then
            for _,row in ipairs(Rewards.Preview(story,story.rules.missions:Get(action.targetId).actionIds)) do Rewards.Append(rows,row) end
        else Rewards.Append(rows,Rewards.Row(story,action)) end
    end
    return rows
end

return Rewards

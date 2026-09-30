local Actions = {}
function Actions.Prepare(story, ids)
    local plan = {steps={}, items={}, counts={}, recruits={}, coins=story.adventure.player.Coins, members=story.adventure.data.PartyCount, facts={}, progress={}}
    local function append(id)
        local row = story.rules.actions:Get(id); local kind = row.kind
        if kind == 'accept_mission' then
            local key = 'mission:'..row.targetId
            if plan.progress[key] then return false, '同一操作重复修改任务' end
            local ok, reason = story:CanAccept(row.targetId); if not ok then return false, reason end
            plan.progress[key] = true; plan.steps[#plan.steps+1] = {kind='accept', id=row.targetId}
        elseif kind == 'claim_mission' then
            local key = 'mission:'..row.targetId
            if plan.progress[key] then return false, '同一操作重复修改任务' end
            if story.data:Status('mission',row.targetId) ~= 'ready' then return false, '任务尚未就绪或已经领取' end
            plan.progress[key] = true
            for _, reward in ipairs(story.rules.missions:Get(row.targetId).actionIds) do local ok,reason=append(reward); if not ok then return false,reason end end
            plan.steps[#plan.steps+1] = {kind='complete', id=row.targetId}
        elseif kind == 'recruit_npc' then
            local key = 'recruited:'..row.targetId
            if plan.facts[key] or story.data:GetValue(key) ~= 0 then return false, '这位同行者已经入队' end
            if plan.members >= story.adventure.recipe.maxPartySize then return false, '队伍已满，任务保持待领取' end
            local prepared,reason = story.npcs:PrepareRecruit(row.targetId, plan.members + 1)
            if not prepared then return false,reason end
            plan.members = plan.members + 1; plan.facts[key] = prepared.actorId
            plan.recruits[#plan.recruits+1] = prepared
            local items=story.adventure.equipment.initialLoadouts:Items(prepared.actor.TemplateId)
            for _,id in ipairs(items) do plan.items[#plan.items+1]=id;plan.counts[#plan.counts+1]=1 end
            plan.steps[#plan.steps+1] = {kind='recruit', prepared=prepared}
        elseif kind == 'grant_item' then
            plan.items[#plan.items+1] = row.targetId; plan.counts[#plan.counts+1] = row.value
            plan.steps[#plan.steps+1] = {kind=kind, row=row}
        elseif kind == 'add_coins' then
            plan.coins = plan.coins + row.value
            if plan.coins < 0 or plan.coins > 2147483647 then return false, '金币不足或超过上限' end
            plan.steps[#plan.steps+1] = {kind=kind, row=row}
        else
            local key, value
            if kind == 'set_flag' then key, value = 'flag:'..row.key, row.value
            else
                local definition = kind == 'add_relation' and story.rules.npcs:Get(row.targetId) or story.rules.factions:Get(row.targetId)
                key = (kind == 'add_relation' and 'relation:' or 'reputation:')..row.targetId
                local current = plan.facts[key]; if current == nil then current = story.data:GetValue(key) end
                value = math.max(kind == 'add_relation' and definition.relationMin or definition.minValue,
                    math.min(kind == 'add_relation' and definition.relationMax or definition.maxValue, current + row.value))
            end
            plan.facts[key] = value; plan.steps[#plan.steps+1] = {kind='fact', key=key, value=value}
        end
        return true
    end
    for _, id in ipairs(ids) do local ok, reason = append(id); if not ok then return nil, reason end end
    if #plan.items > 0 and not story.adventure.equipment:CanGrant(plan.items, plan.counts) then return nil, '背包空间不足，任务保持待领取' end
    if #plan.recruits > 0 then
        local reason; plan.deployment,reason = story.npcs:PrepareDeployment(plan.recruits)
        if not plan.deployment then return nil,reason end
    end
    return plan
end
function Actions.Apply(story, plan)
    for _, step in ipairs(plan.steps) do
        if step.kind == 'accept' then story.data:Begin('mission',step.id)
        elseif step.kind == 'complete' then story.data:Complete('mission',step.id)
        elseif step.kind == 'recruit' then story.npcs:Recruit(step.prepared)
        elseif step.kind == 'fact' then story.data:SetValue(step.key,step.value)
        elseif step.kind == 'grant_item' then assert(story.adventure.equipment:Grant(step.row.targetId,step.row.value))
        elseif step.kind == 'add_coins' then
            if step.row.value < 0 then assert(story.adventure.player:TrySpendCoins(-step.row.value))
            else story.adventure.player:AddCoins(step.row.value) end
        else error('Unknown prepared narrative action') end
    end
    if plan.deployment then story.npcs:ApplyDeployment(plan.deployment) end
end
return Actions

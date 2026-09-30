local Save = {}
function Save.Validate(story,prepared)
    local data = assert(prepared.Narrative,'Missing narrative save state')
    local actors = {}; for i=0,prepared.ActorCount-1 do local actor=prepared:GetActorAt(i);actors[actor.Id]=actor end
    for i=0,data.ProgressCount-1 do
        local progress = data:GetProgressAt(i)
        if progress.Kind == 'mission' then story.rules.missions:Get(progress.Id)
        else
            local quest = story.rules.quests:Get(progress.Id)
            assert(data:Status('mission',quest.missionId) ~= 'inactive','存档阶段没有所属任务')
        end
    end
    for i=0,data.ValueCount-1 do
        local key = data:GetValueKeyAt(i); local kind,id = key:match('^([%a_]+):(.+)$')
        assert(kind,'无效叙事事实键')
        local value = data:GetValue(key)
        if kind == 'relation' then
            local npc = story.rules.npcs:Get(assert(tonumber(id))); assert(value >= npc.relationMin and value <= npc.relationMax,'存档 NPC 好感越界')
        elseif kind == 'reputation' then
            local faction = story.rules.factions:Get(assert(tonumber(id))); assert(value >= faction.minValue and value <= faction.maxValue,'存档阵营声望越界')
        elseif kind == 'recruited' then
            local npc = story.rules.npcs:Get(assert(tonumber(id))); local actor = actors[value]
            assert(npc.recruitable and actor and actor.TemplateId == npc.actorTemplateId and value == 10000 + npc.id,'存档招募记录与队伍不一致')
        else assert(kind == 'flag' and id:match('^[%a_][%w_]*$'),'未知叙事事实类型') end
    end
    for id,actor in pairs(actors) do if id>=10000 and id<100000 then
        local npc=story.rules.npcs:Get(id-10000)
        assert(data:GetValue('recruited:'..npc.id)==id and actor.TemplateId==npc.actorTemplateId,'存档队员缺少对应招募记录')
    end end
end
return Save

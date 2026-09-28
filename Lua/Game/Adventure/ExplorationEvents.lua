-- 配置决定触发来源；消费记录归 AdventureData，局部地图只暂停、不重建。
local Triggers={};Triggers.__index=Triggers
function Triggers.New(config,adventure)
    local self=setmetatable({adventure=adventure,rules=config:GetTable('ExplorationEventTable')},Triggers)
    for _,rule in ipairs(self.rules:All()) do
        local event=adventure.events.events:Get(rule.eventId)
        for _,id in ipairs(event.choiceIds) do
            assert(#adventure.events.choices:Get(id).encounterIds==0,'Exploration stories cannot start a detached battle')
        end
    end
    return self
end
function Triggers:Try(kind,targetId)
    local adventure=self.adventure;local data=adventure.data
    if data.Phase~='area' then return false end
    local area,state=adventure.areas:ActiveLayout(),data.Areas.Active
    for _,rule in ipairs(self.rules:All()) do
        local matches=#rule.areaIds==0
        for _,id in ipairs(rule.areaIds) do if id==area.configId then matches=true end end
        local key=data.SiteId..':'..rule.id
        if matches and rule.trigger==kind and (rule.targetId==0 or rule.targetId==targetId)
            and (not rule.once or not data:HasStoryTrigger(key)) then
            local cell,entry=area.cells[state.CellIndex],area.cells[area.entryIndex]
            if require('Game.Map.HexGrid').Distance(cell.q,cell.r,entry.q,entry.r)>=rule.minDistance then
                local ok=adventure.events:BeginArea(rule.eventId,key,area.name)
                if ok then
                    state:SetInteraction(0,0)
                    local event=adventure.events.events:Get(rule.eventId)
                    if event.presentation=='simple' then
                        assert(adventure:Choose(event.choiceIds[1]));assert(adventure:ReturnToMap())
                    end
                    return true
                end
            end
        end
    end
    return false
end
return Triggers

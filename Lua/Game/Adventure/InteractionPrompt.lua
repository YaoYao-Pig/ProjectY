-- Shared eligibility/priority for the E key, object prompt and HUD action button.
local Prompt={}
function Prompt.Find(adventure)
    if adventure.data.Phase~='area' then return nil end
    local areas=adventure.areas;local area,state=areas:ActiveLayout(),adventure.data.Areas.Active
    if state.InteractionKind~=0 then return nil end
    local radius=1;for _,site in ipairs(area.facilities) do radius=math.max(radius,site.interactionRadius) end
    local distance,queue,head={[state.CellIndex]=0},{state.CellIndex},1
    while head<=#queue do local index=queue[head];head=head+1
        if distance[index]<radius then for _,cell in ipairs(area:Neighbors(area.cells[index])) do
            if not distance[cell.index] then distance[cell.index]=distance[index]+1;queue[#queue+1]=cell.index end
        end end
    end
    local best
    local function add(kind,id,index,title,action,command,a,b,priority,steps)
        local row={kind=kind,id=id,cellIndex=index,title=title,body='靠近目标后按 E',caption=action..'  [E]',
            action=action,command=command,a=a,b=b or 0,priority=priority,steps=steps}
        if not best or steps<best.steps or steps==best.steps and (priority<best.priority or priority==best.priority and id<best.id) then best=row end
    end
    for _,site in ipairs(area.facilities) do local steps=distance[site.entryIndex]
        if steps and steps<=site.interactionRadius then add(1,site.id,site.entryIndex,site.name,'交互','area_interact',1,site.id,2,steps) end
    end
    for _,npc in ipairs(area.npcs) do local live=state:GetNpcAt(npc.id-1);local steps=distance[live.CellIndex]
        if live.Present and steps and steps<=1 then
            local row=npc.narrativeId and adventure.narrative.rules.npcs:Get(npc.narrativeId) or areas.config:GetTable('MapAreaTownNpcTable'):Get(npc.templateId)
            local merchant=adventure.shop.rules:Resolve(area,npc)
            add(2,npc.id,live.CellIndex,row.name,merchant and '交易' or '交谈','area_interact',2,npc.id,npc.narrativeId and 0 or 1,steps)
        end
    end
    for _,loot in ipairs(adventure.equipment:LootSnapshot(areas)) do
        if loot.canSearch and loot.near then add(3,loot.id,loot.cellIndex,loot.name,loot.looted and '存放' or '搜刮','area_loot',loot.id,0,4,distance[loot.cellIndex] or 1) end
    end
    for _,obstacle in ipairs(adventure.obstacles:Snapshot()) do
        if adventure.obstacles:Near(adventure.obstacles.data:Get(state.SiteId,obstacle.id)) then
            add(4,obstacle.id,obstacle.cells[1],obstacle.name,'处理','area_obstacle',obstacle.id,0,3,distance[obstacle.cells[1]] or 1)
        end
    end
    return best
end
function Prompt.Execute(adventure)
    local row=Prompt.Find(adventure)
    if not row then return false,'附近没有可交互的目标' end
    return adventure:AreaCommand(row.command,row.a,row.b)
end
return Prompt

local Hex=require('Game.Map.HexGrid')
local Random=require('Game.Map.SeededRandom')
local Generator={}
-- Runtime obstacles overlay walkable terrain. A cluster can close a narrow passage; wide terrain can offer a detour.
function Generator.Plan(area,rules,occupied)
    local queue,distance=require('Game.Loot.ChestGenerator').Distances(area)
    local used,plans={},{ }
    for index in pairs(occupied) do used[index]=true end
    for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do used[index]=true end end
    used[area.entryIndex]=true;used[area.goalIndex]=true
    for _,rule in ipairs(rules) do if rule.areaId==area.configId then
        local random=Random((area.seed ~ rule.seedSalt) & 0xffffffff)
        local candidates={}
        for _,index in ipairs(queue) do if distance[index]>=rule.minDistance then candidates[#candidates+1]=index end end
        -- Prefer corridors for movement barriers; use the stable seeded order within each group.
        for i=#candidates,2,-1 do local j=random:Integer(1,i);candidates[i],candidates[j]=candidates[j],candidates[i] end
        if rule.blocksMovement then table.sort(candidates,function(a,b)
            local ac,bc=area.cells[a].roomId==0,area.cells[b].roomId==0
            if ac~=bc then return ac end
            return false
        end) end
        for number=1,rule.count do
            local selected
            for _,index in ipairs(candidates) do if not used[index] then
                local center=area.cells[index];local cells={index};local fits=true
                if rule.blocksMovement then
                    for _,other in ipairs(area:Neighbors(center)) do cells[#cells+1]=other.index end
                end
                for _,cell in ipairs(cells) do
                    if used[cell] or distance[cell]<rule.minDistance then fits=false;break end
                end
                for _,plan in ipairs(plans) do local previous=area.cells[plan.cells[1]]
                    if Hex.Distance(center.q,center.r,previous.q,previous.r)<rule.spacing then fits=false;break end
                end
                if fits then selected=cells;break end
            end end
            assert(selected,'Cannot place configured map obstacle: '..rule.id)
            for _,index in ipairs(selected) do used[index]=true end
            plans[#plans+1]={ruleId=rule.id,cells=selected,seed=(area.seed ~ rule.seedSalt ~ number*65537) & 0xffffffff}
        end
    end end
    return plans
end
return Generator

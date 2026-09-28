-- 只输出生成计划。放置不阻断导航，数量/距离/间距/房间筛选均来自配置。
local Random=require('Game.Map.SeededRandom')
local Hex=require('Game.Map.HexGrid')
local Generator={}
function Generator.Distances(area)
    local queue,dist,head={area.entryIndex},{[area.entryIndex]=0},1
    while head<=#queue do
        local index=queue[head];head=head+1
        for _,cell in ipairs(area:Neighbors(area.cells[index])) do if not dist[cell.index] then dist[cell.index]=dist[index]+1;queue[#queue+1]=cell.index end end
    end
    return queue,dist
end
function Generator.Plan(area,rules,occupied)
    local queue,dist=Generator.Distances(area);local plans,used={},{}
    for index in pairs(occupied) do used[index]=true end
    for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do used[index]=true end end
    for _,rule in ipairs(rules) do if rule.areaId==area.configId then
        assert(rule.minCount<=rule.maxCount and rule.minDistance<=rule.maxDistance,'Invalid chest generation range')
        assert(rule.strategy=='reachable' or rule.strategy=='rooms','Unknown chest placement strategy')
        local random=Random((area.seed ~ rule.seedSalt) & 0xffffffff)
        local candidates={}
        for _,index in ipairs(queue) do local cell=area.cells[index]
            if not used[index] and dist[index]>=rule.minDistance and dist[index]<=rule.maxDistance and
                (rule.strategy=='reachable' or cell.roomId>0) and index~=area.entryIndex and index~=area.goalIndex then candidates[#candidates+1]=index end
        end
        local count=random:Integer(rule.minCount,rule.maxCount)
        for number=1,count do
            local selected
            while #candidates>0 and not selected do
                local index=table.remove(candidates,random:Integer(1,#candidates));local cell=area.cells[index];local fits=not used[index]
                for _,plan in ipairs(plans) do local other=area.cells[plan.cellIndex]
                    if Hex.Distance(cell.q,cell.r,other.q,other.r)<math.max(rule.spacing,plan.spacing) then fits=false;break end
                end
                if fits then selected=index end
            end
            assert(selected,'Chest placement budget cannot fit configured count/distances/spacing: '..rule.id)
            used[selected]=true;plans[#plans+1]={cellIndex=selected,lootTableId=rule.lootTableId,spacing=rule.spacing,
                seed=(area.seed ~ (rule.id*104729) ~ (number*65537)) & 0xffffffff}
        end
    end end
    return plans
end
return Generator

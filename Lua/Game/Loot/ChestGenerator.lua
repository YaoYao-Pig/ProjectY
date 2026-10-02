-- 只输出静态计划；耐久、开启与库存归 MapAreaLootData。
local Random=require('Game.Map.SeededRandom')
local Hex=require('Game.Map.HexGrid')
local Generator={}
function Generator.Distances(area,blocked)
    local queue,dist,head={area.entryIndex},{[area.entryIndex]=0},1
    while head<=#queue do
        local index=queue[head];head=head+1
        for _,cell in ipairs(area:Neighbors(area.cells[index])) do
            if not dist[cell.index] and not (blocked and blocked[cell.index]) then
                dist[cell.index]=dist[index]+1;queue[#queue+1]=cell.index
            end
        end
    end
    return queue,dist
end
local function rotate(q,r,rotation)
    for _=1,rotation do q,r=-r,q+r end
    return q,r
end
function Generator.Plan(area,rules,occupied,containers)
    local queue,dist=Generator.Distances(area);local plans,used,blocked={},{},{}
    for index in pairs(occupied) do used[index]=true end
    for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do used[index]=true end end
    for _,rule in ipairs(rules) do if rule.areaId==area.configId then
        assert(rule.minCount<=rule.maxCount and rule.minDistance<=rule.maxDistance,'Invalid container generation range')
        local random=Random((area.seed ~ rule.seedSalt) & 0xffffffff)
        local chance=rule.spawnChance or 100
        if chance==100 or chance>0 and random:Integer(1,10000)<=chance*100 then
            local definition=containers and containers:Get(rule.lootTableId)
            local candidates={}
            local function eligible(cell,distance)
                local room=cell.roomId>0 and area.rooms[cell.roomId]
                return distance and ((rule.layer or -1)<0 or cell.layer==rule.layer)
                    and distance>=rule.minDistance and distance<=rule.maxDistance
                    and ((rule.roomStyleId or 0)==0 or room and room.style and room.style.id==rule.roomStyleId)
                    and ((rule.districtId or 0)==0 or room and room.districtId==rule.districtId)
                    and ((rule.presetId or 0)==0 or room and room.presetId==rule.presetId)
            end
            if rule.strategy=='props' then
                assert((rule.propId or 0)>0,'Prop container requires a prop definition')
                for _,prop in ipairs(area.props) do if prop.configId==rule.propId then
                    local distance
                    for _,index in ipairs(prop.cells) do for _,other in ipairs(area:Neighbors(area.cells[index])) do
                        if dist[other.index] then distance=math.min(distance or math.huge,dist[other.index]+1) end
                    end end
                    if eligible(area.cells[prop.cellIndex],distance) then candidates[#candidates+1]={index=prop.cellIndex,prop=prop} end
                end end
            else
                assert(rule.strategy=='reachable' or rule.strategy=='rooms' or rule.strategy=='wall' or rule.strategy=='goal' or rule.strategy=='fixed','Unknown container placement strategy')
                for _,index in ipairs(queue) do local cell=area.cells[index];local match=true
                    if rule.strategy=='rooms' then match=cell.roomId>0
                    elseif rule.strategy=='wall' then
                        match=false
                        for _,neighbor in ipairs(cell.neighbors) do local other=area.cells[neighbor]
                            if other and other.kind=='wall' then match=true;break end
                        end
                    elseif rule.strategy=='goal' then
                        local goal=area.cells[area.goalIndex]
                        match=cell.layer==goal.layer and Hex.Distance(cell.q,cell.r,goal.q,goal.r)<=3
                    elseif rule.strategy=='fixed' then match=cell.q==rule.q and cell.r==rule.r end
                    if match and not used[index] and index~=area.entryIndex and index~=area.goalIndex and eligible(cell,dist[index]) then
                        candidates[#candidates+1]={index=index}
                    end
                end
            end
            local count=random:Integer(rule.minCount,rule.maxCount)
            local converted={}
            for _,plan in ipairs(plans) do if plan.prop then converted[plan.prop.id]=true end end
            for number=1,count do
                local selected
                while #candidates>0 and not selected do
                    local candidate=table.remove(candidates,random:Integer(1,#candidates));local cell=area.cells[candidate.index]
                    local prop=candidate.prop
                    local rotation=prop and prop.rotation or ((rule.rotation or -1)>=0 and rule.rotation or random:Integer(0,5))
                    local cells={};local fits=not prop or not converted[prop.id]
                    if prop then
                        cells[1]=candidate.index
                        for _,index in ipairs(prop.cells) do if index~=candidate.index then cells[#cells+1]=index end end
                    else
                        for i,q in ipairs(definition and definition.footprintQ or {0}) do
                            local x,z=rotate(q,definition and definition.footprintR[i] or 0,rotation)
                            local other=area:Find(cell.q+x,cell.r+z,cell.layer)
                            if not other or other.blocked or used[other.index] or other.index==area.entryIndex or other.index==area.goalIndex
                                or math.abs((other.height or 0)-(cell.height or 0))>.05 then fits=false;break end
                            cells[#cells+1]=other.index
                        end
                    end
                    for _,index in ipairs(cells) do if occupied[index] then fits=false end end
                    for _,plan in ipairs(plans) do local other=area.cells[plan.cellIndex]
                        if cell.layer==other.layer and Hex.Distance(cell.q,cell.r,other.q,other.r)<math.max(rule.spacing,plan.spacing) then fits=false;break end
                    end
                    -- 每次放置后保留原可达地面；不能把箱子当作跨层导航边。
                    if fits and definition and definition.blocksMovement and not prop then
                        for _,index in ipairs(cells) do blocked[index]=true end
                        local _,reach=Generator.Distances(area,blocked)
                        for _,index in ipairs(queue) do if not blocked[index] and not reach[index] then fits=false;break end end
                        local function accessible(footprint)
                            for _,index in ipairs(footprint) do for _,other in ipairs(area:Neighbors(area.cells[index])) do
                                if reach[other.index] then return true end
                            end end
                            return false
                        end
                        if fits and not accessible(cells) then fits=false end
                        if fits then for _,plan in ipairs(plans) do if not accessible(plan.cells) then fits=false;break end end end
                        if not fits then for _,index in ipairs(cells) do blocked[index]=nil end end
                    end
                    if fits then selected={cellIndex=cell.index,lootTableId=rule.lootTableId,spacing=rule.spacing,cells=cells,
                        rotation=rotation,prop=prop,poolOverrideId=rule.poolOverrideId or 0,unlockEncounterId=rule.unlockEncounterId or 0,
                        seed=(area.seed ~ (rule.id*104729) ~ (number*65537)) & 0xffffffff} end
                end
                assert(selected,'Container placement cannot fit configured count/distances/spacing: '..rule.id)
                for _,index in ipairs(selected.cells) do used[index]=true end
                if selected.prop then converted[selected.prop.id]=true end
                plans[#plans+1]=selected
            end
        end
    end end
    return plans
end
return Generator

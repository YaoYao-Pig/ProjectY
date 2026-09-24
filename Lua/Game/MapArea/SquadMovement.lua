-- 探索编队的纯规划器：每帧四人同时占不同地格，不持有运行状态。
local Hex=require('Game.Map.HexGrid')
local Squad={}
local function copy(values) local result={};for i,v in ipairs(values) do result[i]=v end;return result end
local function distances(area,target,allowed,limit)
    limit=limit or 12 -- 编队只需局部距离场，避免对每一步反复遍历整个地牢。
    local queue,head,result={target},1,{[target]=0}
    while head<=#queue do
        local index=queue[head];head=head+1
        for _,nextIndex in ipairs(area.cells[index].neighbors) do
            local cell=area.cells[nextIndex]
            if result[index]<limit and area:CanStep(area.cells[index],cell) and not result[nextIndex] and allowed(cell) then
                result[nextIndex]=result[index]+1;queue[#queue+1]=nextIndex
            end
        end
    end
    return result
end
function Squad.Deploy(area,anchor,count,allowed)
    assert(count>=1 and count<=4,'Squad size must be 1..4')
    local result,queue,head,seen={},{anchor},1,{[anchor]=true}
    while head<=#queue and #result<count do
        local index=queue[head];head=head+1
        if not allowed or allowed(area.cells[index]) then result[#result+1]=index end
        for _,cell in ipairs(area:Neighbors(area.cells[index])) do
            if not seen[cell.index] then seen[cell.index]=true;queue[#queue+1]=cell.index end
        end
    end
    assert(#result==count,'MapArea entrance has insufficient squad space')
    return result
end
-- 宽处取领队后方的三角队形；无可用侧格时，目标改为前一位队员的足迹。
local function targets(area,positions,leader,allowed)
    local from,to=area.cells[positions[1]],area.cells[leader]
    local direction=1
    for d=1,6 do if from.neighbors[d]==leader then direction=d;break end end
    local behind=(direction+2)%6+1
    local left=(behind+4)%6+1;local right=behind%6+1
    local candidates={area.cells[to.neighbors[left]],area.cells[to.neighbors[right]],area.cells[to.neighbors[behind]]}
    local result={leader}
    for i=2,#positions do
        local cell=candidates[i-1]
        result[i]=area:CanStep(to,cell) and allowed(cell) and cell.index or positions[i-1]
    end
    return result
end
-- 最多 7³ 种同帧组合；排除重格、迎面交换与穿墙。距离场使队员能绕陈设跟进。
local function jointStep(area,positions,leader,goals,fields,allowed,avoid,cohesionLimit)
    local nextPositions,used={leader},{[leader]=true}
    local best,bestScore
    local function visit(i,score)
        if bestScore and score>=bestScore then return end
        if i>#positions then
            for _,index in ipairs(nextPositions) do if not fields[1][index] or fields[1][index]>(cohesionLimit or 4) then return end end
            best=copy(nextPositions);bestScore=score;return
        end
        local candidates={positions[i]}
        for _,index in ipairs(area.cells[positions[i]].neighbors) do
            local cell=area.cells[index]
            if area:CanStep(area.cells[positions[i]],cell) and allowed(cell) then candidates[#candidates+1]=index end
        end
        for _,index in ipairs(candidates) do
            local valid=not used[index] and fields[i][index]~=nil
            for j=1,i-1 do if index==positions[j] and nextPositions[j]==positions[i] then valid=false end end
            if valid then
                used[index]=true;nextPositions[i]=index
                local value=fields[i][index]*10+(index==positions[i] and 0 or 1)+(index==avoid and 100 or 0)
                visit(i+1,score+value)
                used[index]=nil
            end
        end
    end
    visit(2,0);return best
end
function Squad.Plan(area,positions,path,allowed,settle)
    assert(#positions>=1 and #positions<=4,'Squad is not deployed')
    local current,frames=copy(positions),{}
    local function append(nextPositions)
        for _,index in ipairs(nextPositions) do frames[#frames+1]=index end
        current=nextPositions
    end
    -- 战斗结束可能分散在四格以外：领队先等待，同伴逐格收拢，再执行探索路线。
    local nearby=distances(area,current[1],allowed,4)
    local dispersed=false
    for _,index in ipairs(current) do if not nearby[index] then dispersed=true;break end end
    if dispersed then
        local goals=Squad.Deploy(area,current[1],#current,allowed)
        local fields={[1]=distances(area,current[1],allowed,#area.cells)}
        for i=2,#current do fields[i]=distances(area,goals[i],allowed,#area.cells) end
        local seen={}
        for _=1,#area.cells do
            local limit=0
            for _,index in ipairs(current) do
                if not fields[1][index] then return nil,'战后队员之间没有已探索的连通路线' end
                limit=math.max(limit,fields[1][index])
            end
            if limit<=4 then break end
            seen[table.concat(current,',')]=true
            local nextPositions=jointStep(area,current,current[1],goals,fields,allowed,nil,limit)
            if not nextPositions or seen[table.concat(nextPositions,',')] then return nil,'战后队伍暂时无法收拢，请清理附近的阻挡' end
            append(nextPositions)
        end
    end
    local finalGoals
    for _,leader in ipairs(path) do
        local goals=targets(area,current,leader,allowed);local fields={[1]=distances(area,leader,allowed,4)}
        finalGoals=goals
        for i=2,#positions do fields[i]=distances(area,goals[i],allowed) end
        local nextPositions=jointStep(area,current,leader,goals,fields,allowed)
        -- 若领队下一格被占，先留在原地让同伴侧移；绝不把队员传送过去。
        -- 等待时按领队当前位置约束队形。拐角后的位置可能比末尾同伴多隔一格，
        -- 若继续使用前方四格距离场，会把合法的原地收拢也误判为无路可走。
        local waitingFields
        for _=1,4 do
            if nextPositions then break end
            if not waitingFields then
                waitingFields={[1]=distances(area,current[1],allowed,4)}
                for i=2,#positions do waitingFields[i]=fields[i] end
            end
            local clearing=jointStep(area,current,current[1],goals,waitingFields,allowed,leader)
            if not clearing or table.concat(clearing,',')==table.concat(current,',') then return nil,'通路暂时无法容纳整队，请选择附近更开阔的位置' end
            append(clearing)
            nextPositions=jointStep(area,current,leader,goals,fields,allowed)
        end
        if not nextPositions then return nil,'小队无法在此处错身，请选择附近更开阔的位置' end
        append(nextPositions)
    end
    -- 领队抵达后允许同伴收拢；空间不足时保持合法的跟随形状，不强挤成固定三角形。
    if finalGoals and settle~=false then
        local fields={[1]=distances(area,current[1],allowed,4)}
        for i=2,#positions do fields[i]=distances(area,finalGoals[i],allowed) end
        local seen={}
        for _=1,8 do
            seen[table.concat(current,',')]=true
            local nextPositions=jointStep(area,current,current[1],finalGoals,fields,allowed)
            if not nextPositions or seen[table.concat(nextPositions,',')] then break end
            append(nextPositions)
        end
    end
    return frames
end
return Squad

-- Read-only projectile queries. Exploration keeps the map's full CanSee contract.
local Hex=require('Game.Map.HexGrid')
local Trajectory={}
local descriptions={sight='',direct='直射：忽略攻击者相邻一格；后续路径上的角色或物体可能拦截这一发。',
    lobbed='抛射：仅攻击者相邻一格内的角色或物体可能拦截这一发。'}
function Trajectory.Description(mode) return assert(descriptions[mode],'Unknown skill trajectory: '..tostring(mode)) end
local function terrain(cell)
    return {kind='terrain',key='terrain:'..(cell.layer or 0)..':'..Hex.Key(cell.q,cell.r),cell=cell,name='地形或陈设'}
end
local function occupant(value,cell)
    if not value then return nil end
    if value==true then return terrain(cell) end
    if type(value)=='table' and value.kind then
        assert(value.key,'Projectile occupant needs a stable key')
        if value.kind=='actor' and (value.actor.HP<=0 or value.actor.AnimalOwnerId and value.actor.AnimalOwnerId~=0 and not CS.ProjectY.Data.AnimalCompanionState.Independent(value.actor)) then return nil end
        local result={};for key,item in pairs(value)do result[key]=item end;result.cell=cell;return result
    end
    if value.HP<=0 or value.AnimalOwnerId and value.AnimalOwnerId~=0 and not CS.ProjectY.Data.AnimalCompanionState.Independent(value) then return nil end
    return {kind='actor',key='actor:'..value.Id,actor=value,cell=cell}
end
local function touches(physical,origin,target)
    for i=0,physical.CellCount-1 do
        local index=physical:GetCellAt(i)
        if index==origin.index or index==target.index then return true end
    end
    return false
end
function Trajectory.Trace(board,origin,target,mode,occupied,guided)
    assert(descriptions[mode],'Unknown skill trajectory: '..tostring(mode))
    local result={reachable=false,blockers={}}
    if not origin or not target or (origin.layer or 0)~=(target.layer or 0) or
        not board:Find(origin.q,origin.r,origin.layer) or not board:Find(target.q,target.r,target.layer) then return result end
    local area=board.area or (board.CanTrace and board)
    if mode=='sight' and not guided then result.reachable=not area or area:CanSee(origin,target);return result end
    local distance=Hex.Distance(origin.q,origin.r,target.q,target.r)
    local cells,seen={},{}
    -- Asking the existing geometry to ignore intermediates enumerates its complete ray,
    -- including layered hex-column crossings, while retaining endpoint floor checks.
    local function collect(q,r)
        if q==origin.q and r==origin.r or q==target.q and r==target.r then return false end
        local key=Hex.Key(q,r)
        if not seen[key] then seen[key]=true;cells[#cells+1]={q=q,r=r} end
        return false
    end
    if area and not area:CanTrace(origin,target,nil,collect) then return result end
    if guided then result.reachable=true;return result end
    occupied=occupied or {}
    local function checked(q,r)
        local steps=Hex.Distance(origin.q,origin.r,q,r)
        return mode=='direct' and steps>1 or mode=='lobbed' and steps==1
    end
    local ax,_,az=Hex.ToWorld(origin.q,origin.r,0,1)
    local bx,_,bz=Hex.ToWorld(target.q,target.r,0,1)
    if not area then
        for _,epsilon in ipairs({-.000001,.000001})do for step=1,distance-1 do
            local t=step/distance;collect(Hex.FromWorld(ax+(bx-ax)*t+epsilon,az+(bz-az)*t+epsilon,1))
        end end
    end
    local dx,dz=bx-ax,bz-az
    for _,cell in ipairs(cells)do
        local x,_,z=Hex.ToWorld(cell.q,cell.r,0,1);cell.order=(x-ax)*dx+(z-az)*dz
    end
    table.sort(cells,function(a,b)
        if math.abs(a.order-b.order)>1e-8 then return a.order<b.order end
        return a.q<b.q or a.q==b.q and a.r<b.r
    end)
    local excluded={}
    for _,endpoint in ipairs({origin,target})do
        local value=occupant(occupied[Hex.Key(endpoint.q,endpoint.r)],endpoint)
        if value then excluded[value.key]=true end
    end
    local added={}
    local function add(blocker,batch)
        if not blocker or excluded[blocker.key] or added[blocker.key] then return end
        if blocker.kind=='container' and touches(blocker.physical,origin,target) then excluded[blocker.key]=true;return end
        if blocker.kind=='actor' then
            local actor=blocker.actor
            if actor.Q==origin.q and actor.R==origin.r or actor.Q==target.q and actor.R==target.r then excluded[blocker.key]=true;return end
        end
        added[blocker.key]=true;batch[#batch+1]=blocker
    end
    for _,point in ipairs(cells)do if checked(point.q,point.r) then
        local cell=board:Find(point.q,point.r,origin.layer)
        if not cell then return result end
        local batch={}
        if area then
            if area.ProjectileBlockers then
                for _,blocker in ipairs(area:ProjectileBlockers(origin,target,cell))do blocker.cell=cell;add(blocker,batch)end
            elseif not area:CanTrace(origin,target,nil,function(q,r)return q==cell.q and r==cell.r end) then add(terrain(cell),batch)end
        elseif cell.blocked then add(terrain(cell),batch)end
        add(occupant(occupied[Hex.Key(cell.q,cell.r)],cell),batch)
        table.sort(batch,function(a,b)return a.key<b.key end)
        for _,blocker in ipairs(batch)do result.blockers[#result.blockers+1]=blocker end
    end end
    result.reachable=true;return result
end
function Trajectory.CanReach(board,origin,target,mode,occupied,guided)
    return Trajectory.Trace(board,origin,target,mode,occupied,guided).reachable
end
return Trajectory

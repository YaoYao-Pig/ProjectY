-- MapArea 的静态地形与查询；探索记录、移动路径等可变状态归 C# Data。
local Hex = require('Game.Map.HexGrid')
local Layout = {}; Layout.__index = Layout
function Layout.New(definition, seed, source, theme)
    local area = setmetatable({configId=definition.id,name=definition.name,areaType=definition.areaType,
        seed=seed,source=source,theme=theme,width=definition.width,height=definition.height,
        hexRadius=definition.hexRadius,visionRadius=definition.visionRadius,moveStepSeconds=definition.moveStepSeconds,
        discovery=definition.discovery or 'explore',facilities={},npcs={},
        cells={},cellsByKey={},rooms={},generationVersion=1,walkableCount=0}, Layout)
    for r=0,area.height-1 do for q=0,area.width-1 do
        local cell={index=#area.cells+1,q=q,r=r,blocked=true,blocksSight=true,kind='wall',roomId=0,
            roomOwner=0,roomTier=0,obstacleId=0,reserved=false,neighbors={}}
        area.cells[cell.index]=cell;area.cellsByKey[Hex.Key(q,r)]=cell
    end end
    for _,cell in ipairs(area.cells) do for direction=1,6 do
        local q,r=Hex.Neighbor(cell.q,cell.r,direction)
        local other=area:Find(q,r);cell.neighbors[direction]=other and other.index or 0
    end end
    return area
end
function Layout:Find(q,r) return self.cellsByKey[Hex.Key(q,r)] end
function Layout:Neighbors(cell)
    local result={}
    for _,index in ipairs(cell.neighbors) do
        local other=self.cells[index]
        if other and not other.blocked then result[#result+1]=other end
    end
    return result
end
-- 探索移动采用六邻接路径；可用已发现格过滤，防止通过未知地形预知捷径。
function Layout:FindPath(startIndex, goalIndex, allowed)
    local start,goal=assert(self.cells[startIndex]),assert(self.cells[goalIndex])
    if goal.blocked or allowed and not allowed(goal) then return nil end
    local queue,previous,head={startIndex},{[startIndex]=0},1
    while head<=#queue do
        local index=queue[head];head=head+1
        if index==goalIndex then
            local reversed,path={},{}
            while index~=startIndex do reversed[#reversed+1]=index;index=previous[index] end
            for i=#reversed,1,-1 do path[#path+1]=reversed[i] end
            return path
        end
        for _,otherIndex in ipairs(self.cells[index].neighbors) do
            local other=self.cells[otherIndex]
            if other and not other.blocked and previous[otherIndex]==nil and (not allowed or allowed(other)) then
                previous[otherIndex]=index;queue[#queue+1]=otherIndex
            end
        end
    end
end
-- 墙格本身可见；射线中途遇墙即阻挡。微小双向偏移避免沿顶点缝隙偷看。
function Layout:CanSee(origin, target)
    local distance=Hex.Distance(origin.q,origin.r,target.q,target.r)
    if distance<=1 then return true end
    local ax,_,az=Hex.ToWorld(origin.q,origin.r,0,1)
    local bx,_,bz=Hex.ToWorld(target.q,target.r,0,1)
    for _,epsilon in ipairs({-0.000001,0.000001}) do
        for step=1,distance-1 do
            local t=step/distance
            local q,r=Hex.FromWorld(ax+(bx-ax)*t+epsilon,az+(bz-az)*t+epsilon,1)
            local cell=self:Find(q,r)
            if not cell or cell.blocksSight then return false end
        end
    end
    return true
end
function Layout:VisibleFrom(index)
    local origin=assert(self.cells[index]);local result={}
    local radius=self.visionRadius
    for dr=-radius,radius do for dq=math.max(-radius,-dr-radius),math.min(radius,-dr+radius) do
        local target=self:Find(origin.q+dq,origin.r+dr)
        if target and self:CanSee(origin,target) then result[#result+1]=target.index end
    end end
    return result
end
-- 配置与原格子身份保持共享；外部不能通过查询改写地牢布局。
function Layout.Freeze(value, seen)
    if type(value)~='table' or getmetatable(value)==false then return value end
    seen=seen or {};if seen[value] then return seen[value] end
    local proxy,data,class={},{},getmetatable(value);seen[value]=proxy
    for key,item in pairs(value) do data[key]=Layout.Freeze(item,seen) end
    return setmetatable(proxy,{__index=function(_,key) local item=data[key];if item~=nil then return item end;if class then return class[key] end end,
        __newindex=function() error('MapArea layout is read-only',2) end,
        __pairs=function() return next,data,nil end,__len=function() return #data end,__metatable=false})
end
return Layout

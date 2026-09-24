-- 生成期城市规划：目的地连接、地形代价、临街地块与增量连通检查。
-- 只维护本次生成的蓝图，游戏内的探索与占格仍由 C# Data 持有。
local Geometry=require('Game.MapArea.DungeonGeometry')
local Hex=require('Game.Map.HexGrid')
local Planner={};Planner.__index=Planner
function Planner.New(area,terrain,recipe,random,buildings)
    local pathfinder=require('Game.Map.MapPathfinder')(area)
    -- 复用 Dijkstra，但邻接必须来自真实的分层道路图，不能把桥面折叠到地面。
    for _,cell in ipairs(area.cells) do pathfinder.neighbors[cell]=area:Neighbors(cell) end
    area.roadPaths={};area.planningDiagnostics={skipped={},candidateChecks=0,loopCount=0}
    return setmetatable({area=area,terrain=terrain,recipe=recipe,random=random,pathfinder=pathfinder,homes={},protected={},buildings=buildings},Planner)
end
function Planner:Protect(door)
    self.protected[door.index]=true
    for _,other in ipairs(self.area:Neighbors(door)) do self.protected[other.index]=true end
end
function Planner:TryBlock(indices)
    local area=self.area
    for _,index in ipairs(indices) do area.cells[index].blocked=true end
    local reachable=Geometry.Reachable(area,area.entryIndex)
    local valid=#reachable==area.walkableCount-#indices
    if not valid then for _,index in ipairs(indices) do area.cells[index].blocked=false end end
    return valid
end
function Planner:Paint(path,radius,kind)
    local area,recipe=self.area,self.recipe;local queue,distance,indices={}, {},{}
    for _,cell in ipairs(path) do if not distance[cell.index] then distance[cell.index]=0;queue[#queue+1]=cell end end
    local head=1
    while head<=#queue do
        local cell=queue[head];head=head+1
        if not cell.interiorId then cell.road=true;cell.reserved=true;cell.floorAccent=recipe.pavingColor;cell.floorAccentWeight=.96 end
        if kind=='square' then cell.pavingRole='plaza' end
        if cell.kind=='garden' then cell.kind='street' end
        if distance[cell.index]<radius then for _,other in ipairs(area:Neighbors(cell)) do
            if distance[other.index]==nil then distance[other.index]=distance[cell.index]+1;queue[#queue+1]=other end
        end end
    end
    for _,cell in ipairs(path) do indices[#indices+1]=cell.index end
    area.roadPaths[#area.roadPaths+1]={kind=kind,radius=radius,cells=indices}
end
function Planner:Route(start,goal,loop)
    local area,recipe,random=self.area,self.recipe,self.random
    return self.pathfinder:FindPath(start,goal,function(from,to)
        if from.blocked or not area:CanStep(from,to) then return nil end
        local cost=1+random:Noise(to.localQ,to.localR,recipe.roadNoiseScale,733)*recipe.roadNoise
            +math.abs(to.height-from.height)*recipe.roadSlopeCost
        if to.road then cost=cost*(loop and 1.8 or recipe.roadReuse) end
        return cost
    end)
end
function Planner:Network(nodes)
    local recipe=self.recipe;local connected={[1]=true};local pairsUsed={}
    self:Paint({nodes[1]},recipe.mainRoadRadius,'entry')
    -- 目的地先形成一张树，再补少量回路；台阶和桥的实际通行代价决定街道走向。
    for _=2,#nodes do
        local best,a,b
        for i=1,#nodes do if connected[i] then for j=1,#nodes do if not connected[j] then
            local distance=Hex.Distance(nodes[i].q,nodes[i].r,nodes[j].q,nodes[j].r)+math.abs(nodes[i].height-nodes[j].height)
            if not best or distance<best then best,a,b=distance,i,j end
        end end end end
        local path=assert(self:Route(nodes[a],nodes[b]),'Royal destination is unreachable')
        self:Paint(path,recipe.mainRoadRadius,'main');connected[b]=true;pairsUsed[math.min(a,b)..':'..math.max(a,b)]=true
    end
    local candidates={}
    for a=1,#nodes do for b=a+1,#nodes do if not pairsUsed[a..':'..b] then
        candidates[#candidates+1]={a=a,b=b,distance=Hex.Distance(nodes[a].q,nodes[a].r,nodes[b].q,nodes[b].r)}
    end end end
    table.sort(candidates,function(a,b)return a.distance<b.distance or a.distance==b.distance and (a.a<b.a or a.a==b.a and a.b<b.b)end)
    for _,pair in ipairs(candidates) do
        if self.area.planningDiagnostics.loopCount>=recipe.roadLoopCount then break end
        local path=assert(self:Route(nodes[pair.a],nodes[pair.b],true));local added=0
        for _,cell in ipairs(path) do if not cell.road then added=added+1 end end
        if added>recipe.mainRoadRadius*2 then
            self:Paint(path,recipe.laneRadius,'loop');self.area.planningDiagnostics.loopCount=self.area.planningDiagnostics.loopCount+1
        end
    end
end
function Planner:FrontageDistances()
    local sources={};for _,cell in ipairs(self.area.cells) do if cell.road then sources[#sources+1]=cell end end
    return self.pathfinder:Distances(sources,function(from,to)
        if not from.blocked and self.area:CanStep(from,to) then return 1 end
    end,self.recipe.frontageDistance)
end
function Planner:Candidate(lot,q,r,rotation)
    local cells,height={},nil
    for i,dq in ipairs(lot.footprintQ) do
        local x,y=Geometry.Rotate(dq,lot.footprintR[i],rotation);local cell=self.area:Find(q+x,r+y)
        if not cell or cell.blocked or cell.reserved or self.protected[cell.index] then return nil end
        height=height or cell.height
        if math.abs(height-cell.height)>.01 then return nil end
        for _,h in ipairs(cell.corners) do if math.abs(h-height)>.01 then return nil end end
        cells[#cells+1]=cell.index
    end
    local eq,er=Geometry.Rotate(lot.entryQ,lot.entryR,rotation);local door=self.area:Find(q+eq,r+er)
    if not door or door.blocked or math.abs(door.height-height)>.01 then return nil end
    for _,index in ipairs(cells) do if index==door.index then return nil end end
    -- 门口不能只剩崖边的单格窄口；服务人员、巡游者和小队需要可错身的前场。
    local occupied={};for _,index in ipairs(cells) do occupied[index]=true end
    local exits=0;for _,other in ipairs(self.area:Neighbors(door)) do if not occupied[other.index] then exits=exits+1 end end
    if exits<self.recipe.minimumDoorNeighbors then return nil end
    if not self.buildings:CanFit(lot,q,r,rotation,height,function(cell)return not cell.reserved and not self.protected[cell.index]end) then return nil end
    return {q=q,r=r,rotation=rotation,cells=cells,height=height,door=door}
end
function Planner:Place(preset,lot)
    local terrain,recipe=self.terrain,self.recipe;local district=assert(terrain.districts[preset.districtId],'Royal placement district missing')
    local targetQ,targetR=district.q+preset.localQ,district.r+preset.localR
    local candidates={};local frontage=preset.role=='house' and self:FrontageDistances() or nil
    local radius=preset.searchRadius
    if district.searchRadius>0 then radius=math.min(radius,district.searchRadius) end
    Geometry.Disk(targetQ,targetR,radius,function(q,r)
        local worldQ,worldR=terrain:World(q,r)
        for _,turn in ipairs(preset.rotations) do
            local candidate=self:Candidate(lot,worldQ,worldR,(terrain.turn+turn)%6)
            if candidate and (not frontage or frontage[candidate.door]) then
                local score=Hex.Distance(q,r,targetQ,targetR)*recipe.anchorWeight
                    +self.random:Noise(q,r,5,preset.id+743)*recipe.plotNoiseWeight
                if frontage then
                    score=score+frontage[candidate.door]*recipe.frontageWeight
                    local nearest
                    for _,home in ipairs(self.homes) do local distance=Hex.Distance(worldQ,worldR,home.q,home.r);nearest=math.min(nearest or distance,distance) end
                    if nearest then score=score+nearest*recipe.clusterWeight end
                end
                candidate.score=score;candidates[#candidates+1]=candidate
            end
        end
    end)
    table.sort(candidates,function(a,b)
        if a.score~=b.score then return a.score<b.score end
        if a.q~=b.q then return a.q<b.q end
        if a.r~=b.r then return a.r<b.r end
        return a.rotation<b.rotation
    end)
    for i=1,math.min(#candidates,recipe.candidateLimit) do
        local value=candidates[i];self.area.planningDiagnostics.candidateChecks=self.area.planningDiagnostics.candidateChecks+1
        if self:TryBlock(value.cells) then
            local id=#self.area.props+1
            for _,index in ipairs(value.cells) do
                local cell=self.area.cells[index];cell.blocksSight=true;cell.obstacleId=id
            end
            self.area.walkableCount=self.area.walkableCount-#value.cells
            value.id=id;value.assetId=lot.assetId;value.scale=lot.scale;value.districtId=preset.districtId;value.placementId=preset.id
            -- 布局只保留契约数据；门口是单独的地图格，不把生成期候选对象暴露给运行时。
            self.area.props[id]={id=id,assetId=value.assetId,q=value.q,r=value.r,rotation=value.rotation,scale=value.scale,
                height=value.height,cells=value.cells,districtId=value.districtId,placementId=value.placementId}
            value.service=self.buildings:Apply(lot,self.area.props[id],value.door)
            if preset.required or lot.houseUnits>0 then self:Protect(value.door) end
            if lot.houseUnits>0 then
                self.homes[#self.homes+1]=value
                local path=assert(self:Route(value.door,self.area.cells[self.area.entryIndex]),'Royal house has no street route')
                -- 支巷到达现有街网即止，不反复扩宽整条主街。
                local branch={};for _,cell in ipairs(path) do branch[#branch+1]=cell;if cell.road then break end end
                self:Paint(branch,recipe.laneRadius,'lane')
            end
            return value
        end
    end
    assert(not preset.required,'Royal required plot has no connected legal site: '..preset.id..' '..preset.name..' candidates='..#candidates)
    self.area.planningDiagnostics.skipped[#self.area.planningDiagnostics.skipped+1]={placementId=preset.id,reason=#candidates==0 and 'no-flat-free-plot' or 'would-disconnect-public-space'}
end
return Planner

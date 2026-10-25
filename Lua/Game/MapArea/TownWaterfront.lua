-- 整侧水岸由一维岸线定义：每个横向截面从岸边向外连续为水，直到地图边界。
local Hex=require('Game.Map.HexGrid')
local Geometry=require('Game.MapArea.DungeonGeometry')
local Random=require('Game.Map.SeededRandom')
local Waterfront={}
local function flat(cell)
    if not cell or cell.layer~=0 or cell.interiorId or cell.obstacleId~=0 or cell.reserved then return false end
    for _,height in ipairs(cell.corners) do if math.abs(height-cell.height)>.01 then return false end end
    return true
end
local function opposite(direction)return (direction+2)%6+1 end
local function link(a,b,direction)
    a.neighbors[direction]=b.index;a.walkMask=a.walkMask | (1 << (direction-1))
end
function Waterfront.Build(area,row,config,doors)
    local source=area.source.dock
    if not source then return end
    if area.source.generationVersion==9 then return require('Game.MapArea.TownWaterfrontLegacy').Build(area,row,config,doors) end
    assert(area.source.generationVersion>=10,'Full waterfront requires world generation v10')
    local settings=config:GetTable('DockSettingsTable'):Get(1)
    local definition=config:GetTable('MapAreaTownFacilityTable'):Get(settings.facilityId)
    assert(definition.kind=='dock' and definition.npcTemplateId==settings.npcTemplateId,'Invalid dock facility configuration')
    local direction=source.shoreDirection;local dq,dr=Hex.Neighbor(0,0,direction)
    local turn=(7-direction)%6;local cq,cr=area.width//2,area.height//2
    local random=Random((area.seed ~ 0x375a91c3) & 0xffffffff)
    local coordinates,slices,outline={}, {},{}
    local minCross,maxCross,cityMin,cityMax=math.huge,-math.huge,math.huge,-math.huge
    for _,cell in ipairs(area.cells) do if cell.layer==0 then
        local q,r=Geometry.Rotate(cell.q-cq,cell.r-cr,-turn);local along=q+r/2
        coordinates[cell.index]={along=along,cross=r}
        minCross=math.min(minCross,r);maxCross=math.max(maxCross,r)
        local slice=slices[r];if not slice then slice={};slices[r]=slice end;slice[#slice+1]=cell
        if cell.townInside then
            outline[r]=math.max(outline[r] or -math.huge,along);cityMin=math.min(cityMin,r);cityMax=math.max(cityMax,r)
        end
    end end
    assert(cityMin<=cityMax,'Waterfront needs existing town ground')
    local protected={}
    for _,door in ipairs(doors) do Geometry.Disk(door.q,door.r,1,function(q,r)
        local cell=area:Find(q,r);if cell then protected[cell.index]=true end
    end) end
    for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do protected[index]=true end end
    for _,cell in ipairs(area.cells) do
        if cell.interiorId or cell.reserved or cell.kind=='street' or cell.kind=='square' or cell.kind=='entry' then protected[cell.index]=true end
        if cell.layer>0 then local base=area:Find(cell.q,cell.r);protected[base.index]=true end
    end
    local curve={}
    local function buildCurve()
        for r=minCross,maxCross do
            local anchor=math.max(cityMin,math.min(cityMax,r))
            local edge=outline[anchor]
            if not edge then
                local distance=1;while not edge do edge=outline[anchor-distance] or outline[anchor+distance];distance=distance+1 end
            end
            curve[r]=edge-2.2+(random:Noise(r,0,7,301)-.5)*3.4
        end
        for index in pairs(protected) do local point=coordinates[index]
            if point then curve[point.cross]=math.max(curve[point.cross],point.along+.65) end
        end
        -- 保护包络推动整段岸线；限制曲线斜率，建筑外侧不会出现窄槽、陆墙或独立陆岛。
        for r=minCross+1,maxCross do curve[r]=math.max(curve[r],curve[r-1]-.7) end
        for r=maxCross-1,minCross,-1 do curve[r]=math.max(curve[r],curve[r+1]-.7) end
    end
    local function wet(cell)
        local point=coordinates[cell.index];return point and point.along>curve[point.cross]
    end
    -- 保留原街道/建筑连接。若边缘花园承担连接，整体向外推岸，不在水里留下孤立补丁。
    local waterCells,inside
    for attempt=1,8 do
        buildCurve();waterCells={};inside=0;local changed={}
        for _,cell in ipairs(area.cells) do if cell.layer==0 and wet(cell) then
            assert(not protected[cell.index],'Shoreline submerged a protected town cell')
            waterCells[#waterCells+1]=cell;if cell.townInside then inside=inside+1 end
            if not cell.blocked then cell.blocked=true;changed[#changed+1]=cell end
        end end
        local reached,distance=Geometry.Reachable(area,area.entryIndex)
        local connected=#reached==area.walkableCount-#changed
        for _,cell in ipairs(changed) do cell.blocked=false end
        if connected then break end
        assert(attempt<8,'Town shoreline failed to preserve public connectivity')
        for _,cell in ipairs(area.cells) do if not cell.blocked and not wet(cell) and not distance[cell.index] then
            local path=assert(area:FindPath(area.entryIndex,cell.index))
            for _,index in ipairs(path) do protected[index]=true end
        end end
    end
    local candidates={}
    for _,start in ipairs(area.cells) do if not start.blocked and flat(start) and not wet(start) then
        local point=coordinates[start.index];local steps=math.floor(curve[point.cross]-point.along+1e-6)
        if steps>=0 and steps<=6 then
            local land=area:Find(start.q+dq*steps,start.r+dr*steps)
            local first=area:Find(start.q+dq*(steps+1),start.r+dr*(steps+1))
            local boat=area:Find(start.q+dq*(steps+3),start.r+dr*(steps+3))
            local expansion,seen,valid={},{},land and first and boat and wet(first) and wet(boat)
            if valid then for step=0,steps do
                local center=area:Find(start.q+dq*step,start.r+dr*step)
                if not center then valid=false;break end
                Geometry.Disk(center.q,center.r,1,function(q,r)
                    local cell=area:Find(q,r)
                    if cell and not wet(cell) and not seen[cell.index] then
                        seen[cell.index]=true
                        if cell.interiorId or cell.obstacleId~=0 or area:Find(q,r,1)
                            or not cell.blocked and math.abs(cell.height-start.height)>.01 then valid=false
                        elseif cell.blocked and not protected[cell.index] then expansion[#expansion+1]=cell
                        elseif cell.blocked then valid=false end
                    end
                end)
            end end
            if valid and not protected[first.index] then
                local dry=0
                for d=1,6 do local q,r=Hex.Neighbor(land.q,land.r,d);local cell=area:Find(q,r)
                    if cell and not wet(cell) and (not cell.blocked or seen[cell.index]) then dry=dry+1 end
                end
                if dry>=3 then candidates[#candidates+1]={land=land,water=first,expansion=expansion,height=start.height,
                    score=start.height*100+steps*3+math.abs(point.cross)*.04-point.along*.01} end
            end
        end
    end end
    table.sort(candidates,function(a,b)return a.score<b.score or a.score==b.score and a.land.index<b.land.index end)
    local selected=assert(candidates[1],'Cannot connect full town waterfront: area='..area.configId..', seed='..area.seed..', direction='..direction)
    selected.cells=waterCells;selected.inside=inside
    for _,cell in ipairs(selected.expansion) do
        cell.blocked=false;cell.blocksSight=false;cell.kind='street';cell.townInside=true;cell.reserved=true
        cell.height=selected.height;cell.corners={cell.height,cell.height,cell.height,cell.height,cell.height,cell.height}
        area.walkableCount=area.walkableCount+1
    end
    local land=selected.land;local waterLevel=land.height-math.max(.25,source.landHeight-source.waterLevel)
    local waterIndices={}
    for _,cell in ipairs(selected.cells) do
        local point=coordinates[cell.index];local distance=point.along-curve[point.cross]
        local depth=math.min(3.5,.35+distance*.3+random:Noise(point.cross,point.along,5,337)*.2)
        if not cell.blocked then area.walkableCount=area.walkableCount-1 end
        cell.blocked=true;cell.blocksSight=false;cell.kind='water';cell.waterKind=source.waterKind
        cell.renderGround=false
        cell.waterLevel=waterLevel;cell.waterDepth=depth;cell.waterAssetId=source.waterAssetId
        cell.height=waterLevel-depth;cell.corners={cell.height,cell.height,cell.height,cell.height,cell.height,cell.height}
        cell.walkMask=0;cell.reserved=true;cell.stairRise=0
        waterIndices[#waterIndices+1]=cell.index
    end
    -- 陆岸保留城市原有台地；公共平地使用受邻接高差约束的低缓起伏，空白岸坡起伏更明显。
    local offsets={};local changedBank={};local bankIndices={}
    for _,cell in ipairs(area.cells) do if cell.layer==0 and not cell.waterLevel then
        local point=coordinates[cell.index];local distance=curve[point.cross]-point.along
        if distance>=0 and distance<=3.5 then
            cell.shoreBank=true;bankIndices[#bankIndices+1]=cell.index
            if not protected[cell.index] and not cell.reserved and cell.obstacleId==0 and not cell.interiorId
                and Hex.Distance(cell.q,cell.r,land.q,land.r)>3 then
                if cell.blocked then
                    cell.height=math.max(waterLevel+.18,math.max(waterLevel+.2,cell.height)+(random:Noise(point.cross,point.along,5,347)-.2)*1.8)
                    cell.corners={cell.height,cell.height,cell.height,cell.height,cell.height,cell.height}
                elseif flat(cell) then
                    local level=true
                    for _,other in ipairs(area:Neighbors(cell)) do if math.abs(other.height-cell.height)>.01 then level=false;break end end
                    if level then
                        offsets[cell.index]=random:Noise(point.cross,point.along,6,349)*1.3
                        changedBank[#changedBank+1]=cell
                    end
                end
            end
        end
    end end
    for _=1,6 do for _,cell in ipairs(changedBank) do
        local offset=offsets[cell.index]
        for _,other in ipairs(area:Neighbors(cell)) do if not other.waterLevel then offset=math.min(offset,(offsets[other.index] or 0)+row.maxEdgeRise*.8) end end
        offsets[cell.index]=offset
    end end
    for _,cell in ipairs(changedBank) do
        cell.height=cell.height+offsets[cell.index];cell.corners={cell.height,cell.height,cell.height,cell.height,cell.height,cell.height}
    end
    -- 只为新增接入格恢复真实干岸边；既有建筑门户和层间导航不重新生成。
    for _,cell in ipairs(selected.expansion) do
        cell.walkMask=0
        for d=1,6 do local q,r=Hex.Neighbor(cell.q,cell.r,d);local other=area:Find(q,r)
            cell.neighbors[d]=other and other.index or 0
            if other and not other.blocked and not other.interiorId and math.abs(cell.height-other.height)<=row.maxEdgeRise then
                link(cell,other,d);link(other,cell,opposite(d))
            end
        end
    end
    -- 建筑内部楼梯已在 TownBuildings 接好；只截断入水边，不能重建整城地形邻接。
    for _,cell in ipairs(area.cells) do if not cell.blocked then
        for d,index in ipairs(cell.neighbors) do
            local other=area.cells[index]
            if other and other.waterLevel then cell.walkMask=cell.walkMask & ~(1 << (d-1)) end
        end
    end end
    -- 前三米完好甲板在两种模型中共用。水面仍是阻挡格，甲板为独立的真实步行层。
    local deck=area:AddLayerCell(selected.water.q,selected.water.r,1,land.height)
    deck.localQ=selected.water.localQ;deck.localR=selected.water.localR
    deck.corners={deck.height,deck.height,deck.height,deck.height,deck.height,deck.height}
    deck.kind='bridge';deck.renderGround=false;deck.townInside=true;deck.deckThickness=.16
    for d=1,6 do deck.neighbors[d]=0 end
    link(land,deck,direction);link(deck,land,opposite(direction))
    land.kind='street';land.reserved=true
    local path=assert(area:FindPath(area.entryIndex,land.index))
    for _,index in ipairs(path) do local cell=area.cells[index]
        if cell.layer==0 and cell.kind=='garden' then cell.kind='street' end
    end
    local shoreNeighbors=area:Neighbors(land);local worker
    for _,cell in ipairs(shoreNeighbors) do if cell.layer==0 and not cell.interiorId then
        worker=cell;break
    end end
    assert(worker,'Dock requires a safe worker position')
    local id=#area.props+1
    local lx,_,lz=Hex.ToWorld(land.q,land.r,land.height,area.hexRadius)
    local wx,_,wz=Hex.ToWorld(selected.water.q,selected.water.r,waterLevel,area.hexRadius)
    local yaw=math.deg(math.atan(wx-lx,wz-lz))
    -- 渲染器的 prop.scale 是格径倍率；显式三轴为米制，甲板顶固定在 .5 米。
    area.props[id]={id=id,assetId=source.initialDamaged and settings.ruinedAssetId or settings.intactAssetId,
        q=land.q,r=land.r,height=land.height-.5,rotation=0,yaw=yaw,scale=1/area.hexRadius,
        scaleX=1,scaleY=1,scaleZ=1,cameraObstacle=false,cells={land.index,deck.index},dockId=source.id}
    local facility={id=#area.facilities+1,configId=definition.id,name=definition.name,kind=definition.kind,
        description=definition.description,entryIndex=land.index,approachIndex=deck.index,
        interactionRadius=definition.interactionRadius,npcTemplateId=definition.npcTemplateId,dockId=source.id}
    area.facilities[#area.facilities+1]=facility
    area.generationVersion=area.generationVersion+2
    area.waterfront={dockId=source.id,landingIndex=land.index,facilityId=facility.id,propId=id}
    area.dock={id=source.id,townId=source.townId,direction=direction,entryIndex=land.index,approachIndex=deck.index,
        workerIndex=worker.index,waterIndex=selected.water.index,deckIndex=deck.index,waterCells=waterIndices,
        internalWaterCount=selected.inside,q=land.q,r=land.r,height=land.height,yaw=yaw,
        shoreline={turn=turn,centerQ=cq,centerR=cr,minCross=minCross,maxCross=maxCross,cityMin=cityMin,cityMax=cityMax,curve=curve,bankCells=bankIndices},
        boatQ=selected.water.q+dq*2,boatR=selected.water.r+dr*2,boatHeight=waterLevel}
    doors[#doors+1]=land
end
function Waterfront.BindResidents(area)
    if not area.waterfront then return end
    for _,npc in ipairs(area.npcs) do if npc.facilityId==area.waterfront.facilityId then
        npc.dockId=area.waterfront.dockId;area.waterfront.npcId=npc.id;area.dock.workerIndex=npc.spawnIndex;return
    end end
    error('Dock facility has no worker')
end
return Waterfront

-- 已保存的 v9 世界保留初版水湾与地格身份；新世界使用 TownWaterfront 的整侧水岸。
local Hex=require('Game.Map.HexGrid')
local Geometry=require('Game.MapArea.DungeonGeometry')
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
    assert(area.source.generationVersion>=9,'Waterfront requires world generation v9')
    local settings=config:GetTable('DockSettingsTable'):Get(1)
    local definition=config:GetTable('MapAreaTownFacilityTable'):Get(settings.facilityId)
    assert(definition.kind=='dock' and definition.npcTemplateId==settings.npcTemplateId,'Invalid dock facility configuration')
    local direction=source.shoreDirection;local dq,dr=Hex.Neighbor(0,0,direction)
    local dx,_,dz=Hex.ToWorld(dq,dr,0,1);local norm=math.sqrt(dx*dx+dz*dz);dx,dz=dx/norm,dz/norm
    local cx,_,cz=Hex.ToWorld(area.width//2,area.height//2,0,1)
    local protected={}
    for _,door in ipairs(doors) do Geometry.Disk(door.q,door.r,1,function(q,r)
        local cell=area:Find(q,r);if cell then protected[cell.index]=true end
    end) end
    for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do protected[index]=true end end
    local candidates={}
    for _,cell in ipairs(area.cells) do if not cell.blocked and flat(cell) and not protected[cell.index] then
        local x,_,z=Hex.ToWorld(cell.q,cell.r,0,1);local forward=(x-cx)*dx+(z-cz)*dz
        if forward>0 then
            local outside=false
            for step=2,6 do local nextCell=area:Find(cell.q+dq*step,cell.r+dr*step)
                if nextCell and not nextCell.townInside then outside=true;break end
            end
            if outside then candidates[#candidates+1]={cell=cell,score=forward-math.abs((x-cx)*dz-(z-cz)*dx)*.2} end
        end
    end end
    table.sort(candidates,function(a,b)return a.score>b.score or a.score==b.score and a.cell.index<b.cell.index end)
    local selected
    for _,candidate in ipairs(candidates) do
        local land=candidate.cell;local waterCells,inside,valid={},0,true
        local lx,_,lz=Hex.ToWorld(land.q,land.r,0,1)
        -- 水湾沿同一世界方向通向城界；前三排确实切进原有城市地格。
        for _,cell in ipairs(area.cells) do if cell.layer==0 then
            local x,_,z=Hex.ToWorld(cell.q,cell.r,0,1)
            local forward=(x-lx)*dx+(z-lz)*dz;local across=math.abs((x-lx)*dz-(z-lz)*dx)
            local width=forward<5 and 2.3 or 4.1
            if forward>=1.5 and across<=width then
                if protected[cell.index] or cell.interiorId or cell.reserved or cell.obstacleId~=0 or area:Find(cell.q,cell.r,1)
                    or cell.townInside and not flat(cell) then valid=false;break end
                waterCells[#waterCells+1]=cell
                if cell.townInside then inside=inside+1 end
            end
        end end
        local first=area:Find(land.q+dq,land.r+dr)
        local boat=area:Find(land.q+dq*3,land.r+dr*3)
        if valid and inside>=4 and first and first.townInside and boat then
            local changed={}
            for _,cell in ipairs(waterCells) do if not cell.blocked then cell.blocked=true;changed[#changed+1]=cell end end
            local reachable=Geometry.Reachable(area,area.entryIndex)
            valid=#reachable==area.walkableCount-#changed
            for _,cell in ipairs(changed) do cell.blocked=false end
            local neighbors=area:Neighbors(land);local count=0
            for _,cell in ipairs(neighbors) do
                local inWater=false;for _,water in ipairs(waterCells) do if cell==water then inWater=true;break end end
                if not inWater and cell.layer==0 and not cell.interiorId and not protected[cell.index] then count=count+1 end
            end
            if valid and count>=3 then selected={land=land,water=first,cells=waterCells,inside=inside};break end
        end
    end
    assert(selected,'Cannot fit connected town waterfront: area='..area.configId..', seed='..area.seed..', direction='..direction)
    local land=selected.land;local waterLevel=land.height-math.max(.25,source.landHeight-source.waterLevel)
    local depth=math.max(.8,source.waterDepth);local waterIndices={}
    for _,cell in ipairs(selected.cells) do
        if not cell.blocked then area.walkableCount=area.walkableCount-1 end
        cell.blocked=true;cell.blocksSight=false;cell.kind='water';cell.waterKind=source.waterKind
        cell.waterLevel=waterLevel;cell.waterDepth=depth;cell.waterAssetId=source.waterAssetId
        cell.height=waterLevel-depth;cell.corners={cell.height,cell.height,cell.height,cell.height,cell.height,cell.height}
        cell.walkMask=0;cell.reserved=true;cell.stairRise=0
        waterIndices[#waterIndices+1]=cell.index
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
    area.generationVersion=area.generationVersion+1
    area.waterfront={dockId=source.id,landingIndex=land.index,facilityId=facility.id,propId=id}
    area.dock={id=source.id,townId=source.townId,direction=direction,entryIndex=land.index,approachIndex=deck.index,
        workerIndex=worker.index,waterIndex=selected.water.index,deckIndex=deck.index,waterCells=waterIndices,
        internalWaterCount=selected.inside,q=land.q,r=land.r,height=land.height,yaw=yaw,
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

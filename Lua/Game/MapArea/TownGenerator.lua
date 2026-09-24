-- 四层等高街、低街与可穿行街桥组成山城；联排建筑按整组占地放置。
local Hex=require('Game.Map.HexGrid')
local Geometry=require('Game.MapArea.DungeonGeometry')
local Town={}
local function shuffled(values,random)
    local result={};for i,v in ipairs(values) do result[i]=v end
    for i=#result,2,-1 do local j=random:Integer(1,i);result[i],result[j]=result[j],result[i] end
    return result
end
function Town.Validate(row)
    assert(#row.facilityIds>=1 and (#row.royalLayoutIds>0 or #row.facilityIds<=9),'Town facility count exceeds available street blocks')
    assert(#row.blockIds>0 and #row.houseLotIds>0 and #row.streetLotIds>0,'Town preset pools cannot be empty')
    assert(row.bridgeWidth%2==1 and row.rampLength>=4,'Town bridge width must be odd and ramps need sufficient run')
end
function Town.Generate(area,row,random,config)
    Town.Validate(row)
    if #row.royalLayoutIds>0 then return require('Game.MapArea.RoyalTownGenerator').Generate(area,row,random,config) end
    local lots=config:GetTable('MapAreaTownLotTable');local definitions=config:GetTable('MapAreaTownFacilityTable')
    local blocks=config:GetTable('MapAreaTownBlockTable')
    area.props={};area.corridorRadius=row.streetRadius;area.generationVersion=2
    local buildings=require('Game.MapArea.TownBuildings').New(area,config)
    local terrain=require('Game.MapArea.TownTerrain').Build(area,row,random)
    local reserved={};for _,cell in ipairs(area.cells) do if cell.reserved then reserved[cell.index]=true end end
    -- 桥头需要完整的集结空间；仅剩一条细线可达并不足以保证四人编队过桥。
    local bridgeAccess={}
    for _,index in ipairs(terrain.bridgeCells) do for _,landing in ipairs(area:Neighbors(area.cells[index])) do
        if landing.layer==0 then
            bridgeAccess[landing.index]=true
            for _,other in ipairs(area:Neighbors(landing)) do if other.layer==0 then bridgeAccess[other.index]=true end end
        end
    end end
    local entryR=row.streetRows[1]+6
    local entry=assert(terrain:Cell(math.floor(-entryR/2),entryR));area.entryIndex=entry.index
    assert(not entry.blocked and #Geometry.Reachable(area,entry.index)==area.walkableCount,'Town terrain layers are not connected')
    -- 街桥是可走层上的真实构件，不把桥下地面标成阻挡。
    local bq,br=terrain:World(-terrain.bridgeRow/2,terrain.bridgeRow)
    area.props[1]={id=1,assetId=row.bridgeAssetId,q=bq,r=br,rotation=terrain.turn,scale=1,
        scaleX=row.valleyHalfWidth*2*math.sqrt(3)*area.hexRadius,scaleY=1,
        scaleZ=(row.bridgeWidth+.33)*1.5*area.hexRadius,height=terrain.step*3,cells=terrain.bridgeCells}
    local function surface(cell,kind)
        if not cell.blocked and cell.kind~='stairs' and cell.kind~='ramp' and cell.layer==0 then
            cell.kind=kind;cell.floorAccent=kind=='square' and area.theme.plazaColor or area.theme.roadColor;cell.floorAccentWeight=.92
        end
    end
    -- 等高主街与低街先保留净空，生成建筑不再依靠事后挖路穿过住宅。
    for _,cell in ipairs(area.cells) do if cell.layer==0 and not cell.blocked then
        local u=cell.localQ+cell.localR/2
        local street=math.abs(u)<row.valleyHalfWidth
        for _,r in ipairs(row.streetRows) do if math.abs(cell.localR-r)<=row.streetRadius then street=true end end
        if street then surface(cell,'street');reserved[cell.index]=true end
    end end
    -- 广场是中层街的一个开敞节点，与低街相接；其余地方保留连续街面。
    local square,facilityIds=nil,{}
    for _,id in ipairs(row.facilityIds) do
        local definition=definitions:Get(id)
        if definition.kind=='square' then assert(not square,'Multiple town squares');square=definition
        else facilityIds[#facilityIds+1]=id end
    end
    assert(square,'Town requires a configured square')
    local center=assert(terrain:Cell(-row.streetRows[2]/2,row.streetRows[2]))
    Geometry.Disk(center.q,center.r,row.plazaRadius,function(q,r)
        local cell=area:Find(q,r);if cell then surface(cell,'square') end
    end)
    local lastPlacementFailure
    local function place(lot,q,r,rotation,allowReserved)
        local cells={};local height
        assert(#lot.footprintQ==#lot.footprintR,'Town footprint arrays differ')
        for i,dq in ipairs(lot.footprintQ) do
            local x,y=Geometry.Rotate(dq,lot.footprintR[i],rotation);local cell=area:Find(q+x,r+y)
            if not cell or cell.blocked or cell.interiorId or cell.reserved or bridgeAccess[cell.index] or not allowReserved and reserved[cell.index] then lastPlacementFailure='occupied footprint at '..(q+x)..','..(r+y);return nil end
            height=height or cell.height
            if math.abs(cell.height-height)>.01 then lastPlacementFailure='crosses terrace';return nil end
            for _,corner in ipairs(cell.corners) do if math.abs(corner-height)>.01 then lastPlacementFailure='crosses slope';return nil end end
            cells[#cells+1]=cell.index
        end
        local eq,er=Geometry.Rotate(lot.entryQ,lot.entryR,rotation);local door=area:Find(q+eq,r+er)
        if not door or door.blocked or math.abs(door.height-height)>.01 then lastPlacementFailure='invalid door';return nil end
        for _,index in ipairs(cells) do assert(index~=door.index,'Town entry is inside a footprint') end
        if not buildings:CanFit(lot,q,r,rotation,height,function(cell)return not bridgeAccess[cell.index] and not cell.reserved and (allowReserved or not reserved[cell.index])end) then lastPlacementFailure='invalid interior';return nil end
        local id=#area.props+1
        for _,index in ipairs(cells) do local cell=area.cells[index];cell.blocked=true;cell.blocksSight=true;cell.obstacleId=id;area.walkableCount=area.walkableCount-1 end
        local reachable=Geometry.Reachable(area,area.entryIndex);local seen={};for _,index in ipairs(reachable) do seen[index]=true end
        local gardens={};local cutsStreet=false
        for _,cell in ipairs(area.cells) do if not cell.blocked and not seen[cell.index] then
            if reserved[cell.index] or cell.kind~='garden' then cutsStreet=true else gardens[#gardens+1]=cell end
        end end
        if cutsStreet then
            for _,index in ipairs(cells) do local cell=area.cells[index];cell.blocked=false;cell.blocksSight=false;cell.obstacleId=0;area.walkableCount=area.walkableCount+1 end
            lastPlacementFailure='disconnects public street';return nil
        end
        -- 联排后方被挡墙封闭的小庭院属于建筑后院，不纳入公共通行面；绝不封闭道路、坡道或门前。
        for _,cell in ipairs(gardens) do cell.blocked=true;area.walkableCount=area.walkableCount-1 end
        area.props[id]={id=id,assetId=lot.assetId,q=q,r=r,rotation=rotation,scale=lot.scale,height=height,cells=cells}
        local service=buildings:Apply(lot,area.props[id],door)
        return door,service
    end
    local function facility(definition,lot,q,r,rotation,allowReserved)
        local door,service=place(lot,q,r,rotation,allowReserved)
        if not door and definition.kind~='square' then
            local lq,lr=terrain:Local(q,r);local side=lq+lr/2<0 and -1 or 1
            for _,dr in ipairs(row.facilitySlideRows) do
                for slide=0,row.lotSlideCells do
                    if dr~=0 or slide~=0 then
                        local dx,dy=Geometry.Rotate(slide*side-dr//2,dr,terrain.turn)
                        door,service=place(lot,q+dx,r+dy,rotation,allowReserved);if door then break end
                    end
                end
                if door then break end
            end
        end
        assert(door,'Town facility cannot fit its street preset: '..definition.name..' ('..tostring(lastPlacementFailure)..')')
        area.facilities[#area.facilities+1]={id=#area.facilities+1,configId=definition.id,name=definition.name,kind=definition.kind,
            description=definition.description,entryIndex=service.index,approachIndex=door.index,interactionRadius=definition.interactionRadius,npcTemplateId=definition.npcTemplateId}
        return door
    end
    local plazaEntry=facility(square,lots:Get(square.lotIds[1]),center.q,center.r,0,true)
    area.goalIndex=plazaEntry.index;area.rooms[1]={id=1,name='中层市集广场',tier=3,presetId=0,center=plazaEntry.index}
    local doors={plazaEntry};local slots={};local streetSlots={};local anchors={}
    for band,r in ipairs(row.streetRows) do for _,side in ipairs({-1,1}) do anchors[#anchors+1]={u=side*10,r=r,band=band} end end
    anchors=shuffled(anchors,random);facilityIds=shuffled(facilityIds,random)
    for b,anchor in ipairs(anchors) do
        local block=blocks:Get(row.blockIds[random:Integer(1,#row.blockIds)])
        local aq=anchor.u-anchor.r/2;local q,r=terrain:World(aq,anchor.r)
        local buildingCenter
        for i,dq in ipairs(block.slotQ) do
            local x,y=terrain:World(aq+dq,anchor.r+block.slotR[i]);local rotation=(terrain.turn+block.slotRotation[i])%6
            if i==1 and facilityIds[b] then
                local definition=definitions:Get(facilityIds[b]);local fx,fy=terrain:World(aq+block.facilityQ,anchor.r+block.facilityR)
                doors[#doors+1]=facility(definition,lots:Get(definition.lotIds[random:Integer(1,#definition.lotIds)]),fx,fy,terrain.turn,true)
                buildingCenter=area:Find(fx,fy)
            else slots[#slots+1]={q=x,r=y,rotation=rotation,side=anchor.u<0 and -1 or 1};buildingCenter=area:Find(x,y) end
        end
        area.rooms[#area.rooms+1]={id=#area.rooms+1,name='第 '..anchor.band..' 层 · '..block.name,tier=3,presetId=block.id,center=buildingCenter.index}
        for i,dq in ipairs(block.decorQ) do local x,y=terrain:World(aq+dq,anchor.r+block.decorR[i]);streetSlots[#streetSlots+1]={q=x,r=y,rotation=terrain.turn} end
    end
    local homes=0
    for _,slot in ipairs(shuffled(slots,random)) do
        if homes>=row.houseCount then break end
        local lot=lots:Get(row.houseLotIds[random:Integer(1,#row.houseLotIds)])
        assert(lot.houseUnits>0,'Residential lot has no house units')
        local door=place(lot,slot.q,slot.r,slot.rotation,true)
        -- 以预设街区为生长中心，在有限范围内为完整联排找空地；大店铺和桥头净空优先。
        local candidates={}
        if not door then Geometry.Disk(slot.q,slot.r,row.houseSearchRadius,function(q,r,dq,dr)
            candidates[#candidates+1]={q=q,r=r,distance=Hex.Distance(0,0,dq,dr)}
        end) end
        table.sort(candidates,function(a,b)return a.distance<b.distance or a.distance==b.distance and (a.r<b.r or a.r==b.r and a.q<b.q)end)
        for _,candidate in ipairs(candidates) do
            if door then break end
            door=place(lot,candidate.q,candidate.r,slot.rotation,true)
        end
        if door then homes=homes+lot.houseUnits;doors[#doors+1]=door end
    end
    assert(homes==row.houseCount,'Town presets cannot fit configured residential groups: '..homes..'/'..row.houseCount)
    -- 门前和必要坡道不摆摊；宽街两侧的小设施可以进入街道保留带，但不得断开任何层。
    local doorClear={}
    for _,door in ipairs(doors) do Geometry.Disk(door.q,door.r,1,function(q,r)local cell=area:Find(q,r);if cell then doorClear[cell.index]=true end end) end
    for _,slot in ipairs(streetSlots) do
        local lot=lots:Get(row.streetLotIds[random:Integer(1,#row.streetLotIds)]);local clear=true
        for i,dq in ipairs(lot.footprintQ) do
            local x,y=Geometry.Rotate(dq,lot.footprintR[i],slot.rotation);local cell=area:Find(slot.q+x,slot.r+y)
            if not cell or cell.reserved or doorClear[cell.index] then clear=false end
        end
        if clear then place(lot,slot.q,slot.r,slot.rotation,true) end
    end
    doors[#doors+1]=entry;entry.kind='entry'
    local candidates={}
    for _,cell in ipairs(area.cells) do if not cell.blocked and cell.layer==0 and cell.kind=='garden' and not reserved[cell.index]
        and not doorClear[cell.index] then candidates[#candidates+1]=cell end end
    local trees=0
    for _,cell in ipairs(shuffled(candidates,random)) do
        if trees>=row.treeCount then break end
        local q,r={},{ };Geometry.Disk(0,0,1,function(x,y)q[#q+1]=x;r[#r+1]=y end)
        if place({assetId=area.theme.treeAssetId,scale=area.theme.treeScale,scaleMode='grid',footprintQ=q,footprintR=r,entryQ=0,entryR=2},cell.q,cell.r,0) then trees=trees+1 end
    end
    local queue,distance=Geometry.Reachable(area,area.entryIndex)
    assert(#queue==area.walkableCount,'Town street layers must stay connected');area.goalDistance=distance[area.goalIndex]
    require('Game.MapArea.TownResidents').Populate(area,row,config,doors)
    return area
end
return Town

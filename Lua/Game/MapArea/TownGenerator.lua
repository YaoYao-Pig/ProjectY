-- 城镇由广场、六个街区预设和配置设施组合；所有建筑占地先确定，再连通门前道路。
local Hex=require('Game.Map.HexGrid')
local Geometry=require('Game.MapArea.DungeonGeometry')
local Town={}
local function shuffled(values,random)
    local result={};for i,v in ipairs(values) do result[i]=v end
    for i=#result,2,-1 do local j=random:Integer(1,i);result[i],result[j]=result[j],result[i] end
    return result
end
function Town.Validate(row)
    assert(#row.facilityIds>=1 and #row.facilityIds<=7,'Town supports a square and up to six street facilities')
    assert(#row.blockIds>0 and #row.houseLotIds>0 and #row.streetLotIds>0,'Town preset pools cannot be empty')
    assert(row.blockDistance%2==0,'Town block distance must be even')
end
function Town.Generate(area,row,random,config)
    Town.Validate(row)
    local lots=config:GetTable('MapAreaTownLotTable');local definitions=config:GetTable('MapAreaTownFacilityTable')
    local blocks=config:GetTable('MapAreaTownBlockTable');local npcTemplates=config:GetTable('MapAreaTownNpcTable')
    area.props={};area.corridorRadius=row.streetRadius;area.generationVersion=1
    local cq,cr=area.width//2,area.height//2
    local center=assert(area:Find(cq,cr));local radius=row.blockDistance+10
    assert(cq>radius and cr>radius and area.width-cq>radius and area.height-cr>radius,'Town dimensions are too small for configured blocks')
    for _,cell in ipairs(area.cells) do
        cell.kind='garden';cell.blocksSight=false
        cell.blocked=Hex.Distance(cq,cr,cell.q,cell.r)>radius
        if not cell.blocked then area.walkableCount=area.walkableCount+1 end
    end
    local function surface(q,r,size,kind)
        Geometry.Disk(q,r,size,function(x,y)
            local cell=area:Find(x,y)
            if cell and not cell.blocked then
                cell.kind=kind;cell.floorAccent=kind=='square' and area.theme.plazaColor or area.theme.roadColor
                cell.floorAccentWeight=.9
            end
        end)
    end
    surface(cq,cr,row.plazaRadius,'square')
    local function place(lot,q,r,rotation)
        assert(#lot.footprintQ==#lot.footprintR and #lot.footprintQ>0,'Invalid town lot footprint')
        local cells={}
        for i,dq in ipairs(lot.footprintQ) do
            local x,y=Geometry.Rotate(dq,lot.footprintR[i],rotation);local cell=area:Find(q+x,r+y)
            if not cell or cell.blocked then return nil end
            cells[#cells+1]=cell.index
        end
        local eq,er=Geometry.Rotate(lot.entryQ,lot.entryR,rotation)
        local entry=area:Find(q+eq,r+er)
        if not entry or entry.blocked then return nil end
        for _,index in ipairs(cells) do assert(index~=entry.index,'Town door is inside blocking footprint') end
        local id=#area.props+1
        for _,index in ipairs(cells) do
            local cell=area.cells[index];cell.blocked=true;cell.blocksSight=true;cell.obstacleId=id
            area.walkableCount=area.walkableCount-1
        end
        -- 围墙式组合与外围树木也不能截出孤立地格；可选预设冲突时放弃该槽。
        if #Geometry.Reachable(area,entry.index)~=area.walkableCount then
            for _,index in ipairs(cells) do
                local cell=area.cells[index];cell.blocked=false;cell.blocksSight=false;cell.obstacleId=0
                area.walkableCount=area.walkableCount+1
            end
            return nil
        end
        config:GetTable('MapAssetTable'):Get(lot.assetId)
        area.props[id]={id=id,assetId=lot.assetId,q=q,r=r,rotation=rotation,scale=lot.scale,cells=cells}
        return entry
    end
    local square,facilityIds,seen=nil,{},{}
    for _,id in ipairs(row.facilityIds) do
        assert(not seen[id],'Duplicate town facility');seen[id]=true
        if definitions:Get(id).kind=='square' then assert(not square,'Multiple town squares');square=definitions:Get(id)
        else facilityIds[#facilityIds+1]=id end
    end
    assert(square,'Town requires a configured central square')
    local function facility(definition,lot,q,r,rotation)
        local entry=assert(place(lot,q,r,rotation),'Town facility overlaps another preset lot: '..definition.name)
        area.facilities[#area.facilities+1]={id=#area.facilities+1,configId=definition.id,name=definition.name,kind=definition.kind,
            description=definition.description,entryIndex=entry.index,interactionRadius=definition.interactionRadius,npcTemplateId=definition.npcTemplateId}
        return entry
    end
    local plazaEntry=facility(square,lots:Get(square.lotIds[1]),cq,cr,0)
    area.rooms[1]={id=1,name='中心广场',tier=3,presetId=0,center=plazaEntry.index}
    local doors={plazaEntry};local homeSlots={};local streetSlots={}
    facilityIds=shuffled(facilityIds,random)
    local turns=shuffled({0,1,2,3,4,5},random)
    for b,turn in ipairs(turns) do
        local block=blocks:Get(row.blockIds[random:Integer(1,#row.blockIds)])
        assert(#block.slotQ==#block.slotR and #block.slotQ==#block.slotRotation and #block.decorQ==#block.decorR,'Town block arrays differ')
        local bq,br=Geometry.Rotate(row.blockDistance//2,-row.blockDistance,turn);bq=bq+cq;br=br+cr
        for i,dq in ipairs(block.slotQ) do
            local x,y=Geometry.Rotate(dq,block.slotR[i],turn)
            local q,r,rotation=bq+x,br+y,(turn+block.slotRotation[i])%6
            if i==1 and facilityIds[b] then
                local definition=definitions:Get(facilityIds[b])
                doors[#doors+1]=facility(definition,lots:Get(definition.lotIds[random:Integer(1,#definition.lotIds)]),q,r,rotation)
            else homeSlots[#homeSlots+1]={q=q,r=r,rotation=rotation} end
        end
        area.rooms[#area.rooms+1]={id=#area.rooms+1,name=block.name,tier=3,presetId=block.id,center=assert(area:Find(bq,br)).index}
        for i,dq in ipairs(block.decorQ) do
            local x,y=Geometry.Rotate(dq,block.decorR[i],turn);streetSlots[#streetSlots+1]={q=bq+x,r=br+y,rotation=turn}
        end
    end
    local homes=0
    for _,slot in ipairs(shuffled(homeSlots,random)) do
        if homes>=row.houseCount then break end
        local entry=place(lots:Get(row.houseLotIds[random:Integer(1,#row.houseLotIds)]),slot.q,slot.r,slot.rotation)
        if entry then homes=homes+1;doors[#doors+1]=entry end
    end
    assert(homes==row.houseCount,'Town presets cannot fit configured home count')
    -- 所有门前保留净空，街区陈设不得盖住设施入口。
    local reserved={}
    for _,door in ipairs(doors) do Geometry.Disk(door.q,door.r,1,function(q,r)
        local cell=area:Find(q,r);if cell then reserved[cell.index]=true end
    end) end
    for _,slot in ipairs(streetSlots) do
        local lot=lots:Get(row.streetLotIds[random:Integer(1,#row.streetLotIds)]);local clear=true
        for i,dq in ipairs(lot.footprintQ) do
            local x,y=Geometry.Rotate(dq,lot.footprintR[i],slot.rotation);local cell=area:Find(slot.q+x,slot.r+y)
            if not cell or reserved[cell.index] then clear=false end
        end
        if clear then place(lot,slot.q,slot.r,slot.rotation) end
    end
    local eq,er=Geometry.Rotate(0,-radius+2,random:Integer(0,5));local entry=assert(area:Find(cq+eq,cr+er))
    assert(not entry.blocked,'Town entrance overlaps buildings')
    area.entryIndex=entry.index;doors[#doors+1]=entry
    for _,door in ipairs(doors) do
        local path=assert(area:FindPath(plazaEntry.index,door.index),'Town entrance has no connected street')
        for _,index in ipairs(path) do local cell=area.cells[index];surface(cell.q,cell.r,row.streetRadius,'street') end
    end
    surface(cq,cr,row.plazaRadius,'square')
    area.cells[entry.index].kind='entry';area.goalIndex=plazaEntry.index
    -- 景观树只放外围庭院，不挤占街道或门前；每棵使用完整七格足迹。
    local trees=0;local treeCandidates={}
    for _,cell in ipairs(area.cells) do if not cell.blocked and cell.kind=='garden' and Hex.Distance(cq,cr,cell.q,cell.r)>=row.blockDistance+5 then treeCandidates[#treeCandidates+1]=cell end end
    for _,cell in ipairs(shuffled(treeCandidates,random)) do
        if trees>=row.treeCount then break end
        local q,r={},{};local clear=true
        Geometry.Disk(cell.q,cell.r,1,function(x,y,dx,dy)
            local other=area:Find(x,y);if not other or other.blocked or other.kind~='garden' or reserved[other.index] then clear=false end
            q[#q+1]=dx;r[#r+1]=dy
        end)
        if clear and place({assetId=area.theme.treeAssetId,scale=area.theme.treeScale,footprintQ=q,footprintR=r,entryQ=0,entryR=2},cell.q,cell.r,0) then trees=trees+1 end
    end
    local queue,distance=Geometry.Reachable(area,area.entryIndex)
    assert(#queue==area.walkableCount,'Town lots must preserve a connected walkable area')
    area.goalDistance=distance[area.goalIndex]
    local occupied={}
    local function addNpc(templateId,index,route)
        assert(not occupied[index],'NPC spawn overlap');occupied[index]=true
        local template=npcTemplates:Get(templateId)
        area.npcs[#area.npcs+1]={id=#area.npcs+1,templateId=templateId,spawnIndex=index,route=route,stepSeconds=template.stepSeconds,idleSeconds=template.idleSeconds}
    end
    for _,site in ipairs(area.facilities) do
        local door=area.cells[site.entryIndex];local found
        for _,cell in ipairs(area:Neighbors(door)) do if not occupied[cell.index] and cell.index~=entry.index then found=cell;break end end
        assert(found,'No service NPC space');addNpc(site.npcTemplateId,found.index,{})
    end
    for i=1,row.residentCount do
        local start=doors[(i-1)%#doors+1];local target=doors[(i+3)%#doors+1]
        local spawn
        for _,cell in ipairs(area:Neighbors(start)) do if not occupied[cell.index] and cell.index~=entry.index then spawn=cell;break end end
        assert(spawn,'No resident spawn space')
        local out=assert(area:FindPath(spawn.index,target.index));local back=assert(area:FindPath(target.index,spawn.index))
        local route={};for _,index in ipairs(out) do route[#route+1]=index end;for _,index in ipairs(back) do route[#route+1]=index end
        addNpc(row.residentTemplateIds[(i-1)%#row.residentTemplateIds+1],spawn.index,route)
    end
    return area
end
return Town

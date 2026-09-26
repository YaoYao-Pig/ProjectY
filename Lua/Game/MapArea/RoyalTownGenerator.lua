-- 王城由地形、功能片区、街网与临街地块逐步生成；正式宫苑保留建筑内部的轴线。
local Geometry=require('Game.MapArea.DungeonGeometry')
local Royal={}
function Royal.Generate(area,row,random,config)
    local recipe=config:GetTable('MapAreaRoyalTable'):Get(row.royalLayoutIds[random:Integer(1,#row.royalLayoutIds)])
    local placements=config:GetTable('MapAreaRoyalPlacementTable');local lots=config:GetTable('MapAreaTownLotTable')
    local definitions=config:GetTable('MapAreaTownFacilityTable')
    area.props={};area.generationVersion=4;area.corridorRadius=row.streetRadius
    local terrain=require('Game.MapArea.RoyalTownTerrain').Build(area,row,recipe,random,config)
    local gate
    for _,id in ipairs(recipe.districtIds) do if terrain.districts[id].role=='gate' then assert(not gate,'Royal recipe has multiple gates');gate=terrain.districts[id] end end
    assert(gate and recipe.entryOffsetR%2==0,'Royal entry requires one gate district and an even offset')
    local entry=assert(terrain:Cell(gate.q-recipe.entryOffsetR/2,gate.r+recipe.entryOffsetR))
    assert(not entry.blocked,'Royal entry is outside the city');area.entryIndex=entry.index;entry.kind='entry'
    local reachable,terrainDistance=Geometry.Reachable(area,entry.index)
    if #reachable~=area.walkableCount then
        local missing={}
        for _,cell in ipairs(area.cells) do if not cell.blocked and not terrainDistance[cell.index] then
            missing[#missing+1]=cell.localQ..','..cell.localR..':'..cell.kind..'/'..cell.height
        end end
        error('Royal terrain is disconnected; seed='..area.seed..' turn='..terrain.turn..' missing='..table.concat(missing,';'))
    end
    local buildings=require('Game.MapArea.TownBuildings').New(area,config)
    local planner=require('Game.MapArea.RoyalTownPlanner').New(area,terrain,recipe,random,buildings);planner:Protect(entry)
    local doors,nodes={entry},{entry};local expected={};for _,id in ipairs(row.facilityIds) do expected[id]=true end
    local intentions={};local homes=0
    for _,id in ipairs(recipe.placementIds) do
        local preset=placements:Get(id);local definition
        if preset.facilityId>0 then
            assert(preset.required,'Royal functional facilities must be mandatory plots')
            assert(expected[preset.facilityId],'Royal facility placement not declared or duplicated')
            definition=definitions:Get(preset.facilityId);expected[preset.facilityId]=nil
        end
        local pool=definition and definition.lotIds or preset.lotIds;assert(#pool>0,'Royal placement has no configured lot')
        intentions[#intentions+1]={preset=preset,definition=definition,lot=lots:Get(pool[random:Integer(1,#pool)])}
    end
    local function place(intent)
        local preset,definition,lot=intent.preset,intent.definition,intent.lot
        local value=planner:Place(preset,lot);if not value then return end
        if definition then
            area.facilities[#area.facilities+1]={id=#area.facilities+1,configId=definition.id,name=definition.name,kind=definition.kind,
                description=definition.description,entryIndex=value.service.index,approachIndex=value.door.index,interactionRadius=definition.interactionRadius,npcTemplateId=definition.npcTemplateId}
            area.rooms[#area.rooms+1]={id=#area.rooms+1,name=definition.name,tier=3,presetId=preset.id,center=value.door.index}
            doors[#doors+1]=value.door;nodes[#nodes+1]=value.door
            if definition.kind=='palace' then area.goalIndex=value.service.index end
        elseif preset.role=='landmark' then nodes[#nodes+1]=value.door
        elseif lot.houseUnits>0 then homes=homes+lot.houseUnits;doors[#doors+1]=value.door end
    end
    -- 中庭固定陈设先占地，避免主路先穿过喷泉；可选花园则等街区长好后再寻找余地。
    for _,intent in ipairs(intentions) do if intent.preset.role=='landmark' or intent.preset.required and intent.preset.role=='garden' then place(intent) end end
    for _,intent in ipairs(intentions) do if intent.preset.role=='facility' then place(intent) end end
    local deck=assert(terrain:Cell(terrain.valleyU-recipe.bridgeR/2,recipe.bridgeR,1))
    nodes[#nodes+1]=deck;nodes[#nodes+1]=assert(area:Find(deck.q,deck.r))
    -- 居住片区先留一个小型公共节点，再沿相连的街巷生长，避免所有房屋挤在外围。
    for _,id in ipairs(recipe.districtIds) do
        local district=terrain.districts[id]
        if district.role=='residential' then
            local best,cost
            Geometry.Disk(district.q,district.r,district.searchRadius,function(q,r,dq,dr)
                local cell=terrain:Cell(q,r)
                if cell and not cell.blocked and not cell.interiorId then
                    local value=math.max(math.abs(dq),math.abs(dr),math.abs(dq+dr))
                    if not cost or value<cost then best,cost=cell,value end
                end
            end)
            assert(best,'Royal residential district lacks public space');planner:Protect(best);nodes[#nodes+1]=best
        end
    end
    planner:Network(nodes)
    for _,intent in ipairs(intentions) do if intent.definition then
        for _,facility in ipairs(area.facilities) do if facility.configId==intent.definition.id then
            planner:Paint({area.cells[facility.approachIndex]},terrain.districts[intent.preset.districtId].roadRadius,'square')
        end end
    end end
    for _,intent in ipairs(intentions) do if intent.preset.role=='house' then place(intent) end end
    for _,intent in ipairs(intentions) do if intent.preset.role=='detail' or intent.preset.role=='garden' and not intent.preset.required then place(intent) end end
    assert(next(expected)==nil and homes==row.houseCount,'Royal recipe does not match facilities or house count')
    local function ornament(asset,q,r,height,x,y,z,cells)
        local worldQ,worldR=terrain:World(q,r);local id=#area.props+1
        area.props[id]={id=id,assetId=asset,q=worldQ,r=worldR,rotation=terrain.turn,scale=1,scaleX=x,scaleY=y,scaleZ=z,height=height,cells=cells}
    end
    ornament(recipe.bridgeAssetId,terrain.valleyU-recipe.bridgeR/2,recipe.bridgeR,terrain.step,row.valleyHalfWidth*2*math.sqrt(3)*area.hexRadius,1,
        (row.bridgeWidth+.33)*1.5*area.hexRadius,terrain.bridgeCells)
    -- 挡墙沿弯曲的等高线分段布置。坡道、街口、地块和公众通路都优先于装饰。
    for band in ipairs(recipe.boundaryR) do
        for u=-recipe.halfWidth+recipe.railingSpan,recipe.halfWidth-recipe.railingSpan,recipe.railingSpan do
            local r=math.ceil(terrain:Boundary(band,u))-1;local q=math.floor(u-r/2);local cells={};local clear=true
            for offset=-(recipe.railingSpan//2),recipe.railingSpan//2 do
                local cell=terrain:Cell(q+offset,r)
                if not cell or cell.blocked or cell.reserved or planner.protected[cell.index] or math.abs(cell.height-band*terrain.step)>.01 then clear=false;break end
                for _,h in ipairs(cell.corners) do if math.abs(h-cell.height)>.01 then clear=false end end
                cells[#cells+1]=cell.index
            end
            if clear and planner:TryBlock(cells) then
                for _,index in ipairs(cells) do area.cells[index].obstacleId=#area.props+1 end
                area.walkableCount=area.walkableCount-#cells
                local width=(recipe.railingSpan-.3)*math.sqrt(3)*area.hexRadius
                ornament(recipe.railingAssetId,q,r,band*terrain.step,width,1,1,cells)
                ornament(recipe.retainingAssetId,q,r,(band-1)*terrain.step,width,terrain.step/3.2,1,cells)
            end
        end
    end
    require('Game.MapArea.TownDressing').Apply(area,row,random,config,doors)
    local distance;reachable,distance=Geometry.Reachable(area,entry.index)
    assert(#reachable==area.walkableCount,'Royal public space disconnected after planning')
    for _,door in ipairs(doors) do assert(distance[door.index],'Royal entrance is disconnected') end
    area.goalDistance=assert(distance[area.goalIndex]);require('Game.MapArea.TownResidents').Populate(area,row,config,doors)
    return area
end
return Royal

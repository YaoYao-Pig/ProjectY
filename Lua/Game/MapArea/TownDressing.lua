-- 街边陈设占据真实地面格：避开门前、坡道、室内和桥面，逐件检查道路连通。
local G=require('Game.MapArea.DungeonGeometry')
local Hex=require('Game.Map.HexGrid')
local Dressing={}
function Dressing.Apply(area,town,random,config,doors,buildings)
    local profile=config:GetTable('MapAreaTownDressingTable'):Get(town.dressingProfileId)
    local definitions=config:GetTable('MapAreaPropTable');local clear,distance,queue={},{},{}
    assert(buildings and buildings.area==area,'Town dressing requires the shared building builder')
    local lots=config:GetTable('MapAreaTownLotTable');local knownDoors={}
    for _,door in ipairs(doors) do knownDoors[door.index]=true end
    for _,room in ipairs(area.interiors) do for _,index in ipairs(room.doorIndices) do
        if not knownDoors[index] then doors[#doors+1]=area.cells[index];knownDoors[index]=true end
    end end
    local function protect(door) G.Disk(door.q,door.r,1,function(q,r)
        local cell=area:Find(q,r);if cell then clear[cell.index]=true end
    end) end
    for _,door in ipairs(doors) do protect(door) end
    clear[area.entryIndex]=true;clear[area.goalIndex]=true
    for _,cell in ipairs(area.cells) do
        if cell.layer==0 and (cell.kind=='street' or cell.obstacleId>0) then distance[cell.index]=0;queue[#queue+1]=cell end
    end
    local head=1
    while head<=#queue do
        local cell=queue[head];head=head+1
        if distance[cell.index]<profile.edgeDistance then for direction=1,6 do
            local q,r=Hex.Neighbor(cell.q,cell.r,direction);local nextCell=area:Find(q,r)
            if nextCell and distance[nextCell.index]==nil then distance[nextCell.index]=distance[cell.index]+1;queue[#queue+1]=nextCell end
        end end
    end
    local candidates,placed={},{}
    local function available(cell,height)
        if not cell or cell.layer~=0 or cell.blocked or cell.reserved or cell.interiorId or clear[cell.index]
            or cell.kind~='garden' or not cell.townInside or math.abs(cell.height-height)>.01 then return false end
        for _,h in ipairs(cell.corners) do if math.abs(h-height)>.01 then return false end end
        return true
    end
    for _,cell in ipairs(area.cells) do if distance[cell.index] and available(cell,cell.height) then candidates[#candidates+1]=cell end end
    local scores={};for _,cell in ipairs(candidates) do scores[cell.index]=random:Noise(cell.q,cell.r,1,25811) end
    table.sort(candidates,function(a,b)return scores[a.index]<scores[b.index] or scores[a.index]==scores[b.index] and a.index<b.index end)
    for attempt=1,profile.count do
        local row=definitions:Get(profile.propIds[(attempt-1)%#profile.propIds+1])
        local lot=row.buildingLotId~=0 and lots:Get(row.buildingLotId) or nil
        if lot then assert(lot.assetId==row.assetId and lot.scale==row.scale and lot.scaleMode==row.scaleMode,'Dressing building visual must match its lot') end
        local footprint=lot or row
        local rotation=math.floor(random:Noise(attempt,0,1,25831)*6)
        for _,cell in ipairs(candidates) do
            local cells,valid={},available(cell,cell.height)
            for _,other in ipairs(placed) do if Hex.Distance(cell.q,cell.r,other.q,other.r)<profile.spacing then valid=false end end
            if valid then for i,dq in ipairs(footprint.footprintQ) do
                local q,r=G.Rotate(dq,footprint.footprintR[i],rotation);local covered=area:Find(cell.q+q,cell.r+r)
                if not available(covered,cell.height) then valid=false;break end
                cells[#cells+1]=covered
            end end
            local entries
            if valid and lot then
                valid=buildings:CanFit(lot,cell.q,cell.r,rotation,cell.height,function(floor)return available(floor,cell.height) end)
                if valid then
                    entries=assert(buildings:Doors(lot,cell.q,cell.r,rotation))
                    for _,door in ipairs(entries) do if clear[door.index] or door.reserved or door.interiorId then valid=false end end
                end
            end
            if valid then
                for _,covered in ipairs(cells) do covered.blocked=true end
                local reachable,connected
                if lot then local distance;reachable,distance,connected=buildings:Reachable(lot,cell.q,cell.r,rotation)
                else reachable=G.Reachable(area,area.entryIndex);connected=true end
                if connected and #reachable==area.walkableCount-#cells then
                    local prop={id=#area.props+1,configId=row.id,assetId=row.assetId,cellIndex=cell.index,q=cell.q,r=cell.r,
                        rotation=rotation,scale=row.scale,height=cell.height,cells={}}
                    if row.scaleMode=='meters' then prop.scaleX=row.scale;prop.scaleY=row.scale;prop.scaleZ=row.scale end
                    for _,covered in ipairs(cells) do covered.blocksSight=row.blocksSight;covered.obstacleId=prop.id;prop.cells[#prop.cells+1]=covered.index end
                    area.walkableCount=area.walkableCount-#cells;area.props[prop.id]=prop
                    if lot then
                        buildings:Apply(lot,prop,entries[1])
                        for _,door in ipairs(entries) do
                            protect(door)
                            if not knownDoors[door.index] then doors[#doors+1]=door;knownDoors[door.index]=true end
                        end
                    end
                    placed[#placed+1]=cell;break
                end
                for _,covered in ipairs(cells) do covered.blocked=false end
            end
        end
    end
end
return Dressing

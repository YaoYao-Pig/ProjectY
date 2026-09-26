-- 街边陈设占据真实地面格：避开门前、坡道、室内和桥面，逐件检查道路连通。
local G=require('Game.MapArea.DungeonGeometry')
local Hex=require('Game.Map.HexGrid')
local Dressing={}
function Dressing.Apply(area,town,random,config,doors)
    local profile=config:GetTable('MapAreaTownDressingTable'):Get(town.dressingProfileId)
    local definitions=config:GetTable('MapAreaPropTable');local clear,distance,queue={},{},{}
    for _,door in ipairs(doors) do G.Disk(door.q,door.r,1,function(q,r)
        local cell=area:Find(q,r);if cell then clear[cell.index]=true end
    end) end
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
        local rotation=math.floor(random:Noise(attempt,0,1,25831)*6)
        for _,cell in ipairs(candidates) do
            local cells,valid={},available(cell,cell.height)
            for _,other in ipairs(placed) do if Hex.Distance(cell.q,cell.r,other.q,other.r)<profile.spacing then valid=false end end
            if valid then for i,dq in ipairs(row.footprintQ) do
                local q,r=G.Rotate(dq,row.footprintR[i],rotation);local covered=area:Find(cell.q+q,cell.r+r)
                if not available(covered,cell.height) then valid=false;break end
                cells[#cells+1]=covered
            end end
            if valid then
                for _,covered in ipairs(cells) do covered.blocked=true end
                local reachable=G.Reachable(area,area.entryIndex)
                if #reachable==area.walkableCount-#cells then
                    local prop={id=#area.props+1,configId=row.id,assetId=row.assetId,cellIndex=cell.index,q=cell.q,r=cell.r,
                        rotation=rotation,scale=row.scale,height=cell.height,cells={}}
                    if row.scaleMode=='meters' then prop.scaleX=row.scale;prop.scaleY=row.scale;prop.scaleZ=row.scale end
                    for _,covered in ipairs(cells) do covered.blocksSight=row.blocksSight;covered.obstacleId=prop.id;prop.cells[#prop.cells+1]=covered.index end
                    area.walkableCount=area.walkableCount-#cells;area.props[prop.id]=prop;placed[#placed+1]=cell;break
                end
                for _,covered in ipairs(cells) do covered.blocked=false end
            end
        end
    end
end
return Dressing

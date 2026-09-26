-- 物件占地与显示实例同源；固定陈设不随机移位，随机陈设避开战斗区和宽通道。
local G=require('Game.MapArea.DungeonGeometry')
local Props={}
local function footprint(area,room,row,q,r,rotation)
    local cells,valid={},true
    assert(#row.footprintQ>0 and #row.footprintQ==#row.footprintR,'Invalid prop footprint: '..row.id)
    for i,dq in ipairs(row.footprintQ) do
        local x,z=G.Rotate(dq,row.footprintR[i],rotation)
        local cell=area:Find(q+x,r+z)
        if not cell or cell.blocked or cell.reserved or cell.roomId~=room.id then valid=false
        else cells[#cells+1]=cell end
    end
    return valid and cells or nil
end
local function place(area,room,row,q,r,rotation,cells)
    local prop={id=#area.props+1,configId=row.id,assetId=row.assetId,cellIndex=area:Find(q,r).index,
        q=q,r=r,rotation=rotation,scale=row.scale,roomId=room.id,cells={}}
    if row.scaleMode=='meters' then prop.scaleX=row.scale;prop.scaleY=row.scale;prop.scaleZ=row.scale end
    for _,cell in ipairs(cells) do
        cell.blocked=true;cell.blocksSight=row.blocksSight;cell.obstacleId=prop.id
        prop.cells[#prop.cells+1]=cell.index;area.walkableCount=area.walkableCount-1
    end
    area.props[prop.id]=prop
    return prop
end
function Props.Fixed(area,config)
    local rows=config:GetTable('MapAreaRoomPlacementTable'):All();local props=config:GetTable('MapAreaPropTable')
    -- 配表入口一次检查占地唯一性，避免重复坐标重复扣减可走格数。
    for _,prop in ipairs(props:All()) do
        local seen={}
        assert(#prop.footprintQ>0 and #prop.footprintQ==#prop.footprintR,'Invalid prop footprint: '..prop.id)
        for i,q in ipairs(prop.footprintQ) do
            local key=q..':'..prop.footprintR[i]
            assert(not seen[key],'Duplicate prop footprint coordinate: '..prop.id);seen[key]=true
        end
        assert(seen['0:0'],'Prop footprint must include its origin: '..prop.id)
    end
    for _,room in ipairs(area.rooms) do
        if room.tier==3 then
            for _,placement in ipairs(rows) do
                if placement.presetId==room.presetId then
                    local dq,dr=G.Rotate(placement.q,placement.r,room.rotation)
                    local q,r=room.q+dq,room.r+dr;local prop=props:Get(placement.propId)
                    local rotation=(room.rotation+placement.rotation)%6
                    local cells=assert(footprint(area,room,prop,q,r,rotation),'Preset prop overlaps a wall, combat area or another prop: '..placement.id)
                    place(area,room,prop,q,r,rotation,cells)
                end
            end
        end
    end
end
function Props.Scatter(area,random,config)
    local props=config:GetTable('MapAreaPropTable')
    for _,room in ipairs(area.rooms) do
        if room.tier==2 then
            local candidates,wallDistance={},{}
            local floorCount=0
            for _,cell in ipairs(area.cells) do
                if cell.roomId==room.id and cell.kind~='wall' then
                    floorCount=floorCount+1
                    if not cell.blocked and not cell.reserved then
                        candidates[#candidates+1]=cell
                        local nearest=room.radius
                        G.Disk(cell.q,cell.r,5,function(q,r,dq,dr)
                            local other=area:Find(q,r)
                            if not other or other.kind=='wall' then nearest=math.min(nearest,math.max(math.abs(dq),math.abs(dr),math.abs(dq+dr))) end
                        end)
                        wallDistance[cell.index]=nearest
                    end
                end
            end
            local pool={};for _,id in ipairs(room.style.propIds) do pool[#pool+1]=props:Get(id) end
            -- 先放成片设施，再补小件；同一房间的设施沿建筑轴布置，天然物件采用自由朝向。
            table.sort(pool,function(a,b) return #a.footprintQ>#b.footprintQ or #a.footprintQ==#b.footprintQ and a.id<b.id end)
            local occupied=0
            for attempt=1,room.style.propCount do
                if occupied>=floorCount*room.style.propCoverage then break end
                local row=pool[(attempt-1)%#pool+1]
                assert(row.placement=='wall' or row.placement=='aligned' or row.placement=='island','Unknown prop placement mode')
                local rotation=row.placement=='island' and random:Integer(0,5) or room.rotation
                local scores={}
                for _,cell in ipairs(candidates) do
                    scores[cell.index]=(row.placement=='island' and 0 or wallDistance[cell.index])+
                        random:Noise(cell.q,cell.r,5,room.id*971+attempt*71)*5
                end
                table.sort(candidates,function(a,b) return scores[a.index]<scores[b.index] or scores[a.index]==scores[b.index] and a.index<b.index end)
                for _,cell in ipairs(candidates) do
                    local cells=footprint(area,room,row,cell.q,cell.r,rotation)
                    if cells then
                        local prop=place(area,room,row,cell.q,cell.r,rotation,cells)
                        local reachable=G.Reachable(area,area.entryIndex)
                        if #reachable==area.walkableCount then occupied=occupied+#cells;break
                        else
                            -- 装饰不能切断任何地面；本次候选不满足契约便原样回滚。
                            area.props[prop.id]=nil
                            for _,covered in ipairs(cells) do covered.blocked=false;covered.blocksSight=false;covered.obstacleId=0;area.walkableCount=area.walkableCount+1 end
                        end
                    end
                end
            end
        end
    end
end
function Props.Dress(area,dungeon,random,config)
    local definitions=config:GetTable('MapAreaPropTable')
    for _,room in ipairs(area.rooms) do
        local style=room.preset or room.style
        local ids=style and style.dressingPropIds or dungeon.basicDressingIds
        local count=style and style.dressingCount or dungeon.basicDressingCount
        local candidates,scores={},{}
        for _,cell in ipairs(area.cells) do
            if cell.roomId==room.id and not cell.blocked and not cell.reserved then
                local wall=3
                G.Disk(cell.q,cell.r,3,function(q,r,dq,dr)
                    local other=area:Find(q,r)
                    if not other or other.kind=='wall' then wall=math.min(wall,math.max(math.abs(dq),math.abs(dr),math.abs(dq+dr))) end
                end)
                scores[cell.index]=wall+random:Noise(cell.q,cell.r,2,9311+room.id)*2
                candidates[#candidates+1]=cell
            end
        end
        table.sort(candidates,function(a,b)return scores[a.index]<scores[b.index] or scores[a.index]==scores[b.index] and a.index<b.index end)
        -- 独立的追加预算让小型遗物与旧有大型功能设施并存，不挤占中央战斗区。
        local offset=math.floor(random:Noise(room.q,room.r,1,9337)*#ids)
        for attempt=1,count do
            local row=definitions:Get(ids[(attempt+offset-1)%#ids+1])
            local rotation=row.placement=='island' and (attempt+room.id)%6 or room.rotation
            for _,cell in ipairs(candidates) do
                local cells=footprint(area,room,row,cell.q,cell.r,rotation)
                if cells then
                    local prop=place(area,room,row,cell.q,cell.r,rotation,cells)
                    if #G.Reachable(area,area.entryIndex)==area.walkableCount then break end
                    area.props[prop.id]=nil
                    for _,covered in ipairs(cells) do covered.blocked=false;covered.blocksSight=false;covered.obstacleId=0;area.walkableCount=area.walkableCount+1 end
                end
            end
        end
    end
end
return Props

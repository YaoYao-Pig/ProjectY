-- 码头只是静态岸线布局；修复、威胁和船只状态由旅行数据持有。
local Hex=require('Game.Map.HexGrid')
local Random=require('Game.Map.SeededRandom')
local Docks={}
local function navigable(cell,row)
    return cell and cell.waterLevel and cell.waterDepth>=row.minWaterDepth and not cell.worldTravelBlocked
end
local function shoreDirection(town,water)
    local x,_,z=Hex.ToWorld(water.q-town.center.q,water.r-town.center.r,0,1)
    local best,value=1,-math.huge
    for direction=1,6 do
        local q,r=Hex.Neighbor(0,0,direction);local dx,_,dz=Hex.ToWorld(q,r,0,1)
        local dot=x*dx+z*dz;if dot>value then best,value=direction,dot end
    end
    return best
end
function Docks.Build(map,config)
    assert(map.generationVersion>=9,'Docks require map generation v9')
    local row=config:GetTable('DockSettingsTable'):Get(1)
    local maxStep=config:GetTable('WorldTravelTable'):Get(1).maxHeightStep
    assert(row.maxTownDistance>=1 and row.maxTownDistance==math.floor(row.maxTownDistance),'Invalid dock town distance')
    assert(row.minWaterDepth>0 and row.maxWaterStep>=0 and row.maxBankRise>=0,'Invalid dock water limits')
    assert(row.damagedChance>=0 and row.damagedChance<=100 and row.threatChance>=0 and row.threatChance<=100,'Invalid dock state chance')
    local random=Random((map.seed ~ 0x6d2b79f5) & 0xffffffff)
    local occupied={}
    for _,town in ipairs(map.towns) do if town.role=='settlement' then
        local queue,previous,distances,head={town.center},{[town.center]=false},{[town.center]=0},1
        local best,bestScore
        while head<=#queue do
            local land=queue[head];head=head+1
            for direction=1,6 do
                local q,r=Hex.Neighbor(land.q,land.r,direction);local water=map.cellsByKey[Hex.Key(q,r)]
                if not occupied[land] and not land.buildingId and not land.wonderId and navigable(water,row)
                    and not occupied[water] and land.height>=water.waterLevel-.05
                    and land.height-water.waterLevel<=row.maxBankRise then
                    local continuation=false
                    for nextDirection=1,6 do
                        local nq,nr=Hex.Neighbor(q,r,nextDirection);local nextCell=map.cellsByKey[Hex.Key(nq,nr)]
                        if navigable(nextCell,row) and math.abs(nextCell.waterLevel-water.waterLevel)<=row.maxWaterStep then continuation=true;break end
                    end
                    if continuation then
                        local score=distances[land]+random:Noise(land.q,land.r,1,9173)*.25+direction*.00001
                        if not bestScore or score<bestScore then best,bestScore={land=land,water=water,direction=direction},score end
                    end
                end
                if water and distances[water]==nil and distances[land]<row.maxTownDistance
                    and not water.waterLevel and not water.worldTravelBlocked and not water.buildingId and not water.wonderId
                    and math.abs(water.height-land.height)<=maxStep then
                    distances[water]=distances[land]+1;previous[water]=land;queue[#queue+1]=water
                end
            end
        end
        if best then
            local land,water=best.land,best.water;occupied[land]=true;occupied[water]=true
            local lx,_,lz=Hex.ToWorld(land.q,land.r,land.height,map.hexRadius)
            local wx,_,wz=Hex.ToWorld(water.q,water.r,water.waterLevel,map.hexRadius)
            local path,reversed={},{};local cursor=land
            while cursor do reversed[#reversed+1]=cursor;cursor=previous[cursor] end
            for i=#reversed,1,-1 do path[#path+1]=reversed[i] end
            local scale=.2*map.hexRadius;local deckHeight=math.max(land.height,water.waterLevel+.12)
            local dock={id=town.id,townId=town.id,landQ=land.q,landR=land.r,waterQ=water.q,waterR=water.r,
                direction=best.direction,shoreDirection=shoreDirection(town,water),waterKind=water.waterKind,
                waterLevel=water.waterLevel,waterDepth=water.waterDepth,waterAssetId=water.waterAssetId,
                landHeight=land.height,approachCells=path,x=lx+(wx-lx)*.45,y=deckHeight-.5*scale,scale=scale,deckHeight=deckHeight,
                z=lz+(wz-lz)*.45,yaw=math.deg(math.atan(wx-lx,wz-lz)),
                initialDamaged=random:Noise(town.id,0,1,9181)*100<row.damagedChance,
                initialThreat=random:Noise(town.id,0,1,9187)*100<row.threatChance,
                intactAssetId=row.intactAssetId,ruinedAssetId=row.ruinedAssetId,boatAssetId=row.boatAssetId}
            map.docks[#map.docks+1]=dock;town.dock=dock;land.dockId=dock.id;water.dockId=dock.id
        end
    end end
    -- 岸边码头的占地不再叠放灌木；不重新抽样或推进原装饰随机流。
    if #map.docks>0 then
        local keep={}
        for _,item in ipairs(map.decorations) do
            local clear=true
            for _,dock in ipairs(map.docks) do
                if Hex.Distance(item.cell.q,item.cell.r,dock.landQ,dock.landR)<=1 then clear=false;break end
            end
            if clear then item.id=#keep+1;item.cell.decorationId=item.id;keep[#keep+1]=item
            else item.cell.decorationId=nil end
        end
        map.decorations=keep
    end
end
return Docks

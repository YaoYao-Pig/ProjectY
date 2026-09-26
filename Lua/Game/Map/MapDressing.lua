-- 大地图环境陈设使用位置噪声；不消耗聚落、水系和道路的随机序列。
local Random=require('Game.Map.SeededRandom')
local Dressing={}
function Dressing.Build(map,rules)
    local random=Random(map.seed ~ 0x51297613)
    local water,road={},{}
    for _,cell in ipairs(map.cells) do
        if cell.waterLevel or #cell.roadIds>0 then
            local target=cell.waterLevel and water or road
            target[cell]=true
            for _,neighbor in ipairs(map:GetNeighbors(cell.q,cell.r)) do
                target[neighbor]=true
                for _,other in ipairs(map:GetNeighbors(neighbor.q,neighbor.r)) do target[other]=true end
            end
        end
    end
    for _,cell in ipairs(map.cells) do
        if not cell.waterLevel and not cell.buildingId and not cell.decorationId and #cell.roadIds==0 then
            local dominant=cell.biomeWeights[1]
            for _,weight in ipairs(cell.biomeWeights) do if weight.weight>dominant.weight then dominant=weight end end
            local neighbors=map:GetNeighbors(cell.q,cell.r);local slope=0
            for _,other in ipairs(neighbors) do slope=math.max(slope,math.abs(cell.height-other.height)) end
            for _,row in ipairs(rules) do
                local allowed=false;for _,region in ipairs(row.regions) do if region==dominant.regionType then allowed=true end end
                if allowed and slope<=row.maxSlope and (not row.nearWater or water[cell]) and (not row.nearRoad or road[cell])
                    and random:Noise(cell.q,cell.r,1,1801+row.id*73)<row.density*dominant.weight then
                    local clear=true
                    for dq=-row.clearance,row.clearance do for dr=math.max(-row.clearance,-dq-row.clearance),math.min(row.clearance,-dq+row.clearance) do
                        local other=map:FindCell(cell.q+dq,cell.r+dr)
                        if other and (other.buildingId or other.decorationId) then clear=false end
                    end end
                    if clear then
                        local item={id=#map.decorations+1,cell=cell,assetId=row.assetId,
                            scale=row.minScale+(row.maxScale-row.minScale)*random:Noise(cell.q,cell.r,1,1901+row.id),
                            yaw=random:Noise(cell.q,cell.r,1,1999+row.id)*360}
                        cell.decorationId=item.id;map.decorations[item.id]=item;break
                    end
                end
            end
        end
    end
end
return Dressing

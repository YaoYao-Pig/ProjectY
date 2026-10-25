-- 奇观拥有完整连续占地；最多一个巨树实例，使用独立随机流，不推进区域布局随机数。
local Class=require('Core.Class')
local Hex=require('Game.Map.HexGrid')
local Random=require('Game.Map.SeededRandom')
local Wonders=Class('MapWonders')
function Wonders:ctor(config)
    self.rows=config:GetTable('MapWonderTable'):All()
    self.maxStep=config:GetTable('WorldTravelTable'):Get(1).maxHeightStep
    for _,row in ipairs(self.rows) do
        local asset=config:GetTable('MapAssetTable'):Get(row.assetId)
        assert(asset.footprintRadius==row.footprintRadius,'Wonder model footprint differs from layout')
        for _,id in ipairs(row.variantAssetIds) do
            local variant=config:GetTable('MapAssetTable'):Get(id)
            assert(variant.footprintRadius==row.footprintRadius,'Wonder variant footprint differs from layout')
        end
        config:GetTable('MapAreaTable'):Get(row.areaId)
        assert(row.maxCount==1 and row.footprintRadius>=2,'Wonders require a single multi-cell instance')
    end
end
function Wonders:Build(map)
    local random=Random(map.seed ~ 0x47726565)
    local protected={}
    for _,town in ipairs(map:GetTowns()) do protected[town.center]=true end
    for _,building in ipairs(map:GetBuildings()) do protected[building.entrance]=true end
    for _,row in ipairs(self.rows) do
        local allowed={};for _,kind in ipairs(row.regions) do allowed[kind]=true end
        local candidates={}
        for _,cell in ipairs(map.cells) do
            if allowed[map:GetRegion(cell.regionId).regionType] and not cell.waterLevel and not cell.buildingId and not cell.worldTravelBlocked then
                candidates[#candidates+1]={cell=cell,rank=random:Noise(cell.q,cell.r,1,row.id*911)}
            end
        end
        table.sort(candidates,function(a,b)
            if a.rank~=b.rank then return a.rank>b.rank end
            return a.cell.q<b.cell.q or a.cell.q==b.cell.q and a.cell.r<b.cell.r
        end)
        for _,candidate in ipairs(candidates) do
            local center=candidate.cell;local footprint={};local low,high=math.huge,-math.huge;local valid=true
            local radius=row.footprintRadius
            for dq=-radius,radius do for dr=math.max(-radius,-dq-radius),math.min(radius,-dq+radius) do
                local cell=map:FindCell(center.q+dq,center.r+dr)
                if not cell or protected[cell] or cell.waterLevel or cell.buildingId or cell.wonderId or cell.worldTravelBlocked or #cell.roadIds>0 then valid=false;break end
                footprint[#footprint+1]=cell;low=math.min(low,cell.height);high=math.max(high,cell.height)
            end;if not valid then break end end
            if valid and high-low<=row.maxGroundDelta then
                local entrance;local entrances,entrySeen={},{}
                for _,cell in ipairs(footprint) do
                    for direction=1,6 do
                        local q,r=Hex.Neighbor(cell.q,cell.r,direction);local nextCell=map:FindCell(q,r)
                        if nextCell and Hex.Distance(q,r,center.q,center.r)==radius+1 and not nextCell.waterLevel
                            and not nextCell.buildingId and not nextCell.worldTravelBlocked and math.abs(nextCell.height-cell.height)<=self.maxStep then
                            if not entrySeen[nextCell] then entrySeen[nextCell]=true;entrances[#entrances+1]=nextCell end
                            if not entrance or nextCell.r<entrance.r or nextCell.r==entrance.r and nextCell.q<entrance.q then entrance=nextCell end
                        end
                    end
                end
                if entrance then
                    local id=#map.wonders+1
                    local wonder={id=id,configId=row.id,name=row.name,areaId=row.areaId,cell=center,cells=footprint,entrance=entrance,entrances=entrances,pointId=400000+id}
                    map.wonders[id]=wonder
                    for _,cell in ipairs(footprint) do cell.wonderId=id;cell.worldTravelBlocked=true end
                    -- Cosmetic selection has its own position channel; it never changes placement or entry identity.
                    local assetId=row.assetId
                    if #row.variantAssetIds>0 then
                        local pick=math.min(#row.variantAssetIds,1+math.floor(random:Noise(center.q,center.r,1,row.id*911+613)*#row.variantAssetIds))
                        assetId=row.variantAssetIds[pick]
                    end
                    local decoration={id=#map.decorations+1,cell=center,assetId=assetId,scale=row.scale,yaw=0,height=low-row.rootEmbed,wonder=true}
                    map.decorations[decoration.id]=decoration;center.decorationId=decoration.id
                    wonder.decorationId=decoration.id
                    break
                end
            end
        end
    end
end
return Wonders

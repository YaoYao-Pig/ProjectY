-- 等水位水体中的可访问遗址。水域分析完成后独立抽样，不修改岸线、道路或聚落。
local Class=require('Core.Class')
local Random=require('Game.Map.SeededRandom')
local Hex=require('Game.Map.HexGrid')
local Sites=Class('MapWaterSites')
function Sites:ctor(config)
    self.rows=config:GetTable('MapWaterSiteTable'):All()
    for _,row in ipairs(self.rows) do
        config:GetTable('MapAreaTable'):Get(row.areaId)
        config:GetTable('MapAssetTable'):Get(row.assetId)
        assert(row.clearRadius>=1 and row.minBodyCells>=1+3*row.clearRadius*(row.clearRadius+1),'Water site needs a complete open-water disk')
        assert(row.chance>=0 and row.chance<=1 and row.maxCount>=0 and row.spacing>0,'Invalid water site distribution')
    end
end
function Sites.OpenWater(map,cell,row)
    if not cell.waterLevel or cell.waterDepth<row.minDepth then return false end
    for dr=-row.clearRadius,row.clearRadius do
        for dq=math.max(-row.clearRadius,-dr-row.clearRadius),math.min(row.clearRadius,-dr+row.clearRadius) do
            local other=map:FindCell(cell.q+dq,cell.r+dr)
            if not other or other.waterBodyId~=cell.waterBodyId or other.waterLevel~=cell.waterLevel or
                other.waterDepth<row.minDepth or other.buildingId or other.waterSiteId then return false end
        end
    end
    return true
end
function Sites:Build(map)
    map.waterSites={}
    for _,row in ipairs(self.rows) do
        local random=Random((map.seed ~ row.seedSalt) & 0xffffffff)
        local bodies={};for _,body in ipairs(map.waterBodies) do if #body.cells>=row.minBodyCells then bodies[#bodies+1]=body end end
        -- 身份只依赖稳定的水体及规则；不会挪用 town/forest 的 pointId 范围。
        local count=0
        while #bodies>0 and count<row.maxCount do
            local body=table.remove(bodies,random:Integer(1,#bodies))
            if random:Integer(0,999999)/1000000<row.chance then
                local candidates={}
                for _,cell in ipairs(body.cells) do
                    if Sites.OpenWater(map,cell,row) then
                        local fits=true
                        for _,site in ipairs(map.waterSites) do
                            if Hex.Distance(cell.q,cell.r,site.cell.q,site.cell.r)<math.max(row.spacing,site.spacing) then fits=false;break end
                        end
                        if fits then candidates[#candidates+1]=cell end
                    end
                end
                if #candidates>0 then
                    local cell=candidates[random:Integer(1,#candidates)]
                    local site={id=#map.waterSites+1,configId=row.id,pointId=200000+row.id*100000+body.id,
                        areaId=row.areaId,name=row.name,cell=cell,waterBodyId=body.id,spacing=row.spacing}
                    map.waterSites[site.id]=site;cell.waterSiteId=site.id;count=count+1
                    local item={id=#map.decorations+1,cell=cell,assetId=row.assetId,scale=row.scale,
                        height=cell.waterLevel,yaw=random:Integer(0,5)*60}
                    map.decorations[item.id]=item;cell.decorationId=item.id;site.decorationId=item.id
                end
            end
        end
    end
end
return Sites

local Hex=require('Game.Map.HexGrid')
local Profile={}
function Profile.ForTown(map,town,config)
    local rule=config:GetTable('EconomyRuleTable'):Get(1)
    local goods=config:GetTable('EconomyCommodityTable'):All()
    local maxStep=config:GetTable('WorldTravelTable'):Get(1).maxHeightStep
    local start=assert(map:FindCell(town.center.q,town.center.r));local queue={{cell=start,distance=0}};local seen={[Hex.Key(start.q,start.r)]=true};local head=1
    local sums,total,water,roads={},0,0,0
    for _,good in ipairs(goods) do assert(#good.regionTypes==#good.regionWeights,'Economy terrain weights differ');sums[good.id]=0 end
    local waterSeen={}
    while head<=#queue do
        local current=queue[head];head=head+1;local cell=current.cell;local weight=1-current.distance/(rule.radius+1)
        total=total+weight
        if #cell.roadIds>0 then roads=roads+weight end
        local region=map:GetRegion(cell.regionId).regionType
        for _,good in ipairs(goods) do
            for i,kind in ipairs(good.regionTypes) do if kind==region then sums[good.id]=sums[good.id]+weight*good.regionWeights[i] end end
        end
        if current.distance<rule.radius then for direction=1,6 do
            local q,r=Hex.Neighbor(cell.q,cell.r,direction);local other=map:FindCell(q,r);local key=Hex.Key(q,r)
            if other and other.waterLevel then
                if not waterSeen[key] and math.abs(cell.height-other.waterLevel)<=maxStep then waterSeen[key]=true;water=water+weight end
            elseif other and not seen[key] and not other.worldTravelBlocked and math.abs(cell.height-other.height)<=maxStep then
                seen[key]=true;queue[#queue+1]={cell=other,distance=current.distance+1}
            end
        end end
    end
    local result={resources={},tags={},tradeAccess=math.min(1,roads/math.max(1,total)*8)}
    for _,good in ipairs(goods) do
        local strength=math.min(1,sums[good.id]/math.max(1,total)*1.8+water/math.max(1,total)*8*good.waterWeight)
        result.resources[good.id]=strength
        if strength>=.55 then result.tags[#result.tags+1]={commodityId=good.id,rich=true}
        elseif strength<=.15 then result.tags[#result.tags+1]={commodityId=good.id,rich=false} end
    end
    return result
end
function Profile.Build(map,config)
    for _,town in ipairs(map:GetTowns()) do if town.role=='settlement' then town.economy=Profile.ForTown(map,town,config) end end
end
return Profile

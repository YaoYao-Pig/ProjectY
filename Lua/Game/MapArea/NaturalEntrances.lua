-- 入口只落在营地可达的山脚/谷缘；巨树入口在占地外侧，玩法条件由MapAreaSystem处理。
local Hex=require('Game.Map.HexGrid')
local Entrances={}
function Entrances.Build(map,config,definitions,anchor)
    local maxStep=config:GetTable('WorldTravelTable'):Get(1).maxHeightStep
    local start=map:GetCell(anchor.q,anchor.r)
    local queue,seen,head={start},{[start]=0},1
    while head<=#queue do
        local cell=queue[head];head=head+1
        for _,other in ipairs(map:GetNeighbors(cell.q,cell.r)) do
            if seen[other]==nil and not other.waterLevel and not other.worldTravelBlocked and math.abs(cell.height-other.height)<=maxStep then
                seen[other]=seen[cell]+1;queue[#queue+1]=other
            end
        end
    end
    local result={}
    local function add(cell,definition,pointId,kind,itemId,itemCount,name)
        local region=map:GetRegion(cell.regionId);local x,y,z=map:GetCellWorldPosition(cell.q,cell.r)
        result[#result+1]={areaConfigId=definition.id,pointId=pointId,name=name or definition.name,
            naturalKind=kind,entryItemId=itemId,entryItemCount=itemCount,q=cell.q,r=cell.r,x=x,y=y,z=z,
            source={regionId=region.instanceId,regionConfigId=region.configId,regionType=region.regionType,
                q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights,generationVersion=map.generationVersion}}
    end
    for _,rule in ipairs(config:GetTable('MapAreaNaturalEntranceTable'):All()) do
        for _,region in ipairs(map:GetRegionsByType(rule.regionType)) do
            local selected
            for _,cell in ipairs(region.cells) do
                if cell.landformEntrance==rule.kind and seen[cell] and not cell.buildingId and not cell.wonderId then
                    if not selected or seen[cell]<seen[selected] then selected=cell end
                end
            end
            if selected then add(selected,definitions:Get(rule.areaId),300000+region.instanceId,rule.kind,rule.itemId,rule.itemCount) end
        end
    end
    for _,wonder in ipairs(map:GetWonders()) do
        local selected
        for _,cell in ipairs(wonder.entrances) do
            if seen[cell] and (not selected or seen[cell]<seen[selected]) then selected=cell end
        end
        if selected then add(selected,definitions:Get(wonder.areaId),wonder.pointId,'GiantTree',0,0,wonder.name) end
    end
    return result
end
return Entrances

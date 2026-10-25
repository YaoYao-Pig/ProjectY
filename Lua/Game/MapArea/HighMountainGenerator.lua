local Terrain=require('Game.MapArea.NaturalTerrain')
local Legacy=require('Game.MapArea.HighMountainLegacyGenerator')
local AscentPath=require('Game.MapArea.MountainAscentPath')
local HeightField=require('Game.MapArea.MountainAscentTerrain')
local Mountain={}
function Mountain.Validate(row)
    Legacy.Validate(row);AscentPath.Validate(row)
    assert(row.ascentLakeRadius>=2 and row.ascentLakeRadius<=3.5,'Invalid mountain side-lake radius')
end
function Mountain.Generate(area,row,random,config)
    if area.source.generationVersion and area.source.generationVersion<=7 then return Legacy.Generate(area,row,random,config) end
    Mountain.Validate(row)
    local path=AscentPath.Build(area,row,random)
    local field=HeightField.Build(area,row,path,random)
    Terrain.Begin(area,row,function(_,_,cell)
        local height=field:Sample(cell.q,cell.r);local water=field:IsWater(cell.q,cell.r)
        local snow=height>path.peakHeight*.79
        return height,water and row.waterSurfaceId or (snow and row.snowSurfaceId or row.rockSurfaceId),not path.navigation[cell.index]
    end)
    area.generationVersion=2;area.corridorRadius=row.ascentTrailRadius
    area.ascentRoute={};area.ascentStages={};area.rooms={};area.ascentLength=path.length;area.ascentGrade=path.grade
    local route={}
    for i,node in ipairs(path.nodes) do area.ascentRoute[i]=node.index;route[i]={index=node.index,height=node.height} end
    area.trails={route};area.entryIndex=path.nodes[1].index;area.goalIndex=path.nodes[#path.nodes].index
    for _,stage in ipairs(path.stages) do
        area.ascentStages[stage.id]={id=stage.id,centerIndex=stage.centerIndex,height=stage.height,routeStart=stage.routeStart,routeEnd=stage.routeEnd}
        area.rooms[stage.id]={id=stage.id,name=row.landmarkName,tier=1,presetId=0,center=stage.centerIndex,height=stage.height}
    end
    for index,navigation in pairs(path.navigation) do
        local cell=area.cells[index]
        cell.height=navigation.height;cell.reserved=true;cell.naturalBarrier=false;cell.blocked=false;cell.surfaceId=row.trailSurfaceId
        cell.ascentStation=navigation.station;cell.ascentDistance=navigation.arc;cell.ascentStageGate=navigation.platform
        local stage=1
        for _,definition in ipairs(path.stages) do if navigation.station>=definition.station then stage=definition.id else break end end
        cell.ascentStage=stage
    end
    -- Height planning remains continuous, but the final scene keeps the world's flat hex columns.
    -- Neighboring trail columns climb in small steps; no sloped mesh hides the individual hex tops.
    Terrain.Finish(area,row,config,{flatTops=true,connect=function(a,b)return path:CanConnect(a,b)end,requireAllOpen=true})
    local rockHeight=config:GetTable('MapAssetTable'):Get(row.rockAssetId).referenceHeight
    for _,cell in ipairs(area.cells) do
        if cell.blocked and not cell.naturalWater and field.distances[cell.index]>path.coreWidth+path.step*2 then
            if cell.q%4==0 and cell.r%4==0 and random:Noise(cell.q,cell.r,5,5939)>.66 then
                local scale=math.min(.4+random:Noise(cell.q,cell.r,6,705)*.3,(path.peakHeight-cell.height-.5)/rockHeight)
                if scale>.25 then Terrain.ScenicProp(area,config,cell,row.rockAssetId,scale,random:Integer(0,359)) end
            elseif cell.height<path.peakHeight*.28 and cell.q%7==0 and cell.r%6==0 then
                Terrain.ScenicProp(area,config,cell,row.pineAssetId,.9,random:Integer(0,359))
            end
        end
    end
end
return Mountain

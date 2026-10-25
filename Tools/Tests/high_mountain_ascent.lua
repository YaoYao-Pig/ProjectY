-- Focused v2 ascent contract and v7 regeneration compatibility; no Editor or native state.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Generator=require('Game.MapArea.MapAreaGenerator')
local function generator(strategy)
    local result=Generator(config)
    result:Register(config:GetEnum('MapArea','E_MapAreaType').HighMountain,strategy,'MapAreaHighMountainTable','MapAreaHighMountainThemeTable')
    return result
end
local current=generator(require('Game.MapArea.HighMountainGenerator'))
local legacy=generator(require('Game.MapArea.HighMountainLegacyGenerator'))
local row=config:GetTable('MapAreaHighMountainTable'):Get(1)
local Hex=require('Game.Map.HexGrid')
assert(row.summitHeight==46 and row.ridgeRelief==24 and row.switchbacks==5 and row.lakeRadius==3.5,'Legacy mountain profile values changed')
local function generate(engine,seed,version)
    return engine:Generate(70,seed,1770,{generationVersion=version,regionType=12,biomeWeights={{regionType=12,weight=.8},{regionType=1,weight=.2}}})
end
local function signature(area)
    local values={tostring(area.entryIndex),tostring(area.goalIndex),tostring(area.walkableCount)}
    for _,cell in ipairs(area.cells) do
        values[#values+1]=table.concat({cell.height,cell.walkMask,cell.surfaceId,table.concat(cell.corners,','),table.concat(cell.color,',')},':')
    end
    for _,prop in ipairs(area.props) do values[#values+1]=table.concat({prop.assetId,prop.q,prop.r,prop.height,prop.yaw,prop.scaleX},':') end
    return table.concat(values,'|')
end
for _,seed in ipairs({20261025,7,42,73}) do
    local area=generate(current,seed,8)
    assert(area.generationVersion==2 and #area.ascentStages==row.ascentPlatforms+2)
    assert(area.ascentRoute[1]==area.entryIndex and area.ascentRoute[#area.ascentRoute]==area.goalIndex)
    local summit=area.cells[area.goalIndex].height
    assert(math.abs(summit-area.cells[area.entryIndex].height-row.ascentHeight)<.00001)
    local count=0
    for _,cell in ipairs(area.cells) do
        assert(cell.height<=summit+.00001,'An unrelated terrain peak rises above the ascent destination')
        if not cell.blocked then
            count=count+1;assert(cell.ascentStation and cell.reserved,'Terrain outside the planned ascent became walkable')
            for _,other in ipairs(area:Neighbors(cell)) do
                assert(area:CanStep(other,cell),'Mountain ascent must support walking back downhill')
                assert(math.abs(cell.ascentDistance-other.ascentDistance)<=math.sqrt(3)*area.hexRadius*3.1+.00001
                    or cell.ascentStageGate and cell.ascentStageGate==other.ascentStageGate,'Cross-traverse shortcut')
            end
        end
        assert(#cell.corners==6 and (cell.stairRise or 0)==0 and (cell.deckThickness or 0)==0,'Mountain should use existing hex-column rendering')
        for _,height in ipairs(cell.corners) do assert(height==cell.height,'Mountain hex top must remain flat and individually readable') end
    end
    assert(count==area.walkableCount)
    for i,index in ipairs(area.ascentRoute) do
        local cell=area.cells[index]
        for direction=1,6 do
            local q,r=Hex.Neighbor(cell.q,cell.r,direction);local other=area:Find(q,r)
            assert(other and not other.blocked,'Main ascent lost its three-cell clearance')
        end
        if i>1 then
            local previous=area.cells[area.ascentRoute[i-1]]
            assert(area:CanStep(previous,cell) and area:CanStep(cell,previous))
            assert(cell.height>=previous.height-.00001,'Main ascent descends before reaching the summit')
            assert(cell.height-previous.height<=row.ascentMaxGrade*math.sqrt(3)*area.hexRadius+.00001,'Main ascent exceeds its grade')
        end
    end
    local shortest=assert(area:FindPath(area.entryIndex,area.goalIndex));local lastGate=1;local previous=area.cells[area.entryIndex]
    for _,index in ipairs(shortest) do
        local cell=area.cells[index]
        assert(cell.height>=previous.height-.00001,'Actual navigation route descends along the ascent')
        if cell.ascentStageGate and cell.ascentStageGate~=lastGate then
            assert(cell.ascentStageGate==lastGate+1,'Actual route skipped or reversed a stage');lastGate=cell.ascentStageGate
        end
        previous=cell
    end
    assert(lastGate==#area.ascentStages and #shortest>=#area.ascentRoute*.75,'Actual route bypassed the intended traverses')
    for i=2,#area.ascentStages-1 do
        assert(not area:FindPath(area.entryIndex,area.goalIndex,function(cell)return cell.ascentStageGate~=i end),'A turning platform can be bypassed')
    end
    assert(signature(area)==signature(generate(current,seed,8)),'V2 ascent is not deterministic')
    local old=generate(current,seed,7)
    assert(old.generationVersion==1 and not old.ascentRoute and signature(old)==signature(generate(legacy,seed,7)),'V7 save no longer regenerates the preserved legacy layout')
    if seed==42 then assert(signature(area)==signature(generate(current,seed,nil)),'Unversioned new areas must use v2') end
    print(string.format('PASS mountain ascent seed %d: flat hex tops, %d route cells, %d actual steps, %d platforms, %.1fm rise, %.1f%% grade; v7 legacy exact',
        seed,#area.ascentRoute,#shortest,#area.ascentStages,row.ascentHeight,area.ascentGrade*100))
end
config:OnShutdown()

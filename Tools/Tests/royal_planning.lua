-- 王城本次改动的针对性检查：默认世界种子、不同朝向、临街门口、回路及确定性。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local value=file:read('*a');file:close();return value
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local source={regionId=1,regionType=6,regionConfigId=6,q=0,r=0,height=1,biomeWeights={{regionType=6,weight=1}}}
local definition=config:GetTable('MapAreaTable'):Get(6)
local function generate(seed)
    local worldSeed=((seed-definition.seedSalt) ~ 2654435761)&0xffffffff
    return generator:Generate(6,worldSeed,1,source)
end
local function fingerprint(area)
    local values={}
    for _,prop in ipairs(area.props) do values[#values+1]=table.concat({prop.assetId,prop.q,prop.r,prop.rotation,prop.height},':') end
    for _,road in ipairs(area.roadPaths) do values[#values+1]=road.kind..':'..table.concat(road.cells,',') end
    return table.concat(values,';')
end
local previous
for _,seed in ipairs({2667826519,19,7301,19477}) do
    local area=generate(seed);local kinds={}
    local profile=config:GetTable('MapAreaTownTable'):Get(5)
    assert(area.generationVersion==4 and #area.facilities==#profile.facilityIds and #area.npcs==#profile.facilityIds+profile.residentCount)
    local reachable=require('Game.MapArea.DungeonGeometry').Reachable(area,area.entryIndex)
    assert(#reachable==area.walkableCount,'Public terrain disconnected')
    for _,road in ipairs(area.roadPaths) do
        kinds[road.kind]=true
        for i,index in ipairs(road.cells) do
            assert(not area.cells[index].blocked and area.cells[index].road,'Road overwritten by a plot')
            if i>1 then assert(area:CanStep(area.cells[road.cells[i-1]],area.cells[index]),'Road crosses a cliff or layer') end
        end
    end
    assert(kinds.main and kinds.lane and kinds.loop,'Street hierarchy or return route missing')
    for _,facility in ipairs(area.facilities) do assert(#area:Neighbors(area.cells[facility.entryIndex])>=3,'Facility door lacks public space') end
    local hash=fingerprint(area);assert(hash~=previous,'Seed only changed colors');previous=hash
    if seed==2667826519 then assert(fingerprint(generate(seed))==hash,'Same seed is not deterministic') end
    print('PASS organic royal seed '..seed..': '..area.walkableCount..' walkable, '..#area.props..' props, '..area.planningDiagnostics.loopCount..' loops, '..#area.planningDiagnostics.skipped..' optional plots skipped')
end

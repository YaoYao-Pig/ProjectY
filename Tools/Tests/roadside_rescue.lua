-- Actual roadside layout/configuration and battle clipping; no Editor or native combat state.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(config:GetEnum('MapArea','E_MapAreaType').RoadsideRescue,
    require('Game.MapArea.RoadsideRescueGenerator'),'MapAreaRoadsideRescueTable','MapAreaRoadsideRescueThemeTable')
local Hex=require('Game.Map.HexGrid')
local Squad=require('Game.MapArea.SquadMovement')
local Board=require('Game.Battle.BattleBoard')
local function generate(kind,seed)
    return generator:Generate(61,seed,3061,{regionType=kind,biomeWeights={{regionType=kind,weight=1}}})
end
local function signature(area)
    local result={}
    for _,cell in ipairs(area.cells) do result[#result+1]=cell.kind..':'..tostring(cell.blocked)..':'..cell.surfaceId end
    for _,prop in ipairs(area.props) do result[#result+1]=table.concat({prop.assetId,prop.q,prop.r,prop.yaw},':') end
    return table.concat(result,'|')
end
local checked=0
for _,theme in ipairs(config:GetTable('MapAreaRoadsideRescueThemeTable'):All()) do
    local area=generate(theme.regionType,20261024)
    local queue,seen,head={area.entryIndex},{[area.entryIndex]=true},1
    while head<=#queue do
        local cell=area.cells[queue[head]];head=head+1
        assert(cell.layer==0 and cell.height==0,'Roadside navigation must remain on one flat layer')
        for _,other in ipairs(area:Neighbors(cell)) do
            if not seen[other.index] then seen[other.index]=true;queue[#queue+1]=other.index end
        end
    end
    assert(#queue==area.walkableCount and #queue>200 and seen[area.goalIndex] and seen[area.safeIndex],'Road, shelter and cover must stay connected')
    local plan=assert(area.encounterPlans[1]);assert(#area.encounterPlans==1 and plan.encounterId==302 and #plan.cells==4)
    local safe=plan.cells[4];local center=area.cells[area.battleCenterIndex]
    assert(safe.index==area.safeIndex and center==plan.cells[1])
    local encounter=config:GetTable('CombatEncounterTable'):Get(plan.encounterId)
    assert(encounter.enemyIds[1]==921 and encounter.enemyIds[2]==922 and encounter.enemyIds[3]==921 and encounter.enemyIds[4]==920)
    local occupied={}
    for _,cell in ipairs(plan.cells) do assert(seen[cell.index] and not occupied[cell.index]);occupied[cell.index]=true end
    local fixed=Board.FromArea(area,center.q,center.r,area.battleRadius,0)
    assert(Hex.Distance(center.q,center.r,safe.q,safe.r)==18 and not fixed:Find(safe.q,safe.r),'Sheltered actor must be physically outside the battle window')
    for count=3,4 do
        local deployment=Squad.Deploy(area,area.entryIndex,count,function(cell)return not cell.blocked and not occupied[cell.index]end)
        local radius=0
        for i=1,3 do
            local pursuer=plan.cells[i]
            radius=math.max(radius,Hex.Distance(center.q,center.r,pursuer.q,pursuer.r))
            assert(fixed:Find(pursuer.q,pursuer.r)==pursuer)
        end
        local localOccupied={}
        for _,index in ipairs(deployment) do
            local cell=area.cells[index]
            assert(cell.r<plan.cells[1].r and cell.r>safe.r and not occupied[index] and not localOccupied[index])
            assert(fixed:Find(cell.q,cell.r)==cell,'Player deployment must fit the fixed combat window')
            radius=math.max(radius,Hex.Distance(center.q,center.r,cell.q,cell.r));localOccupied[index]=true
        end
        radius=radius+config:GetTable('MapAreaEncounterTable'):Get(area.configId).battleMargin
        assert(radius<=area.battleRadius,'Default participant bounds unexpectedly reached the rear shelter')
        local battle=Board.FromArea(area,center.q,center.r,radius,0)
        assert(not battle:Find(safe.q,safe.r) and Hex.Distance(center.q,center.r,safe.q,safe.r)>radius+3)
        for _,index in ipairs(deployment) do
            local start=area.cells[index]
            local _,distance=battle:Search(start.q,start.r,{},1000)
            for i=1,3 do assert(distance[plan.cells[i]],'Cover disconnected the player from a pursuer') end
        end
    end
    local props={}
    for _,prop in ipairs(area.props) do
        assert(not props[prop.cells[1]] and area.cells[prop.cells[1]].blocked and area.cells[prop.cells[1]].blocksSight)
        assert(prop.layer==0 and prop.scaleX>0 and prop.scaleY>0 and prop.scaleZ>0)
        config:GetTable('MapAssetTable'):Get(prop.assetId);props[prop.cells[1]]=true
    end
    assert(#area.props==15,'Expected the compact existing-asset cover set')
    assert(not pcall(function()area.battleRadius=32 end),'Event geometry must be immutable')
    checked=checked+1
end
local area=generate(1,20261024)
assert(signature(area)==signature(generate(1,20261024)),'Equal seeds must reproduce terrain and prop orientation')
local changed=generate(1,7)
assert(area.entryIndex==changed.entryIndex and area.safeIndex==changed.safeIndex and area.battleCenterIndex==changed.battleCenterIndex,'Seeds must not move combatants toward the sheltered actor')
print(string.format('PASS roadside rescue: %d themes, %d walkable cells, 3/4 player deployment, 15 existing cover props, sheltered actor outside radius %d',checked,area.walkableCount,area.battleRadius))
config:OnShutdown()

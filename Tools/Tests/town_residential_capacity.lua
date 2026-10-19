-- Residential growth keeps the configured count when an individual preset cannot fit a row house.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local lots=config:GetTable('MapAreaTownLotTable')
local function check(id,seed,kind)
    local area=generator:Generate(id,seed,11,{regionId=1,regionType=kind,regionConfigId=kind,q=0,r=0,height=1,biomeWeights={{regionType=kind,weight=1}}})
    local profile=config:GetTable('MapAreaTownTable'):Get(config:GetTable('MapAreaTable'):Get(id).profileId)
    local homes,occupied=0,{}
    local public=function(cell)return not cell.interiorId end
    for _,room in ipairs(area.interiors)do
        homes=homes+lots:Get(room.lotId).houseUnits
        for _,index in ipairs(room.cells)do
            assert(not occupied[index],'Residential growth overlaps an existing interior');occupied[index]=true
            assert(not area.cells[index].blocked and area.cells[index].interiorId==room.id)
        end
        for _,index in ipairs(room.doorIndices)do
            assert(area.cells[index].reserved and area:FindPath(area.entryIndex,index,public),'Residential growth blocks a public entrance')
        end
        for _,portal in ipairs(room.portals)do
            local outside,inside=area.cells[portal.outsideIndex],area.cells[portal.insideIndex]
            assert(area:CanStep(outside,inside) and area:CanStep(inside,outside),'Residential growth breaks a doorway')
        end
    end
    assert(homes==profile.houseCount,'Residential count differs from the configured complete groups')
    assert(#area.facilities==#profile.facilityIds,'Residential growth must retain every required facility')
    assert(#require('Game.MapArea.DungeonGeometry').Reachable(area,area.entryIndex)==area.walkableCount,'Residential growth disconnects town cells')
    local signature={};for _,prop in ipairs(area.props)do signature[#signature+1]=table.concat({prop.assetId,prop.q,prop.r,prop.rotation},':')end
    print('PASS capacity area='..id..' seed='..seed..' region='..kind..': '..homes..' homes; public doors and complete graph connected')
    return table.concat(signature,';')
end
-- Before the fix, market seed 4 deterministically failed with 21/24 homes.
local signature=check(2,4,1)
assert(signature==check(2,4,1),'Residential placement must remain deterministic')
for _,id in ipairs({3,4,5})do check(id,4,id==4 and 6 or 1)end
for seed=5,9 do check(2,seed,seed%2+1)end

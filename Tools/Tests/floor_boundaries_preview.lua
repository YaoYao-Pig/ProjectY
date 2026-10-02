-- Isolated display snapshots, without changing the live player's map or starting Play.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
generator:Register(5,require('Game.MapArea.ShipwreckGenerator'),'MapAreaShipwreckTable','MapAreaShipwreckThemeTable')
local snapshot=require('Game.MapArea.MapAreaSystem').LayoutSnapshot
local result={}
for _,spec in ipairs({{6,20260925,11,2,'town'},{40,20260921,300010,3,'ship'}}) do
    local region=spec[4]
    local area=generator:Generate(spec[1],spec[2],spec[3],{regionId=region,regionConfigId=region,regionType=region,q=0,r=0,height=1,biomeWeights={{regionType=region,weight=1}}})
    local reader={config=config,appearance=require('Game.Adventure.PawnAppearance').New(config),ActiveLayout=function()return area end}
    assert(#area.floorBoundaryPatches>0,'Missing boundary geometry')
    local owner
    if spec[5]=='town' then
        for _,room in ipairs(area.interiors) do if room.upperEntryIndex then owner=room.upperEntryIndex;break end end
    else
        for _,patch in ipairs(area.floorBoundaryPatches) do
            local cell=area.cells[patch.ownerIndex]
            if cell.layer==2 and cell.coverInteriorId==2001 then owner=cell.index;break end
        end
    end
    assert(owner,'Missing upper floor fixture')
    result[#result+1]={name=spec[5],layout=snapshot(reader),ownerIndex=owner}
end
return result

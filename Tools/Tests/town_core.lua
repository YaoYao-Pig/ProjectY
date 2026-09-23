-- 真实城镇配表的定向检查，不启动 Editor。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local data=file:read('*a');file:close();return data
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local function make(id,kind,seed)
    return generator:Generate(id,seed,11,{regionId=7,regionType=kind,regionConfigId=kind,q=0,r=0,height=1,biomeWeights={{regionType=kind,weight=1}}})
end
local function signature(area)
    local result={};for _,prop in ipairs(area.props) do result[#result+1]=prop.assetId..':'..prop.q..':'..prop.r..':'..prop.rotation end
    return table.concat(result,';')
end
for _,id in ipairs({2,3,4,5}) do
    local area=make(id,id==4 and 6 or 5,20260924)
    local definition=config:GetTable('MapAreaTable'):Get(id);local profile=config:GetTable('MapAreaTownTable'):Get(definition.profileId)
    assert(#area.facilities==#profile.facilityIds and #area.npcs==#area.facilities+profile.residentCount)
    local occupied={}
    for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do assert(not occupied[index]);occupied[index]=true end end
    for _,facility in ipairs(area.facilities) do assert(area:FindPath(area.entryIndex,facility.entryIndex)) end
    for _,npc in ipairs(area.npcs) do
        assert(not area.cells[npc.spawnIndex].blocked)
        local previous=npc.spawnIndex
        for _,index in ipairs(npc.route) do
            local a,b=area.cells[previous],area.cells[index]
            assert(not b.blocked and require('Game.Map.HexGrid').Distance(a.q,a.r,b.q,b.r)==1)
            previous=index
        end
        if #npc.route>0 then assert(previous==npc.spawnIndex) end
    end
    assert(signature(area)==signature(make(id,id==4 and 6 or 5,20260924)))
    print('PASS town '..id..': '..#area.facilities..' facilities / '..#area.props..' props / '..#area.npcs..' NPCs')
end
assert(signature(make(2,1,20260924))~=signature(make(2,1,20260925)))
print('PASS seeded block variation and Region themes')

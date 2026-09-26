-- 装饰扩展的定向验收：真实源表导出、三类地图、连续导航及成片材质。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local data=file:read('*a');file:close();return data
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(1,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local all,materials={},{}
local function make(id,kind)
    return generator:Generate(id,20260925,11,{regionId=7,regionType=kind,regionConfigId=kind,q=0,r=0,height=1,biomeWeights={{regionType=kind,weight=1}}})
end
local function inspect(area)
    local count,signature=0,{}
    for _,prop in ipairs(area.props) do
        if prop.assetId>=89 and prop.assetId<=112 then
            all[prop.assetId]=true;count=count+1
            assert(prop.scaleX==1 and prop.scaleY==1 and prop.scaleZ==1,'Dressing must remain meter-sized')
            for _,index in ipairs(prop.cells) do local cell=area.cells[index]
                assert(cell.blocked and cell.obstacleId==prop.id and not cell.reserved,'Dressing occupied reserved space')
                assert(cell.kind~='corridor' and cell.kind~='street' and cell.kind~='stairs','Dressing blocked a route')
            end
            signature[#signature+1]=prop.assetId..':'..prop.q..':'..prop.r..':'..prop.rotation
        end
    end
    assert(count>0,'No new dressing generated')
    assert(#require('Game.MapArea.DungeonGeometry').Reachable(area,area.entryIndex)==area.walkableCount,'Disconnected map')
    for _,site in ipairs(area.facilities) do assert(area:FindPath(area.entryIndex,site.entryIndex),'Facility inaccessible') end
    for _,cell in ipairs(area.cells) do assert(cell.surfaceId>0);materials[cell.surfaceId]=true end
    print('PASS dressing area='..area.name..' props='..count)
    return table.concat(signature,';')
end
for kind=1,6 do local area=make(1,kind);local signature=inspect(area)
    if kind==5 then assert(signature==inspect(make(1,kind)),'Decoration nondeterministic') end
    local roomFloors={}
    for _,cell in ipairs(area.cells) do if cell.roomId>0 and cell.kind~='wall' then
        assert(not roomFloors[cell.roomId] or roomFloors[cell.roomId]==cell.surfaceId,'Material scattered per tile')
        roomFloors[cell.roomId]=cell.surfaceId
    end end
end
for id=2,6 do inspect(make(id,5)) end
local registry=require('Core.SystemRegistry')({ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local b=f:read('*a');f:close();return b
end,LogError=error})
registry:Register('Config',require('Config.ConfigSystem'));registry:Register('Map',require('Game.Map.MapSystem'),{'Config'});registry:Start()
local map=registry:Get('Map'):Generate(20260925,{1,2,3,4,5,6,1,4,5,6});local count=0
for _,prop in ipairs(map.decorations) do if prop.assetId>=89 then
    assert(not prop.cell.waterLevel and not prop.cell.buildingId and #prop.cell.roadIds==0,'World dressing overlapped gameplay')
    count=count+1;all[prop.assetId]=true
end end
assert(count>0);registry:Shutdown()
local kinds=0;for _ in pairs(all) do kinds=kinds+1 end
assert(kinds==24,'Expected 24 dressing types across fixtures, got '..kinds)
assert(materials[15] and materials[16] and materials[19] and materials[22] and materials[23] and materials[24],'Missing dungeon surface families')
print('PASS world props='..count..' / all 24 models generated; dungeon moss, wood, frost, stone materials covered')

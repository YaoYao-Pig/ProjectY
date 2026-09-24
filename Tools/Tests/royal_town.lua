-- 读取真实导出表：王城设施、中庭、门洞与上下桥的四人寻路。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local data=file:read('*a');file:close();return data
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(2,require('Game.MapArea.TownGenerator'),'MapAreaTownTable','MapAreaTownThemeTable')
local squad=require('Game.MapArea.SquadMovement')
for _,region in ipairs({1,2,6}) do
    local area=generator:Generate(6,20260924,11,{regionId=1,regionType=region,regionConfigId=region,q=0,r=0,height=1,biomeWeights={{regionType=region,weight=1}}})
    local profile=config:GetTable('MapAreaTownTable'):Get(5)
    assert(#area.facilities==#profile.facilityIds and #area.npcs==#profile.facilityIds+profile.residentCount)
    for _,prop in ipairs(area.props) do assert(math.tointeger(prop.q) and math.tointeger(prop.r),'Snapshot anchors must remain integer hex coordinates') end
    local deck
    for _,cell in ipairs(area.cells) do
        if cell.layer==1 then deck=cell end
        if not cell.blocked then for _,nextCell in ipairs(area:Neighbors(cell)) do assert(area:CanStep(nextCell,cell),'One-way street') end end
    end
    local under=area:Find(deck.q,deck.r);assert(not under.blocked and deck.height-under.height>=4.5)
    local positions=squad.Deploy(area,area.entryIndex,4)
    for _,index in ipairs({area.goalIndex,deck.index,under.index,area.entryIndex}) do
        local path=assert(area:FindPath(positions[1],index));local frames,reason=squad.Plan(area,positions,path,function()return true end);assert(frames,reason)
        for offset=1,#frames,4 do
            local occupied={};for i=1,4 do local nextIndex=frames[offset+i-1]
                assert(not occupied[nextIndex]);occupied[nextIndex]=true
                assert(nextIndex==positions[i] or area:CanStep(area.cells[positions[i]],area.cells[nextIndex]));positions[i]=nextIndex
            end
        end
    end
    for _,facility in ipairs(area.facilities) do assert(area:FindPath(area.entryIndex,facility.entryIndex)) end
    print('PASS royal Region '..region..': '..area.walkableCount..' walkable / '..#area.props..' props / four-member palace and bridge routes')
end

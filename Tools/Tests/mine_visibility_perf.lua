-- 有限离线视野基准：真实冻结矿井、半径 12、入口/坍塌/梯道；共 20 次查询。
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(6,require('Game.MapArea.MineGenerator'),'MapAreaMineTable','MapAreaMineThemeTable')
local area=generator:Generate(50,20260921,400050,{regionId=3,regionConfigId=3,regionType=3,q=0,r=0,height=1,biomeWeights={{regionType=3,weight=1}}})
assert(area.visionRadius==12)
local cases={{'entry',area.entryIndex},{'upper_collapse',area.openings[1].viewpointIndex},
    {'stairs',area.stairs[1].cells[3]},{'middle_collapse',area.openings[2].viewpointIndex}}
local total,partyTotal=0,0
local visibility=require('Game.MapArea.LayeredVisibility')
local Squad=require('Game.MapArea.SquadMovement')
for _,case in ipairs(cases) do
    local start=os.clock();local count
    count=#area:VisibleFrom(case[2])
    local seconds=os.clock()-start;total=total+seconds
    print(string.format('PERF %s index=%d layer=%d visible=%d perVisibleFromMs=%.3f',case[1],case[2],area.cells[case[2]].layer,count,seconds*1000))
    local positions=Squad.Deploy(area,case[2],4,function(cell)return not cell.blocked end)
    local query=visibility.NewQuery(area);start=os.clock()
    for _,index in ipairs(positions) do area:VisibleFrom(index,query) end
    local party=os.clock()-start;partyTotal=partyTotal+party
    print(string.format('PERF %s actualFourMemberRevealMs=%.3f',case[1],party*1000))
end
print(string.format('PERF representativeFourMemberRevealMs=%.3f',total*1000))
print(string.format('PERF sharedQueryAverageFourMemberRevealMs=%.3f',partyTotal/4*1000))
config:OnShutdown()

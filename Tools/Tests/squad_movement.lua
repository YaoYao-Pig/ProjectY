-- 编队最小检查：真实生成地牢，以及转角/窄口夹具；每一步验证而不只看最终位置。
package.path='Lua/?.lua;'..package.path
local Squad=require('Game.MapArea.SquadMovement')
local Layout=require('Game.MapArea.MapAreaLayout')
local Hex=require('Game.Map.HexGrid')
local function check(area,start,path,allowed)
    local frames,reason=Squad.Plan(area,start,path,allowed);assert(frames,reason)
    local current={table.unpack(start)}
    for offset=1,#frames,#start do
        local used,nextPositions={},{}
        for i=1,#start do
            local index=frames[offset+i-1];local cell=area.cells[index];local old=area.cells[current[i]]
            assert(not cell.blocked and allowed(cell) and not used[index],'Invalid occupied cell')
            assert(Hex.Distance(old.q,old.r,cell.q,cell.r)<=1,'Teleport detected')
            for j=1,i-1 do assert(not(index==current[j] and nextPositions[j]==current[i]),'Head-on swap') end
            nextPositions[i]=index;used[index]=true
        end
        current=nextPositions
    end
    assert(current[1]==(path[#path] or start[1]))
    return current
end
local area=Layout.New({id=1,name='夹具',areaType=1,width=32,height=24,hexRadius=1.5,visionRadius=9,moveStepSeconds=.13},1,{}, {})
for _,cell in ipairs(area.cells) do cell.blocked=cell.q==16 and cell.r~=12 end
local allowed=function() return true end
for count=1,4 do
    local positions=Squad.Deploy(area,area:Find(5,12).index,count)
    for _,coord in ipairs({{26,12},{22,18},{21,5},{5,12}}) do
        local path=assert(area:FindPath(positions[1],area:Find(table.unpack(coord)).index))
        positions=check(area,positions,path,allowed)
    end
end
print('PASS 1..4 members: turns, narrow opening, return route, no overlaps / swaps / teleports')
local Config=require('Config.ConfigSystem');local config=Config()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Generator=require('Game.MapArea.MapAreaGenerator');local generator=Generator(config)
generator:Register(config:GetEnum('MapArea','E_MapAreaType').Dungeon,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
area=generator:Generate(1,20260921,4,{regionId=7,regionConfigId=1,regionType=1,q=5,r=2,height=1,biomeWeights={{regionType=1,weight=1}}})
local positions=Squad.Deploy(area,area.entryIndex,4)
local known={};for _,index in ipairs(positions) do for _,cell in ipairs(area:VisibleFrom(index)) do known[cell]=true end end
local filter=function(cell) return known[cell.index] end
local path={};for index in pairs(known) do if not area.cells[index].blocked then
    local candidate=area:FindPath(positions[1],index,filter)
    if candidate and #candidate>#path then path=candidate end
end end
positions=check(area,positions,path,filter)
positions=check(area,positions,assert(area:FindPath(positions[1],area.goalIndex)),allowed)
check(area,positions,assert(area:FindPath(positions[1],area.entryIndex)),allowed)
print('PASS generated dungeon: known terrain, full outward / return route across rooms and props')

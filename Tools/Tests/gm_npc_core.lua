package.path='Lua/?.lua;'..package.path
local Commands=require('Game.GM.NpcCommands')
local actors={{Id=10,HP=20},{Id=20,HP=20}}
local data={PartyCount=2,Phase='map',Areas={ActiveSiteId=0}}
function data:GetPartyAt(index)return actors[index+1]end
local occupied,enemies={[1]=true},{}
local state={IsNpcOccupied=function(_,index)return occupied[index]==true end}
local area={cells={{index=1},{index=2},{index=3},{index=4}}}
local neighbors={{2,3},{1,4},{1,4},{2,3}}
function area:Neighbors(cell)local rows={};for _,index in ipairs(neighbors[cell.index])do rows[#rows+1]=self.cells[index]end;return rows end
local adventure={data=data,areas={}}
function adventure.areas:EnemyOccupancy()return enemies end
function adventure.areas:SquadFootprint(_,ids)
    assert(ids[1]==10 and ids[2]==20)
    return function(index,member)
        if member==1 then if index==2 then return {2,4} elseif index==3 then return {3} end
        elseif index==4 then return {4} end
    end
end
local story={data={DialogueOpen=false},rules={settings={recruitSearchRadius=2}}}
local gm=Commands.New(adventure,story)
assert(gm:CanTravel())
for _,phase in ipairs({'battle','event','result'})do data.Phase=phase;assert(not gm:CanTravel())end
data.Phase='map';story.data.DialogueOpen=true;assert(not gm:CanTravel());story.data.DialogueOpen=false
actors[1].HP=0;actors[2].HP=0;assert(not gm:CanTravel());actors[1].HP=20;actors[2].HP=20
local deployment=assert(gm:Deployment(area,state,1))
assert(deployment.cells[1]==3 and deployment.cells[2]==4,'Planner must backtrack when a large leader footprint blocks another member')
occupied[4]=true
local result,reason=gm:Deployment(area,state,1);assert(not result and reason:find('合法位置'))
occupied[4]=nil;enemies[4]=true;assert(not gm:Deployment(area,state,1))
assert(data.Phase=='map' and data.Areas.ActiveSiteId==0,'Planning must not mutate world location')
print('PASS GM NPC phase/dialogue/defeated gates, complete footprints, backtracking, occupied cells and enemy rejection')

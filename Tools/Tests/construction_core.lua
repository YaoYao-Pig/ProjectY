package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Layout=require('Game.MapArea.MapAreaLayout');local Board=require('Game.Battle.BattleBoard')
local base=Layout.New({id=1,name='Construction fixture',areaType=3,width=7,height=7,hexRadius=1,visionRadius=6,moveStepSeconds=.1},1,{}, {})
for _,cell in ipairs(base.cells) do cell.blocked=false;cell.blocksSight=false;cell.kind='floor';cell.height=0;cell.surfaceId=201;cell.wallHeight=2 end
base.entryIndex=1;base.goalIndex=49;base.props={}
base=Layout.Freeze(base)
local data={Count=0,Revision=0,records={}}
function data:GetAt(i)return self.records[i+1] end
local function add(skill,q,r)
    local row={Id=data.Count+1,SiteId=1,CellIndex=base:Find(q,r).index,SkillId=skill,MaxHP=40,HP=40,Removed=false}
    data.Count=data.Count+1;data.records[data.Count]=row;data.Revision=data.Revision+1;return row
end
local inventory={CountItem=function()return 99 end,Equipped=function()return nil end,Offhand=function()return nil end}
local adventure={equipment={data=inventory,rules={HasWeaponTag=function()return true end},LootSnapshot=function()return {} end},
    data={Areas={Active={IsNpcOccupied=function()return false end}}},areas={}}
local construction=require('Game.Battle.Construction').New(config,adventure,data)
local area=construction:Layout(base,1);local board=Board.FromArea(area,3,3,6)
local originalRecord=construction.Record;local queries=0
construction.Record=function(self,...)queries=queries+1;return originalRecord(self,...) end
local unchanged=area:NavigationView();assert(unchanged==base,'Empty construction site should plan directly on its static layout')
local sample=area:Find(3,3)
local identity={sample.index,sample.q,sample.r,sample.layer,sample.neighbors,sample.interiorId,sample.corners,sample.surfaceId,sample.baseHeight}
assert(queries==0,'Static cell fields queried construction state')
local fence=add(301,3,3)
assert(area:Find(3,3).blocked and not base:Find(3,3).blocked)
local fenced=area:NavigationView()
assert(fenced:Find(3,3).blocked and not unchanged:Find(3,3).blocked,'New query must observe construction placed after the previous query')
assert(construction:Layout(base,2):NavigationView()==base,'Construction in another site should not add a planning projection')
assert(area:CanSee(area:Find(2,3),area:Find(4,3)),'Fence must not block shots')
fence.Removed=true;data.Revision=data.Revision+1
local wall=add(302,3,3)
assert(not area:CanSee(area:Find(2,3),area:Find(4,3)),'Wall must block line of sight')
wall.Removed=true;data.Revision=data.Revision+1
assert(area:CanSee(area:Find(2,3),area:Find(4,3)) and not area:Find(3,3).blocked)
assert(fenced:Find(3,3).blocked and not area:NavigationView():Find(3,3).blocked,'A planning query must stay consistent while the next query observes removal')
local platform=add(304,3,3)
assert(area:Find(3,3).height==1.4 and base:Find(3,3).height==0)
assert(area:MoveCost(area:Find(2,3),area:Find(3,3))==2)
local raised=area:NavigationView();assert(raised:Find(3,3).height==1.4 and raised:MoveCost(raised:Find(2,3),raised:Find(3,3))==2)
assert(construction:RangeBonus(board,{Q=3,R=3},{Q=5,R=3},{target='enemy',range=3})==1)
platform.Removed=true;data.Revision=data.Revision+1
assert(area:Find(3,3).height==0,'Destroyed platform must restore the original standing surface')
assert(area:NavigationView():Find(3,3).height==0 and raised:Find(3,3).height==1.4,'Platform demolition must affect the next query and live view immediately')
local pit=add(306,3,3);pit.MaxHP=0
assert(area:MoveCost(area:Find(2,3),area:Find(3,3))==3)
local _,distance=board:Search(2,3,{},2)
assert(not distance[area:Find(3,3)] and distance[area:Find(4,2)]==2,'Weighted movement must find a cheaper route around a trench')
local actor={Id=1,Team=1,Q=2,R=2};local battle={board=board,Active=function()return actor end,Occupied=function()return {} end}
local skill=config:GetTable('CombatSkillTable'):Get(301)
inventory.CountItem=function()return 0 end
assert(not construction:CanUse(battle,skill,area:Find(3,2)),'Missing materials must reject placement')
inventory.CountItem=function()return 99 end
assert(construction:CanUse(battle,skill,area:Find(3,2)))
battle.Occupied=function()return {['3:2']=true} end
assert(not construction:CanUse(battle,skill,area:Find(3,2)),'Occupied cells must reject placement')
battle.Occupied=function()return {} end
assert(not construction:Budget(actor,305),'Carrying a shovel is insufficient; actor must equip it')
inventory.Equipped=function()return {ItemId=73} end
assert(construction:Budget(actor,305))
assert(not construction:CanUse(battle,config:GetTable('CombatSkillTable'):Get(307),area:Find(3,3)),'Excavations cannot be attacked as structures')
print('PASS construction: static layout preserved, movement, sight, height, demolition restoration, material and tool boundaries')

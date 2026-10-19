-- Real BattleSystem, board search, animal footprint queries and construction MoveCost.
-- Only C# movement bookkeeping / actor state are isolated scalar adapters.
package.path='Lua/?.lua;'..package.path
assert(loadfile('Tools/Tests/battle_movement_fixture.lua'))()
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local value=file:read('*a');file:close();return value
end}})
local Board=require('Game.Battle.BattleBoard')
local Hex=require('Game.Map.HexGrid')
local movement=CS.ProjectY.Data.BattleMovement
local animals=require('Game.Animals.AnimalRules').New(config)
local function actor(id,team,q,r)
    local unit={Id=id,TemplateId=1,Team=team,Q=q,R=r,HP=40,AP=0,Guard=0,Moved=false,MainUsed=false,AnimalOwnerId=0}
    function unit:BeginTurn(points)self.AP=points;self.Guard=0;self.Moved=false;self.MainUsed=false;self.movementSpent=0 end
    unit.BeginDeploymentTurn=unit.BeginTurn
    function unit:SpendAction(kind,cost)
        assert(self.AP>=cost);self.AP=self.AP-cost;self.Moved=true
        if kind=='main' then self.MainUsed=true end
    end
    return unit
end
local function scenario(board,range,points,enemyQ,enemyR)
    local hero,enemy=actor(1,1,0,0),actor(2,2,enemyQ or -1,enemyR or 1)
    local units={hero,enemy};local order={1,2}
    local battle=require('Game.Battle.BattleSystem')()
    battle.board=board;battle.preparationRules=config:GetTable('BattlePreparationTable'):Get(1)
    battle.stats={animals=animals,Template=function()return {name='测试角色',moveRange=range,moveCost=1,actionPoints=points}end,
        buffs={Skipping=function()return nil end},Get=function(_,unit)return unit.Team==1 and 10 or 1 end}
    battle.data={Phase='combat',Winner='',ActiveId=1,UnitCount=2,TurnCount=2,TurnIndex=0,Round=1,MaxRounds=10,
        GetUnitAt=function(_,index)return units[index+1]end,GetTurnAt=function(_,index)return order[index+1]end,
        AddLog=function()end,SelectTurn=function(self,index)self.ActiveId=order[index+1];self.TurnIndex=index end,
        BeginDeployment=function(self)self.Phase='deployment';order={};self.TurnCount=0 end,
        AddTurn=function(self,id)order[#order+1]=id;self.TurnCount=#order end}
    battle.Changed={Emit=function()end};battle.gameEffects={TickActor=function()end}
    battle:BeginTurn(0)
    return battle,hero
end
local function state(unit)
    return table.concat({unit.Q,unit.R,unit.AP,movement.Spent(unit),tostring(unit.Moved),tostring(unit.MainUsed)},':')
end
local function includes(cells,q,r)
    for _,cell in ipairs(cells)do if cell.q==q and cell.r==r then return true end end
    return false
end

local battle,hero=scenario(Board.Create(5,93,0),4,1)
local before=state(hero)
assert(not battle:TryMove(-1,1),'Occupied target must be rejected')
assert(not battle:TryMove(9,9),'Outside target must be rejected')
assert(not battle:TryMove(0,0),'Standing still is not a movement segment')
assert(state(hero)==before)
assert(battle:TryMove(1,0) and hero.AP==0 and movement.Spent(hero)==1 and not hero.Moved)
assert(battle:TryMove(3,0) and hero.AP==0 and movement.Spent(hero)==3 and not hero.Moved)
before=state(hero)
assert(not battle:TryMove(5,0) and state(hero)==before,'Rejected over-budget segment must be atomic')
local reachable,distance=battle:Reachable()
assert(includes(reachable,4,0) and distance[battle.board:Find(4,0)]==1)
assert(battle:TryMove(4,0) and hero.AP==0 and movement.Spent(hero)==4 and hero.Moved)
assert(#battle:Reachable()==0 and not battle:TryMove(3,0))
print('PASS segments accumulate shortest-path distance, charge movement AP once, and reject occupied/outside/over-budget targets atomically')

battle:BeginTurn(0)
assert(hero.AP==1 and movement.Spent(hero)==0 and not hero.Moved)
before=state(hero)
-- Selection and cancellation do not issue TryMove: repeated reachable queries must be pure.
for _=1,3 do assert(#battle:Reachable()>0)end
assert(state(hero)==before,'Previewing/cancelling without a move command cannot spend movement')
hero:SpendAction('secondary',1)
assert(hero.Moved and #battle:Reachable()==0 and not battle:TryMove(3,0))
battle:BeginTurn(0)
assert(hero.AP==1 and not hero.Moved and movement.Spent(hero)==0 and #battle:Reachable()>0)
hero.AP=0;before=state(hero)
assert(#battle:Reachable()==0 and not battle:TryMove(3,0) and state(hero)==before,'Initial movement still needs its AP cost')
print('PASS movement previews are read-only, a completed action closes movement, and the next turn restores budget')

local deployment,scout=scenario(Board.Create(5,94,0),5,4)
deployment:BeginDeployment()
assert(deployment:TryMove(1,0) and deployment:TryMove(2,0))
assert(movement.Spent(scout)==2 and scout.AP==3)
local origin=deployment.board.deploymentOrigins[scout.Id]
assert(origin.q==0 and origin.r==0)
for _,cell in ipairs(deployment:Reachable())do
    assert(Hex.Distance(origin.q,origin.r,cell.q,cell.r)<=deployment.preparationRules.deploymentRadius)
end
before=state(scout)
assert(not deployment:TryMove(3,0) and state(scout)==before,'Deployment radius must not follow each segment origin')
assert(deployment:TryMove(0,0) and movement.Spent(scout)==4 and scout.AP==3)
print('PASS deployment segments share one budget while retaining the original deployment-radius boundary')

local Layout=require('Game.MapArea.MapAreaLayout')
local base=Layout.New({id=999,name='移动费用走廊',areaType='Dungeon',width=7,height=2,
    hexRadius=1,visionRadius=8,moveStepSeconds=.1},1,{},nil)
for _,cell in ipairs(base.cells)do cell.height=0;cell.blocked=cell.r~=0;cell.blocksSight=false end
base:Find(6,1).blocked=false
local placed={}
placed[base:Find(1,0).index]={SkillId=303}
placed[base:Find(2,0).index]={SkillId=303}
placed[base:Find(4,0).index]={SkillId=305}
placed[base:Find(5,0).index]={SkillId=306}
local construction={definitions=config:GetTable('ConstructionTable'),Record=function(_,_,index)return placed[index]end}
local area=require('Game.MapArea.ConstructionTerrain').Wrap(base,construction,1)
assert(area:MoveCost(area:Find(0,0),area:Find(1,0))==2)
assert(area:MoveCost(area:Find(1,0),area:Find(2,0))==1)
assert(area:MoveCost(area:Find(2,0),area:Find(3,0))==2)
assert(area:MoveCost(area:Find(3,0),area:Find(4,0))==2)
assert(area:MoveCost(area:Find(4,0),area:Find(5,0))==3)
local terrain,climber=scenario(Board.FromArea(area,0,0,8,0),10,4,6,1)
local cells,costs=terrain:Reachable()
assert(includes(cells,5,0) and costs[terrain.board:Find(5,0)]==10 and not includes(cells,6,0))
assert(terrain:TryMove(1,0) and movement.Spent(climber)==2 and climber.AP==3)
assert(terrain:TryMove(3,0) and movement.Spent(climber)==5 and climber.AP==3)
assert(terrain:TryMove(4,0) and movement.Spent(climber)==7 and climber.AP==3)
before=state(climber)
assert(not terrain:TryMove(6,0) and state(climber)==before)
assert(terrain:TryMove(5,0) and movement.Spent(climber)==10 and climber.Moved and climber.AP==3)
print('PASS actual platform ascent/descent, same-height deck, pit and trench costs accumulate across segments')
config:OnShutdown()

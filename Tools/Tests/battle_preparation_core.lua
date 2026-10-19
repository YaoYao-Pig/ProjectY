-- Targeted native Lua checks. Export configuration before running; no Editor is required.
package.path='Lua/?.lua;'..package.path
assert(loadfile('Tools/Tests/battle_movement_fixture.lua'))()
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=f:read('*a');f:close();return bytes
end}})
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local Hex=require('Game.Map.HexGrid')
local function effects()
    local c={Count=0,rows={},nextId=1}
    function c:GetAt(i)return self.rows[i+1]end
    function c:Find(id)for _,e in ipairs(self.rows)do if e.EffectId==id then return e end end end
    function c:Add(id,source,name,amount,duration)
        local e={Id=self.nextId,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.nextId=self.nextId+1;self.rows[#self.rows+1]=e;self.Count=#self.rows;return e
    end
    function c:Refresh(id,source,name,amount,duration)
        for _,e in ipairs(self.rows)do if e.Id==id then e.SourceId=source;e.SourceName=name;e.Amount=amount;e.Remaining=duration;e.Elapsed=0;return end end
        error('Missing effect')
    end
    function c:Advance(id,period)
        for _,e in ipairs(self.rows)do if e.Id==id then e.Elapsed=period>0 and (e.Elapsed+1)%period or 0;if e.Remaining>0 then e.Remaining=e.Remaining-1 end;return end end
        error('Missing effect')
    end
    function c:Remove(id)for i,e in ipairs(self.rows)do if e.Id==id then table.remove(self.rows,i);self.Count=#self.rows;return end end;error('Missing effect')end
    return c
end
local function actor(id,template,team,q,r,preparation)
    local a={Id=id,TemplateId=template,Team=team,Q=q,R=r,HP=40,MaxHP=40,AP=0,Guard=0,Moved=false,MainUsed=false,AnimalOwnerId=0,TraitCount=0,Effects=effects(),Growth=EmptyGrowth()}
    a.Growth.SkillCount=preparation and 1 or 0;function a.Growth:GetSkillAt()return preparation end
    function a:GetCooldown()return 0 end
    function a:SetCooldown()end
    function a:RecordAction()end
    function a:BeginDeploymentTurn(points)self.AP=points;self.Guard=0;self.Moved=false;self.MainUsed=false;self.movementSpent=0 end
    function a:BeginTurn(points)self:BeginDeploymentTurn(points)end
    function a:SpendAction(kind,cost)assert(self.AP>=cost);self.AP=self.AP-cost;self.Moved=true;if kind=='main'then self.MainUsed=true end end
    function a:Move(q,r,cost)self.Q=q;self.R=r;self.AP=self.AP-cost;self.Moved=true end
    function a:SetMaxHP(max)self.HP=math.max(1,math.min(max,self.HP+max-self.MaxHP));self.MaxHP=max end
    function a:Heal(amount)local applied=math.min(self.MaxHP-self.HP,amount);self.HP=self.HP+applied;return applied end
    return a
end
local inventory={counts={[91]=2,[92]=1},WearableCount=0}
function inventory:Equipped()return nil end
function inventory:Offhand()return nil end
function inventory:Worn()return nil end
function inventory:CountItem(id)return self.counts[id]or 0 end
function inventory:ConsumeStack(id,count)assert(self:CountItem(id)>=count);self.counts[id]=self.counts[id]-count end
local battle=require('Game.Battle.BattleSystem')()
battle.stats=require('Game.Battle.CombatStats')(config,inventory)
battle.skills=config:GetTable('CombatSkillTable');battle.effects=config:GetTable('CombatEffectTable')
battle.encounters=config:GetTable('CombatEncounterTable');battle.consumables=config:GetTable('ConsumableTable')
battle.preparationRules=config:GetTable('BattlePreparationTable'):Get(1)
battle.Changed={Emit=function()end}
battle.gameEffects=require('Game.Battle.GameEffects').New(battle.stats,battle.effects,function(...)battle:Emit(...)end)
battle.board=require('Game.Battle.BattleBoard').Create(4,123,0)
local units={actor(1,1,1,-3,0,401),actor(2,2,1,-3,2,402),actor(101,4,2,3,0)}
for _,a in ipairs(units)do a:SetMaxHP(battle.stats:MaximumHP(a));a.HP=a.MaxHP end
local order,logs={},{}
battle.data={Phase='idle',Round=0,MaxRounds=3,EncounterId=1,Winner='',UnitCount=#units,TurnCount=0,TurnIndex=0,LogCount=0}
local d=battle.data
function d:GetUnitAt(i)return units[i+1]end
function d:GetTurnAt(i)return order[i+1]end
function d:AddLog(message)logs[#logs+1]=message;self.LogCount=#logs end
function d:GetLogAt(i)return logs[i+1]end
function d:BeginDeployment()assert(self.Phase=='idle');self.Phase='deployment';order={};self.TurnCount=0 end
function d:BeginRound()self.Phase='combat';self.Round=self.Round+1;order={};self.TurnCount=0 end
function d:AddTurn(id)order[#order+1]=id;self.TurnCount=#order end
function d:SelectTurn(i)self.ActiveId=order[i+1];self.TurnIndex=i end
function d:Finish(winner)self.Winner=winner;self.Phase='ended'end
local worldRounds=0;battle.board.onRoundCompleted=function()worldRounds=worldRounds+1 end
local count=0;local function test(name,run)run();count=count+1;print('PASS '..name)end
test('deployment has only allies, independent AP and no enemy turn',function()
    battle:BeginDeployment();assert(d.Phase=='deployment'and d.Round==0 and d.TurnCount==2)
    assert(battle:Active().Id==2 and battle:Active().AP==4 and units[3].AP==0)
    assert(not battle:StepAI());local before=battle:Active().AP
    assert(not battle:TrySkill(2,101)and battle:Active().AP==before)
    assert(not battle:Active().Moved and #battle:Reachable()>0,'Rejected cast must keep movement available')
end)
test('deployment segments respect origin radius and share the turn movement budget',function()
    local a=battle:Active();local reachable=battle:Reachable();assert(#reachable>0)
    for _,cell in ipairs(reachable)do assert(Hex.Distance(-3,2,cell.q,cell.r)<=2)end
    assert(not battle:TryMove(0,2));local cell=reachable[1];assert(battle:TryMove(cell.q,cell.r))
    assert(a.AP==3 and not a.Moved and CS.ProjectY.Data.BattleMovement.Spent(a)>0)
    for _,nextCell in ipairs(battle:Reachable())do assert(Hex.Distance(-3,2,nextCell.q,nextCell.r)<=2)end
end)
test('preparation and consumables share AP without granting item skills',function()
    local a=battle:Active();a.HP=a.HP-15
    assert(battle:TrySkill(402,a.Id));assert(a.AP==1 and a.MainUsed and a.Effects:Find(402).Remaining==1)
    assert(a.Moved and #battle:Reachable()==0,'Successfully cast skill must close the remaining movement budget')
    assert(not battle:TrySkill(701,a.Id));assert(battle:TryItem(91));assert(a.AP==0 and inventory:CountItem(91)==1 and a.HP==a.MaxHP-3)
    local hp=a.HP;assert(not battle:TryItem(91));assert(a.HP==hp and inventory:CountItem(91)==1)
end)
test('deployment does not tick buffs or world time; formal AP is fresh',function()
    assert(battle:EndTurn());assert(battle:Active().Id==1 and d.Phase=='deployment')
    assert(units[2].Effects:Find(402).Remaining==1 and worldRounds==0)
    assert(battle:TrySkill(401,1));assert(battle:EndTurn())
    assert(d.Phase=='combat'and d.Round==1 and worldRounds==0 and battle:Active().Id==2)
    assert(units[2].AP==4 and not units[2].Moved and not units[2].MainUsed and units[2].Effects:Find(402))
    assert(not battle:TrySkill(402,2));assert(battle:EndTurn());assert(not units[2].Effects:Find(402))
end)
test('HUD phase, preparation skills and real consumable counts are read-only',function()
    local view=require('Game.Battle.BattleHUDModel').Build(battle,{PartyCount=2,GetPartyAt=function(_,i)return units[i+1]end})
    assert(view.phase=='combat'and #view.items==2 and view.items[1].count==1)
    for _,skill in ipairs(view.skills)do assert(skill.id~=401 and skill.id~=402 and skill.id~=701)end
end)
test('a completed combat round advances time once; draw cleanup removes preparation effects',function()
    while d.Round==1 do assert(battle:EndTurn())end
    assert(worldRounds==1 and d.Round==2)
    while d.Winner==''do assert(battle:EndTurn())end
    assert(d.Winner=='draw'and d.Phase=='ended'and units[1].Effects.Count==0 and units[2].Effects.Count==0)
end)
config:OnShutdown();print('Battle preparation: '..count..' checks passed')

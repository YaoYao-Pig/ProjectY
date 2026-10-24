-- Targeted native Lua checks for pairwise diplomacy, independent AI and battle presentation.
package.path='Lua/?.lua;'..package.path
local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local Gear=assert(loadfile('Tools/Tests/equipment_read_fixture.lua'))()
assert(loadfile('Tools/Tests/battle_movement_fixture.lua'))()
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local Battle=require('Game.Battle.BattleSystem')
local function unit(id,team,q,r)
    local actor={Id=id,TemplateId=3,Team=team,Q=q,R=r,HP=30,MaxHP=40,AP=8,Guard=0,MainUsed=false,Moved=false,
        AnimalOwnerId=0,TraitCount=0,Growth=EmptyGrowth(),Effects={Count=0,Find=function()return nil end}}
    function actor:GetCooldown()return 0 end
    function actor:BeginDeploymentTurn(points)self.AP=points end
    function actor:SpendAction(kind,cost)self.AP=self.AP-cost;self.MainUsed=kind=='main';self.Moved=true end
    function actor:SetCooldown()end
    function actor:RecordAction()end
    return actor
end
local function fixture()
    local area=require('Game.MapArea.MapAreaLayout').New({id=999,name='Sides',areaType=1,width=12,height=12,
        hexRadius=1,visionRadius=9,moveStepSeconds=.1},123,{}, {wallHeight=3})
    for _,cell in ipairs(area.cells) do cell.blocked=false;cell.blocksSight=false;cell.height=0 end
    local board=require('Game.Battle.BattleBoard').FromArea(area,5,5,8)
    board.sideRelations={
        [1]={[2]='hostile',[3]='hostile',[4]='allied',[5]='neutral'},
        [2]={[1]='hostile',[3]='hostile',[4]='hostile'},
        [3]={[1]='hostile',[2]='hostile'},
        [4]={[1]='allied',[2]='hostile',[5]='allied'},
        [5]={[1]='neutral',[4]='allied'},
    }
    board.primaryEnemyTeam=2
    local units={unit(1,1,3,4),unit(101,2,5,4),unit(102,3,6,4),unit(103,4,4,4),unit(104,5,4,5)}
    local weapons={};for _,actor in ipairs(units) do weapons[actor.Id]=Gear(actor.Id,1,actor.Id) end
    local inventory={WearableCount=0,Equipped=function(_,id)return weapons[id]end,
        Offhand=function()return nil end,Worn=function()return nil end,CountItem=function()return 0 end}
    local battle=Battle();battle.board=board
    battle.stats=require('Game.Battle.CombatStats')(config,inventory)
    battle.skills=config:GetTable('CombatSkillTable');battle.encounters=config:GetTable('CombatEncounterTable')
    battle.consumables=config:GetTable('ConsumableTable');battle.preparationRules=config:GetTable('BattlePreparationTable'):Get(1)
    battle.Changed={Emit=function()end};battle.gameEffects={Clear=function()end}
    local order={}
    local data={Phase='combat',Winner='',ActiveId=1,Round=1,MaxRounds=10,EncounterId=1,
        UnitCount=#units,TurnCount=0,TurnIndex=0,LogCount=0}
    function data:GetUnitAt(index)return units[index+1]end
    function data:AddLog()end
    function data:Finish(winner)assert(self.Winner=='');self.Winner=winner;self.Phase='ended'end
    function data:Reset(id,maximum)
        units={};order={};self.UnitCount=0;self.TurnCount=0;self.Phase='idle';self.Round=0;self.Winner=''
        self.EncounterId=id;self.MaxRounds=maximum
    end
    function data:SetRandomSeed(seed)assert(seed>0)end
    function data:AddUnit(actor,team,q,r)
        actor.Team=team;actor.Q=q;actor.R=r;units[#units+1]=actor;self.UnitCount=#units
    end
    function data:BeginDeployment()self.Phase='deployment';order={};self.TurnCount=0 end
    function data:AddTurn(id)order[#order+1]=id;self.TurnCount=#order end
    function data:GetTurnAt(index)return order[index+1]end
    function data:SelectTurn(index)self.ActiveId=order[index+1];self.TurnIndex=index end
    battle.data=data
    return battle,units
end
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end

test('pairwise relations are not transitive; independent sides and animals remain separate',function()
    local battle,units=fixture()
    assert(battle:IsHostile(units[1],units[2]) and battle:IsHostile(2,3))
    assert(battle:IsAllied(1,4) and battle:IsAllied(4,5) and not battle:IsAllied(1,5))
    assert(not battle:IsHostile(1,5) and not battle:IsHostile(1,0) and not battle:IsHostile(0,2))
    assert(not battle:IsAllied(1,3),'Enemies of an enemy must not merge')
    battle.board.sideRelations=nil
    assert(battle:IsHostile(1,2) and battle:IsAllied(1,1) and not battle:IsHostile(1,0))
end)

test('display color does not confer player control or hide independent hostility',function()
    local battle,units=fixture()
    assert(battle:PresentationTeam(units[1])==1 and battle:PresentationTeam(units[2])==2)
    assert(battle:PresentationTeam(units[3])==3 and battle:IsHostile(1,units[3]))
    assert(battle:PresentationTeam(units[4])==4 and units[4].Team==4)
    assert(battle:PresentationTeam(units[5])==3)
    local playerOrder=battle:TurnOrder(true);assert(#playerOrder==1 and playerOrder[1].Id==1)
    battle.data.ActiveId=units[4].Id
    local hud=require('Game.Battle.BattleHUDModel').Build(battle,{PartyCount=1,GetPartyAt=function()return units[1]end})
    assert(not hud.player and not hud.moveAvailable)
end)

test('attacks and healing use actual relations including non-player allies',function()
    local battle,units=fixture()
    assert(battle:CanUseSkill(3,units[2].Id) and battle:CanUseSkill(3,units[3].Id))
    assert(not battle:CanUseSkill(3,units[4].Id) and not battle:CanUseSkill(3,units[5].Id))
    assert(battle:CanUseSkill(5,units[4].Id) and not battle:CanUseSkill(5,units[5].Id))
    battle.data.ActiveId=units[4].Id
    assert(battle:CanUseSkill(5,units[1].Id) and battle:CanUseSkill(3,units[2].Id))
    assert(not battle:CanUseSkill(3,units[3].Id))
end)

test('allied and independent AI choose their own valid enemies; neutral sides do not fight',function()
    local battle,units=fixture();local attacked,ended
    function battle:TrySkill(id,target)if id==3 then attacked=target end;return true end
    function battle:EndTurn()ended=true;return true end
    -- Skip the opportunistic disarm without replacing the actual relation/range checks for attacks.
    local canUse=battle.CanUseSkill
    function battle:CanUseSkill(id,target)if id==501 or id==503 then return false end;return canUse(self,id,target)end
    battle.data.ActiveId=units[4].Id;assert(battle:StepAI() and ended and attacked==units[2].Id)
    ended,attacked=false,nil;battle.data.ActiveId=units[3].Id
    assert(battle:StepAI() and ended and attacked==units[2].Id,'The closer enemy side should be chosen before the player')
    ended,attacked=false,nil;battle.data.ActiveId=units[5].Id
    assert(battle:StepAI() and ended and attacked==nil)
    battle.data.ActiveId=1;assert(not battle:StepAI())
end)

test('multi-target attacks exclude allied and neutral sides before spending the action',function()
    local battle,units=fixture();local selected={};local consumed=0
    local skill=battle:Skill(units[1],3);skill.maxTargets=4;skill.splashRadius=3;skill.effectIds={3}
    function battle:Skill()return skill end
    function battle.stats.equipment:Consume()consumed=consumed+1 end
    function battle.gameEffects:Prepare(_,source,target)return {source=source,target=target}end
    function battle:ApplyEffectProgram(_,_,program)
        for _,effect in ipairs(program)do selected[#selected+1]=effect.target.Id end
    end
    assert(battle:TrySkill(3,units[2].Id) and consumed==1 and #selected==2)
    assert(selected[1]==units[2].Id and selected[2]==units[3].Id)
    units[1].MainUsed=false;skill.manualTargets=true;selected={}
    local ap=units[1].AP
    assert(not battle:TrySkillTargets(3,{units[2].Id,units[4].Id}) and units[1].AP==ap and consumed==1)
end)

test('victory ignores neutrals but requires every hostile side; allies cannot replace a dead player',function()
    local battle,units=fixture();units[2].HP=0
    assert(not battle:CheckWinner(),'A hostile third party still has living members')
    units[3].HP=0;assert(battle:CheckWinner() and battle.data.Winner=='victory')
    assert(battle:CheckWinner(),'Repeated winner queries must not settle twice')
    battle,units=fixture();units[1].HP=0
    assert(battle:CheckWinner() and battle.data.Winner=='defeat' and units[4].HP>0)
end)

test('original positions and more than four independent AI participants survive StartArea',function()
    local battle,units=fixture();local opponents={units[2],units[3],units[4],units[5],unit(105,64,7,4)}
    local board=battle.board
    battle:StartArea(1,board,{{actor=units[1],q=3,r=4}},opponents)
    assert(battle.data.UnitCount==6 and battle.data.TurnCount==1 and battle.data.Phase=='deployment')
    for i,actor in ipairs(opponents)do
        assert(battle:FindUnit(actor.Id)==actor and actor.Team==({2,3,4,5,64})[i])
    end
    assert(not battle:StepAI())
end)

test('projectile warnings recognize cross-side allies and actual interception geometry',function()
    local battle,units=fixture()
    -- For direct shots, adjacent cover is ignored: move the ally two hexes from the shooter.
    units[1].Q=2;units[2].Q=5;units[4].Q=4
    local skill=battle:Skill(units[1],3);skill.trajectory='direct'
    local profile=require('Game.Battle.ProjectileCombat').Profile(battle,units[1],skill,battle.board:Find(5,4),nil,units[2])
    assert(profile.friendlyRisk and profile.blockerCount==1)
    battle.board.sideRelations[1][4]='neutral'
    profile=require('Game.Battle.ProjectileCombat').Profile(battle,units[1],skill,battle.board:Find(5,4),nil,units[2])
    assert(not profile.friendlyRisk and profile.blockerCount==1)
end)

config:OnShutdown()
print('PASS battle sides: '..count..' focused checks')

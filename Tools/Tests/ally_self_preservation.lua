-- Real battle reachability, relations, equipment budgets and guard effects; native state is isolated.
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
    local actor={Id=id,TemplateId=1,Team=team,Q=q,R=r,HP=40,MaxHP=40,AP=4,Guard=0,MainUsed=false,Moved=false,
        AnimalOwnerId=0,AnimalSpeciesId=0,TraitCount=0,Growth=EmptyGrowth(),Effects={Count=0,Find=function()end}}
    function actor:GetCooldown()return 0 end
    function actor:SpendAction(kind,cost)self.AP=self.AP-cost;self.MainUsed=kind=='main' or self.MainUsed;self.Moved=true end
    function actor:SetGuard(amount)self.Guard=amount end
    function actor:SetCooldown()end
    function actor:RecordAction()end
    return actor
end
local function fixture()
    local player,ally,enemy=unit(1,1,-3,0),unit(20,4,0,0),unit(30,2,3,0)
    ally.HP=20
    local units={player,ally,enemy};local weapons={}
    for _,actor in ipairs(units)do weapons[actor.Id]=Gear(actor.Id,40,actor.Id)end
    local inventory={WearableCount=0,Equipped=function(_,id)return weapons[id]end,
        Offhand=function()end,Worn=function()end,CountItem=function()return 0 end}
    local battle=Battle();battle.board=require('Game.Battle.BattleBoard').Create(6,881,0)
    for _,cell in ipairs(battle.board.cells)do cell.blocked=false;cell.blocksSight=false;cell.height=0 end
    battle.board.sideRelations={[1]={[4]='allied',[2]='hostile'},[4]={[1]='allied',[2]='hostile'},[2]={[1]='hostile',[4]='hostile'}}
    battle.board.aiProfiles={[ally.Id]={selfPreservation=true,retreatHealthRatio=.5}}
    battle.stats=require('Game.Battle.CombatStats')(config,inventory)
    battle.skills=config:GetTable('CombatSkillTable');battle.effects=config:GetTable('CombatEffectTable')
    battle.data={Phase='combat',Winner='',ActiveId=ally.Id,Round=1,UnitCount=#units}
    function battle.data:GetUnitAt(index)return units[index+1]end
    function battle.data:AddLog()end
    function battle.data:RollPercent()error('Guard and retreat must not consume random rolls')end
    local events={};battle.Changed={Emit=function(_,event)events[#events+1]=event end}
    battle.gameEffects=require('Game.Battle.GameEffects').New(battle.stats,battle.effects,function(...)battle:Emit(...)end)
    function battle:EndTurn()self.ends=(self.ends or 0)+1;self.data.ActiveId=player.Id;return true end
    return battle,ally,player,enemy,events,units
end
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end

test('injured ally approaches support, preserves hostile distance, and applies real guard after moving',function()
    local battle,ally,player,enemy,events=fixture()
    assert(battle:StepAI())
    assert(battle.stats.animals:Distance(ally,player,battle.board)<3)
    assert(battle.stats.animals:Distance(ally,enemy,battle.board)>=3)
    assert(ally.Guard==3 and ally.AP==2 and not ally.MainUsed and ally.Team==4 and battle.ends==1)
    assert(events[1].kind=='moved' and events[2].kind=='guard')
end)

test('engaged ally guards in place instead of provoking an opportunity attack',function()
    local battle,ally,player,enemy=fixture();enemy.Q=1
    assert(#battle:OpportunityAttackers(ally)==1)
    assert(battle:StepAI() and ally.Q==0 and ally.R==0 and ally.Guard==3 and ally.HP==20 and ally.AP==3)
end)

test('ally does not move closer to the enemy to reach support behind enemy lines',function()
    local battle,ally,player=fixture();player.Q=4
    assert(battle:StepAI() and ally.Q==0 and ally.R==0 and ally.Guard==3)
end)

test('dead support is ignored and the ally still guards',function()
    local battle,ally,player,enemy,events,units=fixture();player.HP=0
    -- The only living support is beyond the enemy; the nearby corpse must not attract retreat.
    units[#units+1]=unit(2,1,4,0);battle.data.UnitCount=#units
    assert(battle:StepAI() and ally.Q==0 and ally.R==0 and ally.Guard==3)
end)

test('movement cannot spend the last AP needed to guard and exhausted actors simply end',function()
    local battle,ally=fixture();ally.AP=1
    assert(battle:StepAI() and ally.Q==0 and ally.R==0 and ally.Guard==3 and ally.AP==0)
    battle,ally=fixture();ally.AP=0
    assert(battle:StepAI() and ally.Q==0 and ally.R==0 and ally.Guard==0 and battle.ends==1)
end)

test('profiles preserve normal combat for healthy allies, unprofiled units, and hostile sides',function()
    for _,mode in ipairs({'healthy','unprofiled','hostile'})do
        local battle,ally,player,enemy=fixture();enemy.Q=1;local target=enemy.Id
        if mode=='healthy' then ally.HP=21
        elseif mode=='unprofiled' then battle.board.aiProfiles=nil
        else ally.Team=2;player.Q=-1;target=player.Id end
        local attacked
        function battle:TrySkill(id,targetId)
            if self:Skill(ally,id).target=='enemy' then attacked=targetId end
            return true
        end
        local canUse=battle.CanUseSkill
        function battle:CanUseSkill(id,targetId)if id==501 or id==503 then return false end;return canUse(self,id,targetId)end
        assert(battle:StepAI() and attacked==target and battle.ends==1,mode)
    end
end)

test('retreat cannot act on a different actor after the movement hands off the turn',function()
    local battle,ally,player=fixture();local tryMove=battle.TryMove
    function battle:TryMove(q,r)local ok=tryMove(self,q,r);self.data.ActiveId=player.Id;return ok end
    assert(battle:StepAI() and ally.Q~=0 and ally.Guard==0 and battle.ends==nil)
end)

test('policy rejects invalid threshold and never allows player AI control',function()
    local battle,ally,player=fixture();battle.board.aiProfiles[ally.Id].retreatHealthRatio=0
    local ok,err=pcall(function()battle:StepAI()end)
    assert(not ok and tostring(err):find('retreatHealthRatio',1,true))
    battle.data.ActiveId=player.Id;battle.board.aiProfiles[player.Id]={selfPreservation=true,retreatHealthRatio=1}
    assert(not battle:StepAI() and battle.ends==nil)
end)

config:OnShutdown()
print('PASS ally self-preservation: '..count..' focused checks')

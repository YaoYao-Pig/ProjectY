-- Actual movement, opportunity attacks and turn hand-off, isolated from the running campaign.
local registry=require('Core.SystemRegistry')(Services)
registry:Register('Config',require('Config.ConfigSystem'))
registry:Register('Battle',require('Game.Battle.BattleSystem'),{'Config'})
registry:Register('Equipment',require('Game.Equipment.EquipmentSystem'),{'Config'})
local ok,result=xpcall(function()
    registry:Start()
    local battle,equipment=registry:Get('Battle'),registry:Get('Equipment');local data=Services.Adventure
    data:Reset(441);equipment:Start()
    local actor=data:AddPartyActor(1,1);battle.stats.birth:Initialize(actor,441)
    actor:SetMaxHP(1000);actor:Restore() -- Large fixture health isolates movement from lethal-hit randomness.
    battle.data:Reset(1,20);battle.board=require('Game.Battle.BattleBoard').Create(5,441,0)
    battle.data:AddUnit(actor,1,0,0)
    local enemy=battle.data:AddEnemy(92002,4,1,0);battle.stats.birth:Initialize(enemy,441)
    enemy:SetMaxHP(battle.stats:MaximumHP(enemy));enemy:Restore();equipment:InitializeEnemy(enemy)
    battle:Emit('battle_started','Morale flight fixture')
    battle.data:BeginDeployment();battle.data:BeginRound();battle.data:AddTurn(actor.Id);battle.data:AddTurn(enemy.Id)
    battle.data:SelectTurn(0);actor:BeginTurn(battle.stats:Template(actor).actionPoints)
    battle.spellcasting:BindBoard(battle)
    local state=CS.ProjectY.Data.MoraleState
    state.Set(actor,state.Maximum(actor),0,-3)
    local skill=battle:Skill(actor,battle:SkillIds(actor)[1])
    assert(not battle:ActionBudget(skill),'Fleeing actor could use an action')
    assert(not battle:TryMove(-1,0),'Fleeing actor could select a manual destination')
    assert(not require('Game.Battle.OpportunityAttacks').Skill(battle,actor,enemy),'Fleeing actor could make an opportunity attack')
    local reactions=0
    local unsubscribe=battle.Changed:Subscribe(function(event)if event.kind=='opportunity_attack'then reactions=reactions+1 end end)
    local reachable=#battle:Reachable()
    local move=battle.TryMove;local moveReason
    function battle:TryMove(q,r,retreat)
        local before=self.stats:MoveRange(actor,self.stats:Template(actor))
        local success,why=move(self,q,r,retreat)
        moveReason=tostring(why)..' target='..q..','..r..' range='..before..'/'..self.stats:MoveRange(actor,self.stats:Template(actor))..' available='..#self:Reachable()..' moved='..tostring(actor.Moved)..' AP='..actor.AP
        return success,why
    end
    battle.morale:Flee(battle,actor);unsubscribe()
    local logs={};for i=0,battle.data.LogCount-1 do logs[#logs+1]=battle.data:GetLogAt(i)end
    assert(require('Game.Map.HexGrid').Distance(actor.Q,actor.R,enemy.Q,enemy.R)>1,
        'Automatic flight did not move away: reason='..tostring(moveReason)..' reachable='..reachable..' hp='..actor.HP..' q='..actor.Q..' r='..actor.R..' reactions='..reactions..' logs='..table.concat(logs,' | '))
    assert(battle.data.ActiveId==enemy.Id and reactions==1,'Flight must provoke one opportunity attack, replan after the reduced range and pass the turn')
    battle:ClearBattleEffects();assert(not state.Active(actor) and not state.Active(enemy),'Battle cleanup retained morale')
    return 'PASS actual battle: fleeing blocks manual moves/actions/reactions, automatically moves away, receives opportunity attacks and hands off the turn'
end,debug.traceback)
registry:Shutdown();if not ok then error(result,0)end
return result

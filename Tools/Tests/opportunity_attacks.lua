-- Real battle, equipment, effect and footprint rules; only native mutable state is isolated.
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
local Board=require('Game.Battle.BattleBoard')
local movement=CS.ProjectY.Data.BattleMovement
local function effects()
    local collection={Count=0,rows={},nextId=1}
    function collection:GetAt(index)return assert(self.rows[index+1])end
    function collection:Find(effectId)
        for _,row in ipairs(self.rows)do if row.EffectId==effectId then return row end end
    end
    function collection:Require(id)
        for _,row in ipairs(self.rows)do if row.Id==id then return row end end;error('Unknown effect instance')
    end
    function collection:Add(id,source,name,amount,duration)
        local row={Id=self.nextId,EffectId=id,SourceId=source,SourceName=name,Amount=amount,Remaining=duration,Elapsed=0,Stacks=1}
        self.nextId=self.nextId+1;self.rows[#self.rows+1]=row;self.Count=#self.rows;return row
    end
    function collection:Refresh(id,source,name,amount,duration,maximum,stack)
        local row=self:Require(id);row.SourceId=source;row.SourceName=name;row.Amount=amount;row.Remaining=duration;row.Elapsed=0
        row.Stacks=stack and math.min(maximum,row.Stacks+1) or 1
    end
    function collection:Advance(id,period)
        local row=self:Require(id);row.Elapsed=period>0 and (row.Elapsed+1)%period or 0
        if row.Remaining>0 then row.Remaining=row.Remaining-1 end
    end
    function collection:Remove(id)
        for index,row in ipairs(self.rows)do if row.Id==id then table.remove(self.rows,index);self.Count=#self.rows;return end end
        error('Unknown removed effect')
    end
    return collection
end
CS.ProjectY.Data.GameBuffState={Configure=function(instance,ids,amounts)
    instance.amounts={};for i,id in ipairs(ids)do instance.amounts[id]=amounts[i]end
end,Amount=function(instance,id)return assert(instance.amounts[id])end}
CS.ProjectY.Data.EquipmentCombatState={
    DamageWeapon=function(inventory,id,amount)
        local item=inventory:GetWeapon(id);inventory.wearCalls=inventory.wearCalls+1
        item.condition.Current=math.max(0,item.condition.Current-amount);item.condition.Broken=item.condition.Current==0
        return amount
    end,
    DamageArmor=function()return 0 end,
    RefreshMaximum=function(actor,maximum)actor:SetMaxHP(maximum)end,
}
local function actor(id,side,q,r,template)
    local unit={Id=id,TemplateId=template or 1,Team=side,Q=q,R=r,HP=46,MaxHP=46,AP=4,Guard=0,
        MainUsed=false,Moved=false,AnimalOwnerId=0,AnimalSpeciesId=0,TraitCount=0,Growth=EmptyGrowth(),Effects=effects(),
        cooldowns={},actions={},spends=0,turns=0}
    function unit:GetCooldown(id)return self.cooldowns[id] or 0 end
    function unit:SetCooldown(id,turns)self.cooldowns[id]=turns end
    function unit:RecordAction(templateId,count,q,r)
        self.actions[#self.actions+1]={template=templateId,count=count,q=q,r=r}
    end
    function unit:SpendAction(kind,cost)
        self.spends=self.spends+1;self.AP=self.AP-cost;self.Moved=true;if kind=='main'then self.MainUsed=true end
    end
    function unit:BeginTurn(points)
        self.turns=self.turns+1;self.AP=points;self.Guard=0;self.MainUsed=false;self.Moved=false;self.movementSpent=0
    end
    unit.BeginDeploymentTurn=unit.BeginTurn
    function unit:Damage(amount)
        if self.MountedAnimal then
            local mount=self.MountedAnimal;local used=mount:Damage(amount)
            if mount.HP==0 then mount.AnimalOwnerId=0;self.MountedAnimal=nil end
            return used
        end
        local used=math.min(self.HP,amount);self.HP=self.HP-used;return used
    end
    function unit:Heal(amount)local used=math.min(self.MaxHP-self.HP,amount);self.HP=self.HP+used;return used end
    function unit:SetMaxHP(maximum)
        self.HP=self.HP==0 and 0 or math.max(1,math.min(maximum,self.HP+maximum-self.MaxHP));self.MaxHP=maximum
    end
    function unit:SetGuard(amount)self.Guard=amount end
    return unit
end
local function fixture(units)
    units=units or {actor(1,1,0,0),actor(90,2,1,0)}
    local env={units=units,events={},logs={},rollCalls=0,roll=0,weapons={},offhands={}}
    local inventory={WearableCount=0,wearCalls=0}
    function inventory:Equipped(id)return env.weapons[id]end
    function inventory:Offhand(id)return env.offhands[id]end
    function inventory:Worn()end
    function inventory:CountItem()return 0 end
    function inventory:GetWeapon(id)
        for _,item in pairs(env.weapons)do if item.Id==id then return item end end
        for _,item in pairs(env.offhands)do if item.Id==id then return item end end
        error('Unknown fixture weapon')
    end
    for _,unit in ipairs(units)do env.weapons[unit.Id]=Gear(unit.Id,40,unit.Id)end
    local battle=Battle();env.battle=battle;env.inventory=inventory
    battle.board=Board.Create(6,220,0)
    battle.skills=config:GetTable('CombatSkillTable');battle.effects=config:GetTable('CombatEffectTable')
    battle.encounters=config:GetTable('CombatEncounterTable');battle.consumables=config:GetTable('ConsumableTable')
    battle.preparationRules=config:GetTable('BattlePreparationTable'):Get(1)
    battle.stats=require('Game.Battle.CombatStats')(config,inventory)
    for _,unit in ipairs(units)do unit.MaxHP=battle.stats:MaximumHP(unit);unit.HP=unit.MaxHP end
    local order={};for _,unit in ipairs(units)do order[#order+1]=unit.Id end
    battle.data={Phase='combat',Winner='',ActiveId=units[1].Id,Round=1,MaxRounds=20,EncounterId=1,
        UnitCount=#units,TurnCount=#units,TurnIndex=0}
    function battle.data:GetUnitAt(index)return units[index+1]end
    function battle.data:GetTurnAt(index)return order[index+1]end
    function battle.data:SelectTurn(index)self.ActiveId=order[index+1];self.TurnIndex=index end
    function battle.data:AddLog(message)env.logs[#env.logs+1]=message end
    function battle.data:Finish(winner)assert(self.Winner=='');self.Winner=winner;self.Phase='ended'end
    function battle.data:RollPercent()env.rollCalls=env.rollCalls+1;return env.roll end
    battle.Changed={Emit=function(_,event)
        event.activeQ=units[1].Q;event.activeR=units[1].R;env.events[#env.events+1]=event
    end}
    battle.checks=function(...)battle:ChanceLog(...)end
    battle.gameEffects=require('Game.Battle.GameEffects').New(battle.stats,battle.effects,function(...)battle:Emit(...)end,
        {roll=function()return battle.data:RollPercent()end,
            report=function(kind,plan,details)battle:Emit(kind,details.reason or details.checkName or kind,plan.sourceId,plan.target.Id,0,plan.target,false,details)end})
    return env
end
local function selected(env,kind)
    local rows={};for _,event in ipairs(env.events)do if event.kind==kind then rows[#rows+1]=event end end;return rows
end
local function state(unit)
    return table.concat({unit.Q,unit.R,unit.HP,unit.AP,movement.Spent(unit),tostring(unit.MainUsed),tostring(unit.Moved),unit.spends,#unit.actions},':')
end
local checks=0
local function test(name,run)run();checks=checks+1;print('PASS '..name)end

test('exported ordinary-melee marker and candidate queries are explicit and read-only',function()
    local expected={[1]=true,[10]=true,[11]=true,[12]=true,[13]=true,[205]=true,[504]=true};local total=0
    for _,row in ipairs(config:GetTable('CombatSkillTable'):All())do if row.opportunityAttack then
        assert(expected[row.id],'Unexpected marked skill '..row.id);total=total+1
    end end
    assert(total==7)
    local env=fixture();local hero,enemy=env.units[1],env.units[2];local before=state(hero)..state(enemy)
    for _,skill in ipairs(env.battle.skills:All()) do require('Game.Battle.OpportunityAttacks').Validate(env.battle,skill) end
    for _=1,3 do
        local candidates=env.battle:OpportunityAttackers(hero)
        assert(#candidates==1 and candidates[1].source==enemy and candidates[1].skill.id==10)
    end
    assert(state(hero)..state(enemy)==before and env.rollCalls==0 and env.inventory.wearCalls==0 and #env.events==0 and #env.logs==0)
end)

test('reaction resolves before relocation and ignores the enemy turn budget and cooldown',function()
    local env=fixture();local hero,enemy=env.units[1],env.units[2]
    enemy.AP=0;enemy.MainUsed=true;enemy.Moved=true;enemy.movementSpent=2;enemy:SetCooldown(10,4)
    local enemyState=state(enemy);local oldHP=hero.HP;local skill=env.battle:Skill(enemy,10)
    assert(env.battle:TryMove(0,1))
    local reactions,damage,moves=selected(env,'opportunity_attack'),selected(env,'damage'),selected(env,'moved')
    assert(#reactions==1 and #damage==1 and #moves==1 and hero.HP<oldHP)
    assert(reactions[1].sourceId==enemy.Id and damage[1].sourceId==enemy.Id and damage[1].targetId==hero.Id)
    assert(damage[1].activeQ==0 and damage[1].activeR==0 and moves[1].activeQ==0 and moves[1].activeR==1)
    assert(damage[1].hpBefore==oldHP and damage[1].hpAfter==hero.HP and damage[1].attackHit)
    assert(hero.AP==3 and movement.Spent(hero)==1 and not hero.MainUsed)
    assert(enemy.AP==0 and enemy.MainUsed and enemy.Moved and movement.Spent(enemy)==2 and enemy:GetCooldown(10)==4 and enemy.spends==0)
    assert(#enemy.actions==1 and enemy.actions[1].template==skill.actionTemplate and enemy.actions[1].q==0 and enemy.actions[1].r==0)
    assert(env.weapons[enemy.Id].condition.Current==100-skill.weaponWear and env.inventory.wearCalls==1)
    assert(enemyState~=state(enemy),'The actual attack must record an action even though its turn budget remains unchanged')
    assert(env.battle.skills:Get(10).name=='单手斩击','Reaction display name mutated the shared skill configuration')
end)

test('rejected moves never roll, wear equipment, attack or spend movement',function()
    local env=fixture();local hero=env.units[1];local before=state(hero)
    for _,cell in ipairs({{0,0},{1,0},{9,9},{-4,0}})do assert(not env.battle:TryMove(cell[1],cell[2]))end
    assert(state(hero)==before)
    hero.AP=0;assert(not env.battle:TryMove(0,1));hero.AP=4
    hero.Moved=true;assert(not env.battle:TryMove(0,1));hero.Moved=false
    assert(env.rollCalls==0 and env.inventory.wearCalls==0 and #env.events==0 and #env.logs==0 and #env.units[2].actions==0)
end)

test('each legal segment rechecks adjacency, including circling before disengaging',function()
    local env=fixture();local hero=env.units[1]
    assert(env.battle:TryMove(0,1) and #selected(env,'opportunity_attack')==1)
    assert(env.battle:TryMove(-1,1) and #selected(env,'opportunity_attack')==2)
    assert(env.battle:TryMove(-2,1) and #selected(env,'opportunity_attack')==2)
    assert(hero.AP==3 and movement.Spent(hero)==3 and hero.Moved and env.inventory.wearCalls==2)
end)

test('every eligible adjacent enemy attacks once in stable actor-ID order',function()
    local env=fixture({actor(1,1,0,0),actor(90,2,1,0),actor(20,2,0,-1)})
    local candidates=env.battle:OpportunityAttackers(env.units[1])
    assert(#candidates==2 and candidates[1].source.Id==20 and candidates[2].source.Id==90)
    assert(env.battle:TryMove(0,1))
    local reactions=selected(env,'opportunity_attack')
    assert(#reactions==2 and reactions[1].sourceId==20 and reactions[2].sourceId==90)
    assert(#env.units[2].actions==1 and #env.units[3].actions==1 and #selected(env,'moved')==1)
end)

test('allies, neutrals, dead, stunned, attached, ranged and dead-zone enemies are excluded',function()
    local cases={
        function(env,enemy)enemy.Team=1 end,
        function(env,enemy)enemy.Team=0 end,
        function(env,enemy)enemy.Team=4;env.battle.board.sideRelations={[1]={[4]='neutral'},[4]={[1]='neutral'}}end,
        function(env,enemy)enemy.HP=0 end,
        function(env,enemy)enemy.Effects:Add(10006,enemy.Id,'test',0,2)end,
        function(env,enemy)enemy.AnimalOwnerId=1 end,
        function(env,enemy)env.weapons[enemy.Id]=Gear(enemy.Id,46,enemy.Id)end,
        function(env,enemy)env.weapons[enemy.Id]=Gear(enemy.Id,742,enemy.Id)end,
        function(env,enemy)enemy.Q=2 end,
    }
    for index,change in ipairs(cases)do
        local env=fixture();change(env,env.units[2]);assert(#env.battle:OpportunityAttackers(env.units[1])==0,'Eligibility case '..index)
        assert(env.battle:TryMove(0,1) and #selected(env,'opportunity_attack')==0 and env.rollCalls==0 and env.inventory.wearCalls==0)
    end
end)

test('deployment movement is safe and enemy movement receives player reactions',function()
    local env=fixture();env.battle.data.Phase='deployment';env.battle.board.deploymentOrigins={[1]={q=0,r=0}}
    assert(#env.battle:OpportunityAttackers(env.units[1])==0 and env.battle:TryMove(0,1))
    assert(env.rollCalls==0 and env.inventory.wearCalls==0 and #selected(env,'opportunity_attack')==0)
    env=fixture({actor(90,2,0,0),actor(1,1,1,0)})
    assert(env.battle:TryMove(0,1));local reactions=selected(env,'opportunity_attack')
    assert(#reactions==1 and reactions[1].sourceId==1 and reactions[1].targetId==90)
end)

test('ordinary miss still wears the weapon and allows the legal move',function()
    local env=fixture();env.roll=99;local hp=env.units[1].HP
    assert(env.battle:TryMove(0,1) and env.units[1].HP==hp and env.rollCalls==1)
    assert(#selected(env,'miss')==1 and #selected(env,'damage')==0 and #selected(env,'moved')==1 and env.inventory.wearCalls==1)
end)

test('dual wield selects one main-hand attack and empty hands retain their normal attack',function()
    local env=fixture();local enemy=env.units[2]
    env.offhands[enemy.Id]=Gear(1000,40,enemy.Id);env.offhands[enemy.Id].Hand='offhand'
    local candidates=env.battle:OpportunityAttackers(env.units[1]);assert(#candidates==1 and candidates[1].skill.id==10)
    assert(env.battle:TryMove(0,1) and #enemy.actions==1 and env.inventory.wearCalls==1 and env.offhands[enemy.Id].condition.Current==100)
    env=fixture();enemy=env.units[2];env.weapons[enemy.Id]=nil
    candidates=env.battle:OpportunityAttackers(env.units[1]);assert(#candidates==1 and candidates[1].skill.id==504)
    assert(env.battle:TryMove(0,1) and #selected(env,'damage')==1 and env.inventory.wearCalls==0)
end)

test('full multi-cell footprint establishes adjacency even when anchors are two hexes apart',function()
    local env=fixture();local enemy=env.units[2];enemy.TemplateId=401;enemy.Q=-2;enemy.R=0
    assert(env.battle.stats.animals:Distance(enemy,env.units[1],env.battle.board)==1)
    assert(#env.battle:OpportunityAttackers(env.units[1])==1)
    assert(env.battle:TryMove(0,1) and #selected(env,'opportunity_attack')==1 and #selected(env,'moved')==1)
    env=fixture();env.units[1].TemplateId=401;env.units[2].Q=2
    assert(env.battle.stats.animals:Distance(env.units[2],env.units[1],env.battle.board)==1)
    assert(#env.battle:OpportunityAttackers(env.units[1])==1,'Moving multi-cell targets must use their full footprint too')
end)

test('lethal first reaction stops later enemies and ends combat without charging movement',function()
    local env=fixture({actor(1,1,0,0),actor(90,2,1,0),actor(20,2,0,-1)});local hero=env.units[1];hero.HP=1
    local accepted,reason=env.battle:TryMove(0,1)
    assert(accepted and reason and hero.HP==0 and env.battle.data.Winner=='defeat')
    assert(hero.Q==0 and hero.R==0 and hero.AP==4 and movement.Spent(hero)==0)
    local reactions=selected(env,'opportunity_attack');assert(#reactions==1 and reactions[1].sourceId==20)
    assert(#env.units[2].actions==0 and #env.units[3].actions==1 and #selected(env,'moved')==0 and #selected(env,'battle_ended')==1)
end)

test('weapon on-hit stun interrupts the move and hands off the active turn',function()
    local env=fixture();local hero,enemy=env.units[1],env.units[2];env.weapons[enemy.Id]=Gear(enemy.Id,45,enemy.Id)
    local accepted,reason=env.battle:TryMove(0,1)
    assert(accepted and reason and hero.HP>0 and env.battle.stats.buffs:Skipping(hero))
    assert(hero.Q==0 and hero.R==0 and hero.AP==4 and movement.Spent(hero)==0 and env.battle.data.ActiveId==enemy.Id)
    assert(#selected(env,'opportunity_attack')==1 and #selected(env,'effect_added')==1 and #selected(env,'moved')==0)
    assert(env.rollCalls==2,'Ordinary hit and the weapon stun must use the existing random stream')
end)

test('defeated mount shrinks the movement budget before the original destination is committed',function()
    local env=fixture();local hero=env.units[1];local mount=actor(200,1,0,0,201)
    mount.AnimalSpeciesId=1;mount.AnimalOwnerId=hero.Id;mount.AnimalBond=0;mount.HP=1;hero.MountedAnimal=mount
    local hp=hero.HP;local accepted,reason=env.battle:TryMove(-4,0)
    assert(accepted and reason and mount.HP==0 and not hero.MountedAnimal and hero.HP==hp)
    assert(hero.Q==0 and hero.R==0 and hero.AP==4 and movement.Spent(hero)==0 and env.battle.data.ActiveId==hero.Id)
    assert(#selected(env,'opportunity_attack')==1 and #selected(env,'mount_defeated')==1 and #selected(env,'moved')==0)
end)

test('AI retreat killed by a reaction never acts on or ends the next actor turn',function()
    local mover,hero,ally=actor(90,2,0,0),actor(1,1,1,0),actor(91,2,-4,0)
    local env=fixture({mover,hero,ally});env.weapons[mover.Id]=Gear(mover.Id,742,mover.Id);mover.HP=1
    assert(env.battle:StepAI())
    assert(mover.HP==0 and env.battle.data.Winner=='' and env.battle.data.ActiveId==hero.Id)
    assert(hero.turns==1 and ally.turns==0 and hero.spends==0 and not hero.MainUsed and not hero.Moved)
    assert(#hero.actions==1 and #selected(env,'opportunity_attack')==1 and #selected(env,'moved')==0)
    for _,event in ipairs(selected(env,'turn_ended'))do assert(event.sourceId~=hero.Id,'AI ended the newly selected player turn')end
end)

test('AI command stops when turn handoff returns to the same actor in a new round',function()
    local mover,hero=actor(90,2,0,0),actor(1,1,1,0)
    local env=fixture({mover,hero});env.weapons[mover.Id]=Gear(mover.Id,742,mover.Id)
    env.weapons[hero.Id]=Gear(hero.Id,45,hero.Id)
    -- Isolate the handoff boundary: skipped intervening turns can return the same ID in a new round.
    function env.battle:AdvanceTurn()
        self.data.Round=self.data.Round+1;self.data.ActiveId=mover.Id
        mover.Effects=effects();mover:BeginTurn(self.stats:Template(mover).actionPoints)
    end
    assert(env.battle:StepAI() and env.battle.data.Round==2 and env.battle.data.ActiveId==mover.Id)
    assert(mover.HP>0 and mover.turns==1 and mover.spends==0 and #mover.actions==0)
    assert(not mover.Moved and not mover.MainUsed and movement.Spent(mover)==0)
    assert(#selected(env,'turn_ended')==1 and #selected(env,'opportunity_attack')==1)
end)

config:OnShutdown()
print('Opportunity attacks: '..checks..' focused checks passed')

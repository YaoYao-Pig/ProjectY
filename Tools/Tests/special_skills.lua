-- Real special-skill model, battle submission wrappers and visibility; native transient state is isolated.
package.path='Lua/?.lua;'..package.path
local Signal=require('Core.Signal')
local Battle=require('Game.Battle.BattleSystem')
local Board=require('Game.Battle.BattleBoard')
local Model=require('Game.Progression.SpecialSkills')
local bridge={}
local native={SpecialSkillBattleState=bridge,DeathDoorState={Alive=function(actor)return not actor.dead end}}
CS={ProjectY={Data=native}}
native.PartyRoster={Find=function(data,id)for _,actor in ipairs(data.roster)do if actor.Id==id then return actor end end end}
function bridge.Reset(data)data.observations=nil end
function bridge.Begin(data)
    data.observations={open=true,participants={},rows={}}
    for _,actor in ipairs(data.units)do
        if actor.Team==1 and actor.AnimalOwnerId==0 and not actor.dead and native.PartyRoster.Find(data,actor.Id)==actor then
            data.observations.participants[actor.Id]=actor
        end
    end
end
function bridge.IsParticipant(data,actor)
    local state=data.observations
    return state and state.open and state.participants[actor.Id]==actor or false
end
function bridge.Observe(data,learner,id,chance,name)
    assert(bridge.IsParticipant(data,learner))
    local key=learner.Id..':'..id;local row=data.observations.rows[key]
    if not row or chance>row.Chance then data.observations.rows[key]={Learner=learner,SkillId=id,Chance=chance,SourceName=name}end
end
function bridge.Consume(data)
    if not data.observations or not data.observations.open then return false end
    data.observations.open=false;return true
end
function bridge.Observations(data)
    assert(not data.observations.open)
    local rows={};for _,row in pairs(data.observations.rows)do rows[#rows+1]=row end
    table.sort(rows,function(a,b)return a.Learner.Id<b.Learner.Id or a.Learner.Id==b.Learner.Id and a.SkillId<b.SkillId end)
    local result={Length=#rows};for i,row in ipairs(rows)do result[i-1]=row end;return result
end
local function actor(id,team,q,r)
    local result={Id=id,Team=team or 1,TemplateId=1,AnimalOwnerId=0,Q=q or 0,R=r or 0,attribute=8,
        name='Actor '..id,original={},RecordAction=function()end}
    result.Growth={Initialized=true,PendingCount=2,skills={},rolls=0,roll=.1,
        HasSkill=function(self,id)return self.skills[id]==true end,
        GrantSkill=function(self,id)if self.skills[id]then return false end;self.skills[id]=true;return true end,
        NextRandom=function(self)self.rolls=self.rolls+1;return self.roll end}
    return result
end
local function fixture()
    local teacher,learner,enemy,reserve=actor(1,1,0,0),actor(2,1,1,0),actor(9,2,3,0),actor(3,1,-1,0)
    teacher.original[101]=true;enemy.original[101]=true
    local data={Phase='map',SiteId=1,roster={teacher,learner,reserve},units={teacher,learner,enemy},bond=80}
    data.PartyBonds={Score=function()return data.bond end}
    local rules={bySkill={[101]={teachable=true,reteachable=false,relationMinimum=50},[102]={teachable=true,reteachable=true,relationMinimum=20}}}
    function rules:IsOriginal(unit,id)return unit.original[id]==true end
    function rules:Owns(unit,id)return self:IsOriginal(unit,id) or unit.Growth:HasSkill(id)end
    function rules:Requirements(unit)return unit.attribute>=6,require('Language').SpecialSkillUnknown end
    function rules:ObservationChance(unit)return unit.attribute>=6 and math.min(1,(unit.attribute-5)*.1) or 0 end
    local skills={Get=function(_,id)return {id=id,name='Skill '..id,description='Description '..id}end}
    local battle=Battle();battle.board=Board.Create(6,1,0);battle.data={Phase='combat',ActiveId=teacher.Id,UnitCount=#data.units}
    function battle.data:GetUnitAt(index)return data.units[index+1]end
    battle.Changed=Signal(function(message)error(message)end)
    battle.stats={specialSkills=rules,Template=function(_,unit)return {name=unit.name}end,equipment={Consume=function()end}}
    local logs,events={},{}
    battle.Changed:Subscribe(function(event)events[#events+1]=event end)
    local adventure={data=data,battle=battle,sites={[1]={name='Test Site'}},config={GetTable=function(_,name)assert(name=='CombatSkillTable');return skills end},
        growth={chronicle={Record=function(_,...)logs[#logs+1]={kind='single',args={...}}end,
            RecordPair=function(_,...)logs[#logs+1]={kind='pair',args={...}}end}},
        personalGrowth={RecordLearnedSkill=function(_,unit,id)assert(unit.Growth:HasSkill(id));unit.recorded=(unit.recorded or 0)+1 end}}
    local model=Model.New(adventure);model:Start()
    local env={model=model,data=data,battle=battle,rules=rules,teacher=teacher,learner=learner,enemy=enemy,reserve=reserve,logs=logs,events=events}
    function env:Begin()battle.Changed:Emit({kind='battle_started'})end
    return env
end
do
    local e=fixture();local m,t,s=e.model,e.teacher,e.learner
    assert(m:CanTeach(t,s,101));local rows=m:TeachingRows(s,t);assert(#rows==1 and rows[1].skillId==101 and rows[1].allowed)
    assert(not m:CanTeach(t,t,101));assert(not m:CanTeach(e.enemy,s,101));assert(not m:CanTeach(t,s,999))
    e.data.Phase='battle';assert(not m:Teach(t.Id,s.Id,101));e.data.Phase='area'
    e.data.bond=49;assert(not m:CanTeach(t,s,101));e.data.bond=50
    s.attribute=5;assert(not m:CanTeach(t,s,101));s.attribute=8
    t.dead=true;assert(not m:CanTeach(t,s,101));t.dead=false
    e.rules.bySkill[101].teachable=false;assert(not m:CanTeach(t,s,101));e.rules.bySkill[101].teachable=true
    assert(m:Teach(t.Id,s.Id,101));assert(s.Growth:HasSkill(101) and s.Growth.PendingCount==2 and s.recorded==1)
    assert(not m:Teach(t.Id,s.Id,101));assert(not m:CanTeach(s,e.reserve,101))
    e.rules.bySkill[101].reteachable=true;assert(m:Teach(s.Id,e.reserve.Id,101))
    assert(#e.logs==2 and e.logs[1].kind=='pair' and e.logs[1].args[2]==s and e.logs[1].args[3]==t)
    assert(s.Growth.rolls==0 and e.reserve.Growth.rolls==0)
    m:Dispose();assert(not e.battle.specialSkillObserver and not e.data.observations)
end
print('PASS: teaching eligibility, roster/reserve, retransmission, idempotency and pair-only history')
do
    local e=fixture();e:Begin();local m=e.model
    local captured=m:CaptureUse(e.enemy,101);assert(#captured==1 and captured[1].learner==e.learner)
    m:CommitUse(captured)
    e.learner.attribute=10;m:CommitUse(m:CaptureUse(e.enemy,101))
    e.learner.attribute=6;e.enemy.name='Later name';m:CommitUse(m:CaptureUse(e.enemy,101))
    local row=e.data.observations.rows['2:101'];assert(row.Chance==.5 and row.SourceName=='Actor 9')
    e.learner.Growth.roll=.49;assert(m:Settle('victory','Test Site'))
    assert(e.learner.Growth:HasSkill(101) and e.learner.Growth.rolls==1 and e.learner.Growth.PendingCount==2)
    assert(not e.reserve.Growth:HasSkill(101) and e.reserve.Growth.rolls==0 and not m:Settle('victory','Test Site'))
    assert(#e.logs==1 and e.logs[1].kind=='single' and e.logs[1].args[2]==e.learner and e.logs[1].args[6]==false)
    assert(e.logs[1].args[4]:find('Actor 9',1,true))
end
print('PASS: highest observed probability, one roll per skill, reserve exclusion and safe source history')
for _,result in ipairs({'victory','defeat','draw'})do
    local e=fixture();e:Begin();e.model:CommitUse(e.model:CaptureUse(e.enemy,101))
    assert(e.model:Settle(result,'Test Site') and e.learner.Growth:HasSkill(101))
    assert(not e.model:Settle(result,'Test Site') and e.learner.Growth.rolls==1)
end
do
    local e=fixture();e:Begin();e.model:CommitUse(e.model:CaptureUse(e.enemy,101));e.learner.dead=true
    assert(e.model:Settle('victory','Test Site') and e.learner.Growth.rolls==0 and #e.logs==0)
    e.learner.dead=false;e:Begin();e.model:CommitUse(e.model:CaptureUse(e.enemy,101));e.learner.Growth.roll=.3
    -- A roll exactly equal to the captured chance fails; a later battle may try again.
    e.data.observations.rows['2:101'].Chance=.3
    assert(e.model:Settle('draw','Test Site') and not e.learner.Growth:HasSkill(101))
end
print('PASS: all battle outcomes, survival, strict probability boundary and consumption')
do
    local e=fixture();local m=e.model;e:Begin()
    e.battle.board:Find(2,0).blocked=true
    assert(not m:CanObserve(e.learner,e.enemy) and #m:CaptureUse(e.enemy,101)==0)
    e.battle.board:Find(2,0).blocked=false
    assert(m:CanObserve(e.learner,e.enemy))
    e.battle.board.spellcasting={BlocksSight=function()return true end};assert(not m:CanObserve(e.learner,e.enemy))
    e.battle.board.spellcasting=nil
    local calls=0;e.battle.board.area={visionRadius=1,CanSee=function(_,origin,target)calls=calls+1;assert(origin.q==1 and target.q==3);return false end}
    e.battle.board.Find=function(_,q,r)return {q=q,r=r,layer=0}end
    assert(not m:CanObserve(e.learner,e.enemy) and calls==0)
    e.battle.board.area.visionRadius=2
    assert(not m:CanObserve(e.learner,e.enemy) and calls==1)
    e.battle.data.Phase='deployment';assert(m:CaptureUse(e.enemy,101)==nil)
    e.battle.data.Phase='combat';assert(m:CaptureUse(e.enemy,999)==nil)
end
print('PASS: independent-board blockers, MapArea visibility, fog and deployment exclusion')
for _,api in ipairs({'TrySkill','TrySkillAt','TrySkillAtWithLanding'})do
    local e=fixture();e:Begin();e.battle.data.ActiveId=e.enemy.Id
    local args
    e.battle[api..'Internal']=function(_,...)args={...};return false,'rejected'end
    assert(not e.battle[api](e.battle,101,2,0,1,0) and next(e.data.observations.rows)==nil)
    assert(args[1]==101 and #e.events==1)
    e.battle[api..'Internal']=function()
        -- Last-hit cleanup and movement happen after the snapshot but before success is returned.
        e.learner.attribute=0;e.enemy.Q=-3;e.battle.data.Phase='ended'
        e.battle.board.spellcasting={BlocksSight=function()return true end}
        return true
    end
    assert(e.battle[api](e.battle,101,2,0,1,0))
    assert(#e.events==2 and e.events[2].kind=='skill_used' and e.events[2].skillId==101)
    assert(e.data.observations.rows['2:101'].Chance>.29)
    assert(e.model:Settle('victory','Test Site') and e.learner.Growth:HasSkill(101))
end
do
    local e=fixture();e:Begin();e.battle.data.ActiveId=e.enemy.Id
    e.battle.Skill=function()return {manualTargets=true,maxTargets=3}end
    e.battle.CanUseSkill=function()return true end
    e.battle.TrySkillInternal=function()return true end
    assert(e.battle:TrySkillTargets(101,{1,2}) and #e.events==2)
    assert(not e.battle:TrySkillTargets(101,{1,1}) and #e.events==2)
    local opportunity=require('Game.Battle.OpportunityAttacks')
    e.battle.Emit=function()end;e.battle.ApplyEffectProgram=function()end
    opportunity.Execute(e.battle,e.enemy,e.learner,{id=101,name='Reaction',effectIds={},target='enemy',trajectory='sight'})
    assert(#e.events==3 and e.events[3].kind=='skill_used')
    local count=0;for _ in pairs(e.data.observations.rows)do count=count+1 end;assert(count==1)
end
print('PASS: successful actor/cell/landing/multitarget/reaction submission, failure discard and final-hit snapshot')
do
    local e=fixture();e:Begin();e.battle.data.ActiveId=e.enemy.Id
    local ContainerCombat=require('Game.Loot.ContainerCombat')
    local combat=setmetatable({},{__index=ContainerCombat})
    combat.BattleInternal=function(_,battle,skillId,id)
        assert(battle==e.battle and skillId==101 and id==17);return false,'invalid container'
    end
    assert(not combat:Battle(e.battle,101,17) and next(e.data.observations.rows)==nil and #e.events==1)
    combat.BattleInternal=function()return true end
    assert(combat:Battle(e.battle,101,17) and e.data.observations.rows['2:101'] and #e.events==2)
end
print('PASS: container skill success notification and failed command isolation')

-- Real title/effect execution with isolated C# state doubles; no Editor or campaign data.
package.path='Lua/?.lua;'..package.path
local state={}
function state.BeginBattle(data)
    data.kills={};for _,actor in ipairs(data.units)do state.End(actor)end
end
function state.RecordKill(data,id)if data.kills[id]then return false end;data.kills[id]=true;return true end
function state.BeginTurn(actor)actor.titleTriggers=0 end
function state.TryKillBenefit(actor,limit)
    if actor.titleTriggers>=limit then return false end;actor.titleTriggers=actor.titleTriggers+1;return true
end
function state.End(actor)actor.titleTriggers=0 end
local life={}
function life.Alive(actor)return not actor.dead and (actor.HP>0 or actor.entered==true)end
function life.Used(actor)return actor.entered==true end
CS={ProjectY={Data={DeathDoorState=life,TitleCombatState=state}}}
local function actor(id,team,hp)
    local value={Id=id,TemplateId=id,Team=team,AnimalOwnerId=0,HP=hp or 100,MaxHP=100,
        Effects={Count=0},bonuses={},title={name='Fixture title'}}
    function value:Damage(amount)
        if self.MountedAnimal then
            local used=self.MountedAnimal:Damage(amount)
            if self.MountedAnimal.HP==0 then self.MountedAnimal=nil end
            return used
        end
        local used=math.min(self.HP,amount);self.HP=self.HP-used;return used
    end
    function value:Heal(amount)
        assert(self.HP>0,'Title healing must never revive zero-HP actors')
        self.healCalls=(self.healCalls or 0)+1
        local used=math.min(amount,self.MaxHP-self.HP);self.HP=self.HP+used;return used
    end
    return value
end
local units={};local nextId=0
local function add(team,hp)
    nextId=nextId+1;local value=actor(nextId,team,hp);units[#units+1]=value;return value
end
local hero=add(1,40);local ally=add(1);local foe=add(2)
local data={Phase='combat',Winner='',units=units}
function data:GetUnitAt(index)return self.units[index+1]end
setmetatable(data,{__index=function(_,key)if key=='UnitCount'then return #units end end})
local stats={titles={},deathDoor={},buffs={Find=function()return nil end}}
function stats:Template(value)return{name='Actor '..value.Id,bodyInjuries=false}end
function stats.titles:Effect(value,kind)return value.bonuses[kind]or 0 end
function stats.titles:Equipped(value)return value.title end
function stats.deathDoor:Resolve(_,target,before,used,incoming)
    if not target.deathDoor or target.HP>0 or incoming<=0 then return end
    if before>0 and not used then target.entered=true else target.dead=true end
end
local battle={data=data,stats=stats,morale={}}
function battle:FindUnit(id)for _,value in ipairs(units)do if value.Id==id then return value end end end
function battle:IsHostile(source,target)
    local team=type(source)=='number'and source or source.Team
    return team>0 and target.Team>0 and team~=target.Team
end
function battle.morale:Change(_,value,amount,reason)
    assert(value.HP>0 and reason==value.title.name,'Title morale must use its equipped title and a living recipient')
    value.morale=(value.morale or 0)+amount
end
local events={}
local effects=require('Game.Battle.GameEffects').New(stats,{},function(kind,_,sourceId,targetId,amount,target,_,impact)
    events[#events+1]={kind=kind,sourceId=sourceId,targetId=targetId,amount=amount,target=target,impact=impact}
end,{battle=battle})
local combat=require('Game.Battle.TitleCombat').New(battle)
battle.titleCombat=combat;battle.gameEffects=effects;effects.titleCombat=combat
local rewards={}
combat.onKill=function(source,target)rewards[#rewards+1]={source=source,target=target}end
combat:Begin()
local damage={kind='damage',duration='instant',damageColor='',equipmentDamage=0,killEquipmentDamage=0}
local skill={damageScale=1}
local function strike(source,target,amount,periodic,sourceId,ability)
    effects:Execute(damage,target,amount,sourceId or source.Id,'Fixture source','Fixture strike',source,true,nil,periodic,ability or skill)
end

-- Damage bonuses use the current holder's life, not a captured DOT/skill snapshot.
hero.bonuses={low_health_damage_percent=20,damage_percent=50};hero.HP=29
assert(combat:Damage(hero,foe,100,skill,false,true)==120,'Low-health attack damage must not duplicate base title damage')
hero.HP=30;assert(combat:Damage(hero,foe,100,skill,false,true)==100,'Thirty percent is outside the low-health threshold')
hero.HP=0;hero.entered=true;assert(combat:Damage(hero,foe,100,skill,false,true)==100,'Death-door holders receive no low-health damage bonus')
hero.HP=29;hero.entered=false
assert(combat:Damage(hero,foe,100,skill,true,true)==100,'DOT must not gain a second snapshot bonus')
assert(combat:Damage(hero,foe,100,nil,false,true)==100,'Indirect damage is not an attack skill')
assert(combat:Damage(hero,foe,100,skill,false,false)==100)
foe.bonuses.damage_taken_percent=10
assert(combat:Damage(hero,foe,100,skill,false,true)==132,'Incoming and outgoing percentages compose once')
assert(combat:Damage(nil,foe,100,nil,true,false)==110,'Incoming penalty applies to periodic damage')
assert(combat:Damage(hero,foe,0,skill,false,true)==0)
local riderCost=add(1,29);riderCost.bonuses.low_health_damage_percent=30
local costMount=actor(998,1);costMount.AnimalOwnerId=riderCost.Id;riderCost.MountedAnimal=costMount
strike(riderCost,riderCost,10)
assert(costMount.HP==90,'Mounted self-damage must not become an offensive low-health hit')
local mitigationInput
effects.legacyCombat={Damage=function(_,_,_,_,amount)return amount+10 end,Resolved=function()end}
effects.professions={Mitigate=function(_,_,amount)mitigationInput=amount;return amount-5 end}
strike(hero,foe,10)
assert(mitigationInput==26 and foe.HP==79,'Title percentages follow legacy damage and precede existing mitigation')
effects.legacyCombat=nil;effects.professions=nil

-- Each of the first two hostile kills supplies both benefits; later kills still award reputation.
hero.bonuses={kill_heal_percent=6,kill_morale=10};hero.HP=40;foe.bonuses={};foe.HP=1
strike(hero,foe,1)
assert(#rewards==1 and hero.HP==46 and hero.morale==10 and hero.healCalls==1)
local healEvent=events[#events]
assert(healEvent.kind=='heal'and healEvent.amount==6 and healEvent.impact.hpBefore==40 and healEvent.impact.hpAfter==46
    and healEvent.impact.actionName==hero.title.name,'Title healing must go through real effect events and actor body healing')
local second=add(2,1);strike(hero,second,1)
local third=add(2,1);strike(hero,third,1)
assert(#rewards==3 and hero.HP==52 and hero.morale==20 and hero.titleTriggers==2,'Multi-target kills cap benefits, not reputation')
combat:BeginTurn(ally);local fourth=add(2,1);strike(hero,fourth,1)
assert(hero.HP==52 and #rewards==4,'Other actors turns must not reset holder limits')
combat:BeginTurn(hero);local fifth=add(2,1);strike(hero,fifth,1)
assert(hero.HP==58 and hero.morale==30 and #rewards==5)
-- A repeated death of the same encounter actor cannot duplicate its settlement.
foe.HP=1;strike(hero,foe,1);assert(#rewards==5 and hero.HP==58)
effects:Notify('defeated','Synthetic GM event',hero.Id,add(2,0),0)
assert(#rewards==5,'Synthetic defeated notifications cannot create title/reputation benefits')

-- Affiliation and identity checks are independent of identifiers and of the generic event stream.
local rewardCount=#rewards
local neutral=add(0,1);strike(hero,neutral,1)
local friendly=add(1,1);strike(hero,friendly,1)
local tame=add(2,1);tame.AnimalOwnerId=hero.Id;strike(hero,tame,1)
local impostor=actor(hero.Id,1);local impersonatedTarget=add(2,1);strike(impostor,impersonatedTarget,1)
local phantom=actor(add(2).Id,2,1);strike(hero,phantom,1)
assert(#rewards==rewardCount,'Neutral, allied, tamed and fabricated combatants are not genuine hostile kills')
local rider=add(2);local mount=actor(999,2,1);mount.AnimalOwnerId=rider.Id;rider.MountedAnimal=mount
strike(hero,rider,1);assert(#rewards==rewardCount and rider.HP==100,'A defeated mount is not a rider kill')

-- DOT keeps its original real source even after that source dies; zero-HP holders cannot heal or rally.
hero.HP=0;hero.entered=true;combat:BeginTurn(hero)
local dotTarget=add(2,1);strike(nil,dotTarget,1,true,hero.Id)
assert(#rewards==rewardCount+1 and rewards[#rewards].source==hero and hero.HP==0 and hero.morale==30)
hero.entered=false;local afterDeath=add(2,1);strike(nil,afterDeath,1,true,hero.Id)
assert(#rewards==rewardCount+2 and hero.HP==0 and hero.morale==30,'Dead source retains kill attribution only')
local missingSource=add(2,1);strike(nil,missingSource,1,true,123456)
assert(#rewards==rewardCount+2,'Unknown periodic source does not fabricate ownership')

-- First lethal blow can enter death door; a later real positive hit can kill at zero HP.
hero.HP=40;local doorTarget=add(2,1);doorTarget.deathDoor=true
strike(hero,doorTarget,1);assert(doorTarget.entered and #rewards==rewardCount+2)
strike(hero,doorTarget,0);assert(not doorTarget.dead and #rewards==rewardCount+2)
strike(hero,doorTarget,1);assert(doorTarget.dead and #rewards==rewardCount+3,'Actual death at zero HP must settle once')
strike(hero,doorTarget,1);assert(#rewards==rewardCount+3)

hero.bonuses={turn_heal_percent=2};hero.HP=50
combat:EndTurn(hero);assert(hero.HP==52,'End-turn healing uses maximum HP')
hero.MaxHP=20;hero.HP=10;combat:EndTurn(hero);assert(hero.HP==11,'A positive title heal has a minimum of one')
hero.HP=0;hero.entered=true;combat:EndTurn(hero);assert(hero.HP==0,'End-turn title healing cannot rescue a death-door actor')
hero.HP=10;hero.entered=false;data.Phase='deployment';combat:EndTurn(hero);assert(hero.HP==10)
data.Phase='combat';data.Winner='victory';combat:EndTurn(hero);assert(hero.HP==10)
-- Actual campaign attribution excludes NPCs, pets and third parties, even if they share team 1.
data.Winner='';combat:Begin()
local campaign={PartyCount=2,balance=0,kills={},GetPartyAt=function(_,i)return i==0 and hero or ally end}
CS.ProjectY.Data.ReputationState={AwardKill=function(c,id,amount)
    if c.kills[id]then return false end;c.kills[id]=true;c.balance=c.balance+amount;return true
end}
stats.titles.forge={policy={killReward=2,legendReward=50}}
local titles=require('Game.Progression.Titles').New({data=campaign,battle=battle,parties={legends={byUnit={[777]={id=1}}}}})
combat.onKill=function(source,target)titles:RewardKill(source,target)end
local enemyKiller=add(2);strike(enemyKiller,add(1,1),1)
local pet=add(1);pet.AnimalOwnerId=hero.Id;strike(pet,add(2,1),1)
local npc=add(1);strike(npc,add(2,1),1)
local thirdParty=add(3);strike(thirdParty,add(2,1),1)
assert(campaign.balance==0,'Only an actual party member owns campaign reputation attribution')
local normal=add(2,1);strike(ally,normal,1);assert(campaign.balance==2)
local legend=add(2,1);legend.TemplateId=777;strike(ally,legend,1);assert(campaign.balance==52)
local peaceTarget=add(0,1);strike(ally,peaceTarget,1)
local ownedTarget=add(2,1);ownedTarget.AnimalOwnerId=ally.Id;strike(ally,ownedTarget,1)
assert(campaign.balance==52,'Neutral and owned targets never award shared reputation')
combat:Finish();assert(hero.titleTriggers==0)
for _,path in ipairs({'Lua/Game/Battle/TitleCombat.lua','Lua/Game/Battle/GameEffects.lua','Lua/Game/Battle/BattleSystem.lua'})do assert(loadfile(path))end
print('PASS title combat: actual kills, DOT ownership, hostile identity, deduplication, own-turn caps, death door, damage and heal effects')

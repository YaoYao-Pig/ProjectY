-- Exercise the real presentation entry points: unknown facts must not leak through parallel HUDs.
package.path='Lua/?.lua;'..package.path
local L=require('Language')
local Log=require('Game.Battle.BattleLog')
local target={name='Target',team=2,healthKnown=false,defenseKnown=false,guardKnown=false}
local impact={hpBefore=831,hpAfter=827,maxHP=953,defense=79,guard=67}
local text=Log.Format('damage','unused',{name='Observer',team=1},target,4,impact)
assert(text:find(L.InspectionUnknown,1,true))
for _,secret in ipairs({'831','827','953','79','67'})do assert(not text:find(secret,1,true),'Hidden log value leaked: '..secret)end
local guard=Log.Format('guard','unused',nil,target,4,{guardAfter=67,guardBefore=63})
assert(guard:find(L.InspectionUnknown,1,true) and not guard:find('67',1,true))
target.healthKnown=true;target.defenseKnown=true;target.guardKnown=true
text=Log.Format('damage','unused',nil,target,4,impact)
assert(text:find('827/953',1,true) and text:find('79',1,true) and text:find('67',1,true))
print('PASS unknown life, defense and guard never leak through settled logs; revealed facts return')

CS={UnityEngine={Color=function(...)return {...}end},ProjectY={Data={SpellcastingState={Current=function()return 0 end,Maximum=function()return 0 end,Regen=function()return 0 end},
    AnimalCompanionState={Independent=function()return false end},DeathDoorState={Alive=function(a)return a.HP>0 end,Entered=function()return false end,Dead=function(a)return a.HP<=0 end}}}}
local Unit=require('UI.Widget.BattleUnit')
local function node()return {text='',gameObject={SetActive=function()end}}end
local view={Group={},Button={},Name=node(),Detail=node(),Active=node(),Side={},Health={}}
local widget={view=view,compact=true,hud={SetHealth=function()end}}
local row={id=2,name='Enemy',identity={name='Enemy'},hp=827,maxHP=953,speed=79,team=2,alive=true,active=false,healthKnown=false,speedKnown=false}
Unit.SetData(widget,row);assert(view.Detail.text==L.InspectionUnknown)
widget.compact=false;Unit.SetData(widget,row);assert(view.Detail.text==L.InspectionUnknown)
row.healthKnown=true;Unit.SetData(widget,row);assert(view.Detail.text:find('827',1,true))
widget.compact=true;row.speedKnown=true;Unit.SetData(widget,row);assert(view.Detail.text:find('79',1,true))
print('PASS action-order cards and unit cards mask undiscovered speed and HP')

local actor={Id=2,TemplateId=4,HP=827,MaxHP=953,TraitCount=2,GetTraitAt=function(_,i)return 101+i end}
local known={}
local stats={spellcasting={Sync=function()end},traits={Get=function(_,id)return {name='SecretTrait'..id}end},
    inspection={Known=function(_,_,field)return known[field]==true end},
    animals={IsStaticBody=function()return true end},Template=function()return {name='Enemy'}end}
local snapshot=require('Game.Battle.CombatSnapshot')
local appearances={Template=function()return {}end}
local result=snapshot(actor,stats,appearances)
assert(result.traits==L.InspectionUnknown..' · '..L.InspectionUnknown and result.hp==827)
known['trait:102']=true
result=snapshot(actor,stats,appearances)
assert(result.traits==L.InspectionUnknown..' · SecretTrait102')
print('PASS shared combat snapshot masks each trait separately and preserves authoritative numeric rendering inputs')

-- The enemy action bar must not even resolve unseen skills into tooltip data.
local Hud=require('Game.Battle.BattleHUDModel')
CS.ProjectY.Data.BattleMovement={Remaining=function()return 0 end}
local enemy={Id=22,Team=2,HP=30,MaxHP=40,AP=2,Guard=1,GetCooldown=function()return 0 end}
local skillKnown,skillCalls={},0
local hudStats={spellcasting={Sync=function()end},
    inspection={Known=function(_,_,field)return skillKnown[field]==true end},
    Template=function()return {name='Enemy',actionPoints=3}end,
    Get=function()return 5 end,MoveRange=function()return 4 end,
    equipment={Weapon=function()end,Loaded=function()end}}
local battle={data={Winner='',Phase='combat',Round=1,MaxRounds=10,TurnCount=0,LogCount=0},stats=hudStats,board={},
    Active=function()return enemy end,Units=function()return {enemy}end,SkillIds=function()return {11,12}end,
    encounters={Get=function()return {name='Encounter'}end},consumables={All=function()return {}end},
    SkillBudget=function()return true end,
    Skill=function(_,_,id)
        skillCalls=skillCalls+1;assert(skillKnown['skill:'..id],'Unseen skill was resolved into UI data')
        return {id=id,iconId=id,name='KnownSkill'..id,description='KnownDescription'..id,
            contexts={'battle'},skillKind='active',action='main',cost=1,range=2,target='enemy'}
    end}
local hud=Hud.Build(battle,{PartyCount=0})
assert(#hud.skills==0 and skillCalls==0)
skillKnown['skill:11']=true
hud=Hud.Build(battle,{PartyCount=0})
assert(#hud.skills==1 and skillCalls==1 and hud.skills[1].id==11 and hud.skills[1].name=='KnownSkill11')
assert(not hud.skills[1].available and hud.skills[1].reason==L.BattleEnemyTurn)
print('PASS enemy HUD resolves and exposes only witnessed skills while preserving action restrictions')

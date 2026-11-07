-- Isolated rules tests: deterministic state doubles, no Editor or live campaign.
package.path='Lua/?.lua;'..package.path
local function tableOf(rows)
    local byId={};for _,row in ipairs(rows)do byId[row.id]=row end
    return {All=function()return rows end,Get=function(_,id)return assert(byId[id],'Missing fixture '..id)end,Find=function(_,id)return byId[id]end}
end
local tables={
    TitleForgeEffectTable=tableOf({{id=1,name='Defense',description='Defense',category='primary',kind='attribute',attribute='defense',amount=1,cost=20,maxRank=5,negative=false},
        {id=2,name='Courage',description='Courage',category='combat',kind='attribute',attribute='courage',amount=1,cost=20,maxRank=5,negative=false}}),
    ReputationRuleTable=tableOf({{id=1,killReward=2,legendReward=50,missionReward=60,townReward=30,discountPercent=50}}),
    GrowthAttributeTable=tableOf({{id=1,code='defense',name='Defense'},{id=2,code='courage',name='Courage'}}),
    CombatUnitTable=tableOf({{id=1},{id=2}}),LegendaryEncounterTable=tableOf({{id=11}}),MissionTable=tableOf({{id=1}}),
    QuestTable=tableOf({{id=3}}),TownMissionTable=tableOf({{id=5}}),
    TitleRequirementTable=tableOf({{id=1,kind='kill',targetId=0,required=2,description='Two kills'},
        {id=2,kind='mission',targetId=1,required=1,description='Mission'},
        {id=3,kind='legend',targetId=11,required=1,description='Legend'},
        {id=4,kind='rescue',targetId=0,required=3,description='Rescue'}}),
    TitleTable=tableOf({{id=1,name='Veteran',description='Fixture',mode='all',requirementIds={1,2},attributeIds={1},attributeValues={3},damagePercent=10,moraleMaximum=10},
        {id=2,name='Hero',description='Fixture',mode='any',requirementIds={3,4},attributeIds={2},attributeValues={5},damagePercent=20,moraleMaximum=0}}),
    MoraleRuleTable=tableOf({{id=1,baseCourage=40,maximum={Evaluate=function(_,v)return 50+v.courage end},initialPercent=75,
        minimumChance=5,maximumChance=95,supportRadius=1,witnessRadius=4,allyBonus=3,enemyPenalty=3,woundPercent=15,rallyDistance=1}}),
    MoraleStageTable=tableOf({{id=1,stage=-3,name='Fleeing',minimumPercent=0,hitScale=0,defenseScale=.7,checkBonus=-30},
        {id=2,stage=-2,name='Breaking',minimumPercent=20,hitScale=.8,defenseScale=.8,checkBonus=-20},
        {id=3,stage=-1,name='Wavering',minimumPercent=40,hitScale=.9,defenseScale=.9,checkBonus=-10},
        {id=4,stage=0,name='Steady',minimumPercent=60,hitScale=1,defenseScale=1,checkBonus=0},
        {id=5,stage=1,name='Confident',minimumPercent=90,hitScale=1.1,defenseScale=1.1,checkBonus=10}}),
    MoraleEventTable=tableOf({{id=1,kind='wound',name='Wound',difficulty=0,change=-20},{id=2,kind='ally_defeated',name='Loss',difficulty=0,change=-20},
        {id=3,kind='ally_fleeing',name='Panic',difficulty=0,change=-15},{id=4,kind='enemy_defeated',name='Gain',difficulty=0,change=10},
        {id=5,kind='kill',name='Kill',difficulty=0,change=15},{id=6,kind='outnumbered',name='Surrounded',difficulty=0,change=-10},
        {id=7,kind='rally',name='Rally',difficulty=0,change=20}})
}
local config={GetTable=function(_,name)return assert(tables[name],name)end}
local ts,ms={},{}
CS={ProjectY={Data={TitleState=ts,MoraleState=ms,ReputationState={BeginBattle=function()end,AwardSettlement=function()return true end},DeathDoorState={Alive=function(a)return a.HP>0 end,BeginBattle=function()end}}}}
local function actor(id,team,q)
    local a={Id=id,Team=team,TemplateId=team,AnimalOwnerId=0,HP=100,MaxHP=100,Q=q,R=0,owned={},counters={},settlements={},kills={},equipped=0,revision=0}
    a.SetMaxHP=function(self,v)self.MaxHP=v end
    return a
end
function ts.Equipped(a)return a.equipped end
function ts.Revision(a)return a.revision end
function ts.Count(a)return #a.owned end
function ts.CustomCount()return 0 end
function ts.At(a,i)return a.owned[i+1]end
function ts.Owns(a,id)for _,v in ipairs(a.owned)do if v==id then return true end end;return false end
function ts.Counter(a,k)return a.counters[k] or 0 end
function ts.Increment(a,k)a.counters[k]=ts.Counter(a,k)+1;a.revision=a.revision+1 end
function ts.Award(a,id)if ts.Owns(a,id)then return false end;a.owned[#a.owned+1]=id;a.revision=a.revision+1;return true end
function ts.Equip(a,id)assert(id==0 or ts.Owns(a,id));a.equipped=id;a.revision=a.revision+1 end
function ts.BeginBattle(a)a.kills={}end
function ts.RecordKill(a,id)if a.kills[id]then return false end;a.kills[id]=true;return true end
function ts.RecordSettlement(a,k,id)local key=k..':'..id;if a.settlements[key]then return false end;a.settlements[key]=true;return true end
function ms.Active(a)return a.morale~=nil end
function ms.Current(a)return a.morale.current end
function ms.Maximum(a)return a.morale.maximum end
function ms.Stage(a)return a.morale.stage end
function ms.Begin(a,m,c,s)a.morale={maximum=m,current=c,stage=s}end
ms.Set=ms.Begin
function ms.End(a)a.morale=nil end
function ms.BeginBattle(b)b.defeated={}end
function ms.RecordDefeat(b,id)if b.defeated[id]then return false end;b.defeated[id]=true;return true end
local first,second,enemy=actor(1,1,0),actor(2,1,1),actor(3,2,2)
local units={first,second,enemy};local logs={};local nextRoll=99
local data={Phase='combat',Winner='',ActiveId=1,UnitCount=3,RollPercent=function()return nextRoll end,GetUnitAt=function(_,i)return units[i+1]end}
local rules=require('Game.Progression.TitleRules').New(config)
local stats={titles=rules,animals={Distance=function(_,a,b)return math.abs(a.Q-b.Q)end},
    Get=function(_,a,name)return (name=='courage' and 40 or 10)+rules:Bonus(a,name)end,
    Template=function()return {name='Actor'}end,MaximumHP=function()return 100 end,spellcasting={Sync=function()end}}
local battle={data=data,stats=stats,Units=function()return units end,FindUnit=function(_,id)for _,a in ipairs(units)do if a.Id==id then return a end end end,
    IsHostile=function(_,a,b)return a.Team~=b.Team end,IsAllied=function(_,a,b)return a.Team==b.Team end,Active=function()return first end}
local morale=require('Game.Battle.Morale').New(config,stats);battle.morale=morale
function battle:Emit(kind,message,source,target,amount,unit)logs[#logs+1]={kind=kind,amount=amount};morale:OnEvent(self,{kind=kind,target=unit})end
local bonds={RescueCount=function()return 0 end}
local party={Phase='map',SiteId=1,PartyCount=2,PartyBonds=bonds,GetPartyAt=function(_,i)return units[i+1]end}
local awards=0
local adventure={battle=battle,data=party,sites={[1]={name='Test'}},parties={legends={byUnit={[2]={id=11}}}},growth={chronicle={Record=function()awards=awards+1 end}}}
local titles=require('Game.Progression.Titles').New(adventure)
assert(not rules:Eligible(first,tables.TitleTable:Get(1),bonds))
titles:OnBattleEvent({kind='battle_started'})
enemy.HP=0;titles:OnBattleEvent({kind='defeated',sourceId=1,target=enemy});titles:OnBattleEvent({kind='defeated',sourceId=1,target=enemy})
assert(ts.Counter(first,'kill:0')==1 and ts.Counter(second,'kill:0')==0,'Kill must belong only to killer and be deduplicated')
assert(ts.Owns(first,2) and not ts.Owns(first,1) and first.equipped==0,'Unlock must not silently equip')
titles:OnBattleEvent({kind='battle_started'});titles:OnBattleEvent({kind='defeated',sourceId=1,target=enemy})
second.HP=0;titles:Complete('mission',1);titles:Complete('mission',1)
assert(ts.Counter(first,'mission:0')==1 and ts.Counter(second,'mission:0')==1,'Mission counts all current members once, including downed members')
assert(ts.Owns(first,1) and awards==2,'All requirements and repeat award guards failed')
assert(titles:Equip(1,1) and rules:Bonus(first,'defense')==3)
assert(titles:Equip(1,2) and rules:Bonus(first,'defense')==0 and rules:Bonus(first,'courage')==5,'Single slot must replace bonuses')
assert(not titles:Equip(2,1));party.Phase='battle';assert(not titles:Equip(1,0));party.Phase='map';assert(titles:Equip(1,0))
titles:Complete('quest',3);assert(ts.Counter(first,'mission:0')==1,'Quest steps must not inflate mission total')
titles:Complete('town',100,5);titles:Complete('town',100,5);titles:Complete('town',101,5)
assert(ts.Counter(first,'mission:0')==3 and ts.Counter(first,'town:5')==2,'Town instance and definition identities differ')
second.HP=100;enemy.HP=100;morale:Begin(battle)
assert(ms.Current(first)==67 and ms.Stage(first)==0)
assert(morale:Stage(0,100)==-3 and morale:Stage(20,100)==-2 and morale:Stage(40,100)==-1 and morale:Stage(60,100)==0 and morale:Stage(90,100)==1)
local before=ms.Current(first);morale:Check(battle,first,'wound');assert(ms.Current(first)==before-20)
nextRoll=0;before=ms.Current(first);morale:Check(battle,first,'wound');assert(ms.Current(first)==before,'Successful negative check must preserve morale')
morale:Check(battle,first,'kill');assert(ms.Current(first)==before+15)
-- Two wavering allies can cascade, but each broadcasts only on entering fleeing.
ms.Set(first,90,20,-2);ms.Set(second,90,20,-2);nextRoll=99
morale:Change(battle,first,-20,'Fixture');assert(morale:Fleeing(first) and morale:Fleeing(second) and #logs<30,'Panic cascade must terminate')
assert(morale:Attribute(first,'defense',10)==7)
local skill=morale:Skill(first,{damageScale=1,hitChance=80});assert(skill.hitChance==0)
enemy.Q=8;nextRoll=0;morale:BeginTurn(battle,first);assert(ms.Stage(first)>=-1,'Rally must restore a controllable state')
ms.Set(first,90,0,-3);enemy.Q=2
local moved,ended
function battle:Reachable()return {{q=-1,r=0},{q=-3,r=0},{q=1,r=0}}end
function battle:TryMove(q,r,retreat)moved=q;assert(retreat)end
function battle:EndTurn()ended=true end
morale:Flee(battle,first);assert(moved==-3 and ended,'Fleeing must move away and end turn')
morale:End(battle);assert(not ms.Active(first) and morale:Attribute(first,'defense',10)==10)
print('title_morale_core: ownership, counters, single slot, stages, checks, cascade, rally and flight passed')

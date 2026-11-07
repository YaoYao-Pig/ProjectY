package.path='Lua/?.lua;'..package.path
local Targets=require('Game.Adventure.UnitInspectionTargets')
local function tableOf(rows)
    local byId={};for _,row in ipairs(rows) do byId[row.id]=row end
    return {Get=function(_,id)return assert(byId[id],'Unknown fixture row '..tostring(id))end,
        Find=function(_,id)return byId[id]end,All=function()return rows end}
end
local function actor(id,template)
    local row={Id=id,TemplateId=template,AnimalOwnerId=0,AnimalSpeciesId=0,TraitCount=0,Q=1,R=0,traits={}}
    function row:AddTrait(value)
        for _,id in ipairs(self.traits) do if id==value then return end end
        self.traits[#self.traits+1]=value;self.TraitCount=#self.traits
    end
    function row:SetMaxHP(value)self.MaxHP=value end
    function row:Restore()self.HP=self.MaxHP end
    return row
end
local units=tableOf({{id=1,name='Hero',traitIds={7}},{id=2,name='Enemy',traitIds={8}},
    {id=3,name='Recruit',traitIds={7}},{id=4,name='Resident',traitIds={8}},
    {id=5,name='Legend',traitIds={9}}})
local npcs=tableOf({{id=21,name='Recruit name',actorTemplateId=3,townTemplateId=1,locationKind='town'},
    {id=31,name='Legend name',actorTemplateId=5,townTemplateId=1,locationKind='world_party'}})
local residentTemplates=tableOf({{id=1,name='Resident name'}})
local mappings=tableOf({{id=1,unitId=4}})
local config={GetTable=function(_,name)return assert(({NpcTable=npcs,MapAreaTownNpcTable=residentTemplates,UnitInspectionNpcTable=mappings})[name])end}
local hero=actor(1,1);local reserve=actor(2,1);local animal=actor(110012,2)
animal.AnimalOwnerId=hero.Id;animal.AnimalSpeciesId=1;hero.animal=animal
local own={hero,reserve}
local data={Phase='map',Seed=123,SiteId=20,EventId=50,ChoiceId=100,Areas={ActiveSiteId=20},
    Narrative={DialogueOpen=false,Minutes=2880}}
CS={ProjectY={Data={CombatActorData=actor,
    PartyRoster={Count=function()return #own end,At=function(_,i)return own[i+1]end,
        Find=function(_,id)for _,row in ipairs(own) do if row.Id==id then return row end end end},
    AnimalCompanionState={Bound=function(row)return row.animal end},
    ProfessionDuelState={Active=function()return data.duel==true end,ActorId=function()return hero.Id end}}}}
local stats={units=units,growth={profileByUnit={[3]=true}},birth={Initialize=function(_,row,seed)row.birthSeed=seed end},
    Template=function(_,row)return units:Get(row.TemplateId)end,MaximumHP=function()return 20 end}
local npcPrepare=0
local adventure={config=config,data=data,battle={stats=stats,board={}},growth={PrepareActor=function(_,row)
    npcPrepare=npcPrepare+1;row.birthSeed=data.Seed;row:AddTrait(6);row:AddTrait(7)
end}}
local enemy=actor(120011,2);local second=actor(120012,2);second.Q=2
local legend=actor(1000000000,5)
local world={Id=1,Defeated=false,MemberCount=2,GetMemberAt=function(_,i)return ({enemy,legend})[i+1]end}
local near=true
adventure.parties={data={ContactId=1,Find=function(_,id)return id==1 and world end},Near=function()return near end}
local targets=Targets.New(adventure)
assert(targets:Key(hero)=='actor:1' and targets:Owned(reserve) and targets:Owned(animal))
assert(targets:Key(legend)=='npc:31')
assert(#targets:Rows()==5 and targets:Find('actor:120011').actor==enemy)
near=false;assert(#targets:Rows()==3 and not targets:Find('actor:120011'))
near=true;adventure.parties.data.ContactId=0
data.Narrative.DialogueOpen=true;data.Narrative.DialogueNpcId=31;data.Narrative.DialogueLocalNpcId=1
assert(targets:Find('npc:31').actor==legend,'Legend dialogue must preserve real actor identity')
data.Narrative.DialogueOpen=false
local cells={{index=1},{index=2},{index=3}}
local definitions={{id=1,templateId=1,stableId=200021,narrativeId=21},{id=2,templateId=1,stableId=100001}}
local residents={{Id=1,Present=true,CellIndex=1},{Id=2,Present=true,CellIndex=2}}
local visible={1}
local state={SiteId=20,VisibleCount=1,EncounterCount=1,NpcCount=2,
    GetVisibleAt=function(_,i)return visible[i+1]end,GetNpcAt=function(_,i)return residents[i+1]end,
    GetEncounterAt=function()return {EnemyCount=2,GetEnemyAt=function(_,i)return ({enemy,second})[i+1]end}end}
data.Areas.Active=state
local layout={cells=cells,npcs=definitions,Find=function(_,q)return cells[q]end}
adventure.areas={ActiveLayout=function()return layout end}
data.Phase='area'
assert(targets:Find('actor:120011') and not targets:Find('actor:120012'),'Hidden enemies must not be inspectable')
local before=targets:Find('npc:21')
assert(before and before.name=='Recruit name' and not before.owned and before.actor.TraitCount==2)
assert(targets:Find('npc:21').actor==before.actor and npcPrepare==1,'Static NPC projection should be reused')
assert(not targets:Find('resident:20:100001'),'Hidden residents must not be inspectable')
residents[1].Present=false;assert(not targets:Find('npc:21'))
residents[1].Present=true;visible={1,2};state.VisibleCount=2
local resident=targets:Find('resident:20:100001');assert(resident and targets:Key(resident.actor)==resident.key)
state.SiteId=21
local other=targets:Find('resident:21:100001');assert(other and other.key~=resident.key)
assert(other.actor.birthSeed~=resident.actor.birthSeed,'Residents of different towns have distinct deterministic birth inputs')
state.SiteId=20
local recruited=actor(10021,3);own[#own+1]=recruited
local after=targets:Find('npc:21');assert(after.owned and after.actor==recruited and before.key==after.key)
data.Phase='battle';adventure.battle.board={area=layout}
adventure.battle.Units=function()return {hero,enemy,second,legend}end
visible={1};state.VisibleCount=1
assert(targets:Find('actor:120011') and not targets:Find('actor:120012'))
assert(targets:Find('npc:31') and not targets:Find('npc:31').owned,'Allied/legendary units are not player-owned')
assert(targets:Key(enemy)=='actor:120011','Exploration and battle must keep the same enemy key')
adventure.battle.board={};local temporary=actor(101,2)
local firstKey=targets:Key(temporary);data.SiteId=21
assert(firstKey~=targets:Key(temporary),'Legacy event IDs must be scoped by encounter location')
data.duel=true;local opponent=actor(9000001,2)
local duelKey=targets:Key(opponent);data.Narrative.Minutes=4320
assert(duelKey~=targets:Key(opponent),'Different daily duel opponents must not share attempts')
local rows=targets.Rows;targets.Rows=function()error('Identity must not enumerate targets')end
local key,owned=targets:Identity(enemy);assert(key=='actor:120011' and not owned)
targets.Rows=rows
print('PASS inspection target visibility, contact reachability, roster ownership, NPC trait projection, recruitment and stable identities')

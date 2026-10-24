-- Event recruits retain their live actor and equipment; preparation must remain read-only.
package.path='Lua/?.lua;'..package.path
local Npcs=require('Game.Narrative.NpcSystem')
local Actions=require('Game.Narrative.NarrativeActions')
CS={ProjectY={Data={}}}
local checks=0
local function test(name,run)run();checks=checks+1;print('PASS '..name)end
local function fixture()
    local actor={Id=10301,TemplateId=910,Team=4,HP=17,MaxHP=60,Growth={Initialized=false}}
    local group={actor=actor};local facts={};local log={prepared=0,transferred=0,items=0,capacity=0,joined=0}
    local story={data={GetValue=function(_,key)return facts[key] or 0 end,SetValue=function(_,key,value)facts[key]=value end},
        rules={npcs={Get=function()return {locationKind='event',recruitable=true,actorTemplateId=910}end},
            actions={Get=function(_,id)return id==1 and {kind='recruit_npc',targetId=301} or {kind='grant_item',targetId=7,value=1}end}},
        adventure={data={Phase='map',PartyCount=3,Narrative={Minutes=0}},recipe={maxPartySize=4},player={Coins=0},
            battle={stats={MaximumHP=function()return 75 end}},equipment={data={},
                initialLoadouts={Items=function()error('Event recruit must not receive a new loadout')end,
                    Apply=function()error('Event recruit must retain its physical equipment')end},
                CanGrant=function()log.capacity=log.capacity+1;return false end},
            growth={PrepareActor=function(_,value)assert(value==actor and not value.Growth.Initialized);value.Growth.Initialized=true;log.prepared=log.prepared+1 end,
                RecordJoined=function(_,value)assert(value==actor);log.joined=log.joined+1 end}}}
    function story.adventure.specialEventsPrepare()return {npcId=301,actorId=actor.Id,actor=actor,group=group,existing=true}end
    story.adventure.specialEvents={byNpc={[301]={initialInjuryPartIds={},initialInjuryTypeIds={},initialInjuryDamage={},injuryRecoveryMinutes={}}},PrepareRecruit=function()return story.adventure.specialEventsPrepare()end}
    story.npcs=Npcs.New(story)
    CS.ProjectY.Data.EncounterRecruitment={
        Validate=function(data,source,value)assert(data==story.adventure.data and source==group and source.actor==value and value.Team==4 and value.HP>0)end,
        Transfer=function(data,source,value)
            assert(value.Growth.Initialized);source.actor=nil;value.Team=1;data.PartyCount=data.PartyCount+1;data.recruit=value;log.transferred=log.transferred+1
        end}
    CS.ProjectY.Data.EquipmentCombatState={RefreshMaximum=function(value,maximum)local hp=value.HP;value.MaxHP=maximum;value.HP=math.min(hp,maximum)end}
    return story,actor,group,log,facts
end
test('victory survivor joins as the same wounded actor without spare inventory or duplicate equipment',function()
    local story,actor,group,log,facts=fixture()
    local plan=assert(Actions.Prepare(story,{1}))
    assert(not actor.Growth.Initialized and group.actor==actor and log.transferred==0 and log.capacity==0)
    Actions.Apply(story,plan)
    assert(story.adventure.data.recruit==actor and actor.HP==17 and actor.MaxHP==75 and actor.Team==1 and group.actor==nil)
    assert(log.prepared==1 and log.transferred==1 and log.joined==1 and facts['recruited:301']==10301)
    assert(not Actions.Prepare(story,{1}) and log.transferred==1)
end)
test('failed protection and full party do not initialize or remove the event actor',function()
    local story,actor,group,log=fixture()
    story.adventure.specialEventsPrepare=function()return nil,'骑士未获救'end
    local plan,reason=Actions.Prepare(story,{1});assert(not plan and reason=='骑士未获救')
    story.adventure.data.PartyCount=4
    plan,reason=Actions.Prepare(story,{1});assert(not plan and reason:match('队伍已满'))
    assert(not actor.Growth.Initialized and group.actor==actor and log.transferred==0)
end)
test('a real item reward still checks bag capacity before recruiting',function()
    local story,actor,group,log=fixture()
    local plan,reason=Actions.Prepare(story,{1,2})
    assert(not plan and reason:match('背包空间不足') and log.capacity==1)
    assert(not actor.Growth.Initialized and group.actor==actor and log.transferred==0)
end)
test('duplicate recruit operations cannot initialize or transfer twice',function()
    local story,actor,group,log=fixture()
    local plan,reason=Actions.Prepare(story,{1,1})
    assert(not plan and reason:match('已经入队'))
    assert(not actor.Growth.Initialized and group.actor==actor and log.transferred==0)
end)
print('encounter_recruitment: '..checks..' checks passed')

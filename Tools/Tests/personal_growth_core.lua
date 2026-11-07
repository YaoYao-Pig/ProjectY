-- Real exported rules and rewards; isolated state bridge, no Editor or live saves.
package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local bridge={}
CS={ProjectY={Data={PeopleState=bridge,DeathDoorState={Alive=function(actor)return not actor.dead end}}}}
local function collection(records)
    return {Count=#records,GetAt=function(_,i)return records[i+1]end,FindActor=function(_,id)
        for _,record in ipairs(records)do if record.Actor.Id==id then return record end end
    end}
end
function bridge.Get(data)return data.people end
function bridge.Prepared(prepared)return prepared.people end
function bridge.RecordGrowthEvent(data,id,kind,eventId)
    local record=data.people:FindActor(id)
    if not record or not record.Joined then return false end
    local field=assert(({battle='BattleWins',rescue='Rescues',learn='LearnedSkills'})[kind])
    local key=kind..':'..eventId
    if record.receipts[key]then return false end
    record.receipts[key]=true;record[field]=record[field]+1;return true
end
function bridge.ChooseGrowth(data,id,expectedStage,choiceId)
    local record=data.people:FindActor(id)
    if not record or not record.Joined or record.Stage~=expectedStage or expectedStage>=2 then return false end
    record.Stage=record.Stage+1;record[record.Stage==1 and 'Branch1' or 'Branch2']=choiceId;return true
end
local nextId=0
local function setup(profileId)
    nextId=nextId+1
    local growth={Initialized=true,skills={},grants=0,HasSkill=function(self,id)return self.skills[id]==true end,
        GrantSkill=function(self,id)if self.skills[id]then return false end;self.grants=self.grants+1;self.skills[id]=true;return true end}
    local actor={Id=nextId,TemplateId=1,Team=1,Growth=growth,traits={[7]=true},innate={},
        HasTrait=function(self,id)return self.traits[id]==true end,
        AddTrait=function(self,id)self.traits[id]=true end,
        RemoveTrait=function(self,id)local existed=self.traits[id];self.traits[id]=nil;return existed end,
        SetMaxHP=function(self,value)self.maxHP=value end}
    local record={Actor=actor,Joined=true,ProfileId=profileId,Stage=0,Branch1=0,Branch2=0,
        BattleWins=0,Rescues=0,LearnedSkills=0,receipts={}}
    local data={Phase='map',SiteId=1,people=collection({record})}
    local log={}
    local adventure={config=config,data=data,sites={[1]={name='Test Site'}},
        growth={Actor=function(_,id)if id==actor.Id then return actor end end,chronicle={Record=function(_,...)log[#log+1]={...}end}},
        battle={stats={Template=function(_,target)return {skillIds=target.innate}end,MaximumHP=function()return 100 end}}}
    return require('Game.Progression.PersonalGrowth').New(adventure),record,actor,data,log
end
local function earn(model,actor)
    for i=1,4 do assert(model:RecordBattleVictory(actor,'battle-'..i))end
    for i=1,2 do assert(model:RecordRescue(actor,'battle-'..i..':target-2'))end
    for _,id in ipairs({101,102,105})do actor.Growth:GrantSkill(id);assert(model:RecordLearnedSkill(actor,id))end
end
-- Four motives have distinct prerequisites; observation never writes progress or rewards.
for profileId=1,4 do
    local model,record,actor,_,log=setup(profileId)
    for _=1,4 do
        local rows=model:Choices(actor.Id)
        assert(#rows==2 and not rows[1].available and not rows[2].available)
        assert(model:Summary(actor.Id).stage==1 and not model:Summary(actor.Id).available)
    end
    assert(record.Stage==0 and record.BattleWins==0 and record.Rescues==0 and record.LearnedSkills==0 and #log==0)
    assert(not model:Choose(actor.Id,model:Choices(actor.Id)[1].choiceId))
    if profileId==2 then
        actor.Growth:GrantSkill(101);assert(model:RecordLearnedSkill(actor,101))
    elseif profileId==3 then assert(model:RecordRescue(actor,'battle-1:target-2'))
    else assert(model:RecordBattleVictory(actor,'battle-1'))end
    assert(model:Choices(actor.Id)[1].available,'Each motive must use its configured real-event counter')
end
print('PASS: motive prerequisites and read-only projections')
-- Both alternatives at each stage work, preserve unrelated traits, and cannot be replayed.
for profileId=1,4 do
    for first=1,2 do
        for second=1,2 do
            local model,record,actor,data,log=setup(profileId);earn(model,actor)
            local rows=model:Choices(actor.Id);local chosen=model.rules.choices:Get(rows[first].choiceId)
            local rejected=model.rules.choices:Get(rows[first==1 and 2 or 1].choiceId)
            local grants=actor.Growth.grants
            local ok,body=model:Choose(actor.Id,chosen.id)
            assert(ok and type(body)=='string' and #body>0 and record.Stage==1 and record.Branch1==chosen.id)
            assert(actor:HasTrait(chosen.traitId) and not actor:HasTrait(rejected.traitId) and actor:HasTrait(7))
            assert(#log==1 and actor.Growth.grants==grants)
            assert(not model:Choose(actor.Id,chosen.id) and not model:Choose(actor.Id,rejected.id))
            rows=model:Choices(actor.Id);local final=model.rules.choices:Get(rows[second].choiceId)
            assert(rows[second].available and rows[second].reward:find(model.rules.traits:Get(chosen.traitId).name,1,true))
            assert(model:Choose(actor.Id,final.id) and record.Stage==2 and record.Branch2==final.id)
            assert(not actor:HasTrait(chosen.traitId) and actor:HasTrait(final.traitId) and actor:HasTrait(7))
            assert(actor.Growth:HasSkill(final.skillIds[1]) and actor.Growth.grants==grants+1)
            assert(#log==2 and #model:Choices(actor.Id)==0 and model:Summary(actor.Id).completed)
            assert(not model:Choose(actor.Id,final.id) and #log==2)
            model:ValidateSaved({people=data.people})
            local reloaded=require('Game.Progression.PersonalGrowth').New(model.adventure)
            assert(#reloaded:Choices(actor.Id)==0 and not reloaded:Choose(actor.Id,final.id))
            assert(not reloaded:RecordBattleVictory(actor,'battle-1') and record.BattleWins==4)
            assert(not reloaded:RecordRescue(actor,'battle-1:target-2') and record.Rescues==2)
            assert(not reloaded:RecordLearnedSkill(actor,101) and record.LearnedSkills==3)
        end
    end
end
print('PASS: all 16 first/final branch combinations, replacement and replay guards')
-- Previously learned and innate skills must be disclosed and must not erase trait benefits.
for _,innate in ipairs({false,true})do
    local model,record,actor=setup(1);earn(model,actor)
    assert(model:Choose(actor.Id,111))
    if innate then actor.innate={2512}else actor.Growth:GrantSkill(2512)end
    local before=actor.Growth.grants
    local row=model:Choices(actor.Id)[1]
    assert(row.reward:find(string.format(require('Language').PeopleGrowthSkillKnown,
        model.rules.skills:Get(2512).name,model.rules.skills:Get(2512).description),1,true))
    assert(model:Choose(actor.Id,121) and actor.Growth.grants==before)
    assert(actor:HasTrait(2003) and not actor:HasTrait(2001) and record.Stage==2)
end
print('PASS: already learned and innate rewards still grant the distinct final trait')
-- External commands and stale UI projections cannot award another actor/profile or bypass phase/life.
do
    local model,record,actor,data,log=setup(1);earn(model,actor)
    for _,id in ipairs({211,121,999999,111.5,'111'})do assert(not model:Choose(actor.Id,id))end
    assert(not model:Choose(actor.Id+100,111))
    data.Phase='battle';assert(not model:Choose(actor.Id,111));data.Phase='map'
    actor.dead=true;assert(not model:Choices(actor.Id)[1].available and not model:Choose(actor.Id,111));actor.dead=false
    local replacement={Id=actor.Id};assert(not model:RecordBattleVictory(replacement,'different-instance'))
    record.Joined=false
    assert(#model:Choices(actor.Id)==0 and model:Summary(actor.Id)==nil and not model:RecordBattleVictory(actor,'unjoined'))
    assert(not model:Choose(actor.Id,111));record.Joined=true
    assert(record.Stage==0 and #log==0 and record.BattleWins==4)
    assert(not pcall(function()model:RecordBattleVictory(actor,'')end))
    assert(not pcall(function()model:RecordLearnedSkill(actor,106)end))
    assert(model:Choose(actor.Id,111))
    record.Branch1=211;assert(not pcall(function()model:ValidateSaved({people=data.people})end))
end
print('PASS: phase, life, identity, malformed state, and stale/cross-profile commands')
-- Save validation rejects forged claims and rewards even before the first choice.
do
    local model,record,actor,data=setup(1)
    local function validate()model:ValidateSaved({people=data.people})end
    validate()
    actor:AddTrait(2001);assert(not pcall(validate));actor:RemoveTrait(2001)
    earn(model,actor);assert(model:Choose(actor.Id,111));validate()
    actor:AddTrait(2002);assert(not pcall(validate));actor:RemoveTrait(2002)
    actor:RemoveTrait(2001);assert(not pcall(validate));actor:AddTrait(2001)
    local victories=record.BattleWins;record.BattleWins=0;assert(not pcall(validate));record.BattleWins=victories
    assert(model:Choose(actor.Id,121));validate()
    actor:AddTrait(2001);assert(not pcall(validate));actor:RemoveTrait(2001)
    actor:AddTrait(2005);assert(not pcall(validate));actor:RemoveTrait(2005)
    actor.Growth.skills[2512]=nil;assert(not pcall(validate));actor.Growth.skills[2512]=true
    validate()
end
print('PASS: saved prerequisites, missing rewards, and unchosen/replaced/foreign traits')

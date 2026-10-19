package.path='Lua/?.lua;'..package.path
local config
if SocialSource then
    config={GetTable=function(_,name)
        local rows=assert(SocialSource[name],name)
        return {Count=#rows,All=function() return rows end,Get=function(_,id)
            for _,row in ipairs(rows) do if row.id==id then return row end end;error('Unknown '..name..':'..id)
        end}
    end}
else
    config=require('Config.ConfigSystem')()
    config:OnInit({services={ReadConfig=function(_,name)
        local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
        local bytes=file:read('*a');file:close();return bytes
    end}})
end
local Rules=require('Game.Progression.PartyStoryRules');local rules=Rules.New(config)
local count=0
local function test(name,run) run();count=count+1;print('PASS '..name) end
local function actor(id)
    local result={Id=id,TemplateId=id,Team=1,HP=20,MaxHP=100,traits={}}
    function result:RemoveTrait(trait) local present=self.traits[trait];self.traits[trait]=nil;return present==true end
    function result:SetMaxHP(value) self.MaxHP=value end
    return result
end
local a,b,c=actor(1),actor(2),actor(3)
local function heal(before,after,periodic)
    return {kind='heal',sourceId=1,targetId=2,amount=after-before,hpBefore=before,hpAfter=after,periodic=periodic==true}
end
test('rescue needs real low-health immediate allied healing during combat',function()
    assert(rules:IsRescue(heal(25,40),'combat',a,b))
    assert(not rules:IsRescue(heal(26,41),'combat',a,b))
    assert(not rules:IsRescue(heal(20,20),'combat',a,b))
    assert(not rules:IsRescue(heal(0,15),'combat',a,b))
    assert(not rules:IsRescue(heal(20,35,true),'combat',a,b))
    assert(not rules:IsRescue(heal(20,35),'deployment',a,b))
    assert(not rules:IsRescue(heal(20,35),'combat',a,a))
    c.Team=2;assert(not rules:IsRescue(heal(20,35),'combat',a,c));c.Team=1
    local bad=heal(20,35);bad.hpBefore=nil;assert(not pcall(function() rules:IsRescue(bad,'combat',a,b) end))
end)
test('production effect execution preserves exact health snapshots and periodic provenance through the battle event',function()
    local treated=actor(2)
    function treated:Heal(amount) local before=self.HP;self.HP=math.min(self.MaxHP,self.HP+amount);return self.HP-before end
    local received
    local gateway={data={AddLog=function() end},Changed={Emit=function(_,event) received=event end}}
    local emit=require('Game.Battle.BattleSystem').Emit
    local effects=require('Game.Battle.GameEffects').New({Template=function() return {name='同伴'} end},nil,
        function(...) emit(gateway,...) end)
    effects:Execute({kind='heal'},treated,100,1,'救援者','治疗',a,false,{tag='kept'})
    assert(received.hpBefore==20 and received.hpAfter==100 and received.amount==80 and received.periodic==false and received.impact.tag=='kept')
    assert(rules:IsRescue(received,'combat',a,treated))
    treated.HP=20;effects:Execute({kind='heal'},treated,10,1,'救援者','持续治疗',a,false,nil,true)
    assert(received.hpBefore==20 and received.hpAfter==30 and received.periodic==true and not rules:IsRescue(received,'combat',a,treated))
end)
test('configured thresholds cross once and the removable negative trait has an actual penalty',function()
    assert(rules:Stage(29).minimum==0 and rules:Stage(30).minimum==30 and rules:Stage(60).minimum==60)
    assert(#rules:Crossed(25,35)==1 and #rules:Crossed(35,45)==0 and #rules:Crossed(20,70)==2)
    local negative=false
    for _,id in ipairs(rules.settings.removeTraitIds) do if rules.traits:Get(id).amount<0 then negative=true end end
    assert(negative,'Rescue trait rules must include a real negative modifier')
end)
-- The data double supplies the C# boundary; tests exercise production story orchestration and chronicle projections.
local function dataDouble()
    local state={Revision=0,BondCount=0,HonorCount=0,ParticipantCount=0,bonds={},honors={},rescues={},participants={}}
    local function key(x,y) return math.min(x,y)..':'..math.max(x,y) end
    function state:Find(x,y) return self.bonds[key(x,y)] end
    function state:Score(x,y) local row=self:Find(x,y);return row and row.Score or 0 end
    function state:Bond(x,y)
        local k=key(x,y);if not self.bonds[k] then self.bonds[k]={Score=0,SharedBattles=0,Rescues=0};self.BondCount=self.BondCount+1 end
        return self.bonds[k]
    end
    function state:ResetBattle() self.open=false;self.participants={};self.ParticipantCount=0;self.seen={} end
    function state:BeginBattle() self:ResetBattle();self.open=true end
    function state:AddParticipant(who) self.participants[#self.participants+1]=who;self.ParticipantCount=#self.participants end
    function state:GetParticipantAt(index) return self.participants[index+1] end
    function state:IsParticipant(id) for _,who in ipairs(self.participants) do if who.Id==id then return true end end;return false end
    function state:TryRescue(x,y,amount)
        assert(self.open);local k=key(x,y);if self.seen[k] then return false end;self.seen[k]=true
        local row=self:Bond(x,y);row.Score=math.min(100,row.Score+amount);row.Rescues=row.Rescues+1
        self.rescues[x]=(self.rescues[x] or 0)+1;self.Revision=self.Revision+1;return true
    end
    function state:SettleBattle(victory,amount)
        if not self.open then return false end;self.open=false
        if victory then for i,first in ipairs(self.participants) do for j=i+1,#self.participants do
            local second=self.participants[j]
            if first.HP>0 and second.HP>0 then local row=self:Bond(first.Id,second.Id);row.Score=math.min(100,row.Score+amount);row.SharedBattles=row.SharedBattles+1;self.Revision=self.Revision+1 end
        end end end;return true
    end
    function state:RescueCount(id) return self.rescues[id] or 0 end
    function state:HasHonor(id,honor) return self.honors[id..':'..honor]==true end
    function state:AwardHonor(id,honor) assert(not self:HasHonor(id,honor));self.honors[id..':'..honor]=true;self.HonorCount=self.HonorCount+1;self.Revision=self.Revision+1 end
    return state
end
local state=dataDouble();local data={PartyBonds=state,PartyCount=3,SiteId=1,JournalCount=0,minutes=1505,journal={}}
function data:GetPartyAt(index) return ({a,b,c})[index+1] end
function data:GetJournalAt(index) return self.journal[index+1] end
function data:RecordPair(kind,title,body,location,eventId,choiceId,subject,object,delta)
    local row={Sequence=#self.journal+1,Kind=kind,Title=title,Body=body,Location=location,SubjectId=subject,ObjectId=object,RelationDelta=delta,Minutes=self.minutes,Day=math.floor(self.minutes/1440)+1}
    function row:Involves(id) return self.SubjectId==id or self.ObjectId==id end
    self.journal[#self.journal+1]=row;self.JournalCount=#self.journal
end
local stats={Template=function(_,who) return {name=({'艾岚 · 剑士','诺拉 · 游侠','伊文 · 法师'})[who.Id]} end,MaximumHP=function() return 100 end}
local chronicle=require('Game.Progression.Chronicle').New(config,data,stats)
local units={a,b};local signal=require('Core.Signal')(function(message) error(message) end)
local battle={stats=stats,data={Phase='combat'},Changed=signal,Units=function() return units end}
local model=require('Game.Progression.PartyStory').New({config=config,data=data,battle=battle,growth={chronicle=chronicle},sites={{name='石桥遗址'}}})
model:Start()
test('battle rescue identifies both actors, removes configured traits, and excludes bystanders from history',function()
    b.traits[3]=true;b.traits[6]=true
    signal:Emit({kind='battle_started'});signal:Emit(heal(20,35))
    assert(state:Score(1,2)==25 and state:RescueCount(1)==1 and not b.traits[3] and not b.traits[6])
    assert(#chronicle:Rows(1)==3 and #chronicle:Rows(2)==3 and #chronicle:Rows(3)==0)
    local rescue=data.journal[1];assert(rescue.SubjectId==1 and rescue.ObjectId==2 and rescue.RelationDelta==25 and rescue.Location=='石桥遗址')
    assert(chronicle:Rows(1)[1].date=='第2日 01:05')
    local before=data.JournalCount;signal:Emit(heal(20,35));assert(data.JournalCount==before and state:RescueCount(1)==1)
    local reverse=heal(20,35);reverse.sourceId=2;reverse.targetId=1;signal:Emit(reverse);assert(state:RescueCount(2)==0)
end)
test('only surviving participants gain common victory and a threshold announcement; settlement is idempotent',function()
    assert(model:Settle('victory','石桥遗址'));assert(state:Score(1,2)==35 and state:Find(1,2).SharedBattles==1)
    assert(state:Score(1,3)==0 and #chronicle:Rows(3)==0)
    local before=data.JournalCount;assert(not model:Settle('victory','石桥遗址'));assert(data.JournalCount==before)
    assert(chronicle:Rows(1)[1].title=='关系 · 信任')
    units={a,b,c};signal:Emit({kind='battle_started'});c.HP=0
    assert(model:Settle('victory','石桥遗址'));assert(state:Score(1,3)==0 and state:Score(2,3)==0);c.HP=20
end)
test('three distinct rescues grant one persistent honor and overview shows progress and relationships',function()
    units={a,b}
    for _=1,2 do signal:Emit({kind='battle_started'});signal:Emit(heal(20,35));model:Settle('draw','石桥遗址') end
    assert(state:RescueCount(1)==3 and state:HasHonor(1,1) and state.HonorCount==1)
    local rows=model:OverviewRows(a);assert(#rows==3 and rows[3].title=='★ 荣誉 · 守望者' and rows[3].body:find('3 / 3',1,true))
    signal:Emit({kind='battle_started'});signal:Emit(heal(20,35));assert(state.HonorCount==1 and state:Score(1,2)==100)
end)
test('shutdown unsubscribes and malformed config fails before battle subscription',function()
    model:Dispose();local before=state:RescueCount(1);signal:Emit({kind='battle_started'});signal:Emit(heal(20,35));assert(state:RescueCount(1)==before)
    local bad={GetTable=function(_,name)
        if name=='PartyBondStageTable' then return {All=function() return {{id=1,minimum=30}} end} end
        return config:GetTable(name)
    end}
    assert(not pcall(function() Rules.New(bad) end))
end)
print('Social core: '..count..' checks passed')

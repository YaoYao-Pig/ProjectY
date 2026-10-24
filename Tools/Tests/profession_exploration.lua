package.path='Lua/?.lua;'..package.path
local L=setmetatable({ProfessionExploreExtracted='%s:%d',ProfessionExploreRumor='%s/%s/%d/%d',
    ProfessionExploreCared='%s:%d',ProfessionExploreCleansed='%s',ProfessionExploreTrackMoved='%s:%d,%d>%d,%d@%d',
    ProfessionExploreTrackStill='%s:%d,%d=%d,%d@%d'},{__index=function(_,key)return key end})
package.loaded.Language=L
local Exploration=require('Game.Adventure.ProfessionExploration')
local function tableOf(rows)
    local index={};for _,row in ipairs(rows)do index[row.id]=row end
    return {All=function()return rows end,Get=function(_,id)return assert(index[id],tostring(id))end,Find=function(_,id)return index[id]end}
end
local rules={
    {id=1806,kind='extract',range=2,minutes=5,rewardItemId=8014,rewardCount=1},
    {id=1816,kind='rumor',range=3,minutes=30,amount=12},
    {id=1826,kind='care',range=3,minutes=10,amount=360,itemId=91,itemCount=1},
    {id=1836,kind='curse',range=0,minutes=5},
    {id=1856,kind='track',range=4,minutes=5,amount=120}}
local rows=tableOf(rules)
local curse={id=8008,itemId=8008,triggerBuffId=12020,applyEffectId=20020,cleanseItemId=8017,description='Curse',clue='Cleanse'}
local tables={ProfessionExplorationTable=rows,ProfessionCurseTable=tableOf({curse}),MapAreaTable=tableOf({{id=1,profileId=1}}),
    MapAreaForestTable=tableOf({{id=1,fernAssetId=700}}),CombatSkillTable=tableOf({{id=1806,name='Extract'},{id=1816,name='Rumor'},
    {id=1826,name='Care'},{id=1836,name='Curse'},{id=1856,name='Track'}})}
local config={GetTable=function(_,name)return assert(tables[name],name)end}
local function effects()
    local list={};return {Count=0,GetAt=function(_,i)return list[i+1]end,rows=list}
end
local actor={Id=1,HP=10,TemplateId=1,Effects=effects()}
local ally={Id=2,HP=10,TemplateId=2,Effects=effects(),recovery=600,permanent=false}
local beast={Id=31,HP=10,TemplateId=31,AnimalOwnerId=0,Q=1,R=0}
local members={actor,ally};local memberCells={1,2};local visible={1,2,3,4}
local area={configId=1,areaType=3,name='Forest',props={{assetId=700,q=1,r=0}},facilities={},cells={}}
for i=1,5 do area.cells[i]={index=i,q=i-1,r=0,layer=0}end
function area:Find(q,r)return r==0 and self.cells[q+1]end
function area:CanSee()return true end
function area:FindPath(from,to)local result={};for _=1,math.abs(from-to)do result[#result+1]=to end;return result end
local state={MemberCount=2,VisibleCount=4,EncounterCount=1,
    GetMemberIdAt=function(_,i)return members[i+1].Id end,GetMemberCellAt=function(_,i)return memberCells[i+1]end,
    GetVisibleAt=function(_,i)return visible[i+1]end,
    GetEncounterAt=function()return {EnemyCount=1,GetEnemyAt=function()return beast end}end}
local facts,keys={},{}
local narrative={Minutes=60,ValueCount=0,GetValue=function(_,key)return facts[key]or 0 end,GetValueKeyAt=function(_,i)return keys[i+1]end}
function narrative:SetValue(key,value)
    if facts[key]==nil then keys[#keys+1]=key;self.ValueCount=#keys end;facts[key]=value
end
local stock={[91]=1,[8017]=1};local weapon={Id=99,ItemId=8008};local mainWeapon,offWeapon
local bag={CountItem=function(_,id)return stock[id]or 0 end,
    ConsumeStack=function(_,id,n)assert((stock[id]or 0)>=n);stock[id]=stock[id]-n end,
    Equipped=function()return mainWeapon end,Offhand=function()return offWeapon end}
local canGrant=true;local journal={};local service=true
local visited={}
local adventure={config=config,data={Narrative=narrative,Phase='area',PartyCount=2,GetPartyAt=function(_,i)return members[i+1]end,HasVisited=function(_,id)return visited[id]end,
    Areas={Active=state,ActiveSiteId=1}},areas={forestType=3,ActiveLayout=function()return area end},
    factions={ServiceAllowed=function()return service,'closed'end},sites={{id=1,name='Town',q=0,r=0},{id=2,name='Real mine',q=2,r=0},{id=3,name='Far mine',q=100,r=0}},
    narrative={AdvanceMinutes=function(_,n)narrative.Minutes=narrative.Minutes+n end},
    equipment={data=bag,rules={items=tableOf({{id=8014,name='Reagent'},{id=8008,name='Ritual knife'}})},
        CanGrant=function()return canGrant end,Grant=function(_,id,n)assert(canGrant);stock[id]=(stock[id]or 0)+n;return true end},
    growth={chronicle={Record=function(_,kind,subject,title,text)assert(kind=='event');journal[#journal+1]=text end}},
    battle={stats={animals={byUnit={[31]=true}},units=tableOf({{id=31,name='Wolf'}}),Template=function(_,unit)return {name='Actor'..unit.Id}end}}}
local effectSerial=0
adventure.battle.gameEffects={Apply=function(_,id,source,target)
    assert(id==20020);effectSerial=effectSerial+1;target.Effects.rows[#target.Effects.rows+1]={Id=effectSerial,EffectId=12020}
    target.Effects.Count=#target.Effects.rows;return true end,
    Remove=function(_,target,id)for i,e in ipairs(target.Effects.rows)do if e.Id==id then table.remove(target.Effects.rows,i);target.Effects.Count=#target.Effects.rows;return end end;error('missing effect')end}
CS={ProjectY={Data={ProfessionExplorationState={
    CanCare=function(unit,now,work)return unit.HP>0 and not unit.permanent and unit.recovery>now+work end,
    Care=function(unit,equipment,id,count,now,work,amount)
        assert(not unit.permanent);equipment:ConsumeStack(id,count);unit.recovery=math.max(now+work,unit.recovery-amount);return true end}}}}
local subject=Exploration.New(adventure)

-- A failed capacity preflight consumes neither the plant nor time; one real instance yields once.
canGrant=false;assert(not subject:Use(actor,1,rows:Get(1806)));assert(narrative.Minutes==60 and not stock[8014])
canGrant=true;assert(subject:Use(actor,1,rows:Get(1806)));assert(stock[8014]==1 and narrative.Minutes==65)
assert(not subject:Use(actor,1,rows:Get(1806)) and stock[8014]==1)
local restored=Exploration.New(adventure);assert(not restored:Plant(actor,rows:Get(1806)),'Harvest fact must survive controller replacement')

-- Rumors require a real open tavern, return a real nearby site, and are daily per town.
assert(not subject:CanUse(actor,1,rows:Get(1816)))
area.facilities={{kind='tavern',name='Inn',entryIndex=2}}
service=false;assert(not subject:CanUse(actor,1,rows:Get(1816)));service=true
visited[2]=true;assert(not subject:CanUse(actor,1,rows:Get(1816)),'Already visited places are not new rumors');visited[2]=nil
assert(subject:Use(actor,1,rows:Get(1816)));assert(journal[#journal]=='Inn/Real mine/2/0')
assert(not subject:Use(actor,1,rows:Get(1816)))
narrative.Minutes=1500;assert(not subject:Use(actor,1,rows:Get(1816)),'Do not invent another nearby rumor')

-- Care targets a living nearby ally, preserves permanent injuries and charges once per day.
narrative.Minutes=100;ally.permanent=true;assert(not subject:CanUse(actor,2,rows:Get(1826)))
ally.permanent=false;assert(subject:Use(actor,2,rows:Get(1826)));assert(ally.recovery==240 and stock[91]==0)
stock[91]=1;assert(not subject:Use(actor,2,rows:Get(1826)) and stock[91]==1)

-- Each cursed weapon has its own effect; identification does not consume a cleansing reagent.
offWeapon=weapon;subject:OnEquip(actor,weapon);assert(actor.Effects.Count==1)
subject:OnEquip(actor,weapon);assert(actor.Effects.Count==1,'Re-equip does not retrigger')
local second={Id=100,ItemId=8008};subject:OnEquip(actor,second);assert(actor.Effects.Count==2)
assert(subject:Use(actor,1,rows:Get(1836)));assert(stock[8017]==1 and actor.Effects.Count==2)
assert(subject:Use(actor,1,rows:Get(1836)));assert(stock[8017]==0 and actor.Effects.Count==1 and actor.Effects:GetAt(0).Id==2)
subject:OnEquip(actor,weapon);assert(actor.Effects.Count==1,'Purified instance stays purified')

-- Observations are explicit, never performed by CanUse; unseen movement cannot leak a position.
local values=narrative.ValueCount;assert(not subject:CanUse(actor,1,rows:Get(1856)));assert(narrative.ValueCount==values)
subject:ObserveTracks();assert(subject:Track(actor,rows:Get(1856)).current==2)
beast.Q=2;subject:ObserveTracks();local trace=subject:Track(actor,rows:Get(1856));assert(trace.previous==2 and trace.current==3)
state.VisibleCount=1;beast.Q=4;subject:ObserveTracks();assert(subject:Track(actor,rows:Get(1856)).current==3)
assert(subject:Use(actor,1,rows:Get(1856)));assert(journal[#journal]:find('1,0>2,0',1,true))
narrative.Minutes=narrative.Minutes+121;assert(not subject:Track(actor,rows:Get(1856)))
for key in pairs(facts)do assert(key:match('^flag:[%a_][%w_]*$'),'Narrative facts must obey save validation: '..key)end
local registered={};subject:RegisterHandlers({Register=function(_,kind,handler)registered[kind]=handler end})
local count=0;for _ in pairs(registered)do count=count+1 end;assert(count==5)
print('PASS profession exploration: real plants, inventory preflight, per-instance persistence, sourced daily rumors, ally care limits, independent curse cleansing, explicit visible-only footprints, expiry, save-safe facts and five handlers')

-- Targeted Lua checks for occupied settlement services and multi-side attribution.
package.path='Lua/?.lua;'..package.path
CS={ProjectY={Data={}}}
local count=0
local function test(name,run)run();count=count+1;print('PASS '..name)end

test('shop blocks entry and purchase, keeps real stock, and applies recovery at the data boundary',function()
    local Shop=require('Game.Shop.ShopModel')
    local allowed,factor,minute,interactions,rolls,buys,adjustments=true,.3,0,0,0,0,0
    local settlement={LiberatedAt=-1};local stock
    local data={Revision=0,IsOpen=false}
    function data:Find()return stock end
    function data:Refresh(merchant,site,npc,template,period,entries,items,counts,prices)
        assert(counts[1]==10 and counts[2]==1,'Lua must pass original roll quantities to the authoritative bridge')
        stock={SiteId=site,LocalNpcId=npc,TemplateId=template,Period=period,Count=2,
            entries={{EntryId=entries[1],ItemId=items[1],Count=counts[1],Price=prices[1]},
                {EntryId=entries[2],ItemId=items[2],Count=counts[2],Price=prices[2]}}}
        function stock:Find(id)return self.entries[id]end
        function stock:GetAt(index)return self.entries[index+1]end
        self.Revision=self.Revision+1;return stock
    end
    function data:Open(value)assert(not self.IsOpen);self.Active=value;self.IsOpen=true;self.Revision=self.Revision+1 end
    function data:Close()self.Active=nil;self.IsOpen=false end
    function data:Buy()buys=buys+1;return ''end
    -- Persistent idempotence belongs to the C# Data checks; this fixture observes Lua calls.
    CS.ProjectY.Data.FactionPersistence={ApplyShopRecovery=function(shops,value,liberatedAt,recovery)
        assert(shops==data and value==stock);adjustments=adjustments+1
        if value.applied==liberatedAt then return end
        for _,entry in ipairs(value.entries)do entry.Count=math.floor(entry.Count*recovery)end
        value.applied=liberatedAt
    end}
    local area={name='town',npcs={{id=1,templateId=3}}}
    local adventure={data={Phase='area',Seed=123,Areas={ActiveSiteId=7,Active={Stop=function()end}}},
        player={Coins=100},narrative={data={DialogueOpen=false,Minutes=0}},
        factions={data={FindSite=function()return settlement end},ServiceAllowed=function()return allowed,'occupied'end,Recovery=function()return factor end},
        areas={ActiveLayout=function()return area end,Interact=function()interactions=interactions+1;return true end,CloseInteraction=function()end},
        growth={chronicle={Record=function()end}},equipment={data={},CanGrant=function()return true end},
        config={GetTable=function()return {Get=function()return {name='merchant'}end}end}}
    local rules={Resolve=function()return {id=1,templateId=1}end,Period=function()return minute end,
        Roll=function()rolls=rolls+1;return {1,2},{31,40},{10,1},{3,4}end,
        items={Get=function(_,id)return {id=id,name='supplies',kind='material',width=1,height=1}end},
        templates={Get=function()return {name='goods',refreshDays=1}end}}
    local shop=setmetatable({adventure=adventure,rules=rules,data=data},Shop)
    allowed=false;assert(not shop:Open(1) and interactions==0 and rolls==0)
    allowed=true;assert(shop:Open(1) and stock.entries[1].Count==10 and adjustments==0)
    shop:Close();settlement.LiberatedAt=0
    assert(shop:Open(1) and rolls==1 and stock.entries[1].Count==3 and stock.entries[2].Count==0)
    shop:Close();factor=.8
    assert(shop:Open(1) and rolls==1 and stock.entries[1].Count==3 and adjustments==2)
    allowed=false;assert(not shop:Buy(1,data.Revision,1) and buys==0)
    for _,row in ipairs(shop:Snapshot().rows)do assert(not row.available and row.reason=='occupied')end
    allowed=true;assert(shop:Buy(1,data.Revision,1) and buys==1)
    shop:Close();minute=1
    assert(shop:Open(1) and rolls==2 and stock.entries[1].Count==8)
    shop:Close();settlement.LiberatedAt=100;factor=.4
    assert(shop:Open(1) and rolls==2 and stock.entries[1].Count==3)
    shop:Close();minute=2;factor=1
    assert(shop:Open(1) and rolls==3 and stock.entries[1].Count==10 and stock.applied==100)
end)

test('occupation hides residents, recovery gates only recruits, and recruited identity wins',function()
    local Npcs=require('Game.Narrative.NpcSystem')
    local service,available=true,false;local checked={};local present={};local preparedCount=0
    local definitions={[10]={recruitable=true,actorTemplateId=3},[11]={recruitable=false},[12]={recruitable=true}}
    local actor={SetMaxHP=function()end,Restore=function()end}
    local story={data={DialogueOpen=false,GetValue=function(_,key)return key=='recruited:12' and 10012 or 0 end},
        rules={npcs={Get=function(_,id)return assert(definitions[id])end}},
        adventure={data={Seed=123,Areas={ActiveSiteId=7,Active={SetNpcPresent=function(_,id,value)present[id]=value end}},
            PrepareRecruitActor=function()preparedCount=preparedCount+1;return actor end},
            factions={ServiceAllowed=function()return service,'occupied'end,NpcAvailable=function(_,site,id)
                assert(site==7 and definitions[id].recruitable);checked[id]=true;return available end},
            areas={ActiveLayout=function()return {npcs={{id=1},{id=2,narrativeId=10},{id=3,narrativeId=11},{id=4,narrativeId=12}}}end},
            characterAppearances={Party=function()end},growth={PrepareActor=function()end},
            equipment={initialLoadouts={Validate=function()return true end}},battle={stats={MaximumHP=function()return 40 end}}}}
    local npcs=Npcs.New(story);npcs.locations={[10]=7,[12]=7}
    npcs:SyncPresence();assert(present[1] and not present[2] and present[3] and not present[4])
    assert(checked[10] and not checked[11] and not checked[12])
    assert(not npcs:PrepareRecruit(10) and preparedCount==0)
    service=false;available=true;npcs:SyncPresence()
    for i=1,4 do assert(not present[i])end
    assert(not npcs:PrepareRecruit(10) and preparedCount==0)
    service=true;npcs:SyncPresence();assert(present[1] and present[2] and present[3] and not present[4])
    assert(npcs:PrepareRecruit(10).actor==actor and preparedCount==1)
    assert(not npcs:PrepareRecruit(12) and preparedCount==1)
end)

test('only player-attributed hostile defeats advance mission kills',function()
    local Battle=require('Game.Battle.BattleSystem');local Story=require('Game.Narrative.NarrativeSystem')
    local units={{Id=1,Team=1,TemplateId=1,AnimalOwnerId=0},{Id=2,Team=2,TemplateId=4,AnimalOwnerId=0},
        {Id=3,Team=3,TemplateId=5,AnimalOwnerId=0},{Id=4,Team=4,TemplateId=6,AnimalOwnerId=0},
        {Id=5,Team=0,TemplateId=7,AnimalOwnerId=0},{Id=6,Team=2,TemplateId=8,AnimalOwnerId=1}}
    local callback;local battle=Battle();battle.data={UnitCount=#units,GetUnitAt=function(_,i)return units[i+1]end}
    battle.board={sideRelations={[1]={[2]='hostile',[3]='hostile',[4]='allied'}}}
    battle.Changed={Subscribe=function(_,fn)callback=fn;return function()end end}
    local kills={};local story=Story();local legendKills={}
    story.adventure={battle=battle,parties={legends={RecordDefeat=function(_,target)legendKills[#legendKills+1]=target.TemplateId end}}};local townKills=0
    story.townMissions={RecordKill=function()townKills=townKills+1 end}
    story.data={RecordKill=function(_,id)kills[#kills+1]=id end};story:OnStart()
    callback({kind='damage',sourceId=1,targetId=2})
    callback({kind='defeated',sourceId=4,targetId=2})
    callback({kind='defeated',sourceId=2,targetId=3})
    callback({kind='defeated',sourceId=1,targetId=4})
    callback({kind='defeated',sourceId=1,targetId=5})
    callback({kind='defeated',sourceId=1,targetId=6})
    callback({kind='defeated',targetId=2})
    assert(#kills==0 and #legendKills==0)
    callback({kind='defeated',sourceId=1,targetId=2})
    callback({kind='defeated',sourceId=1,target=units[3]})
    assert(#kills==2 and kills[1]==4 and kills[2]==5)
    assert(townKills==2,'Town clear missions must use the same hostile player attribution')
    assert(#legendKills==2 and legendKills[1]==4 and legendKills[2]==5,'Legendary resolution must use the same hostile player attribution')
end)

test('dead independent sides drop once including allies, excluding players and tamed animals',function()
    local Loot=require('Game.Loot.MapLoot');local actors={};local dropped={}
    for i,team in ipairs({2,3,4,1,0,2,4})do
        local actor={Id=i,TemplateId=99,Team=team,HP=i==7 and 30 or 0,AnimalOwnerId=i==6 and 1 or 0,Q=i,R=0,DropResolved=false}
        function actor:ResolveDrop()assert(not self.DropResolved);self.DropResolved=true end
        actors[#actors+1]=actor
    end
    local state={LootCount=0,GetLootAt=function(_,i)return {Id=i+1}end}
    local areas={data={Active=state},ActiveLayout=function()return {seed=123,Find=function(_,q)return {index=q}end}end}
    local loot=setmetatable({equipment={data={}},rules={enemies={[99]={lootTableId=102,seedSalt=1}}}},Loot)
    function loot:ActorHasEquipment()return true end
    function loot:Add(target)target.LootCount=target.LootCount+1;return true end
    function loot:Prepare()end
    CS.ProjectY.Data.EquipmentCombatState={DropActor=function(_,_,_,id)dropped[#dropped+1]=id end}
    local stats={Template=function()return {name='fighter'}end}
    assert(loot:ActorDrops(areas,actors,stats)==3 and #dropped==3)
    assert(loot:ActorDrops(areas,actors,stats)==0 and #dropped==3)
    assert(actors[1].DropResolved and actors[2].DropResolved and actors[3].DropResolved)
    for i=4,7 do assert(not actors[i].DropResolved)end
end)

print('PASS faction services: '..count..' focused checks')

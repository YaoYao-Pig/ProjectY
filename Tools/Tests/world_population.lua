-- Population repair and paid replacements, using real configuration and small native-state fixtures.
package.path='Lua/?.lua;'..package.path
local Parties=require('Game.Adventure.WorldParties')
local Factions=require('Game.Adventure.WorldFactions')
local Rules=require('Game.Adventure.FactionRules')
local LOD=require('Game.Adventure.WorldLOD')
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local value=file:read('*a');file:close();return value
end}})
local rules=Rules.New(config)
local function equal(actual,expected,message)
    assert(actual==expected,(message or 'Unexpected value')..': '..tostring(actual)..' ~= '..tostring(expected))
end
local passed=0
local function test(name,run)run();passed=passed+1;print('PASS '..name)end
local function fixture()
    local list,states,cells={},{},{}
    for q=0,30 do cells[#cells+1]={q=q,r=0,height=0,regionId=1}end
    local map={GetCells=function()return cells end,GetRegion=function()return {regionType=1}end,
        GetCell=function(_,q,r)return assert(r==0 and cells[q+1])end,FindCell=function(_,q,r)return r==0 and cells[q+1] or nil end}
    local data={Count=0,GetAt=function(_,i)return list[i+1]end,Find=function(_,id)return list[id]end}
    function data:Add(definition,q,r,home,seed)
        local party={Id=#list+1,DefinitionId=definition,HomeSiteId=home,Travel={Q=q,R=r,Progress=0},
            Defeated=false,BattleSiteId=0,SafeUntil=0,MemberCount=0,CargoCount=0,Mission='patrol',StrengthReady=true,Lod=1}
        function party:ConfigureFaction(faction,hq,hr,role)self.FactionId=faction;self.HomeQ=hq;self.HomeR=hr;self.Role=role end
        function party:GetMemberAt(i)return self.actors[i+1]end
        list[#list+1]=party;self.Count=#list;return party
    end
    local fd={SiteCount=0,GetSiteAt=function(_,i)return states[i+1]end}
    local adventure={config=config,data={Seed=42},battle={encounters=config:GetTable('CombatEncounterTable')},
        travel={Cost=function()return 1 end},sites={{id=1,q=-20,r=0}}}
    local factions=setmetatable({adventure=adventure,rules=rules,data=fd},Factions)
    function factions:PrepareRoster(party,encounter)
        party.MemberCount=#adventure.battle.encounters:Get(encounter).enemyIds;party.actors={}
        for i=1,party.MemberCount do party.actors[i]={identity=party.Id..':'..i,HP=100,MaxHP=100,AnimalOwnerId=0} end
    end
    adventure.factions=factions
    local definition=config:GetTable('WorldPartyTable'):Get(3)
    local parties=setmetatable({adventure=adventure,data=data,map=map,sites=adventure.sites,towns={},
        rule=config:GetTable('WorldPartyRuleTable'):Get(1),definitions={All=function()return {definition}end,Get=function(_,id)equal(id,3);return definition end},
        legends={Find=function()return nil end}},Parties)
    function parties:Roam(party)party.roamed=true end
    function parties:Path(from,to)return {from,to}end
    adventure.parties=parties
    return parties,factions,list,states,fd,definition
end

test('real orc and goblin diplomacy is hostile to humans and the player',function()
    for _,id in ipairs({4,5}) do equal(rules:Relation(0,id),'hostile');equal(rules:Relation(1,id),'hostile');equal(rules:Relation(id,1),'hostile')end
end)

test('ordinary roaming parties can initialize without an available faction outpost',function()
    local p,_,list,_,_,row=fixture();p:Spawn(false)
    equal(#list,row.count)
    for _,party in ipairs(list)do equal(party.HomeSiteId,0);equal(party.Role,'raider');assert(party.roamed and party.MemberCount>0)end
end)

test('old saves fill missing ordinary mobiles once and do not revive historical defeated rosters',function()
    local p,_,list,_,_,row=fixture()
    local guard=p.data:Add(3,0,0,2,1);guard.Role='garrison'
    local defeated=p.data:Add(3,2,0,0,1);defeated.Role='raider';defeated.Defeated=true;defeated.MemberCount=1;defeated.actors={{HP=0}}
    p:Spawn(true,true);equal(#list,row.count+1,'Garrison must not count against the roaming population')
    p:Spawn(true,true);equal(#list,row.count+1,'Repeated loads must not duplicate mobiles')
    equal(defeated.actors[1].HP,0);equal(defeated.Defeated,true)
end)

test('old-save roaming repair never creates replacement trade or escort caravans',function()
    local p,_,list=fixture();local row=config:GetTable('WorldPartyTable'):Get(1)
    p.definitions={All=function()return {row}end}
    p:Spawn(true,true);equal(#list,0)
end)

test('legendary identity remains unique and defeated actors never respawn on load',function()
    local p,_,list=fixture();local row=config:GetTable('WorldPartyTable'):Get(15)
    p.definitions={All=function()return {row}end};p.legends={Find=function(_,id)return id==15 and row end}
    p:Spawn(true,true);equal(#list,1)
    local original=list[1].actors[1];original.HP=0;list[1].Defeated=true
    p:Spawn(true,true);equal(#list,1);equal(list[1].actors[1],original);equal(original.HP,0)
end)

test('population repair preserves saves that have reached native party capacity',function()
    local p=fixture();p.data.Count=4096
    local guard={DefinitionId=3,Role='garrison',Travel={Q=0,R=0}}
    function p.data:GetAt()return guard end
    function p.data:Add()error('A full world must not add another party during load')end
    p:Spawn(true,true);equal(p.data.Count,4096)
end)

test('replacement patrols cost full rosters and obey cooldown, time budget and population cap',function()
    local p,f,list,states,fd,row=fixture()
    p.sites[2]={id=2,q=12,r=0}
    local guard=p.data:Add(3,12,0,2,1);guard.Role='garrison';guard.FactionId=5
    local old=p.data:Add(3,8,0,2,1);old.Role='raider';old.FactionId=5;old.Defeated=true;old.SafeUntil=360;old.actors={{HP=0}}
    local cost=#p.adventure.battle.encounters:Get(row.encounterId).enemyIds*rules.policies:Get(5).recruitCost
    local site={SiteId=2,FactionId=5,GuardPartyId=guard.Id,OccupierId=0,Reserve=10000}
    function site:SpendReserve(amount)if self.Reserve<amount then return false end;self.Reserve=self.Reserve-amount;return true end
    states[1]=site;fd.SiteCount=1
    p.lod=setmetatable({parties=p,adventure=p.adventure,homeParties={[2]={guard,old}},nearParties={}},LOD)
    p:Recruit(site,359,20);equal(#list,2,'Retreat cooldown must finish before rebuilding')
    p:Recruit(site,360,1);equal(#list,3);equal(site.Reserve,10000-cost)
    local replacement=list[3];assert(replacement~=old and replacement.actors[1]~=old.actors[1]);equal(old.actors[1].HP,0)
    equal(p.lod.homeParties[2][3],replacement);equal(p.lod.nearParties[replacement.Id],replacement)
    p:Recruit(site,390,100);equal(#list,row.count+2,'Only configured active population can be rebuilt')
    equal(site.Reserve,10000-cost*row.count);p:Recruit(site,420,100);equal(#list,row.count+2)
end)

test('unsupplied, occupied and undefended homes cannot create replacements',function()
    local p,_,list=fixture();p.sites[2]={id=2,q=12,r=0}
    local guard=p.data:Add(3,12,0,2,1);guard.Role='garrison';guard.FactionId=5
    local site={SiteId=2,FactionId=5,GuardPartyId=guard.Id,OccupierId=0,Reserve=0,SpendReserve=function()return false end}
    p:Recruit(site,1000,1);equal(#list,1)
    site.OccupierId=4;site.SpendReserve=function()error('Occupied home cannot spend recruitment supplies')end
    p:Recruit(site,1000,1);equal(#list,1)
    site.OccupierId=0;guard.Defeated=true;p:Recruit(site,1000,1);equal(#list,1)
end)

test('strategic recovery schedules paid recruits only once per consumed period',function()
    local p,f,list,states,fd,row=fixture();p.sites[2]={id=2,q=12,r=0};f.sites=p.sites
    local guard=p.data:Add(3,12,0,2,1);guard:ConfigureFaction(5,12,0,'garrison')
    local policy=rules.policies:Get(5)
    local cost=#p.adventure.battle.encounters:Get(row.encounterId).enemyIds*policy.recruitCost
    local site={SiteId=2,FactionId=5,GuardPartyId=guard.Id,OccupierId=0,Reserve=500,LastRecoveryAt=0,LiberatedAt=-1}
    function site:SpendReserve(amount)if self.Reserve<amount then return false end;self.Reserve=self.Reserve-amount;return true end
    function site:AddReserve(amount)self.Reserve=self.Reserve+amount end
    function site:SetRecoveryAt(minute)self.LastRecoveryAt=minute end
    states[1]=site;fd.SiteCount=1
    f:Recover(30);equal(#list,2);equal(site.Reserve,500+policy.income-cost);equal(site.LastRecoveryAt,30)
    f:Recover(30);equal(#list,2);equal(site.Reserve,500+policy.income-cost)
    f:Recover(60);equal(#list,3);equal(site.Reserve,500+policy.income*2-cost*2)
end)

config:OnShutdown();print('World population: '..passed..' passed')

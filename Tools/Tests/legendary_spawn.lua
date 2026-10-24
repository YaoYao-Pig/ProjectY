package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)local f=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local b=f:read('*a');f:close();return b end}})
local Hex=require('Game.Map.HexGrid');local EmptyGrowth=assert(loadfile('Tools/Tests/growth_empty.lua'))()
local stats=require('Game.Battle.CombatStats')(config)
local function fixture()
    local map={cells={},byKey={}}
    for q=10,36 do for r=-8,8 do local cell={q=q,r=r,regionId=({1,2,5})[q%3+1]};map.cells[#map.cells+1]=cell;map.byKey[Hex.Key(q,r)]=cell end end
    function map:GetCells()return self.cells end
    function map:GetRegion(id)return {regionType=id}end
    function map:FindCell(q,r)return self.byKey[Hex.Key(q,r)]end
    function map:GetCell(q,r)return assert(self:FindCell(q,r))end
    local data={Count=0,rows={}}
    function data:GetAt(i)return self.rows[i+1]end
    function data:Add(definition,q,r,home,seed)
        local p={Id=#self.rows+1,DefinitionId=definition,Travel={Q=q,R=r},members={},MemberCount=0,HomeSiteId=home}
        function p:ConfigureFaction(faction,hq,hr,role)self.FactionId=faction;self.HomeQ=hq;self.HomeR=hr;self.Role=role end
        function p:GetMemberAt(i)return self.members[i+1]end
        function p:AddMember(template)
            local actor={Id=self.Id*100+1,TemplateId=template,TraitCount=0,traits={},Growth=EmptyGrowth(),Effects={Count=0},AnimalSpeciesId=0}
            function actor:AddTrait(id)for _,old in ipairs(self.traits)do if old==id then return end end;self.traits[#self.traits+1]=id;self.TraitCount=#self.traits end
            function actor:GetTraitAt(i)return self.traits[i+1]end
            function actor:SetMaxHP(hp)self.MaxHP=hp end
            function actor:Restore()self.HP=self.MaxHP end
            self.members[#self.members+1]=actor;self.MemberCount=#self.members;return actor
        end
        self.rows[#self.rows+1]=p;self.Count=#self.rows;return p
    end
    local adventure={config=config,data={Seed=721},battle={stats=stats,encounters=config:GetTable('CombatEncounterTable')},
        characterAppearances={Group=function()return 1 end,Assign=function(_,actor)actor.appearance=true end},travel={Cost=function()return 1 end}}
    local equipment=require('Game.Equipment.EquipmentSystem')();equipment.rules=stats.equipment;equipment.initialLoadouts={ApplyEnemy=function()end};adventure.equipment=equipment
    adventure.factions=setmetatable({adventure=adventure,data={SiteCount=0},rules=require('Game.Adventure.FactionRules').New(config)},require('Game.Adventure.WorldFactions'))
    local parties=setmetatable({adventure=adventure,map=map,sites={{q=0,r=0}},data=data,definitions=config:GetTable('WorldPartyTable'),rule=config:GetTable('WorldPartyRuleTable'):Get(1),Roam=function()end},require('Game.Adventure.WorldParties'))
    parties.legends=require('Game.Adventure.LegendaryEncounters').New(parties);adventure.parties=parties
    return parties
end
local p=fixture();p:Spawn(true);assert(p.data.Count==6,'An existing world must receive all six missing legendary identities when habitats exist')
local positions={}
for _,party in ipairs(p.data.rows)do
    assert(p.adventure.factions.rules:Suitable(party.FactionId,p.map:GetCell(party.Travel.Q,party.Travel.R).regionId))
    assert(Hex.Distance(0,0,party.Travel.Q,party.Travel.R)>=p.rule.spawnSafeRadius and party.MemberCount==1)
    local actor=party:GetMemberAt(0);assert(actor.TraitCount==1 and actor.HP==actor.MaxHP and actor.HP>0,'Real roster initialization must grant innate traits before maximum HP')
    assert((actor.TemplateId>=705)==(actor.appearance==true),'Only human legends use randomized humanoid appearance')
    positions[party.DefinitionId]=Hex.Key(party.Travel.Q,party.Travel.R)
end
local dead=p.data.rows[1];dead.Defeated=true;dead:GetMemberAt(0).HP=0
p.data.rows[2]:GetMemberAt(0).HP=7
p:Spawn(true);assert(p.data.Count==6 and dead:GetMemberAt(0).HP==0 and p.data.rows[2]:GetMemberAt(0).HP==7,'Reload cannot duplicate, revive or heal existing legends')
local missing=table.remove(p.data.rows);p.data.Count=#p.data.rows;p:Spawn(true)
assert(p.data.Count==6 and p.data.rows[6].DefinitionId==missing.DefinitionId and p.data.rows[2]:GetMemberAt(0).HP==7)
local same=fixture();same:Spawn(true)
for _,party in ipairs(same.data.rows)do assert(positions[party.DefinitionId]==Hex.Key(party.Travel.Q,party.Travel.R),'Same seed must reproduce legendary placement')end
print('PASS real missing-legend spawn and roster paths: habitats, camp distance, innate traits, humanoid/static bodies, deterministic placement and no duplicate/heal/revive on reload')
config:OnShutdown()

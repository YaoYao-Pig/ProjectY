-- Production acquisition/affix/loadout/loot rules with isolated C# state boundaries; no Editor or user saves.
package.path='Lua/?.lua;'..package.path
package.loaded.Language={LegendaryAlreadyIssued='already issued',LegendarySaveInvalid='invalid legendary save'}
local function tableOf(rows)
    return {All=function()return rows end,Find=function(_,id)for _,row in ipairs(rows)do if row.id==id then return row end end end,
        Get=function(self,id)return assert(self:Find(id),'missing fixture row '..tostring(id))end}
end
local definitions={
    {id=9001,fixedAffixId=1,acquisitionKind='actor',sourceUnitId=705,sourceAreaId=0,sourceLootTableId=0,fallbackAreaIds={}},
    {id=9002,fixedAffixId=1,acquisitionKind='dungeon',sourceUnitId=0,sourceAreaId=70,sourceLootTableId=9102,fallbackAreaIds={20,1}},
    {id=9005,fixedAffixId=1,acquisitionKind='reserved',sourceUnitId=0,sourceAreaId=0,sourceLootTableId=0,fallbackAreaIds={}},
    {id=9014,fixedAffixId=1,acquisitionKind='reserved',sourceUnitId=0,sourceAreaId=0,sourceLootTableId=0,fallbackAreaIds={}}
}
local items={{id=40,kind='weapon',name='sword'},{id=9001,kind='weapon',name='named sword'},
    {id=9002,kind='weapon',name='named bow'},{id=9005,kind='weapon',name='reserved sword'},{id=9014,kind='wearable',name='reserved shield'}}
local container={id=9102,name='fixed chest',poolId=0,itemIds={9002},counts={1},kind='chest',maxDurability=60,interaction='search'}
local ordinary={id=10,name='ordinary chest',poolId=0,itemIds={40},counts={1},kind='chest',maxDurability=30,interaction='search'}
local chestRules={}
for _,id in ipairs({70,20,1})do chestRules[#chestRules+1]={id=910200+id,areaId=id,lootTableId=9102,
    minCount=1,maxCount=1,spawnChance=100,poolOverrideId=0,strategy='reachable'}end
local loadouts={{id=705,unitId=705,weaponId=9001,offhandWeaponId=0,wearableIds={}}}
local lootEntries,shopEntries={},{}
local tables={LegendaryEquipmentTable=tableOf(definitions),EquipmentItemTable=tableOf(items),EquipmentLootTable=tableOf({ordinary,container}),
    MapAreaTable=tableOf({{id=1},{id=20},{id=70}}),MapAreaChestRuleTable=tableOf(chestRules),CombatUnitTable=tableOf({{id=705}}),
    LootEntryTable=tableOf(lootEntries),ShopEntryTable=tableOf(shopEntries),CharacterLoadoutTable=tableOf(loadouts),
    CampRecipeTable=tableOf({}),EquipmentDemoTable=tableOf({}),
    EquipmentWeaponTable=tableOf({{id=40,hands=1,kind='spear'},{id=9001,hands=2,kind='spear'},{id=9002,hands=2,kind='bow'},{id=9005,hands=1,kind='spear'}}),
    EquipmentWearableTable=tableOf({{id=9014,slot='offhand'}}),EquipmentAttributeTable=tableOf({}),
    EquipmentAffixTable=tableOf({
        {id=1,name='ordinary',color='#FFFFFF',targetTypes={'spear','bow','shield'},attributeIds={},attributeValues={},damageMultiplier=1,hitBonus=0,weight=10},
        {id=6,name='random legendary',color='#FFAA00',targetTypes={'spear','bow','shield'},attributeIds={},attributeValues={},damageMultiplier=1.2,hitBonus=10,weight=1}})}
local config={GetTable=function(_,name)return assert(tables[name],name)end}
local function narrative(copy)
    local result={values={},keys={},ValueCount=0}
    function result:GetValue(key)return self.values[key] or 0 end
    function result:SetValue(key,value)
        if self.values[key]==nil then self.keys[#self.keys+1]=key;self.ValueCount=#self.keys end
        self.values[key]=value
    end
    function result:GetValueKeyAt(index)return self.keys[index+1]end
    for key,value in pairs(copy or {})do result:SetValue(key,value)end
    return result
end
local world={sites={{id=1,areaConfigId=20},{id=2,areaConfigId=70},{id=3,areaConfigId=70}}}
local equipment={adventure={Narrative=narrative(),Seed=444},context={systems={Get=function(_,name)
    if name=='Adventure'then return world end
    assert(name=='Battle');return {stats={animals={Cells=function(_,actor,area)return {assert(area:Find(actor.Q,actor.R))}end}}}
end}}}
local Acquisition=require('Game.Equipment.LegendaryAcquisition')
local acquisition=Acquisition.New(config,equipment);equipment.acquisition=acquisition
local bow=definitions[2]
local selected=acquisition:SelectedSite(bow,world.sites,equipment.adventure.Narrative,444)
assert(selected==2 or selected==3)
assert(not acquisition:AllowsContainer(9102,{SiteId=1}),'Visiting fallback first must not claim a primary-world source')
assert(acquisition:AllowsContainer(9102,{SiteId=selected}))
assert(equipment.adventure.Narrative.ValueCount==0,'Choosing or inspecting a site must not issue an item')
world.sites={{id=1,areaConfigId=20},{id=2,areaConfigId=1}}
assert(acquisition:SelectedSite(bow,world.sites,equipment.adventure.Narrative,444)==1,'First available fallback type wins')
world.sites={{id=1,areaConfigId=1}}
assert(acquisition:SelectedSite(bow,world.sites,equipment.adventure.Narrative,444)==1)
world.sites={{id=1,areaConfigId=2}}
assert(not acquisition:SelectedSite(bow,world.sites,equipment.adventure.Narrative,444),'Missing types must not fabricate a source')
world.sites={{id=1,areaConfigId=20},{id=2,areaConfigId=70},{id=3,areaConfigId=70}}
acquisition:RecordContainer(9102,{SiteId=selected})
local persisted=narrative(equipment.adventure.Narrative.values)
assert(acquisition:SelectedSite(bow,world.sites,persisted,1)==selected,'Saved ownership survives later query seeds')
assert(acquisition:Issued(9002,persisted) and not acquisition:AllowsContainer(9102,{SiteId=selected}))
assert(not acquisition:CanGrant({9002},{1}))
assert(not acquisition:CanGrant({9005,9005},{1,1}) and not acquisition:CanGrant({9014},{2}))
assert(acquisition:CanGrant({9005,40},{1,2}))
print('PASS whole-world primary selection, ordered fallback, missing types, saved ownership and duplicate grant rejection')

CS={ProjectY={Data={EquipmentAffixData={Of=function(item)return item.affixId end}}}}
local affixes=require('Game.Equipment.EquipmentAffixes').New(config)
for _,id in ipairs({9001,9002,9005,9014})do
    assert(#affixes.pools[id].ids==1 and affixes.pools[id].ids[1]==1 and affixes.pools[id].weights[1]==1)
    assert(affixes:Legendary(id).id==id and affixes:Legendary({ItemId=id}).id==id)
    assert(not affixes.allowed[id][6])
end
assert(#affixes.pools[40].ids==2 and affixes.allowed[40][6],'Ordinary random affix pools must remain unchanged')
assert(not pcall(function()affixes:Of({ItemId=9001,affixId=6})end))
assert(not affixes:Legendary(40))
shopEntries[1]={itemId=9002};assert(not pcall(Acquisition.New,config,equipment));shopEntries[1]=nil
lootEntries[1]={itemId=9002};assert(not pcall(Acquisition.New,config,equipment));lootEntries[1]=nil
loadouts[1].weaponId=9005;assert(not pcall(Acquisition.New,config,equipment));loadouts[1].weaponId=9001
print('PASS fixed affixes for weapons/shields, unchanged ordinary quality and illegal source validation')

equipment.adventure.Narrative=narrative()
local data={owners={},weapons={},nextId=1,WeaponCount=0,WearableCount=0,capacity=true}
function data:CanGrant()return self.capacity end
function data:AddWeapon(id)
    local value={Id=self.nextId,ItemId=id,affixId=1};self.nextId=self.nextId+1
    self.weapons[#self.weapons+1]=value;self.WeaponCount=#self.weapons;return value
end
function data:GetWeaponAt(index)return self.weapons[index+1]end
CS.ProjectY.Data.EquipmentCombatState={IsInitialized=function(target,id)return target.owners[id]end,
    Initialize=function(target,owner,main,off)
        assert(not target.owners[owner]);target.owners[owner]=true
        for _,id in ipairs({main,off})do if id~=0 then local value=target:AddWeapon(id);value.OwnerActorId=owner end end
    end}
local loadout=require('Game.Equipment.InitialLoadout').New(config,{})
loadout:ApplyEnemy(data,{Id=800001,TemplateId=705},acquisition)
local original=data.weapons[1]
assert(data.WeaponCount==1 and original.ItemId==9001 and acquisition:Issued(9001))
loadout:ApplyEnemy(data,{Id=800001,TemplateId=705},acquisition)
loadout:ApplyEnemy(data,{Id=800002,TemplateId=705},acquisition)
assert(data.WeaponCount==1 and data.weapons[1]==original,'Repeated actor initialization must not copy the named weapon')
equipment.data=data;equipment.rules={items=tables.EquipmentItemTable}
local Equipment=require('Game.Equipment.EquipmentSystem')
equipment.CanGrant=Equipment.CanGrant
data.capacity=false
assert(not Equipment.Grant(equipment,9005,1) and not acquisition:Issued(9005),'Failed capacity must not consume uniqueness')
data.capacity=true
assert(Equipment.Grant(equipment,9005,1) and acquisition:Issued(9005))
local count=data.WeaponCount
assert(not Equipment.Grant(equipment,9005,1) and data.WeaponCount==count)
print('PASS actor original-instance issuance, duplicate owner initialization, failed grants and committed grants')

local function areaState(site,initialized)
    local result={SiteId=site,LootInitialized=initialized,LootCount=0,loot={},MemberCount=0,NpcCount=0,EncounterCount=0}
    function result:GetLootAt(index)return self.loot[index+1]end
    function result:AddLoot(index,id,name,ids,counts)
        assert(not self.LootInitialized)
        self.loot[#self.loot+1]={Id=#self.loot+1,CellIndex=index,TableId=id,Name=name,ids=ids,counts=counts}
        self.LootCount=#self.loot
    end
    function result:CompleteLootInitialization()self.LootInitialized=true end
    return result
end
local function physical(cells)
    return {Configured=true,CellCount=#cells,GetCellAt=function(_,i)return cells[i+1]end}
end
CS.ProjectY.Data.ContainerState={Of=function(row)return assert(row.physical)end,
    Initialize=function(state,id,_,_,_,_,cells)state.loot[id].physical=physical(cells)end}
local migrations=0
CS.ProjectY.Data.LegendaryAcquisitionState={AppendContainer=function(state,story,index,id,itemId,name,_,_,_,_,cells)
    assert(state.LootInitialized and story:GetValue('flag:legendary_equipment_issued_'..itemId)==0)
    for _,old in ipairs(state.loot)do assert(old.TableId~=id and old.CellIndex~=index)end
    local value={Id=state.LootCount+1,CellIndex=index,TableId=id,Name=name,ids={itemId},counts={1},physical=physical(cells)}
    state.loot[#state.loot+1]=value;state.LootCount=#state.loot;migrations=migrations+1
end}
local Loot=require('Game.Loot.MapLoot')
local loot=setmetatable({equipment=equipment,rules={containers=tables.EquipmentLootTable,
    Roll=function(_,id)local row=tables.EquipmentLootTable:Get(id);return row.itemIds,row.counts end},chestRules=tables.MapAreaChestRuleTable},Loot)
function loot:Prepare(value)value.prepared=true end
local ordinaryPlan={cellIndex=1,lootTableId=10,seed=1,cells={1},rotation=0,unlockEncounterId=0}
local legendaryPlan={cellIndex=3,lootTableId=9102,seed=2,cells={3},rotation=0,unlockEncounterId=0}
local layout={cells={{index=1},{index=2},{index=3}},containerPlans={ordinaryPlan,legendaryPlan},props={},configId=70}
equipment.adventure.Narrative=narrative()
local excluded=areaState(1,false)
local areas={data={Active=excluded},layouts={},ActiveLayout=function()return layout end}
loot:Initialize(areas)
assert(excluded.LootCount==1 and excluded.loot[1].TableId==10,'Unselected areas must not contain empty legendary boxes')
local fresh=areaState(selected,false);areas.data.Active=fresh
loot:Initialize(areas)
assert(fresh.LootCount==2 and fresh.loot[2].prepared and acquisition:Issued(9002))
loot:Initialize(areas)
assert(fresh.LootCount==2 and migrations==0)
equipment.adventure.Narrative=narrative()
local old=areaState(selected,false)
old:AddLoot(1,10,'old chest',{40},{1});old.loot[1].physical=physical({1});old.loot[1].searched=0.75;old:CompleteLootInitialization()
local oldChest=old.loot[1];areas.data.Active=old
loot:Initialize(areas)
assert(migrations==1 and old.LootCount==2 and old.loot[1]==oldChest and oldChest.searched==0.75)
loot:Initialize(areas)
assert(migrations==1 and old.LootCount==2,'Old-area migration must append once without rerolling existing loot')
print('PASS no empty duplicate-site containers, first materialization, old-area append and re-entry idempotence')

local saved={Narrative=narrative(equipment.adventure.Narrative.values),Equipment={WeaponCount=0,WearableCount=0},areas={old},parties={Count=0,Factions={ConflictCount=0}},hasWorld=true}
old.loot[2].weapon={Id=777,ItemId=9002,affixId=1}
CS.ProjectY.Data.ExpeditionPersistence={HasWorld=function(p)return p.hasWorld end,AreaCount=function(p)return #p.areas end,
    Area=function(p,i)return p.areas[i+1]end,GroundCount=function(c)return c.weapon and 1 or 0 end,
    GroundWeapon=function(c)return c.weapon end,GroundWearable=function()end}
CS.ProjectY.Data.WorldPartiesData={Prepared=function(p)return p.parties end}
acquisition:ValidateSaved(saved,world)
saved.Equipment.WeaponCount=1;saved.Equipment.GetWeaponAt=function()return {Id=999,ItemId=9002,affixId=1}end
assert(not pcall(acquisition.ValidateSaved,acquisition,saved,world),'Duplicate inventory/ground identities must be rejected')
saved.Equipment.WeaponCount=0;old.loot[2].weapon.affixId=6
assert(not pcall(acquisition.ValidateSaved,acquisition,saved,world),'Random affix on named equipment must be rejected')
old.loot[2].weapon.affixId=1;saved.Narrative=narrative()
assert(not pcall(acquisition.ValidateSaved,acquisition,saved,world),'Physical named equipment needs a persisted issued fact')
saved.Narrative=narrative(equipment.adventure.Narrative.values);saved.Narrative:SetValue('flag:legendary_equipment_site_9002',99)
assert(not pcall(acquisition.ValidateSaved,acquisition,saved,world),'Invalid source sites must be rejected before Apply')
print('PASS saved physical uniqueness across owners/containers, fixed quality, issuance facts and source-site validation')

for _,path in ipairs({'Lua/Game/Equipment/LegendaryAcquisition.lua','Lua/Game/Equipment/EquipmentAffixes.lua',
    'Lua/Game/Equipment/EquipmentSystem.lua','Lua/Game/Equipment/InitialLoadout.lua','Lua/Game/Loot/MapLoot.lua','Lua/Game/Adventure/ExpeditionSave.lua'})do assert(loadfile(path))end
print('PASS legendary acquisition syntax')

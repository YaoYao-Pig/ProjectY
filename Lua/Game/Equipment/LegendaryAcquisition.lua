-- Rules only. Unique issuance and its chosen world site live in the existing NarrativeData facts.
local Language=require('Language')
local Acquisition={};Acquisition.__index=Acquisition
local issuedPrefix='flag:legendary_equipment_issued_'
local sitePrefix='flag:legendary_equipment_site_'
function Acquisition.New(config,equipment)
    local self=setmetatable({equipment=equipment,definitions=config:GetTable('LegendaryEquipmentTable'),byContainer={},areas={}},Acquisition)
    local items=config:GetTable('EquipmentItemTable')
    local containers=config:GetTable('EquipmentLootTable')
    local areaDefinitions=config:GetTable('MapAreaTable')
    local rules=config:GetTable('MapAreaChestRuleTable'):All()
    for _,row in ipairs(self.definitions:All()) do
        local item=items:Get(row.id)
        assert(item.kind=='weapon' or item.kind=='wearable','Named legendary must be physical equipment: '..row.id)
        assert(row.fixedAffixId==1,'Named legendary identity must not add a random quality affix: '..row.id)
        local allowed={};self.areas[row.id]=allowed
        if row.acquisitionKind=='dungeon' then
            assert(row.sourceUnitId==0 and row.sourceAreaId>0 and row.sourceLootTableId>0,'Invalid legendary dungeon source: '..row.id)
            assert(not self.byContainer[row.sourceLootTableId],'Legendary container reused: '..row.sourceLootTableId)
            self.byContainer[row.sourceLootTableId]=row
            local container=containers:Get(row.sourceLootTableId)
            assert(container.poolId==0 and #container.itemIds==1 and container.itemIds[1]==row.id and #container.counts==1 and container.counts[1]==1,
                'Legendary container must hold exactly its one fixed equipment item: '..row.id)
            allowed[row.sourceAreaId]=true;areaDefinitions:Get(row.sourceAreaId)
            for _,id in ipairs(row.fallbackAreaIds) do
                assert(not allowed[id],'Repeated legendary fallback area: '..row.id);allowed[id]=true;areaDefinitions:Get(id)
            end
            for id in pairs(allowed) do
                local found=0
                for _,rule in ipairs(rules) do if rule.lootTableId==row.sourceLootTableId and rule.areaId==id then
                    assert(rule.minCount==1 and rule.maxCount==1 and rule.spawnChance==100 and rule.poolOverrideId==0 and rule.strategy~='props',
                        'Legendary placement must have one guaranteed independent container: '..rule.id)
                    found=found+1
                end end
                assert(found==1,'Legendary source area needs exactly one chest rule: '..row.id..'/'..id)
            end
        elseif row.acquisitionKind=='actor' then
            config:GetTable('CombatUnitTable'):Get(row.sourceUnitId)
            assert(row.sourceUnitId>0 and row.sourceAreaId==0 and row.sourceLootTableId==0 and #row.fallbackAreaIds==0,'Invalid legendary actor source: '..row.id)
        else
            assert(row.acquisitionKind=='reserved' and row.sourceUnitId==0 and row.sourceAreaId==0 and row.sourceLootTableId==0 and #row.fallbackAreaIds==0,
                'Reserved legendary must have no automatic source: '..row.id)
        end
    end
    -- Named identities never enter random chest pools or recurring shops.
    for _,entry in ipairs(config:GetTable('LootEntryTable'):All()) do
        assert(not self.definitions:Find(entry.itemId),'Named legendary cannot be random loot: '..entry.itemId)
    end
    for _,entry in ipairs(config:GetTable('ShopEntryTable'):All()) do
        assert(not self.definitions:Find(entry.itemId),'Named legendary cannot be recurring shop stock: '..entry.itemId)
    end
    for _,recipe in ipairs(config:GetTable('CampRecipeTable'):All()) do for _,id in ipairs(recipe.outputIds) do
        assert(not self.definitions:Find(id),'Named legendary cannot be repeatable camp production: '..id)
    end end
    for _,recipe in ipairs(config:GetTable('EquipmentDemoTable'):All()) do for _,id in ipairs(recipe.starterItemIds) do
        assert(not self.definitions:Find(id),'Named legendary cannot be an automatic starter grant: '..id)
    end end
    for _,container in ipairs(containers:All()) do for _,id in ipairs(container.itemIds) do
        local row=self.definitions:Find(id)
        assert(not row or row.acquisitionKind=='dungeon' and row.sourceLootTableId==container.id,'Named legendary has an unconfigured container source: '..id)
    end end
    for _,loadout in ipairs(config:GetTable('CharacterLoadoutTable'):All()) do
        local identities={}
        local function validate(id)
            local row=self.definitions:Find(id)
            assert(not row or row.acquisitionKind=='actor' and row.sourceUnitId==loadout.unitId,'Named legendary has an unconfigured actor source: '..id)
            if row then assert(not identities[id],'Named legendary repeats in one initial loadout: '..id);identities[id]=true end
        end
        validate(loadout.weaponId);validate(loadout.offhandWeaponId)
        for _,id in ipairs(loadout.wearableIds) do validate(id) end
    end
    return self
end
function Acquisition:Issued(itemId,narrative)
    return (narrative or self.equipment.adventure.Narrative):GetValue(issuedPrefix..itemId)==1
end
function Acquisition:CanGrant(ids,counts)
    local seen={}
    for i,id in ipairs(ids) do if self.definitions:Find(id) then
        if counts[i]~=1 or seen[id] or self:Issued(id) then return false,Language.LegendaryAlreadyIssued end
        seen[id]=true
    end end
    return true
end
function Acquisition:Record(ids,siteId)
    local narrative=self.equipment.adventure.Narrative
    for _,id in ipairs(ids) do if self.definitions:Find(id) then
        assert(not self:Issued(id),'Legendary equipment was generated twice: '..id)
        narrative:SetValue(issuedPrefix..id,1)
        if siteId then narrative:SetValue(sitePrefix..id,siteId) end
    end end
end
function Acquisition:EnemyLoadout(actor,main,off,items,slots)
    local issued={}
    local function select(id)
        local row=self.definitions:Find(id)
        if not row then return id end
        assert(row.acquisitionKind=='actor' and row.sourceUnitId==actor.TemplateId,'Legendary equipment is on an unconfigured actor: '..id)
        if self:Issued(id) then return 0 end
        issued[#issued+1]=id;return id
    end
    main,off=select(main),select(off)
    local selected,selectedSlots={},{}
    for i,id in ipairs(items) do local kept=select(id)
        if kept~=0 then selected[#selected+1]=kept;selectedSlots[#selectedSlots+1]=slots[i] end
    end
    return main,off,selected,selectedSlots,issued
end
function Acquisition:SelectedSite(row,sites,narrative,seed)
    local assigned=narrative:GetValue(sitePrefix..row.id)
    if assigned>0 then
        local site=sites[assigned]
        assert(site and self.areas[row.id][site.areaConfigId],Language.LegendarySaveInvalid)
        return assigned
    end
    local function candidates(areaId)
        local result={}
        for _,site in ipairs(sites) do if site.areaConfigId==areaId then result[#result+1]=site.id end end
        table.sort(result);return result
    end
    local possible=candidates(row.sourceAreaId)
    if #possible==0 then
        for _,id in ipairs(row.fallbackAreaIds) do possible=candidates(id);if #possible>0 then break end end
    end
    if #possible==0 then return nil end
    return possible[1+(((math.tointeger(seed) ~ row.id*7919) & 0xffffffff)%#possible)]
end
function Acquisition:AllowsContainer(containerId,state)
    local row=self.byContainer[containerId]
    if not row then return true end
    if self:Issued(row.id) then return false end
    local adventure=self.equipment.context.systems:Get('Adventure')
    return self:SelectedSite(row,assert(adventure.sites),self.equipment.adventure.Narrative,self.equipment.adventure.Seed)==state.SiteId
end
function Acquisition:RecordContainer(containerId,state)
    local row=self.byContainer[containerId]
    if row then self:Record({row.id},state.SiteId) end
end
function Acquisition:ValidateSaved(prepared,world)
    local narrative=prepared.Narrative
    local seen={}
    local function item(value)
        if not value then return end
        local row=self.definitions:Find(value.ItemId)
        if row then
            assert(not seen[row.id] and self:Issued(row.id,narrative),Language.LegendarySaveInvalid)
            assert(CS.ProjectY.Data.EquipmentAffixData.Of(value)==row.fixedAffixId,Language.LegendarySaveInvalid)
            seen[row.id]=true
        end
    end
    local equipment=prepared.Equipment
    for i=0,equipment.WeaponCount-1 do item(equipment:GetWeaponAt(i)) end
    for i=0,equipment.WearableCount-1 do item(equipment:GetWearableAt(i)) end
    local bridge=CS.ProjectY.Data.ExpeditionPersistence
    local function container(value)
        for i=0,bridge.GroundCount(value)-1 do item(bridge.GroundWeapon(value,i));item(bridge.GroundWearable(value,i)) end
    end
    if bridge.HasWorld(prepared) then
        for i=0,bridge.AreaCount(prepared)-1 do local area=bridge.Area(prepared,i)
            for j=0,area.LootCount-1 do container(area:GetLootAt(j)) end
        end
        local parties=CS.ProjectY.Data.WorldPartiesData.Prepared(prepared)
        for i=0,parties.Count-1 do local party=parties:GetAt(i);if party.Cargo then container(party.Cargo) end end
        for i=0,parties.Factions.ConflictCount-1 do local conflict=parties.Factions:GetConflictAt(i)
            for j=0,conflict.PendingCargoCount-1 do container(conflict:GetPendingCargoAt(j)) end
        end
    end
    for i=0,narrative.ValueCount-1 do
        local key=narrative:GetValueKeyAt(i)
        local issued=key:match('^flag:legendary_equipment_issued_(%d+)$')
        local site=key:match('^flag:legendary_equipment_site_(%d+)$')
        if issued or site then
            local row=self.definitions:Find(tonumber(issued or site));local value=narrative:GetValue(key)
            assert(row and value>0 and math.tointeger(value),Language.LegendarySaveInvalid)
            if issued then assert(value==1,Language.LegendarySaveInvalid)
            else
                assert(row.acquisitionKind=='dungeon' and self:Issued(row.id,narrative),Language.LegendarySaveInvalid)
                if world and bridge.HasWorld(prepared) then
                    local source=world.sites[value]
                    assert(source and self.areas[row.id][source.areaConfigId],Language.LegendarySaveInvalid)
                end
            end
        end
    end
end
return Acquisition

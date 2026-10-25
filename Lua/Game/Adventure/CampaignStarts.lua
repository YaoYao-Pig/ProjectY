-- Opening definitions and previews are derived from config; live inventory and saved recipes remain authoritative.
local LuaLanguage = require('Language')
local Starts = {}

function Starts.Get(config, id)
    if id == nil then id = 1 end
    assert(type(id) == 'number' and math.tointeger(id) and id > 0, LuaLanguage.StartOriginInvalid)
    local row = config:GetTable('CampaignStartTable'):Find(id)
    assert(row, string.format(LuaLanguage.StartOriginUnknown,tostring(id)))
    assert(type(row.name) == 'string' and row.name ~= '' and type(row.description) == 'string', 'Invalid campaign start description')
    assert(math.tointeger(row.coins) and row.coins >= 0 and row.coins <= 2147483647, 'Invalid campaign start coins')
    config:GetTable('AdventureDemoTable'):Get(row.adventureRecipeId)
    config:GetTable('ProfessionTable'):Get(row.initialProfessionId)
    return row
end

function Starts.List(config)
    local rows = {}
    for _,row in ipairs(config:GetTable('CampaignStartTable'):All()) do rows[#rows + 1] = Starts.Get(config, row.id) end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end

function Starts.Preview(config, id)
    local profile = Starts.Get(config, id)
    local recipe = config:GetTable('AdventureDemoTable'):Get(profile.adventureRecipeId)
    local equipment = config:GetTable('EquipmentDemoTable'):Get(recipe.equipmentRecipeId)
    local units, items = config:GetTable('CombatUnitTable'), config:GetTable('EquipmentItemTable')
    local preview = {id=profile.id, name=profile.name, description=profile.description,
        adventureRecipeId=profile.adventureRecipeId, coins=profile.coins, partyNames={}, equipmentRows={}}
    local byItem, party = {}, {}
    local function add(itemId, count, owner)
        assert(math.tointeger(count) and count > 0, 'Invalid campaign starter count')
        local row = byItem[itemId]
        if not row then
            local item = items:Get(itemId)
            row = {itemId=item.id, name=item.name, iconPath=item.iconPath, kind=item.kind, count=0, equippedBy={}}
            byItem[itemId] = row; preview.equipmentRows[#preview.equipmentRows + 1] = row
        end
        row.count = row.count + count
        if owner then row.equippedBy[#row.equippedBy + 1] = owner end
    end
    local professions=config:GetTable('ProfessionTable');local farmer=config:GetTable('CharacterBirthRuleTable'):Get(1).defaultProfessionId
    for index,unitId in ipairs(recipe.partyIds) do
        local templateName=units:Get(unitId).name
        local name=string.format(LuaLanguage.GrowthCharacterProfessionName,templateName:match('^(.-)%s*·') or templateName,
            professions:Get(index==1 and profile.initialProfessionId or farmer).name)
        preview.partyNames[#preview.partyNames + 1] = name; party[unitId] = name
    end
    assert(#equipment.starterItemIds == #equipment.starterCounts, 'Campaign starter arrays differ')
    for index,itemId in ipairs(equipment.starterItemIds) do add(itemId, equipment.starterCounts[index]) end
    assert(#equipment.equipUnitIds == #equipment.equipWeaponIds, 'Campaign starter equipment arrays differ')
    for index,unitId in ipairs(equipment.equipUnitIds) do
        local owner = assert(party[unitId], 'Campaign starter weapon has no party member')
        local row = assert(byItem[equipment.equipWeaponIds[index]], 'Campaign starter weapon is absent from the backpack')
        row.equippedBy[#row.equippedBy + 1] = owner
    end
    for _,loadout in ipairs(config:GetTable('CharacterLoadoutTable'):All()) do
        local owner = party[loadout.unitId]
        if owner then
            if loadout.weaponId ~= 0 then add(loadout.weaponId, 1, owner) end
            if loadout.offhandWeaponId ~= 0 then add(loadout.offhandWeaponId, 1, owner) end
            for _,itemId in ipairs(loadout.wearableIds) do add(itemId, 1, owner) end
        end
    end
    return preview
end

return Starts

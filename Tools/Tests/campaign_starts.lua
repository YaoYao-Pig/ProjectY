-- Offline checks only: config bytes and isolated Lua adapters, without Unity or player save files.
package.path = 'Lua/?.lua;' .. package.path
local Starts = require('Game.Adventure.CampaignStarts')
local Creation = require('Game.Adventure.CampaignCreation')
local checks = 0
local function test(name, run) run(); checks = checks + 1; print('PASS ' .. name) end
local function rejects(run)
    local ok, reason = pcall(run)
    assert(not ok and tostring(reason) ~= '', 'Expected an explicit rejection')
end
local function configTable(rows)
    local byId = {}; for _,row in ipairs(rows) do byId[row.id] = row end
    return {All=function() return rows end, Find=function(_, id) return byId[id] end,
        Get=function(_, id) return assert(byId[id], 'Missing fixture row ' .. tostring(id)) end}
end
local profiles = {{id=2, name='Second opening', description='Second supplies', adventureRecipeId=102, coins=25},
    {id=1, name='Default opening', description='Default supplies', adventureRecipeId=101, coins=60}}
local tables = {
    CampaignStartTable=configTable(profiles),
    AdventureDemoTable=configTable({{id=101, partyIds={1,2}, equipmentRecipeId=11}, {id=102, partyIds={2,1}, equipmentRecipeId=12}}),
    EquipmentDemoTable=configTable({
        {id=11, starterItemIds={101,91}, starterCounts={1,2}, equipUnitIds={1}, equipWeaponIds={101}},
        {id=12, starterItemIds={102,91}, starterCounts={1,4}, equipUnitIds={1}, equipWeaponIds={102}},
    }),
    CombatUnitTable=configTable({{id=1,name='Lead'}, {id=2,name='Companion'}}),
    EquipmentItemTable=configTable({{id=101,name='Sword',iconPath='sword.png',kind='weapon'},
        {id=102,name='Staff',iconPath='staff.png',kind='weapon'}, {id=91,name='Supplies',iconPath='',kind='consumable'},
        {id=201,name='Clothing',iconPath='clothing.png',kind='wearable'}}),
    CharacterLoadoutTable=configTable({{id=1,unitId=2,weaponId=0,offhandWeaponId=0,wearableIds={201}}}),
}
local config = {GetTable=function(_, name) return assert(tables[name], 'Unknown fixture table ' .. name) end}

test('opening selection defaults only when omitted and rejects malformed or unknown IDs', function()
    assert(Starts.Get(config).id == 1 and Starts.Get(config, 2).adventureRecipeId == 102)
    local rows = Starts.List(config); assert(rows[1].id == 1 and rows[2].id == 2)
    for _,id in ipairs({0,-1,1.5,'1',false,{},math.huge,0/0,99}) do rejects(function() Starts.Get(config, id) end) end
    local coins = profiles[1].coins; profiles[1].coins = -1
    rejects(function() Starts.Get(config, 2) end); profiles[1].coins = coins
    local recipe = profiles[1].adventureRecipeId; profiles[1].adventureRecipeId = 999
    rejects(function() Starts.Get(config, 2) end); profiles[1].adventureRecipeId = recipe
end)

test('preview derives ordered party, grant quantities and equipped owners from both equipment sources', function()
    local preview = Starts.Preview(config, 2)
    assert(preview.coins == 25 and preview.partyNames[1] == 'Companion' and preview.partyNames[2] == 'Lead')
    assert(#preview.equipmentRows == 3)
    assert(preview.equipmentRows[1].itemId == 102 and preview.equipmentRows[1].count == 1)
    assert(preview.equipmentRows[1].equippedBy[1] == 'Lead' and preview.equipmentRows[1].iconPath == 'staff.png')
    assert(preview.equipmentRows[2].count == 4 and #preview.equipmentRows[2].equippedBy == 0)
    assert(preview.equipmentRows[3].itemId == 201 and preview.equipmentRows[3].equippedBy[1] == 'Companion')
    preview.equipmentRows[1].count = 99; preview.partyNames[1] = 'Changed display'
    assert(Starts.Preview(config, 2).equipmentRows[1].count == 1 and Starts.Preview(config, 2).partyNames[1] == 'Companion')
end)

local current, clearCount, saveCount, saveSuccess = nil, 0, 0, true
local function adventureFixture()
    local flags = {['flag:campaign_start']=88}
    local adventure = {config=config, data={Phase='map'}, parties={data={}}, camp={data={}}, shop={data={}},
        narrative={data={SetValue=function(_, key, value) flags[key] = value end}},
        equipment={worldLoot={session={}}}, player={Coins=777}, battle={}, characterSaves={id='old-slot'},
        buildCount=0, startCount=0, flags=flags, seed=999, recipeId=5}
    function adventure:BuildWorld(seed, recipeId, size, progress)
        self.buildCount = self.buildCount + 1
        progress(.5, 'terrain'); progress(1, 'ready')
        return {map={seed=seed, recipeId=recipeId}, recipe=self.config:GetTable('AdventureDemoTable'):Get(recipeId), size=size}
    end
    function adventure:Start(seed, recipeId, size, world)
        assert(world.recipe.id == recipeId and world.map.seed == seed and world.size == size)
        self.startCount = self.startCount + 1; self.seed = seed; self.recipeId = recipeId
        flags['flag:campaign_start'] = nil
    end
    function adventure:Snapshot() return {seed=self.seed,recipeId=self.recipeId,coins=self.player.Coins,startId=flags['flag:campaign_start']} end
    return adventure
end
CS = {ProjectY={Data={
    ExpeditionPersistence={ResetProfile=function(player, coins)
        assert(current.flags['flag:campaign_start'] ~= nil, 'Player change listeners must see the opening identity')
        player.Coins = coins
    end},
    CampaignSaves={NewCampaign=function(saves) saves.id = 'new-slot' end},
}}}
package.loaded['Game.Map.MapRenderSnapshot'] = function(map) return map end
package.loaded['Game.Presentation.VisualEffects'] = {Clear=function() clearCount = clearCount + 1 end}
package.loaded['Game.Adventure.CharacterSave'] = {Write=function(adventure)
    saveCount = saveCount + 1
    assert(adventure.flags['flag:campaign_start'] ~= nil, 'Opening identity must be set before the initial save')
    assert(adventure.characterSaves.id == 'new-slot')
    adventure.saved = adventure:Snapshot()
    return saveSuccess, saveSuccess and nil or 'isolated save failure'
end}
package.loaded.Main = {Get=function(_, name) assert(name == 'Adventure'); return assert(current) end}
local function prepare(job)
    while true do local done, map = Creation.Step(job); if done then return map end end
end

test('invalid opening is rejected before building or changing the active session', function()
    current = adventureFixture()
    for _,id in ipairs({0,1.5,'2',false,99}) do rejects(function() Creation.New(current, '17', 2500, id) end) end
    assert(current.buildCount == 0 and current.startCount == 0 and current.player.Coins == 777)
    assert(current.seed == 999 and current.recipeId == 5 and current.characterSaves.id == 'old-slot' and current.flags['flag:campaign_start'] == 88)
end)

test('preparation remains isolated; commit uses selected recipe and coins and saves identity exactly once', function()
    for _,id in ipairs({1,2}) do
        current = adventureFixture()
        local profile = Starts.Get(config, id)
        local job = Creation.New(current, '4294967295', 2500, id)
        assert(job.recipeId == profile.adventureRecipeId and current.buildCount == 0)
        local map = prepare(job)
        assert(map.recipeId == profile.adventureRecipeId and current.player.Coins == 777 and current.startCount == 0)
        assert(current.characterSaves.id == 'old-slot' and current.flags['flag:campaign_start'] == 88)
        local beforeSave, beforeClear = saveCount, clearCount
        local result = Creation.Commit(job)
        assert(result.recipeId == profile.adventureRecipeId and result.coins == profile.coins and result.startId == id)
        assert(current.saved.startId == id and current.saved.coins == profile.coins and current.saved.recipeId == profile.adventureRecipeId)
        rejects(function() Creation.Commit(job) end)
        assert(current.startCount == 1 and saveCount == beforeSave + 1 and clearCount == beforeClear + 1)
    end
end)

test('initial save failure preserves selected session and cannot issue starter grants twice', function()
    current = adventureFixture(); saveSuccess = false
    local job = Creation.New(current, '0', 2500, 2); prepare(job)
    local result = Creation.Commit(job)
    assert(result.warning:find('isolated save failure', 1, true) and result.startId == 2 and result.coins == 25)
    rejects(function() Creation.Commit(job) end); assert(current.startCount == 1)
    saveSuccess = true
end)

test('menu bridge forwards the opening ID and reports invalid selection without mutating the current session', function()
    local bridge = require('Game.Adventure.DemoBridge'); current = adventureFixture()
    for _,id in ipairs({0,'2',99}) do
        local map, state = bridge('menu_start', 2500, '42', id)
        assert(map == nil and state.error ~= '' and current.startCount == 0 and current.buildCount == 0)
    end
    local map, state = bridge('menu_start', 2500, '42', 2)
    assert(map.recipeId == 102 and state.startId == 2 and state.coins == 25)
    current = adventureFixture(); map, state = bridge('menu_start', 2500, '42')
    assert(map.recipeId == 101 and state.startId == 1 and state.coins == 60)
end)

test('loading bridge forwards selection, rejects invalid begin and releases cancelled preparation', function()
    local bridge = require('Game.Adventure.CampaignLoadingBridge'); current = adventureFixture()
    rejects(function() bridge('begin', 1, '42', 2500, 99) end)
    assert(current.buildCount == 0 and current.characterSaves.id == 'old-slot')
    bridge('begin', 2, '42', 2500, 2)
    rejects(function() bridge('step', 1) end)
    bridge('release', 2)
    assert(current.startCount == 0 and current.player.Coins == 777 and current.flags['flag:campaign_start'] == 88)
    bridge('begin', 3, '42', 2500, 2)
    while true do local done = bridge('step', 3); if done then break end end
    local state = bridge('commit', 3); assert(state.recipeId == 102 and state.startId == 2 and state.coins == 25)
    rejects(function() bridge('commit', 3) end); bridge('release', 3)
    bridge('begin', 4, '42', 2500)
    while true do local done = bridge('step', 4); if done then break end end
    assert(bridge('commit', 4).startId == 1); bridge('release', 4)
end)

test('every exported opening resolves its actual party, supplies and automatic equipment', function()
    local actual = require('Config.ConfigSystem')()
    actual:OnInit({services={ReadConfig=function(_, name)
        local file = assert(io.open('Assets/GameFramework/Resources/_Gen/Config/' .. name .. '.bytes', 'rb'))
        local bytes = file:read('*a'); file:close(); return bytes
    end}})
    local rows = Starts.List(actual); assert(#rows > 1 and rows[1].id == 1)
    local recipes = {}
    for _,profile in ipairs(rows) do
        local preview = Starts.Preview(actual, profile.id)
        local recipe = actual:GetTable('AdventureDemoTable'):Get(profile.adventureRecipeId)
        assert(not recipes[recipe.id], 'Opening must select its own saved recipe'); recipes[recipe.id] = true
        assert(#preview.partyNames == #recipe.partyIds and #preview.partyNames > 0 and #preview.equipmentRows > 0)
        assert(preview.coins == profile.coins and preview.adventureRecipeId == recipe.id)
        local actualGrants, previews = {}, {}
        local equipment = actual:GetTable('EquipmentDemoTable'):Get(recipe.equipmentRecipeId)
        for index,itemId in ipairs(equipment.starterItemIds) do actualGrants[itemId] = (actualGrants[itemId] or 0) + equipment.starterCounts[index] end
        local party = {}; for _,unitId in ipairs(recipe.partyIds) do party[unitId] = true end
        for _,loadout in ipairs(actual:GetTable('CharacterLoadoutTable'):All()) do
            if party[loadout.unitId] then
                for _,itemId in ipairs({loadout.weaponId,loadout.offhandWeaponId}) do
                    if itemId ~= 0 then actualGrants[itemId] = (actualGrants[itemId] or 0) + 1 end
                end
                for _,itemId in ipairs(loadout.wearableIds) do actualGrants[itemId] = (actualGrants[itemId] or 0) + 1 end
            end
        end
        for _,row in ipairs(preview.equipmentRows) do
            assert(not previews[row.itemId] and row.count == actualGrants[row.itemId] and row.count >= #row.equippedBy)
            previews[row.itemId] = true
        end
        for itemId in pairs(actualGrants) do assert(previews[itemId], 'Initial item missing from the preview') end
        print('  Opening ' .. profile.id .. ': recipe ' .. recipe.id .. ', ' .. #preview.partyNames .. ' party, ' .. #preview.equipmentRows .. ' item rows')
    end
end)
print('Campaign opening checks passed: ' .. checks)

package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
for _,path in ipairs({'Lua/Game/Loot/MapLoot.lua','Lua/Game/Loot/ContainerCombat.lua','Lua/Game/Loot/ContainerTerrain.lua',
    'Lua/Game/MapArea/MapAreaSystem.lua','Lua/Game/Adventure/CharacterSkills.lua','Lua/Game/Adventure/AdventureSystem.lua','Lua/Game/Battle/BattleSystem.lua'}) do assert(loadfile(path)) end
local rules=require('Game.Loot.LootRules').New(config)
for seed=1,12 do
    local ids,counts=rules:Roll(204,seed);local total=0
    for i,id in ipairs(ids) do assert(id==40 or id==46);total=total+counts[i] end
    assert(total==2,'Boss weighted pool must produce its two guaranteed draws')
    ids,counts=rules:Roll(201,seed,6);assert(#ids==1 and counts[1]==1,'Placement pool override was ignored')
end
print('PASS weighted guarantees, merged repeated picks and map-specific pool overrides')
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(1,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
generator:Register(3,require('Game.MapArea.ForestGenerator'),'MapAreaForestTable','MapAreaForestThemeTable')
generator:Register(5,require('Game.MapArea.ShipwreckGenerator'),'MapAreaShipwreckTable','MapAreaShipwreckThemeTable')
local Chest=require('Game.Loot.ChestGenerator')
local function signature(plans)
    local values={};for _,plan in ipairs(plans) do values[#values+1]=plan.lootTableId..':'..table.concat(plan.cells,',')..':'..plan.rotation end
    return table.concat(values,'|')
end
for _,id in ipairs({1,20,40}) do for _,seed in ipairs({412,91,7}) do
    local source={regionId=5,regionConfigId=5,regionType=5,q=0,r=0,height=0,biomeWeights={{regionType=5,weight=1}}}
    local area=generator:Generate(id,seed,9,source)
    local again=generator:Generate(id,seed,9,source)
    assert(signature(area.containerPlans)==signature(again.containerPlans),'Container plan must be repeatable')
    local used,blocked={},{}
    for _,plan in ipairs(area.containerPlans) do
        local row=config:GetTable('EquipmentLootTable'):Get(plan.lootTableId)
        assert(plan.cells[1]==plan.cellIndex)
        for _,index in ipairs(plan.cells) do
            assert(not used[index] and index~=area.entryIndex and index~=area.goalIndex,'Container footprint overlaps protected placement')
            used[index]=true;if row.blocksMovement then blocked[index]=true end
        end
    end
    local base=Chest.Distances(area);local _,reachable=Chest.Distances(area,blocked)
    for _,index in ipairs(base) do assert(blocked[index] or reachable[index],'Container seals another reachable floor') end
    for _,plan in ipairs(area.containerPlans) do
        local accessible=false
        for _,index in ipairs(plan.cells) do for _,other in ipairs(area:Neighbors(area.cells[index])) do if reachable[other.index] then accessible=true end end end
        assert(accessible,'Container has no accessible interaction side')
    end
end end
print('PASS dungeon/forest/shipwreck seeds: deterministic footprints, accessible sides and preserved connectivity')
local Layout=require('Game.MapArea.MapAreaLayout')
local area=Layout.New({id=999,name='Placement',areaType=1,width=8,height=8,hexRadius=1,visionRadius=8,moveStepSeconds=.1},77,{}, {})
for _,cell in ipairs(area.cells) do cell.blocked=false;cell.blocksSight=false;cell.height=0;cell.kind='floor' end
area.entryIndex=1;area.goalIndex=64;area.props={}
local rule={id=1,areaId=999,lootTableId=201,strategy='fixed',q=4,r=4,rotation=2,minCount=1,maxCount=1,minDistance=1,maxDistance=99,spacing=1,seedSalt=1,spawnChance=0}
assert(#Chest.Plan(area,{rule},{},config:GetTable('EquipmentLootTable'))==0)
rule.spawnChance=100
local plans=Chest.Plan(area,{rule},{},config:GetTable('EquipmentLootTable'))
assert(#plans==1 and plans[1].cellIndex==area:Find(4,4).index and plans[1].rotation==2)
assert(not pcall(Chest.Plan,area,{rule},{[plans[1].cellIndex]=true},config:GetTable('EquipmentLootTable')),'Required fixed overlap must fail clearly')
local prop={id=1,configId=12,cellIndex=area:Find(3,3).index,cells={area:Find(3,3).index},rotation=1}
area.props={prop};area.cells[prop.cellIndex].blocked=true
rule.strategy='props';rule.propId=12
plans=Chest.Plan(area,{rule},{},config:GetTable('EquipmentLootTable'))
assert(#plans==1 and plans[1].prop==prop and plans[1].cellIndex==prop.cellIndex)
print('PASS 0/100 spawn probability, fixed placement errors and existing-prop association')

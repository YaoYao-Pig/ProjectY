package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'));local bytes=file:read('*a');file:close();return bytes
end}})
local Rules=require('Game.Loot.LootRules')
local loot=Rules.New(config)
local function signature(ids,counts)
    local values={};for i,id in ipairs(ids) do values[#values+1]=id..':'..counts[i] end;return table.concat(values,',')
end
for _,id in ipairs({1,10,11,100,101}) do
    local a,b=loot:Roll(id,412);local c,d=loot:Roll(id,412);assert(signature(a,b)==signature(c,d))
    for i,item in ipairs(a) do assert(b[i]>0 and config:GetTable('EquipmentItemTable'):Find(item)) end
end
local fake={GetTable=function(_,name)
    if name=='LootEntryTable' then return {All=function()return {
        {id=1,poolId=1,itemId=31,chance=100,minCount=2,maxCount=2},
        {id=2,poolId=1,itemId=40,chance=0,minCount=1,maxCount=1},
        {id=3,poolId=1,itemId=31,chance=100,minCount=3,maxCount=3},
        {id=4,poolId=1,itemId=51,chance=100,minCount=1,maxCount=1}}
    end} end
    return config:GetTable(name)
end}
local exact=Rules.New(fake);local ids,counts=exact:Roll(10,0)
assert(#ids==2 and ids[1]==31 and counts[1]==5 and ids[2]==51)
local emptyIds=exact:Roll(11,0);assert(#emptyIds==0)
print('PASS independent 0/100 percent drops, multiple hits, merged quantities, empty pools and deterministic rolls')
local Generator=require('Game.MapArea.MapAreaGenerator')
local generator=Generator(config)
generator:Register(1,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
generator:Register(3,require('Game.MapArea.ForestGenerator'),'MapAreaForestTable','MapAreaForestThemeTable')
generator:Register(4,require('Game.MapArea.BattlefieldGenerator'),'MapAreaBattlefieldTable','MapAreaBattlefieldThemeTable')
local Chest=require('Game.Loot.ChestGenerator');local Hex=require('Game.Map.HexGrid')
for _,areaId in ipairs({1,20}) do
    local area=generator:Generate(areaId,412,9,{regionId=5,regionConfigId=5,regionType=5,q=0,r=0,height=0,biomeWeights={{regionType=5,weight=1}}})
    local plans=Chest.Plan(area,config:GetTable('MapAreaChestRuleTable'):All(),{[area.entryIndex]=true})
    local again=Chest.Plan(area,config:GetTable('MapAreaChestRuleTable'):All(),{[area.entryIndex]=true})
    local _,distance=Chest.Distances(area)
    local minimum,maximum=0,0
    for _,rule in ipairs(config:GetTable('MapAreaChestRuleTable'):All()) do if rule.areaId==areaId then
        minimum=minimum+(rule.spawnChance==100 and rule.minCount or 0);maximum=maximum+rule.maxCount
    end end
    assert(#plans>=minimum and #plans<=maximum)
    local props={};for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do props[index]=true end end
    for i,plan in ipairs(plans) do
        assert(plan.cellIndex==again[i].cellIndex and distance[plan.cellIndex] and not area.cells[plan.cellIndex].blocked)
        assert(not props[plan.cellIndex],'Chest overlaps map dressing')
        for j=1,i-1 do
            local a,b=area.cells[plan.cellIndex],area.cells[plans[j].cellIndex]
            assert(Hex.Distance(a.q,a.r,b.q,b.r)>=plan.spacing)
        end
    end
end
print('PASS forest/dungeon chest count, reachable placement, spacing and deterministic placement')
local source={regionId=1,regionConfigId=1,regionType=1,q=0,r=0,height=0,encounterId=1,biomeWeights={{regionType=1,weight=1}}}
local field=generator:Generate(30,412,2,source)
assert(field.areaType==4 and #field.cells==61 and field.discovery=='open' and #field.encounterPlans==1)
assert(#field.encounterPlans[1].cells==3 and field:FindPath(field.entryIndex,field.goalIndex))
assert(#Chest.Plan(field,config:GetTable('MapAreaChestRuleTable'):All(),{})==0)
print('PASS event battlefield retains hex topology, enemy deployment and post-battle navigation')

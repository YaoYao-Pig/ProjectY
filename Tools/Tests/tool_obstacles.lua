package.path='Lua/?.lua;'..package.path
local config=require('Config.ConfigSystem')()
config:OnInit({services={ReadConfig=function(_,name)
    local file=assert(io.open('Assets/GameFramework/Resources/_Gen/Config/'..name..'.bytes','rb'))
    local bytes=file:read('*a');file:close();return bytes
end}})
local generator=require('Game.MapArea.MapAreaGenerator')(config)
generator:Register(1,require('Game.MapArea.DungeonGenerator'),'MapAreaDungeonTable')
generator:Register(3,require('Game.MapArea.ForestGenerator'),'MapAreaForestTable','MapAreaForestThemeTable')
local source={regionId=5,regionType=5,regionConfigId=5,q=0,r=0,height=0,biomeWeights={{regionType=5,weight=1}}}
local planner=require('Game.MapArea.ObstacleGenerator')
local rules=config:GetTable('MapAreaObstacleTable'):All()
local function signature(plans)
    local result={};for _,p in ipairs(plans) do result[#result+1]=p.ruleId..':'..table.concat(p.cells,',') end
    return table.concat(result,';')
end
for _,areaId in ipairs({1,20}) do for _,seed in ipairs({17,20260928}) do
    local area=generator:Generate(areaId,seed,100005,source)
    local used={[area.entryIndex]=true,[area.goalIndex]=true}
    local chests=require('Game.Loot.ChestGenerator').Plan(area,config:GetTable('MapAreaChestRuleTable'):All(),used)
    for _,p in ipairs(chests) do used[p.cellIndex]=true end
    local plans=planner.Plan(area,rules,used)
    local expected=0;for _,rule in ipairs(rules) do if rule.areaId==areaId then expected=expected+rule.count end end
    assert(#plans==expected and signature(plans)==signature(planner.Plan(area,rules,used)))
    local seen={}
    for _,plan in ipairs(plans) do for _,index in ipairs(plan.cells) do
        assert(not area.cells[index].blocked and not used[index] and not seen[index]);seen[index]=true
    end end
    local blocked={};for _,index in ipairs(plans[1].cells) do blocked[index]=true end
    assert(not area:FindPath(area.entryIndex,plans[1].cells[1],function(c)return not blocked[c.index]end))
    assert(area:FindPath(area.entryIndex,plans[1].cells[1]),'Clearing must restore underlying terrain')
    print('PASS deterministic obstacles, reserved cells and restored paths: area '..areaId..', seed '..seed)
end end
local eq=require('Game.Equipment.EquipmentRules').New(config,nil)
for _,id in ipairs({70,71,72,73,74})do assert(eq:IsUtilityWeapon(id)) end
assert(not eq:IsUtilityWeapon(45) and eq:HasWeaponTag(70,'axe') and eq:HasWeaponTag(71,'axe'))
for _,file in ipairs({'Lua/Game/MapArea/ObstacleInteractions.lua','Lua/Game/MapArea/MapAreaSystem.lua','Lua/Game/Adventure/EventSystem.lua','Lua/Game/Adventure/AdventureSystem.lua','Lua/Game/Adventure/MainHudModel.lua','Lua/UI/Panel/StoryEventCtr.lua'})do assert(loadfile(file))end
config:OnShutdown()
print('PASS utility classification, axe variants and changed Lua syntax')

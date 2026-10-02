-- 在布局冻结前安置容器；静态计划与动态库存不重复持有状态。
local Chest=require('Game.Loot.ChestGenerator')
local Layout={}
function Layout.Populate(area,config)
    local rules=config:GetTable('MapAreaChestRuleTable'):All();local any=false
    for _,rule in ipairs(rules) do if rule.areaId==area.configId then any=true;break end end
    area.containerPlans={}
    if not any then return end
    local occupied={}
    local encounterRule=config:GetTable('MapAreaEncounterTable'):Find(area.configId)
    if encounterRule and not area.encounterPlans then
        area.encounterPlans=area.areaType==3 and require('Game.MapArea.ForestEncounters').Plan(area,encounterRule,config)
            or require('Game.MapArea.DungeonEncounters').Plan(area,encounterRule,config:GetTable('CombatEncounterTable'):Get(encounterRule.encounterId))
    end
    if area.encounterPlans then
        local animals=require('Game.Animals.AnimalRules').New(config)
        for _,plan in ipairs(area.encounterPlans) do
            local encounter=config:GetTable('CombatEncounterTable'):Get(plan.encounterId)
            for i,cell in ipairs(plan.cells) do
                for _,part in ipairs(assert(animals:Cells({TemplateId=encounter.enemyIds[i],Q=cell.q,R=cell.r},area))) do occupied[part.index]=true end
            end
        end
    end
    for _,npc in ipairs(area.npcs) do occupied[npc.spawnIndex]=true end
    occupied[area.entryIndex]=true
    local legacy=config:GetTable('EquipmentDemoTable'):Get(1)
    if area.configId==legacy.areaId then
        local queue,dist=Chest.Distances(area);local props={}
        for _,prop in ipairs(area.props) do for _,index in ipairs(prop.cells) do props[index]=true end end
        for i,id in ipairs(legacy.lootTableIds) do
            local selected,score
            for _,index in ipairs(queue) do if not occupied[index] and not props[index] and index~=area.goalIndex then
                local delta=math.abs(dist[index]-legacy.lootDistances[i])
                if not score or delta<score then selected,score=index,delta end
            end end
            assert(selected,'No reachable legacy supply cell');occupied[selected]=true
            area.containerPlans[#area.containerPlans+1]={cellIndex=selected,lootTableId=id,cells={selected},rotation=0,
                seed=(area.seed ~ i*65537) & 0xffffffff,poolOverrideId=0,unlockEncounterId=0}
        end
    end
    for _,plan in ipairs(Chest.Plan(area,rules,occupied,config:GetTable('EquipmentLootTable'))) do
        area.containerPlans[#area.containerPlans+1]=plan
        if plan.prop then
            plan.prop.container=true
            for _,index in ipairs(plan.cells) do
                local cell=area.cells[index]
                if cell.blocked then area.walkableCount=area.walkableCount+1 end
                cell.blocked=false;cell.blocksSight=false;cell.obstacleId=0
            end
        end
    end
end
return Layout

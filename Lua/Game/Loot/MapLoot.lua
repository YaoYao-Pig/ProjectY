local Hex=require('Game.Map.HexGrid')
local Generator=require('Game.Loot.ChestGenerator')
local Loot={};Loot.__index=Loot
function Loot.New(config,equipment)
    return setmetatable({equipment=equipment,rules=require('Game.Loot.LootRules').New(config),
        chestRules=config:GetTable('MapAreaChestRuleTable'),legacy=config:GetTable('EquipmentDemoTable'):Get(1)},Loot)
end
function Loot:Add(state,index,containerId,seed,enemyDrop,name)
    local row=self.rules.containers:Get(containerId)
    local ids,counts=self.rules:Roll(containerId,seed)
    if enemyDrop and #ids==0 then return false end
    state:AddLoot(index,containerId,name or row.name,ids,counts,enemyDrop)
    return true
end
function Loot:Initialize(areas)
    local area,state=areas:ActiveLayout(),areas.data.Active
    if state.LootInitialized then return end
    local used=areas:EnemyOccupancy(area,state)
    for i=0,state.MemberCount-1 do
        local cell=area.cells[state:GetMemberCellAt(i)];local actor=areas:PartyActor(state:GetMemberIdAt(i))
        for _,part in ipairs(assert(areas.combatStats.animals:Cells(actor,area,cell.q,cell.r))) do used[part.index]=true end
    end
    for i=0,state.NpcCount-1 do used[state:GetNpcAt(i).CellIndex]=true end
    -- 原有入口补给按原配方保留，同样在生成时固化内容。
    if area.configId==self.legacy.areaId then
        local queue,dist=Generator.Distances(area)
        for i,id in ipairs(self.legacy.lootTableIds) do
            local selected,score
            for _,index in ipairs(queue) do if not used[index] then
                local delta=math.abs(dist[index]-self.legacy.lootDistances[i])
                if not score or delta<score then selected,score=index,delta end
            end end
            assert(selected,'No reachable legacy supply cell');used[selected]=true
            self:Add(state,selected,id,(area.seed ~ i*65537) & 0xffffffff,false)
        end
    end
    local plans=Generator.Plan(area,self.chestRules:All(),used)
    for _,plan in ipairs(plans) do self:Add(state,plan.cellIndex,plan.lootTableId,plan.seed,false) end
    state:CompleteLootInitialization()
end
function Loot:EnemyDrops(areas,battle)
    return self:ActorDrops(areas,battle:Units(),battle.stats)
end
function Loot:ActorDrops(areas,actors,stats)
    local area,state=areas:ActiveLayout(),areas.data.Active
    local generated=0
    for _,actor in ipairs(actors) do
        if actor.Team==2 and actor.HP==0 and actor.AnimalOwnerId==0 and not actor.DropResolved then
            local rule=self.rules.enemies[actor.TemplateId]
            if rule then
                local cell=assert(area:Find(actor.Q,actor.R),'Defeated enemy is outside the battlefield')
                local seed=(area.seed ~ actor.Id*104729 ~ rule.seedSalt) & 0xffffffff
                if self:Add(state,cell.index,rule.lootTableId,seed,true,stats:Template(actor).name..'的战利品') then generated=generated+1 end
            end
            actor:ResolveDrop()
        end
    end
    return generated
end
function Loot:Contents(container)
    if not container.ContentsReady then
        local row=self.rules.containers:Get(container.TableId)
        assert(row.poolId==0,'Random loot must store its rolled contents at generation time')
        local ids,counts=self.rules:Roll(row.id,0)
        container:SetContents(row.name,ids,counts)
    end
    local ids,counts={},{}
    for i=0,container.ItemCount-1 do ids[#ids+1]=container:GetItemIdAt(i);counts[#counts+1]=container:GetCountAt(i) end
    return ids,counts
end
function Loot:Collect(areas,id)
    local equipment=self.equipment
    if equipment.adventure.Phase~='area' then return false,'只能在探索时搜刮' end
    local state,area=areas.data.Active,areas:ActiveLayout();local container
    for i=0,state.LootCount-1 do local row=state:GetLootAt(i);if row.Id==id then container=row;break end end
    if not container or container.Looted then return false,'这里已经搜刮过了' end
    local cell=area.cells[container.CellIndex];local near=false
    for i=0,state.MemberCount-1 do local member=area.cells[state:GetMemberCellAt(i)]
        if Hex.Distance(cell.q,cell.r,member.q,member.r)<=self.legacy.interactionRadius and area:CanSee(member,cell) then near=true end
    end
    if not near then return false,'先靠近宝箱或掉落物（相邻一格）' end
    local ids,counts=self:Contents(container)
    if not equipment:CanGrant(ids,counts) then return false,'背包空间不足；原地保留战利品，请整理后再领取' end
    for i,itemId in ipairs(ids) do assert(equipment:Grant(itemId,counts[i])) end
    state:Loot(id)
    return true,#ids==0 and '宝箱里没有物品' or ('已搜刮：'..container.Name)
end
function Loot:Snapshot(areas)
    local state=areas.data.Active;local visible,result={},{}
    for i=0,state.VisibleCount-1 do visible[state:GetVisibleAt(i)]=true end
    for i=0,state.LootCount-1 do local container=state:GetLootAt(i);local row=self.rules.containers:Get(container.TableId)
        if not container.ContentsReady then self:Contents(container) end
        if visible[container.CellIndex] and (not container.Looted or row.kind=='chest') then
            result[#result+1]={id=container.Id,cellIndex=container.CellIndex,name=container.Name,looted=container.Looted,
                asset=self.equipment.rules:Asset(container.Looted and row.openedAssetId or row.assetId)}
        end
    end
    return result
end
return Loot

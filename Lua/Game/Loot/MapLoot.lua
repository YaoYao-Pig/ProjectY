local Hex=require('Game.Map.HexGrid')
local Generator=require('Game.Loot.ChestGenerator')
local Loot={};Loot.__index=Loot
function Loot.New(config,equipment)
    return setmetatable({equipment=equipment,rules=require('Game.Loot.LootRules').New(config),
        session=CS.ProjectY.Data.LootSessionData(),
        chestRules=config:GetTable('MapAreaChestRuleTable'),legacy=config:GetTable('EquipmentDemoTable'):Get(1)},Loot)
end
function Loot:Add(state,index,containerId,seed,enemyDrop,name,plan)
    local row=self.rules.containers:Get(containerId)
    local ids,counts=self.rules:Roll(containerId,seed,plan and plan.poolOverrideId)
    if enemyDrop and #ids==0 then return false end
    state:AddLoot(index,containerId,name or row.name,ids,counts,enemyDrop)
    if plan then
        local cells={};for i,cell in ipairs(plan.cells) do cells[i]=cell end
        CS.ProjectY.Data.ContainerState.Initialize(state,state.LootCount,row.maxDurability,row.interaction=='break',plan.unlockEncounterId,plan.rotation,cells)
    end
    return true
end
function Loot:Initialize(areas)
    local area,state=areas:ActiveLayout(),areas.data.Active
    if not state.LootInitialized then
        for _,plan in ipairs(area.containerPlans) do
            self:Add(state,plan.cellIndex,plan.lootTableId,plan.seed,false,nil,plan)
        end
        state:CompleteLootInitialization()
    end
    if not area.containerState then
        areas.layouts[state.SiteId]=require('Game.Loot.ContainerTerrain').Wrap(area,self,state)
    end
end
function Loot:Physical(container) return CS.ProjectY.Data.ContainerState.Of(container) end
function Loot:Find(areas,id)
    local state=areas.data.Active
    if id<1 or id>state.LootCount then return nil end
    return state:GetLootAt(id-1)
end
function Loot:SyncLock(state,container)
    local physical=self:Physical(container)
    if not physical.Unlocked and state:GetEncounterAt(physical.UnlockEncounterId-1).Defeated then
        CS.ProjectY.Data.ContainerState.Unlock(state,container.Id)
    end
    return physical
end
function Loot:Near(areas,container)
    local area,state=areas:ActiveLayout(),areas.data.Active;local physical=self:Physical(container)
    for i=0,state.MemberCount-1 do local member=area.cells[state:GetMemberCellAt(i)]
        for j=0,physical.CellCount-1 do local target=area.cells[physical:GetCellAt(j)]
            if member.layer==target.layer and Hex.Distance(member.q,member.r,target.q,target.r)<=self.legacy.interactionRadius and area:CanSee(member,target) then
                if member.index==target.index then return true end
                for _,index in ipairs(target.neighbors) do local side=area.cells[index]
                    if side and not side.blocked and side.layer==target.layer then
                        local connected=false
                        for direction,neighbor in ipairs(side.neighbors) do
                            if neighbor==target.index and (side.walkMask & (1 << (direction-1)))~=0 then connected=true;break end
                        end
                        if connected then
                            local path=area:FindPath(member.index,side.index)
                            if path and #path<self.legacy.interactionRadius then return true end
                        end
                    end
                end
            end
        end
    end
    return false
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
    for i=0,container.ItemCount-1 do
        local count=container:GetCountAt(i)
        if count>0 then ids[#ids+1]=container:GetItemIdAt(i);counts[#counts+1]=count end
    end
    return ids,counts
end
function Loot:Collect(areas,id)
    local equipment=self.equipment
    if equipment.adventure.Phase~='area' then return false,'只能在探索时搜刮' end
    if self.session.Active then return false,'请先关闭当前搜刮窗口' end
    local state,area=areas.data.Active,areas:ActiveLayout();local container
    for i=0,state.LootCount-1 do local row=state:GetLootAt(i);if row.Id==id then container=row;break end end
    if not container then return false,'容器不存在' end
    local definition=self.rules.containers:Get(container.TableId)
    if container.Looted and definition.kind=='ground' and definition.brokenAssetId==0 then return false,'这里已经搜刮过了' end
    local physical=self:SyncLock(state,container)
    if not physical.Unlocked then return false,'清除守卫后才能打开或破坏这个容器' end
    if not physical.CanSearch then return false,'用普通攻击或伤害技能打碎容器后再拾取' end
    if not self:Near(areas,container) then return false,'先靠近容器的可交互一侧' end
    if definition.interaction=='tool' and not physical.Destroyed and not self.session:IsOpened(container) then
        local worker=false
        for i=0,state.MemberCount-1 do local actor=areas:PartyActor(state:GetMemberIdAt(i))
            if actor.HP>0 then for _,hand in ipairs({'Equipped','Offhand'}) do
                local weapon=self.equipment.data[hand](self.equipment.data,actor.Id)
                if weapon and self.equipment.rules:HasWeaponTag(weapon.ItemId,definition.toolTag) then worker=true end
            end end
        end
        if not worker then return false,'需要装备对应工具，或用攻击破坏容器' end
        areas:Stop();areas:SpendWorkRounds(definition.interactionRounds)
        if not areas:RefreshLivingSquad() then return false,'队伍已无法继续探索' end
    end
    self:Prepare(container);state:Stop()
    self.session:Open(state,{id},false,container.Name,'搜索后可双向拖动物品，也可在容器内整理位置')
    return true
end
function Loot:Prepare(container)
    self:Contents(container)
    local kinds,widths,heights={},{},{}
    for i=0,container.ItemCount-1 do
        local item=self.equipment.rules.items:Get(container:GetItemIdAt(i))
        kinds[#kinds+1]=item.kind;widths[#widths+1]=item.width;heights[#heights+1]=item.height
    end
    self.session:Prepare(container,kinds,widths,heights)
end
function Loot:OpenBattle(areas,first,summary)
    local state=areas.data.Active;local ids={}
    for i=first,state.LootCount-1 do
        local container=state:GetLootAt(i);self:Prepare(container);ids[#ids+1]=container.Id
    end
    state:Stop();self.session:Open(state,ids,true,'战斗结算',summary)
end
function Loot:Take(areas,key,x,y,rotated)
    local session=self.session
    if self.equipment.adventure.Phase~='area' or not session.Active or session.Area~=areas.data.Active then return false,'搜刮已结束' end
    local entry=session:Find(key)
    if not entry or entry.Count==0 then return false,'这件战利品已被取走' end
    if not entry.Revealed then return false,'请等待搜索完成' end
    local ammo,capacity,rounds=0,0,0
    if entry.Kind=='magazine' then
        local row=self.equipment.rules.magazines:Get(entry.ItemId);ammo,capacity,rounds=row.ammoItemId,row.capacity,row.spawnRounds
    end
    local count=entry.Count
    if not session:Take(self.equipment.data,key,x,y,rotated,ammo,capacity,rounds) then return false,'放置位置无效；物品仍在右侧，同类物品请拖到已有堆叠上' end
    return true,self.equipment.rules.items:Get(entry.ItemId).name..' ×'..count,entry.ContainerId
end
function Loot:Move(areas,key,x,y,rotated)
    local session=self.session
    if self.equipment.adventure.Phase~='area' or not session.Active or session.Area~=areas.data.Active then return false,'搜刮已结束' end
    if session.SelectedContainerId==0 then return false,'请先选择一个容器，再整理或存入物品' end
    if not session:Move(key,x,y,rotated) then return false,'位置被占用、超出容器范围或物品尚未搜索' end
    return true,'已保存容器内的位置'
end
function Loot:Put(areas,key,x,y,rotated)
    local session=self.session
    if self.equipment.adventure.Phase~='area' or not session.Active or session.Area~=areas.data.Active then return false,'搜刮已结束' end
    if session.SelectedContainerId==0 then return false,'请先选择要存入的战利品容器' end
    local place=self.equipment.data.Grid:Find(key)
    if not place then return false,'只能存入左侧背包中的物品' end
    local name=self.equipment.rules.items:Get(place.ItemId).name
    if not session:Put(self.equipment.data,key,x,y,rotated) then return false,'容器位置被占用或超出范围，物品保留在背包中' end
    return true,'已存入容器：'..name
end
function Loot:Snapshot(areas)
    local state,area=areas.data.Active,areas:ActiveLayout();local visible,result={},{}
    for i=0,state.VisibleCount-1 do visible[state:GetVisibleAt(i)]=true end
    for i=0,state.LootCount-1 do local container=state:GetLootAt(i);local row=self.rules.containers:Get(container.TableId)
        if not container.ContentsReady then self:Contents(container) end
        local physical=self:SyncLock(state,container);local cells,shown={},false
        for j=0,physical.CellCount-1 do local index=physical:GetCellAt(j);cells[#cells+1]=index;shown=shown or visible[index] end
        local assetId=self.session:IsOpened(container) and row.openedAssetId or row.assetId
        if container.Looted and row.emptyAssetId>0 then assetId=row.emptyAssetId end
        if physical.Destroyed then
            assetId=row.brokenAssetId
            if assetId==0 and not container.Looted then
                for j=0,container.ItemCount-1 do if container:GetCountAt(j)>0 then
                    assetId=self.equipment.rules.items:Get(container:GetItemIdAt(j)).assetId;break
                end end
            end
        end
        if shown and assetId>0 and (not container.Looted or row.kind=='chest' and not physical.Destroyed or row.brokenAssetId>0) then
            local plan=area.containerPlans[i+1];local prop=plan and plan.prop
            local items={}
            if row.displayContents~='none' and not physical.Destroyed then
                for j=0,container.ItemCount-1 do if container:GetCountAt(j)>0 then
                    items[#items+1]={index=j,asset=self.equipment.rules:Asset(self.equipment.rules.items:Get(container:GetItemIdAt(j)).assetId)}
                end end
            end
            local scale=physical.Destroyed and 1 or row.modelScale
            result[#result+1]={id=container.Id,cellIndex=container.CellIndex,cells=cells,name=container.Name,looted=container.Looted,
                durability=physical.Durability,maxDurability=physical.MaxDurability,destroyed=physical.Destroyed,
                canSearch=physical.CanSearch,near=self:Near(areas,container),interaction=row.interaction,
                blocksMovement=physical.Configured and not physical.Destroyed and row.blocksMovement,
                rotation=prop and (prop.yaw or -prop.rotation*60) or -physical.Rotation*60,
                scale=scale,scaleX=prop and not physical.Destroyed and (prop.scaleX or prop.scale*area.hexRadius) or scale,
                scaleY=prop and not physical.Destroyed and (prop.scaleY or prop.scale*area.hexRadius) or scale,
                scaleZ=prop and not physical.Destroyed and (prop.scaleZ or prop.scale*area.hexRadius) or scale,
                items=items,displayContents=row.displayContents,displayHeight=row.displayHeight,displayItemScale=row.displayItemScale,
                offsetX=prop and prop.offsetX or 0,offsetZ=prop and prop.offsetZ or 0,
                height=prop and prop.height or area.cells[container.CellIndex].height,
                asset=self.equipment.rules:Asset(assetId)}
        end
    end
    return result
end
return Loot

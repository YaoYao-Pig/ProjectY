-- Rebuild immutable layouts and check the prepared C# records before replacing the active expedition.
local Save={}
local function validateGround(rules,bridge,container)
    local function magazine(item)
        if not item then return end
        local definition=rules.magazines:Get(item.ItemId)
        assert(rules.items:Get(item.ItemId).kind=='magazine' and item.Capacity==definition.capacity and item.AmmoItemId==definition.ammoItemId,'存档容器弹匣规格与配置不符')
    end
    for i=0,bridge.GroundCount(container)-1 do
        local weapon=bridge.GroundWeapon(container,i)
        local loose,loaded=bridge.GroundMagazine(container,i,false),bridge.GroundMagazine(container,i,true)
        magazine(loose);magazine(loaded)
        if weapon then
            local definition=rules.weapons:Get(weapon.ItemId);rules.affixes:Of(weapon)
            assert(rules.items:Get(weapon.ItemId).kind=='weapon','存档容器武器类型无效')
            if loaded then assert(loaded.ItemId==definition.magazineItemId,'存档容器武器的弹匣不兼容') end
            for j=0,weapon.RuneCount-1 do
                local id=weapon:GetRuneSocketAt(j);local allowed=false
                for _,socket in ipairs(definition.socketIds) do if socket==id then allowed=true;break end end
                assert(allowed,'存档容器武器配件槽已不存在')
                assert(rules.runes:Get(weapon:GetRune(id)).slotKind==rules.sockets:Get(id).kind,'存档容器武器配件不兼容')
            end
        end
        local wearable=bridge.GroundWearable(container,i)
        if wearable then rules.wearables:Get(wearable.ItemId);rules.affixes:Of(wearable);assert(rules.items:Get(wearable.ItemId).kind=='wearable','存档容器防具类型无效') end
    end
end
function Save.Prepare(adventure,prepared)
    local bridge=CS.ProjectY.Data.ExpeditionPersistence
    local world=adventure:BuildWorld(prepared.Seed,bridge.Recipe(prepared),bridge.Target(prepared)>0 and bridge.Target(prepared) or nil)
    world.layouts={};world.states={}
    if not bridge.HasWorld(prepared) then return world end
    adventure.fog:Prepare(world.map,prepared)
    local baseCount=#world.sites
    local travel=bridge.Travel(prepared)
    assert(world.map:GetCell(travel.Q,travel.R),'存档旅行位置不在当前地图')
    for i=0,travel.StepCount-1 do local step=travel:GetStepAt(i);assert(world.map:GetCell(step.Q,step.R),'存档旅行路线已不在当前地图') end
    for i=0,travel.StopCount-1 do
        local stop=travel:GetStopAt(i);local cell=assert(world.map:GetCell(stop.Q,stop.R),'存档旅途地点已不在当前地图')
        assert(stop.Id==#world.sites+1,'存档旅途地点与当前地图不一致')
        local x,y,z=world.map:GetCellWorldPosition(cell.q,cell.r)
        world.sites[stop.Id]={id=stop.Id,eventId=stop.EventId,q=cell.q,r=cell.r,x=x,y=y,z=z,travelStop=true,
            name=stop.EncounterId>0 and adventure.battle.encounters:Get(stop.EncounterId).name or adventure.events.events:Get(stop.EventId).name}
    end
    bridge.ValidateSites(prepared,baseCount,#world.sites)
    local parties=CS.ProjectY.Data.WorldPartiesData.Prepared(prepared)
    local factions=parties.Factions
    assert(not parties.Initialized or parties.Clock<=prepared.Narrative.Minutes,'存档队伍时钟超前')
    for i=0,parties.Count-1 do
        local party=parties:GetAt(i);local row=adventure.parties.definitions:Get(party.DefinitionId)
        for j=0,party.MemberCount-1 do adventure.battle.gameEffects:ValidateSaved(party:GetMemberAt(j)) end
        assert(world.map:FindCell(party.Travel.Q,party.Travel.R),'存档游荡队伍位置无效')
        if party.AbstractTravel then
            local target=assert(world.map:FindCell(party.AbstractQ,party.AbstractR),'存档抽象行程目的地无效')
            assert(not target.waterLevel,'抽象行程不能到达水域')
        end
        if row.kind=='caravan' then
            assert(world.sites[party.HomeSiteId] and world.sites[party.DestinationSiteId],'存档商队城镇失效')
            assert(party.Defeated or party.Cargo,'存档商队货物丢失')
        elseif party.Cargo then assert(party.Role=='raider' or party.Role=='patrol','该类队伍不能持有劫获货物') end
        if party.BattleSiteId>0 then
            assert(world.sites[party.BattleSiteId] and world.sites[party.BattleSiteId].travelStop,'存档队伍战场失效')
        end
        for j=0,party.Travel.StepCount-1 do local step=party.Travel:GetStepAt(j);assert(world.map:FindCell(step.Q,step.R),'存档队伍路线失效') end
        if party.Cargo then
            validateGround(adventure.equipment.rules,bridge,party.Cargo)
            for j=0,party.CargoCount-1 do local item=party:GetCargoAt(j)
                adventure.equipment.rules.items:Get(item.ItemId);assert(adventure.parties.prices[item.ItemId],'存档货物没有价格')
            end
        end
    end
    for i=0,factions.ConflictCount-1 do local conflict=factions:GetConflictAt(i)
        for j=0,conflict.PendingCargoCount-1 do
            local cargo=conflict:GetPendingCargoAt(j)
            validateGround(adventure.equipment.rules,bridge,cargo)
            for k=0,cargo.ItemCount-1 do adventure.equipment.rules.items:Get(cargo:GetItemIdAt(k)) end
        end
    end
    local npcs=adventure.narrative and require('Game.Narrative.NpcSystem').New(adventure.narrative)
    if npcs then npcs:BindWorld(world.sites) end
    for i=0,bridge.AreaCount(prepared)-1 do
        local site=assert(world.sites[bridge.AreaSite(prepared,i)],'存档探索地点已不存在')
        local definition=bridge.AreaDefinition(prepared,i)
        local source,point=site.source,site.pointId
        if not site.areaConfigId then
            local special=adventure.specialEvents.byEvent[site.eventId]
            assert(definition==(special and special.areaId or adventure.areas.battlefieldAreaId),'事件地点与配置的小地图不一致')
            local cell=world.map:GetCell(site.q,site.r);local region=world.map:GetRegion(cell.regionId)
            source={regionId=region.instanceId,regionConfigId=region.configId,regionType=region.regionType,
                q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights,encounterId=bridge.AreaEncounter(prepared,i)}
            if site.travelStop then local terrain=assert(adventure.travel.terrains[region.regionType]);source.obstacleChance=terrain.battleObstacleChance;source.surfaceId=terrain.battleSurfaceId;source.propIds=terrain.battlePropIds end
            if factions:FindConflict(site.id) then source.factionConflict=true;source.obstacleChance=.06 end
            point=site.id
        else assert(definition==site.areaConfigId,'存档探索区域配置已变化') end
        local layout=adventure.areas.generator:Generate(definition,prepared.Seed,point,source,function(area)
            if npcs then npcs:Populate(area,site) end
            adventure.specialEvents:Decorate(area)
        end)
        assert(#layout.cells==bridge.AreaCells(prepared,i),'存档区域布局已变化')
        local state=bridge.Area(prepared,i)
        assert(#layout.npcs==state.NpcCount,'存档居民配置已变化')
        for n=0,state.MemberCount-1 do assert(not layout.cells[state:GetMemberCellAt(n)].blocked,'存档队伍位于阻挡地格') end
        for n=0,state.EncounterCount-1 do local group=state:GetEncounterAt(n)
            adventure.battle.encounters:Get(group.EncounterId)
            for j=0,group.EnemyCount-1 do local actor=group:GetEnemyAt(j)
                adventure.config:GetTable('CombatUnitTable'):Get(actor.TemplateId)
                assert(actor.AnimalSpeciesId~=0 or adventure.battle.stats.animals:IsStaticBody(actor) or actor.CustomizationJson~='', '存档角色缺少外观')
                assert(layout:Find(actor.Q,actor.R),'存档敌人坐标不在区域内')
                for k=0,actor.TraitCount-1 do adventure.config:GetTable('CombatTraitTable'):Get(actor:GetTraitAt(k)) end
                adventure.battle.gameEffects:ValidateSaved(actor)
            end
        end
        for n=0,state.LootCount-1 do local loot=state:GetLootAt(n)
            adventure.equipment.worldLoot.rules.containers:Get(loot.TableId)
            for j=0,loot.ItemCount-1 do adventure.config:GetTable('EquipmentItemTable'):Get(loot:GetItemIdAt(j)) end
            validateGround(adventure.equipment.rules,bridge,loot)
        end
        world.layouts[site.id]=layout;world.states[site.id]=state
    end
    adventure.narrative.townMissions:ValidateSaved(CS.ProjectY.Data.TownMissionData.Prepared(prepared),world,parties)
    return world
end
function Save.BindLayouts(adventure,world)
    for site,layout in pairs(world.layouts) do
        local constructed=adventure.construction:Layout(layout,site)
        adventure.areas.layouts[site]=require('Game.Loot.ContainerTerrain').Wrap(constructed,adventure.equipment.worldLoot,assert(world.states[site]))
    end
end
function Save.RestoreLayouts(adventure,world)
    if adventure.data.Areas.Active then
        if adventure.narrative then adventure.narrative.npcs:SyncPresence() end
        adventure.areas:RevealSquad(adventure.areas:ActiveLayout(),adventure.data.Areas.Active)
    end
end
return Save

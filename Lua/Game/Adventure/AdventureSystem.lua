local Class = require('Core.Class')
local System = require('Core.LuaSystem')
local Hex = require('Game.Map.HexGrid')
local Adventure = Class('AdventureSystem', System)
function Adventure:OnInit(context)
    System.OnInit(self, context)
    local config = context.systems:Get('Config')
    self.config=config
    self.characterSaves=assert(context.services.CharacterSaves,'Character save service requires regenerated xLua bindings')
    self.characterAppearances=require('Game.Adventure.CharacterAppearance').New(config,context.services.Appearances)
    self.recipe = config:GetTable('AdventureDemoTable'):Get(1)
    self.appearances = require('Game.Adventure.PawnAppearance').New(config)
    self.mapSystem = context.systems:Get('Map')
    self.battle = context.systems:Get('Battle')
    self.events = context.systems:Get('AdventureEvents')
    self.growth = context.systems:Get('Growth')
    self.data, self.player = context.services.Adventure, context.services.Player
    self.areas = context.systems:Get('MapArea')
    self.equipment = context.systems:Get('Equipment')
    self.obstacles=require('Game.MapArea.ObstacleInteractions').New(config,self)
    self.areas.obstacles=self.obstacles
    self.construction=require('Game.Battle.Construction').New(config,self)
    self.battle.construction=self.construction;self.areas.construction=self.construction
    self.containerCombat=require('Game.Loot.ContainerCombat').New(self)
    self.battle.containerCombat=self.containerCombat
    self.explorationEvents = require('Game.Adventure.ExplorationEvents').New(config,self)
    self.professionExploration=require('Game.Adventure.ProfessionExploration').New(self)
    self.characterSkills=require('Game.Adventure.CharacterSkills').New(self)
    self.professionExploration:RegisterHandlers(self.characterSkills)
    self.battle.beasts:RegisterLife(self.characterSkills,self)
    require('Game.Adventure.ProfessionDuels').Register(self.characterSkills,self)
    self.shop=require('Game.Shop.ShopModel').New(self)
    self.camp=require('Game.Camp.CampModel').New(self)
    self.partyStory=require('Game.Progression.PartyStory').New(self)
    self.travel=require('Game.Adventure.WorldTravel').New(self)
    self.water=require('Game.Adventure.WaterTravel').New(self)
    self.specialEvents=require('Game.Adventure.SpecialEvents').New(self)
    self.events.specialEvents=self.specialEvents
    self.fog=require('Game.Adventure.WorldFog').New(self)
    self.parties=require('Game.Adventure.WorldParties').New(self)
    self.factions=require('Game.Adventure.WorldFactions').New(self)
    self.areas.factions=self.factions
    assert(self.recipe.maxPartySize<=4 and #self.recipe.partyIds > 0 and #self.recipe.partyIds <= self.recipe.maxPartySize, 'Invalid demo party size')
    assert(#self.recipe.buildingIds == #self.recipe.buildingEventIds, 'Building event mapping differs')
end
function Adventure:OnStart() self.partyStory:Start() end
function Adventure:BuildWorld(seed,recipeId,targetCells,progress,generationVersion)
    local recipe = self.config:GetTable('AdventureDemoTable'):Get(recipeId or 1)
    if generationVersion==6 and not recipe.seededRegions then generationVersion=5 end
    local map
    if recipe.seededRegions then
        map = self.mapSystem:GenerateSeeded(seed,targetCells,progress,#recipe.regionIds > 0 and recipe.regionIds or nil,generationVersion)
    else map = self.mapSystem:Generate(seed,recipe.regionIds,targetCells,progress,generationVersion) end
    local sites, dry = {}, {}
    for _, cell in ipairs(map:GetCells()) do
        if not cell.waterLevel and not cell.buildingId and not cell.worldTravelBlocked then dry[#dry + 1] = cell end
    end
    assert(#dry > #recipe.wildEventIds, 'Map needs dry cells for adventure sites')
    local function addSite(eventId, cell, name)
        local x, y, z = map:GetCellWorldPosition(cell.q, cell.r)
        sites[#sites + 1] = {id = #sites + 1, eventId = eventId, q = cell.q, r = cell.r,
            name = name or self.events.events:Get(eventId).name, x = x, y = y, z = z}
    end
    local camp, closest
    for _, cell in ipairs(dry) do
        local distance = Hex.Distance(0, 0, cell.q, cell.r)
        if not closest or distance < closest then camp, closest = cell, distance end
    end
    addSite(recipe.campEventId, camp)
    for _, eventId in ipairs(recipe.wildEventIds) do
        local selected, furthest
        for _, cell in ipairs(dry) do
            local nearest = math.huge
            for _, site in ipairs(sites) do nearest = math.min(nearest, Hex.Distance(cell.q, cell.r, site.q, site.r)) end
            if not furthest or nearest > furthest then selected, furthest = cell, nearest end
        end
        assert(furthest > 0, 'Adventure sites overlap')
        addSite(eventId, selected)
    end
    local areaTowns={}
    for _,site in ipairs(self.areas:Entrances(map)) do
        site.id=#sites+1;sites[#sites+1]=site;areaTowns[site.pointId]=true
    end
    if recipe.startAreaId>0 then
        local market
        local areaId=recipe.startAreaId
        for _,site in ipairs(sites) do if site.areaConfigId==areaId then market=site;break end end
        assert(market,'本次地图没有剧情集市；请选择更大地图规模')
        local town=map:GetCell(market.q,market.r);local start
        for direction=1,6 do local q,r=Hex.Neighbor(town.q,town.r,direction);local cell=map:FindCell(q,r)
            if cell and not cell.waterLevel and not cell.worldTravelBlocked and math.abs(cell.height-town.height)<=self.travel.maxStep then start=cell;break end
        end
        assert(start,'剧情集市周围没有可通行营地位置')
        sites[1].q=start.q;sites[1].r=start.r;sites[1].x,sites[1].y,sites[1].z=map:GetCellWorldPosition(start.q,start.r)
    end
    local mapping = {}
    for i, id in ipairs(recipe.buildingIds) do mapping[id] = recipe.buildingEventIds[i] end
    for _, building in ipairs(map:GetBuildings()) do
        local eventId = mapping[building.configId]
        if eventId and not areaTowns[building.townId] and #sites < 10 then addSite(eventId, building.cell) end
    end
    if map.generationVersion>=7 then
        for _,site in ipairs(require('Game.MapArea.NaturalEntrances').Build(map,self.config,self.areas.generator.definitions,sites[1])) do
            site.id=#sites+1;sites[#sites+1]=site
        end
    end
    return {map=map,sites=sites,recipe=recipe,seed=seed,targetCells=targetCells or 0,generationVersion=map.generationVersion}
end
function Adventure:Start(seed,recipeId,targetCells,preparedWorld,initialProfessionId)
    local recipe=self.config:GetTable('AdventureDemoTable'):Get(recipeId or 1)
    seed=seed or recipe.seed
    local world=preparedWorld or self:BuildWorld(seed,recipe.id,targetCells)
    self.equipment.worldLoot.session:Close()
    self.recipe=world.recipe
    self.areas:Clear();self.construction.data:Clear();self.data:Reset(seed)
    local map,sites=world.map,world.sites
    self.map, self.sites = map, sites
    CS.ProjectY.Data.ExpeditionPersistence.Configure(self.data,self.construction.data,self.obstacles.data,self.recipe.id,world.targetCells)
    CS.ProjectY.Data.ExpeditionPersistence.SetGeneration(self.data,world.generationVersion)
    self.travel:Reset(map,sites)
    self.water:Bind(map,sites,true)
    self.fog:Reset(map)
    self.parties:Bind(map,sites)
    self.partyStory:Reset()
    for i, id in ipairs(self.recipe.partyIds) do
        local actor = self.data:AddPartyActor(i, id)
        self.characterAppearances:Party(actor,seed)
        self.growth:PrepareActor(actor,i==1 and initialProfessionId or nil)
        actor:SetMaxHP(self.battle.stats:MaximumHP(actor)); actor:Restore()
    end
    self.equipment:Start(self.recipe.equipmentRecipeId)
    self.equipment:StartPartyLoadouts()
    for i=0,self.data.PartyCount-1 do local actor=self.data:GetPartyAt(i);actor:SetMaxHP(self.battle.stats:MaximumHP(actor));actor:Restore() end
    if self.narrative then self.narrative:Start() end
    for i=0,self.data.PartyCount-1 do
        local actor=self.data:GetPartyAt(i)
        local main,off=self.equipment.data:Equipped(actor.Id),self.equipment.data:Offhand(actor.Id)
        if main then self.professionExploration:OnEquip(actor,main)end
        if off then self.professionExploration:OnEquip(actor,off)end
    end
    self.parties:Initialize()
    self.factions:ObserveWorld()
    for i=0,self.data.PartyCount-1 do self.growth:RecordJoined(self.data:GetPartyAt(i),'营地') end
end
function Adventure:RestorePrepared(prepared,world)
    self.equipment.worldLoot.session:Close()
    self.areas:Clear();self.construction.data:Clear();self.data:Reset(prepared.Seed)
    self.recipe=world.recipe;self.map=world.map;self.sites=world.sites
    CS.ProjectY.Data.ExpeditionPersistence.Configure(self.data,self.construction.data,self.obstacles.data,self.recipe.id,world.targetCells)
    CS.ProjectY.Data.ExpeditionPersistence.SetGeneration(self.data,world.generationVersion)
    self.travel:Reset(world.map,world.sites);self.partyStory:Reset()
    self.water:Bind(world.map,world.sites,true)
    self.parties:Bind(world.map,world.sites)
    if self.narrative then self.narrative.lastBuffMinute=nil;self.narrative.npcs:BindWorld(world.sites) end
    require('Game.Adventure.ExpeditionSave').BindLayouts(self,world)
    if prepared.LegacyNarrative and self.narrative then self.narrative:Start() end
    self.fog:Bind(world.map)
    self.characterSaves:Apply(prepared,self.data,self.player)
    self.water:Bind(world.map,world.sites,false)
    self.fog:Update()
    require('Game.Adventure.ExpeditionSave').RestoreLayouts(self,world)
    self.parties:Initialize()
    self.factions:ObserveWorld()
end
function Adventure:Visit(siteId)
    return self.travel:Visit(siteId)
end
function Adventure:EnterSite(siteId)
    if self.camp.data.IsOpen then return false,'请先关闭营地面板' end
    local site = self.sites[siteId]
    if not site then return false, '未知地点' end
    local available,explanation=self.specialEvents:CanEnter(site)
    if not available then return false,explanation end
    local handled,entered,explanation=self.factions.conflicts:EnterSite(siteId)
    if handled then return entered,explanation end
    if self.areas:AreaId(site) then
        local ok,reason=self.areas:Enter(site,self.data.Seed)
        if ok then self.equipment:InitializeLoot(self.areas);self.obstacles:Initialize();self.explorationEvents:Try('enter',0) end
        return ok,reason
    end
    local ok,reason = self.events:Begin(site)
    if not ok then return false,reason end
    local event = self.events.events:Get(site.eventId)
    if event.presentation == 'simple' then
        ok,reason = self:Choose(event.choiceIds[1])
        -- 简单事件的条件应在配置层保证可结算；失败时保留当前状态并显示原因。
        if not ok then return false,reason end
        -- 保留结果阶段，让异步旅行轮询能打开 StoryEvent；玩家确认后再返回大地图。
    end
    return true
end
function Adventure:AreaCommand(command,a,b)
    if self.water.data.IsOpen then return false,require('Language').WaterCloseMenu end
    if self.shop.data.IsOpen then return false,'请先关闭商店' end
    if self.narrative and self.narrative.data.DialogueOpen then return false,'请先结束当前对话' end
    if command=='area_interact_nearest' then return require('Game.Adventure.InteractionPrompt').Execute(self) end
    if command=='area_tame' then return self.areas:Tame(a,b) end
    if command=='area_obstacle' then return self.obstacles:Begin(a) end
    if command=='area_loot' then
        return self.equipment:Loot(self.areas,a)
    end
    if command=='area_move' then local cell=self.areas:ActiveLayout():Find(a,b);return self.obstacles:MoveTo(cell and cell.index or 0) end
    if command=='area_move_cell' then return self.obstacles:MoveTo(a) end
    if command=='area_walk' then return self.areas:Walk(a) end
    if command=='area_interact' then
        local ok,reason=self.areas:Interact(a,b)
        if ok and a==2 and self.narrative then
            local npc=self.areas:ActiveLayout().npcs[b]
            if npc.dockId then return self.water:Open(npc.dockId) end
            if npc.narrativeId and #self.narrative.rules.npcs:Get(npc.narrativeId).dialogueIds>0 then
                ok,reason=self.narrative.dialogue:Open(npc.narrativeId,b)
                if not ok then self.areas:CloseInteraction() end
                return ok,reason
            end
            if self.shop.rules:Resolve(self.areas:ActiveLayout(),npc) then return self.shop:Open(b) end
        end
        if ok and a==1 then
            local area=self.areas:ActiveLayout()
            if area.facilities[b].kind=='dock' then return self.water:Open(area.facilities[b].dockId) end
            for _,npc in ipairs(area.npcs) do
                if npc.facilityId==b and self.shop.rules:Resolve(area,npc) then
                    ok,reason=self.shop:Open(npc.id)
                    if not ok then self.areas:CloseInteraction() end
                    return ok,reason
                end
            end
            self.explorationEvents:Try('facility',area.facilities[b].configId)
        end
        return ok,reason
    end
    if command=='area_close' then return self.areas:CloseInteraction() end
    if command=='area_stop' then self.obstacles.data:Cancel();return self.areas:Stop() end
    if command=='area_leave' then self.obstacles.data:Cancel();return self.areas:Leave() end
    error('Unknown MapArea command: '..tostring(command))
end
function Adventure:TakeLoot(key,x,y,rotated)
    local ok,reason,containerId=self.equipment.worldLoot:Take(self.areas,key,x,y,rotated)
    if ok then
        local container=self.equipment.worldLoot.session.Area:GetLootAt(containerId-1)
        self.growth.chronicle:Record('loot',nil,container.Name,reason,self.areas:ActiveLayout().name,true)
    end
    return ok,reason
end
function Adventure:CloseLoot()
    local session=self.equipment.worldLoot.session;local state=session.Area;local completed={}
    if state then
        for i=0,state.LootCount-1 do
            local container=state:GetLootAt(i)
            if session:Contains(container.Id) and container.Looted then completed[#completed+1]=container end
        end
    end
    session:Close()
    if state and self.data.Phase=='area' and state==self.data.Areas.Active then
        for _,container in ipairs(completed) do
            if container.ItemCount==0 then self.growth.chronicle:Record('loot',nil,container.Name,'打开了一个空箱子。',self.areas:ActiveLayout().name,true) end
            self.explorationEvents:Try('loot',container.TableId)
        end
    end
end
function Adventure:Choose(choiceId)
    local ok, choice, resultText = self.events:Choose(choiceId)
    if not ok then return false, choice end
    if self.specialEvents:Choose(choice,resultText) then return true end
    if #choice.encounterIds == 1 then
        local site=assert(self.sites[self.data.SiteId]);local cell=self.map:GetCell(site.q,site.r)
        local region=self.map:GetRegion(cell.regionId)
        local source={regionId=region.instanceId,regionConfigId=region.configId,regionType=region.regionType,
            q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights,encounterId=choice.encounterIds[1]}
        assert(self.areas:EnterEventBattlefield(site,self.data.Seed,source))
        self.equipment:InitializeLoot(self.areas)
        self.areas:StartBattle(self.battle,self.data.Areas.Active:GetEncounterAt(0))
    else
        self.data:Complete(resultText or self.events:Text(choice.result))
    end
    return true
end
function Adventure:SettleBattle()
    local result = self.data.Battle.Winner
    if result == '' then return end
    if self.professionDuels:Settle(result) then return end
    assert(self.data.Phase == 'battle', 'Battle result already consumed')
    self.data:BeginSettlement()
    local specialMessage=self.specialEvents:Settle(result)
    local encounter = self.battle.encounters:Get(self.data.Battle.EncounterId)
    local location = assert(self.sites[self.data.SiteId]).name
    self.partyStory:Settle(result,location)
    self.growth.chronicle:Record('battle',nil,encounter.name,
        result=='victory' and '小队赢得了战斗。' or (result=='defeat' and '小队败退，带着伤势返回。' or '小队撤出了战斗。'),location,true)
    for _,actor in ipairs(self.battle:Units()) do
        if actor.Team==1 and actor.AnimalOwnerId==0 and actor.HP>0 then self.battle.stats.animals:BattleBond(actor) end
    end
    if result=='victory' then
        for _, actor in ipairs(self.battle:Units()) do
            if actor.Team==1 and actor.AnimalOwnerId==0 then self.growth:AddExperience(actor,encounter.experience,location) end
        end
    end
    if self.data.AreaEncounterId>0 then
        local firstLoot=assert(self.battle.board.lootStartCount,'Missing battle loot boundary')
        local dropped=self.equipment:GenerateEnemyDrops(self.areas,self.battle)+self.parties:Settle(result)
        local message
        if result=='victory' then
            local encounter=self.battle.encounters:Get(self.data.Battle.EncounterId)
            self.player:AddCoins(encounter.rewardCoins);self.events:AwardTraits(encounter.rewardTraitIds)
            message='敌群已击败，获得 '..encounter.rewardCoins..' 金币。可以继续探索。'
            if dropped>0 then message=message..' 发现 '..dropped..' 份战利品，请搜索并拖入背包。' end
        elseif result=='defeat' then message='小队全员倒地，已撤回大地图，请到营地休整。'
        else message='战斗时间耗尽，已撤回大地图。敌人的伤势保留。' end
        if specialMessage then message=specialMessage end
        self.areas:RestoreAfterBattle(self.battle)
        self.data:FinishAreaBattle(message);self.battle.board=nil
        if specialMessage then self.narrative:Refresh() end
        if result=='victory' then
            self.equipment.worldLoot:OpenBattle(self.areas,firstLoot,message)
            self.explorationEvents:Try('victory',encounter.id)
        end
        return
    end
    if result == 'victory' then
        local encounter = self.battle.encounters:Get(self.data.Battle.EncounterId)
        self.player:AddCoins(encounter.rewardCoins)
        self.events:AwardTraits(encounter.rewardTraitIds)
        self.data:Complete('胜利！带回 ' .. encounter.rewardCoins .. ' 金币。伤势保留，返回移动营地可休整。')
    elseif result == 'defeat' then
        self.data:Complete('队伍败退，本次没有战利品。返回地图后，请到移动营地休整。')
    else
        self.data:Complete('队伍撤回，本次没有战利品。可以返回移动营地休整。')
    end
end
function Adventure:BattleCommand(command, a, b)
    if self.data.Phase ~= 'battle' then return false, '当前不在战斗中' end
    local actor = self.battle:Active()
    if command ~= 'ai' and actor.Team ~= 1 then return false, '等待敌方行动' end
    local ok, reason
    if command == 'move' then ok, reason = self.battle:TryMove(a, b)
    elseif command == 'move_cell' then
        if self.data.AreaEncounterId==0 then return false,'当前不是地牢战斗' end
        local cell=self.areas:ActiveLayout().cells[a]
        if not cell then return false,'无效地格' end
        ok,reason=self.battle:TryMove(cell.q,cell.r)
    elseif command == 'skill' then ok, reason = self.battle:TrySkill(a, b)
    elseif command == 'skill_targets' then
        local ids={};for i=0,b.Length-1 do ids[#ids+1]=b[i] end
        ok,reason=self.battle:TrySkillTargets(a,ids)
    elseif command == 'skill_landing' then
        assert(b and b.Length==3,'Skill landing requires target id and axial coordinates')
        ok,reason=self.battle:TrySkillWithLanding(a,b[0],b[1],b[2])
    elseif command == 'skill_at_landing' then
        assert(b and b.Length==4,'Cell skill landing requires source and destination axial coordinates')
        ok,reason=self.battle:TrySkillAtWithLanding(a,b[0],b[1],b[2],b[3])
    elseif command == 'use_item' then ok,reason=self.battle:TryItem(a)
    elseif command == 'skill_container' then ok,reason=self.containerCombat:Battle(self.battle,a,b)
    elseif command == 'skill_cell' then
        local cell=self.battle.board.cells[b]
        if self.data.AreaEncounterId>0 then cell=self.areas:ActiveLayout().cells[b] end
        if not cell then return false,'无效技能落点' end
        ok,reason=self.battle:TrySkillAt(a,cell.q,cell.r)
    elseif command == 'end_turn' then ok, reason = self.battle:EndTurn()
    elseif command == 'ai' then ok, reason = self.battle:StepAI()
    else error('Unknown battle command: ' .. tostring(command)) end
    if ok then
        if self.data.AreaEncounterId>0 then self.areas:RevealBattle(self.battle) end
        self:SettleBattle()
    end
    return ok, reason
end
function Adventure:Tick(dt)
    if self.map then self.parties:SyncClock();self.factions:ObserveWorld();self.travel:Tick(dt) end
    if self.equipment.worldLoot.session.Active then return end
    if self.data.Phase=='battle' and self.data.Battle.Winner~='' then self:SettleBattle();return end
    if self.data.Phase~='area' then return end
    if self.narrative and self.narrative.data.DialogueOpen then return end
    if self.context.services.UI.IsWorldPaused then return end
    self.battle.beasts:FollowArea(self)
    self.professionExploration:ObserveTracks()
    if self.specialEvents:BeforeExplore() then return end
    local group=self.areas:FindEncounter()
    if group then self.areas:StartBattle(self.battle,group);self:SettleBattle()
    elseif not self.obstacles:TryRequested() then self.explorationEvents:Try('explore',0) end
end
function Adventure:ReturnToMap()
    if self.data.Phase ~= 'result' then return false, '请先完成事件或战斗' end
    local leave=self.specialEvents:ShouldLeave(self.data.ChoiceId)
    self.data:ReturnToMap(); self.battle.board = nil
    if leave then return self.areas:Leave() end
    if self.data.Phase=='area' then self.areas:RefreshLivingSquad() end
    return true
end
function Adventure:MapSnapshot()
    local map=assert(self.map,'Start an adventure first')
    local result=require('Game.Map.MapRenderSnapshot')(map)
    local sites,occupied={},{}
    for i=0,self.factions.data.SiteCount-1 do local state=self.factions.data:GetSiteAt(i)
        if not state.IsTown then local site=self.sites[state.SiteId];sites[Hex.Key(site.q,site.r)]=true end
    end
    for i,cell in ipairs(map:GetCells()) do if sites[Hex.Key(cell.q,cell.r)] then occupied[i]=true end end
    for _,key in ipairs({'decorations','groundcover'}) do
        local kept={};for _,item in ipairs(result[key]) do if not occupied[item.cell] then kept[#kept+1]=item end end
        result[key]=kept
    end
    return result
end
function Adventure:Snapshot()
    self.fog:Update()
    local result = {phase = self.data.Phase, coins = self.player.Coins, result = self.data.ResultText,
        sites = {}, party = {}, units = {}, cells = {}, reachable = {}, skills = {}, logs = {}, choices = {}, traps = {},
        eventTitle = '', eventText = '', encounter = '', round = 0, activeId = 0, radius = 0,battlePhase=self.data.Battle.Phase}
    result.travel=self.travel:Snapshot()
    result.water=self.water:WorldSnapshot()
    result.worldFog=self.fog.data
    result.worldParties=self.parties:Snapshot()
    -- cells 和 reachable 都由 C# ReadCell 读取，必须包含相同的值类型字段。
    local function cellView(cell) return {q = cell.q, r = cell.r, blocked = cell.blocked,cellIndex=cell.index or 0} end
    local function actorView(actor)
        local row=require('Game.Battle.CombatSnapshot')(actor,self.battle.stats,self.appearances)
        if self.data.Phase=='battle' then row.team=self.battle:PresentationTeam(actor) end
        if self.narrative then row.name=self.narrative.npcs:ActorName(actor) or row.name end
        return row
    end
    for i = 0, self.data.PartyCount - 1 do
        local actor=self.data:GetPartyAt(i);local row=actorView(actor)
        result.party[#result.party + 1]=row
    end
    for _, site in ipairs(assert(self.sites, 'Start an adventure first')) do
        local available,reason
        local special=self.specialEvents.byEvent[site.eventId]
        local areaId=self.areas:AreaId(site)
        if site.factionSite or self.factions.data:FindConflict(site.id) then available=true
        elseif areaId then available,reason=self.areas:CanEnter(site)
        else available,reason=self.events:CanVisit(site) end
        if available then available,reason=self.specialEvents:CanEnter(site) end
        local kind='event'
        if areaId then
            local areaType=self.areas.generator.definitions:Get(areaId).areaType
            kind=site.naturalKind and 'nature' or special and 'battlefield' or areaType==self.areas.shipwreckType and 'shipwreck' or (areaType==self.areas.townType and 'town' or 'dungeon')
        end
        local conflict=self.factions.data:FindConflict(site.id)
        local description=site.factionSite and self.factions:Describe(site.id)
        if site.factionSite then available=true;reason=description;kind='town' end
        if conflict then available=conflict.Phase~='expired';reason=conflict.Phase=='active' and '双方正在交战，可按关系加入' or '战斗已结束，可搜刮战场';kind='battlefield' end
        local siteName=description and (site.name..' · '..description) or site.name
        if self.fog:Known(site.q,site.r,site.naturalKind=='HighMountain' and site.source.regionId or nil) and (not site.travelStop or areaId or site.factionSite or special) and (not conflict or conflict.Phase~='expired') then result.sites[#result.sites + 1] = {id = site.id, name = siteName, x = site.x, y = site.y, z = site.z,
            available = available, visited = self.data:HasVisited(site.id),areaConfigId=areaId or 0,reason=reason or '',
            kind=kind,q=site.q,r=site.r,
            worldRegionId=site.naturalKind=='HighMountain' and site.source.regionId or 0,
            worldTownId=site.areaConfigId and site.pointId and self.map:GetTowns()[site.pointId] and site.pointId or 0} end
    end
    if self.data.Areas.ActiveSiteId>0 then
        result.area=self.areas:Snapshot(self.data.Phase=='battle' and self.battle or nil)
        local layout=self.areas:ActiveLayout()
        for _,member in ipairs(result.area.members) do
            local actor=self.areas:PartyActor(member.actorId)
            local row
            for _,candidate in ipairs(result.party) do if candidate.id==member.actorId then row=candidate;break end end
            assert(row,'Area member has no party projection')
            local cell=assert(layout.cells[member.cellIndex],'Area member has no anchor cell')
            row.cellIndex=cell.index
            for _,occupied in ipairs(assert(self.battle.stats.animals:Cells(actor,layout,cell.q,cell.r,cell.layer))) do
                row.occupiedCells[#row.occupiedCells+1]=occupied.index
            end
        end
        result.area.loot=self.equipment:LootSnapshot(self.areas)
        result.area.obstacles=self.obstacles:Snapshot()
        result.area.constructions=self.construction:Snapshot()
        result.area.constructionRevision=self.construction.data.Revision
        result.area.containerRevision=CS.ProjectY.Data.ContainerState.Revision(self.data.Areas.Active)
    end
    if self.data.Phase == 'event' then
        local event = self.events.events:Get(self.data.EventId)
        result.eventTitle, result.eventText = event.name, self.events:Text(event.description)
        for _, id in ipairs(event.choiceIds) do
            local ok, reason = self.events:CanChoose(id)
            result.choices[#result.choices + 1] = {id = id, label = self.events.choices:Get(id).label, available = ok, reason = reason or ''}
        end
    end
    if self.data.Battle.UnitCount > 0 then
        result.encounter = self.battle.encounters:Get(self.data.Battle.EncounterId).name
        result.round, result.activeId, result.radius = self.data.Battle.Round, self.data.Battle.ActiveId, self.battle.board.radius
        for _, actor in ipairs(self.battle:Units()) do
            local row=actorView(actor)
            row.cellIndex=assert(self.battle.board:Find(actor.Q,actor.R)).index
            for _,cell in ipairs(assert(self.battle.stats.animals:Cells(actor,self.battle.board))) do row.occupiedCells[#row.occupiedCells+1]=cell.index end
            result.units[#result.units + 1] = row
        end
        for _, cell in ipairs(self.battle.board.cells) do result.cells[#result.cells + 1] = cellView(cell) end
        for _, cell in ipairs(self.battle:Reachable()) do result.reachable[#result.reachable + 1] = cellView(cell) end
        if self.data.Phase == 'battle' then
            result.traps=self.battle.professions:TrapRows()
            for _, id in ipairs(self.battle:SkillIds(self.battle:Active())) do
                local skill, targets,previews = self.battle:Skill(self.battle:Active(),id), {},{}
                for _, actor in ipairs(self.battle:Units()) do if self.battle:CanUseSkill(id, actor.Id) then
                    targets[#targets + 1] = actor.Id;previews[#previews+1]=self.battle:ShotPreview(self.battle:Active(),actor,skill)
                end end
                local targetCells,cellLandingOptions={},{}
                local needsCellLanding=self.battle:NeedsCellLanding(id)
                for _,cell in ipairs(self.battle:SkillCells(id)) do
                    targetCells[#targetCells+1]=cell.index or 0
                    if needsCellLanding then
                        local cells={}
                        for _,landing in ipairs(self.battle:CellLandingCells(id,cell.q,cell.r)) do cells[#cells+1]=cellView(landing) end
                        cellLandingOptions[#cellLandingOptions+1]={source=cellView(cell),cells=cells}
                    end
                end
                local rangeCells={}
                for _,cell in ipairs(self.battle:SkillRangeCells(id)) do rangeCells[#rangeCells+1]=assert(cell.index) end
                local needsLanding=self.battle:NeedsSkillLanding(id)
                local landingOptions={}
                if needsLanding then
                    for _,targetId in ipairs(targets) do
                        local cells={}
                        for _,cell in ipairs(self.battle:SkillLandingCells(id,targetId)) do cells[#cells+1]=cellView(cell) end
                        landingOptions[#landingOptions+1]={targetId=targetId,cells=cells}
                    end
                end
                result.skills[#result.skills + 1] = {id = id, name = skill.name, description = skill.description,
                    cost = skill.cost, action = skill.action, targets = targets,targetCells=targetCells,rangeCells=rangeCells,
                    manualTargets=skill.manualTargets,maxTargets=skill.maxTargets,guided=skill.guided,targetPreviews=previews,
                    needsLanding=needsLanding,landingOptions=landingOptions,needsCellLanding=needsCellLanding,cellLandingOptions=cellLandingOptions,
                    containerTargets=self.containerCombat:Targets(self.battle:Active(),id,self.battle)}
            end
        end
        for i = 0, self.data.Battle.LogCount - 1 do result.logs[#result.logs + 1] = self.data.Battle:GetLogAt(i) end
    end
    result.torch=require('Game.Adventure.Torch').Snapshot(self)
    return result
end
function Adventure:OnShutdown()
    if self.partyStory then self.partyStory:Dispose() end
    if self.camp then self.camp:Close() end
    if self.battle then self.battle.containerCombat=nil end
    if self.construction then self.construction.data:Clear();self.battle.construction=nil;self.areas.construction=nil end
    self.map = nil; self.sites = nil
    -- 配方或依赖读取失败时可能尚未取得会话数据，仍须允许启动回滚。
    if self.data then self.data:Reset(0); self.data = nil end
end
return Adventure

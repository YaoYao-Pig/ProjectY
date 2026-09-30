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
    self.explorationEvents = require('Game.Adventure.ExplorationEvents').New(config,self)
    self.characterSkills=require('Game.Adventure.CharacterSkills').New(self)
    assert(self.recipe.maxPartySize<=4 and #self.recipe.partyIds > 0 and #self.recipe.partyIds <= self.recipe.maxPartySize, 'Invalid demo party size')
    assert(#self.recipe.buildingIds == #self.recipe.buildingEventIds, 'Building event mapping differs')
end
function Adventure:Start(seed,recipeId)
    self.recipe = self.config:GetTable('AdventureDemoTable'):Get(recipeId or 1)
    seed = seed or self.recipe.seed
    local map = self.mapSystem:Generate(seed, self.recipe.regionIds)
    local sites, dry = {}, {}
    for _, cell in ipairs(map:GetCells()) do
        if not cell.waterLevel and not cell.buildingId then dry[#dry + 1] = cell end
    end
    assert(#dry > #self.recipe.wildEventIds, 'Map needs dry cells for adventure sites')
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
    addSite(self.recipe.campEventId, camp)
    for _, eventId in ipairs(self.recipe.wildEventIds) do
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
    local mapping = {}
    for i, id in ipairs(self.recipe.buildingIds) do mapping[id] = self.recipe.buildingEventIds[i] end
    for _, building in ipairs(map:GetBuildings()) do
        local eventId = mapping[building.configId]
        if eventId and not areaTowns[building.townId] and #sites < 10 then addSite(eventId, building.cell) end
    end
    self.areas:Clear();self.data:Reset(seed)
    self.map, self.sites = map, sites
    for i, id in ipairs(self.recipe.partyIds) do
        local actor = self.data:AddPartyActor(i, id)
        self.characterAppearances:Party(actor,seed)
        self.growth:Initialize(actor)
        actor:SetMaxHP(self.battle.stats:MaximumHP(actor)); actor:Restore()
    end
    self.equipment:Start()
    self.equipment:StartPartyLoadouts()
    for i=0,self.data.PartyCount-1 do local actor=self.data:GetPartyAt(i);actor:SetMaxHP(self.battle.stats:MaximumHP(actor));actor:Restore() end
    if self.narrative then self.narrative:Start() end
end
function Adventure:Visit(siteId)
    local site = self.sites[siteId]
    if not site then return false, '未知地点' end
    if self.areas:AreaId(site) then
        local ok,reason=self.areas:Enter(site,self.data.Seed)
        if ok then self.equipment:InitializeLoot(self.areas);self.explorationEvents:Try('enter',0) end
        return ok,reason
    end
    local ok,reason = self.events:Begin(site)
    if not ok then return false,reason end
    local event = self.events.events:Get(site.eventId)
    if event.presentation == 'simple' then
        ok,reason = self:Choose(event.choiceIds[1])
        -- 简单事件的条件应在配置层保证可结算；失败时保留当前状态并显示原因。
        if not ok then return false,reason end
        self:ReturnToMap()
    end
    return true
end
function Adventure:AreaCommand(command,a,b)
    if self.narrative and self.narrative.data.DialogueOpen then return false,'请先结束当前对话' end
    if command=='area_tame' then return self.areas:Tame(a,b) end
    if command=='area_loot' then
        local ok,reason=self.equipment:Loot(self.areas,a)
        if ok then
            local loot=self.data.Areas.Active:GetLootAt(a-1);local row=self.equipment.loot:Get(loot.TableId)
            local ids,counts=self.equipment:LootContents(loot)
            local items={};for i,id in ipairs(ids) do items[#items+1]=self.equipment.rules.items:Get(id).name..' ×'..counts[i] end
            self.growth.chronicle:Record('loot',nil,loot.Name,#items>0 and table.concat(items,'、') or '打开了一个空箱子。',self.areas:ActiveLayout().name,true)
            self.explorationEvents:Try('loot',loot.TableId)
        end
        return ok,reason
    end
    if command=='area_move' then return self.areas:MoveTo(a,b) end
    if command=='area_move_cell' then return self.areas:MoveToIndex(a) end
    if command=='area_walk' then return self.areas:Walk(a) end
    if command=='area_interact' then
        local ok,reason=self.areas:Interact(a,b)
        if ok and a==2 and self.narrative then
            local npc=self.areas:ActiveLayout().npcs[b]
            if npc.narrativeId then
                ok,reason=self.narrative.dialogue:Open(npc.narrativeId,b)
                if not ok then self.areas:CloseInteraction() end
                return ok,reason
            end
        end
        if ok and a==1 then self.explorationEvents:Try('facility',self.areas:ActiveLayout().facilities[b].configId) end
        return ok,reason
    end
    if command=='area_close' then return self.areas:CloseInteraction() end
    if command=='area_stop' then return self.areas:Stop() end
    if command=='area_leave' then return self.areas:Leave() end
    error('Unknown MapArea command: '..tostring(command))
end
function Adventure:Choose(choiceId)
    local ok, choice = self.events:Choose(choiceId)
    if not ok then return false, choice end
    if #choice.encounterIds == 1 then
        local site=assert(self.sites[self.data.SiteId]);local cell=self.map:GetCell(site.q,site.r)
        local region=self.map:GetRegion(cell.regionId)
        local source={regionId=region.instanceId,regionConfigId=region.configId,regionType=region.regionType,
            q=cell.q,r=cell.r,height=cell.height,biomeWeights=cell.biomeWeights,encounterId=choice.encounterIds[1]}
        assert(self.areas:EnterEventBattlefield(site,self.data.Seed,source))
        self.equipment:InitializeLoot(self.areas)
        self.areas:StartBattle(self.battle,self.data.Areas.Active:GetEncounterAt(0))
    else
        self.data:Complete(self.events:Text(choice.result))
    end
    return true
end
function Adventure:SettleBattle()
    local result = self.data.Battle.Winner
    if result == '' then return end
    assert(self.data.Phase == 'battle', 'Battle result already consumed')
    self.data:BeginSettlement()
    local encounter = self.battle.encounters:Get(self.data.Battle.EncounterId)
    local location = assert(self.sites[self.data.SiteId]).name
    self.growth.chronicle:Record('battle',nil,encounter.name,
        result=='victory' and '小队赢得了战斗。' or (result=='defeat' and '小队败退，带着伤势返回。' or '小队撤出了战斗。'),location,true)
    for _,actor in ipairs(self.battle:Units()) do
        if actor.Team==1 and actor.HP>0 then self.battle.stats.animals:BattleBond(actor) end
    end
    if result=='victory' then
        for _, actor in ipairs(self.battle:Units()) do
            if actor.Team==1 then self.growth:AddExperience(actor,encounter.experience,location) end
        end
    end
    if self.data.AreaEncounterId>0 then
        local dropped=self.equipment:GenerateEnemyDrops(self.areas,self.battle)
        local message
        if result=='victory' then
            local encounter=self.battle.encounters:Get(self.data.Battle.EncounterId)
            self.player:AddCoins(encounter.rewardCoins);self.events:AwardTraits(encounter.rewardTraitIds)
            message='敌群已击败，获得 '..encounter.rewardCoins..' 金币。可以继续探索。'
            if dropped>0 then message=message..' 地面留下 '..dropped..' 份战利品。' end
        elseif result=='defeat' then message='小队全员倒地，已撤回大地图，请到营地休整。'
        else message='战斗时间耗尽，已撤回大地图。敌人的伤势保留。' end
        self.areas:RestoreAfterBattle(self.battle)
        self.data:FinishAreaBattle(message);self.battle.board=nil
        if result=='victory' then self.explorationEvents:Try('victory',encounter.id) end
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
function Adventure:Tick()
    if self.data.Phase=='battle' and self.data.Battle.Winner~='' then self:SettleBattle();return end
    if self.data.Phase~='area' then return end
    if self.narrative and self.narrative.data.DialogueOpen then return end
    if self.context.services.UI.IsWorldPaused then return end
    local group=self.areas:FindEncounter()
    if group then self.areas:StartBattle(self.battle,group);self:SettleBattle()
    else self.explorationEvents:Try('explore',0) end
end
function Adventure:ReturnToMap()
    if self.data.Phase ~= 'result' then return false, '请先完成事件或战斗' end
    self.data:ReturnToMap(); self.battle.board = nil
    return true
end
function Adventure:MapSnapshot() return require('Game.Map.MapRenderSnapshot')(assert(self.map, 'Start an adventure first')) end
function Adventure:Snapshot()
    local result = {phase = self.data.Phase, coins = self.player.Coins, result = self.data.ResultText,
        sites = {}, party = {}, units = {}, cells = {}, reachable = {}, skills = {}, logs = {}, choices = {},
        eventTitle = '', eventText = '', encounter = '', round = 0, activeId = 0, radius = 0}
    -- cells 和 reachable 都由 C# ReadCell 读取，必须包含相同的值类型字段。
    local function cellView(cell) return {q = cell.q, r = cell.r, blocked = cell.blocked,cellIndex=cell.index or 0} end
    local function actorView(actor)
        local row=require('Game.Battle.CombatSnapshot')(actor,self.battle.stats,self.appearances)
        if self.narrative then row.name=self.narrative.npcs:ActorName(actor) or row.name end
        return row
    end
    for i = 0, self.data.PartyCount - 1 do
        local actor=self.data:GetPartyAt(i);local row=actorView(actor)
        result.party[#result.party + 1]=row
    end
    for _, site in ipairs(assert(self.sites, 'Start an adventure first')) do
        local available,reason
        local areaId=self.areas:AreaId(site)
        if areaId then available,reason=self.areas:CanEnter(site)
        else available,reason=self.events:CanVisit(site) end
        result.sites[#result.sites + 1] = {id = site.id, name = site.name, x = site.x, y = site.y, z = site.z,
            available = available, visited = self.data:HasVisited(site.id),areaConfigId=areaId or 0,reason=reason or '',
            kind=areaId and (self.areas.generator.definitions:Get(areaId).areaType==self.areas.townType and 'town' or 'dungeon') or 'event'}
    end
    if self.data.Areas.ActiveSiteId>0 then
        result.area=self.areas:Snapshot(self.data.Phase=='battle' and self.battle or nil)
        result.area.loot=self.equipment:LootSnapshot(self.areas)
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
            for _, id in ipairs(self.battle:SkillIds(self.battle:Active())) do
                local skill, targets = self.battle:Skill(self.battle:Active(),id), {}
                for _, actor in ipairs(self.battle:Units()) do if self.battle:CanUseSkill(id, actor.Id) then targets[#targets + 1] = actor.Id end end
                local targetCells={}
                for _,cell in ipairs(self.battle:SkillCells(id)) do targetCells[#targetCells+1]=cell.index or 0 end
                result.skills[#result.skills + 1] = {id = id, name = skill.name, description = skill.description,
                    cost = skill.cost, action = skill.action, targets = targets,targetCells=targetCells}
            end
        end
        for i = 0, self.data.Battle.LogCount - 1 do result.logs[#result.logs + 1] = self.data.Battle:GetLogAt(i) end
    end
    return result
end
function Adventure:OnShutdown()
    self.map = nil; self.sites = nil
    -- 配方或依赖读取失败时可能尚未取得会话数据，仍须允许启动回滚。
    if self.data then self.data:Reset(0); self.data = nil end
end
return Adventure
